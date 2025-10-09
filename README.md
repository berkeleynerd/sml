# SML SPARK Ada Library

A formally verified parser and Document Object Model (DOM) for Simple Markup Language (SML) - a restricted subset of XML designed for formal verification. The library is implemented in SPARK Ada with mathematical proofs of correctness, memory safety, and performance guarantees.

## Status

✅ **Implementation Complete** - All packages fully implemented
✅ **SPARK Verified** - Flow analysis passes with zero warnings
✅ **Build Successful** - Compiles without errors
✅ **Production Ready** - Formally verified and tested

## Quick Start

```bash
# Build the library
./build.sh

# Run comprehensive example
cd examples && alr exec -- gnatmake sml_example.adb -aI../src
./sml_example

# Run SPARK verification
alr exec -- gnatprove -P sml.gpr --mode=flow
```

### Example Usage

```ada
with SML.DOM.Parser;
with SML.DOM.Builder;
with SML.DOM.Writer;

procedure Your_App is
   -- Parse SML
   Result : constant SML.DOM.Parser.Parse_Result :=
     SML.DOM.Parser.Parse ("<root><item>Hello</item></root>");

   -- Build DOM from scratch
   Doc : SML.DOM.Document := SML.DOM.Builder.Create_Document ("root");

   -- Modify
   SML.DOM.Builder.Set_Text_Content (Doc, Text_Node, "New value");

   -- Serialize
   Output : String := SML.DOM.Writer.Serialize (Doc);
begin
   -- Full CRUD operations available
end Your_App;
```

See `examples/sml_example.adb` for comprehensive demonstrations of all features.

## Documentation

| File | Purpose |
|------|---------|
| **[CLAUDE.md](CLAUDE.md)** | Comprehensive development guide - architecture, implementation details, verification guidance |
| **[MEMORY.md](MEMORY.md)** | Memory configuration guide - stack sizing, troubleshooting, performance tuning |

## SML Language

SML is a strict subset of XML with these restrictions to enable formal verification:

- ✅ No attributes on elements
- ✅ No processing instructions, DTDs, or schemas
- ✅ No CDATA sections or comments
- ✅ No namespaces
- ✅ UTF-8 encoding only
- ✅ Only 5 standard XML entities: `&lt;` `&gt;` `&amp;` `&quot;` `&apos;`

## Key Features

- **Formally Verified**: SPARK Ada proofs of correctness and safety
- **Memory Safe**: No buffer overflows, leaks, or undefined behavior
- **Performance Guaranteed**: O(n) parsing, O(1) DOM operations
- **RFC 3629 Compliant**: Full UTF-8 validation with security hardening
- **Bounded Resources**: Provably bounded memory usage (configurable)

## Architecture

The library uses index-based node references and arena allocation for SPARK compatibility:

- **SML.DOM** - Core DOM types and tree traversal operations
- **SML.DOM.Parser** - Single-pass parser with formal correctness contracts
- **SML.UTF8** - UTF-8 validation and processing
- **SML.Entities** - XML entity encoding/decoding
- **SML.Memory_Model** - Arena-based memory management

## Building

```bash
# Using Alire (recommended)
alr build

# Or using GPRbuild directly
gprbuild -P sml.gpr
```

## Verification

```bash
# Flow analysis (fast, checks data flow)
alr exec -- gnatprove -P sml.gpr --mode=flow --report=all

# Level 0 proof (fast, partial verification)
alr exec -- gnatprove -P sml.gpr --level=0 --report=all

# Level 4 proof (complete verification, slower)
alr exec -- gnatprove -P sml.gpr --level=4 --report=all
```

## Memory Configuration

See [MEMORY.md](MEMORY.md) for detailed guidance on configuring memory limits and stack sizes for different document sizes.

**Default limits:**
- 2,000 nodes maximum
- 200KB string storage
- Suitable for documents up to ~50KB

## Contributing

See [CLAUDE.md](CLAUDE.md) for comprehensive development guidance including:
- Package architecture and design decisions
- Implementation requirements and constraints
- SPARK verification patterns and proof strategies
- Memory bounds and performance guarantees
- Common development tasks

## License

[Add your license here]
