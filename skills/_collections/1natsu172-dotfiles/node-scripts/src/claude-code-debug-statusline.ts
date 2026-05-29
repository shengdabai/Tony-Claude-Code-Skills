#!/usr/bin/env bun

import { existsSync, readFileSync, writeFileSync } from "node:fs";

const LOG_FILE = "_debug_statusline.json";

function loadExistingLogs(): unknown[] {
  if (existsSync(LOG_FILE)) {
    try {
      const content = readFileSync(LOG_FILE, "utf-8");
      return JSON.parse(content);
    } catch (_error) {
      return [];
    }
  }
  return [];
}

function saveLog(logs: unknown[]): void {
  try {
    writeFileSync(LOG_FILE, JSON.stringify(logs, null, 2));
  } catch (error) {
    console.error("ログ保存エラー:", error);
  }
}

async function main() {
  const logs = loadExistingLogs();

  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    const jsonData = JSON.parse(input);
    logs.push({
      timestamp: new Date().toISOString(),
      data: jsonData,
    });
    saveLog(logs);
  } catch (_error) {
    logs.push({
      timestamp: new Date().toISOString(),
      error: "JSON解析エラー",
      rawInput: input,
    });
    saveLog(logs);
  }
}

if (import.meta.main) {
  main();
}
