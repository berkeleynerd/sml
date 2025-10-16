# Structure Reorganization Summary

## Overview

Reorganized the SML library to have:
1. Consistent naming conventions for tests and examples
2. GPR files located in their respective directories
3. Clear separation between test programs and example programs

## Changes Made

### 1. File Renaming

**Examples (in examples/):**
- `sml_example.adb` → `example_basic_dom.adb`
- `schema_validation_example.adb` → `example_schema_validation.adb`

**Tests (remain in test/):**
- `test_parser.adb` (unchanged)
- `test_io.adb` (unchanged)
- `test_schema.adb` (unchanged)

**Note:** `test_schema_loader.adb` remains in examples/ as it depends on `sml-schema-loader` package.

### 2. GPR File Reorganization

**Moved/Created:**
- `examples.gpr` → `examples/examples.gpr`
- Created `test/tests.gpr` (consolidating test_parser.gpr, test_io.gpr, test_schema.gpr)

**Deleted:**
- `test_parser.gpr`
- `test_io.gpr`
- `test_schema.gpr`

### 3. Build System Updates

- Updated `build_tests.sh` to use `test/tests.gpr`
- Works around gprbuild 25.0.0 issue on macOS ARM64 by using gnatmake

### 4. Documentation Updates

Updated all references in:
- README.md
- CLAUDE.md
- SCHEMA_TUTORIAL.md
- SCHEMA_SPEC.md
- alire.toml

## New Structure

```
sml/
├── examples/
│   ├── examples.gpr                    # Examples project file
│   ├── example_basic_dom.adb           # Basic DOM operations
│   ├── example_schema_validation.adb   # Schema validation demo
│   ├── test_schema_loader.adb          # Schema loader tests
│   └── sml-schema-loader.ads/.adb      # Schema loader utility
├── test/
│   ├── tests.gpr                       # Tests project file
│   ├── test_parser.adb                 # Parser unit tests
│   ├── test_io.adb                     # I/O tests
│   ├── test_schema.adb                 # Schema validation tests
│   └── fixtures/                       # Test data files
├── src/                                # Library sources
├── build_tests.sh                      # Test build script
└── sml.gpr                            # Main library project
```

## Naming Conventions

- **Examples**: `example_*.adb` - Demonstrate library usage
- **Tests**: `test_*.adb` - Verify library functionality

## Building

```bash
# Build library
alr build

# Build tests
./build_tests.sh

# Build examples
alr exec -- gnatmake -P examples/examples.gpr
```

## Benefits

1. **Clearer organization** - GPR files with their sources
2. **Consistent naming** - Easy to identify purpose
3. **Simplified structure** - One GPR per directory
4. **Better separation** - Tests vs examples clearly distinguished
