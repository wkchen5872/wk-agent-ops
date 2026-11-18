# Spec Delta

## ADDED Requirements

### Requirement: Handoff events are delivered through the notification hook
The notification hook SHALL accept handoff events from the handoff routing hook, render each kind from its own template, and apply the handoff switches itself. Attention events SHALL be delivered whenever Telegram delivery is enabled, independent of the category switches and of `NOTIFY_LEVEL`. The sender MUST NOT need an environment override to have a handoff event delivered.

#### Scenario: Attention event with other categories off
- **WHEN** every category switch is off, Telegram delivery is enabled, and a handoff attention event arrives
- **THEN** the attention message is sent

#### Scenario: Progress event with its switch off
- **WHEN** `NOTIFY_HANDOFF_FINISH=false` and a handoff finish event arrives
- **THEN** no message is sent

#### Scenario: Attention event without a usable template
- **WHEN** a handoff attention event arrives and its template or table entry is missing
- **THEN** the attention message is still sent with a built-in fallback text

#### Scenario: Handoff event uses its own template
- **WHEN** a handoff review event arrives
- **THEN** the message is rendered from the handoff review template, not from the waiting-for-response template

### Requirement: Settings menu lists the handoff switches
The category menu SHALL list the three handoff switches — 交件單實作完成, 交件單每輪審查, 交件單收尾 — with their on or off state, and SHALL state that notices needing the user are always sent. Saving SHALL write the three keys without changing other keys.

#### Scenario: Handoff switch saved
- **WHEN** the user turns off 交件單實作完成 and saves
- **THEN** the config holds `NOTIFY_HANDOFF_IMPLEMENT=false` and every other key is unchanged
