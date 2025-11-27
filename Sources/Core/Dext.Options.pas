unit Dext.Options;

interface

uses
  System.SysUtils,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Binder;

type
  /// <summary>
  ///   Used to retrieve configured TOptions instances.
  /// </summary>
  IOptions<T: class> = interface
    ['{A1B2C3D4-E5F6-4789-A1B2-C3D4E5F67899}']
    function GetValue: T;
    property Value: T read GetValue;
  end;

  /// <summary>
  ///   Implementation of IOptions<T>.
  /// </summary>
  TOptions<T: class, constructor> = class(TInterfacedObject, IOptions<T>)
  private
    FValue: T;
  public
    constructor Create(const Value: T);
    destructor Destroy; override;
    function GetValue: T;
  end;

  /// <summary>
  ///   Factory to create IOptions<T> from IConfiguration.
  /// </summary>
  TOptionsFactory = class
  public
    class function Create<T: class, constructor>(Configuration: IConfiguration): IOptions<T>;
  end;

implementation

{ TOptions<T> }

constructor TOptions<T>.Create(const Value: T);
begin
  inherited Create;
  FValue := Value;
end;

destructor TOptions<T>.Destroy;
begin
  FValue.Free;
  inherited;
end;

function TOptions<T>.GetValue: T;
begin
  Result := FValue;
end;

{ TOptionsFactory }

class function TOptionsFactory.Create<T>(Configuration: IConfiguration): IOptions<T>;
var
  Value: T;
begin
  Value := TConfigurationBinder.Bind<T>(Configuration);
  Result := TOptions<T>.Create(Value);
end;

end.
