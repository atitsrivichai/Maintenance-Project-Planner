#!/usr/bin/env bash
input=$(cat)
if echo "$input" | grep -q 'README.md'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"README.md ต้องถามก่อนแก้เสมอ"}}'
  exit 0
fi
exit 0
