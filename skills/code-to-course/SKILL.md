---
name: code-to-course
description: "Turn any codebase into a beautiful, interactive single-page HTML course with bilingual (Chinese/English) support. Use this skill whenever someone wants to create an interactive course, tutorial, or educational walkthrough from a codebase or project. Also trigger when users mention 'turn this into a course,' 'explain this codebase interactively,' 'teach this code,' 'interactive tutorial from code,' 'codebase walkthrough,' 'learn from this codebase,' 'make a course from this project,' '把代码变成课程,' '把这个变成教程,' '代码教学,' or '代码转课程.'"
---

# Codebase-to-Course (代码转课程)

Transform any codebase into a stunning, interactive course with **bilingual (中英文) output**.

The output is a **directory** containing a pre-built `styles.css`, `main.js`, per-module HTML files, and an assembled `index.html` — open it directly in the browser with no setup required.

**Bilingual Requirement**: Every screen in every module must contain both Chinese (中文) and English text. The primary audience is Chinese speakers learning technical concepts, but English should always be available for reference.

## Language Strategy

All course content is presented in **bilingual format**:

- **Headings/Titles**: Chinese first, English in parentheses or subtitle
- **Body text**: Chinese paragraph, followed by English translation in a lighter/smaller style
- **Code explanations**: Chinese explanation (primary), English explanation (secondary)
- **Quiz questions/options**: Both languages shown
- **Glossary tooltips**: Chinese definition primary, English definition secondary
- **Chat animations/Messages**: Chinese text, with English hover tooltip

Add this CSS custom property to the course's `_base.html` for bilingual styling:

```css
:root {
  /* ... existing vars ... */
  --lang-primary: #1a1a2e;
  --lang-secondary: #6b7280;
}

.lang-zh { /* Chinese primary text */ }
.lang-en { /* English secondary text, lighter color */ }
.lang-en {
  color: var(--lang-secondary);
  font-size: 0.9em;
  font-style: italic;
  margin-top: 0.25em;
}
```

## First-Run Welcome

When the skill is first triggered, introduce yourself in both languages:

> **我可以把任何代码库变成互动课程，教你代码如何工作——不需要任何编程基础。**
>
> **I can turn any codebase into an interactive course that teaches how it works — no coding knowledge required.**
>
> 只需指向一个项目：
> - **本地文件夹** — 例如 "把 ./my-project 变成课程"
> - **GitHub 链接** — 例如 "make a course from https://github.com/user/repo"
> - **当前项目** — 如果已经在代码库中，直接说 "把这个变成课程"

## Who This Is For / 目标用户

The target learner is a **"vibe coder"** — someone who builds software by instructing AI coding tools in natural language.

**假设零基础。** 每个 CS 概念都需要用通俗语言解释。不使用行话。语气像一个聪明的朋友在解释，不是教授讲课。

**Assume zero technical background.** Every CS concept explained in plain language.

## The Process / 流程

### Phase 1: Codebase Analysis (代码分析)

Read all key files, trace data flows, identify main components, map communication patterns.

**提取内容**:
- 主要"角色"（组件/服务/模块）及其职责
- 主要用户旅程（端到端使用时发生了什么）
- 关键 API、数据流和通信模式
- 巧妙的工程模式（缓存、懒加载、错误处理等）
- 技术栈及选择原因

### Phase 2: Curriculum Design (课程设计)

Structure as **4-6 modules**. Arc: start from user-facing behavior → progressively zoom into code.

| 模块位置 | 目的 | 对 vibe coder 的意义 |
|---|---|---|
| 1 | "这个应用做什么——以及当你使用时发生了什么" | 从产品开始，追踪一个核心用户动作到代码中 |
| 2 | 认识角色 | 知道有哪些组件，以便告诉 AI "把这个逻辑放在 X 而不是 Y" |
| 3 | 组件如何通信 | 理解数据流，解决"它没有显示出来"的问题 |
| 4 | 外部世界（API、数据库） | 了解外部依赖，评估成本、限速和故障模式 |
| 5 | 巧妙的技巧 | 学习模式（缓存、分块、错误处理），可以向 AI 请求 |
| 6 | 当事情出错时 | 建立调试直觉，脱离 AI bug 循环 |

This is a **menu, not a checklist** — pick modules that serve the codebase.

**Each module must contain**:
- 3-6 screens (sub-sections)
- At least one code↔English/Chinese translation
- At least one interactive element
- One or two "aha!" callout boxes
- One metaphor that fits the concept
- **Bilingual**: Every screen has both Chinese and English text

**Mandatory interactive elements**:
- **群聊动画** — Group Chat Animation (iMessage/微信风格)
- **数据流动画** — Message Flow / Data Flow Animation
- **代码↔中英翻译块** — Code ↔ Chinese/English Translation Blocks
- **测验** — Quizzes (至少每个模块一个)
- **术语工具提示** — Glossary Tooltips (每个术语首次出现)

### Phase 2.5: Module Briefs (complex codebases only)

For complex codebases, write briefs at `course-name/briefs/0N-slug.md`.

### Phase 3: Build the Course (构建课程)

**Output structure**:
```
course-name/
  styles.css       ← copied from references/styles.css
  main.js          ← copied from references/main.js
  _base.html       ← customized shell
  _footer.html     ← copied from references/_footer.html
  build.sh         ← copied from references/build.sh
  briefs/          ← module briefs (complex only)
  modules/
    01-intro.html
    02-actors.html
    ...
  index.html       ← assembled by build.sh
```

**Step 1**: Setup — Copy 4 files verbatim from references/.

**Step 2**: Customize `_base.html` — Replace `COURSE_TITLE`, accent colors, nav dots.

**Step 3**: Write modules — Each module file contains only `<section class="module">` content.

**Bilingual module content pattern**:

```html
<h2>认识角色 — Meet the Actors</h2>
<p class="lang-zh">这个应用由几个主要组件组成，它们各自负责不同的工作。</p>
<p class="lang-en">This app is made of several components, each responsible for different tasks.</p>
```

For **translation blocks** (code explanations):

```html
<div class="translation-english">
  <span class="translation-label">中文解释</span>
  <div class="translation-lines">
    <p class="tl">发送请求到这个 URL 并等待响应...</p>
  </div>
  <span class="translation-label" style="margin-top:8px">English Translation</span>
  <div class="translation-lines">
    <p class="tl">Send a request to the URL and wait for a response...</p>
  </div>
</div>
```

For **glossary tooltips**:

```html
<span class="term" data-definition-zh="API（应用程序编程接口）就像餐厅的服务员——你告诉服务员你想要什么，他们把请求传达给厨房，然后把食物端回来。"
            data-definition-en="An API is like a restaurant waiter — you tell them what you want, they relay the request to the kitchen, and bring the food back.">
  API
</span>
```

For **quizzes**:

```html
<div class="quiz-question">
  <p class="lang-zh">哪个组件负责处理用户的点击事件？</p>
  <p class="lang-en">Which component handles user click events?</p>
</div>
<div class="quiz-options">
  <button data-value="a">
    <span class="lang-zh">前端组件</span>
    <span class="lang-en">Frontend Component</span>
  </button>
</div>
```

**Step 4**: Assemble — Run `bash build.sh` from course directory.

### Phase 4: Review and Open (回顾和打开)

After `build.sh`, open `index.html` in the browser. Walk through what was built.

## Design Identity / 设计标识

- **Warm palette**: 暖色调，米白背景，暖灰色
- **Bold accent**: 一个自信的强调色
- **Distinctive typography**: 有性格的展示字体
- **Generous whitespace**: 呼吸感
- **Dark code blocks**: IDE 风格，Catppuccin 语法高亮

## Reference Files / 参考文件

The `references/` directory contains detailed specs. **Read them only when you reach the relevant phase.**

- **`references/content-philosophy.md`** — Content rules and guidelines
- **`references/gotchas.md`** — Common failure points checklist
- **`references/module-brief-template.md`** — Module brief template
- **`references/design-system.md`** — Complete CSS custom properties, color palette, typography
- **`references/interactive-elements.md`** — HTML patterns for every interactive element

## Critical Rules / 关键规则

- **Never regenerate** `styles.css` or `main.js` — always copy from references
- Module files contain only `<section>` content — no `<html>`, `<head>`, `<body>`, `<style>`, `<script>`
- Use CSS `scroll-snap-type: y proximity` (NOT `mandatory`)
- Use `min-height: 100dvh` with `100vh` fallback on `.module`
- Interactive element JS is in `main.js`; wire up via `data-*` attributes
- **Every piece of content must be bilingual** — Chinese primary, English secondary
- Glossary tooltips must include both `data-definition-zh` and `data-definition-en`
- The gloss tooltip JS (in main.js) must be updated to show bilingual definitions
