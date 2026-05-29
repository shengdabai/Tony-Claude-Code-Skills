#!/usr/bin/env python3
"""
SPI Display Driver Example

This example demonstrates SPI communication for displays with:
- SPI configuration (mode, speed, bit order)
- Data/Command pin control
- DMA-like bulk transfers
- Display initialization sequence

Platform: Uses spidev library (Linux)
For ESP32/RP2350: Adapt to ESP-IDF spi_master or Pico SDK spi_* functions

Example displays:
- ST7789: 240x240 or 240x320 TFT LCD (common on T-Embed, Presto)
- ILI9341: 320x240 TFT LCD
- ST7735: 128x160 TFT LCD
"""

import time
import logging
from typing import List, Tuple
from dataclasses import dataclass

try:
    import spidev
    import RPi.GPIO as GPIO
except ImportError:
    print("Install dependencies: pip install spidev RPi.GPIO")
    print("Note: RPi.GPIO for pin control, adapt for other platforms")
    exit(1)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class SPIConfig:
    """SPI configuration parameters"""
    bus: int = 0  # SPI bus number
    device: int = 0  # Chip select
    max_speed_hz: int = 40_000_000  # 40 MHz
    mode: int = 0  # SPI mode (CPOL=0, CPHA=0)
    bits_per_word: int = 8
    lsb_first: bool = False  # MSB first


class ST7789Display:
    """ST7789 TFT display driver"""

    # ST7789 commands
    CMD_SWRESET = 0x01  # Software reset
    CMD_SLPOUT = 0x11  # Sleep out
    CMD_NORON = 0x13  # Normal display mode
    CMD_INVOFF = 0x20  # Display inversion off
    CMD_INVON = 0x21  # Display inversion on
    CMD_DISPON = 0x29  # Display on
    CMD_CASET = 0x2A  # Column address set
    CMD_RASET = 0x2B  # Row address set
    CMD_RAMWR = 0x2C  # Memory write
    CMD_MADCTL = 0x36  # Memory data access control
    CMD_COLMOD = 0x3A  # Interface pixel format

    def __init__(
        self,
        spi_config: SPIConfig,
        dc_pin: int,
        rst_pin: int,
        width: int = 240,
        height: int = 240
    ):
        """
        Initialize ST7789 display driver.

        Args:
            spi_config: SPI configuration
            dc_pin: Data/Command GPIO pin (BCM numbering)
            rst_pin: Reset GPIO pin (BCM numbering)
            width: Display width in pixels
            height: Display height in pixels
        """
        self.spi_config = spi_config
        self.dc_pin = dc_pin
        self.rst_pin = rst_pin
        self.width = width
        self.height = height

        # Initialize SPI
        self.spi = spidev.SpiDev()
        self.spi.open(spi_config.bus, spi_config.device)
        self.spi.max_speed_hz = spi_config.max_speed_hz
        self.spi.mode = spi_config.mode
        self.spi.bits_per_word = spi_config.bits_per_word
        self.spi.lsb_first = spi_config.lsb_first

        # Initialize GPIO
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.dc_pin, GPIO.OUT)
        GPIO.setup(self.rst_pin, GPIO.OUT)

        logger.info(
            f"ST7789 initialized: {width}x{height}, "
            f"SPI {spi_config.max_speed_hz / 1_000_000:.0f} MHz"
        )

    def reset(self):
        """Hardware reset display"""
        GPIO.output(self.rst_pin, GPIO.HIGH)
        time.sleep(0.01)
        GPIO.output(self.rst_pin, GPIO.LOW)
        time.sleep(0.01)
        GPIO.output(self.rst_pin, GPIO.HIGH)
        time.sleep(0.12)
        logger.debug("Display reset")

    def write_command(self, cmd: int):
        """
        Write command byte to display.

        Args:
            cmd: Command byte
        """
        GPIO.output(self.dc_pin, GPIO.LOW)  # Command mode
        self.spi.writebytes([cmd])

    def write_data(self, data: List[int]):
        """
        Write data bytes to display.

        Args:
            data: List of data bytes
        """
        GPIO.output(self.dc_pin, GPIO.HIGH)  # Data mode
        self.spi.writebytes(data)

    def write_data_bulk(self, data: bytes):
        """
        Write large data buffer to display (efficient for frame buffer).

        Args:
            data: Bytes to write
        """
        GPIO.output(self.dc_pin, GPIO.HIGH)  # Data mode

        # Send in chunks to avoid SPI driver limits
        chunk_size = 4096
        for i in range(0, len(data), chunk_size):
            chunk = data[i:i + chunk_size]
            self.spi.writebytes(chunk)

    def init_display(self):
        """Initialize display with command sequence"""
        logger.info("Initializing display...")

        # Hardware reset
        self.reset()

        # Software reset
        self.write_command(self.CMD_SWRESET)
        time.sleep(0.15)

        # Sleep out
        self.write_command(self.CMD_SLPOUT)
        time.sleep(0.50)

        # Color mode: 16-bit color (RGB565)
        self.write_command(self.CMD_COLMOD)
        self.write_data([0x55])  # 16-bit/pixel

        # Memory data access control (rotation, color order)
        self.write_command(self.CMD_MADCTL)
        self.write_data([0x00])  # Default orientation

        # Display inversion off
        self.write_command(self.CMD_INVOFF)

        # Normal display mode
        self.write_command(self.CMD_NORON)
        time.sleep(0.01)

        # Display on
        self.write_command(self.CMD_DISPON)
        time.sleep(0.10)

        logger.info("Display initialized")

    def set_window(
        self,
        x0: int,
        y0: int,
        x1: int,
        y1: int
    ):
        """
        Set display window for drawing.

        Args:
            x0: Start column
            y0: Start row
            x1: End column
            y1: End row
        """
        # Column address set
        self.write_command(self.CMD_CASET)
        self.write_data([
            (x0 >> 8) & 0xFF,
            x0 & 0xFF,
            (x1 >> 8) & 0xFF,
            x1 & 0xFF
        ])

        # Row address set
        self.write_command(self.CMD_RASET)
        self.write_data([
            (y0 >> 8) & 0xFF,
            y0 & 0xFF,
            (y1 >> 8) & 0xFF,
            y1 & 0xFF
        ])

        # Memory write
        self.write_command(self.CMD_RAMWR)

    def fill_screen(self, color: int):
        """
        Fill entire screen with color.

        Args:
            color: RGB565 color (16-bit)
        """
        logger.info(f"Filling screen with color 0x{color:04X}")

        # Set window to full screen
        self.set_window(0, 0, self.width - 1, self.height - 1)

        # Create color buffer (RGB565 = 2 bytes per pixel)
        pixel_count = self.width * self.height
        color_bytes = bytes([
            (color >> 8) & 0xFF,  # High byte
            color & 0xFF           # Low byte
        ] * pixel_count)

        # Write buffer to display
        self.write_data_bulk(color_bytes)

    def draw_pixel(self, x: int, y: int, color: int):
        """
        Draw single pixel.

        Args:
            x: Column
            y: Row
            color: RGB565 color
        """
        if x < 0 or x >= self.width or y < 0 or y >= self.height:
            return

        self.set_window(x, y, x, y)
        self.write_data([
            (color >> 8) & 0xFF,
            color & 0xFF
        ])

    def draw_rectangle(
        self,
        x: int,
        y: int,
        w: int,
        h: int,
        color: int
    ):
        """
        Draw filled rectangle.

        Args:
            x: Start column
            y: Start row
            w: Width
            h: Height
            color: RGB565 color
        """
        self.set_window(x, y, x + w - 1, y + h - 1)

        # Create color buffer
        pixel_count = w * h
        color_bytes = bytes([
            (color >> 8) & 0xFF,
            color & 0xFF
        ] * pixel_count)

        self.write_data_bulk(color_bytes)

    def close(self):
        """Clean up resources"""
        self.spi.close()
        GPIO.cleanup()
        logger.info("Display closed")


# Color definitions (RGB565)
class Color:
    """Common RGB565 colors"""
    BLACK = 0x0000
    WHITE = 0xFFFF
    RED = 0xF800
    GREEN = 0x07E0
    BLUE = 0x001F
    CYAN = 0x07FF
    MAGENTA = 0xF81F
    YELLOW = 0xFFE0
    ORANGE = 0xFD20


# Example usage
if __name__ == "__main__":
    # Pin configuration (adjust for your hardware)
    DC_PIN = 25  # BCM GPIO 25
    RST_PIN = 27  # BCM GPIO 27

    # SPI configuration
    spi_config = SPIConfig(
        bus=0,
        device=0,
        max_speed_hz=40_000_000,  # 40 MHz
        mode=0  # Mode 0 for ST7789
    )

    # Create display
    display = ST7789Display(
        spi_config=spi_config,
        dc_pin=DC_PIN,
        rst_pin=RST_PIN,
        width=240,
        height=240
    )

    try:
        # Initialize
        display.init_display()

        # Test pattern
        logger.info("Drawing test pattern...")

        # Fill screen with colors
        for color in [Color.BLACK, Color.RED, Color.GREEN, Color.BLUE, Color.WHITE]:
            display.fill_screen(color)
            time.sleep(0.5)

        # Draw rectangles
        display.fill_screen(Color.BLACK)
        display.draw_rectangle(20, 20, 80, 80, Color.RED)
        display.draw_rectangle(140, 20, 80, 80, Color.GREEN)
        display.draw_rectangle(20, 140, 80, 80, Color.BLUE)
        display.draw_rectangle(140, 140, 80, 80, Color.YELLOW)

        logger.info("Test complete")
        time.sleep(2)

    finally:
        # Clean up
        display.close()
