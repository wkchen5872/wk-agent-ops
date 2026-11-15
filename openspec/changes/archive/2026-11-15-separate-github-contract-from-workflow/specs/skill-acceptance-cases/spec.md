# Spec Delta

## Purpose

Keep the replayable acceptance cases for instruction-only skills in the repository's test bank, where maintainers use them to check that a skill still decides correctly after it is edited, and keep them out of the skills that are shipped to other projects.

## ADDED Requirements

### Requirement: Acceptance cases live in the repository test bank
Replayable acceptance cases for instruction-only skills SHALL be kept under the repository's test directory: one file per skill, one file for cases that span several entries, and the replay method beside them. Each case SHALL state its fixture, simulated responses, expected calls, prohibitions, and verdict, and SHALL carry an identifier that is unique across the whole bank.

#### Scenario: Maintainer edits a skill
- **WHEN** a maintainer changes a skill and wants to check its decisions
- **THEN** the cases for that skill and the replay method are found in the test bank
- **AND** the project's tests read the cases from that location

#### Scenario: A case is incomplete
- **WHEN** a case lacks its fixture, expected calls, prohibitions, or verdict
- **THEN** the project's checks report that case

#### Scenario: Two cases share an identifier
- **WHEN** the same case identifier appears twice anywhere in the bank
- **THEN** the project's checks report the duplicate

### Requirement: Shipped skills carry run-time material only
A shipped skill MUST NOT contain acceptance cases or refer to them. Content an agent needs while running the skill, such as a format or a complete example, SHALL stay in the skill when cases move out. Every reference file of a shipped skill SHALL be named in its SKILL.md together with the condition for reading it.

#### Scenario: Skill is installed in another project
- **WHEN** the skills are installed into a project
- **THEN** no skill directory contains an acceptance-cases file
- **AND** no installed skill file points to one

#### Scenario: A run-time example existed only inside a case
- **WHEN** the only complete example of a report or post is embedded in an acceptance case
- **THEN** the example is placed in the skill's own references before the case leaves the skill
- **AND** the case in the test bank refers to that example instead of being the sole copy

#### Scenario: A reference has no reading condition
- **WHEN** a skill ships a reference file that its SKILL.md does not name with a condition for reading it
- **THEN** the project's checks report that reference

### Requirement: Removing a case is recorded
A case SHALL be removed from the bank only when another case covers the same situation with the same verdict and with every prohibition of the removed case. Each removal SHALL be recorded with the removed identifier, the covering identifier, and the comparison result. Similar cases that exercise different entries SHALL NOT be treated as duplicates.

#### Scenario: A cross-entry case duplicates an entry case
- **WHEN** a cross-entry case and an entry case have the same situation, verdict, and prohibitions
- **THEN** one of them may be removed and the removal is recorded with the identifier that covers it

#### Scenario: Two entries have parallel cases
- **WHEN** the Issue entry and the PR entry each have a case for the same kind of situation
- **THEN** both cases are kept

#### Scenario: The covering case lacks a prohibition
- **WHEN** the candidate covering case does not include a prohibition that the other case states
- **THEN** the other case is kept, or the prohibition is first added to the covering case

### Requirement: A reused case is expanded before removal
A case whose fixture, simulated responses, or expected calls another case reuses by reference SHALL NOT be removed until the referencing case states that content itself. After any removal, every case reference in the bank SHALL resolve.

#### Scenario: Another case reuses the candidate's fixture
- **WHEN** a case states that its fixture or expected calls are the same as the removal candidate's
- **THEN** the candidate is kept, or the referencing case first states that fixture and those calls itself
- **AND** after any removal every case reference in the bank still resolves
