## ADDED Requirements

### Requirement: Doctor checks the Herdr app host
For each host `herdr-app` in use, the `host` checks SHALL confirm that the `herdr-app` and `hc` commands exist, that herdr-core is running, and that the Herdr app window is open, in that order. Each missing piece SHALL be a `fail host` line that says what is missing and how to fix it; when all pass, the line SHALL be `ok` and show the herdr-core version.

#### Scenario: Herdr app is closed
- **WHEN** a role uses `host: herdr-app`, herdr-core is running, and the Herdr app window is not open
- **THEN** a `fail host` line says the Herdr app is not open and asks the user to open it

#### Scenario: herdr-core is not running
- **WHEN** a role uses `host: herdr-app` and `hc server status` fails
- **THEN** a `fail host` line says herdr-core is not running

#### Scenario: A command is missing
- **WHEN** a role uses `host: herdr-app` and `herdr-app` is not installed
- **THEN** a `fail host` line names the missing `herdr-app` command

#### Scenario: Herdr app is ready
- **WHEN** a role uses `host: herdr-app` with both commands present, herdr-core running, and the app open
- **THEN** the host lines are `ok` and show the herdr-core version
