# IoT Architecture Patterns

## Distributed Systems Design

### Event-Driven Architecture with MQTT Pub/Sub

Event-driven architecture is fundamental to IoT systems, enabling loose coupling and scalability.

**Core Principles:**
- **Asynchronous Communication**: Devices publish events without blocking
- **Decoupled Components**: Publishers don't know about subscribers
- **Event Flow**: Device → MQTT Broker → Subscribers
- **Scalability**: Add subscribers without changing publishers

**MQTT Implementation:**
```
Publisher (ESP32) → MQTT Broker (Mosquitto) → Subscriber (Jetson Nano)
                                            → Subscriber (Presto)
                                            → Subscriber (Mobile App)
```

**Best Practices:**
- Use retained messages for state persistence
- Implement Last Will and Testament (LWT) for device presence
- Design idempotent event handlers
- Include timestamps and message IDs in payloads

### Edge Computing vs Cloud Processing

Decision framework for processing location:

**Process at Edge When:**
- Real-time response required (<100ms)
- Bandwidth is constrained
- Privacy/security concerns with cloud transmission
- Intermittent connectivity expected
- Localized decision-making sufficient

**Process in Cloud When:**
- Complex analytics or ML models needed
- Historical data aggregation required
- Resource-intensive computations
- Cross-device coordination needed
- Long-term storage required

**Hybrid Approach (Recommended):**
```
Edge Device:
  ├── Immediate response (sensor fusion, control loops)
  ├── Data preprocessing (filtering, aggregation)
  └── Local caching during offline periods

Cloud/Central Hub:
  ├── Complex analytics and ML inference
  ├── Historical trend analysis
  ├── Device coordination and orchestration
  └── Long-term data storage
```

### Data Consistency in Distributed Environments

**Consistency Models:**

1. **Strong Consistency**: All nodes see the same data at the same time
   - Use for: Critical state (device locks, safety states)
   - Trade-off: Higher latency, reduced availability

2. **Eventual Consistency**: All nodes eventually converge to the same state
   - Use for: Sensor readings, telemetry, status updates
   - Trade-off: Temporary inconsistency acceptable

3. **Causal Consistency**: Related events maintain order
   - Use for: Command sequences, state transitions
   - Trade-off: Complexity in tracking causality

**Implementation Strategies:**
- Use message sequence numbers for ordering
- Implement conflict resolution logic (Last-Write-Wins, Merge Functions)
- Design for idempotency to handle duplicate messages
- Use vector clocks for distributed timestamps

### CAP Theorem Trade-offs for IoT

CAP Theorem: A distributed system can provide only two of three guarantees:
- **C**onsistency: All nodes see the same data
- **A**vailability: Every request receives a response
- **P**artition Tolerance: System continues despite network failures

**IoT System Choices:**

1. **CP (Consistency + Partition Tolerance)**:
   - Sacrifice: Availability during network partitions
   - Use for: Safety-critical systems, device locks
   - Example: Emergency stop commands

2. **AP (Availability + Partition Tolerance)** - Most Common for IoT:
   - Sacrifice: Strong consistency
   - Use for: Sensor telemetry, monitoring systems
   - Example: Temperature readings, device status

**Argus System Design (AP):**
- Devices continue operating during network outages
- State synchronization when connectivity restored
- Local timers run independently
- MQTT retained messages for state recovery

### Eventually Consistent Data Models

**Design Patterns:**

1. **CRDT (Conflict-Free Replicated Data Types)**:
   - G-Counter: Grow-only counter for telemetry
   - PN-Counter: Positive-negative counter for up/down counts
   - LWW-Register: Last-write-wins for simple state
   - OR-Set: Add/remove sets for device collections

2. **Event Sourcing**:
   - Store all state changes as events
   - Rebuild state by replaying events
   - Natural audit log
   - Time-travel debugging capabilities

3. **State-Based CRDTs**:
   - Devices maintain local state
   - Periodically sync entire state
   - Merge function resolves conflicts
   - No operation history needed

**Implementation Example for Device State:**
```python
class DeviceState:
    def __init__(self):
        self.lww_register = {}  # Last-Write-Wins for simple properties
        self.vclock = VectorClock()  # Track causality

    def update(self, key, value, timestamp):
        if key not in self.lww_register or timestamp > self.lww_register[key]['ts']:
            self.lww_register[key] = {'value': value, 'ts': timestamp}

    def merge(self, other_state):
        for key, data in other_state.lww_register.items():
            self.update(key, data['value'], data['ts'])
```

### Offline-First Design Patterns

**Principles:**
- Devices function without network connectivity
- Queue operations during offline periods
- Sync when connectivity restored
- Resolve conflicts with merge strategies

**Implementation Strategies:**

1. **Local State Persistence**:
   - SQLite or embedded database on device
   - Write-ahead log for uncommitted changes
   - Periodic sync with central broker

2. **Command Queue**:
   - Store commands locally if broker unavailable
   - Retry with exponential backoff
   - Deduplicate on reconnection

3. **Conflict Resolution**:
   - Timestamp-based (Last-Write-Wins)
   - Semantic merging (e.g., max/min for counters)
   - Manual resolution for critical conflicts
   - Application-specific merge functions

**Argus Offline Behavior:**
```
Presto (Central Display):
  ├── Continues timer operations locally
  ├── Caches last known device states
  ├── Queues notification requests
  └── Syncs state when MQTT reconnects

T-Embed (Desk Timer):
  ├── Runs timer independently
  ├── Stores mode changes locally
  ├── Publishes updates on reconnection
  └── Resolves conflicts with latest timestamp
```

## Communication Architecture Patterns

### Hub-and-Spoke Topology (Argus Pattern)

**Architecture:**
```
                 Jetson Nano (Hub)
                 [MQTT Broker]
                       |
        +--------------+--------------+
        |              |              |
    Presto          T-Embed      Android Phone
   (Spoke)          (Spoke)         (Spoke)
```

**Characteristics:**
- Central broker coordinates all communication
- Devices don't communicate peer-to-peer
- Hub provides services (AI, persistence, coordination)
- Spokes are lightweight clients

**Advantages:**
- Simple device implementation
- Centralized logic and state management
- Easy to add new devices
- Single point for monitoring and logging

**Disadvantages:**
- Hub is single point of failure (mitigate with offline-first design)
- All traffic passes through hub (optimize with QoS and compression)
- Hub resource constraints limit scalability (monitor and scale horizontally)

**When to Use:**
- Small to medium scale IoT deployments (<100 devices)
- Devices need coordination
- Centralized intelligence beneficial
- Reliability more important than performance

### Mesh Networking Considerations

**Use Cases for Mesh:**
- Large physical areas requiring coverage extension
- Redundant paths for reliability
- Peer-to-peer device communication needed
- No suitable location for central hub

**Trade-offs vs Hub-and-Spoke:**
- More complex device firmware
- Higher device resource requirements
- Difficult to maintain consistent state
- Better fault tolerance through redundancy

**Hybrid Approach:**
- Mesh network for physical layer (Zigbee, Thread)
- MQTT over mesh for application layer
- Hub-and-spoke for application logic

### Message Broker Design (Mosquitto Configuration)

**Configuration Principles:**

1. **Persistence**:
   ```conf
   persistence true
   persistence_location /var/lib/mosquitto/
   persistence_file mosquitto.db
   ```
   - Ensures QoS 1/2 messages survive broker restart
   - Retains last known state

2. **Security**:
   ```conf
   allow_anonymous false
   password_file /etc/mosquitto/passwd
   acl_file /etc/mosquitto/acl
   ```
   - Authenticate all clients
   - Fine-grained topic permissions

3. **Performance Tuning**:
   ```conf
   max_connections 1000
   max_queued_messages 1000
   message_size_limit 268435456
   ```
   - Balance between resource usage and capacity

4. **Monitoring**:
   ```conf
   log_dest file /var/log/mosquitto/mosquitto.log
   log_type all
   connection_messages true
   ```

**High Availability Setup:**
- Bridge configuration for broker redundancy
- Shared subscriptions for load balancing
- Retained messages for state recovery

### Topic Naming Conventions and Hierarchy

**Best Practices:**

1. **Hierarchical Structure**:
   ```
   {system}/{location}/{device-type}/{device-id}/{metric}

   Examples:
   argus/desk/timer/tEmbed01/state
   argus/wrist/display/presto01/command
   argus/hub/ai/jetson01/inference
   ```

2. **Direction Indicators**:
   ```
   {device}/status      - Device publishing state
   {device}/command     - Command to device
   {device}/telemetry   - Sensor data
   {device}/event       - Asynchronous events
   ```

3. **Wildcards for Subscriptions**:
   ```
   argus/+/timer/+/state      - All timer states
   argus/desk/#               - All desk devices
   +/+/+/+/telemetry          - All telemetry
   ```

**Anti-Patterns to Avoid:**
- Special characters in topics (/, +, #, $)
- Very deep hierarchies (>7 levels)
- Spaces or non-ASCII characters
- Versioning in topics (use payload versioning instead)

### Quality of Service (QoS) Strategy

**QoS Levels:**

- **QoS 0 (At Most Once)**: Fire and forget
  - Use for: High-frequency sensor data, non-critical telemetry
  - Example: Temperature readings every second

- **QoS 1 (At Least Once)**: Guaranteed delivery, may duplicate
  - Use for: Important events, commands
  - Example: Timer state changes, notifications
  - Requires: Idempotent handlers

- **QoS 2 (Exactly Once)**: Guaranteed once, highest overhead
  - Use for: Financial transactions, critical commands
  - Example: Billing events, safety lockouts
  - Trade-off: Higher latency and broker load

**Argus QoS Strategy:**
```
Timer State Updates:    QoS 1 (important, idempotent)
Telemetry Data:         QoS 0 (high frequency, not critical)
Commands:               QoS 1 (must arrive, deduplicated by ID)
Presence (LWT):         QoS 1 (critical for status)
```

### Message Payload Optimization

**Principles:**

1. **Use Efficient Encoding**:
   - JSON for developer friendliness (default choice)
   - MessagePack for binary efficiency (50% reduction)
   - Protocol Buffers for strict schemas (backward compatibility)
   - CBOR for IoT-optimized binary JSON

2. **Minimize Payload Size**:
   ```json
   // Bad: Verbose, repetitive
   {
     "deviceName": "T-Embed Timer",
     "currentTime": 1234567890,
     "timerState": "running",
     "remainingSeconds": 300
   }

   // Good: Compact, abbreviated
   {
     "t": 1234567890,
     "s": "run",
     "r": 300
   }
   ```

3. **Delta Updates**:
   - Send only changed fields
   - Include sequence number for ordering
   - Periodic full updates for synchronization

4. **Compression**:
   - GZIP for larger payloads (>1KB)
   - Consider bandwidth vs CPU trade-off
   - Useful for batch telemetry

**Example Optimization:**
```python
# Full state (100 bytes)
full = {"id": "t01", "state": "running", "elapsed": 45, "total": 300, "mode": "work"}

# Delta update (30 bytes)
delta = {"id": "t01", "e": 45}  # Only elapsed changed

# Binary (MessagePack): ~20 bytes
import msgpack
binary = msgpack.packb(delta)
```

