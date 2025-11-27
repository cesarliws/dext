unit Dext.Json.Types;

interface

uses
  System.SysUtils, System.Classes;

type
  TDextJsonNodeType = (jntNull, jntString, jntNumber, jntBoolean, jntObject, jntArray);

  IDextJsonNode = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetNodeType: TDextJsonNodeType;
    function AsString: string;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsDouble: Double;
    function AsBoolean: Boolean;
    function ToJson(Indented: Boolean = False): string;
  end;

  IDextJsonArray = interface;

  IDextJsonObject = interface(IDextJsonNode)
    ['{B1B2C3D4-E5F6-7890-ABCD-EF1234567891}']
    // Getters
    function Contains(const Name: string): Boolean;
    function GetNode(const Name: string): IDextJsonNode;
    function GetString(const Name: string): string;
    function GetInteger(const Name: string): Integer;
    function GetInt64(const Name: string): Int64;
    function GetDouble(const Name: string): Double;
    function GetBoolean(const Name: string): Boolean;
    function GetObject(const Name: string): IDextJsonObject;
    function GetArray(const Name: string): IDextJsonArray;
    
    // Iteration
    function GetCount: Integer;
    function GetName(Index: Integer): string;
    
    // Setters
    procedure SetString(const Name, Value: string);
    procedure SetInteger(const Name: string; Value: Integer);
    procedure SetInt64(const Name: string; Value: Int64);
    procedure SetDouble(const Name: string; Value: Double);
    procedure SetBoolean(const Name: string; Value: Boolean);
    procedure SetObject(const Name: string; Value: IDextJsonObject);
    procedure SetArray(const Name: string; Value: IDextJsonArray);
    procedure SetNull(const Name: string);
  end;

  IDextJsonArray = interface(IDextJsonNode)
    ['{C1B2C3D4-E5F6-7890-ABCD-EF1234567892}']
    function GetCount: NativeInt;
    function GetNode(Index: Integer): IDextJsonNode;
    function GetString(Index: Integer): string;
    function GetInteger(Index: Integer): Integer;
    function GetInt64(Index: Integer): Int64;
    function GetDouble(Index: Integer): Double;
    function GetBoolean(Index: Integer): Boolean;
    function GetObject(Index: Integer): IDextJsonObject;
    function GetArray(Index: Integer): IDextJsonArray;

    procedure Add(const Value: string); overload;
    procedure Add(Value: Integer); overload;
    procedure Add(Value: Int64); overload;
    procedure Add(Value: Double); overload;
    procedure Add(Value: Boolean); overload;
    procedure Add(Value: IDextJsonObject); overload;
    procedure Add(Value: IDextJsonArray); overload;
    procedure AddNull;
  end;

  IDextJsonProvider = interface
    ['{D1B2C3D4-E5F6-7890-ABCD-EF1234567893}']
    function CreateObject: IDextJsonObject;
    function CreateArray: IDextJsonArray;
    function Parse(const Json: string): IDextJsonNode;
  end;

implementation

end.
