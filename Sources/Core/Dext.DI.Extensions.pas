unit Dext.DI.Extensions;

interface

uses
  System.Classes,
  System.SysUtils,
  System.TypInfo,
  Dext.DI.Interfaces;

type
  TServiceCollectionExtensions = class
  public
   class function AddSingleton<T: class>(
      const ACollection: IServiceCollection;
      const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload; static;

    class function AddTransient<T: class>(
      const ACollection: IServiceCollection;
      const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload; static;

    class function AddScoped<T: class>(
      const ACollection: IServiceCollection;
      const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload; static;

    class function AddSingleton<TService: IInterface; TImplementation: class>(
      const ACollection: IServiceCollection;
      const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload; static;

    class function AddTransient<TService: IInterface; TImplementation: class>(
      const ACollection: IServiceCollection;
      const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload; static;

    class function AddScoped<TService: IInterface; TImplementation: class>(
      const ACollection: IServiceCollection;
      const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload; static;

  end;

  TServiceProviderExtensions = class
  public
    // Para classes
    // Para classes
    class function GetServiceObject<T: class>(const AProvider: IServiceProvider): T; overload; static;
    class function GetRequiredServiceObject<T: class>(const AProvider: IServiceProvider): T; overload; static;

    // Para interfaces
    class function GetService<T: IInterface>(const AProvider: IServiceProvider): T; overload; static;
    class function GetRequiredService<T: IInterface>(const AProvider: IServiceProvider): T; overload; static;
  end;

implementation

{ TServiceCollectionExtensions }

class function TServiceCollectionExtensions.AddSingleton<T>(
  const ACollection: IServiceCollection;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
begin
  Result := ACollection.AddSingleton(
    TServiceType.FromClass(T), T, AFactory);
end;

class function TServiceCollectionExtensions.AddTransient<T>(
  const ACollection: IServiceCollection;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
begin
  Result := ACollection.AddTransient(
    TServiceType.FromClass(T), T, AFactory);
end;

class function TServiceCollectionExtensions.AddScoped<T>(
  const ACollection: IServiceCollection;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
begin
  Result := ACollection.AddScoped(
    TServiceType.FromClass(T), T, AFactory);
end;

// Implementações para interfaces
class function TServiceCollectionExtensions.AddSingleton<TService, TImplementation>(
  const ACollection: IServiceCollection;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
var
  Guid: TGUID;
begin
  Guid := GetTypeData(TypeInfo(TService))^.Guid;
  Result := ACollection.AddSingleton(
    TServiceType.FromInterface(Guid), TImplementation, AFactory);
end;

class function TServiceCollectionExtensions.AddTransient<TService, TImplementation>(
  const ACollection: IServiceCollection;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
var
  Guid: TGUID;
begin
  Guid := GetTypeData(TypeInfo(TService))^.Guid;
  Result := ACollection.AddTransient(
    TServiceType.FromInterface(Guid), TImplementation, AFactory);
end;

class function TServiceCollectionExtensions.AddScoped<TService, TImplementation>(
  const ACollection: IServiceCollection;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
var
  Guid: TGUID;
begin
  Guid := GetTypeData(TypeInfo(TService))^.Guid;
  Result := ACollection.AddScoped(
    TServiceType.FromInterface(Guid), TImplementation, AFactory);
end;

// Para classes
class function TServiceProviderExtensions.GetServiceObject<T>(
  const AProvider: IServiceProvider): T;
begin
  Result := T(AProvider.GetService(TServiceType.FromClass(TypeInfo(T))));
end;

class function TServiceProviderExtensions.GetRequiredServiceObject<T>(
  const AProvider: IServiceProvider): T;
var
  Obj: TObject;
begin
  Obj := AProvider.GetService(TServiceType.FromClass(TypeInfo(T)));
  if Obj = nil then
    raise EDextDIException.Create('Service not registered: ' + string(PTypeInfo(TypeInfo(T))^.Name));
  Result := T(Obj);
end;

// Para interfaces
class function TServiceProviderExtensions.GetService<T>(
  const AProvider: IServiceProvider): T;
var
  Guid: TGUID;
begin
  Guid := GetTypeData(TypeInfo(T))^.Guid;
  Result := T(AProvider.GetServiceAsInterface(TServiceType.FromInterface(Guid)));
end;

class function TServiceProviderExtensions.GetRequiredService<T>(
  const AProvider: IServiceProvider): T;
var
  Guid: TGUID;
  LService: IInterface;
begin
  Guid := GetTypeData(TypeInfo(T))^.Guid;
  LService := AProvider.GetServiceAsInterface(TServiceType.FromInterface(Guid));
  if not Assigned(LService) then
    raise EDextDIException.Create('Service not registered: ' + string(PTypeInfo(TypeInfo(T))^.Name));
  Result := T(LService);
end;

end.
