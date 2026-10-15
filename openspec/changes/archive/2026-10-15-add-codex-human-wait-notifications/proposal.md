# Proposal

## Why

Codex `PermissionRequest` also precedes automatic review, so its working notification cannot identify a request that actually needs a person. Users need separate human-wait notifications and understandable, independently selectable notification categories.

## What Changes

- Preserve legacy notifications and neutral provider responses; PermissionRequest continues following the shared action-required switch.
- Add hook-triggered, non-blocking, per-session Codex daemon checks for human approval and synchronous questions, plus successful-post notifications for async structured questions. No LaunchAgent or login service.
- Add a Traditional Chinese grouped settings menu with three shared categories and two Codex-only categories, explicit support status, cancellation and save summaries.
- Preserve legacy level defaults; new categories remain off until explicitly selected.
- Cover lifecycle, concurrency, privacy and cross-provider regressions with isolated tests.

## Capabilities

### New Capabilities
- `codex-human-wait-notifications`: On-demand observation, waiting transitions, bounded failure and lifecycle-owned deployment.

### Modified Capabilities
- `telegram-notify-hook`: Per-category settings, grouped setup/update, independent legacy and daemon branches, and question hook registration.
- `notify-test-harness`: Category, menu and daemon lifecycle contract coverage without live messaging.

## Impact

Changes are scoped to `scripts/notify/`, notification documentation and this OpenSpec change. Claude Code, Antigravity and Copilot retain existing event mappings. Codex adds two opt-in categories: human approval and synchronous questions need sessions loaded in the existing local daemon, while async structured questions notify from native successful-result metadata. Plain-text questions are not covered. Python 3 plus isolated `websocket-client` are required only for enabled daemon checks. Developer machine settings are changed only through the installation/update entrypoints.
