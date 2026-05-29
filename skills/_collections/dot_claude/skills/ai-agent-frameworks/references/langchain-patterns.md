# LangChain Patterns and Best Practices

## Core Concepts

### Chains
Sequences of LLM calls and processing steps combined together.

### Agents
Systems that use LLMs to choose which tools to call and in what order.

### Tools
Functions that agents can invoke to interact with external systems.

### LCEL (LangChain Expression Language)
Declarative syntax for composing chains with `|` operator.

### LangGraph
Stateful workflow engine for complex, cyclic agent behaviors.

## Agent Types

### ReAct Agent

**Pattern:** Reasoning + Acting in iterative loop

**When to use:**
- General-purpose agent tasks
- Need transparency in reasoning
- Tool calling with explanation

**Example:**
```python
from langchain.agents import create_react_agent, AgentExecutor
from langchain_openai import ChatOpenAI
from langchain.tools import Tool

# Define tools
search_tool = Tool(
    name="Search",
    func=search_function,
    description="Search the web for information"
)

calculator_tool = Tool(
    name="Calculator",
    func=calculator_function,
    description="Perform mathematical calculations"
)

# Create agent
llm = ChatOpenAI(model="gpt-4", temperature=0)
agent = create_react_agent(llm, tools=[search_tool, calculator_tool])

# Execute with AgentExecutor
agent_executor = AgentExecutor(
    agent=agent,
    tools=[search_tool, calculator_tool],
    verbose=True,
    max_iterations=5,  # Prevent infinite loops
    handle_parsing_errors=True  # Graceful error handling
)

result = agent_executor.invoke({"input": "What is the population of Tokyo times 2?"})
```

**Characteristics:**
- ✅ Transparent reasoning (shows thought process)
- ✅ Good for debugging
- ❌ More tokens used (reasoning overhead)
- ❌ Can be verbose

### Structured Chat Agent

**Pattern:** Better parsing and structured outputs

**When to use:**
- Need JSON outputs
- Multiple tools with complex parameters
- Chat-based interfaces

**Example:**
```python
from langchain.agents import create_structured_chat_agent

agent = create_structured_chat_agent(
    llm=llm,
    tools=tools,
    prompt=custom_prompt
)

agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)
```

### OpenAI Functions Agent

**Pattern:** Uses OpenAI's function calling API

**When to use:**
- Using OpenAI models (GPT-4, GPT-3.5)
- Need reliable tool calling
- Production systems (more predictable)

**Example:**
```python
from langchain.agents import create_openai_functions_agent

agent = create_openai_functions_agent(llm=llm, tools=tools, prompt=prompt)
agent_executor = AgentExecutor(agent=agent, tools=tools)
```

**Characteristics:**
- ✅ Most reliable tool calling
- ✅ Structured outputs
- ✅ Better performance
- ❌ OpenAI-specific (not portable)

### Custom Agent

**Pattern:** Full control over agent behavior

**When to use:**
- Unique reasoning patterns
- Special tool selection logic
- Performance optimization

**Example:**
```python
from langchain.agents import BaseSingleActionAgent

class CustomAgent(BaseSingleActionAgent):
    def plan(self, intermediate_steps, **kwargs):
        # Custom planning logic
        return AgentAction(tool="search", tool_input="query", log="reasoning")

    async def aplan(self, intermediate_steps, **kwargs):
        # Async version
        return await super().aplan(intermediate_steps, **kwargs)
```

## Chain Composition Patterns

### LCEL: Basic Chaining

**Pattern:** Pipe operator for sequential composition

**Example:**
```python
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_openai import ChatOpenAI

# Components
prompt = ChatPromptTemplate.from_template("Tell me a joke about {topic}")
model = ChatOpenAI(model="gpt-3.5-turbo")
output_parser = StrOutputParser()

# Chain composition
chain = prompt | model | output_parser

# Execute
result = chain.invoke({"topic": "programming"})
```

**Benefits:**
- ✅ Readable, declarative syntax
- ✅ Easy to compose and modify
- ✅ Type safety and validation
- ✅ Streaming support

### Parallel Chains

**Pattern:** Execute multiple chains concurrently

**Example:**
```python
from langchain_core.runnables import RunnableParallel

# Create parallel chains
chain = RunnableParallel(
    summary=prompt1 | model | StrOutputParser(),
    keywords=prompt2 | model | StrOutputParser(),
    sentiment=prompt3 | model | StrOutputParser()
)

# All three execute in parallel
result = chain.invoke({"text": input_text})
# result = {"summary": "...", "keywords": "...", "sentiment": "..."}
```

### Conditional Branching

**Pattern:** Route based on input or intermediate results

**Example:**
```python
from langchain_core.runnables import RunnableBranch

# Define branches
branch = RunnableBranch(
    (lambda x: "code" in x["topic"], code_chain),
    (lambda x: "math" in x["topic"], math_chain),
    default_chain  # Fallback
)

chain = prompt | branch | output_parser
```

### Map-Reduce Pattern

**Pattern:** Process items in parallel, then combine

**Example:**
```python
from langchain.chains import MapReduceChain

# Map: Process each document
map_chain = LLMChain(llm=llm, prompt=map_prompt)

# Reduce: Combine results
reduce_chain = LLMChain(llm=llm, prompt=reduce_prompt)

# Combine
map_reduce = MapReduceChain(
    llm_chain=map_chain,
    reduce_chain=reduce_chain,
    document_variable_name="docs"
)

# Process multiple documents
result = map_reduce.invoke({"docs": document_list})
```

## RAG Patterns

### Basic RAG

**Pattern:** Retrieve → Generate

**Example:**
```python
from langchain_community.vectorstores import FAISS
from langchain_openai import OpenAIEmbeddings
from langchain.chains import RetrievalQA

# Create vector store
embeddings = OpenAIEmbeddings()
vectorstore = FAISS.from_documents(documents, embeddings)

# Create retriever
retriever = vectorstore.as_retriever(search_kwargs={"k": 4})

# Create QA chain
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=retriever,
    return_source_documents=True
)

result = qa_chain.invoke({"query": "What is LangChain?"})
```

### Conversational RAG

**Pattern:** RAG with chat history

**Example:**
```python
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory

memory = ConversationBufferMemory(
    memory_key="chat_history",
    return_messages=True
)

qa_chain = ConversationalRetrievalChain.from_llm(
    llm=llm,
    retriever=retriever,
    memory=memory
)

# Maintains conversation context
qa_chain.invoke({"question": "What is LangChain?"})
qa_chain.invoke({"question": "What are its main features?"})  # "its" refers to LangChain
```

### Multi-Query RAG

**Pattern:** Generate multiple queries for better retrieval

**Example:**
```python
from langchain.retrievers import MultiQueryRetriever

retriever = MultiQueryRetriever.from_llm(
    retriever=vectorstore.as_retriever(),
    llm=llm
)

# Automatically generates variations of the query
docs = retriever.get_relevant_documents("Tell me about agent frameworks")
```

### Contextual Compression

**Pattern:** Retrieve many, compress to most relevant

**Example:**
```python
from langchain.retrievers import ContextualCompressionRetriever
from langchain.retrievers.document_compressors import LLMChainExtractor

compressor = LLMChainExtractor.from_llm(llm)
compression_retriever = ContextualCompressionRetriever(
    base_compressor=compressor,
    base_retriever=retriever
)

# Returns only most relevant excerpts
docs = compression_retriever.get_relevant_documents("query")
```

## Tool Integration

### Function Calling Pattern

**Example:**
```python
from langchain.tools import tool

@tool
def search_database(query: str, limit: int = 10) -> str:
    """
    Search the database for relevant records.

    Args:
        query: Search query string
        limit: Maximum number of results to return

    Returns:
        JSON string of search results
    """
    # Implementation
    results = db.search(query, limit=limit)
    return json.dumps(results)

# Agent will automatically understand tool from docstring
tools = [search_database]
agent = create_openai_functions_agent(llm, tools, prompt)
```

### StructuredTool for Complex Inputs

**Example:**
```python
from langchain.tools import StructuredTool
from pydantic import BaseModel, Field

class SearchInput(BaseModel):
    query: str = Field(description="Search query")
    filters: dict = Field(description="Filter criteria")
    limit: int = Field(default=10, description="Result limit")

def search_with_filters(query: str, filters: dict, limit: int) -> str:
    # Implementation
    return results

search_tool = StructuredTool.from_function(
    func=search_with_filters,
    name="search_database",
    description="Search database with filters",
    args_schema=SearchInput
)
```

### Tool Error Handling

**Pattern:** Return error messages as strings

**Example:**
```python
@tool
def api_call(endpoint: str) -> str:
    """Call external API"""
    try:
        response = requests.get(endpoint, timeout=10)
        response.raise_for_status()
        return json.dumps(response.json())
    except requests.Timeout:
        return "Error: Request timed out"
    except requests.RequestException as e:
        return f"Error: {str(e)}"
```

### Tool with Callbacks

**Pattern:** Track tool usage for observability

**Example:**
```python
from langchain.callbacks import StdOutCallbackHandler

agent_executor = AgentExecutor(
    agent=agent,
    tools=tools,
    callbacks=[StdOutCallbackHandler()],  # Logs all tool calls
    verbose=True
)
```

## Memory Management

### Conversation Buffer Memory

**Pattern:** Store all messages in memory

**Example:**
```python
from langchain.memory import ConversationBufferMemory

memory = ConversationBufferMemory(
    memory_key="chat_history",
    return_messages=True
)

chain = LLMChain(llm=llm, prompt=prompt, memory=memory)

# Automatic history tracking
chain.run("Hello")
chain.run("What did I just say?")  # Knows you said "Hello"
```

**Characteristics:**
- ✅ Complete conversation history
- ❌ Unbounded growth (context overflow)

### Conversation Buffer Window Memory

**Pattern:** Keep only last N messages

**Example:**
```python
from langchain.memory import ConversationBufferWindowMemory

memory = ConversationBufferWindowMemory(
    k=5,  # Keep last 5 messages only
    memory_key="chat_history",
    return_messages=True
)
```

**Characteristics:**
- ✅ Bounded memory usage
- ❌ Loses older context

### Conversation Summary Memory

**Pattern:** Summarize old messages to save tokens

**Example:**
```python
from langchain.memory import ConversationSummaryMemory

memory = ConversationSummaryMemory(
    llm=llm,
    memory_key="chat_history"
)

# Automatically summarizes when context gets large
```

**Characteristics:**
- ✅ Bounded memory
- ✅ Retains key information
- ❌ Summarization costs tokens
- ❌ May lose details

### Vector Store Memory

**Pattern:** Store memories in vector database for semantic retrieval

**Example:**
```python
from langchain.memory import VectorStoreRetrieverMemory

memory = VectorStoreRetrieverMemory(
    retriever=vectorstore.as_retriever(search_kwargs={"k": 3})
)

# Retrieves most relevant memories based on current input
```

## LangGraph: Advanced Workflows

### Basic LangGraph Pattern

**Pattern:** Define nodes and edges explicitly

**Example:**
```python
from langgraph.graph import StateGraph, END
from typing import TypedDict

# Define state
class AgentState(TypedDict):
    messages: list
    next_action: str

# Define nodes (functions)
def research_node(state: AgentState):
    # Research logic
    return {"messages": state["messages"] + [research_result]}

def write_node(state: AgentState):
    # Writing logic
    return {"messages": state["messages"] + [written_content]}

# Build graph
workflow = StateGraph(AgentState)

# Add nodes
workflow.add_node("research", research_node)
workflow.add_node("write", write_node)

# Add edges
workflow.add_edge("research", "write")
workflow.add_edge("write", END)

# Set entry point
workflow.set_entry_point("research")

# Compile
app = workflow.compile()

# Execute
result = app.invoke({"messages": [], "next_action": ""})
```

### Conditional Edges

**Pattern:** Route based on state

**Example:**
```python
def router(state: AgentState):
    """Decide next node based on state"""
    if state["next_action"] == "research":
        return "research_node"
    elif state["next_action"] == "write":
        return "write_node"
    else:
        return END

workflow.add_conditional_edges(
    "decision_node",
    router,
    {
        "research_node": "research",
        "write_node": "write",
        END: END
    }
)
```

### Cyclic Workflows

**Pattern:** Allow loops for retries or refinement

**Example:**
```python
def quality_check(state: AgentState):
    """Check if output is good enough"""
    if quality_score(state["output"]) > 0.8:
        return END
    else:
        return "improve_node"  # Loop back

workflow.add_conditional_edges(
    "generate_node",
    quality_check,
    {
        END: END,
        "improve_node": "improve"
    }
)

workflow.add_edge("improve", "generate_node")  # Complete the loop
```

### Checkpointing

**Pattern:** Save state for long-running workflows

**Example:**
```python
from langgraph.checkpoint import MemorySaver

# Add checkpointing
memory = MemorySaver()
app = workflow.compile(checkpointer=memory)

# Execute with thread ID for state persistence
result = app.invoke(
    {"messages": []},
    config={"configurable": {"thread_id": "user-123"}}
)

# Resume later with same thread ID
```

## Common Anti-Patterns

### ❌ Not Handling Agent Loops

**Problem:**
```python
agent_executor = AgentExecutor(agent=agent, tools=tools)
# Can run forever if agent gets confused
```

**Solution:**
```python
agent_executor = AgentExecutor(
    agent=agent,
    tools=tools,
    max_iterations=10,  # Hard limit
    max_execution_time=60,  # Timeout in seconds
    handle_parsing_errors=True
)
```

### ❌ Overloading Agent with Tools

**Problem:**
```python
# 20 tools - agent wastes tokens deciding which to use
agent = create_openai_functions_agent(llm, tools=twenty_tools, prompt=prompt)
```

**Solution:**
```python
# 3-7 tools per agent
# Create specialized agents instead
research_agent = create_agent(llm, tools=[search, read_docs])
code_agent = create_agent(llm, tools=[execute_code, read_file, write_file])
```

### ❌ Not Using Memory for Conversations

**Problem:**
```python
chain = LLMChain(llm=llm, prompt=prompt)
chain.run("My name is Alice")
chain.run("What's my name?")  # Doesn't remember
```

**Solution:**
```python
memory = ConversationBufferMemory()
chain = LLMChain(llm=llm, prompt=prompt, memory=memory)
chain.run("My name is Alice")
chain.run("What's my name?")  # Returns "Alice"
```

### ❌ Ignoring Streaming

**Problem:**
```python
# User waits 30 seconds for full response
result = chain.invoke({"input": query})
```

**Solution:**
```python
# Stream tokens as they arrive
for chunk in chain.stream({"input": query}):
    print(chunk, end="", flush=True)
```

### ❌ Not Setting Timeouts

**Problem:**
```python
@tool
def slow_api_call(query: str) -> str:
    return requests.get(url).json()  # Could hang forever
```

**Solution:**
```python
@tool
def slow_api_call(query: str) -> str:
    try:
        return requests.get(url, timeout=10).json()
    except requests.Timeout:
        return "Error: Timeout"
```

## Production Patterns

### LangSmith Integration

**Pattern:** Production observability

**Example:**
```python
import os
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = "your-key"
os.environ["LANGCHAIN_PROJECT"] = "your-project"

# All chain/agent runs automatically traced
```

### Caching for Repeated Queries

**Example:**
```python
from langchain.cache import InMemoryCache
from langchain.globals import set_llm_cache

set_llm_cache(InMemoryCache())

# Identical queries return cached results
llm.invoke("What is 2+2?")  # Calls API
llm.invoke("What is 2+2?")  # Returns from cache
```

### Rate Limiting

**Example:**
```python
from langchain.llms import OpenAI
from langchain.callbacks import get_openai_callback

# Track token usage
with get_openai_callback() as cb:
    result = chain.invoke({"input": query})
    print(f"Tokens used: {cb.total_tokens}")
    print(f"Cost: ${cb.total_cost}")
```

### Async for Concurrency

**Example:**
```python
import asyncio

async def process_batch(queries):
    tasks = [chain.ainvoke({"input": q}) for q in queries]
    results = await asyncio.gather(*tasks)
    return results

# Process 10 queries concurrently
results = asyncio.run(process_batch(ten_queries))
```

### Error Handling Chain

**Pattern:** Fallback on errors

**Example:**
```python
from langchain_core.runnables import RunnableWithFallbacks

primary_chain = prompt | ChatOpenAI(model="gpt-4")
fallback_chain = prompt | ChatOpenAI(model="gpt-3.5-turbo")

chain_with_fallback = primary_chain.with_fallbacks([fallback_chain])

# If GPT-4 fails, automatically tries GPT-3.5
```

## Testing Strategies

### Mock LLM for Testing

```python
from langchain.llms.fake import FakeListLLM

responses = ["Response 1", "Response 2", "Response 3"]
llm = FakeListLLM(responses=responses)

chain = prompt | llm | output_parser

# Predictable responses for testing
result = chain.invoke({"input": "test"})  # Returns "Response 1"
```

### Test Tool Calls

```python
def test_agent_calls_correct_tool():
    agent_executor = AgentExecutor(agent=agent, tools=tools)

    with get_openai_callback() as cb:
        result = agent_executor.invoke({"input": "Search for Python"})

    # Verify tool was called
    assert "search" in cb.tool_calls
```

### Integration Testing with Real APIs

```python
@pytest.mark.integration
def test_full_rag_pipeline():
    # Test with small dataset
    test_docs = load_test_documents()
    vectorstore = FAISS.from_documents(test_docs, embeddings)

    qa_chain = RetrievalQA.from_chain_type(
        llm=llm,
        retriever=vectorstore.as_retriever()
    )

    result = qa_chain.invoke({"query": "test query"})
    assert len(result["result"]) > 0
```
