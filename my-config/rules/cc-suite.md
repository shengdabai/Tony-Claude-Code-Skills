# cc-suite 接入规则（命中 cc-suite / 桥接 / 审计 skill·rules·plugin 时先 Read）

xiaolai/cc-suite = **项目级多工具桥接 + NLP 工件审计**。装在 `cc-suite@xiaolai`，当前 0.11.1。
本文件是本机唯一权威用法；与 README 冲突以本文件为准（README 面向通用用户，不知道本机已有体系）。

## Iron Law 三条

1. **桥接只走 `~/.claude/scripts/cc-suite-bridge.sh`，绝不裸跑 `/cc-suite:init`。**
   裸跑在非仓库目录 = 改写全局 `~/.codex/config.toml` + 把 247 个全局 skill 灌给 Codex（推翻精选 23 skill 桥接）。包装脚本有硬闸门。
2. **审计类命令随便用，委派类命令让位给 `cc`。** cc-suite 的 `/implement` `/review-plan` 没有风险分级、没有 VERDICT 闸门、没有 UNKNOWN≠通过。编码协作走 `cc` skill。
3. **反向委派（claude-octopus）默认关闭。** 它驱动 headless Claude，落在 2026-06-15 起的独立 API 计费桶。
   有**三条**独立通路，只关一条等于没关：项目 `.agents/mcp_config.json`（agy→Claude，`bridge_mcp.sh` 每次运行都会塞回）、项目 `.codex/config.toml`（Codex→Claude）、全局 `~/.gemini/config/mcp_config.json`（全局 agy，项目级剥离管不到）。
   包装脚本每次桥接都清前两条、检测第三条。要开必须显式 `--reverse`——它会同时注册两条并写入 `.cc-suite-reverse-opt-in` 标记；**verify 靠这个标记区分「你主动开的」和「意外开的」，没标记就是 FAIL 而不是 warning**。

## 功能裁决表（每一项都有归属，别再重新判断）

### 采纳 — 这是引入 cc-suite 的理由
| 功能 | 用法 | 说明 |
|---|---|---|
| `/cc-suite:audit-rules` | 审 `~/.claude/rules/` | 已实测：22 文件 69KB，Codex 高 effort 约 5 分钟出 7 维报告 |
| `/cc-suite:audit-skill` | 审 SKILL.md | 与 `darwin-skill` 互补：darwin 是 Claude 自评（同族盲区），这个是 Codex 跨族 |
| `/cc-suite:audit-command` `/audit-plugin` `/audit-agent` | 审 slash command / plugin / agent 定义 | Tony-claude-plugins 仓库的质量门禁 |
| `/cc-suite:audit-nlp` | 全仓扫所有 NL 工件 | 大扫除用，单次成本高 |
| `/cc-suite:audit` | 审代码（只读） | 不改文件，随便用 |
| `/cc-suite:verify` | 拿上一份 audit 报告逐条复验 | **无等价物**：它按 finding 判 FIXED / PARTIAL / NOT FIXED，`superpowers:verification-before-completion` 只要求「跑证明命令」，覆盖不了手工修完之后的跨模型复验 |
| `/cc-suite:status` `/result` `/cancel` `/continue` | Codex job 管理 | **真增量**：`cc-run.sh` 没有后台 job 跟踪和 resume |
| `/cc-suite:codex-preflight` `/agy-preflight` | 后端就绪 + 动态模型目录 | 别再硬编码模型名，以 preflight 输出为准 |
| `/cc-suite:agy` | 调 Antigravity | 比裸 `agy` 多 job 跟踪 / 超时 / resume |
| 项目级四条桥 | 见下方流程 | AGENTS.md 单源 / skills symlink / hooks 镜像 / MCP 平价 |

### 改造后用 — 不能照搬
| 功能 | 改造方式 |
|---|---|
| `/cc-suite:implement` `/review-plan` | 只用于 `cc` 的 **L1 轻任务**。L2/L3 走 `cc` 五步，理由见 Iron Law 2 |
| `/cc-suite:bug-analyze` | 让位给 `codex:codex-rescue`（已有 rescue 触发器：同 bug 2 次失败） |
| `/cc-suite:audit-fix` | **会自动改代码、最多跑 3 轮**，与 Iron Law 2 冲突。只允许用在 `cc` 的 L1 轻任务；L2/L3 用只读 `/cc-suite:audit` 出 finding，改动由 Claude 评估后自己落，再用 `/cc-suite:verify` 复验 |
| `--private` 模式 | **默认不要用**。它只是往 `.gitignore` 多写几条规则，把 `CLAUDE.md` `AGENTS.md` `.mcp.json` `.claude/` 排除掉——项目指令就不进版本库了。**它不是保密措施**：不保护已 tracked 的文件、不清 git 历史、不阻止内容进入其他产物、也不影响任何非 git 的同步通道。客户资料的保密靠「放在 skills-sync hook 覆盖范围外的目录 + 独立 `--permission-mode default` 会话 + 逐次确认同步状态」，不靠这个 flag。⚠️ 本机 **iCloud Desktop 同步是开启的**（`~/Library/Mobile Documents/com~apple~CloudDocs/Desktop` 存在），所以 `~/Desktop/` 下任何路径都不能当作「不外传」，客户资料要放 Desktop 之外 |

### 拒绝 — 有等价物或有代价
| 功能 | 拒绝理由 | 本体系等价物 |
|---|---|---|
| Codex→Claude / agy→Claude 反向委派 | headless Claude 独立计费桶 | `cc` 里 Claude 本来就是编排者，不需要被反向调 |
| `claude_code_sessions` / `claude_code_transcript` | 把会话转录送给 OpenAI；`all_projects:true` 是全机范围 | `ai-search "关键词"` |
| `/cc-suite:grok` + grok 桥 | grok 未装、VPN-only | — |
| `/cc-suite:bridge-tools`（opencode/qwen/kimi） | 本机不用这三个 CLI | — |
| `/cc-suite:migrate-google` | 无 `GEMINI.md` 遗留待迁 | — |
| stop-time review gate（`/cc-suite:setup`） | Stop hook 已被监工 + fake-toolcall-guard 占用，再插一个 900s 超时的 review 会拖慢每次收尾 | 保持默认 `stopReviewGate: false` |
| `add-agent` advisor personas | 与 `liuxiaopai-design` / `critic` / `code-reviewer` 重叠 | — |

## 桥接项目的标准流程

```bash
cd <项目仓库根>                                   # 必须是 git 仓库，且不是 $HOME
bash ~/.claude/scripts/cc-suite-bridge.sh          # 桥接（自动剥离反向委派）
bash ~/.claude/scripts/cc-suite-verify.sh          # 验收，全绿才算完成
```

三个脚本的分工：

| 脚本 | 什么时候跑 | 作用 |
|---|---|---|
| `cc-suite-bridge.sh` | 桥接 / relink / unbridge | 唯一的写入入口，带闸门 |
| `cc-suite-verify.sh` | 每次桥接后、cc-suite 升级后 | 检查真实状态，**反向计费通路无 opt-in 标记 = FAIL** |
| `cc-suite-selftest.sh` | 改了上面两个脚本后、cc-suite 升级后 | 64 项 fixture 回归测试（写操作只在临时目录；但会调真实 verify，因此会读真实 ~/.codex·~/.gemini·~/Desktop 并跑真实 preflight）。护栏回归是静默的——桥接照样成功只是拦不住了，所以必须有这层 |

桥接后：**所有共享指令写进 `AGENTS.md`**，`CLAUDE.md` 只剩 `@AGENTS.md` 一行，别再直接改它。

**该不该桥接的判据**：这个项目你确实会用 Claude + Codex + agy 交替干活 → 桥。只用 Claude → 不桥，纯属增加文件。

## 已知坑（实测确认，不是推测）

1. **升级 cc-suite 后所有已桥接项目的软链会指向旧版本目录**（`.claude/skills/cc-suite -> .../0.11.1/...` 是版本号硬路径）。升级后每个项目跑一次 `bash ~/.claude/scripts/cc-suite-bridge.sh relink`。verify 脚本会检出这个。
2. **原生 `unbridge.sh` 有三处残留**：`.claude/skills/cc-suite` 软链（且 gitignore 块已被删除 → 变成 untracked，公开仓库有误提交风险）、空的 `.codex/`、`.mcp.json` 里的 `codex-cli` 条目。包装脚本的 `unbridge` 子命令已补前两个。
3. **`.mcp.json` 里带 `env` 的 server**：镜像进 `.codex/config.toml` 时值不会写入（只留注释提示），但 `.agents/mcp_config.json` 会写入明文值——该文件默认已被 gitignore，别手动取消忽略。
4. **AGENTS.md 超 32KiB 会被 Codex 静默截断**。verify 脚本检查这一项。
5. `bridge_mcp.sh` 每次运行都会重新塞回 `claude-code` 反向委派条目，所以**必须走包装脚本**（它每次都剥离）。
6. **原生 `init.sh` 的步骤顺序有坑**：它先镜像 `.mcp.json` 再往里加 `codex-cli`，导致首轮 agy 看不到 `codex-cli`，要跑两遍才齐。包装脚本已把顺序倒过来。
7. **别手工从 Bash 直接跑 `codex-runner.mjs`**：本机同时装了 cc-suite 和 codex 两个插件，shell 快照里 `CLAUDE_PLUGIN_DATA` 被后者覆盖，job 状态会落到 `~/.claude/plugins/data/codex-openai-codex/state/` 而不是 cc-suite 自己的目录。功能不受影响，但排查时别找错地方。用 slash 命令即可。
8. `unbridge` 后 `.mcp.json` 里的 `codex-cli` 条目是原生行为保留的，不影响功能，不想留就手工删。

## 接入层的已知限制（Codex 五轮审查后仍存在，都不阻断日常使用）

这些是**明知而接受**的，不是没发现：

1. **hooks parity 只比事件名**，不比 matcher / command 内容。Claude 侧改了某个 hook 的命令但事件名没变时，verify 不会报。
2. **无 Perl 时 `run_bounded` 无超时**（本机有 Perl，实测 1 秒超时的进程树约 2 秒被杀、rc=124）。另外 preflight 若「先输出 status:ok 再挂起」，超时返回码会被输出匹配掩盖。
3. **`cc-suite-selftest.sh` 不是完全 hermetic**：写操作全在临时目录，但它会调真实 verify → 读真实 `~/.codex`·`~/.gemini`·`~/Desktop` 并跑真实 preflight。
4. **Desktop 扫描只认 `.claude/skills/cc-suite` 软链，且只覆盖 6 层**。其他位置的项目要 `cd` 进去再跑 verify（当前项目走 7 种痕迹检测，更严）。
5. **结构等价性校验基于 tomllib，注释不受保护**。已用「出现多于一对 cc-suite sentinel 就拒绝改动」缓解。

## 升级流程

```bash
claude plugin update cc-suite@xiaolai --scope project   # 注意是 project scope，user scope 会报未安装
# 重启 Claude Code 才生效
bash ~/.claude/scripts/cc-suite-verify.sh               # 检出需要 relink 的项目
```

## 与其他体系的边界

- 编码协作流程 → `cc` skill（本文件不接管）
- Codex 通路选择 / 5 个配合模式 → `rules/claude-codex-collab.md`
- 循环化审计（把 audit 跑成 loop）→ `rules/loop-engineering.md` 的五要素
- 交接班 → `/handoff` `/pickup`（cc-suite 不涉及）
