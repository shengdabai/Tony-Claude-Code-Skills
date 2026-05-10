#!/bin/bash
# Automated firmware flashing script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
TIMEOUT=30
MOUNT_POINT="/media/$USER/RPI-RP2"

echo -e "${GREEN}=== Pico Firmware Flasher ===${NC}"

# Check for UF2 file
UF2_FILE="$1"

if [ -z "$UF2_FILE" ]; then
    # Try to find UF2 in build directory
    if [ -d "build" ]; then
        UF2_FILE=$(find build -name "*.uf2" | head -n 1)
    fi
fi

if [ -z "$UF2_FILE" ] || [ ! -f "$UF2_FILE" ]; then
    echo -e "${RED}ERROR: UF2 file not found${NC}"
    echo "Usage: $0 <firmware.uf2>"
    echo "   or: $0  (auto-detect in build/)"
    exit 1
fi

echo "Firmware: $UF2_FILE"
echo ""

# Check if device is already mounted
if [ -d "$MOUNT_POINT" ]; then
    echo -e "${GREEN}RP2040/RP2350 bootloader detected${NC}"
else
    echo -e "${YELLOW}Waiting for RP2040/RP2350 in BOOTSEL mode...${NC}"
    echo "Please:"
    echo "  1. Hold the BOOTSEL button"
    echo "  2. Connect USB or press RESET"
    echo "  3. Release BOOTSEL"
    echo ""

    # Wait for mount point
    elapsed=0
    while [ ! -d "$MOUNT_POINT" ] && [ $elapsed -lt $TIMEOUT ]; do
        sleep 1
        elapsed=$((elapsed + 1))
        echo -ne "\rWaiting... ${elapsed}s / ${TIMEOUT}s"
    done
    echo ""

    if [ ! -d "$MOUNT_POINT" ]; then
        echo -e "${RED}Timeout waiting for bootloader${NC}"
        echo ""
        echo "Alternative methods:"
        echo "  1. Check USB cable connection"
        echo "  2. Try different USB port"
        echo "  3. Use picoprobe/debugger: openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c \"program $UF2_FILE verify reset exit\""
        exit 1
    fi
fi

# Flash firmware
echo -e "${YELLOW}Flashing firmware...${NC}"
cp "$UF2_FILE" "$MOUNT_POINT/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Firmware flashed successfully!${NC}"
    echo "Device will reboot automatically"
    exit 0
else
    echo -e "${RED}Flash failed${NC}"
    exit 1
fi
