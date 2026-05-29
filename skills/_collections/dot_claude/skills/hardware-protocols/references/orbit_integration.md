# Orbit System Integration Reference

This document provides detailed integration patterns, topic schemas, and message formats for the Orbit multi-device embedded system.

## Device Roles

### Jetson Nano (Central Hub)
- **Role**: MQTT broker, pattern analyzer, coordinator
- **Services**: Mosquitto broker (TCP + WebSocket), AI/ML processing
- **Communication**: WiFi network gateway
- **Topics**: Subscribes to all `orbit/#`, publishes state and alerts

### Pimoroni Presto (RP2350)
- **Role**: Primary timer display, BLE gateway
- **Hardware**: SPI display (ST7789), BLE radio
- **Communication**: WiFi → MQTT broker, BLE → Android app
- **Topics**: Subscribes to `orbit/timer/#`, `orbit/alert/#`, publishes status

### LILYGO T-Embed (ESP32)
- **Role**: Portable timer display
- **Hardware**: SPI display (ST7789), I2C sensors, battery
- **Communication**: WiFi → MQTT broker
- **Topics**: Subscribes to `orbit/timer/#`, `orbit/alert/#`, publishes battery/status

### Stream Deck Neo
- **Role**: Timer control interface
- **Hardware**: LCD buttons, USB power
- **Communication**: WebSocket MQTT (port 9001)
- **Topics**: Publishes to `orbit/timer/control/#`, subscribes to `orbit/timer/state/#`

### Android App
- **Role**: Mobile notifications, configuration
- **Hardware**: Smartphone
- **Communication**: BLE → Presto
- **Topics**: N/A (uses BLE GATT instead of MQTT)

## Topic Hierarchy

```
orbit/
├── timer/
│   ├── state/
│   │   └── current              [retained] Current timer state (all devices)
│   ├── control/
│   │   ├── start                Command: Start timer
│   │   ├── pause                Command: Pause timer
│   │   ├── resume               Command: Resume timer
│   │   └── reset                Command: Reset timer
│   └── config/
│       └── presets              [retained] Timer duration presets
├── device/
│   ├── presto/
│   │   ├── status               [retained] Device online/offline
│   │   ├── rssi                 WiFi signal strength
│   │   └── ack                  Command acknowledgment
│   ├── tembed/
│   │   ├── status               [retained] Device online/offline
│   │   ├── battery              Battery percentage
│   │   ├── rssi                 WiFi signal strength
│   │   └── ack                  Command acknowledgment
│   └── streamdeck/
│       ├── status               [retained] Plugin online/offline
│       └── button/{id}/state    Button visual state
├── alert/
│   ├── visual/
│   │   ├── all                  Alert to all devices
│   │   ├── presto               Alert to specific device
│   │   └── tembed               Alert to specific device
│   └── priority/
│       ├── ambient              Low-priority ambient notification
│       ├── gentle               Gentle attention request
│       ├── standard             Normal alert
│       ├── urgent               High-priority alert
│       └── critical             Emergency alert
└── metrics/
    ├── focus/
    │   └── {timestamp}          Focus quality metrics
    └── usage/
        └── {timestamp}          Device usage statistics
```

## Message Schemas

### Timer State (`orbit/timer/state/current`)

**QoS**: 1 (At least once)
**Retained**: Yes
**Format**: JSON

```json
{
  "running": true,
  "mode": "pomodoro",
  "remaining": 1500,
  "total": 1500,
  "started_at": 1234567890,
  "paused_at": null
}
```

**Fields**:
- `running` (boolean): Timer is actively counting down
- `mode` (string): Timer mode ("pomodoro", "break", "custom")
- `remaining` (uint32): Seconds remaining
- `total` (uint32): Total duration in seconds
- `started_at` (uint32): Unix timestamp when started
- `paused_at` (uint32|null): Unix timestamp when paused, or null

### Timer Control Commands

**QoS**: 1 (At least once)
**Retained**: No

#### Start (`orbit/timer/control/start`)
```json
{
  "duration": 1500,
  "mode": "pomodoro"
}
```

#### Pause (`orbit/timer/control/pause`)
```json
{
  "timestamp": 1234567890
}
```

#### Resume (`orbit/timer/control/resume`)
```json
{
  "timestamp": 1234567890
}
```

#### Reset (`orbit/timer/control/reset`)
```json
{
  "timestamp": 1234567890
}
```

### Device Status (`orbit/device/{device_id}/status`)

**QoS**: 1 (At least once)
**Retained**: Yes
**Format**: JSON

```json
{
  "online": true,
  "timestamp": 1234567890,
  "version": "1.0.0",
  "uptime": 86400
}
```

**Last Will Testament**: Same format with `"online": false`

### Battery Level (`orbit/device/tembed/battery`)

**QoS**: 0 (At most once) - frequent updates
**Retained**: No
**Format**: JSON

```json
{
  "percentage": 85,
  "voltage": 3.95,
  "charging": false,
  "timestamp": 1234567890
}
```

### Visual Alert (`orbit/alert/visual/{target}`)

**QoS**: 1 (At least once)
**Retained**: No
**Format**: JSON

```json
{
  "priority": "standard",
  "pattern": "pulse",
  "color": "#FF6B6B",
  "duration_ms": 3000,
  "repeat": 1
}
```

**Fields**:
- `priority` (string): "ambient", "gentle", "standard", "urgent", "critical"
- `pattern` (string): "solid", "pulse", "flash", "breathe", "wave"
- `color` (string): Hex color code for display
- `duration_ms` (uint32): How long to show alert
- `repeat` (uint8): Number of times to repeat pattern

## Communication Patterns

### Pattern 1: Timer Start from Stream Deck

```
┌─────────────┐                ┌─────────────┐                ┌──────────────┐
│ Stream Deck │                │   Jetson    │                │ Presto/T-Emb │
└──────┬──────┘                └──────┬──────┘                └──────┬───────┘
       │                              │                               │
       │ PUB orbit/timer/control/start│                               │
       │ {"duration": 1500, ...}      │                               │
       ├─────────────────────────────>│                               │
       │                              │                               │
       │                              │ (Process command)             │
       │                              │                               │
       │                              │ PUB orbit/timer/state/current │
       │                              │ (retained, QoS 1)             │
       │                              ├──────────────────────────────>│
       │                              │                               │
       │ SUB orbit/timer/state/current│                               │ (Display
       │<─────────────────────────────┤                               │  timer)
       │                              │                               │
       │ (Update button display)      │                               │
       │                              │                               │
```

### Pattern 2: Device Connection with LWT

```
┌─────────────┐                ┌─────────────┐
│   Device    │                │   Broker    │
└──────┬──────┘                └──────┬──────┘
       │                              │
       │ CONNECT with LWT:            │
       │   topic: orbit/device/X/status│
       │   payload: {"online": false} │
       ├─────────────────────────────>│
       │                              │
       │                        CONNACK│
       │<─────────────────────────────┤
       │                              │
       │ PUB orbit/device/X/status    │
       │ {"online": true} (retained)  │
       ├─────────────────────────────>│
       │                              │
       │ ... normal operation ...     │
       │                              │
       │ (Unexpected disconnect)      │
       │ ╳                            │
       │                              │
       │                              │ PUB orbit/device/X/status
       │                              │ {"online": false} (LWT)
       │                              │ (Automatic)
       │                              │
```

### Pattern 3: Battery Monitoring

```
┌─────────────┐                ┌─────────────┐
│   T-Embed   │                │   Jetson    │
└──────┬──────┘                └──────┬──────┘
       │                              │
       │ (Every 60 seconds)           │
       │                              │
       │ I2C read battery gauge       │
       │                              │
       │ PUB orbit/device/tembed/battery│
       │ {"percentage": 85, ...}      │
       ├─────────────────────────────>│
       │                              │
       │                              │ (Check threshold)
       │                              │
       │                              │ (If < 20%)
       │                              │
       │      PUB orbit/alert/visual/tembed│
       │      {"priority": "standard",│
       │       "pattern": "pulse",    │
       │       "color": "#FFD700"}    │
       │<─────────────────────────────┤
       │                              │
       │ (Display low battery warning)│
       │                              │
```

## WebSocket MQTT Configuration

Stream Deck plugin requires WebSocket MQTT connection:

```typescript
import * as mqtt from 'mqtt';

const client = mqtt.connect('ws://192.168.1.100:9001', {
    clientId: `streamdeck_${Date.now()}`,
    clean: false,  // Persistent session
    reconnectPeriod: 5000,
    will: {
        topic: 'orbit/device/streamdeck/status',
        payload: JSON.stringify({ online: false }),
        qos: 1,
        retain: true
    }
});

client.on('connect', () => {
    // Publish online status
    client.publish(
        'orbit/device/streamdeck/status',
        JSON.stringify({ online: true, timestamp: Date.now() }),
        { qos: 1, retain: true }
    );

    // Subscribe to topics
    client.subscribe('orbit/timer/state/current', { qos: 1 });
});
```

## BLE Integration (Presto ↔ Android)

Presto acts as BLE GATT server, Android app as client:

### Service: Timer Control
**UUID**: `12345678-1234-5678-1234-56789abcdef0`

#### Characteristic: State
**UUID**: `12345678-1234-5678-1234-56789abcdef1`
**Properties**: Read, Notify
**Format**: JSON string (same as MQTT timer state)

#### Characteristic: Command
**UUID**: `12345678-1234-5678-1234-56789abcdef2`
**Properties**: Write
**Format**: JSON string (same as MQTT timer commands)

#### Characteristic: Battery
**UUID**: `00002a19-0000-1000-8000-00805f9b34fb` (Standard)
**Properties**: Read, Notify
**Format**: uint8 (percentage)

### Android App Flow
```
1. Scan for "Orbit-Presto" BLE device
2. Connect to GATT server
3. Discover Timer Control service
4. Enable notifications on State characteristic
5. Read current timer state
6. Subscribe to state updates
7. Write commands to Command characteristic
8. (Presto relays BLE commands to MQTT)
```

## Error Handling

### MQTT Connection Lost
1. Device detects disconnect (no CONNACK)
2. Queue messages locally (max 100 messages)
3. Attempt reconnect with exponential backoff (1s, 2s, 4s, ... 60s)
4. On reconnect, re-subscribe to topics
5. Publish queued messages

### Broker Unavailable (Jetson Down)
1. Devices continue local timer operation
2. Display cached state
3. Visual indicator: connection status LED/icon
4. Periodic reconnection attempts
5. Sync state when broker returns

### Message Delivery Failure (QoS 1)
1. Client retransmits until PUBACK received
2. Broker queues if client offline (persistent session)
3. Log delivery failures
4. Alert if retries exhausted (rare with QoS 1)

## Performance Targets

### Latency
- **MQTT publish to display update**: <100ms typical
- **Stream Deck button press to all devices**: <150ms typical
- **BLE notification to Android**: <50ms typical

### Update Rates
- **Timer tick**: 1 Hz (every second)
- **Battery level**: 0.017 Hz (every 60 seconds)
- **WiFi RSSI**: 0.1 Hz (every 10 seconds)
- **Stream Deck button state**: On change

### Network Load
- **Idle state**: <1 KB/s per device
- **Timer active**: ~2 KB/s per device (1 Hz updates)
- **Burst (visual alert)**: ~5 KB/s brief spike

## Security Considerations

### Phase 1: Local Network Only
- No authentication required
- Trust all devices on local network
- Use allow_anonymous = true in Mosquitto

### Phase 2: Basic Authentication (Optional)
- Username/password for MQTT
- ACL for topic permissions
- Separate credentials per device

### Phase 3: TLS/SSL (Future)
- Certificate-based authentication
- Encrypted MQTT transport
- Secure WebSocket (wss://)

## Debugging Tools

### Monitor All MQTT Traffic
```bash
mosquitto_sub -h localhost -t '#' -v
```

### Test Publish
```bash
mosquitto_pub -h localhost -t 'orbit/timer/control/start' \
    -m '{"duration": 1500, "mode": "pomodoro"}'
```

### WebSocket Test
```bash
npm install -g mqtt
mqtt pub -h ws://192.168.1.100:9001 -t test -m "hello"
```

### BLE Scanner (Android)
Use "nRF Connect" app to:
- Scan for Orbit devices
- Inspect GATT services
- Read/write characteristics
- Monitor notifications
