#!/usr/bin/env node
// Deterministic read-only GetNote collector for the daily article job.
// It intentionally exposes only listNotes and recall to the publishing chain.
import fs from "node:fs";
import { GetNoteClient } from "$HOME/.claude/mcp-servers/getnote-mcp/dist/client.js";

const output = process.argv[2];
const apiKey = process.env.GETNOTE_API_KEY;
const clientId = process.env.GETNOTE_CLIENT_ID;
if (!output || !apiKey || !clientId) {
  console.error("usage/config error: output path and GetNote environment are required");
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

const listed = await retry("listNotes", () => client.listNotes({ since_id: 0 }));
const notes = (listed.notes || []).slice(0, 20).map((note) => ({
  id: note.id,
  title: note.title,
  content: String(note.content || "").slice(0, 8000),
  ref_content: String(note.ref_content || "").slice(0, 4000),
  note_type: note.note_type,
  created_at: note.created_at,
  updated_at: note.updated_at,
}));

const queries = [
  "AI 工作台 工程化破界 自我进化",
  "终身学习 长期主义 践行",
  "跨领域连接 新可能 价值",
];
const recalls = [];
for (const query of queries) {
  const result = await retry(`recall:${query}`, () => client.recall({ query, top_k: 8 }));
  recalls.push({
    query,
    results: (result.results || []).map((item) => ({
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
    collector: "getnote-readonly-export/v1",
    read_only_methods: ["listNotes", "recall"],
    fetched_at: new Date().toISOString(),
    note_count: notes.length,
    recall_query_count: recalls.length,
  },
  notes,
  recalls,
};
fs.writeFileSync(output, `${JSON.stringify(payload, null, 2)}\n`, { mode: 0o600 });
fs.chmodSync(output, 0o600);
console.log(`GetNote read-only export complete: notes=${notes.length} recalls=${recalls.length}`);
