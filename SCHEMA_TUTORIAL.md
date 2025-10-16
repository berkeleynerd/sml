# SML Schema Validation Tutorial

Quick start guide for using SML's formally verified schema validation system.

## Overview

SML Schema provides type-safe validation for configuration files and data interchange with:
- **Formal verification** - 0 high-priority SPARK issues
- **Type constraints** - integer, boolean, decimal, string with ranges
- **Enumerations** - Restrict values to allowed lists
- **Structure rules** - Sequence (ordered) and choice (one-of) models
- **Cardinality** - Required/optional elements with min/max occurrences

## Quick Start: Programmatic Schema Construction

The core SML.Schema package (src/) provides the validation engine. Build schemas programmatically in your application:

### Step 1: Create a Schema

```ada
with SML.Schema;

procedure My_Validator is
   use SML.Schema;

   Schema : Schema_Document;
   Success : Boolean;
begin
   -- Initialize empty schema
   Initialize (Schema);

   -- Schema is now ready for type and element definitions
end My_Validator;
```

### Step 2: Define Types

#### Integer Type with Range

```ada
-- Define port number type (1-65535)
declare
   Port_Type : Simple_Type_Definition :=
     (Name        => To_Bounded_String ("portType"),
      Base_Type   => Integer_Type,
      Min_Value   => 1,
      Max_Value   => 65535,
      Min_Length  => 0,
      Max_Length  => Max_String_Length,
      Enum_Values => [others => Empty_String],
      Enum_Count  => 0);
begin
   Add_Simple_Type (Schema, Port_Type, Success);
   if not Success then
      Put_Line ("Failed to add port type");
   end if;
end;
```

#### Enumeration Type

```ada
-- Define log level enumeration
declare
   Log_Level_Type : Simple_Type_Definition;
begin
   Log_Level_Type.Name := To_Bounded_String ("logLevel");
   Log_Level_Type.Base_Type := String_Type;
   Log_Level_Type.Enum_Count := 4;
   Log_Level_Type.Enum_Values (1) := To_Bounded_String ("DEBUG");
   Log_Level_Type.Enum_Values (2) := To_Bounded_String ("INFO");
   Log_Level_Type.Enum_Values (3) := To_Bounded_String ("WARNING");
   Log_Level_Type.Enum_Values (4) := To_Bounded_String ("ERROR");

   Add_Simple_Type (Schema, Log_Level_Type, Success);
end;
```

#### Complex Type with Sequence

```ada
-- Define database config structure
declare
   DB_Type : Complex_Type_Definition;
begin
   DB_Type.Name := To_Bounded_String ("databaseType");
   DB_Type.Content_Model := Sequence_Model;
   DB_Type.Child_Count := 2;

   -- Required <host> element
   DB_Type.Children (1).Element_Name := To_Bounded_String ("host");
   DB_Type.Children (1).Min_Occurs := 1;
   DB_Type.Children (1).Max_Occurs := 1;

   -- Required <port> element
   DB_Type.Children (2).Element_Name := To_Bounded_String ("port");
   DB_Type.Children (2).Min_Occurs := 1;
   DB_Type.Children (2).Max_Occurs := 1;

   Add_Complex_Type (Schema, DB_Type, Success);
end;
```

### Step 3: Validate Documents

```ada
with SML.DOM.Parser;

-- Parse instance document
declare
   Instance_SML : constant String :=
     "<config><port>8080</port><debug>true</debug></config>";

   Parse_Result : constant SML.DOM.Parser.Parse_Result :=
     SML.DOM.Parser.Parse (Instance_SML);
begin
   if Parse_Result.Success then
      declare
         Validation : constant Validation_Result :=
           Validate_Document (Schema, Parse_Result.Doc);
      begin
         if Validation.Status = Valid then
            Put_Line ("Document is valid!");
         else
            Put_Line ("Validation failed: " &
                     To_String (Validation.Error_Message));
         end if;
      end;
   end if;
end;
```

## Loading Schemas from SML (Optional)

The examples/ directory contains a reference implementation for loading schemas from SML documents.

### Using the Schema Loader

**Copy the loader to your project:**
```bash
cp examples/sml-schema-loader.ads your_project/src/
cp examples/sml-schema-loader.adb your_project/src/
```

**Load schema from SML:**
```ada
with SML.Schema.Loader;

-- Schema as SML string
Schema_SML : constant String :=
  "<schema>" &
  "  <simpleType>" &
  "    <name>portType</name>" &
  "    <restriction>" &
  "      <base>integer</base>" &
  "      <minValue>1</minValue>" &
  "      <maxValue>65535</maxValue>" &
  "    </restriction>" &
  "  </simpleType>" &
  "  <element>" &
  "    <name>config</name>" &
  "    <type>configType</type>" &
  "  </element>" &
  "</schema>";

-- Parse schema document
Schema_Parse : constant SML.DOM.Parser.Parse_Result :=
  SML.DOM.Parser.Parse (Schema_SML);

if Schema_Parse.Success then
   -- Load schema
   Schema_Load : constant SML.Schema.Loader.Schema_Load_Result :=
     SML.Schema.Loader.Load_Schema (Schema_Parse.Doc);

   if Schema_Load.Success then
      -- Use Schema_Load.Schema for validation
      Result := Validate_Document (Schema_Load.Schema, Instance_Doc);
   end if;
end if;
```

## Common Patterns

### Configuration File Validation

```ada
-- Define schema for server config
Schema : Schema_Document;
Initialize (Schema);

-- Add types for host, port, max_connections, etc.
-- Add element definitions
-- Add complex types for structure

-- Validate config file
Config_Result := SML.DOM.Parser.Parse (Config_File_Contents);
Validation := Validate_Document (Schema, Config_Result.Doc);
```

### Data Interchange Validation

```ada
-- Define schema for API messages
Schema : Schema_Document;

-- Add types for message structure
-- Add choice types for different message kinds

-- Validate incoming messages
Message_Result := SML.DOM.Parser.Parse (Network_Data);
Validation := Validate_Document (Schema, Message_Result.Doc);
```

### Type-Safe Settings

```ada
-- Use enumerations for settings
Log_Level_Type.Base_Type := String_Type;
Log_Level_Type.Enum_Values (1) := To_Bounded_String ("DEBUG");
Log_Level_Type.Enum_Values (2) := To_Bounded_String ("INFO");
-- etc.

-- Validation ensures only valid values accepted
```

## Error Handling

Schema validation returns detailed error information:

```ada
Result := Validate_Document (Schema, Doc);

case Result.Status is
   when Valid =>
      Put_Line ("Document is valid");

   when Invalid =>
      Put_Line ("Validation error:");
      Put_Line ("  Message: " & To_String (Result.Error_Message));
      Put_Line ("  Path: " & To_String (Result.Error_Path));
      Put_Line ("  Line: " & Result.Line'Image);
      Put_Line ("  Column: " & Result.Column'Image);
end case;
```

## Complete Example

See `examples/example-schema-validation.adb` for a complete working example demonstrating:
1. Schema definition in SML
2. Loading schema into Schema_Document
3. Validating correct documents
4. Rejecting invalid documents with error messages

Run with:
```bash
bin/example-schema-validation
```

## Testing

The library includes comprehensive test suites:

```bash
# Core validation engine tests (7 tests)
./test/build_tests.sh
bin/test-schema

# Schema loader tests (8 tests)
./examples/build_examples.sh
bin/test-schema-loader
```

## Schema Language Reference

For complete schema language specification including all supported types, constraints, and examples, see [SCHEMA_SPEC.md](SCHEMA_SPEC.md).

## Formal Verification

The core SML.Schema validation engine maintains:
- **0 high-priority SPARK issues** - All critical safety properties proven
- **Type invariants** - Schema bounds formally guaranteed
- **Memory safety** - No buffer overflows or undefined behavior
- **Bounded resources** - Compile-time memory limits

The schema loader (examples/) has minimal SPARK_Mode => Off usage (Integer'Value parsing only) and provides a proven pattern users can adapt.

## Performance

**Schema Validation:**
- O(n) in document size for structure validation
- O(1) type lookups
- O(k) enumeration checks where k = number of enum values
- Zero heap allocations (stack-based)

**Typical Performance:**
- Small documents (<1KB): <1ms validation
- Medium documents (10KB): <10ms validation
- Large documents (100KB): <100ms validation

## Limitations

By design for SPARK compatibility:
- No recursive type definitions
- No XPath or complex path expressions
- No regular expression patterns
- Maximum 100 element definitions per schema
- Maximum 100 type definitions per schema
- Maximum 20 enumeration values per type
- Maximum 20 children per sequence/choice

These limits are configurable in `src/sml-schema.ads`.

## Next Steps

1. Run the examples to see schema validation in action
2. Review SCHEMA_SPEC.md for complete language reference
3. Copy examples/sml-schema-loader.* if you need schema loading
4. Build your own schemas programmatically using SML.Schema API

## Support

See [CLAUDE.md](CLAUDE.md) for:
- Complete package architecture
- Development patterns
- SPARK verification guidance
- Troubleshooting tips
