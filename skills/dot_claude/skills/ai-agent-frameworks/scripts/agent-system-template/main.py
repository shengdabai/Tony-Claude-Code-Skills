#!/usr/bin/env python3
"""
Agent System Template - Example Usage

This demonstrates a simple multi-agent workflow.
Customize agents, tools, and workflows for your use case.
"""

import os
import yaml
import logging
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def load_config():
    """Load configuration from config.yaml"""
    with open("config.yaml") as f:
        return yaml.safe_load(f)


def main():
    """Main entry point"""
    logger.info("Starting agent system...")

    # Load configuration
    config = load_config()

    # Verify API key
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        logger.error("OPENAI_API_KEY not set in environment")
        return

    logger.info("Configuration loaded successfully")
    logger.info(f"Available agents: {list(config['agents'].keys())}")

    # TODO: Implement your workflow here
    # Example:
    # 1. Initialize agents from config
    # 2. Define workflow orchestration
    # 3. Execute workflow
    # 4. Track costs and performance

    logger.info("Agent system completed")


if __name__ == "__main__":
    main()
