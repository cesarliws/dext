program Core.TestConfig;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Configuration.Json,
  Dext.Configuration.EnvironmentVariables;

procedure RunTest;
var
  Builder: IConfigurationBuilder;
  Config: IConfigurationRoot;
  Val: string;
begin
  Writeln('Starting Configuration Test...');

  Builder := TConfigurationBuilder.Create;
  
  // Add JSON source
  Writeln('Adding JSON source...');
  Builder.Add(TJsonConfigurationSource.Create('appsettings.json', True));
  
  // Add Env Vars source
  Writeln('Adding Environment Variables source...');
  Builder.Add(TEnvironmentVariablesConfigurationSource.Create);
  
  Writeln('Building configuration...');
  Config := Builder.Build;
  
  Writeln('Reading values...');
  
  Val := Config['AppSettings:Message'];
  Writeln('AppSettings:Message = ', Val);
  
  Val := Config['Logging:LogLevel:Default'];
  Writeln('Logging:LogLevel:Default = ', Val);
  
  // Test Environment Variable (PATH is usually present)
  Val := Config['PATH']; 
  if Val = '' then Val := Config['Path'];
  Writeln('PATH length = ', Length(Val));
  
  Writeln('Test Finished.');
end;

begin
  try
    RunTest;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ReadLn;
end.
