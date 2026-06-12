---
description: 循环单轮：把测试/构建修到全绿（一次调用 = 一轮；套 /loop 或 ralph 变循环）
argument-hint: [verify 命令，默认自动探测 npm test / pytest / make test]
---

# Loop: Green（修到全绿）

这是一个 loop engineering 循环体（规范见 `~/.claude/rules/loop-engineering.md`）。执行**一轮**：

## 五要素
- Trigger: 被调用即跑一轮
- Work: 修当前最小 root cause（一轮只修一个问题，不顺手重构）
- Verify: `$ARGUMENTS`（为空则按项目自动探测：package.json 有 test script → `npm test`；pyproject/pytest.ini → `pytest`；Makefile → `make test`）
- Exit: Verify exit 0 → 报告"✅ 全绿"并明确说"循环可停"
- Budget: 同一错误连修 3 次仍在 → 停，写两个替代方案，报告"⛔ 升级人工"

## 本轮流程
1. 跑 Verify 命令，全绿 → 直接报告"✅ 全绿，循环可停"，结束
2. 红 → 取**第一个**失败，用 systematic-debugging 思路找 root cause（读报错→定位→最小修复，不猜）
3. 修复后重跑 Verify 确认该失败消失、无新增失败
4. 追加一行日志到 `.omc/logs/loop-green.log`：`<时间> | 修复 <文件:行> <一句话原因> | verify=<pass/fail>`
5. 报告本轮结果：修了什么 + 为什么 + 剩余失败数（≤ 3 行，防理解债）

## 禁止
- 一轮修多个不相关问题 / 顺手重构
- 为了绿而删测试、skip 测试、放宽断言（这是作弊，发现自己想这么做就停下报告）
- git push / commit（除非用户在循环启动时明确授权过）
