unit Admin.Utils;

interface

uses
  System.SysUtils,
  System.IOUtils;

function GetFilePath(const RelativePath: string): string;

implementation

function GetFilePath(const RelativePath: string): string;
var
  AppDir: string;
  SearchDir: string;
  TargetPath: string;
  CandidatePath: string;
  I: Integer;
begin
  AppDir := ExtractFilePath(ParamStr(0));
  AppDir := ExpandFileName(AppDir);
  
  // Estratégia: Subir até encontrar 'Dext.Starter.Admin'  
  SearchDir := AppDir;
  for I := 0 to 5 do
  begin
    // Verifica se existe Dext.Starter.Admin neste nível
    TargetPath := TPath.Combine(SearchDir, 'Dext.Starter.Admin');
    if TDirectory.Exists(TargetPath) then
    begin
      CandidatePath := TPath.Combine(TargetPath, RelativePath);
      // Verificar se o arquivo/diretório existe antes de retornar
      if TFile.Exists(CandidatePath) or TDirectory.Exists(TPath.GetDirectoryName(CandidatePath)) then
      begin
        Result := CandidatePath;
        Exit;
      end;
    end;
    
    // Subir um nível
    SearchDir := TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(SearchDir));
    if SearchDir = '' then Break;
  end;
  
  // Fallback: caminho absoluto direto (para cenário onde estamos rodando de dentro do projeto)
  CandidatePath := TPath.Combine(AppDir, RelativePath);
  if TFile.Exists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;
  
  // Último fallback: mesmo que não exista, retorna o path esperado
  Result := TPath.Combine(AppDir, '..\Dext.Starter.Admin\' + RelativePath);
end;

end.
