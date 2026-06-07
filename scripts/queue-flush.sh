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
#
# Failure stance: NEVER lose a queued entry. The block response is built BEFORE
# the entry is removed, and removal is an atomic rename, so any failure path
# leaves the queue intact and simply delivers nothing this turn.
# ---------------------------------------------------------------------------
set -euo pipefail

# Consume the Stop-hook JSON on stdin; we don't need it. Leaving it unread can
# surface a broken pipe to the caller, so drain it cleanly.
cat >/dev/null 2>&1 || true

# jq is required to decode entries and to emit the response. If it is missing we
# cannot deliver, so leave the queue untouched and let Claude stop normally.
command -v jq >/dev/null 2>&1 || exit 0

QUEUE="${CLAUDE_PROJECT_DIR:-.}/.claude/prompt-queue"
TMP=""
trap 'rm -f "${TMP:-}" 2>/dev/null || true' EXIT

# Nothing queued -> let Claude stop normally.
[ -s "$QUEUE" ] || exit 0

# First non-blank line (positional pop — not a content match).
NEXT_RAW="$(awk 'NF{print; exit}' "$QUEUE")"

# Only blank lines remain: clear the file and let Claude stop.
if [ -z "$NEXT_RAW" ]; then
  : > "$QUEUE"
  exit 0
fi

# Decode the entry. Lines are JSON-encoded strings; a hand-edited plain-text
# line (invalid JSON, or non-string JSON like null/objects) falls back to the
# raw line so nothing is ever silently dropped.
NEXT="$(printf '%s' "$NEXT_RAW" | jq -er 'select(type == "string")' 2>/dev/null)" || NEXT="$NEXT_RAW"
[ -n "$NEXT" ] || NEXT="$NEXT_RAW"

# Build the response BEFORE mutating the queue, so a jq failure here can never
# drop the entry.
REASON="Delivered from the end-of-turn queue (your turn finished, so here is the next queued prompt). Complete it, then stop — any remaining queued prompts arrive the same way.

${NEXT}"
OUT="$(jq -nc --arg r "$REASON" '{decision:"block", reason:$r}')"

# Pop the first non-blank line (and any blank lines before it); preserve the
# order of everything after it. Unique temp + atomic rename on the same fs.
TMP="$(mktemp "${QUEUE}.XXXXXX")"
awk 'BEGIN{popped=0}
     { if (!popped && NF) { popped=1; next } if (popped) print }' \
  "$QUEUE" > "$TMP"
mv "$TMP" "$QUEUE"
TMP=""

# Deliver only after the entry is safely removed.
printf '%s\n' "$OUT"
exit 0
