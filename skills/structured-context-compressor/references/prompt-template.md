# Portable Prompt Template

```md
Create a structured continuation summary for a long conversation.

Return exactly these sections:
1. Primary request and intent
2. Key technical concepts
3. Files and code sections
4. Errors and fixes
5. Problem solving
6. All user messages
7. Pending tasks
8. Current work
9. Next aligned step

Rules:
- preserve user intent precisely
- include all user messages or an accurate condensed equivalent
- keep the next step aligned to the most recent explicit request
- if the current work is unclear, say that explicitly rather than guessing
```
