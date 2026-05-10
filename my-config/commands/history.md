# Session History

Display Claude Code conversation history with three modes.

```bash
python3 ~/.claude/scripts/history.py $ARGUMENTS
```

## 用法

| 输入 | 行为 |
|---|---|
| `/history <关键词>` | 在历史记录的首条 prompt 与对话内容中搜索关键词，列出全部命中会话(最多 30 条) |
| `/history` | 显示过去 24 小时内的全部会话,带表格(ID / 核心概括 / 补充信息) |
| `/history all` | 显示历史会话**总数**,默认列出最近 20 条 |
| `/history all <N>` | 显示最近 N 条(如 `/history all 100`) |

输出为对齐表格,直接呈现给用户,不要总结或修改。
