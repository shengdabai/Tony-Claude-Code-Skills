# Hardware Interfaces Programming Guide

## GPIO Configuration and Usage

### Basic GPIO Operations

```c
#include "pico/stdlib.h"

// Initialize single GPIO
gpio_init(LED_PIN);
gpio_set_dir(LED_PIN, GPIO_OUT);
gpio_put(LED_PIN, 1);  // Set high

// Read input
gpio_init(BUTTON_PIN);
gpio_set_dir(BUTTON_PIN, GPIO_IN);
gpio_pull_up(BUTTON_PIN);
bool pressed = !gpio_get(BUTTON_PIN);  // Active low

// Toggle GPIO
gpio_xor_mask(1 << LED_PIN);
```

### GPIO Pin Functions

Each GPIO can be assigned to different peripheral functions:

| Function | Description | Pins |
|----------|-------------|------|
| GPIO_FUNC_SIO | Software I/O (default) | All |
| GPIO_FUNC_SPI | SPI peripheral | Configurable |
| GPIO_FUNC_UART | UART peripheral | Configurable |
| GPIO_FUNC_I2C | I2C peripheral | Configurable |
| GPIO_FUNC_PWM | PWM output | All |
| GPIO_FUNC_PIO0/1 | PIO state machines | All |
| GPIO_FUNC_USB | USB D+/D- | 0, 1 (fixed) |

### GPIO Interrupts

```c
// Edge-triggered interrupt
void gpio_callback(uint gpio, uint32_t events) {
    if (events & GPIO_IRQ_EDGE_RISE) {
        // Rising edge
    }
    if (events & GPIO_IRQ_EDGE_FALL) {
        // Falling edge
    }
}

gpio_set_irq_enabled_with_callback(PIN, GPIO_IRQ_EDGE_RISE | GPIO_IRQ_EDGE_FALL,
                                  true, &gpio_callback);
```

## SPI Interface

### SPI Configuration

RP2350 has two SPI peripherals (spi0, spi1). Default pins:

**SPI0:**
- RX (MISO): GPIO 16
- CS: GPIO 17
- SCK: GPIO 18
- TX (MOSI): GPIO 19

**SPI1:**
- RX (MISO): GPIO 8 or 12
- CS: GPIO 9 or 13
- SCK: GPIO 10 or 14
- TX (MOSI): GPIO 11 or 15

### Basic SPI Communication

```c
#include "hardware/spi.h"

void spi_setup() {
    // Initialize SPI at 1 MHz
    spi_init(spi0, 1000 * 1000);

    // Set SPI format: 8 data bits, CPOL=0, CPHA=0, MSB first
    spi_set_format(spi0, 8, SPI_CPOL_0, SPI_CPHA_0, SPI_MSB_FIRST);

    // Configure GPIO for SPI
    gpio_set_function(PIN_MISO, GPIO_FUNC_SPI);
    gpio_set_function(PIN_SCK, GPIO_FUNC_SPI);
    gpio_set_function(PIN_MOSI, GPIO_FUNC_SPI);

    // CS is managed as regular GPIO
    gpio_init(PIN_CS);
    gpio_set_dir(PIN_CS, GPIO_OUT);
    gpio_put(PIN_CS, 1);
}

// Read/Write transaction
uint8_t spi_transfer(uint8_t data) {
    uint8_t rx;
    gpio_put(PIN_CS, 0);
    spi_write_read_blocking(spi0, &data, &rx, 1);
    gpio_put(PIN_CS, 1);
    return rx;
}
```

### SPI with DMA

```c
#include "hardware/dma.h"

void spi_dma_write(uint8_t *data, size_t len) {
    int dma_chan = dma_claim_unused_channel(true);

    dma_channel_config cfg = dma_channel_get_default_config(dma_chan);
    channel_config_set_transfer_data_size(&cfg, DMA_SIZE_8);
    channel_config_set_dreq(&cfg, spi_get_dreq(spi0, true));  // TX DREQ

    gpio_put(PIN_CS, 0);

    dma_channel_configure(
        dma_chan,
        &cfg,
        &spi_get_hw(spi0)->dr,  // Write to SPI data register
        data,                    // Read from buffer
        len,                     // Transfer count
        true                     // Start immediately
    );

    dma_channel_wait_for_finish_blocking(dma_chan);
    gpio_put(PIN_CS, 1);

    dma_channel_unclaim(dma_chan);
}
```

## I2C Interface

### I2C Configuration

RP2350 has two I2C peripherals (i2c0, i2c1). Default pins:

**I2C0:**
- SDA: GPIO 4 or 8 or 12 or 16 or 20
- SCL: GPIO 5 or 9 or 13 or 17 or 21

**I2C1:**
- SDA: GPIO 2 or 6 or 10 or 14 or 18 or 26
- SCL: GPIO 3 or 7 or 11 or 15 or 19 or 27

### Basic I2C Communication

```c
#include "hardware/i2c.h"

#define I2C_ADDR 0x68  // Example: MPU6050

void i2c_setup() {
    i2c_init(i2c0, 400 * 1000);  // 400 kHz

    gpio_set_function(I2C_SDA, GPIO_FUNC_I2C);
    gpio_set_function(I2C_SCL, GPIO_FUNC_I2C);

    // Enable pull-ups (external 4.7kΩ recommended for reliability)
    gpio_pull_up(I2C_SDA);
    gpio_pull_up(I2C_SCL);
}

// Write register
void i2c_write_reg(uint8_t reg, uint8_t value) {
    uint8_t buf[2] = {reg, value};
    i2c_write_blocking(i2c0, I2C_ADDR, buf, 2, false);
}

// Read register
uint8_t i2c_read_reg(uint8_t reg) {
    uint8_t value;
    i2c_write_blocking(i2c0, I2C_ADDR, &reg, 1, true);  // nostop=true
    i2c_read_blocking(i2c0, I2C_ADDR, &value, 1, false);
    return value;
}

// Read multiple bytes
void i2c_read_bytes(uint8_t reg, uint8_t *buf, size_t len) {
    i2c_write_blocking(i2c0, I2C_ADDR, &reg, 1, true);
    i2c_read_blocking(i2c0, I2C_ADDR, buf, len, false);
}
```

### I2C Device Scanning

```c
void i2c_bus_scan() {
    printf("\nI2C Bus Scan\n");
    printf("   0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F\n");

    for (int addr = 0; addr < (1 << 7); ++addr) {
        if (addr % 16 == 0) {
            printf("%02x ", addr);
        }

        uint8_t rxdata;
        int ret = i2c_read_blocking(i2c0, addr, &rxdata, 1, false);

        printf(ret < 0 ? "." : "@");
        printf(addr % 16 == 15 ? "\n" : "  ");
    }
    printf("Done.\n");
}
```

## UART Interface

### UART Configuration

RP2350 has two UART peripherals (uart0, uart1). Default pins:

**UART0:**
- TX: GPIO 0 or 12 or 16
- RX: GPIO 1 or 13 or 17

**UART1:**
- TX: GPIO 4 or 8
- RX: GPIO 5 or 9

### Basic UART Communication

```c
#include "hardware/uart.h"

void uart_setup() {
    uart_init(uart1, 115200);

    gpio_set_function(TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(RX_PIN, GPIO_FUNC_UART);

    // Set data format: 8N1
    uart_set_format(uart1, 8, 1, UART_PARITY_NONE);

    // Enable FIFO
    uart_set_fifo_enabled(uart1, true);
}

// Blocking write
void uart_write_string(const char *str) {
    uart_puts(uart1, str);
}

// Non-blocking read with timeout
bool uart_read_with_timeout(uint8_t *data, uint32_t timeout_us) {
    if (uart_is_readable_within_us(uart1, timeout_us)) {
        *data = uart_getc(uart1);
        return true;
    }
    return false;
}
```

### UART with Interrupts

```c
void uart_rx_handler() {
    while (uart_is_readable(uart1)) {
        uint8_t ch = uart_getc(uart1);
        // Process received byte
        printf("Received: 0x%02x\n", ch);
    }
}

void uart_setup_with_irq() {
    uart_init(uart1, 115200);

    gpio_set_function(TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(RX_PIN, GPIO_FUNC_UART);

    // Enable RX interrupt
    irq_set_exclusive_handler(UART1_IRQ, uart_rx_handler);
    irq_set_enabled(UART1_IRQ, true);
    uart_set_irq_enables(uart1, true, false);  // RX only
}
```

## PWM (Pulse Width Modulation)

### PWM Basics

RP2350 has 12 PWM slices, each with 2 channels (A and B), for 24 total PWM outputs.

```c
#include "hardware/pwm.h"

void pwm_setup(uint gpio, uint freq_hz) {
    gpio_set_function(gpio, GPIO_FUNC_PWM);

    uint slice_num = pwm_gpio_to_slice_num(gpio);

    // Calculate wrap value for desired frequency
    // PWM freq = sys_clk / (clkdiv * (wrap + 1))
    // For 125 MHz sys clock and 1 kHz PWM: wrap = 125000 / freq - 1
    uint32_t wrap = 125000000 / freq_hz - 1;
    pwm_set_wrap(slice_num, wrap);

    // Set initial duty cycle to 50%
    pwm_set_gpio_level(gpio, wrap / 2);

    // Enable PWM
    pwm_set_enabled(slice_num, true);
}

// Set duty cycle (0.0 to 1.0)
void pwm_set_duty(uint gpio, float duty) {
    uint slice_num = pwm_gpio_to_slice_num(gpio);
    uint16_t wrap = pwm_get_wrap(slice_num);
    pwm_set_gpio_level(gpio, (uint16_t)(wrap * duty));
}
```

### Servo Motor Control

```c
void servo_init(uint gpio) {
    gpio_set_function(gpio, GPIO_FUNC_PWM);
    uint slice_num = pwm_gpio_to_slice_num(gpio);

    // 50 Hz (20ms period) for standard servos
    // wrap = 125MHz / 50Hz - 1 = 2499999
    pwm_set_wrap(slice_num, 2499999);
    pwm_set_enabled(slice_num, true);
}

// angle: 0-180 degrees
void servo_set_angle(uint gpio, uint8_t angle) {
    uint slice_num = pwm_gpio_to_slice_num(gpio);

    // Servo pulse: 1ms (0°) to 2ms (180°)
    // At 50Hz: 1ms = 125000, 2ms = 250000
    uint32_t pulse_width = 125000 + (angle * 125000 / 180);
    pwm_set_gpio_level(gpio, pulse_width);
}
```

## ADC (Analog-to-Digital Converter)

### ADC Configuration

RP2350 has a 12-bit ADC with 5 input channels:
- ADC0: GPIO 26
- ADC1: GPIO 27
- ADC2: GPIO 28
- ADC3: GPIO 29 (only on RP2350, not RP2040)
- ADC4: Internal temperature sensor

```c
#include "hardware/adc.h"

void adc_setup() {
    adc_init();

    // Initialize ADC GPIO pins
    adc_gpio_init(26);  // ADC0
    adc_gpio_init(27);  // ADC1
    adc_gpio_init(28);  // ADC2
}

// Read single sample
float adc_read_voltage(uint channel) {
    adc_select_input(channel);
    uint16_t raw = adc_read();  // 0-4095 (12-bit)

    // Convert to voltage (0-3.3V)
    return raw * 3.3f / 4095.0f;
}

// Temperature sensor
float read_temperature() {
    adc_select_input(4);  // Temperature sensor
    uint16_t raw = adc_read();

    float voltage = raw * 3.3f / 4095.0f;
    float temp_c = 27.0f - (voltage - 0.706f) / 0.001721f;

    return temp_c;
}
```

### ADC with DMA (Continuous Sampling)

```c
uint16_t adc_buffer[1000];

void adc_continuous_sampling() {
    adc_init();
    adc_gpio_init(26);
    adc_select_input(0);

    // Configure ADC FIFO
    adc_fifo_setup(
        true,    // Enable FIFO
        true,    // Enable DMA requests
        1,       // DREQ threshold
        false,   // Don't include error bit
        false    // Keep full 12-bit samples
    );

    // Set up DMA
    int dma_chan = dma_claim_unused_channel(true);
    dma_channel_config cfg = dma_channel_get_default_config(dma_chan);
    channel_config_set_transfer_data_size(&cfg, DMA_SIZE_16);
    channel_config_set_read_increment(&cfg, false);
    channel_config_set_write_increment(&cfg, true);
    channel_config_set_dreq(&cfg, DREQ_ADC);

    dma_channel_configure(
        dma_chan,
        &cfg,
        adc_buffer,    // Write to buffer
        &adc_hw->fifo, // Read from ADC FIFO
        1000,          // Transfer count
        true           // Start immediately
    );

    // Set sample rate (96 kHz max)
    adc_set_clkdiv(125000000 / 48000);  // 48 kHz

    // Start continuous sampling
    adc_run(true);

    // Wait for DMA to complete
    dma_channel_wait_for_finish_blocking(dma_chan);

    // Stop sampling
    adc_run(false);
    adc_fifo_drain();

    // Process buffer...
}
```

## DMA (Direct Memory Access)

### DMA Channel Configuration

```c
#include "hardware/dma.h"

void dma_memory_copy(void *dst, const void *src, size_t len) {
    int chan = dma_claim_unused_channel(true);

    dma_channel_config cfg = dma_channel_get_default_config(chan);
    channel_config_set_transfer_data_size(&cfg, DMA_SIZE_8);
    channel_config_set_read_increment(&cfg, true);
    channel_config_set_write_increment(&cfg, true);

    dma_channel_configure(
        chan,
        &cfg,
        dst,   // Write address
        src,   // Read address
        len,   // Transfer count
        true   // Start immediately
    );

    dma_channel_wait_for_finish_blocking(chan);
    dma_channel_unclaim(chan);
}
```

### DMA Chaining

```c
void dma_chain_example() {
    int chan1 = dma_claim_unused_channel(true);
    int chan2 = dma_claim_unused_channel(true);

    // Configure channel 1
    dma_channel_config cfg1 = dma_channel_get_default_config(chan1);
    channel_config_set_chain_to(&cfg1, chan2);  // Chain to chan2

    dma_channel_configure(chan1, &cfg1, dest1, src1, len1, false);

    // Configure channel 2
    dma_channel_config cfg2 = dma_channel_get_default_config(chan2);
    dma_channel_configure(chan2, &cfg2, dest2, src2, len2, false);

    // Start first channel (will automatically trigger second)
    dma_channel_start(chan1);

    // Wait for both to complete
    dma_channel_wait_for_finish_blocking(chan2);
}
```

## Timer and Alarms

### Hardware Timers

```c
#include "pico/time.h"

// Repeating timer callback
bool timer_callback(repeating_timer_t *rt) {
    printf("Timer fired!\n");
    return true;  // Keep repeating
}

int main() {
    repeating_timer_t timer;

    // Call every 1000ms
    add_repeating_timer_ms(1000, timer_callback, NULL, &timer);

    while (1) {
        tight_loop_contents();
    }
}
```

### One-Shot Alarms

```c
int64_t alarm_callback(alarm_id_t id, void *user_data) {
    printf("Alarm triggered!\n");
    return 0;  // Don't reschedule
}

void setup_alarm() {
    // Fire after 5 seconds
    add_alarm_in_ms(5000, alarm_callback, NULL, false);
}
```

## Watchdog Timer

```c
#include "hardware/watchdog.h"

void watchdog_setup() {
    // Enable watchdog with 5-second timeout
    watchdog_enable(5000, false);
}

void main_loop() {
    while (1) {
        // Feed watchdog to prevent reset
        watchdog_update();

        // Your main loop code...
        sleep_ms(100);
    }
}

// Check if watchdog caused last reset
if (watchdog_caused_reboot()) {
    printf("System recovered from watchdog reset\n");
}
```

## Flash Memory

### Reading Flash

```c
#include "hardware/flash.h"
#include "hardware/sync.h"

#define FLASH_TARGET_OFFSET (256 * 1024)  // 256KB into flash

void read_from_flash() {
    const uint8_t *flash_ptr = (const uint8_t *)(XIP_BASE + FLASH_TARGET_OFFSET);

    printf("First byte: 0x%02x\n", flash_ptr[0]);
}
```

### Writing Flash

```c
uint8_t write_buffer[FLASH_PAGE_SIZE];

void write_to_flash() {
    // Prepare data
    for (int i = 0; i < FLASH_PAGE_SIZE; i++) {
        write_buffer[i] = i;
    }

    // Disable interrupts during flash operation
    uint32_t ints = save_and_disable_interrupts();

    // Erase sector (4KB)
    flash_range_erase(FLASH_TARGET_OFFSET, FLASH_SECTOR_SIZE);

    // Program page (256 bytes)
    flash_range_program(FLASH_TARGET_OFFSET, write_buffer, FLASH_PAGE_SIZE);

    // Re-enable interrupts
    restore_interrupts(ints);
}
```

## Multicore Communication

### Core Launch and FIFO

```c
#include "pico/multicore.h"

void core1_entry() {
    while (1) {
        // Wait for data from core 0
        uint32_t data = multicore_fifo_pop_blocking();

        // Process data
        uint32_t result = data * 2;

        // Send result back
        multicore_fifo_push_blocking(result);
    }
}

int main() {
    stdio_init_all();

    // Launch core 1
    multicore_launch_core1(core1_entry);

    while (1) {
        // Send data to core 1
        multicore_fifo_push_blocking(42);

        // Get result
        uint32_t result = multicore_fifo_pop_blocking();
        printf("Result: %lu\n", result);

        sleep_ms(1000);
    }
}
```

## Clock Configuration

```c
#include "hardware/clocks.h"

// Get current frequencies
uint32_t sys_clk = clock_get_hz(clk_sys);    // System clock
uint32_t peri_clk = clock_get_hz(clk_peri);  // Peripheral clock
uint32_t usb_clk = clock_get_hz(clk_usb);    // USB clock

printf("System clock: %lu Hz\n", sys_clk);
```
