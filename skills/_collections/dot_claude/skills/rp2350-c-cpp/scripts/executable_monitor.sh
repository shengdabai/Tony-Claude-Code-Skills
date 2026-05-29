#!/bin/bash
# Serial monitor for Pico debugging

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Pico Serial Monitor ===${NC}"

# Detect serial port
SERIAL_PORT=""

if [ "$(uname)" == "Darwin" ]; then
    # macOS
    SERIAL_PORT=$(ls /dev/tty.usbmodem* 2>/dev/null | head -n 1)
elif [ "$(uname)" == "Linux" ]; then
    # Linux
    SERIAL_PORT=$(ls /dev/ttyACM* 2>/dev/null | head -n 1)
fi

if [ -z "$SERIAL_PORT" ]; then
    echo -e "${RED}No serial device found${NC}"
    echo ""
    echo "Available devices:"
    if [ "$(uname)" == "Darwin" ]; then
        ls -la /dev/tty.* 2>/dev/null | grep -i usb || echo "  None"
    else
        ls -la /dev/ttyACM* /dev/ttyUSB* 2>/dev/null || echo "  None"
    fi
    exit 1
fi

echo "Port: $SERIAL_PORT"
echo "Baud: 115200"
echo ""
echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
echo "---"

# Check if screen is available
if command -v screen &> /dev/null; then
    screen "$SERIAL_PORT" 115200
elif command -v minicom &> /dev/null; then
    minicom -D "$SERIAL_PORT" -b 115200
elif command -v picocom &> /dev/null; then
    picocom "$SERIAL_PORT" -b 115200
else
    echo -e "${RED}No serial terminal found${NC}"
    echo "Please install one of: screen, minicom, picocom"
    exit 1
fi
