## Context

The branch guard is defined in the managed portable protocol. The shell command
must update Git metadata, while some Provider sandboxes deliberately protect that
metadata even when the workspace is writable.

## Goals / Non-Goals

**Goals:**

- Make the first `opsx-branch` attempt request only the permission it already
  requires.
- Preserve the provider-neutral branch guard and installer flow.

**Non-Goals:**

- Changing `opsx-branch`, Codex sandbox configuration, or approval rules.
- Granting broad or persistent full access.

## Decisions

- Add one provider-neutral sentence to the existing branch guard paragraph. This
  keeps permission routing with the Agent caller, where the execution capability
  exists; a shell script cannot elevate its own sandbox permission.
- Extend the existing portable-protocol test with a focused text assertion before
  changing the template, then regenerate the managed protocol through the current
  installer.

## Risks / Trade-offs

- Provider wording may be interpreted differently across tools → require only the
  minimum Git-write permission and only when the active sandbox is known to protect
  Git metadata.
