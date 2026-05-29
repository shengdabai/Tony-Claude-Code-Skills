# Multi-Agent System Observability Guide

## Why Observability Matters for Agent Systems

Multi-agent systems are inherently complex and unpredictable:

- **Emergent behavior** - Agents interact in unexpected ways
- **Long execution chains** - Hard to trace where things went wrong
- **Non-deterministic** - Same input can produce different outputs
- **Cost implications** - Token usage can spiral out of control
- **Debugging difficulty** - Black box interactions between agents

**Without observability, you're flying blind.**

## Core Observability Pillars

### 1. Tracing (Execution Flow)
Track the sequence of agent actions, tool calls, and decisions

### 2. Logging (Events)
Record all significant events for debugging and audit

### 3. Metrics (Performance)
Measure cost, latency, success rates, and resource usage

### 4. Visualization (Understanding)
Make complex workflows comprehensible to humans

## Tracing Multi-Agent Workflows

### Basic Tracing Pattern

```python
import uuid
from datetime import datetime
from typing import List, Dict
import json

class Trace:
    """Simple tracing for agent workflows"""

    def __init__(self, workflow_name: str):
        self.workflow_name = workflow_name
        self.trace_id = str(uuid.uuid4())
        self.spans = []
        self.start_time = datetime.now()

    def start_span(self, name: str, metadata: Dict = None) -> str:
        """Start a new span (sub-operation)"""
        span_id = str(uuid.uuid4())
        span = {
            "span_id": span_id,
            "name": name,
            "start_time": datetime.now().isoformat(),
            "metadata": metadata or {},
            "status": "running"
        }
        self.spans.append(span)
        return span_id

    def end_span(self, span_id: str, result: any = None, error: str = None):
        """End a span"""
        for span in self.spans:
            if span["span_id"] == span_id:
                span["end_time"] = datetime.now().isoformat()
                span["status"] = "error" if error else "success"
                if result:
                    span["result"] = str(result)
                if error:
                    span["error"] = error
                break

    def export(self) -> str:
        """Export trace as JSON"""
        return json.dumps({
            "trace_id": self.trace_id,
            "workflow": self.workflow_name,
            "start_time": self.start_time.isoformat(),
            "spans": self.spans
        }, indent=2)

# Usage
trace = Trace("research-write-review")

# Trace research step
research_span = trace.start_span("research", {"agent": "researcher"})
research_result = researcher.run("Research AI frameworks")
trace.end_span(research_span, result=research_result)

# Trace writing step
write_span = trace.start_span("write", {"agent": "writer"})
write_result = writer.run(f"Write based on: {research_result}")
trace.end_span(write_span, result=write_result)

# Export
print(trace.export())
```

### OpenTelemetry Integration

**Industry-standard tracing**

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, BatchSpanProcessor

# Setup
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Add exporter (Console, Jaeger, etc.)
span_processor = BatchSpanProcessor(ConsoleSpanExporter())
trace.get_tracer_provider().add_span_processor(span_processor)

# Instrument agent
def traced_agent_run(agent_name: str, message: str):
    with tracer.start_as_current_span(f"agent.{agent_name}") as span:
        span.set_attribute("agent.name", agent_name)
        span.set_attribute("agent.input", message)

        try:
            result = agent.run(message)
            span.set_attribute("agent.output", result)
            return result
        except Exception as e:
            span.record_exception(e)
            span.set_status(trace.Status(trace.StatusCode.ERROR))
            raise

# Usage
result = traced_agent_run("researcher", "Research topic")
```

### LangSmith for LangChain

**Best-in-class for LangChain applications**

```python
import os
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = "your-key"
os.environ["LANGCHAIN_PROJECT"] = "my-agent-project"

# All LangChain operations automatically traced
chain = prompt | model | output_parser
result = chain.invoke({"input": "test"})

# View traces at https://smith.langchain.com
```

**Custom tags for filtering:**
```python
from langchain.callbacks import tracing_v2_enabled

with tracing_v2_enabled(
    project_name="my-project",
    tags=["production", "customer-123"]
):
    result = chain.invoke({"input": "test"})
```

## Logging Best Practices

### Structured Logging

**Use JSON for machine-readable logs**

```python
import logging
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    """Format logs as JSON"""

    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Add extra fields
        if hasattr(record, "agent_name"):
            log_data["agent_name"] = record.agent_name
        if hasattr(record, "trace_id"):
            log_data["trace_id"] = record.trace_id

        return json.dumps(log_data)

# Setup
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger = logging.getLogger("agent-system")
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# Usage
logger.info("Agent started", extra={
    "agent_name": "researcher",
    "trace_id": "abc-123"
})
```

### What to Log

**Essential events:**

```python
# 1. Agent lifecycle
logger.info("Agent started", extra={"agent": "researcher"})
logger.info("Agent completed", extra={"agent": "researcher", "duration": 5.2})

# 2. Tool calls
logger.info("Tool called", extra={
    "tool": "search",
    "arguments": {"query": "AI frameworks"}
})

# 3. Errors and retries
logger.error("LLM call failed", extra={
    "error": str(e),
    "retry_count": 2
})

# 4. Cost tracking
logger.info("Tokens used", extra={
    "prompt_tokens": 100,
    "completion_tokens": 200,
    "total_cost": 0.015
})

# 5. Decision points
logger.info("Routing decision", extra={
    "condition": "quality_score < 0.8",
    "next_agent": "reviewer"
})
```

### Log Levels Guide

```python
# DEBUG: Detailed diagnostic info (disabled in production)
logger.debug("Prompt constructed", extra={"prompt": full_prompt})

# INFO: Confirmation of normal operation
logger.info("Agent completed task successfully")

# WARNING: Unexpected but handled situations
logger.warning("Rate limit approached, slowing down")

# ERROR: Errors that didn't stop execution
logger.error("Tool call failed, using fallback")

# CRITICAL: Severe errors stopping execution
logger.critical("System out of memory, shutting down")
```

## Metrics Collection

### Key Metrics to Track

**Performance Metrics:**
- Latency (total and per-agent)
- Token usage (prompt, completion, total)
- Cost per request
- Throughput (requests per minute)

**Quality Metrics:**
- Success rate
- Error rate
- Retry count
- User satisfaction scores

**Resource Metrics:**
- Active agents
- Queue depth
- Memory usage
- Tool call frequency

### Prometheus Integration

```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time

# Define metrics
agent_requests = Counter(
    'agent_requests_total',
    'Total agent requests',
    ['agent_name', 'status']
)

agent_duration = Histogram(
    'agent_duration_seconds',
    'Agent execution duration',
    ['agent_name']
)

agent_tokens = Counter(
    'agent_tokens_total',
    'Total tokens used',
    ['agent_name', 'type']
)

active_agents = Gauge(
    'agent_active_count',
    'Number of active agents'
)

# Instrument agent
def monitored_agent_run(agent_name: str, message: str):
    active_agents.inc()
    start_time = time.time()

    try:
        result = agent.run(message)
        agent_requests.labels(agent_name=agent_name, status='success').inc()
        return result

    except Exception as e:
        agent_requests.labels(agent_name=agent_name, status='error').inc()
        raise

    finally:
        duration = time.time() - start_time
        agent_duration.labels(agent_name=agent_name).observe(duration)
        active_agents.dec()

        # Track tokens
        agent_tokens.labels(
            agent_name=agent_name,
            type='prompt'
        ).inc(agent.prompt_tokens)

        agent_tokens.labels(
            agent_name=agent_name,
            type='completion'
        ).inc(agent.completion_tokens)

# Start metrics server
start_http_server(8000)  # Metrics at http://localhost:8000/metrics
```

### Simple In-Memory Metrics

```python
from collections import defaultdict
import statistics

class MetricsCollector:
    """Simple metrics collection"""

    def __init__(self):
        self.counters = defaultdict(int)
        self.histograms = defaultdict(list)

    def increment(self, metric: str, value: int = 1, labels: dict = None):
        """Increment a counter"""
        key = self._key(metric, labels)
        self.counters[key] += value

    def observe(self, metric: str, value: float, labels: dict = None):
        """Record a histogram value"""
        key = self._key(metric, labels)
        self.histograms[key].append(value)

    def _key(self, metric: str, labels: dict = None):
        """Generate metric key with labels"""
        if labels:
            label_str = ",".join(f"{k}={v}" for k, v in sorted(labels.items()))
            return f"{metric}{{{label_str}}}"
        return metric

    def report(self):
        """Generate metrics report"""
        report = {"counters": dict(self.counters), "histograms": {}}

        for metric, values in self.histograms.items():
            report["histograms"][metric] = {
                "count": len(values),
                "mean": statistics.mean(values),
                "median": statistics.median(values),
                "p95": sorted(values)[int(len(values) * 0.95)] if values else 0,
                "max": max(values) if values else 0
            }

        return report

# Usage
metrics = MetricsCollector()

# Track events
metrics.increment("agent.requests", labels={"agent": "researcher"})
metrics.observe("agent.duration", 2.5, labels={"agent": "researcher"})

# Generate report
print(json.dumps(metrics.report(), indent=2))
```

## Cost Tracking

### Real-Time Cost Monitoring

```python
class CostTracker:
    """Track LLM costs"""

    # Pricing per 1K tokens (as of 2024)
    PRICING = {
        "gpt-4": {"prompt": 0.03, "completion": 0.06},
        "gpt-4-turbo": {"prompt": 0.01, "completion": 0.03},
        "gpt-3.5-turbo": {"prompt": 0.0015, "completion": 0.002},
        "claude-3-opus": {"prompt": 0.015, "completion": 0.075},
        "claude-3-sonnet": {"prompt": 0.003, "completion": 0.015}
    }

    def __init__(self):
        self.total_cost = 0.0
        self.cost_by_agent = defaultdict(float)
        self.cost_by_model = defaultdict(float)

    def track(
        self,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
        agent_name: str = None
    ):
        """Track cost for an LLM call"""
        if model not in self.PRICING:
            logger.warning(f"Unknown model pricing: {model}")
            return

        pricing = self.PRICING[model]

        # Calculate cost
        prompt_cost = (prompt_tokens / 1000) * pricing["prompt"]
        completion_cost = (completion_tokens / 1000) * pricing["completion"]
        total = prompt_cost + completion_cost

        # Update totals
        self.total_cost += total
        self.cost_by_model[model] += total
        if agent_name:
            self.cost_by_agent[agent_name] += total

        return total

    def get_report(self) -> dict:
        """Get cost report"""
        return {
            "total_cost": round(self.total_cost, 4),
            "by_agent": {k: round(v, 4) for k, v in self.cost_by_agent.items()},
            "by_model": {k: round(v, 4) for k, v in self.cost_by_model.items()}
        }

    def alert_if_over_budget(self, budget: float):
        """Alert if over budget"""
        if self.total_cost > budget:
            logger.critical(
                f"Budget exceeded! Cost: ${self.total_cost:.2f}, Budget: ${budget:.2f}"
            )

# Usage
cost_tracker = CostTracker()

# After each LLM call
cost = cost_tracker.track(
    model="gpt-4",
    prompt_tokens=500,
    completion_tokens=200,
    agent_name="researcher"
)

print(f"Call cost: ${cost:.4f}")

# Check budget
cost_tracker.alert_if_over_budget(budget=10.0)

# Final report
print(json.dumps(cost_tracker.get_report(), indent=2))
```

## Debugging Stuck Agents

### Timeout Detection

```python
import signal
from contextlib import contextmanager

@contextmanager
def timeout(seconds: int):
    """Context manager for timeouts"""

    def timeout_handler(signum, frame):
        raise TimeoutError(f"Operation timed out after {seconds} seconds")

    # Set alarm
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(seconds)

    try:
        yield
    finally:
        signal.alarm(0)  # Disable alarm

# Usage
try:
    with timeout(30):
        result = agent.run("Complex query")
except TimeoutError as e:
    logger.error("Agent stuck", extra={
        "agent": "researcher",
        "timeout": 30,
        "last_action": agent.last_action
    })
```

### Loop Detection

```python
class LoopDetector:
    """Detect infinite loops in agent behavior"""

    def __init__(self, window_size: int = 5):
        self.window_size = window_size
        self.action_history = []

    def check(self, action: str) -> bool:
        """Check if agent is looping"""
        self.action_history.append(action)

        # Keep only recent history
        if len(self.action_history) > self.window_size:
            self.action_history.pop(0)

        # Check for loops
        if len(self.action_history) == self.window_size:
            # All actions the same?
            if len(set(self.action_history)) == 1:
                logger.warning(
                    f"Loop detected: same action repeated {self.window_size} times",
                    extra={"action": action}
                )
                return True

        return False

# Usage
loop_detector = LoopDetector(window_size=3)

for iteration in range(max_iterations):
    action = agent.get_next_action()

    if loop_detector.check(action):
        logger.error("Agent in infinite loop, aborting")
        break

    agent.execute(action)
```

## Visualization

### Execution Timeline

```python
import matplotlib.pyplot as plt
from datetime import datetime

def visualize_timeline(spans: List[Dict]):
    """Visualize agent execution timeline"""

    fig, ax = plt.subplots(figsize=(12, 6))

    for i, span in enumerate(spans):
        start = datetime.fromisoformat(span["start_time"])
        end = datetime.fromisoformat(span["end_time"])
        duration = (end - start).total_seconds()

        # Color by status
        color = "green" if span["status"] == "success" else "red"

        # Draw bar
        ax.barh(i, duration, left=0, color=color, alpha=0.7)
        ax.text(duration / 2, i, span["name"], ha="center", va="center")

    ax.set_yticks(range(len(spans)))
    ax.set_yticklabels([s["name"] for s in spans])
    ax.set_xlabel("Duration (seconds)")
    ax.set_title("Agent Execution Timeline")

    plt.tight_layout()
    plt.savefig("timeline.png")

# Usage
visualize_timeline(trace.spans)
```

### Agent Interaction Graph

```python
import networkx as nx
import matplotlib.pyplot as plt

def visualize_agent_graph(interactions: List[Dict]):
    """Visualize agent interactions as graph"""

    G = nx.DiGraph()

    # Add edges (agent interactions)
    for interaction in interactions:
        source = interaction["from_agent"]
        target = interaction["to_agent"]
        G.add_edge(source, target)

    # Draw
    pos = nx.spring_layout(G)
    nx.draw(
        G, pos,
        with_labels=True,
        node_color="lightblue",
        node_size=3000,
        font_size=10,
        font_weight="bold",
        arrows=True
    )

    plt.title("Agent Interaction Graph")
    plt.savefig("agent_graph.png")

# Usage
interactions = [
    {"from_agent": "user", "to_agent": "researcher"},
    {"from_agent": "researcher", "to_agent": "writer"},
    {"from_agent": "writer", "to_agent": "reviewer"},
]

visualize_agent_graph(interactions)
```

## Dashboard Example

### Streamlit Monitoring Dashboard

```python
import streamlit as st
import pandas as pd

st.title("Agent System Dashboard")

# Metrics
col1, col2, col3, col4 = st.columns(4)
col1.metric("Total Requests", metrics.counters["requests"])
col2.metric("Success Rate", f"{success_rate:.1%}")
col3.metric("Total Cost", f"${total_cost:.2f}")
col4.metric("Avg Latency", f"{avg_latency:.2f}s")

# Cost breakdown
st.subheader("Cost by Agent")
cost_df = pd.DataFrame([
    {"Agent": k, "Cost": v}
    for k, v in cost_tracker.cost_by_agent.items()
])
st.bar_chart(cost_df.set_index("Agent"))

# Recent errors
st.subheader("Recent Errors")
errors_df = pd.DataFrame(recent_errors)
st.dataframe(errors_df)

# Latency over time
st.subheader("Latency Trend")
st.line_chart(latency_history)
```

## Production Observability Stack

### Recommended Stack

**Logging:** ELK Stack (Elasticsearch, Logstash, Kibana) or Loki
**Tracing:** Jaeger or Tempo
**Metrics:** Prometheus + Grafana
**Alerting:** Prometheus Alertmanager or PagerDuty
**Cost Tracking:** Custom dashboard + CloudWatch/DataDog

### Quick Setup with Docker Compose

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    depends_on:
      - prometheus

  jaeger:
    image: jaegertracing/all-in-one
    ports:
      - "16686:16686"  # UI
      - "6831:6831/udp"  # Agent

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.0.0
    environment:
      - discovery.type=single-node

  kibana:
    image: docker.elastic.co/kibana/kibana:8.0.0
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
```

## Alerting

### Cost Alerts

```python
def check_cost_alerts(cost_tracker: CostTracker):
    """Check and send cost alerts"""

    # Alert if cost exceeds threshold
    if cost_tracker.total_cost > 100:
        send_alert(
            severity="critical",
            message=f"Cost exceeded $100: ${cost_tracker.total_cost:.2f}",
            channel="slack"
        )

    # Alert on abnormal agent cost
    for agent, cost in cost_tracker.cost_by_agent.items():
        if cost > 20:  # Per-agent threshold
            send_alert(
                severity="warning",
                message=f"Agent '{agent}' cost high: ${cost:.2f}",
                channel="email"
            )
```

### Error Rate Alerts

```python
def check_error_rate(metrics: MetricsCollector):
    """Check error rates"""

    total = metrics.counters.get("requests", 0)
    errors = metrics.counters.get("errors", 0)

    if total > 0:
        error_rate = errors / total

        if error_rate > 0.1:  # 10% error rate
            send_alert(
                severity="critical",
                message=f"Error rate: {error_rate:.1%}",
                channel="pagerduty"
            )
```

## Best Practices Summary

1. **Always enable tracing** in production
2. **Use structured logging** (JSON format)
3. **Track costs in real-time** to avoid surprises
4. **Set up dashboards** for key metrics
5. **Configure alerts** for anomalies
6. **Implement timeouts** to catch stuck agents
7. **Detect loops** automatically
8. **Log all tool calls** for debugging
9. **Version your prompts** to track changes
10. **Regular monitoring reviews** to improve system
