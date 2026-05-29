---
name: dedao-write
version: 1.1.0
description: |
  Eight-role expert writing pipeline that turns a vague idea into a finished,
  fact-checked, on-brand long-form article. Roles run as ordered phases:
  topic strategist, knowledge steward, researcher, writer, voice-polisher,
  fact-checker, editor-in-chief, and layout designer. The voice-polisher
  learns the user's personal style from their past writing (brain + GetNote
  + Obsidian + AI archive) so the finished piece reads in the user's own voice.
  Each role runs on a cost-appropriate model per the model-routing convention.
triggers:
  - "dedao write"
  - "得到体写作"
  - "expert writing"
  - "write an article"
  - "help me write a long-form piece"
  - "ghostwrite in my voice"
  - "write this in my style"
  - "full writing pipeline"
  - "take this idea and write it"
tools:
  - query
  - search
  - get_page
  - put_page
mutating: true
writes_pages: true
writes_to:
  - writing/
---

# dedao-write — Eight-Role Writing Pipeline

> **Convention:** see [conventions/quality.md](../conventions/quality.md) for the
> MANDATORY citation format, source precedence, and back-link rules.
>
> **Convention:** see [conventions/brain-first.md](../conventions/brain-first.md) —
> check the brain (and the user's own notes) before reaching for external sources.
>
> **Convention:** see [conventions/model-routing.md](../conventions/model-routing.md) —
> each role runs on a cost-appropriate model (see the per-phase Model line below).
>
> **Convention:** see [conventions/subagent-routing.md](../conventions/subagent-routing.md) —
> when to run a phase inline vs as a Minion (long phases, user walks away).
>
> **Filing rule:** see [_brain-filing-rules.md](../_brain-filing-rules.md) —
> finished articles file under `writing/`.

## What this solves

A good article needs eight different kinds of judgment, and one person (or one
undifferentiated LLM pass) does all of them badly at once: picking the right
angle, gathering the user's own material, finding evidence, drafting, matching
the user's voice, checking facts, editing structure, and laying it out. This
skill splits the work into eight named roles that run as sequential phases.
Each phase has a single job, reads the previous phase's output, and hands a
clean artifact to the next.

The defining feature is the **voice-polisher** (Phase 5): it studies the user's
past writing across every store they own — gbrain `writing/` + `originals/`,
GetNote saved knowledge, the Obsidian vault, and the cross-model AI archive —
so the finished piece reads like the user wrote it, not like an LLM did.

## The eight roles (run in order)

```
Phase 1  Topic Strategist    选题策划   Pick the angle worth writing + lock the spec
Phase 2  Knowledge Steward   知识管家   Pull the user's OWN material AND voice samples
Phase 3  Researcher          调研专家   Add data + stories as evidence for each claim
Phase 4  Writer              写手       Turn scattered material into a complete draft
Phase 5  Voice Polisher      风格打磨师 Rewrite the draft in the user's personal voice
Phase 6  Fact-Checker        事实核查   Verify every fact, number, date, name, quote
Phase 7  Editor-in-Chief     主编       Audit structure, logic, expression, reader value
Phase 8  Layout Designer     排版设计师 Present it with hierarchy for CJK + English
```

Each phase is a focused pass. Do not collapse them — the value is in the
separation. A phase may loop back one step (editor → writer) but never skips.

**Model routing (per model-routing.md).** Roles differ wildly in cognitive load;
do not run all eight on one model:

| Phase | Role | Model | Why |
|---|---|---|---|
| 1 | Topic Strategist | Opus | Angle selection is high-judgment |
| 2 | Knowledge Steward | Sonnet | Retrieval + dedup, mechanical |
| 3 | Researcher | DeepSeek/Qwen | Large-context gathering, cheap |
| 4 | Writer | Opus | Drafting is the core craft pass |
| 5 | Voice Polisher | Opus | Voice matching needs the best model |
| 6 | Fact-Checker | Sonnet | Verification is checklist-driven |
| 7 | Editor-in-Chief | Opus | Structural + logic judgment |
| 8 | Layout Designer | Sonnet | Formatting is rule-driven |

**Inline vs Minion (per subagent-routing.md).** Short phases (1, 8) run inline.
Phases 3–7 can be long; if the user will walk away or wants progress, run them as
Minions. If >3 phases need to run concurrently you would use Minions — but this
pipeline is sequential, so concurrency is not a factor here.

---

## Phase 1 — Topic Strategist (选题策划)   · Model: Opus

**Job:** From a fuzzy idea, pick the single most-worth-writing topic, lock a
sharp angle, AND fix the article spec (length, depth, channel). Do NOT gather
material yet. The spec drives every later role's granularity.

1. Restate the user's raw idea in one sentence.
2. Generate 3–5 candidate angles. For each: who it's for, what it argues, why
   it's worth the reader's time, what makes it non-obvious.
3. Score each on: does the user have unique material/experience for it
   (`gbrain query` for prior takes), is the claim defensible, is the audience real.
4. Recommend ONE. State: working title, one-sentence thesis, intended reader,
   the promise (what the reader can DO after reading), and the **spec**:
   target length (e.g. ~2000 字 / ~1500 words), depth level (overview vs deep),
   and publish channel (公众号 / blog / newsletter) — channel sets tone + format.

**Output:** a topic brief — `{working_title, thesis, audience, promise, spec:{length, depth, channel}, why_this_angle}`.

**Human checkpoint (recommended):** topic + angle is the highest-leverage human
decision. Show the brief and confirm before Phase 2 — unless the user's request
already pinned the angle, in which case proceed and note the assumption.

## Phase 2 — Knowledge Steward (知识管家)   · Model: Sonnet

**Job:** In ONE retrieval pass, surface BOTH (a) the user's own knowledge on this
topic and (b) representative samples of the user's past writing for voice study.
Gathering both here means Phase 5 reuses these samples instead of re-scanning the
stores a second time.

Query, in this order (brain-first, then the user's other stores):

1. **gbrain** — the primary store:
   ```bash
   gbrain query "<thesis keywords>" --json            # topic material
   gbrain query "type:writing <topic>" --limit 50 --json
   gbrain query "type:writing" --limit 20 --json       # voice samples (any topic)
   gbrain list --tag <topic> --json
   ```
2. **GetNote** — saved knowledge and recordings (MCP):
   `mcp__getnote__recall` / `mcp__getnote__recall_knowledge` on topic keywords;
   `list_topic_notes` if a matching topic exists.
3. **Obsidian vault** — local markdown notes (MCP `mcp__obsidian` search-vault).
4. **AI archive** — prior cross-model conversations:
   `ai-search "<topic>"` (Claude/Codex/Gemini history, already secret-redacted).

For each store: if it's unavailable or empty, log "store X: no material" and move
on — never block the pipeline on one missing store.

**Output:** a material dossier with two parts —
(a) **topic material**: deduplicated user points, prior phrasings, anecdotes,
half-formed takes, each source-tagged (brain slug / GetNote id / Obsidian path /
archive file), verbatim where the phrasing is good;
(b) **voice samples**: 3–8 of the user's past pieces (full or substantial excerpts)
set aside for Phase 5, so the polisher does not re-query the stores.

## Phase 3 — Researcher (调研专家)   · Model: DeepSeek/Qwen (cheap, large-context)

**Job:** For each claim in the thesis, attach supporting evidence — data, studies,
concrete stories. The steward gave the user's side; the researcher adds backing.

1. List every assertion the article will make.
2. For each, find a number/data point, a credible source, or a concrete
   story/example. Prefer the brain first (`gbrain query`), then external sources
   only where the brain is thin.
3. Record source metadata for EVERY external fact: `{publication, author, url,
   date}` — enough for the fact-checker to re-find it and for Phase 8 to build the
   citation in the format defined by
   [conventions/quality.md](../conventions/quality.md).
4. Flag any claim with no evidence as `UNSUPPORTED` — the writer softens it or
   the editor cuts it.

**Output:** an evidence map — `claim → [{type, content, source:{publication, author, url, date}}]`,
with `UNSUPPORTED` flags where backing is missing.

## Phase 4 — Writer (写手)   · Model: Opus

**Job:** Turn the scattered material (dossier + evidence map) into one complete,
coherent draft sized to the Phase 1 spec. This is where zero-in-on-structure
happens — pull the pieces into a single continuous expression.

1. Build a working outline from the thesis sized to `spec.length` and
   `spec.depth`: opening hook → argument sections → close. Each section maps to
   claims + their evidence.
2. **Title + opening hook get a dedicated pass.** Draft 2–3 title options and a
   first paragraph that earns the reader's attention; these carry the most weight
   and are worth isolating from body drafting.
3. Write the full draft in continuous prose. Weave the steward's user-material
   and the researcher's evidence into each section. Reuse the user's own phrasings
   from the dossier verbatim wherever they fit (not paraphrased).
4. Every external fact carries an inline citation marker tied to the evidence map
   (final citation formatting is applied in Phase 8 per quality.md).
5. Do NOT polish voice and do NOT fact-check yet — later phases. Goal here is
   completeness, correct length, and logical flow, not finish.

**Output:** a complete first draft (markdown) sized to spec, with title options,
a worked opening, section structure, and inline citation markers. Coverage check:
every non-`UNSUPPORTED` claim appears; every piece of evidence is used or
consciously dropped.

## Phase 5 — Voice Polisher (风格打磨师)   · Model: Opus

**Job:** Rewrite the draft so it reads in the user's personal voice. The signature
role. Learn the style from the **voice samples Phase 2 already gathered** (do not
re-query the stores), build a fingerprint, then apply it.

1. **Learn the voice** from the Phase 2 voice samples. Extract a concrete
   fingerprint: sentence length and rhythm, paragraph shape, favored connectors
   and transitions, punctuation habits (em-dash vs comma, CJK full-width usage),
   how the user opens and closes, level of directness, recurring metaphors,
   vocabulary tells, and what the user never does.
2. **Apply it.** Rewrite the draft to match the fingerprint. Preserve every fact,
   number, citation marker, and structural beat — change only voice, rhythm, word
   choice, and transitions. Prefer the verbatim user-phrasings from the dossier.
3. If Phase 2 surfaced fewer than ~3 voice samples, say so explicitly, apply a
   light touch, and ask the user for 1–2 reference pieces rather than inventing a
   voice.

**Output:** the draft rewritten in the user's voice, plus a short
`style_fingerprint` note recording what was matched (so later runs are consistent).
Facts and citation markers untouched.

## Phase 6 — Fact-Checker (事实核查)   · Model: Sonnet

**Job:** Verify every fact, number, date, name, and quote. Trust nothing that
can't survive scrutiny.

1. Enumerate every checkable claim: numbers, dates, names, quotes, attributions,
   "studies show" statements.
2. Re-verify each against its source in the evidence map. Re-fetch external
   sources where needed (use the web/fetch tooling available in the session, e.g.
   `firecrawl` MCP or `ai-search` for prior captures — this skill's declared
   gbrain tools cover brain re-verification; web re-fetch uses session tooling).
   A quote must match verbatim; a number must match the cited figure; a date and
   a name must be exact.
3. Mark each: `VERIFIED` (with source), `CORRECTED` (old → new + source), or
   `UNVERIFIABLE` (no source survives — flag for the editor to cut or soften).
4. Confirm every external claim carries a citation marker; add missing ones or
   flag the claim.

**Output:** a fact-check report — every checkable claim with its verdict and
source — plus a corrected draft with every `CORRECTED` fix applied inline. Never
let an `UNVERIFIABLE` claim pass silently toward publication.

## Phase 7 — Editor-in-Chief (主编)   · Model: Opus

**Job:** The gate before publication. Audit the whole piece — structure, logic,
expression, AND whether it delivers the Phase 1 promise to the reader.

1. **Structure:** does the opening earn attention, do sections flow, does the
   close land?
2. **Logic:** does each argument follow, are there gaps or non-sequiturs, does
   any `UNSUPPORTED`/`UNVERIFIABLE` claim still need cutting or softening?
3. **Reader value:** measure the draft against the Phase 1 `promise` — can the
   intended reader actually DO what the article promised after reading? If not,
   name the gap. This is the acceptance test, not a vibe check.
4. **Expression:** cut redundancy, tighten flabby sentences, fix anything fighting
   the user's voice — without re-introducing facts the checker removed.
5. Produce a severity-ordered findings list; apply the fixes. If a structural fix
   needs real rewriting, loop back to the Writer (Phase 4) for that section, then
   re-run Phases 5–6 on the changed text ONLY.

**Output:** the publication-ready draft + an editor's findings list (what was
fixed, what was cut, what looped back, promise-delivery verdict).

## Phase 8 — Layout Designer (排版设计师)   · Model: Sonnet

**Job:** Present the finished content with visual hierarchy, apply the mandatory
citation format, and file it. Respect both Chinese and English publishing
conventions.

1. **Hierarchy:** title, section headings, subheads where they earn their place.
2. **Supporting detail:** pull quotes, callouts, tables for comparative data,
   lists where prose would be dense, code/quote blocks.
3. **Citations (MANDATORY):** convert every inline citation marker to the final
   citation form and honor source precedence exactly as defined in
   [conventions/quality.md](../conventions/quality.md) (do not restate the format
   templates here — quality.md is the single source of truth for them).
4. **CJK + English typography (apply directly, do not defer):**
   - Chinese runs use full-width punctuation:`，。：；？！「」（）`— never ASCII `,.:;?!()` inside CJK text.
   - Add a space between CJK and adjacent Latin letters or Arabic numerals
     (e.g. `用 Opus 写` not `用Opus写`), unless the user's own voice sample
     consistently omits it.
   - Normalize mixed numbering (`1.` vs `1．` vs `(1)`) to one style per the channel.
   - Keep heading levels and emphasis (`**bold**`) consistent throughout.
5. **File it:** write to `writing/<slug>.md` with frontmatter
   (`title`, `type: writing`, `date`, `tags`), citations in final form, and create
   back-links per quality.md (every mentioned person/company with a brain page
   gets a back-link from that entity's page).

**Output:** the laid-out, filed article at `writing/<slug>.md`, plus a one-line
pointer to the slug it landed at.

---

## Phase chaining & loop control

- Phases run **in order, once each**, by default.
- The only allowed loop is **Editor (7) → Writer (4)** for a section that needs
  real rewriting; after the loop, re-run **Voice (5)** and **Fact-Check (6)** on
  the changed text ONLY, not the whole piece.
- Never skip a phase. Never run two roles as one blended pass — the separation is
  the point.
- **Human checkpoints (recommended, not mandatory):** Phase 1 (topic/angle) and
  Phase 5 (voice) are the two decisions most worth a quick user confirm. Pause
  there if the request left them open; otherwise proceed and note the assumption.
- If a store is unavailable in Phase 2, log it and continue; degraded
  material/voice is acceptable, a blocked pipeline is not.

## Output Format

The pipeline produces, in order:

1. **Topic brief** (Phase 1) — `{working_title, thesis, audience, promise, spec:{length, depth, channel}}`.
2. **Material dossier** (Phase 2) — (a) topic material + (b) voice samples, source-tagged.
3. **Evidence map** (Phase 3) — `claim → [evidence]`, with `UNSUPPORTED` flags.
4. **First draft** (Phase 4) — complete prose sized to spec, title options, worked opening, citation markers.
5. **Voiced draft + style fingerprint** (Phase 5).
6. **Fact-check report + corrected draft** (Phase 6).
7. **Editor findings + publication-ready draft + promise-delivery verdict** (Phase 7).
8. **Final article** (Phase 8) — written to `writing/<slug>.md` with frontmatter,
   final-format citations, CJK typography applied, and back-links; the agent
   reports the brain slug it landed at.

The final brain page is the canonical deliverable. Intermediate artifacts are
shown to the user as the pipeline runs; only the finished article is filed.

## Anti-Patterns

- ❌ Running all eight roles on one model. They differ wildly in cognitive load;
  use the per-phase model routing table — Opus where judgment matters, cheaper
  models for mechanical passes.
- ❌ Re-scanning the stores in Phase 5 for voice samples. Phase 2 already gathered
  them in one pass; re-querying is wasted retrieval.
- ❌ Drafting (Phase 4) without the Phase 1 spec. Without `length`/`depth`/`channel`
  the writer guesses the size and gets it wrong.
- ❌ Collapsing roles into one pass ("write + fact-check + lay out at once"). The
  whole value is eight separate judgments; one blended pass does all of them badly.
- ❌ Inventing a voice in Phase 5 instead of learning it. Too little past writing →
  say so and ask for reference pieces; never fabricate a style and call it the user's.
- ❌ Letting an `UNSUPPORTED` or `UNVERIFIABLE` claim reach Phase 8. The fact-checker
  and editor exist to kill these; publishing one defeats the skill.
- ❌ Shipping ASCII punctuation inside Chinese text, or `用Opus写` with no CJK-Latin
  spacing. Phase 8 applies CJK typography directly — it is not optional polish.
- ❌ Skipping the citation-format conversion in Phase 8. The quality.md citation
  format is mandatory; inline markers are not the final form.
- ❌ Re-running the entire pipeline after a small Editor→Writer loop. Re-run only
  voice + fact-check on the changed text.

## Tools Used

- `query` — brain-first material AND voice-sample gathering (Phase 2), evidence
  (Phase 3), prior-take checks (Phase 1).
- `search` — broader brain retrieval when `query` is too narrow.
- `get_page` — read specific prior articles in full for voice study (Phase 2).
- `put_page` — write the finished article to `writing/<slug>.md` (Phase 8).

External (non-gbrain) tooling, used best-effort via the session's own MCPs/CLIs:
- **GetNote** (`mcp__getnote__recall*`) and **Obsidian** (`mcp__obsidian`) — extend
  Phase 2 material and voice gathering.
- **AI archive** (`ai-search`) — prior cross-model conversations for Phase 2.
- **Web fetch** (`firecrawl` MCP or equivalent) — Phase 3 external evidence and
  Phase 6 re-verification of external claims.

The brain remains the primary and only required store; every external store is
best-effort and the pipeline degrades gracefully when one is unavailable.

## Related skills

- `skills/article-enrichment/SKILL.md` — enriches an EXISTING raw text dump in the
  brain; expert-writing CREATES a new article from an idea. Use enrichment when you
  already have the text; use this when you have only an idea.
- `skills/strategic-reading/SKILL.md` — reads source material into a playbook; can
  feed Phase 3 evidence but doesn't write the article.
- `skills/concept-synthesis/SKILL.md` — builds the intellectual map the topic
  strategist (Phase 1) and steward (Phase 2) can mine for angles and material.

## Contract

This skill guarantees:

- Routing matches the canonical triggers in the frontmatter.
- All eight roles run as ordered, separated phases, each on its routed model;
  output is written under `writing/` per `writes_to:`.
- The Phase 1 spec (length, depth, channel) is fixed before drafting and sizes the
  Phase 4 draft.
- The voice-polisher learns from the user's actual past writing (gathered once in
  Phase 2) before applying any style; it never fabricates a voice silently.
- Every external fact in the finished article carries a quality.md citation,
  traces to a source, and is re-verified by the fact-checker;
  `UNSUPPORTED`/`UNVERIFIABLE` claims do not reach publication.
- Phase 8 applies CJK + English typography directly and creates back-links per
  quality.md.
- Conventions referenced (`quality.md`, `brain-first.md`, `model-routing.md`,
  `subagent-routing.md`, `_brain-filing-rules.md`) are followed.
- Privacy contract preserved: no real names, no fork-specific filesystem path
  literals, no upstream-fork references in the skill itself.

The full behavior contract is documented in the phase sections above; this section
exists for the conformance test.
