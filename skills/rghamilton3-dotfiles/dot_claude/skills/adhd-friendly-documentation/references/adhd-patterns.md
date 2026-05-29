# ADHD-Friendly Documentation Patterns

## Core Principles

### 1. Visual Hierarchy
- Use headers (H1, H2, H3) to create clear structure
- Keep nesting shallow (max 3-4 levels)
- Use visual breaks between sections
- Add whitespace generously

### 2. Scannable Content
- Lead with key information
- Use bullet points over paragraphs
- Keep paragraphs to 2-3 sentences max
- Bold important terms and actions
- Use code blocks for technical details

### 3. Progressive Disclosure
- Start with "What" and "Why" in 1-2 sentences
- Provide quick start/TL;DR sections
- Hide complexity in collapsible sections or separate pages
- Link to detailed explanations rather than including inline

### 4. Action-Oriented
- Start instructions with verbs (Run, Create, Install, Configure)
- Number sequential steps clearly
- Separate explanation from action
- Include expected outcomes after steps

### 5. Cognitive Load Reduction
- One concept per section
- Limit choices and options presented at once
- Use consistent terminology throughout
- Avoid jargon without definitions
- Include "why" for non-obvious steps

## Documentation Patterns

### Quick Start Pattern
```markdown
# Project Name

> One-line description of what this does

## Quick Start (60 seconds)

1. Install: `npm install package`
2. Run: `npm start`
3. Open: http://localhost:3000

**You should see:** A welcome screen with...

## What This Does

[2-3 sentence explanation]

## Next Steps
- [Learn core concepts](#concepts) (5 min)
- [Follow tutorial](#tutorial) (15 min)
- [Read API docs](#api) (reference)
```

### API Documentation Pattern
```markdown
## Function Name

**What it does:** One-line description

**When to use:** Brief use case

### Basic Usage
```code
// Minimal working example
```

**Returns:** What you get back

### Parameters
| Name | Type | Required | Description |
|------|------|----------|-------------|
| param1 | string | Yes | Brief explanation |

### Common Examples
[2-3 frequent use cases with code]

### Details
[Link to advanced usage, edge cases]
```

### Tutorial Pattern
```markdown
# Tutorial Title

**Goal:** What you'll build (1 sentence)
**Time:** Estimated duration
**Prerequisites:** What you need to know

## What You'll Learn
- [ ] Concept 1
- [ ] Concept 2
- [ ] Concept 3

---

## Step 1: [Action Verb]

**Goal:** What this step achieves

### Do This
```code
// Exact code to run
```

### What Happened
[Brief explanation of what changed]

### Checkpoint
✅ You should now see/have: [Expected result]

---

## Step 2: [Action Verb]
...
```

### Troubleshooting Pattern
```markdown
## Troubleshooting

### Quick Fixes
Common issues with one-line solutions:
- **Error X**: Run `command Y`
- **Issue Z**: Check that [condition]

### Detailed Issues

#### Problem: Specific Error Message
**Symptoms:** What you see
**Cause:** Why it happens
**Solution:**
1. First step
2. Second step
**Expected result:** What should change
```

## Visual Aids

### Use Tables for Comparison
| Feature | Option A | Option B |
|---------|----------|----------|
| Speed   | Fast     | Slow     |
| Size    | Large    | Small    |

### Use Callouts for Important Info
```markdown
> ⚠️ **Warning:** Critical information
> 💡 **Tip:** Helpful suggestion
> ℹ️ **Note:** Additional context
> ✅ **Success:** Expected outcome
```

### Use Diagrams for Relationships
- Flow charts for processes
- Sequence diagrams for interactions
- Architecture diagrams for structure
- Keep diagrams simple (max 5-7 elements)

## Anti-Patterns to Avoid

### ❌ Wall of Text
```markdown
This is a very long paragraph that goes on and on explaining
multiple concepts at once without any breaks or structure making
it very hard to scan and find the information you need especially
when you're trying to quickly understand what's happening...
```

### ✅ Better: Chunked Content
```markdown
This explains one concept clearly.

**Key point:** Important detail here.

The next paragraph introduces a new idea.
```

### ❌ Hidden Action Steps
```markdown
You'll want to install the dependencies and configure the
environment variables before running the server.
```

### ✅ Better: Explicit Steps
```markdown
**Setup (2 minutes):**

1. Install dependencies: `npm install`
2. Set environment: `cp .env.example .env`
3. Run server: `npm start`
```

### ❌ Ambiguous Language
```markdown
You might want to consider using the advanced configuration
if you need more control, which can be helpful in certain
situations.
```

### ✅ Better: Clear Guidance
```markdown
**Use basic config** for most projects.

**Use advanced config when:**
- You need custom caching
- You deploy to multiple regions
```

### ❌ Mixed Abstraction Levels
```markdown
First you install Docker, which uses containerization
technology that isolates processes using kernel namespaces,
then run `docker pull image`.
```

### ✅ Better: Consistent Level
```markdown
**Quick start:**
1. Install Docker
2. Run: `docker pull image`

[Learn how Docker works](#concepts) (optional)
```

## Formatting Conventions

### Headers
- H1: Page title only
- H2: Major sections
- H3: Sub-sections
- H4: Rare, for very detailed docs

### Code Blocks
- Always include language syntax
- Add comments for non-obvious lines
- Keep examples under 10 lines when possible
- Show complete, runnable code

### Lists
- Use bullets for unordered information
- Use numbers for sequential steps
- Keep each item to one line when possible
- Limit to 5-7 items per list

### Emphasis
- **Bold** for important terms and actions
- *Italic* sparingly, for slight emphasis
- `Code formatting` for technical terms, commands, file names
- AVOID ALL CAPS except in code/constants

## Content Organization

### Information Hierarchy
1. **Title + one-line summary**
2. **Quick start** (< 2 minutes)
3. **Core concepts** (5-10 min)
4. **Tutorials** (hands-on practice)
5. **API reference** (look-up)
6. **Advanced topics** (deep dives)

### File Structure
```
docs/
├── README.md (Quick start + overview)
├── getting-started.md (Tutorial)
├── concepts/
│   ├── core-idea-1.md
│   ├── core-idea-2.md
├── api/
│   ├── reference.md
└── advanced/
    ├── performance.md
    └── troubleshooting.md
```

### Page Length
- README: Under 200 lines
- Getting started: 100-300 lines
- Concept pages: 50-150 lines
- API reference: As needed, but well-structured

## Writing Style

### Voice
- Use imperative/command form for instructions
- Use present tense
- Use active voice
- Write conversationally but precisely

### Sentence Structure
- Lead with the action or key point
- Keep sentences under 20 words
- One idea per sentence
- Use simple sentence structures

### Examples
- Show before explaining when possible
- Include expected output
- Use realistic, relatable scenarios
- Explain non-obvious parts

## Accessibility Considerations

### For Screen Readers
- Use semantic markdown (proper headers, lists)
- Add alt text to images and diagrams
- Ensure link text is descriptive

### For Neurodivergent Readers
- Provide multiple entry points (visual, text, code)
- Allow skipping to relevant sections
- Include estimates for time/complexity
- Offer both detailed and brief explanations

### For Non-Native Speakers
- Use common, simple words
- Define technical terms
- Avoid idioms and colloquialisms
- Be explicit rather than implied
