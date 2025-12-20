program TestUtf8Serializer;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext.Core.Span in '..\..\Sources\Core\Base\Dext.Core.Span.pas',
  Dext.Json.Utf8 in '..\..\Sources\Core\Json\Dext.Json.Utf8.pas',
  Dext.Json.Utf8.Serializer in '..\..\Sources\Core\Json\Dext.Json.Utf8.Serializer.pas';

type
  TSimpleRecord = record
    Id: Integer;
    Name: string;
    Price: Double;
    Active: Boolean;
  end;

procedure TestSimpleRecord;
var
  Json: string;
  Bytes: TBytes;
  Rec: TSimpleRecord;
begin
  Writeln('Testing Simple Record Deserialization...');
  Json := '{ "Id": 101, "Name": "Product A", "Price": 12.50, "Active": true }';
  Bytes := TEncoding.UTF8.GetBytes(Json);
  
  Rec := TUtf8JsonSerializer.Deserialize<TSimpleRecord>(TByteSpan.FromBytes(Bytes));
  
  Assert(Rec.Id = 101);
  Assert(Rec.Name = 'Product A');
  Assert(Abs(Rec.Price - 12.50) < 0.001);
  Assert(Rec.Active = True);
  
  Writeln('  Id: ', Rec.Id);
  Writeln('  Name: ', Rec.Name);
  Writeln('Simple OK.');
end;

begin
  try
    TestSimpleRecord;
    Writeln('ALL TESTS PASSED');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  Readln;
end.
