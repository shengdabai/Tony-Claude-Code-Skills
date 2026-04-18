#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const skillsDir = path.join(repoRoot, "skills");
const configPath = path.join(repoRoot, "config", "settings.json");
const readmePath = path.join(repoRoot, "README.md");

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function findSkillDoc(skillPath) {
  for (const candidate of ["SKILL.md", "skill.md"]) {
    const fullPath = path.join(skillPath, candidate);
    if (fs.existsSync(fullPath) && fs.statSync(fullPath).isFile()) {
      return fullPath;
    }
  }
  return null;
}

function parseFrontmatter(markdown) {
  const match = markdown.match(/^---\n([\s\S]*?)\n---\n?/);
  if (!match) return {};

  const result = {};
  const lines = match[1].split("\n");

  for (let index = 0; index < lines.length; index += 1) {
    const rawLine = lines[index];
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const separator = line.indexOf(":");
    if (separator === -1) continue;

    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();

    if (/^[>|][+-]?$/.test(value)) {
      const blockLines = [];
      while (index + 1 < lines.length) {
        const nextLine = lines[index + 1];
        if (!/^\s+/.test(nextLine)) break;
        blockLines.push(nextLine.trim());
        index += 1;
      }
      value = blockLines.join(" ");
    } else {
      value = value.replace(/^['"]|['"]$/g, "");
    }

    result[key] = value;
  }
  return result;
}

function firstMeaningfulLine(markdown) {
  const withoutFrontmatter = markdown.replace(/^---\n[\s\S]*?\n---\n?/, "");
  let inCodeFence = false;

  for (const rawLine of withoutFrontmatter.split("\n")) {
    const line = rawLine.trim();
    if (line.startsWith("```")) {
      inCodeFence = !inCodeFence;
      continue;
    }
    if (inCodeFence) continue;
    if (!line) continue;
    if (line.startsWith("#")) continue;
    if (line.startsWith("<") && line.endsWith(">")) continue;
    return line;
  }

  return "No description available.";
}

function normalizeDescription(text) {
  return text.replace(/\s+/g, " ").trim();
}

function summarizeDescription(text, maxLength = 180) {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1).trimEnd()}...`;
}

function escapeTable(text) {
  return text.replace(/\|/g, "\\|");
}

function loadMcpCount() {
  if (!fs.existsSync(configPath)) return 0;

  try {
    const parsed = JSON.parse(readText(configPath));
    return Object.keys(parsed.mcpServers || {}).length;
  } catch {
    return 0;
  }
}

function loadSkills() {
  if (!fs.existsSync(skillsDir)) return [];

  return fs
    .readdirSync(skillsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
    .map((entry) => {
      const skillPath = path.join(skillsDir, entry.name);
      const docPath = findSkillDoc(skillPath);
      const rawMarkdown = docPath ? readText(docPath) : "";
      const frontmatter = rawMarkdown ? parseFrontmatter(rawMarkdown) : {};
      const frontmatterDescription =
        frontmatter.description && !/^[>|][+-]?$/.test(frontmatter.description)
          ? frontmatter.description
          : "";
      const descriptionSource =
        frontmatterDescription || firstMeaningfulLine(rawMarkdown);

      return {
        name: entry.name,
        relativePath: `skills/${entry.name}/`,
        description: summarizeDescription(
          normalizeDescription(descriptionSource || "")
        ),
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name, "en"));
}

function renderSkillTable(skills) {
  const rows = skills.map(
    (skill) =>
      `| [\`${skill.name}\`](${skill.relativePath}) | ${escapeTable(
        skill.description || "No description available."
      )} | [Open](${skill.relativePath}) |`
  );

  return [
    "| Skill | Description | Folder |",
    "| --- | --- | --- |",
    ...rows,
  ].join("\n");
}

function buildReadme(skills, mcpCount) {
  const skillTable = renderSkillTable(skills);
  const skillCount = skills.length;

  return `# Tony's Claude Code Skills & Codex Workflow Collection

[English](#english) | [中文](#中文)

> This README is generated from the repository contents. The skill index below is always built from \`skills/\`, so newly synced skills can be browsed directly from the README.
>
> 这个 README 根据仓库内容自动生成。下面的技能索引直接来自 \`skills/\` 目录，因此每次同步后的技能都能在 README 中直接查看。

## English

This repository mirrors my day-to-day AI workflow assets for Claude Code and Codex.

- \`skills/\` stores the published skill folders that I sync from my local setup.
- \`config/\` stores sanitized configuration snapshots such as MCP settings and hooks.
- \`tools/\` stores the sync helpers that copy local skills into the repo and regenerate this README.

### Why This README Stays Accurate

- The skill index is generated from the actual repository directories, not maintained by hand.
- Running \`bash tools/config-sync.sh\` or \`bash tools/skill-sync.sh\` regenerates the README after syncing files.
- That means whatever is pushed under \`skills/\` is also visible here for quick browsing.

### Repository Snapshot

- Total skill folders: **${skillCount}**
- MCP servers in sanitized config: **${mcpCount}**
- Main sync command: \`bash tools/config-sync.sh\`

## 中文

这个仓库用于镜像我日常在 Claude Code 和 Codex 中使用的 AI 工作流资产。

- \`skills/\` 保存从本地环境同步出来并发布到仓库的技能目录。
- \`config/\` 保存已经脱敏的配置快照，例如 MCP 设置和 hooks。
- \`tools/\` 保存同步脚本，以及生成本 README 的辅助工具。

### 为什么 README 能保持同步

- 技能索引是根据仓库里真实存在的目录自动生成的，不再手工维护。
- 运行 \`bash tools/config-sync.sh\` 或 \`bash tools/skill-sync.sh\` 时，会在同步后自动重建 README。
- 这样只要新的技能被推送到 \`skills/\`，README 里也会同步出现，便于查看和检索。

### 仓库快照

- 技能目录总数：**${skillCount}**
- 已脱敏配置中的 MCP 服务器数量：**${mcpCount}**
- 主要同步命令：\`bash tools/config-sync.sh\`

## Skill Index / 技能索引

Auto-generated from \`skills/\`. Descriptions are extracted from each skill's own documentation when available.

根据 \`skills/\` 自动生成。描述优先取自每个技能自身的文档。

${skillTable}

## Sync Workflow / 同步方式

1. Update or add skills in the local Claude Code setup.
2. Run \`bash tools/config-sync.sh\` to sync skills, sanitized configs, and regenerate the README.
3. Review the diff, commit, and push.

1. 在本地 Claude Code 环境中新增或更新技能。
2. 运行 \`bash tools/config-sync.sh\`，同步 skills、脱敏配置，并重新生成 README。
3. 检查 diff 后提交并推送。

## License / 许可证

Individual skills may retain their own upstream licenses. Repository-level scripts and documentation in this repo follow the repository license.

各个技能可能保留其上游许可证；本仓库中的脚本与说明文档遵循仓库自身许可证。
`;
}

function main() {
  const skills = loadSkills();
  const mcpCount = loadMcpCount();
  const readme = buildReadme(skills, mcpCount);
  fs.writeFileSync(readmePath, readme);
  process.stdout.write(`README updated with ${skills.length} skills.\n`);
}

main();
