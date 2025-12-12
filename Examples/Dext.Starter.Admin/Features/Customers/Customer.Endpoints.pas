unit Customer.Endpoints;

interface

uses
  Dext,
  Dext.Web,
  Dext.Collections,
  Dext.Persistence,
  DbContext,
  Customer,
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.NetEncoding;

type
  TCustomerEndpoints = class
  public
    class procedure Map(App: IApplicationBuilder);
  private
    class function GenerateCustomerRow(const C: TCustomer): string;
    class function GenerateCustomerForm(const C: TCustomer): string;
    class function CheckAuth(Context: IHttpContext): Boolean;
  end;

implementation

{ TCustomerEndpoints }

class function TCustomerEndpoints.CheckAuth(Context: IHttpContext): Boolean;
begin
  Result := (Context.User <> nil) and 
            (Context.User.Identity <> nil) and 
            (Context.User.Identity.IsAuthenticated);
            
  if not Result then
    Context.Response.StatusCode := 401;
end;

class function TCustomerEndpoints.GenerateCustomerRow(const C: TCustomer): string;
begin
  Result := Format(
    '<tr id="customer-row-%d">' +
    '  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">%d</td>' +
    '  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-medium">%s</td>' +
    '  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">%s</td>' +
    '  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">%m</td>' +
    '  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">' +
    '    <div class="flex items-center justify-end space-x-2">' +
    '      <button hx-get="/customers/%d/form" hx-target="#modal-container" ' +
    '              class="text-indigo-600 hover:text-indigo-900" title="Edit">' +
    '        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">' +
    '          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' +
    '                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>' +
    '        </svg>' +
    '      </button>' +
    '      <button hx-delete="/customers/%d" hx-confirm="Delete this customer?" ' +
    '              hx-target="closest tr" hx-swap="outerHTML" ' +
    '              class="text-red-600 hover:text-red-900" title="Delete">' +
    '        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">' +
    '          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' +
    '                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>' +
    '        </svg>' +
    '      </button>' +
    '    </div>' +
    '  </td>' +
    '</tr>',
    [C.Id, C.Id, C.Name, C.Email, C.TotalSpent, C.Id, C.Id]);
end;

class function TCustomerEndpoints.GenerateCustomerForm(const C: TCustomer): string;
var
  IsEdit: Boolean;
  Title, Action, Method, SwapTarget, SwapMode: string;
  NameValue, EmailValue, TotalSpentValue: string;
begin
  IsEdit := C <> nil;
  
  if IsEdit then
  begin
    Title := 'Edit Customer';
    Action := Format('/customers/%d', [C.Id]);
    Method := 'hx-put';
    SwapTarget := Format('#customer-row-%d', [C.Id]);
    SwapMode := 'outerHTML';
    NameValue := C.Name;
    EmailValue := C.Email;
    TotalSpentValue := FloatToStr(C.TotalSpent);
  end
  else
  begin
    Title := 'Add Customer';
    Action := '/customers/';
    Method := 'hx-post';
    SwapTarget := '#customers-table-body';
    SwapMode := 'beforeend';
    NameValue := '';
    EmailValue := '';
    TotalSpentValue := '0.00';
  end;
  
  Result := Format(
    '<div id="modal-backdrop" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">' +
    '  <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">' +
    '    <div class="flex justify-between items-center mb-4">' +
    '      <h3 class="text-lg font-medium text-gray-900">%s</h3>' +
    '      <button onclick="document.getElementById(''modal-container'').innerHTML=''''" ' +
    '              class="text-gray-400 hover:text-gray-500">' +
    '        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">' +
    '          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>' +
    '        </svg>' +
    '      </button>' +
    '    </div>' +
    '    <form %s="%s" hx-target="%s" hx-swap="%s" class="space-y-4">' +
    '      <div>' +
    '        <label for="name" class="block text-sm font-medium text-gray-700">Name</label>' +
    '        <input type="text" name="name" id="name" value="%s" required ' +
    '               class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">' +
    '      </div>' +
    '      <div>' +
    '        <label for="email" class="block text-sm font-medium text-gray-700">Email</label>' +
    '        <input type="email" name="email" id="email" value="%s" required ' +
    '               class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">' +
    '      </div>' +
    '      <div>' +
    '        <label for="totalspent" class="block text-sm font-medium text-gray-700">Total Spent</label>' +
    '        <input type="number" name="totalspent" id="totalspent" value="%s" step="0.01" ' +
    '               class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">' +
    '      </div>' +
    '      <div class="flex justify-end space-x-3 pt-4">' +
    '        <button type="button" onclick="document.getElementById(''modal-container'').innerHTML=''''" ' +
    '                class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>' +
    '        <button type="submit" ' +
    '                class="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700">Save</button>' +
    '      </div>' +
    '    </form>' +
    '  </div>' +
    '</div>',
    [Title, Method, Action, SwapTarget, SwapMode, NameValue, EmailValue, TotalSpentValue]);
end;

class procedure TCustomerEndpoints.Map(App: IApplicationBuilder);
begin
  // GET /customers/ - List all customers
  App.MapGet('/customers/',
    procedure(Context: IHttpContext)
    var
      Db: TAppDbContext;
      Customers: IList<TCustomer>;
      Html: TStringBuilder;
      C: TCustomer;
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      Db := TServiceProviderExtensions.GetRequiredServiceObject<TAppDbContext>(Context.Services);
      Customers := Db.Entities<TCustomer>.List;
      
      Html := TStringBuilder.Create;
      try
        Html.Append('<div class="bg-white rounded-lg shadow overflow-hidden">');
        Html.Append('  <div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">');
        Html.Append('    <h3 class="text-lg font-medium text-gray-900">Customers</h3>');
        Html.Append('    <button hx-get="/customers/form" hx-target="#modal-container" ');
        Html.Append('            class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 flex items-center">');
        Html.Append('      <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">');
        Html.Append('        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>');
        Html.Append('      </svg>');
        Html.Append('      Add Customer');
        Html.Append('    </button>');
        Html.Append('  </div>');
        Html.Append('  <table class="min-w-full divide-y divide-gray-200">');
        Html.Append('    <thead class="bg-gray-50">');
        Html.Append('      <tr>');
        Html.Append('        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">ID</th>');
        Html.Append('        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>');
        Html.Append('        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>');
        Html.Append('        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Spent</th>');
        Html.Append('        <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>');
        Html.Append('      </tr>');
        Html.Append('    </thead>');
        Html.Append('    <tbody class="bg-white divide-y divide-gray-200" id="customers-table-body">');
        
        for C in Customers do
          Html.Append(GenerateCustomerRow(C));
        
        Html.Append('    </tbody>');
        Html.Append('  </table>');
        Html.Append('</div>');
        
        var Res: IResult := TContentResult.Create(Html.ToString, 'text/html');
        Res.Execute(Context);
      finally
        Html.Free;
      end;
    end);

  // GET /customers/form - Return empty form for adding
  App.MapGet('/customers/form',
    procedure(Context: IHttpContext)
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      var Html := GenerateCustomerForm(nil);
      var Res: IResult := TContentResult.Create(Html, 'text/html');
      Res.Execute(Context);
    end);

  // GET /customers/{id}/form - Return form pre-filled for editing
  App.MapGet('/customers/{id}/form',
    procedure(Context: IHttpContext)
    var
      Db: TAppDbContext;
      Id: Integer;
      C: TCustomer;
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      Db := TServiceProviderExtensions.GetRequiredServiceObject<TAppDbContext>(Context.Services);
      Id := StrToIntDef(Context.Request.RouteParams['id'], 0);
      
      if Id > 0 then
      begin
        C := Db.Entities<TCustomer>.Find(Id);
        if C <> nil then
        begin
          var Html := GenerateCustomerForm(C);
          var Res: IResult := TContentResult.Create(Html, 'text/html');
          Res.Execute(Context);
          Exit;
        end;
      end;
      
      Context.Response.StatusCode := 404;
    end);

  // POST /customers/ - Add new customer
  App.MapPost('/customers/',
    procedure(Context: IHttpContext)
    var
      Db: TAppDbContext;
      C: TCustomer;
      Body, Name, Email, TotalSpentStr: string;
      Reader: TStreamReader;
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      Db := TServiceProviderExtensions.GetRequiredServiceObject<TAppDbContext>(Context.Services);
      
      // Read body stream (now populated by Dext from FormParams)
      if Context.Request.Body <> nil then
      begin
        Context.Request.Body.Position := 0;
        Reader := TStreamReader.Create(Context.Request.Body, TEncoding.UTF8, False);
        try
          Body := Reader.ReadToEnd;
        finally
          Reader.Free;
        end;
      end
      else
        Body := '';
      
      // Parse URL-encoded form data
      Name := '';
      Email := '';
      TotalSpentStr := '0';
      
      var Params := Body.Split(['&']);
      for var Param in Params do
      begin
        var Parts := Param.Split(['=']);
        if Length(Parts) = 2 then
        begin
          var Key := TNetEncoding.URL.Decode(Parts[0]);
          var Value := TNetEncoding.URL.Decode(Parts[1]);
          
          if SameText(Key, 'name') then Name := Value
          else if SameText(Key, 'email') then Email := Value
          else if SameText(Key, 'totalspent') then TotalSpentStr := Value;
        end;
      end;
      
      C := TCustomer.Create;
      C.Name := Name;
      C.Email := Email;
      C.TotalSpent := StrToFloatDef(TotalSpentStr, 0);
      C.Status := TCustomerStatus.Active;
      
      Db.Entities<TCustomer>.Add(C);
      Db.SaveChanges;
    
      var Html := GenerateCustomerRow(C);
      var Res: IResult := TContentResult.Create(Html, 'text/html');
      Res.Execute(Context);
      
      // Close modal and show toast
      Context.Response.AddHeader('HX-Trigger', '{"closeModal": true, "showToast": {"message": "Customer added successfully", "type": "success"}}');
    end);

  // PUT /customers/{id} - Update customer
  App.MapPut('/customers/{id}',
    procedure(Context: IHttpContext)
    var
      Db: TAppDbContext;
      Id: Integer;
      C: TCustomer;
      Body: string;
      Reader: TStreamReader;
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      Db := TServiceProviderExtensions.GetRequiredServiceObject<TAppDbContext>(Context.Services);
      Id := StrToIntDef(Context.Request.RouteParams['id'], 0);
      
      if Id > 0 then
      begin
        C := Db.Entities<TCustomer>.Find(Id);
        if C <> nil then
        begin
          // Read body stream (now populated by Dext from FormParams)
          if Context.Request.Body <> nil then
          begin
            Context.Request.Body.Position := 0;
            Reader := TStreamReader.Create(Context.Request.Body, TEncoding.UTF8, False);
            try
              Body := Reader.ReadToEnd;
            finally
              Reader.Free;
            end;
          end
          else
            Body := '';
          
          // Parse URL-encoded form data
          var Params := Body.Split(['&']);
          for var Param in Params do
          begin
            var Parts := Param.Split(['=']);
            if Length(Parts) = 2 then
            begin
              var Key := TNetEncoding.URL.Decode(Parts[0]);
              var Value := TNetEncoding.URL.Decode(Parts[1]);
              
              if SameText(Key, 'name') then C.Name := Value
              else if SameText(Key, 'email') then C.Email := Value
              else if SameText(Key, 'totalspent') then C.TotalSpent := StrToFloatDef(Value, 0);
            end;
          end;
          
          Db.SaveChanges;
          
          var Html := GenerateCustomerRow(C);
          var Res: IResult := TContentResult.Create(Html, 'text/html');
          Res.Execute(Context);
          
          // Close modal and show toast
          Context.Response.AddHeader('HX-Trigger', '{"closeModal": true, "showToast": {"message": "Customer updated successfully", "type": "success"}}');
          Exit;
        end;
      end;
      
      Context.Response.StatusCode := 404;
    end);

  // DELETE /customers/{id} - Delete customer
  App.MapDelete('/customers/{id}',
    procedure(Context: IHttpContext)
    var
      Db: TAppDbContext;
      Id: Integer;
      C: TCustomer;
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      Db := TServiceProviderExtensions.GetRequiredServiceObject<TAppDbContext>(Context.Services);
      Id := StrToIntDef(Context.Request.RouteParams['id'], 0);
      
      if Id > 0 then
      begin
        C := Db.Entities<TCustomer>.Find(Id);
        if C <> nil then
        begin
          Db.Entities<TCustomer>.Remove(C);
          Db.SaveChanges;
          var Res := Results.Ok;
          Res.Execute(Context);
          Exit;
        end;
      end;
      
      var ResErr := Results.NotFound;
      ResErr.Execute(Context);
    end);
end;

end.
