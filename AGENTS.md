# Repository Guidelines

## Project Structure & Module Organization
- `src/` — SPARK Ada sources (`SML.*`); proof-only units mirror as `sml-*-proof.ad[sb]` for `.Proof` children.
- `test/` — Ada test mains (`test_*.adb`) and `test/fixtures/` sample SML files.
- `bin/` — Built executables (e.g., `bin/test_parser`, `bin/test_schema`).
- `obj/`, `lib/` — Build artifacts; `proof/` and `proof.log` for SPARK results.
- `sml.gpr`, `test_*.gpr` — GPRbuild projects; `config/sml_config.gpr` compiler/profile settings.
- `alire.toml`, `alire/` — Alire crate metadata.

## Build, Test, and Development Commands
```bash
# Build library (recommended)
alr build
# Or directly
gprbuild -P sml.gpr
# Build tests
alr exec -- gprbuild -P test_parser.gpr
alr exec -- gprbuild -P test_schema.gpr
# Run tests
bin/test_parser && bin/test_schema
# SPARK flow/proofs (writes to proof/)
alr exec -- gnatprove -P sml.gpr --mode=flow --report=all
alr exec -- gnatprove -P sml.gpr --level=4 --report=all
```

## Coding Style & Naming Conventions
- Ada 2022; style checks enforced via GNAT (`-gnaty3 -gnatyM120 -gnatyB -gnatyl -gnatya -gnatyO`).
- Indentation 3 spaces; max line length 120; explicit `overriding`; consistent layout and attribute casing.
- Package namespace `SML.*`; filenames `sml-<unit>.ad[sb]` (e.g., `sml-dom-parser.ads`).
- Keep run-time allocation within the memory model; prefer contracts (`Pre`, `Post`) and pure helpers in proof units.

## Testing Guidelines
- Place new tests in `test/` as `test_<topic>.adb`; use fixtures under `test/fixtures/`.
- Copy an existing `test_*.gpr` or add a new one with your main; build via `alr exec -- gprbuild -P <file>.gpr`.
- Tests must be deterministic and exit non-zero on failure. Include edge cases (invalid UTF-8, entities, schema bounds).

## Commit & Pull Request Guidelines
- Conventional prefixes observed: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `proof:` (e.g., `feat(schema): add choice occurs`).
- PRs: describe scope, link issues, outline verification (test output + `gnatprove` level used), and note memory/stack changes if any.
- Update docs when user-facing behavior changes (README, MEMORY.md). Keep changes focused and small.

## Security & Verification Tips
- Maintain strict UTF-8 and entity handling; avoid unbounded allocations.
- For large tests, adjust stack as in `test_parser.gpr` (`-Wl,-stack_size,0x2000000`).
