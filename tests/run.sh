#!/usr/bin/env bash
#
# end-of-turn-queue — regression suite
# ---------------------------------------------------------------------------
# Exercises the real Stop-hook script (scripts/queue-flush.sh) and the actual
# `!` bash snippets extracted from commands/*.md, against a throwaway queue.
#
# Run:   tests/run.sh        (or: bash tests/run.sh)
# Exits non-zero if any check fails. Requires: bash, jq, awk.
#
# Note on the command snippets: Claude Code substitutes $ARGUMENTS into the
# shell as raw text with no escaping (a documented CC limitation, issue #16163).
# These tests eval the snippet with ARGUMENTS as a shell variable, which
# validates the snippet's LOGIC (append, empty-guard, encoding) but is safer
# than CC's textual splice — they intentionally do not assert anything about
# shell-metacharacter injection, which no plugin can prevent at this layer.
# ---------------------------------------------------------------------------
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUSH="$REPO/scripts/queue-flush.sh"
ADD_MD="$REPO/commands/add.md"
LIST_MD="$REPO/commands/list.md"
CLEAR_MD="$REPO/commands/clear.md"

command -v jq  >/dev/null 2>&1 || { echo "FATAL: jq not found on PATH"; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "FATAL: awk not found on PATH"; exit 2; }
[ -x "$FLUSH" ] || { echo "FATAL: $FLUSH not executable"; exit 2; }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
export CLAUDE_PROJECT_DIR="$ROOT"
Q="$ROOT/.claude/prompt-queue"
mkdir -p "$ROOT/.claude"

pass=0; fail=0
chk() { # chk <got> <want> <name>
  if [ "$1" = "$2" ]; then printf 'PASS  %s\n' "$3"; pass=$((pass+1))
  else printf 'FAIL  %s\n        got : [%s]\n        want: [%s]\n' "$3" "$1" "$2"; fail=$((fail+1)); fi
}
reason() { printf '%s' "$1" | jq -r '.reason'; }      # extract .reason from hook JSON
seed()   { printf '%s' "$1" | jq -nc --arg p "$1" '$p' >> "$Q"; }  # append one JSON-encoded entry
reset()  { : > "$Q"; }

# Pull the single-line !`...` snippet out of a command markdown file.
extract_cmd() { sed -n 's/^!`\(.*\)`$/\1/p' "$1"; }

echo "== scripts/queue-flush.sh =="

reset; rm -f "$Q"
out="$("$FLUSH" </dev/null)"; rc=$?
chk "$rc|$out" "0|" "no queue file -> exit 0, no output"

reset
out="$("$FLUSH" </dev/null)"; rc=$?
chk "$rc|$out" "0|" "empty queue -> exit 0, no output"

reset; seed "run the tests"; seed "update the changelog"
out="$("$FLUSH" </dev/null)"
chk "$(printf '%s' "$out" | jq -r '.decision')" "block" "delivery uses decision:block"
chk "$(reason "$out" | grep -c 'run the tests')" "1" "FIFO: first in is first delivered"
chk "$(grep -c . "$Q")" "1" "one entry remains after a pop"
out="$("$FLUSH" </dev/null)"
chk "$(reason "$out" | grep -c 'update the changelog')" "1" "FIFO: second delivered next"
out="$("$FLUSH" </dev/null)"; rc=$?
chk "$rc|$out" "0|" "drained -> exit 0 (self-terminates)"

reset; printf '%s' 'say "hi"
line two' | jq -Rsc . >> "$Q"
out="$("$FLUSH" </dev/null)"
chk "$(printf '%s' "$out" | jq -e '.decision=="block"' >/dev/null 2>&1 && echo ok)" "ok" "quotes+newline: valid JSON out"
chk "$(reason "$out" | grep -c 'say "hi"')" "1" "quotes survive round-trip"
chk "$(reason "$out" | grep -c 'line two')" "1" "embedded newline survives"

reset; printf '%s\n' "plain reminder" > "$Q"
out="$("$FLUSH" </dev/null)"
chk "$(reason "$out" | grep -c 'plain reminder')" "1" "hand-edited plain-text line tolerated"

reset; printf '%s\n' 'null' > "$Q"
out="$("$FLUSH" </dev/null)"
chk "$(reason "$out" | grep -c 'null')" "1" "non-string JSON falls back to raw"

reset; printf '\n\n' >> "$Q"; seed "after blanks"
out="$("$FLUSH" </dev/null)"
chk "$(reason "$out" | grep -c 'after blanks')" "1" "leading blank lines skipped"

# jq-missing guard: run with a PATH that has coreutils but no jq.
reset; printf '%s\n' '"keep me"' > "$Q"
STUB="$ROOT/nojq-bin"; mkdir -p "$STUB"; stub_ok=1
for t in bash awk cat mktemp mv rm sed grep printf; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$STUB/$t" || stub_ok=0
done
if [ "$stub_ok" = 1 ]; then
  out="$(PATH="$STUB" "$FLUSH" </dev/null)"; rc=$?
  chk "$rc|$out" "0|" "jq missing -> exit 0, no output"
  chk "$(cat "$Q")" '"keep me"' "jq missing -> queue left intact"
else
  echo "SKIP  jq-missing guard (could not stub PATH)"
fi

chk "$(ls "$ROOT/.claude/" | grep -c 'prompt-queue\.')" "0" "no leftover temp files"

echo "== commands/add.md  (/queue:add) =="
ADD="$(extract_cmd "$ADD_MD")"
chk "$([ -n "$ADD" ] && echo ok)" "ok" "add.md snippet extracted"
reset
( ARGUMENTS='ship the release'; eval "$ADD" ) >/dev/null
chk "$(jq -r . < "$Q")" "ship the release" "add: appends one decodable JSON line"
chk "$(grep -c . "$Q")" "1" "add: exactly one line appended"
reset
out="$( ARGUMENTS=''; eval "$ADD" )"
chk "$(printf '%s' "$out" | grep -c 'Nothing to queue')" "1" "add: empty arg is rejected"
chk "$([ -s "$Q" ] && echo nonempty || echo empty)" "empty" "add: empty arg appends nothing"
reset
( ARGUMENTS="don't forget the apostrophe"; eval "$ADD" ) >/dev/null
chk "$(jq -r . < "$Q")" "don't forget the apostrophe" "add: ordinary apostrophes round-trip"

echo "== commands/list.md  (/queue:list) =="
LIST="$(extract_cmd "$LIST_MD")"
reset; seed "first"; seed "second"
out="$(eval "$LIST")"
chk "$(printf '%s' "$out" | grep -c '1. first')"  "1" "list: numbers entries, decoded, next-first"
chk "$(printf '%s' "$out" | grep -c '2. second')" "1" "list: second entry shown"
reset
out="$(eval "$LIST")"
chk "$(printf '%s' "$out" | grep -c '(empty)')" "1" "list: empty queue shows (empty)"

echo "== commands/clear.md  (/queue:clear) =="
CLEAR="$(extract_cmd "$CLEAR_MD")"
reset; seed "a"; seed "b"
out="$(eval "$CLEAR")"
chk "$(printf '%s' "$out" | grep -c 'Cleared 2')" "1" "clear: reports count cleared"
chk "$([ -s "$Q" ] && echo nonempty || echo empty)" "empty" "clear: empties the queue"
reset
out="$(eval "$CLEAR")"
chk "$(printf '%s' "$out" | grep -c 'already empty')" "1" "clear: already-empty message"
reset; printf '\n\n\n' > "$Q"
out="$(eval "$CLEAR")"
chk "$(printf '%s' "$out" | grep -c 'Cleared 0 queued')" "1" "clear: whitespace-only file -> single 0"

echo "============================================"
printf 'PASS=%d  FAIL=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
