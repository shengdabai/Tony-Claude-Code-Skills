#!/usr/bin/env node
// Deterministic read-only GetNote collector for the daily article job.
// It intentionally exposes only listNotes and recall to the publishing chain.
//
// v2 (2026-09-06): tiered material window. Prefer notes from the last 24h; if fewer
// than MIN_NOTES, widen to the last 7 days; if still short, fall back to the latest
// 20 notes. The receipt records which tier was used so the prompt can adapt
// (e.g. lean harder on WebSearch when material is thin).
import fs from "node:fs";
import { GetNoteClient } from "$HOME/.claude/mcp-servers/getnote-mcp/dist/client.js";

const output = process.argv[2];
const apiKey = process.env.GETNOTE_API_KEY;
const clientId = process.env.GETNOTE_CLIENT_ID;
if (!output || !apiKey || !clientId) {
  console.error("usage/config error: output path and GetNote environment are required");
  process.exit(2);
}
const MIN_NOTES = Number(process.env.GETNOTE_MIN_NOTES || 3);
const TIERS = [
  { name: "24h", hours: 24 },
  { name: "7d", hours: 24 * 7 },
  { name: "latest20", hours: null },
];

const client = new GetNoteClient(apiKey, clientId);
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function retry(label, operation) {
  let last;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      last = error;
      if (attempt < 3) await pause(attempt * 1500);
    }
  }
  throw new Error(`${label} failed after 3 attempts: ${last?.message || "unknown"}`);
}

// GetNote timestamps arrive as ISO strings or epoch seconds/milliseconds.
function toEpochMs(value) {
  if (value === null || value === undefined || value === "") return NaN;
  if (typeof value === "number") return value < 1e12 ? value * 1000 : value;
  const numeric = Number(value);
  if (Number.isFinite(numeric) && String(value).trim() !== "") {
    return numeric < 1e12 ? numeric * 1000 : numeric;
  }
  // GetNote 无时区字符串按北京时间解析，不依赖本机时区。
  const iso = String(value).trim().replace(" ", "T");
  return Date.parse(/[zZ]|[+-]\d{2}:?\d{2}$/.test(iso) ? iso : `${iso}+08:00`);
}
function newestStamp(note) {
  const stamps = [toEpochMs(note.created_at), toEpochMs(note.updated_at)].filter(Number.isFinite);
  return stamps.length ? Math.max(...stamps) : NaN;
}
function shape(note) {
  return {
    id: note.id,
    title: note.title,
    content: String(note.content || "").slice(0, 8000),
    ref_content: String(note.ref_content || "").slice(0, 4000),
    note_type: note.note_type,
    created_at: note.created_at,
    updated_at: note.updated_at,
  };
}

const listed = await retry("listNotes", () => client.listNotes({ since_id: 0 }));
// Sort newest-first explicitly instead of trusting the API's order, then keep 20.
const all = (listed.notes || [])
  .slice()
  .sort((a, b) => (newestStamp(b) || 0) - (newestStamp(a) || 0))
  .slice(0, 20);
const now = Date.now();
let chosen = [];
let tier = TIERS[TIERS.length - 1];
for (const candidate of TIERS) {
  if (candidate.hours === null) {
    chosen = all;
    tier = candidate;
    break;
  }
  const cutoff = now - candidate.hours * 3600 * 1000;
  chosen = all.filter((note) => {
    const stamp = newestStamp(note);
    return Number.isFinite(stamp) && stamp >= cutoff;
  });
  tier = candidate;
  if (chosen.length >= MIN_NOTES) break;
}
const notes = chosen.map(shape);

const queries = [
  "AI 工作台 工程化破界 自我进化",
  "终身学习 长期主义 践行",
  "跨领域连接 新可能 价值",
];
const recalls = [];
for (const query of queries) {
  const result = await retry(`recall:${query}`, () => client.recall({ query, top_k: 8 }));
  // Recall results follow the chosen tier window too, so a "24h" receipt never
  // smuggles in months-old material; the latest20 tier keeps everything.
  const cutoff = tier.hours === null ? -Infinity : now - tier.hours * 3600 * 1000;
  recalls.push({
    query,
    results: (result.results || [])
      .filter((item) => {
        const stamp = toEpochMs(item.created_at);
        return tier.hours === null || (Number.isFinite(stamp) && stamp >= cutoff);
      })
      .map((item) => ({
        note_id: item.note_id,
        note_type: item.note_type,
        title: item.title,
        content: String(item.content || "").slice(0, 8000),
        created_at: item.created_at,
      })),
  });
}

const payload = {
  receipt: {
    collector: "getnote-readonly-export/v2",
    read_only_methods: ["listNotes", "recall"],
    fetched_at: new Date().toISOString(),
    material_tier: tier.name,
    window_hours: tier.hours,
    min_notes: MIN_NOTES,
    listed_count: all.length,
    note_count: notes.length,
    recall_query_count: recalls.length,
    recall_kept_count: recalls.reduce((sum, r) => sum + r.results.length, 0),
  },
  notes,
  recalls,
};
fs.writeFileSync(output, `${JSON.stringify(payload, null, 2)}\n`, { mode: 0o600 });
fs.chmodSync(output, 0o600);
console.log(
  `GetNote read-only export complete: tier=${tier.name} notes=${notes.length}/${all.length} recalls=${recalls.length}`,
);
