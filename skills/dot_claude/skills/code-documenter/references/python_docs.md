# Python Documentation Standards

## Overview

Python documentation follows PEP 257 conventions with type hints from PEP 484. Use Google-style or NumPy-style docstrings for consistency.

## Module Docstrings

Place at the top of the file, explaining:
- Purpose of the module
- Key components or classes
- Usage examples if applicable

```python
"""Module for managing time-based productivity alerts.

This module provides classes and functions for creating, scheduling, and
delivering visual notifications to help users manage time blindness.

Example:
    >>> from productivity import AlertManager
    >>> manager = AlertManager()
    >>> manager.schedule_reminder(minutes=25, message="Take a break")
```

## Class Docstrings

Include:
- Purpose and responsibility
- Attributes section with types and descriptions
- Usage examples for complex classes

```python
class TimerDisplay:
    """Visual timer display with ADHD-optimized feedback.

    Provides smooth visual transitions and non-disruptive notifications
    suitable for professional environments.

    Attributes:
        remaining_seconds: Time remaining in current timer session
        urgency_level: Current urgency state (0.0 to 1.0)
        color_mode: Display color scheme ('standard' or 'colorblind')
    """
```

## Function/Method Docstrings

Include:
- Clear description of functionality
- Args section with names, types, and descriptions
- Returns section with type and description
- Raises section for exceptions

```python
def calculate_focus_quality(
    session_data: dict[str, Any],
    threshold: float = 0.6
) -> float:
    """Calculate focus quality score from session metrics.

    Analyzes productivity patterns to determine focus quality on a
    0.0 to 1.0 scale, with higher values indicating better focus.

    Args:
        session_data: Dictionary containing session metrics including
            'duration_seconds', 'interruptions', and 'completion_rate'
        threshold: Minimum acceptable focus quality (default: 0.6)

    Returns:
        Focus quality score between 0.0 and 1.0

    Raises:
        ValueError: If session_data is missing required keys
        TypeError: If duration_seconds is not numeric
    """
```

## Type Hints

Always use type hints in function signatures:

```python
from typing import Optional, List, Dict, Union
from pathlib import Path

def load_config(
    config_path: Path,
    defaults: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """Load configuration from file."""
```

## Inline Comments

Focus on "why" not "what":

```python
# Gradual color transition prevents jarring changes
# that could break hyperfocus inappropriately
current_color = self._smooth_transition(
    start=self.previous_color,
    end=target_color,
    duration_ms=500
)
```

## What NOT to Document

Avoid obvious comments:

```python
# BAD: Obvious comment
counter = counter + 1  # Increment counter

# GOOD: Explains why
counter += 1  # Track failed reconnection attempts
```

## Standards Summary

- Use triple double-quotes `"""` for docstrings
- First line: one-line summary ending with period
- Blank line before detailed description
- Google or NumPy style for consistency
- Type hints in signatures
- Document public APIs (classes, functions)
- Skip private methods unless complex
- Focus inline comments on "why" not "what"
