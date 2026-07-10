# Codecs Diretos & Geração Estática

A S54 adiciona uma camada compartilhada de planejamento de codecs usada por protobuf, JSON, hidratação ORM e futuros codecs gerados. O objetivo é remover chamadas quentes de `TValue` e RTTI quando um DTO ou entidade pode ser descrito por um plano de campos validado.

O runtime tem três níveis:

- **Fallback RTTI**: caminho de compatibilidade para membros dinâmicos ou não suportados.
- **Codecs por offset direto**: leitura e escrita de campos físicos validados via `Dext.Core.DirectAccess`.
- **Codecs gerados**: readers, writers e invokers gRPC em Pascal registrados no `TDextCodecRegistry`.

## Gerar um `.proto`

```bash
dext codecs export-proto --unit C:\caminho\MeuContrato.pas --out C:\caminho\MeuContrato.proto
```

## Gerar codecs Pascal

```bash
dext codecs generate --unit C:\caminho\MeuContrato.pas --out C:\caminho\MeuContrato.DextCodecs.pas
```

Adicione a unit gerada à aplicação ou package para que a seção `initialization` registre os codecs.

## Formato de DTO Suportado

O gerador foi desenhado para contratos Dext controlados, code-first e baseados em DTOs:

```pascal
uses
  Dext.Collections,
  Dext.Grpc.Attributes,
  Dext.Types.Nullable,
  Dext.Types.UUID;

type
  [GrpcMessage]
  TCustomerDto = class
  private
    FId: Integer;
    FName: string;
    FExternalId: TUUID;
    FTags: IList<Nullable<Integer>>;
  public
    [ProtoMember(1)]
    property Id: Integer read FId write FId;
    [ProtoMember(2)]
    property Name: string read FName write FName;
    [ProtoMember(3)]
    property ExternalId: TUUID read FExternalId write FExternalId;
    [ProtoMember(4)]
    property Tags: IList<Nullable<Integer>> read FTags write FTags;
  end;
```

Os formatos cobertos incluem escalares nativos, `string`, `TBytes`, `TGUID`, `TUUID`, classes aninhadas com `[GrpcMessage]`, `IList<T>`, `Nullable<T>`, `Prop<T>`, `Nullable<IList<T>>`, `IList<Nullable<T>>` e `IList<Prop<T>>`.

## Segurança do Offset Direto

O acesso direto só é usado quando `TDextTypeModel` valida um campo físico e o tipo nativo é suportado. Tipos gerenciados como `string`, interfaces, arrays dinâmicos, referências de objeto, GUIDs e UUIDs são atribuídos por helpers tipados para preservar reference count e regras de ownership.

Propriedades calculadas, getters/setters customizados, wrappers não suportados, listas ambíguas e membros com converters permanecem no fallback.

## Onde Ajuda

- **gRPC / protobuf**: readers/writers gerados e modo protobuf direto evitam RTTI repetido.
- **JSON**: `TDextJson` reutiliza o plano compartilhado para campos diretos suportados.
- **Hidratação ORM**: materialização de entidades usa o mesmo plano preservando converters e SmartProp/Nullable.
- **Sync de EntityDataSet**: payloads protobuf aproveitam o mesmo tratamento de objetos e listas.

Os maiores ganhos são esperados em Win32, onde `TValue` e invocação RTTI custam muito mais. Em Win64 o ganho depende da carga e deve ser medido com os benchmarks da S54.

## Limites Atuais

- O gerador CLI é pragmático, não um parser Delphi completo.
- Prefira DTOs com propriedades apoiadas por campos e tags `[ProtoMember]` estáveis.
- Ownership de listas precisa ser explícito e compatível com Dext Collections.
- `Lazy<T>` não é tratado como formato de dados serializável.
- Codecs JSON gerados são uma otimização futura; hoje o JSON se beneficia do plano direto compartilhado.
- O Expert da IDE foi adiado e deve mostrar elegibilidade/fallback antes de habilitar geração ampla.

---

[← README](README.md) | [Networking →](../12-networking/grpc.md)
