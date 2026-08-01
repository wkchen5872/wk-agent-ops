## REMOVED Requirements

### Requirement: Archive event detection
**Reason**: The entropy archive counter is retired.
**Migration**: Existing hook registrations are removed during workflow upgrade.

### Requirement: Threshold-based notification
**Reason**: Entropy threshold notifications are retired.
**Migration**: No replacement is provided.

### Requirement: Telegram notification (optional)
**Reason**: Entropy-specific Telegram notifications are retired.
**Migration**: General workflow notifications remain independent of this feature.

### Requirement: Installation
**Reason**: The entropy counter is no longer distributed.
**Migration**: Re-run the workflow installer to remove legacy registrations and deployed files.
