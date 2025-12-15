# Swagger Attributes - Guia Completo

Este documento descreve todos os atributos customizados disponíveis para controlar a documentação Swagger/OpenAPI gerada pelo Dext Framework.

## 📋 Índice

- [Atributos de Tipo](#atributos-de-tipo)
- [Atributos de Campo/Propriedade](#atributos-de-campopropriedade)
- [Exemplos Práticos](#exemplos-práticos)

## Atributos de Tipo

Estes atributos são aplicados a records e classes para customizar o schema gerado.

### `[SwaggerSchema]`

Customiza a descrição do schema de um tipo.

**Sintaxe:**
```pascal
[SwaggerSchema(Title: string)]
[SwaggerSchema(Title, Description: string)]
```

**Exemplo:**
```pascal
[SwaggerSchema('User', 'Represents a user in the system')]
TUser = record
  Id: Integer;
  Name: string;
end;
```

**Resultado no OpenAPI:**
```json
{
  "type": "object",
  "description": "Represents a user in the system",
  "properties": { ... }
}
```

---

## Atributos de Campo/Propriedade

Estes atributos são aplicados a campos de records ou propriedades de classes.

### `[SwaggerProperty]`

Adiciona uma descrição a um campo/propriedade.

**Sintaxe:**
```pascal
[SwaggerProperty(Description: string)]
[SwaggerProperty(Name, Description: string)]
```

**Exemplo:**
```pascal
TUser = record
  [SwaggerProperty('Unique identifier for the user')]
  Id: Integer;
  
  [SwaggerProperty('Full name of the user')]
  Name: string;
end;
```

**Resultado no OpenAPI:**
```json
{
  "properties": {
    "Id": {
      "type": "integer",
      "description": "Unique identifier for the user"
    },
    "Name": {
      "type": "string",
      "description": "Full name of the user"
    }
  }
}
```

---

### `[SwaggerFormat]`

Especifica o formato de um campo (e.g., 'email', 'uri', 'uuid', 'password', 'date-time').

**Sintaxe:**
```pascal
[SwaggerFormat(Format: string)]
```

**Exemplo:**
```pascal
TUser = record
  [SwaggerFormat('email')]
  Email: string;
  
  [SwaggerFormat('date-time')]
  CreatedAt: TDateTime;
  
  [SwaggerFormat('uuid')]
  Token: string;
end;
```

**Resultado no OpenAPI:**
```json
{
  "properties": {
    "Email": {
      "type": "string",
      "format": "email"
    },
    "CreatedAt": {
      "type": "number",
      "format": "date-time"
    },
    "Token": {
      "type": "string",
      "format": "uuid"
    }
  }
}
```

---

### `[SwaggerExample]`

Adiciona um exemplo de valor ao campo.

**Sintaxe:**
```pascal
[SwaggerExample(Value: string)]
```

**Exemplo:**
```pascal
TUser = record
  [SwaggerExample('1')]
  Id: Integer;
  
  [SwaggerExample('John Doe')]
  Name: string;
  
  [SwaggerExample('john@example.com')]
  Email: string;
end;
```

**Resultado no OpenAPI:**
```json
{
  "properties": {
    "Id": {
      "type": "integer",
      "description": "(Example: 1)"
    },
    "Name": {
      "type": "string",
      "description": "(Example: John Doe)"
    },
    "Email": {
      "type": "string",
      "description": "(Example: john@example.com)"
    }
  }
}
```

---

### `[SwaggerRequired]`

Marca um campo como obrigatório no schema.

**Sintaxe:**
```pascal
[SwaggerRequired]
```

**Exemplo:**
```pascal
TCreateUserRequest = record
  [SwaggerRequired]
  Name: string;
  
  [SwaggerRequired]
  Email: string;
  
  Password: string;  // Opcional
end;
```

**Resultado no OpenAPI:**
```json
{
  "type": "object",
  "required": ["Name", "Email"],
  "properties": { ... }
}
```

---

### `[SwaggerIgnoreProperty]`

Exclui um campo/propriedade do schema gerado.

**Sintaxe:**
```pascal
[SwaggerIgnoreProperty]
```

**Exemplo:**
```pascal
TUser = record
  Id: Integer;
  Name: string;
  
  [SwaggerIgnoreProperty]
  InternalData: string;  // Não aparecerá no schema
end;
```

**Resultado no OpenAPI:**
```json
{
  "properties": {
    "Id": { "type": "integer" },
    "Name": { "type": "string" }
    // InternalData não aparece
  }
}
```

---

## Exemplos Práticos

### Exemplo 1: User Model Completo

```pascal
[SwaggerSchema('User', 'Represents a user in the system')]
TUser = record
  [SwaggerProperty('Unique identifier')]
  [SwaggerExample('123')]
  Id: Integer;
  
  [SwaggerProperty('Full name of the user')]
  [SwaggerExample('John Doe')]
  Name: string;
  
  [SwaggerProperty('Email address')]
  [SwaggerFormat('email')]
  [SwaggerExample('john@example.com')]
  Email: string;
  
  [SwaggerProperty('User role')]
  [SwaggerExample('admin')]
  Role: string;
  
  [SwaggerProperty('Account creation date')]
  [SwaggerFormat('date-time')]
  CreatedAt: TDateTime;
  
  [SwaggerIgnoreProperty]
  PasswordHash: string;  // Nunca expor no schema
end;
```

### Exemplo 2: Create Request com Validação

```pascal
[SwaggerSchema('Create User Request', 'Request body for creating a new user')]
TCreateUserRequest = record
  [SwaggerProperty('Full name of the user')]
  [SwaggerRequired]
  [SwaggerExample('Jane Smith')]
  Name: string;
  
  [SwaggerProperty('Email address')]
  [SwaggerFormat('email')]
  [SwaggerRequired]
  [SwaggerExample('jane@example.com')]
  Email: string;
  
  [SwaggerProperty('User password (min 8 characters)')]
  [SwaggerFormat('password')]
  [SwaggerRequired]
  Password: string;
  
  [SwaggerProperty('User role (optional)')]
  [SwaggerExample('user')]
  Role: string;
end;
```

### Exemplo 3: Product com Preço

```pascal
[SwaggerSchema('Product', 'Represents a product in the catalog')]
TProduct = record
  [SwaggerProperty('Unique product identifier')]
  [SwaggerExample('1')]
  Id: Integer;
  
  [SwaggerProperty('Product name')]
  [SwaggerRequired]
  [SwaggerExample('Laptop')]
  Name: string;
  
  [SwaggerProperty('Product description')]
  [SwaggerExample('High-performance laptop')]
  Description: string;
  
  [SwaggerProperty('Price in USD')]
  [SwaggerRequired]
  [SwaggerExample('999.99')]
  Price: Double;
  
  [SwaggerProperty('Stock quantity')]
  [SwaggerExample('50')]
  Stock: Integer;
  
  [SwaggerProperty('Whether the product is available')]
  InStock: Boolean;
  
  [SwaggerProperty('Product SKU')]
  [SwaggerExample('LAP-001')]
  SKU: string;
end;
```

### Exemplo 4: Nested Objects

```pascal
[SwaggerSchema('Address', 'Physical address')]
TAddress = record
  [SwaggerProperty('Street address')]
  [SwaggerRequired]
  Street: string;
  
  [SwaggerProperty('City')]
  [SwaggerRequired]
  City: string;
  
  [SwaggerProperty('ZIP/Postal code')]
  [SwaggerFormat('zip')]
  ZipCode: string;
end;

[SwaggerSchema('User with Address', 'User with complete address information')]
TUserWithAddress = record
  [SwaggerProperty('User ID')]
  Id: Integer;
  
  [SwaggerProperty('User name')]
  Name: string;
  
  [SwaggerProperty('User address')]
  Address: TAddress;  // Nested object
end;
```

## 🎯 Melhores Práticas

1. **Sempre adicione descrições** - Use `[SwaggerProperty]` para documentar cada campo
2. **Use formatos apropriados** - `email`, `uri`, `uuid`, `date-time`, `password`
3. **Marque campos obrigatórios** - Use `[SwaggerRequired]` para validação
4. **Adicione exemplos** - Use `[SwaggerExample]` para facilitar testes
5. **Oculte dados sensíveis** - Use `[SwaggerIgnoreProperty]` para passwords, tokens, etc.
6. **Documente schemas** - Use `[SwaggerSchema]` para descrever o propósito do tipo

## 📚 Formatos Comuns

| Formato | Descrição | Exemplo |
|---------|-----------|---------|
| `email` | Endereço de email | `user@example.com` |
| `uri` | URI/URL | `https://example.com` |
| `uuid` | UUID v4 | `550e8400-e29b-41d4-a716-446655440000` |
| `date` | Data (ISO 8601) | `2025-01-15` |
| `date-time` | Data e hora (ISO 8601) | `2025-01-15T10:30:00Z` |
| `time` | Hora | `10:30:00` |
| `password` | Senha (oculta na UI) | `********` |
| `byte` | Base64 encoded | `U3dhZ2dlciByb2Nrcw==` |
| `binary` | Dados binários | - |
| `int32` | Integer 32-bit | `2147483647` |
| `int64` | Integer 64-bit | `9223372036854775807` |
| `float` | Float | `3.14` |
| `double` | Double | `3.141592653589793` |

## 🔄 Atributos Futuros (Planejados)

Os seguintes atributos estão planejados para versões futuras:

- `[SwaggerIgnore]` - Ignorar endpoint inteiro
- `[SwaggerOperation]` - Customizar operação
- `[SwaggerResponse]` - Definir respostas customizadas
- `[SwaggerTag]` - Adicionar tags a endpoints
- `[SwaggerDeprecated]` - Marcar como deprecated
- `[SwaggerMinLength]` / `[SwaggerMaxLength]` - Validação de string
- `[SwaggerMinimum]` / `[SwaggerMaximum]` - Validação de número
- `[SwaggerPattern]` - Regex pattern para validação

## 💡 Dicas

- Combine múltiplos atributos para documentação completa
- Use exemplos realistas para facilitar testes
- Mantenha descrições concisas mas informativas
- Revise a documentação gerada no Swagger UI
- Atualize atributos quando mudar a API

---

**Documentação gerada para Dext Framework v1.0**
