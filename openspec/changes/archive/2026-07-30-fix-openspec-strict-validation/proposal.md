## Why

Five canonical OpenSpec specifications fail strict validation, so the repository
cannot use `openspec validate --all --strict` as a reliable conformance check.
The failures are limited to missing normative keywords and missing scenario
blocks in otherwise existing requirements.

## What Changes

- Add literal `MUST` or `SHALL` wording to 13 existing requirement bodies
  without changing their behavior.
- Add one testable `#### Scenario` to each of three requirements in
  `telegram-notify-hook` that currently have no scenario.
- Run strict validation across all changes and canonical specifications.
- Preserve archived change artifacts as historical records.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is a documentation-conformance correction and does not change
requirement behavior, so the change explicitly opts out of delta specs.

## Impact

- Affected files are limited to the canonical specifications for
  `install-profile-cli`, `pre-commit-quality-gate`, `tdd-enforcement-rules`,
  `telegram-notify-hook`, and `template-profile-structure`.
- No runtime code, APIs, dependencies, hooks, or installation behavior changes.
