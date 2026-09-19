#!/usr/bin/env python3
"""Check staged Git blobs, never print credential values. Complements vendor scans."""
import argparse
from collections import Counter
import json
import math
from pathlib import PurePosixPath
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(['git', *args], stderr=subprocess.DEVNULL)


def forbidden_path(name):
    name = name.casefold()
    p = PurePosixPath(name)
    return (p.name == 'sessions_extracted.json'
            or name == 'skills/xiaolai/claude-agent-sdk/agent/state.json'
            or any(part in {'sessions', 'ai-archive', 'browser_state', 'browser_profile', '.ssh', '.aws'} for part in p.parts)
            or p.name in {'auth.json', '.npmrc'}
            or p.name.startswith(('.env', 'credentials.', 'secrets.', 'id_rsa'))
            or p.suffix in {'.key', '.pem', '.p12', '.pfx'})


def entropy(value):
    return -sum(n / len(value) * math.log2(n / len(value)) for n in Counter(value).values())


def findings(data):
    # JSON exports contain literal backslash-n; normalize those as well as newlines.
    encoding = 'utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8'
    text = data.decode(encoding, errors='replace').replace('\\r', '\r').replace('\\n', '\n').replace('\\t', '\t')
    rules = {
        'alibaba-access-key-id': r'(?<![A-Za-z0-9])LTAI[A-Za-z0-9]{12,30}(?![A-Za-z0-9])',
        'labelled-access-key-secret': r'(?i:access[ _-]*key[ _-]*secret)[\s:=：*|\"\'\\`]{1,16}([A-Za-z0-9+/=_-]{16,64})(?![A-Za-z0-9+/=_-])',
    }
    result = []
    for rule, pattern in rules.items():
        for match in re.finditer(pattern, text):
            value = match.group(1) if match.lastindex else match.group()
            # Exact placeholder syntax / obvious repeated examples only, no path exemptions.
            if value.upper().startswith(('YOUR_', 'EXAMPLE_', 'REDACTED')):
                continue
            if entropy(value) < 3.5:
                continue
            result.append(rule)
    return sorted(set(result))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    entries = []
    failures = []
    for record in git('ls-files', '--stage', '-z').split(b'\0'):
        if not record:
            continue
        info, raw_name = record.split(b'\t', 1)
        mode, oid, stage = info.split()
        name = raw_name.decode('utf-8', errors='surrogateescape')
        if stage != b'0':
            failures.append((name, 'unmerged-index'))
        elif forbidden_path(name) and not (PurePosixPath(name).name.casefold() == '.env.example' and not forbidden_path(str(PurePosixPath(name).parent / 'template.txt'))):
            # Runtime files have no .example exemption. Scan env templates below.
            failures.append((name, 'private-runtime-or-credential-file'))
        elif mode == b'160000':
            failures.append((name, 'unscanned-submodule'))
        else:
            entries.append((name, oid))
    # One Git subprocess avoids per-file overhead and scans the staged blob, not disk.
    with subprocess.Popen(['git', 'cat-file', '--batch'], stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as proc:
        for name, oid in entries:
            proc.stdin.write(oid + b'\n')
            proc.stdin.flush()
            header = proc.stdout.readline().split()
            if len(header) != 3 or header[1] != b'blob':
                raise RuntimeError('unreadable Git blob')
            size = int(header[2])
            data = proc.stdout.read(size)
            if len(data) != size or proc.stdout.read(1) != b'\n':
                raise RuntimeError('truncated Git blob')
            failures.extend((name, rule) for rule in findings(data))
        proc.stdin.close()
        if proc.wait() != 0:
            raise RuntimeError('Git blob reader failed')
    for name, rule in failures:
        print(json.dumps({'path': name, 'rule': rule}, ensure_ascii=True))
    print(f'Public-content guard: {len(entries)} staged blobs checked; {len(failures)} findings. Values withheld.')
    return 1 if failures else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, subprocess.SubprocessError, ValueError, RuntimeError):
        print('Public-content guard failed; publication must stop.', file=sys.stderr)
        sys.exit(2)
