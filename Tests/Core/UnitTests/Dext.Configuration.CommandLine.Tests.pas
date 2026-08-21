unit Dext.Configuration.CommandLine.Tests;

interface

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Configuration.CommandLine;

type
  [TestFixture('Configuration.CommandLine')]
  TCommandLineConfigurationTests = class
  public
    [Test('Should parse standard --Key=Value argument')]
    procedure Should_ParseStandardKeyValue_When_DoubleDashEqualsProvided;

    [Test('Should parse slash prefixed /Key=Value argument')]
    procedure Should_ParseSlashKeyValue_When_SlashEqualsProvided;

    [Test('Should replace double underscore with colon delimiter')]
    procedure Should_ReplaceDoubleUnderscore_When_NestedKeyProvided;

    [Test('Should parse space separated --Key Value argument')]
    procedure Should_ParseSpaceSeparatedValue_When_NextTokenIsValue;

    [Test('Should apply switch mappings dictionary')]
    procedure Should_MapShortSwitch_When_SwitchMappingsProvided;

    [Test('Should treat standalone flag as true')]
    procedure Should_SetTrue_When_FlagHasNoValue;

    [Test('Should override earlier configuration sources in builder')]
    procedure Should_OverrideEarlierSources_When_AddedToBuilder;

    [Test('Should handle empty arguments gracefully')]
    procedure Should_HandleEmptyArgs_When_EmptyArrayGiven;
  end;

implementation

{ TCommandLineConfigurationTests }

procedure TCommandLineConfigurationTests.Should_ParseStandardKeyValue_When_DoubleDashEqualsProvided;
var
  Provider: TCommandLineConfigurationProvider;
  Value: string;
begin
  Provider := TCommandLineConfigurationProvider.Create(['--Server:Port=9090', '--App:Name=DextApp']);
  try
    Provider.Load;

    Should(Provider.TryGet('Server:Port', Value)).BeTrue;
    Should(Value).Be('9090');

    Should(Provider.TryGet('App:Name', Value)).BeTrue;
    Should(Value).Be('DextApp');
  finally
    Provider.Free;
  end;
end;

procedure TCommandLineConfigurationTests.Should_ParseSlashKeyValue_When_SlashEqualsProvided;
var
  Provider: TCommandLineConfigurationProvider;
  Value: string;
begin
  Provider := TCommandLineConfigurationProvider.Create(['/Database:Host=127.0.0.1', '/Faturamento:MaxDiscount=15']);
  try
    Provider.Load;

    Should(Provider.TryGet('Database:Host', Value)).BeTrue;
    Should(Value).Be('127.0.0.1');

    Should(Provider.TryGet('Faturamento:MaxDiscount', Value)).BeTrue;
    Should(Value).Be('15');
  finally
    Provider.Free;
  end;
end;

procedure TCommandLineConfigurationTests.Should_ReplaceDoubleUnderscore_When_NestedKeyProvided;
var
  Provider: TCommandLineConfigurationProvider;
  Value: string;
begin
  Provider := TCommandLineConfigurationProvider.Create(['--Database__Password=SecretPass', '--Logging__LogLevel__Default=Debug']);
  try
    Provider.Load;

    Should(Provider.TryGet('Database:Password', Value)).BeTrue;
    Should(Value).Be('SecretPass');

    Should(Provider.TryGet('Logging:LogLevel:Default', Value)).BeTrue;
    Should(Value).Be('Debug');
  finally
    Provider.Free;
  end;
end;

procedure TCommandLineConfigurationTests.Should_ParseSpaceSeparatedValue_When_NextTokenIsValue;
var
  Provider: TCommandLineConfigurationProvider;
  Value: string;
begin
  Provider := TCommandLineConfigurationProvider.Create(['--Server:Port', '9090', '--Database:Host', '10.0.0.1']);
  try
    Provider.Load;

    Should(Provider.TryGet('Server:Port', Value)).BeTrue;
    Should(Value).Be('9090');

    Should(Provider.TryGet('Database:Host', Value)).BeTrue;
    Should(Value).Be('10.0.0.1');
  finally
    Provider.Free;
  end;
end;

procedure TCommandLineConfigurationTests.Should_MapShortSwitch_When_SwitchMappingsProvided;
var
  Mappings: IDictionary<string, string>;
  Provider: TCommandLineConfigurationProvider;
  Value: string;
begin
  Mappings := TCollections.CreateDictionaryIgnoreCase<string, string>;
  Mappings.Add('p', 'Server:Port');
  Mappings.Add('e', 'DEXT_ENVIRONMENT');

  Provider := TCommandLineConfigurationProvider.Create(['-p', '8088', '-e=Staging'], Mappings);
  try
    Provider.Load;

    Should(Provider.TryGet('Server:Port', Value)).BeTrue;
    Should(Value).Be('8088');

    Should(Provider.TryGet('DEXT_ENVIRONMENT', Value)).BeTrue;
    Should(Value).Be('Staging');
  finally
    Provider.Free;
  end;
end;

procedure TCommandLineConfigurationTests.Should_SetTrue_When_FlagHasNoValue;
var
  Provider: TCommandLineConfigurationProvider;
  Value: string;
begin
  Provider := TCommandLineConfigurationProvider.Create(['--EnableDiagnostics', '--DetailedErrors']);
  try
    Provider.Load;

    Should(Provider.TryGet('EnableDiagnostics', Value)).BeTrue;
    Should(Value).Be('true');

    Should(Provider.TryGet('DetailedErrors', Value)).BeTrue;
    Should(Value).Be('true');
  finally
    Provider.Free;
  end;
end;

procedure TCommandLineConfigurationTests.Should_OverrideEarlierSources_When_AddedToBuilder;
var
  Config: IConfigurationRoot;
begin
  Config := TConfigurationBuilder.Create
    .Add(TMemoryConfigurationSource.Create([
      TPair<string, string>.Create('Server:Port', '8080'),
      TPair<string, string>.Create('Database:Password', 'OldPass')
    ]))
    .Add(TCommandLineConfigurationSource.Create(['--Server:Port=9090', '--Database__Password=NewPass']))
    .Build;

  Should(Config['Server:Port']).Be('9090');
  Should(Config['Database:Password']).Be('NewPass');
end;

procedure TCommandLineConfigurationTests.Should_HandleEmptyArgs_When_EmptyArrayGiven;
var
  Provider: TCommandLineConfigurationProvider;
  Value: string;
begin
  Provider := TCommandLineConfigurationProvider.Create([]);
  try
    Provider.Load;
    Should(Provider.TryGet('NonExistent', Value)).BeFalse;
  finally
    Provider.Free;
  end;
end;

end.
