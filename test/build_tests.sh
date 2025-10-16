#!/bin/bash
# Build test executables using gnatmake to work around gprbuild issue on macOS ARM64

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building SML test executables with gnatmake..."
echo "Note: Using gnatmake due to gprbuild 25.0.0 issue with single-main projects on macOS ARM64"
echo

# Build all tests using consolidated project file
echo "Building all tests..."
alr exec -- gnatmake -P tests.gpr
if [ $? -ne 0 ]; then
    echo "Error building tests"
    exit 1
fi

echo
echo "Test build complete!"
echo "Executables are in ../bin/"
echo
echo "To run tests (from project root):"
echo "  ./bin/test-parser"
echo "  ./bin/test-schema"
echo "  ./bin/test-io"
