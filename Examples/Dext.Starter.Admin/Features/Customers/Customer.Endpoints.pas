unit Customer.Endpoints;

interface

uses
  Dext,
  Dext.Web,
  Dext.Collections,
  Dext.Persistence,
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
  Result := Format(
    '<tr id="customer-%d">' +
    '<td>%d</td>' +
    '<td>%s</td>' +
    '<td>%s</td>' +
    '<td>%m</td>' +
    '<td>' +
    '  <button class="btn btn-sm btn-primary" hx-get="/customers/%d/form" hx-target="#modal-content" hx-trigger="click" _="on click call showModal()">Edit</button>' +
    '  <button class="btn btn-sm btn-danger" hx-delete="/customers/%d" hx-target="#customer-%d" hx-swap="outerHTML" hx-confirm="Are you sure?">Delete</button>' +
    '</td>' +
    '</tr>',
    [C.Id, C.Id, C.Name, C.Email, C.TotalSpent, C.Id, C.Id, C.Id]);
end;

function GenerateCustomerForm(C: TCustomer): string;
var
  Method, Url, Title, Name, Email, Total, IdVal: string;
begin
  if Assigned(C) then
  begin
    Title := 'Edit Customer';
    Url := '/customers/' + IntToStr(C.Id);
    Method := 'hx-put';
    IdVal := IntToStr(C.Id);
    Name := C.Name;
    Email := C.Email;
    Total := FloatToStr(C.TotalSpent);
  end
  else
  begin
    Title := 'New Customer';
    Url := '/customers/';
    Method := 'hx-post';
    IdVal := '0';
    Name := '';
    Email := '';
    Total := '0';
  end;

  Result := Format(
    '<div class="p-4">' +
    '<h3>%s</h3>' +
    '<form %s="%s" hx-target="#customer-%s" hx-swap="outerHTML">' + // Default swap for PUT. For POST, we might override in the response handling or target list
    '<input type="hidden" name="id" value="%s">' +
    '<div class="mb-3"><label>Name</label><input type="text" name="Name" class="form-control" value="%s" required></div>' +
    '<div class="mb-3"><label>Email</label><input type="email" name="Email" class="form-control" value="%s" required></div>' +
    '<div class="mb-3"><label>Total Spent</label><input type="number" name="TotalSpent" class="form-control" value="%s"></div>' +
    '<div class="d-flex justify-content-end gap-2">' +
    '  <button type="button" class="btn btn-secondary" _="on click call closeModal()">Cancel</button>' +
    '  <button type="submit" class="btn btn-primary">Save</button>' +
    '</div>' +
    '</form></div>',
    [Title, Method, Url, IdVal, IdVal, Name, Email, Total]
  );
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
    begin
      if Dto.Id > 0 then
      begin
        C := Service.GetById(Dto.Id);
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
