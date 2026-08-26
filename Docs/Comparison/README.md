# Dext Framework — Marketing Documentation

This folder contains the strategic positioning and technical comparison documents for the Dext Framework.

---

## Document Map

### 1. [`Dext_vs_DotNet_Narrative.md`](./Dext_vs_DotNet_Narrative.md) — *The Story*

> **"Why Dext was built — and what it means for Delphi in 2026."**

A human, narrative-first document. Ideal for blog posts, forum threads, community presentations, and anyone getting their first impression of Dext. It tells the *why* and the *so what*, not just the *what*.

**Best for:**
- Blog posts and community articles
- Introduction threads on Delphi/programming forums
- A quick read for CTOs and engineering managers
- Developers from .NET or other ecosystems evaluating Dext for the first time

---

### 2. [`Feature_Comparison_Dext_vs_DotNet.md`](./Feature_Comparison_Dext_vs_DotNet.md) — *The Reference Table*

> **"What Dext does — feature by feature, side by side with .NET."**

A structured, objective reference document. Organized into four blocks:
- **Block A**: 60+ features at full parity with ASP.NET Core + EF Core
- **Block B**: 17 features exclusive to Dext (not available in .NET)
- **Block C**: Honest gaps and roadmap items
- **Block D**: Platform differences that don't apply to Delphi by design

**Best for:**
- Tech leads doing a formal technical evaluation
- Developers wanting a precise feature lookup
- PR or README links as a technical evidence page
- Open-source contributors evaluating where to focus efforts

---

### 3. [`Dext_ORM_Capabilities.md`](./Dext_ORM_Capabilities.md) — *The ORM Deep-Dive*

> **"How the Dext ORM works — architecture, code, and exclusive capabilities."**

A technical deep-dive focused exclusively on the ORM and data access layer. Contains side-by-side code examples (Delphi vs C#) for all core patterns, including advanced sections on Multi-Mapping, Stored Procedures, Smart Properties, EntityDataSet, JSON Column queries, and high-performance engineering internals.

**Best for:**
- Delphi developers learning or adopting Dext.ORM
- Technical writers documenting the ORM
- Developers migrating from FireDAC + legacy components to Dext
- Anyone evaluating the ORM's depth independently from the rest of the framework

---

### 4. [`Open_Source_Licensing_Enterprise.md`](./Open_Source_Licensing_Enterprise.md) — *The Enterprise Safety Guide*

> **"Why Apache 2.0 matters — compliance, patent protection, and CI/CD pipeline clearance."**

A whitepaper-style document for enterprise and legal evaluation. Covers the strategic importance of Apache 2.0 over GPL/MIT/LGPL, how Dext clears automated compliance tools (like Snyk), and what it means for commercial product development.

**Best for:**
- Enterprise procurement and legal teams
- CTOs and architects evaluating open-source risk
- Organizations with strict IP and patent compliance requirements
- Teams running automated license-scanning in their CI/CD pipelines

---

## Suggested Reading Order by Audience

| You are… | Start with | Then read |
|:---|:---|:---|
| **Dev from .NET / Java / Go** curious about Dext | Narrative | Feature_Comparison (Block B) |
| **Tech lead** doing a formal evaluation | Feature_Comparison | ORM_Capabilities |
| **Delphi dev** adopting the ORM | ORM_Capabilities | — |
| **CTO / Manager** needing a business case | Narrative (skip to "The Numbers") | Licensing |
| **Enterprise procurement / legal** | Licensing | — |
| **Open-source contributor** | Feature_Comparison (Block C roadmap) | Ecosystem Overview |

---

## External References

- 📘 [Dext Ecosystem Overview](https://github.com/dotpas/dext/blob/main/Docs/Dext_Ecosystem_Overview.md) — Architecture deep-dive: zero-allocation pipeline, SIMD collections, Binary Code Folding
- 📗 [Features Implemented Index](https://github.com/dotpas/dext/blob/main/Docs/Features_Implemented_Index.md) — Complete feature implementation index with spec links
- 🗺️ [Roadmap](https://github.com/dotpas/dext/blob/main/Docs/ROADMAP.md) — Planned features and Wave delivery schedule

---

*Dext Framework | May 2026*
