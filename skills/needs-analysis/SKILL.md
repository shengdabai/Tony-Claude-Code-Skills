---
name: needs-analysis
description: Mandatory high-priority need validation. Always use before general brainstorming or planning whenever Tony's message contains the Chinese word “需求” or the standalone English word “needs” (case-insensitive). Investigate product, customer, business, or software needs with supporting and disconfirming evidence; judge true, conditional, pseudo, or insufficient; score breadth, urgency, and frequency; then design a decisive validation before development.
---

# Needs Analysis

Turn a raw request into an evidence-backed product decision. Separate whether the problem is real from whether it is an attractive product opportunity.

## Operating rules

- Start with the conclusion. Use `真需求`, `有条件成立`, `伪需求`, or `证据不足`; include confidence (`高/中/低`). Do not force a binary verdict when evidence is missing.
- Treat “广泛、刚需、高频” as opportunity qualities, not proof that a need exists. A need can be real but commercially weak.
- Consider a candidate attractive when the need is at least conditionally real and one or more of the three qualities scores at least 3/5. More passing qualities increase priority, but do not replace evidence.
- Distinguish facts, user claims, third-party estimates, inference, and unknowns. Cite or link sources when research tools are available.
- Prefer observed behavior over stated preference: payment, active workaround, repeated use, switching, budget, deadlines, support tickets, search or purchase behavior.
- Do not confuse a requested feature with the underlying need. Analyze the problem independently of the proposed solution.
- Continue on low-risk assumptions when possible. Ask only questions whose answers would materially change the verdict or validation test.

Read [rubric.md](references/rubric.md) before scoring or issuing the final verdict.

## Workflow

### 1. Normalize the raw need

Rewrite it without solution bias:

> `[specific user]` in `[specific situation]` struggles to `[job/progress]`, causing `[measurable cost or consequence]`; today they use `[current alternative/workaround]`.

Record separately:

- proposed solution;
- target user and buyer;
- triggering situation;
- desired outcome;
- current alternative;
- claimed frequency and consequence;
- uncertainties and assumptions.

If the user and situation are absent, infer a provisional version and label it as an assumption.

### 2. Build the evidence set

Search only as deeply as the decision warrants. Use this order:

1. User-provided materials, current workspace, product analytics, customer notes, support records, sales or payment evidence.
2. Direct customer evidence: interviews with concrete past behavior, paid pilots, preorders, retained usage, switching or active workarounds.
3. Market behavior: competitor customers and pricing, reviews, complaints, procurement/RFPs, job posts, communities, search trends.
4. Market reports, surveys, social engagement, and generic opinions as supporting proxies only.

For each important item capture: source, date, affected segment, what it supports or contradicts, and evidence strength. Recheck live sources for time-sensitive claims. If access is unavailable, state the limitation and do not fabricate findings.

Search for disconfirming evidence as deliberately as confirming evidence. Look for non-consumption, free substitutes, low retention, long replacement cycles, weak willingness to pay, or a segment too costly to reach.

### 3. Judge true versus false need

Evaluate these independent questions:

- Is there an identifiable user in a recurring or important situation?
- Does the problem exist without the proposed product?
- Is there observable cost, risk, delay, frustration, lost revenue, or missed progress?
- Do users already spend time, money, reputation, or effort on a workaround?
- Is the buyer able and willing to act now?
- Does contrary evidence weaken the claimed problem or segment?

Use the rubric's verdict rules. A verbal “I would use this” is weak evidence. A paid or repeated workaround is strong evidence.

### 4. Score the three opportunity qualities

Score each from 0–5 using the rubric and show one sentence of evidence:

- **广泛 Breadth**: enough reachable users share the problem; define the denominator and reachable segment instead of saying “everyone”.
- **刚需 Urgency**: inaction creates a material, time-bound consequence; distinguish must-have from useful.
- **高频 Frequency**: the problem or workflow recurs often enough to support habit, retention, or repeat purchase.

Mark each quality `通过` at 3–5 and `未通过` at 0–2. Do not hide the three scores inside a single average.

Map passed qualities to product logic:

- 广泛: emphasize simple onboarding, distribution, standardization, or lower unit price.
- 刚需: emphasize outcome certainty, speed, trust, service, and premium pricing.
- 高频: emphasize workflow integration, retention, automation, and subscription or repeat use.

### 5. Design the smallest decisive validation

Identify the riskiest assumption and propose a test that can fail. Include:

- target participant and recruitment channel;
- artifact or offer;
- behavior to observe;
- sample size or exposure;
- success threshold;
- failure/stop threshold;
- timebox and next decision.

Prefer commitment tests over opinion tests: paid diagnostic, deposit, signed pilot, data access, calendar commitment, or repeated usage. For Tony's AI 本机工作台服务, when relevant, map the test to the current `50 触达 / 10 访谈 / 3 demo / 1 付费意向` gate and recommend the next missing external action.

### 6. Deliver the analysis

Use this structure, scaling detail to the decision:

1. **结论** — verdict, confidence, and one-sentence reason.
2. **需求重述** — user, situation, job, consequence, current alternative.
3. **证据与反证** — compact table with source/date/type/strength/implication.
4. **真伪需求判断** — behavioral evidence, gaps, and why the verdict follows.
5. **三要素评分** — 广泛 X/5, 刚需 X/5, 高频 X/5; pass count and product implications.
6. **产品决策** — build now, validate first, narrow segment, reposition, or stop.
7. **最小验证实验** — exact test, thresholds, timebox, and next action.
8. **仍未知** — only uncertainties capable of changing the decision.

When the user also requests implementation, present the analysis first, convert validated findings into acceptance criteria, then continue the implementation unless a failed gate makes building wasteful or unsafe.

## Failure modes

- Do not call a need real solely because many people liked, searched, or discussed it.
- Do not call a need false solely because it is niche or infrequent; urgent niche problems can support premium products.
- Do not count the same evidence twice across breadth, urgency, and frequency.
- Do not use market size as a substitute for reachable users or willingness to pay.
- Do not make interview count the goal; use interviews to uncover past behavior and then seek commitment.
- Do not recommend a full build when a landing page, manual concierge test, paid diagnostic, or prototype can test the riskiest assumption faster.
