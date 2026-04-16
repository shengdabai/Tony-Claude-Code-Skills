---
name: iot-system-architect
description: Expert IoT system architecture covering distributed systems, event-driven design, edge computing, and microservices patterns. Use when designing multi-device systems, planning communication architecture, implementing event-driven patterns, or scaling IoT deployments. Specializes in MQTT-based architectures, state synchronization, and real-time constraints.
---

# IoT System Architect

## Overview

This skill provides expert guidance for architecting distributed IoT systems with multiple devices, edge computing, and cloud integration. It covers event-driven design patterns, microservices architecture, state management across distributed devices, and scalability considerations for production deployments.

## When to Use This Skill

Invoke this skill when:

- Designing multi-device IoT systems with distributed coordination
- Planning communication architecture and message broker topology
- Implementing event-driven patterns with MQTT or similar protocols
- Making edge computing vs cloud processing decisions
- Scaling IoT deployments beyond proof-of-concept
- Establishing state synchronization across devices
- Designing for offline-first or eventually consistent systems
- Creating architecture decision records for IoT projects
- Evaluating trade-offs between performance, reliability, and complexity

## Core Capabilities

### 1. Distributed Systems Design

Apply distributed systems principles to IoT architectures:

**Event-Driven Architecture:**
- Design pub/sub patterns with MQTT as the primary message broker
- Establish topic hierarchies that scale with device count
- Implement event sourcing for device state history
- Create idempotent message handlers to handle duplicate delivery
- Design for eventual consistency across device fleet

**CAP Theorem Trade-offs:**
- Prioritize Availability and Partition tolerance for IoT (AP systems)
- Accept eventual consistency for device states
- Implement conflict resolution strategies (last-write-wins, vector clocks, CRDTs)
- Design compensating transactions for failed operations

**Offline-First Design:**
- Enable devices to operate independently during network outages
- Queue messages locally when broker connection is lost
- Implement state reconciliation upon reconnection
- Design graceful degradation of functionality

**Data Consistency Patterns:**
- Use optimistic replication for device state
- Implement causal consistency where order matters
- Apply strong consistency only for critical operations (e.g., safety shutoffs)
- Design idempotent operations to handle message replay

### 2. Communication Architecture

Design robust communication patterns for device coordination:

**Topology Patterns:**

*Hub-and-Spoke (Argus Pattern):*
- Central hub (e.g., Jetson Nano with MQTT broker) coordinates all devices
- Devices communicate through the hub, not directly
- Simplifies message routing and state management
- Single point of failure mitigated with local device autonomy

*Mesh Networking:*
- Direct device-to-device communication when needed
- Higher complexity but better fault tolerance
- Consider for offline operation or peer coordination

**MQTT Broker Design:**
- Configure Mosquitto with appropriate QoS levels per message type
- Implement retained messages for device state
- Use persistent sessions for reliable delivery
- Set up authentication and ACLs for security

**Topic Naming Conventions:**
```
<domain>/<device_id>/<component>/<action>
Examples:
- argus/presto/timer/state
- argus/tembed/display/command
- argus/phone/notification/event
```

**Quality of Service Strategy:**
- QoS 0: Fire-and-forget for high-frequency sensor data
- QoS 1: At-least-once for commands and state updates
- QoS 2: Exactly-once for critical operations (use sparingly due to overhead)

**Message Payload Optimization:**
- Use compact JSON or binary formats (Protocol Buffers, MessagePack)
- Minimize payload size for bandwidth-constrained devices
- Batch non-urgent messages to reduce overhead
- Implement compression for larger payloads

### 3. Microservices for IoT

Decompose monolithic systems into maintainable services:

**Service Boundaries:**
- One service per device type or functional domain
- Services own their data and expose APIs
- Bounded contexts prevent tight coupling
- Each service can be developed, deployed, and scaled independently

**API Design:**
- RESTful APIs for synchronous operations (device configuration)
- Event-driven messaging for asynchronous coordination (state changes)
- WebSocket connections for real-time bidirectional communication
- GraphQL for flexible data queries from dashboards

**Service Discovery:**
- Use mDNS/Bonjour for local network discovery
- Implement service registry for dynamic environments
- Hard-code endpoints for static deployments to reduce complexity

**Inter-Service Communication:**
- MQTT for event broadcasts and state synchronization
- HTTP/REST for request-response operations
- gRPC for high-performance service-to-service calls
- Message queues (Redis Streams) for work distribution

**Failure Isolation:**
- Circuit breakers to prevent cascade failures
- Timeouts on all network operations
- Bulkhead pattern to isolate resources
- Health checks and automatic restart policies

**Container Orchestration:**
- Docker for backend service deployment
- Docker Compose for local development and small deployments
- Consider Kubernetes for large-scale production (>50 devices)
- Maintain device firmware separate from backend containers

### 4. Edge Computing Patterns

Optimize processing placement between edge and cloud:

**Processing Decision Framework:**

*Process at Edge When:*
- Real-time response required (<100ms latency)
- Bandwidth is limited or expensive
- Privacy/security requires local processing
- Operation doesn't require cloud data
- Example: Timer state transitions, button press handling

*Process at Cloud When:*
- Heavy computation required (ML inference on large models)
- Data aggregation across multiple devices needed
- Long-term storage and analytics required
- Integration with external services needed
- Example: Notification routing, usage analytics, backup

**Data Aggregation at Edge:**
- Pre-filter sensor data before sending to cloud
- Compute running averages and statistics locally
- Send only deltas or significant changes
- Batch non-urgent updates

**Real-Time Decision Making:**
- Implement state machines on devices for autonomous operation
- Use edge AI for local inference (TensorFlow Lite, ONNX Runtime)
- Maintain decision logic at the edge to survive network outages
- Update logic remotely via MQTT or OTA updates

**Bandwidth Optimization:**
- Compress data before transmission
- Use delta encoding for state updates
- Implement adaptive sampling rates based on network conditions
- Cache frequently accessed cloud data at edge

**Edge AI/ML Deployment:**
- Run inference on Jetson Nano for vision tasks
- Use TensorFlow Lite on ESP32/RP2350 for simple models
- Implement model quantization to reduce size
- Update models remotely without reflashing firmware

### 5. State Management

Synchronize state across distributed devices reliably:

**Device State Synchronization:**
- Publish state changes to MQTT with retained messages
- Subscribe to relevant device states for coordination
- Handle out-of-order message delivery gracefully
- Implement state versioning with timestamps or vector clocks

**State Machine Design:**
```
States: IDLE → RUNNING → PAUSED → COMPLETED
Events: start, pause, resume, reset, complete
Transitions: validated to prevent invalid state changes
```

- Define clear states and valid transitions
- Implement guards to prevent invalid transitions
- Publish state change events for observability
- Persist state to survive reboots

**Conflict-Free Replicated Data Types (CRDTs):**
- Use for state that multiple devices can modify
- G-Counter for increment-only values (usage statistics)
- LWW-Register for last-write-wins semantics
- OR-Set for collaborative collections

**Event Sourcing:**
- Store all state changes as immutable events
- Rebuild current state by replaying events
- Enable time-travel debugging and audit trails
- Simplify state synchronization across devices

**State Recovery:**
- Devices request current state upon reconnection
- Use MQTT retained messages for latest state
- Implement state snapshots to avoid replaying entire history
- Handle partial state during recovery gracefully

**Idempotent Operations:**
- Design operations to have the same effect if repeated
- Use unique message IDs to detect duplicates
- Implement deduplication windows for recently processed messages
- Critical for at-least-once delivery semantics

### 6. Scalability Considerations

Design systems that scale from prototype to production:

**Horizontal vs Vertical Scaling:**
- Scale MQTT broker vertically for small deployments (<100 devices)
- Scale horizontally with broker clustering for large fleets
- Use load balancers for HTTP/REST APIs
- Shard device connections across multiple broker instances

**Load Balancing Strategies:**
- Round-robin for stateless services
- Consistent hashing for affinity-based routing
- Geo-based routing for distributed deployments
- Health-aware routing to avoid overloaded instances

**Database Sharding:**
- Partition device data by device ID or device type
- Time-series databases (InfluxDB, TimescaleDB) for sensor data
- Document stores (MongoDB) for device configurations
- Use read replicas for analytics queries

**Caching Strategies:**
- Redis for session state and frequently accessed data
- Cache device states at edge to reduce broker queries
- Implement TTL-based expiration for stale data
- Use cache-aside pattern for device configurations

**Message Queue Sizing:**
- Configure broker memory limits based on device count
- Implement message TTL to prevent queue buildup
- Monitor queue depth and set up alerts
- Use dead-letter queues for failed message handling

**Connection Pooling:**
- Reuse MQTT connections across message publishes
- Pool database connections in backend services
- Implement connection retry with exponential backoff
- Set appropriate keepalive intervals

### 7. Architecture Decision Records (ADRs)

Document key architectural decisions with rationale:

**When to Create an ADR:**
- Choosing between MQTT, CoAP, or HTTP for device communication
- Selecting edge vs cloud processing for specific workloads
- Deciding on state synchronization strategy
- Evaluating database technology for device data
- Adopting new design patterns or frameworks

**ADR Template:**

Use the provided `assets/adr_template.md` to document decisions:

```markdown
# ADR-NNN: [Decision Title]

Date: YYYY-MM-DD
Status: [Proposed | Accepted | Deprecated | Superseded]

## Context
[Describe the architectural challenge and constraints]

## Decision
[State the decision clearly]

## Rationale
[Explain why this decision was made]

## Consequences
[Document trade-offs, benefits, and drawbacks]

## Alternatives Considered
[List other options and why they were rejected]
```

**Best Practices:**
- Number ADRs sequentially (ADR-001, ADR-002...)
- Keep ADRs concise (1-2 pages maximum)
- Update status as decisions evolve
- Link related ADRs
- Include performance metrics when relevant

## Architecture Principles

Follow these principles when designing IoT systems:

1. **Loose Coupling**: Devices operate independently; failure of one device doesn't cascade
2. **High Cohesion**: Group related functionality within service/device boundaries
3. **Fail-Safe**: Design for graceful degradation when network or services fail
4. **Observability**: Instrument with logging, metrics, and distributed tracing
5. **Maintainability**: Clear module boundaries, documentation, and testability
6. **Performance**: Meet real-time constraints through edge processing and optimization
7. **Security**: Defense in depth with encryption, authentication, and authorization

## Argus Reference Architecture

The Argus system provides a concrete example of these principles in practice:

**System Overview:**
```
┌─────────────────────────────────────────────┐
│         Android Device (Pixel Pro)          │
│     [Notification Bridge & Control]         │
└────────────┬──────────────┬─────────────────┘
             │ BLE          │
             ▼              ▼
    ┌──────────────┐  ┌──────────────┐
    │   Presto     │  │   T-Embed    │
    │  (Central)   │◄─┤   (Desk)     │
    │ RP2350+4"    │  │ ESP32-S3     │
    └──────┬───────┘  └──────┬───────┘
           │ MQTT            │ MQTT
           └────────┬────────┘
                    ▼
         ┌─────────────────────┐
         │   Jetson Nano       │
         │ [MQTT Broker+AI]    │
         └─────────┬───────────┘
                   │ WebSocket
                   ▼
         ┌─────────────────────┐
         │   Stream Deck Neo   │
         │  [Macro Control]    │
         └─────────────────────┘
```

**Key Architectural Patterns Applied:**

- **Observer Pattern**: All devices subscribe to timer state changes via MQTT
- **State Pattern**: Timer implements multiple operating modes (work, break, long break)
- **Strategy Pattern**: Different timing strategies (Pomodoro, custom intervals)
- **Publish-Subscribe**: Core communication model enables loose coupling
- **Singleton**: MQTT broker connection shared across device handlers

**Multi-Device State Synchronization:**
1. Presto publishes timer state to `argus/presto/timer/state`
2. T-Embed subscribes and updates display accordingly
3. Phone receives notifications via BLE bridge
4. Stream Deck reflects current state via WebSocket connection

**Fallback Behavior During Outages:**
- Presto operates autonomously if MQTT broker is down
- T-Embed shows "disconnected" status but retains last known state
- Phone queues notifications until BLE connection restored
- System auto-recovers when connectivity returns

**Scalable MQTT Topic Structure:**
```
argus/
├── presto/
│   ├── timer/state          (retained, QoS 1)
│   ├── timer/command        (QoS 1)
│   └── button/event         (QoS 0)
├── tembed/
│   ├── display/state        (retained, QoS 1)
│   └── display/command      (QoS 1)
├── phone/
│   ├── notification/event   (QoS 1)
│   └── notification/ack     (QoS 1)
└── system/
    ├── health               (QoS 0, periodic)
    └── logs                 (QoS 0)
```

For detailed design patterns and examples, see `references/design_patterns.md` and `references/argus_architecture.md`.

## Diagramming and Modeling

Use these techniques to communicate architecture effectively:

**System Context Diagram (C4 Level 1):**
- Show the system and its users/external systems
- Identify system boundary and key interactions

**Container Diagram (C4 Level 2):**
- Show major containers (devices, services, databases)
- Illustrate communication protocols and dependencies

**Sequence Diagrams:**
- Document multi-device interaction flows
- Show message ordering and timing constraints
- Highlight error and retry scenarios

**State Diagrams:**
- Model device state machines
- Document valid transitions and guards
- Clarify complex stateful behavior

**Data Flow Diagrams:**
- Trace data through the system
- Identify transformation points
- Highlight aggregation and filtering

**Deployment Diagrams:**
- Show physical device placement
- Document network topology
- Illustrate container orchestration

## Resources

This skill includes bundled resources for reference and templates:

### references/

- **`design_patterns.md`**: Comprehensive catalog of design patterns for IoT systems with examples and anti-patterns
- **`argus_architecture.md`**: Detailed Argus system architecture including component specifications and implementation details

Load these references when working on complex architectural decisions or needing detailed pattern examples.

### assets/

- **`adr_template.md`**: Architecture Decision Record template for documenting key design decisions

Copy this template when creating new ADRs for IoT projects.
