# gbrain 智能路由(代码检索 + OPC 跨项目记忆)

gbrain 是已配置好的本地知识脑(v0.31.3, ~12000 pages, BM25 + 代码索引)。
它能在你 Read/Grep 之前替你回答两类问题:
1. **代码层**: code-def / code-callers / code-callees / code-refs(已对 Tony-CCS 跑过 code 索引)
2. **决策层**: OPC 商业策略历史(`opc-doc/` 内容已 sync 到 brain)

## Iron Law:动手前先问 brain

凡是要 Grep/Read 大量文件去理解代码结构、追溯函数调用、定位定义、回忆某个项目的历史决策——
**先用 1 条 gbrain 命令查,再决定是否要走传统路径**。

成本对比:
- Grep + Read 多文件: 5-30s,占 context,可能漏
- gbrain code-*: <1s,精准定位,JSON 输出可直接 pipe

## 强制触发场景(必须先 brain 查)

### 场景 A:代码理解类(本机已索引 Tony-CCS)
触发词:"哪里定义了 X"/"X 被谁调用"/"X 调用了什么"/"找 X 的所有引用"

| 用户问的 | 必须先跑 |
|---------|---------|
| "X 在哪定义" | `gbrain code-def X` |
| "谁调用了 X" | `gbrain code-callers X` |
| "X 调用了什么" | `gbrain code-callees X` |
| "X 的所有引用" | `gbrain code-refs X` |
| "搜代码里的 'foo bar'" | `gbrain query 'foo bar' --lang ts`(或对应语言) |

### 场景 B:gstack 调试/审查类
触发 `/investigate`、`/review`、`/plan-eng-review` 这些 gstack skill 时,
在它们的 Phase 1(Root Cause / 读代码)之前**主动**跑:

```bash
gbrain code-def <suspected-symbol>          # 先定位代码
gbrain code-callers <symbol>                # 摸清调用面
gbrain query "<error keyword>" --source tony-ccs   # 查相关历史
```

把 gbrain 的输出当作 Phase 1 的第一份证据,再决定要不要深入 Read。

### 场景 C:OPC 跨项目策略类
触发词:"我之前在 X 项目怎么定的利基"/"那个商业模式还能用吗"/"我以前的 MVP 设计"

```bash
gbrain query "<项目代号> 利基定位"          # 拉历史利基决策
gbrain list --tag <项目代号>               # 列该项目所有 OPC 文档
gbrain query "<阶段名> 我做过哪些"           # 跨项目找同类决策
```

启动 `/opc-orchestrator` 时**必须**先用项目代号查 brain,把已有结论作为上下文,
而不是从零再问一遍同样问题。

## 不需要走 brain 的场景

- 单文件 Read(已知路径)
- 用户给了具体行号
- 写新代码(没历史可查)
- 简单的 git status / git log 查询

## 错误回退

如果 gbrain 命令失败、超时、或返回 No results:
1. 不要重试同一查询
2. 可以换关键词再试 1 次
3. 还是空,直接走 Grep/Read 传统路径,**不要因为 brain 没数据就阻塞工作**

## 关键约束

- **只读 brain,不要替用户写**:除非用户明确说"存到 brain"或调用 `opc-to-gbrain.sh`,
  不要主动 `gbrain put` 写页面
- **不重复索引**:Tony-CCS 已经索引,不要再 `gbrain sources add`
- **embed 缺 key**:语义搜索受限,但 BM25 关键词搜索完全可用,优先用精确词
- **brain 数据可能过时**:如果 brain 答案与当前代码冲突,以当前代码为准并更新 brain

## 速查命令

```bash
gbrain doctor --fast        # 健康检查
gbrain list -n 10           # 看最近 10 页
gbrain sources list         # 列已注册 source
gbrain query "..."          # 混合搜索(默认)
gbrain search "..."         # 纯 BM25 关键词
gbrain code-def Symbol      # 定位定义
gbrain backlinks <slug>     # 反向链接
```
