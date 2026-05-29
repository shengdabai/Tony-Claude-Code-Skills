# Argus System Architecture

## System Overview

Argus is a distributed IoT system for productivity tracking using multiple specialized devices coordinated through MQTT messaging. The system implements a hub-and-spoke topology with the Jetson Nano serving as the central intelligence hub.

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│         Android Device (Pixel Pro)          │
│     [Notification Bridge & Control]         │
│                                             │
│  - Receives notifications via BLE           │
│  - User control interface                   │
│  - Background service for bridging          │
└────────────┬──────────────┬─────────────────┘
             │ BLE          │ BLE
             ▼              ▼
    ┌──────────────┐  ┌──────────────┐
    │   Presto     │  │   T-Embed    │
    │  (Central)   │◄─┤   (Desk)     │
    │ RP2350+4"    │  │ ESP32-S3     │
    │              │  │              │
    │ - Main UI    │  │ - Desk timer │
    │ - BLE hub    │  │ - Local      │
    │ - Touchscreen│  │   display    │
    └──────┬───────┘  └──────┬───────┘
           │ MQTT            │ MQTT
           │ WiFi            │ WiFi
           └────────┬────────┘
                    ▼
         ┌─────────────────────┐
         │   Jetson Nano       │
         │ [MQTT Broker+AI]    │
         │                     │
         │ - Mosquitto broker  │
         │ - AI inference      │
         │ - State persistence │
         │ - API gateway       │
         └─────────┬───────────┘
                   │ WebSocket/USB
                   ▼
         ┌─────────────────────┐
         │   Stream Deck Neo   │
         │  [Macro Control]    │
         │                     │
         │ - Physical buttons  │
         │ - Timer controls    │
         │ - Mode switching    │
         └─────────────────────┘
```

## Component Details

### Android Device (Pixel Pro)
**Role:** Notification bridge and user interface

**Responsibilities:**
- Receive notifications from Presto via BLE
- Display system notifications to user
- Provide mobile control interface
- Background service for reliable notification delivery

**Technology Stack:**
- Flutter for cross-platform app
- BLE for device communication
- Android notification APIs
- Background service for always-on connectivity

**Communication:**
- BLE GATT client to Presto
- Optional: MQTT over WiFi for redundancy

### Presto (RP2350 + 4" Display)
**Role:** Central display and BLE hub

**Hardware:**
- Pimoroni Presto (RP2350 microcontroller)
- 4" touchscreen display (480x480)
- RGB backlight
- WiFi connectivity
- BLE 5.0

**Responsibilities:**
- Primary user interface (timer display, controls)
- BLE server for phone connectivity
- Aggregate state from all devices
- Send notifications to phone via BLE
- Touch interface for timer control

**Technology Stack:**
- MicroPython on RP2350
- PicoGraphics for display rendering
- BLE GATT server
- MQTT client (umqtt.simple)

**State Management:**
- Local timer state (runs independently)
- Cached state from other devices
- Queues MQTT messages during offline periods

### T-Embed (ESP32-S3)
**Role:** Desk timer and secondary display

**Hardware:**
- ESP32-S3 microcontroller
- Integrated display
- Rotary encoder for input
- WiFi connectivity

**Responsibilities:**
- Desk-specific timer display
- Local timer operation
- Syncs with Presto for coordinated timing
- Independent operation during network outages

**Technology Stack:**
- Arduino/ESP-IDF framework
- LVGL for graphics
- MQTT client (PubSubClient)

**Design Considerations:**
- Minimal power consumption
- Fast boot time
- Responsive encoder input
- Graceful degradation without network

### Jetson Nano
**Role:** Central intelligence hub

**Responsibilities:**
- MQTT broker (Mosquitto)
- AI inference for productivity patterns
- Data persistence (PostgreSQL/SQLite)
- RESTful API for external integrations
- WebSocket server for Stream Deck
- Historical analytics

**Technology Stack:**
- Ubuntu Linux
- Mosquitto MQTT broker
- FastAPI for REST API
- PostgreSQL for data storage
- Redis for caching
- Docker for service containerization

**Services:**
```
jetson-nano/
├── mosquitto/          - MQTT broker
├── api-gateway/        - FastAPI REST API
├── ai-service/         - ML inference
├── telemetry-service/  - Data collection
├── notification-svc/   - Notification routing
└── postgres/           - Data persistence
```

### Stream Deck Neo
**Role:** Physical macro control

**Responsibilities:**
- Physical buttons for timer control
- Start/stop/pause timer
- Mode switching (work/break)
- Quick access to presets

**Technology Stack:**
- Python SDK for Stream Deck
- WebSocket client to Jetson Nano
- Custom button layouts

**Integration:**
- Connects to Jetson Nano via USB/WebSocket
- Receives state updates via MQTT (through Jetson)
- Sends commands via WebSocket API

## Communication Patterns

### MQTT Topic Structure

```
argus/{location}/{device-type}/{device-id}/{data-type}

Examples:
argus/wrist/display/presto01/state
argus/wrist/display/presto01/command
argus/desk/timer/tembed01/state
argus/desk/timer/tembed01/telemetry
argus/hub/ai/jetson01/inference
argus/hub/broker/jetson01/status
```

### Topic Categories

**State Topics** (QoS 1, Retained):
```
argus/{location}/{device}/state
Payload: {
  "timer_running": true,
  "elapsed": 1200,
  "total": 1500,
  "mode": "work",
  "timestamp": 1234567890
}
```

**Command Topics** (QoS 1):
```
argus/{location}/{device}/command
Payload: {
  "cmd": "start_timer",
  "duration": 1500,
  "mode": "work",
  "request_id": "uuid"
}
```

**Event Topics** (QoS 1):
```
argus/{location}/{device}/event
Payload: {
  "event": "timer_complete",
  "timestamp": 1234567890,
  "data": {...}
}
```

**Telemetry Topics** (QoS 0):
```
argus/{location}/{device}/telemetry
Payload: {
  "battery": 85,
  "wifi_rssi": -45,
  "uptime": 3600,
  "memory_free": 102400
}
```

### Message Flow Examples

**Starting a Timer:**
```
1. User taps "Start" on Presto touchscreen
2. Presto publishes: argus/wrist/display/presto01/command
   {"cmd": "start_timer", "duration": 1500, "mode": "work"}
3. Presto updates local state and publishes: argus/wrist/display/presto01/state
   {"timer_running": true, "elapsed": 0, "total": 1500}
4. T-Embed receives state update via subscription to argus/+/+/+/state
5. T-Embed syncs its display to match Presto
6. Jetson Nano logs event to database
7. Stream Deck updates button LED to show running state
```

**Timer Completion:**
```
1. Presto timer reaches zero
2. Presto publishes event: argus/wrist/display/presto01/event
   {"event": "timer_complete", "mode": "work"}
3. Presto sends BLE notification to Android phone
4. Android displays system notification
5. T-Embed receives event, updates local display
6. Jetson AI service analyzes completion pattern
7. Stream Deck button changes to "Start Break" mode
```

**Offline Synchronization:**
```
1. T-Embed loses WiFi connection
2. T-Embed continues timer operation locally
3. User completes timer on T-Embed
4. T-Embed queues state update: {"elapsed": 1500, "timestamp": X}
5. T-Embed reconnects to WiFi
6. T-Embed publishes queued state updates
7. Presto receives updates, resolves any conflicts using timestamp
8. System converges to consistent state
```

## State Synchronization Strategy

### Eventually Consistent Model

The system uses an eventually consistent model where:
- Each device maintains local state
- State changes are published to MQTT
- All devices subscribe to relevant state topics
- Conflicts resolved by timestamp (Last-Write-Wins)

### Conflict Resolution

**Scenario:** Both Presto and T-Embed modify timer state while network is partitioned

```python
class StateConflictResolver:
    """Resolve state conflicts using vector clocks and LWW"""

    def resolve(self, local_state, remote_state):
        # Compare vector clocks
        if self.is_concurrent(local_state.vclock, remote_state.vclock):
            # Concurrent update: use Last-Write-Wins
            if remote_state.timestamp > local_state.timestamp:
                return remote_state
            else:
                return local_state
        elif self.happens_before(local_state.vclock, remote_state.vclock):
            # Remote state is newer
            return remote_state
        else:
            # Local state is newer
            return local_state

    def is_concurrent(self, vclock1, vclock2):
        # Check if vector clocks are concurrent
        pass

    def happens_before(self, vclock1, vclock2):
        # Check if vclock1 happened before vclock2
        pass
```

### Offline Behavior

**Presto Offline:**
- Continues timer operation
- Caches T-Embed state (last known)
- Queues notification requests
- Publishes all updates on reconnection

**T-Embed Offline:**
- Runs timer independently
- No state from Presto (acceptable)
- Publishes state on reconnection

**Jetson Nano Offline:**
- All devices continue operation
- No AI inference or data persistence
- No Stream Deck updates
- Full sync when broker returns

## Failure Modes and Recovery

### Network Partition

**Detection:**
- MQTT Last Will and Testament (LWT)
- Periodic heartbeat messages
- Connection state callbacks

**Response:**
- Continue local operation
- Display "Offline" indicator
- Queue state updates
- Attempt reconnection with exponential backoff

**Recovery:**
- Re-establish MQTT connection
- Re-subscribe to all topics
- Publish queued updates
- Resolve state conflicts
- Resume normal operation

### Device Failure

**Presto Fails:**
- T-Embed continues independently
- No BLE notifications to phone
- Stream Deck shows "Presto Offline"
- User can control via T-Embed or Stream Deck

**T-Embed Fails:**
- Presto continues normally
- No desk display
- All other functionality intact

**Jetson Nano Fails:**
- All devices lose MQTT broker
- Devices operate independently
- No cross-device synchronization
- No AI features or data persistence
- Manual restart required

### State Corruption

**Symptoms:**
- Invalid state values
- Inconsistent state across devices
- Unexpected behavior

**Detection:**
- State validation on receive
- Checksum verification
- Schema validation (JSON Schema)

**Recovery:**
- Reject invalid states
- Request full state sync
- Fall back to last known good state
- Log error for debugging

## Performance Characteristics

### Latency Targets

- Timer state update propagation: <100ms
- Command acknowledgment: <50ms
- Notification delivery: <200ms
- Display update: <16ms (60 FPS)

### Throughput

- State updates: ~10/second (per device)
- Telemetry: ~1/second (per device)
- Commands: ~5/second (burst)
- Events: ~1/minute (average)

### Resource Constraints

**Presto (RP2350):**
- RAM: 520KB (conservative usage)
- Flash: 4MB (room for OTA updates)
- Display: 60 FPS target

**T-Embed (ESP32-S3):**
- RAM: 512KB (MQTT + display buffers)
- Flash: 8MB (firmware + assets)

**Jetson Nano:**
- RAM: 4GB (multiple services)
- Storage: 32GB SD card
- CPU: Quad-core ARM (AI inference)

## Security Considerations

### Authentication
- MQTT username/password authentication
- TLS for MQTT connections (optional, local network)
- BLE pairing with PIN
- Stream Deck local connection only

### Authorization
- ACL-based topic permissions
- Read-only topics for state
- Write-only for commands
- Admin topics restricted to Jetson

### Data Privacy
- All data stays on local network
- No cloud dependencies
- Optional encryption for sensitive data
- Audit logging for debugging

## Scalability Path

### Current Scale (MVP)
- 3 devices (Presto, T-Embed, Stream Deck)
- 1 user
- Single location

### Near-Term Scale
- 5-10 devices (add more timers/displays)
- 1-2 users
- Multiple rooms

### Future Scale
- 20-50 devices
- 5-10 users (family/small team)
- Multiple locations (home, office)

### Scaling Strategy
- Horizontal scaling of MQTT broker (cluster)
- Database sharding by user/location
- Service decomposition (microservices)
- Load balancing for API gateway
- Redis for distributed caching
