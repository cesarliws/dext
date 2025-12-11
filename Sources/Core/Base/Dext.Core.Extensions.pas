unit Dext.Core.Extensions;

interface

uses
  System.SysUtils,
  Dext.DI.Interfaces,
  Dext.Hosting.BackgroundService;

type
  /// <summary>
  ///   Core extension methods for IServiceCollection.
  /// </summary>
  TDextServiceCollectionExtensions = class
  public
    /// <summary>
    ///   Adds background service infrastructure to the DI container.
    ///   Returns a builder for registering hosted services.
    /// </summary>
    class function AddBackgroundServices(Services: IServiceCollection): TBackgroundServiceBuilder;
  end;

implementation

{ TDextServiceCollectionExtensions }

class function TDextServiceCollectionExtensions.AddBackgroundServices(
  Services: IServiceCollection): TBackgroundServiceBuilder;
begin
  Result := TBackgroundServiceBuilder.Create(Services);
end;

end.
