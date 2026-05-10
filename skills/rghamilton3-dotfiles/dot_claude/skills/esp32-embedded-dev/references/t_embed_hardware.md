# T-Embed ESP32-S3 Hardware Reference

## Overview

LILYGO T-Embed is an ESP32-S3 development board with integrated 1.9" LCD display, rotary encoder, RGB LEDs, and battery charging circuit.

## Hardware Specifications

- **MCU**: ESP32-S3-WROOM-1-N8R8
  - Dual-core Xtensa LX7 @ 240 MHz
  - 512 KB SRAM
  - 8 MB Flash
  - 8 MB PSRAM
  - WiFi 802.11 b/g/n
  - Bluetooth 5.0 (BLE)

- **Display**: 1.9" ST7789 LCD
  - Resolution: 170 x 320 pixels
  - 16-bit color (RGB565)
  - SPI interface @ 40 MHz

- **Input**: Rotary encoder with button
  - Quadrature encoder
  - Push button function
  - Hardware debouncing

- **LEDs**: 8x WS2812B RGB LEDs
  - Addressable RGB
  - Controlled via RMT peripheral

- **Battery**: LiPo charging circuit
  - TP4054 charger IC
  - USB-C charging
  - Battery voltage monitoring

## Complete Pinout

### Display (ST7789 - SPI)
```c
#define LCD_MOSI        GPIO_NUM_35
#define LCD_SCLK        GPIO_NUM_36
#define LCD_CS          GPIO_NUM_37
#define LCD_DC          GPIO_NUM_34
#define LCD_RST         GPIO_NUM_38
#define LCD_BACKLIGHT   GPIO_NUM_33
```

### Rotary Encoder
```c
#define ROTARY_A        GPIO_NUM_3
#define ROTARY_B        GPIO_NUM_46
#define ROTARY_BUTTON   GPIO_NUM_0
```

### RGB LEDs (WS2812B - RMT)
```c
#define LED_DATA        GPIO_NUM_4
#define LED_COUNT       8
```

### Battery Management
```c
#define BAT_ADC         GPIO_NUM_1    // Battery voltage divider
#define CHARGING_DET    GPIO_NUM_2    // Charging status detection
```

### I2C Pins (Available for external sensors)
```c
#define I2C_SDA         GPIO_NUM_18
#define I2C_SCL         GPIO_NUM_8
```

### UART Pins (for debugging)
```c
#define UART_TX         GPIO_NUM_43
#define UART_RX         GPIO_NUM_44
```

## Complete Initialization Example

```c
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "driver/rmt_tx.h"
#include "driver/adc.h"
#include "esp_adc_cal.h"
#include "esp_log.h"

static const char *TAG = "TEMBED";

// Pin definitions
#define LCD_HOST        SPI2_HOST
#define LCD_MOSI        GPIO_NUM_35
#define LCD_SCLK        GPIO_NUM_36
#define LCD_CS          GPIO_NUM_37
#define LCD_DC          GPIO_NUM_34
#define LCD_RST         GPIO_NUM_38
#define LCD_BL          GPIO_NUM_33

#define ROTARY_A        GPIO_NUM_3
#define ROTARY_B        GPIO_NUM_46
#define ROTARY_BTN      GPIO_NUM_0

#define LED_GPIO        GPIO_NUM_4
#define LED_COUNT       8

#define BAT_ADC_CHANNEL ADC1_CHANNEL_0  // GPIO1
#define CHARGING_DET    GPIO_NUM_2

// Global handles
static spi_device_handle_t spi;
static rmt_channel_handle_t led_chan = NULL;
static rmt_encoder_handle_t led_encoder = NULL;
static esp_adc_cal_characteristics_t adc_chars;

// LCD initialization
esp_err_t lcd_init(void) {
    // Configure control pins
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << LCD_DC) | (1ULL << LCD_RST) | (1ULL << LCD_BL),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ESP_ERROR_CHECK(gpio_config(&io_conf));

    // SPI bus configuration
    spi_bus_config_t buscfg = {
        .mosi_io_num = LCD_MOSI,
        .miso_io_num = -1,
        .sclk_io_num = LCD_SCLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = 170 * 320 * 2 + 8,
    };
    ESP_ERROR_CHECK(spi_bus_initialize(LCD_HOST, &buscfg, SPI_DMA_CH_AUTO));

    // SPI device configuration
    spi_device_interface_config_t devcfg = {
        .clock_speed_hz = 40 * 1000 * 1000,
        .mode = 0,
        .spics_io_num = LCD_CS,
        .queue_size = 7,
        .flags = SPI_DEVICE_NO_DUMMY,
    };
    ESP_ERROR_CHECK(spi_bus_add_device(LCD_HOST, &devcfg, &spi));

    // Hardware reset
    gpio_set_level(LCD_RST, 0);
    vTaskDelay(pdMS_TO_TICKS(100));
    gpio_set_level(LCD_RST, 1);
    vTaskDelay(pdMS_TO_TICKS(100));

    // ST7789 initialization sequence
    // (Add ST7789 init commands here)

    // Enable backlight
    gpio_set_level(LCD_BL, 1);

    ESP_LOGI(TAG, "LCD initialized");
    return ESP_OK;
}

// Rotary encoder initialization
esp_err_t rotary_init(void) {
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << ROTARY_A) | (1ULL << ROTARY_B) | (1ULL << ROTARY_BTN),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .intr_type = GPIO_INTR_ANYEDGE,
    };
    ESP_ERROR_CHECK(gpio_config(&io_conf));

    ESP_ERROR_CHECK(gpio_install_isr_service(0));

    // Add ISR handlers here

    ESP_LOGI(TAG, "Rotary encoder initialized");
    return ESP_OK;
}

// RGB LED initialization
esp_err_t led_init(void) {
    rmt_tx_channel_config_t tx_chan_config = {
        .clk_src = RMT_CLK_SRC_DEFAULT,
        .gpio_num = LED_GPIO,
        .mem_block_symbols = 64,
        .resolution_hz = 10 * 1000 * 1000,  // 10 MHz
        .trans_queue_depth = 4,
    };
    ESP_ERROR_CHECK(rmt_new_tx_channel(&tx_chan_config, &led_chan));

    led_strip_encoder_config_t encoder_config = {
        .resolution = 10 * 1000 * 1000,
    };
    ESP_ERROR_CHECK(rmt_new_led_strip_encoder(&encoder_config, &led_encoder));
    ESP_ERROR_CHECK(rmt_enable(led_chan));

    ESP_LOGI(TAG, "RGB LEDs initialized");
    return ESP_OK;
}

// Battery monitoring initialization
esp_err_t battery_init(void) {
    // Configure ADC for battery voltage reading
    ESP_ERROR_CHECK(adc1_config_width(ADC_WIDTH_BIT_12));
    ESP_ERROR_CHECK(adc1_config_channel_atten(BAT_ADC_CHANNEL, ADC_ATTEN_DB_11));

    // Characterize ADC
    esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11,
                            ADC_WIDTH_BIT_12, 1100, &adc_chars);

    // Configure charging detection pin
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << CHARGING_DET),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
    };
    ESP_ERROR_CHECK(gpio_config(&io_conf));

    ESP_LOGI(TAG, "Battery monitoring initialized");
    return ESP_OK;
}

// Read battery voltage (in mV)
uint32_t battery_read_voltage(void) {
    uint32_t adc_reading = 0;

    // Oversample for accuracy
    for (int i = 0; i < 32; i++) {
        adc_reading += adc1_get_raw(BAT_ADC_CHANNEL);
    }
    adc_reading /= 32;

    // Convert to voltage (battery divider: R1=100k, R2=100k)
    uint32_t voltage = esp_adc_cal_raw_to_voltage(adc_reading, &adc_chars);
    voltage *= 2;  // Account for voltage divider

    return voltage;
}

// Check if battery is charging
bool battery_is_charging(void) {
    return gpio_get_level(CHARGING_DET) == 0;
}

// Complete T-Embed initialization
esp_err_t tembed_init(void) {
    ESP_LOGI(TAG, "Initializing T-Embed hardware");

    ESP_ERROR_CHECK(lcd_init());
    ESP_ERROR_CHECK(rotary_init());
    ESP_ERROR_CHECK(led_init());
    ESP_ERROR_CHECK(battery_init());

    uint32_t voltage = battery_read_voltage();
    bool charging = battery_is_charging();
    ESP_LOGI(TAG, "Battery: %lu mV, Charging: %s",
            voltage, charging ? "YES" : "NO");

    ESP_LOGI(TAG, "T-Embed initialization complete");
    return ESP_OK;
}

void app_main(void) {
    tembed_init();

    // Your application code here
}
```

## ST7789 Display Driver

### Display Specifications

- Controller: ST7789V
- Resolution: 170x320 pixels
- Color depth: 16-bit RGB565
- Rotation: Portrait mode (170 width x 320 height)

### Initialization Commands

```c
typedef struct {
    uint8_t cmd;
    uint8_t data[16];
    uint8_t len;
    uint8_t delay_ms;
} lcd_init_cmd_t;

static const lcd_init_cmd_t st7789_init_cmds[] = {
    {0x01, {0}, 0, 150},                          // Software reset
    {0x11, {0}, 0, 255},                          // Sleep out
    {0x3A, {0x55}, 1, 10},                        // Color mode: 16-bit
    {0x36, {0x00}, 1, 0},                         // Memory access control
    {0x2A, {0x00, 0x00, 0x00, 0xAA}, 4, 0},      // Column address (0-170)
    {0x2B, {0x00, 0x00, 0x01, 0x3F}, 4, 0},      // Row address (0-319)
    {0x21, {0}, 0, 0},                            // Display inversion ON
    {0x13, {0}, 0, 10},                           // Normal display mode
    {0x29, {0}, 0, 255},                          // Display ON
    {0, {0}, 0xFF, 0},                            // END
};

void lcd_send_init_cmds(const lcd_init_cmd_t *cmds) {
    while (cmds->cmd != 0 || cmds->len != 0xFF) {
        lcd_send_cmd(cmds->cmd);

        if (cmds->len > 0) {
            lcd_send_data(cmds->data, cmds->len);
        }

        if (cmds->delay_ms > 0) {
            vTaskDelay(pdMS_TO_TICKS(cmds->delay_ms));
        }

        cmds++;
    }
}
```

## Power Consumption

### Typical Current Draw

| Mode | Current (mA) | Notes |
|------|-------------|--------|
| Full operation (WiFi + BLE + Display + LEDs) | 200-300 | All peripherals active |
| WiFi active, display on | 120-150 | LEDs off |
| WiFi connected, display dim | 80-100 | Backlight reduced |
| BLE only, display off | 40-60 | WiFi disabled |
| Light sleep | 1-5 | Periodic wake-ups |
| Deep sleep | <0.1 | All peripherals off |

### Power Optimization Tips

1. **Display backlight**: PWM control on GPIO33 for brightness adjustment
2. **LED power**: Turn off unused LEDs
3. **WiFi sleep**: Enable modem sleep for battery operation
4. **Display updates**: Reduce frame rate when not animating
5. **Deep sleep**: Use for long idle periods

## Memory Layout

### Flash Partitioning (Recommended)

```csv
# partitions_tembed.csv
nvs,      data, nvs,     0x9000,  0x6000,
phy_init, data, phy,     0xf000,  0x1000,
factory,  app,  factory, 0x10000, 0x300000,
storage,  data, spiffs,  0x310000, 0x0F0000,
```

### PSRAM Usage

- Frame buffers: Store in PSRAM to save internal RAM
- Large data structures: Allocate using `heap_caps_malloc(MALLOC_CAP_SPIRAM)`
- Display buffers: Use PSRAM for double buffering

## Troubleshooting

### Display Issues

**Flickering display**:
- Increase SPI clock speed (40 MHz recommended)
- Enable double buffering
- Use DMA for transfers

**Wrong colors**:
- Check RGB565 byte order
- Verify MADCTL (0x36) settings

**Partial screen updates**:
- Set correct column/row address range
- Ensure CS pin toggling

### Rotary Encoder

**Erratic counting**:
- Enable hardware debouncing (RC filter)
- Add software debouncing in ISR
- Check pull-up resistors

**Missed counts**:
- Use higher priority interrupt
- Implement quadrature state machine

### LED Issues

**LEDs not responding**:
- Check RMT timing (should be 10 MHz)
- Verify WS2812B data format (GRB order)
- Ensure adequate power supply

**Color accuracy**:
- WS2812B uses GRB order, not RGB
- Apply gamma correction for better perception

### Battery Monitoring

**Inaccurate voltage**:
- Calibrate ADC using `esp_adc_cal_characterize()`
- Average multiple readings
- Account for voltage divider (2x multiplier)

**Charging detection false positives**:
- Add debouncing on CHARGING_DET pin
- Check TP4054 status logic (active low)

## Example Project Structure

```
t-embed-project/
├── main/
│   ├── main.c
│   ├── display_driver.c
│   ├── rotary_encoder.c
│   ├── led_controller.c
│   ├── battery_monitor.c
│   └── CMakeLists.txt
├── components/
│   └── st7789/
│       ├── st7789.c
│       ├── st7789.h
│       └── CMakeLists.txt
├── CMakeLists.txt
├── sdkconfig
└── partitions.csv
```

## References

- [LILYGO T-Embed GitHub](https://github.com/Xinyuan-LilyGO/T-Embed)
- [ESP32-S3 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-s3_datasheet_en.pdf)
- [ST7789 Datasheet](https://www.displayfuture.com/Display/datasheet/controller/ST7789.pdf)
- [WS2812B Datasheet](https://cdn-shop.adafruit.com/datasheets/WS2812B.pdf)
