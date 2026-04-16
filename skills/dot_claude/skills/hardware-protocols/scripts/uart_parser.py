#!/usr/bin/env python3
"""
UART Command Parser with State Machine

This example demonstrates UART communication with:
- AT command handling
- State machine for command sequences
- Line buffering (CR/LF handling)
- Timeout management
- Unsolicited response handling

Platform: Uses pyserial library (cross-platform)
For ESP32/RP2350: Adapt to ESP-IDF uart_* or Pico SDK uart_* functions

Common UART modules:
- ESP8266/ESP32: WiFi modules with AT commands
- HC-05/HC-06: Bluetooth modules
- SIM800/SIM900: GSM/GPRS modules
- NEO-6M: GPS modules (NMEA protocol)
"""

import serial
import time
import logging
from typing import Optional, Callable, List
from enum import Enum
from dataclasses import dataclass

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ATCommandState(Enum):
    """State machine states for AT command processing"""
    IDLE = "idle"
    WAITING_RESPONSE = "waiting_response"
    PROCESSING = "processing"
    ERROR = "error"


@dataclass
class ATResponse:
    """AT command response"""
    success: bool
    response: str
    duration_ms: float


class UARTParser:
    """UART communication with AT command support"""

    def __init__(
        self,
        port: str,
        baudrate: int = 115200,
        timeout: float = 1.0,
        line_terminator: str = "\r\n"
    ):
        """
        Initialize UART parser.

        Args:
            port: Serial port (/dev/ttyUSB0, COM3, etc.)
            baudrate: Baud rate (9600, 115200, etc.)
            timeout: Read timeout in seconds
            line_terminator: Line ending (CR+LF, LF, etc.)
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.line_terminator = line_terminator
        self.serial: Optional[serial.Serial] = None

        # Parser state
        self.state = ATCommandState.IDLE
        self.line_buffer = ""

        # Callbacks for unsolicited responses
        self.unsolicited_handlers: List[Callable[[str], None]] = []

    def open(self):
        """Open serial port"""
        try:
            self.serial = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=self.timeout
            )
            logger.info(
                f"Opened {self.port} at {self.baudrate} baud "
                f"(8N1, timeout={self.timeout}s)"
            )

            # Flush input buffer
            self.serial.reset_input_buffer()

        except serial.SerialException as e:
            logger.error(f"Failed to open {self.port}: {e}")
            raise

    def close(self):
        """Close serial port"""
        if self.serial and self.serial.is_open:
            self.serial.close()
            logger.info(f"Closed {self.port}")

    def read_line(self, timeout: Optional[float] = None) -> Optional[str]:
        """
        Read line from UART (blocking until line terminator or timeout).

        Args:
            timeout: Override default timeout (None = use port timeout)

        Returns:
            Line string (without terminator), or None on timeout
        """
        if timeout is not None:
            original_timeout = self.serial.timeout
            self.serial.timeout = timeout

        try:
            while True:
                # Read one byte
                byte = self.serial.read(1)
                if not byte:
                    # Timeout
                    return None

                char = byte.decode('utf-8', errors='ignore')
                self.line_buffer += char

                # Check for line terminator
                if self.line_buffer.endswith(self.line_terminator):
                    # Remove terminator and return line
                    line = self.line_buffer[:-len(self.line_terminator)]
                    self.line_buffer = ""
                    return line

        finally:
            if timeout is not None:
                self.serial.timeout = original_timeout

    def write_line(self, line: str):
        """
        Write line to UART with terminator.

        Args:
            line: Line to write (terminator will be added)
        """
        data = (line + self.line_terminator).encode('utf-8')
        self.serial.write(data)
        logger.debug(f"TX: {line}")

    def send_at_command(
        self,
        command: str,
        timeout: float = 2.0,
        expected_response: str = "OK"
    ) -> ATResponse:
        """
        Send AT command and wait for response.

        Args:
            command: AT command (without terminator)
            timeout: Maximum wait time for response
            expected_response: Expected success response ("OK", "SEND OK", etc.)

        Returns:
            ATResponse with success status and response text
        """
        start_time = time.time()
        self.state = ATCommandState.WAITING_RESPONSE

        # Send command
        self.write_line(command)

        # Collect response lines
        response_lines = []
        success = False

        # Read lines until timeout or OK/ERROR
        while True:
            elapsed = (time.time() - start_time) * 1000
            remaining = timeout - (elapsed / 1000)

            if remaining <= 0:
                # Timeout
                logger.warning(f"Command timeout: {command}")
                self.state = ATCommandState.ERROR
                break

            line = self.read_line(timeout=remaining)
            if line is None:
                # Timeout
                logger.warning(f"No response to: {command}")
                self.state = ATCommandState.ERROR
                break

            logger.debug(f"RX: {line}")

            # Skip empty lines
            if not line.strip():
                continue

            # Skip command echo
            if line.strip() == command.strip():
                continue

            response_lines.append(line)

            # Check for completion
            if expected_response in line:
                success = True
                self.state = ATCommandState.IDLE
                break
            elif "ERROR" in line:
                success = False
                self.state = ATCommandState.ERROR
                break

        # Calculate duration
        duration_ms = (time.time() - start_time) * 1000

        # Join response lines
        response = "\n".join(response_lines)

        # Log result
        if success:
            logger.info(f"Command OK ({duration_ms:.1f}ms): {command}")
        else:
            logger.error(f"Command FAILED ({duration_ms:.1f}ms): {command}")

        return ATResponse(success, response, duration_ms)

    def register_unsolicited_handler(self, handler: Callable[[str], None]):
        """
        Register callback for unsolicited responses (events).

        Args:
            handler: Callback function(line: str) -> None
        """
        self.unsolicited_handlers.append(handler)

    def poll_unsolicited(self, timeout: float = 0.1):
        """
        Poll for unsolicited responses (non-blocking).

        Args:
            timeout: How long to wait for data
        """
        line = self.read_line(timeout=timeout)
        if line and line.strip():
            logger.debug(f"Unsolicited: {line}")

            # Call handlers
            for handler in self.unsolicited_handlers:
                try:
                    handler(line)
                except Exception as e:
                    logger.error(f"Handler error: {e}")


class WiFiATModule:
    """Example: ESP8266/ESP32 WiFi module with AT commands"""

    def __init__(self, uart: UARTParser):
        """
        Initialize WiFi module interface.

        Args:
            uart: UARTParser instance
        """
        self.uart = uart

    def test(self) -> bool:
        """Test AT communication"""
        response = self.uart.send_at_command("AT", timeout=1.0)
        return response.success

    def reset(self) -> bool:
        """Software reset module"""
        response = self.uart.send_at_command("AT+RST", timeout=5.0)
        return response.success

    def get_version(self) -> Optional[str]:
        """Get firmware version"""
        response = self.uart.send_at_command("AT+GMR", timeout=2.0)
        if response.success:
            return response.response
        return None

    def connect_wifi(self, ssid: str, password: str) -> bool:
        """
        Connect to WiFi access point.

        Args:
            ssid: WiFi SSID
            password: WiFi password

        Returns:
            True if connected
        """
        # Set WiFi mode to station
        resp = self.uart.send_at_command("AT+CWMODE=1", timeout=2.0)
        if not resp.success:
            return False

        # Connect to AP
        cmd = f'AT+CWJAP="{ssid}","{password}"'
        resp = self.uart.send_at_command(cmd, timeout=10.0)

        return resp.success

    def disconnect_wifi(self) -> bool:
        """Disconnect from WiFi"""
        resp = self.uart.send_at_command("AT+CWQAP", timeout=2.0)
        return resp.success

    def get_ip(self) -> Optional[str]:
        """Get IP address"""
        resp = self.uart.send_at_command("AT+CIFSR", timeout=2.0)
        if resp.success:
            # Parse IP from response (format varies by module)
            for line in resp.response.split('\n'):
                if "STAIP" in line:
                    # Extract IP address
                    parts = line.split('"')
                    if len(parts) >= 2:
                        return parts[1]
        return None


# Example usage
if __name__ == "__main__":
    # Serial port configuration (adjust for your system)
    PORT = "/dev/ttyUSB0"  # Linux
    # PORT = "COM3"  # Windows
    # PORT = "/dev/cu.usbserial-0001"  # macOS

    BAUDRATE = 115200

    # Create UART parser
    uart = UARTParser(
        port=PORT,
        baudrate=BAUDRATE,
        timeout=1.0,
        line_terminator="\r\n"
    )

    try:
        # Open serial port
        uart.open()

        # Create WiFi module interface
        wifi = WiFiATModule(uart)

        # Test communication
        logger.info("Testing AT communication...")
        if wifi.test():
            logger.info("AT test OK")

            # Get version
            version = wifi.get_version()
            if version:
                logger.info(f"Firmware version:\n{version}")

            # Connect to WiFi (example - replace with your credentials)
            # logger.info("Connecting to WiFi...")
            # if wifi.connect_wifi("YourSSID", "YourPassword"):
            #     logger.info("WiFi connected")
            #
            #     ip = wifi.get_ip()
            #     if ip:
            #         logger.info(f"IP address: {ip}")

        else:
            logger.error("AT test failed - check wiring and baud rate")

        # Example: Poll for unsolicited responses
        logger.info("Polling for unsolicited responses (5 seconds)...")
        for _ in range(50):
            uart.poll_unsolicited(timeout=0.1)

    except serial.SerialException as e:
        logger.error(f"Serial error: {e}")

    except KeyboardInterrupt:
        logger.info("Interrupted by user")

    finally:
        # Clean up
        uart.close()
