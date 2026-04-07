# entropy-check-d3-autofix

## Purpose

D3 is the broken markdown link audit sub-check for entropy-check. It scans `.md` files in `docs/` and `AGENTS.md` for local file and anchor links that do not resolve, and offers intelligent auto-fix by searching for the referenced filename within the project.

## Requirements

### Requirement: Markdown link validation
The skill SHALL scan all `.md` files in `docs/` and `AGENTS.md` for `[text](target)` links and validate that targets exist.

#### Scenario: Broken local file link detected
- **WHEN** a `.md` file contains `[text](./path/file.md)` and `path/file.md` does not exist
- **THEN** the audit reports a D3 finding with file path and broken link target

#### Scenario: External links skipped
- **WHEN** a link target starts with `http://`, `https://`, or `mailto:`
- **THEN** the link is skipped (not validated)

#### Scenario: Broken anchor detected
- **WHEN** a link contains `#anchor` and the target file does not have a heading matching the anchor
- **THEN** the audit reports a D3 finding with the broken anchor reference

#### Scenario: Same-file anchor validated
- **WHEN** a link is `[text](#section)` with no file path
- **THEN** the anchor is validated against headings in the same file

### Requirement: D3 auto-fix for broken links
The skill SHALL offer auto-fix for broken file references found during D3 audit.

#### Scenario: Auto-fix single match
- **WHEN** a broken link target's filename matches exactly one file in the project
- **THEN** auto-fix updates the link path in-place to the found location

#### Scenario: Auto-fix zero matches — remove link
- **WHEN** a broken link target's filename matches no files in the project
- **THEN** auto-fix replaces `[text](broken-path)` with just `text` (removes link, keeps label)

#### Scenario: Auto-fix multiple matches — defer to human
- **WHEN** a broken link target's filename matches more than one file in the project
- **THEN** auto-fix reports the candidates and leaves the original unchanged for human resolution

#### Scenario: Auto-fix backtick paths
- **WHEN** a backtick-quoted path like `` `scripts/old/path.sh` `` does not exist
- **THEN** auto-fix searches for the filename and updates the backtick reference using the same single/zero/multiple-match logic
