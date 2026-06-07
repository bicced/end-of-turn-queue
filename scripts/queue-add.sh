#!/usr/bin/env bash
#
# end-of-turn-queue — /queue append helper
# ---------------------------------------------------------------------------
# Reads the prompt from STDIN and appends it to the queue as a single
# JSON-encoded line. Taking the prompt on stdin (the slash command pipes it in
# via a quoted heredoc) means shell metacharacters in the prompt — quotes,
# $(...), backticks — are never interpreted: the text is treated as data, not
# code. It also lets a single queued prompt span multiple lines.
# ---------------------------------------------------------------------------
set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "end-of-turn-queue: jq is required but was not found on PATH."
  exit 1
}

prompt="$(cat)"

# Treat an all-whitespace (or empty) prompt as nothing to queue.
if [ -z "${prompt//[[:space:]]/}" ]; then
  echo "Nothing to queue. Usage: /queue <prompt>"
  exit 0
fi

dir="${CLAUDE_PROJECT_DIR:-.}/.claude"
mkdir -p "$dir"

# -R raw input, -s slurp the whole prompt into one string, -c one compact line.
printf '%s' "$prompt" | jq -Rsc . >> "$dir/prompt-queue"
echo "Queued for end-of-turn."
