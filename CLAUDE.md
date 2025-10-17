# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a formally verified SPARK Ada library for parsing and validating Simple Markup Language (SML), a restricted subset of XML designed for formal verification. The library provides a DOM parser with schema validation, all with mathematical proofs of correctness and memory safety.

## Build Commands

### Quick Build Everything
```bash
./build_all.sh  # Builds library, tests, and examples
```

### Individual Components

**Library:**
```bash
alr build
# Or with specific Ada version:
alr build -- -cargs:ada -gnat2022 -gnatX0
```

**Tests:**
```bash
./test/build_tests.sh
# Or manually:
alr exec -- gnatmake -P test/tests.gpr
```
Note: Uses `gnatmake` instead of `gprbuild` due to gprbuild 25.0.0 issue on macOS ARM64.

**Examples:**
```bash
./examples/build_examples.sh
# Or manually:
alr exec -- gprbuild -P examples/examples.gpr
```

### Running Tests

```bash
# Individual test suites
bin/test-parser   # Parser tests
bin/test-schema   # Schema validation tests
bin/test-io       # File I/O tests

# Examples (run in order)
bin/example-basic-dom           # DOM operations tutorial
bin/example-schema-validation   # Schema validation demo
bin/test-schema-loader         # Integration tests
```

### SPARK Verification

```bash
# Flow analysis (fast, data flow checking)
alr exec -- gnatprove -P sml.gpr --mode=flow --report=all

# Level 0 proof (partial verification)
alr exec -- gnatprove -P sml.gpr --level=0 --report=all

# Level 4 proof (complete verification - slow)
alr exec -- gnatprove -P sml.gpr --level=4 --prover=cvc5,z3,altergo --timeout=60
```

## Architecture

### Core Design Principles

1. **Index-Based Node References**: Instead of pointers, nodes use discrete index types (`Node_Id`) for SPARK compatibility. This enables formal verification and prevents aliasing issues.

2. **Arena Allocation**: All memory is allocated from fixed-size pools on the stack:
   - Node pool: 2,000 nodes max (configurable in `src/sml-memory_model.ads:44`)
   - String pool: 200KB max (configurable in `src/sml-memory_model.ads:47`)
   - No heap allocation - enables bounded memory proofs

3. **Limited Types**: `Document` is a limited type preventing copying and ensuring single ownership. This eliminates aliasing bugs and simplifies verification.

4. **Discriminated Result Types**: No exceptions - all errors returned through discriminated records:
   ```ada
   type Parse_Result (Success : Boolean := False) is record
      case Success is
         when True => Doc : Document;
         when False => Error : Error_Info;
      end case;
   end record;
   ```

### Package Structure

**Core Packages:**
- `SML.Memory_Model` - Arena allocator with bounded memory (stack-based)
- `SML.UTF8` - RFC 3629 compliant UTF-8 validation
- `SML.Entities` - XML entity encoding/decoding (&lt; &gt; &amp; &quot; &apos;)
- `SML.DOM` - Document model with opaque types and traversal API
- `SML.DOM.Parser` - Single-pass O(n) parser with error reporting
- `SML.DOM.Builder` - DOM construction maintaining invariants
- `SML.DOM.Writer` - Serialization to SML format
- `SML.Schema` - Type and structure validation engine

**Ghost Packages (proof only):**
- `SML.*.Proof` - Ghost code for formal verification (no runtime overhead)

### Key Invariants

1. **Well-Formedness**: Every `Document` satisfies `Is_Well_Formed`:
   - Single root element
   - Acyclic tree structure
   - Consistent parent-child links
   - Valid depth (≤1000 levels)

2. **Memory Safety**: Verified by SPARK:
   - No buffer overflows
   - No memory leaks
   - Bounded resource usage
   - No undefined behavior

3. **Deletion Pattern**: Nodes use logical deletion (tombstone) rather than deallocation. Deleted nodes are skipped during traversal/serialization.

## Memory Configuration

Default limits handle ~50KB SML documents. For larger files:

### Option 1: Increase Stack Size (Recommended)

Add to your `.gpr` file:
```ada
package Linker is
   -- Platform-specific syntax:
   for Linker_Options use ("-Wl,-stack_size,0x4000000");   -- macOS (64MB hex)
   -- for Linker_Options use ("-Wl,-z,stack-size=67108864"); -- Linux (64MB decimal)
   -- for Linker_Options use ("-Wl,--stack,67108864");       -- Windows (64MB decimal)
end Linker;
```

### Option 2: Modify Library Constants

Edit `src/sml-memory_model.ads`:
```ada
Max_Document_Nodes : constant Natural := 10_000;     -- Increase as needed
Max_String_Storage : constant Natural := 1_000_000;  -- Increase as needed
```
Then rebuild: `alr clean && alr build`

## Known Limitations

**Schema Content Type Validation Gap** (from PLAN.md):
- Structure validation: ✅ Working
- Cardinality validation: ✅ Working
- Content type functions: ✅ Exist
- **Gap**: Element content not automatically validated against type definitions

Workaround: Manually call content validators:
```ada
Result := Validate_Document (Schema, Doc);  -- Structure only
if Result.Status = Valid then
   -- Manually validate specific content:
   Port_Text := Get_Element_Content (Doc, "port");
   Content_Result := Validate_Integer_Content (Port_Text, 1, 65535);
end if;
```

## Development Workflow

### Adding New Features

1. **Maintain SPARK Verification**: Any changes must preserve 0 high-priority issues
2. **Update Contracts**: Ensure preconditions, postconditions, and invariants are updated
3. **Test Coverage**: Add tests to relevant test suite in `test/`
4. **Ghost Code**: Add verification predicates in `.Proof` child packages

### Modifying Parser

The parser (`src/sml-dom-parser.adb`) uses a state machine with careful error handling:
- Single-pass design (O(n) complexity)
- Detailed error reporting with line/column
- Entity expansion during parsing
- UTF-8 validation on all input

Key parser states:
- `Expecting_Element`: Looking for opening tag
- `In_Element_Name`: Parsing element name
- `In_Element_Content`: Inside element, may find text or nested elements
- `In_Text`: Accumulating text content
- `In_Close_Tag`: Parsing closing tag

### Working with Schema Validation

Schema validation has two layers:
1. **Core engine** (`src/sml-schema.ads`) - Programmatic API
2. **Loader example** (`examples/sml-schema-loader.ads`) - Load schemas from files

The loader is provided as example/reference code users can adapt.

## Testing Strategy

### Test Organization

- `test/test-parser.adb` - Parser edge cases, UTF-8, entities
- `test/test-schema.adb` - Schema validation (7 comprehensive tests)
- `test/test-io.adb` - File operations
- `examples/test-schema-loader.adb` - Integration tests (8 tests)

### Running Single Tests

Tests are organized as procedures within each test program. To run specific tests, modify the main procedure in the test file to call only desired test procedures.

## SPARK Verification Notes

### Current Status
- 0 high-priority issues (production ready)
- ~500 medium-priority issues (loop termination, complex postconditions)

### Common Verification Patterns

1. **Loop Invariants**: Required for bounded loops
2. **Structural Variants**: For recursive tree operations
3. **Ghost Functions**: Define properties without runtime cost
4. **Lemmas**: Prove intermediate steps

### Verification Levels

- **Flow**: Data dependencies (fast, always run this first)
- **Level 0**: Basic checks (quick smoke test)
- **Level 4**: Complete verification (slow but thorough)

## Platform-Specific Notes

### macOS (including Apple Silicon)
- Default stack: 8MB
- Linker flag: `-Wl,-stack_size,0xHEXVALUE` (hexadecimal)
- gprbuild 25.0.0 has issues with single-main projects (use gnatmake for tests)

### Linux
- Default stack: 8MB (varies by distro)
- Linker flag: `-Wl,-z,stack-size=DECIMAL` or `-Wl,--stack-size=DECIMAL`
- Test which syntax works on your system

### Windows
- Default stack: 1MB (too small - must increase!)
- Linker flag: `-Wl,--stack,DECIMAL`
- Minimum 16MB recommended for default library settings

## Error Handling Patterns

The library uses discriminated records instead of exceptions:

```ada
-- Parser result
Result : constant Parse_Result := Parse (Input);
if Result.Success then
   -- Use Result.Doc
else
   -- Check Result.Error.Message, Line, Column
end if;

-- Schema validation
Val_Result : constant Validation_Result := Validate_Document (Schema, Doc);
case Val_Result.Status is
   when Valid => -- Document valid
   when Invalid_Structure => -- Check Val_Result.Error_Message
   when Invalid_Content => -- Check Val_Result.Element_Path
end case;
```

## File I/O Utilities

Optional utilities in `util/sml-io.ads`:
- SPARK specification with `SPARK_Mode => Off` body (uses Ada.Sequential_IO)
- Maximum file size: 1MB default (configurable)
- Bounded buffer operations for safety

```ada
-- Parse from file
File_Result := SML.IO.Parse_File ("/path/to/file.sml");

-- Write to file
Write_Result := SML.IO.Write_Document ("/path/to/output.sml", Doc);
```