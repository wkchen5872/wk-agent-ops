## ADDED Requirements

### Requirement: Apply the shared authoring contract
The doc-updater skill and provider agents SHALL load the shared documentation authoring policy before editing. They SHALL discover related nested module docs, examples, diagrams and links, classify document purpose, and apply the relevant contract without duplicating that policy in each entrypoint.

#### Scenario: API change affects module documentation
- **WHEN** an API change affects a nested module document and its examples or diagrams
- **THEN** the updater reads those related artifacts and applies API completeness and consistency checks
- **AND** unrelated documents remain unchanged

#### Scenario: Stale design text in an affected section
- **WHEN** current evidence contradicts old design prose or its diagram
- **THEN** the updater reconciles the affected statements and figure while retaining necessary technical rationale and verification limits
- **AND** it does not append a conversation narrative as the explanation

#### Scenario: Equivalent provider entrypoints
- **WHEN** the portable skill, Claude agent or Codex agent performs documentation updates
- **THEN** each follows the same shared policy and reports actual validation separately from unperformed checks
- **AND** existing mode selection and no-automatic-commit behavior are preserved
