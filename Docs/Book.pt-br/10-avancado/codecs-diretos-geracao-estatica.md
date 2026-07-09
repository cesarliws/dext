# Codecs Diretos & Geração Estática

A S54 adiciona uma camada de codecs reutilizável para DTOs marcados com `[GrpcMessage]` e `[ProtoMember]`.

## Uso

Gere um `.proto`:

```bash
dext codecs proto --unit C:\caminho\MeuContrato.pas --out C:\caminho\MeuContrato.proto
```

Gere leitores e escritores Pascal estáticos:

```bash
dext codecs generate --unit C:\caminho\MeuContrato.pas --out C:\caminho\MeuContrato.DextCodecs.pas
```

O gerador cobre:

- escalares nativos
- `string` e `TBytes`
- classes aninhadas
- `IList<T>` com tipos escalares e objetos

## Limites atuais

- O contrato precisa usar `[GrpcMessage]` e `[ProtoMember]` com tags estáveis.
- O caminho estático atende os tipos suportados pelo modelo nativo do Dext.
- Coleções genéricas fora de `IList<T>` ainda seguem pelo caminho RTTI.
- O codec direto depende de campo físico descoberto pelo modelo, então propriedades calculadas continuam no fallback RTTI.

## Onde isso ajuda

Essa mesma base já pode alimentar:

- gRPC/protobuf
- REST/JSON
- ORM hydration
- `TEntityDataSet` remoto

---

[← README](README.md) | [Networking →](../12-networking/grpc.md)
