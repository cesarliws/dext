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
unit Dext.Http.StaticFiles;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Dext.Http.Interfaces,
  Dext.Http.Core;

type
  TContentTypeProvider = class
  private
    FMimeTypes: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    function TryGetContentType(const AFileName: string; out AContentType: string): Boolean;
  end;

  TStaticFileOptions = record
    RootPath: string;
    DefaultFile: string;
    ServeUnknownFileTypes: Boolean;
    ContentTypeProvider: TContentTypeProvider;
    
    class function Create: TStaticFileOptions; static;
  end;

  TStaticFileMiddleware = class(TMiddleware)
  private
    FOptions: TStaticFileOptions;
    FOwnsProvider: Boolean;
    
    function GetContentType(const AFileName: string): string;
    procedure ServeFile(AContext: IHttpContext; const AFilePath: string);
  public
    constructor Create(const AOptions: TStaticFileOptions);
    destructor Destroy; override;

    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  TApplicationBuilderStaticFilesExtensions = class
  public
    class function UseStaticFiles(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload;
    class function UseStaticFiles(const ABuilder: IApplicationBuilder; const AOptions: TStaticFileOptions): IApplicationBuilder; overload;
    class function UseStaticFiles(const ABuilder: IApplicationBuilder; const ARootPath: string): IApplicationBuilder; overload;
  end;

implementation

uses
  System.Generics.Defaults,
  System.Rtti;

{ TContentTypeProvider }

constructor TContentTypeProvider.Create;
begin
  FMimeTypes := TDictionary<string, string>.Create(TStringComparer.Ordinal);
  // Common Web Types
  FMimeTypes.Add('.html', 'text/html');
  FMimeTypes.Add('.htm', 'text/html');
  FMimeTypes.Add('.css', 'text/css');
  FMimeTypes.Add('.js', 'application/javascript');
  FMimeTypes.Add('.json', 'application/json');
  FMimeTypes.Add('.xml', 'text/xml');
  FMimeTypes.Add('.txt', 'text/plain');
  
  // Images
  FMimeTypes.Add('.png', 'image/png');
  FMimeTypes.Add('.jpg', 'image/jpeg');
  FMimeTypes.Add('.jpeg', 'image/jpeg');
  FMimeTypes.Add('.gif', 'image/gif');
  FMimeTypes.Add('.svg', 'image/svg+xml');
  FMimeTypes.Add('.ico', 'image/x-icon');
  FMimeTypes.Add('.webp', 'image/webp');
  
  // Fonts
  FMimeTypes.Add('.woff', 'font/woff');
  FMimeTypes.Add('.woff2', 'font/woff2');
  FMimeTypes.Add('.ttf', 'font/ttf');
  FMimeTypes.Add('.eot', 'application/vnd.ms-fontobject');
  
  // Others
  FMimeTypes.Add('.pdf', 'application/pdf');
  FMimeTypes.Add('.zip', 'application/zip');
  FMimeTypes.Add('.map', 'application/json'); // Source maps
end;

destructor TContentTypeProvider.Destroy;
begin
  FMimeTypes.Free;
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
  Bytes: TBytes;
begin
  try
    FileStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
    try
      AContext.Response.SetContentType(GetContentType(AFilePath));
      AContext.Response.SetContentLength(FileStream.Size);
      
      SetLength(Bytes, FileStream.Size);
      if FileStream.Size > 0 then
        FileStream.ReadBuffer(Bytes[0], FileStream.Size);
        
      AContext.Response.Write(Bytes);
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
begin
  // âœ… Instantiate Singleton Middleware
  var Middleware := TStaticFileMiddleware.Create(TStaticFileOptions.Create);
  Result := ABuilder.UseMiddleware(Middleware);
end;

class function TApplicationBuilderStaticFilesExtensions.UseStaticFiles(
  const ABuilder: IApplicationBuilder;
  const AOptions: TStaticFileOptions): IApplicationBuilder;
begin
  // âœ… Instantiate Singleton Middleware
  var Middleware := TStaticFileMiddleware.Create(AOptions);
  Result := ABuilder.UseMiddleware(Middleware);
end;

class function TApplicationBuilderStaticFilesExtensions.UseStaticFiles(
  const ABuilder: IApplicationBuilder;
  const ARootPath: string): IApplicationBuilder;
var
  Options: TStaticFileOptions;
begin
  Options := TStaticFileOptions.Create;
  Options.RootPath := ARootPath;
  
  // âœ… Instantiate Singleton Middleware
  var Middleware := TStaticFileMiddleware.Create(Options);
  Result := ABuilder.UseMiddleware(Middleware);
end;

end.

