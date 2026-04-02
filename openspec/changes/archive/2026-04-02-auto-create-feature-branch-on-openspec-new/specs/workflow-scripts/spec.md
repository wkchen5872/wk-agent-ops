## ADDED Requirements

### Requirement: workflow install.sh deploys hook as part of standard setup
`scripts/workflow/install.sh` SHALL call `openspec-branch-creator/install.sh` as part of the standard workflow setup so that one command installs everything.

#### Scenario: Running install.sh installs both scripts and hook
- **WHEN** `bash scripts/workflow/install.sh` is executed
- **THEN** wt-work, wt-done, wt-resume, pm-start are installed AND the openspec-branch-creator hook is deployed and registered in settings.json

### Requirement: wt-work-flow.md documents the branch resolution flow
A new file `docs/workflow/wt-work-flow.md` SHALL exist with a Mermaid flowchart illustrating the three branch resolution paths in `wt-work.sh`, plus an explanation of the cross-machine scenario.

#### Scenario: Doc is present and contains a Mermaid diagram
- **WHEN** `docs/workflow/wt-work-flow.md` is read
- **THEN** the file contains a `flowchart` or `graph` Mermaid block covering local-branch, remote-branch, and new-branch paths

### Requirement: wt-done documentation notes local-only scope
The workflow documentation SHALL include an explicit note that `wt-done` handles only local branch merges and does not support team workflows (remote push, PR creation, code review).

#### Scenario: Local-only note is present in docs
- **WHEN** `docs/workflow/guide.md` or the wt-done section of the README is read
- **THEN** a visible warning or note states that wt-done is local-only and team/remote workflows are a future TODO
