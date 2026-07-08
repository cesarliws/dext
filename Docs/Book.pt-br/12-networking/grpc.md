# gRPC & Protocol Buffers (Integração gRPC)

O Dext Framework oferece uma pilha de comunicação binária nativa e de alta performance baseada em gRPC e Protocol Buffers (proto3). Essa pilha serve como uma substituição moderna e multiplataforma para protocolos legados como DataSnap, RemoteObjects ou REST/JSON sobre HTTP/1.

---

## 1. Arquitetura Core

A pilha gRPC está dividida em quatro camadas principais:

1. **Camada de Serialização** (`Dext.Serialization.Protobuf`): Serialização binária rápida e de zero alocação no heap usando buffers de memória baseados em `TSpan`.
2. **Camada de Codec** (`Dext.Grpc.Codec`): Gerenciamento e parsing de pacotes gRPC Length-Prefixed Messages (LPM).
3. **Camada de Servidor** (`Dext.Web.Grpc.Server`): Despacho de requisições de frames HTTP/2 diretamente para os métodos de serviço registrados via RTTI.
4. **Integração Cliente & DataSet** (`Dext.Entity.GrpcProvider`): Acoplamento do provedor ao `TEntityDataSet` para persistência distribuída bidirecional transparente.

---

## 2. Configuração do Servidor

Os serviços gRPC são definidos de forma declarativa (Code-First) a partir de interfaces normais em Delphi.

```pascal
type
  [GrpcService('dext.services.UserService')]
  IUserService = interface(IInvokable)
    ['{A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D}']
    function GetUser(const ARequest: TUserRequest): TUserResponse;
  end;
```

Para habilitar o mapeamento gRPC no servidor, basta registrar as classes e interfaces de serviço no IoC do container:

```pascal
procedure TStartup.ConfigureServices(const AServices: TDextServices);
begin
  AServices.AddSingleton<IUserService, TUserService>;
end;
```

---

## 3. Sincronização Remota via TEntityDataSet

O provedor `TEntitygRpcProvider` pode ser anexado a um `TEntityDataSet` para sincronizar automaticamente as operações CRUD através de payloads protobuf compactados.

```pascal
var
  FDataSet: TEntityDataSet;
  FProvider: TEntitygRpcProvider;
begin
  FDataSet := TEntityDataSet.Create(Self);
  FProvider := TEntitygRpcProvider.Create('http://localhost:50051');
  
  // Associa o provedor gRPC ao dataset
  FDataSet.SetRemoteProvider(FProvider);
  FDataSet.Load<TUserTest>(FProvider.FetchUsers);
  FDataSet.Open;
end;
```
