# Claude Config Changelog

记录基于 `/insights` 报告的 4 轮配置优化（2026-04-25）。

每轮的 ledger 文件保留在 `~/.omc/plans/` 下，可读取详细执行步骤。

---

## Round 1 — 报告 JSON 摘要解读 + 基础设施

**Trigger**: `/insights` 命令产出报告，用户要求"全面优化配置"
**Ledger**: `~/.omc/plans/insights-optimization-todo.md`

### 新增
- `~/.claude/rules/verification.md` — read-back + restart + smoke test
- `~/.claude/rules/intent-defaults.md` — 字面执行 / 不扩 scope / native integration
- `~/.claude/rules/session-resilience.md` — plan-then-execute + ledger
- `~/.claude/skills/sync-skills-preflight/SKILL.md` — 推 GitHub 前 5 项检查
- `~/.claude/skills/audit-projects/SKILL.md` — 多 repo 批量审计带恢复
- `~/.claude/skills/resume-from-ledger/SKILL.md` — 中断恢复
- `~/.omc/plans/_template.md` — Ledger 模板
- `~/.claude/hooks/secret-scan.sh` — Edit/Write 后扫密钥（非阻塞）

### 修改
- `~/.claude/CLAUDE.md` 顶部插入 4 条 Cardinal Rules
- `~/.claude/settings.json` PostToolUse 注册 secret-scan hook（matcher Edit|Write, timeout 2s）

### 验证
- 3 skill 出现在系统 skill 列表
- secret-scan pipe-test 通过（含密钥时报警告，干净文件静默）
- jq 校验 settings.json valid

---

## Round 2 — HTML 报告精读 + sync repo 历史抹除（方案 C）

**Trigger**: 用户要求"仔细全面认真阅读报告"+"上一个问题方案执行 C"
**Ledger**: `~/.omc/plans/insights-html-fullread-todo.md`

### 新增
- `~/.claude/rules/tool-discipline.md` — Cardinal Rule 5 详解（Bash 最后选择）
- `~/.claude/rules/multi-claude-cache.md` — KV cache hygiene + context window

### 修改
- `~/.claude/CLAUDE.md` Cardinal Rule 增第 5 条工具纪律
- `~/.claude/hooks/secret-scan.sh` 加 1MB size guard 防超时
- `~/.claude/hooks/sync-skills-to-github.sh` 重写：
  - 不再推 settings.json
  - 加 `.gitignore` 自动维护
  - 加 push 前 secret-scan 拦截
- `~/.claude/settings.json` allow 列表 22 → 54 条（jq/find/grep/git/gh 等高频命令）

### Destructive 操作（用户授权）
- `cd <sync repo> && git reset --hard origin/main` — 接续远端 HEAD
- `git-filter-repo --invert-paths --path settings.json --path config/settings.json` — 抹除 24 commits 历史
- `git push --force origin main` — 远端 HEAD = `b0b3be7`，settings.json 完全消失

### 安全网
- `backup-pre-reset-20260425-1117` 分支保留在 sync repo 本地

---

## Round 3 — Hook timeout 健康审计

**Trigger**: 用户要求"还有什么可以优化"
**Ledger**: 无独立 ledger（小修复）

### 修改
- `~/.claude/settings.json` 6 个 vibe-island-bridge hook 加 `timeout: 2`：
  - Notification / PostToolUse / PreCompact / PreToolUse / SubagentStart / SubagentStop
  - PermissionRequest 保留 86400（用户决策等待）

### 备份
- `~/.claude/settings.json.bak.20260425`

### 验证
- `jq` 查询 timeout=null 的 vibe hook 数量 = 0
- 总 hook 数 23 个，全部有 timeout

---

## Round 4 — Rules 整合减重

**Trigger**: 用户要求"都做，仔细做"（合并 rules 减重）
**Ledger**: `~/.omc/plans/rules-consolidation-todo.md`

### 删除（5 个文件 / -208 行）
- `~/.claude/rules/hooks.md` (46) — 内容过时
- `~/.claude/rules/testing.md` (30) — 80% TDD 不适合 skill 工作
- `~/.claude/rules/agents.md` (49) — 系统 prompt 已含
- `~/.claude/rules/security.md` (36) — 关键内容并入 verification
- `~/.claude/rules/performance.md` (47) — 拆分到 multi-claude-cache 和 CLAUDE.md

### 合并（保留关键内容）
- `verification.md` 加 "Secret-Aware Verification" 段（+13 行）
- `multi-claude-cache.md` 加 "Context Window Hygiene" + "模型选择" 段（+19 行）
- `git-workflow.md` 重写：精简 + Pre-Commit/Pre-Push Security Gate（45 → 37 行）

### 备份
- `~/.claude/rules.bak.20260425/` — 13 文件完整镜像

### 结果
- 13 文件 / 599 行 → **8 文件 / 415 行**（减重 31%）
- 每次冷启动节省约 3K tokens

---

## Round 5 — Auth Preflight + Async + Polish

**Trigger**: 用户字面要求"都做"（A/B/C/E/F/G）
**Ledger**: `~/.omc/plans/round5-final-polish-todo.md`

### 新增
- `~/.claude/hooks/auth-preflight.sh` — SessionStart 时检查 gh auth + 5 个 MCP 启动脚本 + 6 个 cli-modes 配置文件存在性
  - **不**检查 env vars（hook 子进程不继承 zshrc 的 env，会 false alarm）
  - 注册到 SessionStart 事件，timeout 3s，非阻塞 stderr 输出
- `~/.claude/hooks/log-rotate.sh` — Stop 时清 `.omc/logs/` 7 天前文件 + 截断 >5MB 大文件
  - 注册到 Stop 事件，timeout 5s

### 修改
- `~/.claude/rules/intent-defaults.md` 加 "Anti-Pattern: 不要替用户隐藏 secret" 段（OpenClaw 401 redact 误诊案例的应对）
- `~/.claude/settings.json` Stop 事件下的 `sync-skills-to-github.sh` 加 `async: true` — 后台运行不再阻塞 Stop（节省 5800ms）

### Archive
- 4 个 historical ledger 移到 `~/.omc/plans/archive/`：
  - insights-optimization-todo.md (Round 1)
  - insights-html-fullread-todo.md (Round 2)
  - insights-debug-fixes-todo.md (Round 2 sync repo)
  - rules-consolidation-todo.md (Round 4)

### NOT Done — with reason
- **D 跳过**: backup-pre-reset-20260425-1117 分支保留 — Round 2 force-push 还没满 24h 安全观察期。删除 = 销毁 Round 2 唯一回滚路径。Cardinal Rule 2 verification 精神要求保留证据。

### 备份
- `~/.claude/settings.json.bak.round5-20260425`

---

## 当前最终状态（2026-04-25）

### Cardinal Rules（5 条）
1. 字面执行（intent-defaults.md）
2. 验证再说完成（verification.md）
3. 大任务先 plan（session-resilience.md）
4. 集成而非另起
5. 工具纪律（tool-discipline.md）

### Rules 文件（8 个 / 415 行）
- coding-style (70) / multi-claude-cache (60) / patterns (55)
- session-resilience (51) / verification (51) / tool-discipline (47)
- intent-defaults (44) / git-workflow (37)

### 自定义 Skills（3 个）
- sync-skills-preflight / audit-projects / resume-from-ledger

### Hooks 健康度
- 23 个 hook，**全部有 timeout 保护**
- Edit/Write 后自动 secret-scan（1MB size guard）
- Stop 时 sync-skills 含 push-time secret block

### Permissions
- allow 列表 54 条（覆盖高频 ports/jq/find/grep/git/gh 等）
- defaultMode: dontAsk

### GitHub Sync Repo
- HEAD: `b0b3be7`（settings.json 已完全清除）
- `.gitignore`: 7 项保护（settings.json + .env + *.key + *.pem）
- sync hook 永远不再推 settings.json

---

## 完整回滚指引

如发现新会话行为退化或某轮改动有问题：

### 回滚 Rules 整合（Round 4）
```bash
rm -rf ~/.claude/rules
mv ~/.claude/rules.bak.20260425 ~/.claude/rules
```

### 回滚 Settings.json 改动（Round 3 + Round 2 部分）
```bash
cp ~/.claude/settings.json.bak.20260425 ~/.claude/settings.json
```

### 回滚 sync repo 历史改写（Round 2 destructive 部分）
```bash
cd "$HOME/Desktop/02-编程项目/01-Claude生态/tony claude skills"
git reset --hard backup-pre-reset-20260425-1117
git push --force origin main
```
**注意**: 这会把 GitHub 上的 settings.json 重新公开。仅在确认 round 2 改动有问题时使用。

### 回滚 Cardinal Rules（Round 1 + Round 2）
Edit `~/.claude/CLAUDE.md`，删除 `<cardinal_rules>` ... `</cardinal_rules>` 整段。

### 删除新增 skills / hooks
```bash
rm -rf ~/.claude/skills/{sync-skills-preflight,audit-projects,resume-from-ledger}
rm ~/.claude/hooks/secret-scan.sh
# 然后手动从 settings.json 移除 secret-scan hook 注册
```

---

## Ledger 索引

历史 ledger 已归档到 `~/.omc/plans/archive/`：

- `archive/rules-consolidation-todo.md` (Round 4)
- `archive/insights-html-fullread-todo.md` (Round 2)
- `archive/insights-debug-fixes-todo.md` (Round 2 sync repo 部分)
- `archive/insights-optimization-todo.md` (Round 1)

主目录保留：
- `~/.omc/plans/round5-final-polish-todo.md` (Round 5 本轮)
- `~/.omc/plans/_template.md` (Ledger 模板)
