# Design

## Context

動機與範圍見 [proposal.md](proposal.md)，來源為 Issue #18。現行契約 §6 將 Author 視為必備外框，要求「方式／人類」，§6.1／6.2／6.6／6.7 與 §7、附錄案例各自重述部分欄位；github-issue／github-pr 也描述人類與 Agent 格式。剛合併的 change-review 已引用共用格式，但 Step 6 仍認得舊的「方式: Agent 協助代發」標記，不能只刪除範例而破壞原作者辨識。

## Goals / Non-Goals

**Goals:** 新內容更精簡；Agent 發布與原報告來源仍可追查；新舊格式皆可讀；不同操作採相同欄位語意。

**Non-Goals:** 不變更 GitHub operation、帳號或授權政策、不證明 GitHub 帳號背後的真人、不移除批准事件中的既有來源／範圍／版本，不把 commit trailer 改成 GitHub 貼文格式。

## Decisions

### 1. 依本次是否有 Agent 參與決定 Author

Agent 協助建立、發布或修改內容時，Author 仍在最後，保留工具、已知模型與雙 Session ID。使用者是人類，不代表 Agent 代發的內容可以標為純人類而省略追蹤資訊；純人類直接發文才可省略 Author，且不產生空段落。

「方式／人類」兩欄從新產生的 Author 移除，不加 `mode`、`publisher-human` 等替代欄位。GitHub UI 顯示的實際帳號照平台紀錄，不複製成委託者身分。

新 Agent Author 範例：

```markdown
## Author

Co-Authored-By: Codex
AI-Assisted-By: gpt-6.1-sol
SESSION-ID: <本次原生 ID 或 null>
XIRP-SESSION-ID: <本次管理 ID 或 null>
```

替代方案是維持人類帳號作可選欄位；未採用，因為仍保留 Issue #18 指出的重複欄位及推定本人風險。

### 2. 保留原報告作者與發布者兩種來源

代發實質 Review／實作報告時，仍以 `原報告作者` 與可核對的來源說明原作者，下面四種 Agent metadata 屬於本次發布者。來源可以是已發布報告，或如實標為 local-only 的紀錄；不能為湊連結自動上傳或發布，正文須足以讓讀者理解結果，不能只貼不可讀的本機路徑。

新格式以原報告作者／來源判斷代發，不需要新的「方式」標籤。讀取舊資料仍接受「方式: Agent 協助代發」；該標記不能單獨證明原作者的 Session，只有發布者可核對時仍不得當成實作者。純粹整合多個來源的摘要保留各來源，不能虛構一個作者完成全部內容。

替代方案是刪除所有作者資訊，完全依賴平台帳號；未採用，因為共用帳號無法區分產生報告與代發的 Agent。

### 3. 缺值規則與新版批准流程保持不變

已知模型維持已知精度，未知模型整行省略並回報；原生／管理 ID 各自查詢、各自為 null，不互填、不把別名當 ID、不從他人紀錄猜模型或 Session。未知作者身分不引入新的帳號確認。

Issue #17 的批准來源、可選 approved_by、版本／快照與操作授權不屬於 Author 的「人類」欄位；本 Change 不以全檔刪字方式去除它們。Issue #19 的 commit 引用留待另外處理。

### 4. 單一契約與讀舊寫新

範本與欄位語意只由 template 契約擁有，入口只描述所需流程與引用。適用所有 Issue／PR body、更新／Review／修正／Checkpoint／Closure；Agent 事件沿用共用 Author，純人類內容使用省略 Author 的例外。明確更新／回覆時只修改獲授權的新內容，舊正文與留言不批次清洗；讀取歷史欄位不表示可以在新內容重新輸出它們。

## TDD Strategy and Verification Boundaries

先針對受影響範本與入口寫有效 Red，再改 template／範例並經 installer 同步。斷言應限定 Author 範本與操作案例，不能用全檔禁止「人類」或「方式」而誤刪批准來源與 legacy fixture。

除了靜態一致性，安排盲讀重播：正常 Agent、未知模型／一個或兩個 Session 缺值、純人類發文、Agent 代人類發布、已知原作者代發、來源不明、只有代發者可核對，以及讀舊格式後追加新留言。涵蓋 Issue 建立／更新／結案與 PR 建立／更新／Review／修正／Checkpoint／Closure。驗證去掉兩欄不會造成通知錯對象或遺失版本與 Finding ID。

跑受影響 handoff／publication／review suites、installer 新裝重裝與三工具入口、本 Change strict validate 與 verify。案例重播和真實 GitHub／Session 寫入分開記錄，沒有明確發布授權時不為測試寫入 GitHub。

## Risks / Trade-offs

- [純人類例外與「Author 必填」舊文衝突] → 同步契約外框、各用途範本與主規格 delta，保留 Agent 情境下的必填規則。
- [刪除舊代發標籤後通知到發布者] → 新的原作者來源與舊標記都可讀，原作者不可核對仍不送。
- [移除過多追蹤資訊或新增同義標籤] → 用正向欄位保留與新內容負向案例驗證，範圍只限兩個多餘欄位。

## Migration Plan

此輪只建立規劃。設計確認後從 template 修改並透過 installer 更新；既有 GitHub 內容、已封存 Change 與歷史驗證報告保持原樣，不回溯修改。回復時還原本次來源修改並重跑 installer；不改動已發表的記錄。
