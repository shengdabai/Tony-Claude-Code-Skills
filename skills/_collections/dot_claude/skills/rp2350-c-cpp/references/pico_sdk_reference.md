# Pico SDK API Reference

## Core Libraries

### pico_stdlib

The standard library providing essential functions for initialization and basic I/O.

```c
#include "pico/stdlib.h"

// Initialize all standard I/O (USB, UART, timers)
void stdio_init_all(void);

// USB stdio only
void stdio_usb_init(void);

// UART stdio only
void stdio_uart_init(void);

// Sleep functions
void sleep_ms(uint32_t ms);
void sleep_us(uint64_t us);

// Busy wait (maintains timing precision)
void busy_wait_ms(uint32_t ms);
void busy_wait_us(uint32_t us);
void busy_wait_us_32(uint32_t us);

// Time functions
uint32_t time_us_32(void);  // 32-bit microsecond counter
uint64_t time_us_64(void);  // 64-bit microsecond counter
```

### hardware/gpio

GPIO control and interrupt handling.

```c
#include "hardware/gpio.h"

// Basic GPIO functions
void gpio_init(uint gpio);
void gpio_set_dir(uint gpio, bool out);  // true = output, false = input
void gpio_put(uint gpio, bool value);
bool gpio_get(uint gpio);

// Multiple GPIO operations (using bitmask)
void gpio_set_mask(uint32_t mask);
void gpio_clr_mask(uint32_t mask);
void gpio_xor_mask(uint32_t mask);
void gpio_put_masked(uint32_t mask, uint32_t value);
void gpio_put_all(uint32_t value);

// Pull-up/pull-down resistors
void gpio_pull_up(uint gpio);
void gpio_pull_down(uint gpio);
void gpio_disable_pulls(uint gpio);
void gpio_set_pulls(uint gpio, bool up, bool down);

// GPIO function assignment
enum gpio_function {
    GPIO_FUNC_XIP,     // Flash interface
    GPIO_FUNC_SPI,     // SPI peripheral
    GPIO_FUNC_UART,    // UART peripheral
    GPIO_FUNC_I2C,     // I2C peripheral
    GPIO_FUNC_PWM,     // PWM peripheral
    GPIO_FUNC_SIO,     // Software I/O (default GPIO)
    GPIO_FUNC_PIO0,    // PIO state machine 0
    GPIO_FUNC_PIO1,    // PIO state machine 1
    GPIO_FUNC_CLOCK,   // Clock output
    GPIO_FUNC_USB,     // USB
    GPIO_FUNC_NULL,    // Null (disable)
};

void gpio_set_function(uint gpio, enum gpio_function fn);

// Interrupts
typedef void (*gpio_irq_callback_t)(uint gpio, uint32_t event_mask);

enum gpio_irq_level {
    GPIO_IRQ_LEVEL_LOW  = 0x1,
    GPIO_IRQ_LEVEL_HIGH = 0x2,
    GPIO_IRQ_EDGE_FALL  = 0x4,
    GPIO_IRQ_EDGE_RISE  = 0x8,
};

void gpio_set_irq_enabled(uint gpio, uint32_t events, bool enabled);
void gpio_set_irq_enabled_with_callback(uint gpio, uint32_t events,
                                       bool enabled, gpio_irq_callback_t callback);
void gpio_add_raw_irq_handler(uint gpio, irq_handler_t handler);
void gpio_acknowledge_irq(uint gpio, uint32_t events);
```

### hardware/spi

SPI peripheral control.

```c
#include "hardware/spi.h"

// SPI instances
#define spi0  spi_inst_t *spi0
#define spi1  spi_inst_t *spi1

// Initialize SPI
uint spi_init(spi_inst_t *spi, uint baudrate);
void spi_deinit(spi_inst_t *spi);

// SPI format configuration
void spi_set_format(spi_inst_t *spi, uint data_bits,
                   spi_cpol_t cpol, spi_cpha_t cpha,
                   spi_order_t order);

typedef enum {
    SPI_CPOL_0 = 0,  // Clock idle low
    SPI_CPOL_1 = 1   // Clock idle high
} spi_cpol_t;

typedef enum {
    SPI_CPHA_0 = 0,  // Capture on first edge
    SPI_CPHA_1 = 1   // Capture on second edge
} spi_cpha_t;

typedef enum {
    SPI_MSB_FIRST = 0,
    SPI_LSB_FIRST = 1
} spi_order_t;

// Data transfer (blocking)
int spi_write_blocking(const spi_inst_t *spi, const uint8_t *src, size_t len);
int spi_read_blocking(const spi_inst_t *spi, uint8_t repeated_tx_data,
                     uint8_t *dst, size_t len);
int spi_write_read_blocking(const spi_inst_t *spi, const uint8_t *src,
                            uint8_t *dst, size_t len);

// Check status
bool spi_is_writable(const spi_inst_t *spi);
bool spi_is_readable(const spi_inst_t *spi);
bool spi_is_busy(const spi_inst_t *spi);

// DMA support
uint spi_get_dreq(const spi_inst_t *spi, bool is_tx);
```

### hardware/i2c

I2C peripheral control.

```c
#include "hardware/i2c.h"

// I2C instances
#define i2c0  i2c_inst_t *i2c0
#define i2c1  i2c_inst_t *i2c1

// Initialize I2C
uint i2c_init(i2c_inst_t *i2c, uint baudrate);
void i2c_deinit(i2c_inst_t *i2c);

// I2C transfer (blocking)
int i2c_write_blocking(i2c_inst_t *i2c, uint8_t addr,
                      const uint8_t *src, size_t len, bool nostop);
int i2c_read_blocking(i2c_inst_t *i2c, uint8_t addr,
                     uint8_t *dst, size_t len, bool nostop);

// I2C transfer (non-blocking, timeout)
int i2c_write_timeout_us(i2c_inst_t *i2c, uint8_t addr,
                        const uint8_t *src, size_t len,
                        bool nostop, uint timeout_us);
int i2c_read_timeout_us(i2c_inst_t *i2c, uint8_t addr,
                       uint8_t *dst, size_t len,
                       bool nostop, uint timeout_us);

// I2C write with restart
int i2c_write_blocking_until(i2c_inst_t *i2c, uint8_t addr,
                             const uint8_t *src, size_t len,
                             bool nostop, absolute_time_t until);

// Check bus status
bool i2c_is_busy(i2c_inst_t *i2c);
```

### hardware/pwm

PWM (Pulse Width Modulation) control.

```c
#include "hardware/pwm.h"

// PWM slice functions
void pwm_set_wrap(uint slice_num, uint16_t wrap);
void pwm_set_chan_level(uint slice_num, uint chan, uint16_t level);
void pwm_set_both_levels(uint slice_num, uint16_t level_a, uint16_t level_b);
void pwm_set_gpio_level(uint gpio, uint16_t level);
uint16_t pwm_get_wrap(uint slice_num);
uint16_t pwm_get_chan_level(uint slice_num, uint chan);

// Clock divider (fractional)
void pwm_set_clkdiv(uint slice_num, float divider);
void pwm_set_clkdiv_int_frac(uint slice_num, uint8_t integer, uint8_t fract);

// Enable/disable PWM
void pwm_set_enabled(uint slice_num, bool enabled);
void pwm_set_mask_enabled(uint32_t mask);

// Helper functions
uint pwm_gpio_to_slice_num(uint gpio);
uint pwm_gpio_to_channel(uint gpio);

// PWM configuration
typedef struct {
    uint32_t csr;
    uint32_t div;
    uint32_t ctr;
    uint32_t cc;
    uint32_t top;
} pwm_config;

pwm_config pwm_get_default_config(void);
void pwm_init(uint slice_num, pwm_config *c, bool start);

// Interrupt handling
void pwm_clear_irq(uint slice_num);
void pwm_set_irq_enabled(uint slice_num, bool enabled);
void pwm_set_irq_mask_enabled(uint32_t slice_mask, bool enabled);
```

### hardware/adc

Analog-to-Digital Converter control.

```c
#include "hardware/adc.h"

// Initialize ADC
void adc_init(void);
void adc_gpio_init(uint gpio);  // GPIO 26-28 (ADC0-2)

// Select input channel
void adc_select_input(uint input);  // 0-3 for ADC0-3, 4 for temp sensor

// Read ADC
uint16_t adc_read(void);  // Single 12-bit reading

// FIFO mode
void adc_fifo_setup(bool en, bool dreq_en, uint16_t dreq_thresh,
                    bool err_in_fifo, bool byte_shift);
bool adc_fifo_is_empty(void);
uint16_t adc_fifo_get(void);
uint16_t adc_fifo_get_blocking(void);
void adc_fifo_drain(void);

// Free-running mode
void adc_run(bool run);
void adc_set_clkdiv(float clkdiv);

// IRQ handling
void adc_irq_set_enabled(bool enabled);
```

### hardware/uart

UART serial communication.

```c
#include "hardware/uart.h"

// UART instances
#define uart0  uart_inst_t *uart0
#define uart1  uart_inst_t *uart1

// Initialize UART
uint uart_init(uart_inst_t *uart, uint baudrate);
void uart_deinit(uart_inst_t *uart);

// UART format
void uart_set_format(uart_inst_t *uart, uint data_bits, uint stop_bits,
                    uart_parity_t parity);

typedef enum {
    UART_PARITY_NONE = 0,
    UART_PARITY_EVEN = 1,
    UART_PARITY_ODD  = 2
} uart_parity_t;

// Flow control
void uart_set_hw_flow(uart_inst_t *uart, bool cts, bool rts);

// FIFO control
void uart_set_fifo_enabled(uart_inst_t *uart, bool enabled);

// Write/read (blocking)
void uart_putc_raw(uart_inst_t *uart, char c);
void uart_putc(uart_inst_t *uart, char c);
void uart_puts(uart_inst_t *uart, const char *s);
char uart_getc(uart_inst_t *uart);

// Write/read (non-blocking)
void uart_write_blocking(uart_inst_t *uart, const uint8_t *src, size_t len);
void uart_read_blocking(uart_inst_t *uart, uint8_t *dst, size_t len);

// Status checks
bool uart_is_writable(uart_inst_t *uart);
bool uart_is_readable(uart_inst_t *uart);
bool uart_is_readable_within_us(uart_inst_t *uart, uint32_t us);

// IRQ handling
void uart_set_irq_enables(uart_inst_t *uart, bool rx_has_data, bool tx_needs_data);
```

### hardware/dma

Direct Memory Access controller.

```c
#include "hardware/dma.h"

// Channel management
int dma_claim_unused_channel(bool required);
void dma_channel_claim(uint channel);
void dma_channel_unclaim(uint channel);

// Channel configuration
typedef struct dma_channel_config {
    uint32_t ctrl;
} dma_channel_config;

dma_channel_config dma_channel_get_default_config(uint channel);
void dma_channel_configure(uint channel, const dma_channel_config *config,
                          volatile void *write_addr, const volatile void *read_addr,
                          uint transfer_count, bool trigger);

// Config setters
void channel_config_set_read_increment(dma_channel_config *c, bool incr);
void channel_config_set_write_increment(dma_channel_config *c, bool incr);
void channel_config_set_transfer_data_size(dma_channel_config *c, enum dma_channel_transfer_size size);
void channel_config_set_dreq(dma_channel_config *c, uint dreq);
void channel_config_set_chain_to(dma_channel_config *c, uint chain_to);
void channel_config_set_ring(dma_channel_config *c, bool write, uint size_bits);

enum dma_channel_transfer_size {
    DMA_SIZE_8 = 0,
    DMA_SIZE_16 = 1,
    DMA_SIZE_32 = 2
};

// Start/stop
void dma_channel_start(uint channel);
void dma_start_channel_mask(uint32_t chan_mask);
void dma_channel_abort(uint channel);

// Status
bool dma_channel_is_busy(uint channel);
void dma_channel_wait_for_finish_blocking(uint channel);

// Interrupts
void dma_channel_set_irq0_enabled(uint channel, bool enabled);
void dma_channel_set_irq1_enabled(uint channel, bool enabled);
void dma_irqn_acknowledge_channel(uint irq_index, uint channel_num);
```

### pico/time

High-resolution time functions.

```c
#include "pico/time.h"

// Absolute time type
typedef struct {
    uint64_t _private_us_since_boot;
} absolute_time_t;

// Get current time
absolute_time_t get_absolute_time(void);
uint32_t to_ms_since_boot(absolute_time_t t);
uint64_t to_us_since_boot(absolute_time_t t);

// Time arithmetic
absolute_time_t make_timeout_time_us(uint64_t us);
absolute_time_t make_timeout_time_ms(uint32_t ms);
absolute_time_t delayed_by_us(const absolute_time_t t, uint64_t us);
absolute_time_t delayed_by_ms(const absolute_time_t t, uint32_t ms);

// Time comparison
int64_t absolute_time_diff_us(absolute_time_t from, absolute_time_t to);
bool time_reached(absolute_time_t t);

// Sleep until
void sleep_until(absolute_time_t target);
bool best_effort_wpa_scan_in_progress(uint32_t max_time_ms);

// Alarms
typedef void (*alarm_callback_t)(uint alarm_num);
typedef int64_t (*alarm_pool_callback_t)(alarm_id_t id, void *user_data);

alarm_id_t add_alarm_in_us(uint64_t us, alarm_callback_t callback,
                          void *user_data, bool fire_if_past);
alarm_id_t add_alarm_in_ms(uint32_t ms, alarm_callback_t callback,
                          void *user_data, bool fire_if_past);
alarm_id_t add_alarm_at(absolute_time_t time, alarm_callback_t callback,
                       void *user_data, bool fire_if_past);
bool cancel_alarm(alarm_id_t alarm_id);
```

### pico/multicore

Multicore programming support.

```c
#include "pico/multicore.h"

// Launch core 1
void multicore_launch_core1(void (*entry)(void));
void multicore_launch_core1_with_stack(void (*entry)(void),
                                       uint32_t *stack_bottom,
                                       size_t stack_size_bytes);

// Reset core 1
void multicore_reset_core1(void);

// Inter-core FIFO
void multicore_fifo_push_blocking(uint32_t data);
bool multicore_fifo_push_timeout_us(uint32_t data, uint64_t timeout_us);
uint32_t multicore_fifo_pop_blocking(void);
bool multicore_fifo_pop_timeout_us(uint64_t timeout_us, uint32_t *out);
bool multicore_fifo_rvalid(void);  // Check if data available
bool multicore_fifo_wready(void);  // Check if space available
void multicore_fifo_drain(void);
void multicore_fifo_clear_irq(void);

// Lockout
void multicore_lockout_start_blocking(void);
void multicore_lockout_end_blocking(void);
```

### hardware/flash

Flash memory access and programming.

```c
#include "hardware/flash.h"

// Flash constants
#define FLASH_PAGE_SIZE         256u
#define FLASH_SECTOR_SIZE       4096u
#define FLASH_BLOCK_SIZE        65536u

// Flash operations (interrupts disabled during operation)
void flash_range_erase(uint32_t flash_offs, size_t count);
void flash_range_program(uint32_t flash_offs, const uint8_t *data, size_t count);

// Get flash unique ID
void flash_get_unique_id(uint8_t *id_out);  // 8 bytes

// Flash safety (call before flash operations)
void flash_safe_execute(void (*func)(void *), void *param, uint32_t timeout_ms);
```

### hardware/watchdog

Watchdog timer.

```c
#include "hardware/watchdog.h"

// Enable watchdog
void watchdog_enable(uint32_t delay_ms, bool pause_on_debug);

// Update (feed) watchdog
void watchdog_update(void);

// Check if watchdog caused last reset
bool watchdog_caused_reboot(void);

// Reboot system
void watchdog_reboot(uint32_t pc, uint32_t sp, uint32_t delay_ms);
```

### pico/util/queue

Thread-safe queue implementation.

```c
#include "pico/util/queue.h"

// Queue type
typedef struct {
    spin_lock_t *lock;
    uint8_t *data;
    uint16_t wptr;
    uint16_t rptr;
    uint16_t element_size;
    uint16_t element_count;
} queue_t;

// Queue operations
void queue_init(queue_t *q, uint element_size, uint element_count);
void queue_free(queue_t *q);
bool queue_try_add(queue_t *q, const void *data);
bool queue_try_remove(queue_t *q, void *data);
bool queue_is_empty(queue_t *q);
bool queue_is_full(queue_t *q);
uint queue_get_level(queue_t *q);
```

## USB Device (TinyUSB)

The Pico SDK includes TinyUSB for USB device functionality.

```c
#include "tusb.h"

// USB initialization (already done if using pico_enable_stdio_usb)
bool tusb_init(void);
void tud_task(void);

// USB CDC (Virtual Serial Port)
bool tud_cdc_connected(void);
uint32_t tud_cdc_available(void);
uint32_t tud_cdc_read(void *buffer, uint32_t bufsize);
uint32_t tud_cdc_write(void const *buffer, uint32_t bufsize);
void tud_cdc_write_flush(void);

// USB HID (Human Interface Device)
bool tud_hid_ready(void);
bool tud_hid_report(uint8_t report_id, void const *report, uint8_t len);
bool tud_hid_keyboard_report(uint8_t report_id, uint8_t modifier,
                             uint8_t keycode[6]);
bool tud_hid_mouse_report(uint8_t report_id, uint8_t buttons,
                          int8_t x, int8_t y, int8_t vertical, int8_t horizontal);

// USB MSC (Mass Storage Class)
bool tud_msc_ready(void);
// Callbacks required: tud_msc_inquiry_cb, tud_msc_get_capacity_cb, etc.
```

## Common Patterns

### Pattern: Debounced Button with Interrupt

```c
#include "pico/stdlib.h"

#define BUTTON_PIN 15
#define DEBOUNCE_MS 50

static volatile absolute_time_t last_interrupt_time;
static volatile bool button_pressed = false;

void gpio_callback(uint gpio, uint32_t events) {
    absolute_time_t now = get_absolute_time();
    int64_t diff = absolute_time_diff_us(last_interrupt_time, now);

    if (diff > DEBOUNCE_MS * 1000) {
        button_pressed = true;
        last_interrupt_time = now;
    }
}

int main() {
    stdio_init_all();

    gpio_init(BUTTON_PIN);
    gpio_set_dir(BUTTON_PIN, GPIO_IN);
    gpio_pull_up(BUTTON_PIN);

    gpio_set_irq_enabled_with_callback(BUTTON_PIN, GPIO_IRQ_EDGE_FALL,
                                      true, &gpio_callback);

    while (1) {
        if (button_pressed) {
            printf("Button pressed!\n");
            button_pressed = false;
        }
        tight_loop_contents();
    }
}
```

### Pattern: Periodic Task with Alarm

```c
#include "pico/stdlib.h"
#include "pico/time.h"

int64_t periodic_callback(alarm_id_t id, void *user_data) {
    printf("Periodic task executed\n");

    // Return delay in microseconds for next alarm
    // Return 0 to cancel alarm
    return 1000000;  // 1 second
}

int main() {
    stdio_init_all();

    // Start periodic alarm
    add_alarm_in_ms(1000, periodic_callback, NULL, true);

    while (1) {
        tight_loop_contents();
    }
}
```

### Pattern: SPI with Multiple Devices

```c
#include "hardware/spi.h"
#include "pico/stdlib.h"

#define SPI_PORT spi0
#define CS_DEVICE1 17
#define CS_DEVICE2 21

void spi_select_device(uint cs_pin) {
    // Deselect all devices
    gpio_put(CS_DEVICE1, 1);
    gpio_put(CS_DEVICE2, 1);

    // Select target device
    gpio_put(cs_pin, 0);
}

void spi_deselect_all() {
    gpio_put(CS_DEVICE1, 1);
    gpio_put(CS_DEVICE2, 1);
}

int main() {
    stdio_init_all();

    // Initialize SPI
    spi_init(SPI_PORT, 1000000);  // 1 MHz
    gpio_set_function(16, GPIO_FUNC_SPI);  // MISO
    gpio_set_function(18, GPIO_FUNC_SPI);  // SCK
    gpio_set_function(19, GPIO_FUNC_SPI);  // MOSI

    // Initialize CS pins
    gpio_init(CS_DEVICE1);
    gpio_set_dir(CS_DEVICE1, GPIO_OUT);
    gpio_put(CS_DEVICE1, 1);

    gpio_init(CS_DEVICE2);
    gpio_set_dir(CS_DEVICE2, GPIO_OUT);
    gpio_put(CS_DEVICE2, 1);

    // Communicate with device 1
    spi_select_device(CS_DEVICE1);
    uint8_t data = 0x42;
    spi_write_blocking(SPI_PORT, &data, 1);
    spi_deselect_all();

    while (1) {
        tight_loop_contents();
    }
}
```
