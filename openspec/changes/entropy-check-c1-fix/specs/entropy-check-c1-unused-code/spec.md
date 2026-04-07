## MODIFIED Requirements

### Requirement: Unused Bash function detection
The skill SHALL scan `.sh` files for functions that are defined but have no callsite anywhere in the project (including the defining file itself).

#### Scenario: Unused function detected
- **WHEN** a Bash function `foo()` is defined in `file.sh`
- **AND** `foo` appears only once across all `.sh` files in the project (i.e., the definition line itself)
- **THEN** C1 reports a finding: `file.sh: function 'foo' appears unused`

#### Scenario: Self-contained function not flagged as unused
- **WHEN** a Bash function is defined and called within the same `.sh` file
- **THEN** total occurrences across all `.sh` files is ≥ 2
- **AND** no C1 finding is reported for that function

#### Scenario: Used function not reported
- **WHEN** a Bash function is called in at least one other file
- **THEN** no C1 finding is reported for that function

#### Scenario: Findings marked as heuristic
- **WHEN** C1 reports any finding
- **THEN** the finding is labeled "confirm before removing" to indicate possible false positives

### Requirement: Unused Python import detection
The skill SHALL scan `.py` files for import statements where the imported name does not appear in the file body, correctly handling multi-name imports.

#### Scenario: Unused import detected
- **WHEN** a `.py` file contains `import foo` or `from foo import bar` and the name does not appear elsewhere in the file
- **THEN** C1 reports a finding: `file.py: import 'foo'/'bar' appears unused`

#### Scenario: Multi-name import parsed correctly
- **WHEN** a `.py` file contains `from foo import bar, baz`
- **THEN** the extracted name is `bar` (not `bar,`) and checked for usage independently
- **AND** trailing commas are stripped before usage check

#### Scenario: __all__ exemption
- **WHEN** an imported name appears in `__all__` or is a re-export pattern
- **THEN** the import is not flagged
