unit Admin.Utils;

interface

uses
  System.SysUtils,
  System.IOUtils;

function GetFilePath(const RelativePath: string): string;

implementation

// function GetFilePath(const RelativePath: string): string;
function GetFilePath(const RelativePath: string): string;
var
  AppDir: string;
  BaseDir: string;
  I: Integer;
  Candidate: string;
begin
  AppDir := ExtractFilePath(ParamStr(0));
  
  // Strategy: Climb up looking for 'Dext.Starter.Admin' folder
  BaseDir := AppDir;
  for I := 0 to 5 do
  begin
    // Check if Dext.Starter.Admin exists in current BaseDir
    Candidate := IncludeTrailingPathDelimiter(BaseDir) + 'Dext.Starter.Admin';
    if DirectoryExists(Candidate) then
    begin
       Result := IncludeTrailingPathDelimiter(Candidate) + RelativePath;
       Exit;
    end;
    
    // Also check if we ARE inside Dext.Starter.Admin already (e.g. running from source root)
    if DirectoryExists(IncludeTrailingPathDelimiter(BaseDir) + 'wwwroot') then
    begin
       Result := IncludeTrailingPathDelimiter(BaseDir) + RelativePath;
       Exit;
    end;

    // Move up
    BaseDir := BaseDir + '..\';
  end;

  // Fallback: Just append to AppDir if not found (will likely fail but shows intention)
  Result := IncludeTrailingPathDelimiter(AppDir) + RelativePath;
end;

end.
