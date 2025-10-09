#!/bin/bash
##############################################################################
# SML Library Build Script
# Builds library and examples using Alire
##############################################################################

set -e

echo "========================================"
echo "Building SML Library and Examples"
echo "========================================"
echo

# Build library
echo "Building library..."
alr build
echo "✅ Library built"
echo

# Build examples (separate project)
echo "Building examples..."
alr exec -- gprbuild -P examples.gpr
echo "✅ Examples built"

echo
echo "========================================"
echo "Build Complete!"
echo "========================================"
echo "  Library:   lib/libSml.a"
echo "  Example:   bin/sml_example"
echo
echo "Next steps:"
echo "  Run:   bin/sml_example"
echo "  Verify: alr exec -- gnatprove -P sml.gpr --mode=flow"
echo "========================================"
