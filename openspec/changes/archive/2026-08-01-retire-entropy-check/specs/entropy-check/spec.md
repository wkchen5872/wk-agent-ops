## REMOVED Requirements

### Requirement: Context detection
**Reason**: The entropy audit is retired because it has not produced useful maintenance decisions.
**Migration**: Remove installed `entropy-check` skills; no replacement is provided.

### Requirement: Audit routing table
**Reason**: The entropy audit and its routing model are retired.
**Migration**: Use focused project tests and purpose-built review tools when needed.

### Requirement: U2 — Docs completeness
**Reason**: Placeholder detection is retired with the entropy audit.
**Migration**: Review documentation as part of the normal change workflow.

### Requirement: U3 — Dead references
**Reason**: Dead-reference detection is retired with the entropy audit.
**Migration**: Use focused link validation when a project demonstrates that need.

### Requirement: O1 — Stale active changes (openspec)
**Reason**: Stale-change reporting is retired with the entropy audit.
**Migration**: Inspect active changes directly with OpenSpec.

### Requirement: Output format
**Reason**: The audit output no longer exists.
**Migration**: None.

### Requirement: Watermark update
**Reason**: The entropy audit no longer keeps execution state.
**Migration**: Installers remove stale `openspec/.entropy-state` files.
