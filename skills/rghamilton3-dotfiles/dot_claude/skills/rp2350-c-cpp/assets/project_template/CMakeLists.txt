cmake_minimum_required(VERSION 3.13)

# Include the Pico SDK
include(pico_sdk_import.cmake)

# Project configuration
project(my_project C CXX ASM)
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
    pico_stdlib          # Standard library
    hardware_spi         # SPI peripheral
    hardware_i2c         # I2C peripheral
    hardware_pwm         # PWM
    hardware_adc         # ADC
)

# Enable USB output, disable UART
pico_enable_stdio_usb(my_project 1)
pico_enable_stdio_uart(my_project 0)

# Create map/bin/hex/uf2 files
pico_add_extra_outputs(my_project)

# Optional: Configure stack size
# target_compile_definitions(my_project PRIVATE
#     PICO_STACK_SIZE=0x2000
# )
