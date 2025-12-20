unit Admin.Middleware;

interface

uses
  Dext.Web,
  Dext.Web.Interfaces,
  Dext.Web.Core,
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  Dext.Web.Results,
  Admin.Utils;

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
    // Check if it's an HTMX request
    if AContext.Request.GetHeader('HX-Request') <> '' then
    begin
       AContext.Response.StatusCode := 401;
       AContext.Response.AddHeader('HX-Redirect', '/auth/login'); 
    end
    else
    begin
       // Regular browser request (F5 / Direct Access)
       // If it's a known SPA route, serve the main index.html
       // This allows the SPA to load, and then the client-side JS will check for the token
       if (Path.StartsWith('/customers', True)) or 
          (Path.StartsWith('/settings', True)) or 
          (Path.StartsWith('/dashboard', True)) then
       begin
         var FullPath := GetFilePath('wwwroot\index.html');
         if TFile.Exists(FullPath) then
           Results.Html(TFile.ReadAllText(FullPath)).Execute(AContext)
         else
           Results.NotFound('SPA Index not found').Execute(AContext);
       end
       else
       begin
         // Otherwise, redirect to login page
         AContext.Response.StatusCode := 302;
         AContext.Response.AddHeader('Location', '/auth/login');
       end;
    end;
  end;
end;

end.
