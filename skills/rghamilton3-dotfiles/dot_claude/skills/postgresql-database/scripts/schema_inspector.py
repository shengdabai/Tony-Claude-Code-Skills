#!/usr/bin/env python3
"""
Inspect PostgreSQL database schema and generate documentation.

Usage:
    python schema_inspector.py <database_url> [--output markdown|json] [--table TABLE]

Example:
    python schema_inspector.py postgresql://user:password@localhost/dbname
    python schema_inspector.py postgresql://user:password@localhost/dbname --table users
    python schema_inspector.py postgresql://user:password@localhost/dbname --output json
"""

import sys
import json
import argparse
from sqlalchemy import create_engine, inspect, MetaData


def format_column_type(column_type):
    """Format SQLAlchemy column type as string."""
    return str(column_type)


def get_table_info(inspector, table_name):
    """Get detailed information about a table."""
    columns = inspector.get_columns(table_name)
    pk_constraint = inspector.get_pk_constraint(table_name)
    foreign_keys = inspector.get_foreign_keys(table_name)
    indexes = inspector.get_indexes(table_name)
    unique_constraints = inspector.get_unique_constraints(table_name)

    return {
        'name': table_name,
        'columns': columns,
        'primary_key': pk_constraint,
        'foreign_keys': foreign_keys,
        'indexes': indexes,
        'unique_constraints': unique_constraints,
    }


def format_markdown_table(table_info):
    """Format table information as Markdown."""
    md = f"## {table_info['name']}\n\n"

    # Columns
    md += "### Columns\n\n"
    md += "| Column | Type | Nullable | Default | Comment |\n"
    md += "|--------|------|----------|---------|----------|\n"

    for col in table_info['columns']:
        col_name = col['name']
        col_type = format_column_type(col['type'])
        nullable = 'YES' if col.get('nullable', True) else 'NO'
        default = col.get('default', '')
        comment = col.get('comment', '')

        md += f"| {col_name} | {col_type} | {nullable} | {default} | {comment} |\n"

    # Primary Key
    if table_info['primary_key'] and table_info['primary_key'].get('constrained_columns'):
        md += "\n### Primary Key\n\n"
        pk_cols = ', '.join(table_info['primary_key']['constrained_columns'])
        md += f"- `{pk_cols}`\n"

    # Foreign Keys
    if table_info['foreign_keys']:
        md += "\n### Foreign Keys\n\n"
        md += "| Column | References | On Delete | On Update |\n"
        md += "|--------|------------|-----------|------------|\n"

        for fk in table_info['foreign_keys']:
            col_name = ', '.join(fk['constrained_columns'])
            ref_table = fk['referred_table']
            ref_cols = ', '.join(fk['referred_columns'])
            on_delete = fk.get('ondelete', '')
            on_update = fk.get('onupdate', '')

            md += f"| {col_name} | {ref_table}({ref_cols}) | {on_delete} | {on_update} |\n"

    # Indexes
    if table_info['indexes']:
        md += "\n### Indexes\n\n"
        md += "| Name | Columns | Unique | Type |\n"
        md += "|------|---------|--------|------|\n"

        for idx in table_info['indexes']:
            idx_name = idx['name']
            idx_cols = ', '.join(idx['column_names'])
            unique = 'YES' if idx.get('unique', False) else 'NO'
            idx_type = idx.get('type', 'btree')

            md += f"| {idx_name} | {idx_cols} | {unique} | {idx_type} |\n"

    # Unique Constraints
    if table_info['unique_constraints']:
        md += "\n### Unique Constraints\n\n"
        for uc in table_info['unique_constraints']:
            uc_name = uc.get('name', 'unnamed')
            uc_cols = ', '.join(uc['column_names'])
            md += f"- `{uc_name}`: {uc_cols}\n"

    md += "\n---\n\n"
    return md


def inspect_schema(database_url, output_format='markdown', specific_table=None):
    """Inspect database schema and generate documentation."""
    engine = create_engine(database_url)
    inspector = inspect(engine)

    # Get table names
    table_names = inspector.get_table_names()

    if specific_table:
        if specific_table not in table_names:
            print(f"Error: Table '{specific_table}' not found", file=sys.stderr)
            return False
        table_names = [specific_table]

    # Collect information
    tables_info = []
    for table_name in sorted(table_names):
        table_info = get_table_info(inspector, table_name)
        tables_info.append(table_info)

    # Output
    if output_format == 'json':
        # JSON output
        print(json.dumps(tables_info, indent=2, default=str))

    elif output_format == 'markdown':
        # Markdown output
        print(f"# Database Schema: {engine.url.database}\n\n")
        print(f"**Total Tables:** {len(tables_info)}\n\n")

        # Table of contents
        print("## Tables\n")
        for table_info in tables_info:
            print(f"- [{table_info['name']}](#{table_info['name']})")
        print("\n---\n")

        # Detailed information for each table
        for table_info in tables_info:
            print(format_markdown_table(table_info))

        # Summary statistics
        print("## Summary\n\n")

        total_columns = sum(len(t['columns']) for t in tables_info)
        total_indexes = sum(len(t['indexes']) for t in tables_info)
        total_fks = sum(len(t['foreign_keys']) for t in tables_info)

        print(f"- **Total Tables:** {len(tables_info)}")
        print(f"- **Total Columns:** {total_columns}")
        print(f"- **Total Indexes:** {total_indexes}")
        print(f"- **Total Foreign Keys:** {total_fks}")

        # Tables without primary keys
        tables_without_pk = [
            t['name'] for t in tables_info
            if not t['primary_key'] or not t['primary_key'].get('constrained_columns')
        ]

        if tables_without_pk:
            print(f"\n⚠️ **Tables without Primary Key:** {', '.join(tables_without_pk)}")

        # Tables without indexes (excluding primary key)
        tables_without_indexes = [
            t['name'] for t in tables_info
            if len(t['indexes']) == 0
        ]

        if tables_without_indexes:
            print(f"\n⚠️ **Tables without Indexes:** {', '.join(tables_without_indexes)}")

    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database_url", help="PostgreSQL connection URL")
    parser.add_argument(
        "--output",
        choices=['markdown', 'json'],
        default='markdown',
        help="Output format (default: markdown)"
    )
    parser.add_argument(
        "--table",
        help="Inspect specific table only"
    )

    args = parser.parse_args()

    try:
        success = inspect_schema(args.database_url, args.output, args.table)
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
