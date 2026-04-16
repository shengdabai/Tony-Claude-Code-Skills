# CrewAI Patterns and Best Practices

## Core Concepts

### Agents
Specialized AI entities with defined roles, goals, and capabilities. Think of them as team members.

### Tasks
Specific assignments with descriptions, expected outputs, and assigned agents.

### Processes
Orchestration strategies defining how agents collaborate:
- **Sequential**: Tasks execute one after another
- **Hierarchical**: Manager agent delegates and coordinates
- **Custom**: User-defined orchestration logic

### Tools
Functions agents can call to interact with external systems.

## Role Design Best Practices

### Principle: Specialization Over Generalization

**Good Role Design:**
```python
researcher = Agent(
    role="Technical Researcher",
    goal="Find accurate, up-to-date information on software frameworks",
    backstory="Expert at evaluating technical documentation and comparing frameworks",
    tools=[web_search_tool, documentation_reader],
    verbose=True
)
```

**Poor Role Design:**
```python
# Too generic - unclear what this agent should do
general_agent = Agent(
    role="Helper",
    goal="Help with stuff",
    backstory="Does things",
    verbose=True
)
```

### Role Definition Checklist

✅ **Specific role title** - "Senior Python Developer" not "Developer"
✅ **Clear goal** - What success looks like for this agent
✅ **Relevant backstory** - Provides context for decision-making
✅ **Appropriate tools** - Only tools needed for this role
✅ **Realistic scope** - One agent shouldn't do everything

### Common Role Patterns

**Research → Write → Review:**
```python
researcher = Agent(
    role="Research Analyst",
    goal="Gather comprehensive data on {topic}",
    tools=[search_tool, pdf_reader]
)

writer = Agent(
    role="Content Writer",
    goal="Create engaging content based on research",
    tools=[writing_tool]
)

reviewer = Agent(
    role="Editor",
    goal="Ensure quality, accuracy, and clarity",
    tools=[grammar_tool]
)
```

**Plan → Execute → Verify:**
```python
planner = Agent(
    role="Project Planner",
    goal="Create detailed implementation plan",
    tools=[documentation_tool]
)

executor = Agent(
    role="Implementation Engineer",
    goal="Execute the plan and build features",
    tools=[code_execution_tool, git_tool]
)

verifier = Agent(
    role="QA Engineer",
    goal="Verify implementation meets requirements",
    tools=[test_runner_tool]
)
```

## Task Design Patterns

### Effective Task Descriptions

**Good Task:**
```python
research_task = Task(
    description="""
    Research the following frameworks for building REST APIs in Python:
    - FastAPI
    - Django REST Framework
    - Flask-RESTful

    For each framework, identify:
    1. Performance characteristics
    2. Learning curve
    3. Community support
    4. Production readiness

    Provide concrete examples and benchmark data where available.
    """,
    agent=researcher,
    expected_output="Structured comparison table with concrete data points"
)
```

**Poor Task:**
```python
# Too vague - agent won't know what to deliver
vague_task = Task(
    description="Look into Python frameworks",
    agent=researcher,
    expected_output="Something useful"
)
```

### Task Dependency Patterns

**Sequential Dependencies:**
```python
# Task 2 depends on Task 1 output
task1 = Task(
    description="Research topic and create outline",
    agent=researcher
)

task2 = Task(
    description="Write article based on the outline from previous task",
    agent=writer,
    context=[task1]  # Automatically gets task1 output
)

task3 = Task(
    description="Edit and refine the article",
    agent=editor,
    context=[task2]  # Gets task2 output
)

crew = Crew(
    agents=[researcher, writer, editor],
    tasks=[task1, task2, task3],
    process=Process.sequential
)
```

**Parallel with Merge:**
```python
# Multiple tasks run in parallel, merged in final task
research_web = Task(description="Research web sources", agent=web_researcher)
research_papers = Task(description="Research academic papers", agent=paper_researcher)
research_interviews = Task(description="Conduct expert interviews", agent=interviewer)

synthesis = Task(
    description="Synthesize all research findings",
    agent=synthesizer,
    context=[research_web, research_papers, research_interviews]
)
```

## Process Patterns

### Sequential Process

**When to use:**
- Linear workflows
- Each step depends on previous step
- Clear handoff points

**Example:**
```python
crew = Crew(
    agents=[researcher, writer, editor, publisher],
    tasks=[research, write, edit, publish],
    process=Process.sequential,
    verbose=True
)
```

**Characteristics:**
- ✅ Simple to understand and debug
- ✅ Predictable execution order
- ❌ No parallelization
- ❌ One failure stops entire pipeline

### Hierarchical Process

**When to use:**
- Complex workflows requiring delegation
- Dynamic task prioritization
- Need oversight and quality control

**Example:**
```python
manager = Agent(
    role="Project Manager",
    goal="Coordinate team and ensure project success",
    backstory="Experienced at delegating and overseeing complex projects",
    allow_delegation=True  # Critical for hierarchical
)

crew = Crew(
    agents=[manager, researcher, developer, tester],
    tasks=[project_tasks],
    process=Process.hierarchical,
    manager_llm="gpt-4"  # Manager needs strong reasoning
)
```

**Characteristics:**
- ✅ Dynamic task allocation
- ✅ Manager can retry failed tasks
- ❌ More expensive (manager overhead)
- ❌ Less predictable execution

### Custom Process

**When to use:**
- Unique orchestration requirements
- Conditional branching logic
- Integration with existing systems

**Example:**
```python
def custom_process(tasks, agents):
    """Custom orchestration logic"""
    results = []

    # Run research tasks in parallel
    research_results = parallel_execute([tasks[0], tasks[1]])

    # Conditional branching
    if quality_check(research_results):
        results.append(execute_task(tasks[2], agents[2]))
    else:
        results.append(execute_task(tasks[3], agents[3]))  # Retry with different agent

    return results

crew = Crew(
    agents=agents,
    tasks=tasks,
    process=custom_process
)
```

## Tool Integration

### Tool Definition Pattern

```python
from langchain.tools import Tool

@tool
def search_documentation(query: str) -> str:
    """
    Search technical documentation for relevant information.

    Args:
        query: Search query string

    Returns:
        Relevant documentation excerpts
    """
    # Implementation
    return results

# Assign to agents
researcher = Agent(
    role="Researcher",
    tools=[search_documentation, web_search, pdf_reader],
    # ...
)
```

### Tool Access Control

**Pattern: Role-appropriate tools**
```python
# Junior developer - limited tools
junior = Agent(
    role="Junior Developer",
    tools=[read_code, run_tests],  # No deployment tools
)

# Senior developer - full access
senior = Agent(
    role="Senior Developer",
    tools=[read_code, write_code, run_tests, deploy],
)
```

### Tool Error Handling

```python
@tool
def api_call(endpoint: str) -> str:
    """Call external API with error handling"""
    try:
        response = requests.get(endpoint, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.Timeout:
        return "Error: API request timed out. Try again later."
    except requests.exceptions.RequestException as e:
        return f"Error: API call failed - {str(e)}"
```

## Memory and Context Management

### Short-term Memory (Conversation Context)

CrewAI maintains conversation context automatically within a task execution.

**Control context with task dependencies:**
```python
task1 = Task(description="...", agent=agent1)
task2 = Task(
    description="...",
    agent=agent2,
    context=[task1]  # Agent2 sees task1's output
)
```

### Long-term Memory (Across Executions)

**Pattern: External memory store**
```python
from crewai import Crew

crew = Crew(
    agents=[agent],
    tasks=[task],
    memory=True,  # Enable built-in memory (experimental)
)

# Or use custom memory
class CustomMemory:
    def __init__(self):
        self.store = {}

    def save(self, key, value):
        self.store[key] = value

    def retrieve(self, key):
        return self.store.get(key)

# Integrate with agents via tools
memory = CustomMemory()

@tool
def save_memory(key: str, value: str):
    memory.save(key, value)
    return f"Saved {key}"

@tool
def retrieve_memory(key: str):
    return memory.retrieve(key)
```

### Context Pruning

**Problem:** Long conversations exceed context windows

**Solution:** Summarization between tasks
```python
summarizer = Agent(
    role="Summarizer",
    goal="Condense previous work into key points",
)

# After every N tasks, run summarization
summary_task = Task(
    description="Summarize previous research findings into 3-5 key points",
    agent=summarizer,
    context=[task1, task2, task3]
)

# Next tasks reference only the summary
next_task = Task(
    description="Continue research based on summary",
    agent=researcher,
    context=[summary_task]  # Not all previous tasks
)
```

## Common Configurations

### Research Paper Writer

```python
from crewai import Agent, Task, Crew, Process

# Agents
researcher = Agent(
    role="Academic Researcher",
    goal="Find credible sources and data on {topic}",
    backstory="PhD-level researcher skilled at literature review",
    tools=[academic_search, pdf_extractor],
    verbose=True
)

writer = Agent(
    role="Technical Writer",
    goal="Write clear, well-structured academic content",
    backstory="Published author with expertise in technical writing",
    verbose=True
)

reviewer = Agent(
    role="Peer Reviewer",
    goal="Ensure academic rigor and clarity",
    backstory="Senior researcher with publication review experience",
    verbose=True
)

# Tasks
research = Task(
    description="Research {topic} and gather 10+ credible sources",
    agent=researcher,
    expected_output="Annotated bibliography with key findings"
)

write = Task(
    description="Write a 2000-word research paper on {topic}",
    agent=writer,
    context=[research],
    expected_output="Complete paper with citations"
)

review = Task(
    description="Review paper for accuracy, clarity, and citations",
    agent=reviewer,
    context=[write],
    expected_output="Edited paper with reviewer comments"
)

# Crew
crew = Crew(
    agents=[researcher, writer, reviewer],
    tasks=[research, write, review],
    process=Process.sequential,
    verbose=True
)

result = crew.kickoff(inputs={"topic": "Multi-agent AI systems"})
```

### Customer Support Routing

```python
# Agents
intake = Agent(
    role="Support Intake Specialist",
    goal="Understand customer issue and classify urgency",
    tools=[ticket_reader]
)

technical = Agent(
    role="Technical Support Engineer",
    goal="Resolve technical issues",
    tools=[database_query, log_analyzer]
)

billing = Agent(
    role="Billing Specialist",
    goal="Resolve billing and payment issues",
    tools=[payment_system, invoice_generator]
)

escalation = Agent(
    role="Senior Support Manager",
    goal="Handle escalated or complex issues",
    allow_delegation=True
)

# Hierarchical process for dynamic routing
crew = Crew(
    agents=[intake, technical, billing, escalation],
    tasks=[support_tasks],
    process=Process.hierarchical,
    manager_llm="gpt-4"
)
```

## Anti-Patterns

### ❌ Too Many Agents

**Problem:**
```python
# 10 agents for a simple workflow
agents = [agent1, agent2, agent3, agent4, agent5,
          agent6, agent7, agent8, agent9, agent10]
```

**Solution:** Start with 2-4 agents, add more only when justified

### ❌ Overlapping Responsibilities

**Problem:**
```python
researcher = Agent(role="Researcher", goal="Research AND write")
writer = Agent(role="Writer", goal="Write AND edit")
```

**Solution:** Clear role boundaries
```python
researcher = Agent(role="Researcher", goal="Research only")
writer = Agent(role="Writer", goal="Write only")
editor = Agent(role="Editor", goal="Edit only")
```

### ❌ Vague Task Descriptions

**Problem:**
```python
Task(description="Do research", agent=researcher)
```

**Solution:** Specific, actionable descriptions
```python
Task(
    description="""
    Research the top 5 Python web frameworks by GitHub stars.
    For each, identify: release date, latest version, key features.
    """,
    agent=researcher,
    expected_output="Table with framework comparison"
)
```

### ❌ No Error Handling in Tools

**Problem:**
```python
@tool
def api_call(url):
    return requests.get(url).json()  # Crashes on failure
```

**Solution:** Graceful error handling
```python
@tool
def api_call(url):
    try:
        return requests.get(url, timeout=10).json()
    except Exception as e:
        return f"API call failed: {str(e)}"
```

## Performance Optimization

### 1. Minimize Agent Count
Each agent adds overhead. Start minimal, add agents when needed.

### 2. Use Specific Task Descriptions
Vague descriptions cause agents to do exploratory work (expensive).

### 3. Limit Tool Access
Don't give all tools to all agents. More tools = more decision-making overhead.

### 4. Cache Repeated Work
If multiple tasks need the same data, do it once and share via context.

### 5. Use Smaller Models for Simple Agents
```python
simple_agent = Agent(
    role="Data Formatter",
    goal="Format data into JSON",
    llm="gpt-3.5-turbo"  # Cheaper for simple tasks
)

complex_agent = Agent(
    role="Strategic Analyst",
    goal="Analyze market trends",
    llm="gpt-4"  # More capable for complex reasoning
)
```

## Testing Strategies

### Unit Test Individual Agents

```python
def test_researcher_agent():
    task = Task(
        description="Find the capital of France",
        agent=researcher,
        expected_output="Paris"
    )

    result = task.execute()
    assert "Paris" in result
```

### Integration Test Full Crew

```python
def test_research_workflow():
    crew = Crew(agents=[researcher, writer], tasks=[research, write])
    result = crew.kickoff(inputs={"topic": "Test Topic"})

    assert len(result) > 100  # Some minimum output length
    assert "Test Topic" in result
```

### Mock External Tools

```python
@tool
def mock_search(query: str) -> str:
    """Mock search for testing"""
    return "Test search result"

# Use in test environment
test_agent = Agent(role="Researcher", tools=[mock_search])
```

## Production Deployment Tips

1. **Set timeouts** on long-running tasks to prevent runaway costs
2. **Log all agent interactions** for debugging and auditing
3. **Monitor token usage** per agent to identify expensive patterns
4. **Implement circuit breakers** for external tool calls
5. **Version your agent configurations** to track changes
6. **Test with smaller models first** before deploying expensive models
7. **Implement rate limiting** on tool usage to prevent API quota exhaustion
