# Contributing to Dext Framework

First off, thank you for considering contributing to Dext! It's people like you who make Dext such a great tool for the Delphi community.

By participating in this project, you agree to abide by its terms.

## How Can I Contribute?

### Reporting Bugs
*   Check the [issue tracker](https://github.com/cesarliws/dext/issues) to see if the bug has already been reported.
*   If not, open a new issue. Clearly describe the problem and include steps to reproduce it.

### Suggesting Enhancements
*   Open an issue with the tag `enhancement`.
*   Explain why this feature would be useful to most Dext users.

### Pull Requests
1.  Fork the repository.
2.  Create a new branch for your feature or bugfix.
3.  Implement your changes.
4.  Follow the **Object Pascal Style Guide** (consistent with the rest of the project).
5.  Ensure all tests pass by running the PowerShell scripts in the `Tests/` directory.
6.  Submit a Pull Request targeting the `main` or `develop` branch.

## Technical Standards

### Code Style
*   Use spaces, not tabs (2 or 4 spaces as per the project standard).
*   Follow the naming conventions: `T` for Classes, `I` for Interfaces, `f` for private fields.
*   Keep methods focused and adhere to SOLID principles.
*   **Interface Performance & Safety**:
    *   Always pass interface parameters as `const` in method signatures (e.g., `procedure DoSomething(const AService: IMyService)`). This prevents the compiler from generating unnecessary `_AddRef` and `_Release` calls, avoiding overhead from atomic CPU lock instructions.
    *   Avoid mixing raw object pointers and interface references at public boundaries or within user-facing APIs. Restrict devirtualization (casting interfaces back to objects) strictly to isolated internal loops where the object lifecycle is fully controlled and never exposed.

### Testing
*   New features should ideally come with unit tests.
*   Check `Docs/Book/08-testing` for guidance on how to write tests for Dext.

## Communication
*   Join our community Discord/Telegram (links in README).
*   Respect all contributors and maintainers.

---
*Building the future of Delphi together.*
