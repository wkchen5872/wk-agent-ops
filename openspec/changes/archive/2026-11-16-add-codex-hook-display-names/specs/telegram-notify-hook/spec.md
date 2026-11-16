# Spec Delta

## ADDED Requirements

### Requirement: Codex notification hooks have display names

The notification installer SHALL write a non-empty `statusMessage` on each owned Codex handler. The defaults SHALL be `Telegram 完成通知` for Stop, `Telegram 操作確認與等待檢查` for PermissionRequest, `Telegram 同步問題等待檢查` for question PreToolUse, and `Telegram 非同步問題通知` for async-question PostToolUse. The field SHALL be on the handler alongside `type` and `command`.

#### Scenario: First Codex registration is named

- **WHEN** notification registration runs with no owned Codex handlers present
- **THEN** each of the four owned handlers is registered once with its documented default `statusMessage`
- **AND** existing event names, matchers, commands, timeout values, and neutral runtime behavior remain unchanged

### Requirement: Registration fills missing Codex notification names

Ordinary notification installation and repeated registration SHALL fill absent, null, empty, or whitespace-only `statusMessage` values on matching owned Codex handlers. Registration SHALL preserve non-blank custom names and all other existing fields. It MUST NOT rename unrelated handlers or duplicate existing registrations.

#### Scenario: An existing handler has no usable name

- **WHEN** registration finds an owned handler with absent, null, empty, or whitespace-only `statusMessage`
- **THEN** it fills that handler's documented default name without replacing the handler or its matcher group

#### Scenario: The user already named a handler

- **WHEN** registration finds an owned handler whose `statusMessage` is `我的完成提醒`
- **THEN** the value remains `我的完成提醒` and no duplicate handler is added

#### Scenario: Repeated registration converges

- **WHEN** registration runs twice on a configuration containing unnamed owned handlers, named owned handlers, and unrelated handlers
- **THEN** the second run leaves the JSON configuration semantically unchanged
- **AND** unrelated handlers and top-level configuration remain unchanged on both runs

### Requirement: Explicit notification repair restores default Codex names

The explicit `fix-hooks` repair SHALL recreate owned Codex notification handlers with their documented default names. Its documentation SHALL distinguish this reset from ordinary registration, which preserves custom names. Repair SHALL preserve unrelated hooks and MUST NOT approve, enable, or bypass Codex hook trust.

#### Scenario: Explicit repair rebuilds named handlers

- **WHEN** `fix-hooks` repairs an existing installation with a custom-owned notification name
- **THEN** the recreated handler has its documented default `statusMessage`
- **AND** unrelated hooks remain intact and the user is directed to review Codex hooks

### Requirement: Naming changes preserve other notification providers

Adding Codex display names SHALL leave the existing Claude Code, Antigravity, and Copilot notification registration formats and behavior unchanged. Notification registration MUST NOT add Codex naming fields to another provider's handlers.

#### Scenario: Multiple providers are configured

- **WHEN** notification registration runs with Codex and other supported providers configured
- **THEN** Codex handlers receive names while other providers retain their existing registration fields and behavior
