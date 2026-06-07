---
description: Remove all prompts from the end-of-turn queue.
allowed-tools: Bash(test:*), Bash(grep:*)
---
!`Q="${CLAUDE_PROJECT_DIR}/.claude/prompt-queue"; if [ -s "$Q" ]; then n="$(grep -c '[^[:space:]]' "$Q" 2>/dev/null || echo 0)"; : > "$Q"; echo "Cleared $n queued prompt(s)."; else echo "Queue already empty."; fi`

The end-of-turn queue has been cleared. Confirm in one short line; take no further action.
