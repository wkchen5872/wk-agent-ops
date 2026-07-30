## Context

See `proposal.md` for motivation. OpenSpec strict validation currently rejects
five canonical specifications for two schema-level reasons:

- 13 requirement bodies do not contain the literal normative keyword `MUST` or
  `SHALL`, even where the Chinese wording already expresses an obligation.
- Three requirements in `telegram-notify-hook` have no level-four
  `#### Scenario` block.

The existing requirement behavior is authoritative. This change must make that
content parseable without redefining capabilities or editing archived changes.

## Goals / Non-Goals

**Goals:**

- Make all five affected canonical specifications strict-valid.
- Keep the wording and scenarios semantically equivalent to the current
  requirements.
- Leave a validation sequence that detects both targeted and repository-wide
  regressions.

**Non-Goals:**

- Changing installer, hook, notification, profile, or TDD behavior.
- Adding delta specs for editorial-only corrections.
- Rewriting unaffected requirements or historical archived artifacts.
- Fixing implementation gaps that validation may reveal after syntax
  conformance is restored.

## Decisions

### Use `SHALL` as the normative keyword

Rewrite only the opening sentence of each rejected requirement so it contains
literal `SHALL`. Preserve the existing subject, conditions, and outcome.

Alternative considered: configure the validator to recognize Chinese
normative wording. That would introduce tooling behavior for a small,
repository-local documentation issue and would not repair the existing specs
for standard OpenSpec consumers.

### Add one minimal scenario to each scenario-less requirement

Add exactly one `#### Scenario` to each of these existing
`telegram-notify-hook` requirements:

- `hook.sh — 通知腳本`: an enabled notification event follows the configured
  notification level and sends through Telegram.
- `Line Notify 架構佔位`: inspecting the provider directory finds the
  placeholder and its extension guidance.
- `說明文件`: inspecting the shipped notification docs finds both the
  architecture and Telegram setup guidance described by the requirement.

Each scenario restates an already required observable outcome; it must not add
new provider behavior or runtime paths.

Alternative considered: move a neighboring scenario under each requirement.
That would incorrectly change which requirement the scenario verifies.

### Treat strict validation as the test boundary

The existing failing `openspec validate <name> --type spec --strict` results are
the red evidence. During implementation, validate each affected specification
after editing, then run `openspec validate --all --strict` as the final
repository-wide check. Runtime test suites are outside this documentation-only
change because no executable behavior changes.

### Skip delta specs

Set `skip_specs: true` because the implementation edits canonical spec syntax
without changing requirement behavior. Creating delta requirements would
misrepresent an editorial repair as a capability change.

## Risks / Trade-offs

- [Normative wording accidentally changes meaning] → Keep changes sentence-local
  and review the final diff for added or removed conditions.
- [A new scenario introduces behavior] → Derive each WHEN/THEN pair directly
  from its existing requirement and add only one scenario.
- [Targeted specs pass while another spec remains invalid] → Require the final
  all-spec strict validation.

## Migration Plan

1. Record the current five failing specification names.
2. Apply the normative-keyword and scenario-only edits to canonical specs.
3. Validate each affected spec strictly, then validate all OpenSpec items.
4. If review finds semantic drift, revert the affected sentence or scenario;
   no runtime rollback is required.
