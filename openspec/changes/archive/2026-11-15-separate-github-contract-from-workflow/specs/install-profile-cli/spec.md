# Spec Delta

## ADDED Requirements

### Requirement: Retired skill acceptance references are removed only when unmodified
install.sh SHALL remove an installed `references/acceptance-cases.md` of the openspec-commit, github-pr, github-issue, git-commit-writer, and change-review skills under `.claude/skills/` and `.agents/skills/` only when the file is byte-identical to a version this installer shipped. A modified or unknown copy, and a symbolic link, SHALL be left in place and reported. No other file or directory SHALL be deleted by this step, and running it again SHALL change nothing.

#### Scenario: Fresh install
- **WHEN** install.sh runs on a project with no earlier installation
- **THEN** none of the five skills has an acceptance-cases file in either skills directory

#### Scenario: Reinstall over an unmodified shipped copy
- **WHEN** a project holds a copy identical to any version the installer shipped, current or earlier
- **THEN** install.sh removes that copy and reports the removal

#### Scenario: Reinstall over a modified copy
- **WHEN** a project's copy differs from every shipped version
- **THEN** install.sh leaves it in place and reports that the cases now live in the source repository's test bank
- **AND** the user decides whether to delete it

#### Scenario: The copy is a symbolic link
- **WHEN** the path is a symbolic link
- **THEN** install.sh leaves it in place and reports it

#### Scenario: Unrelated content is beside the retired file
- **WHEN** the same references directory holds other files, or another skill not in the list has a file with the same name
- **THEN** those files are untouched
- **AND** a references directory is removed only when the retired file was its last entry

#### Scenario: Installer runs twice
- **WHEN** install.sh runs a second time on the same project
- **THEN** it removes nothing further and reports the same kept files
