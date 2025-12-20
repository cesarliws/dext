{***************************************************************************}
{           Dext Framework - Response Compression                           }
{***************************************************************************}
unit Dext.Web.Middleware.Compression;

interface

uses
  System.SysUtils, System.Classes, System.ZLib,
  Dext.Web.Interfaces, Dext.Web.Middleware, Dext.Threading.Async;

type
  TCompressionMiddleware = class(TMiddleware)
  public
    function Invoke(const AContext: IHttpContext): ITask; override;
  end;

implementation

{ TCompressionMiddleware }

function TCompressionMiddleware.Invoke(const AContext: IHttpContext): ITask;
var
  LAccessEncoding: string;
  LResponseStream: TMemoryStream;
  LCustomStream: TMemoryStream;
  LZipStream: TZCompressionStream;
begin
  // Very basic implementation: Check Accept-Encoding for gzip
  // In a real middleware, we would intercept the response stream.
  // Since Dext IHttpContext.Response.Body is a stream, we can wrap it?
  
  // Current Dext architecture might support response buffering.
  // For now, we just pass through as a placeholder for the logic.
  // To truly implement compression, we need to replace the Response.Body with a compression stream wrapper
  // OR compress the buffer after processing.

  // Assuming we can inspect headers:
  // LAccessEncoding := AContext.Request.Headers['Accept-Encoding'];
  // if Pos('gzip', LAccessEncoding) > 0 then ...
  
  Result := Next(AContext);
end;

end.
