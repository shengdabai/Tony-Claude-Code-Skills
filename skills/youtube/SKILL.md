---
name: youtube
description: |
  Launch the YouTube Creator Agent to auto-generate videos.
  Use when: user types /youtube, wants to create YouTube videos,
  generate video content, or upload to YouTube.
  Keywords: youtube, video, 视频, 创作视频, 发布视频
---

# YouTube Creator Agent

Auto-generate and upload YouTube videos from a topic.

## What it does
1. Takes a topic/idea from the user
2. Generates a video script (title, description, narration segments)
3. Creates TTS voiceover with edge-tts
4. Composes video with ffmpeg (background + subtitles + narration)
5. Uploads to YouTube via Data API v3

## How to launch

Run the agent in the terminal:

```bash
cd ~/youtube-creator && PATH="$PATH:$HOME/Library/Python/3.9/bin" python3 youtube-creator.py
```

Then interact:
```
youtube >> 做一个3分钟的视频，主题是"如何用AI提升工作效率"
```

## Quick mode (non-interactive)

To generate a video without entering interactive mode, use bash:

```bash
cd ~/youtube-creator && PATH="$PATH:$HOME/Library/Python/3.9/bin" python3 -c "
from dotenv import load_dotenv; load_dotenv(override=True)
import os; os.environ['PATH'] += ':/Users/adam/Library/Python/3.9/bin'
exec(open('youtube-creator.py').read().split('if __name__')[0])
history = [{'role': 'user', 'content': 'YOUR_TOPIC_HERE'}]
agent_loop(history)
"
```

## Available tools in the agent
- `bash` — shell commands
- `read_file` / `write_file` — file operations
- `generate_assets` — TTS voiceover + SRT subtitles + background image
- `compose_video` — ffmpeg video composition
- `upload_youtube` — YouTube Data API v3 upload (OAuth required)

## Configuration
- LLM API: `~/youtube-creator/.env` (Kimi/Anthropic compatible)
- YouTube OAuth: `~/youtube-creator/.env` (Client ID + Secret)
- Output directory: `~/youtube-creator/output/`

## First-time YouTube upload
First upload will open a browser window for Google OAuth authorization.
After that, the token is cached in `youtube_token.json`.
