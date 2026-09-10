#!/usr/bin/env bash
input=$(cat)

if echo "$input" | grep -qE '\.env|credentials|id_rsa'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"secret file — ห้ามแตะเด็ดขาด"}}'
  exit 0
fi

if echo "$input" | grep -qE 'push --force|push -f|rm -rf'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"คำสั่งกู้กลับยาก ต้องขออนุมัติก่อน"}}'
  exit 0
fi

if echo "$input" | grep -qE 'package\.json|<script src='; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"เพิ่ม dependency ใหม่ ต้องถามก่อน"}}'
  exit 0
fi

if echo "$input" | grep -q 'README.md'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"README.md ต้องถามก่อนแก้เสมอ"}}'
  exit 0
fi

exit 0
