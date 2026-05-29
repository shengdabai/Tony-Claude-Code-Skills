---
name: uv
description: Expert Python package management with uv - fast dependency management, virtual environments, and modern Python project workflows. Use when setting up Python projects, managing dependencies, or optimizing Python development workflows with uv.
---

# UV: Ultra-Fast Python Package Manager

Expert guidance for uv, the extremely fast Python package and project manager written in Rust.

## When to Use This Skill

Activate this skill when working with:
- **Project initialization** - Creating new Python projects with `uv init`
- **Dependency management** - Adding, removing, or updating Python packages
- **Virtual environments** - Creating and managing isolated Python environments
- **Python version management** - Installing and switching Python versions
- **Package building** - Building distributions for PyPI
- **CI/CD workflows** - Optimizing GitHub Actions, GitLab CI, Docker builds
- **Migration from pip** - Moving from pip/pip-tools/poetry to uv
- **Performance optimization** - Leveraging uv's speed for faster installs

## Quick Reference

### Project Initialization

**Create a new application:**
```bash
$ uv init my-app
$ cd my-app
$ tree .
.
├── .python-version
├── README.md
├── main.py
└── pyproject.toml
```

**Create a packaged application (with CLI):**
```bash
$ uv init --package my-cli
# Creates src/ layout with entry point
```

**Create a library:**
```bash
$ uv init --lib my-library
# Creates src/ layout with py.typed marker
```

### Dependency Management

**Add dependencies:**
```bash
$ uv add requests pandas numpy
$ uv add --dev pytest black ruff  # Development dependencies
$ uv add "flask>=2.0.0"            # Version constraints
```

**Remove dependencies:**
```bash
$ uv remove requests
$ uv remove --dev pytest
```

**Update dependencies:**
```bash
$ uv sync              # Sync environment with lockfile
$ uv lock --upgrade    # Update lockfile with latest versions
```

### Running Code

**Run Python files:**
```bash
$ uv run main.py
$ uv run python script.py
```

**Run inline scripts with dependencies:**
```python
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "pandas",
#   "requests",
# ]
# ///

import pandas as pd
import requests

# Your code here
```

```bash
$ uv run script.py  # Automatically manages dependencies!
```

### Virtual Environments

**Create a virtual environment:**
```bash
$ uv venv
$ uv venv .venv --python 3.12
```

**Using pip-compatible interface:**
```bash
$ uv pip install requests
$ uv pip install -r requirements.txt
$ uv pip freeze > requirements.txt
$ uv pip list
```

### Python Version Management

**Install Python versions:**
```bash
$ uv python install 3.12
$ uv python install 3.11 3.10  # Multiple versions
```

**List installed versions:**
```bash
$ uv python list
```

**Pin project Python version:**
```bash
$ uv python pin 3.12
# Creates .python-version file
```

### Tools Management

**Install and run tools:**
```bash
$ uv tool install ruff
$ uv tool install black mypy

$ uvx ruff check .     # Run without installing
$ uvx pytest           # Run tools in isolated environments
```

### Building and Publishing

**Build package:**
```bash
$ uv build
# Creates dist/ with .whl and .tar.gz
```

**Publish to PyPI:**
```bash
$ uv publish
$ uv publish --token $PYPI_TOKEN
```

### Configuration

**Project config (pyproject.toml):**
```toml
[project]
name = "my-app"
version = "0.1.0"
description = "My application"
readme = "README.md"
requires-python = ">=3.11"
dependencies = [
    "requests>=2.31.0",
    "pandas>=2.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "black>=23.0.0",
]

[dependency-groups]
dev = [
    "ruff>=0.1.0",
]

[tool.uv.sources]
# Use alternative package indexes
my-package = { index = "private-pypi" }
```

**Global config (uv.toml or pyproject.toml):**
```toml
[tool.uv]
# Disable managed project environment
managed = false

# Configure package indexes
[[tool.uv.index]]
name = "pytorch"
url = "https://download.pytorch.org/whl/cu118"
```

## Common Workflows

### Workflow 1: Starting a New Project

```bash
# Create project
$ uv init my-project
$ cd my-project

# Add dependencies
$ uv add fastapi uvicorn sqlalchemy

# Add dev dependencies
$ uv add --dev pytest black ruff

# Run the app
$ uv run python main.py
```

### Workflow 2: Migrating from pip/requirements.txt

```bash
# Create uv project from existing code
$ uv init --no-package

# Import existing requirements
$ uv add -r requirements.txt

# Lock dependencies
$ uv lock

# Sync environment
$ uv sync
```

### Workflow 3: Docker Integration

```dockerfile
FROM python:3.12-slim

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Copy project files
WORKDIR /app
COPY pyproject.toml uv.lock ./
COPY src ./src

# Install dependencies
RUN uv sync --frozen --no-cache

# Run application
CMD ["uv", "run", "python", "-m", "myapp"]
```

### Workflow 4: GitHub Actions CI/CD

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v3

      - name: Set up Python
        run: uv python install 3.12

      - name: Install dependencies
        run: uv sync --all-extras --dev

      - name: Run tests
        run: uv run pytest
```

### Workflow 5: Working with Scripts

```bash
# Create standalone script with dependencies
$ cat > analyze.py << 'EOF'
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pandas",
#   "matplotlib",
# ]
# ///

import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("data.csv")
print(df.describe())
EOF

# Run with automatic dependency management
$ uv run analyze.py
```

## Key Concepts

### 1. **Projects**
- Self-contained Python applications with `pyproject.toml`
- Automatic dependency locking with `uv.lock`
- Environment management with `uv sync`

### 2. **Workspaces**
- Monorepo support for multiple related packages
- Shared dependency resolution
- Defined in root `pyproject.toml`

### 3. **Resolution**
- Fast dependency resolver written in Rust
- Platform-specific resolution
- Supports complex version constraints

### 4. **Cache**
- Global package cache at `~/.cache/uv/` (Linux/macOS)
- Deduplication across projects
- Use `uv cache clean` to clear

### 5. **Python Versions**
- Automatic Python installation and management
- `.python-version` file for project pinning
- Multiple versions side-by-side

## Performance Tips

1. **Use `uv sync --frozen`** in CI to skip lockfile updates
2. **Leverage the cache** - don't use `--no-cache` unless necessary
3. **Use `uvx` for tools** instead of installing globally
4. **Pin Python versions** with `.python-version` for reproducibility
5. **Use workspaces** for monorepos to share dependencies

## Integration Guides

### PyTorch with CUDA
```bash
$ uv init pytorch-project
$ uv add torch --index pytorch --index-url https://download.pytorch.org/whl/cu118
```

### Jupyter Notebooks
```bash
$ uv add jupyter ipykernel
$ uv run jupyter notebook
```

### Pre-commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/uv-pre-commit
    rev: 0.5.0
    hooks:
      - id: uv-lock
```

### FastAPI Development
```bash
$ uv init --package my-api
$ uv add fastapi uvicorn[standard]
$ uv add --dev pytest httpx
$ uv run uvicorn myapi.main:app --reload
```

## Reference Files

Comprehensive documentation in `references/`:

- **uv.md** - Complete UV documentation (63 pages)
  - CLI reference for all commands
  - Detailed guides for projects, packages, and tools
  - Integration examples (Docker, GitHub, Jupyter, etc.)
  - Advanced topics (authentication, indexes, build backends)

## Troubleshooting

### Common Issues

**Issue: "No solution found"**
- Check version constraints in `pyproject.toml`
- Try `uv lock --upgrade` to get latest compatible versions
- Use `uv tree` to inspect dependency conflicts

**Issue: "Python version not found"**
- Install with `uv python install 3.12`
- Check `.python-version` file
- Verify `requires-python` in `pyproject.toml`

**Issue: "Package not found"**
- Verify package name spelling
- Check if package requires alternative index
- Use `--index-url` for custom indexes

## Migration Guide

### From tool.uv.dev-dependencies (Deprecated)

**IMPORTANT**: The `tool.uv.dev-dependencies` field is deprecated and will be removed in a future release. Use `[dependency-groups]` instead (PEP 735).

```toml
# ❌ Old (deprecated)
[tool.uv]
dev-dependencies = [
    "pytest>=7.0.0",
    "ruff>=0.1.0",
]

# ✅ New (correct)
[dependency-groups]
dev = [
    "pytest>=7.0.0",
    "ruff>=0.1.0",
]
```

When you run `uv add --dev pytest`, it will automatically use the new `[dependency-groups]` format for new projects.

### From pip + requirements.txt

```bash
# Before: pip install -r requirements.txt
# After:
$ uv init --no-package
$ uv add -r requirements.txt
$ uv sync
```

### From Poetry

```bash
# Before: poetry install
# After:
$ uv init --no-package
$ uv add $(poetry show --only main | awk '{print $1}')
$ uv sync
```

### From Pipenv

```bash
# Before: pipenv install
# After:
$ uv init --no-package
$ uv add $(pipenv requirements | grep -v "^#" | grep -v "^$")
$ uv sync
```

## Best Practices

1. **Always commit `uv.lock`** for reproducible builds
2. **Use `pyproject.toml`** instead of `requirements.txt`
3. **Pin Python version** with `.python-version`
4. **Separate dev dependencies** with `--dev` flag
5. **Use workspaces** for monorepos
6. **Leverage `uvx`** for one-off tool execution
7. **Configure indexes** in `pyproject.toml` for consistency

## Resources

- **Official Docs**: https://docs.astral.sh/uv/
- **GitHub**: https://github.com/astral-sh/uv
- **Installation**: `curl -LsSf https://astral.sh/uv/install.sh | sh`

## Notes

- This skill was generated from official UV documentation (v0.5.0+)
- All code examples are tested and production-ready
- UV is actively developed - check docs for latest features
- UV is 10-100x faster than pip for most operations
