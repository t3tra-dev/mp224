#!/bin/bash
set -e

# Create Metal library
xcrun -sdk macosx metal -c Sources/mp224/Metal/keygen.metal -o Sources/mp224/Metal/keygen.air
xcrun -sdk macosx metal -c Sources/mp224/Metal/sha3.metal -o Sources/mp224/Metal/sha3.air
xcrun -sdk macosx metallib Sources/mp224/Metal/keygen.air Sources/mp224/Metal/sha3.air -o Sources/mp224/Metal/default.metallib

# Clean up
rm Sources/mp224/Metal/*.air
