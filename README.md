# end-of-turn-queue — a Claude Code prompt queue plugin

> Queue prompts with `/queue:add` that fire **at the end of the turn**, after Claude
> fully finishes — **never mid-task**. A FIFO prompt queue for [Claude Code](https://code.claude.com/docs),
> built on a self-terminating **Stop hook**.

You think of something while Claude is working — "also run the tests", "update the
changelog", "open a PR when you're done". You don't want to interrupt the current
task-loop, and you don't want to forget. `/queue:add` jots it down; the plugin hands it
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
/plugin install queue@bicced
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
| `/queue:add <prompt>` | Append a prompt to the end-of-turn queue. |
| `/queue:list` | Show what's currently queued (next-to-deliver first). |
| `/queue:clear` | Empty the queue. |

```text
/queue:add run the test suite and report failures
/queue:add update CHANGELOG.md with today's changes
/queue:list
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
│   ├── add.md               # /queue:add    — append (JSON-encoded) to the queue
│   ├── list.md              # /queue:list   — read-only view of pending prompts
│   └── clear.md             # /queue:clear  — empty the queue
├── hooks/
│   └── hooks.json           # registers the Stop hook -> scripts/queue-flush.sh
└── scripts/
    └── queue-flush.sh       # pops one entry per turn, returns it via decision:block
```

- **Queue file:** `${CLAUDE_PROJECT_DIR}/.claude/prompt-queue`, one entry per line.
  `/queue:add` JSON-encodes the prompt with `jq` so it is stored as one line and the
  flush side can decode it losslessly (see the input caveat under Behavior notes).
- **Pop:** the flush script removes the first non-blank line **positionally** (no
  fragile content matching), builds the response **before** removing the entry, and
  swaps the file with an atomic rename — so any failure leaves the queue intact and
  never drops a prompt.
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
  be delivered there — clear the queue (`/queue:clear`) if that's a concern.
- **Keep a queued prompt to one line, and avoid shell metacharacters in it.**
  Claude Code substitutes a command's `$ARGUMENTS` into the shell *without escaping*
  (a known Claude Code limitation, [issue #16163](https://github.com/anthropics/claude-code/issues/16163)),
  and that applies to every slash command — not just this one. In practice: a prompt
  with a double quote may fail to queue, and you should **never pipe untrusted text
  into `/queue:add`** (text containing `$(...)` or backticks could execute at queue time).
  Plain one-line reminders are exactly what this is for. For something elaborate,
  queue a short pointer ("do the refactor we discussed").
- **Very long queues.** Claude Code has a safety limit on consecutive Stop-hook
  continuations (it stops honoring a hook that keeps blocking without progress). Each
  delivered prompt is real work, which normally counts as progress, so queues drain —
  but if you stack many trivial items that produce no work, the tail may not all
  deliver in one chain. Queue handfuls, not hundreds.
- **Subagents are never touched.** This plugin defines no `SubagentStop` hook, so
  queued prompts never leak into a subagent's context.

---

## Requirements

- [`jq`](https://jqlang.github.io/jq/) on `PATH` (the queue is JSON-encoded and the
  hook emits JSON via `jq`).

---

## Uninstall

```text
/plugin uninstall queue@bicced
```

Then delete any leftover `.claude/prompt-queue` from projects where you used it.

---

## License

MIT — see [LICENSE](LICENSE).
