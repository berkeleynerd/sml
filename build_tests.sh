#!/bin/bash
# Build test executables using gnatmake to work around gprbuild issue on macOS ARM64

echo "Building SML test executables with gnatmake..."
echo "Note: Using gnatmake due to gprbuild 25.0.0 issue with single-main projects on macOS ARM64"
echo

# Build parser tests
echo "Building test_parser..."
alr exec -- gnatmake -P test_parser.gpr
if [ $? -ne 0 ]; then
    echo "Error building test_parser"
    exit 1
fi

# Build schema tests
echo "Building test_schema..."
alr exec -- gnatmake -P test_schema.gpr
if [ $? -ne 0 ]; then
    echo "Error building test_schema"
    exit 1
fi

# Build IO tests
echo "Building test_io..."
alr exec -- gnatmake -P test_io.gpr
if [ $? -ne 0 ]; then
    echo "Error building test_io"
    exit 1
fi

echo
echo "Test build complete!"
echo "Executables are in bin/"
echo
echo "To run tests:"
echo "  ./bin/test_parser"
echo "  ./bin/test_schema"
echo "  ./bin/test_io"
