#!/usr/bin/env python3
"""import_allowlist: enforce layer boundaries from a declared module map (JS/TS/Python, stdlib only).

Inspired by the architecture check in xiaolai/sonovo: the allowlist describes the layers the
project *intends*, not whatever imports happen to resolve. Every source file is assigned to a
module by glob; every import is resolved to a module (or an external package) and compared with
the module's allowlist.

Config (architecture.json, paths relative to the config file's directory):

{
  "modules": { "app": ["app.js"], "logic": ["src/logic.js"], "data": ["src/data.js"], "tests": ["tests/**"] },
  "allowed":  { "app": ["logic", "data"], "logic": ["data"], "data": [], "tests": ["*"] },
  "external": { "*": [], "tests": ["node:*", "playwright"] },
  "ignore":   ["node_modules/**", ".git/**"]
}

* ``allowed[m]`` lists the modules ``m`` may import; ``"*"`` means any. A module absent from
  ``allowed`` may import nothing internal.
* ``external[m]`` lists bare-specifier packages ``m`` may import (fnmatch patterns); ``"*"`` is
  the default for every module. ``node:*`` covers Node built-ins.
* A source file that matches no module is reported as ``unassigned`` (use ``ignore`` or add it).

Exit codes: 0 clean, 1 violations, 2 config / input error.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
from pathlib import Path, PurePosixPath

JS_EXT = (".js", ".mjs", ".cjs", ".ts", ".mts", ".cts", ".tsx", ".jsx")
PY_EXT = (".py",)
IMPORT_RES = [
    re.compile(r"^\s*import\s+(?:[^'\"]*?\s+from\s+)?['\"]([^'\"]+)['\"]", re.M),
    re.compile(r"^\s*export\s+[^'\"]*?\s+from\s+['\"]([^'\"]+)['\"]", re.M),
    re.compile(r"\brequire\(\s*['\"]([^'\"]+)['\"]\s*\)"),
    re.compile(r"\bimport\(\s*['\"]([^'\"]+)['\"]\s*\)"),
]
PY_IMPORT_RES = [re.compile(r"^\s*import\s+([\w.]+)", re.M), re.compile(r"^\s*from\s+([\w.]+)\s+import\b", re.M)]
STDLIB_FALLBACK = {"os", "sys", "re", "json", "pathlib", "typing", "collections", "itertools", "functools", "subprocess", "argparse", "datetime", "hashlib", "tempfile", "unittest", "io", "math", "time", "shutil", "logging", "dataclasses", "fnmatch", "glob", "string", "textwrap", "copy", "enum", "abc", "contextlib", "urllib", "http", "socket", "threading", "asyncio", "csv", "sqlite3", "random", "statistics", "importlib", "inspect", "traceback", "warnings", "struct", "base64", "uuid", "secrets", "signal", "select", "queue", "heapq", "bisect", "array", "zlib", "gzip", "tarfile", "zipfile", "email", "html", "xml", "decimal", "fractions", "numbers", "operator", "pprint", "platform", "getpass", "locale", "gettext", "codecs", "unicodedata", "difflib"}
NODE_BUILTINS = {"fs", "path", "os", "url", "util", "assert", "child_process", "crypto", "events", "http", "https", "net", "stream", "readline", "zlib", "test", "worker_threads", "module", "process", "buffer", "timers", "tty", "dns"}


def glob_match(rel: str, pattern: str) -> bool:
    """fnmatch with ``**`` meaning any depth (fnmatch's ``*`` already crosses ``/``, so normalise)."""
    pat = pattern.replace("**/", "*").replace("/**", "/*").replace("**", "*")
    return fnmatch.fnmatchcase(rel, pat) or fnmatch.fnmatchcase(rel, pattern)


def load_config(path: Path) -> dict:
    try:
        cfg = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"error: cannot read {path}: {exc}") from exc
    for key in ("modules", "allowed"):
        if key not in cfg or not isinstance(cfg[key], dict):
            raise SystemExit(f"error: {path}: '{key}' must be an object")
    cfg.setdefault("external", {})
    cfg.setdefault("ignore", ["node_modules/**", ".git/**", ".git.nosync/**", "dist/**", "build/**"])
    for m, targets in cfg["allowed"].items():
        if m not in cfg["modules"]:
            raise SystemExit(f"error: allowed.{m} names an undeclared module")
        for t in targets:
            if t != "*" and t not in cfg["modules"]:
                raise SystemExit(f"error: allowed.{m} lists undeclared module '{t}'")
    return cfg


def module_of(rel: str, cfg: dict) -> str | None:
    for name, patterns in cfg["modules"].items():
        if any(glob_match(rel, p) for p in patterns):
            return name
    return None


def iter_sources(root: Path, cfg: dict):
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = Path(dirpath).relative_to(root).as_posix()
        dirnames[:] = [d for d in dirnames if not any(glob_match((f"{rel_dir}/{d}" if rel_dir != "." else d) + "/x", pat) or glob_match((f"{rel_dir}/{d}" if rel_dir != "." else d), pat.rstrip("/*")) for pat in cfg["ignore"])]
        for f in sorted(filenames):
            if not f.endswith(JS_EXT + PY_EXT):
                continue
            rel = f"{rel_dir}/{f}" if rel_dir != "." else f
            if any(glob_match(rel, pat) for pat in cfg["ignore"]):
                continue
            yield rel


def resolve_js(spec: str, from_rel: str, root: Path) -> str | None:
    """Resolve a relative import to a repo-relative file path, or None for bare specifiers."""
    if not spec.startswith((".", "/")):
        return None
    base = (PurePosixPath(from_rel).parent / spec) if spec.startswith(".") else PurePosixPath(spec.lstrip("/"))
    candidates = [base]
    if not PurePosixPath(base).suffix:
        candidates += [base.with_suffix(ext) for ext in JS_EXT] + [base / f"index{ext}" for ext in JS_EXT]
    for c in candidates:
        p = root / PurePosixPath(os.path.normpath(str(c)))
        if p.is_file():
            return PurePosixPath(os.path.normpath(str(c))).as_posix()
    return PurePosixPath(os.path.normpath(str(base))).as_posix()


def resolve_py(spec: str, from_rel: str, root: Path) -> str | None:
    parts = spec.split(".")
    if spec.startswith("."):
        return None
    for n in range(len(parts), 0, -1):
        cand = root / Path(*parts[:n])
        if (cand.with_suffix(".py")).is_file():
            return cand.with_suffix(".py").relative_to(root).as_posix()
        if (cand / "__init__.py").is_file():
            return (cand / "__init__.py").relative_to(root).as_posix()
    return None


def external_allowed(module: str, spec: str, cfg: dict) -> bool:
    pkg = spec
    if spec.startswith("node:") or spec.split("/")[0] in NODE_BUILTINS:
        pkg = "node:" + spec.removeprefix("node:")
    else:
        head = spec.split("/")
        pkg = "/".join(head[:2]) if spec.startswith("@") else head[0]
    patterns = list(cfg["external"].get("*", [])) + list(cfg["external"].get(module, []))
    return any(fnmatch.fnmatchcase(pkg, p) or fnmatch.fnmatchcase(spec, p) for p in patterns)


def check(root: Path, cfg: dict) -> list[dict]:
    violations: list[dict] = []
    for rel in iter_sources(root, cfg):
        module = module_of(rel, cfg)
        if module is None:
            violations.append({"file": rel, "line": 0, "kind": "unassigned", "detail": "file matches no module in architecture.json"})
            continue
        text = (root / rel).read_text(encoding="utf-8", errors="replace")
        allowed = cfg["allowed"].get(module, [])
        is_py = rel.endswith(PY_EXT)
        specs: list[tuple[str, int]] = []
        for rx in PY_IMPORT_RES if is_py else IMPORT_RES:
            for m in rx.finditer(text):
                specs.append((m.group(1), text.count("\n", 0, m.start()) + 1))
        for spec, line in specs:
            target = resolve_py(spec, rel, root) if is_py else resolve_js(spec, rel, root)
            if target is None:
                if is_py and (spec.split(".")[0] in getattr(sys, "stdlib_module_names", STDLIB_FALLBACK) or spec.startswith(".")):
                    continue
                if not external_allowed(module, spec, cfg):
                    violations.append({"file": rel, "line": line, "kind": "external", "detail": f"module '{module}' imports external package '{spec}' which is not in external.{module} or external.*"})
                continue
            tmod = module_of(target, cfg)
            if tmod is None:
                violations.append({"file": rel, "line": line, "kind": "unassigned-target", "detail": f"imports '{spec}' -> {target}, which matches no module"})
                continue
            if tmod == module or "*" in allowed or tmod in allowed:
                continue
            violations.append({"file": rel, "line": line, "kind": "layer", "detail": f"module '{module}' may not import module '{tmod}' ('{spec}'); allowed: {', '.join(allowed) or 'nothing'}"})
    return violations


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="import_allowlist", description=__doc__.split("\n\n")[0])
    ap.add_argument("config", nargs="?", default="architecture.json")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    cfg_path = Path(args.config)
    if not cfg_path.is_file():
        print(f"error: {cfg_path} not found", file=sys.stderr)
        return 2
    cfg = load_config(cfg_path)
    root = (cfg_path.parent / cfg.get("root", ".")).resolve()
    violations = check(root, cfg)
    if args.json:
        print(json.dumps({"root": str(root), "violations": violations, "ok": not violations}, ensure_ascii=False, indent=2))
    else:
        for v in violations:
            print(f"{v['file']}:{v['line']}: {v['kind']}: {v['detail']}")
        print(f"import-allowlist: {'OK' if not violations else str(len(violations)) + ' violation(s)'} ({len(cfg['modules'])} modules, root {root})")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
