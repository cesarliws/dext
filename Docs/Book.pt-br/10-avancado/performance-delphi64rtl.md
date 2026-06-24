# Otimização com Delphi64RTL (Win64)

O Dext foi projetado para alta performance nativa, mas sob condições extremas de concorrência e carga no Windows 64-bit (Win64), a RTL (Run-Time Library) padrão do Delphi pode se tornar o gargalo de concorrência devido a alocações e operações de string pesadas.

Para contornar isso, o Dext suporta opcionalmente a **Delphi64RTL** desenvolvida pela comunidade (RDP1974), que substitui funções críticas da RTL por implementações otimizadas em Assembly x86-64 e instruções SIMD.

---

## Por que Usar?

* **Gerenciador de Memória Otimizado (`RDPMM64`)**: Reduz drasticamente a contenção de locks em cenários multi-thread de altíssima concorrência (como o loop do HTTP.sys ou processamento assíncrono).
* **Otimização de Funções de String**: Substitui funções comuns de manipulação de string por versões Assembly otimizadas para processadores modernos.
* **Instruções SIMD (`RDPSimd64`)**: Acelera operações matemáticas e lógicas de baixo nível utilizando instruções vetoriais (AVX/SSE).
* **Melhorias de Performance Comprovadas**: Em nossos benchmarks end-to-end (servidor HTTP.sys + banco de dados embarcado), a inclusão da Delphi64RTL resultou em um ganho de **2x a 3x mais requisições por segundo (req/s)** e latências muito menores sob alta concorrência.

---

## Quando Usar?

* **Apenas no Windows 64-bit (Win64)**: O projeto Delphi64RTL é focado exclusivamente em arquitetura Win64.
* **Aplicações de Alta Escala**: Servidores REST/JSON de produção que lidam com centenas de conexões simultâneas ou rotinas intensivas em CPU.

---

## Como Usar no Dext

A Delphi64RTL é uma dependência **opcional**. Para evitar acoplamento ou poluição no repositório principal, ela não vem inclusa no código fonte do Dext, mas o suporte a ela está pré-configurado no projeto de benchmark.

### Passo 1: Baixar a Biblioteca
Faça o clone do repositório da Delphi64RTL em qualquer diretório da sua máquina ou utilize uma pasta de dependências externas do seu projeto (por exemplo, `External/Delphi64RTL`):

```bash
git clone https://github.com/RDP1974/Delphi64RTL.git
```

### Passo 2: Configurar o Caminho de Busca (Search Path)
Adicione o diretório onde a Delphi64RTL foi baixada:
* No Delphi IDE: Vá em **Tools > Options > Deployment > Connection Profile Manager** (ou nas propriedades do projeto **Building > Delphi Compiler > Search path**).
* Na linha de comando (MSBuild): Adicione o caminho ao parâmetro `/p:DCC_UnitSearchPath`.

### Passo 3: Adicionar ao Arquivo de Projeto (.dpr)
No arquivo principal do seu projeto (`.dpr`), adicione as units `RDPMM64` e `RDPSimd64` como as **primeiras** units da cláusula `uses`, preferencialmente sob diretivas condicionais para manter a compatibilidade com outras plataformas:

```pascal
program MeuServidorDext;

{$APPTYPE CONSOLE}
{$DEFINE USE_RDP} // Defina esta flag para ativar a otimização

uses
  {$IFDEF WIN64}
    {$IFDEF USE_RDP}
    RDPMM64,
    RDPSimd64,
    {$ENDIF}
  {$ENDIF}
  System.SysUtils,
  Dext.Web.WebApplication,
  // ... outras units
```

> [!IMPORTANT]
> A unit `RDPMM64` deve ser listada antes de quase todas as outras units no arquivo `.dpr` para garantir que ela inicialize o gerenciador de memória otimizado corretamente no início da execução do processo.
