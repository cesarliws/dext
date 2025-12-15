unit Admin.Middleware;

interface

uses
  Dext.Web,
  Dext.Web.Interfaces,
  Dext.Web.Core,
  System.SysUtils,
  System.StrUtils;

type
  TAdminAuthMiddleware = class(TMiddleware)
  public
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

implementation

{ TAdminAuthMiddleware }

procedure TAdminAuthMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  Path: string;
begin
  Path := AContext.Request.Path;
  
  // Define Public Paths
  if (Path = '/') or 
     (Path.StartsWith('/login', True)) or 
     (Path.StartsWith('/auth/', True)) or 
     (Path.StartsWith('/css/', True)) or 
     (Path.StartsWith('/js/', True)) or 
     (Path.StartsWith('/lib/', True)) or 
     (SameText(Path, '/favicon.ico')) then
  begin
    ANext(AContext);
    Exit;
  end;

  // Check Authentication
  if (AContext.User <> nil) and 
     (AContext.User.Identity <> nil) and 
     (AContext.User.Identity.IsAuthenticated) then
  begin
    ANext(AContext);
  end
  else
  begin
    // Unauthorized
    AContext.Response.StatusCode := 401;
    AContext.Response.AddHeader('HX-Redirect', '/auth/login'); 
  end;
end;

end.
