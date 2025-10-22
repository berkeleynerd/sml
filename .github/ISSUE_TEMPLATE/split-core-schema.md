---
name: "Refactor: Split core and schema crates"
about: Track splitting parsing/DOM core and schema into separate Alire crates
title: "Refactor: Split sml_core (DOM+Parser) and sml_schema (Schema)"
labels: ["enhancement", "refactor", "backlog"]
assignees: ""
---

Summary
- Split this repo into two crates to reduce dependency surface and speed builds:
  - sml_core: `SML`, `SML.DOM`, `SML.DOM.Parser`, `SML.DOM.Builder`, `SML.DOM.Writer`, `SML.UTF8`, `SML.Entities`, `SML.Memory_Model`.
  - sml_schema: `SML.Schema` only; depends on `sml_core`.

Motivation
- Consumers that only need parsing/DOM should not pull schema.
- Faster proofs/builds for core‑only changes; clearer ownership and release cadence.

Out of Scope (for this issue)
- Public API changes beyond moving files.
- New features or behavior changes.

Proposed Plan (high‑level)
1) Create new repo/crate: sml_core (this repo renamed or copied), remove `sml-schema*.ad[sb]` and schema tests.
2) Create new repo/crate: sml_schema, add schema sources and tests; set `depends = ["sml_core ^0.1"]` in `alire.toml`.
3) Update examples to depend on `sml_schema` (which pulls `sml_core`).
4) CI: add `alr test` in each crate; verify cross‑build on macOS/Linux.

Acceptance Criteria
- `alr build` and `alr test` pass in both crates.
- `sml_core` exports the same Library_Interface minus schema; `sml_schema` exports only `SML.Schema`.
- No cyclic dependencies; compile without warnings elevated to errors in tests.

Risks / Mitigations
- Version skew: start with lockstep minor versions; add CI matrix building `sml_schema` against latest `sml_core`.
- API boundaries: keep package specs unchanged; only relocate files.

Notes
- Alternative is a single‑crate conditional build (GPR external `SML_WITH_SCHEMA`), but separate crates provide cleaner dependency graphs.

