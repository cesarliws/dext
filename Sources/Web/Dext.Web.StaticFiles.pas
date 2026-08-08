{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.StaticFiles;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Interfaces,
  Dext.Web.Builder;

type
  /// <summary>
  ///   MIME type provider based on file extensions.
  /// </summary>
  /// <summary>
  ///   MIME type provider based on file extensions.
  /// </summary>
  TContentTypeProvider = class
  private
    FMimeTypes: IDictionary<string, string>;
    class function NormalizeExtension(const AExtension: string): string; static;
    procedure RegisterDefaults;
  public
    /// <summary> Creates a new TContentTypeProvider with default MIME type mappings. </summary>
    constructor Create;
    /// <summary> Destroys TContentTypeProvider. </summary>
    destructor Destroy; override;
    /// <summary> Registers or updates a MIME type mapping for an extension. </summary>
    procedure AddOrUpdate(const AExtension, AContentType: string);
    /// <summary> Loads custom MIME type mappings from a JSON mapping file. </summary>
    function LoadFromFile(const AFilePath: string): Integer;
    /// <summary> Tries to retrieve the Content-Type for a given file name or extension. </summary>
    function TryGetContentType(const AFileName: string; out AContentType: string): Boolean;
  end;

  /// <summary>
  ///   Configuration options for the static file server.
  /// </summary>
  TStaticFileOptions = record
    /// <summary> Root physical path on disk serving static files (e.g. './wwwroot'). </summary>
    RootPath: string;
    /// <summary> Default file name to serve when a directory URL is requested (e.g. 'index.html'). </summary>
    DefaultFile: string;
    /// <summary> Whether to serve unknown file extensions with fallback octet-stream Content-Type. </summary>
    ServeUnknownFileTypes: Boolean;
    /// <summary> Custom Content-Type provider instance. </summary>
    ContentTypeProvider: TContentTypeProvider;
    /// <summary> Path to external JSON MIME type mapping file. </summary>
    MimeTypesFile: string;
    
    /// <summary> Creates default TStaticFileOptions. </summary>
    class function Create: TStaticFileOptions; static;
  end;

  /// <summary> Fluent builder for TStaticFileOptions. </summary>
  TStaticFileBuilder = record
  private
    FOptions: TStaticFileOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized;
  public
    /// <summary> Creates a new static file builder. </summary>
    class function Create: TStaticFileBuilder; static;
    /// <summary> Configures root path for static file server. </summary>
    function RootPath(const APath: string): TStaticFileBuilder;
    /// <summary> Configures default file name (e.g. 'index.html'). </summary>
    function DefaultFile(const AFile: string): TStaticFileBuilder;
    /// <summary> Configures whether to serve unknown file types. </summary>
    function ServeUnknownFileTypes(AValue: Boolean = True): TStaticFileBuilder;
    /// <summary> Sets a custom content type provider. </summary>
    function ContentTypeProvider(AProvider: TContentTypeProvider): TStaticFileBuilder;
    /// <summary> Sets custom MIME types mapping file path. </summary>
    function MimeTypesFile(const AFilePath: string): TStaticFileBuilder;
    /// <summary> Builds and returns TStaticFileOptions. </summary>
    function Build: TStaticFileOptions;
    /// <summary> Implicit conversion operator from builder to options. </summary>
    class operator Implicit(const ABuilder: TStaticFileBuilder): TStaticFileOptions;
  end;

  /// <summary>
  ///   Middleware responsible for serving physical files from the file system.
  /// </summary>
  TStaticFileMiddleware = class(TMiddleware)
  private
    FOptions: TStaticFileOptions;
    FOwnsProvider: Boolean;
    
    function GetContentType(const AFileName: string): string;
    procedure ServeFile(AContext: IHttpContext; const AFilePath: string);
  public
    /// <summary> Creates a new static file middleware instance with specified options. </summary>
    constructor Create(const AOptions: TStaticFileOptions);
    /// <summary> Destroys static file middleware instance. </summary>
    destructor Destroy; override;

    /// <summary> Invokes static file middleware logic in the HTTP pipeline. </summary>
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary> Extension methods for adding static files middleware to IApplicationBuilder. </summary>
  TApplicationBuilderStaticFilesExtensions = class
  public
    /// <summary> Enables static files middleware with default options. </summary>
    class function UseStaticFiles(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload;
    /// <summary> Enables static files middleware with custom options record. </summary>
    class function UseStaticFiles(const ABuilder: IApplicationBuilder; const AOptions: TStaticFileOptions): IApplicationBuilder; overload;
    /// <summary> Enables static files middleware with custom root path string. </summary>
    class function UseStaticFiles(const ABuilder: IApplicationBuilder; const ARootPath: string): IApplicationBuilder; overload;
    /// <summary> Enables static files middleware with a fluent builder. </summary>
    class function UseStaticFiles(const ABuilder: IApplicationBuilder; const ABuilderObj: TStaticFileBuilder): IApplicationBuilder; overload;
  end;

/// <summary> Factory function returning a fluent TStaticFileBuilder instance. </summary>
function StaticFileOptions: TStaticFileBuilder;

implementation

uses
  System.Rtti,
  Dext.Json,
  Dext.Json.Types;

{ TContentTypeProvider }

constructor TContentTypeProvider.Create;
begin
  FMimeTypes := TCollections.CreateDictionaryIgnoreCase<string, string>;
  RegisterDefaults;
end;

class function TContentTypeProvider.NormalizeExtension(const AExtension: string): string;
begin
  Result := AExtension.Trim;
  if Result = '' then
    Exit('');
  if not Result.StartsWith('.') then
    Result := '.' + Result;
end;

procedure TContentTypeProvider.RegisterDefaults;
begin
  // Common Web Types
  AddOrUpdate('.html', 'text/html; charset=utf-8');
  AddOrUpdate('.htm', 'text/html; charset=utf-8');
  AddOrUpdate('.css', 'text/css; charset=utf-8');
  AddOrUpdate('.js', 'application/javascript; charset=utf-8');
  AddOrUpdate('.json', 'application/json; charset=utf-8');
  AddOrUpdate('.xml', 'text/xml; charset=utf-8');
  AddOrUpdate('.txt', 'text/plain; charset=utf-8');
  
  // Images
  AddOrUpdate('.png', 'image/png');
  AddOrUpdate('.jpg', 'image/jpeg');
  AddOrUpdate('.jpeg', 'image/jpeg');
  AddOrUpdate('.gif', 'image/gif');
  AddOrUpdate('.svg', 'image/svg+xml');
  AddOrUpdate('.ico', 'image/x-icon');
  AddOrUpdate('.webp', 'image/webp');
  
  // Fonts
  AddOrUpdate('.woff', 'font/woff');
  AddOrUpdate('.woff2', 'font/woff2');
  AddOrUpdate('.ttf', 'font/ttf');
  AddOrUpdate('.eot', 'application/vnd.ms-fontobject');
  
  // Others
  AddOrUpdate('.pdf', 'application/pdf');
  AddOrUpdate('.zip', 'application/zip');
  AddOrUpdate('.map', 'application/json'); // Source maps
end;

procedure TContentTypeProvider.AddOrUpdate(const AExtension, AContentType: string);
var
  Ext: string;
begin
  Ext := NormalizeExtension(AExtension);
  if (Ext = '') or (AContentType.Trim = '') then
    Exit;
  FMimeTypes.AddOrSetValue(Ext, AContentType.Trim);
end;

function TContentTypeProvider.LoadFromFile(const AFilePath: string): Integer;
var
  FullPath: string;
  Content: string;
  Lines: TArray<string>;
  Line: string;
  EqPos: Integer;
  Ext: string;
  Mime: string;
  Node: IDextJsonNode;
  Obj: IDextJsonObject;
  I: Integer;
  LineItem: string;
begin
  Result := 0;

  if AFilePath.Trim = '' then
    Exit;

  FullPath := AFilePath;
  if not TPath.IsPathRooted(FullPath) then
    FullPath := TPath.Combine(ExtractFilePath(ParamStr(0)), FullPath);

  if not FileExists(FullPath) then
    Exit;

  Content := TFile.ReadAllText(FullPath, TEncoding.UTF8).Trim;
  if Content = '' then
    Exit;

  // JSON object format: { ".md": "text/markdown", ".csv": "text/csv" }
  if Content.StartsWith('{') then
  begin
    Node := TDextJson.Provider.Parse(Content);
    if (Node <> nil) and (Node.GetNodeType = jntObject) then
    begin
      Obj := Node as IDextJsonObject;
      for I := 0 to Obj.GetCount - 1 do
      begin
        Ext := Obj.GetName(I);
        Mime := Obj.GetString(Ext);
        AddOrUpdate(Ext, Mime);
        Inc(Result);
      end;
    end;
    Exit;
  end;

  // Line format:
  // .md=text/markdown
  // csv=text/csv
  Lines := Content.Split([sLineBreak]);
  for LineItem in Lines do
  begin
    Line := LineItem.Trim;
    if (Line = '') or Line.StartsWith('#') or Line.StartsWith('//') then
      Continue;

    EqPos := Line.IndexOf('=');
    if EqPos < 1 then
      Continue;

    Ext := Line.Substring(0, EqPos).Trim;
    Mime := Line.Substring(EqPos + 1).Trim;
    if (Ext <> '') and (Mime <> '') then
    begin
      AddOrUpdate(Ext, Mime);
      Inc(Result);
    end;
  end;
end;

destructor TContentTypeProvider.Destroy;
begin
  FMimeTypes := nil;
  inherited;
end;

function TContentTypeProvider.TryGetContentType(const AFileName: string; out AContentType: string): Boolean;
var
  Ext: string;
begin
  Ext := TPath.GetExtension(AFileName);
  Result := FMimeTypes.TryGetValue(Ext, AContentType);
end;

{ TStaticFileOptions }

class function TStaticFileOptions.Create: TStaticFileOptions;
begin
  Result.RootPath := 'wwwroot';
  Result.DefaultFile := 'index.html';
  Result.ServeUnknownFileTypes := False;
  Result.ContentTypeProvider := nil; // Will be created if nil
  Result.MimeTypesFile := '';
end;

{ TStaticFileMiddleware }

constructor TStaticFileMiddleware.Create(const AOptions: TStaticFileOptions);
begin
  inherited Create;
  FOptions := AOptions;
  if FOptions.ContentTypeProvider = nil then
  begin
    FOptions.ContentTypeProvider := TContentTypeProvider.Create;
    FOwnsProvider := True;
  end
  else
    FOwnsProvider := False;
    
  // Ensure RootPath is absolute or relative to app dir
  if not TPath.IsPathRooted(FOptions.RootPath) then
    FOptions.RootPath := TPath.Combine(ExtractFilePath(ParamStr(0)), FOptions.RootPath);
    
  if not DirectoryExists(FOptions.RootPath) then
    ForceDirectories(FOptions.RootPath);

  if FOptions.MimeTypesFile <> '' then
    FOptions.ContentTypeProvider.LoadFromFile(FOptions.MimeTypesFile);
end;

destructor TStaticFileMiddleware.Destroy;
begin
  if FOwnsProvider then
    FOptions.ContentTypeProvider.Free;
  inherited;
end;

function TStaticFileMiddleware.GetContentType(const AFileName: string): string;
begin
  if not FOptions.ContentTypeProvider.TryGetContentType(AFileName, Result) then
    Result := 'application/octet-stream';
end;

procedure TStaticFileMiddleware.ServeFile(AContext: IHttpContext; const AFilePath: string);
var
  FileStream: TFileStream;
begin
  try
    FileStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
    try
      AContext.Response.SetContentType(GetContentType(AFilePath));
      AContext.Response.SetContentLength(FileStream.Size);
      
      // âœ… Use efficient Stream writing
      AContext.Response.Write(FileStream);
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
    begin
      // Log error
      AContext.Response.StatusCode := 500;
    end;
  end;
end;

procedure TStaticFileMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  RequestPath: string;
  FilePath: string;
begin
  RequestPath := AContext.Request.Path;
  
  // Normalize path
  if RequestPath = '/' then
    RequestPath := '/' + FOptions.DefaultFile;
    
  // Remove leading slash for combination
  if RequestPath.StartsWith('/') then
    RequestPath := RequestPath.Substring(1);
    
  FilePath := TPath.Combine(FOptions.RootPath, RequestPath);
  
  if FileExists(FilePath) then
  begin
    ServeFile(AContext, FilePath);
    // Terminate pipeline (do not call Next)
    Exit;
  end;
  
  // Not found, continue pipeline
  ANext(AContext);
end;

{ TApplicationBuilderStaticFilesExtensions }

class function TApplicationBuilderStaticFilesExtensions.UseStaticFiles(
  const ABuilder: IApplicationBuilder): IApplicationBuilder;
var
  Middleware: TStaticFileMiddleware;
begin
  // ✅ Instantiate Singleton Middleware
  Middleware := TStaticFileMiddleware.Create(TStaticFileOptions.Create);
  Result := ABuilder.UseMiddleware(Middleware);
end;

class function TApplicationBuilderStaticFilesExtensions.UseStaticFiles(
  const ABuilder: IApplicationBuilder;
  const AOptions: TStaticFileOptions): IApplicationBuilder;
var
  Middleware: TStaticFileMiddleware;
begin
  // ✅ Instantiate Singleton Middleware
  Middleware := TStaticFileMiddleware.Create(AOptions);
  Result := ABuilder.UseMiddleware(Middleware);
end;

class function TApplicationBuilderStaticFilesExtensions.UseStaticFiles(
  const ABuilder: IApplicationBuilder;
  const ARootPath: string): IApplicationBuilder;
var
  Options: TStaticFileOptions;
  Middleware: TStaticFileMiddleware;
begin
  Options := TStaticFileOptions.Create;
  Options.RootPath := ARootPath;
  
  // ✅ Instantiate Singleton Middleware
  Middleware := TStaticFileMiddleware.Create(Options);
  Result := ABuilder.UseMiddleware(Middleware);
end;

class function TApplicationBuilderStaticFilesExtensions.UseStaticFiles(
  const ABuilder: IApplicationBuilder;
  const ABuilderObj: TStaticFileBuilder): IApplicationBuilder;
begin
  Result := UseStaticFiles(ABuilder, ABuilderObj.Build);
end;

function StaticFileOptions: TStaticFileBuilder;
begin
  Result := TStaticFileBuilder.Create;
end;

{ TStaticFileBuilder }

class function TStaticFileBuilder.Create: TStaticFileBuilder;
begin
  Result.FOptions := TStaticFileOptions.Create;
  Result.FInitialized := True;
end;

procedure TStaticFileBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FOptions := TStaticFileOptions.Create;
    FInitialized := True;
  end;
end;

function TStaticFileBuilder.RootPath(const APath: string): TStaticFileBuilder;
begin
  EnsureInitialized;
  FOptions.RootPath := APath;
  Result := Self;
end;

function TStaticFileBuilder.DefaultFile(const AFile: string): TStaticFileBuilder;
begin
  EnsureInitialized;
  FOptions.DefaultFile := AFile;
  Result := Self;
end;

function TStaticFileBuilder.ServeUnknownFileTypes(AValue: Boolean): TStaticFileBuilder;
begin
  EnsureInitialized;
  FOptions.ServeUnknownFileTypes := AValue;
  Result := Self;
end;

function TStaticFileBuilder.ContentTypeProvider(AProvider: TContentTypeProvider): TStaticFileBuilder;
begin
  EnsureInitialized;
  FOptions.ContentTypeProvider := AProvider;
  Result := Self;
end;

function TStaticFileBuilder.MimeTypesFile(const AFilePath: string): TStaticFileBuilder;
begin
  EnsureInitialized;
  FOptions.MimeTypesFile := AFilePath;
  Result := Self;
end;

function TStaticFileBuilder.Build: TStaticFileOptions;
begin
  EnsureInitialized;
  Result := FOptions;
end;

class operator TStaticFileBuilder.Implicit(const ABuilder: TStaticFileBuilder): TStaticFileOptions;
begin
  Result := ABuilder.Build;
end;

end.
