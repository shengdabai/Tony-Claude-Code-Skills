#!/bin/bash
# Automated build script for Pico SDK projects

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BUILD_DIR="build"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

echo -e "${GREEN}=== Pico SDK Build Script ===${NC}"

# Check for PICO_SDK_PATH
if [ -z "$PICO_SDK_PATH" ]; then
    echo -e "${RED}ERROR: PICO_SDK_PATH not set${NC}"
    echo "Please set PICO_SDK_PATH environment variable:"
    echo "  export PICO_SDK_PATH=/path/to/pico-sdk"
    exit 1
fi

echo "SDK Path: $PICO_SDK_PATH"
echo "Build Type: $CMAKE_BUILD_TYPE"
echo "Jobs: $JOBS"
echo ""

# Create build directory
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Creating build directory...${NC}"
    mkdir -p "$BUILD_DIR"
fi

cd "$BUILD_DIR"

# Run CMake
echo -e "${YELLOW}Running CMake...${NC}"
cmake .. -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"

# Build
echo -e "${YELLOW}Building project...${NC}"
make -j"$JOBS"

# Check build result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=== Build Successful ===${NC}"
    echo ""

    # List generated files
    echo "Generated files:"
    for file in *.uf2 *.elf *.bin *.hex; do
        if [ -f "$file" ]; then
            echo "  - $file ($(du -h "$file" | cut -f1))"
        fi
    done

    echo ""

    # Show memory usage
    echo -e "${YELLOW}Memory usage:${NC}"
    arm-none-eabi-size *.elf 2>/dev/null || echo "Size utility not found"

    exit 0
else
    echo -e "${RED}=== Build Failed ===${NC}"
    exit 1
fi
