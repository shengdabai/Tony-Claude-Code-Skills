# ADR-NNN: [Short Decision Title]

**Date**: YYYY-MM-DD
**Status**: [Proposed | Accepted | Deprecated | Superseded by ADR-XXX]
**Deciders**: [List people involved in the decision]
**Technical Story**: [Optional: Link to issue, epic, or user story]

---

## Context

Describe the architectural challenge, forces at play, and constraints that led to this decision.

**Background**:
- What is the current state of the system?
- What problem are we trying to solve?
- What are the technical constraints?
- What are the business requirements?

**Forces**:
- Performance requirements (latency, throughput)
- Scalability needs
- Cost constraints
- Team expertise and preferences
- Existing technology stack
- Time-to-market pressures
- Regulatory or compliance requirements

---

## Decision

State the architectural decision clearly and concisely.

**We will**: [Clear statement of what will be done]

**Example**:
- We will use MQTT as the primary message broker protocol for device communication
- We will implement event sourcing for timer state management
- We will deploy backend services using Docker on Jetson Nano

---

## Rationale

Explain *why* this decision was made. This is the most important section.

**Key Reasons**:
1. [Reason 1 with supporting evidence]
2. [Reason 2 with supporting evidence]
3. [Reason 3 with supporting evidence]

**Supporting Evidence**:
- Benchmarks, prototypes, or proof-of-concepts
- References to documentation or research
- Team experience or lessons learned
- Industry best practices

**Example**:
> We chose MQTT over HTTP because:
> 1. MQTT has lower overhead for high-frequency messages (8 bytes header vs 100+ bytes for HTTP)
> 2. MQTT supports QoS levels for reliable delivery, critical for timer synchronization
> 3. Team has prior experience with MQTT from previous IoT projects
> 4. Extensive library support for embedded devices (ESP32, RP2350)

---

## Consequences

Document the positive and negative consequences of this decision.

### Positive Consequences

- ✅ [Benefit 1]
- ✅ [Benefit 2]
- ✅ [Benefit 3]

### Negative Consequences

- ❌ [Drawback 1]
- ❌ [Drawback 2]
- ❌ [Drawback 3]

### Neutral Consequences

- ℹ️ [Consequence that is neither clearly positive nor negative]

**Example**:

### Positive Consequences
- ✅ Reduced bandwidth usage by 70% compared to HTTP polling
- ✅ Sub-50ms message delivery latency on local network
- ✅ Built-in support for offline message queuing

### Negative Consequences
- ❌ Requires running and maintaining Mosquitto broker
- ❌ Less familiar to web developers on the team
- ❌ Debugging pub/sub message flows is more complex than request-response

### Neutral Consequences
- ℹ️ MQTT libraries add ~50KB to firmware size

---

## Alternatives Considered

List other options that were evaluated and why they were not chosen.

### Alternative 1: [Name]

**Description**: [Brief description of the alternative]

**Pros**:
- [Advantage 1]
- [Advantage 2]

**Cons**:
- [Disadvantage 1]
- [Disadvantage 2]

**Why Not Chosen**: [Specific reason for rejection]

---

### Alternative 2: [Name]

**Description**: [Brief description of the alternative]

**Pros**:
- [Advantage 1]
- [Advantage 2]

**Cons**:
- [Disadvantage 1]
- [Disadvantage 2]

**Why Not Chosen**: [Specific reason for rejection]

---

**Example**:

### Alternative 1: HTTP with Long Polling

**Description**: Use HTTP requests with long polling for real-time updates

**Pros**:
- Familiar to all team members
- No additional broker infrastructure needed
- Standard web debugging tools work

**Cons**:
- Higher latency (200-500ms typical)
- Inefficient for high-frequency updates
- Connection overhead on resource-constrained devices

**Why Not Chosen**: Latency requirements (<100ms) cannot be met reliably with HTTP long polling

---

### Alternative 2: WebSockets

**Description**: Direct WebSocket connections between devices

**Pros**:
- Low latency bidirectional communication
- Built-in web browser support

**Cons**:
- Requires each device to maintain connections to all others (O(n²) scaling)
- No built-in message persistence or QoS
- More complex to implement pub/sub patterns

**Why Not Chosen**: Scaling concerns with full mesh topology and lack of built-in reliability features

---

## Implementation Notes

Optional section for implementation-specific details.

**Migration Path** (if applicable):
- Step-by-step plan for implementing the decision
- Rollback strategy if implementation fails

**Key Implementation Details**:
- Configuration requirements
- Library/framework versions
- Performance tuning parameters

**Testing Strategy**:
- How will the decision be validated?
- Metrics to track

**Example**:

**Migration Path**:
1. Set up Mosquitto broker on Jetson Nano (Week 1)
2. Implement MQTT client on Presto, test locally (Week 2)
3. Add T-Embed MQTT subscriber (Week 3)
4. Migrate remaining devices incrementally (Week 4-5)
5. Deprecate HTTP endpoints after all devices migrated (Week 6)

**Rollback Strategy**: Keep HTTP endpoints active for 2 weeks after MQTT migration to allow quick rollback

**Key Implementation Details**:
- Mosquitto version: 2.0.18
- MQTT client library: Paho MQTT (Python), PubSubClient (Arduino)
- QoS level: 1 for state updates, 0 for high-frequency sensors
- Keepalive interval: 60 seconds

**Testing Strategy**:
- Measure end-to-end latency with 1000 messages
- Validate message delivery during network partition scenarios
- Load test with 50 simulated devices

---

## Related Decisions

List related ADRs that provide context or depend on this decision.

- **ADR-XXX**: [Title] - [Brief description of relationship]
- **Supersedes ADR-YYY**: [Title] - This decision replaces a previous decision
- **Related to ADR-ZZZ**: [Title] - This decision builds upon or relates to another

**Example**:
- **ADR-002**: Choice of Jetson Nano as hub - MQTT broker will run on this hardware
- **Supersedes ADR-001**: HTTP-based communication - MQTT replaces previous HTTP approach
- **Related to ADR-005**: State synchronization strategy - MQTT retained messages enable this

---

## References

Links to supporting documentation, research, or resources.

- [MQTT Specification v5.0](https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html)
- [Mosquitto Documentation](https://mosquitto.org/documentation/)
- [IoT Communication Protocols Comparison](https://example.com/iot-protocols)
- Internal: `/docs/mqtt_prototype_results.md`

---

## Notes

Optional section for additional context, lessons learned, or follow-up items.

**Lessons Learned** (added after implementation):
- [What went well]
- [What could be improved]
- [Unexpected challenges]

**Follow-up Items**:
- [ ] Task 1
- [ ] Task 2

---

## Revision History

| Date | Status Change | Notes |
|------|---------------|-------|
| YYYY-MM-DD | Proposed | Initial draft |
| YYYY-MM-DD | Accepted | Approved by team |
| YYYY-MM-DD | Deprecated | Replaced by ADR-XXX |
