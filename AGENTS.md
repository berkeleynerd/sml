# Repository Guidelines

## Project Structure & Module Organization
- `src/` — SPARK Ada sources (`SML.*`); proof-only units mirror as `sml-*-proof.ad[sb]` for `.Proof` children.
- `test/` — Ada test mains (`test_*.adb`) and `test/fixtures/` sample SML files.
- `bin/` — Built executables (e.g., `bin/test_all`).
- `obj/`, `lib/` — Build artifacts; `proof/` and `proof.log` for SPARK results.
- `sml.gpr`, `test/test_all.gpr`, `tests.gpr` — GPRbuild projects; `config/sml_config.gpr` compiler/profile settings.
- `alire.toml`, `alire/` — Alire crate metadata.

## Build, Test, and Development Commands
```bash
# Build library (recommended)
alr build
# Or directly
gprbuild -P sml.gpr
# Run tests via Alire action
alr test
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
- Prefer adding cases to the omnibus runner (`test/test_all.adb`); keep `test/test_all.gpr` as the single project, and `alire.toml` actions run it via `alr test`.
- Tests must be deterministic and exit non-zero on failure. Include edge cases (invalid UTF-8, entities, schema bounds).

## Commit & Pull Request Guidelines
- Conventional prefixes observed: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `proof:` (e.g., `feat(schema): add choice occurs`).
- PRs: describe scope, link issues, outline verification (test output + `gnatprove` level used), and note memory/stack changes if any.
- Update docs when user-facing behavior changes (README, MEMORY.md). Keep changes focused and small.

## Security & Verification Tips
- Maintain strict UTF-8 and entity handling; avoid unbounded allocations.
- For large tests, adjust stack as in `test/test_all.gpr` (`-Wl,-stack_size,0x2000000`).
