<!-- 46e3fe9a-d67b-47f2-a83d-a130b97fdb76 7937ec89-e424-4d96-9a19-8e7b4ca9431a -->
# Remove token-spacing style check via Alire-managed switches

### What I will change

- Edit `alire.toml` `[build-switches]` to stop injecting the token-spacing style check.
  - Option A (minimal): remove only spacing by defining a custom list without `t`.
  - Option B (coarse): disable all style checks if you prefer zero style noise.
- Do not touch project `.gpr` files or add config pragmas.
- Ensure `-gnateY` is not set anywhere in Alire switches (it would override pragmas, though we are not using pragmas here).

### Exact edits

- Option A (recommended): keep style, drop spacing
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

- Option B (disable style entirely):
```toml
[build-switches]
"*".style_checks = "No"
```

### Verification steps

- Run a clean build: `alr exec -- gprclean -P sml.gpr && alr -n build -- -cargs:ada -gnat2022 -gnatX0`.
- Confirm that token-spacing `(style) space required [-gnatyt]` warnings no longer appear while other intended style checks remain (for Option A).

### To-dos

- [x] Update alire.toml [build-switches] to remove spacing check (Option A) or disable style (Option B)
- [x] Scan generated config (or build output) to ensure -gnatyt is not passed
- [x] Clean and rebuild; confirm no token-spacing warnings remain
