#!/usr/bin/env bun

import { existsSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

interface StatuslineInput {
  session_id: string;
  transcript_path: string;
  cwd: string;
  model: {
    id: string;
    display_name: string;
  };
  workspace: {
    current_dir: string;
    project_dir: string;
  };
  version: string;
  cost: {
    total_cost_usd: number;
    total_duration_ms: number;
    total_api_duration_ms: number;
    total_lines_added: number;
    total_lines_removed: number;
  };
}

interface DurationData {
  sessionId: string;
  startTimestamp: string;
  lastUpdate: string;
  duration: number;
  status: "active" | "finished" | "interrupted";
}

interface FormattedTime {
  hours?: number;
  minutes?: number;
  seconds: number;
}

// NerdFont icons for different states
const ICONS = {
  finished: "\udb80\udd80", // nf-md-comment_check_outline
  interrupted: "\uf256", // nf-fa-hand_stop_o
  active: "\udb84\udf4f", // nf-md-head_snowflake_outline
  error: "\uea87", // nf-cod-error
  parse_error: "\uebe6", // nf-cod-bracket_error
} as const;

function parseStatuslineInput(input: string): StatuslineInput | null {
  try {
    return JSON.parse(input);
  } catch {
    return null;
  }
}

function readDurationData(sessionId: string): DurationData | null {
  try {
    const tmpFile = join(tmpdir(), `claude-code-duration-${sessionId}.json`);

    if (!existsSync(tmpFile)) {
      return null;
    }

    const content = readFileSync(tmpFile, "utf-8");
    const data = JSON.parse(content) as DurationData;

    return data;
  } catch {
    return null;
  }
}

function formatDuration(durationMs: number): FormattedTime {
  const totalSeconds = Math.floor(durationMs / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  return {
    hours: hours > 0 ? hours : undefined,
    minutes: minutes > 0 ? minutes : undefined,
    seconds,
  };
}

function formatDurationString(duration: FormattedTime, status: string): string {
  const parts: string[] = [];

  if (duration.hours) {
    parts.push(`${duration.hours}h`);
  }
  if (duration.minutes) {
    parts.push(`${duration.minutes}m`);
  }
  parts.push(`${duration.seconds}s`);

  const statusIcon = getStatusIcon(status);
  return `${statusIcon} ${parts.join(" ")}`;
}

function getStatusIcon(status: string): string {
  switch (status) {
    case "finished":
      return `\x1b[32m${ICONS.finished}\x1b[0m`;
    case "interrupted":
      return `\x1b[33m${ICONS.interrupted}\x1b[0m`;
    case "active":
      return `\x1b[36m${ICONS.active}\x1b[0m`;
    default:
      return `\x1b[31m${ICONS.error}\x1b[0m`;
  }
}

async function main() {
  try {
    let input = "";
    for await (const chunk of process.stdin) {
      input += chunk.toString();
    }

    const statuslineData = parseStatuslineInput(input);
    if (!statuslineData) {
      console.log(`\x1b[31m${ICONS.parse_error}\x1b[0m Parse error`);
      return;
    }

    const durationData = readDurationData(statuslineData.session_id);
    if (!durationData) {
      console.log(formatDurationString({ seconds: 0 }, "active"));
      return;
    }

    const formattedDuration = formatDuration(durationData.duration);
    console.log(formatDurationString(formattedDuration, durationData.status));
  } catch {
    console.log(`\x1b[31m${ICONS.error}\x1b[0m Error occurred`);
  }
}

if (import.meta.main) {
  await main();
}
