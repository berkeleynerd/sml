# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a formally verified SPARK Ada library for parsing and manipulating Simple Markup Language (SML) - a strict subset of XML designed for formal verification with mathematical proofs of correctness, memory safety, and performance guarantees.

**Current Status**: Implementation complete, SPARK verified, production ready.

## SML Language Restrictions

SML enforces these constraints to enable formal verification:
- No attributes on elements
- No processing instructions (`<?...?>`)
- No DTD or schema declarations
- No CDATA sections (`<![CDATA[...]]>`)
- No comments (`<!--...-->`)
- No namespaces
- UTF-8 encoding only
- Only standard XML entities: `&lt;` `&gt;` `&amp;` `&quot;` `&apos;`

## Build Commands

```bash
# Build library using Alire (recommended)
alr build

# Build library, examples and tests
./build.sh

# Build individual components
alr exec -- gprbuild -P sml.gpr          # Library only
alr exec -- gprbuild -P examples.gpr     # Examples (includes schema loader)
alr exec -- gprbuild -P test_parser.gpr  # Parser tests
alr exec -- gprbuild -P test_schema.gpr  # Schema tests

# Run examples
bin/sml_example                    # Basic DOM usage
bin/schema_validation_example      # Schema validation demo

# Run tests
bin/test_parser                    # Parser tests
bin/test_schema                    # Schema validation tests
bin/test_schema_loader             # Schema loader tests
```

## Example Programs

The repository includes three focused example programs demonstrating different aspects of the library:

### 1. sml_example - Basic DOM Operations (218 lines)
**Purpose:** Tutorial for core DOM functionality
**Features demonstrated:**
- Parsing SML from strings
- Building DOM trees programmatically
- Traversing and navigating trees
- Modifying nodes (add, update, delete)
- Serializing to SML format
- Round-trip operations (parse → modify → serialize → parse)

**When to use:** Start here to learn basic SML library usage
**Run:** `bin/sml_example`
**Location:** `examples/sml_example.adb`

### 2. schema_validation_example - Schema Validation (202 lines)
**Purpose:** Demonstration of schema validation capabilities
**Features demonstrated:**
- Loading schemas from SML strings
- Converting schema SML to Schema_Document
- Validating instance documents
- Accepting valid documents
- Rejecting invalid documents with error messages
- Multiple validation scenarios

**When to use:** Learn how to use schema validation for type-safe configs
**Run:** `bin/schema_validation_example`
**Location:** `examples/schema_validation_example.adb`

### 3. test_schema_loader - File I/O & Integration (455 lines)
**Purpose:** Comprehensive testing and file-based workflows
**Features demonstrated:**
- Schema loader unit tests (8 tests)
- File-based schema loading (using SML.IO)
- File-based instance loading
- End-to-end validation from files
- Error handling at each level

**When to use:** See real-world file-based usage patterns
**Run:** `bin/test_schema_loader`
**Location:** `examples/test_schema_loader.adb`

**Note:** This is a hybrid test/demo program - first 8 procedures are unit tests (inline strings), final procedure demonstrates file I/O integration.

### Example Progression

**Suggested learning order:**
1. Start with `sml_example` to understand DOM basics
2. Move to `schema_validation_example` for validation features
3. Review `test_schema_loader` for file I/O and integration patterns

All examples use inline SML strings except test_schema_loader's final test which demonstrates file-based workflows using SML.IO utilities.

## Verification Commands

```bash
# Fast flow analysis (data dependencies, initialization)
alr exec -- gnatprove -P sml.gpr --mode=flow --report=all

# Level 0: Fast partial proof (<1 second per package)
alr exec -- gnatprove -P sml.gpr --level=0 --report=all

# Level 2: Most VCs proven (<10 seconds per package)
alr exec -- gnatprove -P sml.gpr --level=2 --report=all

# Level 4: Complete verification (all VCs, <60 seconds per package)
alr exec -- gnatprove -P sml.gpr --level=4 --report=all

# Verify single package
alr exec -- gnatprove -P sml.gpr --level=4 -u sml-dom.ads

# Generate proof report
alr exec -- gnatprove -P sml.gpr --level=4 --output=proof_report.out --report=all
```

## Architecture

### Ghost Code Organization

The library uses child ghost packages to separate verification code from runtime:

- **Runtime packages**: Contain the actual implementation
- **Ghost packages** (*.Proof): Contain ghost functions and lemmas for SPARK verification
- **Import pragma pattern**: Parent packages declare ghost functions with `Ghost, Import` 

Ghost packages:
- SML.Memory_Model.Proof - Memory safety proofs and invariants
- SML.DOM.Proof - DOM tree well-formedness and structural properties
- SML.UTF8.Proof - UTF-8 validation properties
- SML.Entities.Proof - Entity encoding/decoding properties  
- SML.DOM.Parser.Proof - Parser correctness properties
- SML.DOM.Builder.Proof - Builder operation properties

### Package Hierarchy

The library uses a hierarchical package structure with index-based node references and arena allocation for SPARK compatibility:

1. **SML** (`src/sml.ads`) - Root package with version information

2. **SML.Memory_Model** (`src/sml-memory_model.ads/.adb`) - Arena-based memory management
   - Fixed-size node and string pools
   - Configurable memory limits (default: 10K nodes, 1MB strings)
   - Ghost predicates for memory safety proofs
   - Zero heap allocations (stack-based arenas)

3. **SML.DOM** (`src/sml-dom.ads/.adb`) - Core DOM types and tree operations
   - `Document` - Limited type owning all nodes
   - `Node_Id` - Index-based references (SPARK-compatible)
   - Read-only traversal operations (O(1))
   - Ghost functions for well-formedness invariants

4. **SML.DOM.Parser** (`src/sml-dom-parser.ads/.adb`) - Single-pass parser
   - `Parse_Result` - Discriminated union for success/failure
   - O(n) parsing with no backtracking
   - Detailed error reporting with line/column info
   - Formal correctness contracts

5. **SML.DOM.Builder** (`src/sml-dom-builder.ads/.adb`) - DOM construction API
   - Create documents and nodes programmatically
   - Safe modification operations
   - Preserves well-formedness invariants

6. **SML.DOM.Writer** (`src/sml-dom-writer.ads/.adb`) - Serialization to SML
   - Round-trip guarantee: parse(write(doc)) = doc
   - Entity encoding for safety
   - Configurable output formatting

7. **SML.UTF8** (`src/sml-utf8.ads/.adb`) - UTF-8 validation and processing
   - RFC 3629 compliant validation
   - Security hardening (reject overlong, surrogates, etc.)
   - UTF-8 aware string navigation

8. **SML.Entities** (`src/sml-entities.ads/.adb`) - XML entity handling
   - Standard 5 entities only
   - Bijective encoding/decoding
   - Injection-safe output

9. **SML.Schema** (`src/sml-schema.ads/.adb`) - Schema validation engine
   - `Schema_Document` - Limited type with type invariants
   - Element vocabulary validation
   - Content type validation (integer, boolean, decimal, string)
   - Enumeration support (up to 20 values per type)
   - Structure validation (sequence, choice, simple content models)
   - Cardinality checking (minOccurs, maxOccurs)
   - Bounded types with formal invariants for SPARK safety
   - 0 high-priority verification issues

### Key Design Decisions

**Memory Management**: Stack-based arena allocation with compile-time bounds - no heap usage, predictable memory, enables SPARK proofs.

**Index-Based References**: `Node_Id` as discrete index type instead of pointers - enables quantified expressions and full SPARK verification.

**Ghost Functions**: Extensive ghost code for specifications without runtime overhead - invariants checked at proof time, not runtime.

**Limited Types**: `Document` as limited type ensures single ownership and prevents aliasing issues in proofs.

## Critical Invariants Maintained

1. **DOM Well-formedness**: `Is_Well_Formed` type invariant on every Document
2. **Memory Safety**: `No_Memory_Leaks` - all nodes properly owned and tracked
3. **Tree Acyclicity**: No cycles in parent-child relationships
4. **Depth Bounds**: Maximum tree depth (1000) prevents stack overflow
5. **UTF-8 Validity**: All strings maintain valid UTF-8 encoding
6. **Schema Bounds**: `Schema_Invariant` ensures counts stay within configured maximums

## Memory Configuration

Default limits (suitable for ~50KB documents):
- 10,000 nodes maximum
- 1MB string storage
- ~1.7MB stack space required

For larger documents, either:
1. Increase stack size in linker options (see MEMORY.md)
2. Modify constants in `src/sml-memory_model.ads` and rebuild

## Common Development Tasks

### Running Tests
```bash
# Build and run parser tests
alr exec -- gprbuild -P test_parser.gpr
bin/test_parser

# Build and run schema tests
alr exec -- gprbuild -P test_schema.gpr
bin/test_schema

# Build and run examples (includes schema loader tests)
alr exec -- gprbuild -P examples.gpr
bin/test_schema_loader
```

### Adding New Test Cases
- Parser tests: Edit `test/test_parser.adb`
- Schema tests: Edit `test/test_schema.adb`
- Follow existing patterns for test procedures

### Debugging Proof Failures
```bash
# Generate counterexamples for failed proofs
alr exec -- gnatprove -P sml.gpr --level=4 --counterexamples=on

# Check specific subprogram
alr exec -- gnatprove -P sml.gpr --limit-subp=<subprogram_name>
```

### Memory Tuning
1. For "Node limit reached" errors: increase stack size or `Max_Document_Nodes`
2. For "String limit reached" errors: increase stack size or `Max_String_Storage`
3. See MEMORY.md for detailed guidance

### Code Formatting
```bash
# Format Ada source files
gnatpp -P sml.gpr
```

## Project Structure

```
sml/
├── src/                              # Library sources
│   ├── sml.ads                       # Root package
│   ├── sml-dom*.ads/.adb            # DOM packages
│   ├── sml-schema.ads/.adb          # Schema validation engine
│   ├── sml-utf8.ads/.adb            # UTF-8 processing
│   ├── sml-entities.ads/.adb        # Entity handling
│   └── sml-memory_model.ads/.adb    # Arena allocation
├── test/                            # Library test programs
│   ├── test_parser.adb              # Parser tests
│   └── test_schema.adb              # Schema validation tests
├── examples/                        # Examples and reference code
│   ├── sml_example.adb              # Basic DOM usage
│   ├── schema_validation_example.adb # Schema demo
│   ├── sml-schema-loader.ads/.adb   # Schema loader (reference)
│   └── test_schema_loader.adb       # Loader tests
├── proof/                           # SPARK proof artifacts
├── obj/                             # Build artifacts
├── lib/                             # Library output
├── bin/                             # Executables
├── sml.gpr                          # Main library project
├── test_parser.gpr                  # Parser tests project
├── test_schema.gpr                  # Schema tests project
├── examples.gpr                     # Examples project
└── alire.toml                       # Alire package manifest
```

## Coding Standards

- **Language**: Ada 2022 with SPARK_Mode
- **Indentation**: 3 spaces (`-gnaty3`)
- **Warnings**: All warnings are errors (`-gnatwa -gnatwe`)
- **Naming**: Mixed_Case for identifiers (e.g., `Parse_Result`, `Node_Id`)
- **Files**: Package.Child → `package-child.ads/.adb`
- **Contracts**: Preconditions, postconditions, and type invariants required
- **Ghost Code**: Use liberally for specifications

## Performance Guarantees

**Parser**:
- O(n) single-pass parsing
- No backtracking
- Sequential input access (cache-friendly)

**DOM Operations**:
- O(1) navigation (parent, child, sibling)
- O(1) property access (kind, name, text)
- O(n) tree walks with sequential access

**Memory**:
- O(1) allocation from arena pools
- Zero heap allocations
- Bounded memory usage (compile-time limits)

## Troubleshooting

### STORAGE_ERROR : stack overflow
Increase stack size in project file:
```ada
package Linker is
   for Linker_Options use ("-Wl,-stack_size,0x4000000");  -- 64MB
end Linker;
```

### Proof failures
1. Add loop invariants if missing
2. Break complex postconditions into lemmas
3. Use ghost variables to track state
4. Increase proof timeout/level if needed

### Build errors on macOS
Ensure linker can find system libraries:
```ada
package Linker is
   for Linker_Options use ("-L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib");
end Linker;
```

## Schema Validation

### Core Library: SML.Schema

The schema validation engine is part of the core library (src/sml-schema.*) with full SPARK verification.

**Building Schemas Programmatically:**
```ada
with SML.Schema; use SML.Schema;

Schema : Schema_Document;
Port_Type : Simple_Type_Definition;
Config_Element : Element_Definition;
Success : Boolean;

-- Initialize
Initialize (Schema);

-- Define port number type (1-65535)
Port_Type.Name := To_Bounded_String ("portType");
Port_Type.Base_Type := Integer_Type;
Port_Type.Min_Value := 1;
Port_Type.Max_Value := 65535;
Add_Simple_Type (Schema, Port_Type, Success);

-- Define root element
Config_Element.Name := To_Bounded_String ("config");
Config_Element.Type_Name := To_Bounded_String ("configType");
Add_Element (Schema, Config_Element, Success);

-- Validate document
Result := Validate_Document (Schema, Doc);
if Result.Status = Valid then
   -- Success!
else
   Put_Line (To_String (Result.Error_Message));
end if;
```

### Reference Implementation: SML.Schema.Loader

The schema loader (examples/sml-schema-loader.*)  is reference code for loading schemas from SML documents.

**Architecture:**
- Uses exception-based pattern for limited type returns (proven in sml-dom-parser.adb)
- Parse_Integer marked SPARK_Mode => Off (uses Integer'Value)
- All other functions maintain SPARK_Mode => On
- Complete working implementation users can copy/adapt

**Usage Pattern:**
```ada
with SML.Schema.Loader;  -- From examples/

-- Parse schema document
Schema_Parse := SML.DOM.Parser.Parse (Schema_SML);

-- Load into Schema_Document
Schema_Load := SML.Schema.Loader.Load_Schema (Schema_Parse.Doc);

if Schema_Load.Success then
   -- Use Schema_Load.Schema for validation
   Result := Validate_Document (Schema_Load.Schema, Instance_Doc);
end if;
```

### Testing Schema Functionality

```bash
# Core validation tests (7 tests)
bin/test_schema

# Schema loader tests (8 tests)
bin/test_schema_loader

# End-to-end demo
bin/schema_validation_example
```

### Schema Language Features

See [SCHEMA_SPEC.md](SCHEMA_SPEC.md) for complete specification.

**Supported:**
- Simple types: integer, boolean, decimal, string
- Integer ranges (minValue, maxValue)
- String enumerations (up to 20 values)
- Complex types with sequence or choice models
- Cardinality constraints (minOccurs, maxOccurs)
- "unbounded" maxOccurs support

**Not Supported (by design for SPARK):**
- Recursive type definitions
- XPath expressions
- Regular expression patterns
- Attributes (SML has no attributes)

## Further Documentation

- **MEMORY.md**: Detailed memory configuration and tuning guide
- **README.md**: Project overview and quick start
- **SCHEMA_SPEC.md**: Complete schema language specification
- **SCHEMA_IMPLEMENTATION_PLAN.md**: Implementation roadmap (historical)
- **proof/**: SPARK verification session data and logs