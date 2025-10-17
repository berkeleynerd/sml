#!/bin/bash
set -e

# Run from parent directory to use alr exec
cd ..

echo "=== Building test project ==="
alr exec -- gprbuild -P test_ghost_pattern/test.gpr

echo -e "\n=== Running gnatprove ==="
alr exec -- gnatprove -P test_ghost_pattern/test.gpr --report=all

echo -e "\n=== Checking if ghost package was analyzed ==="
grep -i "example_ghost" test_ghost_pattern/obj/gnatprove/gnatprove.out || echo "Ghost package not found in output"
