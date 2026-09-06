#!/usr/bin/env node
// Deterministic read-only GetNote collector for the daily AI-news job.
// Exposes only listNotes, filters to the last N hours (default 24), and writes a
// 0600 snapshot the isolated generator reads as untrusted signal data.
import fs from "node:fs";
import { GetNoteClient } from "$HOME/.claude/mcp-servers/getnote-mcp/dist/client.js";

const output = process.argv[2];
const windowHours = Number(process.argv[3] || 24);
const apiKey = process.env.GETNOTE_API_KEY;
const clientId = process.env.GETNOTE_CLIENT_ID;
if (!output || !apiKey || !clientId || !Number.isFinite(windowHours) || windowHours <= 0) {
  console.error("usage/config error: output path, window hours and GetNote environment are required");
  process.exit(2);
}

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
  const iso = String(value).trim().replace(" ", "T");
  return Date.parse(/[zZ]|[+-]\d{2}:?\d{2}$/.test(iso) ? iso : `${iso}+08:00`);
}

const cutoffMs = Date.now() - windowHours * 3600 * 1000;
const listed = await retry("listNotes", () => client.listNotes({ since_id: 0 }));
const all = listed.notes || [];
const recent = all
  .filter((note) => {
    // Use whichever timestamps parse; a missing/unparseable one must not poison Math.max.
    const stamps = [toEpochMs(note.created_at), toEpochMs(note.updated_at)].filter(Number.isFinite);
    return stamps.length > 0 && Math.max(...stamps) >= cutoffMs;
  })
  .slice(0, 30)
  .map((note) => ({
    id: note.id,
    title: note.title,
    content: String(note.content || "").slice(0, 4000),
    ref_content: String(note.ref_content || "").slice(0, 2000),
    note_type: note.note_type,
    created_at: note.created_at,
    updated_at: note.updated_at,
    // URLs are intentionally NOT extracted: note links must never reach the public digest
    // (leak gate rejects any note URL in the output; cross-review 2026-09-06).
  }));

const payload = {
  receipt: {
    collector: "getnote-recent-export/v1",
    read_only_methods: ["listNotes"],
    window_hours: windowHours,
    fetched_at: new Date().toISOString(),
    listed_count: all.length,
    note_count: recent.length,
  },
  notes: recent,
};
fs.writeFileSync(output, `${JSON.stringify(payload, null, 2)}\n`, { mode: 0o600 });
fs.chmodSync(output, 0o600);
console.log(
  `GetNote recent export complete: window=${windowHours}h listed=${all.length} recent=${recent.length}`,
);
