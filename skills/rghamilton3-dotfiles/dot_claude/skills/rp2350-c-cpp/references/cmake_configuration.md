# CMake Configuration for Pico SDK Projects

## Basic Project Structure

```
my_project/
├── CMakeLists.txt
├── pico_sdk_import.cmake
├── src/
│   ├── main.c
│   └── peripheral_init.c
├── include/
│   └── peripheral_init.h
└── build/
```

## Minimal CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.13)

# Include the Pico SDK
include(pico_sdk_import.cmake)

# Project name and languages
project(my_project C CXX ASM)

# Set C/C++ standards
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Initialize the Pico SDK
pico_sdk_init()

# Add executable
add_executable(my_project
    src/main.c
)

# Link libraries
target_link_libraries(my_project
    pico_stdlib
)

# Enable USB output, disable UART
pico_enable_stdio_usb(my_project 1)
pico_enable_stdio_uart(my_project 0)

# Create map/bin/hex/uf2 files
pico_add_extra_outputs(my_project)
```

## Advanced Configuration

### Multiple Source Files

```cmake
# Glob all source files
file(GLOB_RECURSE SOURCES "src/*.c")

add_executable(my_project ${SOURCES})

# Or list explicitly (preferred)
add_executable(my_project
    src/main.c
    src/peripheral_init.c
    src/sensors/temperature.c
    src/sensors/accelerometer.c
    src/display/lcd.c
)
```

### Include Directories

```cmake
# Add include directories
target_include_directories(my_project PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/include
    ${CMAKE_CURRENT_LIST_DIR}/src
)
```

### Hardware Libraries

```cmake
# Common hardware libraries
target_link_libraries(my_project
    pico_stdlib          # Standard library
    hardware_spi         # SPI peripheral
    hardware_i2c         # I2C peripheral
    hardware_pwm         # PWM
    hardware_adc         # Analog-to-Digital Converter
    hardware_dma         # Direct Memory Access
    hardware_uart        # UART
    hardware_watchdog    # Watchdog timer
    hardware_clocks      # Clock configuration
    hardware_timer       # Hardware timers
    hardware_rtc         # Real-time clock
    hardware_flash       # Flash memory
    hardware_sync        # Synchronization primitives
    pico_multicore       # Multicore support
    pico_time            # Time functions
    pico_util            # Utility functions
)
```

### USB Device Libraries

```cmake
# USB libraries (TinyUSB)
target_link_libraries(my_project
    pico_stdlib
    tinyusb_device       # USB device stack
    tinyusb_board        # Board-specific USB
)

# Enable USB output
pico_enable_stdio_usb(my_project 1)
pico_enable_stdio_uart(my_project 0)
```

### Compile Definitions

```cmake
# Add compile definitions
target_compile_definitions(my_project PRIVATE
    PICO_STACK_SIZE=0x2000           # 8KB stack
    PICO_CORE1_STACK_SIZE=0x2000     # 8KB stack for core 1
    PICO_HEAP_SIZE=0x4000            # 16KB heap
    PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS=3000  # USB timeout
    # Custom defines
    MY_CUSTOM_DEFINE=1
    DEBUG_ENABLED
)
```

### Compiler Optimization

```cmake
# Optimization flags
target_compile_options(my_project PRIVATE
    -O3                    # Maximum optimization
    -Wall                  # All warnings
    -Wextra                # Extra warnings
    -Werror                # Warnings as errors
    -flto                  # Link-time optimization
    -ffunction-sections    # Each function in own section
    -fdata-sections        # Each data in own section
)

# Linker flags
target_link_options(my_project PRIVATE
    -Wl,--gc-sections      # Remove unused sections
    -Wl,--print-memory-usage  # Print memory usage
)
```

### Debug Build Configuration

```cmake
# Set build type
set(CMAKE_BUILD_TYPE Debug)

# Debug-specific flags
if(CMAKE_BUILD_TYPE MATCHES Debug)
    target_compile_definitions(my_project PRIVATE
        DEBUG=1
        PICO_STDIO_USB_ENABLE_RESET_VIA_BAUD_RATE=1
    )
    target_compile_options(my_project PRIVATE
        -g              # Debug symbols
        -Og             # Debug-friendly optimization
        -fno-omit-frame-pointer
    )
endif()

# Release-specific flags
if(CMAKE_BUILD_TYPE MATCHES Release)
    target_compile_options(my_project PRIVATE
        -O3             # Maximum optimization
        -DNDEBUG        # Disable assertions
    )
endif()
```

## Multicore Projects

```cmake
add_executable(my_multicore_project
    src/main.c
    src/core1_tasks.c
)

target_link_libraries(my_multicore_project
    pico_stdlib
    pico_multicore  # Required for multicore
)

# Increase stack sizes for both cores
target_compile_definitions(my_multicore_project PRIVATE
    PICO_STACK_SIZE=0x2000
    PICO_CORE1_STACK_SIZE=0x2000
)

pico_enable_stdio_usb(my_multicore_project 1)
pico_enable_stdio_uart(my_multicore_project 0)
pico_add_extra_outputs(my_multicore_project)
```

## FreeRTOS Integration

```cmake
# Include FreeRTOS kernel
set(FREERTOS_KERNEL_PATH ${CMAKE_CURRENT_LIST_DIR}/FreeRTOS-Kernel)
include(${FREERTOS_KERNEL_PATH}/portable/ThirdParty/GCC/RP2040/FreeRTOS_Kernel_import.cmake)

add_executable(my_rtos_project
    src/main.c
    src/task1.c
    src/task2.c
)

target_link_libraries(my_rtos_project
    pico_stdlib
    FreeRTOS-Kernel
    FreeRTOS-Kernel-Heap4  # Use heap_4 memory allocator
)

# FreeRTOS configuration
target_include_directories(my_rtos_project PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/config  # Contains FreeRTOSConfig.h
)

target_compile_definitions(my_rtos_project PRIVATE
    PICO_HEAP_SIZE=0       # Disable pico heap (use FreeRTOS heap)
    configTOTAL_HEAP_SIZE=65536  # 64KB FreeRTOS heap
)

pico_enable_stdio_usb(my_rtos_project 1)
pico_add_extra_outputs(my_rtos_project)
```

## PIO (Programmable I/O) Projects

```cmake
add_executable(my_pio_project
    src/main.c
)

# Generate PIO headers from .pio files
pico_generate_pio_header(my_pio_project
    ${CMAKE_CURRENT_LIST_DIR}/src/ws2812.pio
)

target_link_libraries(my_pio_project
    pico_stdlib
    hardware_pio  # PIO hardware support
)

pico_add_extra_outputs(my_pio_project)
```

## Custom Linker Script

```cmake
# Use custom linker script
pico_set_linker_script(my_project ${CMAKE_CURRENT_LIST_DIR}/memmap_custom.ld)

# Alternative: modify default script
target_link_options(my_project PRIVATE
    "LINKER:--defsym=FLASH_SIZE=2048K"
    "LINKER:--defsym=RAM_SIZE=256K"
)
```

## Build Multiple Targets

```cmake
# Define a macro for common configuration
macro(setup_pico_target target_name)
    pico_enable_stdio_usb(${target_name} 1)
    pico_enable_stdio_uart(${target_name} 0)
    pico_add_extra_outputs(${target_name})

    target_link_libraries(${target_name}
        pico_stdlib
        hardware_spi
        hardware_i2c
    )
endmacro()

# Build multiple targets
add_executable(sensor_node
    src/sensor_node.c
)
setup_pico_target(sensor_node)

add_executable(display_node
    src/display_node.c
)
setup_pico_target(display_node)

add_executable(controller
    src/controller.c
)
setup_pico_target(controller)
```

## Static Library

```cmake
# Create a library
add_library(my_drivers STATIC
    src/drivers/spi_driver.c
    src/drivers/i2c_driver.c
)

target_include_directories(my_drivers PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/include
)

target_link_libraries(my_drivers
    pico_stdlib
    hardware_spi
    hardware_i2c
)

# Use the library in main project
add_executable(main_app
    src/main.c
)

target_link_libraries(main_app
    my_drivers
    pico_stdlib
)

pico_add_extra_outputs(main_app)
```

## Board-Specific Configuration

```cmake
# Set board type
set(PICO_BOARD pico)  # or pico_w, pico2, etc.

# Board-specific libraries
if(PICO_BOARD STREQUAL "pico_w")
    target_link_libraries(my_project
        pico_cyw43_arch_none  # WiFi/BT driver
    )
endif()

# Custom board configuration
set(PICO_BOARD_HEADER_DIRS ${CMAKE_CURRENT_LIST_DIR}/boards)
```

## Testing with CMake

```cmake
enable_testing()

# Add test executable
add_executable(unit_tests
    tests/test_main.c
    tests/test_utils.c
    src/utils.c  # Code under test
)

target_link_libraries(unit_tests
    pico_stdlib
)

# Add test
add_test(NAME unit_tests COMMAND unit_tests)
```

## Install Targets

```cmake
# Install firmware files
install(FILES
    ${CMAKE_BINARY_DIR}/my_project.uf2
    ${CMAKE_BINARY_DIR}/my_project.elf
    DESTINATION firmware
)

# Install headers
install(DIRECTORY include/
    DESTINATION include
    FILES_MATCHING PATTERN "*.h"
)
```

## Build Script Integration

```cmake
# Generate compile_commands.json for clangd/LSP
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Print memory usage after build
add_custom_command(TARGET my_project POST_BUILD
    COMMAND ${CMAKE_SIZE_UTILITY} my_project.elf
    COMMENT "Memory usage:"
)

# Custom target for flashing
add_custom_target(flash
    COMMAND ${CMAKE_CURRENT_LIST_DIR}/scripts/flash.sh $<TARGET_FILE:my_project>.uf2
    DEPENDS my_project
    COMMENT "Flashing firmware..."
)
```

## Common Issues and Solutions

### Issue: SDK Not Found

```cmake
# Solution: Set SDK path before include
set(PICO_SDK_PATH "/path/to/pico-sdk")
include(pico_sdk_import.cmake)
```

### Issue: Multiple Definition Errors

```cmake
# Solution: Use INTERFACE for header-only libraries
add_library(my_headers INTERFACE)
target_include_directories(my_headers INTERFACE include/)
```

### Issue: Undefined Reference to Standard Library

```cmake
# Solution: Link newlib explicitly
target_link_libraries(my_project
    c
    m      # Math library
    gcc    # GCC runtime
)
```

### Issue: Large Binary Size

```cmake
# Solution: Enable LTO and garbage collection
target_compile_options(my_project PRIVATE -flto)
target_link_options(my_project PRIVATE
    -flto
    -Wl,--gc-sections
    -Wl,--print-gc-sections  # Show what was removed
)
```

## CMake Variables Reference

```cmake
# Pico SDK variables
PICO_SDK_PATH              # Path to SDK
PICO_BOARD                 # Board type (pico, pico_w, etc.)
PICO_PLATFORM              # Platform (rp2040, rp2350)
PICO_COMPILER              # Compiler (pico_arm_gcc, pico_arm_clang)

# Standard CMake variables
CMAKE_C_COMPILER           # C compiler path
CMAKE_CXX_COMPILER         # C++ compiler path
CMAKE_BUILD_TYPE           # Debug, Release, MinSizeRel, RelWithDebInfo
CMAKE_BINARY_DIR           # Build directory
CMAKE_CURRENT_LIST_DIR     # Directory of current CMakeLists.txt
```

## Example: Complete Production Project

```cmake
cmake_minimum_required(VERSION 3.13)

# Project configuration
set(PROJECT_NAME "production_firmware")
set(PROJECT_VERSION "1.0.0")

# Include Pico SDK
include(pico_sdk_import.cmake)

project(${PROJECT_NAME} C CXX ASM VERSION ${PROJECT_VERSION})

# Standards
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Initialize SDK
pico_sdk_init()

# Source files
file(GLOB_RECURSE SOURCES
    src/*.c
    src/*.cpp
)

# Create executable
add_executable(${PROJECT_NAME} ${SOURCES})

# Include directories
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/include
    ${CMAKE_CURRENT_LIST_DIR}/config
)

# Link libraries
target_link_libraries(${PROJECT_NAME}
    pico_stdlib
    hardware_spi
    hardware_i2c
    hardware_pwm
    hardware_adc
    hardware_dma
    pico_multicore
)

# Compile definitions
target_compile_definitions(${PROJECT_NAME} PRIVATE
    PICO_STACK_SIZE=0x2000
    PICO_CORE1_STACK_SIZE=0x2000
    FIRMWARE_VERSION="${PROJECT_VERSION}"
)

# Optimization flags
if(CMAKE_BUILD_TYPE MATCHES Release)
    target_compile_options(${PROJECT_NAME} PRIVATE
        -O3
        -flto
        -ffunction-sections
        -fdata-sections
    )
    target_link_options(${PROJECT_NAME} PRIVATE
        -flto
        -Wl,--gc-sections
    )
else()
    target_compile_options(${PROJECT_NAME} PRIVATE
        -g
        -Og
    )
endif()

# USB configuration
pico_enable_stdio_usb(${PROJECT_NAME} 1)
pico_enable_stdio_uart(${PROJECT_NAME} 0)

# Generate outputs
pico_add_extra_outputs(${PROJECT_NAME})

# Memory usage report
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_SIZE_UTILITY} ${PROJECT_NAME}.elf
)
```
