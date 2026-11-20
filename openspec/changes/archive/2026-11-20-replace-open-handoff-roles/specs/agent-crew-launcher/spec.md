## MODIFIED Requirements

### Requirement: A role that has not opened can be changed during the loop
`handoff-role <change-id> <review|finish> <override>` SHALL replace that role's tool, model, effort, provider and billing in the loop's `loop.yaml` while the role's session has not opened, using the override form `handoff-start` accepts. It SHALL first run the checks `handoff-start` applies to roles. When a check fails, or the role's session is already recorded and `--replace` is not given, it SHALL exit non-zero and leave `loop.yaml` unchanged. It MUST NOT modify `roles.yaml`.

#### Scenario: Reviewer changed before the first handoff
- **WHEN** no reviewer has opened and `handoff-role add-export review pi:openai/gpt-6.2-sol:high:api` runs with that model listed and an API-key credential ready
- **THEN** `loop.yaml` holds a Pi review template with those values, and the hook later opens the reviewer from it

#### Scenario: Reviewer already open
- **WHEN** `loop.yaml` records a reviewer session and `handoff-role add-export review codex:gpt-6.2-sol:high` runs without `--replace`
- **THEN** it exits non-zero naming that session and suggesting `--replace`, and `loop.yaml` is unchanged

#### Scenario: Pi role fails verification
- **WHEN** `handoff-role add-export review pi:openai/not-a-model:high:api` runs and the model is not listed under `openai`
- **THEN** it exits non-zero naming the check, and `loop.yaml` is unchanged

#### Scenario: Second Pi role in one worktree
- **WHEN** the implementer is a Pi role, the review role uses the implementer's worktree, and `handoff-role add-export review pi:openai/gpt-6.2-sol:high:api` runs
- **THEN** it exits non-zero explaining that a worktree holds one Pi role, and `loop.yaml` is unchanged

## ADDED Requirements

### Requirement: An open review or finish role can be replaced
With `--replace`, `handoff-role` SHALL replace a review or finish role whose session is open. It SHALL run the same checks on the new settings first; when any fails, the old session, `loop.yaml`, and the records SHALL stay unchanged. Otherwise it SHALL delete or close the old session through the old role's host, clear the role's session in `loop.yaml`, and write the new settings. The implementer SHALL NOT be replaceable.

#### Scenario: Reviewer replaced
- **WHEN** a Codex reviewer is open and `handoff-role add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new --replace` passes its checks
- **THEN** the Codex session is deleted, `loop.yaml` holds the Pi review template with no reviewer session, and `roles.yaml` is unchanged

#### Scenario: Replacement fails its checks
- **WHEN** `--replace` is given and the new Pi model is not listed under its provider
- **THEN** it exits non-zero, the old reviewer session still exists, and `loop.yaml` is unchanged

#### Scenario: Implementer cannot be replaced
- **WHEN** `handoff-role add-export implement claude:opus:high --replace` runs
- **THEN** it exits non-zero saying only review and finish roles can be changed

### Requirement: A record waiting for a replaced role goes to the new role
After a replacement, `handoff-role` SHALL hand the waiting record to the new role at once. For review, a newest `implement`/`done` record that was sent to the old reviewer and has no later review SHALL open the new reviewer and send that round. For finish, a newest `finish`/`blocked` record, or a passing review whose finish session had opened, SHALL open the new finish session. The hand-off SHALL be written to the routing log. With no waiting record, the new role SHALL open when its turn comes.

#### Scenario: Pending review goes to the new reviewer
- **WHEN** the newest record is an `implement`/`done` record already sent to the old reviewer and the reviewer is replaced
- **THEN** the new reviewer opens, receives the review prompt for that round, and the routing log records the hand-off

#### Scenario: Blocked finish goes to the new finish role
- **WHEN** the newest record is `finish`/`blocked` and the finish role is replaced
- **THEN** a new finish session opens and receives the finish prompt

#### Scenario: Nothing is waiting
- **WHEN** the reviewer is replaced while the implementer is still working on its round
- **THEN** no session opens now, and the hook opens the new reviewer when the next `implement`/`done` record is processed

#### Scenario: Hand-off fails after replacement
- **WHEN** the replacement succeeds but the new reviewer cannot be opened
- **THEN** the record stays unprocessed, the user gets one attention notice, and `handoff-route --foreground` retries it

### Requirement: A review or finish role can move to its own worktree
`handoff-role` SHALL accept `--worktree new` to make a review or finish role that uses the implementer's worktree work in a worktree of its own, applied with the other new settings and checked by the one-Pi-role-per-worktree rule. Moving a role back to the implementer's worktree SHALL be refused.

#### Scenario: Pi reviewer next to a Pi finish role
- **WHEN** the finish role is a shared Pi role and `handoff-role add-export review pi:openai/gpt-6.2-sol:medium:api --worktree new` runs
- **THEN** the check passes, `loop.yaml` sets the review worktree to `new`, and the reviewer later opens in its own worktree

#### Scenario: Moving back to the shared worktree
- **WHEN** `handoff-role add-export review codex:gpt-6.2-sol:high --worktree shared` runs
- **THEN** it exits non-zero saying only `--worktree new` is supported, and `loop.yaml` is unchanged
