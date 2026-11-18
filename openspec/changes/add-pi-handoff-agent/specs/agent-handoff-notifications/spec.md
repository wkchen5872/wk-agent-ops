# Spec Delta

## ADDED Requirements

### Requirement: Notifications for Pi records show the provider and billing
For a record that has an `agent` section with `harness: pi`, the handoff notification SHALL take the agent parts from that section instead of from Xirp, in the form `Agent Handoff (Pi / <provider>/<model> / <effort> / <billing>)`, where `<billing>` is shown as `訂閱` for `subscription` and `API` for `api`. The agent parts SHALL be shown for manual runs and retries as well, because they come from the record. A value recorded as `unknown` SHALL be shown as `unknown`.

#### Scenario: Pi implementer on a subscription
- **WHEN** a record's `agent` section is `pi`, `openai-codex`, `gpt-6.2-sol`, `high`, `subscription`
- **THEN** the notification shows `Agent Handoff (Pi / openai-codex/gpt-6.2-sol / high / 訂閱)`

#### Scenario: Retry of a Pi record
- **WHEN** a Pi record whose delivery failed is retried by a manual foreground run
- **THEN** the notification still shows the agent parts from the record

#### Scenario: Mismatch notice shows the recorded billing
- **WHEN** a Pi record shows `billing: unknown` and routing stops for the mismatch
- **THEN** the attention notification shows `unknown` as the billing
