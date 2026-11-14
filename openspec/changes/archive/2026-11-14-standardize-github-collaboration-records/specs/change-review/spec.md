# Spec Delta

## MODIFIED Requirements

### Requirement: Reports use the shared handoff contract
Review reports SHALL follow the shared schema, native-tool operation checks, optional account restrictions, provenance, and ownership rules. An available configured gh or GitHub MCP SHALL perform PR operations without a custom identity script or blob. Each round SHALL record phase, revision, scope, verdict, checks, limits, findings, Next actions, shared Author and verified publication results. The reviewer MUST NOT overwrite others' records or invoke PR create or publish.

#### Scenario: Publishing feedback
- **WHEN** review feedback is ready and remote publication is authorized
- **THEN** the reviewer uses the selected available tool after confirming the target, authorization, required capability, and any applicable explicit account restriction
- **AND** it does not stage, commit, push, change product code, or call the PR create or publish path

#### Scenario: Blocked review can still be reported
- **WHEN** necessary verification is blocked but the PR is identified and report publication is authorized and available
- **THEN** the reviewer publishes the blocked verdict with the known revision, missing evidence, owner, and next action
- **AND** an inability to complete verification is not silently treated as an inability to publish a report

#### Scenario: Remote publication fails
- **WHEN** a completed report cannot be posted because of tool, identity, or permission failure
- **THEN** the reviewer preserves an authorized local draft or returns the report and records publication as incomplete
- **AND** it does not fabricate a report URL or announce that remote handoff completed

#### Scenario: gh is unavailable but MCP can publish
- **WHEN** gh is unavailable but a configured MCP can perform the authorized review publication
- **THEN** the reviewer may use that MCP after its own target and operation checks
- **AND** the absence of a custom identity script or account policy does not block publication

#### Scenario: Required capability or explicit account compliance is unavailable
- **WHEN** no configured tool can publish, the write is explicitly denied, or a mandatory account restriction cannot be satisfied
- **THEN** the report remains unpublished with the concrete limitation recorded
- **AND** a different tool's login is not substituted for evidence about the selected connection

#### Scenario: Publication times out and another channel is available
- **WHEN** the first write has an unknown result
- **THEN** the reviewer reconciles the actual PR report state before retrying through any channel
- **AND** it does not duplicate the report or invent a successful URL

#### Scenario: Write reports success but readback cannot confirm it
- **WHEN** a tool returns success and a report URL but readback fails or the stored target, review ID, phase, head, or content differs
- **THEN** publication is recorded as possibly completed but unconfirmed, separately from the technical verdict
- **AND** the reviewer reconciles state before retrying and does not announce verified remote handoff


### Requirement: Failed PR reviews are appended through github-pr reply
For an identified PR, remote review invocation SHALL authorize a Review reply for pass, changes-required or blocked unless local-only or another explicit restriction excludes publication. The workflow SHALL read back reports and preserve PR history. Verdict, publication and notification SHALL remain separate. Pass SHALL NOT trigger repair notification.

#### Scenario: PR review does not pass
- **WHEN** a confirmed PR receives changes-required or blocked and publication is permitted
- **THEN** github-pr reply appends the reviewed version, findings, checks and limits using the shared Handoff and Author frame
- **AND** the workflow reads back the specific report and does not modify the PR body or earlier comments

#### Scenario: PR review passes or publication was excluded
- **WHEN** review passes during authorized remote review, or the user explicitly requests local-only review
- **THEN** remote pass is posted and read back, while a local-only result is returned directly
- **AND** neither path exceeds the publication restriction or sends a repair notification for pass

#### Scenario: Report publication fails or is uncertain
- **WHEN** reply is denied, unavailable, times out, or cannot be confirmed by readback
- **THEN** the technical verdict remains recorded separately from publication status and the report is returned with the concrete limit
- **AND** no blind duplicate reply or notification claiming confirmed publication is sent

