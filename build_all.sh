#!/bin/bash
# Build all SML components: library, tests, and examples

echo "Building SML Library and all programs..."
echo "========================================"
echo

# Build the library first
echo "Step 1: Building SML library..."
alr build
if [ $? -ne 0 ]; then
    echo "Error building library"
    exit 1
fi
echo

# Build tests
echo "Step 2: Building tests..."
./build_tests.sh
if [ $? -ne 0 ]; then
    echo "Error building tests"
    exit 1
fi
echo

# Build examples  
echo "Step 3: Building examples..."
./build_examples.sh
if [ $? -ne 0 ]; then
    echo "Error building examples"
    exit 1
fi

echo
echo "========================================"
echo "All builds completed successfully!"
echo
echo "Library: built with alr"
echo "Tests:   built with gnatmake (gprbuild workaround)"
echo "Examples: built with gprbuild"
echo
echo "All executables are in bin/"
