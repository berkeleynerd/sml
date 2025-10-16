# GPRbuild Issue on macOS ARM64

## Issue Description

GPRbuild version 25.0.0 crashes with a CONSTRAINT_ERROR when building single-main executable projects on macOS ARM64 (aarch64-apple-darwin).

## Error Details

```
gprbuild: raised CONSTRAINT_ERROR : gpr-sinput.adb:310 access check failed
Exit code: 7
```

The error occurs during the bind phase, after successful compilation.

## Environment

- OS: macOS (darwin 25.0.0)
- Architecture: ARM64 (aarch64-apple-darwin23.6.0)
- GPRbuild: 25.0.0 (2025-05-16)
- GNAT: Provided by Alire

## Affected Project Types

**Failing:**
- Single-main executable projects (e.g., test/tests.gpr with individual mains)

**Working:**
- Library projects (e.g., sml.gpr, sml_io.gpr)
- Multi-main executable projects (e.g., examples.gpr with 3 mains)

## Workaround

Use `gnatmake` instead of `gprbuild` for single-main executable projects:

```bash
./build_tests.sh
# Or: alr exec -- gnatmake -P test/tests.gpr
```

## Reproduction Steps

1. Create a simple project file with a single main:
```ada
project Test is
   for Source_Dirs use ("src/");
   for Object_Dir use "obj/";
   for Main use ("test.adb");
end Test;
```

2. Try to build with gprbuild:
```bash
alr exec -- gprbuild -P test.gpr
```

3. Observe CONSTRAINT_ERROR during bind phase

## Stack Trace

```
Load address: 0x102440000
Call stack traceback locations:
0x10288a790 0x10288ab68 0x10288a740 0x10288abe4 0x1026e8cfc 0x1025c6a80 0x1024d3b28 0x1024d6e78 0x1024d7084 0x1024d7194 0x102453850 0x10290043c
```

## Notes

- The issue appears to be specific to gprbuild's bind phase
- gnatmake successfully builds the same projects
- This may be related to how gprbuild handles project files on macOS ARM64
- The issue affects how gprbuild processes single-main executables, not project structure

## Potential Bug Report

This issue should be reported to AdaCore with:
1. Minimal reproducible example
2. System information  
3. GPRbuild version details
4. Stack trace information
