#!/usr/bin/env python3
"""
Scan chezmoi source directory for potential secrets before committing.
Helps prevent accidental exposure of sensitive data in dotfiles repositories.
"""

import re
import sys
from pathlib import Path
from typing import List, Tuple

# Patterns for common secrets (case-insensitive)
SECRET_PATTERNS = [
    # API Keys and Tokens
    (r'api[_-]?key\s*[=:]\s*["\']?([a-zA-Z0-9_\-]{20,})', 'API Key'),
    (r'api[_-]?secret\s*[=:]\s*["\']?([a-zA-Z0-9_\-]{20,})', 'API Secret'),
    (r'access[_-]?token\s*[=:]\s*["\']?([a-zA-Z0-9_\-]{20,})', 'Access Token'),
    (r'auth[_-]?token\s*[=:]\s*["\']?([a-zA-Z0-9_\-]{20,})', 'Auth Token'),
    (r'secret[_-]?key\s*[=:]\s*["\']?([a-zA-Z0-9_\-]{20,})', 'Secret Key'),

    # AWS Credentials
    (r'AKIA[0-9A-Z]{16}', 'AWS Access Key ID'),
    (r'aws[_-]?secret[_-]?access[_-]?key\s*[=:]\s*["\']?([a-zA-Z0-9/+]{40})', 'AWS Secret Access Key'),

    # Private Keys
    (r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----', 'Private Key'),
    (r'-----BEGIN PGP PRIVATE KEY BLOCK-----', 'PGP Private Key'),

    # Passwords
    (r'password\s*[=:]\s*["\']([^"\']{8,})["\']', 'Password'),
    (r'passwd\s*[=:]\s*["\']([^"\']{8,})["\']', 'Password'),
    (r'pwd\s*[=:]\s*["\']([^"\']{8,})["\']', 'Password'),

    # Database Strings
    (r'postgres://[^:]+:[^@]+@', 'PostgreSQL Connection String'),
    (r'mysql://[^:]+:[^@]+@', 'MySQL Connection String'),
    (r'mongodb(\+srv)?://[^:]+:[^@]+@', 'MongoDB Connection String'),

    # Generic Secrets
    (r'client[_-]?secret\s*[=:]\s*["\']?([a-zA-Z0-9_\-]{20,})', 'Client Secret'),
    (r'consumer[_-]?secret\s*[=:]\s*["\']?([a-zA-Z0-9_\-]{20,})', 'Consumer Secret'),
    (r'bearer\s+[a-zA-Z0-9_\-\.]{20,}', 'Bearer Token'),

    # GitHub/GitLab Tokens
    (r'gh[pousr]_[a-zA-Z0-9]{36,}', 'GitHub Token'),
    (r'glpat-[a-zA-Z0-9\-_]{20,}', 'GitLab Token'),

    # Slack Tokens
    (r'xox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{24,}', 'Slack Token'),
]

# Files/patterns to always check (even if in .chezmoiignore)
CRITICAL_FILES = [
    '.env',
    '.env.local',
    '.env.production',
    'secrets.yaml',
    'secrets.yml',
    'credentials',
]


def find_secrets(content: str, filepath: Path) -> List[Tuple[str, int, str]]:
    """
    Scan content for potential secrets.
    Returns list of (secret_type, line_number, line_content) tuples.
    """
    findings = []
    lines = content.split('\n')

    for line_num, line in enumerate(lines, 1):
        for pattern, secret_type in SECRET_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                findings.append((secret_type, line_num, line.strip()))

    return findings


def is_likely_template(filepath: Path) -> bool:
    """Check if file is likely a chezmoi template that handles secrets safely."""
    # chezmoi template files
    if '.tmpl' in filepath.name:
        return True

    # Files encrypted with age
    if filepath.suffix == '.age':
        return True

    return False


def scan_directory(source_dir: Path) -> dict:
    """
    Scan chezmoi source directory for secrets.
    Returns dict mapping files to their findings.
    """
    results = {}

    if not source_dir.exists():
        print(f"Error: Directory {source_dir} does not exist", file=sys.stderr)
        sys.exit(1)

    # Get all text files
    for filepath in source_dir.rglob('*'):
        if not filepath.is_file():
            continue

        # Skip binary files
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
        except (UnicodeDecodeError, PermissionError):
            continue

        # Scan for secrets
        findings = find_secrets(content, filepath)

        if findings:
            relative_path = filepath.relative_to(source_dir)
            results[relative_path] = {
                'findings': findings,
                'is_template': is_likely_template(filepath),
                'is_critical': any(cf in str(filepath) for cf in CRITICAL_FILES)
            }

    return results


def print_results(results: dict) -> int:
    """Print scan results. Returns exit code (0 if safe, 1 if secrets found)."""
    if not results:
        print("✅ No secrets detected in chezmoi source directory")
        return 0

    print("🚨 POTENTIAL SECRETS DETECTED")
    print("=" * 60)

    exit_code = 0

    for filepath, data in sorted(results.items()):
        print(f"\n📄 {filepath}")

        if data['is_template']:
            print("   ℹ️  This is a template file - verify secrets are templated correctly")
        elif data['is_critical']:
            print("   ⚠️  CRITICAL: This file commonly contains secrets")
            exit_code = 1
        else:
            exit_code = 1

        for secret_type, line_num, line_content in data['findings']:
            print(f"   Line {line_num}: {secret_type}")
            print(f"      {line_content[:80]}...")

    print("\n" + "=" * 60)
    print("\n🔐 RECOMMENDATIONS:")
    print("1. Remove secrets from tracked files")
    print("2. Use chezmoi templates with {{ .secret_name }}")
    print("3. Store secrets in ~/.config/chezmoi/chezmoi.yaml")
    print("4. Use age encryption: chezmoi add --encrypt ~/.ssh/id_rsa")
    print("5. Add sensitive files to .chezmoiignore")

    return exit_code


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Scan chezmoi source directory for potential secrets'
    )
    parser.add_argument(
        'source_dir',
        nargs='?',
        default=Path.home() / '.local/share/chezmoi',
        type=Path,
        help='Path to chezmoi source directory (default: ~/.local/share/chezmoi)'
    )

    args = parser.parse_args()

    print(f"Scanning {args.source_dir} for secrets...")
    results = scan_directory(args.source_dir)
    sys.exit(print_results(results))


if __name__ == '__main__':
    main()
