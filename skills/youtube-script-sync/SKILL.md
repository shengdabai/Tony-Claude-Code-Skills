---
name: youtube-script-sync
description: Sync, update, or optimize Tony's GetNote knowledge base `Youtube视频逐字稿` by turning each parent recording or first-person idea note into an idempotent child note containing a directly recordable YouTube long-video or Shorts script. Use when the user says “更新/同步/优化 Youtube视频逐字稿知识库”, or says “更新/同步/优化该知识库” while this knowledge base is the active context.
---

# YouTube Script Sync

## Contract

- Target the existing GetNote knowledge base `Youtube视频逐字稿` (`topic_id=YkWaVRqY`). Resolve by exact name and confirm the ID before every live run.
- Never overwrite, delete, or rewrite a source recording note. Create the script as a child note with `parent_id`; update that plain-text child on later optimizations.
- Process all eligible parent notes, sequentially, with a dry-run before writes. Avoid duplicate children and respect GetNote quotas.
- Turn the source into two honest, directly recordable scripts: one natural Mandarin version and one independently localized, idiomatic English version for global YouTube viewers. Never promise views, likes, subscribers, or YPP.
- Finish only after live readback proves parent-child linkage, generated-note coverage, and idempotency.

## Fixed configuration

| Field | Value |
|---|---|
| Knowledge base | `Youtube视频逐字稿` |
| Expected topic ID | `YkWaVRqY` |
| Generated title marker | `YT逐字稿·源<source_note_id>` |
| Generated tags | `YT逐字稿` plus `长视频稿` or `Shorts稿`; optionally `待核验` |
| Schema | `youtube-script-sync/v2` |

Read [editorial-system.md](references/editorial-system.md) before generating scripts. Read [tony-voice-profile.md](references/tony-voice-profile.md) when writing or optimizing Tony's spoken copy. For an AI client that cannot discover skills automatically, use [portable-prompt.md](references/portable-prompt.md).

## Workflow

### 1. Preflight

1. Call `get_quota`. Stop before writes if write-note quota cannot cover missing scripts plus one verification retry.
2. Call `list_topics` page by page. Require exactly one exact-name match and verify its ID is `YkWaVRqY`; if it differs, stop and report the mismatch instead of guessing.
3. Call `list_topic_notes` page by page until `has_more=false`. Do not rely on the first page or on semantic recall for full coverage. GetNote's topic listing can omit child notes from both `notes[]` and `total`, even when each child inherits the topic correctly.
4. Treat the topic listing as the source-parent inventory. Exclude system/help notes and generated-title markers.
5. For each source, call `get_note`, then enumerate its exact `children_ids` and call `get_note` for every child. Build the generated-child set from children whose title contains `YT逐字稿·源<source_note_id>` or whose tags contain `YT逐字稿`. Never infer “no child” merely because `list_topic_notes` omitted it.
6. Prefer `audio.original` for recorder notes; use `content` as structure/support. For multi-speaker audio, preserve Tony's lines and attribute other speakers rather than adopting their claims as Tony's.

### 2. Plan without writing

Classify every source as one of:

- `CREATE_LONG`: enough first-person story, concrete evidence, tension, and connected beats for 6–8 minutes; include two standalone Shorts in the same child note.
- `CREATE_SHORT`: one strong point or scene that works best in 35–60 seconds.
- `UPDATE_LONG` / `UPDATE_SHORT`: a matching child exists but its metadata is older than the source, its schema is older than `youtube-script-sync/v2`, or mode is `优化`.
- `UNCHANGED`: matching child exists, metadata matches, and mode is `更新` or `同步`.
- `SKIP_NOT_USER_SOURCE`: imported article, third-party livestream, system note, empty transcript, or content that cannot honestly be voiced as Tony.
- `BLOCKED`: unreadable source, ambiguous duplicate children, quota shortage, or missing permission.

Print the dry-run table with source ID, title, classification, reason, and planned write action. Continue automatically unless a `BLOCKED` item needs authority or would change source data.

### 3. Generate the candidate

Use all relevant ideas in the source, but do not mechanically preserve filler or every tangent. Preserve meaning, personal stance, uncertainty, and first-hand boundaries.

Required child-note structure:

```markdown
# 拍摄定位
<!-- audience, one question, one payoff, format, estimated duration -->

# 可直接录制逐字稿
## 中文逐字稿
<!-- spoken copy only; long or short according to classification -->

## English verbatim script
<!-- a complete, independently recordable, idiomatic English script; preserve facts and boundaries but localize structure instead of translating line by line -->

# 拍摄提示
<!-- real person, real place/action, B-roll; never invent footage -->

# 标题、封面与传播设计
<!-- 3 honest English title options, 2 thumbnail phrases, one description opener, and one specific pinned-comment question -->

# 发布前核验
<!-- proper nouns, dates, prices, statistics, privacy, claims -->

# 同步元数据
schema: youtube-script-sync/v2
source_note_id: <full exact string ID>
source_updated_at: <source value>
format: long|short
language: zh+en
generated_by: <codex|claude|other>
```

For long scripts, append `# 可独立发布的双语 Shorts` with exactly two complete 35–60 second ideas. Each idea must contain `Shorts N · 中文` and `Shorts N · English`; both versions must pose and resolve their own question. Do not use contextless cut-down excerpts.

The English script is not a subtitle pass. Rebuild it from the same source evidence for an English-speaking viewer: put the tension and viewer relevance early, explain China-specific context inline, use natural spoken transitions and contractions, and end with a concrete payoff and question. It may reorder paragraphs, but it must not add facts, experiences, certainty, or product use absent from the Chinese/source version.

Validate the candidate with:

```bash
python3 /Users/tonysheng/.agents/skills/youtube-script-sync/scripts/validate_transcript.py <candidate.md>
```

Fix all errors before a GetNote write. Warnings require judgment but do not automatically block.

### 4. Write sequentially

- Missing child: call `save_note` with `note_type=plain_text`, `parent_id=<source_note_id>`, the complete candidate content, and the generated tags. Then add the child to the target topic only if live readback shows it is not already inherited through the parent.
- Existing matching child: call `update_note`; keep the same note ID and replace title/content/tags with the optimized version. Never create a second generated child for the same source.
- Use a single writer. On `qps_bucket_exceeded` or `qps_global_exceeded`, stop concurrent writes, back off, and retry only the failed item.

### 5. Verify live state

1. Re-read each written child with `get_note`; verify title, content, tags, `is_child_note=true`, and the exact `source_note_id` metadata.
2. Re-read each parent; verify `children_ids` contains the child ID.
3. Re-list every topic page for the parent inventory, then re-read each parent's `children_ids` and calculate:
   - eligible source IDs;
   - generated-source IDs;
   - missing = eligible minus generated;
   - duplicates = source IDs mapped to more than one generated child.
4. Run the same dry-run again. A successful `更新/同步` run must produce zero writes (`UNCHANGED` for all previously processed items).
5. Report counts for created, updated, unchanged, skipped, blocked, missing, duplicates, and remaining quotas. Do not call the run complete if missing or duplicates is nonzero.

## Mode semantics

- `更新` or `同步`: create missing children and refresh only children whose source changed.
- `优化`: re-read every eligible source and update its existing child to the latest editorial and voice rules; still create missing children.
- If the user names one source note, limit the run to that note but keep all verification rules for it.

## Anti-patterns

- Do not turn external recordings into first-person claims by Tony.
- Do not summarize when a directly speakable script is required.
- Do not label a translation or abbreviated subtitle draft as an English verbatim script.
- Do not alternate full Chinese and English paragraphs in one final video unless Tony explicitly asks for a bilingual cut; the two scripts are normally alternative recording versions.
- Do not invent personal tests, locations, footage, quotations, statistics, or audience outcomes.
- Do not treat “realness” as permission to preserve repetitive filler, transcription errors, or weak openings.
- Do not call task creation, a successful API response, or one page of inventory “complete”; use live readback and set-difference verification.
