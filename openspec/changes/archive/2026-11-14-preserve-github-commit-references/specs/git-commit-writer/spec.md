## ADDED Requirements

### Requirement: Commit references identify confirmed directly addressed GitHub work
The writer skill and provider-native commit agents SHALL include confirmed GitHub Issues and PRs directly addressed by the staged work in a single `Refs: ...` line before attribution trailers. They MUST exclude background references and dependencies unless independently confirmed as directly addressed. Unknown or conflicting associations SHALL be omitted with a reported reason, without blocking an otherwise authorized commit.

#### Scenario: Only an Issue is confirmed
- **WHEN** staged work directly addresses Issue #19 in the commit repository and no PR exists
- **THEN** the message includes `Refs: #19` and no guessed PR number

#### Scenario: Issue and PR are confirmed
- **WHEN** staged work directly addresses confirmed Issue #19 and PR #20 in the commit repository
- **THEN** the message includes `Refs: #19, #20` once before the unchanged attribution trailers

#### Scenario: Multiple direct Issues share one commit
- **WHEN** the staged work directly addresses two confirmed Issues
- **THEN** both are retained without silently choosing only the first

#### Scenario: Nearby links are background only
- **WHEN** a Change references completed Issues #13 and #17 as context but directly addresses only #19
- **THEN** the commit lists only #19 unless the staged work independently establishes another direct association

#### Scenario: Association is absent or unresolved
- **WHEN** no association is confirmed or conflicting records cannot identify a direct target
- **THEN** the writer proceeds with the authorized commit without inventing a reference
- **AND** reports unavailable or conflicting associations separately

### Requirement: Reference normalization preserves repository identity without closure effects
References SHALL use `#N` only for the verified commit repository on its host and full HTTPS Issue or PR URLs for other repositories or hosts. The writer SHALL deduplicate by host, owner, repository and number, sort canonical references deterministically, and use no automatic closing keywords. Adding metadata MUST NOT change commit scope, attribution, staging safety or existing hooks.

#### Scenario: Same number belongs to different repositories
- **WHEN** directly addressed work includes local Issue #19 and https://github.com/other/project/issues/19
- **THEN** both appear with their repository identity preserved

#### Scenario: Repeated URL and number identify one target
- **WHEN** both a short number and a URL confirm the same repository target
- **THEN** that reference appears once, with local targets ordered numerically and external URLs lexically after local targets

#### Scenario: References do not request state changes
- **WHEN** an authorized commit includes confirmed targets
- **THEN** the message uses Refs rather than Closes or Fixes to encode those references
- **AND** reference creation performs no Issue or PR state mutation

#### Scenario: Existing message and Git controls remain
- **WHEN** references are inserted into a scoped Conventional Commit
- **THEN** the existing subject, supported tool and model attribution, archive validation and Git safety checks remain effective

### Requirement: Reference metadata never manufactures or rewrites commits
The writer SHALL apply reference requirements only when making an already authorized nonempty commit. It MUST NOT amend or rewrite historical commits, create empty commits, or alter Git history solely because an Issue or PR is created, updated, replied to or closed later.

#### Scenario: GitHub-only operation
- **WHEN** the user requests a reply or closure with no code or document changes
- **THEN** no commit is made just to record the operation's target number

#### Scenario: PR number becomes known after commit
- **WHEN** a PR is created after a commit that correctly referenced its known Issue
- **THEN** the existing commit remains unchanged and the PR association can appear in a future independently needed commit
