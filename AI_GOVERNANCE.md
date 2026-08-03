# Dext Framework: AI Policy, Intellectual Property, and Open-Source Governance

## 1. Executive Summary

The integration of Generative AI and agentic workflows into modern software development introduces new considerations regarding intellectual property (IP), copyright eligibility, and open-source compliance.

This document defines the official policy of the **Dext Framework** regarding AI-assisted development, copyright ownership, contributor expectations, and enterprise user protections under the **Apache License 2.0**.

## 2. Intellectual Property & Human Authorship Standard

Dext Framework adheres strictly to international copyright laws and guidelines established by major intellectual property authorities, including the U.S. Copyright Office (USCO):

* **Purely Autonomous AI Output:** Code generated entirely by artificial intelligence without human creative direction or material modification lacks human authorship and is not eligible for copyright protection. Such raw code inherently falls into the public domain.


* **Human-Assisted & Refactored Code:** When AI tools are utilized as assistive instruments under human specification, architectural guidance, structural arrangement, and manual refactoring, the resulting codebase retains copyright protection. The original human selection, logic, architectural design, and substantive edits constitute protectable creative work.


* **Dext Framework Base Code:** Core features, architecture, Object-Relational Mapping (ORM), Dependency Injection, and Model Context Protocol (MCP) integrations in Dext are designed, reviewed, refactored, and maintained by human engineers. AI is utilized solely as an productivity assistant, preserving human authorship over the collective codebase.



## 3. Compatibility with the Apache 2.0 License

The Dext Framework is distributed under the permissive **Apache License 2.0**. The interaction between AI-generated snippets and Apache 2.0 operates as follows:

* **Public Domain Snippets:** If unedited AI-generated snippets within the codebase are deemed uncopyrightable, their presence does not compromise the repository. Permissive open-source licenses like Apache 2.0 actively encourage free use, modification, and redistribution.


* **Disclaimer of Warranty & Liability:** In full compliance with Sections 7 and 8 of the Apache 2.0 License, Dext is provided on an "AS IS" basis, without warranties or conditions of any kind.



## 4. Contributor Governance & Code Review Protocol

To ensure code quality, security, and IP integrity, all open-source contributions to Dext must adhere to standard governance practices:

1. **Human-in-the-Loop Verification:** Maintainers perform strict human code reviews on all Pull Requests (PRs), whether submitted by community contributors or created via automated agentic workflows.


2. **Developer Certificate of Origin (DCO):** Contributors must ensure that any code submitted—AI-assisted or manually written—does not infringe on third-party intellectual property or violate copyleft licenses (e.g., GPL).


3. **License Contamination Prevention:** Submissions containing verbatim copies of third-party source code under incompatible licenses will be rejected. Maintainers utilize automated Software Composition Analysis (SCA) tools where applicable.


4. **Remediation Protocol:** If a portion of the Dext codebase is ever found to contain disputed or infringing code, the maintainers will immediately follow standard open-source remediation procedures: **Identify, Remove, Replace, and Release a Patch**.



## 5. Guidance for Enterprise & Commercial Users

Companies and developers building commercial software on top of the Dext Framework can do so with full legal confidence:

* **Framework Safety:** The Apache 2.0 license guarantees that using Dext as a foundation or library will not force commercial applications to open-source their proprietary code.


* **Proprietary Application Ownership:** Commercial users are advised to ensure that their internal development teams exercise human direction, manual review, and architectural control when using AI assistants (e.g., Cursor, Copilot, Claude Code) to build proprietary business logic. This practice ensures that their own enterprise software retains copyright protection.



## 6. Alignment with Global Open-Source Standards

The AI governance policies of the Dext Framework align with the practices established by major global software ecosystems, including .NET (Microsoft), Node.js (OpenJS Foundation), Go (Google), and the Linux Foundation. By combining human code review, clear licensing disclaimers, and proactive remediation protocols, Dext delivers an enterprise-ready environment for modern software development.