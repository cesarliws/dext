unit Dext.Auth.Middleware;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Http.Interfaces,
  Dext.Auth.JWT,
  Dext.Auth.Identity;

type
  /// <summary>
  ///   JWT Authentication middleware configuration.
  /// </summary>
  TJwtAuthenticationOptions = record
    SecretKey: string;
    Issuer: string;
    Audience: string;
    TokenPrefix: string; // e.g., "Bearer "
    
    class function Default(const ASecretKey: string): TJwtAuthenticationOptions; static;
  end;

  /// <summary>
  ///   Middleware that validates JWT tokens and populates the User principal.
  /// </summary>
  TJwtAuthenticationMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FOptions: TJwtAuthenticationOptions;
    FTokenHandler: TJwtTokenHandler;
    
    function ExtractToken(const AAuthHeader: string): string;
    function CreatePrincipal(const AClaims: TArray<TClaim>): IClaimsPrincipal;
  public
    constructor Create(const AOptions: TJwtAuthenticationOptions);
    destructor Destroy; override;
    
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
  end;

implementation

uses
  System.StrUtils;

{ TJwtAuthenticationOptions }

class function TJwtAuthenticationOptions.Default(const ASecretKey: string): TJwtAuthenticationOptions;
begin
  Result.SecretKey := ASecretKey;
  Result.Issuer := '';
  Result.Audience := '';
  Result.TokenPrefix := 'Bearer ';
end;

{ TJwtAuthenticationMiddleware }

constructor TJwtAuthenticationMiddleware.Create(const AOptions: TJwtAuthenticationOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FTokenHandler := TJwtTokenHandler.Create(
    AOptions.SecretKey,
    AOptions.Issuer,
    AOptions.Audience
  );
end;

destructor TJwtAuthenticationMiddleware.Destroy;
begin
  FTokenHandler.Free;
  inherited;
end;

function TJwtAuthenticationMiddleware.ExtractToken(const AAuthHeader: string): string;
begin
  WriteLn('AUTH: ExtractToken called with: ', AAuthHeader);
  Result := AAuthHeader;
  
  if FOptions.TokenPrefix <> '' then
  begin
    WriteLn('AUTH: Token prefix configured: ', FOptions.TokenPrefix);
    if StartsText(FOptions.TokenPrefix, AAuthHeader) then
    begin
      Result := Copy(AAuthHeader, Length(FOptions.TokenPrefix) + 1, MaxInt);
      WriteLn('AUTH: Extracted token (first 50 chars): ', Copy(Result, 1, 50));
    end
    else
    begin
      WriteLn('AUTH: Header does not start with expected prefix');
      Result := '';
    end;
  end;
end;

function TJwtAuthenticationMiddleware.CreatePrincipal(const AClaims: TArray<TClaim>): IClaimsPrincipal;
var
  UserName: string;
  Claim: TClaim;
  Identity: IIdentity;
begin
  // Extract username from claims (try 'name' first, then 'sub')
  UserName := '';
  for Claim in AClaims do
  begin
    if SameText(Claim.ClaimType, TClaimTypes.Name) then
    begin
      UserName := Claim.Value;
      Break;
    end;
  end;
  
  if UserName = '' then
  begin
    for Claim in AClaims do
    begin
      if SameText(Claim.ClaimType, TClaimTypes.NameIdentifier) then
      begin
        UserName := Claim.Value;
        Break;
      end;
    end;
  end;
  
  Identity := TClaimsIdentity.Create(UserName, 'JWT');
  Result := TClaimsPrincipal.Create(Identity, AClaims);
end;

procedure TJwtAuthenticationMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  AuthHeader: string;
  Token: string;
  ValidationResult: TJwtValidationResult;
  Principal: IClaimsPrincipal;
begin
  try
    WriteLn('AUTH: Middleware Invoke started');
    // Try to get Authorization header
    if AContext.Request.Headers.ContainsKey('Authorization') then
    begin
      AuthHeader := AContext.Request.Headers['Authorization'];
      WriteLn('AUTH: Header found');
      Token := ExtractToken(AuthHeader);
      
      if Token <> '' then
      begin
        // Validate token
        WriteLn('AUTH: Validating token...');
        ValidationResult := FTokenHandler.ValidateToken(Token);
        
        if ValidationResult.IsValid then
        begin
          // Create principal and set user
          Principal := CreatePrincipal(ValidationResult.Claims);
          AContext.User := Principal;
          
          WriteLn(Format('AUTH: User authenticated: %s', [Principal.Identity.Name]));
        end
        else
        begin
          WriteLn(Format('AUTH: Token validation failed: %s', [ValidationResult.ErrorMessage]));
        end;
      end;
    end
    else
    begin
      WriteLn('AUTH: No Authorization header found');
    end;
    
    // Continue pipeline
    ANext(AContext);
  except
    on E: Exception do
      WriteLn('AUTH: Exception in middleware: ', E.ClassName, ': ', E.Message);
  end;
end;

end.
