---
name: dext-validation
description: Declare validation rules on entities or build fluent custom validators in Dext — attributes, TAbstractValidator<T>, type-safe Smart Property binding, regular expression patterns, and web pipeline auto-validation.
---

# Dext Validation Engine

## Core Import

```pascal
uses
  Dext.Validation; // IValidator, IValidator<T>, TAbstractValidator<T>, TValidator, TValidationPatterns
```

---

## 1. Attribute-Based Validation

Decorate fields or properties directly on entity or model classes.

```pascal
type
  TUser = class
  private
    FName: string;
    FAge: Integer;
    FEmail: string;
  public
    [Required]
    [StringLength(3, 50)]
    property Name: string read FName write FName;

    [Range(18, 99)]
    property Age: Integer read FAge write FAge;

    [EmailAddress]
    property Email: string read FEmail write FEmail;
  end;
```

### Supported Attributes

| Attribute | Types | Description |
| --------- | ----- | ----------- |
| `[Required]` | String, Numeric | Field cannot be empty, zero, or null. |
| `[StringLength(min, max)]` | String | Limits string character count. |
| `[Range(min, max)]` | Integer, Double | Limits numeric boundaries. |
| `[EmailAddress]` | String | Validates email syntax. |

---

## 2. Fluent Validation API

For programmatic, dynamic, or localized validation rules. Inherit from `TAbstractValidator<T>` and call `RuleFor`.

```pascal
type
  TUserValidator = class(TAbstractValidator<TUser>)
  public
    constructor Create; override;
  end;

constructor TUserValidator.Create;
begin
  inherited Create;
  
  RuleFor('Name').Required.Length(3, 50);
  RuleFor('Email').EmailAddress;
  RuleFor('Age').Range(18, 99);
  
  // Custom Must validation
  RuleFor('Active', function(Model: TUser): TValue
    begin
      Result := Model.Active;
    end).Must(function(Val: TValue): Boolean
    begin
      Result := Val.AsBoolean;
    end).WithMessage('User must be active');

  // Conditional validation
  RuleFor('Email').Required.When(function(Model: TUser): Boolean
    begin
      Result := Model.Age > 50;
    end);
end;
```

---

## 3. Smart Property Integration (No Magic Strings)

If your model is defined using Smart Properties (`Prop<T>`, `StringType`, `IntType`, etc.), use a `Prototype` ghost entity to map rules strongly.

```pascal
type
  TSmartUserValidator = class(TAbstractValidator<TSmartUser>)
  public
    constructor Create; override;
  end;

constructor TSmartUserValidator.Create;
begin
  inherited Create;
  // Create ghost entity metadata
  var m := Prototype.Entity<TSmartUser>;
  
  // Strongly-typed rule mapping
  RuleFor(m.Name).Required.Length(3, 50);
  RuleFor(m.Email).EmailAddress;
  RuleFor(m.Phone).MatchesPattern('Phone', 'pt-BR');
end;
```

> **Compiler Constraint**: `RuleFor` has concrete overloads for `Prop<string>`, `Prop<Integer>`, `Prop<Boolean>`, etc. This prevents the compiler from implicitly casting generic records to their basic types (such as `string`) and calling string-based methods with empty names.

---

## 4. Pattern Registry (`TValidationPatterns`)

Use localized regular expressions without repeating them across validators.

```pascal
// Register pattern during startup
TValidationPatterns.Register('PostalCode', '^\d{5}$', 'fr-FR');

// Map inside validator constructor
RuleFor(m.PostalCode).MatchesPattern('PostalCode', 'fr-FR');
```

Predefined patterns include:
- `Phone` (Pt-BR, En-US default)
- `ZipCode` (Pt-BR, En-US default)
- `Email` (global RFC 5322 fallback)

---

## 5. Web Auto-Validation Integration

1. Register your validator in DI at startup:
   ```pascal
   Builder.Services.AddSingleton<IValidator<TUser>, TUserValidator>;
   ```
2. When Minimal API / controller binding resolves a class or record parameter, `THandlerInvoker` runs attribute validation and, if registered, `IValidator<T>`.
3. On failure, the pipeline short-circuits with **HTTP 400** and `Results.ValidationProblem` (`Content-Type: application/problem+json`, fields `type`/`title`/`status`/`errors`).
4. Model-binding conversion failures use `Results.BindingProblem` (same media type; `type` = `https://dext.dev/errors/model-binding`).
5. Prefer `Results.ValidationProblem` in handlers when validating manually outside the auto path.

---

## Quick Reference

```pascal
// Fluent validator execution
var Validator := TUserValidator.Create;
try
  var Result := Validator.Validate(UserInstance);
  try
    if not Result.IsValid then
      ShowErrors(Result.Errors); // Array of TValidationError (FieldName, ErrorMessage)
  finally
    Result.Free;
  end;
finally
  Validator.Free;
end;
```
