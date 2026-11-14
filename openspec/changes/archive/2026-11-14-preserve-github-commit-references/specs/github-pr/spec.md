## ADDED Requirements

### Requirement: PR creation commits retain only references known at commit time
When create needs a new scoped commit, it SHALL preserve confirmed directly addressed Issue and already-existing PR associations using the shared commit reference policy. It MUST NOT guess the new PR number, amend existing commits after creation, or create a redundant commit solely to add references. Reusing an existing PR or commit SHALL preserve existing no-extra-write and scoped-publication guarantees.

#### Scenario: New PR has only a known Issue
- **WHEN** create commits selected work for confirmed Issue #19 before the new PR exists
- **THEN** the commit includes `Refs: #19` and omits the unknown future PR number
- **AND** creating the PR later does not trigger an amend or extra commit

#### Scenario: Selected work is already committed
- **WHEN** create finds the selected work already committed without a reference now available
- **THEN** it publishes the existing commit when authorized without rewriting it to backfill metadata

#### Scenario: Existing open PR is found
- **WHEN** create discovers one matching open PR
- **THEN** it returns that PR without committing additional work or changing history to add references

#### Scenario: Mixed checkout needs a scoped commit
- **WHEN** create commits selected PR files while unrelated staged or dirty files exist
- **THEN** reference formatting applies to the scoped commit without including unrelated work or invoking a whole-worktree writer unsafely

#### Scenario: Metadata operation has no Git write
- **WHEN** update, reply or close writes GitHub metadata
- **THEN** it makes no commit or push merely to record the Issue or PR number
