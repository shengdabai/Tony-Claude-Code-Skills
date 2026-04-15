---
name: twitter
description: |
  Launch the X/Twitter Poster Agent to auto-create and publish tweets.
  Use when: user types /twitter, /x, wants to post tweets, create threads,
  write X content, or manage Twitter posts.
  Keywords: twitter, x, tweet, thread, 推文, 发推, 推特
---

# X/Twitter Poster Agent

Auto-create and publish tweets and threads to X/Twitter.

## What it does
1. Takes a topic/direction from the user
2. Generates tweet content (single tweet or thread)
3. Saves draft for review
4. Posts to X/Twitter via API v2

## How to launch

Run the agent in the terminal:

```bash
cd ~/x-poster && python3 x-poster.py
```

Then interact:
```
x-post >> 写一条关于AI agent发展趋势的推文
x-post >> 写一个5条的thread，主题是为什么每个开发者都应该学AI
x-post >> 查看我最近发布的推文
```

## Quick mode (non-interactive)

```bash
cd ~/x-poster && python3 -c "
from dotenv import load_dotenv; load_dotenv(override=True)
exec(open('x-poster.py').read().split('if __name__')[0])
history = [{'role': 'user', 'content': 'YOUR_TOPIC_HERE'}]
agent_loop(history)
"
```

## Available tools in the agent
- `bash` — shell commands
- `read_file` / `write_file` — file/draft operations
- `post_tweet` — publish a single tweet (max 280 chars)
- `post_thread` — publish a thread (auto-chained replies)
- `get_my_tweets` — fetch recent tweets with engagement metrics

## Writing guidelines (built into agent)
- Concise and punchy, under 280 chars per tweet
- Thread hook: first tweet grabs attention
- 2-3 hashtags, tasteful emoji use
- End with CTA (call to action)
- Agent always shows draft before posting

## Configuration
- LLM API: `~/x-poster/.env` (Kimi/Anthropic compatible)
- X API: `~/x-poster/.env` (API Key + Access Token with Read/Write)
- Drafts: `~/x-poster/drafts/`
- Post history: `~/x-poster/post_history.jsonl`
