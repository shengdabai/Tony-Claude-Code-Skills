# Content method

Validate the brief before generation. Read brief and source files through one non-following, non-blocking file descriptor; require a regular file and enforce size while reading that descriptor. Snapshot file-backed source content under `input/source.md`; rewrite the normalized brief to that relative snapshot and its SHA-256 digest. Derive every output evidence ID from the canonical `claim + source_uri` content, then resolve every factual claim through the ledger.

Build the mode-specific structured object first. Derive the shared content specification, typed-block Markdown, escaped standalone HTML, optional renderings, quality report, and run manifest from that structure. User source blocks are CommonMark-neutralized before rendering. Publish the complete file set through one Artifact Bus transaction. The implementation performs no network access and never evaluates source HTML or scripts.

Markdown and HTML article structures use the level-one sections `内容主体` and `补充说明与参考来源`. Facts stay connected to evidence IDs. Useful unsupported advice uses the `guidance` label. Missing sources remain explicit as `unverified`, `source_gap`, or `blocked-by-evidence`.
