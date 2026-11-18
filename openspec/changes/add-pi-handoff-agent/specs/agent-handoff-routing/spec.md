# Spec Delta

## MODIFIED Requirements

### Requirement: Routing runs when an agent stops
A Stop hook SHALL run when a Claude Code or Codex agent stops, and the Pi trigger defined by `agent-handoff-pi` SHALL run when a Pi agent settles. It SHALL act only on the newest handoff record in the stopping agent's worktree that it has not processed, and SHALL exit without any action when there is no such record or no `loop.yaml` for that change.

#### Scenario: Agent stops after an ordinary question
- **WHEN** an agent stops after answering a question and wrote no new handoff record
- **THEN** the hook sends nothing and exits successfully

#### Scenario: Agent stops after recording a handoff
- **WHEN** an agent stops and a new handoff record exists for a change with a `loop.yaml`
- **THEN** the hook routes that record exactly once

#### Scenario: Pi agent settles after recording a handoff
- **WHEN** a Pi role settles and a new handoff record exists for a change with a `loop.yaml`
- **THEN** the record is routed exactly once, as for Claude Code and Codex

### Requirement: The hook is installed for supported providers
An installer SHALL register the Stop hook for Claude Code and Codex idempotently, SHALL install the Pi trigger in Pi's global extension directory idempotently, and SHALL tell the user that Codex requires trusting the new hook once and that Pi sessions opened before installation do not route until they reload. It MUST NOT mark the hook as trusted on the user's behalf.

#### Scenario: Installer runs twice
- **WHEN** the installer is run a second time
- **THEN** each provider has exactly one registration of the Stop hook
- **AND** Pi's extension directory contains exactly one handoff trigger

#### Scenario: Codex trust is left to the user
- **WHEN** the installer registers the Codex hook
- **THEN** it prints that the hook must be trusted in Codex and does not edit Codex trust state

## ADDED Requirements

### Requirement: A Pi record must match its role template before it is routed
Before routing a record whose role template in `loop.yaml` has `harness: pi`, the hook SHALL compare the record's `agent` section with that template. When the section is missing, any value is `unknown`, or the provider, model, effort, or billing differs, the hook SHALL notify the user naming each mismatch, MUST NOT message or open any session, and SHALL mark the record as processed. Records of Claude Code and Codex roles SHALL be routed as before.

#### Scenario: Implementer switched model mid-session
- **WHEN** the implement template declares `openai-codex/gpt-6.2-sol` and the record's `agent` section shows `openai-codex/gpt-6.1-terra`
- **THEN** the user is notified of the model mismatch, the reviewer is not asked to review, and a later stop does not notify again

#### Scenario: Billing differs
- **WHEN** the template declares `billing: subscription` and the record shows `billing: api`
- **THEN** the user is notified and the record is not routed

#### Scenario: Record has no agent identity
- **WHEN** the role template is Pi and the record has no `agent` section
- **THEN** the user is notified and the record is not routed

#### Scenario: Matching record
- **WHEN** every value in the record's `agent` section equals the role template
- **THEN** the record is routed as usual

### Requirement: The hook verifies a Pi role before opening it
Before the hook opens a Pi reviewer or finish session, it SHALL repeat the model, credential, and billing verification of `agent-handoff-pi`. When verification fails, it SHALL open no session, notify the user naming the failed check, and leave the record unprocessed so that a later hook run, after the user fixes the cause, retries the opening.

#### Scenario: Credential changed after start
- **WHEN** the review template declares `billing: subscription` and, by the first implement handoff, the provider's credential has become an API key
- **THEN** no reviewer session opens, the user is notified, and the record stays unprocessed

#### Scenario: Retry after the fix
- **WHEN** the user restores the subscription credential and the hook runs again for that record
- **THEN** the reviewer session opens and the record is marked as processed
