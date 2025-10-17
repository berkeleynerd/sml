# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a test directory demonstrating the "ghost pattern" for Ada/SPARK formal verification. The pattern addresses circular dependency issues when using ghost packages for proof purposes while enabling gnatprove to utilize ghost implementations for verification.

## Architecture

The ghost pattern uses three-package structure to avoid circular dependencies:

```
Main Package (Example) -----> Types Package (Example_Types)
      |                             ^
      v                             |
Ghost Package (Example_Ghost) ------+
```

### Package Responsibilities

- **Example_Types**: Shared type definitions used by both main and ghost packages
- **Example_Ghost**: Ghost functions for verification contracts (marked with `Ghost` aspect)
- **Example**: Main implementation using ghost functions in pre/postconditions

## Development Commands

### Build the test
```bash
# From parent directory (requires Alire)
alr exec -- gprbuild -P test_ghost_pattern/test.gpr

# Or from this directory
gprbuild -P test.gpr
```

### Run formal verification
```bash
# From parent directory (requires Alire)
alr exec -- gnatprove -P test_ghost_pattern/test.gpr --report=all

# Or from this directory
gnatprove -P test.gpr --report=all
```

### Run complete test suite
```bash
# From parent directory
./test_ghost_pattern/run_test.sh
```

### Verify ghost package is analyzed
```bash
grep -i "example_ghost" obj/gnatprove/gnatprove.out
```

## Key Implementation Details

1. **Ghost packages must not be child packages**: Using separate packages (e.g., `Example_Ghost` instead of `Example.Ghost`) prevents circular dependencies

2. **Ghost aspect requirement**: Ghost packages must be marked with the `Ghost` aspect at the package level

3. **SPARK_Mode**: All packages must have SPARK_Mode enabled for formal verification

4. **Verification flow**: Ghost functions are analyzed by gnatprove and used to verify contracts without being included in the final executable

## Test Validation

A successful test shows:
- Ghost package and its functions are analyzed by gnatprove
- No circular dependency errors
- Contracts using ghost functions are properly verified

Check RESULTS.md for detailed findings about the pattern's effectiveness.