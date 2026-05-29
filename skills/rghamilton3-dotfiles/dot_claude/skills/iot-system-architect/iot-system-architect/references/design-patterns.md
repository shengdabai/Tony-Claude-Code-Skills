# Design Patterns for IoT Systems

## Observer Pattern

**Intent:** Define a one-to-many dependency between objects so that when one object changes state, all its dependents are notified and updated automatically.

**IoT Application:** MQTT subscriptions for state changes

**Structure:**
```
Subject (MQTT Topic)
    ├─> Observer 1 (Device Subscriber)
    ├─> Observer 2 (Telemetry Service)
    └─> Observer 3 (UI Dashboard)
```

**Implementation:**

```python
class TimerSubject:
    """Device that publishes state changes"""
    def __init__(self, mqtt_client, device_id):
        self.mqtt_client = mqtt_client
        self.device_id = device_id
        self.state = {}

    def set_state(self, new_state):
        self.state = new_state
        self.notify()

    def notify(self):
        topic = f"timer/{self.device_id}/state"
        payload = json.dumps(self.state)
        self.mqtt_client.publish(topic, payload, qos=1, retain=True)


class TimerObserver:
    """Service that observes timer state changes"""
    def __init__(self, mqtt_client):
        self.mqtt_client = mqtt_client
        self.mqtt_client.on_message = self.on_message
        self.mqtt_client.subscribe("timer/+/state")

    def on_message(self, client, userdata, msg):
        device_id = msg.topic.split('/')[1]
        state = json.loads(msg.payload)
        self.update(device_id, state)

    def update(self, device_id, state):
        print(f"Timer {device_id} state changed: {state}")
        # Handle state change
```

**Benefits:**
- Loose coupling between publisher and subscribers
- Open/closed principle: Add new observers without modifying subject
- Dynamic subscription management
- Broadcast communication

**Drawbacks:**
- Unexpected updates if not careful with retain flags
- Potential memory leaks if observers not unsubscribed
- No guarantee of notification order

## State Pattern

**Intent:** Allow an object to alter its behavior when its internal state changes. The object will appear to change its class.

**IoT Application:** Device operating modes (work mode, break mode, idle mode)

**Structure:**
```
Context (Timer Device)
    └─> State (current mode)
        ├─> WorkState
        ├─> BreakState
        └─> IdleState
```

**Implementation:**

```python
from abc import ABC, abstractmethod

class TimerState(ABC):
    """Abstract state"""
    @abstractmethod
    def start(self, context):
        pass

    @abstractmethod
    def pause(self, context):
        pass

    @abstractmethod
    def complete(self, context):
        pass


class WorkState(TimerState):
    """Concrete state: Working"""
    def start(self, context):
        context.duration = 25 * 60  # 25 minutes
        context.is_running = True
        context.publish_state()

    def pause(self, context):
        context.is_running = False
        context.publish_state()

    def complete(self, context):
        context.set_state(BreakState())
        context.send_notification("Work session complete!")


class BreakState(TimerState):
    """Concrete state: On break"""
    def start(self, context):
        context.duration = 5 * 60  # 5 minutes
        context.is_running = True
        context.publish_state()

    def pause(self, context):
        context.is_running = False
        context.publish_state()

    def complete(self, context):
        context.set_state(WorkState())
        context.send_notification("Break complete!")


class IdleState(TimerState):
    """Concrete state: Idle"""
    def start(self, context):
        context.set_state(WorkState())
        context.state.start(context)

    def pause(self, context):
        pass  # Already paused

    def complete(self, context):
        pass  # Nothing to complete


class TimerDevice:
    """Context: Timer device with state"""
    def __init__(self):
        self.state = IdleState()
        self.duration = 0
        self.elapsed = 0
        self.is_running = False

    def set_state(self, state):
        self.state = state

    def start(self):
        self.state.start(self)

    def pause(self):
        self.state.pause(self)

    def complete(self):
        self.state.complete(self)

    def publish_state(self):
        # Publish to MQTT
        pass

    def send_notification(self, message):
        # Send notification
        pass
```

**Benefits:**
- Localizes state-specific behavior
- Makes state transitions explicit
- Easy to add new states
- Eliminates conditional logic

**Use Cases:**
- Device operating modes
- Connection states (connected, disconnected, reconnecting)
- Protocol states (idle, authenticating, authenticated)

## Strategy Pattern

**Intent:** Define a family of algorithms, encapsulate each one, and make them interchangeable.

**IoT Application:** Different timer modes (Pomodoro, custom, countdown)

**Implementation:**

```python
class TimerStrategy(ABC):
    """Abstract strategy"""
    @abstractmethod
    def calculate_duration(self, config):
        pass

    @abstractmethod
    def on_complete(self, context):
        pass


class PomodoroStrategy(TimerStrategy):
    """Pomodoro technique: 25 min work, 5 min break"""
    def calculate_duration(self, config):
        if config.get('is_break'):
            return 5 * 60
        return 25 * 60

    def on_complete(self, context):
        context.config['is_break'] = not context.config.get('is_break', False)
        context.start_next_session()


class CustomStrategy(TimerStrategy):
    """Custom durations"""
    def calculate_duration(self, config):
        return config.get('duration', 15 * 60)

    def on_complete(self, context):
        context.stop()


class CountdownStrategy(TimerStrategy):
    """Simple countdown"""
    def calculate_duration(self, config):
        return config.get('target_time') - time.time()

    def on_complete(self, context):
        context.send_notification("Countdown complete!")
        context.stop()


class Timer:
    """Context using strategy"""
    def __init__(self, strategy: TimerStrategy):
        self.strategy = strategy
        self.config = {}

    def set_strategy(self, strategy: TimerStrategy):
        self.strategy = strategy

    def start(self):
        duration = self.strategy.calculate_duration(self.config)
        # Start timer with duration

    def on_complete(self):
        self.strategy.on_complete(self)
```

**Benefits:**
- Algorithms can vary independently from clients
- Replaces conditional logic
- Easy to add new strategies
- Testable in isolation

## Factory Pattern

**Intent:** Define an interface for creating an object, but let subclasses decide which class to instantiate.

**IoT Application:** Device-specific MQTT handlers

**Implementation:**

```python
class MQTTHandler(ABC):
    """Abstract handler"""
    @abstractmethod
    def handle_message(self, topic, payload):
        pass


class TimerHandler(MQTTHandler):
    """Handler for timer devices"""
    def handle_message(self, topic, payload):
        parts = topic.split('/')
        device_id = parts[1]
        command = parts[2]

        if command == 'start':
            self.start_timer(device_id, payload)
        elif command == 'pause':
            self.pause_timer(device_id)

    def start_timer(self, device_id, config):
        # Start timer logic
        pass

    def pause_timer(self, device_id):
        # Pause timer logic
        pass


class DisplayHandler(MQTTHandler):
    """Handler for display devices"""
    def handle_message(self, topic, payload):
        parts = topic.split('/')
        device_id = parts[1]
        command = parts[2]

        if command == 'update':
            self.update_display(device_id, payload)

    def update_display(self, device_id, content):
        # Update display logic
        pass


class SensorHandler(MQTTHandler):
    """Handler for sensor devices"""
    def handle_message(self, topic, payload):
        parts = topic.split('/')
        device_id = parts[1]
        data_type = parts[2]

        self.process_sensor_data(device_id, data_type, payload)

    def process_sensor_data(self, device_id, data_type, data):
        # Process sensor data
        pass


class HandlerFactory:
    """Factory for creating handlers"""
    _handlers = {
        'timer': TimerHandler,
        'display': DisplayHandler,
        'sensor': SensorHandler,
    }

    @classmethod
    def create_handler(cls, device_type: str) -> MQTTHandler:
        handler_class = cls._handlers.get(device_type)
        if not handler_class:
            raise ValueError(f"Unknown device type: {device_type}")
        return handler_class()

    @classmethod
    def register_handler(cls, device_type: str, handler_class):
        """Allow registration of new handler types"""
        cls._handlers[device_type] = handler_class


# Usage
def on_mqtt_message(client, userdata, msg):
    topic = msg.topic
    device_type = topic.split('/')[0]

    handler = HandlerFactory.create_handler(device_type)
    handler.handle_message(topic, msg.payload)
```

**Benefits:**
- Encapsulates object creation
- Easy to add new device types
- Centralizes creation logic
- Supports registration of new types at runtime

## Singleton Pattern

**Intent:** Ensure a class has only one instance and provide a global point of access to it.

**IoT Application:** MQTT broker connection manager

**Implementation:**

```python
import threading

class MQTTConnectionManager:
    """Singleton MQTT connection manager"""
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return

        self._initialized = True
        self.client = mqtt.Client()
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.connected = False
        self.subscriptions = set()

    def connect(self, broker_url, port=1883):
        if not self.connected:
            self.client.connect(broker_url, port)
            self.client.loop_start()

    def subscribe(self, topic, callback):
        self.subscriptions.add(topic)
        self.client.message_callback_add(topic, callback)
        if self.connected:
            self.client.subscribe(topic)

    def publish(self, topic, payload, qos=1, retain=False):
        if self.connected:
            self.client.publish(topic, payload, qos=qos, retain=retain)

    def _on_connect(self, client, userdata, flags, rc):
        self.connected = True
        # Re-subscribe to all topics
        for topic in self.subscriptions:
            self.client.subscribe(topic)

    def _on_disconnect(self, client, userdata, rc):
        self.connected = False

# Usage
mqtt1 = MQTTConnectionManager()
mqtt2 = MQTTConnectionManager()
assert mqtt1 is mqtt2  # Same instance
```

**Benefits:**
- Controlled access to single instance
- Reduced resource usage (one connection)
- Global state management
- Lazy initialization

**Cautions:**
- Can make testing difficult (use dependency injection in tests)
- Global state can lead to tight coupling
- Thread safety required

## Publish-Subscribe Pattern

**Intent:** Define a one-to-many dependency between objects using an event channel.

**IoT Application:** Core communication pattern for MQTT-based systems

**Structure:**
```
Publisher (Timer Device)
    └─> Event Channel (MQTT Broker)
        ├─> Subscriber A (Notification Service)
        ├─> Subscriber B (Telemetry Service)
        └─> Subscriber C (UI Dashboard)
```

**Implementation:**

```python
class EventBus:
    """Simple event bus for in-process pub/sub"""
    def __init__(self):
        self._subscribers = {}

    def subscribe(self, event_type, callback):
        if event_type not in self._subscribers:
            self._subscribers[event_type] = []
        self._subscribers[event_type].append(callback)

    def unsubscribe(self, event_type, callback):
        if event_type in self._subscribers:
            self._subscribers[event_type].remove(callback)

    def publish(self, event_type, data):
        if event_type in self._subscribers:
            for callback in self._subscribers[event_type]:
                try:
                    callback(data)
                except Exception as e:
                    print(f"Error in subscriber: {e}")


class MQTTEventBus:
    """MQTT-based event bus for distributed pub/sub"""
    def __init__(self, mqtt_client):
        self.mqtt_client = mqtt_client
        self.mqtt_client.on_message = self._on_message
        self._handlers = {}

    def subscribe(self, topic, handler):
        self._handlers[topic] = handler
        self.mqtt_client.subscribe(topic)

    def publish(self, topic, event_data):
        payload = json.dumps(event_data)
        self.mqtt_client.publish(topic, payload, qos=1)

    def _on_message(self, client, userdata, msg):
        topic = msg.topic
        if topic in self._handlers:
            try:
                data = json.loads(msg.payload)
                self._handlers[topic](data)
            except Exception as e:
                print(f"Error handling message on {topic}: {e}")


# Usage
event_bus = EventBus()

# Subscribe to events
def on_timer_complete(data):
    print(f"Timer {data['device_id']} completed")
    send_notification(data['device_id'])

def on_timer_complete_log(data):
    print(f"Logging timer completion: {data}")
    log_to_database(data)

event_bus.subscribe('timer.complete', on_timer_complete)
event_bus.subscribe('timer.complete', on_timer_complete_log)

# Publish event
event_bus.publish('timer.complete', {
    'device_id': 't01',
    'duration': 1500,
    'timestamp': time.time()
})
```

**Benefits:**
- Complete decoupling of publishers and subscribers
- Scalable (add subscribers without changing publishers)
- Asynchronous communication
- Multiple subscribers per event

**Considerations:**
- Event versioning for compatibility
- Error handling (one subscriber failure shouldn't affect others)
- Guaranteed delivery (use QoS 1+ in MQTT)
- Event ordering (use sequence numbers if critical)

## Command Pattern

**Intent:** Encapsulate a request as an object, thereby letting you parameterize clients with different requests, queue or log requests, and support undoable operations.

**IoT Application:** Device command queuing and replay

**Implementation:**

```python
from abc import ABC, abstractmethod
from typing import List

class Command(ABC):
    """Abstract command"""
    @abstractmethod
    def execute(self):
        pass

    @abstractmethod
    def undo(self):
        pass


class StartTimerCommand(Command):
    """Concrete command: Start timer"""
    def __init__(self, timer_device, duration):
        self.timer_device = timer_device
        self.duration = duration
        self.previous_state = None

    def execute(self):
        self.previous_state = self.timer_device.get_state()
        self.timer_device.start(self.duration)

    def undo(self):
        self.timer_device.restore_state(self.previous_state)


class PauseTimerCommand(Command):
    """Concrete command: Pause timer"""
    def __init__(self, timer_device):
        self.timer_device = timer_device
        self.was_running = False

    def execute(self):
        self.was_running = self.timer_device.is_running
        self.timer_device.pause()

    def undo(self):
        if self.was_running:
            self.timer_device.resume()


class CommandQueue:
    """Command queue for offline operation"""
    def __init__(self):
        self.queue: List[Command] = []
        self.history: List[Command] = []

    def add_command(self, command: Command):
        self.queue.append(command)

    def execute_all(self):
        while self.queue:
            command = self.queue.pop(0)
            command.execute()
            self.history.append(command)

    def undo_last(self):
        if self.history:
            command = self.history.pop()
            command.undo()


# Usage for offline-first device
class OfflineDevice:
    def __init__(self):
        self.command_queue = CommandQueue()
        self.is_online = False

    def start_timer(self, duration):
        command = StartTimerCommand(self.timer, duration)

        if self.is_online:
            command.execute()
        else:
            # Queue for later execution
            self.command_queue.add_command(command)

    def on_reconnect(self):
        self.is_online = True
        # Execute queued commands
        self.command_queue.execute_all()
```

**Benefits:**
- Decouples invoker from receiver
- Commands can be queued, logged, or undone
- Supports offline operation
- Macro commands (composite pattern)

## Additional Patterns for IoT

### Adapter Pattern

**Use Case:** Integrate legacy devices with modern MQTT architecture

```python
class LegacyDevice:
    """Old device with proprietary protocol"""
    def send_command(self, cmd_code, params):
        # Proprietary protocol
        pass

class MQTTDeviceAdapter:
    """Adapter to make legacy device work with MQTT"""
    def __init__(self, legacy_device, mqtt_client):
        self.legacy_device = legacy_device
        self.mqtt_client = mqtt_client
        self.mqtt_client.on_message = self.on_message

    def on_message(self, client, userdata, msg):
        # Convert MQTT message to legacy command
        command = self.parse_mqtt_command(msg)
        self.legacy_device.send_command(command['code'], command['params'])

    def parse_mqtt_command(self, msg):
        # Map MQTT commands to legacy protocol
        mapping = {
            'start': {'code': 0x01, 'params': []},
            'stop': {'code': 0x02, 'params': []},
        }
        return mapping.get(msg.payload.decode(), mapping['stop'])
```

### Proxy Pattern

**Use Case:** Cache device state to reduce MQTT traffic

```python
class DeviceProxy:
    """Proxy for device with caching"""
    def __init__(self, device, cache_ttl=60):
        self.device = device
        self.cache = {}
        self.cache_ttl = cache_ttl

    def get_state(self):
        now = time.time()
        if 'state' in self.cache and now - self.cache['state_ts'] < self.cache_ttl:
            return self.cache['state']

        # Cache miss: fetch from device
        state = self.device.get_state()
        self.cache['state'] = state
        self.cache['state_ts'] = now
        return state
```

### Template Method Pattern

**Use Case:** Define skeleton of device initialization algorithm

```python
class Device(ABC):
    """Abstract device with template method"""
    def initialize(self):
        self.connect_wifi()
        self.connect_mqtt()
        self.register_device()
        self.device_specific_setup()  # Hook method
        self.publish_ready()

    @abstractmethod
    def device_specific_setup(self):
        """Hook for device-specific initialization"""
        pass

    def connect_wifi(self):
        # Common WiFi connection logic
        pass

    def connect_mqtt(self):
        # Common MQTT connection logic
        pass

    # ... other common methods

class TimerDevice(Device):
    def device_specific_setup(self):
        # Timer-specific initialization
        self.load_timer_presets()
        self.subscribe_to_timer_topics()
```
