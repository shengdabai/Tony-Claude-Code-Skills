---
description: Ensure code has up-to-date documentation and update project docs
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(git diff:*), Bash(git status:*)
---

Please help me ensure all code changes have proper documentation and that project documentation is updated accordingly.

IMPORTANT: This is a comprehensive documentation review and update process.

## Phase 1: Identify Changed Code

1. Check for recent code changes:
   - If in a git repository, run `git status` and `git diff` to identify modified files
   - If not in git, ask the user which files or directories to review

2. Identify all code files that need documentation review:
   - Recently modified or added files
   - Files the user specifically mentions
   - Core implementation files in the project

## Phase 2: Update Code-Level Documentation

For each code file identified, ensure:

1. **File-level documentation**:
   - Each file has a header comment explaining its purpose
   - Module/file docstrings are present and accurate (for Python, JavaScript, etc.)
   - File headers include relevant information (purpose, main exports, dependencies)

2. **Function/Method documentation**:
   - All public functions have docstrings/JSDoc/comments explaining:
     - Purpose and behavior
     - Parameters (types and descriptions)
     - Return values (types and descriptions)
     - Exceptions/errors that may be thrown
     - Usage examples for complex functions
   - Private functions have comments for non-obvious logic

3. **Class documentation**:
   - Class-level docstrings explain the class purpose
   - Constructor parameters are documented
   - Public methods are documented
   - Important properties/attributes are explained

4. **Inline comments**:
   - Complex algorithms have explanatory comments
   - Non-obvious code has clarifying comments
   - TODOs, FIXMEs, or HACKs are properly noted
   - Remove outdated or misleading comments

5. **Type annotations** (where applicable):
   - TypeScript: proper type definitions
   - Python: type hints for function signatures
   - Other languages: appropriate type documentation

## Phase 3: Update Project Documentation

1. **README.md**:
   - If it exists, read and update it to reflect:
     - Accurate project description
     - Updated installation instructions
     - Current usage examples
     - New features or changed APIs
     - Updated dependencies or requirements
   - Ensure all code examples in README still work
   - Update badges, links, or references if needed

2. **docs/ directory**:
   - If a docs/ folder exists, search for all markdown files
   - Update API documentation to match current code
   - Add documentation for new features
   - Update tutorials or guides if code changes affect them
   - Ensure consistency across all documentation files

3. **CHANGELOG.md**:
   - If it exists, consider whether recent changes warrant a changelog entry
   - Suggest adding entries for significant changes

4. **API documentation**:
   - Update any API reference documentation
   - Ensure endpoint descriptions match implementation
   - Update request/response examples

5. **Other documentation files**:
   - Look for CONTRIBUTING.md, ARCHITECTURE.md, etc.
   - Update if changes affect these documents

## Phase 4: Documentation Standards and Consistency

Ensure all documentation follows consistent standards:

1. **Style consistency**:
   - Use consistent formatting (heading levels, code blocks, etc.)
   - Follow the project's existing documentation style
   - Use consistent terminology throughout

2. **Completeness**:
   - All public APIs are documented
   - Configuration options are explained
   - Environment variables are documented
   - Build/deployment steps are clear

3. **Accuracy**:
   - Remove references to removed features
   - Update outdated information
   - Ensure code examples actually work

4. **Links and references**:
   - Update internal links if files moved
   - Check external links are still valid
   - Update version numbers where relevant

## Phase 5: Summary and Recommendations

After completing updates:

1. Provide a summary of:
   - Files updated with documentation
   - New documentation added
   - Documentation files modified
   - Any areas that need manual review

2. Recommend:
   - Additional documentation that might be helpful
   - Areas where documentation is lacking
   - Potential improvements to documentation structure

3. Suggest whether to commit the documentation updates

## Important Notes:

- DO NOT create new documentation files unless they're essential (e.g., don't create README.md if it doesn't exist unless explicitly asked)
- ALWAYS prefer editing existing documentation over creating new files
- Maintain the existing documentation style and structure
- Focus on clarity, accuracy, and usefulness
- Ensure documentation matches the actual code behavior
- Use clear, concise language in all documentation
- Include practical examples where helpful
- Consider the audience (developers, users, contributors)

Please proceed with the documentation review and updates systematically.
