unit Dashboard.Endpoints;

interface

uses
  Dext,
  Dext.Web,
  Dext.Persistence,
  DbContext,
  Customer, Order, // Feature units
  System.IOUtils, // Added for TFile
  System.SysUtils;

type
  TDashboardEndpoints = class
  public
    class procedure Map(App: IApplicationBuilder);
  private
    class function CheckAuth(Context: IHttpContext): Boolean;
  end;

implementation

function GetFilePath(const RelativePath: string): string;
begin
  // Executable runs from Output\ directory, files are in Dext.Starter.Admin\
  Result := IncludeTrailingPathDelimiter(GetCurrentDir) + '..\Dext.Starter.Admin\' + RelativePath;
end;

{ TDashboardEndpoints }

class function TDashboardEndpoints.CheckAuth(Context: IHttpContext): Boolean;
begin
  Result := (Context.User <> nil) and 
            (Context.User.Identity <> nil) and 
            (Context.User.Identity.IsAuthenticated);
            
  if not Result then
    Context.Response.StatusCode := 401;
end;

class procedure TDashboardEndpoints.Map(App: IApplicationBuilder);
begin
  // Root path - serve main shell
  // Allow anonymous access so index.html can load and handle auth logic client-side
  App.MapGet('/',
    procedure(Context: IHttpContext)
    begin
      var Res: IResult := TContentResult.Create(TFile.ReadAllText(GetFilePath('wwwroot\index.html')), 'text/html');
      Res.Execute(Context);
    end);

  // Dashboard fragment - Protected
  App.MapGet('/dashboard',
    procedure(Context: IHttpContext)
    begin
      if not CheckAuth(Context) then Exit;
      
      var Res: IResult := TContentResult.Create(TFile.ReadAllText(GetFilePath('wwwroot\views\dashboard_fragment.html')), 'text/html');
      Res.Execute(Context);
    end);

  // Dashboard stats - returns HTML cards - Protected
  App.MapGet('/dashboard/stats',
    procedure(Context: IHttpContext)
    begin
      if not CheckAuth(Context) then Exit;
      
      var Db := TServiceProviderExtensions.GetRequiredServiceObject<TAppDbContext>(Context.Services);
      
      var TotalCustomers := Db.Entities<TCustomer>.List.Count; 
      
      var Orders := Db.Entities<TOrder>.List;
      var TotalSales: Currency := 0;
      for var O in Orders do
        TotalSales := TotalSales + O.Total;
        
      var Html := Format(
        '<div class="bg-white rounded-lg shadow p-6">' +
        '  <h3 class="text-sm font-medium text-gray-500">Total Customers</h3>' +
        '  <p class="text-2xl font-bold text-gray-900 mt-2">%d</p>' +
        '</div>' +
        '<div class="bg-white rounded-lg shadow p-6">' +
        '  <h3 class="text-sm font-medium text-gray-500">Total Revenue</h3>' +
        '  <p class="text-2xl font-bold text-gray-900 mt-2">%m</p>' +
        '</div>', 
        [TotalCustomers, TotalSales]);

      var Res: IResult := TContentResult.Create(Html, 'text/html');
      Res.Execute(Context);
    end);

  // Dashboard chart data - returns JSON - Protected
  App.MapGet('/dashboard/chart',
    procedure(Context: IHttpContext)
    begin
      if not CheckAuth(Context) then Exit;
      
       var Res := Results.Json('{' +
       '"labels": ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],' +
       '"datasets": [{' +
         '"label": "Sales",' +
         '"data": [12, 19, 3, 5, 2, 3],' +
         '"borderWidth": 1' +
       '}]' +
     '}');
     Res.Execute(Context);
    end);
end;

end.
