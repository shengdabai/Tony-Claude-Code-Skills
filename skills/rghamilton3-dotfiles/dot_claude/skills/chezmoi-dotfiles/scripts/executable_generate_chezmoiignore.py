#!/usr/bin/env python3
"""
Generate comprehensive .chezmoiignore based on common patterns.
Helps build a robust ignore file for various languages and tools.
"""

import argparse
import sys
from pathlib import Path
from typing import Dict, List, Set

# Categorized ignore patterns
PATTERNS = {
    'security': {
        'description': 'Security-sensitive files (always included)',
        'required': True,
        'patterns': [
            '# Security: Never track these files',
            '**/.env',
            '**/.env.*',
            '!**/.env.template',
            '!**/.env.example',
            '**/secrets.yaml',
            '**/secrets.yml',
            '**/*credentials*',
            '**/*secret*',
            '**/*.key',
            '**/*.pem',
            '**/.ssh/id_*',
            '**/.ssh/*_rsa',
            '**/.ssh/*_ed25519',
            '**/.gnupg/**',
            '**/.aws/credentials',
            '**/.docker/config.json',
            '**/.kube/config',
        ]
    },

    'python': {
        'description': 'Python cache and virtual environments',
        'required': False,
        'patterns': [
            '# Python',
            '**/__pycache__/**',
            '**/*.pyc',
            '**/*.pyo',
            '**/*.pyd',
            '**/.Python',
            '**/.venv/**',
            '**/venv/**',
            '**/ENV/**',
            '**/env/**',
            '**/.pytest_cache/**',
            '**/.mypy_cache/**',
            '**/.ruff_cache/**',
            '**/.tox/**',
            '**/.coverage',
            '**/.hypothesis/**',
            '**/htmlcov/**',
            '**/*.egg-info/**',
            '**/dist/**',
            '**/build/**',
        ]
    },

    'node': {
        'description': 'Node.js and JavaScript tooling',
        'required': False,
        'patterns': [
            '# Node.js',
            '**/node_modules/**',
            '**/.npm/**',
            '**/.yarn/**',
            '**/.pnpm-store/**',
            '**/.next/**',
            '**/.nuxt/**',
            '**/.cache/**',
            '**/dist/**',
            '**/build/**',
            '**/.turbo/**',
            '**/.parcel-cache/**',
            '**/.vercel/**',
            '**/coverage/**',
        ]
    },

    'rust': {
        'description': 'Rust build artifacts',
        'required': False,
        'patterns': [
            '# Rust',
            '**/target/**',
            '**/*.rs.bk',
            '**/Cargo.lock',
        ]
    },

    'go': {
        'description': 'Go build artifacts',
        'required': False,
        'patterns': [
            '# Go',
            '**/go.sum',
            '**/*.exe',
            '**/*.exe~',
            '**/*.dll',
            '**/*.so',
            '**/*.dylib',
        ]
    },

    'ruby': {
        'description': 'Ruby gems and bundler',
        'required': False,
        'patterns': [
            '# Ruby',
            '**/.bundle/**',
            '**/vendor/bundle/**',
            '**/*.gem',
            '**/.ruby-version',
        ]
    },

    'java': {
        'description': 'Java/Maven/Gradle artifacts',
        'required': False,
        'patterns': [
            '# Java',
            '**/target/**',
            '**/*.class',
            '**/*.jar',
            '**/*.war',
            '**/.gradle/**',
            '**/build/**',
        ]
    },

    'macos': {
        'description': 'macOS system files',
        'required': False,
        'patterns': [
            '# macOS',
            '**/.DS_Store',
            '**/.AppleDouble',
            '**/.LSOverride',
            '**/.Spotlight-V100',
            '**/.Trashes',
            '**/.fseventsd',
            '**/.DocumentRevisions-V100',
            '**/.TemporaryItems',
        ]
    },

    'windows': {
        'description': 'Windows system files',
        'required': False,
        'patterns': [
            '# Windows',
            '**/Thumbs.db',
            '**/desktop.ini',
            '**/$RECYCLE.BIN/**',
            '**/System Volume Information/**',
        ]
    },

    'linux': {
        'description': 'Linux cache and temporary files',
        'required': False,
        'patterns': [
            '# Linux',
            '**/.cache/**',
            '**/.local/share/Trash/**',
            '**/.thumbnails/**',
        ]
    },

    'editors': {
        'description': 'IDE and editor files',
        'required': False,
        'patterns': [
            '# Editors and IDEs',
            '**/.vscode/**',
            '**/.idea/**',
            '**/*.sublime-project',
            '**/*.sublime-workspace',
            '**/.vim/swap/**',
            '**/.vim/backup/**',
            '**/*.swp',
            '**/*.swo',
            '**/*~',
        ]
    },

    'history': {
        'description': 'Shell and application history',
        'required': False,
        'patterns': [
            '# History files',
            '**/.bash_history',
            '**/.zsh_history',
            '**/.python_history',
            '**/.node_repl_history',
            '**/.lesshst',
            '**/.wget-hsts',
            '**/.sqlite_history',
        ]
    },

    'browsers': {
        'description': 'Browser data and cache',
        'required': False,
        'patterns': [
            '# Browser data',
            '**/.mozilla/**/storage/**',
            '**/.mozilla/**/cache2/**',
            '**/.config/google-chrome/**/Storage/**',
            '**/.config/google-chrome/**/Cache/**',
            '**/.config/chromium/**/Storage/**',
            '**/.config/chromium/**/Cache/**',
        ]
    },

    'logs': {
        'description': 'Log files',
        'required': False,
        'patterns': [
            '# Logs',
            '**/*.log',
            '**/*.pid',
            '**/logs/**',
        ]
    },

    'temp': {
        'description': 'Temporary files',
        'required': False,
        'patterns': [
            '# Temporary files',
            '**/*.tmp',
            '**/*.temp',
            '**/tmp/**',
            '**/temp/**',
        ]
    },

    'docker': {
        'description': 'Docker local data',
        'required': False,
        'patterns': [
            '# Docker',
            '**/.docker/**/cli-plugins/**',
            '**/.docker/**/contexts/**',
        ]
    },
}


def generate_chezmoiignore(categories: Set[str], output_file: Path = None) -> str:
    """Generate .chezmoiignore content based on selected categories."""
    lines = [
        '# Generated .chezmoiignore',
        '# Customize this file based on your needs',
        '',
    ]

    # Always include security patterns
    categories.add('security')

    for category in sorted(categories):
        if category not in PATTERNS:
            print(f"Warning: Unknown category '{category}'", file=sys.stderr)
            continue

        pattern_info = PATTERNS[category]
        lines.append('')
        lines.extend(pattern_info['patterns'])

    content = '\n'.join(lines) + '\n'

    if output_file:
        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.write_text(content)
        print(f"✅ Generated .chezmoiignore at {output_file}")

    return content


def get_default_categories() -> Set[str]:
    """Get recommended default categories."""
    return {
        'security',
        'macos' if sys.platform == 'darwin' else 'linux',
        'editors',
        'history',
        'logs',
        'temp',
    }


def list_categories():
    """List all available categories with descriptions."""
    print("Available categories:\n")
    for category, info in sorted(PATTERNS.items()):
        required = " [REQUIRED]" if info['required'] else ""
        print(f"  {category:15} - {info['description']}{required}")
    print("\nDefault categories:", ', '.join(sorted(get_default_categories())))


def main():
    parser = argparse.ArgumentParser(
        description='Generate comprehensive .chezmoiignore file',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Generate with defaults
  %(prog)s

  # Generate for Python + Node.js project
  %(prog)s --categories python node

  # Generate everything
  %(prog)s --all

  # List available categories
  %(prog)s --list

  # Generate to specific location
  %(prog)s --output ~/.local/share/chezmoi/.chezmoiignore
        '''
    )

    parser.add_argument(
        '--categories', '-c',
        nargs='+',
        metavar='CATEGORY',
        help='Categories to include (default: sensible defaults)'
    )

    parser.add_argument(
        '--all', '-a',
        action='store_true',
        help='Include all categories'
    )

    parser.add_argument(
        '--list', '-l',
        action='store_true',
        help='List available categories and exit'
    )

    parser.add_argument(
        '--output', '-o',
        type=Path,
        metavar='FILE',
        help='Output file path (default: print to stdout)'
    )

    args = parser.parse_args()

    if args.list:
        list_categories()
        return

    # Determine which categories to include
    if args.all:
        categories = set(PATTERNS.keys())
    elif args.categories:
        categories = set(args.categories)
    else:
        categories = get_default_categories()

    # Generate content
    content = generate_chezmoiignore(categories, args.output)

    # Print to stdout if no output file specified
    if not args.output:
        print(content)


if __name__ == '__main__':
    main()
