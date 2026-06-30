program DextGeminiServer;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.Classes,
  System.SysUtils,
  Dext.Collections,
  Dext.Net.RestClient,
  Dext.Options,
  Dext, Dext.DI.Interfaces,
  Dext.Web,
  Dext.Utils,
  Gemini.Models in 'Gemini.Models.pas';

begin
  // Inicializa a aplicação Web do Dext
  var App : IWebApplication := WebApplication;
  var Services := App.Services;

  Services.Configure<TGeminiOptions>(App.Configuration.GetSection('Gemini'));
  var StartupGeminiOptions := TOptionsFactory.Create<TGeminiOptions>(
    App.Configuration.GetSection('Gemini')
  );

  if (StartupGeminiOptions.Value = nil) then
    SafeWriteLn('[WARN] Gemini options não carregadas (seção Gemini).')
  else
  begin
    if Trim(StartupGeminiOptions.Value.ApiKey) = '' then
      SafeWriteLn('[WARN] Gemini.ApiKey não configurada em appsettings.yml');
    if Trim(StartupGeminiOptions.Value.Model) = '' then
      SafeWriteLn('[WARN] Gemini.Model não configurado em appsettings.yml');
  end;

  Services
    .AddTransient<IList<TGeminiPart>, TList<TGeminiPart>>
    .AddTransient<IList<TGeminiContent>, TList<TGeminiContent>>
    .AddTransient<IList<TGeminiCandidate>, TList<TGeminiCandidate>>
    .AddTransient<IList<TGeminiTokenDetail>, TList<TGeminiTokenDetail>>;

  App.Builder
    .UseDeveloperExceptionPage
    .UseHttpLogging
    .UseStaticFiles('wwwroot')

    // Rota da API: Integração com Gemini
    .MapPost<TChatRequest, IOptions<TGeminiOptions>, IResult>('/ia/ask',
      function(Req: TChatRequest; GeminiOptions: IOptions<TGeminiOptions>): IResult
      begin
        var Opts := GeminiOptions.Value;
        if (Opts = nil) or (Trim(Opts.ApiKey) = '') then
          Exit(Results.Problem('Gemini.ApiKey não configurada em appsettings.yml'));
        if Trim(Opts.Model) = '' then
          Exit(Results.Problem('Gemini.Model não configurado em appsettings.yml'));

        var AgentModelUrl :=
          'https://generativelanguage.googleapis.com/v1/models/' + Opts.Model +
          ':generateContent?key=' + Opts.ApiKey;

        var GeminiRequest := TGeminiRequest.Create(Req.pergunta);
        var Payload := TDextJson.Serialize(GeminiRequest);

        var Response := RestClient(AgentModelUrl)
          .PostJson(Payload)
          .Await;

        if Response.StatusCode = HttpStatus.OK then
        begin
          try
            var GeminiResponse := TDextJson.Deserialize<TGeminiResponse>(Response.ContentString);
            if GeminiResponse.HasContent then
            begin
              var ChatResponse: TChatResponse;
              ChatResponse.resposta := GeminiResponse.FirstText;
              Result := Results.Ok(ChatResponse);
            end
            else
              Result := Results.Problem('A IA não retornou uma estrutura de resposta válida.');
          except
            on E: Exception do
              Result := Results.Problem('Erro ao processar a resposta da IA: ' + E.ClassName + ': ' + E.Message);
          end;
        end
        else
        begin
          var ErrorMessage := 'Erro "' + Response.StatusCode.ToString + '" na API do Gemini.';
          try
            var ErrorResponse := TDextJson.Deserialize<TGeminiErrorResponse>(Response.ContentString);
            if (ErrorResponse.error.message <> '') then
              ErrorMessage := ErrorResponse.error.message;
          except
            on E: Exception do
              SafeWriteLn('Error parsing error response: ' + E.Message);
          end;
          Result := Results.Problem(ErrorMessage);
        end;
      end);

  // Inicia o servidor na porta 8080 (Padrão)
  App.Run;
end.






