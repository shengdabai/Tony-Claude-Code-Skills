# MQTT Protocol Reference

Detailed MQTT protocol specifications and advanced patterns.

## Protocol Basics

### MQTT Packet Types

| Type | Name | Direction | Description |
|------|------|-----------|-------------|
| 1 | CONNECT | Client → Server | Connection request |
| 2 | CONNACK | Server → Client | Connection acknowledgment |
| 3 | PUBLISH | Both | Publish message |
| 4 | PUBACK | Both | Publish acknowledgment (QoS 1) |
| 5 | PUBREC | Both | Publish received (QoS 2) |
| 6 | PUBREL | Both | Publish release (QoS 2) |
| 7 | PUBCOMP | Both | Publish complete (QoS 2) |
| 8 | SUBSCRIBE | Client → Server | Subscribe to topics |
| 9 | SUBACK | Server → Client | Subscribe acknowledgment |
| 10 | UNSUBSCRIBE | Client → Server | Unsubscribe from topics |
| 11 | UNSUBACK | Server → Client | Unsubscribe acknowledgment |
| 12 | PINGREQ | Client → Server | Ping request (keepalive) |
| 13 | PINGRESP | Server → Client | Ping response |
| 14 | DISCONNECT | Client → Server | Client disconnect |

## Topic Wildcards

### Single-Level Wildcard (+)
Matches exactly one topic level:

```
sensor/+/temperature
  ✓ sensor/bedroom/temperature
  ✓ sensor/kitchen/temperature
  ✗ sensor/bedroom/living/temperature (too many levels)
  ✗ sensor/temperature (too few levels)
```

### Multi-Level Wildcard (#)
Matches zero or more topic levels (must be last):

```
sensor/#
  ✓ sensor/bedroom/temperature
  ✓ sensor/bedroom/humidity
  ✓ sensor/kitchen/temperature/1
  ✓ sensor (empty subtree)

sensor/bedroom/#
  ✓ sensor/bedroom/temperature
  ✓ sensor/bedroom/temperature/calibrated
  ✗ sensor/kitchen/temperature
```

### Combined Wildcards
```
sensor/+/temperature/#
  ✓ sensor/bedroom/temperature
  ✓ sensor/bedroom/temperature/calibrated
  ✓ sensor/kitchen/temperature/raw/celsius
  ✗ sensor/temperature (missing middle level)
```

## QoS Flow Diagrams

### QoS 0 (At most once)
```
Client                  Broker
  │                       │
  ├── PUBLISH ──────────>│
  │   (QoS 0)            │
  │                       │
```
**Characteristics**: Fire and forget, no acknowledgment, may lose messages.

### QoS 1 (At least once)
```
Client                  Broker
  │                       │
  ├── PUBLISH ──────────>│
  │   (QoS 1)            │
  │                       │
  │<────── PUBACK ───────┤
  │                       │
```
**Characteristics**: Acknowledged delivery, may receive duplicates.

### QoS 2 (Exactly once)
```
Client                  Broker
  │                       │
  ├── PUBLISH ──────────>│
  │   (QoS 2)            │
  │                       │
  │<────── PUBREC ───────┤
  │                       │
  ├── PUBREL ──────────>│
  │                       │
  │<────── PUBCOMP ──────┤
  │                       │
```
**Characteristics**: Guaranteed single delivery, highest overhead.

## Session Types

### Clean Session (clean_start = true)
```
Connect → Subscribe → Disconnect
         (all subscriptions lost)
Connect → Must re-subscribe
```

**Use when**: Short-lived connections, no message queueing needed

**Examples**:
- Diagnostic tools
- Temporary monitoring
- One-time data queries

### Persistent Session (clean_start = false)
```
Connect → Subscribe → Disconnect
         (subscriptions maintained)
         (QoS 1/2 messages queued)
Connect → Subscriptions active immediately
         Receive queued messages
```

**Use when**: Reliable delivery critical, connection may be intermittent

**Examples**:
- IoT devices (Presto, T-Embed)
- Mission-critical sensors
- Command receivers

## Retained Messages

### Behavior
```
Publisher               Broker
  │                       │
  ├── PUBLISH (retain) ─>│ (Store message)
  │                       │

New Subscriber          Broker
  │                       │
  ├── SUBSCRIBE ────────>│
  │                       │
  │<─ PUBLISH (retained)─┤ (Immediate delivery)
  │                       │
```

### Best Practices

**DO use retained messages for**:
- Current state (device status, sensor values)
- Configuration settings
- Last known values

**DON'T use retained messages for**:
- Events (alerts, commands)
- Time-series data
- Transient information

### Clear Retained Message
```
client.publish("topic/name", "", qos=1, retain=true)
```
Empty payload with retain flag clears the retained message.

## Last Will and Testament (LWT)

### Configuration
```python
client.will_set(
    topic="device/status",
    payload='{"online": false}',
    qos=1,
    retain=True
)
client.connect(broker, port, keepalive=60)
```

### Trigger Conditions
LWT is published automatically when:
1. Client disconnects without DISCONNECT packet
2. Network connection lost
3. Keepalive timeout expires
4. Broker shuts down (published on restart)

LWT is **NOT** published when:
1. Client sends DISCONNECT packet
2. Session expires (if clean_start=true)

## Advanced Patterns

### Request/Response Pattern
```
Topic structure:
  request/{service}/{action}
  response/{service}/{client_id}

Client A:
  1. Subscribe to response/calc/client-a
  2. Publish to request/calc/add with payload {"a": 5, "b": 3}

Service:
  1. Subscribe to request/calc/#
  2. Process request
  3. Publish to response/calc/client-a with payload {"result": 8}

Client A:
  4. Receive response
```

### Shared Subscriptions (Load Balancing)
```
# Normal subscription (all clients receive)
topic/data

# Shared subscription (round-robin delivery)
$share/group1/topic/data
```

**Example**:
```
3 Workers subscribe to: $share/workers/tasks/#
Broker distributes messages round-robin among workers
Only one worker receives each message
```

### System Topics ($SYS)
```
$SYS/broker/version
$SYS/broker/uptime
$SYS/broker/clients/connected
$SYS/broker/clients/maximum
$SYS/broker/messages/received
$SYS/broker/messages/sent
$SYS/broker/bytes/received
$SYS/broker/bytes/sent
```

Enable in mosquitto.conf:
```
sys_interval 60
```

## Performance Optimization

### Message Batching
Instead of:
```python
for i in range(1000):
    client.publish(f"sensor/{i}", str(value))
```

Use:
```python
batch = []
for i in range(1000):
    batch.append((f"sensor/{i}", str(value)))

for topic, payload in batch:
    client.publish(topic, payload)
```

### Topic Design for Efficiency
**Good** (hierarchical, specific):
```
building/floor1/room101/temperature
building/floor1/room101/humidity
building/floor2/room201/temperature
```

**Bad** (flat, requires many subscriptions):
```
room101-temperature
room101-humidity
room202-temperature
```

### Connection Pooling
For multiple devices, use separate MQTT connections instead of sharing:
```
# Good: Each device has own connection
presto_client = mqtt.Client("presto-01")
tembed_client = mqtt.Client("tembed-01")

# Bad: Shared connection with different client IDs
# (causes conflicts and connection drops)
```

## Troubleshooting

### Connection Refused (Error 5)
**Causes**:
- Wrong broker address/port
- Firewall blocking connection
- Broker not running
- Client ID conflict (duplicate)

**Solutions**:
```bash
# Check broker running
sudo systemctl status mosquitto

# Check port open
nc -zv 192.168.1.100 1883

# Check firewall
sudo ufw allow 1883/tcp
```

### Messages Not Received
**Checklist**:
1. ✓ Subscribed before messages published?
2. ✓ Topic spelling exact match (case-sensitive)?
3. ✓ QoS level appropriate?
4. ✓ Wildcard syntax correct?
5. ✓ Broker ACL allowing access?

**Debug**:
```bash
# Monitor all topics
mosquitto_sub -h localhost -t '#' -v

# Check specific subscription
mosquitto_sub -h localhost -t 'orbit/timer/state/current' -v
```

### High Latency
**Causes**:
- Network congestion
- Broker overloaded
- QoS 2 overhead
- Large message payloads

**Solutions**:
- Use QoS 0 for non-critical data
- Compress large payloads
- Increase broker resources
- Monitor $SYS/broker/load/#

### Memory Leaks (Queued Messages)
**Cause**: Persistent sessions with offline clients

**Limit in mosquitto.conf**:
```
max_queued_messages 1000
max_queued_bytes 1048576  # 1 MB
```

**Monitor**:
```bash
mosquitto_sub -t '$SYS/broker/messages/stored' -v
```

## Security

### Authentication
```conf
# mosquitto.conf
password_file /etc/mosquitto/passwd

# Create user
mosquitto_passwd -c /etc/mosquitto/passwd username
```

### Access Control Lists (ACL)
```conf
# /etc/mosquitto/acl

# Allow user 'presto' to read orbit/timer/#
user presto
topic read orbit/timer/#

# Allow user 'admin' full access
user admin
topic readwrite #

# Pattern ACL (client ID in topic)
pattern readwrite orbit/device/%c/#
```

### TLS/SSL
```conf
# mosquitto.conf
listener 8883
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key
require_certificate true
```

Client:
```python
client.tls_set(
    ca_certs="/path/to/ca.crt",
    certfile="/path/to/client.crt",
    keyfile="/path/to/client.key"
)
client.connect("broker", 8883, 60)
```
