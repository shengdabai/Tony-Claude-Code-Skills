# zread `--stdio` protocol

Every zread command accepts `--stdio`, switching the process from an interactive
TUI into a JSON-line machine protocol on stdin/stdout. This is the contract used
by GUI / programmatic clients to drive zread.

## Architecture

zread internally uses a Driver / Client split:

- **Driver** holds all business logic (loading config, calling LLMs, running the
  doc server, managing drafts). It is framework-agnostic and only talks to a
  `Transport`.
- **Client** is either a Bubbletea TUI or `StdioClient`. With `--stdio`, the
  cobra command instantiates `transport.NewLocalTransport()` (a channel pair),
  spawns the driver in a goroutine, then runs `StdioClient.Run(ctx)`.
- `StdioClient` reads JSON lines from `os.Stdin` and forwards them as commands
  to the driver, while encoding `Event`s from the driver to `os.Stdout` (one
  JSON object per line). It returns when an event with `"done": true` is
  received.

Result: stdin = command stream, stdout = event stream, both newline-delimited
JSON. stderr is reserved for logs/errors and should not be parsed.

## Event format (driver → client, stdout)

```json
{
  "vm": { ... },
  "waiting_for": ["..."],
  "done": false,
  "error": ""
}
```

- `vm`: full ViewModel snapshot for the current state (shape varies per command — see below).
- `waiting_for`: command `type` values the client may legally send right now. `quit` is always accepted regardless.
- `done`: `true` on the final event; the process will exit on its own.
- `error`: non-empty when the previous command was rejected; `vm`/`waiting_for` remain unchanged.

Rules:
- An event is emitted after every state transition. Treat `vm` as the full current state (no diffs).
- `waiting_for: []` with `done: false` means the driver is awaiting an internal async result — do not send any command; just keep reading.
- The very last event always has `done: true` and an empty `waiting_for`.

## Command format (client → driver, stdin)

One JSON object per line:

```json
{"type": "<command_type>", "params": { ... }}
```

- `type` is required. `params` may be omitted (treated as `{}`).
- Universal command: `{"type":"quit","params":{}}` — every driver handles it and shuts down cleanly.
- Command types prefixed with `_` are driver-internal. They never appear in `waiting_for`; clients must not send them.
- Sending a command not in `waiting_for` returns an event with `error` set while `vm`/`waiting_for` remain unchanged.
- Error message format: `"command \"xxx\" not allowed in state yyy"` / `"invalid params: ..."` / `"invalid JSON: ..."`.

## Driving a session

1. Spawn `zread <command> --stdio` with piped stdin/stdout.
2. Read the first event — it carries the initial ViewModel and `waiting_for`.
3. Render or inspect `vm`; pick a legal command from `waiting_for` and write it as a single JSON line followed by `\n`.
4. Loop: read next event, react, write next command.
5. Stop when `done: true` arrives. The process will exit on its own. Sending `quit` at any time triggers the same shutdown.

---

## `zread browse --stdio`

### ViewModel fields

| Field | Type | Notes |
|---|---|---|
| `state` | string | `"loading"` `"serving"` `"select_version"` `"no_wiki"` `"error"` |
| `url` | string | Local server URL; present when `state="serving"` |
| `browser_opened` | bool | Whether the browser was auto-launched |
| `has_current` | bool | Whether a "current" wiki version exists |
| `versions` | array | Present when `state="select_version"` |
| `versions[].id` | string | Wiki version ID |
| `versions[].timestamp` | string | Version timestamp |
| `versions[].is_current` | bool | Whether this is the current version |
| `error` | string | Present when `state="error"` |

### Commands

| State | `waiting_for` | Command | Params |
|---|---|---|---|
| `select_version` | `["select_version","quit"]` | `select_version` | `{"wiki_id":"<id>"}` or `{"current":true}` |
| `serving` | `["quit"]` | — | — |
| `no_wiki` | `["quit"]` | — | — |
| `loading` | `[]` | *(wait for internal event)* | — |
| `error` | `[]` | — | — |

### State machine

```
loading ──(server ok)──────────────────► serving
loading ──(error)──────────────────────► error (terminal)
select_version ──(select_version cmd)──► loading ──► serving
no_wiki ───────────────────────────────► (terminal, done=true)
```

---

## `zread generate --stdio`

### ViewModel fields

| Field | Type | Notes |
|---|---|---|
| `state` | string | `"select_action"` `"running"` `"done"` `"error"` |
| `max_retries` | int | Configured max retries per page |
| `select_action.scenario` | string | `"has_wiki"` `"has_draft"` `"empty"` |
| `select_action.wiki_date` | string | Date of existing wiki (when `scenario="has_wiki"`) |
| `select_action.draft_done` | int | Pages already done in draft |
| `select_action.draft_total` | int | Total pages in draft |
| `select_action.next_action` | string | Pre-suggested action: `"generate"` `"browse"` `""` |
| `catalog.status` | string | `"idle"` `"running"` `"done"` `"resumed"` `"error"` |
| `catalog.tool_name` | string | Currently-running LLM tool (if any) |
| `catalog.error` | string | Catalog error message |
| `catalog.auto_retry` | int | Auto-retry count so far |
| `pages.tasks` | array | Per-page task list |
| `pages.tasks[].id` | int | Task ID (used for `retry` command) |
| `pages.tasks[].title` | string | Page title |
| `pages.tasks[].slug` | string | Page slug |
| `pages.tasks[].state` | string | `"pending"` `"running"` `"retry_pending"` `"done"` `"failed"` `"resumed"` |
| `pages.tasks[].retry_count` | int | Retries attempted so far |
| `pages.tasks[].max_retries` | int | Retry limit for this task |
| `pages.tasks[].error` | string | Error message if failed |
| `pages.done` | int | Completed page count |
| `pages.total` | int | Total page count |
| `pages.waiting_retry` | bool | `true` when driver is paused waiting for retry/skip decision |
| `done_total` | int | Total pages done (in `state="done"`) |
| `error` | string | Fatal error message |

### Commands

| State / condition | `waiting_for` | Command | Params |
|---|---|---|---|
| `select_action` | `["select_action","cancel","quit"]` | `select_action` | `{"action":"generate"}` or `"browse"` or `"resume"` or `"clear"` or `"cancel"` |
| `running` (normal) | `["quit"]` | — | — |
| `running` (catalog error) | `["quit","retry_catalog"]` | `retry_catalog` | `{}` |
| `running` (pages waiting retry) | `["quit","retry","skip_all"]` | `retry` | `{"task_id":<int>}` |
| `running` (pages waiting retry) | `["quit","retry","skip_all"]` | `skip_all` | `{}` |
| `running` | `["quit","cancel"]` | `cancel` | `{}` |

### CLI flags that affect stdio flow

- `--yes` / `-y`: skips the `select_action` gate; generation starts immediately.
- `--draft-action <resume|clear|cancel>`: pre-answers the draft prompt.
- `--skip-failed`: equivalent to auto-sending `skip_all` when pages fail.

### State machine

```
select_action ──(generate/resume)──► running ──(all done, no failures)──► done
select_action ──(cancel/browse)────► done (immediate)
running ──(pages failed)───────────► waiting_retry=true, accepts retry/skip_all
running ──(cancel)─────────────────► done
```

---

## `zread config --stdio`

### ViewModel fields

| Field | Type | Notes |
|---|---|---|
| `fields` | array (9 items) | Ordered config fields |
| `fields[].title_key` | string | Display label key |
| `fields[].json_key` | string | Key to use in `update_fields`; empty = read-only |
| `fields[].initial` | string | Value at load time |
| `fields[].value` | string | Current (possibly edited) value |
| `dirty` | bool | `true` if any field differs from `initial` |
| `saved` | bool | `true` after successful save |
| `error` | string | Validation error |

Field index → `json_key` mapping:

| Index | `json_key` | Notes |
|---|---|---|
| 0 | `language` | generation language |
| 1 | `doc_language` | doc language |
| 2 | *(empty)* | read-only LLM provider display |
| 3 | `max_concurrent` | int |
| 4 | `max_retries` | int |
| 5 | `llm_provider` | editable in stdio mode |
| 6 | `llm_base_url` | editable in stdio mode |
| 7 | `llm_model` | editable in stdio mode |
| 8 | `llm_api_key` | editable in stdio mode |

### Commands

No state machine. Fixed `waiting_for`: `["update_fields","save","reload_llm","quit"]`.

| Command | Params | Effect |
|---|---|---|
| `update_fields` | `{"fields":{"<json_key>": "<value>", ...}}` | Partial update; only listed keys change |
| `save` | `{}` | Persists config and terminates (`done=true`) |
| `reload_llm` | `{}` | Re-validates LLM provider settings |
| `quit` | `{}` | Exits without saving |

---

## `zread login --stdio`

### ViewModel fields

| Field | Type | Notes |
|---|---|---|
| `state` | string | See states below |
| `authorize_url` | string | OAuth URL to open; present in `open_browser` state |
| `auth_timeout` | int | Nanoseconds until auth expires; present in `waiting` state |
| `browser_warn` | string | Warning if browser launch failed |
| `username` | string | Logged-in username; present in `done` state |
| `avail_models` | array of string | Models to choose from; present in `select_model` state |
| `selected_model` | string | Currently selected model |
| `error` | string | Error message in `error` state |
| `wants_llm_provider_editor` | bool | `true` (with `done=true`) when `--custom` flag was used |

States: `"select_region"` → `"init_flow"` → `"open_browser"` → `"waiting"` → `"select_model"` → `"saving"` → `"done"` / `"error"`

### Commands

| State | `waiting_for` | Command | Params |
|---|---|---|---|
| `select_region` | `["select_region","quit"]` | `select_region` | `{"region":"<provider_key>"}` or `{"region":"__use_own_key__"}` |
| `select_model` | `["select_model","quit"]` | `select_model` | `{"model":"<model_id>"}` |
| all others | `[]` | *(wait for internal auth events)* | — |

### Special cases

- `--custom` flag: driver immediately emits `done: true` with `wants_llm_provider_editor: true`. Client should then launch `zread config --stdio` to configure a custom LLM provider.

### State machine

```
select_region ──(cmd)──► init_flow ──► open_browser ──► waiting ──► select_model
select_model ──(cmd)───► saving ──► done
any ────────────────────────────────────────────────────────────────► error
```

---

## `zread update --stdio`

### ViewModel fields

| Field | Type | Notes |
|---|---|---|
| `state` | string | See states below |
| `current_version` | string | Installed version |
| `latest_version` | string | Available version; present in `has_update`+ |
| `download_url` | string | Asset URL for the update binary |
| `package_manager` | string | e.g. `"brew"`; present in `package_manager` state |
| `downloaded_bytes` | int | Bytes downloaded so far |
| `total_bytes` | int | Total download size |
| `download_percent` | float | 0–100 |
| `error` | string | Error message in `error` state |

States: `"checking"` → `"up_to_date"` / `"package_manager"` / `"has_update"` → `"downloading"` → `"confirm_restart"` / `"error"`

Terminal states (emit `done=true`): `up_to_date`, `package_manager`, `error`, and after restart/skip.

### Commands

| State | `waiting_for` | Command | Params |
|---|---|---|---|
| `has_update` | `["download","quit"]` | `download` | `{}` |
| `confirm_restart` | `["restart","skip_restart","quit"]` | `restart` | `{}` |
| `confirm_restart` | `["restart","skip_restart","quit"]` | `skip_restart` | `{}` |
| all others | `[]` | *(wait for internal events)* | — |

### State machine

```
checking ──► up_to_date (terminal)
         ──► package_manager (terminal)
         ──► has_update ──(download)──► downloading ──► confirm_restart
                                                     ──(restart/skip)──► done
checking / downloading ──(error)──► error (terminal)
```

---

## `zread version --stdio`

Emits a single event with `done: true` immediately. No commands are accepted.

### ViewModel fields

| Field | Type | Notes |
|---|---|---|
| `version` | string | e.g. `"1.2.3"` |
| `channel` | string | Release channel (if set) |
| `go_version` | string | Go runtime version |
| `os` | string | OS name |
| `arch` | string | CPU architecture |

---

## Practical tips

- Always flush stdin after writing a command (the driver reads line-by-line).
- Treat any line on stdout that fails to parse as JSON as a bug — log it but do not crash; zread should not print non-JSON to stdout in `--stdio` mode.
- When `waiting_for` is `[]` and `done` is `false`, keep reading — the driver is awaiting an internal async result and will emit the next event on its own.
- For long-running commands (`generate`), keep reading events continuously; there is no heartbeat, but progress events arrive whenever state changes.
- To cancel cleanly, send `{"type":"quit","params":{}}` and then drain events until `done` rather than killing the process.
- `done: true` events are always terminal. Do not send further commands.
