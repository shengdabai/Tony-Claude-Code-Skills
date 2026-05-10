# Skill Usage System

A reusable skill that manages the progressive disclosure and automatic invocation of other skills across any project.

This is an effort to bootstrap the skills system when using Claude models through tools other than Claude.ai.

I have been testing this as a way to load skills when using Claude Sonnet via GitHub Copilot.

Please be careful when adding new skills. SKILL.md contains some instructions for auditing new skills from remote sources, but you should still manually review and only install skills from trusted sources.

## What This Skill Does

The `skill-usage` skill provides the core infrastructure for:
- **Automatic skill discovery** at session startup
- **Progressive disclosure** (loading metadata first, full content when needed)
- **Automatic invocation** based on task relevance
- **Skill composition** (multiple skills working together)

This allows you to build a library of specialized skills that Claude automatically uses when relevant, without cluttering the main configuration file.

## Installation

### As a Symlink (Recommended)

To share this skill across multiple projects without duplicating:

```bash
# Clone to a central location
mkdir -p ~/Projects/skills
git clone https://github.com/mgood/claude-skill-usage.git ~/Projects/skills/skill-usage

# Symlink to each project
ln -s ~/Projects/skills/skill-usage <project>/.claude/skills/skill-usage
```

Then ask Claude to initialize the skills system:

```
initialize the skills system described in .claude/skills/skill-usage/
```

Claude will automatically:
- Create or update `CLAUDE.md` file with the skills system configuration
- Scan the skills directory and register all available skills
- Set up the proper structure for automatic skill discovery and invocation

That's it! The skills system is now active and ready to use.

### Direct Clone

To install directly into a single project:

```bash
# Create the skills directory if it doesn't exist
mkdir -p .claude/skills

# Clone the skill-usage repository
git clone https://github.com/mgood/claude-skill-usage.git .claude/skills/skill-usage
```

### Download ZIP (No Git Required)

If you prefer not to use git:

1. Download the ZIP from GitHub: https://github.com/mgood/claude-skill-usage/archive/refs/heads/main.zip
2. Extract the ZIP file
3. Rename the extracted folder from `claude-skill-usage-main` to `skill-usage`
4. Move it to your project's `.claude/skills/` directory

Note: You'll need to manually download updates with this method.

## How It Works

### Progressive Disclosure

Instead of loading all skill instructions at once, the system:
1. **Startup**: Loads only YAML metadata from all skills
2. **Runtime**: Loads full instructions only when a skill is relevant
3. **On-demand**: Loads additional resources as needed

This optimizes context usage while keeping all skills available.

### Automatic Invocation

Claude reads skill descriptions and automatically loads relevant skills based on:
- The current task
- User intent
- Available context

Users don't need to explicitly invoke skills - it happens automatically.

### Explicit Invocation

Users can also explicitly request skills:
- "Use the [skill-name] skill to help me..."
- "Apply the [skill-name] skill to this..."

## Benefits

### For Projects
- **Minimal main configuration**: Skills system in just a few lines
- **Portable**: Same skill-usage system works across any project
- **Scalable**: Add new skills without modifying main config

### For Skills
- **Composable**: Skills work together automatically
- **Shareable**: Symlink skills across projects
- **Focused**: Each skill addresses one workflow

### For Users
- **Zero overhead**: Skills load automatically when relevant
- **No memorization**: Don't need to remember when to invoke
- **Progressive learning**: System improves as skills are added

## Creating New Skills

See `SKILL.md` for complete documentation on creating skills.

**Recommended**: Install the `skill-creator` skill for guided assistance:
- Provides templates and best practices for skill creation
- Helps structure skill instructions effectively
- Ensures proper metadata and formatting
- Available at: https://github.com/anthropics/skills

Quick start (manual):
1. Create a directory in your skills folder
2. Add a `SKILL.md` with metadata and instructions
3. Claude will automatically discover and use it

## Example Configuration Comparison

### Before (traditional approach)
```markdown
# CLAUDE.md (5000+ lines with all workflows)

## Workflow A
[500 lines of detailed instructions]

## Workflow B
[300 lines of detailed instructions]

## Workflow C
[400 lines of detailed instructions]

## Workflow D
[350 lines of detailed instructions]

[... many more workflows ...]
```

### After (with skill-usage)
```markdown
# CLAUDE.md (minimal core config)

## Skills System

**Skills Location**: `project/.claude/skills/`

**Available skills** (automatically invoked based on context):

- **skill-usage** (v1.0.0) - Core skills system that manages loading and using other skills through progressive disclosure. Load at startup to enable automatic skill discovery and invocation across all projects.
- **workflow-a** (v1.0.0) - [One-line description of when to use this workflow]
- **workflow-b** (v1.0.0) - [One-line description of when to use this workflow]

**How skills work:**
- Claude reads the descriptions above to determine when each skill is relevant
- When a task matches a skill's description, Claude automatically loads the full skill instructions
- Skills can be explicitly requested: "Use the [skill-name] skill to..."
```

Each workflow becomes a separate skill file that loads only when needed. Claude reads the one-line descriptions and automatically loads the full skill instructions when the task matches.

## Version History

- **1.0.0**: Initial release with progressive disclosure and automatic invocation

## License

MIT License - feel free to use, modify, and share

## Resources

- Skills repository: https://github.com/anthropics/skills
- Creating skills: https://support.claude.com/en/articles/12512198-how-to-create-custom-skills
- Using skills: https://support.claude.com/en/articles/12512180-using-skills-in-claude
