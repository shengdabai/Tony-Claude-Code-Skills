# Portable prompt

Use this with an AI client that has the GetNote MCP tools but does not auto-discover local skills:

> 执行 `~/.agents/skills/youtube-script-sync/SKILL.md` 的完整流程，同步 GetNote 知识库 `Youtube视频逐字稿`（topic_id=`YkWaVRqY`）。先 dry-run，再顺序写入；每条符合条件的父录音笔记只能对应一个 `YT逐字稿` 子笔记。每个子笔记必须使用 `youtube-script-sync/v2`，同时生成可独立直接录制的完整中文逐字稿和完整英文逐字稿；英文按英语 YouTube 观众重新组织，不是直译或字幕摘要。长视频另附两条中英双语 Shorts。生成前读取 editorial/voice reference；写后回读父子关系、做 missing/duplicate 集合核验，并再次 dry-run 证明幂等。不要覆盖原笔记，不要保证流量，不要把第三方录音改写成 Tony 的第一人称。

Natural-language triggers for clients that support Agent Skills:

- `同步 Youtube视频逐字稿知识库`
- `更新 Youtube 视频逐字稿`
- `优化该知识库的全部逐字稿`（only when the active context is this knowledge base）
