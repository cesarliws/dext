unit Dext.Web.StaticFiles.Security.Tests;

interface

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  Dext.Collections.Dict,
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Web,
  Dext.Web.Interfaces,
  Dext.Web.StaticFiles,
  Dext.Web.Mocks,
  Dext.Server.Native,
  Dext.Server.Engine.Interfaces;

type
  [TestFixture('Static Files - path traversal containment')]
  TStaticFilesSecurityTests = class
  public
    // --- the resolver, on its own -------------------------------------------
    [Test('Should serve a plain file inside the root')]
    procedure TestServesPlainFile;

    [Test('Should serve a file in a sub directory')]
    procedure TestServesSubDirectoryFile;

    [Test('Should still serve a file whose name merely contains two dots')]
    procedure TestDoesNotRejectDotsInsideAName;

    [Test('Should reject a parent directory segment')]
    procedure TestRejectsParentSegment;

    [Test('Should reject a parent segment buried in the middle of the path')]
    procedure TestRejectsBuriedParentSegment;

    [Test('Should reject a percent encoded parent segment')]
    procedure TestRejectsEncodedParentSegment;

    [Test('Should reject a backslash separated parent segment')]
    procedure TestRejectsBackslashParentSegment;

    [Test('Should reject an absolute path with a drive letter')]
    procedure TestRejectsDriveLetter;

    [Test('Should reject an NTFS alternate data stream')]
    procedure TestRejectsAlternateDataStream;

    [Test('Should reject an embedded NUL')]
    procedure TestRejectsEmbeddedNul;

    [Test('Should keep every accepted path under the canonical root')]
    procedure TestAcceptedPathsStayUnderTheRoot;

    [Test('Should not accept a sibling directory sharing the root prefix')]
    procedure TestSiblingDirectoryIsNotInsideTheRoot;

    // --- the middleware, against real files ---------------------------------
    [Test('Should serve an existing file through the middleware')]
    procedure TestMiddlewareServesExistingFile;

    [Test('Should not serve a file above the root through the middleware')]
    procedure TestMiddlewareDoesNotEscapeUpwards;

    [Test('Should not serve an absolute path through the middleware')]
    procedure TestMiddlewareDoesNotServeAbsolutePath;
  end;

implementation

const
  ROOT = 'C:\dext_static_root';

type
  TMockRawRequest = class(TInterfacedObject, IDextRawRequest)
  private
    FPath: string;
  public
    constructor Create(const APath: string);
    function GetMethod: string;
    function GetPath: string;
    function GetQueryString: string;
    function GetHeader(const AName: string): string;
    procedure PopulateHeaders(ADict: TDictionary<string, string>);
    function GetContentLength: Int64;
    function GetBodyStream: TStream;
  end;

constructor TMockRawRequest.Create(const APath: string);
begin
  inherited Create;
  FPath := APath;
end;

function TMockRawRequest.GetMethod: string; begin Result := 'GET'; end;
function TMockRawRequest.GetPath: string; begin Result := FPath; end;
function TMockRawRequest.GetQueryString: string; begin Result := ''; end;
function TMockRawRequest.GetHeader(const AName: string): string; begin Result := ''; end;
procedure TMockRawRequest.PopulateHeaders(ADict: TDictionary<string, string>); begin end;
function TMockRawRequest.GetContentLength: Int64; begin Result := 0; end;
function TMockRawRequest.GetBodyStream: TStream; begin Result := nil; end;

{ helpers }

/// True when the middleware served the request itself, i.e. it did not hand the
/// context on to the rest of the pipeline. A rejected path has to look exactly
/// like a missing file, so "was it served" is the whole assertion.
function Served(const ARoot, ARequestPath: string): Boolean;
var
  Options: TStaticFileOptions;
  Middleware: IMiddleware;
  Ctx: IHttpContext;
  WentOn: Boolean;
begin
  Options := TStaticFileOptions.Create;
  Options.RootPath := ARoot;

  Middleware := TStaticFileMiddleware.Create(Options);
  Ctx := TMockHttpContext.Create(
    TDextNativeHttpRequest.Create(TMockRawRequest.Create(ARequestPath), '127.0.0.1'),
    TMockHttpResponse.Create,
    nil);

  WentOn := False;
  Middleware.Invoke(Ctx,
    procedure(C: IHttpContext)
    begin
      WentOn := True;
    end);

  Result := not WentOn;
end;

{ TStaticFilesSecurityTests }

procedure TStaticFilesSecurityTests.TestServesPlainFile;
var
  Resolved: string;
begin
  Should(TryResolveStaticFilePath(ROOT, '/index.html', Resolved))
    .BeTrue.Because('a plain file inside the root is the whole point');
  Should(Resolved).Be(ROOT + '\index.html');
end;

procedure TStaticFilesSecurityTests.TestServesSubDirectoryFile;
var
  Resolved: string;
begin
  Should(TryResolveStaticFilePath(ROOT, '/css/site.css', Resolved)).BeTrue;
  Should(Resolved).Be(ROOT + '\css\site.css');
end;

procedure TStaticFilesSecurityTests.TestDoesNotRejectDotsInsideAName;
var
  Resolved: string;
begin
  // The check is segment exact on purpose: 'notes..txt' is a legal file name and
  // a plain substring search for '..' would refuse to serve it.
  Should(TryResolveStaticFilePath(ROOT, '/notes..txt', Resolved))
    .BeTrue.Because('two dots inside a name are not a parent segment');
  Should(Resolved).Be(ROOT + '\notes..txt');
end;

procedure TStaticFilesSecurityTests.TestRejectsParentSegment;
var
  Resolved: string;
begin
  Should(TryResolveStaticFilePath(ROOT, '/../secret.txt', Resolved)).BeFalse;
  Should(Resolved).BeEmpty.Because('a refused request must not hand back a path');
end;

procedure TStaticFilesSecurityTests.TestRejectsBuriedParentSegment;
var
  Resolved: string;
begin
  Should(TryResolveStaticFilePath(ROOT, '/css/../../secret.txt', Resolved)).BeFalse;
end;

procedure TStaticFilesSecurityTests.TestRejectsEncodedParentSegment;
var
  Resolved: string;
begin
  // Engines disagree on who decodes the path, so the guard decodes before it
  // looks instead of trusting whatever sits in front of it.
  Should(TryResolveStaticFilePath(ROOT, '/%2e%2e/secret.txt', Resolved)).BeFalse;
  Should(TryResolveStaticFilePath(ROOT, '/%2E%2E%2Fsecret.txt', Resolved)).BeFalse;
end;

procedure TStaticFilesSecurityTests.TestRejectsBackslashParentSegment;
var
  Resolved: string;
begin
  Should(TryResolveStaticFilePath(ROOT, '/..\secret.txt', Resolved)).BeFalse;
end;

procedure TStaticFilesSecurityTests.TestRejectsDriveLetter;
var
  Resolved: string;
begin
  // No parent segment anywhere in this one. It escapes because TPath.Combine
  // returns its second argument untouched when that argument is rooted, which
  // drops the root entirely -- and because the path is already canonical, a
  // canonicaliser upstream such as the HTTP.sys kernel has nothing to correct.
  Should(TryResolveStaticFilePath(ROOT, '/C:/Windows/win.ini', Resolved))
    .BeFalse.Because('an absolute path must never be taken from the request');
  Should(Resolved).BeEmpty;
end;

procedure TStaticFilesSecurityTests.TestRejectsAlternateDataStream;
var
  Resolved: string;
begin
  Should(TryResolveStaticFilePath(ROOT, '/appsettings.json::$DATA', Resolved)).BeFalse;
end;

procedure TStaticFilesSecurityTests.TestRejectsEmbeddedNul;
var
  Resolved: string;
begin
  Should(TryResolveStaticFilePath(ROOT, '/index.html' + #0 + '.png', Resolved)).BeFalse;
end;

procedure TStaticFilesSecurityTests.TestAcceptedPathsStayUnderTheRoot;
const
  LEGIT: array[0..3] of string =
    ('/index.html', '/css/site.css', '/img/logo.png', '/docs/a/b/c.pdf');
var
  Resolved: string;
  Candidate: string;
begin
  for Candidate in LEGIT do
  begin
    Should(TryResolveStaticFilePath(ROOT, Candidate, Resolved)).BeTrue;
    Should(Resolved).StartWith(ROOT + '\');
  end;
end;

procedure TStaticFilesSecurityTests.TestSiblingDirectoryIsNotInsideTheRoot;
var
  Resolved: string;
begin
  // The containment comparison carries the trailing delimiter, so it lands on a
  // segment boundary: 'C:\dext_static_root_backup' merely starts with the same
  // characters and must not count as being inside the root.
  Should(TryResolveStaticFilePath(ROOT, '/../dext_static_root_backup/x.txt', Resolved))
    .BeFalse.Because('sharing a prefix with the root is not the same as being under it');
end;

procedure TStaticFilesSecurityTests.TestMiddlewareServesExistingFile;
var
  Base, Root: string;
begin
  Base := TPath.Combine(TPath.GetTempPath, 'dext_sf_' + TGuid.NewGuid.ToString);
  Root := TPath.Combine(Base, 'wwwroot');
  TDirectory.CreateDirectory(Root);
  try
    TFile.WriteAllText(TPath.Combine(Root, 'index.html'), '<h1>ok</h1>');

    Should(Served(Root, '/index.html'))
      .BeTrue.Because('the guard must not get in the way of serving real files');
  finally
    TDirectory.Delete(Base, True);
  end;
end;

procedure TStaticFilesSecurityTests.TestMiddlewareDoesNotEscapeUpwards;
var
  Base, Root, Secret: string;
begin
  Base := TPath.Combine(TPath.GetTempPath, 'dext_sf_' + TGuid.NewGuid.ToString);
  Root := TPath.Combine(Base, 'wwwroot');
  TDirectory.CreateDirectory(Root);
  try
    Secret := TPath.Combine(Base, 'secret.txt');
    TFile.WriteAllText(Secret, 'connection string');

    Should(FileExists(Secret))
      .BeTrue.Because('the target has to exist, or the test proves nothing');
    Should(Served(Root, '/../secret.txt'))
      .BeFalse.Because('a file above the root has to stay unreachable');
  finally
    TDirectory.Delete(Base, True);
  end;
end;

procedure TStaticFilesSecurityTests.TestMiddlewareDoesNotServeAbsolutePath;
var
  Base, Root, Secret: string;
begin
  Base := TPath.Combine(TPath.GetTempPath, 'dext_sf_' + TGuid.NewGuid.ToString);
  Root := TPath.Combine(Base, 'wwwroot');
  TDirectory.CreateDirectory(Root);
  try
    Secret := TPath.Combine(Base, 'secret.txt');
    TFile.WriteAllText(Secret, 'connection string');

    Should(FileExists(Secret)).BeTrue;
    // Handed over as an absolute path, with no parent segment to canonicalise.
    Should(Served(Root, '/' + Secret.Replace('\', '/')))
      .BeFalse.Because('the configured root has to win over a path in the request');
  finally
    TDirectory.Delete(Base, True);
  end;
end;

end.
