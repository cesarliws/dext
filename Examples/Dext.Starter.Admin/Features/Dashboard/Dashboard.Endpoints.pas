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
  AppResponseConsts;

{ TDashboardEndpoints }

class procedure TDashboardEndpoints.Map(App: TDextAppBuilder);
begin
  // Root path
  App.MapGet('/',
    procedure(Context: IHttpContext)
    begin
      // Uses Admin.Utils.GetFilePath
      var Res: IResult := TContentResult.Create(TFile.ReadAllText(GetFilePath('wwwroot\index.html')), 'text/html');
      Res.Execute(Context);
    end);

  // Dashboard fragment
  App.MapGet('/dashboard',
    procedure(Context: IHttpContext)
    begin
      var Res: IResult := TContentResult.Create(TFile.ReadAllText(GetFilePath('wwwroot\views\dashboard_fragment.html')), 'text/html');
      Res.Execute(Context);
    end);

  // Dashboard stats - Injected TAppDbContext
  App.MapGet<TAppDbContext, IHttpContext>('/dashboard/stats',
    procedure(Db: TAppDbContext; Context: IHttpContext)
    begin
      var TotalCustomers := Db.Entities<TCustomer>.List.Count; 
      
      var Orders := Db.Entities<TOrder>.List;
      var TotalSales: Currency := 0;
      for var O in Orders do
        TotalSales := TotalSales + O.Total;
        
      var Html := Format(HTML_DASHBOARD_STATS, [TotalCustomers, TotalSales]);

      var Res: IResult := TContentResult.Create(Html, 'text/html');
      Res.Execute(Context);
    end);

  // Dashboard chart data
  App.MapGet('/dashboard/chart',
    procedure(Context: IHttpContext)
    begin
      var Res := Results.Json(JSON_DASHBOARD_CHART);
      Res.Execute(Context);
    end);
end;

end.
