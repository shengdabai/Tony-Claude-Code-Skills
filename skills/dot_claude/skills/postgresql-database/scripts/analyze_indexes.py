#!/usr/bin/env python3
"""
Analyze PostgreSQL indexes and provide optimization recommendations.

Usage:
    python analyze_indexes.py <database_url>

Example:
    python analyze_indexes.py postgresql://user:password@localhost/dbname
"""

import sys
from sqlalchemy import create_engine, text


def analyze_indexes(database_url):
    """Analyze indexes and provide recommendations."""
    engine = create_engine(database_url)

    print("=" * 80)
    print("PostgreSQL Index Analysis Report")
    print("=" * 80)

    with engine.connect() as conn:
        # 1. Find unused indexes
        print("\n1. UNUSED INDEXES (may be candidates for removal)")
        print("-" * 80)

        unused_query = text("""
            SELECT
                schemaname,
                tablename,
                indexname,
                idx_scan,
                pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
            FROM pg_stat_user_indexes
            WHERE idx_scan = 0
                AND indexrelname NOT LIKE 'pg_toast%'
            ORDER BY pg_relation_size(indexrelid) DESC
            LIMIT 20
        """)

        result = conn.execute(unused_query)
        unused = result.fetchall()

        if unused:
            print(f"{'Table':<20} {'Index':<30} {'Scans':<10} {'Size':<15}")
            print("-" * 80)
            for row in unused:
                print(f"{row[1]:<20} {row[2]:<30} {row[3]:<10} {row[4]:<15}")
            print(f"\nFound {len(unused)} unused indexes")
        else:
            print("✓ No unused indexes found")

        # 2. Find duplicate indexes
        print("\n\n2. DUPLICATE INDEXES (same columns)")
        print("-" * 80)

        duplicate_query = text("""
            SELECT
                indrelid::regclass AS table_name,
                array_agg(indexrelid::regclass) AS indexes,
                pg_size_pretty(sum(pg_relation_size(indexrelid))) AS total_size
            FROM pg_index
            GROUP BY indrelid, indkey
            HAVING COUNT(*) > 1
            ORDER BY sum(pg_relation_size(indexrelid)) DESC
        """)

        result = conn.execute(duplicate_query)
        duplicates = result.fetchall()

        if duplicates:
            print(f"{'Table':<30} {'Duplicate Indexes':<50} {'Total Size':<15}")
            print("-" * 80)
            for row in duplicates:
                indexes = ', '.join(str(idx) for idx in row[1])
                print(f"{row[0]:<30} {indexes:<50} {row[2]:<15}")
            print(f"\nFound {len(duplicates)} sets of duplicate indexes")
        else:
            print("✓ No duplicate indexes found")

        # 3. Find bloated indexes (estimate)
        print("\n\n3. POTENTIALLY BLOATED INDEXES")
        print("-" * 80)

        bloat_query = text("""
            SELECT
                schemaname,
                tablename,
                indexname,
                pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
                idx_scan,
                idx_tup_read,
                idx_tup_fetch
            FROM pg_stat_user_indexes
            WHERE pg_relation_size(indexrelid) > 10485760  -- > 10MB
                AND idx_scan > 0
            ORDER BY pg_relation_size(indexrelid) DESC
            LIMIT 20
        """)

        result = conn.execute(bloat_query)
        large_indexes = result.fetchall()

        if large_indexes:
            print(f"{'Table':<20} {'Index':<30} {'Size':<15} {'Scans':<10}")
            print("-" * 80)
            for row in large_indexes:
                print(f"{row[1]:<20} {row[2]:<30} {row[3]:<15} {row[4]:<10}")
            print(f"\n💡 Consider REINDEX CONCURRENTLY for large indexes")
        else:
            print("✓ No large indexes requiring attention")

        # 4. Missing indexes on foreign keys
        print("\n\n4. FOREIGN KEYS WITHOUT INDEXES")
        print("-" * 80)

        fk_query = text("""
            SELECT
                c.conrelid::regclass AS table_name,
                att.attname AS column_name,
                conname AS constraint_name
            FROM pg_constraint c
            JOIN pg_attribute att ON att.attrelid = c.conrelid
                AND att.attnum = ANY(c.conkey)
            WHERE c.contype = 'f'  -- Foreign key constraints
                AND NOT EXISTS (
                    SELECT 1
                    FROM pg_index i
                    WHERE i.indrelid = c.conrelid
                        AND att.attnum = ANY(i.indkey)
                )
            ORDER BY c.conrelid::regclass::text, att.attname
            LIMIT 20
        """)

        result = conn.execute(fk_query)
        missing_fk_indexes = result.fetchall()

        if missing_fk_indexes:
            print(f"{'Table':<30} {'Column':<30} {'Constraint':<30}")
            print("-" * 80)
            for row in missing_fk_indexes:
                print(f"{row[0]:<30} {row[1]:<30} {row[2]:<30}")
            print(f"\n💡 Consider adding indexes on these foreign key columns")
        else:
            print("✓ All foreign keys have indexes")

        # 5. Index usage statistics
        print("\n\n5. MOST USED INDEXES")
        print("-" * 80)

        used_query = text("""
            SELECT
                schemaname,
                tablename,
                indexname,
                idx_scan,
                pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
            FROM pg_stat_user_indexes
            WHERE idx_scan > 0
            ORDER BY idx_scan DESC
            LIMIT 10
        """)

        result = conn.execute(used_query)
        most_used = result.fetchall()

        if most_used:
            print(f"{'Table':<20} {'Index':<30} {'Scans':<15} {'Size':<15}")
            print("-" * 80)
            for row in most_used:
                print(f"{row[1]:<20} {row[2]:<30} {row[3]:<15} {row[4]:<15}")
        else:
            print("No index usage data available")

        # 6. Summary
        print("\n\n" + "=" * 80)
        print("RECOMMENDATIONS")
        print("=" * 80)

        if unused:
            print("• Remove or investigate unused indexes to reduce write overhead")
        if duplicates:
            print("• Remove duplicate indexes - they waste space and slow down writes")
        if missing_fk_indexes:
            print("• Add indexes on foreign key columns for better JOIN performance")
        if large_indexes:
            print("• Consider REINDEX CONCURRENTLY for large indexes to reduce bloat")

        if not (unused or duplicates or missing_fk_indexes):
            print("✓ Your indexes look healthy! Keep monitoring usage patterns.")

        print("\n💡 Run ANALYZE regularly to keep statistics up to date")
        print("💡 Use 'EXPLAIN ANALYZE' to verify index usage in queries")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)

    database_url = sys.argv[1]
    try:
        analyze_indexes(database_url)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
