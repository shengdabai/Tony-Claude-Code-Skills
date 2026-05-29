/**
 * Pico SDK Project Template
 *
 * Basic example with LED blink and serial output
 */

#include "pico/stdlib.h"
#include <stdio.h>

// LED pin (GPIO 25 for Pico, adjust for your board)
#define LED_PIN 25

int main() {
    // Initialize standard I/O (USB)
    stdio_init_all();

    // Wait for USB CDC connection (optional)
    sleep_ms(2000);

    printf("Pico SDK Project Started\n");

    // Initialize LED pin
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    uint32_t count = 0;

    while (1) {
        // Toggle LED
        gpio_put(LED_PIN, 1);
        printf("LED ON  - Count: %lu\n", count);
        sleep_ms(500);

        gpio_put(LED_PIN, 0);
        printf("LED OFF - Count: %lu\n", count);
        sleep_ms(500);

        count++;
    }

    return 0;
}
