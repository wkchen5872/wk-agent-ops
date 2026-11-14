## ADDED Requirements

### Requirement: Completion forwards confirmed direct GitHub references to the commit writer
Before commit delegation, the coordinator SHALL retain confirmed directly addressed Issue and PR associations from the selected work and pass them, with repository identity and evidence, to the writer alongside existing archive and attribution context. Missing optional references MUST NOT block local completion or authorize additional GitHub actions. Background or conflicting associations SHALL be excluded and reported.

#### Scenario: Existing PR and Issue are known
- **WHEN** completion has confirmed directly addressed Issue and PR URLs for the selected Change
- **THEN** both are passed to the commit writer without losing archive_path, change_id or root-session attribution
- **AND** the resulting nonempty commit retains those references under the writer's formatting rules

#### Scenario: Local-only completion lacks GitHub access
- **WHEN** local completion has no confirmed association and remote access is unavailable or outside authorization
- **THEN** archive, docs and commit may complete without a GitHub lookup or placeholder reference
- **AND** the report distinguishes unknown associations from a known absence

#### Scenario: Previously known associations remain usable offline
- **WHEN** the selected Change has confirmed direct target URLs and completion is local-only
- **THEN** the coordinator retains the verified associations without requiring fresh remote authentication solely for commit metadata
- **AND** those URLs do not authorize publication or state changes

#### Scenario: Recovery finds an existing completion commit
- **WHEN** the completion workflow resumes after its commit already exists
- **THEN** it reuses that commit without amending or duplicating it to add a subsequently discovered reference
