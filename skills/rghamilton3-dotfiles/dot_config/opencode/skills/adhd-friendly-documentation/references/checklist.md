# ADHD-Friendly Documentation Checklist

Use this checklist to validate documentation before publishing.

## Structure & Hierarchy ✓

- [ ] Page has a clear H1 title
- [ ] One-line summary appears near the top
- [ ] Headers create clear visual hierarchy (H2, H3 max)
- [ ] Header nesting doesn't exceed 3-4 levels
- [ ] Related content is grouped under clear section headers

## Scannability ✓

- [ ] Key information appears in the first 2-3 lines
- [ ] Paragraphs are 2-3 sentences maximum
- [ ] Bullet points used instead of long paragraphs
- [ ] Important terms and actions are **bolded**
- [ ] Code/technical terms use `code formatting`
- [ ] Generous whitespace between sections

## Progressive Disclosure ✓

- [ ] Quick start or TL;DR section included
- [ ] Complex details hidden in expandable sections or links
- [ ] "Next steps" or "Learn more" links provided
- [ ] Advanced topics separated from basics

## Action Steps ✓

- [ ] Instructions start with action verbs (Run, Create, Install)
- [ ] Sequential steps are numbered clearly
- [ ] Each step is explicit (no implied actions)
- [ ] Expected outcomes included after steps
- [ ] Code examples are complete and runnable

## Cognitive Load ✓

- [ ] One concept per section
- [ ] Consistent terminology throughout
- [ ] Technical jargon defined on first use
- [ ] No "walls of text" (no paragraphs > 5 sentences)
- [ ] Examples included for abstract concepts
- [ ] Time estimates provided for tutorials/guides

## Visual Elements ✓

- [ ] Tables used for comparisons
- [ ] Callouts/blockquotes for warnings, tips, notes
- [ ] Diagrams included for complex relationships
- [ ] Lists limited to 5-7 items
- [ ] Code blocks include language syntax highlighting

## Content Quality ✓

- [ ] Title clearly states what the doc covers
- [ ] Prerequisites listed upfront
- [ ] "What you'll learn" or goals stated early
- [ ] Common use cases/examples included
- [ ] Troubleshooting section for known issues
- [ ] Links to related documentation

## Writing Style ✓

- [ ] Uses imperative/command form for instructions
- [ ] Active voice used throughout
- [ ] Sentences under 20 words
- [ ] One idea per sentence
- [ ] Avoids idioms and colloquialisms

## Accessibility ✓

- [ ] Images/diagrams have alt text
- [ ] Links have descriptive text (not "click here")
- [ ] Semantic markdown used (headers, lists, emphasis)
- [ ] Content works well with screen readers

## Common Anti-Patterns (Avoid These) ❌

- [ ] No walls of text (check: any paragraph > 5 sentences?)
- [ ] No ambiguous language ("might," "could," "sometimes")
- [ ] No hidden action steps in paragraphs
- [ ] No mixing abstraction levels in same section
- [ ] No missing expected outcomes
- [ ] No undefined jargon/acronyms

## Quick Validation Tests

### The Skim Test
Can someone skim the headers and bullets and understand:
- [ ] What this documentation covers
- [ ] Where to start
- [ ] How to find what they need

### The 30-Second Test
In 30 seconds, can a reader:
- [ ] Understand what this is about
- [ ] Know if it's relevant to them
- [ ] Find the quick start or next step

### The Copy-Paste Test
For tutorials/guides:
- [ ] Can someone copy and paste code examples and have them work?
- [ ] Are all commands complete and accurate?
- [ ] Is the expected output shown?

### The Accessibility Test
- [ ] Can you understand the doc with images removed?
- [ ] Does the structure make sense with just headers visible?
- [ ] Are all links and references clear?

## Score Your Documentation

Count your ✓ marks:

- **35-40**: Excellent! ADHD-friendly and accessible
- **25-34**: Good, but room for improvement
- **15-24**: Needs work on structure and scannability
- **< 15**: Significant revision recommended

## Priority Fixes

If time is limited, focus on these high-impact items:

1. ✨ **Add clear headers** - Most important for scanning
2. ✨ **Break up long paragraphs** - Biggest readability win
3. ✨ **Add quick start section** - Helps readers get started fast
4. ✨ **Number sequential steps** - Clarifies instructions
5. ✨ **Bold key terms and actions** - Improves scanning
