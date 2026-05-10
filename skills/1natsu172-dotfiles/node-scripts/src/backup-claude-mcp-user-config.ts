#!/usr/bin/env bun

import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

type JsonObject = Record<string, unknown>;

function isPlainObject(value: unknown): value is JsonObject {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

// Merge strategy: optimistic merge by server name.
// - If the same server key exists in target and source, prefer source (overwrite whole server object)
// - Do NOT deep-merge nested fields

async function readJsonObject(
	filePath: string,
): Promise<JsonObject | undefined> {
	try {
		const text = await fs.readFile(filePath, "utf8");
		return JSON.parse(text) as JsonObject;
	} catch (error: unknown) {
		if ((error as { code?: string }).code === "ENOENT") {
			return undefined;
		}
		throw error;
	}
}

async function writeJsonAtomic(
	filePath: string,
	data: JsonObject,
): Promise<void> {
	const dir = path.dirname(filePath);
	const tmp = path.join(
		dir,
		`.mcp.json.tmp-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
	);
	const jsonText = JSON.stringify(data, null, 2) + "\n";
	await fs.writeFile(tmp, jsonText, "utf8");
	await fs.rename(tmp, filePath);
}

async function main(): Promise<void> {
	const homeDir = os.homedir();
	const sourcePath = path.join(homeDir, ".claude.json");
	const targetPath = path.join(homeDir, "dotfiles", ".mcp.json");

	const claudeConfig = await readJsonObject(sourcePath);
	if (!claudeConfig) {
		console.error(`.claude.json が見つかりません: ${sourcePath}`);
		process.exitCode = 1;
		return;
	}

	// Read mcpServers only (per official docs)
	const sourceMcpServersRaw = claudeConfig["mcpServers"];
	const sourceMcpServers = isPlainObject(sourceMcpServersRaw)
		? sourceMcpServersRaw
		: undefined;

	if (!sourceMcpServers || Object.keys(sourceMcpServers).length === 0) {
		console.log(
			"~/.claude.json に mcpServers が見つからないため、処理をスキップしました。",
		);
		return;
	}

	const existingTarget: JsonObject = (await readJsonObject(targetPath)) ?? {};
	const existingMcpServersRaw = existingTarget["mcpServers"];
	const existingMcpServers = isPlainObject(existingMcpServersRaw)
		? existingMcpServersRaw
		: {};

	const mergedMcpServers: JsonObject = {
		...(existingMcpServers as JsonObject),
		...(sourceMcpServers as JsonObject),
	};

	// Keep other keys in target file as-is, only update mcpServers
	const nextTarget: JsonObject = {
		...existingTarget,
		mcpServers: mergedMcpServers,
	};

	await writeJsonAtomic(targetPath, nextTarget);

	const sourceCount = Object.keys(sourceMcpServers).length;
	const totalCount = Object.keys(mergedMcpServers).length;
	console.log(
		`mcpServers を ${sourceCount} 件取り込み、${targetPath} に保存しました（合計 ${totalCount} 件）。`,
	);
}

main().catch((error) => {
	console.error("バックアップ中にエラーが発生しました:", error);
	process.exitCode = 1;
});
