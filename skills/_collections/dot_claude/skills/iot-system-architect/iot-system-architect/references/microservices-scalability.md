# Microservices and Scalability Patterns for IoT

## Microservices for IoT

### Service Boundaries for Devices

**Decomposition Strategies:**

1. **By Device Type**:
   ```
   timer-service/     - Manages all timer devices
   display-service/   - Handles display devices
   sensor-service/    - Processes sensor data
   ```
   - Pro: Simple organization, clear ownership
   - Con: Tight coupling if devices interact

2. **By Business Capability**:
   ```
   notification-service/  - Handles all notifications
   telemetry-service/     - Collects and stores telemetry
   control-service/       - Device command and control
   ```
   - Pro: Business-aligned, reusable across devices
   - Con: May split device logic across services

3. **By Bounded Context (DDD)**:
   ```
   timer-context/         - Timer domain logic
   workspace-context/     - Workspace awareness
   notification-context/  - Notification delivery
   ```
   - Pro: Domain-driven, clear boundaries
   - Con: Requires deep domain understanding

**Argus Service Decomposition:**
```
mqtt-broker/           - Mosquitto MQTT broker
device-service/        - Device registration and discovery
timer-service/         - Timer logic and state management
notification-service/  - Android notification bridge
ai-service/            - ML inference (Jetson Nano)
telemetry-service/     - Metrics collection and storage
```

### API Design for Device Coordination

**RESTful Device APIs:**

```
GET    /devices                 - List all devices
GET    /devices/{id}            - Get device details
POST   /devices/{id}/commands   - Send command to device
GET    /devices/{id}/state      - Get current state
PUT    /devices/{id}/config     - Update device configuration
GET    /devices/{id}/telemetry  - Get telemetry data
```

**Event-Driven APIs (MQTT):**

```
Topic: device/{id}/command
Payload: {"cmd": "start_timer", "duration": 300, "mode": "work"}

Topic: device/{id}/state
Payload: {"state": "running", "elapsed": 45, "remaining": 255}

Topic: device/{id}/event
Payload: {"event": "timer_complete", "timestamp": 1234567890}
```

**GraphQL for Complex Queries:**

```graphql
query {
  device(id: "t01") {
    id
    type
    state {
      running
      elapsed
      mode
    }
    telemetry(last: 10) {
      timestamp
      metrics {
        battery
        wifi_strength
      }
    }
  }
}
```

**API Design Principles:**
- Use versioning (v1, v2) for breaking changes
- Include correlation IDs for request tracing
- Implement pagination for collections
- Provide filtering and sorting options
- Use HATEOAS for discoverability (REST)
- Design for idempotency

### Service Discovery Mechanisms

**Static Configuration:**
```yaml
services:
  mqtt_broker:
    host: jetson-nano.local
    port: 1883
  timer_service:
    host: jetson-nano.local
    port: 8001
```
- Simple for small deployments
- Manual updates required

**DNS-Based Discovery:**
```
_mqtt._tcp.argus.local    -> jetson-nano.local:1883
_timer._http.argus.local  -> jetson-nano.local:8001
```
- Use mDNS/Bonjour for local networks
- Standard DNS for cloud deployments

**Service Registry Pattern:**
```
Registry (Consul/etcd):
  - Services register on startup
  - Health checks maintain registry
  - Clients query registry for endpoints
  - Automatic failover on health check failure
```

**MQTT-Based Discovery:**
```
Topic: $SYS/broker/clients/active
Topic: service/+/announce

Device publishes on connect:
  service/timer-01/announce
  Payload: {"service": "timer", "id": "01", "capabilities": ["pomodoro"]}
```

### Inter-Service Communication Patterns

**Synchronous Communication:**

1. **HTTP/REST** (Request-Reply):
   ```python
   # Timer service calls notification service
   response = requests.post(
       "http://notification-service/api/v1/send",
       json={"message": "Timer complete", "priority": "high"}
   )
   ```
   - Pro: Simple, familiar
   - Con: Tight coupling, cascading failures

2. **gRPC** (High Performance):
   ```proto
   service TimerService {
     rpc StartTimer(StartTimerRequest) returns (TimerResponse);
     rpc GetTimerState(TimerStateRequest) returns (TimerState);
   }
   ```
   - Pro: Efficient, type-safe, streaming support
   - Con: Complexity, binary protocol

**Asynchronous Communication:**

1. **Message Queue (MQTT, RabbitMQ)**:
   ```
   Publisher → Queue → Consumer(s)
   - Decoupled services
   - Natural load balancing
   - Reliable delivery with QoS
   ```

2. **Event Bus**:
   ```
   Event: TimerCompleted
     ├─> Notification Service (send notification)
     ├─> Telemetry Service (record event)
     └─> AI Service (analyze patterns)
   ```
   - Pro: Complete decoupling, extensibility
   - Con: Event versioning, debugging complexity

**Recommendation for IoT:**
- Use MQTT for device communication
- Use HTTP/REST for admin/configuration APIs
- Use gRPC for inter-service communication (if performance critical)
- Avoid synchronous chains (max depth: 2)

### Failure Isolation and Resilience

**Circuit Breaker Pattern:**

```python
class CircuitBreaker:
    def __init__(self, failure_threshold=5, timeout=60):
        self.failure_count = 0
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
        self.last_failure_time = None

    def call(self, func, *args, **kwargs):
        if self.state == "OPEN":
            if time.time() - self.last_failure_time > self.timeout:
                self.state = "HALF_OPEN"
            else:
                raise CircuitBreakerOpenError()

        try:
            result = func(*args, **kwargs)
            self.on_success()
            return result
        except Exception as e:
            self.on_failure()
            raise

    def on_success(self):
        self.failure_count = 0
        self.state = "CLOSED"

    def on_failure(self):
        self.failure_count += 1
        self.last_failure_time = time.time()
        if self.failure_count >= self.failure_threshold:
            self.state = "OPEN"
```

**Bulkhead Pattern:**
- Isolate resources for different services
- Separate thread pools, connection pools
- Prevents cascade failures

```python
# Separate executors for different service calls
notification_executor = ThreadPoolExecutor(max_workers=5)
telemetry_executor = ThreadPoolExecutor(max_workers=10)

# Notification failure doesn't impact telemetry
notification_executor.submit(send_notification, data)
telemetry_executor.submit(log_telemetry, data)
```

**Timeout and Retry Strategies:**

```python
import tenacity

@tenacity.retry(
    stop=tenacity.stop_after_attempt(3),
    wait=tenacity.wait_exponential(multiplier=1, min=1, max=10),
    retry=tenacity.retry_if_exception_type(ConnectionError)
)
def call_service(endpoint, data):
    response = requests.post(endpoint, json=data, timeout=5)
    response.raise_for_status()
    return response.json()
```

**Graceful Degradation:**
```python
def get_timer_state(device_id):
    try:
        # Try primary service
        return timer_service.get_state(device_id)
    except ServiceUnavailableError:
        # Fall back to cached state
        return cache.get(f"timer_state:{device_id}")
    except Exception:
        # Return safe default
        return {"state": "unknown", "last_update": None}
```

### Container Orchestration (Docker for Backend)

**Docker Compose for Development:**

```yaml
version: '3.8'

services:
  mqtt-broker:
    image: eclipse-mosquitto:2.0
    ports:
      - "1883:1883"
    volumes:
      - ./mosquitto.conf:/mosquitto/config/mosquitto.conf
      - mosquitto-data:/mosquitto/data

  timer-service:
    build: ./services/timer
    depends_on:
      - mqtt-broker
      - postgres
    environment:
      - MQTT_BROKER=mqtt://mqtt-broker:1883
      - DATABASE_URL=postgresql://postgres:5432/timers
    restart: unless-stopped

  notification-service:
    build: ./services/notification
    depends_on:
      - mqtt-broker
    environment:
      - MQTT_BROKER=mqtt://mqtt-broker:1883
    restart: unless-stopped

  postgres:
    image: postgres:15
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=changeme

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data

volumes:
  mosquitto-data:
  postgres-data:
  redis-data:
```

**Production Considerations:**
- Health checks for all services
- Resource limits (memory, CPU)
- Logging configuration
- Secret management (not in environment variables)
- Volume backups

## Scalability Considerations

### Horizontal vs Vertical Scaling

**Vertical Scaling (Scale Up):**
- Add more CPU, RAM, storage to existing machine
- Simpler to implement
- Limited by hardware maximums
- Single point of failure

**When to Use:**
- Monolithic broker (Mosquitto)
- Database (PostgreSQL primary)
- Single-tenant deployments

**Horizontal Scaling (Scale Out):**
- Add more machines/containers
- Nearly unlimited scaling
- Fault tolerance through redundancy
- Requires stateless design or shared state

**When to Use:**
- Stateless services (API gateways, workers)
- Message consumers
- Read replicas
- Multi-tenant deployments

**Argus Scaling Strategy:**
```
MQTT Broker (Jetson Nano):     Vertical (single broker)
Timer Service:                  Horizontal (stateless API)
Telemetry Service:              Horizontal (worker pool)
PostgreSQL:                     Vertical (primary) + Horizontal (read replicas)
```

### Load Balancing Strategies

**Client-Side Load Balancing:**
```python
import random

class ServiceRegistry:
    def __init__(self):
        self.services = {
            'timer': ['http://timer-1:8001', 'http://timer-2:8001'],
            'telemetry': ['http://telemetry-1:8002', 'http://telemetry-2:8002']
        }

    def get_endpoint(self, service_name):
        endpoints = self.services.get(service_name, [])
        return random.choice(endpoints) if endpoints else None
```

**Round-Robin:**
- Distribute requests evenly
- Simple, no state required
- Doesn't account for server load

**Least Connections:**
- Route to server with fewest active connections
- Better for varying request durations
- Requires connection tracking

**Sticky Sessions:**
- Route same client to same server
- Useful for stateful applications
- Can cause imbalance

**MQTT Shared Subscriptions:**
```
# Multiple consumers share a subscription
$share/group1/telemetry/+/data

# Broker distributes messages among group members
Consumer 1: Receives 50% of messages
Consumer 2: Receives 50% of messages
```

### Database Sharding for Device Data

**Sharding Strategies:**

1. **By Device ID (Hash-Based)**:
   ```python
   shard = hash(device_id) % num_shards
   ```
   - Pro: Even distribution
   - Con: Device data split, multi-shard queries complex

2. **By Device Type**:
   ```
   Shard 1: All timer devices
   Shard 2: All display devices
   Shard 3: All sensor devices
   ```
   - Pro: Type-specific queries stay on one shard
   - Con: Uneven distribution if device types vary

3. **By Location/Zone**:
   ```
   Shard 1: Home office devices
   Shard 2: Bedroom devices
   Shard 3: Kitchen devices
   ```
   - Pro: Location queries efficient
   - Con: Requires location to be part of query

**Time-Series Data (Telemetry):**
```
# Partition by time window
table_2025_01  # January 2025 data
table_2025_02  # February 2025 data

# Or use time-series database (TimescaleDB, InfluxDB)
```

### Caching Strategies (Redis)

**Cache Patterns:**

1. **Cache-Aside (Lazy Loading)**:
   ```python
   def get_device_state(device_id):
       # Try cache first
       cached = redis.get(f"device:{device_id}:state")
       if cached:
           return json.loads(cached)

       # Cache miss: fetch from database
       state = db.query_device_state(device_id)

       # Update cache
       redis.setex(
           f"device:{device_id}:state",
           300,  # 5 minute TTL
           json.dumps(state)
       )

       return state
   ```

2. **Write-Through**:
   ```python
   def update_device_state(device_id, state):
       # Write to database
       db.update_device_state(device_id, state)

       # Update cache
       redis.setex(
           f"device:{device_id}:state",
           300,
           json.dumps(state)
       )
   ```

3. **Write-Behind (Write-Back)**:
   ```python
   def update_device_state(device_id, state):
       # Write to cache immediately
       redis.setex(f"device:{device_id}:state", 300, json.dumps(state))

       # Queue database write for later
       write_queue.put(("update_state", device_id, state))
   ```

**Cache Invalidation:**
- TTL (Time To Live): Automatic expiration
- Event-based: Invalidate on MQTT state change
- Tag-based: Invalidate related caches

**What to Cache:**
- Device state (frequently read)
- User sessions
- Computed aggregations
- API responses
- Service discovery information

### Message Queue Sizing

**Queue Depth Considerations:**

```python
# Calculate required queue depth
messages_per_second = 100
consumer_processing_rate = 80  # msg/sec
burst_duration = 10  # seconds
safety_factor = 1.5

required_depth = (messages_per_second - consumer_processing_rate) * burst_duration * safety_factor
# = (100 - 80) * 10 * 1.5 = 300 messages
```

**Mosquitto Queue Configuration:**
```conf
# Per-client queue limit
max_queued_messages 1000

# Per-subscription queue (for QoS 1/2)
max_queued_bytes 0  # Unlimited

# Reject new connections if broker overloaded
max_connections 1000
```

**Monitoring:**
- Queue depth over time
- Message age in queue
- Consumer lag
- Message drop rate

### Connection Pooling

**Database Connection Pooling:**

```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    "postgresql://user:pass@localhost/db",
    poolclass=QueuePool,
    pool_size=10,        # Normal pool size
    max_overflow=20,     # Extra connections under load
    pool_timeout=30,     # Wait time for connection
    pool_recycle=3600,   # Recycle connections hourly
    pool_pre_ping=True   # Verify connections before use
)
```

**MQTT Connection Pooling:**

```python
class MQTTConnectionPool:
    def __init__(self, broker_url, pool_size=5):
        self.broker_url = broker_url
        self.pool = Queue(maxsize=pool_size)
        for _ in range(pool_size):
            client = mqtt.Client()
            client.connect(broker_url)
            self.pool.put(client)

    def get_client(self):
        return self.pool.get()

    def return_client(self, client):
        self.pool.put(client)
```

**Benefits:**
- Reduced connection overhead
- Controlled resource usage
- Better performance under load
- Connection reuse
