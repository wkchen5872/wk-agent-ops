#!/usr/bin/env bash
# ai-notify-capability: handoff-events
# Fake notification hook: declares handoff events, records each call on one line in $FAKE_XIRP_DIR/notified
# (handoff events also in handoff.jsonl). Exits with $FAKE_NOTIFY_RC (default 0).
payload="$(cat)"
printf 'event=%s action_required=%s %s\n' "$1" "${NOTIFY_ACTION_REQUIRED:-unset}" "$payload" >> "$FAKE_XIRP_DIR/notified"
[[ "$1" == handoff ]] && printf '%s\n' "$payload" >> "$FAKE_XIRP_DIR/handoff.jsonl"
exit "${FAKE_NOTIFY_RC:-0}"
