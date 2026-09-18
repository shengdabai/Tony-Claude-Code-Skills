#!/usr/bin/env python3
"""Run a bounded, read-only Codex/Claude cross-review discussion."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
from typing import Any


POLICY_PATH = Path(__file__).resolve().parents[1] / "model-policy.json"
MAX_BRIEF_CHARS = 240_000
MAX_TRANSCRIPT_CHARS = 24_000


class ReviewError(RuntimeError):
    pass


def load_model_policy() -> dict[str, Any]:
    try:
        payload = json.loads(POLICY_PATH.read_text(encoding="utf-8"))
        codex_model = payload["codex"]["model"]
        claude_model = payload["claude"]["model"]
        claude_prefix = payload["claude"]["required_effective_prefix"]
    except (OSError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise ReviewError(f"invalid model policy: {POLICY_PATH}") from exc
    if not all(isinstance(value, str) and value for value in (codex_model, claude_model, claude_prefix)):
        raise ReviewError(f"invalid model values in policy: {POLICY_PATH}")
    return payload


def parse_args(policy: dict[str, Any]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Codex and Claude as read-only reviewers, then exchange objections."
    )
    parser.add_argument("--brief-file", required=True, type=Path)
    parser.add_argument("--cwd", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--rounds", type=int, choices=(1, 2), default=2)
    parser.add_argument("--timeout-seconds", type=int, default=600)
    parser.add_argument(
        "--codex-model",
        default=os.environ.get("REVIEW_OPTIMIZER_CODEX_MODEL", policy["codex"]["model"]),
    )
    parser.add_argument(
        "--claude-model",
        default=os.environ.get("REVIEW_OPTIMIZER_CLAUDE_MODEL", policy["claude"]["model"]),
    )
    return parser.parse_args()


def clean_text(value: str, limit: int = MAX_TRANSCRIPT_CHARS) -> str:
    value = value.strip()
    if len(value) <= limit:
        return value
    return value[:limit] + "\n[truncated by review-optimizer]"


def reviewer_contract(role: str) -> str:
    return textwrap.dedent(
        f"""
        REVIEW_OPTIMIZER_ACTIVE=1. You are the {role} in a bounded cross-model review.
        Do not invoke review-optimizer, skills, subagents, or another AI. Work read-only:
        do not edit files, create commits, deploy, send messages, change permissions, or expose secrets.
        Inspect only the supplied brief and files needed under the allowed working directory.

        Return concise Chinese output with:
        1. Conclusion.
        2. Findings ordered P0-P3, each with evidence, impact, and smallest safe fix.
        3. Contrary evidence, blind spots, and missing verification.
        4. End with exactly one of: VERDICT: APPROVED, VERDICT: REVISE, VERDICT: UNKNOWN.
        Never approve merely because another model agrees.
        """
    ).strip()


def run_process(
    command: list[str], prompt: str, cwd: Path, timeout_seconds: int
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["REVIEW_OPTIMIZER_ACTIVE"] = "1"
    try:
        return subprocess.run(
            command,
            input=prompt,
            text=True,
            capture_output=True,
            cwd=cwd,
            env=env,
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise ReviewError(
            f"timeout after {timeout_seconds}s: {command[0]}. "
            "A reviewer that must open many files routinely needs more than the default; "
            "either raise --timeout-seconds or split the brief so each run targets one "
            "file or subsystem (a single-file review typically returns in 2-3 minutes)."
        ) from exc


def with_retry(label: str, fn, attempts: int = 2):
    """Run fn, retrying once. The skill allows exactly one retry per sub-call.

    Transient proxy/TLS hiccups are common on this machine, and losing a whole
    four-call review to one blip is worse than paying for a second attempt.
    """
    last: ReviewError | None = None
    for attempt in range(1, attempts + 1):
        try:
            return fn()
        except ReviewError as exc:
            last = exc
            if attempt < attempts:
                print(
                    f"review-optimizer: {label} attempt {attempt} failed ({exc}); retrying once",
                    file=sys.stderr,
                )
    raise last  # type: ignore[misc]


def run_codex(prompt: str, args: argparse.Namespace) -> dict[str, Any]:
    with tempfile.NamedTemporaryFile(prefix="review-codex-", suffix=".txt", delete=False) as handle:
        last_message_path = Path(handle.name)
    command = [
        "codex",
        "exec",
        "--model",
        args.codex_model,
        "--config",
        'model_reasoning_effort="high"',
        "--sandbox",
        "read-only",
        "--cd",
        str(args.cwd),
        "--skip-git-repo-check",
        "--ephemeral",
        "--json",
        "--output-last-message",
        str(last_message_path),
        "-",
    ]
    try:
        completed = run_process(command, prompt, args.cwd, args.timeout_seconds)
        response = last_message_path.read_text(encoding="utf-8") if last_message_path.exists() else ""
    finally:
        last_message_path.unlink(missing_ok=True)
    if completed.returncode != 0 or not response.strip():
        detail = clean_text(completed.stderr or completed.stdout, 4_000)
        raise ReviewError(f"Codex failed (exit {completed.returncode}): {detail}")
    return {
        "selector": args.codex_model,
        "response": clean_text(response),
        "transport": "codex exec --sandbox read-only --ephemeral",
    }


def run_claude(prompt: str, args: argparse.Namespace) -> dict[str, Any]:
    command = [
        str(Path.home() / ".claude/bin/claude"),
        "--print",
        "--model",
        args.claude_model,
        "--effort",
        "high",
        "--permission-mode",
        "plan",
        "--safe-mode",
        "--disable-slash-commands",
        "--allowedTools",
        "Read,Grep,Glob",
        "--output-format",
        "json",
        "--no-session-persistence",
    ]
    completed = run_process(command, prompt, args.cwd, args.timeout_seconds)
    if completed.returncode != 0:
        detail = clean_text(completed.stderr or completed.stdout, 4_000)
        raise ReviewError(f"Claude failed (exit {completed.returncode}): {detail}")
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise ReviewError("Claude returned invalid JSON") from exc
    model_usage = payload.get("modelUsage") or {}
    model_names = sorted(model_usage)
    required_prefix = args.model_policy["claude"]["required_effective_prefix"]
    if not model_names or any(not name.startswith(required_prefix) for name in model_names):
        raise ReviewError(f"Claude model identity check failed: {model_names or 'missing'}")
    response = payload.get("result") or ""
    if not response.strip():
        raise ReviewError("Claude returned an empty result")
    return {
        "selector": args.claude_model,
        "effective_models": model_names,
        "response": clean_text(response),
        "transport": "official Anthropic guard; plan mode; safe mode",
    }


def render_report(
    args: argparse.Namespace,
    codex_initial: dict[str, Any],
    claude_initial: dict[str, Any],
    codex_reply: dict[str, Any] | None,
    claude_reply: dict[str, Any] | None,
    partial_reason: str | None = None,
) -> str:
    sections = [
        "# 审核优化专家 · 双模型讨论记录",
        "",
    ]
    if partial_reason:
        sections += [
            "> ⚠️ **本记录不完整**：仅含第一轮独立审核，对质轮未完成。",
            f"> 原因：{partial_reason}",
            "> 双方未互相检验，分歧未收敛 —— **不得据此判定通过**，结论按 UNKNOWN 处理。",
            "",
        ]
    sections += [
        f"- Codex selector: `{codex_initial['selector']}` ({codex_initial['transport']})",
        f"- Claude selector: `{claude_initial['selector']}`; effective: "
        + ", ".join(f"`{name}`" for name in claude_initial["effective_models"]),
        f"- Rounds: {args.rounds}",
        "",
        "## Codex 独立审核",
        codex_initial["response"],
        "",
        "## Claude 独立审核",
        claude_initial["response"],
    ]
    if codex_reply and claude_reply:
        sections.extend(
            [
                "",
                "## Codex 对质与归并",
                codex_reply["response"],
                "",
                "## Claude 最终回应",
                claude_reply["response"],
            ]
        )
    sections.extend(
        [
            "",
            "## 主 Agent 下一步",
            "逐条验证以上证据，归并共识与分歧；本记录本身不构成通过或修改授权。",
            "",
        ]
    )
    return "\n".join(sections)


def main() -> int:
    policy = load_model_policy()
    args = parse_args(policy)
    args.model_policy = policy
    if not args.brief_file.is_file():
        raise ReviewError(f"brief file not found: {args.brief_file}")
    if not args.cwd.is_dir():
        raise ReviewError(f"working directory not found: {args.cwd}")
    args.cwd = args.cwd.resolve()
    brief = args.brief_file.read_text(encoding="utf-8")
    if not brief.strip():
        raise ReviewError("brief is empty")
    if len(brief) > MAX_BRIEF_CHARS:
        raise ReviewError(f"brief exceeds {MAX_BRIEF_CHARS} characters; use paths and a smaller brief")

    independent_prompt = reviewer_contract("independent reviewer") + "\n\n<review_brief>\n" + brief + "\n</review_brief>"
    codex_initial = with_retry("codex/independent", lambda: run_codex(independent_prompt, args))
    claude_initial = with_retry("claude/independent", lambda: run_claude(independent_prompt, args))

    codex_reply = None
    claude_reply = None
    partial_reason: str | None = None
    if args.rounds == 2:
        codex_prompt = (
            reviewer_contract("Codex challenger")
            + "\n\nCompare the two independent reviews below. Test every disputed claim against the brief or files. "
            "Identify agreements, disagreements, duplicates, omissions, and unsupported claims.\n\n"
            + "<codex_initial>\n"
            + codex_initial["response"]
            + "\n</codex_initial>\n<claude_initial>\n"
            + claude_initial["response"]
            + "\n</claude_initial>\n<review_brief>\n"
            + brief
            + "\n</review_brief>"
        )
        # Round 2 is wrapped so a late failure doesn't discard round 1. Two
        # completed independent reviews are worth reading even without the
        # reconciliation pass — throwing them away forces a full, expensive
        # re-run and tempts whoever is driving to skip review entirely.
        try:
            codex_reply = with_retry("codex/challenger", lambda: run_codex(codex_prompt, args))
        except ReviewError as exc:
            partial_reason = f"round 2 (codex challenger) failed: {exc}"
        if codex_reply is not None:
            claude_prompt = (
                reviewer_contract("Claude final respondent")
                + "\n\nRespond to Codex's reconciliation below. Resolve claims using evidence, preserve justified minority objections, "
                "and state what the main agent must verify before acting.\n\n<codex_reconciliation>\n"
                + codex_reply["response"]
                + "\n</codex_reconciliation>\n<codex_initial>\n"
                + codex_initial["response"]
                + "\n</codex_initial>\n<claude_initial>\n"
                + claude_initial["response"]
                + "\n</claude_initial>\n<review_brief>\n"
                + brief
                + "\n</review_brief>"
            )
            try:
                claude_reply = with_retry(
                    "claude/final", lambda: run_claude(claude_prompt, args)
                )
            except ReviewError as exc:
                partial_reason = f"round 2 (claude final response) failed: {exc}"

    report = render_report(
        args, codex_initial, claude_initial, codex_reply, claude_reply, partial_reason
    )
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    else:
        sys.stdout.write(report)
    if partial_reason:
        # Distinct exit code: round 1 landed and the report is on disk, but the
        # reconciliation never happened, so the result must not be read as a pass.
        print(f"review-optimizer: incomplete — {partial_reason}", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ReviewError as exc:
        print(f"review-optimizer: {exc}", file=sys.stderr)
        raise SystemExit(2)
