# SML Schema Validation Implementation Plan

## Overview
This document outlines the incremental implementation of schema validation capabilities for the SML (Simple Markup Language) library. The plan prioritizes fixing critical safety issues first, then implements schema validation step-by-step while maintaining SPARK Level 0 verification at each stage.

## Key Design Decisions
- **No XPath support**: Dropped entirely (not needed for use cases)
- **Schema-first approach**: Implement schema validation before fixing non-critical verification issues
- **Self-hosting**: Express schema language in SML itself
- **Target use cases**: Configuration files and data interchange
- **Incremental approach**: Each step maintains build, examples, and SPARK Level 0

## Phase 1: Fix Critical Safety Issues (10 high-priority overflow checks)
**Goal**: Resolve all high-priority overflow/underflow checks to ensure safety

### 1.1 Fix sml-entities.adb overflow issues (3 issues)
- Line 37: `Position + 1` overflow in `Is_Entity_Start`
- Line 39: `Position + 6` overflow in entity boundary check
- Line 249: `Text'Length * 6` overflow in `Max_Encoded_Length`

**Fix approach**: Add explicit range checks and preconditions to ensure operations stay within Natural'Last

### 1.2 Fix sml-dom-parser.adb underflow issues (5 issues)
- Line 1390: `Input'Last - 1` underflow check
- Line 1408: `Input'Last - 1` underflow check
- Line 1419: `Input'Last - 8` underflow check
- Line 1430: `Input'Last - 8` underflow check
- Line 1441: `Input'Last - 3` underflow check

**Fix approach**: Add preconditions requiring minimum input length for these operations

### 1.3 Verify and Commit
```bash
alr exec -- gnatprove -P sml.gpr --level=0 --report=all
# Ensure all high-priority issues resolved
git add -A
git commit -m "fix: resolve 10 critical overflow/underflow safety issues"
```

## Phase 2: Design Schema Language Specification
**Goal**: Define schema language expressible in SML

### 2.1 Schema Structure Design
```xml
<schema>
  <element name="config">
    <sequence>
      <element name="database" type="database-config" minOccurs="1" maxOccurs="1"/>
      <element name="logging" type="logging-config" minOccurs="0" maxOccurs="1"/>
    </sequence>
  </element>

  <complexType name="database-config">
    <sequence>
      <element name="host" type="string"/>
      <element name="port" type="integer" minValue="1" maxValue="65535"/>
      <element name="credentials" type="credentials-type"/>
    </sequence>
  </complexType>

  <simpleType name="log-level">
    <enumeration>
      <value>DEBUG</value>
      <value>INFO</value>
      <value>ERROR</value>
    </enumeration>
  </simpleType>
</schema>
```

### 2.2 Create Documentation
- Write SCHEMA_SPEC.md with complete language specification
- Create example schemas for common use cases
- Document validation rules and error reporting

### 2.3 Commit Design
```bash
git add SCHEMA_SPEC.md examples/schemas/
git commit -m "docs: add SML schema language specification and examples"
```

## Phase 3: Implement Core Schema Types
**Goal**: Basic schema representation without validation logic

### 3.1 Create SML.Schema Package
```ada
-- src/sml-schema.ads
package SML.Schema is
   pragma SPARK_Mode;

   type Element_Definition is record
      Name : Bounded_String;
      Type_Name : Bounded_String;
      Min_Occurs : Natural := 1;
      Max_Occurs : Natural := 1;
   end record;

   type Content_Model_Kind is (Sequence, Choice, Simple);

   type Schema_Document is limited private;

private
   -- Implementation details
end SML.Schema;
```

### 3.2 Implement Element Vocabulary Constraints
- Add `Is_Valid_Element_Name` function
- Implement vocabulary checking against schema
- Create error reporting mechanism

### 3.3 Verify and Commit
```bash
alr exec -- gnatprove -P sml.gpr --level=0 -u sml-schema
./build.sh
git add src/sml-schema.*
git commit -m "feat: add core SML.Schema package with element vocabulary validation"
```

## Phase 4: Structure and Cardinality Validation
**Goal**: Validate parent-child relationships and element counts

### 4.1 Implement Parent-Child Structure Rules
```ada
function Is_Valid_Child (Schema : Schema_Document;
                         Parent : Element_Definition;
                         Child : Node_Id) return Boolean
  with Ghost;
```

### 4.2 Add Min/Max Cardinality Validation
```ada
function Check_Cardinality (Schema : Schema_Document;
                           Element : Element_Definition;
                           Count : Natural) return Validation_Result;
```

### 4.3 Verify and Commit
```bash
alr exec -- gnatprove -P sml.gpr --level=0 -u sml-schema
./build.sh
bin/test_parser  # Run tests
git add -A
git commit -m "feat: add structure and cardinality validation to schema"
```

## Phase 5: Content Type Validation
**Goal**: Validate element content against type constraints

### 5.1 Implement Simple Type Validation
```ada
type Simple_Type_Kind is (String_Type, Integer_Type, Boolean_Type, Enumeration);

function Validate_Content (Schema : Schema_Document;
                          Type_Def : Simple_Type_Definition;
                          Content : String) return Validation_Result;
```

### 5.2 Add Sequence and Choice Groups
```ada
type Group_Kind is (Sequence_Group, Choice_Group);

function Validate_Group (Schema : Schema_Document;
                        Group : Group_Definition;
                        Children : Node_Array) return Validation_Result;
```

### 5.3 Verify and Commit
```bash
alr exec -- gnatprove -P sml.gpr --level=0 -u sml-schema
./build.sh
git add -A
git commit -m "feat: add content type and group validation to schema"
```

## Phase 6: Schema Parser and Integration
**Goal**: Parse schema from SML and integrate with DOM parser

### 6.1 Create SML.Schema.Parser
```ada
-- src/sml-schema-parser.ads
package SML.Schema.Parser is
   pragma SPARK_Mode;

   function Parse_Schema (Doc : Document) return Schema_Result
     with Pre => Is_Well_Formed (Doc);
end SML.Schema.Parser;
```

### 6.2 Integrate with DOM Parser
```ada
-- Add to sml-dom-parser.ads
function Parse_With_Schema (Input : String;
                           Schema : Schema_Document) return Parse_Result
  with Pre => Input'Length > 0;
```

### 6.3 Verify and Commit
```bash
alr exec -- gnatprove -P sml.gpr --level=0 --report=all
./build.sh
bin/test_parser
git add -A
git commit -m "feat: add schema parser and DOM integration"
```

## Phase 7: Testing and Documentation
**Goal**: Comprehensive testing and production readiness

### 7.1 Add Test Cases
- Valid document tests (positive cases)
- Invalid document tests (negative cases)
- Edge cases (boundary conditions)
- Performance tests with large schemas

### 7.2 Create Examples
```ada
-- examples/schema_validation.adb
procedure Schema_Validation is
   Schema : Schema_Document;
   Doc : Document;
   Result : Validation_Result;
begin
   -- Load and validate configuration file
   Schema := Parse_Schema_File ("config.xsd.sml");
   Doc := Parse_File ("app-config.sml");
   Result := Validate (Doc, Schema);
end Schema_Validation;
```

### 7.3 Final Verification and Commit
```bash
alr exec -- gnatprove -P sml.gpr --level=4 --report=all
./build.sh
bin/test_parser
bin/schema_validation
git add -A
git commit -m "feat: complete schema validation with tests and examples"
```

## Success Criteria for Each Phase

### Phase Completion Checklist
- [ ] Code compiles without errors
- [ ] Examples run successfully
- [ ] SPARK Level 0 verification passes
- [ ] No new high-priority issues introduced
- [ ] Tests pass (if applicable)
- [ ] Documentation updated
- [ ] Changes committed to git

### Verification Commands
```bash
# Quick verification (after each change)
alr build
alr exec -- gnatprove -P sml.gpr --level=0 --report=all | grep "high:"

# Full verification (before commit)
./build.sh
bin/test_parser
alr exec -- gnatprove -P sml.gpr --level=0 --report=all

# Check for regressions
git diff HEAD~1 proof.log | grep "high:"
```

## Implementation Timeline
- **Phase 1**: 2-3 hours (critical fixes)
- **Phase 2**: 1-2 hours (design and documentation)
- **Phase 3**: 3-4 hours (core schema types)
- **Phase 4**: 3-4 hours (structure validation)
- **Phase 5**: 4-5 hours (content types)
- **Phase 6**: 4-5 hours (parser integration)
- **Phase 7**: 2-3 hours (testing and polish)

**Total estimate**: 19-26 hours of focused work

## Deferred Work
The following 462 medium-priority issues will be addressed AFTER schema implementation:
- Medium overflow checks in loop counters
- Range checks that cannot be statically proven
- Complex postconditions requiring additional ghost code

These can be systematically addressed once the schema feature is complete and tested.

## Risk Mitigation
1. **Build breaks**: Keep changes minimal, test after each modification
2. **Verification failures**: Start with Level 0, increase gradually
3. **Performance**: Profile after implementation, optimize only if needed
4. **Compatibility**: Ensure all existing tests continue to pass
5. **Complexity**: Use ghost code liberally for proofs without runtime cost