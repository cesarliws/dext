# 📦 Coleções Genéricas (`Dext.Collections`)

`Dext.Collections` é o motor de dados em memória de alta performance e seguro quanto
à memória do **Dext Framework**. Projetado do zero para resolver os principais gargalos
das coleções padrão do Delphi (`System.Generics.Collections`), ele reduz drasticamente o
**Tempo de Compilação** (via Dobramento de Código Binário / Code Folding) enquanto entrega
**Zero Vazamentos de Memória**, **Concorrência Lock-Free** e a expressividade do **LINQ**.

---

## 🚀 Por que não usar apenas `System.Generics.Collections`?

As coleções padrão do Delphi impõem um custo alto a aplicações modernas:

1. **Tempo de Compilação e Código Inchado (Code Bloat)**: Instanciar centenas de listas
   genéricas (`TList<T1>`, `TList<T2>`) força o compilador a duplicar o código binário
   para cada parâmetro de tipo.
2. **Gerenciamento Manual de Memória**: Esquecer uma chamada `.Free` causa vazamentos,
   especialmente ao passar coleções entre camadas de serviço.
3. **Ineficiência de Cache**: O `TDictionary` da RTL usa listas encadeadas (chaining) em
   buckets, gerando alto índice de cache misses na CPU.
4. **Contenção por Trava (Lock Contention)**: Operações thread-safe em código legado dependem
   de travas pesadas via `TCriticalSection` ou `TMonitor`.

---

## 🏗️ Pilares de Arquitetura e Performance

### 1. Dobramento de Código Binário (`TRawList`, `TRawDictionary`, `TRawOrderedDict`)
O Dext utiliza uma fina camada de interface genérica (`IList<T>`, `IDictionary<K,V>`,
`IOrderedDictionary<K,V>`) sobre motores de memória bruta não-genéricos. Os motores brutos
internos gerenciam buffers, hashing, sondagem e finalização de tipos gerenciados de forma segura.

> ⚡ **Resultado**: Reduz a duplicação de código genérico em até 60%, reduzindo o tempo
> de build de projetos grandes de 9 minutos para apenas 3.5 minutos!

### 2. Sondagem Otimizada para Cache (`Open Addressing` + `Linear Probing`)
`TRawDictionary` e `TRawOrderedDict` armazenam metadados e entradas de forma contígua
na memória. A busca percorre endereços sequenciais, alinhando-se 100% com as linhas de cache
da CPU e eliminando saltos de ponteiro lentos.

### 3. Aceleração de Hardware e Alocação Zero
- **Vector & Span (`Dext.Collections.Vector.pas`)**: Fatiamento de memória com zero alocação
  para processamento de strings e buffers em altíssima vazão.
- **Vetorização SIMD (`Dext.Collections.Simd.pas`)**: Utiliza instruções AVX/SSE2 para
  analisar de 16 a 32 bytes por ciclo de clock da CPU.
- **Hybrid Sort (`Dext.Collections.Algorithms.pas`)**: Combina `QuickSort` otimizado com
  `Insertion Sort` para pequenas fatias de memória.

---

## 🛠️ Visão Geral da Suíte de Coleções

Todas as coleções do Dext são acessadas através de interfaces e instanciadas pela
factory `TCollections` (`Dext.Collections.Factory.pas`).

```pascal
uses
  Dext.Collections;

var
  Users: IList<TUser>;
  Config: IDictionary<string, string>;
  History: IOrderedDictionary<string, TOrder>;
  ReadCache: IFrozenDictionary<string, TProduct>;
  JobQueue: IChannel<TWorkItem>;
begin
  // Lista de Objetos (É dona e libera os objetos automaticamente)
  Users := TCollections.CreateObjectList<TUser>;

  // Dicionário com Chaves de String Insensíveis a Maiúsculas/Minúsculas
  Config := TCollections.CreateDictionaryIgnoreCase<string>;

  // Dicionário Ordenado (Iteração em ordem de inserção + Busca O(1))
  History := TCollections.CreateOrderedDictionary<string, TOrder>;

  // Canal Concorrente Lock-Free (Estilo Go com backpressure)
  JobQueue := TChannel<TWorkItem>.CreateBounded(100);
end; // Todas as coleções e objetos contidos são liberados automaticamente aqui!
```

---

## 🔒 Segurança de Memória e Gerenciamento de Ownership

A segurança de memória é integrada diretamente em `IList<T>`, `IDictionary<K,V>` e
`IOrderedDictionary<K,V>`.

### Listas de Objetos (`OwnsObjects`)
Quando criada via `TCollections.CreateObjectList<T>`, a lista assume propriedade total:
- Remover um item destrói o objeto automaticamente.
- Limpar a lista (`Clear`) libera todos os objetos.
- Quando a interface sai de escopo, os objetos restantes são destruídos.

```pascal
// Lista apenas de referência (NÃO destrói objetos ao remover/limpar/destruir)
var RefList := TCollections.CreateList<TUser>(False);
```

### Ownership de Chaves/Valores em Dicionários
`IDictionary` e `IOrderedDictionary` suportam ownership de objetos para valores.
Chamar `Extract` transfere a posse do objeto para quem chamou sem destruí-lo.

---

## 🗂️ Novo Recurso: `IOrderedDictionary<K,V>`

`IOrderedDictionary<K,V>` combina busca rápida de chaves `O(1)` com armazenamento denso
que preserva a ordem de inserção.

### Principais Benefícios
- **Enumeração na Ordem de Inserção**: Iterar via `for-in` percorre os elementos exatamente
  na ordem em que foram adicionados (enumerador livre de alocações).
- **Acesso Posicional**: Recupere chaves/valores pelo índice de inserção (`KeyAt`,
  `ValueAt`, `PairAt`, `IndexOf`).
- **Suporte Completo a Comparers e Ownership**: Suporta `IEqualityComparer<K>` customizado,
  chaves string insensíveis a maiúsculas e `OwnsValues`.

```pascal
var Dict := TCollections.CreateOrderedDictionary<string, Integer>;
Dict.Add('First', 10);
Dict.Add('Second', 20);

// Acesso posicional rápido
Writeln('Item no índice 0: ', Dict.KeyAt(0), ' = ', Dict.ValueAt(0));

// Itera exatamente na ordem de inserção: 'First', depois 'Second'
for var Pair in Dict do
  Writeln(Pair.Key, ': ', Pair.Value);
```

---

## ⚡ Padrões de Concorrência e Multithreading

Aplicações de servidor modernas enfrentam sérios gargalos ao gerenciar dados concorrentes
(como sessões de usuários ou conexões web ativas). O Dext oferece três modelos distintos de
concorrência adaptados para diferentes perfis de carga:

### 1. `TConcurrentDictionary<K,V>` (Lock Striping / Travas por Bucket)
Localizado em `Dext.Collections.Concurrent.pas`, o `TConcurrentDictionary` implementa o padrão
**Lock Striping** (semelhante ao Intel TBB ou Java `ConcurrentHashMap`).

Em vez de proteger o dicionário inteiro com um único `TCriticalSection` global, ele distribui
as entradas entre múltiplos buckets de trava (`TSpinLock`) independentes.
- **Alta Concorrência**: Leituras e escritas em buckets de chaves diferentes executam em
  paralelo sem bloquear umas às outras.
- **Zero Contenção Global**: O escopo da trava fica limitado exclusivamente ao bucket sendo
  modificado.

```pascal
uses
  Dext.Collections.Concurrent;

var
  Sessions: TConcurrentDictionary<string, TSessionList>;
begin
  // Busca thread-safe com trava limitada apenas ao bucket específico
  if Sessions.TryGetValue(SessionId, OutList) then
    ProcessSessions(OutList);
end;
```

### 2. `IFrozenDictionary<K,V>` (Operações de Leitura Lock-Free) 🧊
Localizadas em `Dext.Collections.Frozen.pas`, as coleções congeladas foram projetadas para
cargas de trabalho multithread com alto volume de leitura (ex: tabelas de roteamento, metadados,
tokens de sessão).

1. Construa e popule o dicionário durante a inicialização.
2. Chame `.ToFrozenDictionary`.
3. Leia concorrentemente a partir de centenas de threads **100% Lock-Free** sem nenhuma trava
   (`TCriticalSection` ou `TSpinLock`) nem penalidade de barreiras de memória.

### 3. `IChannel<T>` (Troca de Mensagens Lock-Free Estilo Go) 🚀
Localizado em `Dext.Collections.Channels.pas`, o `IChannel<T>` substitui filas compartilhadas
travadas por canais de mensagens lock-free.

- **Zero Lock Contention**: Produtores e consumidores se comunicam sem travar arrays.
- **Backpressure Nativo**: Canais limitados (`TChannel<T>.CreateBounded(1000)`) evitam que
  produtores rápidos saturem a memória enquanto consumidores processam operações lentas de rede.

```pascal
var
  Chan: IChannel<TSessionMessage> := TChannel<TSessionMessage>.CreateBounded(1000);

// Thread Produtora (adiciona payload de rede)
TTask.Run(procedure
  begin
    Chan.Write(Msg);
  end);

// Thread Consumidora (envia para clientes lentos sem segurar travas)
TTask.Run(procedure
  begin
    while Chan.IsOpen do
      SendToNetwork(Chan.Read);
  end);
```

---

## ⚡ LINQ & Filtragem por Expressão

As coleções Dext possuem métodos LINQ avançados integrados diretamente no `IList<T>`.

```pascal
var u := Prototype.Entity<TUser>;

// Filtragem por Propriedades/Expressões (Dext.Specifications)
var Admins := Users
  .Where(u.IsActive and (u.Role = 'Admin'))
  .OrderBy(u.Name.Asc)
  .ToList;

// Métodos Funcionais LINQ
var HasVip := Users.Any(function(User: TUser): Boolean
  begin
    Result := User.IsVip;
  end);
```

---

## 📂 Resumo das Units do Dext Collections

| Nome da Unit | Propósito Principal & Responsabilidades |
| :--- | :--- |
| `Dext.Collections.pas` | Interfaces principais (`IList<T>`, `IDictionary<K,V>`, `IOrderedDictionary<K,V>`, etc.) |
| `Dext.Collections.Factory.pas` | Facade factory `TCollections` para instanciação limpa |
| `Dext.Collections.Base.pas` | Implementações base (`TSmartList<T>`, `TSmartDictionary<K,V>`) |
| `Dext.Collections.Raw.pas` | Backend não-genérico de lista para code folding (`TRawList`) |
| `Dext.Collections.RawDict.pas` | Backend não-genérico de dicionário open-addressing (`TRawDictionary`) |
| `Dext.Collections.RawOrderedDict.pas` | Backend não-genérico de dicionário ordenado (`TRawOrderedDict`) |
| `Dext.Collections.Dict.pas` | Wrapper genérico frontend para `TDictionary<K,V>` |
| `Dext.Collections.OrderedDict.pas` | Wrapper genérico frontend para `TOrderedDictionary<K,V>` |
| `Dext.Collections.HashSet.pas` | Interface e implementação de conjunto open-addressing (`IHashSet<T>`) |
| `Dext.Collections.Frozen.pas` | Estruturas somente-leitura lock-free (`IFrozenDictionary`, `IFrozenSet`) |
| `Dext.Collections.Channels.pas` | Canais de concorrência lock-free estilo Go (`IChannel<T>`) |
| `Dext.Collections.Concurrent.pas` | Filas, pilhas e coleções concorrentes thread-safe |
| `Dext.Collections.Queue.pas` | Estrutura de dados genérica Fila (`IQueue<T>`) |
| `Dext.Collections.Stack.pas` | Estrutura de dados genérica Pilha (`IStack<T>`) |
| `Dext.Collections.Vector.pas` | Vetores dinâmicos contíguos de zero alocação e views de Span |
| `Dext.Collections.Simd.pas` | Rotinas de busca e comparação aceleradas por hardware SIMD |
| `Dext.Collections.Algorithms.pas` | Hybrid Sort (QuickSort + Insertion Sort) e busca binária |
| `Dext.Collections.Comparers.pas` | Comparadores de igualdade e hash otimizados por tipo |
| `Dext.Collections.Extensions.pas` | Métodos de extensão auxiliares para arrays, enumeráveis e LINQ |
| `Dext.Collections.Memory.pas` | Utilitários de baixo nível de memória e inspeção (`IsManagedType`) |
