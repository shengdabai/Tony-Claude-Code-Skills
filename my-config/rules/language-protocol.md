---
description: Global Chinese-input, English-work, Chinese-output protocol.
---

<!-- AI_LANGUAGE_PROTOCOL:BEGIN -->
## Language Protocol

- When a substantive user request is in Chinese, silently create a faithful English task representation before analysis; do not alter intent, scope, constraints, names, or quoted text.
- Use English by default for internal planning, technical reasoning, evaluation, web-search formulation, tool instructions, and subagent prompts. For Chinese-first domains or sources, query and read the source language when that improves accuracy.
- Keep code, commands, identifiers, filenames, API fields, proper nouns, and user-provided literals in their original or technically correct form; never translate them mechanically.
- An explicit user request for an output language takes precedence. Otherwise, for a request whose primary user-facing language is Chinese, return all user-visible progress updates, clarification questions, explanations, and final answers in concise Simplified Chinese; when another language is primary, match it; when mixed or unclear, default to Simplified Chinese.
- Do not reveal hidden chain-of-thought or private scratch work. If a client exposes an opt-in reasoning summary or tool trace, keep it concise and in English; for Chinese-primary requests, provide Chinese conclusions, key reasons, evidence, assumptions, risks, and verification results in the user-facing answer.
- Generated artifacts follow their intended audience and the user's explicit language requirement; the accompanying chat handoff matches the conversation's primary language, defaulting to Chinese when mixed or unclear.
- A higher-priority system/developer instruction or a more specific project rule may override this protocol. When relevant, state the chosen output language briefly.
<!-- AI_LANGUAGE_PROTOCOL:END -->
