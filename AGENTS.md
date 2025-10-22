# Repository Guidelines

## Project Structure & Module Organization
Core SPARK Ada packages live in `src/` as `.ads` specs and `.adb` bodies. Verification artifacts in `proof/` mirror runtime packages with `.Proof` child units and VC logs. Executable demos sit in `examples/`, while compiled binaries resolve to `bin/`. Tests inhabit `test/` with shared documents under `test/fixtures/`. Build and project files (`sml.gpr`, `test_*.gpr`, `alire.toml`) anchor the toolchain, and configuration headers live in `config/`. Utility scripts and helpers reside in `util/`.

## Build, Test, and Verification
Use Alire for reproducible builds: `alr build` compiles the library and resolves dependencies. Targeted builds use `alr exec -- gprbuild -P test_parser.gpr` (parser suite) or `alr exec -- gprbuild -P test_schema.gpr`. Executables for examples and I/O live in separate repositories (sml_examples, sml_io). Run validation with `bin/test_parser` and `bin/test_schema`. Keep proofs current by invoking `alr exec -- gnatprove -P sml.gpr --level=4 --prover=cvc5` and stash extended output in `proof/proof.log`.

## Coding Style & Naming Conventions
Stick to SPARK Ada 2022 style: three-space indentation, one declaration per line, and explicit `with` clauses for dependencies. Keep package names in the `SML.*` hierarchy, placing ghost logic in `.Proof` children. Use Title_Case for types, Mixed_Case for subprograms, and UPPER_SNAKE_CASE for constants. Align contracts (`Pre`, `Post`, `Refined_Post`) vertically for readability, and run `gnatpp` with repository defaults before submitting significant formatting changes.

## Testing Guidelines
Tests live in `test/` and follow the `test_<topic>.adb` naming pattern. Extend suites by mirroring existing driver structure and storing fixtures in `test/fixtures/`. After adding cases, rebuild through the matching `.gpr` project and execute the produced binary from `bin/`. Record any new fixture files in commits and update corresponding proof packages when signatures evolve to avoid stale VC results.

## Commit & Pull Request Guidelines
Commit messages follow `type(scope): subject` (e.g., `feat(schema): add constraint validators`) with imperative subjects capped at ~72 characters. For pull requests, summarize behavioral changes, list touched packages or project files, and note build/test/`gnatprove` results with links or log excerpts. Reference related issues, include screenshots for user-facing changes, and highlight any remaining proof obligations or manual steps reviewers must perform.
