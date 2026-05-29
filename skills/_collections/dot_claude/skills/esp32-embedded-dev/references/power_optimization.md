# Power Optimization Strategies for ESP32

## Power Consumption Overview

### ESP32-S3 Power Modes

| Mode | Current | Wake-up Time | Use Case |
|------|---------|--------------|----------|
| Active (WiFi TX) | 190-260 mA | N/A | Network transmission |
| Active (WiFi RX) | 100-120 mA | N/A | Network reception |
| Active (BLE) | 40-60 mA | N/A | BLE operations |
| Modem sleep | 15-30 mA | <1 ms | WiFi connected, CPU active |
| Light sleep | 0.8-1.2 mA | 5-10 ms | Periodic wake-ups |
| Deep sleep | 10-150 µA | 100-500 ms | Long idle periods |
| Hibernation | <5 µA | 500+ ms | Ultra-low power |

## Deep Sleep Strategies

### Basic Deep Sleep

```c
#include "esp_sleep.h"

void enter_deep_sleep(uint64_t sleep_time_us) {
    ESP_LOGI("POWER", "Entering deep sleep for %llu seconds",
            sleep_time_us / 1000000);

    // Configure wake-up source
    esp_sleep_enable_timer_wakeup(sleep_time_us);

    // Disable peripherals
    esp_wifi_stop();
    esp_bluedroid_disable();
    esp_bt_controller_disable();

    // Enter deep sleep
    esp_deep_sleep_start();
}
```

### Deep Sleep with GPIO Wake

```c
// Wake on button press (LOW level)
esp_sleep_enable_ext0_wakeup(GPIO_NUM_0, 0);

// Wake on any of multiple GPIOs (HIGH level)
const uint64_t ext1_mask = (1ULL << GPIO_NUM_2) | (1ULL << GPIO_NUM_3);
esp_sleep_enable_ext1_wakeup(ext1_mask, ESP_EXT1_WAKEUP_ANY_HIGH);
```

### Deep Sleep with ULP Coprocessor

```c
#include "soc/rtc_cntl_reg.h"
#include "soc/sens_reg.h"
#include "driver/rtc_io.h"
#include "esp32s3/ulp.h"

// ULP program to read sensor periodically
const ulp_insn_t ulp_program[] = {
    // Read ADC
    I_MOVI(R0, 0),
    I_ADC(R1, 0, 0),  // Read ADC1 channel 0

    // Compare threshold
    I_MOVI(R2, 2000),
    I_SUBR(R3, R1, R2),
    I_BGE(4, 0),  // If R1 >= threshold, wake up

    // Sleep
    I_HALT(),

    // Wake up main CPU
    I_WAKE(),
    I_HALT(),
};

void start_ulp_program(void) {
    // Load ULP program
    esp_err_t err = ulp_load_binary(0, ulp_program,
                                   sizeof(ulp_program) / sizeof(ulp_insn_t));
    ESP_ERROR_CHECK(err);

    // Set ULP wake-up period (in microseconds)
    ulp_set_wakeup_period(0, 1000000);  // 1 second

    // Start ULP
    err = ulp_run(0);
    ESP_ERROR_CHECK(err);

    // Enable ULP wake-up
    esp_sleep_enable_ulp_wakeup();
}
```

## Light Sleep Optimization

### Automatic Light Sleep

```c
#include "esp_pm.h"

void enable_dynamic_frequency_scaling(void) {
    esp_pm_config_t pm_config = {
        .max_freq_mhz = 240,
        .min_freq_mhz = 80,
        .light_sleep_enable = true
    };

    ESP_ERROR_CHECK(esp_pm_configure(&pm_config));

    ESP_LOGI("POWER", "Dynamic frequency scaling enabled");
}
```

### Manual Light Sleep

```c
void periodic_light_sleep(void) {
    while (1) {
        // Work for 100ms
        do_work();

        // Sleep for 900ms
        esp_sleep_enable_timer_wakeup(900000);  // 900ms in microseconds
        esp_light_sleep_start();

        // Effective duty cycle: 10%
    }
}
```

### Light Sleep with GPIO Wake

```c
// Configure GPIO for wake-up
rtc_gpio_init(GPIO_NUM_0);
rtc_gpio_set_direction(GPIO_NUM_0, RTC_GPIO_MODE_INPUT_ONLY);
rtc_gpio_pullup_en(GPIO_NUM_0);

// Enable GPIO wake-up
esp_sleep_enable_ext0_wakeup(GPIO_NUM_0, 0);

esp_light_sleep_start();

// Check wake-up cause
esp_sleep_wakeup_cause_t cause = esp_sleep_get_wakeup_cause();
if (cause == ESP_SLEEP_WAKEUP_EXT0) {
    ESP_LOGI("POWER", "Woke from GPIO");
}
```

## WiFi Power Saving

### Modem Sleep

```c
// Minimal modem sleep (better latency)
esp_wifi_set_ps(WIFI_PS_MIN_MODEM);

// Maximum modem sleep (better power saving)
esp_wifi_set_ps(WIFI_PS_MAX_MODEM);

// No power save (best performance)
esp_wifi_set_ps(WIFI_PS_NONE);
```

### Listen Interval Tuning

```c
wifi_config_t wifi_config = {
    .sta = {
        .ssid = WIFI_SSID,
        .password = WIFI_PASSWORD,
        .listen_interval = 10,  // Wake every 10 beacons (~1024ms)
    },
};

// Longer interval = more power savings but higher latency
```

### WiFi Sleep Pattern

```c
void wifi_intermittent_pattern(void) {
    while (1) {
        // Connect WiFi
        esp_wifi_start();
        esp_wifi_connect();

        // Wait for connection
        vTaskDelay(pdMS_TO_TICKS(5000));

        // Send data
        send_mqtt_data();

        // Disconnect
        esp_wifi_disconnect();
        esp_wifi_stop();

        // Sleep
        esp_sleep_enable_timer_wakeup(300 * 1000000);  // 5 minutes
        esp_deep_sleep_start();
    }
}
```

## BLE Power Optimization

### Connection Interval

```c
// Longer interval = lower power
esp_ble_conn_update_params_t conn_params = {
    .min_int = 80,   // 100ms
    .max_int = 160,  // 200ms
    .latency = 4,    // Skip 4 connection events
    .timeout = 400,  // 4s
};

esp_ble_gap_update_conn_params(&conn_params);
```

### Advertising Interval

```c
// Advertising parameters
esp_ble_adv_params_t adv_params = {
    .adv_int_min = 0x20,    // 20ms
    .adv_int_max = 0x40,    // 40ms
    .adv_type = ADV_TYPE_IND,
    .own_addr_type = BLE_ADDR_TYPE_PUBLIC,
    .channel_map = ADV_CHNL_ALL,
    .adv_filter_policy = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY,
};

// Longer interval saves power but reduces discoverability
```

### Non-Connectable Beacons

```c
// Use non-connectable advertising for beacons
esp_ble_adv_params_t beacon_params = {
    .adv_int_min = 0x100,   // 160ms
    .adv_int_max = 0x200,   // 320ms
    .adv_type = ADV_TYPE_NONCONN_IND,  // Non-connectable
    .own_addr_type = BLE_ADDR_TYPE_PUBLIC,
    .channel_map = ADV_CHNL_ALL,
};
```

## Peripheral Power Management

### Display Backlight Control

```c
#include "driver/ledc.h"

#define LCD_BL_PIN  GPIO_NUM_33
#define PWM_CHANNEL LEDC_CHANNEL_0

void init_backlight_pwm(void) {
    ledc_timer_config_t timer_conf = {
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .duty_resolution = LEDC_TIMER_8_BIT,
        .timer_num = LEDC_TIMER_0,
        .freq_hz = 5000,
        .clk_cfg = LEDC_AUTO_CLK
    };
    ledc_timer_config(&timer_conf);

    ledc_channel_config_t channel_conf = {
        .gpio_num = LCD_BL_PIN,
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .channel = PWM_CHANNEL,
        .timer_sel = LEDC_TIMER_0,
        .duty = 0,
        .hpoint = 0
    };
    ledc_channel_config(&channel_conf);
}

void set_backlight_brightness(uint8_t brightness) {
    ledc_set_duty(LEDC_LOW_SPEED_MODE, PWM_CHANNEL, brightness);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, PWM_CHANNEL);
}

// Adaptive brightness based on ambient light
void adaptive_backlight(void) {
    uint32_t ambient = read_light_sensor();

    if (ambient > 1000) {
        set_backlight_brightness(255);  // Full brightness
    } else if (ambient > 500) {
        set_backlight_brightness(128);  // Medium
    } else {
        set_backlight_brightness(64);   // Low
    }
}
```

### LED Power Control

```c
// Turn off LEDs when not needed
void leds_off(void) {
    rgb_t black[LED_COUNT] = {0};
    ws2812_set_colors(black, LED_COUNT);
}

// Reduce LED brightness
void set_led_brightness(uint8_t brightness) {
    for (int i = 0; i < LED_COUNT; i++) {
        leds[i].r = (leds[i].r * brightness) / 255;
        leds[i].g = (leds[i].g * brightness) / 255;
        leds[i].b = (leds[i].b * brightness) / 255;
    }
}
```

### I2C/SPI Power Down

```c
// Disable I2C when not in use
void i2c_power_down(void) {
    i2c_driver_delete(I2C_NUM_0);

    // Set pins to input with pull-up to reduce leakage
    gpio_set_direction(I2C_SDA_PIN, GPIO_MODE_INPUT);
    gpio_set_direction(I2C_SCL_PIN, GPIO_MODE_INPUT);
    gpio_set_pull_mode(I2C_SDA_PIN, GPIO_PULLUP_ONLY);
    gpio_set_pull_mode(I2C_SCL_PIN, GPIO_PULLUP_ONLY);
}

// Disable SPI when not in use
void spi_power_down(void) {
    spi_bus_remove_device(spi_device);
    spi_bus_free(SPI2_HOST);
}
```

## GPIO Configuration for Low Power

### RTC GPIO

```c
// Configure RTC GPIO for deep sleep retention
rtc_gpio_init(GPIO_NUM_0);
rtc_gpio_set_direction(GPIO_NUM_0, RTC_GPIO_MODE_INPUT_ONLY);
rtc_gpio_pullup_en(GPIO_NUM_0);

// Hold GPIO state during deep sleep
rtc_gpio_hold_en(GPIO_NUM_0);

// Release hold after wake-up
rtc_gpio_hold_dis(GPIO_NUM_0);
```

### GPIO Isolation

```c
// Isolate GPIO to prevent current leakage
void isolate_unused_gpios(void) {
    const gpio_num_t unused_pins[] = {
        GPIO_NUM_5, GPIO_NUM_6, GPIO_NUM_7
    };

    for (int i = 0; i < sizeof(unused_pins) / sizeof(gpio_num_t); i++) {
        gpio_reset_pin(unused_pins[i]);
        gpio_set_direction(unused_pins[i], GPIO_MODE_INPUT);
        gpio_set_pull_mode(unused_pins[i], GPIO_FLOATING);
    }
}
```

## CPU Frequency Scaling

### Manual Frequency Control

```c
#include "esp_pm.h"

// Set CPU frequency to 80 MHz
rtc_cpu_freq_config_t freq_config;
rtc_clk_cpu_freq_mhz_to_config(80, &freq_config);
rtc_clk_cpu_freq_set_config(&freq_config);

// Set back to 240 MHz
rtc_clk_cpu_freq_mhz_to_config(240, &freq_config);
rtc_clk_cpu_freq_set_config(&freq_config);
```

### Task-Based Frequency Scaling

```c
void variable_workload_task(void *pvParameters) {
    rtc_cpu_freq_config_t low_freq, high_freq;
    rtc_clk_cpu_freq_mhz_to_config(80, &low_freq);
    rtc_clk_cpu_freq_mhz_to_config(240, &high_freq);

    while (1) {
        if (workload_detected()) {
            // Boost to high frequency
            rtc_clk_cpu_freq_set_config(&high_freq);
            process_heavy_workload();
        } else {
            // Reduce to low frequency
            rtc_clk_cpu_freq_set_config(&low_freq);
            idle_processing();
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
```

## Battery Monitoring

### ADC-Based Voltage Measurement

```c
#include "esp_adc_cal.h"

#define BAT_ADC_CHANNEL  ADC1_CHANNEL_0
#define VOLTAGE_DIVIDER  2  // R1 = R2

static esp_adc_cal_characteristics_t adc_chars;

void battery_monitor_init(void) {
    adc1_config_width(ADC_WIDTH_BIT_12);
    adc1_config_channel_atten(BAT_ADC_CHANNEL, ADC_ATTEN_DB_11);

    esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11,
                            ADC_WIDTH_BIT_12, 1100, &adc_chars);
}

uint32_t battery_read_voltage(void) {
    uint32_t adc_reading = 0;

    // Oversample for accuracy
    for (int i = 0; i < 64; i++) {
        adc_reading += adc1_get_raw(BAT_ADC_CHANNEL);
    }
    adc_reading /= 64;

    uint32_t voltage = esp_adc_cal_raw_to_voltage(adc_reading, &adc_chars);
    return voltage * VOLTAGE_DIVIDER;
}

uint8_t battery_get_percentage(void) {
    uint32_t voltage = battery_read_voltage();

    // LiPo discharge curve
    if (voltage >= 4200) return 100;
    if (voltage >= 4100) return 90;
    if (voltage >= 4000) return 80;
    if (voltage >= 3900) return 60;
    if (voltage >= 3800) return 40;
    if (voltage >= 3700) return 20;
    if (voltage >= 3600) return 10;
    return 0;
}
```

### Low Battery Handling

```c
void battery_monitor_task(void *pvParameters) {
    while (1) {
        uint8_t battery_pct = battery_get_percentage();

        if (battery_pct < 10) {
            ESP_LOGW("BATTERY", "Critical: %d%%", battery_pct);
            enter_emergency_mode();
        } else if (battery_pct < 20) {
            ESP_LOGW("BATTERY", "Low: %d%%", battery_pct);
            reduce_power_consumption();
        }

        vTaskDelay(pdMS_TO_TICKS(60000));  // Check every minute
    }
}

void reduce_power_consumption(void) {
    // Dim display
    set_backlight_brightness(64);

    // Disable LEDs
    leds_off();

    // Reduce WiFi activity
    esp_wifi_set_ps(WIFI_PS_MAX_MODEM);

    // Reduce update frequency
    // ...
}

void enter_emergency_mode(void) {
    // Save state to NVS
    save_state_to_nvs();

    // Turn off display
    set_backlight_brightness(0);

    // Disconnect WiFi
    esp_wifi_disconnect();
    esp_wifi_stop();

    // Enter deep sleep
    enter_deep_sleep(3600 * 1000000);  // 1 hour
}
```

## Power Profiling

### Measuring Power Consumption

```c
void power_profiling_task(void *pvParameters) {
    while (1) {
        uint32_t heap_free = esp_get_free_heap_size();
        uint32_t heap_min = esp_get_minimum_free_heap_size();

        ESP_LOGI("PROFILE", "Free heap: %lu / Min: %lu", heap_free, heap_min);

        // Log task stack usage
        UBaseType_t stack_hwm = uxTaskGetStackHighWaterMark(NULL);
        ESP_LOGI("PROFILE", "Stack HWM: %lu", stack_hwm);

        vTaskDelay(pdMS_TO_TICKS(10000));
    }
}
```

## Best Practices Summary

1. **Sleep when idle**: Use light sleep for < 1s idle, deep sleep for > 1s
2. **Reduce WiFi duty cycle**: Connect only when needed
3. **Optimize BLE intervals**: Longer intervals for better power
4. **Dim displays**: Backlight is major power consumer
5. **Turn off LEDs**: RGB LEDs consume significant current
6. **CPU scaling**: Run at lower frequency when possible
7. **Peripheral management**: Disable unused peripherals
8. **GPIO configuration**: Properly configure unused pins
9. **Battery monitoring**: Implement low-power mode at low battery
10. **Profile regularly**: Measure actual power consumption
