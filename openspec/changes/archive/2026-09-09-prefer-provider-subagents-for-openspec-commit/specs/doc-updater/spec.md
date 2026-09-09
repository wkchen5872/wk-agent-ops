## MODIFIED Requirements

### Requirement: Dual-location file sync
The portable `doc-updater` skill SHALL retain its existing name, while the
Claude Code provider-native agent SHALL use the distinct
`doc-updater-agent` name. Their template and installed copies SHALL remain
synchronized through the common installer.

#### Scenario: Template source exists
- **WHEN** the change is implemented
- **THEN** both `template/common/.claude/agents/doc-updater-agent.md` and `.claude/agents/doc-updater-agent.md` contain identical content
- **AND** the obsolete `.claude/agents/doc-updater.md` installed file is absent

#### Scenario: Skill template source exists
- **WHEN** the change is implemented
- **THEN** both `template/common/skills/doc-updater/SKILL.md` and `.claude/skills/doc-updater/SKILL.md` contain identical content
- **AND** the skill remains available as `doc-updater`
