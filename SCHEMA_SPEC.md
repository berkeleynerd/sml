# SML Schema Language Specification

## Implementation Status

✅ **Complete and Production Ready**

- Schema language fully specified (this document)
- Core validation engine implemented in `src/sml-schema.ads/.adb`
- Reference loader implemented in `examples/sml-schema-loader.ads/.adb`
- Comprehensive test coverage (16 test procedures: 7 core validation + 9 loader tests)
- **0 high-priority SPARK verification issues**
- Working examples demonstrating all features

**Quick Start:**
```bash
bin/schema_validation_example      # End-to-end demo
bin/test_schema                    # Core validation tests
bin/test_schema_loader             # Loader tests
```

**Documentation:**
- Core API: `src/sml-schema.ads`
- Loader reference: `examples/sml-schema-loader.adb`
- Tutorial: See usage examples in this spec and example programs

---

## Overview

SML Schema defines validation rules for SML documents using SML itself (self-hosting). This specification describes the schema language, its constraints, and validation semantics.

## Design Principles

1. **Self-Hosting**: Schemas are expressed as valid SML documents
2. **Simplicity**: Minimal feature set sufficient for configuration and data interchange
3. **Verifiability**: All validation rules must be formally verifiable in SPARK
4. **No Attributes**: Works within SML's no-attribute constraint
5. **Deterministic**: Validation produces consistent, predictable results

## Schema Structure

### Root Element

Every schema document starts with a `<schema>` root element:

```xml
<schema>
  <!-- Schema definitions -->
</schema>
```

### Element Definitions

Elements are defined with vocabulary, type, and cardinality constraints:

```xml
<element>
  <name>elementName</name>
  <type>typeName</type>
  <minOccurs>0</minOccurs>
  <maxOccurs>unbounded</maxOccurs>
</element>
```

### Type Definitions

#### Simple Types

Simple types define content validation for text elements:

```xml
<simpleType>
  <name>portNumber</name>
  <restriction>
    <base>integer</base>
    <minValue>1</minValue>
    <maxValue>65535</maxValue>
  </restriction>
</simpleType>
```

Base types:
- `string` - Any text content
- `integer` - Signed integer values
- `boolean` - true/false values
- `decimal` - Decimal numbers

#### Complex Types

Complex types define element structure:

```xml
<complexType>
  <name>addressType</name>
  <sequence>
    <element>
      <name>street</name>
      <type>string</type>
    </element>
    <element>
      <name>city</name>
      <type>string</type>
    </element>
    <element>
      <name>zipCode</name>
      <type>zipCodeType</type>
    </element>
  </sequence>
</complexType>
```

### Content Models

#### Sequence

Elements must appear in the specified order:

```xml
<sequence>
  <element>
    <name>first</name>
    <type>string</type>
  </element>
  <element>
    <name>second</name>
    <type>string</type>
  </element>
</sequence>
```

Strict ordering semantics (implemented):
- Siblings are validated left-to-right; required order is enforced.
- Extra elements after the last expected element are rejected.
- Text nodes (including whitespace) are ignored between elements.
- Cardinality (`minOccurs`/`maxOccurs`) applies to each expected item consecutively.

Examples:
```xml
<!-- Expected: <first> then <second> -->
<root>
  <second/>   <!-- Rejected: out of order (expected <first>) -->
  <first/>
</root>

<root>
  <first/>
  <second/>
  <extra/>    <!-- Rejected: unexpected element after sequence -->
</root>
```

#### Choice

Exactly one of the elements must appear:

```xml
<choice>
  <element>
    <name>email</name>
    <type>string</type>
  </element>
  <element>
    <name>phone</name>
    <type>string</type>
  </element>
</choice>
```

### Cardinality

- `minOccurs` - Minimum number of occurrences (default: 1)
- `maxOccurs` - Maximum number of occurrences (default: 1, "unbounded" for unlimited)

### Enumerations

Restrict content to a set of valid values:

```xml
<simpleType>
  <name>logLevel</name>
  <restriction>
    <base>string</base>
    <enumeration>
      <value>DEBUG</value>
      <value>INFO</value>
      <value>WARNING</value>
      <value>ERROR</value>
    </enumeration>
  </restriction>
</simpleType>
```

## Complete Example

### Schema Document

```xml
<schema>
  <!-- Define a simple type for port numbers -->
  <simpleType>
    <name>portType</name>
    <restriction>
      <base>integer</base>
      <minValue>1</minValue>
      <maxValue>65535</maxValue>
    </restriction>
  </simpleType>

  <!-- Define an enumeration for log levels -->
  <simpleType>
    <name>logLevelType</name>
    <restriction>
      <base>string</base>
      <enumeration>
        <value>DEBUG</value>
        <value>INFO</value>
        <value>WARNING</value>
        <value>ERROR</value>
      </enumeration>
    </restriction>
  </simpleType>

  <!-- Define complex type for database configuration -->
  <complexType>
    <name>databaseType</name>
    <sequence>
      <element>
        <name>host</name>
        <type>string</type>
      </element>
      <element>
        <name>port</name>
        <type>portType</type>
      </element>
      <element>
        <name>username</name>
        <type>string</type>
      </element>
      <element>
        <name>password</name>
        <type>string</type>
      </element>
      <element>
        <name>poolSize</name>
        <type>integer</type>
        <minOccurs>0</minOccurs>
        <maxOccurs>1</maxOccurs>
      </element>
    </sequence>
  </complexType>

  <!-- Define complex type for logging configuration -->
  <complexType>
    <name>loggingType</name>
    <sequence>
      <element>
        <name>level</name>
        <type>logLevelType</type>
      </element>
      <element>
        <name>output</name>
        <type>string</type>
        <minOccurs>0</minOccurs>
        <maxOccurs>unbounded</maxOccurs>
      </element>
    </sequence>
  </complexType>

  <!-- Define the root element -->
  <element>
    <name>config</name>
    <type>configType</type>
  </element>

  <!-- Define the main configuration structure -->
  <complexType>
    <name>configType</name>
    <sequence>
      <element>
        <name>database</name>
        <type>databaseType</type>
      </element>
      <element>
        <name>logging</name>
        <type>loggingType</type>
        <minOccurs>0</minOccurs>
      </element>
    </sequence>
  </complexType>
</schema>
```

### Valid Instance Document

```xml
<config>
  <database>
    <host>localhost</host>
    <port>5432</port>
    <username>admin</username>
    <password>secret</password>
    <poolSize>10</poolSize>
  </database>
  <logging>
    <level>INFO</level>
    <output>stdout</output>
    <output>file://logs/app.log</output>
  </logging>
</config>
```

## Validation Rules

### Element Validation

1. **Name Matching**: Element name must match schema definition
2. **Type Checking**: Content must validate against specified type
3. **Cardinality**: Number of occurrences must be within min/max bounds
4. **Order**: For sequences, elements must appear in specified order
5. **Completeness**: All required elements must be present

### Type Validation

1. **String**: Any valid UTF-8 text
2. **Integer**: Valid integer within Natural range
3. **Boolean**: Exactly "true" or "false"
4. **Decimal**: Valid decimal number representation

### Error Reporting

Validation errors include:
- Element path (e.g., "/config/database/port")
- Error type (e.g., "Type Mismatch", "Missing Required Element")
- Expected vs actual values
- Line and column numbers when available

## Implementation Constraints

### Memory Bounds

- Maximum element definitions: 100
- Maximum type definitions: 100 (simple + complex combined)
- Maximum enumeration values: 20 per type
- Maximum sequence/choice elements: 20 per group
- Maximum nesting depth: 10 levels

### Performance Guarantees

- O(n) validation for document size n
- O(1) type lookup with hash tables
- Single-pass validation (no backtracking)

## Future Extensions

The following features are intentionally deferred:
- Pattern matching (regular expressions)
- Key/keyref constraints
- Union types
- Default values
- Fixed values
- Whitespace normalization

These can be added incrementally while maintaining backward compatibility.
