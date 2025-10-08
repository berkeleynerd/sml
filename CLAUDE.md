# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SPARK Ada specification project for a Simple Markup Language (SML) parser and Document Object Model (DOM). SML is a strict subset of XML with significant restrictions to enable formal verification.

## SML Restrictions

SML enforces these constraints (different from full XML):
- No attributes on elements
- No processing instructions (`<?...?>`)
- No DTD or schema declarations
- No CDATA sections (`<![CDATA[...]]>`)
- No comments (`<!--...-->`)
- No namespaces
- UTF-8 encoding only
- Only standard XML entities: `&lt;` `&gt;` `&amp;` `&quot;` `&apos;`

## Build and Verification Commands

```bash
# Compile with GNAT
gnatmake -gnatwa -gnatwe -gnatyyM -gnaty3 -gnatyx -gnatyO sml.ads

# Run SPARK verification
gnatprove -P<project>.gpr --level=4 --report=all

# Check individual package
gnatprove -P<project>.gpr --level=4 -u sml-dom.ads

# Generate proof documentation
gnatprove -P<project>.gpr --output=gnatprove_report.out --report=all
```

## Architecture

### Package Hierarchy

The system uses a hierarchical package structure with `SML` as the root:

1. **SML** - Root package with version information and constants

2. **SML.DOM** - Core DOM types and tree traversal
   - `Unbounded_String` for text storage (avoids variant record issues)
   - `Document` is a limited type owning all nodes
   - `Node_Id` provides safe references
   - Ghost functions specify well-formedness invariants

3. **SML.Parser** - Parsing logic with formal correctness contracts
   - `Parse_Result` discriminated union for type-safe success/failure
   - Ghost functions `Is_Valid_SML` and `Parses_To` specify total correctness
   - Parser state tracking for proof decomposition

4. **SML.UTF8** - UTF-8 validation and navigation
   - Validates byte sequences
   - Provides UTF-8 aware string navigation

5. **SML.Entities** - Entity reference handling
   - Only 5 standard XML entities
   - Expansion and encoding with safety contracts

6. **SML.Proof_Helpers** - Ghost code for verification (not runtime accessible)
   - Lemmas for complex properties
   - Loop invariant templates
   - Induction helpers

### Key Design Decisions

**Memory Management**: `Document` owns all nodes through `Node_Pool` - centralized ownership prevents leaks and enables safe deallocation.

**Ghost Functions**: Extensive use of ghost functions to specify correctness properties without runtime overhead.

**Error Handling**: Parser returns detailed error information (position, line, column, kind) for debugging and formal reasoning.

**Type Safety**: Discriminated unions and preconditions ensure type-safe API usage.

## Critical Invariants

1. **DOM Well-formedness**: Every `Document` maintains `Is_Well_Formed` as a type invariant
2. **Tree Depth**: Maximum depth limited to prevent stack overflow (`Max_Tree_Depth = 1000`)
3. **Children Count**: Maximum children per element (`Max_Children = 10000`)
4. **UTF-8 Validity**: All strings in DOM maintain UTF-8 validity
5. **Memory Safety**: `No_Memory_Leaks` ghost predicate ensures all nodes are properly owned

## Proof Obligations

When modifying specifications, ensure these properties hold:

1. **Parser Soundness**: `Parse` succeeds only for valid SML (`Is_Valid_SML`)
2. **Parser Completeness**: All valid SML can be parsed
3. **Representation Correctness**: `Parses_To` relation accurately maps input to DOM
4. **Memory Safety**: No leaks, no double-free, no dangling references
5. **Termination**: All functions must provably terminate

## Common Development Tasks

### Adding a new DOM operation
1. Add specification to `sml-dom.ads` with appropriate preconditions
2. Add ghost function if needed for postcondition
3. Add corresponding lemma in `sml-proof_helpers.ads` if property is complex
4. Ensure operation preserves `Is_Well_Formed` invariant

### Extending parser capabilities
1. Update `Is_Valid_SML` ghost function in `sml-parser.ads`
2. Add new error kinds if needed
3. Update `Parses_To` relation to specify new behavior
4. Add proof helpers for new parsing constructs

### Strengthening verification
1. If prover fails, add lemma in `SML.Proof_Helpers`
2. Consider adding loop invariants for iterative code
3. Break complex postconditions into smaller, provable parts
4. Use ghost variables to track intermediate state

## Implementation Requirements

### Memory Bounds and Arena Sizes
- **Node Arena**: 1,000,000 nodes maximum
- **String Arena**: 100,000,000 characters maximum
- **Memory Formula**: Memory ≤ Input_Size × 10 + Fixed_Overhead
- **Node Count**: Nodes ≤ Input_Length / 3 (minimum element is 3 chars: `<a>`)
- **String Storage**: ≤ Input_Length × 2 (worst case with entity expansion)
- **Stack Depth**: Max 1000 levels (prevents stack overflow)
- **Children per Node**: Max 10,000 children

### UTF-8 Validation Rules
**Valid Byte Sequences**:
- 1-byte: `00..7F`
- 2-byte: `C2..DF` + `80..BF` (no C0-C1 overlong)
- 3-byte: `E0` + `A0..BF` + `80..BF` (no overlong)
- 3-byte: `E1..EC` + `80..BF` + `80..BF`
- 3-byte: `ED` + `80..9F` + `80..BF` (no surrogates)
- 4-byte: `F0` + `90..BF` + `80..BF` + `80..BF` (no overlong)
- 4-byte: `F4` + `80..8F` + `80..BF` + `80..BF` (max U+10FFFF)

**Security Checks**:
- Reject overlong encodings (e.g., `C0 AF` for `/`)
- Reject surrogates (U+D800-U+DFFF)
- Detect path traversal (`../` encodings)
- Detect script injection (encoded `<script>`)
- Prevent null byte injection

### Performance Guarantees
**Parser Complexity**:
- Overall: O(n) single-pass, no backtracking
- UTF-8 validation: O(n) with bounded lookahead (max 4 bytes)
- Entity expansion: O(1) for standard entities
- Tree building: O(1) per node
- Stack operations: O(1) push/pop

**DOM Operations**:
- Navigation: O(1) - Root, Parent, First_Child, Next_Sibling
- Queries: O(1) - Kind, Name, Text_Value
- Tree walks: O(nodes) with sequential access pattern
- Memory allocation: O(1) from arena pools
- Document finalization: O(nodes) for cleanup

**Cache Behavior**:
- Parser: Sequential input access (>90% cache line utilization)
- DOM: Depth-first traversal matches memory layout
- No pointer chasing in critical paths

### Entity Encoding Rules
**Standard Entities Only**:
- `&lt;` for `<`
- `&gt;` for `>`
- `&amp;` for `&`
- `&quot;` for `"`
- `&apos;` for `'`

**Round-Trip Properties**:
- Encode then decode = identity
- Canonical forms enforced
- No information loss
- Injection-safe (no raw `<` in output)

### Error Detection Requirements
**Detection Precedence** (check in order):
1. UTF-8 errors (invalid sequences, truncation)
2. Lexical errors (invalid entities, bad characters)
3. Syntactic errors (mismatched tags, structure)
4. Semantic errors (well-formedness violations)
5. Resource errors (depth/size limits)

**Error Information**:
- Position (byte offset in input)
- Line and column numbers
- Error kind enumeration
- Actionable error message
- Context extraction available

### Proof Structure Guidance
**Parser Soundness**:
- Simulation invariant: parser states ↔ partial parse trees
- Progress lemma: valid states only transition to valid states
- Completion implies validity per grammar

**Memory Safety**:
- Single ownership model (document owns all nodes)
- Arena allocation prevents fragmentation
- No cycles in ownership graph
- Finalization releases entire subtree

**Entity Bijection**:
- Injective: different texts → different encodings
- Surjective: every valid encoding has a decoding
- Round-trip: decode(encode(x)) = x

**Error Completeness**:
- All invalid input produces errors
- No false positives for valid input
- Most specific error reported first

## Implementation Checklist

### Pre-Implementation Setup
1. **Create GNAT Project File** (`sml.gpr`)
   - Enable SPARK_Mode globally
   - Set proof level configurations
   - Add compiler flags: `-gnatwa -gnatwe -gnatyyM -gnaty3 -gnatyx -gnatyO`
   - Configure separate directories for specs, bodies, proof artifacts

2. **Configure Development Environment**
   - Set up proof verification scripts
   - Configure pre-commit hooks for compilation and SPARK level 1
   - Set up code formatting with gnatpp

### Implementation Order

#### Phase 1: Foundation
- `sml.adb` - Empty body for root package

#### Phase 2: UTF-8 (Critical Foundation)
- `sml-utf8.adb` - Core validation functions
- Test with UTF-8 test vectors from RFC 3629

#### Phase 3: Entity Handling
- `sml-entities.adb` - Entity encoding/decoding
- Ensure bijection properties hold

#### Phase 4: DOM Operations
- `sml-dom.adb` - Tree construction and traversal
- Implement arena-based memory management
- Maintain ownership invariants

#### Phase 5: Parser (Most Complex)
- `sml-parser.adb` - Main parsing logic
- Single-pass, no backtracking
- Proper error detection and reporting

#### Phase 6: Proof Helpers
- `sml-proof_helpers.adb` - Lemma implementations
- May be empty (ghost) or contain proof tactics

#### Phase 7: Ghost Packages
All ghost specification packages (empty bodies):
- `sml-*-*.adb` for all proof specifications

### Verification Commands

```bash
# Initial compilation check
gnatmake -P sml.gpr

# Incremental proof verification (per package)
gnatprove -P sml.gpr --level=2 -u <package>

# Full proof verification
gnatprove -P sml.gpr --level=4 --report=all

# Generate proof report
gnatprove -P sml.gpr --output=proof_report.out --report=all
```

### Proof Goals
- **Level 0**: Fast partial proof (< 1 second)
- **Level 1**: Flow analysis and simple proofs
- **Level 2**: Most VCs proven (< 10 seconds)
- **Level 4**: Complete proofs (< 60 seconds per package)

### Success Criteria
- Zero compilation warnings
- All VCs proven at level 4
- Performance requirements met (10MB in < 1 second)
- Memory bounds respected (1M nodes, 100MB strings)

## Additional Proof Lemmas

These lemmas may be needed during implementation to help SPARK prove key properties:

### Null Safety Lemmas
```ada
-- No null dereferences in traversal
Lemma_Traversal_Null_Safe:
  ∀ N: N = Null_Node → No operations performed

-- Parent operation null-safe
Lemma_Parent_Null_Safe:
  Parent(Doc, N) = Null_Node ∨ Is_Valid_Node(Parent(Doc, N))
```

### Bounds Safety Lemmas
```ada
-- Parser respects input bounds
Lemma_Parser_Respects_Input_Bounds:
  Parser_State.Position ≤ Input'Last + 1

-- Stack depth bounded
Lemma_Parser_Stack_Bounded:
  State.Stack_Depth ≤ Max_Tree_Depth
```

### Ownership Lemmas
```ada
-- All nodes reachable from root
Lemma_All_Nodes_Reachable:
  Owns_Node(Doc, N) → Reachable_From_Root(Doc, N)

-- No cycles in ownership
Lemma_No_Ownership_Cycles:
  Acyclic_Ownership(Doc)
```