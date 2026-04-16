# Agent System Template

Boilerplate for building multi-agent systems with observability and best practices built-in.

## Structure

```
agent-system-template/
├── agents/           - Agent definitions
│   ├── researcher.py
│   └── writer.py
├── tools/            - Reusable tools
│   └── search.py
├── workflows/        - Orchestration logic
│   └── research_workflow.py
├── config.yaml       - Configuration
├── main.py           - Entry point
└── requirements.txt  - Dependencies
```

## Quick Start

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Configure API keys:
   ```bash
   cp .env.example .env
   # Edit .env with your API keys
   ```

3. Run example workflow:
   ```bash
   python main.py
   ```

## Customization

- Add new agents in `agents/`
- Add tools in `tools/`
- Define workflows in `workflows/`
- Adjust config in `config.yaml`

## Features

- ✅ Basic observability (logging, tracing)
- ✅ Cost tracking
- ✅ Error handling
- ✅ Configurable agents and workflows
- ✅ Example implementations
