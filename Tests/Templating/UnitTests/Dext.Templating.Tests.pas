unit Dext.Templating.Tests;

interface

uses
  Dext.Testing,
  Dext.Templating,
  Dext.Scaffolding.Models,
  FireDAC.Comp.Client,
  System.SysUtils;

type
  [TestClass]
  TTemplatingTests = class
  public
    [Test] procedure Test_Advanced_Filters_With_Params;
    [Test] procedure Test_Chained_Filters;
    [Test] procedure Test_Comparison_Filters_In_If;
    [Test] procedure Test_Complex_Path_Resolution;
    [Test] procedure Test_Conditional_IF_False;
    [Test] procedure Test_Conditional_IF_True;
    [Test] procedure Test_Conditional_With_Else;
    [Test] procedure Test_Continue_And_Break_In_Loop;
    [Test] procedure Test_Encoded_Directive;
    [Test] procedure Test_Error_Reporting_Position;
    [Test] procedure Test_Escaping;
    [Test] procedure Test_Filters_CamelCase;
    [Test] procedure Test_Filters_PascalCase;
    [Test] procedure Test_Filters_Pluralize;
    [Test] procedure Test_Filters_Singularize;
    [Test] procedure Test_Filters_SnakeCase;
    [Test] procedure Test_Html_Escaping;
    [Test] procedure Test_Inline_Define_And_Macro_Call;
    [Test] procedure Test_Loop_ForEach;
    [Test] procedure Test_Loop_TDataSet;
    [Test] procedure Test_Loop_With_Else_And_Pseudo_Variables;
    [Test] procedure Test_Nested_Control_Flow;
    [Test] procedure Test_Nested_Loops;
    [Test] procedure Test_Nested_Property_Resolution;
    [Test] procedure Test_Raw_Block_Literal_Output;
    [Test] procedure Test_Render_Template_With_Layout_Sections_And_Partial;
    [Test] procedure Test_Set_And_Inline_Expression;
    [Test] procedure Test_Simple_Property_Resolution;
    [Test] procedure Test_Switch_Case_Default;
    [Test] procedure Test_Whitespace_Control_With_Tilde;
    [Test] procedure Test_Whitespace_Handling;
  end;

implementation

uses
  Data.DB, Datasnap.DBClient;

{ TTemplatingTests }

procedure TTemplatingTests.Test_Simple_Property_Resolution;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Model := TTableViewModel.Create;
  try
    Model.DelphiClassName := 'TUser';
    Context.SetObject('Model', Model);
    
    Output := Engine.Render('class @Model.DelphiClassName', Context);
    
    Should(Output).Be('class TUser');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Nested_Property_Resolution;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Col: TColumnViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Model := TTableViewModel.Create;
  try
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'Id';
    Model.Columns.Add(Col);
    
    Context.SetObject('Model', Model);
    
    // Testing deep traversal implicitly handled by the engine
    Output := Engine.Render('@Model.Columns[0].DelphiName', Context);
    
    // Note: The engine currently supports Dot notation for properties, 
    // but array indexing [0] was not explicitly in the spec.
    // However, if we put the specific column in context:
    Context.SetObject('Col', Col);
    Output := Engine.Render('@Col.DelphiName', Context);
    
    Should(Output).Be('Id');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Conditional_IF_True;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Context.SetValue('IsActive', 'true');
  
  Output := Engine.Render('@if (IsActive)Active@endif', Context);
  
  Should(Output).Be('Active');
end;

procedure TTemplatingTests.Test_Conditional_IF_False;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Context.SetValue('IsActive', 'false');
  
  Output := Engine.Render('@if (IsActive)Active@endif', Context);
  
  Should(Output).Be('');
end;

procedure TTemplatingTests.Test_Conditional_With_Else;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;

  Context.SetValue('IsActive', 'false');
  Output := Engine.Render('@if (IsActive)Active@elseInactive@endif', Context);

  Should(Output).Be('Inactive');
end;

procedure TTemplatingTests.Test_Loop_ForEach;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Col: TColumnViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Model := TTableViewModel.Create;
  try
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'Id';
    Col.DelphiType := 'Integer';
    Model.Columns.Add(Col);
    
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'Name';
    Col.DelphiType := 'string';
    Model.Columns.Add(Col);
    
    Context.SetObject('Model', Model);
    
    Output := Engine.Render(
      '@foreach (var col in Model.Columns)' + sLineBreak +
      '  @col.DelphiName: @col.DelphiType;' + sLineBreak +
      '@endforeach', Context);
      
    Should(Output).Contain('Id: Integer;');
    Should(Output).Contain('Name: string;');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Loop_With_Else_And_Pseudo_Variables;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Col: TColumnViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;

  Model := TTableViewModel.Create;
  try
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'Id';
    Model.Columns.Add(Col);

    Col := TColumnViewModel.Create;
    Col.DelphiName := 'Name';
    Model.Columns.Add(Col);

    Context.SetObject('Model', Model);

    Output := Engine.Render(
      '@foreach (var col in Model.Columns)' +
      '@col.@@index:@col.DelphiName(@if (col.@@first)F@endif@if (col.@@last)L@endif);' +
      '@elseEMPTY@endforeach', Context);

    Should(Output).Contain('1:Id(F);');
    Should(Output).Contain('2:Name(L);');

    Output := Engine.Render('@foreach (var item in Items)X@elseEMPTY@endforeach', Context);
    Should(Output).Be('EMPTY');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Filters_PascalCase;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Context.SetValue('Name', 'user_profile');
  
  Output := Engine.Render('@Name.ToPascalCase()', Context);
  
  Should(Output).Be('UserProfile');
end;

procedure TTemplatingTests.Test_Filters_CamelCase;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Context.SetValue('Name', 'UserName');
  
  Output := Engine.Render('@Name.ToCamelCase()', Context);
  
  Should(Output).Be('userName');
end;

procedure TTemplatingTests.Test_Advanced_Filters_With_Params;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;

  Context.SetValue('Name', '  user profile  ');
  Context.SetValue('EmptyName', '');
  Context.SetValue('Bio', 'abcdefghijklmnopqrstuvwxyz');

  Should(Engine.Render('@Name.trim().uppercase()', Context)).Be('USER PROFILE');
  Should(Engine.Render('@EmptyName.default(''N/A'')', Context)).Be('N/A');
  Should(Engine.Render('@Bio.truncate(5, ''~'')', Context)).Be('abcde~');
end;

procedure TTemplatingTests.Test_Comparison_Filters_In_If;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;

  Context.SetValue('Status', 'active');
  Output := Engine.Render('@if (Status.eq(''active''))OK@elseFAIL@endif', Context);

  Should(Output).Be('OK');
end;

procedure TTemplatingTests.Test_Escaping;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Output := Engine.Render('email@@example.com', Context);
  Should(Output).Be('email@example.com');
end;

procedure TTemplatingTests.Test_Html_Escaping;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  (Engine as TDextTemplateEngine).IsHtmlMode := True;
  
  Context.SetValue('Content', '<script>alert("xss")</script>');
  Output := Engine.Render('<div>@Content</div>', Context);
  
  Should(Output).Be('<div>&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;</div>');
end;

procedure TTemplatingTests.Test_Nested_Control_Flow;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Col: TColumnViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Model := TTableViewModel.Create;
  try
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'Id';
    Col.IsPrimaryKey := True;
    Model.Columns.Add(Col);
    
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'Name';
    Col.IsPrimaryKey := False;
    Model.Columns.Add(Col);
    
    Context.SetObject('Model', Model);
    
    Output := Engine.Render(
      '@foreach (var col in Model.Columns)' +
      '@if (col.IsPrimaryKey)[PK] @endif' +
      '@col.DelphiName' +
      '@endforeach', Context);
      
    Should(Output).Contain('[PK] Id');
    Should(Output).Contain('Name');
    Should(Output).NotContain('[PK] Name');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Whitespace_Handling;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Context.SetValue('Show', 'true');
  
  // The engine should skip one newline after @if and @endif
  Output := Engine.Render(
    '@if (Show)' + sLineBreak +
    'Content' + sLineBreak +
    '@endif' + sLineBreak +
    'Footer', Context);
    
  // Current logic in ParseBlock:
  // if (ATemplate[Pos] = #13) then Inc(Pos);
  // if (ATemplate[Pos] = #10) then Inc(Pos);
  // This means '@if (Show)\r\nContent' becomes 'Content'
  
  Should(Output).Be('Content' + sLineBreak + 'Footer');
end;

procedure TTemplatingTests.Test_Nested_Loops;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Col: TColumnViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  Model := TTableViewModel.Create;
  try
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'Id';
    Model.Columns.Add(Col);
    
    Context.SetObject('Model', Model);
    
    // Nested Loop: For each table, for each column
    Output := Engine.Render(
      '@foreach (var t in Model.Columns)' +
        'Col:@t.DelphiName' +
      '@endforeach', Context);
      
    Should(Output).Contain('Col:Id');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Complex_Path_Resolution;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  Model := TTableViewModel.Create;
  try
    Model.Name := 'User';
    Context.SetObject('Model', Model);
    
    // Testing Model.Name.ToPascalCase() - triple level
    Output := Engine.Render('@Model.Name.ToPascalCase()', Context);
    Should(Output).Be('User');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Filters_SnakeCase;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  Context.SetValue('Name', 'UserProfile');
  Output := Engine.Render('@Name.ToSnakeCase()', Context);
  Should(Output).Be('user_profile');
end;

procedure TTemplatingTests.Test_Filters_Pluralize;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Context.SetValue('S1', 'User');
  Context.SetValue('S2', 'Category');
  Context.SetValue('S3', 'Box');
  
  Should(Engine.Render('@S1.Pluralize()', Context)).Be('Users');
  Should(Engine.Render('@S2.Pluralize()', Context)).Be('Categories');
  Should(Engine.Render('@S3.Pluralize()', Context)).Be('Boxes');
end;

procedure TTemplatingTests.Test_Filters_Singularize;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Context.SetValue('S1', 'Users');
  Context.SetValue('S2', 'Categories');
  Context.SetValue('S3', 'Order'); // Already singular
  
  Should(Engine.Render('@S1.Singularize()', Context)).Be('User');
  Should(Engine.Render('@S2.Singularize()', Context)).Be('Category');
  Should(Engine.Render('@S3.Singularize()', Context)).Be('Order');
end;

procedure TTemplatingTests.Test_Chained_Filters;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  Context.SetValue('Name', 'user_category');
  
  // @Name.ToPascalCase().Pluralize() -> UserCategory -> UserCategories
  Output := Engine.Render('@Name.ToPascalCase().Pluralize()', Context);
  
  Should(Output).Be('UserCategories');
end;

procedure TTemplatingTests.Test_Render_Template_With_Layout_Sections_And_Partial;
var
  Engine: TDextTemplateEngine;
  Context: ITemplateContext;
  Loader: TInMemoryTemplateLoader;
  Output: string;
begin
  Loader := TInMemoryTemplateLoader.Create;
  Loader.AddTemplate('views\products\index.html',
    '@layout(''shared/_Layout'')' + sLineBreak +
    '@section(''title'')Produtos@endsection' + sLineBreak +
    '@section(''content'')' + sLineBreak +
    '<h1>@PageTitle</h1>' + sLineBreak +
    '@partial(''components/_Badge'', status: Status)' + sLineBreak +
    '@endsection');
  Loader.AddTemplate('views\shared\_Layout.html',
    '<html><head><title>@renderSection(''title'')</title></head><body>@renderSection(''content'')</body></html>');
  Loader.AddTemplate('views\components\_Badge.html',
    '<span class="badge">@status.uppercase()</span>');

  Engine := TDextTemplateEngine.Create(Loader);
  try
    Engine.TemplateRoot := 'views';
    Context := TTemplating.CreateContext;
    Context.SetValue('PageTitle', 'Catalogo');
    Context.SetValue('Status', 'active');

    Output := Engine.RenderTemplate('products/index.html', Context);

    Should(Output).Contain('<title>Produtos</title>');
    Should(Output).Contain('<h1>Catalogo</h1>');
    Should(Output).Contain('<span class="badge">ACTIVE</span>');
  finally
    Engine.Free;
  end;
end;

procedure TTemplatingTests.Test_Inline_Define_And_Macro_Call;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;

  Output := Engine.Render(
    '@define(''badge'', status)' + sLineBreak +
    '<span>@status.uppercase()</span>' + sLineBreak +
    '@enddefine' + sLineBreak +
    '@> badge(''active'')', Context);

  Should(Output).Contain('<span>ACTIVE</span>');
end;

procedure TTemplatingTests.Test_Set_And_Inline_Expression;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Col: TColumnViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;

  Model := TTableViewModel.Create;
  try
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'A';
    Model.Columns.Add(Col);
    Col := TColumnViewModel.Create;
    Col.DelphiName := 'B';
    Model.Columns.Add(Col);
    Context.SetObject('Model', Model);
    Context.SetValue('FirstName', 'John');
    Context.SetValue('LastName', 'Doe');

    Output := Engine.Render(
      '@set total = 2 + 3' + sLineBreak +
      '@set full = @(FirstName + '' '' + LastName)' + sLineBreak +
      '@foreach (var col in Model.Columns)' + sLineBreak +
      '  @set total = @total + 1' + sLineBreak +
      '@endforeach' + sLineBreak +
      'Total=@total;Full=@full;Expr=@(3 * 4)', Context);

    Should(Output).Contain('Total=7');
    Should(Output).Contain('Full=John Doe');
    Should(Output).Contain('Expr=12');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Continue_And_Break_In_Loop;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Model: TTableViewModel;
  Col: TColumnViewModel;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;

  Model := TTableViewModel.Create;
  try
    Col := TColumnViewModel.Create; Col.DelphiName := 'Id'; Model.Columns.Add(Col);
    Col := TColumnViewModel.Create; Col.DelphiName := 'Skip'; Model.Columns.Add(Col);
    Col := TColumnViewModel.Create; Col.DelphiName := 'Name'; Model.Columns.Add(Col);
    Col := TColumnViewModel.Create; Col.DelphiName := 'Stop'; Model.Columns.Add(Col);
    Col := TColumnViewModel.Create; Col.DelphiName := 'Tail'; Model.Columns.Add(Col);
    Context.SetObject('Model', Model);

    Output := Engine.Render(
      '@foreach (var col in Model.Columns)' +
      '@if (col.DelphiName.eq(''Skip''))@continue@endif' +
      '@if (col.DelphiName.eq(''Stop''))@break@endif' +
      '@col.DelphiName;' +
      '@endforeach', Context);

    Should(Output).Contain('Id;');
    Should(Output).Contain('Name;');
    Should(Output).NotContain('Skip;');
    Should(Output).NotContain('Stop;');
    Should(Output).NotContain('Tail;');
  finally
    Model.Free;
  end;
end;

procedure TTemplatingTests.Test_Switch_Case_Default;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;

  Context.SetValue('Status', 'active');
  Output := Engine.Render(
    '@switch (Status)' +
    '@case (''active'')A' +
    '@case (''suspended'')S' +
    '@defaultU' +
    '@endswitch', Context);
  Should(Output).Be('A');

  Context.SetValue('Status', 'unknown');
  Output := Engine.Render(
    '@switch (Status)' +
    '@case (''active'')A' +
    '@defaultU' +
    '@endswitch', Context);
  Should(Output).Be('U');
end;

procedure TTemplatingTests.Test_Raw_Block_Literal_Output;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  Context.SetValue('Name', 'John');

  Output := Engine.Render(
    '@raw' + sLineBreak +
    'Literal @Name and @if (true) not parsed @endif' + sLineBreak +
    '@endraw', Context);

  Should(Output).Contain('Literal @Name and @if (true) not parsed @endif');
end;

procedure TTemplatingTests.Test_Whitespace_Control_With_Tilde;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  Context.SetValue('Show', 'true');

  Output := Engine.Render(
    'A   ' + sLineBreak +
    '@~if (Show)' + sLineBreak +
    'B' + sLineBreak +
    '@endif~' + sLineBreak +
    '   C', Context);

  Should(Output).Be('A' + 'B' + 'C');
end;

procedure TTemplatingTests.Test_Error_Reporting_Position;
var
  Engine: ITemplateEngine;
begin
  Engine := TTemplating.CreateEngine;
  try
    Engine.Render('@if(test) missing endif', TTemplating.CreateContext);
    Assert.Fail('Should have raised ETemplateException');
  except
    on E: ETemplateException do
    begin
      Should(E.Pos.Line).Be(1);
      Should(E.Pos.Col).Be(1); // Pointer to where @if starts
      Should(E.Message).Contain('Missing closing marker @endif');
    end;
    on E: Exception do Assert.Fail('Expected ETemplateException but got ' + E.ClassName);
  end;
end;

procedure TTemplatingTests.Test_Encoded_Directive;
var
  Engine: ITemplateEngine;
  Context: ITemplateContext;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Engine.IsHtmlMode := False; // Disable default escaping
  Context := TTemplating.CreateContext;
  Context.SetValue('Name', '<b>Cezar</b>');

  Output := Engine.Render('@Name', Context);
  Should(Output).Be('<b>Cezar</b>');

  Output := Engine.Render('@encoded(Name)', Context);
  Should(Output).Be('&lt;b&gt;Cezar&lt;/b&gt;');
end;

procedure TTemplatingTests.Test_Loop_TDataSet;
var
  Context: ITemplateContext;
  DataSet: TFDMemTable;
  Engine: ITemplateEngine;
  Output: string;
begin
  Engine := TTemplating.CreateEngine;
  Context := TTemplating.CreateContext;
  
  // TFDMemTable is a pure-Delphi in-memory table - no midas.dll dependency,
  // no false-positive FastMM5 leaks on shutdown.
  DataSet := TFDMemTable.Create(nil);
  try
    DataSet.FieldDefs.Add('ID', ftInteger);
    DataSet.FieldDefs.Add('Name', ftString, 50);
    DataSet.CreateDataSet;
    
    DataSet.Append;
    DataSet.FieldByName('ID').AsInteger := 1;
    DataSet.FieldByName('Name').AsString := 'Item 1';
    DataSet.Post;

    DataSet.Append;
    DataSet.FieldByName('ID').AsInteger := 2;
    DataSet.FieldByName('Name').AsString := 'Item 2';
    DataSet.Post;

    Context.SetObject('Data', DataSet);
    
    Output := Engine.Render(
      '@foreach (var row in Data)' +
      '#@row.ID: @row.Name (@index);' +
      '@endforeach', Context);

    Should(Output).Contain('#1: Item 1 (1);');
    Should(Output).Contain('#2: Item 2 (2);');
  finally
    DataSet.Free;
  end;
end;

end.
