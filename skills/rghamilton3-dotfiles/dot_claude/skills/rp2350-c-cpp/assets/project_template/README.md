# Pico SDK Project Template

Basic template for RP2040/RP2350 development with C/C++ and Pico SDK.

## Requirements

- Pico SDK
- CMake (>= 3.13)
- ARM GCC toolchain (`gcc-arm-none-eabi`)

## Setup

1. Set SDK path:
```bash
export PICO_SDK_PATH=/path/to/pico-sdk
```

2. Build:
```bash
mkdir build
cd build
cmake ..
make -j4
```

3. Flash:
```bash
# Hold BOOTSEL button, connect USB, then:
cp my_project.uf2 /media/$USER/RPI-RP2/
```

## Project Structure

```
my_project/
├── CMakeLists.txt          # Build configuration
├── pico_sdk_import.cmake   # SDK integration
├── src/
│   └── main.c              # Main application
├── .vscode/                # VSCode configuration
└── build/                  # Build output (generated)
```

## Adding Libraries

Edit `CMakeLists.txt`:

```cmake
target_link_libraries(my_project
    pico_stdlib
    hardware_spi    # Add SPI
    hardware_i2c    # Add I2C
    # ...
)
```

## Debugging

### Serial Output (USB CDC)

```bash
screen /dev/ttyACM0 115200
# or
minicom -D /dev/ttyACM0 -b 115200
```

### GDB with Picoprobe

Terminal 1:
```bash
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg
```

Terminal 2:
```bash
gdb-multiarch build/my_project.elf
(gdb) target remote localhost:3333
(gdb) load
(gdb) break main
(gdb) continue
```

## Resources

- [Pico SDK Documentation](https://raspberrypi.github.io/pico-sdk-doxygen/)
- [Getting Started Guide](https://datasheets.raspberrypi.com/pico/getting-started-with-pico.pdf)
- [RP2350 Datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf)
