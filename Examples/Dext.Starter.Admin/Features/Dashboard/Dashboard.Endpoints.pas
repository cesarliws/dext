unit Dashboard.Endpoints;

interface

uses
  Dext,
  Dext.Web,
  Dext.Web.Results, // Added for Results helper
  Dext.Persistence,
  DbContext,
  Customer, Order, // Feature units
  Admin.Utils, // Shared
  System.IOUtils, 
  System.SysUtils;

type
  TDashboardEndpoints = class
  public
    class procedure Map(App: TDextAppBuilder);
  end;

implementation

uses
  AppResponseConsts,
  Dashboard.Service;

{ TDashboardEndpoints }

class procedure TDashboardEndpoints.Map(App: TDextAppBuilder);
begin
  // Root path (index.html is in wwwroot, not in views, so use relative path)
  App.MapGet('/',
    procedure(Context: IHttpContext)
    begin
      Results.HtmlFromFile('..\index.html').Execute(Context);
    end);

  // Dashboard fragment
  App.MapGet('/dashboard',
    procedure(Context: IHttpContext)
    begin
      Results.HtmlFromFile('dashboard_fragment.html').Execute(Context);
    end);

  // Dashboard stats - Injected IDashboardService
  App.MapGet<IDashboardService, IResult>('/dashboard/stats',
    function(Service: IDashboardService): IResult
    begin
      var Stats := Service.GetStats;
      
      var Html := Format(HTML_DASHBOARD_STATS, [Stats.TotalCustomers, Stats.TotalSales]);
      Result := Results.Html(Html);
    end);

  // Dashboard chart data - Using real customer data
  App.MapGet<IDashboardService, IResult>('/dashboard/chart',
    function(Service: IDashboardService): IResult
    begin
      Result := Results.Json(Service.GetChartDataJson);
    end);
end;

end.
