# Skill 驗收題庫

指令型 Skill 沒有可執行的程式碼，修改後只能以可重播的案例檢查 Agent 的決策是否改變。這些案例是本 repo 的開發期測試資產，不隨 Skill 安裝到其他專案；執行時需要的格式與完整範例都在各 Skill 自己的 `SKILL.md` 與 `references/`。

## 檔案

| 檔案 | 內容 | 代號 |
| --- | --- | --- |
| [shared.md](shared.md) | 跨入口的共同案例：寫入核對、工具與帳號、批准紀錄、Author、交接與結案 | `C-NN` |
| [github-issue.md](github-issue.md) | `github-issue` 的 create、update、close | `GI-NN` |
| [github-pr.md](github-pr.md) | `github-pr` 的 create、update、reply、close | `GP-NN` |
| [change-review.md](change-review.md) | `change-review` 的入口、版本、檢查、發布與交接 | `CR-NN` |
| [openspec-commit.md](openspec-commit.md) | `openspec-commit` 的本地完成、交付、放棄與恢復 | `OC-NN` |
| [git-commit-writer.md](git-commit-writer.md) | `git-commit-writer` 的 commit 範圍與 GitHub 引用 | `WC-NN` |

`tests/test_acceptance_bank.sh` 檢查題庫的結構；其他 `tests/test_*.sh` 以案例標題作為各需求的回歸錨點。

## 案例格式

每個案例以 `### <代號> <標題>` 開頭，代號在整個題庫中唯一，並包含：

| 欄位 | 內容 |
| --- | --- |
| Fixture | 輸入情境：repository、Change、分支、工作區與遠端的既有狀態 |
| 模擬回覆 | 固定的 `gh`、MCP、`git` 回覆，重播時不實際執行 |
| 預期呼叫 | 依序列出應提出的 `gh`／MCP／`git` 呼叫與關鍵參數 |
| 禁止 | 出現任何一項即失敗的呼叫或聲明 |
| 判定 | pass 的條件 |

案例可以寫「同 X-NN」沿用另一案的 Fixture、模擬回覆或預期呼叫；被沿用的案例必須存在。

## 重播方式

以正常啟動的 Agent Session 讀取受測 Skill 與案例的 Fixture、模擬回覆，請它說明接下來會提出的呼叫與回報；再逐項比對預期呼叫、禁止與判定。出現任何禁止項目就是失敗。記下實際使用的工具與模型。

驗證 Skill 是否自足時，重播只提供受測 Skill 的目錄，不提供其他 Skill 或整合說明。

重播是離線的決策驗收。模擬回覆不能用來宣稱真的查過帳號、發過 PR 或呼叫過工具；真實的 GitHub 操作另在明確授權的測試 repository，以當下可用的通道執行。沒有實測的通道如實列為未驗證，不為了湊驗收而安裝工具或登入。

## 重播結果放哪裡

重播與驗證的結果只寫在兩個地方，不在 `docs/` 建立驗證文件：

- **本機 Work Item**：依 `work-items/AGENTS.md`，寫在處理該 Change 的 Work Item 中自己的紀錄（`agents/` 或 `reviews/`）。它是本機暫存，可隨 Work Item 清理。
- **GitHub PR**：需要讓團隊看到時，以 `github-pr reply` 發布在對應的 PR。

內容至少有案例檔的版本、去敏後的輸入、實際回覆或呼叫摘要、與預期的差異、每個案例的結果，以及已知限制。預期判定在重播前寫下，之後不為了追認結果而修改。

## 去重對照

只有同時符合下列三項才刪除案例，預設保留：

1. 題庫中另有一案具有相同的情境與相同的判定。
2. 該案的禁止項目涵蓋被刪案例的全部禁止項目。
3. 沒有其他案例以「同 X」沿用被刪案例的內容；有的話，先在引用案例中寫出沿用的內容。

相似但屬於不同入口的案例（例如 Issue 與 PR 各自的同類情境）不算重複。

| 候選 | 比對對象 | 結果 | 依據 |
| --- | --- | --- | --- |
| C-16 | CR-42 | 保留 | 準則 2：CR-42 沒有 C-16 的「重新 archive」「建立空 commit」兩項禁止。準則 3：C-17 以「同 C-16」沿用其 Fixture 與預期呼叫 |
| C-18 | OC-16 | 保留 | 準則 2：OC-16 的禁止只有「宣稱已審查」，沒有 C-18 的「宣稱已合併」。情境也不同：C-18 是一般交付整理，OC-16 先經過 openspec-commit 的本地三步 |
| C-05 | CR-08 | 保留 | 準則 2：CR-08 沒有 C-05 的「在報告或輸出中寫入 token 或認證設定」 |
| C-20 | CR-15 | 保留 | 準則 1：C-20 是 Issue 留言，CR-15 是 PR 審查回覆，屬於不同入口。準則 2：CR-15 沒有「擴大授權範圍」 |
| C-21 | GI-15 | 保留 | 準則 1：C-21 的判定另要求回報缺少的權限。準則 2：GI-15 沒有「換帳號」，換工具的禁止也只限 MCP |
| C-35 | GI-49 | 刪除 | 情境相同（以 not planned 關閉 #42，摘要成功、close 被拒、補權限後重跑），判定相同；GI-49 的禁止涵蓋 C-35 的全部四項並另有「共同禁止」與「換帳號」；沒有案例沿用 C-35 |
