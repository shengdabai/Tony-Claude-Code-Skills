# Custom Agent System Design Guide

## When to Build Custom

### Build Custom When:

1. **Minimal Requirements**
   - Single-purpose agent with well-defined scope
   - No need for multi-agent collaboration
   - Simple tool integration

2. **Performance Critical**
   - Framework overhead is unacceptable
   - Need maximum control over execution
   - Optimizing for speed and cost

3. **Unique Architecture**
   - Requirements don't match framework patterns
   - Need custom orchestration logic
   - Special state management needs

4. **Learning Exercise**
   - Want to understand agents deeply
   - Building educational prototype
   - Experimenting with novel patterns

5. **Integration Constraints**
   - Must integrate with existing systems
   - Framework dependencies conflict
   - Special deployment requirements

### Use Framework When:

1. **Standard Patterns** - Workflow matches framework patterns
2. **Quick Iteration** - Need to ship fast
3. **Community Support** - Want examples and help
4. **Rich Ecosystem** - Need many integrations
5. **Production Tooling** - Want observability and monitoring

## Minimal Agent Implementation

### Core Components

**1. Prompt Template**
**2. LLM Client**
**3. Tool Execution**
**4. Response Parsing**

### Basic Agent (100 lines)

```python
import openai
import json
from typing import List, Dict, Callable, Any

class SimpleAgent:
    """Minimal agent implementation"""

    def __init__(
        self,
        model: str = "gpt-4",
        system_message: str = "You are a helpful assistant",
        tools: List[Dict] = None
    ):
        self.model = model
        self.system_message = system_message
        self.tools = tools or []
        self.tool_functions = {}
        self.conversation_history = []

    def register_tool(self, name: str, func: Callable, description: str):
        """Register a tool function"""
        self.tool_functions[name] = func
        self.tools.append({
            "type": "function",
            "function": {
                "name": name,
                "description": description,
                "parameters": {
                    "type": "object",
                    "properties": {},  # Add parameter schema as needed
                }
            }
        })

    def run(self, user_message: str, max_iterations: int = 5) -> str:
        """Run the agent"""
        self.conversation_history.append({
            "role": "user",
            "content": user_message
        })

        for iteration in range(max_iterations):
            # Call LLM
            response = openai.ChatCompletion.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": self.system_message},
                    *self.conversation_history
                ],
                tools=self.tools if self.tools else None,
                tool_choice="auto" if self.tools else None
            )

            message = response.choices[0].message

            # If no tool calls, return response
            if not message.get("tool_calls"):
                self.conversation_history.append({
                    "role": "assistant",
                    "content": message.content
                })
                return message.content

            # Execute tool calls
            self.conversation_history.append(message.to_dict())

            for tool_call in message.tool_calls:
                function_name = tool_call.function.name
                function_args = json.loads(tool_call.function.arguments)

                # Execute function
                if function_name in self.tool_functions:
                    result = self.tool_functions[function_name](**function_args)
                else:
                    result = f"Error: Unknown function {function_name}"

                # Add result to history
                self.conversation_history.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": str(result)
                })

        return "Max iterations reached"

# Usage
agent = SimpleAgent()

# Register tools
agent.register_tool(
    name="search",
    func=lambda query: f"Search results for: {query}",
    description="Search the web"
)

# Run
result = agent.run("Search for Python frameworks")
print(result)
```

### Production-Ready Agent (More Features)

```python
import openai
import json
import logging
from typing import List, Dict, Callable, Any, Optional
from dataclasses import dataclass
from datetime import datetime

@dataclass
class Message:
    role: str
    content: str
    timestamp: datetime = None

    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()

class Agent:
    """Production-ready custom agent"""

    def __init__(
        self,
        model: str = "gpt-4",
        system_message: str = "You are a helpful assistant",
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        timeout: int = 60,
        max_retries: int = 3
    ):
        self.model = model
        self.system_message = system_message
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.timeout = timeout
        self.max_retries = max_retries

        self.tools = []
        self.tool_functions = {}
        self.conversation_history = []

        # Logging
        self.logger = logging.getLogger(__name__)

        # Metrics
        self.total_tokens = 0
        self.total_cost = 0.0
        self.tool_call_count = {}

    def register_tool(
        self,
        name: str,
        func: Callable,
        description: str,
        parameters: Dict
    ):
        """Register a tool with full schema"""
        self.tool_functions[name] = func
        self.tools.append({
            "type": "function",
            "function": {
                "name": name,
                "description": description,
                "parameters": parameters
            }
        })
        self.logger.info(f"Registered tool: {name}")

    def _call_llm(self, messages: List[Dict]) -> Any:
        """Call LLM with retry logic"""
        for attempt in range(self.max_retries):
            try:
                response = openai.ChatCompletion.create(
                    model=self.model,
                    messages=messages,
                    tools=self.tools if self.tools else None,
                    tool_choice="auto" if self.tools else None,
                    temperature=self.temperature,
                    max_tokens=self.max_tokens,
                    timeout=self.timeout
                )

                # Track usage
                usage = response.usage
                self.total_tokens += usage.total_tokens

                # Estimate cost (GPT-4 pricing)
                prompt_cost = usage.prompt_tokens * 0.00003
                completion_cost = usage.completion_tokens * 0.00006
                self.total_cost += prompt_cost + completion_cost

                return response

            except openai.error.RateLimitError:
                self.logger.warning(f"Rate limit hit, retry {attempt + 1}")
                time.sleep(2 ** attempt)  # Exponential backoff

            except openai.error.Timeout:
                self.logger.error(f"Timeout on attempt {attempt + 1}")

            except Exception as e:
                self.logger.error(f"LLM call failed: {e}")
                raise

        raise Exception("Max retries exceeded")

    def _execute_tool(self, function_name: str, arguments: Dict) -> str:
        """Execute tool with error handling"""
        try:
            if function_name not in self.tool_functions:
                return f"Error: Unknown function {function_name}"

            # Track usage
            self.tool_call_count[function_name] = \
                self.tool_call_count.get(function_name, 0) + 1

            # Execute
            self.logger.info(f"Executing tool: {function_name}")
            result = self.tool_functions[function_name](**arguments)

            return str(result)

        except Exception as e:
            self.logger.error(f"Tool execution failed: {e}")
            return f"Error executing {function_name}: {str(e)}"

    def run(
        self,
        user_message: str,
        max_iterations: int = 10,
        stream: bool = False
    ) -> str:
        """Run the agent with comprehensive error handling"""

        self.conversation_history.append({
            "role": "user",
            "content": user_message
        })

        for iteration in range(max_iterations):
            self.logger.info(f"Iteration {iteration + 1}/{max_iterations}")

            # Prepare messages
            messages = [
                {"role": "system", "content": self.system_message},
                *self.conversation_history
            ]

            # Call LLM
            response = self._call_llm(messages)
            message = response.choices[0].message

            # Check for completion
            if not message.get("tool_calls"):
                content = message.content
                self.conversation_history.append({
                    "role": "assistant",
                    "content": content
                })
                return content

            # Add assistant message with tool calls
            self.conversation_history.append(message.to_dict())

            # Execute all tool calls
            for tool_call in message.tool_calls:
                function_name = tool_call.function.name
                function_args = json.loads(tool_call.function.arguments)

                result = self._execute_tool(function_name, function_args)

                # Add tool result
                self.conversation_history.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": result
                })

        return "Max iterations reached without completion"

    def get_metrics(self) -> Dict:
        """Get agent performance metrics"""
        return {
            "total_tokens": self.total_tokens,
            "total_cost": self.total_cost,
            "tool_calls": self.tool_call_count,
            "messages": len(self.conversation_history)
        }

    def reset(self):
        """Reset conversation history"""
        self.conversation_history = []
        self.logger.info("Conversation history reset")

# Usage
agent = Agent(model="gpt-4", temperature=0)

# Register tool with full schema
agent.register_tool(
    name="search_database",
    func=lambda query, limit=10: {"results": [], "count": 0},
    description="Search the database",
    parameters={
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "Search query"
            },
            "limit": {
                "type": "integer",
                "description": "Max results",
                "default": 10
            }
        },
        "required": ["query"]
    }
)

result = agent.run("Find users in the database")
print(result)
print(agent.get_metrics())
```

## State Machine Pattern

**Pattern:** Explicit state transitions for complex workflows

### Implementation

```python
from enum import Enum
from typing import Dict, Callable

class AgentState(Enum):
    IDLE = "idle"
    RESEARCHING = "researching"
    WRITING = "writing"
    REVIEWING = "reviewing"
    COMPLETE = "complete"
    ERROR = "error"

class StateMachineAgent:
    """Agent with explicit state machine"""

    def __init__(self):
        self.state = AgentState.IDLE
        self.data = {}

        # State transition map
        self.transitions = {
            AgentState.IDLE: self._idle_state,
            AgentState.RESEARCHING: self._research_state,
            AgentState.WRITING: self._write_state,
            AgentState.REVIEWING: self._review_state,
            AgentState.COMPLETE: self._complete_state,
        }

    def _idle_state(self, input_data: Dict) -> AgentState:
        """Handle idle state"""
        self.data = input_data
        return AgentState.RESEARCHING

    def _research_state(self, input_data: Dict) -> AgentState:
        """Handle research state"""
        # Perform research
        research_results = self._do_research(self.data["topic"])
        self.data["research"] = research_results

        if research_results:
            return AgentState.WRITING
        else:
            return AgentState.ERROR

    def _write_state(self, input_data: Dict) -> AgentState:
        """Handle writing state"""
        # Write content
        content = self._do_writing(self.data["research"])
        self.data["content"] = content

        return AgentState.REVIEWING

    def _review_state(self, input_data: Dict) -> AgentState:
        """Handle review state"""
        # Review content
        quality_score = self._do_review(self.data["content"])

        if quality_score > 0.8:
            return AgentState.COMPLETE
        else:
            # Loop back to writing
            return AgentState.WRITING

    def _complete_state(self, input_data: Dict) -> AgentState:
        """Handle completion"""
        return AgentState.COMPLETE

    def run(self, initial_input: Dict, max_transitions: int = 20) -> Dict:
        """Execute state machine"""
        self.state = AgentState.IDLE
        transitions = 0

        while self.state != AgentState.COMPLETE and transitions < max_transitions:
            print(f"State: {self.state.value}")

            # Execute current state handler
            next_state = self.transitions[self.state](initial_input)

            # Transition
            self.state = next_state
            transitions += 1

        return self.data

    def _do_research(self, topic: str) -> str:
        """Research implementation"""
        # Call LLM or tools
        return f"Research on {topic}"

    def _do_writing(self, research: str) -> str:
        """Writing implementation"""
        # Call LLM
        return f"Content based on {research}"

    def _do_review(self, content: str) -> float:
        """Review implementation"""
        # Call LLM for quality check
        return 0.9  # Quality score
```

## Multi-Agent Orchestration

**Pattern:** Coordinate multiple custom agents

### Implementation

```python
class Orchestrator:
    """Orchestrate multiple agents"""

    def __init__(self):
        self.agents = {}
        self.results = {}

    def register_agent(self, name: str, agent: Agent):
        """Register an agent"""
        self.agents[name] = agent

    def sequential(self, workflow: List[Dict]) -> Dict:
        """Execute agents sequentially"""
        results = {}

        for step in workflow:
            agent_name = step["agent"]
            message = step["message"]

            # Get previous results if context specified
            if "context" in step:
                context = "\n".join([
                    f"{k}: {v}"
                    for k, v in results.items()
                    if k in step["context"]
                ])
                message = f"{context}\n\n{message}"

            # Execute agent
            agent = self.agents[agent_name]
            result = agent.run(message)
            results[agent_name] = result

        return results

    def parallel(self, tasks: List[Dict]) -> Dict:
        """Execute agents in parallel"""
        import concurrent.futures

        results = {}

        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = {}

            for task in tasks:
                agent_name = task["agent"]
                message = task["message"]

                agent = self.agents[agent_name]
                future = executor.submit(agent.run, message)
                futures[future] = agent_name

            for future in concurrent.futures.as_completed(futures):
                agent_name = futures[future]
                results[agent_name] = future.result()

        return results

# Usage
orchestrator = Orchestrator()
orchestrator.register_agent("researcher", researcher_agent)
orchestrator.register_agent("writer", writer_agent)
orchestrator.register_agent("reviewer", reviewer_agent)

# Sequential workflow
workflow = [
    {"agent": "researcher", "message": "Research Python frameworks"},
    {
        "agent": "writer",
        "message": "Write article",
        "context": ["researcher"]
    },
    {
        "agent": "reviewer",
        "message": "Review article",
        "context": ["writer"]
    }
]

results = orchestrator.sequential(workflow)
```

## Prompt Engineering for Agents

### System Message Templates

**Research Agent:**
```python
RESEARCHER_SYSTEM = """You are an expert researcher.

Your responsibilities:
- Find accurate, up-to-date information
- Verify sources for credibility
- Provide citations for all claims
- Identify conflicting information

Always:
- Use the search tool when you need current information
- Cite sources in your responses
- Note when information may be outdated

Never:
- Make up information
- Present opinions as facts
- Skip verification steps
"""
```

**Code Generation Agent:**
```python
CODER_SYSTEM = """You are an expert Python developer.

Your responsibilities:
- Write clean, PEP 8 compliant code
- Include comprehensive docstrings
- Add error handling
- Write testable code

Always:
- Use type hints
- Handle edge cases
- Include example usage
- Consider performance

Never:
- Use deprecated APIs
- Ignore security best practices
- Write untested code
"""
```

### Persona-Based Prompting

```python
class PersonaAgent(Agent):
    """Agent with rich persona"""

    PERSONAS = {
        "skeptic": """You are a critical thinker who questions assumptions.
        You look for flaws in arguments and demand evidence.
        You play devil's advocate to strengthen ideas.""",

        "optimist": """You are an enthusiastic supporter who sees potential.
        You identify opportunities and build on ideas.
        You focus on what can work.""",

        "pragmatist": """You are a practical thinker focused on feasibility.
        You consider real-world constraints and trade-offs.
        You prioritize actionable solutions."""
    }

    def __init__(self, persona: str, **kwargs):
        system_message = self.PERSONAS.get(
            persona,
            "You are a helpful assistant"
        )
        super().__init__(system_message=system_message, **kwargs)
```

## Testing Custom Agents

### Unit Tests

```python
import pytest
from unittest.mock import Mock, patch

def test_tool_registration():
    agent = Agent()

    def dummy_tool(x: int) -> int:
        return x * 2

    agent.register_tool(
        name="double",
        func=dummy_tool,
        description="Double a number",
        parameters={}
    )

    assert "double" in agent.tool_functions
    assert agent.tool_functions["double"](5) == 10

def test_tool_execution_error_handling():
    agent = Agent()

    def failing_tool():
        raise ValueError("Tool failed")

    agent.register_tool(
        name="fails",
        func=failing_tool,
        description="A failing tool",
        parameters={}
    )

    result = agent._execute_tool("fails", {})
    assert "Error" in result

@patch('openai.ChatCompletion.create')
def test_agent_run(mock_openai):
    # Mock OpenAI response
    mock_openai.return_value = Mock(
        choices=[Mock(message=Mock(content="Test response", tool_calls=None))],
        usage=Mock(total_tokens=100, prompt_tokens=50, completion_tokens=50)
    )

    agent = Agent()
    result = agent.run("Test message")

    assert result == "Test response"
    assert agent.total_tokens == 100
```

### Integration Tests

```python
def test_full_workflow():
    """Test complete agent workflow"""
    agent = Agent()

    # Register real tools
    agent.register_tool(
        name="calculate",
        func=lambda x, y: x + y,
        description="Add two numbers",
        parameters={
            "type": "object",
            "properties": {
                "x": {"type": "number"},
                "y": {"type": "number"}
            }
        }
    )

    # Run with real API (integration test)
    result = agent.run("What is 25 + 37?")

    # Verify result contains answer
    assert "62" in result
```

## Performance Optimization

### Caching Responses

```python
from functools import lru_cache
import hashlib

class CachedAgent(Agent):
    """Agent with response caching"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.cache = {}

    def _cache_key(self, message: str) -> str:
        """Generate cache key"""
        return hashlib.md5(message.encode()).hexdigest()

    def run(self, user_message: str, **kwargs) -> str:
        """Run with caching"""
        cache_key = self._cache_key(user_message)

        if cache_key in self.cache:
            self.logger.info("Returning cached response")
            return self.cache[cache_key]

        result = super().run(user_message, **kwargs)
        self.cache[cache_key] = result

        return result
```

### Async Support

```python
import asyncio
import aiohttp

class AsyncAgent(Agent):
    """Async agent for concurrent operations"""

    async def _call_llm_async(self, messages: List[Dict]) -> Any:
        """Async LLM call"""
        # Implement async API call
        pass

    async def run_async(self, user_message: str, **kwargs) -> str:
        """Async execution"""
        # Implementation
        pass

# Usage
async def main():
    agent = AsyncAgent()

    # Run multiple queries concurrently
    tasks = [
        agent.run_async("Query 1"),
        agent.run_async("Query 2"),
        agent.run_async("Query 3")
    ]

    results = await asyncio.gather(*tasks)
    return results

results = asyncio.run(main())
```

## Deployment Considerations

### Environment Variables

```python
import os
from dotenv import load_dotenv

load_dotenv()

agent = Agent(
    model=os.getenv("MODEL", "gpt-4"),
    api_key=os.getenv("OPENAI_API_KEY")
)
```

### Logging

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("agent.log"),
        logging.StreamHandler()
    ]
)
```

### Error Monitoring

```python
import sentry_sdk

sentry_sdk.init(dsn=os.getenv("SENTRY_DSN"))

class MonitoredAgent(Agent):
    """Agent with error monitoring"""

    def run(self, user_message: str, **kwargs) -> str:
        try:
            return super().run(user_message, **kwargs)
        except Exception as e:
            sentry_sdk.capture_exception(e)
            raise
```

## When to Graduate to a Framework

**Signals it's time to use a framework:**

1. You've reimplemented framework features (RAG, memory, chains)
2. Team spends more time on infrastructure than features
3. Need features like observability, testing, debugging
4. Multi-agent complexity is growing
5. Onboarding new developers is difficult

**Migration path:**
1. Identify which framework matches your patterns
2. Start with new features in the framework
3. Gradually migrate existing agents
4. Keep custom code where framework doesn't fit
