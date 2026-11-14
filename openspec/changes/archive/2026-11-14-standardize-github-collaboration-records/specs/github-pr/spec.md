# Spec Delta

## MODIFIED Requirements

### Requirement: PR formatting uses a minimal frame with optional associations
PR bodies and replies SHALL begin with Handoff, include concise Next actions and end with shared Author. Handoff SHALL identify the verified head branch. Confirmed work and dependency links SHALL be optional and Work Items marked local-only. Bodies SHALL explain purpose, published changes and actual verification. Review, repair, Checkpoint and Closure replies SHALL use corresponding shared content.

#### Scenario: PR begins without local identifiers
- **WHEN** a published branch has no associated Work Item, Change, or Issue
- **THEN** Handoff contains its verified branch and no empty association fields
- **AND** the body still explains the work without relying on identifiers

#### Scenario: Associations are supplied later
- **WHEN** a later update confirms a Change, Work Item, or directly corresponding Issue
- **THEN** the description can add those associations without creating another PR
- **AND** dependency links remain distinguishable from Issues whose work this PR addresses

#### Scenario: Description follows a newer published version
- **WHEN** an authorized update describes a newer remote head
- **THEN** changes, verification and Next actions match that published version while unrelated human notes and historical reports are preserved


### Requirement: PR Author includes native and Xirp session identifiers independently
Bodies and replies SHALL end with shared human or agent-assisted Author. Agent posts SHALL retain tool, known root-session model, SESSION-ID and XIRP-SESSION-ID. Unavailable IDs SHALL independently be null with reasons reported and unknown models omitted. Human-direct posts SHALL identify the human without fabricated Agent metadata. Relayed substantive reports SHALL preserve source authorship separately.

#### Scenario: Both identifiers are available
- **WHEN** the current posting session has verified native and Xirp identifiers
- **THEN** Author publishes both in their dedicated fields without choosing one instead of the other
- **AND** the identifiers refer to the posting session rather than a source record's author

#### Scenario: Only one identifier is available
- **WHEN** the native or Xirp ID cannot be obtained after the applicable lookup
- **THEN** Author retains the known ID and uses null only for the unavailable field
- **AND** the workflow explains the missing value and completes the remaining authorized operation without asking the user to supply an optional ID

#### Scenario: Session metadata is wholly unavailable
- **WHEN** neither identifier is available from the posting runtime or applicable local metadata
- **THEN** both fields are null and the report explains the actual lookup limits
- **AND** no ID is invented and PR creation is not blocked solely by that absence


### Requirement: Metadata operations do not inherit create publication side effects
Update, reply and close SHALL retain their existing operation scope and MUST NOT stage, commit or push merely because create can publish Git. They SHALL use dual session Author fields when writing applicable current content, preserve unrelated text and history, and retain existing readback and close-scope guarantees. The removed publish operation SHALL remain removed.

#### Scenario: Reviewer posts a reply from a dirty checkout
- **WHEN** github-pr reply is requested while local code changes exist
- **THEN** it appends the requested comment with both Author session fields and no Git publication
- **AND** the current posting identity remains distinct from the implementer referenced in the report

#### Scenario: Description update or close is requested
- **WHEN** the user requests only PR description changes or closure
- **THEN** the operation preserves its existing authorized scope without creating commits or pushing
- **AND** close affects only its PR, preserves branches and leaves linked Issue states unchanged


### Requirement: Reply adds actionable review or fix evidence
Reply SHALL append one shared-frame Review, Changes, Checkpoint or Closure comment with Next actions. Reviews SHALL identify actual version, verdict, findings, checks and limits. Repair replies SHALL map changes to stable Finding IDs and fixing evidence. Only Reviewer verification SHALL resolve findings. Prior comments SHALL remain intact. Checkpoint and closure content SHALL retain their distinct evidence requirements.

#### Scenario: Reviewer reports a defect
- **WHEN** an agent posts a changes-required review
- **THEN** its reply identifies the actual reviewed head and actionable items with impact, evidence or location, and a way to check the fix
- **AND** a todo list is understandable without opening the local Work Item

#### Scenario: Implementer reports fixes
- **WHEN** an implementer posts a repair reply
- **THEN** it maps each addressed finding to what changed, a fixing revision, test results, or an evidenced disagreement
- **AND** pending items remain explicit and no tests are invented

#### Scenario: Review has no findings or cannot finish
- **WHEN** review finds no demonstrated defect or required verification is unavailable
- **THEN** the reply reports pass for the checked scope or blocked with concrete limits, without manufacturing tasks or platform approval


### Requirement: Closing a PR affects only confirmed corresponding Issues
Close SHALL use the shared Closure-before-state-change sequence and close only the selected PR without merging. Direct Issue links SHALL convey work association without closure authority. Linked Issues, dependencies, other PRs and branches SHALL remain unchanged. Already closed or merged PRs SHALL report actual state and receive only missing explicitly authorized summary work.

#### Scenario: PR links both task and dependency Issues
- **WHEN** close targets a PR directly addressing Issue A and depending on Issue B or another PR
- **THEN** only the selected PR is closed after its Closure summary is verified
- **AND** Issues A and B and the dependency PR remain unchanged

#### Scenario: No corresponding Issue or ambiguous relationships
- **WHEN** no corresponding Issue exists
- **THEN** close can close only the PR without creating an Issue
- **AND** uncertain optional Issue links are disclosed and remain untouched

#### Scenario: PR closure fails or Issue closure partially succeeds
- **WHEN** the summary or PR closure cannot be confirmed
- **THEN** no Issue is mutated and summary publication and PR state are reported separately
- **AND** a later invocation reconciles state and attempts only the remaining authorized work

#### Scenario: Target is already closed or merged
- **WHEN** close is requested for an already closed or merged PR
- **THEN** the skill reports its actual existing state without reopening, merging, or repeating a completed closure
- **AND** Issue closure requires its own explicit operation and authorization


## ADDED Requirements

### Requirement: PR closure summary distinguishes merged and abandoned changes
PR Closure SHALL state published or reviewed revision, intended or existing outcome, delivered changes, verification, unresolved findings and follow-up references. Successful implementation handoff SHALL distinguish ready-to-merge from merged. Close MUST NOT merge. A replaced or abandoned PR SHALL explain its replacement or cancellation without treating its underlying Issue as finished.

#### Scenario: Implementation awaits merge
- **WHEN** the reviewed head passes but no merge occurred
- **THEN** Closure says ready for authorized merge without claiming merged or closing the PR as a substitute

#### Scenario: Replaced proposal
- **WHEN** PR A is replaced by PR B while its Issue remains necessary
- **THEN** Closure links PR B, closes only authorized PR A and leaves the Issue open

#### Scenario: Already merged target
- **WHEN** a summary is explicitly requested after merge
- **THEN** the reply records actual merge evidence without another close or invented acceptance

