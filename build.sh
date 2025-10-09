#!/bin/bash
##############################################################################
# SML Library Build Script
# Builds the SML library and example programs
##############################################################################

set -e  # Exit on error

echo "================================================"
echo "Building SML SPARK Ada Library"
echo "================================================"
echo

# Clean previous builds
echo "Cleaning previous build artifacts..."
alr clean
echo "✓ Clean complete"
echo

# Build the library
echo "Building SML library..."
alr build
echo "✓ Library build complete"
echo

# Build examples
if [ -f "examples/dom_example.adb" ]; then
    echo "Building dom_example..."
    echo "Note: Example uses library from obj/development"
    echo "      Run manually: cd examples && alr exec -- gnatmake dom_example.adb -aI../src -aO../obj/development"
    echo "⚠ Example requires manual build (no GPR file yet)"
else
    echo "⚠ No examples found"
fi

echo
echo "================================================"
echo "Build Summary"
echo "================================================"
echo "Library:  ✅ SUCCESS"
echo "Examples: ℹ️  Manual build required"
echo
echo "Next steps:"
echo "  Verify: alr exec -- gnatprove -P sml.gpr --mode=flow"
echo "  Test:   cd examples && alr exec -- gnatmake dom_example.adb -aI../src"
echo "================================================"
