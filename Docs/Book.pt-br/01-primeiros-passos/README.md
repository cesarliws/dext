# 1. Primeiros Passos

Bem-vindo ao Dext! Esta seção vai te colocar para rodar em minutos.

## Capítulos

1. [Por Onde Começar?](por-onde-comecar.md) - Escolhendo seu caminho de aprendizado
2. [Instalação](instalacao.md) - Começando com o Dext
3. [Hello World](hello-world.md) - Sua primeira aplicação
4. [Estrutura do Projeto](estrutura-projeto.md) - Layout de pastas e organização
5. [Inicialização da Aplicação](inicializacao-aplicacao.md) - O padrão Startup Class

## Início Rápido

```pascal
program HelloDext;

{$APPTYPE CONSOLE}

uses
  Dext.Web;

begin
  TWebHostBuilder.CreateDefault(nil)
    .UseUrls('http://localhost:5000')
    .Configure(procedure(App: IApplicationBuilder)
      begin
        App.MapGet('/hello', procedure(Ctx: IHttpContext)
          begin
            Ctx.Response.Write('Olá, Dext!');
          end);
      end)
    .Build
    .Run;
end.
```

Execute e visite `http://localhost:5000/hello` 🎉

---

[Próximo: Instalação →](instalacao.md)
