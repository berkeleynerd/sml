# Style Checks Decision: Disable Token Spacing (t) via Alire

- Decision: Remove the GNAT token‑spacing style check (t) from project builds.
- Mechanism: Configure Alire‑managed style switches in `alire.toml` to exclude `-gnatyt`.
- Change applied:

```toml
[build-switches]
"*".style_checks = [
  "-gnaty3",      # indentation 3
  "-gnatyM120",   # max width 120
  "-gnatyB",      # short-circuit bools
  "-gnatyl",      # layout
  "-gnatya",      # attribute casing
  "-gnatyO"       # explicit overriding
]
```

- Rationale: Align spacing to prevailing code style; reduce noise while retaining commonly accepted checks (indentation, short-circuit safety, layout, width 120, casing, overriding).
- Verification: Clean, non‑interactive rebuild shows no token‑spacing warnings; other style diagnostics (e.g., `-gnatyB`, `-gnatyM`, `-gnatyl`/`-gnaty0`) and non‑style warnings remain unchanged.
- Scope: Uses Alire’s supported path so all project builds (including tests/examples) inherit the setting. No `-gnateY` present; no project pragmas required.
