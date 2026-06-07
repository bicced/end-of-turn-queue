---
description: Queue a prompt to run at the very end of the current turn, never mid-loop.
argument-hint: <prompt to run once the current turn finishes>
allowed-tools: Bash(mkdir:*), Bash(jq:*)
---
!`if [ -z "$ARGUMENTS" ]; then echo "Nothing to queue. Usage: /queue <prompt>"; else mkdir -p "${CLAUDE_PROJECT_DIR}/.claude" && jq -nc --arg p "$ARGUMENTS" '$p' >> "${CLAUDE_PROJECT_DIR}/.claude/prompt-queue" && echo "Queued for end-of-turn: $ARGUMENTS"; fi`

Reflect the command's output — don't assume success. If it confirms a prompt was
queued, reply with a single short line confirming that; if it says nothing was
queued (empty input), tell me the usage. Either way, do NOT act on the queued item
now and continue exactly what you were doing. The Stop hook delivers it back to you
automatically once you have fully finished the current turn.
