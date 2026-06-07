#!/usr/bin/env bash
#
# end-of-turn-queue — Stop hook
# ---------------------------------------------------------------------------
# Fires once when the MAIN agent finishes its turn (never between tool calls,
# never inside a subagent — this plugin defines no SubagentStop hook). Pops
# exactly ONE queued prompt and hands it back to Claude as the next instruction
# via {"decision":"block","reason":...}.
#
# Self-terminating: each fire removes one entry, so the queue strictly shrinks.
# When it is empty the hook exits 0 and Claude is allowed to stop. The loop
# guard is structural (the shrinking queue), not a reliance on stop_hook_active.
#
# Queue format: one entry per line at ${CLAUDE_PROJECT_DIR}/.claude/prompt-queue,
# each line a JSON-encoded string (robust to quotes, newlines, anything). A
# hand-written plain-text line is also tolerated (used verbatim).
# ---------------------------------------------------------------------------
set -euo pipefail

# Consume the Stop-hook JSON on stdin; we don't need it. Leaving it unread can
# surface a broken pipe to the caller, so drain it cleanly.
cat >/dev/null 2>&1 || true

QUEUE="${CLAUDE_PROJECT_DIR:-.}/.claude/prompt-queue"

# Nothing queued -> let Claude stop normally.
[ -s "$QUEUE" ] || exit 0

# First non-blank line (positional pop — not a content match).
NEXT_RAW="$(awk 'NF{print; exit}' "$QUEUE")"

# Only blank lines remain: clear the file and let Claude stop.
if [ -z "$NEXT_RAW" ]; then
  : > "$QUEUE"
  exit 0
fi

# Decode the JSON-encoded entry; fall back to the raw line for hand-edited files.
NEXT="$(printf '%s' "$NEXT_RAW" | jq -r . 2>/dev/null)" || NEXT="$NEXT_RAW"
[ -n "$NEXT" ] || NEXT="$NEXT_RAW"

# Remove the first non-blank line (and any blank lines before it); preserve the
# order of everything after it.
awk 'BEGIN{popped=0}
     { if (!popped && NF) { popped=1; next } if (popped) print }' \
  "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"

# Hand the prompt back as Claude's next instruction.
REASON="Delivered from the end-of-turn queue (your turn finished, so here is the next queued prompt). Complete it, then stop — any remaining queued prompts arrive the same way.

${NEXT}"

jq -nc --arg r "$REASON" '{decision:"block", reason:$r}'
exit 0
