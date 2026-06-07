---
description: Queue a prompt to run at the very end of the current turn, never mid-loop.
argument-hint: <prompt to run once the current turn finishes>
allowed-tools: Bash(mkdir:*), Bash(jq:*)
---
!`if [ -z "$ARGUMENTS" ]; then echo "Nothing to queue. Usage: /queue <prompt>"; else mkdir -p "${CLAUDE_PROJECT_DIR}/.claude" && jq -nc --arg p "$ARGUMENTS" '$p' >> "${CLAUDE_PROJECT_DIR}/.claude/prompt-queue" && echo "Queued for end-of-turn: $ARGUMENTS"; fi`

The line above has already appended the prompt to the end-of-turn queue (stored
one entry per line, JSON-encoded, at `${CLAUDE_PROJECT_DIR}/.claude/prompt-queue`).

Do NOT act on the queued item now. Reply with a single short line confirming it's
queued, then continue with exactly what you were doing. The Stop hook will deliver
this prompt back to you automatically once you have fully finished the current turn.
