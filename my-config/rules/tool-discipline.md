# Tool Discipline

## Iron Law: Bash 是最后选择，不是默认选择

报告数据：921 Bash : 50 Edit = 18:1 比例 + 48 次 Bash 命令失败 + 4 次 Edit 失败。说明 Bash 用得**远超必要**。

## 必须用 dedicated tool 的场景

| 操作 | ✅ 正确工具 | ❌ 错误的 Bash 写法 |
|------|----------|------------------|
| 读文件 | `Read` | `cat /path/to/file` / `head` / `tail` |
| 改文件 | `Edit`（精确替换）/ `Write`（全文重写） | `sed -i` / `awk` / `echo > file` / `cat <<EOF` |
| 找文件 | `Glob` | `find` |
| 搜代码 | `Grep` | `grep -r` / `rg` |
| 列文件 | `Glob` 或 `Read directory` | `ls` |
| 打印输出 | 直接 text response | `echo "已完成"` |

## Bash 真正合适的场景

- 启动进程：`npm run dev`、`gh pr create`、`git commit`
- 查询动态状态：`git status`、`docker ps`、`ports`
- 编译/测试：`tsc`、`pytest`、`make`
- 系统级命令：`brew install`、`launchctl`、`xcrun`
- 多步骤管道：`jq ... | xargs ... | head`（确实需要的）

## Edit 失败 4 次 — 修复方法

报告显示 4 次 Edit 失败，最常见原因：
1. **没先 Read 就 Edit** → Edit tool 强制要求先 Read
2. **old_string 不唯一** → 加更多 surrounding context 让其唯一
3. **空白字符不匹配** → 注意 cat -n 行号前缀和实际内容的 tab 分隔

## 自检（执行前问自己）

如果我准备调 Bash，问：
- 这是文件读 / 改 / 搜索吗？→ 用 Read/Edit/Write/Grep/Glob
- 这是输出文本给用户吗？→ 直接说话
- 这是 echo/cat/head/tail？→ 99% 时候用错了

只有真的需要 shell 行为（启动进程、动态查询、多步管道）才用 Bash。

## 例外（允许 Bash）

- 用户明确说"用 bash"/"运行命令"
- 验证脚本（如 `bash -n`、`jq empty`）
- 一次性诊断（`which`、`file`、`stat`）
- 确实没有对应 dedicated tool（如 `chmod`、`xcrun simctl`）
