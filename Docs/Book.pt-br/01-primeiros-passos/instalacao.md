# Guia de Instalação do Dext Framework

Este guia descreve os passos necessários para instalar e configurar o Dext Framework. Você pode optar pela **Instalação Automática** (recomendada via TMS Smart Setup) ou pela **Instalação Manual**.

---

## 1. Instalação Automática (TMS Smart Setup - Recomendado)

Se você utiliza o **TMS Smart Setup**, a instalação, compilação e configuração do framework na IDE do Delphi são totalmente automatizadas.

> [!IMPORTANT]
> **Habilitando o Servidor da Comunidade (Community Server)**  
> Como o Dext Framework é um pacote open-source da comunidade, você deve garantir que o **Community Server** esteja habilitado no seu espaço de trabalho do TMS Smart Setup. Você pode ativá-lo usando um dos seguintes métodos:
> 
> * **Via Linha de Comando (CLI)**: Abra seu terminal e execute:
>   ```bash
>   tms server-enable community
>   ```
> * **Via Interface Gráfica (GUI)**: Abra o aplicativo `tmsgui.exe`. (Se for um novo workspace, o assistente de inicialização perguntará imediatamente quais servidores ativar. Caso contrário, clique no ícone de engrenagem de configurações no canto superior direito e certifique-se de habilitar a opção **Community Server**).
> 
>   ![TMS Smart Setup Community](../../Images/smart-setup-community.png)

Uma vez habilitado o Community Server, você pode instalar o Dext tanto pela interface gráfica (GUI) quanto pela linha de comando (CLI):

### 1.1. Instalação via GUI
1. Abra o aplicativo **TMS Smart Setup** (`tmsgui.exe`).
2. No campo de busca, digite `dotpas.dext`.
3. Selecione **Dext Framework** na lista de produtos.
4. Clique no botão **Install**.

### 1.2. Instalação via CLI
Basta executar o seguinte comando no seu terminal:
```bash
tms install dotpas.dext
```

O Smart Setup lerá o manifesto `tmsbuild.yaml`, compilará todos os pacotes para as plataformas suportadas e configurará automaticamente todos os Library Paths, Browsing Paths, variáveis de ambiente e diretórios das BPLs na IDE do Delphi.

> [!TIP]
> Você pode baixar a versão mais recente do TMS Smart Setup na [Página de Download do TMS Smart Setup](https://doc.tmssoftware.com/smartsetup/download/).

---

## 2. Instalação Manual

Se preferir compilar e configurar o framework manualmente, siga os passos abaixo.

### 2.1. Personalização do Framework (Dext.inc)

Antes de compilar o Dext Framework, você pode personalizar seu comportamento e os drivers/integrações de banco de dados ativos editando o arquivo `Sources\Common\Dext.inc`. Este arquivo centraliza todas as diretivas globais de compilação:

#### A. Drivers de Banco de Dados (Dext.Entity)
Por padrão, o Dext vem configurado apenas com o driver **SQLite** habilitado, garantindo total compatibilidade com o **Delphi Community Edition**. Se você possui Delphi Enterprise/Architect e deseja habilitar outros bancos de dados, descomente as linhas correspondentes:
```pascal
{$DEFINE DEXT_ENABLE_DB_SQLITE}      // Ativo por padrão
{.$DEFINE DEXT_ENABLE_DB_POSTGRES}   // Remova o ponto (.) para ativar
{.$DEFINE DEXT_ENABLE_DB_MYSQL}
{.$DEFINE DEXT_ENABLE_DB_MSSQL}
{.$DEFINE DEXT_ENABLE_DB_ORACLE}
{.$DEFINE DEXT_ENABLE_DB_FIREBIRD}
```
*Importante:* Ao habilitar outros bancos de dados, adicione a unit `Dext.Entity.Drivers.FireDAC.Links` ao seu projeto (ex: na cláusula `uses` do `.dpr` ou Formulário Principal) para garantir que os drivers sejam vinculados corretamente.

#### B. Integração com TestInsight (`DEXT_TESTINSIGHT`)
Se você utiliza a ferramenta **TestInsight** para gerenciar e executar testes unitários diretamente na IDE do Delphi, descomente a linha correspondente para ativar a integração:
```pascal
{.$DEFINE DEXT_TESTINSIGHT}
```
*Nota: Requer que `TestInsight.Client.pas` esteja no Library Path da sua IDE.*

#### C. Web Stencils (`DEXT_ENABLE_WEB_STENCILS`)
Para projetos desenvolvidos em **Delphi 12.2 ou superior** no Windows, o Dext suporta o uso do novo mecanismo de templates **Web Stencils**:
```pascal
{$IFDEF DEXT_DELPHI12_UP}
  {$IFDEF MSWINDOWS}
    {$DEFINE DEXT_ENABLE_WEB_STENCILS}
  {$ENDIF}
{$ENDIF}
```

> [!NOTE]
> O suporte a **Web Stencils** é condicional. O pacote `Dext.Web.Core.dpk` inclui o arquivo `Dext.inc` e declara condicionalmente a dependência do pacote `inetstn` da Embarcadero apenas se `DEXT_ENABLE_WEB_STENCILS` estiver ativo. Em versões anteriores à 12.2 ou outras plataformas, essa dependência e o código relacionado são completamente desativados/ignorados pelo compilador de forma transparente, sem warnings.

#### D. Conflitos de Nomes de Componentes (`DEXT_USE_ENTITY_PREFIX`)
Caso você possua outras bibliotecas instaladas (como o Devart EntityDAC) que utilizem os mesmos nomes de componentes (`TEntityDataSet`, `TEntityDataProvider`), descomente a linha correspondente para registrar componentes com o prefixo `TDext...` e evitar conflitos na IDE:
```pascal
{.$DEFINE DEXT_USE_ENTITY_PREFIX}
```

---

### 2.2. Compilação do Grupo de Projetos

Após ajustar o arquivo `Dext.inc` conforme a sua necessidade:

1. Abra o grupo de projetos principal no Delphi:
    - `Sources\DextFramework.groupproj`
2. No Project Manager, clique com o botão direito no nó raiz (**ProjectGroup**) e selecione **Build All**.
3. Aguarde a conclusão da compilação de todos os pacotes.

Todos os artefatos compilados (DCUs, BPLs e DCPs) serão gerados na exata mesma pasta:
- `..\Output\$(ProductVersion)\$(Platform)\$(Config)` (relativo às pastas dos pacotes)

*Exemplo de pasta de saída para Delphi 12 Athens Win32 Debug:*
- `Output\23.0\Win32\Debug`

> [!IMPORTANT]
> **Compatibilidade e Limite de Versão do Delphi**
> O Dext utiliza o sufixo de biblioteca Lib Suffix `$(Auto)` para adicionar o versionamento automaticamente ao nome da BPL criada, e a variável `$(ProductVersion)` para organizar os artefatos gerados. Estes recursos exigem o **Delphi 10.4 Sydney** ou superior.
>
> Para versões anteriores à 10.4:
> - A instalação deve ser feita manualmente.
> - Devido à falta de suporte para `$(ProductVersion)` e Lib Suffix `$(Auto)`, a instalação de múltiplos ambientes ou plataformas lado a lado na mesma máquina pode causar colisões e erros. Isso acontece porque a IDE busca as BPLs através da variável de ambiente `PATH` do Windows e tentará carregar o primeiro arquivo que encontrar.

---

### 2.3. Configuração de Variável de Ambiente

Utilizar uma variável de ambiente simplifica seus Library Paths e permite alternar entre diferentes versões/forks do Dext facilmente.

1. No Delphi, vá em **Tools** > **Options** > **IDE** > **Environment Variables**.
2. Em **User System Overrides**, clique em **New...**.
3. **Variable Name**: `DEXT`
4. **Value**: O caminho completo para a pasta `Sources` dentro do seu repositório clonado.
    - *Exemplo*: `C:\dev\Dext\DextRepository\Sources`
    - *Nota*: Aponte para a pasta `Sources`, não a raiz do repositório.

    ![Variável de Ambiente DEXT](../../Images/ide-env-var.png)

---

### 2.4. Configuração do Library Path (DCUs e DCPs)

Para que a IDE encontre os arquivos compilados do framework, adicione os caminhos no Library Path.

> [!IMPORTANT]
> A IDE do Delphi **não expande** variáveis dinâmicas de projeto (como `$(Platform)`, `$(Config)` ou `$(ProductVersion)`) nas configurações globais de Library Path. Por isso, você deve adicionar caminhos específicos (com a versão do compilador Delphi) para as combinações que deseja utilizar.
>
> Valores de `$(ProductVersion)` comuns:
> - **21.0** para Delphi 10.4 Sydney
> - **22.0** para Delphi 11 Alexandria
> - **23.0** para Delphi 12 Athens

1. No Delphi, vá em **Tools** > **Options** > **Language** > **Delphi** > **Library**.
2. Selecione a **Platform** desejada (ex: Windows 32-bit).
3. No campo **Library Path**, adicione os seguintes caminhos (use a variável `$(DEXT)` para simplificar):
    - `$(DEXT)\Common` (contém o `Dext.inc` e outras units úteis para o desenvolvimento, como `Dext.MM` ou `Dext.Testing.TestInsight`)
    - `$(DEXT)\..\Output\23.0\Win32\Release` (caminho dos artefatos DCUs, BPLs e DCPs na configuração Release)

*Nota: Repita o processo para outras plataformas (ex: Win64) ou configurações, ajustando a versão e plataforma conforme necessário.*

---

### 2.5. Configuração do Path de Execução (BPLs)

Como as BPLs compiladas em modo runtime são geradas na pasta de saída, a IDE do Delphi precisa localizá-las ao carregar os pacotes de design-time. Para resolver isso, você deve adicionar o diretório de saída das BPLs na variável de ambiente `PATH` da IDE ou do Windows:

1. Vá em **Tools** > **Options** > **IDE** > **Environment Variables**.
2. Em **User System Overrides**, selecione a variável **PATH** e clique em **Edit** (ou clique em **New...** se ela não existir).
3. Adicione no final do valor existente, separando por ponto e vírgula (`;`), os caminhos das BPLs na configuração **Release**, ajustando o caminho físico do seu repositório e a versão do compilador:
    - *Exemplo para Delphi 12 Athens (23.0)*:
      `;C:\dev\Dext\DextRepository\Output\23.0\Win32\Release;C:\dev\Dext\DextRepository\Output\23.0\Win64\Release`

---

### 2.6. Configuração do Debug DCU Path

Se você precisa debugar o código fonte interno do framework passo a passo nas suas aplicações:

1. Compile os pacotes do Dext Framework na configuração **Debug**.
2. No Delphi, vá em **Tools** > **Options** > **Language** > **Delphi** > **Library**.
3. No campo **Debug DCU Path**, adicione a pasta correspondente aos artefatos de Debug:
    - `$(DEXT)\..\Output\23.0\Win32\Debug`

---

### 2.7. Instalação de Pacotes de Design-Time

Para instalar os componentes de tempo de design e assistentes na IDE do Delphi:

1. Abra `Sources\DextFramework.groupproj` no Delphi.
2. Clique com o botão direito no nó raiz (**ProjectGroup**) e selecione **Build All** (para garantir que todos os pacotes foram compilados).
3. Clique com o botão direito nos seguintes pacotes no Project Manager e selecione **Install**:
    - **`Dext.EF.Design.dpk`**: Componentes `TEntityDataSet`, `TEntityDataProvider` e experts/assistentes para scaffolding e editores.
    - **`Dext.Testing.Design.dpk`**: Expert **Dext Test Explorer** para gerenciar e executar testes unitários diretamente na IDE.

---

### 2.8. Configuração do Gerenciador de Memória (Dext.MM)

O gerenciador de memória do Dext (`Dext.MM.pas`) reside na pasta `Sources\Common`. Para utilizá-lo em suas aplicações executáveis:

1. Certifique-se de que a pasta `$(DEXT)\Common` está adicionada ao seu Library Path (conforme passo 2.4).
2. No arquivo principal da sua aplicação (arquivo `.dpr` do executável), adicione `Dext.MM` como a **primeiríssima** unit na cláusula `uses`.
   - *Exemplo*:
     ```pascal
     program MeuProjeto;

     uses
       Dext.MM, // Deve ser sempre a primeira!
       Vcl.Forms,
       ...
     ```

### 2.9. Integrações Opcionais (WebStencils e TestInsight)

Por motivos de portabilidade e compatibilidade de instalação automatizada, as units de integrações opcionais não são incluídas de forma estática nos pacotes principais do framework:

* **Web Stencils**: A unit `Dext.Web.View.WebStencils.pas` reside em `Sources\Web` e é usada apenas quando a condicional `DEXT_ENABLE_WEB_STENCILS` está ativa em seu `Dext.inc`.
* **TestInsight**: A unit `Dext.Testing.TestInsight.pas` reside em `Sources\Testing`. Para utilizá-la em seus projetos de testes, adicione-a diretamente ao uses do projeto `.dpr` de testes (condicionada a `{$IFDEF TESTINSIGHT}`) e certifique-se de que a biblioteca do cliente TestInsight está no library path da IDE.

---

### 2.10. Configuração do Browsing Path (Arquivos Fonte)

Para permitir a navegação no código fonte (Ctrl+Click) e debugging detalhado, adicione os seguintes diretórios ao **Browsing Path** da sua IDE.

> [!WARNING]
> **NÃO coloque estas pastas de fontes no campo Library Path!**  
> Se você adicionar pastas de sources (fontes) no Library Path, o compilador do Delphi irá recompilar pedaços do Dext toda vez que você compilar o projeto da sua aplicação. Isso fará com que arquivos `.dcu` de versões diferentes fiquem espalhados pelas pastas do seu projeto, gerando erros de compilação difíceis de rastrear (como o erro `F2051`).  
> **O Dext deve ser compilado exclusivamente na instalação.**

```text
$(DEXT)
$(DEXT)\AI
$(DEXT)\AI\MCP
$(DEXT)\Core
$(DEXT)\Core\Base
$(DEXT)\Core\Interception
$(DEXT)\Core\Json
$(DEXT)\Dashboard
$(DEXT)\Data
$(DEXT)\Debug
$(DEXT)\Design
$(DEXT)\Events
$(DEXT)\Hosting
$(DEXT)\Hosting\CLI
$(DEXT)\Hosting\CLI\Logger
$(DEXT)\Hosting\CLI\Tools
$(DEXT)\Hubs
$(DEXT)\Hubs\Transports
$(DEXT)\Net
$(DEXT)\Testing
$(DEXT)\UI
$(DEXT)\Web
$(DEXT)\Web\Caching
$(DEXT)\Web\Hosting
$(DEXT)\Web\Indy
$(DEXT)\Web\Middleware
$(DEXT)\Web\Mvc
$(DEXT)\..\Apps\CLI\Commands
```

> [!TIP]
> **Dica:** Como adicionar cada item manualmente é trabalhoso, você pode copiar a linha abaixo e colá-la diretamente no final do campo **Browsing Path**:
> ```text
> ;$(DEXT);$(DEXT)\AI;$(DEXT)\AI\MCP;$(DEXT)\Core;$(DEXT)\Core\Base;$(DEXT)\Core\Interception;$(DEXT)\Core\Json;$(DEXT)\Dashboard;$(DEXT)\Data;$(DEXT)\Debug;$(DEXT)\Design;$(DEXT)\Events;$(DEXT)\Hosting;$(DEXT)\Hosting\CLI;$(DEXT)\Hosting\CLI\Logger;$(DEXT)\Hosting\CLI\Tools;$(DEXT)\Hubs;$(DEXT)\Hubs\Transports;$(DEXT)\Net;$(DEXT)\Testing;$(DEXT)\UI;$(DEXT)\Web;$(DEXT)\Web\Caching;$(DEXT)\Web\Hosting;$(DEXT)\Web\Indy;$(DEXT)\Web\Middleware;$(DEXT)\Web\Mvc;$(DEXT)\..\Apps\CLI\Commands
> ```

---

### 2.11 Instalação para Outras Plataformas (Linux, Win64, Android, iOS...)

O Dext Framework suporta compilação multi-plataforma. Se você deseja utilizar o Dext em plataformas como Linux, Windows 64-bit ou dispositivos móveis, siga as instruções abaixo:

1. **Adicione a plataforma ao pacote (se necessário):**
   No Delphi Project Manager, se a plataforma desejada não estiver listada no pacote em **Target Platforms**, clique com o botão direito em **Target Platforms**, escolha **Add Platform...** e selecione a plataforma desejada.
2. **Selecione a plataforma ativa na barra de ferramentas:**
   Para compilar os pacotes do Dext para a plataforma desejada, selecione a plataforma ativa no menu drop-down de seleção de plataforma ativa na barra de ferramentas principal do Delphi.
3. **Execute o Build:**
   Com a plataforma ativa selecionada, clique com o botão direito no nó raiz (**ProjectGroup**) no Project Manager e selecione **Build All**.
4. **Configure os Paths para a nova plataforma:**
   Repita os passos de **Library Path** (Passo 2.4) e **Browsing Path** (Passo 2.10) para cada uma das novas plataformas configuradas nas Opções da IDE do Delphi.

---

## Verificação

Para confirmar que a instalação está correta:

1. Feche o grupo de projetos do framework.
2. Abra o grupo de exemplos:
    - `Examples\DextExamples.groupproj`
3. Execute **Build All**.
4. Se todos os projetos compilarem com sucesso, o ambiente está configurado corretamente.

---

## Resolução de Problemas

### F2051: Unit was compiled with a different version

**Causa:**  
Este erro ocorre quando o compilador Delphi encontra um conflito entre arquivos `.dcu` pré-compilados e arquivos fonte `.pas` crus. Tipicamente, isso acontece quando as pastas `Sources` são incorretamente adicionadas ao **Library Path** em vez do **Browsing Path**.

**Solução:**
1. Vá em **Tools** > **Options** > **Language** > **Delphi** > **Library**.
2. Verifique seu **Library Path**:
    - ✅ Deve conter **apenas** a pasta do build compilado e o caminho de diretivas (ex: `Output\23.0\Win32\Release` e `$(DEXT)\Common`).
    - ❌ Remova quaisquer pastas `Sources\*` do Library Path.
3. Verifique seu **Browsing Path**:
    - ✅ Deve conter as pastas `Sources\*` (conforme listado no Passo 2.10 acima).
4. Limpe e recompile:
    - Delete quaisquer arquivos `.dcu` da pasta de saída do seu projeto.
    - Recompile o Dext framework (`Sources\DextFramework.groupproj` > **Build All**).
    - Recompile seu projeto.

### Compilação falha com erros "File not found"

**Causa:**  
O Library Path não contém a pasta dos DCUs/BPLs/DCPs compilados, ou o framework não foi compilado para a plataforma/configuração alvo.

**Solução:**
1. Certifique-se de que você compilou o framework Dext para a plataforma correta (Win32/Win64) e configuração (Release/Debug).
2. Verifique se o Library Path aponta para a pasta do build correta:
    - ex: `$(DEXT)\..\Output\23.0\Win32\Release`

---

### Referência Rápida: Resumo da Configuração de Paths

| Tipo de Path      | O Que Adicionar                                | Objetivo                                 |
|-------------------|------------------------------------------------|------------------------------------------|
| **Library Path**  | `Output\23.0\Win32\Release`                    | Localizar arquivos `.dcu` / `.dcp` / `.bpl` |
| **Library Path**  | `$(DEXT)\Common`                               | Localizar o `Dext.inc` e units comuns    |
| **System PATH**   | `Output\23.0\Win32\Release`                    | Encontrar as BPLs em tempo de execução   |
| **Browsing Path** | Todas as pastas `Sources\*`                    | Navegação no código e debugging          |
| **Debug DCU Path**| `Output\23.0\Win32\Debug`                      | Localizar arquivos de debug `.dcu`       |

---

[← Voltar para Primeiros Passos](../../README.pt-br.md) | [Próximo: Hello World →](hello-world.md)
