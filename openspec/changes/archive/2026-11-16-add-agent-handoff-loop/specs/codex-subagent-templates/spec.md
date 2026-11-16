# Spec Delta

## ADDED Requirements

### Requirement: GitHub copy agents use the Terra model
The GitHub PR and GitHub Issue Codex custom agents SHALL be project-owned templates that set `model = "gpt-5.6-terra"` and `model_reasoning_effort = "medium"`, and SHALL be installed identically to their templates.

#### Scenario: GitHub PR agent model configuration is validated
- **WHEN** the GitHub PR Codex template is inspected
- **THEN** its model is `gpt-5.6-terra`
- **AND** its reasoning effort is `medium`

#### Scenario: GitHub Issue agent model configuration is validated
- **WHEN** the GitHub Issue Codex template is inspected
- **THEN** its model is `gpt-5.6-terra`
- **AND** its reasoning effort is `medium`
