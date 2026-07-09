# gRPC & TEntityDataSet Integration Demo

Este exemplo demonstra o uso do gRPC e Protocol Buffers (proto3) de ponta a
ponta no Dext Framework, com e sem o uso de componentes visuais.

## Recursos Demonstrados
1. **Comunicação Code-First gRPC**: Definição de contratos via interfaces e
   atributos (`[GrpcService]`, `[GrpcMethod]`).
2. **Serialização Protobuf**: Mapeamento de entidades com `[ProtoMember]`.
3. **Sincronização com TEntityDataSet**: Busca (`FetchAll`) e persistência
   de alterações (`ApplyChanges`) via `TEntitygRpcProvider<T>`.

## Como Executar
1. Abra o projeto no Delphi ou compile usando a linha de comando:
   ```bash
   msbuild Grpc.EntityDataSet.Demo.dproj
   ```
2. Execute a aplicação gerada na pasta `Output`.
