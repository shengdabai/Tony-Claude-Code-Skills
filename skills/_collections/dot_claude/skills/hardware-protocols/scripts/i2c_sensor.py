#!/usr/bin/env python3
"""
I2C Sensor Reading with Error Handling

This example demonstrates robust I2C sensor communication with:
- Device detection and scanning
- Register read/write with error handling
- Retry logic with exponential backoff
- Multi-byte data handling (LSB/MSB)

Platform: Uses smbus2 library (Linux)
For ESP32/RP2350: Adapt to ESP-IDF i2c_master or Pico SDK i2c_* functions

Example sensors:
- BME280: Temperature, humidity, pressure (0x76 or 0x77)
- MPU6050: Accelerometer, gyroscope (0x68)
- ADS1115: 16-bit ADC (0x48-0x4F)
"""

import time
import logging
from typing import Optional, List, Tuple
from dataclasses import dataclass

try:
    from smbus2 import SMBus
except ImportError:
    print("Install smbus2: pip install smbus2")
    exit(1)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class I2CDevice:
    """I2C device information"""
    address: int
    name: str = "Unknown"
    detected: bool = False


class I2CSensor:
    """Robust I2C sensor communication"""

    # Common I2C device addresses
    KNOWN_DEVICES = {
        0x68: "MPU6050 (Accel/Gyro)",
        0x76: "BME280/BMP280 (Temp/Pressure)",
        0x77: "BME280/BMP280 (Temp/Pressure)",
        0x3C: "SSD1306 (OLED Display)",
        0x3D: "SSD1306 (OLED Display)",
        0x48: "ADS1115 (ADC)",
        0x50: "AT24C32 (EEPROM)",
    }

    def __init__(self, bus_number: int = 1, max_retries: int = 3):
        """
        Initialize I2C interface.

        Args:
            bus_number: I2C bus number (1 for /dev/i2c-1, Raspberry Pi default)
            max_retries: Maximum retry attempts for failed operations
        """
        self.bus_number = bus_number
        self.max_retries = max_retries
        self.bus: Optional[SMBus] = None

    def open(self):
        """Open I2C bus"""
        try:
            self.bus = SMBus(self.bus_number)
            logger.info(f"Opened I2C bus {self.bus_number}")
        except Exception as e:
            logger.error(f"Failed to open I2C bus: {e}")
            raise

    def close(self):
        """Close I2C bus"""
        if self.bus:
            self.bus.close()
            logger.info("Closed I2C bus")

    def scan(self) -> List[I2CDevice]:
        """
        Scan I2C bus for devices.

        Returns:
            List of detected I2C devices
        """
        if not self.bus:
            raise RuntimeError("I2C bus not opened")

        devices = []
        logger.info("Scanning I2C bus...")

        for addr in range(0x01, 0x78):  # Valid I2C addresses: 0x01 to 0x77
            try:
                # Try to write to address (ACK = device present)
                self.bus.write_quick(addr)
                name = self.KNOWN_DEVICES.get(addr, "Unknown Device")
                device = I2CDevice(address=addr, name=name, detected=True)
                devices.append(device)
                logger.info(f"  Found device at 0x{addr:02X}: {name}")

            except OSError:
                # No device at this address (NACK)
                pass

        logger.info(f"Scan complete. Found {len(devices)} device(s)")
        return devices

    def read_byte(self, device_addr: int, register: int) -> Optional[int]:
        """
        Read single byte from device register.

        Args:
            device_addr: I2C device address (7-bit)
            register: Register address to read from

        Returns:
            Byte value, or None on error
        """
        for attempt in range(self.max_retries):
            try:
                value = self.bus.read_byte_data(device_addr, register)
                logger.debug(
                    f"Read 0x{device_addr:02X} reg 0x{register:02X} = 0x{value:02X}"
                )
                return value

            except OSError as e:
                logger.warning(
                    f"Read failed (attempt {attempt + 1}/{self.max_retries}): {e}"
                )
                if attempt < self.max_retries - 1:
                    time.sleep(0.1 * (2 ** attempt))  # Exponential backoff
                else:
                    logger.error("Max retries exceeded")
                    return None

    def write_byte(self, device_addr: int, register: int, value: int) -> bool:
        """
        Write single byte to device register.

        Args:
            device_addr: I2C device address (7-bit)
            register: Register address to write to
            value: Byte value to write

        Returns:
            True on success, False on error
        """
        for attempt in range(self.max_retries):
            try:
                self.bus.write_byte_data(device_addr, register, value)
                logger.debug(
                    f"Write 0x{device_addr:02X} reg 0x{register:02X} = 0x{value:02X}"
                )
                return True

            except OSError as e:
                logger.warning(
                    f"Write failed (attempt {attempt + 1}/{self.max_retries}): {e}"
                )
                if attempt < self.max_retries - 1:
                    time.sleep(0.1 * (2 ** attempt))
                else:
                    logger.error("Max retries exceeded")
                    return False

    def read_word(
        self,
        device_addr: int,
        register: int,
        little_endian: bool = False
    ) -> Optional[int]:
        """
        Read 16-bit word from device register.

        Args:
            device_addr: I2C device address
            register: Starting register address
            little_endian: If True, LSB first; if False, MSB first

        Returns:
            16-bit value, or None on error
        """
        msb = self.read_byte(device_addr, register)
        lsb = self.read_byte(device_addr, register + 1)

        if msb is None or lsb is None:
            return None

        if little_endian:
            return (msb << 8) | lsb
        else:
            return (lsb << 8) | msb

    def read_block(
        self,
        device_addr: int,
        register: int,
        length: int
    ) -> Optional[List[int]]:
        """
        Read multiple bytes from device.

        Args:
            device_addr: I2C device address
            register: Starting register address
            length: Number of bytes to read

        Returns:
            List of bytes, or None on error
        """
        for attempt in range(self.max_retries):
            try:
                data = self.bus.read_i2c_block_data(device_addr, register, length)
                logger.debug(
                    f"Read block 0x{device_addr:02X} reg 0x{register:02X} "
                    f"len {length}: {[hex(b) for b in data]}"
                )
                return data

            except OSError as e:
                logger.warning(
                    f"Block read failed (attempt {attempt + 1}/{self.max_retries}): {e}"
                )
                if attempt < self.max_retries - 1:
                    time.sleep(0.1 * (2 ** attempt))
                else:
                    logger.error("Max retries exceeded")
                    return None


class BME280Sensor:
    """Example: BME280 temperature/humidity/pressure sensor"""

    # BME280 register addresses
    REG_ID = 0xD0
    REG_CTRL_HUM = 0xF2
    REG_STATUS = 0xF3
    REG_CTRL_MEAS = 0xF4
    REG_CONFIG = 0xF5
    REG_PRESS_MSB = 0xF7
    REG_TEMP_MSB = 0xFA
    REG_HUM_MSB = 0xFD

    CHIP_ID = 0x60  # Expected chip ID

    def __init__(self, i2c: I2CSensor, address: int = 0x76):
        """
        Initialize BME280 sensor.

        Args:
            i2c: I2CSensor instance
            address: I2C address (0x76 or 0x77)
        """
        self.i2c = i2c
        self.address = address

    def begin(self) -> bool:
        """
        Initialize sensor and verify chip ID.

        Returns:
            True if sensor detected and initialized
        """
        # Read chip ID
        chip_id = self.i2c.read_byte(self.address, self.REG_ID)
        if chip_id != self.CHIP_ID:
            logger.error(
                f"BME280 not found at 0x{self.address:02X} "
                f"(ID: 0x{chip_id:02X}, expected 0x{self.CHIP_ID:02X})"
            )
            return False

        logger.info(f"BME280 detected at 0x{self.address:02X}")

        # Configure sensor
        # Humidity oversampling x1
        self.i2c.write_byte(self.address, self.REG_CTRL_HUM, 0x01)

        # Temperature and pressure oversampling x1, normal mode
        self.i2c.write_byte(self.address, self.REG_CTRL_MEAS, 0x27)

        # Config: standby 1000ms, filter off
        self.i2c.write_byte(self.address, self.REG_CONFIG, 0xA0)

        return True

    def read_temperature(self) -> Optional[float]:
        """
        Read temperature in Celsius.

        Returns:
            Temperature value, or None on error
        """
        # Read raw 20-bit temperature (MSB, LSB, XLSB)
        data = self.i2c.read_block(self.address, self.REG_TEMP_MSB, 3)
        if not data:
            return None

        adc_T = (data[0] << 12) | (data[1] << 4) | (data[2] >> 4)

        # Simplified conversion (real implementation needs calibration data)
        # This is just for demonstration
        temp_c = (adc_T / 16384.0) - 273.15

        logger.info(f"Temperature: {temp_c:.2f} °C")
        return temp_c


# Example usage
if __name__ == "__main__":
    # Create I2C interface
    i2c = I2CSensor(bus_number=1)

    try:
        # Open bus
        i2c.open()

        # Scan for devices
        devices = i2c.scan()

        if not devices:
            logger.warning("No I2C devices found")
            exit(1)

        # Try to initialize BME280 if found
        bme_addresses = [0x76, 0x77]
        for addr in bme_addresses:
            if any(d.address == addr for d in devices):
                logger.info(f"\nInitializing BME280 at 0x{addr:02X}...")
                bme = BME280Sensor(i2c, addr)

                if bme.begin():
                    # Read temperature every 2 seconds
                    for _ in range(5):
                        temp = bme.read_temperature()
                        time.sleep(2)
                    break

    finally:
        # Clean up
        i2c.close()
