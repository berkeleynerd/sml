#!/bin/bash
# Build example executables

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building SML example programs..."
echo

# Build all examples using gprbuild (works fine with multi-main projects)
echo "Building all examples..."
alr exec -- gprbuild -P examples.gpr
if [ $? -ne 0 ]; then
    echo "Error building examples"
    exit 1
fi

echo
echo "Example build complete!"
echo "Executables are in ../bin/"
echo
echo "To run examples (from project root):"
echo "  ./bin/example-basic-dom          # Basic DOM operations tutorial"
echo "  ./bin/example-schema-validation  # Schema validation demonstration"
echo "  ./bin/test-schema-loader         # Schema loader tests"
echo
echo "Run examples in order for best learning experience."
