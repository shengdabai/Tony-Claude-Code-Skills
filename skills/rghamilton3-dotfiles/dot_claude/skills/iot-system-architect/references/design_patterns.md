# IoT Design Patterns Catalog

This document provides a comprehensive catalog of design patterns for IoT systems, including implementation examples, trade-offs, and anti-patterns to avoid.

## Communication Patterns

### 1. Publish-Subscribe (Pub/Sub)

**Intent**: Decouple message producers from consumers through an intermediary message broker.

**When to Use**:
- Multiple devices need to react to the same event
- Device count is dynamic (devices can join/leave)
- One-to-many or many-to-many communication needed

**Implementation with MQTT**:

```python
# Publisher (e.g., Presto timer)
import paho.mqtt.client as mqtt

client = mqtt.Client()
client.connect("broker.local", 1883)

# Publish timer state change
state = {"status": "running", "elapsed": 1500, "mode": "work"}
client.publish("argus/presto/timer/state", json.dumps(state), qos=1, retain=True)
```

```python
# Subscriber (e.g., T-Embed display)
def on_message(client, userdata, message):
    state = json.loads(message.payload)
    update_display(state)

client = mqtt.Client()
client.on_message = on_message
client.connect("broker.local", 1883)
client.subscribe("argus/presto/timer/state", qos=1)
client.loop_forever()
```

**Trade-offs**:
- ✅ Loose coupling between devices
- ✅ Scalable to many subscribers
- ✅ Late-joining devices can catch up (with retained messages)
- ❌ Requires message broker infrastructure
- ❌ No guaranteed delivery without QoS 1+
- ❌ Debugging message flow can be complex

**Anti-Pattern**: Direct device-to-device HTTP calls in a pub/sub system
- Creates tight coupling
- Requires hardcoded IP addresses
- Fails when devices are offline

---

### 2. Request-Reply

**Intent**: Synchronous communication where one device requests data from another and waits for a response.

**When to Use**:
- Device configuration queries
- Immediate acknowledgment required
- Transactional operations (must complete or rollback)

**Implementation with MQTT**:

```python
# Requester
import uuid

request_id = str(uuid.uuid4())
reply_topic = f"argus/presto/config/reply/{request_id}"

def on_reply(client, userdata, message):
    config = json.loads(message.payload)
    print(f"Received config: {config}")

client.subscribe(reply_topic)
client.on_message = on_reply

request = {"request_id": request_id, "reply_to": reply_topic}
client.publish("argus/hub/config/request", json.dumps(request), qos=1)

# Wait for response (with timeout)
```

```python
# Responder
def on_request(client, userdata, message):
    req = json.loads(message.payload)
    config = get_device_config()
    client.publish(req["reply_to"], json.dumps(config), qos=1)
```

**Trade-offs**:
- ✅ Clear request-response semantics
- ✅ Easy to implement timeouts
- ❌ Requester must stay online to receive response
- ❌ Doesn't scale well for many concurrent requests
- ❌ Coupling between requester and responder

**Anti-Pattern**: Synchronous blocking waits in event-driven systems
- Blocks event loop
- Can cause deadlocks
- Use async/await or callbacks instead

---

### 3. Message Queue

**Intent**: Buffer messages for asynchronous processing with delivery guarantees.

**When to Use**:
- Processing can be delayed (non-real-time)
- Need to handle bursts of messages
- Want to guarantee message delivery even if consumer is offline

**Implementation with Redis Streams**:

```python
import redis

r = redis.Redis()

# Producer
message = {"device": "presto", "event": "timer_complete", "timestamp": time.time()}
r.xadd("argus:events", message)

# Consumer with consumer group
while True:
    messages = r.xreadgroup("analytics", "worker1", {"argus:events": ">"}, count=10)
    for stream, msg_list in messages:
        for msg_id, msg_data in msg_list:
            process_event(msg_data)
            r.xack("argus:events", "analytics", msg_id)
```

**Trade-offs**:
- ✅ Decouples producers from consumers
- ✅ Handles variable processing speeds
- ✅ Provides delivery guarantees
- ✅ Supports multiple consumer groups
- ❌ Adds latency (not suitable for real-time)
- ❌ Requires additional infrastructure
- ❌ Message ordering may not be preserved across partitions

---

## State Management Patterns

### 4. State Machine

**Intent**: Model device behavior as a set of states and transitions triggered by events.

**When to Use**:
- Device has distinct operational modes
- Transitions between modes have business rules
- Need to prevent invalid state transitions

**Implementation**:

```python
from enum import Enum, auto
from typing import Optional

class TimerState(Enum):
    IDLE = auto()
    RUNNING = auto()
    PAUSED = auto()
    COMPLETED = auto()

class TimerEvent(Enum):
    START = auto()
    PAUSE = auto()
    RESUME = auto()
    RESET = auto()
    COMPLETE = auto()

class TimerStateMachine:
    TRANSITIONS = {
        (TimerState.IDLE, TimerEvent.START): TimerState.RUNNING,
        (TimerState.RUNNING, TimerEvent.PAUSE): TimerState.PAUSED,
        (TimerState.RUNNING, TimerEvent.COMPLETE): TimerState.COMPLETED,
        (TimerState.PAUSED, TimerEvent.RESUME): TimerState.RUNNING,
        (TimerState.PAUSED, TimerEvent.RESET): TimerState.IDLE,
        (TimerState.COMPLETED, TimerEvent.RESET): TimerState.IDLE,
    }

    def __init__(self):
        self.state = TimerState.IDLE

    def transition(self, event: TimerEvent) -> bool:
        key = (self.state, event)
        if key in self.TRANSITIONS:
            old_state = self.state
            self.state = self.TRANSITIONS[key]
            self.publish_state_change(old_state, self.state, event)
            return True
        return False  # Invalid transition

    def publish_state_change(self, old, new, event):
        payload = {
            "previous_state": old.name,
            "current_state": new.name,
            "event": event.name,
            "timestamp": time.time()
        }
        mqtt_client.publish("argus/presto/timer/state", json.dumps(payload), retain=True)
```

**Trade-offs**:
- ✅ Prevents invalid state transitions
- ✅ Self-documenting behavior
- ✅ Easy to test
- ✅ Simplifies debugging
- ❌ Can become complex with many states
- ❌ May be overkill for simple devices

**Anti-Pattern**: Spaghetti conditionals instead of state machines
```python
# DON'T DO THIS
if running and button_pressed:
    if paused:
        resume()
    else:
        pause()
elif not running:
    start()
# ... dozens of nested conditions
```

---

### 5. Event Sourcing

**Intent**: Store all state changes as a sequence of immutable events rather than just current state.

**When to Use**:
- Need audit trail of all changes
- Want to replay history for debugging
- Supporting time-travel queries
- Synchronizing state across devices

**Implementation**:

```python
# Event store
class EventStore:
    def __init__(self):
        self.events = []

    def append(self, event):
        event["id"] = len(self.events)
        event["timestamp"] = time.time()
        self.events.append(event)
        self.publish_event(event)

    def get_events(self, after_id=0):
        return [e for e in self.events if e["id"] > after_id]

    def rebuild_state(self, up_to_id=None):
        state = TimerState.IDLE
        elapsed = 0

        events = self.events if up_to_id is None else self.events[:up_to_id+1]
        for event in events:
            if event["type"] == "STARTED":
                state = TimerState.RUNNING
                elapsed = 0
            elif event["type"] == "PAUSED":
                state = TimerState.PAUSED
                elapsed = event["elapsed"]
            # ... handle other events

        return {"state": state, "elapsed": elapsed}

# Usage
store = EventStore()
store.append({"type": "STARTED", "duration": 1500})
store.append({"type": "PAUSED", "elapsed": 750})
store.append({"type": "RESUMED"})

# Rebuild state at any point in time
state_at_event_1 = store.rebuild_state(up_to_id=1)
```

**Trade-offs**:
- ✅ Complete audit trail
- ✅ Can replay history for debugging
- ✅ Simplifies state synchronization
- ✅ Enables temporal queries
- ❌ Storage overhead
- ❌ Rebuilding state can be slow
- ❌ Schema evolution is challenging

---

### 6. CRDT (Conflict-Free Replicated Data Type)

**Intent**: Enable multiple devices to modify the same data independently and merge changes without conflicts.

**When to Use**:
- Multiple devices can modify same state
- Network partitions are common
- Eventual consistency is acceptable

**Implementation (G-Counter)**:

```python
class GCounter:
    """Grow-only counter that merges without conflicts"""
    def __init__(self, device_id):
        self.device_id = device_id
        self.counts = {}  # device_id -> count

    def increment(self):
        self.counts[self.device_id] = self.counts.get(self.device_id, 0) + 1

    def value(self):
        return sum(self.counts.values())

    def merge(self, other):
        for device_id, count in other.counts.items():
            self.counts[device_id] = max(
                self.counts.get(device_id, 0),
                count
            )

# Device 1
counter1 = GCounter("presto")
counter1.increment()
counter1.increment()

# Device 2
counter2 = GCounter("tembed")
counter2.increment()

# Merge counts from both devices
counter1.merge(counter2)
print(counter1.value())  # 3 (2 from presto + 1 from tembed)
```

**Trade-offs**:
- ✅ No conflicts during merge
- ✅ Works offline
- ✅ Eventually consistent
- ❌ Limited operations (e.g., can't decrement G-Counter)
- ❌ Memory overhead (stores per-device state)
- ❌ Complex to implement for arbitrary data

---

## Resilience Patterns

### 7. Circuit Breaker

**Intent**: Prevent cascading failures by stopping requests to a failing service.

**When to Use**:
- Calling external services that may fail
- Want to fail fast instead of waiting for timeouts
- Need to give failing services time to recover

**Implementation**:

```python
from enum import Enum
import time

class CircuitState(Enum):
    CLOSED = "closed"    # Normal operation
    OPEN = "open"        # Blocking requests
    HALF_OPEN = "half_open"  # Testing if service recovered

class CircuitBreaker:
    def __init__(self, failure_threshold=5, timeout=60):
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.last_failure_time = None

    def call(self, func, *args, **kwargs):
        if self.state == CircuitState.OPEN:
            if time.time() - self.last_failure_time > self.timeout:
                self.state = CircuitState.HALF_OPEN
            else:
                raise Exception("Circuit breaker is OPEN")

        try:
            result = func(*args, **kwargs)
            if self.state == CircuitState.HALF_OPEN:
                self.state = CircuitState.CLOSED
                self.failure_count = 0
            return result
        except Exception as e:
            self.failure_count += 1
            self.last_failure_time = time.time()

            if self.failure_count >= self.failure_threshold:
                self.state = CircuitState.OPEN

            raise e

# Usage
mqtt_breaker = CircuitBreaker(failure_threshold=3, timeout=30)

def publish_with_breaker(topic, payload):
    mqtt_breaker.call(mqtt_client.publish, topic, payload)
```

**Trade-offs**:
- ✅ Fails fast when service is down
- ✅ Prevents resource exhaustion
- ✅ Gives failing services time to recover
- ❌ May reject valid requests during recovery
- ❌ Requires tuning thresholds and timeouts

---

### 8. Retry with Exponential Backoff

**Intent**: Retry failed operations with increasing delays to avoid overwhelming recovering services.

**When to Use**:
- Transient failures are common (network glitches)
- Want to retry automatically without manual intervention
- Need to avoid retry storms

**Implementation**:

```python
import time
import random

def exponential_backoff_retry(func, max_retries=5, base_delay=1, max_delay=60):
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise e

            # Calculate delay with jitter
            delay = min(base_delay * (2 ** attempt), max_delay)
            jitter = random.uniform(0, delay * 0.1)
            total_delay = delay + jitter

            print(f"Attempt {attempt + 1} failed, retrying in {total_delay:.2f}s")
            time.sleep(total_delay)

# Usage
def connect_to_broker():
    exponential_backoff_retry(
        lambda: mqtt_client.connect("broker.local", 1883),
        max_retries=5
    )
```

**Trade-offs**:
- ✅ Handles transient failures gracefully
- ✅ Reduces load on recovering services
- ✅ Jitter prevents thundering herd
- ❌ Can delay error detection
- ❌ May retry non-retryable errors (need to distinguish)

---

## Data Patterns

### 9. Time-Series Windowing

**Intent**: Aggregate sensor data over time windows for analysis and storage efficiency.

**When to Use**:
- High-frequency sensor data
- Storage/bandwidth constraints
- Need statistical summaries (avg, min, max)

**Implementation**:

```python
from collections import deque
import time

class TimeSeriesWindow:
    def __init__(self, window_size_seconds=60):
        self.window_size = window_size_seconds
        self.data = deque()

    def add(self, value):
        now = time.time()
        self.data.append((now, value))

        # Remove old data outside window
        cutoff = now - self.window_size
        while self.data and self.data[0][0] < cutoff:
            self.data.popleft()

    def get_stats(self):
        if not self.data:
            return None

        values = [v for _, v in self.data]
        return {
            "count": len(values),
            "min": min(values),
            "max": max(values),
            "avg": sum(values) / len(values),
            "first": values[0],
            "last": values[-1]
        }

# Usage - collect temperature readings
temp_window = TimeSeriesWindow(window_size_seconds=300)  # 5 minute window

# Every second
temp_window.add(read_temperature())

# Every 5 minutes, publish aggregated stats
if time.time() % 300 < 1:
    stats = temp_window.get_stats()
    mqtt_client.publish("sensors/temperature/stats", json.dumps(stats))
```

**Trade-offs**:
- ✅ Reduces storage and bandwidth
- ✅ Provides statistical insights
- ✅ Smooths noisy sensor data
- ❌ Loses individual data points
- ❌ Introduces latency (waiting for window to fill)

---

## Anti-Patterns to Avoid

### 1. God Object

**Problem**: Single device or service handles too many responsibilities.

**Example**: Hub that does MQTT brokering, AI inference, database, web server, and device control all in one.

**Solution**: Apply microservices pattern, separate concerns.

---

### 2. Chatty Communication

**Problem**: Devices send many small messages instead of batching.

**Example**: Sending individual sensor readings every 100ms instead of batching 10 readings.

**Solution**: Batch messages, use time-series windowing.

---

### 3. Hardcoded Configuration

**Problem**: Device IPs, broker addresses, and credentials in source code.

**Example**:
```python
# DON'T DO THIS
BROKER_IP = "192.168.1.100"
DEVICE_ID = "presto-001"
```

**Solution**: Use configuration files, environment variables, or service discovery.

---

### 4. Synchronous Everything

**Problem**: Blocking operations in event-driven systems.

**Example**:
```python
# DON'T DO THIS in an event loop
response = requests.get("http://api.example.com/data", timeout=30)
```

**Solution**: Use async/await, callbacks, or message queues.

---

### 5. No Graceful Degradation

**Problem**: System completely fails when one component is unavailable.

**Example**: Timer stops working when MQTT broker is down.

**Solution**: Design devices to operate autonomously, queue messages during outages.

---

## Pattern Selection Guide

| Scenario | Recommended Pattern |
|----------|-------------------|
| Device-to-device event broadcast | Publish-Subscribe |
| Request device configuration | Request-Reply |
| Process analytics offline | Message Queue |
| Device with multiple modes | State Machine |
| Audit trail requirement | Event Sourcing |
| Multi-device counter | CRDT (G-Counter) |
| Unreliable external service | Circuit Breaker |
| Network glitches | Retry with Exponential Backoff |
| High-frequency sensor data | Time-Series Windowing |

## Further Reading

- *Enterprise Integration Patterns* by Hohpe and Woolf
- *Designing Data-Intensive Applications* by Martin Kleppmann
- *Release It!* by Michael Nygard (resilience patterns)
- MQTT specification v5.0
- CRDTs research papers by Marc Shapiro
