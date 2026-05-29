#!/usr/bin/env python3
"""
Analyze slow queries using pg_stat_statements.

This script requires the pg_stat_statements extension to be enabled:
    CREATE EXTENSION pg_stat_statements;

Usage:
    python analyze_queries.py <database_url> [--limit N]

Example:
    python analyze_queries.py postgresql://user:password@localhost/dbname --limit 20
"""

import sys
import argparse
from sqlalchemy import create_engine, text


def format_time(ms):
    """Format milliseconds to human-readable string."""
    if ms < 1000:
        return f"{ms:.2f}ms"
    elif ms < 60000:
        return f"{ms/1000:.2f}s"
    else:
        return f"{ms/60000:.2f}m"


def analyze_queries(database_url, limit=10):
    """Analyze slow queries using pg_stat_statements."""
    engine = create_engine(database_url)

    print("=" * 120)
    print("PostgreSQL Query Performance Analysis")
    print("=" * 120)

    with engine.connect() as conn:
        # Check if pg_stat_statements is available
        check_ext = text("""
            SELECT EXISTS(
                SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
            )
        """)

        result = conn.execute(check_ext)
        has_extension = result.scalar()

        if not has_extension:
            print("\n❌ pg_stat_statements extension is not installed!")
            print("\nTo install it:")
            print("  1. Add 'pg_stat_statements' to shared_preload_libraries in postgresql.conf")
            print("  2. Restart PostgreSQL")
            print("  3. Run: CREATE EXTENSION pg_stat_statements;")
            return

        # 1. Slowest queries by mean execution time
        print("\n1. SLOWEST QUERIES BY MEAN EXECUTION TIME")
        print("-" * 120)

        slow_query = text(f"""
            SELECT
                LEFT(query, 80) AS query_preview,
                calls,
                ROUND(total_exec_time::numeric, 2) AS total_time_ms,
                ROUND(mean_exec_time::numeric, 2) AS mean_time_ms,
                ROUND(max_exec_time::numeric, 2) AS max_time_ms,
                ROUND((100 * total_exec_time / SUM(total_exec_time) OVER())::numeric, 2) AS pct_total
            FROM pg_stat_statements
            WHERE query NOT LIKE '%pg_stat_statements%'
            ORDER BY mean_exec_time DESC
            LIMIT :limit
        """)

        result = conn.execute(slow_query, {"limit": limit})
        rows = result.fetchall()

        if rows:
            print(f"{'Query Preview':<80} {'Calls':<10} {'Mean':<12} {'Max':<12} {'% Total':<10}")
            print("-" * 120)
            for row in rows:
                query = row[0].replace('\n', ' ')[:80]
                print(f"{query:<80} {row[1]:<10} {format_time(row[3]):<12} {format_time(row[4]):<12} {row[5]:.1f}%")
        else:
            print("No query statistics available yet")

        # 2. Most time-consuming queries (total time)
        print("\n\n2. MOST TIME-CONSUMING QUERIES (by total execution time)")
        print("-" * 120)

        total_time_query = text(f"""
            SELECT
                LEFT(query, 80) AS query_preview,
                calls,
                ROUND(total_exec_time::numeric, 2) AS total_time_ms,
                ROUND(mean_exec_time::numeric, 2) AS mean_time_ms,
                ROUND((100 * total_exec_time / SUM(total_exec_time) OVER())::numeric, 2) AS pct_total
            FROM pg_stat_statements
            WHERE query NOT LIKE '%pg_stat_statements%'
            ORDER BY total_exec_time DESC
            LIMIT :limit
        """)

        result = conn.execute(total_time_query, {"limit": limit})
        rows = result.fetchall()

        if rows:
            print(f"{'Query Preview':<80} {'Calls':<10} {'Total':<12} {'Mean':<12} {'% Total':<10}")
            print("-" * 120)
            for row in rows:
                query = row[0].replace('\n', ' ')[:80]
                print(f"{query:<80} {row[1]:<10} {format_time(row[2]):<12} {format_time(row[3]):<12} {row[4]:.1f}%")

        # 3. Most frequently called queries
        print("\n\n3. MOST FREQUENTLY CALLED QUERIES")
        print("-" * 120)

        frequent_query = text(f"""
            SELECT
                LEFT(query, 80) AS query_preview,
                calls,
                ROUND(total_exec_time::numeric, 2) AS total_time_ms,
                ROUND(mean_exec_time::numeric, 2) AS mean_time_ms
            FROM pg_stat_statements
            WHERE query NOT LIKE '%pg_stat_statements%'
            ORDER BY calls DESC
            LIMIT :limit
        """)

        result = conn.execute(frequent_query, {"limit": limit})
        rows = result.fetchall()

        if rows:
            print(f"{'Query Preview':<80} {'Calls':<10} {'Total':<12} {'Mean':<12}")
            print("-" * 120)
            for row in rows:
                query = row[0].replace('\n', ' ')[:80]
                print(f"{query:<80} {row[1]:<10} {format_time(row[2]):<12} {format_time(row[3]):<12}")

        # 4. Queries with high variability
        print("\n\n4. QUERIES WITH HIGH VARIABILITY (max >> mean)")
        print("-" * 120)

        variance_query = text(f"""
            SELECT
                LEFT(query, 80) AS query_preview,
                calls,
                ROUND(mean_exec_time::numeric, 2) AS mean_time_ms,
                ROUND(max_exec_time::numeric, 2) AS max_time_ms,
                ROUND((max_exec_time / NULLIF(mean_exec_time, 0))::numeric, 2) AS variance_ratio
            FROM pg_stat_statements
            WHERE query NOT LIKE '%pg_stat_statements%'
                AND calls > 10
                AND mean_exec_time > 0
            ORDER BY (max_exec_time / NULLIF(mean_exec_time, 0)) DESC
            LIMIT :limit
        """)

        result = conn.execute(variance_query, {"limit": limit})
        rows = result.fetchall()

        if rows:
            print(f"{'Query Preview':<80} {'Calls':<10} {'Mean':<12} {'Max':<12} {'Ratio':<10}")
            print("-" * 120)
            for row in rows:
                query = row[0].replace('\n', ' ')[:80]
                print(f"{query:<80} {row[1]:<10} {format_time(row[2]):<12} {format_time(row[3]):<12} {row[4]:.1f}x")
            print("\n💡 High variance may indicate inconsistent query plans or data distribution")

        # 5. Summary statistics
        print("\n\n5. OVERALL STATISTICS")
        print("-" * 120)

        summary_query = text("""
            SELECT
                COUNT(*) AS total_queries,
                ROUND(SUM(total_exec_time)::numeric, 2) AS total_time_ms,
                ROUND(AVG(mean_exec_time)::numeric, 2) AS avg_mean_time_ms,
                SUM(calls) AS total_calls
            FROM pg_stat_statements
            WHERE query NOT LIKE '%pg_stat_statements%'
        """)

        result = conn.execute(summary_query)
        row = result.fetchone()

        if row:
            print(f"Total unique queries: {row[0]}")
            print(f"Total execution time: {format_time(row[1])}")
            print(f"Average mean time: {format_time(row[2])}")
            print(f"Total query calls: {row[3]}")

        # Recommendations
        print("\n\n" + "=" * 120)
        print("RECOMMENDATIONS")
        print("=" * 120)
        print("• Focus on queries with high mean execution time and high call count")
        print("• Use EXPLAIN ANALYZE to understand query plans")
        print("• Consider adding indexes for frequently run slow queries")
        print("• Review queries with high variability - they may benefit from plan stability")
        print("• Reset statistics with: SELECT pg_stat_statements_reset();")
        print("\n💡 Set log_min_duration_statement in postgresql.conf to log slow queries to files")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database_url", help="PostgreSQL connection URL")
    parser.add_argument("--limit", type=int, default=10, help="Number of queries to show per category")

    args = parser.parse_args()

    try:
        analyze_queries(args.database_url, args.limit)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
