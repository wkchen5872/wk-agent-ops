# Spec Delta

## MODIFIED Requirements

### Requirement: Successful PR handoff uses the verified final published version
Authorized successful PR delivery SHALL confirm the intended head repository and ref, publish through normal Git push when needed, and read back the actual head before describing it. A ready-to-merge Closure SHALL require sufficient review evidence for the final published content. New content MUST NOT inherit an earlier pass. A missing or failed final review SHALL stop the ready-to-merge claim without undoing local completion.

#### Scenario: Final reviewed head is published
- **WHEN** authorized publication is confirmed and valid review evidence covers the actual PR head
- **THEN** the workflow updates the authorized PR description and posts a version-bound Closure through github-pr reply with readback
- **AND** it leaves merge, deployment and independent Issue acceptance unperformed

#### Scenario: Archive or documentation changes the head
- **WHEN** completion creates content not covered by the prior review
- **THEN** the workflow obtains one authorized review round or reports that the final revision needs review before claiming ready to merge
- **AND** it does not auto-repair, poll or copy the old pass to the new head

#### Scenario: Push fails or head moves
- **WHEN** push is rejected or the observed PR head differs from the intended reviewed version
- **THEN** the workflow reports the confirmed commit and the publication or version limit
- **AND** it does not force push, describe unpushed content as published or attest readiness for a different head

#### Scenario: Original PR is already merged
- **WHEN** completion creates new commits after the original PR was merged
- **THEN** the workflow reports the PR's actual state and that the new commits need a separately authorized follow-up PR, or reports them as pending handoff
- **AND** pushing to the old branch is not reported as a completed review or merge, and the merged PR is not reopened
