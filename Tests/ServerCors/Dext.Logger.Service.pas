unit Dext.Logger.Service;

interface

type
  ILogger = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    procedure Log(const AMessage: string);
  end;

  TConsoleLogger = class(TInterfacedObject, ILogger)
  public
    constructor Create;
    destructor Destroy; override;
    procedure Log(const AMessage: string);
  end;

implementation

constructor TConsoleLogger.Create;
begin
  inherited;
   Writeln('TConsoleLogger.Create');
end;

destructor TConsoleLogger.Destroy;
begin
   Writeln('TConsoleLogger.Destroy');
  inherited;
end;

procedure TConsoleLogger.Log(const AMessage: string);
begin
  Writeln('LOG: ', AMessage);
end;

end.
