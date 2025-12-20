program TestUtf8Json;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  Dext.Core.Span in '..\..\Sources\Core\Base\Dext.Core.Span.pas',
  Dext.Json.Utf8 in '..\..\Sources\Core\Json\Dext.Json.Utf8.pas';

procedure Log(const Msg: string);
begin
  Writeln(Msg);
end;

procedure TestPrimitives;
var
  Json: string;
  Bytes: TBytes;
  Reader: TUtf8JsonReader;
begin
  Log('Testing Primitives...');
  Json := ' [ 123 , -456.78, true, false, null ] ';
  Bytes := TEncoding.UTF8.GetBytes(Json);
  
  Reader := TUtf8JsonReader.Create(TByteSpan.FromBytes(Bytes));
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.StartArray);
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.Number);
  Assert(Reader.GetInt32 = 123);
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.Number);
  // Assert(Abs(Reader.GetDouble + 456.78) < 0.001); // float comparison
  Log('  Float: ' + FloatToStr(Reader.GetDouble));
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.TrueValue);
  Assert(Reader.GetBoolean = True);
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.FalseValue);
  Assert(Reader.GetBoolean = False);

  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.NullValue);

  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.EndArray);
  
  Assert(not Reader.Read); // EOF
  Log('Primitives OK.');
end;

procedure TestObjectNavigation;
var
  Json: string;
  Bytes: TBytes;
  Reader: TUtf8JsonReader;
begin
  Log('Testing Object Navigation...');
  Json := '{ "name": "Dext", "id": 99 }';
  Bytes := TEncoding.UTF8.GetBytes(Json);
  
  Reader := TUtf8JsonReader.Create(TByteSpan.FromBytes(Bytes));
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.StartObject);
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.PropertyName);
  Assert(Reader.ValueSpanEquals('name'));
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.StringValue);
  Assert(Reader.GetString = 'Dext');
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.PropertyName);
  Assert(Reader.ValueSpanEquals('id'));
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.Number);
  Assert(Reader.GetInt32 = 99);
  
  Assert(Reader.Read);
  Assert(Reader.TokenType = TJsonTokenType.EndObject);
  
  Log('Object Navigation OK.');
end;

procedure TestSkip;
var
  Json: string;
  Bytes: TBytes;
  Reader: TUtf8JsonReader;
begin
  Log('Testing Skip...');
  Json := '{"skip_me": [1, 2, { "nest": 3 }], "keep_me": "yes"}';
  Bytes := TEncoding.UTF8.GetBytes(Json);
  
  Reader := TUtf8JsonReader.Create(TByteSpan.FromBytes(Bytes));
  
  Reader.Read; // {
  Reader.Read; // "skip_me"
  Reader.Read; // [ ...
  
  Assert(Reader.TokenType = TJsonTokenType.StartArray);
  Reader.Skip;
  
  Assert(Reader.TokenType = TJsonTokenType.EndArray);
  
  Reader.Read; // "keep_me"
  Assert(Reader.TokenType = TJsonTokenType.PropertyName);
  Assert(Reader.ValueSpanEquals('keep_me'));
  
  Log('Skip OK.');
end;

begin
  try
    TestPrimitives;
    TestObjectNavigation;
    TestSkip;
    Writeln('ALL TESTS PASSED');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  Readln;
end.
