# 批准紀錄

在 PR 上**記錄**設計批准、或**查找並核對**已發布的批准紀錄時讀本檔。是否可以開始實作、哪些使用者指示算數，由 `docs/openspec-workflow.md` 決定；本檔只管紀錄怎麼寫、怎麼找、怎麼和目前的設計比對。手上已有涵蓋這個 Change 的明確使用者指示時，不需要先有 PR 事件。

## 授權與帳號

授權來自可辨識的使用者指示，不能由 repository 權限推導：某個帳號能寫入 repo，不代表使用者同意了哪一件工作。反過來，已經有明確指示時，不要求證明 API 帳號就是使用者本人，也不另設專屬記錄者名單；誰發布了批准紀錄只代表發布帳號。明示的帳號限制仍依 `SKILL.md` 的 Account restriction 處理，候選 PR 自己修改的規範不能放寬它。

## 批准事件

批准事件是一則**獨立的 PR 回覆**（經 `github-pr reply` 發布），不依賴 PR 正文中的批准區塊，新的 Session 可直接從 PR 的留言找到它。外層依 `SKILL.md` 的共用外框（Every post）：Handoff 在前，Next actions 與本輪發布者的 Author 在後，中間是下列 marker 與欄位。

```markdown
<!-- wk-agent-ops:design-approval -->
## Design approval

- status: <approved｜superseded>
- approved_by: <已知且可公開的人類識別；未知時整行省略>
- approved_at: <含時區的時間；只知道日期時寫 YYYY-MM-DD；完全未知則 null>
- approved_scope: <Change／artifacts 範圍>
- artifact_revision: <被批准的設計 commit｜unpublished-snapshot sha256:<digest>（base <HEAD SHA>）>
- source_kind: agent-attested-user-instruction
- source_ref: <來源類型的描述，例如「使用者在對話中的明確批准」>
- recorded_by: Agent-Tool <工具> · Session <reference>（<type>）
- recorded_at: <含時區>
- supersedes: <前一個批准事件 URL｜none>
```

- 這是**交接紀錄**：只有使用者授權把批准發布到 GitHub 時才寫；本地實作不需要先發布它
  （是否可以開始實作見 `docs/openspec-workflow.md`）。
- `approved_by` 選填：只寫已知且適合公開的人類識別，未知就整行省略，不能拿 API 登入帳號
  補填。留言的實際作者只代表發布帳號，不證明真人或委託者是誰。
- `source_kind` 新紀錄用 `agent-attested-user-instruction`（Agent 轉述使用者指示）；使用者
  本人在 PR 留言或原生 Review 屬於 `human-github`。`source_ref` 描述來源，未公開的對話只寫
  不含私人細節的描述，不編造 transcript URL。
- `artifact_revision`：設計已 commit 時寫那個 commit。設計只在本機、尚未 commit（例如
  untracked 的 Change）時，寫 `unpublished-snapshot sha256:<digest>`，並附上當時的 HEAD 作為
  base。不編造 commit 或連結，也不為了取得 commit 而自行 commit 或 push。指紋的算法：在 Change
  根目錄下，依相對路徑排序每個檔案，依序串接「相對路徑、NUL、檔案內容、NUL」後取 SHA-256；
  計算前把 `tasks.md` 的 `- [x]` 還原成 `- [ ]`，所以勾選進度不影響指紋：

  ```bash
  # 執行目錄：專案根目錄
  ( cd openspec/changes/<change-id> && find . -type f | sed 's|^\./||' | LC_ALL=C sort |
    while IFS= read -r f; do
      printf '%s\0' "$f"
      if [ "$(basename "$f")" = tasks.md ]; then
        sed 's/^\([[:space:]]*\)- \[x\] /\1- [ ] /' "$f"
      else cat "$f"; fi
      printf '\0'
    done ) | shasum -a 256
  ```

  另一台機器若沒有這些檔案，就無法核對這個指紋，只能回報「批准的是未發布的本機版本，
  此處無法核對」；之後那些檔案被 commit 或發布時，可以用同樣的算法對該版本重算。
- `approved_at` 用來源的實際精度（只知道日期就寫 `YYYY-MM-DD`，完全未知寫 `null`），
  不以 `recorded_at` 代替。
- 設計有實質改變或使用者撤回授權時，不編輯舊事件：新增一則 `status: superseded` 的事件，
  以 `supersedes` 指向它取代的事件；取得新的指示後，再新增一則 `status: approved` 的事件。
- 舊事件的 `approved_by`、marker 與來源種類照原樣可讀，不要求補欄位或再確認帳號。

## 讀取與核對已發布的紀錄

1. 找已發布的紀錄。新的 PR 沒有正文批准區塊：讀 PR 的留言
   與 Review，找含 `<!-- wk-agent-ops:design-approval -->` 的事件與使用者本人的留言或原生
   Review；舊版 PR 正文的批准區塊若有 `source_ref`，讀它指向的事件。以最新的有效事件為準，
   最新的是 `superseded` 就不能沿用。
2. 核對 `approved_scope` 涵蓋要實作的 Change，並拿**目前工作區的實際內容**（含 staged、
   unstaged 與 untracked）和批准的版本比對，不能只比 commit：
   - `artifact_revision` 是 commit 時：

     ```bash
     git rev-parse --verify -q <artifact_revision>^{commit}
     git diff --quiet <artifact_revision> -- openspec/changes/<change-id>/
     git ls-files --others --exclude-standard -- openspec/changes/<change-id>/
     ```

     第一行找不到這個 commit，代表基線不可得。`git diff`（不帶 `HEAD`）比的是工作區，
     staged 與 unstaged 都會算進去；結束碼 0 是相同，1 是有差異，結束碼大於 1 是工具錯誤。
     第三行列出 untracked 檔案，有任何一個屬於設計範圍就是有差異。
   - `artifact_revision` 是 `unpublished-snapshot` 時：依上面「批准事件」的算法重新計算目前檔案的
     指紋，與紀錄相同才算相同。
   - 差異只差在 tasks 的勾選（`- [ ]` 與 `- [x]`）是進度紀錄，不算設計改變；tasks 的文字、
     其他 artifacts 或新增、刪除的檔案有變，就是實質改變的候選，交由人判斷或取得指示。
     commit 基線下確認「只差在勾選」：

     ```bash
     git diff --quiet <artifact_revision> -- openspec/changes/<change-id>/ \
       ':(exclude)openspec/changes/<change-id>/tasks.md'
     diff <(git show <artifact_revision>:openspec/changes/<change-id>/tasks.md | sed 's/- \[x\] /- [ ] /') \
          <(sed 's/- \[x\] /- [ ] /' openspec/changes/<change-id>/tasks.md)
     ```

     兩者都沒有差異（且沒有 untracked 檔案）才算只有進度改變。
   - 基線不可得、指紋無法計算或工具出錯時，結果是「無法核對」，不能當成相同。這時依當前
     使用者的指示判斷：指示涵蓋目前內容就照常繼續並回報核對限制；只靠舊紀錄時先釐清。

3. 找不到可辨識的使用者指示、範圍不涵蓋、或已被取代 → 這筆紀錄不能作為依據，回報缺少什麼；是否可以
   開始實作依 `docs/openspec-workflow.md` 判斷。

需要發布批准紀錄時（使用者要求記到 PR），依上面的批准事件格式以 `github-pr reply` 新增獨立事件
並回讀；不編輯或刪除舊事件，也不靠改寫 PR 正文表達批准狀態。

## recorded_by 與完整 provenance 欄位

PR 正文與一般回覆的 Author 只有 `SKILL.md` 共用外框的四個欄位。下表的完整欄位用於批准事件的 `recorded_by`，以及審查完整基線。

| 欄位 | 規則 |
| --- | --- |
| role | planner、implementer、publisher、reviewer 等；代發時分別寫作者與 publisher |
| `Agent-Tool` | 實際執行的工具。用於批准事件與完整基線；commit 仍使用既有的 `Co-Authored-By` trailer |
| `AI-Assisted-By` | 當次已知的 root-session model。未知時省略並回報，不猜更細的版本；已知就不省略 |
| Session reference 與 type | 原生 ID 須已知且允許發布，type 為 `runtime` 或 `user-provided`；否則用明示的 alias，或 `unavailable`／`withheld` |
| `Machine-Alias` | 只用已設定的中性別名；沒有就 `null`。不讀取也不發布原始 hostname |
| 時間 | 含時區 |
| revision | 已發布的 commit，或明確的 `unpublished` |

預設揭露範圍：Issue、PR 與 Review 保留實際工具、已知模型與已知的原生與 Xirp Session ID。專案或使用者另有明確的不公開要求時，把該值標為 `withheld` 並保留可用的 alias。
未知的值不從歷史、環境變數或他人紀錄推測。不發布本機絕對路徑、credential，或自行編造
的 provider email。後來的 publisher 或 implementer 不改寫原作者；轉發他人撰寫的報告時
標明原作者。
