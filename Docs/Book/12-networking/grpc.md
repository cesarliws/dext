# gRPC & Protocol Buffers (gRPC Integration)

The Dext Framework provides a first-class, high-performance binary communication stack based on gRPC and Protocol Buffers (proto3). This serves as a modern, cross-platform replacement for legacy communication protocols like DataSnap, RemoteObjects, or REST/JSON over HTTP/1.

---

## 1. Core Architecture

The gRPC stack is divided into four main layers:

1. **Serialization Layer** (`Dext.Serialization.Protobuf`): Fast, zero-allocation binary serialization using `TSpan` memory buffers.
2. **Codec Layer** (`Dext.Grpc.Codec`): Handles gRPC Length-Prefixed Messages (LPM).
3. **Server Layer** (`Dext.Web.Grpc.Server`): Direct HTTP/2 frame routing and method dispatch via reflection.
4. **Client & DataSet Integration** (`Dext.Entity.GrpcProvider`): Integrates with `TEntityDataSet` for seamless remote synchronization.

---

## 2. Server Configuration

Services are mapped automatically from Delphi interfaces using the code-first approach. 

```pascal
type
  [GrpcService('dext.services.UserService')]
  IUserService = interface(IInvokable)
    ['{A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D}']
    function GetUser(const ARequest: TUserRequest): TUserResponse;
  end;
```

To enable the gRPC dispatcher on the Dext Server, register the service mapping in the application startup:

```pascal
procedure TStartup.ConfigureServices(const AServices: TDextServices);
begin
  AServices.AddSingleton<IUserService, TUserService>;
end;
```

---

## 3. Remote Sync via TEntityDataSet

The gRPC sync provider (`TEntitygRpcProvider`) can be attached to a `TEntityDataSet` to synchronize CRUD operations using protobuf messages.

```pascal
var
  FDataSet: TEntityDataSet;
  FProvider: TEntitygRpcProvider;
begin
  FDataSet := TEntityDataSet.Create(Self);
  FProvider := TEntitygRpcProvider.Create('http://localhost:50051');
  
  // Bind remote provider to dataset
  FDataSet.SetRemoteProvider(FProvider);
  FDataSet.Load<TUserTest>(FProvider.FetchUsers);
  FDataSet.Open;
end;
```
