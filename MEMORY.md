# SML Memory Configuration Guide

## Overview

The SML library uses stack-based arena allocation for SPARK compliance and formal verification. All memory is allocated on the process stack, which provides deterministic behavior and enables complete memory safety proofs.

## Default Memory Limits

The library is configured with conservative defaults that fit on typical process stacks:

- **Maximum nodes**: 10,000 (elements + text nodes combined)
- **String storage**: 1MB total
- **Stack space required**: ~1.7MB per parse operation
- **Suitable for**: SML documents up to ~50KB input size

### Memory Breakdown

```
Per Document allocation:
├── Node array:      640KB  (10,000 nodes × 64 bytes)
├── String storage:  1MB    (text content after entity expansion)
└── Parser context:  ~100KB (temporary during parsing)
                     ------
Total:               ~1.7MB per parse operation
```

### Document Capacity

With default settings, you can parse documents with:
- Up to 10,000 total nodes (elements and text combined)
- Approximately 3,000-5,000 elements (depending on nesting depth)
- 1MB of text content (after entity reference expansion)
- Input files up to ~50KB of SML markup

## Handling Larger Documents

If you encounter "Node limit reached" or "String limit reached" errors, or if you're parsing documents larger than 50KB, you have two options:

### Option 1: Increase Stack Size (Recommended)

Increase your application's stack size at link time. This is the simplest approach and doesn't require rebuilding the library.

#### macOS / Linux (GNAT)

Add to your `.gpr` project file:

```ada
package Linker is
   for Linker_Options use ("-Wl,-stack_size,0x4000000");  -- 64MB stack
end Linker;
```

#### Windows (GNAT)

```ada
package Linker is
   for Linker_Options use ("-Wl,--stack,67108864");  -- 64MB stack
end Linker;
```

#### Runtime (Unix/Linux)

You can also increase stack size at runtime:

```bash
# Set stack size to 64MB
ulimit -s 65536

# Run your application
./your_application
```

#### Recommended Stack Sizes

- **Small documents** (<50KB): 8MB stack (default on most systems)
- **Medium documents** (50KB-500KB): 32MB stack
- **Large documents** (500KB-5MB): 64MB stack
- **Very large documents** (>5MB): 128MB+ stack

### Option 2: Modify Library Constants

If you need to permanently change the limits for your use case, you can modify the constants in `src/sml-memory_model.ads` and rebuild the library.

1. Edit `src/sml-memory_model.ads`:

```ada
--  Increase these constants as needed:
Max_Document_Nodes : constant Natural := 50_000;      -- 5x increase
Max_String_Storage : constant Natural := 5_000_000;   -- 5x increase
```

2. Rebuild the library:

```bash
alr clean
alr build
```

3. Rebuild your application against the modified library.

**Note**: Changing these constants requires proportionally more stack space. The formula is approximately:

```
Stack needed ≈ (Max_Document_Nodes × 64 + Max_String_Storage + 100KB)
```

## Error Messages

The parser provides helpful error messages when limits are exceeded:

- **"Input exceeds memory limits. See SML.Memory_Model"**
  The input file is too large. Check the input size limit (~300KB with defaults).

- **"Node limit reached. Increase stack or see SML.Memory_Model"**
  Too many elements/text nodes. Increase stack size or node limit.

- **"String limit reached. Increase stack or see SML.Memory_Model"**
  Too much text content. Increase stack size or string storage limit.

## Memory Safety

The SML library is formally verified with SPARK to guarantee:

- **No memory leaks**: All allocated memory is properly tracked and freed
- **No buffer overflows**: All array accesses are bounds-checked
- **No undefined behavior**: All operations have well-defined semantics
- **Deterministic allocation**: Stack-based allocation provides predictable behavior

The stack-based approach ensures that:
1. Memory is automatically reclaimed when functions return
2. No heap fragmentation can occur
3. Allocation is deterministic and fast (O(1))
4. All memory usage is statically provable

## Performance Characteristics

### Memory Allocation

- **Node allocation**: O(1) - simple array index increment
- **String allocation**: O(1) - simple pointer bump
- **Total parse operation**: O(n) where n is input size

### Cache Efficiency

The arena-based approach provides excellent cache locality:
- Nodes stored contiguously in array
- Sequential access patterns during parsing
- Minimal pointer chasing during traversal

## Examples

### Example 1: Default Configuration

```ada
--  Parse a small document (works with default 8MB stack)
with SML.DOM.Parser;

procedure Small_Example is
   Result : constant SML.DOM.Parser.Parse_Result :=
     SML.DOM.Parser.Parse ("<root><child>text</child></root>");
begin
   if Result.Success then
      --  Process document...
   end if;
end Small_Example;
```

### Example 2: Large Document with Increased Stack

```ada
--  my_project.gpr
project My_Project is
   for Source_Dirs use ("src");
   for Main use ("large_example.adb");

   package Linker is
      for Linker_Options use ("-Wl,-stack_size,0x4000000");  -- 64MB
   end Linker;
end My_Project;
```

```ada
--  large_example.adb
with Ada.Text_IO;
with SML.DOM.Parser;

procedure Large_Example is
   --  Can now handle documents up to several megabytes
   Result : constant SML.DOM.Parser.Parse_Result :=
     SML.DOM.Parser.Parse (Large_SML_String);
begin
   if Result.Success then
      Ada.Text_IO.Put_Line ("Large document parsed successfully!");
   else
      Ada.Text_IO.Put_Line ("Error: " &
        Result.Error.Message (1 .. Result.Error.Msg_Length));
   end if;
end Large_Example;
```

### Example 3: Modified Constants for Specific Use Case

If you're building an application that always handles large documents, modify the library constants:

```ada
--  In src/sml-memory_model.ads:
Max_Document_Nodes : constant Natural := 100_000;     -- 10x increase
Max_String_Storage : constant Natural := 10_000_000;  -- 10x increase
```

Then ensure your linker provides adequate stack:

```ada
--  In your project.gpr:
package Linker is
   for Linker_Options use ("-Wl,-stack_size,0x8000000");  -- 128MB stack
end Linker;
```

## Troubleshooting

### "STORAGE_ERROR : stack overflow"

**Cause**: The process stack is too small for the arena allocations.

**Solution**: Increase stack size using the linker options shown above, or reduce the memory constants in `sml-memory_model.ads`.

### "Input exceeds memory limits"

**Cause**: Input file is larger than 1/3 of `Max_String_Storage`.

**Solution**:
1. Increase stack size and rebuild, OR
2. Increase `Max_String_Storage` constant and rebuild library

### "Node limit reached"

**Cause**: Document has more than `Max_Document_Nodes` elements/text nodes.

**Solution**:
1. Increase stack size and rebuild, OR
2. Increase `Max_Document_Nodes` constant and rebuild library

## Platform-Specific Notes

### macOS (including Apple Silicon M-series)

**Default stack size:** 8MB (8176 KB typically)

**Maximum via ulimit:**
```bash
ulimit -Hs        # Shows hard limit: 65520 KB (~64 MB)
ulimit -s 65520   # Set to maximum
```

**Maximum via linker (recommended for Ada):**
```ada
package Linker is
   -- Practical maximums for Apple Silicon:
   for Linker_Options use ("-Wl,-stack_size,0x4000000");   -- 64 MB
   -- for Linker_Options use ("-Wl,-stack_size,0x8000000");   -- 128 MB
   -- for Linker_Options use ("-Wl,-stack_size,0x10000000");  -- 256 MB
end Linker;
```

**Notes:**
- ulimit hard limit is ~64 MB on macOS 26.1
- Linker flags can specify much larger stacks (up to GBs)
- For SML with default settings, 32-64 MB is recommended
- Apple Silicon handles large stacks efficiently via virtual memory
- **Use linker flags, not ulimit, for Ada programs**

**Verified on:** macOS Darwin 25.0.0 (macOS 26.1), Apple M-series hardware

### Linux

- Default stack size: 8MB (typically)
- Maximum via ulimit: varies by distribution (often 8-64 MB)
- Can be increased with `ulimit -s` or linker flags
- Use `-Wl,-z,stack-size=<bytes>` linker flag
- Check with: `ulimit -Hs` for hard limit

### Windows

- Default stack size: 1MB
- **Important**: Windows has a smaller default stack - increase it!
- Use `-Wl,--stack,<bytes>` linker flag
- Recommended minimum: 16MB for SML library

## Further Reading

- SPARK Ada documentation: https://www.adacore.com/about-spark
- Memory safety proofs: See `proof/` directory
- Arena allocation: See `src/sml-memory_model.ads` for implementation details
