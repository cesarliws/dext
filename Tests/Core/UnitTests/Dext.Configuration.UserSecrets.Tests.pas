unit Dext.Configuration.UserSecrets.Tests;

interface

uses
  System.SysUtils,
  System.IOUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Configuration.UserSecrets;

type
  [TestFixture('Configuration.UserSecrets')]
  TUserSecretsConfigurationTests = class
  public
    [Test('Should resolve correct cross-platform secrets file path')]
    procedure Should_ResolveCorrectPath_When_UserSecretsIdProvided;

    [Test('Should return empty path when UserSecretsId is empty')]
    procedure Should_ReturnEmptyPath_When_UserSecretsIdIsEmpty;

    [Test('Should load values from secrets.json file')]
    procedure Should_LoadSecrets_When_FileExists;

    [Test('Should not raise exception when file is optional and missing')]
    procedure Should_NotRaiseException_When_OptionalFileMissing;

    [Test('Should override earlier memory/json source in configuration builder')]
    procedure Should_OverrideBaseSettings_When_SecretsLoaded;
  end;

implementation

{ TUserSecretsConfigurationTests }

procedure TUserSecretsConfigurationTests.Should_ResolveCorrectPath_When_UserSecretsIdProvided;
var
  ResolvedPath: string;
begin
  ResolvedPath := TUserSecretsConfigurationProvider.ResolveSecretsFilePath('my-test-app-id');
  Should(ResolvedPath).NotBeEmpty;
  Should(ResolvedPath).Contain('my-test-app-id');
  Should(ResolvedPath).EndWith('secrets.json');
end;

procedure TUserSecretsConfigurationTests.Should_ReturnEmptyPath_When_UserSecretsIdIsEmpty;
var
  ResolvedPath: string;
begin
  ResolvedPath := TUserSecretsConfigurationProvider.ResolveSecretsFilePath('');
  Should(ResolvedPath).BeEmpty;
end;

procedure TUserSecretsConfigurationTests.Should_LoadSecrets_When_FileExists;
var
  TestId: string;
  SecretsPath: string;
  SecretsDir: string;
  Provider: TUserSecretsConfigurationProvider;
  Value: string;
begin
  TestId := 'dext-test-' + TGUID.NewGuid.ToString;
  SecretsPath := TUserSecretsConfigurationProvider.ResolveSecretsFilePath(TestId);
  SecretsDir := TPath.GetDirectoryName(SecretsPath);

  ForceDirectories(SecretsDir);
  try
    TFile.WriteAllText(SecretsPath,
      '{' + sLineBreak +
      '  "ApiKey": "SecretValue123",' + sLineBreak +
      '  "Database": {' + sLineBreak +
      '    "Password": "DevSecretPassword"' + sLineBreak +
      '  }' + sLineBreak +
      '}', TEncoding.UTF8);

    Provider := TUserSecretsConfigurationProvider.Create(TestId, False);
    try
      Provider.Load;

      Should(Provider.TryGet('ApiKey', Value)).BeTrue;
      Should(Value).Be('SecretValue123');

      Should(Provider.TryGet('Database:Password', Value)).BeTrue;
      Should(Value).Be('DevSecretPassword');
    finally
      Provider.Free;
    end;
  finally
    if FileExists(SecretsPath) then
      TFile.Delete(SecretsPath);
    if TDirectory.Exists(SecretsDir) then
      TDirectory.Delete(SecretsDir, True);
  end;
end;

procedure TUserSecretsConfigurationTests.Should_NotRaiseException_When_OptionalFileMissing;
var
  Provider: TUserSecretsConfigurationProvider;
  Value: string;
begin
  Provider := TUserSecretsConfigurationProvider.Create('non-existent-secrets-id-' + TGUID.NewGuid.ToString, True);
  try
    Provider.Load;
    Should(Provider.TryGet('SomeKey', Value)).BeFalse;
  finally
    Provider.Free;
  end;
end;

procedure TUserSecretsConfigurationTests.Should_OverrideBaseSettings_When_SecretsLoaded;
var
  TestId: string;
  SecretsPath: string;
  SecretsDir: string;
  Config: IConfigurationRoot;
begin
  TestId := 'dext-test-override-' + TGUID.NewGuid.ToString;
  SecretsPath := TUserSecretsConfigurationProvider.ResolveSecretsFilePath(TestId);
  SecretsDir := TPath.GetDirectoryName(SecretsPath);

  ForceDirectories(SecretsDir);
  try
    TFile.WriteAllText(SecretsPath,
      '{' + sLineBreak +
      '  "Database": {' + sLineBreak +
      '    "Password": "SecretsOverriddenPassword"' + sLineBreak +
      '  }' + sLineBreak +
      '}', TEncoding.UTF8);

    Config := TConfigurationBuilder.Create
      .Add(TMemoryConfigurationSource.Create([
        TPair<string, string>.Create('Database:Password', 'BasePassword'),
        TPair<string, string>.Create('Database:Host', 'localhost')
      ]))
      .Add(TUserSecretsConfigurationSource.Create(TestId, False))
      .Build;

    Should(Config['Database:Password']).Be('SecretsOverriddenPassword');
    Should(Config['Database:Host']).Be('localhost');
  finally
    if FileExists(SecretsPath) then
      TFile.Delete(SecretsPath);
    if TDirectory.Exists(SecretsDir) then
      TDirectory.Delete(SecretsDir, True);
  end;
end;

end.
