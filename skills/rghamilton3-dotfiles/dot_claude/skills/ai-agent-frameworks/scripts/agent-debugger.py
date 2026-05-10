#!/usr/bin/env python3
"""
Agent Debugger

Analyze agent execution traces to identify bottlenecks, loops, and errors.
Visualizes agent workflows for better understanding.
"""

import argparse
import json
from datetime import datetime
from typing import List, Dict, Optional
from collections import defaultdict, Counter


class TraceAnalyzer:
    """Analyze agent execution traces"""

    def __init__(self, trace_file: str):
        with open(trace_file) as f:
            self.trace = json.load(f)

        self.spans = self.trace.get("spans", [])
        self.workflow = self.trace.get("workflow", "unknown")

    def summary(self) -> Dict:
        """Generate summary statistics"""
        total_duration = self._calculate_total_duration()

        return {
            "workflow": self.workflow,
            "total_spans": len(self.spans),
            "total_duration": total_duration,
            "status": self._overall_status(),
            "error_count": sum(1 for s in self.spans if s.get("status") == "error")
        }

    def _calculate_total_duration(self) -> float:
        """Calculate total workflow duration"""
        if not self.spans:
            return 0.0

        start_times = [
            datetime.fromisoformat(s["start_time"])
            for s in self.spans if "start_time" in s
        ]

        end_times = [
            datetime.fromisoformat(s["end_time"])
            for s in self.spans if "end_time" in s
        ]

        if not start_times or not end_times:
            return 0.0

        duration = (max(end_times) - min(start_times)).total_seconds()
        return round(duration, 2)

    def _overall_status(self) -> str:
        """Determine overall workflow status"""
        statuses = [s.get("status") for s in self.spans]

        if "error" in statuses:
            return "error"
        elif all(s == "success" for s in statuses):
            return "success"
        else:
            return "partial"

    def detect_loops(self) -> List[Dict]:
        """Detect repeated agent actions (potential loops)"""
        loops = []
        action_sequence = [s.get("name") for s in self.spans]

        # Look for repeated sequences
        for window_size in range(2, 6):  # Check for loops of 2-5 steps
            for i in range(len(action_sequence) - window_size * 2):
                window = action_sequence[i:i + window_size]
                next_window = action_sequence[i + window_size:i + window_size * 2]

                if window == next_window:
                    loops.append({
                        "pattern": " → ".join(window),
                        "start_index": i,
                        "repetitions": 2,
                        "severity": "warning"
                    })

        return loops

    def identify_bottlenecks(self, threshold: float = 5.0) -> List[Dict]:
        """Find slow operations"""
        bottlenecks = []

        for span in self.spans:
            if "start_time" in span and "end_time" in span:
                start = datetime.fromisoformat(span["start_time"])
                end = datetime.fromisoformat(span["end_time"])
                duration = (end - start).total_seconds()

                if duration > threshold:
                    bottlenecks.append({
                        "span": span["name"],
                        "duration": round(duration, 2),
                        "metadata": span.get("metadata", {})
                    })

        # Sort by duration
        bottlenecks.sort(key=lambda x: x["duration"], reverse=True)

        return bottlenecks

    def error_analysis(self) -> List[Dict]:
        """Analyze errors in the trace"""
        errors = []

        for span in self.spans:
            if span.get("status") == "error":
                errors.append({
                    "span": span["name"],
                    "error": span.get("error", "Unknown error"),
                    "metadata": span.get("metadata", {})
                })

        return errors

    def agent_usage(self) -> Dict[str, int]:
        """Count agent invocations"""
        agent_counts = Counter()

        for span in self.spans:
            agent = span.get("metadata", {}).get("agent")
            if agent:
                agent_counts[agent] += 1

        return dict(agent_counts)

    def visualize_timeline(self) -> str:
        """Generate ASCII timeline visualization"""
        if not self.spans:
            return "No spans to visualize"

        lines = []
        lines.append("\n=== Execution Timeline ===\n")

        for i, span in enumerate(self.spans):
            status_icon = {
                "success": "✓",
                "error": "✗",
                "running": "○"
            }.get(span.get("status"), "?")

            # Calculate duration if available
            duration = ""
            if "start_time" in span and "end_time" in span:
                start = datetime.fromisoformat(span["start_time"])
                end = datetime.fromisoformat(span["end_time"])
                duration = f" ({(end - start).total_seconds():.2f}s)"

            agent = span.get("metadata", {}).get("agent", "unknown")

            lines.append(f"{i+1:2}. {status_icon} [{agent:12}] {span['name']}{duration}")

        return "\n".join(lines)

    def recommendations(self) -> List[str]:
        """Generate optimization recommendations"""
        recommendations = []

        # Check for loops
        loops = self.detect_loops()
        if loops:
            recommendations.append(
                f"⚠️  Detected {len(loops)} potential loop(s). "
                "Review agent logic to prevent infinite loops."
            )

        # Check for bottlenecks
        bottlenecks = self.identify_bottlenecks(threshold=5.0)
        if bottlenecks:
            slowest = bottlenecks[0]
            recommendations.append(
                f"🐌 Bottleneck detected: '{slowest['span']}' took {slowest['duration']}s. "
                "Consider caching or optimization."
            )

        # Check for errors
        errors = self.error_analysis()
        if errors:
            recommendations.append(
                f"❌ {len(errors)} error(s) detected. "
                "Implement proper error handling and retries."
            )

        # Check agent distribution
        agent_usage = self.agent_usage()
        if agent_usage:
            max_agent = max(agent_usage, key=agent_usage.get)
            if agent_usage[max_agent] > len(self.spans) * 0.5:
                recommendations.append(
                    f"📊 Agent '{max_agent}' handles {agent_usage[max_agent]} of {len(self.spans)} spans. "
                    "Consider splitting responsibilities."
                )

        # Check total duration
        total_duration = self._calculate_total_duration()
        if total_duration > 60:
            recommendations.append(
                f"⏱️  Long execution time ({total_duration}s). "
                "Consider parallel execution or async patterns."
            )

        if not recommendations:
            recommendations.append("✅ No major issues detected.")

        return recommendations


def main():
    parser = argparse.ArgumentParser(description="Debug agent execution traces")
    parser.add_argument("trace_file", help="Path to trace JSON file")
    parser.add_argument("--summary", action="store_true", help="Show summary only")
    parser.add_argument("--loops", action="store_true", help="Detect loops")
    parser.add_argument("--bottlenecks", action="store_true", help="Identify bottlenecks")
    parser.add_argument("--errors", action="store_true", help="Show errors")
    parser.add_argument("--timeline", action="store_true", help="Visualize timeline")
    parser.add_argument("--all", action="store_true", help="Show all analysis")

    args = parser.parse_args()

    try:
        analyzer = TraceAnalyzer(args.trace_file)

        # If no specific flags, show all
        show_all = args.all or not any([
            args.summary, args.loops, args.bottlenecks,
            args.errors, args.timeline
        ])

        # Summary
        if args.summary or show_all:
            summary = analyzer.summary()
            print("\n=== Workflow Summary ===")
            print(f"Workflow: {summary['workflow']}")
            print(f"Status: {summary['status']}")
            print(f"Total Spans: {summary['total_spans']}")
            print(f"Duration: {summary['total_duration']}s")
            print(f"Errors: {summary['error_count']}")

        # Timeline visualization
        if args.timeline or show_all:
            print(analyzer.visualize_timeline())

        # Loop detection
        if args.loops or show_all:
            loops = analyzer.detect_loops()
            if loops:
                print("\n=== Detected Loops ===")
                for loop in loops:
                    print(f"Pattern: {loop['pattern']}")
                    print(f"  Starting at span {loop['start_index']}")
                    print()

        # Bottleneck analysis
        if args.bottlenecks or show_all:
            bottlenecks = analyzer.identify_bottlenecks()
            if bottlenecks:
                print("\n=== Bottlenecks (>5s) ===")
                for bn in bottlenecks:
                    print(f"{bn['span']:30} {bn['duration']:8.2f}s")

        # Error analysis
        if args.errors or show_all:
            errors = analyzer.error_analysis()
            if errors:
                print("\n=== Errors ===")
                for error in errors:
                    print(f"Span: {error['span']}")
                    print(f"Error: {error['error']}")
                    print()

        # Agent usage
        if show_all:
            agent_usage = analyzer.agent_usage()
            if agent_usage:
                print("\n=== Agent Usage ===")
                for agent, count in sorted(
                    agent_usage.items(),
                    key=lambda x: x[1],
                    reverse=True
                ):
                    print(f"{agent:20} {count:5} invocations")

        # Recommendations
        if show_all:
            recommendations = analyzer.recommendations()
            print("\n=== Recommendations ===")
            for rec in recommendations:
                print(f"  {rec}")

    except FileNotFoundError:
        print(f"Error: Trace file '{args.trace_file}' not found")
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in '{args.trace_file}'")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    main()
