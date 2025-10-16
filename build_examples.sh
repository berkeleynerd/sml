#!/bin/bash
# Build example executables

echo "Building SML example programs..."
echo

# Build all examples using gprbuild (works fine with multi-main projects)
echo "Building all examples..."
alr exec -- gprbuild -P examples/examples.gpr
if [ $? -ne 0 ]; then
    echo "Error building examples"
    exit 1
fi

echo
echo "Example build complete!"
echo "Executables are in bin/"
echo
echo "To run examples:"
echo "  ./bin/example-basic-dom          # Basic DOM operations tutorial"
echo "  ./bin/example-schema-validation  # Schema validation demonstration"
echo "  ./bin/test-schema-loader         # Schema loader tests"
echo
echo "Run examples in order for best learning experience."
