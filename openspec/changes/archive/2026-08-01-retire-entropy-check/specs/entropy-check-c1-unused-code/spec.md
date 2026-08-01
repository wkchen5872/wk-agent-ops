## REMOVED Requirements

### Requirement: Unused Bash function detection
**Reason**: C1 unused-code detection is retired with the entropy audit.
**Migration**: Use a language-specific analyzer only when a project needs one.

### Requirement: Unused Python import detection
**Reason**: C1 unused-code detection is retired with the entropy audit.
**Migration**: Use the project's Python analyzer when configured.

### Requirement: Unused TypeScript/JavaScript import detection
**Reason**: C1 unused-code detection is retired with the entropy audit.
**Migration**: Use the project's TypeScript or JavaScript analyzer when configured.

### Requirement: No auto-fix for C1
**Reason**: The C1 audit no longer exists.
**Migration**: None.
