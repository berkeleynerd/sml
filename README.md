# SML SPARK Ada Library

A formally verified parser and Document Object Model (DOM) for Simple Markup Language (SML) - a restricted subset of XML designed for formal verification. The library is implemented in SPARK Ada with mathematical proofs of correctness, memory safety, and performance guarantees.

## Status

✅ **Implementation Complete** - All packages fully implemented
✅ **SPARK Verified** - Flow analysis passes with zero high-priority issues
✅ **Schema Validation** - Type-safe configuration validation system
✅ **Build Successful** - Compiles without errors
✅ **Production Ready** - Formally verified and tested

## Quick Start

```bash
# Build the core library and tests
alr build -- -cargs:ada -gnat2022 -gnatX0
alr exec -- gprbuild -P test_parser.gpr
alr exec -- gprbuild -P test_schema.gpr

# Run the tests
bin/test_parser
bin/test_schema

# Run SPARK verification
alr exec -- gnatprove -P sml.gpr --mode=prove --level=4 --prover=cvc5 >> proof.log 2>&1
```

## Examples

Examples and integration demos have moved to a separate repository:
`sml_examples` (https://github.com/berkeleynerd/sml_examples).
It contains runnable binaries (`sml_example`, `schema_validation_example`,
`test_schema_loader`) and local fixtures.

## Documentation

| File | Purpose |
|------|---------|
| **[AGENTS.md](AGENTS.md)** | Contributor guide with build, style, and review expectations |
| **[MEMORY.md](MEMORY.md)** | Memory configuration guide - stack sizing, troubleshooting, performance tuning |
| (Additional docs) | Architecture and schema specification (to be added) |

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
- **Schema Validation**: Formally verified type constraints and structure rules
- **RFC 3629 Compliant**: Full UTF-8 validation with security hardening
- **Bounded Resources**: Provably bounded memory usage (configurable)

## Architecture

The library uses index-based node references and arena allocation for SPARK compatibility:

- **SML.DOM** - Core DOM types and tree traversal operations
- **SML.DOM.Parser** - Single-pass parser with formal correctness contracts
- **SML.DOM.Builder** - DOM construction and modification API
- **SML.DOM.Writer** - Serialization to SML format

Ghost code for formal verification is organized into separate `.Proof` child packages:
- **SML.DOM.Proof** - DOM tree well-formedness and structural properties
- **SML.Memory_Model.Proof** - Memory safety proofs and invariants
- **SML.UTF8.Proof** - UTF-8 validation properties
- **SML.Entities.Proof** - Entity encoding/decoding properties
- **SML.Schema** - Schema validation engine with content types, structure rules, and cardinality
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

## Schema Validation

SML includes a formally verified schema validation system for type-safe configuration files and data validation.

### Core Library (src/)

**SML.Schema** - Validation engine with:
- **Element vocabulary** - Define allowed element names
- **Content types** - integer, boolean, decimal, string with ranges/lengths
  - Strings: length, optional prefix/suffix
  - Decimals: min/max range
- **Enumerations** - Restrict values to specific lists (e.g., log levels)
- **Cardinality** - Min/max occurrence constraints (minOccurs, maxOccurs)
- **Structure rules** - Sequence (ordered), choice (one-of), and all (unordered)
  - Sequences enforce strict sibling order; extra elements are rejected; text/whitespace between elements is ignored.
  - Group-level occurs on sequence/choice via child `<minOccurs>/<maxOccurs>`; `unbounded` allowed (not for `all`).
  - `all` follows XSD: `minOccurs` ∈ {0,1}, `maxOccurs` = 1.
- **Type safety** - Formal invariants with 0 high-priority SPARK issues

### Example/Reference Code

See `sml_examples` for a reference `SML.Schema.Loader` implementation
and end-to-end schema validation demos.

### Quick Start: Programmatic Schema

```ada
with SML.Schema;

procedure Validate_Config is
   Schema : Schema_Document;
   Port_Type : Simple_Type_Definition;
   Success : Boolean;
begin
   -- Build schema
   Initialize (Schema);

   Port_Type.Name := To_Bounded_String ("portType");
   Port_Type.Base_Type := Integer_Type;
   Port_Type.Min_Value := 1;
   Port_Type.Max_Value := 65535;
   Add_Simple_Type (Schema, Port_Type, Success);

   -- Validate document
   Result := Validate_Document (Schema, Doc);
   if Result.Status = Valid then
      -- Document is valid!
   end if;
end Validate_Config;
```

### Running Schema Examples

See the `sml_examples` repository for build and run instructions.

### Schema Language

Schemas are expressed in SML itself. A concise schema specification will be added; see the `sml_examples` repository for working examples.

**Example schema:**
```xml
<schema>
  <simpleType>
    <name>portType</name>
    <restriction>
      <base>integer</base>
      <minValue>1</minValue>
      <maxValue>65535</maxValue>
    </restriction>
  </simpleType>

  <element>
    <name>config</name>
    <type>configType</type>
  </element>
</schema>
```

**Loading schemas:** See the loader in `sml_examples/src/` for a reference implementation.

## Contributing

Development guidance and extended documentation will be added soon. For
questions or proposals, please open an issue or PR.

## License

[Add your license here]
