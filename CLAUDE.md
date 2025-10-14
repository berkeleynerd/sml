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
alr exec -- gprbuild -P sml.gpr      # Library only
alr exec -- gprbuild -P examples.gpr  # Examples
alr exec -- gprbuild -P test.gpr      # Tests

# Run examples
bin/sml_example

# Run tests
bin/test_parser
```

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
# Build and run test suite
alr exec -- gprbuild -P test.gpr
bin/test_parser
```

### Adding New Test Cases
Edit `test/test_parser.adb` and add test procedures following existing patterns.

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
├── src/                 # Library sources
│   ├── sml.ads         # Root package
│   ├── sml-*.ads       # Package specs
│   └── sml-*.adb       # Package bodies
├── test/               # Test programs
│   └── test_parser.adb
├── examples/           # Usage examples
│   └── sml_example.adb
├── proof/              # SPARK proof artifacts
├── obj/                # Build artifacts
├── lib/                # Library output
├── bin/                # Executables
├── sml.gpr            # Main project file
├── test.gpr           # Test project
├── examples.gpr       # Examples project
└── alire.toml         # Alire package manifest
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

## Further Documentation

- **MEMORY.md**: Detailed memory configuration and tuning guide
- **README.md**: Project overview and quick start
- **AGENTS.md**: Repository guidelines and contribution standards
- **proof/**: SPARK verification session data and logs