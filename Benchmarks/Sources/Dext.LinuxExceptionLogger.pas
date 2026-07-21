unit Dext.LinuxExceptionLogger;

interface

implementation

uses
  System.SysUtils;

procedure LinuxExceptObjProc(Obj: TObject; Addr: Pointer);
begin
  if Obj is Exception then
  begin
    Writeln(
      ErrOutput,
      'Fatal Unhandled Exception: ' + Exception(Obj).ClassName +
      ': ' + Exception(Obj).Message);
  end;
  // Terminate execution
  Halt(1);
end;

initialization
  System.ExceptProc := @LinuxExceptObjProc;

end.
