---
name: code-documenter
description: Automatically detect and add comprehensive documentation to code files across multiple languages (Python, JavaScript/TypeScript, C/C++, Dart/Flutter). Generate language-appropriate docstrings, comments, and examples following industry standards. Use when code files lack documentation, after implementing new features, or when requested to document code. Support single files and batch documentation.
---

# Code Documenter

## Overview

Add or update professional documentation to code files following language-specific best practices and industry conventions. Reduce cognitive load by providing clear, well-structured documentation that explains "why" rather than just "what."

## Related Tools

This skill focuses on **code-level documentation** (docstrings, inline comments).

For **project-level documentation**, use:
- `/doc-generate` - Generate API docs, architecture diagrams, README files
- `code-documentation` plugin - Automated project documentation workflows

**Decision**: Use this skill for code, plugin for projects.

## Supported Languages

- **Python**: PEP 257 docstrings with type hints (Google/NumPy style)
- **JavaScript/TypeScript**: JSDoc/TSDoc comments with examples
- **C/C++**: Doxygen-style documentation with memory safety notes
- **Dart/Flutter**: Triple-slash comments with widget documentation

## When to Use This Skill

This skill should be used when:

1. **Explicit request**: User asks to "document this code" or "add documentation"
2. **Auto-detection scenarios**:
   - New code has been written without documentation
   - Existing code lacks adequate docstrings/comments
   - Public APIs are undocumented
   - Complex logic needs explanation
3. **After code changes**: When implementing features or fixing bugs
4. **Before commits**: When preparing code for review

## Documentation Workflow

### Step 1: Identify Files to Document

Determine which files need documentation:

- If user provides file path(s), use those specific files
- If user says "document my changes," check git status for modified files
- If user says "document this," use the file currently in context
- For "document everything," ask user to confirm scope

### Step 2: Detect Language and Load Standards

For each file, detect the programming language by extension:

- `.py` → Python: Read `references/python_docs.md`
- `.js, .ts, .jsx, .tsx` → JavaScript/TypeScript: Read `references/javascript_typescript_docs.md`
- `.cpp, .cc, .h, .hpp, .c` → C/C++: Read `references/cpp_docs.md`
- `.dart` → Dart/Flutter: Read `references/dart_flutter_docs.md`

If language is unsupported, inform user and skip the file.

Load only the relevant reference file into context to avoid token waste. Do not load all language references at once.

### Step 3: Analyze Code Structure

Read the target file and identify:

1. **Top-level documentation**: Module/file docstring
2. **Classes/Interfaces**: Class documentation, attributes, purpose
3. **Functions/Methods**: Parameter descriptions, return values, exceptions
4. **Complex logic**: Areas needing inline comments
5. **Constants/Enums**: Purpose and usage documentation

### Step 4: Apply Documentation Standards

Following the loaded language standards, add documentation at the **standard detail level**:

- Document all public APIs (classes, functions, methods)
- Add module/file-level documentation
- Include parameter and return value descriptions
- Add inline comments for non-obvious logic
- Skip private methods unless they're complex
- Include usage examples for complex APIs

**Key Principles**:
- First line should be a concise one-line summary
- Explain "why" in comments, not "what"
- Use proper formatting for the language (PEP 257, JSDoc, Doxygen, etc.)
- Include type information where applicable
- Add examples for complex usage patterns
- Note side effects, thread safety, memory ownership

### Step 5: Preserve Code Logic

**CRITICAL**: Do not modify the actual code logic, only add documentation.

- Add docstrings/comments without changing functionality
- Preserve existing formatting and style
- Keep all existing code intact
- Only add documentation blocks and inline comments

### Step 6: Apply Changes

Use the Edit tool to add documentation:

1. **For module/file documentation**: Add at the very top of the file
2. **For class documentation**: Add immediately before class definition
3. **For function documentation**: Add immediately before function definition
4. **For inline comments**: Add on line above or at end of complex statements

Make multiple small, focused edits rather than one large replacement.

### Step 7: Verify and Report

After documenting:

1. Confirm all public APIs are documented
2. Check that complex logic has explanatory comments
3. Verify formatting matches language conventions
4. Report summary to user:
   - Files documented
   - Documentation elements added (modules, classes, functions)
   - Any issues or skipped items

## Language-Specific Quick Reference

### Python

```python
"""Module-level docstring explaining purpose."""

class Example:
    """Class docstring with purpose.

    Attributes:
        attr_name: Description with type info
    """

    def method(self, param: str) -> bool:
        """One-line description.

        Args:
            param: Parameter description

        Returns:
            Return value description

        Raises:
            ExceptionType: When this occurs
        """
```

### JavaScript/TypeScript

```typescript
/**
 * Function description.
 *
 * @param param - Parameter description
 * @returns Return value description
 * @throws {ErrorType} When error occurs
 *
 * @example
 * ```typescript
 * const result = example('value');
 * ```
 */
function example(param: string): boolean {
```

### C/C++

```cpp
/**
 * @file filename.h
 * @brief Brief file description
 */

/**
 * @brief Function description
 *
 * @param param Parameter description
 * @return Return value description
 *
 * @warning Important warnings
 * @threadsafe Thread safety information
 */
bool example(const std::string& param);
```

### Dart/Flutter

```dart
/// Function description.
///
/// Detailed explanation if needed.
///
/// Returns description.
///
/// Throws [ExceptionType] when error occurs.
///
/// Example:
/// ```dart
/// final result = example('value');
/// ```
bool example(String param) {
```

## Examples

### Example 1: Document Single Python File

**User request**: "Document this file"

**Process**:
1. Detect file is Python (.py extension)
2. Read `references/python_docs.md`
3. Analyze file structure (modules, classes, functions)
4. Add PEP 257 docstrings following Google style
5. Add inline comments for complex logic
6. Report: "Added module docstring, 3 class docstrings, 12 function docstrings, and 8 inline comments"

### Example 2: Document Changed TypeScript Files

**User request**: "Document my changes"

**Process**:
1. Check git status for modified .ts/.tsx files
2. For each file: detect TypeScript
3. Read `references/javascript_typescript_docs.md`
4. Add JSDoc comments to new/modified functions
5. Update existing docstrings if signatures changed
6. Report: "Documented 5 TypeScript files with 23 functions"

### Example 3: Document C++ Header

**User request**: "Add documentation to timer.h"

**Process**:
1. Detect C++ from .h extension
2. Read `references/cpp_docs.md`
3. Add file-level @file and @brief
4. Document all public classes and methods
5. Add @note for thread safety, memory ownership
6. Report: "Added file header, 2 class docs, 15 method docs with threading notes"

## Advanced Features

### Batch Documentation

When documenting multiple files:

1. Group files by language to minimize reference file loading
2. Process all Python files, then JavaScript, then C++, etc.
3. Load each language reference only once
4. Report progress: "Documenting file 3 of 8..."
5. Provide summary at end with breakdown by language

### Smart Detection of Documentation Needs

Automatically identify what needs documentation:

- **Missing module docstrings**: Top of file has no documentation
- **Undocumented public APIs**: Classes/functions lack docstrings
- **Complex logic**: Code blocks with high cyclomatic complexity
- **Recent changes**: Functions modified in recent commits
- **TODO/FIXME comments**: Areas marked for attention

### Handling Edge Cases

**Mixed languages in project**: Document each file in its native style

**Partially documented code**: Fill in gaps without duplicating existing docs

**Generated code**: Skip auto-generated files (ask user if uncertain)

**Test files**: Use simpler documentation (purpose and what is tested)

**Legacy code**: Add minimal documentation first, suggest comprehensive pass

## Best Practices

1. **Read the file first**: Always read the target file before documenting
2. **Load references as needed**: Don't load all language references at once
3. **Multiple small edits**: Make focused edits rather than large replacements
4. **Preserve formatting**: Match existing code style and indentation
5. **Explain "why" not "what"**: Focus comments on reasoning, not mechanics
6. **Include examples**: Add usage examples for complex APIs
7. **Note constraints**: Document preconditions, thread safety, ownership
8. **Update existing docs**: If code changed, update related documentation

## Resources

### references/

Language-specific documentation standards:

- `python_docs.md` - PEP 257 conventions, type hints, Google/NumPy style
- `javascript_typescript_docs.md` - JSDoc/TSDoc standards with examples
- `cpp_docs.md` - Doxygen conventions, thread safety, memory management
- `dart_flutter_docs.md` - Dart doc comments, Flutter widget documentation

Load only the relevant reference when documenting files in that language.
