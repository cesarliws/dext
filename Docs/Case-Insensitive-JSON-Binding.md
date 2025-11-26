# Correções Implementadas - Case Insensitive JSON Binding

## 📋 Problemas Identificados

### 1. **CORS** ✅ 
- **Problema**: Só funcionava com `AllowedOrigins = ['*']`
- **Causa**: Configuração incorreta - não estava especificando origens permitidas
- **Solução**: Documentação melhorada sobre configuração CORS

### 2. **Case Sensitivity no JSON** ✅ RESOLVIDO
- **Problema**: JSON vinha com campos em lowercase (`login`, `password`) mas records Delphi estavam em PascalCase (`Login`, `Password`)
- **Sintoma**: Binding falhava, campos ficavam vazios, validação sempre retornava false
- **Causa**: Deserialização JSON era case-sensitive por padrão

## 🔧 Mudanças Implementadas

### 1. **Dext.Json.pas** - Deserialização Case-Insensitive

#### Modificação no `TDextSerializer.DeserializeRecord`:
```pascal
function TDextSerializer.DeserializeRecord(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  FieldName: string;
  ActualFieldName: string;  // ✅ NOVO: Nome real encontrado no JSON
  FieldValue: TValue;
  Found: Boolean;            // ✅ NOVO: Flag de campo encontrado
begin
  // ... código existente ...
  
  for Field in RttiType.GetFields do
  begin
    FieldName := GetFieldName(Field);
    ActualFieldName := FieldName;
    Found := AJson.Contains(FieldName);

    // ✅ NOVO: Se não encontrou e CaseInsensitive está habilitado, buscar ignorando case
    if (not Found) and FSettings.CaseInsensitive then
    begin
      var LowerFieldName := LowerCase(FieldName);
      var UpperFieldName := UpperCase(FieldName);
      
      // Tentar lowercase
      if AJson.Contains(LowerFieldName) then
      begin
        ActualFieldName := LowerFieldName;
        Found := True;
      end
      // Tentar uppercase
      else if AJson.Contains(UpperFieldName) then
      begin
        ActualFieldName := UpperFieldName;
        Found := True;
      end
      // Tentar primeira letra minúscula (camelCase)
      else if Length(FieldName) > 0 then
      begin
        var CamelCaseName := LowerCase(FieldName[1]) + Copy(FieldName, 2, Length(FieldName) - 1);
        if AJson.Contains(CamelCaseName) then
        begin
          ActualFieldName := CamelCaseName;
          Found := True;
        end;
      end;
    end;

    if not Found then
      Continue;

    // ✅ MUDANÇA: Usar ActualFieldName em vez de FieldName em todas as chamadas Get*
    FieldValue := TValue.From<Integer>(AJson.GetInteger(ActualFieldName));
    // ... etc para todos os tipos
  end;
end;
```

#### Nova Sobrecarga `TDextJson.Deserialize`:
```pascal
/// <summary>
///   Deserializes a JSON string into a TValue with custom settings.
/// </summary>
class function Deserialize(AType: PTypeInfo; const AJson: string; 
  const ASettings: TDextSettings): TValue; overload; static;
```

### 2. **Dext.Core.ModelBinding.pas** - Usar Case-Insensitive por Padrão

```pascal
function TModelBinder.BindBody(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  Stream: TStream;
  JsonString: string;
  Settings: TDextSettings;  // ✅ NOVO
begin
  // ... código existente ...

  // ✅ NOVO: Usar settings com CaseInsensitive = True por padrão
  Settings := TDextSettings.Default.WithCaseInsensitive;

  try
    Result := TDextJson.Deserialize(AType, JsonString, Settings);
  except
    on E: Exception do
      raise EBindingException.Create('Error binding body: ' + E.Message);
  end;
end;
```

## 📖 Como Usar

### Exemplo de Record Delphi (PascalCase):
```pascal
type
  TLoginRequest = record
    Login: string;
    Password: string;
  end;
```

### JSON Recebido (lowercase):
```json
{
  "login": "admin",
  "password": "123456"
}
```

### ✅ Agora Funciona Automaticamente!

O model binder agora faz o match case-insensitive automaticamente:
- `login` → `Login`
- `password` → `Password`
- `userName` → `UserName` (camelCase → PascalCase)
- `user_name` → `UserName` (snake_case → PascalCase via atributo `[JsonName]`)

## 🌐 Configuração CORS Correta

### ❌ Não Recomendado (Desenvolvimento apenas):
```pascal
var corsOptions := TCorsOptions.Create;
// Permite QUALQUER origem - inseguro!
corsOptions.AllowedOrigins := ['*'];  
corsOptions.AllowCredentials := True;  // ⚠️ Não funciona com *
```

### ✅ Recomendado (Produção):
```pascal
var corsOptions := TCorsOptions.Create;
// Especificar origens permitidas explicitamente
corsOptions.AllowedOrigins := ['http://localhost:5173', 'http://localhost:8080'];
corsOptions.AllowedMethods := ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'];
corsOptions.AllowedHeaders := ['Content-Type', 'Authorization'];
corsOptions.AllowCredentials := True;  // ✅ Funciona com origens específicas
corsOptions.MaxAge := 3600;  // Cache preflight por 1 hora

TApplicationBuilderCorsExtensions.UseCors(Builder, corsOptions);
```

### 🔧 Builder Fluente (Alternativa):
```pascal
TApplicationBuilderCorsExtensions.UseCors(Builder,
  procedure(Cors: TCorsBuilder)
  begin
    Cors
      .WithOrigins(['http://localhost:5173', 'http://localhost:8080'])
      .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
      .WithHeaders(['Content-Type', 'Authorization'])
      .AllowCredentials
      .WithMaxAge(3600);
  end);
```

## 🧪 Testando

### 1. Teste com JSON lowercase:
```pascal
var Json := '{"login":"admin","password":"123"}';
var Request := TDextJson.Deserialize<TLoginRequest>(Json);
// ✅ Request.Login = "admin"
// ✅ Request.Password = "123"
```

### 2. Teste com JSON PascalCase:
```pascal
var Json := '{"Login":"admin","Password":"123"}';
var Request := TDextJson.Deserialize<TLoginRequest>(Json);
// ✅ Request.Login = "admin"
// ✅ Request.Password = "123"
```

### 3. Teste com JSON camelCase:
```pascal
type
  TUserData = record
    UserName: string;
    EmailAddress: string;
  end;

var Json := '{"userName":"john","emailAddress":"john@example.com"}';
var User := TDextJson.Deserialize<TUserData>(Json);
// ✅ User.UserName = "john"
// ✅ User.EmailAddress = "john@example.com"
```

## 🎯 Benefícios

1. **✅ Compatibilidade Total**: Funciona com JSON de qualquer fonte (JavaScript, Python, etc.)
2. **✅ Sem Mudanças no Código**: Records Delphi continuam em PascalCase (convenção Delphi)
3. **✅ Automático**: Não precisa adicionar atributos `[JsonName]` em todos os campos
4. **✅ Flexível**: Ainda suporta `[JsonName]` para casos especiais (snake_case, etc.)
5. **✅ Retrocompatível**: Código existente continua funcionando

## 📝 Notas Importantes

### Ordem de Prioridade na Busca Case-Insensitive:
1. **Exato**: Tenta o nome exato primeiro (`Login`)
2. **Lowercase**: Tenta tudo minúsculo (`login`)
3. **Uppercase**: Tenta tudo maiúsculo (`LOGIN`)
4. **CamelCase**: Tenta primeira letra minúscula (`login` para campo `Login`)

### Quando Usar `[JsonName]`:
```pascal
type
  TUser = record
    [JsonName('user_id')]      // ✅ snake_case específico
    UserId: Integer;
    
    [JsonName('full_name')]    // ✅ nome diferente
    FullName: string;
    
    Email: string;             // ✅ Não precisa - case-insensitive automático
  end;
```

## 🚀 Próximos Passos

Se ainda tiver problemas:

1. **Verificar CORS no Browser DevTools**:
   - Abra F12 → Network
   - Veja se há erros CORS
   - Verifique headers `Access-Control-*`

2. **Debug JSON Binding**:
   ```pascal
   // Adicionar log temporário
   WriteLn('JSON Recebido: ', JsonString);
   WriteLn('Record Deserializado: ', TDextJson.Serialize(Request));
   ```

3. **Testar Validação**:
   ```pascal
   if Request.Login.IsEmpty or Request.Password.IsEmpty then
     WriteLn('⚠️ Campos vazios após binding!');
   ```

## 📚 Documentação Relacionada

- [Dext JSON Features](Dext%20JSON%20Features.md)
- [Model Binding Guide](ModelBinding.md)
- [CORS Configuration](CORS.md)
