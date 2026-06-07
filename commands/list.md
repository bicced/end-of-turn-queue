---
description: Show the prompts currently waiting in the end-of-turn queue.
allowed-tools: Bash(jq:*), Bash(test:*)
---
Current end-of-turn queue (top of the list is delivered next):

!`Q="${CLAUDE_PROJECT_DIR}/.claude/prompt-queue"; if [ ! -s "$Q" ]; then echo "(empty)"; else i=0; while IFS= read -r line || [ -n "$line" ]; do [ -z "$line" ] && continue; i=$((i+1)); dec="$(printf '%s' "$line" | jq -r . 2>/dev/null)" || dec="$line"; printf '%s. %s\n' "$i" "$dec"; done < "$Q"; fi`

This is a read-only view. Do NOT act on these items now — they are delivered
automatically at end of turn. Summarize what's queued in one short line.
