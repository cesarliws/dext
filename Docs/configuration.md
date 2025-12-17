# Configuração e Compatibilidade

O Dext Framework utiliza um sistema de diretivas de compilação para garantir compatibilidade entre diferentes versões do Delphi e oferecer flexibilidade na escolha de dependências.

## Arquivo de Configuração (`Dext.inc`)

O arquivo `Sources\Dext.inc` contém as definições globais do projeto. Ele detecta automaticamente a versão do compilador e habilita recursos modernos quando disponíveis.

### Definições Automáticas

| Diretiva | Descrição | Versão Mínima |
|----------|-----------|---------------|
| `DEXT_HAS_SYSTEM_HASH` | Habilita o uso da unit `System.Hash` (nativa) para criptografia e hashing, eliminando dependências do OpenSSL/Indy. | Delphi XE8 (Ver 29.0) |

### Overrides (Manual)

Você pode forçar certos comportamentos definindo diretivas globais no seu projeto (`Project Options > Delphi Compiler > Conditional Defines`) ou descomentando/adicionando no `Dext.inc`.

| Diretiva | Descrição |
|----------|-----------|
| `DEXT_FORCE_INDY_HASH` | Força o uso do Indy (`IdHMACSHA256`) mesmo em versões modernas do Delphi que possuem `System.Hash`. Útil se você precisar de compatibilidade estrita com sistemas legados ou encontrar problemas com a implementação nativa. |

## Módulos Afetados

### JWT (`Dext.Auth.JWT`)

- **Padrão (XE8+):** Usa `System.Hash.THashSHA2`. Não requer DLLs externas.
- **Legado (< XE8):** Usa `IdHMACSHA256`. Requer DLLs do OpenSSL (`libeay32.dll`, `ssleay32.dll`) no PATH ou na pasta do executável.
