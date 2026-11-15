---
type: Playbook
title: OpenSpec Workflow
description: Shared OpenSpec planning, review, implementation, verification, and delivery workflow.
tags: [agents, openspec, workflow]
timestamp: 2026-09-15T00:00:00+08:00
---

<!-- Managed by wk-agent-ops · do not edit here — re-running install.sh overwrites this file. -->

# OpenSpec Workflow

Use this playbook when [Agent Operating Protocol](agent-protocol.md) requires
formal planning or the task follows an existing OpenSpec change. These are
repository workflow requirements, not a description of upstream CLI defaults.

## 1. Explore and select the change

Read the relevant existing specs and active changes. Clarify the outcome,
acceptance criteria, affected boundaries, and unresolved decisions. Reuse an
applicable change; create a new one only when needed. Exploration alone does
not require creating artifacts or an implementation branch.

OpenSpec owns requirements, design, and implementation tasks. A provider's
execution mode or progress display may assist, but must not replace those
artifacts or introduce a separate development plan.

## 2. Prepare the branch

After accepting or deriving a change ID, run `opsx-branch <change-id>` before
any OpenSpec new, fast-forward, or continue action. For new and fast-forward,
do this before creating the scaffold; for continue, do it before reading status
or writing the next artifact. If the command exits non-zero, stop the current
OpenSpec action and report the error. If the helper is unavailable, report the
missing prerequisite; do not silently skip the guard.

When the active Provider sandbox is known to protect Git metadata, request the
minimum required Git-write permission on the first attempt; do not run a
guaranteed-to-fail sandbox probe first.

## 3. Specify and review

Use the installed OpenSpec skills or integration and the project's configured
schema to create the required artifacts, such as proposal, design, specs, and
tasks. Do not create provider-native plan or task files as substitutes.

Obtain human review of the design before implementation. An
explicit user instruction to implement an identified Change authorizes
implementation of its current design; no separate approval phrase, account confirmation, or PR event is required.
Judge it by four things: its source, the Change and artifacts it covers, the
design revision, and the scope of work.

- **Accepted sources:** the current user's explicit instruction in this
  session; an instruction relayed through an existing collaboration channel as a
  traceable handoff that names the work and its source (no private original
  conversation or account proof is needed); or a published approval record — the
  user's own PR comment or review, or a recorded approval event.
- **What does not authorize Apply:** Creating a Change, a discussion, or a review on
  their own; an agent's technical review pass, design or implementation; an
  agent suggestion, a body that claims approval, or any approval claim with no
  identifiable user instruction behind it; and an approval that was withdrawn
  or superseded by a material design change. An API account shows only who
  posted, never whose intent it was.
- **Clarify first** when sources conflict, the latest instruction withdraws
  authorization, acceptance criteria or design decisions changed materially
  after the approved revision, or the scope cannot be identified. Clarify only
  the affected part; other authorized work continues. When the user asks to
  pause, stop Apply until they direct again.
- Existing approval remains valid while scope and decisions remain unchanged.
  Material requirement or design changes, or a withdrawn instruction, need
  renewed direction for the changed decisions, and changed acceptance criteria
  are made in the OpenSpec artifacts — editing an Issue or pull request does not
  approve them.
- Permission to implement does not include permission to publish to GitHub.
  Recording an approval, or that it was superseded, on a pull request needs the
  user's separate request.
- A design or implementation review that does not pass returns to specification
  revision or repair; it does not advance to the next stage, and an
  implementer's statement that something is fixed is not a pass.

For behavior that cannot reasonably be tested automatically, record the reason,
replayable acceptance steps, and expected results before implementation. Add
actual results after implementation; a proposed check is not passing evidence.

## 4. Implement and verify

Read the active change's artifacts and implement its tasks using the protocol's
TDD loop. Keep tasks and evidence current. Run the applicable project checks
and OpenSpec verification before reporting implementation complete. A spec
review does not replace executing tests or acceptance checks.

## 5. Deliver within the requested scope

When archival is requested or part of the authorized project workflow, use the
OpenSpec archive process, including required reconciliation of delta specs.
Commit only within the requested delivery scope and after required checks pass.
For review-first work, leave changes unarchived and uncommitted and report what
was verified and what remains.

These are separate stages: design review, human design approval,
implementation review, archival, commit, merge, deployment,
real-data acceptance, and Issue closure.
Each keeps its own evidence and needs its own authorization; completing one does
not imply completing another. A merged design-only pull request does not replace
the later implementation review and acceptance. When required acceptance waits
for real data, report delivery and acceptance status separately, and do not
archive early to close work whose required data acceptance is incomplete. A
review pass, a merge, or a date arriving is not acceptance.

## GitHub handoff (optional)

A project may use GitHub Issues and pull requests to hand work between sessions
or machines. This is optional: no Change requires an Issue or PR. When it is
used, [GitHub 協作整合](github-handoff.md) explains where each stage touches
GitHub and which skill to invoke; the `github-issue`, `github-pr`, and
`change-review` skills hold the post formats, write-time checks, and approval
records. OpenSpec remains the authority for requirements; an Issue or PR edit
alone approves nothing, and each stage in section 5 still needs its own evidence
and authorization.

## Integration entrypoints

Use the installed integration for each stage: explore, new/fast-forward/continue,
apply, verify, and archive/commit. Load its instructions when invoking it rather
than duplicating command mechanics here. If no OpenSpec integration is available,
report the prerequisite instead of falling back to provider-native planning.
