# end-of-turn-queue — a Claude Code prompt queue plugin

> Queue prompts with `/queue` that fire **at the end of the turn**, after Claude
> fully finishes — **never mid-task**. A FIFO prompt queue for [Claude Code](https://code.claude.com/docs),
> built on a self-terminating **Stop hook**.

You think of something while Claude is working — "also run the tests", "update the
changelog", "open a PR when you're done". You don't want to interrupt the current
task-loop, and you don't want to forget. `/queue` jots it down; the plugin hands it
back to Claude the moment the current turn finishes, one item at a time, in order.

---

## Why this exists

A Stop hook fires **once per turn, when the main agent has finished** — not between
tool calls, not inside subagents. That's the exact moment you want a deferred prompt
to land. This plugin turns that hook into a FIFO queue:

- **Never mid-loop.** Queued prompts are delivered only at a true turn boundary.
- **One at a time.** Each queued prompt gets its own full turn before the next is
  delivered, so multi-step follow-ups don't trample each other.
- **Self-terminating.** Every Stop fire removes exactly one entry, so the queue
  strictly shrinks and Claude is always eventually allowed to stop. No infinite loop.

---

## Install

### As a marketplace (recommended)

```text
/plugin marketplace add bicced/end-of-turn-queue
/plugin install end-of-turn-queue@bicced
```

Then restart Claude Code (or run `/reload-plugins`) so the Stop hook is registered.

### For local development

```bash
claude --plugin-dir /absolute/path/to/end-of-turn-queue
```

Editing `hooks.json` or `plugin.json` afterwards requires `/reload-plugins` or a
restart to take effect.

---

## Usage

| Command | What it does |
|---|---|
| `/queue <prompt>` | Append a prompt to the end-of-turn queue. |
| `/queue-list` | Show what's currently queued (next-to-deliver first). |
| `/queue-clear` | Empty the queue. |

```text
/queue run the test suite and report failures
/queue update CHANGELOG.md with today's changes
/queue-list
```

Claude confirms each item is queued and keeps working. When it finishes the current
turn, the first queued prompt is delivered as its next instruction; finishing *that*
delivers the next; and so on until the queue drains.

---

## How it works

```
end-of-turn-queue/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (name, keywords, metadata)
│   └── marketplace.json     # self-hosted marketplace so the repo is installable
├── commands/
│   ├── queue.md             # /queue        — append (JSON-encoded) to the queue
│   ├── queue-list.md        # /queue-list   — read-only view of pending prompts
│   └── queue-clear.md       # /queue-clear  — empty the queue
├── hooks/
│   └── hooks.json           # registers the Stop hook -> scripts/queue-flush.sh
└── scripts/
    └── queue-flush.sh       # pops one entry per turn, returns it via decision:block
```

- **Queue file:** `${CLAUDE_PROJECT_DIR}/.claude/prompt-queue`, one entry per line.
  Each line is a **JSON-encoded string**, so prompts containing quotes or newlines
  survive intact. The flush script pops the first line **positionally** (no fragile
  content matching) and writes the rest back atomically.
- **Delivery:** the Stop hook emits `{"decision":"block","reason":"<your prompt>"}`,
  which tells Claude to keep going with that prompt as its next instruction.

---

## Behavior notes (read these)

- **"End of turn" means the next turn boundary, not "all work forever is done."**
  Claude has no signal for "the user's larger goal is complete." A queued prompt is
  delivered the next time Claude finishes a turn — which is usually what you want
  (drain ASAP), but it can be sooner than you imagine.
- **Structured clarifying questions are safe.** The Stop hook does not fire for the
  `AskUserQuestion` tool, so a queued prompt won't hijack a multiple-choice question.
  A plain-text "do you want A or B?" turn *does* end the turn, so a queued item could
  be delivered there — clear the queue (`/queue-clear`) if that's a concern.
- **Keep a single queued prompt on one logical line.** Long multi-line prompts are
  best queued as a short pointer ("do the refactor we discussed"). Avoid unbalanced
  shell quotes in a single `/queue` invocation.
- **Subagents are never touched.** This plugin defines no `SubagentStop` hook, so
  queued prompts never leak into a subagent's context.

---

## Requirements

- [`jq`](https://jqlang.github.io/jq/) on `PATH` (the queue is JSON-encoded and the
  hook emits JSON via `jq`).

---

## Uninstall

```text
/plugin uninstall end-of-turn-queue@bicced
```

Then delete any leftover `.claude/prompt-queue` from projects where you used it.

---

## License

MIT — see [LICENSE](LICENSE).
