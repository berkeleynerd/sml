# Specification: SPARK Ada Simple Markup Language (SML) Library

## Project Overview

A formally verified XML parser and DOM library for a restricted subset of XML called Simple Markup Language (SML), implemented in SPARK Ada with mathematical proofs of correctness.

## Primary Requirements

### 1. Language Restrictions (SML Subset)

The parser MUST enforce these restrictions compared to full XML:
- ✅ Elements with text content only (no mixed content)
- ✅ No attributes on any elements
- ✅ No processing instructions (`<?...?>`)
- ✅ No DTD or schema declarations
- ✅ No CDATA sections (`<![CDATA[...]]>`)
- ✅ No comments (`<!--...-->`)
- ✅ No namespaces or prefixes
- ✅ UTF-8 encoding exclusively
- ✅ Only 5 standard entities: `&lt;` `&gt;` `&amp;` `&quot;` `&apos;`

### 2. Formal Verification Requirements

The implementation MUST be proven correct using SPARK 2014:
- **Memory Safety**: No buffer overflows, no memory leaks, no dangling pointers
- **Absence of Runtime Errors**: No exceptions possible at runtime
- **Functional Correctness**: Parser accepts all and only valid SML documents
- **Termination**: All functions provably terminate
- **Data Invariants**: DOM tree maintains well-formedness at all times

### 3. Performance Requirements

- Parse documents up to 10MB in reasonable time (< 1 second)
- Support DOM trees up to depth 1000
- Support elements with up to 10,000 children
- Constant-time node traversal operations
- Linear-time parsing relative to input size

### 4. API Requirements

The library MUST provide:
- Type-safe DOM representation
- Read-only tree traversal API
- Detailed error reporting with position information
- UTF-8 validation utilities
- Entity reference handling

## Technical Constraints

### SPARK Ada Constraints
- SPARK_Mode must be On for all packages
- No access types in public API (use private types)
- No aliasing that prevents proof
- No recursion (use iteration with loop invariants)
- All loops must have variants for termination proof

### Ada 2012 Requirements
- Use Ada 2012 features:
  - Preconditions and postconditions
  - Type invariants
  - Expression functions
  - Quantified expressions
- Follow Ada Quality and Style Guide

### Verification Levels
Must achieve SPARK proof at:
- Level 0: Fast partial proof (development)
- Level 2: Automatic proof (CI/CD)
- Level 4: All proofs complete (release)

## Functional Specifications

### Parser Behavior

#### Valid Input
For valid SML input, the parser MUST:
1. Return Success status
2. Produce a well-formed DOM tree
3. Preserve all text content exactly
4. Expand entity references correctly
5. Track accurate position information

#### Invalid Input
For invalid input, the parser MUST:
1. Return Failure status
2. Provide specific error kind
3. Report exact error position (line, column, byte offset)
4. Give helpful error message
5. Never crash or raise exceptions

### DOM Operations

All DOM operations MUST:
- Maintain tree invariants
- Complete in bounded time
- Use bounded stack space
- Return valid results or Null_Node
- Never expose internal representation

## Quality Attributes

### Reliability
- 100% proof coverage at SPARK level 4
- No unproven verification conditions
- Complete formal verification of all properties

### Usability
- Clear, type-safe API
- Comprehensive error messages
- Good documentation with examples
- Intuitive function names

### Maintainability
- Modular package structure
- Clear separation of concerns
- Ghost code for proof clarity
- Documented design decisions

### Portability
- Pure Ada 2012 (no system dependencies)
- No compiler-specific features
- Works on any GNAT version supporting SPARK 2014

## Success Criteria

The project is complete when:

1. **All packages implemented** with bodies (`.adb` files)
2. **100% SPARK proof** at level 4 with no unproven VCs
3. **All formal properties proven** including:
   - Memory safety for all operations
   - Functional correctness per specifications
   - Termination of all functions
   - Invariant preservation
4. **Documentation complete** including:
   - API reference
   - Usage examples
   - Proof strategy document
5. **Performance validated** meeting all requirements
6. **All postconditions proven** without assumptions

## Development Methodology

### Verification-Driven Development (VDD)
1. Write specifications first
2. Add contracts (pre/post/invariants)
3. Implement with proof in mind
4. Strengthen contracts iteratively
5. Add ghost code as needed

### Incremental Proof Strategy
1. Start with type safety
2. Add absence of runtime errors
3. Prove functional properties
4. Achieve full functional correctness

### Proof Strategy
Formal verification approach:
1. Prove specifications are consistent
2. Validate contracts against requirements
3. Verify performance bounds formally
4. Prove error detection completeness

## Risk Mitigation

### Technical Risks
- **Complex proofs**: Mitigate with lemmas and ghost code
- **Performance**: Profile early, optimize carefully
- **Proof time**: Use proof decomposition, parallelize

### Project Risks
- **Scope creep**: Strictly enforce SML restrictions
- **Verification difficulty**: Start simple, add complexity
- **Integration issues**: Define interfaces early

## Deliverables

### Core Deliverables
1. Complete SPARK Ada source code
2. GNAT project file (`.gpr`)
3. Proof artifacts and reports
4. Proof verification scripts
5. Documentation (HTML and PDF)

### Optional Deliverables
1. Example applications
2. Performance benchmarks
3. Formal proof paper
4. Tutorial materials

## Timeline Estimates

- Phase 1-2 (Foundation & UTF-8): 2-3 days
- Phase 3-4 (Entities & DOM): 3-4 days
- Phase 5 (Parser): 4-5 days
- Phase 6-7 (Proofs & Validation): 3-4 days
- Phase 8 (Documentation): 2-3 days

**Total estimate**: 14-19 days of focused development

## Acceptance Criteria

The following must succeed for acceptance:

```bash
# Compilation without warnings
gnatmake -P sml.gpr -gnatwa -gnatwe

# Full proof at maximum level
gnatprove -P sml.gpr --level=4 --report=all

# Verify no unproven VCs
gnatprove -P sml.gpr --report=provers | grep "unproved" | wc -l  # Must be 0

# Performance validation (via example program)
time ./sml_validate large_test.sml  # < 1 second

# Example programs compile and run
./sml_validate valid_examples/*.sml
```

## Future Enhancements (Out of Scope)

These are NOT required but could be added later:
- Streaming parser API
- DOM modification operations
- Pretty printing with formatting
- Schema validation
- XPath subset support
- XML output generation

---

*This specification defines the complete requirements for the SML SPARK Ada library. Any changes must be documented and justified.*