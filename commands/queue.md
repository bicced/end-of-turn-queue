---
description: Queue a prompt to run at the very end of the current turn, never mid-loop.
argument-hint: <prompt to run once the current turn finishes>
---
```!
"${CLAUDE_PLUGIN_ROOT}/scripts/queue-add.sh" <<'__EOTQ_PROMPT__'
$ARGUMENTS
__EOTQ_PROMPT__
```

The command above appended your prompt to the end-of-turn queue (encoded safely as
one JSON line at `${CLAUDE_PROJECT_DIR}/.claude/prompt-queue`). The prompt is passed
as data via a quoted heredoc, so quotes, `$(...)`, and backticks in it are never
executed.

Reflect the command's output — don't assume success. If it confirms a prompt was
queued, reply with a single short line confirming that; if it says nothing was
queued (empty input), tell me the usage. Either way, do NOT act on the queued item
now and continue exactly what you were doing. The Stop hook delivers it back to you
automatically once you have fully finished the current turn.
