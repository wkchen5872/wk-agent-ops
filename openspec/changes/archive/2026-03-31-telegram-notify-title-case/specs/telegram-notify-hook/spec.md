## MODIFIED Requirements

### Requirement: 訊息排版
Task Complete 通知的標題 SHALL 為 `🟢 **Task Complete**`（首字大寫，其餘小寫）。

#### Scenario: Task Complete 訊息格式
- **WHEN** Stop 或 AfterAgent event 觸發
- **THEN** 訊息標題為 `🟢 **Task Complete**`
