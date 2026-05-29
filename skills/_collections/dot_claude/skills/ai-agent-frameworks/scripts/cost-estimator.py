#!/usr/bin/env python3
"""
Multi-Agent Cost Estimator

Estimates token usage and costs for multi-agent workflows.
Helps budget and optimize agent systems before deployment.
"""

import argparse
import json
from typing import List, Dict
from dataclasses import dataclass


# Pricing per 1K tokens (as of 2024)
PRICING = {
    "gpt-4": {"prompt": 0.03, "completion": 0.06},
    "gpt-4-turbo": {"prompt": 0.01, "completion": 0.03},
    "gpt-3.5-turbo": {"prompt": 0.0015, "completion": 0.002},
    "claude-3-opus": {"prompt": 0.015, "completion": 0.075},
    "claude-3-sonnet": {"prompt": 0.003, "completion": 0.015},
    "claude-3-haiku": {"prompt": 0.00025, "completion": 0.00125}
}


@dataclass
class AgentEstimate:
    """Cost estimate for a single agent"""
    name: str
    model: str
    avg_prompt_tokens: int
    avg_completion_tokens: int
    iterations: int = 1

    @property
    def total_tokens(self) -> int:
        return (self.avg_prompt_tokens + self.avg_completion_tokens) * self.iterations

    @property
    def cost(self) -> float:
        if self.model not in PRICING:
            return 0.0

        pricing = PRICING[self.model]
        prompt_cost = (self.avg_prompt_tokens * self.iterations / 1000) * pricing["prompt"]
        completion_cost = (self.avg_completion_tokens * self.iterations / 1000) * pricing["completion"]

        return prompt_cost + completion_cost


class WorkflowEstimator:
    """Estimate costs for multi-agent workflows"""

    def __init__(self):
        self.agents: List[AgentEstimate] = []

    def add_agent(
        self,
        name: str,
        model: str,
        avg_prompt_tokens: int,
        avg_completion_tokens: int,
        iterations: int = 1
    ):
        """Add an agent to the workflow"""
        agent = AgentEstimate(
            name=name,
            model=model,
            avg_prompt_tokens=avg_prompt_tokens,
            avg_completion_tokens=avg_completion_tokens,
            iterations=iterations
        )
        self.agents.append(agent)

    def estimate(self, num_requests: int = 1) -> Dict:
        """Calculate total cost estimate"""
        total_cost = sum(agent.cost for agent in self.agents) * num_requests
        total_tokens = sum(agent.total_tokens for agent in self.agents) * num_requests

        breakdown = [
            {
                "agent": agent.name,
                "model": agent.model,
                "tokens": agent.total_tokens,
                "cost": round(agent.cost, 4),
                "iterations": agent.iterations
            }
            for agent in self.agents
        ]

        return {
            "total_cost": round(total_cost, 4),
            "total_tokens": total_tokens,
            "num_requests": num_requests,
            "cost_per_request": round(total_cost / num_requests, 4) if num_requests > 0 else 0,
            "breakdown": breakdown
        }

    def optimize_recommendations(self) -> List[str]:
        """Suggest cost optimizations"""
        recommendations = []

        # Check for expensive models
        for agent in self.agents:
            if agent.model == "gpt-4" and agent.iterations > 3:
                recommendations.append(
                    f"Consider using gpt-4-turbo for '{agent.name}' "
                    f"(3.3x cheaper, similar quality)"
                )

            if agent.model in ["gpt-4", "claude-3-opus"] and agent.avg_completion_tokens > 1000:
                recommendations.append(
                    f"'{agent.name}' generates long outputs. "
                    f"Consider limiting max_tokens or using cheaper model for initial draft."
                )

        # Check for redundant agents
        model_counts = {}
        for agent in self.agents:
            model_counts[agent.model] = model_counts.get(agent.model, 0) + 1

        if model_counts.get("gpt-4", 0) > 3:
            recommendations.append(
                "Multiple GPT-4 agents detected. Consider consolidating or "
                "using cheaper models (GPT-3.5) for simpler agents."
            )

        # Check total cost
        total_cost = sum(agent.cost for agent in self.agents)
        if total_cost > 1.0:
            recommendations.append(
                f"High per-workflow cost (${total_cost:.2f}). "
                f"Consider caching, batching, or reducing iterations."
            )

        return recommendations


def main():
    parser = argparse.ArgumentParser(description="Estimate multi-agent workflow costs")
    parser.add_argument("--config", help="JSON config file with agent definitions")
    parser.add_argument("--requests", type=int, default=1, help="Number of requests to estimate")
    parser.add_argument("--optimize", action="store_true", help="Show optimization recommendations")

    args = parser.parse_args()

    estimator = WorkflowEstimator()

    if args.config:
        # Load from config file
        with open(args.config) as f:
            config = json.load(f)

        for agent_config in config.get("agents", []):
            estimator.add_agent(**agent_config)

    else:
        # Interactive mode
        print("=== Multi-Agent Cost Estimator ===\n")
        print("Available models:", ", ".join(PRICING.keys()))
        print()

        while True:
            name = input("Agent name (or 'done' to finish): ").strip()
            if name.lower() == "done":
                break

            model = input("Model: ").strip()
            if model not in PRICING:
                print(f"Warning: Unknown model '{model}', cost will be $0")

            avg_prompt = int(input("Avg prompt tokens: "))
            avg_completion = int(input("Avg completion tokens: "))
            iterations = int(input("Iterations per agent (default 1): ") or "1")

            estimator.add_agent(name, model, avg_prompt, avg_completion, iterations)
            print()

    # Calculate estimate
    estimate = estimator.estimate(num_requests=args.requests)

    # Display results
    print("\n=== Cost Estimate ===")
    print(f"Total Cost: ${estimate['total_cost']:.4f}")
    print(f"Total Tokens: {estimate['total_tokens']:,}")
    print(f"Cost per Request: ${estimate['cost_per_request']:.4f}")
    print(f"\nFor {estimate['num_requests']:,} requests\n")

    print("=== Per-Agent Breakdown ===")
    for item in estimate["breakdown"]:
        print(f"{item['agent']:20} | {item['model']:15} | "
              f"{item['tokens']:8,} tokens | ${item['cost']:.4f} | "
              f"{item['iterations']} iteration(s)")

    # Optimization recommendations
    if args.optimize:
        recommendations = estimator.optimize_recommendations()
        if recommendations:
            print("\n=== Optimization Recommendations ===")
            for i, rec in enumerate(recommendations, 1):
                print(f"{i}. {rec}")
        else:
            print("\n=== No optimization recommendations ===")


if __name__ == "__main__":
    main()
