unit Customer.Endpoints;

interface

uses
  Dext,
  Dext.Web,
  Dext.Collections,
  Dext.Persistence,
  Dext.Json,
  Customer,
  Customer.Dto,
  Admin.Utils,
  Dext.Web.Results, // Added
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.NetEncoding;

// ... (Interface unchanged) -> This was the error. I must provide the TYPE block.
type
  TCustomerEndpoints = class
  public
    class procedure Map(App: TDextAppBuilder);
  end;

implementation

uses
  AppResponseConsts,
  Customer.Service;

// Helper Functions
function GenerateCustomerRow(C: TCustomer): string;
begin
  // Uses HTML_CUSTOMER_ROW from AppResponseConsts
  // Format: Id, Id, Name, Email, TotalSpent, IdEditButton, IdDeleteButton
  Result := Format(HTML_CUSTOMER_ROW,
    [C.Id, C.Id, C.Name, C.Email, C.TotalSpent, C.Id, C.Id]);
end;

function GenerateCustomerForm(C: TCustomer): string;
var
  Method, Url, Title, HxTarget, HxSwap, Name, Email, Total: string;
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  
  if Assigned(C) then
  begin
    Title := 'Edit Customer';
    Method := 'hx-put';
    Url := '/customers/' + IntToStr(C.Id);
    HxTarget := '#customer-row-' + IntToStr(C.Id);
    HxSwap := 'outerHTML';
    Name := C.Name;
    Email := C.Email;
    Total := FormatFloat('0.00', C.TotalSpent, FS);
  end
  else
  begin
    Title := 'New Customer';
    Method := 'hx-post';
    Url := '/customers/';
    HxTarget := '#customers-table-body';
    HxSwap := 'beforeend';
    Name := '';
    Email := '';
    Total := '0';
  end;

  // Uses HTML_CUSTOMER_FORM from AppResponseConsts
  // Format: Title, Method, Url, HxTarget, HxSwap, Name, Email, TotalSpent
  Result := Format(HTML_CUSTOMER_FORM,
    [Title, Method, Url, HxTarget, HxSwap, Name, Email, Total]);
end;

{ TCustomerEndpoints }

class procedure TCustomerEndpoints.Map(App: TDextAppBuilder);
begin
  // GET /customers/ - List all customers
  App.MapGet<ICustomerService, IHttpContext, IResult>('/customers/',
    function(Service: ICustomerService; Context: IHttpContext): IResult
    var
      Customers: IList<TCustomer>;
      Html: TStringBuilder;
      C: TCustomer;
    begin
      Customers := Service.GetAll;
      
      Html := TStringBuilder.Create;
      try
        Html.Append(HTML_CUSTOMER_LIST_HEADER);
        for C in Customers do
          Html.Append(GenerateCustomerRow(C));
        Html.Append(HTML_CUSTOMER_LIST_FOOTER);
        
        Result := Results.Html(Html.ToString);
      finally
        Html.Free;
      end;
    end);

  // GET /customers/form
  App.MapGet<IHttpContext, IResult>('/customers/form',
    function(Context: IHttpContext): IResult
    begin
      Result := Results.Html(GenerateCustomerForm(nil));
    end);

  // GET /customers/{id}/form
  App.MapGet<ICustomerService, Integer, IHttpContext, IResult>('/customers/{id}/form',
    function(Service: ICustomerService; Id: Integer; Context: IHttpContext): IResult
    var
      C: TCustomer;
    begin
      if Id > 0 then
      begin
        C := Service.GetById(Id);
        if C <> nil then
          Exit(Results.Html(GenerateCustomerForm(C)));
      end;
      
      Result := Results.NotFound;
    end);

  // POST /customers/ - Add new customer
  App.MapPost<ICustomerService, TCustomerDto, IHttpContext, IResult>('/customers/',
    function(Service: ICustomerService; Dto: TCustomerDto; Context: IHttpContext): IResult
    var
      C: TCustomer;
    begin
      if (Dto.Name.Trim.IsEmpty) or (Dto.Email.Trim.IsEmpty) then
        Exit(Results.BadRequest);

      C := TCustomer.Create;
      C.Name := Dto.Name;
      C.Email := Dto.Email;
      C.TotalSpent := Dto.TotalSpent;
      C.Status := TCustomerStatus.Active;
      
      Service.Add(C);
    
      Context.Response.AddHeader('HX-Trigger', '{"closeModal": true, "showToast": {"message": "Customer added successfully", "type": "success"}}');
      Result := Results.Html(GenerateCustomerRow(C));
    end);

  // PUT /customers/{id}
  App.MapPut<ICustomerService, TCustomerDto, IHttpContext, IResult>('/customers/{id}',
    function(Service: ICustomerService; Dto: TCustomerDto; Context: IHttpContext): IResult
    var
      C: TCustomer;
      Id: Integer;
    begin
      // Get ID from route params, not DTO
      Id := StrToIntDef(Context.Request.RouteParams['id'], 0);
      
      if Id > 0 then
      begin
        C := Service.GetById(Id);
        if C <> nil then
        begin
          C.Name := Dto.Name;
          C.Email := Dto.Email;
          C.TotalSpent := Dto.TotalSpent;
          
          Service.Update(C);
          
          Context.Response.AddHeader('HX-Trigger', '{"closeModal": true, "showToast": {"message": "Customer updated successfully", "type": "success"}}');
          Exit(Results.Html(GenerateCustomerRow(C)));
        end;
      end;
      Result := Results.NotFound;
    end);

  // DELETE /customers/{id}
  App.MapDelete<ICustomerService, IHttpContext, IResult>('/customers/{id}',
    function(Service: ICustomerService; Context: IHttpContext): IResult
    var
      Id: Integer;
    begin
      Id := StrToIntDef(Context.Request.RouteParams['id'], 0);
      
      if Id > 0 then
      begin
          var C := Service.GetById(Id);
          if C <> nil then
          begin
             Service.Delete(Id);
             Exit(Results.Ok);
          end;
      end;
      
      Result := Results.NotFound;
    end);
end;

end.
