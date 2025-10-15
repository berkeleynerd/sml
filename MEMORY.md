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

## Quick Reference: Platform-Specific Stack Configuration

| Platform | Linker Flag Syntax | Example (64MB) | Notes |
|----------|-------------------|----------------|-------|
| **macOS** | `-Wl,-stack_size,0xHEX` | `-Wl,-stack_size,0x4000000` | Hexadecimal, ulimit max ~64MB |
| **Linux** | `-Wl,-z,stack-size=DECIMAL` | `-Wl,-z,stack-size=67108864` | Decimal bytes, varies by distro |
| **Windows** | `-Wl,--stack,DECIMAL` | `-Wl,--stack,67108864` | Decimal bytes, default only 1MB! |

**Stack sizes:** 32MB = 0x2000000 (hex) = 33554432 (decimal), 64MB = 0x4000000 (hex) = 67108864 (decimal)

## Handling Larger Documents

If you encounter "Node limit reached" or "String limit reached" errors, or if you're parsing documents larger than 50KB, you have two options:

### Option 1: Increase Stack Size (Recommended)

Increase your application's stack size at link time. This is the simplest approach and doesn't require rebuilding the library.

**Note:** Linker flag syntax is platform-specific. The examples below show platform-specific flags, or see "Cross-Platform Configuration" section below for automatic detection.

#### macOS (GNAT)

Add to your `.gpr` project file:

```ada
package Linker is
   for Linker_Options use ("-Wl,-stack_size,0x4000000");  -- 64MB stack (hex)
end Linker;
```

#### Linux (GNAT with GNU ld)

```ada
package Linker is
   for Linker_Options use ("-Wl,-z,stack-size=67108864");  -- 64MB stack (decimal)
end Linker;
```

**Alternative for some Linux systems:**
```ada
package Linker is
   for Linker_Options use ("-Wl,--stack-size=67108864");  -- 64MB stack
end Linker;
```

#### Windows (GNAT with MinGW)

```ada
package Linker is
   for Linker_Options use ("-Wl,--stack,67108864");  -- 64MB stack (decimal)
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

#### Cross-Platform Configuration (Advanced)

For portable projects that build on multiple platforms, use case statements to auto-detect the OS:

```ada
package Linker is
   type OS_Type is ("macos", "linux", "windows", "unknown");

   -- Detect OS via Alire or environment
   OS : OS_Type := OS_Type'Value
     (external ("ALIRE_OS", external ("OS_DETECT", "unknown")));

   case OS is
      when macos =>
         for Linker_Options use (
            "-L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib",
            "-Wl,-stack_size,0x4000000");  -- 64MB (macOS hexadecimal)

      when linux =>
         for Linker_Options use (
            "-Wl,-z,stack-size=67108864");  -- 64MB (Linux decimal)

      when windows =>
         for Linker_Options use (
            "-Wl,--stack,67108864");  -- 64MB (Windows decimal)

      when unknown =>
         -- Conservative default (works on most Unix-like systems)
         for Linker_Options use ("-Wl,-stack_size,0x4000000");
   end case;
end Linker;
```

**Simpler alternative using external variable:**
```ada
package Linker is
   Stack_Flag : constant String := external ("STACK_FLAG", "-Wl,-stack_size,0x4000000");
   for Linker_Options use (Stack_Flag);
end Linker;
```

Then build with:
```bash
# macOS
gprbuild -P myproject.gpr

# Linux
gprbuild -P myproject.gpr -XSTACK_FLAG="-Wl,-z,stack-size=67108864"

# Windows
gprbuild -P myproject.gpr -XSTACK_FLAG="-Wl,--stack,67108864"
```

**Note:** The SML library's `.gpr` files currently use macOS-specific syntax. Linux and Windows users should modify the Linker package in their project files as shown above.

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

**Default stack size:** 8MB (typically, varies by distribution)

**Maximum via ulimit:**
```bash
ulimit -Hs        # Check hard limit (distribution-specific)
ulimit -s 65536   # Set to 64MB (if allowed)
```
- Common limits: 8MB-64MB (some allow "unlimited")
- Debian/Ubuntu: Often 8MB hard limit
- RHEL/Fedora: Often allows much larger

**Maximum via linker (recommended):**
```ada
package Linker is
   for Linker_Options use ("-Wl,-z,stack-size=67108864");  -- 64MB
   -- Alternative syntax on some systems:
   -- for Linker_Options use ("-Wl,--stack-size=67108864");
end Linker;
```

**Notes:**
- Test which syntax works: `-z,stack-size=` vs `--stack-size=`
- Uses decimal bytes (not hexadecimal like macOS)
- Can specify very large stacks (GBs) if needed
- Virtual memory systems handle this efficiently

### Windows (MinGW/GNAT)

**Default stack size:** 1MB

**⚠️ Critical:** Windows default is **too small** for SML library - you **must** increase it!

**Stack configuration:**
```ada
package Linker is
   for Linker_Options use ("-Wl,--stack,67108864");  -- 64MB
end Linker;
```

**Minimum recommended:** 16MB for SML with default settings

**Notes:**
- Uses decimal bytes
- No ulimit equivalent on Windows
- Must use linker flags
- Stack size is fixed at link time (no runtime adjustment)

## Further Reading

- SPARK Ada documentation: https://www.adacore.com/about-spark
- Memory safety proofs: See `proof/` directory
- Arena allocation: See `src/sml-memory_model.ads` for implementation details
