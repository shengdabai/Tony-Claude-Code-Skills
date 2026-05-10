# Production Deployment Patterns for Agent Systems

## Deployment Architectures

### 1. Synchronous API Pattern

**When to use:** Simple workflows, low latency requirements

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

class AgentRequest(BaseModel):
    message: str
    agent_type: str = "researcher"

class AgentResponse(BaseModel):
    result: str
    cost: float
    duration: float

@app.post("/agent/run")
async def run_agent(request: AgentRequest) -> AgentResponse:
    """Synchronous agent execution"""
    try:
        start_time = time.time()

        # Get agent
        agent = get_agent(request.agent_type)

        # Execute
        result = agent.run(request.message)

        return AgentResponse(
            result=result,
            cost=agent.total_cost,
            duration=time.time() - start_time
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

**Characteristics:**
- ✅ Simple implementation
- ✅ Easy to debug
- ❌ Client waits for completion
- ❌ Timeout issues with long workflows

### 2. Async Task Queue Pattern

**When to use:** Long-running workflows, high scalability needs

```python
from celery import Celery
from fastapi import FastAPI, BackgroundTasks
import redis

# Celery setup
celery_app = Celery(
    "agent_tasks",
    broker="redis://localhost:6379/0",
    backend="redis://localhost:6379/1"
)

@celery_app.task
def run_agent_task(agent_type: str, message: str, task_id: str):
    """Background agent task"""
    try:
        agent = get_agent(agent_type)
        result = agent.run(message)

        # Store result
        redis_client.set(f"result:{task_id}", json.dumps({
            "status": "completed",
            "result": result,
            "cost": agent.total_cost
        }))

    except Exception as e:
        redis_client.set(f"result:{task_id}", json.dumps({
            "status": "failed",
            "error": str(e)
        }))

# FastAPI endpoints
api = FastAPI()

@api.post("/agent/run")
async def run_agent_async(request: AgentRequest):
    """Submit async agent task"""
    task_id = str(uuid.uuid4())

    # Queue task
    run_agent_task.delay(request.agent_type, request.message, task_id)

    return {"task_id": task_id, "status": "queued"}

@api.get("/agent/status/{task_id}")
async def get_status(task_id: str):
    """Check task status"""
    result = redis_client.get(f"result:{task_id}")

    if not result:
        return {"status": "processing"}

    return json.loads(result)
```

**Characteristics:**
- ✅ Non-blocking API
- ✅ Horizontal scaling
- ✅ Handles long workflows
- ❌ More complex setup
- ❌ Result polling needed

### 3. Serverless Pattern

**When to use:** Unpredictable load, pay-per-use

```python
# AWS Lambda handler
import json
import boto3

def lambda_handler(event, context):
    """Serverless agent execution"""

    # Parse request
    body = json.loads(event["body"])
    message = body["message"]

    # Run agent (with strict timeout)
    try:
        agent = get_agent("researcher")
        result = agent.run(message)

        return {
            "statusCode": 200,
            "body": json.dumps({"result": result})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
```

**Deployment (Serverless Framework):**
```yaml
service: agent-api

provider:
  name: aws
  runtime: python3.11
  timeout: 300  # 5 minutes max

functions:
  runAgent:
    handler: handler.lambda_handler
    events:
      - http:
          path: agent/run
          method: post
    environment:
      OPENAI_API_KEY: ${env:OPENAI_API_KEY}
```

**Characteristics:**
- ✅ Auto-scaling
- ✅ Pay per invocation
- ✅ Zero infrastructure management
- ❌ Cold start latency
- ❌ Execution time limits

### 4. Stream Processing Pattern

**When to use:** Real-time responses, better UX

```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse

app = FastAPI()

async def agent_stream(message: str):
    """Stream agent responses"""
    agent = StreamingAgent()

    async for chunk in agent.run_stream(message):
        yield f"data: {json.dumps({'chunk': chunk})}\n\n"

    yield "data: [DONE]\n\n"

@app.post("/agent/stream")
async def stream_agent(request: AgentRequest):
    """Stream agent output"""
    return StreamingResponse(
        agent_stream(request.message),
        media_type="text/event-stream"
    )
```

**Frontend (JavaScript):**
```javascript
const eventSource = new EventSource('/agent/stream');

eventSource.onmessage = (event) => {
  if (event.data === '[DONE]') {
    eventSource.close();
    return;
  }

  const data = JSON.parse(event.data);
  updateUI(data.chunk);
};
```

## Scaling Strategies

### Horizontal Scaling

**Pattern:** Multiple agent workers behind load balancer

```yaml
# docker-compose.yml
version: '3.8'

services:
  nginx:
    image: nginx
    ports:
      - "80:80"
    depends_on:
      - agent-worker-1
      - agent-worker-2
      - agent-worker-3

  agent-worker-1:
    image: agent-api:latest
    environment:
      - WORKER_ID=1

  agent-worker-2:
    image: agent-api:latest
    environment:
      - WORKER_ID=2

  agent-worker-3:
    image: agent-api:latest
    environment:
      - WORKER_ID=3

  redis:
    image: redis:7
    ports:
      - "6379:6379"
```

### Worker Pool Pattern

```python
from multiprocessing import Pool

class AgentWorkerPool:
    """Pool of agent workers"""

    def __init__(self, num_workers: int = 4):
        self.pool = Pool(num_workers)

    def run_parallel(self, tasks: List[Dict]) -> List[Any]:
        """Execute tasks in parallel"""
        results = self.pool.map(self._run_task, tasks)
        return results

    def _run_task(self, task: Dict) -> Any:
        """Run single task"""
        agent = get_agent(task["agent_type"])
        return agent.run(task["message"])

# Usage
pool = AgentWorkerPool(num_workers=4)
tasks = [
    {"agent_type": "researcher", "message": "Query 1"},
    {"agent_type": "researcher", "message": "Query 2"},
    {"agent_type": "writer", "message": "Query 3"},
]

results = pool.run_parallel(tasks)
```

## Fault Tolerance

### Retry Pattern

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10),
    reraise=True
)
def resilient_agent_run(agent_type: str, message: str) -> str:
    """Agent execution with retries"""
    agent = get_agent(agent_type)
    return agent.run(message)

# Usage
try:
    result = resilient_agent_run("researcher", "Query")
except Exception as e:
    logger.error(f"Failed after 3 retries: {e}")
```

### Circuit Breaker Pattern

```python
from circuitbreaker import circuit

@circuit(failure_threshold=5, recovery_timeout=60)
def call_external_api(endpoint: str) -> Dict:
    """Call with circuit breaker"""
    response = requests.get(endpoint, timeout=10)
    response.raise_for_status()
    return response.json()

# Usage - will open circuit after 5 failures
try:
    data = call_external_api("https://api.example.com/data")
except CircuitBreakerError:
    logger.error("Circuit open, using fallback")
    data = get_cached_data()
```

### Graceful Degradation

```python
class ResilientAgent:
    """Agent with fallback strategies"""

    def __init__(self):
        self.primary_model = "gpt-4"
        self.fallback_model = "gpt-3.5-turbo"

    def run(self, message: str) -> str:
        """Run with fallback"""
        try:
            # Try primary model
            return self._run_with_model(message, self.primary_model)

        except Exception as e:
            logger.warning(f"Primary model failed: {e}, using fallback")

            try:
                # Try fallback model
                return self._run_with_model(message, self.fallback_model)

            except Exception as e2:
                logger.error(f"Fallback failed: {e2}, using cached response")

                # Use cached/default response
                return self._get_cached_response(message)

    def _run_with_model(self, message: str, model: str) -> str:
        # Implementation
        pass

    def _get_cached_response(self, message: str) -> str:
        # Return cached or default response
        return "Service temporarily unavailable. Please try again."
```

## Security

### API Authentication

```python
from fastapi import Depends, HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt

security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    """Verify JWT token"""
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return payload

    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

@app.post("/agent/run")
async def run_agent(
    request: AgentRequest,
    user = Depends(verify_token)
):
    """Protected endpoint"""
    logger.info(f"Request from user: {user['user_id']}")

    # Track usage per user
    track_usage(user["user_id"], request)

    # Execute agent
    result = agent.run(request.message)
    return {"result": result}
```

### Rate Limiting

```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.post("/agent/run")
@limiter.limit("10/minute")  # 10 requests per minute
async def run_agent(request: Request, agent_request: AgentRequest):
    """Rate-limited endpoint"""
    result = agent.run(agent_request.message)
    return {"result": result}
```

### Input Validation

```python
from pydantic import BaseModel, validator, Field

class AgentRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=5000)
    agent_type: str = Field(..., regex="^[a-z_]+$")
    max_iterations: int = Field(default=10, ge=1, le=20)

    @validator("message")
    def validate_message(cls, v):
        """Validate message content"""
        # Check for malicious patterns
        dangerous = ["<script>", "DROP TABLE", "'; DELETE"]
        if any(d in v for d in dangerous):
            raise ValueError("Invalid input detected")

        return v
```

### Prompt Injection Protection

```python
def sanitize_input(user_input: str) -> str:
    """Basic prompt injection protection"""

    # Remove system-like instructions
    dangerous_patterns = [
        "ignore previous instructions",
        "you are now",
        "forget everything",
        "new role:",
        "system:",
        "assistant:"
    ]

    lower_input = user_input.lower()
    for pattern in dangerous_patterns:
        if pattern in lower_input:
            logger.warning(f"Potential prompt injection: {pattern}")
            # Optionally reject or sanitize
            user_input = user_input.replace(pattern, "[REDACTED]")

    return user_input

# Usage
safe_input = sanitize_input(user_input)
result = agent.run(safe_input)
```

## Cost Management

### Budget Limits

```python
class BudgetLimitedAgent:
    """Agent with budget enforcement"""

    def __init__(self, budget: float):
        self.budget = budget
        self.cost_tracker = CostTracker()

    def run(self, message: str) -> str:
        """Run with budget check"""

        # Check budget before execution
        if self.cost_tracker.total_cost >= self.budget:
            raise BudgetExceededError(
                f"Budget exceeded: ${self.cost_tracker.total_cost:.2f} / ${self.budget:.2f}"
            )

        # Execute with cost tracking
        result = self._run_with_tracking(message)

        # Check budget after execution
        if self.cost_tracker.total_cost > self.budget:
            logger.warning(
                f"Budget exceeded during execution: ${self.cost_tracker.total_cost:.2f}"
            )

        return result

    def _run_with_tracking(self, message: str) -> str:
        # Execute and track costs
        pass
```

### Token Limiting

```python
def limit_context_window(messages: List[Dict], max_tokens: int = 4000) -> List[Dict]:
    """Limit conversation context to max tokens"""
    import tiktoken

    encoding = tiktoken.encoding_for_model("gpt-4")
    total_tokens = 0
    limited_messages = []

    # Keep most recent messages that fit in budget
    for message in reversed(messages):
        message_tokens = len(encoding.encode(message["content"]))

        if total_tokens + message_tokens > max_tokens:
            break

        limited_messages.insert(0, message)
        total_tokens += message_tokens

    return limited_messages
```

### Cost Alerts

```python
import smtplib
from email.mime.text import MIMEText

def send_cost_alert(cost: float, threshold: float):
    """Send email alert when cost exceeds threshold"""
    if cost < threshold:
        return

    msg = MIMEText(f"Agent cost alert: ${cost:.2f} exceeds threshold ${threshold:.2f}")
    msg["Subject"] = "Agent Cost Alert"
    msg["From"] = "alerts@example.com"
    msg["To"] = "admin@example.com"

    with smtplib.SMTP("localhost") as server:
        server.send_message(msg)

# Monitor and alert
if cost_tracker.total_cost > 100:
    send_cost_alert(cost_tracker.total_cost, threshold=100)
```

## Monitoring in Production

### Health Checks

```python
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    checks = {
        "api": "healthy",
        "database": check_database(),
        "redis": check_redis(),
        "openai": check_openai_api()
    }

    # Overall status
    status = "healthy" if all(v == "healthy" for v in checks.values()) else "unhealthy"

    return {
        "status": status,
        "checks": checks,
        "timestamp": datetime.now().isoformat()
    }

def check_openai_api() -> str:
    """Check OpenAI API connectivity"""
    try:
        openai.Model.list()
        return "healthy"
    except Exception:
        return "unhealthy"
```

### Readiness Probe

```python
@app.get("/ready")
async def readiness_check():
    """Readiness probe for k8s"""

    # Check if agent is initialized
    if not agent_initialized:
        return JSONResponse(
            status_code=503,
            content={"ready": False, "reason": "Agent not initialized"}
        )

    # Check if resources are available
    if active_requests > max_concurrent_requests:
        return JSONResponse(
            status_code=503,
            content={"ready": False, "reason": "Too many active requests"}
        )

    return {"ready": True}
```

## Kubernetes Deployment

### Deployment Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: agent-api
  template:
    metadata:
      labels:
        app: agent-api
    spec:
      containers:
      - name: agent-api
        image: agent-api:latest
        ports:
        - containerPort: 8000
        env:
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: openai
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: agent-api-service
spec:
  selector:
    app: agent-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: LoadBalancer
```

### Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: agent-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: agent-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Testing in Production

### Canary Deployment

```yaml
# Primary deployment (90% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-api-stable
spec:
  replicas: 9
  # ... deployment spec

---
# Canary deployment (10% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-api-canary
spec:
  replicas: 1
  # ... new version spec

---
# Service routes to both
apiVersion: v1
kind: Service
metadata:
  name: agent-api
spec:
  selector:
    app: agent-api  # Matches both deployments
```

### Feature Flags

```python
import os

FEATURE_FLAGS = {
    "use_new_model": os.getenv("FEATURE_NEW_MODEL", "false") == "true",
    "enable_caching": os.getenv("FEATURE_CACHING", "false") == "true",
}

def run_agent(message: str) -> str:
    """Run agent with feature flags"""

    if FEATURE_FLAGS["use_new_model"]:
        agent = NewModelAgent()
    else:
        agent = StandardAgent()

    if FEATURE_FLAGS["enable_caching"]:
        agent.enable_cache()

    return agent.run(message)
```

## Disaster Recovery

### Backup Strategy

```python
import boto3
from datetime import datetime

def backup_agent_state(agent_id: str):
    """Backup agent state to S3"""
    s3 = boto3.client("s3")

    # Collect state
    state = {
        "agent_id": agent_id,
        "conversation_history": agent.conversation_history,
        "memory": agent.memory.export(),
        "metrics": agent.get_metrics(),
        "timestamp": datetime.now().isoformat()
    }

    # Upload to S3
    key = f"backups/{agent_id}/{datetime.now():%Y%m%d-%H%M%S}.json"
    s3.put_object(
        Bucket="agent-backups",
        Key=key,
        Body=json.dumps(state)
    )

# Periodic backups
schedule.every(1).hour.do(lambda: backup_agent_state("main-agent"))
```

### State Recovery

```python
def recover_agent_state(agent_id: str, timestamp: str = None):
    """Recover agent from backup"""
    s3 = boto3.client("s3")

    if not timestamp:
        # Get latest backup
        response = s3.list_objects_v2(
            Bucket="agent-backups",
            Prefix=f"backups/{agent_id}/",
            MaxKeys=1
        )
        key = response["Contents"][0]["Key"]
    else:
        key = f"backups/{agent_id}/{timestamp}.json"

    # Download state
    obj = s3.get_object(Bucket="agent-backups", Key=key)
    state = json.loads(obj["Body"].read())

    # Restore agent
    agent.conversation_history = state["conversation_history"]
    agent.memory.restore(state["memory"])

    return agent
```

## Best Practices Summary

1. **Use async patterns** for long-running workflows
2. **Implement health checks** for all services
3. **Set up proper monitoring** before production
4. **Enforce rate limits** to prevent abuse
5. **Implement circuit breakers** for external dependencies
6. **Use secrets management** for API keys
7. **Enable auto-scaling** for variable load
8. **Test with chaos engineering** to verify resilience
9. **Implement gradual rollouts** for new versions
10. **Have disaster recovery plan** with backups
