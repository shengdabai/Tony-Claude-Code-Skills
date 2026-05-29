# Embedded Bus Protocols (I2C, SPI, UART)

Detailed specifications for synchronous and asynchronous serial communication.

## I2C (Inter-Integrated Circuit)

### Physical Layer
- **2-wire**: SDA (data), SCL (clock)
- **Voltage**: 3.3V or 5V (level shifters if mixing)
- **Pull-ups**: Required on both lines (2.2K-10K typical)
- **Multi-master**: Supports multiple masters (with arbitration)
- **Max devices**: 128 (7-bit addressing) or 1024 (10-bit)

### Timing Specifications

| Speed Mode | Frequency | Rise Time | Fall Time |
|------------|-----------|-----------|-----------|
| Standard | 100 KHz | <1000 ns | <300 ns |
| Fast | 400 KHz | <300 ns | <300 ns |
| Fast Plus | 1 MHz | <120 ns | <120 ns |
| High Speed | 3.4 MHz | <80 ns | <80 ns |

### Transaction Protocol

```
START → ADDRESS + R/W → ACK → DATA → ACK → ... → STOP

START:  SDA falling while SCL high
STOP:   SDA rising while SCL high
ACK:    SDA low during clock pulse
NACK:   SDA high during clock pulse
```

### Write Transaction
```
Master: START
Master: [Address 0x68] [Write=0]
Slave:  ACK
Master: [Register 0x1A]
Slave:  ACK
Master: [Data 0x05]
Slave:  ACK
Master: STOP
```

### Read Transaction with Repeated Start
```
Master: START
Master: [Address 0x68] [Write=0]
Slave:  ACK
Master: [Register 0x3B]
Slave:  ACK
Master: REPEATED START
Master: [Address 0x68] [Read=1]
Slave:  ACK
Slave:  [Data 0x12]
Master: ACK
Slave:  [Data 0x34]
Master: NACK  (last byte)
Master: STOP
```

### Arbitration (Multi-Master)
```
Master A wants to transmit: SDA=0
Master B wants to transmit: SDA=1

Master B detects conflict (reads SDA=0 when it drove SDA=1)
Master B backs off, Master A continues
```

### Clock Stretching
Slave can hold SCL low to pause master:
```
Master: (tries to raise SCL)
Slave:  (holds SCL low) - "I'm not ready"
Master: (waits for SCL to go high)
Slave:  (releases SCL when ready)
```

**When used**:
- Slow sensors need processing time
- EEPROM during write cycles
- Displays during frame updates

### Common Issues

**No ACK (NACK)**:
- Wrong device address
- Device not powered
- Device busy (check if initialization complete)
- Pull-up resistors missing/wrong value

**Bus Stuck**:
```c
// Recover stuck I2C bus
void i2c_recover() {
    // Manually toggle SCL to clear stuck SDA
    for (int i = 0; i < 9; i++) {
        gpio_set_level(SCL_PIN, 0);
        delay_us(5);
        gpio_set_level(SCL_PIN, 1);
        delay_us(5);
    }
    // Send STOP
    gpio_set_level(SDA_PIN, 0);
    delay_us(5);
    gpio_set_level(SDA_PIN, 1);
}
```

---

## SPI (Serial Peripheral Interface)

### Physical Layer
- **4-wire**: MOSI, MISO, SCK, CS
- **Full-duplex**: Simultaneous send and receive
- **Single master**: One master, multiple slaves
- **Chip Select**: One CS per slave (active low)

### SPI Modes (CPOL, CPHA)

```
Mode | CPOL | CPHA | Idle | Sample Edge | Shift Edge
-----|------|------|------|-------------|------------
0    | 0    | 0    | Low  | Rising      | Falling
1    | 0    | 1    | Low  | Falling     | Rising
2    | 1    | 0    | High | Falling     | Rising
3    | 1    | 1    | High | Rising      | Falling

CPOL: Clock polarity (idle state)
CPHA: Clock phase (data capture edge)
```

### Timing Diagram (Mode 0)
```
CS   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_______________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾

SCK  _______|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_______
            ↑ ↓ ↑ ↓ ↑ ↓ ↑ ↓ ↑ ↓ ↑ ↓ ↑ ↓ ↑
MOSI -------<D7><D6><D5><D4><D3><D2><D1><D0>------
MISO -------<D7><D6><D5><D4><D3><D2><D1><D0>------

↑ Sample (rising edge)
↓ Shift  (falling edge)
```

### Transaction Example
```c
// Select slave
gpio_set_level(CS_PIN, 0);

// Write command (0x2C = memory write)
spi_transfer(0x2C);

// Write data
uint8_t data[] = {0x12, 0x34, 0x56, 0x78};
spi_transfer_bulk(data, sizeof(data));

// Deselect slave
gpio_set_level(CS_PIN, 1);
```

### DMA Optimization
```c
// Without DMA: CPU waits for each byte
for (int i = 0; i < 76800; i++) {
    spi_transfer(buffer[i]);  // 76KB @ 40MHz = ~15ms
}

// With DMA: CPU free during transfer
spi_dma_transfer(buffer, 76800);  // 76KB @ 40MHz = ~15ms
do_other_work();  // CPU can do work meanwhile
spi_dma_wait_complete();
```

### Multi-Slave Configuration

**Separate CS per device**:
```
Master                Slave 1 (Display)
  MOSI ────────────────→ MOSI
  MISO ←───────────────── MISO
  SCK  ────────────────→ SCK
  CS1  ────────────────→ CS

                        Slave 2 (SD Card)
  MOSI ────────────────→ MOSI
  MISO ←───────────────── MISO
  SCK  ────────────────→ SCK
  CS2  ────────────────→ CS
```

**Daisy Chain** (rare, specific devices):
```
Master      Slave 1        Slave 2
  MOSI ────→ DIN   DOUT ──→ DIN   DOUT
  SCK  ────→ CLK          → CLK
  CS   ────→ CS           → CS
```

### Common Issues

**Garbled Data**:
- Wrong SPI mode (check CPOL/CPHA in datasheet)
- Clock too fast for slave
- MISO/MOSI swapped
- Level shifter causing phase issues

**No Response**:
- CS not asserted (check active low/high)
- CS timing violation (setup/hold time)
- Device needs initialization sequence first

---

## UART (Universal Asynchronous Receiver/Transmitter)

### Physical Layer
- **2-wire**: TX, RX (plus GND)
- **Asynchronous**: No shared clock
- **Point-to-point**: One-to-one connection
- **Optional**: RTS/CTS for hardware flow control

### Frame Format
```
IDLE | START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | PARITY | STOP | IDLE
     |   0   | Data Bits (LSB first)    |   ?    | 1/2  |

START:  Always 0
DATA:   5, 6, 7, or 8 bits
PARITY: Optional (even, odd, none)
STOP:   1, 1.5, or 2 bits (always 1)
```

### Common Configurations

| Name | Data | Parity | Stop | Example Use |
|------|------|--------|------|-------------|
| 8N1 | 8 | None | 1 | Most common (default) |
| 8E1 | 8 | Even | 1 | Error detection |
| 7E1 | 7 | Even | 1 | ASCII with parity |
| 8N2 | 8 | None | 2 | Slow devices |

### Baud Rate Timing
```
9600 baud = 9600 bits/second
Bit time = 1/9600 = 104.17 μs

115200 baud = 115200 bits/second
Bit time = 1/115200 = 8.68 μs
```

**Tolerance**: ±2% for reliable communication

### Flow Control

**None (No handshaking)**:
```
TX ────→ RX
RX ←──── TX
```
Use when: Receiver always keeps up with sender

**Software (XON/XOFF)**:
```
Sender: [DATA] [DATA] [DATA] ...
Receiver: (buffer 80% full) → send XOFF (0x13)
Sender: (stop sending)
Receiver: (buffer 20% full) → send XON (0x11)
Sender: (resume sending)
```

**Hardware (RTS/CTS)**:
```
Master              Slave
  TX ──────────────→ RX
  RX ←─────────────── TX
  RTS ─────────────→ CTS
  CTS ←────────────── RTS

Slave: RTS=0 (ready to receive)
Master: (can send data)
Slave: RTS=1 (buffer full, stop)
Master: (must wait)
```

### Ring Buffer Implementation
```c
#define BUFFER_SIZE 256

typedef struct {
    uint8_t buffer[BUFFER_SIZE];
    uint16_t head;
    uint16_t tail;
} ring_buffer_t;

void buffer_write(ring_buffer_t* rb, uint8_t data) {
    uint16_t next = (rb->head + 1) % BUFFER_SIZE;
    if (next != rb->tail) {  // Not full
        rb->buffer[rb->head] = data;
        rb->head = next;
    }
}

uint8_t buffer_read(ring_buffer_t* rb) {
    if (rb->head == rb->tail) return 0;  // Empty
    uint8_t data = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) % BUFFER_SIZE;
    return data;
}
```

### AT Command State Machine
```
State: IDLE
  ↓ (send "AT\r\n")
State: WAITING_OK
  ↓ (receive "OK\r\n")
State: IDLE

State: IDLE
  ↓ (send "AT+CMD=value\r\n")
State: WAITING_RESPONSE
  ↓ (receive "+CMD:response\r\n")
State: WAITING_OK
  ↓ (receive "OK\r\n")
State: IDLE
```

### Common Issues

**Garbage Characters**:
- Wrong baud rate
- Baud rate tolerance exceeded
- Incorrect data/parity/stop bits
- Ground not shared

**Missing Characters**:
- No flow control, buffer overflow
- Baud rate too high for receiver
- Processing too slow

**No Response**:
- TX/RX swapped
- Voltage level mismatch (3.3V vs 5V)
- Wrong line terminator (CR vs LF vs CRLF)

### RS-232 vs TTL Levels

**TTL (3.3V or 5V)**:
```
Logic 1: +3.3V or +5V
Logic 0: 0V (GND)
```

**RS-232**:
```
Logic 1 (mark):  -3V to -15V
Logic 0 (space): +3V to +15V
```

**Conversion**: Use MAX3232 or similar level shifter

### Debugging
```bash
# Monitor serial port (Linux)
screen /dev/ttyUSB0 115200

# Send command and see response
echo "AT" > /dev/ttyUSB0
cat /dev/ttyUSB0

# Hex dump (see exact bytes)
xxd /dev/ttyUSB0
```
