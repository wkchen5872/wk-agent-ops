## ADDED Requirements

### Requirement: The example implement template commits through git-commit-writer
Every implement prompt in the bundled example role templates, including commented alternatives for other harnesses, SHALL commit each round through the `git-commit-writer` skill instead of running `git commit` directly, passing the round's subject as the skill's `subject` input: `feat(<change>): <summary>` for the first round and `fix(<change>): address <review-id>` for a repair round.

#### Scenario: Claude implementer finishes a repair round
- **WHEN** an implementer opened from the example `claude` template finishes round 2 after review `codex-add-export-r01`
- **THEN** its commit is made through `git-commit-writer` with subject `fix(add-export): address codex-add-export-r01`
- **AND** the commit has `Co-Authored-By: Claude Code <noreply@anthropic.com>` and an `AI-Assisted-By` trailer, not a model name in `Co-Authored-By`

### Requirement: Existing role templates are not overwritten
The installer SHALL keep creating `.agent-handoff/roles.yaml` from the example only when that file does not exist, and the handoff documentation SHALL tell users with an existing file how to update its implement prompt.

#### Scenario: Existing roles.yaml is kept
- **WHEN** the project installer runs and `.agent-handoff/roles.yaml` already exists
- **THEN** the file is left unchanged
- **AND** the handoff documentation explains how to replace its implement prompt with the example's
