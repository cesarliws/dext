# ORM: Primeiros Passos

Aprenda a criar sua primeira entidade e contexto de banco de dados.

> 📦 **Exemplo**: [Web.EventHub](../../../Examples/Web.EventHub/)

## 1. Criar uma Entidade

```pascal
unit MeuProjeto.Domain.Entities;

interface

uses
  Dext.Entity; // Facade: Table, Column, PK, AutoInc, Required, MaxLength

type
  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
    FCreatedAt: TDateTime;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [Required, MaxLength(100)]
    property Name: string read FName write FName;

    [Required, MaxLength(200)]
    property Email: string read FEmail write FEmail;

    [CreatedAt]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

implementation

end.
```

> [!IMPORTANT]
> Use a facade `Dext.Entity` para atributos — **NÃO** `Dext.Entity.Attributes` diretamente.  
> Evite atributos `[Column]` redundantes; o Dext mapeia propriedades automaticamente via Naming Strategy.

## 2. Criar um DbContext

```pascal
unit MeuProjeto.Data.Context;

interface

uses
  Dext.Entity.Core,    // IDbSet<T>, TDbContext - OBRIGATÓRIO para genéricos
  Dext.Entity;         // Facade

type
  TAppDbContext = class(TDbContext)
  private
    function GetUsers: IDbSet<TUser>;
  public
    property Users: IDbSet<TUser> read GetUsers;
  end;

implementation

uses
  MeuProjeto.Domain.Entities;

function TAppDbContext.GetUsers: IDbSet<TUser>;
begin
  Result := Entities<TUser>;
end;

end.
```

> [!IMPORTANT]
> Como `IDbSet<T>` é genérico, você **DEVE** adicionar `Dext.Entity.Core` ao uses.  
> A facade `Dext.Entity` **NÃO** exporta tipos genéricos.  
> Use **Properties** para expor `IDbSet<T>` (recomendado) — isso evita ambiguidades sintáticas.

## 3. Configurar Conexão (via DI)

A abordagem recomendada é registrar o DbContext via DI no seu Startup:

```pascal
procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    .AddDbContext<TAppDbContext>(ConfigureDatabase)
    .AddScoped<IUserService, TUserService>;
end;

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseSQLite('App.db')
    .WithPooling(True); // OBRIGATÓRIO para APIs Web
end;
```

Drivers e conexões suportados:
- `.UseSQLite('arquivo.db')`
- `.UsePostgreSQL('connection-string')`
- `.UseMySQL('connection-string')`
- `.UseSQLServer('connection-string')`
- `.UseFirebird('connection-string')`
- `.UseOracle('connection-string')`
- `.UseConnectionDef('nome-def-firedac')` (Utiliza uma definição de conexão global pré-registrada no FireDAC)

### 3.1. Uso do UseConnectionDef e Pooling do FireDAC

Ao utilizar `.UseConnectionDef('NomeDef')`, o Dext resolve automaticamente o dialeto correspondente ao driver configurado no FireDAC. Além disso, se a definição no FireDAC tiver o pooling habilitado (`Pooled=True`), o Dext detectará isso nativamente e herdará essa configuração:

```pascal
procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseConnectionDef('MinhaConexaoFB')
    .WithPooling(True); // Habilita o reaproveitamento das conexões gerenciadas pelo FireDAC
end;
```

### 3.2. Configuração de Dialeto

O Dext tenta inferir o dialeto SQL automaticamente baseado no DriverID da conexão FireDAC. Se você estiver usando uma Connection String customizada ou se a detecção falhar, você pode forçar o dialeto manualmente:

```pascal
procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseSQLServer(Configuration.Get('ConnectionStrings:Default'))
    .UseDialect(ddSQLServer) // Opcional se a detecção falhar
    .WithPooling(True);
end;
```

> [!TIP]
> Para o **SQL Server**, o Dext utiliza por padrão o `TSQLServerDialect` que é otimizado para versões 2012+. Se você estiver em uma versão legada (2008), o comportamento de paginação (Skip/Take) pode exigir atenção especial.

> [!WARNING]
> **Connection Pooling**: APIs Web são multithreaded. **SEMPRE** habilite pooling via `.WithPooling(True)` para evitar exaustão de conexões.

### 3.3. Tamanho do Lote de Operações em Massa (Bulk Batch Size)

Por padrão, operações em massa (`PersistAddRange`, `PersistUpdateRange`, e `PersistRemoveRange`) são fatiadas (chunking) em lotes de 100 registros por vez para evitar ultrapassar limites de parâmetros do driver de banco de dados (por exemplo, FireDAC) ou consumo excessivo de rede. Você pode personalizar esse tamanho conforme a necessidade do seu ambiente:

```pascal
procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UsePostgreSQL(Configuration.Get('ConnectionStrings:Default'))
    .WithBulkBatchSize(250) // Define o tamanho do lote para 250 registros
    .WithPooling(True);
end;
```


## 4. Criar Tabelas

```pascal
Db.EnsureCreated;   // Retorna True se o schema foi criado (função: Boolean)
```

## 5. Operações CRUD

### Create (Inserir)

```pascal
var User := TUser.Create;
User.Name := 'João Silva';
User.Email := 'joao@exemplo.com';

Db.Users.Add(User);
Db.SaveChanges;

// ✅ User.Id é autopopulado (AutoInc) — sem necessidade de nova query!
WriteLn('Usuário criado com ID: ', User.Id);
```

### Read (Ler)

```pascal
// Buscar por ID
var User := Db.Users.Find(1);

// Obter todos
var Todos := Db.Users.ToList;

// Query com Smart Properties (recomendado)
var u := TUser.Props;
var Joaos := Db.Users
  .Where(u.Name.StartsWith('João'))
  .ToList;
```

### Update (Atualizar)

```pascal
var User := Db.Users.Find(1);
User.Name := 'Jane Doe';
Db.Users.Update(User);  // ✅ Força State = Modified
Db.SaveChanges;
```

> [!WARNING]
> Sempre chame `Db.Users.Update(Entity)` **antes** de `SaveChanges` para atualizações. Rastreamento automático pode falhar silenciosamente para entidades desconectadas.

### Delete (Remover)

```pascal
var User := Db.Users.Find(1);
Db.Users.Remove(User);
Db.SaveChanges;
```

## 6. Seed de Dados

Faça o seed dos dados no `.dpr` **antes** de `App.Run`:

```pascal
class procedure TDbSeeder.Seed(const Provider: IServiceProvider);
begin
  var Scope := Provider.CreateScope;
  try
    var Db := Scope.ServiceProvider.GetService(TAppDbContext) as TAppDbContext;

    if Db.EnsureCreated then
    begin
      // Use .Any para verificar existência (evita carregar tudo)
      if not Db.Users.QueryAll.Any then
      begin
        var Admin := TUser.Create;
        Admin.Name := 'Admin';
        Admin.Email := 'admin@exemplo.com';
        Db.Users.Add(Admin);
        Db.SaveChanges;
      end;
    end;
  finally
    Scope := nil;
  end;
end;
```

---

[← Visão Geral ORM](README.md) | [Próximo: Entidades e Mapeamento →](entidades.md)
