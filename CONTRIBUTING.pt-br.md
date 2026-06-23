# Contribuindo com o Dext Framework

Antes de mais nada, muito obrigado por considerar contribuir com o Dext! São pessoas como você que fazem do Dext uma ferramenta incrível para a comunidade Delphi.

Ao participar deste projeto, você concorda em cumprir seus termos e diretrizes.

## Como Posso Contribuir?

### Reportando Bugs
*   Verifique o [rastreador de problemas (issues)](https://github.com/cesarliws/dext/issues) para ver se o bug já foi relatado.
*   Caso contrário, abra uma nova issue. Descreva claramente o problema e inclua passos para reproduzi-lo.

### Sugerindo Melhorias
*   Abra uma issue com a tag `enhancement`.
*   Explique por que essa funcionalidade seria útil para a maioria dos usuários do Dext.

### Pull Requests
1.  Faça um Fork do repositório.
2.  Crie uma nova branch para sua funcionalidade ou correção.
3.  Implemente suas alterações.
4.  Siga o **Object Pascal Style Guide** (consistente com o resto do projeto).
5.  Certifique-se de que todos os testes passem executando os scripts PowerShell no diretório `Tests/`.
6.  Envie um Pull Request direcionado à branch `main` ou `develop`.

## Padrões Técnicos

### Estilo de Código
*   Use espaços, não tabs (2 ou 4 espaços conforme o padrão do projeto).
*   Siga as convenções de nomenclatura: `T` para Classes, `I` para Interfaces, `f` para campos privados.
*   Mantenha os métodos focados e siga os princípios SOLID.
*   **Desempenho & Segurança de Interfaces**:
    *   Sempre passe parâmetros de interface como `const` nas assinaturas de métodos (ex: `procedure DoSomething(const AService: IMyService)`). Isso evita chamadas desnecessárias a `_AddRef` e `_Release` geradas pelo compilador, eliminando sobrecarga com instruções atômicas de CPU.
    *   Evite misturar ponteiros de objetos puros (raw objects) com referências de interfaces em limites públicos ou APIs visíveis ao usuário. Restrinja a desvirtualização (fazer typecast de interfaces de volta para objetos) estritamente a loops internos isolados onde o ciclo de vida do objeto é totalmente controlado e nunca exposto.

### Testes
*   Novas funcionalidades devem, idealmente, vir acompanhadas de testes unitários.
*   Consulte `Docs/Book.pt-br/08-testing` para orientações sobre como escrever testes para o Dext.

## Comunicação
*   Junte-se à nossa comunidade no Discord/Telegram (links no README).
*   Respeite todos os colaboradores e mantenedores.

---
*Construindo o futuro do Delphi juntos.*
