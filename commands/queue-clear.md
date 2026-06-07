---
description: Remove all prompts from the end-of-turn queue.
allowed-tools: Bash(test:*), Bash(grep:*)
---
!`Q="${CLAUDE_PROJECT_DIR}/.claude/prompt-queue"; if [ -s "$Q" ]; then n="$(grep -c '[^[:space:]]' "$Q" 2>/dev/null || true)"; [ -n "$n" ] || n=0; : > "$Q"; echo "Cleared $n queued prompt(s)."; else echo "Queue already empty."; fi`

Reflect the command output above in one short line — it will say either how many
prompts were cleared or that the queue was already empty. Take no further action.
