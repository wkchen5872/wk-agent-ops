## MODIFIED Requirements

### Requirement: 訊息排版
Action Required 的狀態圖示 SHALL 為 🟠（橙色），標題為 `🟠 **Action Required**`。

#### Scenario: Action Required 訊息格式（含 message）
- **WHEN** Notification event 觸發，stdin JSON 含 `message` 欄位
- **THEN** 訊息標題為 `🟠 **Action Required**`（橙色圖示）

#### Scenario: Action Required 訊息格式（無 message）
- **WHEN** Notification event 觸發，stdin JSON 無 `message` 欄位
- **THEN** 訊息標題為 `🟠 **Action Required**`（橙色圖示）
