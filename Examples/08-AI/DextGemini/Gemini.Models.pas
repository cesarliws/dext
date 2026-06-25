unit Gemini.Models;

interface

uses
  Dext.Json.Types,
  Dext.Core.Activator,
  Dext.Collections,
  Dext.Validation;

type
  TGeminiOptions = class
  private
    FApiKey: string;
    FModel: string;
  published
    property ApiKey: string read FApiKey write FApiKey;
    property Model: string read FModel write FModel;
  end;

  // ---------------------------------------------------------------------------
  // Request models
  // ---------------------------------------------------------------------------
  TGeminiPart = record
  public
    text: string;
  end;

  TGeminiContent = record
  public
    parts: IList<TGeminiPart>;
    role: string;
    class function Create(const AText: string; const ARole: string = ''): TGeminiContent; static;
  end;

  TGeminiRequest = record
  public
    contents: IList<TGeminiContent>;
    class function Create(const AQuestion: string): TGeminiRequest; static;
  end;

  // ---------------------------------------------------------------------------
  // Response models - successful (200 OK)
  // ---------------------------------------------------------------------------

  TGeminiCandidate = record
  public
    content: TGeminiContent;
    finishReason: string;
    index: Integer;
  end;

  TGeminiTokenDetail = record
  public
    modality: string;
    tokenCount: Integer;
  end;

  TGeminiUsageMetadata = record
  public
    promptTokenCount: Integer;
    candidatesTokenCount: Integer;
    totalTokenCount: Integer;
    thoughtsTokenCount: Integer;
    promptTokensDetails: IList<TGeminiTokenDetail>;
  end;

  TGeminiResponse = record
  public
    candidates: IList<TGeminiCandidate>;
    usageMetadata: TGeminiUsageMetadata;
    modelVersion: string;
    responseId: string;

    function HasContent: Boolean;
    function FirstText: string;
  end;

  // ---------------------------------------------------------------------------
  // Response models - API error body
  // ---------------------------------------------------------------------------

  TGeminiErrorDetail = record
  public
    code: Integer;
    message: string;
    status: string;
  end;

  TGeminiErrorResponse = record
  public
    error: TGeminiErrorDetail;
  end;

  // ---------------------------------------------------------------------------
  // Client-facing DTOs
  // ---------------------------------------------------------------------------
  TChatRequest = record
  public
    [Required]
    pergunta: string;
  end;

  TChatResponse = record
  public
    resposta: string;
  end;

implementation

{ TGeminiContent }

class function TGeminiContent.Create(const AText: string; const ARole: string): TGeminiContent;
begin
  Result.parts := TCollections.CreateList<TGeminiPart>;
  var Part: TGeminiPart;
  Part.text := AText;
  Result.parts.Add(Part);
  Result.role := ARole;
end;

{ TGeminiRequest }

class function TGeminiRequest.Create(const AQuestion: string): TGeminiRequest;
begin
  Result.contents := TCollections.CreateList<TGeminiContent>;
  Result.contents.Add(TGeminiContent.Create(AQuestion));
end;

{ TGeminiResponse }

function TGeminiResponse.HasContent: Boolean;
begin
  Result := Assigned(candidates) and (candidates.Count > 0) and
    Assigned(candidates[0].content.parts) and (candidates[0].content.parts.Count > 0);
end;

function TGeminiResponse.FirstText: string;
begin
  if HasContent then
    Result := candidates[0].content.parts[0].text
  else
    Result := '';
end;

end.
