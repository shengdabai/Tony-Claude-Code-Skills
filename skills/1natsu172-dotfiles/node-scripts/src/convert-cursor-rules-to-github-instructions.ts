#!/usr/bin/env bun

/**
 * CursorのrulesファイルをGitHub Copilot instructionsフォーマットに変換するスクリプト
 *
 * 使用方法:
 * bun run scripts/convert-cursor-rules-to-github-instructions.ts [入力ディレクトリ] [出力ディレクトリ]
 *
 * 例:
 * bun run scripts/convert-cursor-rules-to-github-instructions.ts .cursor/rules ~/copilot-instructions
 */

import { existsSync } from "node:fs";
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { basename, extname, join } from "node:path";

interface CursorRuleFrontMatter {
	description?: string;
	globs?: string;
	alwaysApply?: boolean;
}

interface GitHubInstructionFrontMatter {
	description?: string;
	applyTo?: string;
}

/**
 * フロントマターを解析する
 */
function parseFrontMatter(content: string): { frontMatter: any; body: string } {
	const frontMatterRegex = /^---\n([\s\S]*?)\n---\n([\s\S]*)$/;
	const match = content.match(frontMatterRegex);

	if (!match) {
		return { frontMatter: {}, body: content };
	}

	const frontMatterText = match[1];
	const body = match[2];

	if (!frontMatterText || !body) {
		return { frontMatter: {}, body: content };
	}

	// 簡単なYAMLパーサー（基本的なkey: value形式のみ対応）
	const frontMatter: any = {};
	frontMatterText.split("\n").forEach((line) => {
		const colonIndex = line.indexOf(":");
		if (colonIndex > 0) {
			const key = line.slice(0, colonIndex).trim();
			const value = line.slice(colonIndex + 1).trim();

			// 値の型を推測
			if (value === "true") {
				frontMatter[key] = true;
			} else if (value === "false") {
				frontMatter[key] = false;
			} else if (value === "" || value === "null") {
				frontMatter[key] = null;
			} else {
				frontMatter[key] = value;
			}
		}
	});

	return { frontMatter, body };
}

/**
 * フロントマターを文字列に変換する
 */
function stringifyFrontMatter(frontMatter: any): string {
	if (Object.keys(frontMatter).length === 0) {
		return "";
	}

	const lines = Object.entries(frontMatter).map(([key, value]) => {
		if (typeof value === "string") {
			// glob パターンや特殊文字が含まれる場合はダブルクォートで囲む
			if (value.includes("*") || value.includes("/") || value.includes(".")) {
				return `${key}: "${value}"`;
			}
			return `${key}: ${value}`;
		}
		return `${key}: ${value}`;
	});

	return `---\n${lines.join("\n")}\n---\n\n`;
}

/**
 * CursorのrulesファイルをGitHub instructionsフォーマットに変換する
 */
function convertCursorRuleToGitHubInstruction(content: string): string {
	const { frontMatter, body } = parseFrontMatter(content);

	// Cursorのフロントマターの形式
	const cursorFrontMatter = frontMatter as CursorRuleFrontMatter;

	// GitHub instructionsのフロントマターに変換
	const gitHubFrontMatter: GitHubInstructionFrontMatter = {};

	// applyToフィールドの設定（globsがある場合はそれを使用、なければデフォルト）
	if (cursorFrontMatter.globs) {
		gitHubFrontMatter.applyTo = cursorFrontMatter.globs;
	} else {
		gitHubFrontMatter.applyTo = "**";
	}

	// descriptionフィールドがある場合は保持
	if (cursorFrontMatter.description) {
		gitHubFrontMatter.description = cursorFrontMatter.description;
	}

	// フロントマターとボディを結合
	const result = stringifyFrontMatter(gitHubFrontMatter) + body;

	return result;
}

/**
 * ディレクトリ内のすべての.mdcファイルを変換する
 */
async function convertDirectory(
	inputDir: string,
	outputDir: string,
): Promise<void> {
	console.log(`Converting files from ${inputDir} to ${outputDir}`);

	// 出力ディレクトリを作成
	if (!existsSync(outputDir)) {
		await mkdir(outputDir, { recursive: true });
	}

	// 入力ディレクトリのファイル一覧を取得
	const files = await readdir(inputDir);

	let convertedCount = 0;
	let skippedCount = 0;

	for (const file of files) {
		const inputFilePath = join(inputDir, file);

		// .mdcファイルのみを処理
		if (extname(file) !== ".mdc") {
			console.log(`Skipping non-.mdc file: ${file}`);
			skippedCount++;
			continue;
		}

		try {
			// ファイルを読み込み
			const content = await readFile(inputFilePath, "utf-8");

			// 変換
			const convertedContent = convertCursorRuleToGitHubInstruction(content);

			// 出力ファイル名を.mdに変更
			const outputFileName = basename(file, ".mdc") + ".instructions.md";
			const outputFilePath = join(outputDir, outputFileName);

			// ファイルを書き込み
			await writeFile(outputFilePath, convertedContent, "utf-8");

			console.log(`✅ Converted: ${file} → ${outputFileName}`);
			convertedCount++;
		} catch (error) {
			console.error(`❌ Failed to convert ${file}:`, error);
		}
	}

	console.log(`\n📊 Conversion Summary:`);
	console.log(`  - Converted: ${convertedCount} files`);
	console.log(`  - Skipped: ${skippedCount} files`);
	console.log(`  - Total: ${convertedCount + skippedCount} files`);
}

/**
 * メイン処理
 */
async function main(): Promise<void> {
	const args = process.argv.slice(2);

	if (args.length < 2) {
		console.error(
			"Usage: bun run convert-cursor-rules-to-github-instructions.ts <input-dir> <output-dir>",
		);
		console.error("");
		console.error("Example:");
		console.error(
			"  bun run scripts/convert-cursor-rules-to-github-instructions.ts .cursor/rules ~/copilot-instructions",
		);
		process.exit(1);
	}

	const inputDir = args[0];
	const outputDir = args[1];

	if (!inputDir || !outputDir) {
		console.error("❌ Both input and output directories must be specified");
		process.exit(1);
	}

	// 入力ディレクトリの存在確認
	if (!existsSync(inputDir)) {
		console.error(`❌ Input directory does not exist: ${inputDir}`);
		process.exit(1);
	}

	try {
		await convertDirectory(inputDir, outputDir);
		console.log(`\n🎉 Conversion completed successfully!`);
		console.log(`📁 Output directory: ${outputDir}`);
	} catch (error) {
		console.error("❌ Conversion failed:", error);
		process.exit(1);
	}
}

// スクリプトが直接実行された場合のみメイン処理を実行
main().catch(console.error);
