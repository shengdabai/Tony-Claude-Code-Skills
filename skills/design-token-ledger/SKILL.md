---
name: design-token-ledger
description: Two stdlib-Python gates borrowed from the architecture checks in xiaolai/sonovo. token_ledger.py audits CSS/HTML/JS against the project's design-token contract and emits a ledger (tokens, uses, unused, raw literals, undefined refs, documented exceptions, media-query thresholds) so a "100% tokenized" claim has evidence; import_allowlist.py enforces declared layer boundaries from architecture.json for JS/TS/Python imports. Use before claiming a web UI is tokenized, when wiring a verify/CI step for a web project, or when a repo needs import-direction rules. Not a formatter and not a CSS parser for every framework: text-level audit, read-only.
---

# design-token-ledger — token 台账 + import 边界

Tony 的 `web-design-tokens` 规则要求:声称 100% tokenized 前,对完整范围做审计并给证据;有持续项目时把检查接进 verify/CI。这两个脚本就是那份证据的生成器。

## 1. token_ledger.py — 设计 token 台账

```bash
python3 -I scripts/token_ledger.py styles.css index.html app.js            # Markdown 台账到 stdout
python3 -I scripts/token_ledger.py styles.css index.html app.js --quiet    # 一行结论 + 前 20 条违规(接 verify 用)
python3 -I scripts/token_ledger.py src/ --json --out ledger.json           # 目录递归 + JSON
```

查什么:

| 项 | 说明 |
|---|---|
| tokens | 每个 `--name: value`,定义位置、作用域、被引用次数;定义在 `:root` / 主题选择器之外的记为 `component-token` 违规 |
| raw-literal | 非 token 定义里的颜色、长度、字体族、数值字重/行高/z-index/opacity、时长、阴影函数 |
| raw-fallback | `var(--x, #fff)` 这类带原始值的回退 |
| undefined-token | 引用了未定义的 token |
| unused | 定义了却没人用(信息,不算违规;JS 里用模板字符串拼的 token 名探测不到) |
| breakpoints | `@media` 里的阈值:`var()` 用不了,单列不算违规,要求在 token 源头注释里记录 |
| exceptions | 同行或上一行有 `/* token-exception: 原因 */` 的字面值,单列,不算 tokenized |

结构性值(`0`、`100%`、`auto`、`1fr`、`none`、`inherit`、`currentColor`…)和结构性属性(`display`、`position`、`flex`、`grid-template-*`…)不算设计决策。只含 `var()`/关键字的颜色函数(如 `color-mix(in srgb, currentColor var(--tint), transparent)`)不算字面值。

退出码:0 无违规;1 有违规;2 输入错误。结论措辞固定三种:`100% tokenized` / `compliant except for documented exceptions` / `violations`。

## 2. import_allowlist.py — 分层 import 白名单

```bash
python3 -I scripts/import_allowlist.py architecture.json
```

`architecture.json` 放在项目根:

```json
{
  "modules":  { "app": ["app.js"], "logic": ["src/logic.js"], "data": ["src/data.js"], "tests": ["tests/*"] },
  "allowed":  { "app": ["logic", "data"], "logic": ["data"], "data": [], "tests": ["*"] },
  "external": { "*": [], "tests": ["node:*", "playwright"] },
  "ignore":   ["node_modules/**", ".git/**"]
}
```

- 每个源文件按 glob 归到一个模块;归不进去 → `unassigned` 违规(补进 modules 或 ignore)。
- `allowed[m]` 是 m 可以 import 的内部模块;`"*"` 任意;没列的模块什么内部模块都不能 import。
- `external[m]` 是 m 可以 import 的外部包(fnmatch);`node:*` 覆盖 Node 内建;`"*"` 键是所有模块的默认。
- 识别 ESM `import … from`、`export … from`、`require()`、动态 `import()`,以及 Python `import` / `from … import`(标准库自动放行)。

退出码:0 干净;1 有违规;2 配置错误。

## 接进项目

package.json 示例(35-workbench-command-center 已接):

```json
"check:architecture": "python3 -I \"${DESIGN_TOKEN_LEDGER_DIR:-$HOME/.agents/skills/design-token-ledger/scripts}/import_allowlist.py\" architecture.json",
"check:tokens": "python3 -I \"${DESIGN_TOKEN_LEDGER_DIR:-$HOME/.agents/skills/design-token-ledger/scripts}/token_ledger.py\" styles.css index.html app.js --quiet",
"verify": "npm run lint && npm run check:architecture && npm run check:tokens && npm test"
```

## Agent 侧用法

1. 改了 web UI 后先跑 `token_ledger.py`,把结论原话写进交付说明;有违规就补 token 或加 `token-exception` 注释并说明原因,不把例外算进 100%。
2. 新项目第一次接入:先 `import_allowlist.py` 看 `unassigned` 列表,照实际依赖写 `architecture.json`,再收紧。
3. 两个脚本都是文本级审计,不替代浏览器里的视觉和可访问性验证。

## 验证

```bash
cd skills/design-token-ledger && python3 -I -m unittest discover -s tests
```
