# ADR-{NUMBER}: {Title}

**Status:** {Proposed | Accepted | Deprecated | Superseded}

**Date:** {YYYY-MM-DD}

**Decision Makers:** {List of people involved in the decision}

**Tags:** {communication, scalability, security, performance, etc.}

---

## Context

Describe the forces at play, including:
- Technical constraints
- Business requirements
- User needs
- Resource limitations
- Timeline pressures
- Organizational factors

What is the issue that motivates this decision or change?

## Decision

State the architecture decision and provide detailed justification.

What is the change that is being proposed or has been made?

Include:
- Chosen solution overview
- Key components and their responsibilities
- Technology choices
- Implementation approach

## Rationale

Why is this decision the right choice?

Include:
- Alignment with system goals
- How it addresses the context
- Technical advantages
- Business value
- Risk mitigation

## Alternatives Considered

### Alternative 1: {Name}

**Description:** Brief description of this alternative

**Pros:**
- Advantage 1
- Advantage 2

**Cons:**
- Disadvantage 1
- Disadvantage 2

**Why not chosen:** Explanation

### Alternative 2: {Name}

**Description:** Brief description of this alternative

**Pros:**
- Advantage 1
- Advantage 2

**Cons:**
- Disadvantage 1
- Disadvantage 2

**Why not chosen:** Explanation

## Consequences

### Positive Consequences
- Benefit 1
- Benefit 2
- Benefit 3

### Negative Consequences
- Trade-off 1
- Trade-off 2
- Cost 1

### Neutral Consequences
- Change 1
- Change 2

## Implementation Impact

### Components Affected
- Component A: {description of impact}
- Component B: {description of impact}

### Performance Implications
- Latency impact: {description}
- Throughput impact: {description}
- Resource usage: {description}

### Development Impact
- Estimated effort: {hours/days/weeks}
- Required skills: {list of skills}
- Dependencies: {external dependencies}
- Testing requirements: {description}

### Operational Impact
- Deployment changes: {description}
- Monitoring requirements: {description}
- Maintenance considerations: {description}

## Risks and Mitigation

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| {Risk description} | {Low/Med/High} | {Low/Med/High} | {How to mitigate} |

## Compliance and Standards

- Standards followed: {list relevant standards}
- Regulations considered: {any regulatory requirements}
- Best practices applied: {industry best practices}

## Success Metrics

How will we measure if this decision was successful?

- Metric 1: {description and target}
- Metric 2: {description and target}
- Metric 3: {description and target}

## Follow-up Actions

- [ ] Action item 1
- [ ] Action item 2
- [ ] Action item 3

## References

- [Link to relevant documentation]
- [Link to research or articles]
- [Related ADRs]

## Revision History

| Date | Author | Description |
|------|--------|-------------|
| {YYYY-MM-DD} | {Name} | Initial version |

---

## Example ADR

Below is a filled-out example for reference:

---

# ADR-001: Use MQTT for Device Communication

**Status:** Accepted

**Date:** 2024-01-15

**Decision Makers:** System Architect, IoT Team Lead

**Tags:** communication, scalability, iot

---

## Context

The Argus system requires reliable communication between multiple heterogeneous devices (Presto, T-Embed, Jetson Nano, Stream Deck). The devices are on the same local network but may experience intermittent connectivity. Key requirements:

- Low latency (<100ms for state updates)
- Support for multiple subscribers to the same data
- Offline operation and message queuing
- Small footprint for embedded devices
- Easy integration with Python (Jetson) and MicroPython (Presto)

## Decision

Use MQTT (Message Queuing Telemetry Transport) as the primary communication protocol for all device-to-device and device-to-server communication. Mosquitto will serve as the MQTT broker running on the Jetson Nano.

**Architecture:**
- Jetson Nano: Mosquitto broker (central hub)
- All devices: MQTT clients
- Topic structure: `argus/{location}/{device-type}/{device-id}/{data-type}`
- QoS 1 for important messages (state, commands)
- QoS 0 for high-frequency telemetry

## Rationale

MQTT is purpose-built for IoT scenarios and aligns perfectly with our requirements:

1. **Publish-Subscribe Model**: Natural fit for our hub-and-spoke topology
2. **Quality of Service**: QoS levels provide delivery guarantees where needed
3. **Small Footprint**: Minimal overhead for ESP32 and RP2350 devices
4. **Retained Messages**: Last known state automatically available to new subscribers
5. **Last Will and Testament**: Automatic detection of device disconnections
6. **Wide Support**: Excellent libraries for all our platforms
7. **Offline Queuing**: Built-in support for message persistence

## Alternatives Considered

### Alternative 1: HTTP/REST

**Description:** RESTful APIs with polling for updates

**Pros:**
- Familiar to developers
- Excellent tooling and debugging
- Native support in all languages

**Cons:**
- Requires polling for real-time updates (inefficient)
- Higher latency for state synchronization
- More complex client implementation
- Poor offline support

**Why not chosen:** Polling-based updates don't meet our <100ms latency requirement and waste bandwidth on a local network.

### Alternative 2: WebSockets

**Description:** Bidirectional WebSocket connections between devices

**Pros:**
- Real-time bidirectional communication
- Native web browser support
- Relatively simple protocol

**Cons:**
- No built-in message persistence
- No QoS guarantees
- Requires custom pub/sub implementation
- Limited support on embedded devices
- Each device needs to maintain multiple connections

**Why not chosen:** Lack of built-in pub/sub and QoS features would require significant custom development, negating the simplicity advantage.

### Alternative 3: gRPC

**Description:** High-performance RPC framework with Protocol Buffers

**Pros:**
- Excellent performance
- Strong typing with Protocol Buffers
- Bidirectional streaming

**Cons:**
- Limited support on constrained devices (RP2350)
- Binary protocol harder to debug
- Requires code generation
- More complex than needed
- No built-in pub/sub

**Why not chosen:** Overkill for local network communication, and MicroPython support is limited.

## Consequences

### Positive Consequences
- Simplified device implementation (existing MQTT libraries)
- Built-in features reduce custom code (QoS, retained messages, LWT)
- Excellent debugging tools (MQTT Explorer, mosquitto_sub)
- Easy to add new devices (just connect to broker)
- Offline operation with message queuing

### Negative Consequences
- Single point of failure (broker on Jetson Nano)
- All traffic passes through broker (potential bottleneck)
- Learning curve for developers unfamiliar with MQTT

### Neutral Consequences
- Need to run Mosquitto broker on Jetson Nano
- Topic naming conventions must be enforced
- Security configuration required (authentication, ACLs)

## Implementation Impact

### Components Affected
- **All Devices**: Implement MQTT client functionality
- **Jetson Nano**: Run Mosquitto broker service
- **State Management**: Design around MQTT topic structure
- **Monitoring**: Integrate with Mosquitto logging

### Performance Implications
- **Latency**: Expected 20-50ms for local network communication
- **Throughput**: Broker can handle >10,000 messages/second (far exceeds our ~100/sec)
- **Resource usage**: Mosquitto uses ~10MB RAM, negligible CPU

### Development Impact
- **Estimated effort**: 2 weeks for full integration across all devices
- **Required skills**: MQTT protocol knowledge, experience with Mosquitto
- **Dependencies**:
  - Mosquitto broker (apt install)
  - paho-mqtt (Python)
  - umqtt.simple (MicroPython)
  - PubSubClient (Arduino/ESP-IDF)
- **Testing requirements**: Integration tests for all device communication paths

### Operational Impact
- **Deployment changes**: Mosquitto must run as systemd service on Jetson
- **Monitoring requirements**: Monitor broker health, connection count, message rate
- **Maintenance**: Periodic log rotation, broker updates

## Risks and Mitigation

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| Broker failure causes system-wide outage | Medium | High | Implement broker monitoring, automatic restart, and device offline operation mode |
| Broker becomes bottleneck at scale | Low | Medium | Monitor broker performance, plan for clustering if needed (100+ devices) |
| Message storms overwhelm broker | Low | Medium | Implement rate limiting on devices, QoS 0 for high-frequency data |
| Topic structure becomes confusing | Medium | Low | Document naming conventions, create topic visualization |

## Compliance and Standards

- **Standards followed**: MQTT 3.1.1 specification
- **Regulations**: None (local network only)
- **Best practices**:
  - OWASP IoT Security Guidelines
  - MQTT Security Best Practices (authentication, TLS)

## Success Metrics

- **Latency**: 95th percentile message delivery < 100ms
- **Reliability**: 99.9% message delivery success for QoS 1
- **Uptime**: Broker uptime > 99.5%
- **Developer Satisfaction**: Team survey after 1 month implementation

## Follow-up Actions

- [x] Set up Mosquitto broker on Jetson Nano
- [x] Configure authentication and ACLs
- [x] Document topic naming conventions
- [ ] Implement monitoring dashboard for broker health
- [ ] Create integration test suite
- [ ] Write developer guide for MQTT usage

## References

- [MQTT Specification](https://mqtt.org/mqtt-specification/)
- [Mosquitto Documentation](https://mosquitto.org/documentation/)
- [Paho MQTT Python Client](https://www.eclipse.org/paho/python.html)
- ADR-002: MQTT Topic Structure Design

## Revision History

| Date | Author | Description |
|------|--------|-------------|
| 2024-01-15 | System Architect | Initial version |
| 2024-01-20 | IoT Team Lead | Added security considerations |
