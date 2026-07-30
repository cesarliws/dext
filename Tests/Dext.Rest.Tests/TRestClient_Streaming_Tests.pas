{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
unit TRestClient_Streaming_Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Testing.Fluent,
  System.IOUtils,
  Dext.Net.Download,
  Dext.Net.RestClient,
  Dext.Net.RestRequest,
  Dext.Web,
  Dext.Web.Interfaces;

type
  [TestFixture('TRestClient streaming download (S58)')]
  TDextDownloadGateTests = class
  public
    [Test]
    procedure ClosedGate_ShouldLeaveTargetUntouched;
    [Test]
    procedure Open_ShouldFlushBufferedBytesThenForward;
    [Test]
    procedure Resume_ShouldHonourTargetPosition;
    [Test]
    procedure Replay_ShouldNotDropPreExistingBytes;
    [Test]
    procedure ErrorPayload_ShouldBeCapped;
    [Test]
    procedure EmptySuccess_ShouldWriteNothing;

    // --- la superficie pubblica del client ---
    [Test]
    procedure ExecuteIntoAsync_ShouldRejectANilTarget;
    [Test]
    procedure OnReceive_ShouldBeStoredOnTheClient;
    [Test]
    procedure OnReceive_OnTheRequest_ShouldReplaceTheClientOne;
  end;

  /// <summary>
  ///   I tre test del capitolo 5.1 della spec, contro un server VERO acceso
  ///   in-process. Sono di integrazione: qui non si controlla una firma, si
  ///   controlla che 50 MB passino senza gonfiare la memoria, che il progresso
  ///   arrivi a pezzi e che un abort a meta' si faccia sentire.
  /// </summary>
  [TestFixture('TRestClient streaming download -- end to end (S58 5.1)')]
  TRestClientStreamingTests = class
  public
    [Test]
    procedure Test_GetInto_StreamingToFile;
    [Test]
    procedure Test_OnReceive_ProgressEvents;
    [Test]
    procedure Test_OnReceive_Abort;

    // --- DownloadToFile ---
    [Test]
    procedure DownloadToFile_ShouldOnlyNameTheFileWhenItIsWhole;
    [Test]
    procedure DownloadToFile_ShouldRefuseAnExistingTargetWithoutOverwrite;
    [Test]
    procedure DownloadToFile_ShouldNotLetTheServerEscapeTheDirectory;
  end;

implementation

type
  /// Stesso accesso al campo privato usato da Tests\Web (TTRestRequestHack):
  /// il builder e' un record che tiene lo stato in un'interfaccia.
  TRestRequestPeek = record
    Data: IRestRequestData;
  end;

function TextOf(AStream: TMemoryStream): string;
var
  Bytes: TBytes;
begin
  SetLength(Bytes, AStream.Size);
  if AStream.Size > 0 then
    Move(AStream.Memory^, Bytes[0], AStream.Size);
  Result := TEncoding.UTF8.GetString(Bytes);
end;

procedure WriteText(AStream: TStream; const AText: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AText);
  AStream.WriteBuffer(Bytes[0], Length(Bytes));
end;

{ TDextDownloadGateTests }

/// The 404 case: what the server said must not end up in the caller's file.
procedure TDextDownloadGateTests.ClosedGate_ShouldLeaveTargetUntouched;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  Gate := TDextDownloadGate.Create(Target);
  try
    WriteText(Gate, '{"error":"not found"}');

    Should(Integer(Target.Size)).Be(0);
    Should(Gate.IsOpen).BeFalse;
    Should(Length(Gate.ErrorBytes)).Be(21);
    Should(Gate.ErrorTruncated).BeFalse;
  finally
    Gate.Free;
    Target.Free;
  end;
end;

/// Bytes that arrived before the status was known are not lost.
procedure TDextDownloadGateTests.Open_ShouldFlushBufferedBytesThenForward;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  Gate := TDextDownloadGate.Create(Target);
  try
    WriteText(Gate, 'HEAD');
    Should(Integer(Target.Size)).Be(0);

    Gate.Open;
    Should(Integer(Target.Size)).Be(4);

    WriteText(Gate, 'TAIL');
    Should(TextOf(Target)).Be('HEADTAIL');
  finally
    Gate.Free;
    Target.Free;
  end;
end;

/// A resumed download appends instead of overwriting.
procedure TDextDownloadGateTests.Resume_ShouldHonourTargetPosition;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  try
    WriteText(Target, 'ALREADY-ON-DISK:');
    Gate := TDextDownloadGate.Create(Target);
    try
      Gate.Open;
      WriteText(Gate, 'REST');

      Should(TextOf(Target)).Be('ALREADY-ON-DISK:REST');
      // Size is what THIS transfer wrote, not what the file holds.
      Should(Integer(Gate.Size)).Be(4);
    finally
      Gate.Free;
    end;
  finally
    Target.Free;
  end;
end;

/// What the RTL does when it replays a request after a redirect or an
/// authentication challenge: it rewinds the response stream. That rewind must
/// stop at the bytes the caller already had.
procedure TDextDownloadGateTests.Replay_ShouldNotDropPreExistingBytes;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  try
    WriteText(Target, 'ALREADY-ON-DISK:');
    Gate := TDextDownloadGate.Create(Target);
    try
      Gate.Open;
      WriteText(Gate, 'FIRST-ATTEMPT');

      Gate.Size := 0;
      Gate.Position := 0;
      Should(Integer(Target.Size)).Be(16);

      WriteText(Gate, 'AGAIN');
      Should(TextOf(Target)).Be('ALREADY-ON-DISK:AGAIN');
    finally
      Gate.Free;
    end;
  finally
    Target.Free;
  end;
end;

/// An error body is a message, not a payload: buffering it must have a ceiling.
procedure TDextDownloadGateTests.ErrorPayload_ShouldBeCapped;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
  Big: TBytes;
begin
  Target := TMemoryStream.Create;
  Gate := TDextDownloadGate.Create(Target, 100);
  try
    SetLength(Big, 250);
    FillChar(Big[0], Length(Big), Ord('x'));
    Gate.WriteBuffer(Big[0], Length(Big));

    Should(Length(Gate.ErrorBytes)).Be(100);
    Should(Gate.ErrorTruncated).BeTrue;
    Should(Integer(Target.Size)).Be(0);
  finally
    Gate.Free;
    Target.Free;
  end;
end;

/// A 2xx with no body never fires the engine's progress callback, so the gate
/// is opened on the status instead. That must not invent bytes.
procedure TDextDownloadGateTests.EmptySuccess_ShouldWriteNothing;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  Gate := TDextDownloadGate.Create(Target);
  try
    Gate.Open;

    Should(Integer(Target.Size)).Be(0);
    Should(Length(Gate.ErrorBytes)).Be(0);
  finally
    Gate.Free;
    Target.Free;
  end;
end;

/// Uno stream di destinazione non e' opzionale: senza, non c'e' streaming.
procedure TDextDownloadGateTests.ExecuteIntoAsync_ShouldRejectANilTarget;
var
  Client: TRestClient;
  Failed: Boolean;
begin
  Client := TRestClient.Create('http://localhost:1');
  Failed := False;
  try
    Client.Instance.ExecuteIntoAsync(hmGET, '/x', nil);
  except
    on E: EArgumentNilException do
      Failed := True;
  end;
  Should(Failed).BeTrue;
end;

/// L'handler globale si posa sul client e si rilegge da li'.
procedure TDextDownloadGateTests.OnReceive_ShouldBeStoredOnTheClient;
var
  Client: TRestClient;
begin
  Client := TRestClient.Create('http://localhost:1');
  Should(Assigned(Client.Instance.ReceiveHandler)).BeFalse;

  Client.OnReceive(
    procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
    begin
    end);

  Should(Assigned(Client.Instance.ReceiveHandler)).BeTrue;
end;

/// Quello di richiesta SOSTITUISCE quello del client: non si sommano, e il
/// globale resta al suo posto per le altre richieste.
procedure TDextDownloadGateTests.OnReceive_OnTheRequest_ShouldReplaceTheClientOne;
var
  Client: TRestClient;
  Req: TRestRequest;
  Chiamato: string;
  Abort: Boolean;
  Handler, Globale: TRestReceiveAnonEvent;
begin
  Chiamato := '';
  Client := TRestClient.Create('http://localhost:1');
  Client.OnReceive(
    procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
    begin
      Chiamato := 'client';
    end);

  Req := Client.Request(hmGET, '/x').OnReceive(
    procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
    begin
      Chiamato := 'richiesta';
    end);

  // Quello che verrebbe usato per QUESTA richiesta.
  Handler := TRestRequestPeek(Req).Data.GetReceiveHandler;
  Should(Assigned(Handler)).BeTrue;
  Abort := False;
  Handler(0, 0, Abort);
  Should(Chiamato).Be('richiesta');

  // Il globale non e' stato toccato.
  Chiamato := '';
  Globale := Client.Instance.ReceiveHandler;
  Globale(0, 0, Abort);
  Should(Chiamato).Be('client');
end;

{ TRestClientStreamingTests }

const
  /// 50 MB come chiede la spec, serviti a blocchi da 1 MB: cosi' nemmeno il
  /// server tiene in RAM l'intero corpo, e il test misura il CLIENT.
  DIM_BLOCCO = 1024 * 1024;
  BLOCCHI = 50;
  TOTALE = Int64(DIM_BLOCCO) * BLOCCHI;

/// Memoria allocata adesso, secondo il memory manager. Serve a dire se il
/// download e' passato PER la RAM o ATTRAVERSO di essa.
function MemoriaAllocata: Int64;
var
  Stato: TMemoryManagerState;
  I: Integer;
begin
  GetMemoryManagerState(Stato);
  Result := 0;
  for I := 0 to High(Stato.SmallBlockTypeStates) do
    Inc(Result, Int64(Stato.SmallBlockTypeStates[I].AllocatedBlockCount) *
      Stato.SmallBlockTypeStates[I].UseableBlockSize);
  Inc(Result, Int64(Stato.TotalAllocatedMediumBlockSize));
  Inc(Result, Int64(Stato.TotalAllocatedLargeBlockSize));
end;

/// Accende un server che serve /grande con TOTALE byte e Content-Length
/// dichiarata (senza, il progresso non avrebbe un totale da riportare).
function AccendiServer(out AHost: IWebHost): string;
var
  Builder: IWebHostBuilder;
  Blocco: TBytes;
  I: Integer;
begin
  SetLength(Blocco, DIM_BLOCCO);
  for I := 0 to High(Blocco) do
    Blocco[I] := Byte(I mod 251); // 251: primo, cosi' il motivo non si allinea ai blocchi

  Builder := TWebHost.CreateDefaultBuilder.UseUrls('http://127.0.0.1:0');
  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/grande',
        procedure(Ctx: IHttpContext)
        var
          N: Integer;
        begin
          Ctx.Response.SetContentType('application/octet-stream');
          Ctx.Response.SetContentLength(TOTALE);
          for N := 1 to BLOCCHI do
            Ctx.Response.Write(Blocco);
        end);
    end);

  AHost := Builder.Build;
  AHost.Start;
  Result := 'http://localhost:' + AHost.Port.ToString;
end;

/// 50 MB su file, e la memoria del processo che non se ne accorge.
procedure TRestClientStreamingTests.Test_GetInto_StreamingToFile;
var
  Host: IWebHost;
  BaseUrl, Percorso: string;
  Target: TFileStream;
  Resp: IRestResponse;
  Prima, Dopo: Int64;
begin
  BaseUrl := AccendiServer(Host);
  Percorso := TPath.Combine(TPath.GetTempPath, 'dext_s58_grande.bin');
  try
    Target := TFileStream.Create(Percorso, fmCreate);
    try
      Prima := MemoriaAllocata;
      Resp := RestClient(BaseUrl).GetInto('/grande', Target).Await;
      Dopo := MemoriaAllocata;
    finally
      Target.Free;
    end;

    Should(Resp.StatusCode).Be(200);
    Should(Integer(TFile.GetSize(Percorso))).Be(Integer(TOTALE));
    // Il corpo NON e' nella risposta: e' nel file del chiamante.
    Should(Assigned(Resp.ContentStream)).BeFalse;
    Should(Resp.ContentString).BeEmpty;
    // La soglia della spec: 5 MB di crescita su 50 MB scaricati.
    Should((Dopo - Prima) < 5 * 1024 * 1024).BeTrue;
  finally
    Host.Stop;
    if TFile.Exists(Percorso) then
      TFile.Delete(Percorso);
  end;
end;

/// Il progresso deve arrivare a pezzi, crescere, e finire sul totale.
procedure TRestClientStreamingTests.Test_OnReceive_ProgressEvents;
var
  Host: IWebHost;
  BaseUrl: string;
  Target: TMemoryStream;
  Resp: IRestResponse;
  Chiamate: Integer;
  UltimoLetto, TotaleVisto: Int64;
  Crescente: Boolean;
  Progresso: TRestReceiveAnonEvent;
begin
  BaseUrl := AccendiServer(Host);
  Chiamate := 0;
  UltimoLetto := 0;
  TotaleVisto := 0;
  Crescente := True;
  try
    Target := TMemoryStream.Create;
    try
      Progresso :=
        procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
        begin
          Inc(Chiamate);
          if AReadCount < UltimoLetto then
            Crescente := False;
          UltimoLetto := AReadCount;
          TotaleVisto := AContentLength;
        end;
      Resp := RestClient(BaseUrl)
        .OnReceive(Progresso)
        .GetInto('/grande', Target)
        .Await;
    finally
      Target.Free;
    end;

    Should(Resp.StatusCode).Be(200);
    Should(Chiamate > 1).BeTrue;          // "a pezzi", non tutto insieme
    Should(Crescente).BeTrue;             // AReadCount non torna indietro
    Should(Integer(TotaleVisto)).Be(Integer(TOTALE));
    Should(Integer(UltimoLetto)).Be(Integer(TOTALE));
  finally
    Host.Stop;
  end;
end;

/// Abort a meta': deve fallire con EOperationCancelled, non "riuscire a meta'".
procedure TRestClientStreamingTests.Test_OnReceive_Abort;
var
  Host: IWebHost;
  BaseUrl: string;
  Target: TMemoryStream;
  Cancellato: Boolean;
  Scaricato: Int64;
  Progresso: TRestReceiveAnonEvent;
begin
  BaseUrl := AccendiServer(Host);
  Cancellato := False;
  Scaricato := 0;
  try
    Target := TMemoryStream.Create;
    try
      try
        Progresso :=
          procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
          begin
            if AReadCount > (TOTALE div 2) then
              AAbort := True;
          end;
        RestClient(BaseUrl)
          .Request(hmGET, '/grande')
          .OnReceive(Progresso)
          .ExecuteInto(Target)
          .Await;
      except
        on E: EOperationCancelled do
          Cancellato := True;
      end;
      Scaricato := Target.Size;
    finally
      Target.Free;
    end;

    Should(Cancellato).BeTrue;
    // Si e' fermato: il corpo intero NON c'e'.
    Should(Scaricato < TOTALE).BeTrue;
  finally
    Host.Stop;
  end;
end;

/// Il nome definitivo arriva SOLO a scaricamento finito, e il .part sparisce.
procedure TRestClientStreamingTests.DownloadToFile_ShouldOnlyNameTheFileWhenItIsWhole;
var
  Host: IWebHost;
  BaseUrl, Cartella, Percorso: string;
  Resp: IRestResponse;
begin
  BaseUrl := AccendiServer(Host);
  Cartella := TPath.Combine(TPath.GetTempPath, 'dext_s58_dl');
  Percorso := TPath.Combine(Cartella, 'scaricato.bin');
  try
    Resp := RestClient(BaseUrl).DownloadToFile('/grande', Percorso).Await;

    Should(Resp.StatusCode).Be(200);
    Should(TFile.Exists(Percorso)).BeTrue;
    Should(Integer(TFile.GetSize(Percorso))).Be(Integer(TOTALE));
    // Nessun residuo: o e' intero col suo nome, o non c'e'.
    Should(TFile.Exists(Percorso + '.part')).BeFalse;
  finally
    Host.Stop;
    if TDirectory.Exists(Cartella) then
      TDirectory.Delete(Cartella, True);
  end;
end;

/// Una destinazione che esiste gia' non si sovrascrive per sbaglio -- e lo si
/// scopre PRIMA di scaricare, non dopo.
procedure TRestClientStreamingTests.DownloadToFile_ShouldRefuseAnExistingTargetWithoutOverwrite;
var
  Host: IWebHost;
  BaseUrl, Cartella, Percorso: string;
  Rifiutato: Boolean;
begin
  BaseUrl := AccendiServer(Host);
  Cartella := TPath.Combine(TPath.GetTempPath, 'dext_s58_dl2');
  Percorso := TPath.Combine(Cartella, 'gia_qui.bin');
  Rifiutato := False;
  try
    TDirectory.CreateDirectory(Cartella);
    TFile.WriteAllText(Percorso, 'roba mia');

    try
      RestClient(BaseUrl).DownloadToFile('/grande', Percorso).Await;
    except
      on E: EInOutError do
        Rifiutato := True;
    end;

    Should(Rifiutato).BeTrue;
    // E il file di prima e' ancora il suo.
    Should(TFile.ReadAllText(Percorso)).Be('roba mia');
  finally
    Host.Stop;
    if TDirectory.Exists(Cartella) then
      TDirectory.Delete(Cartella, True);
  end;
end;

/// Il nome lo puo' scegliere il server, la CARTELLA no: un
/// Content-Disposition ostile non deve scrivere fuori dalla destinazione.
procedure TRestClientStreamingTests.DownloadToFile_ShouldNotLetTheServerEscapeTheDirectory;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  BaseUrl, Cartella, Percorso, Fuori: string;
  Resp: IRestResponse;
begin
  Builder := TWebHost.CreateDefaultBuilder.UseUrls('http://127.0.0.1:0');
  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/ostile',
        procedure(Ctx: IHttpContext)
        begin
          Ctx.Response.SetContentType('application/octet-stream');
          // Il classico tentativo di risalita.
          Ctx.Response.AddHeader('Content-Disposition',
            'attachment; filename="..\..\preso.txt"');
          Ctx.Response.Write(TEncoding.ANSI.GetBytes('contenuto'));
        end);
    end);
  Host := Builder.Build;
  Host.Start;
  BaseUrl := 'http://localhost:' + Host.Port.ToString;

  Cartella := TPath.Combine(TPath.GetTempPath, 'dext_s58_dl3');
  Percorso := TPath.Combine(Cartella, 'atteso.bin');
  Fuori := TPath.Combine(TPath.GetTempPath, 'preso.txt');
  try
    if TFile.Exists(Fuori) then
      TFile.Delete(Fuori);

    Resp := RestClient(BaseUrl)
      .DownloadToFile('/ostile', Percorso, nil, [doUseContentDisposition]).Await;

    Should(Resp.StatusCode).Be(200);
    // Il file e' rimasto DENTRO la cartella di destinazione...
    Should(Length(TDirectory.GetFiles(Cartella))).Be(1);
    // ...e non e' finito due livelli piu' su.
    Should(TFile.Exists(Fuori)).BeFalse;
  finally
    Host.Stop;
    if TDirectory.Exists(Cartella) then
      TDirectory.Delete(Cartella, True);
    if TFile.Exists(Fuori) then
      TFile.Delete(Fuori);
  end;
end;

end.
