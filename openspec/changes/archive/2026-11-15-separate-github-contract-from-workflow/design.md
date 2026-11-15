# Design

## Context

動機見 proposal.md 的 Why。以下是影響做法的現況，全部來自實際讀取來源檔與執行查詢：

- `template/common/docs/github-handoff.md` 共 1375 行。`github-pr` 的 SKILL.md 開頭寫明「`docs/github-handoff.md` owns every template, field meaning, and rule… Read that contract first — sections 3, 4, 5, 6, 6.2, 6.3, 6.6, 6.7, 8, 9 and 11」；`github-issue` 也有相同的依賴。
- 現行 SKILL.md 行數：`github-issue` 389、`github-pr` 493、`change-review` 334、`openspec-commit` 539、`git-commit-writer` 278。兩個 GitHub 入口已用自己的文字寫了目標核對、工具選擇與回讀步驟，缺的是範本、Author 規則、帳號限制、Checkpoint、Closure 與批准紀錄。
- 驗收案例共 303 個：`github-issue` 50、`github-pr` 66、`change-review` 91、`openspec-commit` 31、`git-commit-writer` 16，加上契約附錄 A 的 49 個。全部都有 Fixture、預期呼叫、禁止與判定，沒有重複代號。
- 出貨的執行檔對題庫的引用只有 SKILL.md 的「Replay cases」指向與三份 `examples.md` 開頭的一句話。唯一的例外是 `change-review`：它沒有 `examples.md`，完整報告的寫法只存在題庫的 CR-60 至 CR-63。
- `scripts/skills/install.sh` 以 `rsync -a` 同步 Skills，不會刪除來源已不存在的檔案。五份題庫在 Git 歷史中共有 27 個不同的出貨版本（`change-review` 10、`github-pr` 9、`github-issue` 5、`openspec-commit` 2、`git-commit-writer` 1）。installer 已有一個先例：`scripts/github/check-identity.sh` 只在與出貨版本的 blob 相同時才移除。
- 三支測試腳本共有 55 行讀取題庫，用途有三種：檢查特定案例標題存在、把題庫當成內容探針（例如檢查 `XIRP-SESSION-ID` 是否出現）、把題庫當成「重裝會覆寫舊檔」的探針。
- `docs/workflow/local-development.md` 的 01 階段與 `docs/diagrams/local-development-define.svg` 都寫「先建立 Change，再依需要建立 Issue」。managed 的 `docs/diagrams/github-handoff.svg` 第一步是「建立 OpenSpec Change」、第二步是「github-issue create」。
- `docs/openspec-workflow.md` 第 3 節已有 Apply 授權的核心規則，第 5 節已有 archive、commit、merge、deployment 各自獨立的規則。
- `docs/agent-protocol.md` 第 1 節、rule `github-handoff.md` 與 seed `AGENTS.md` 都要求操作 Issue／PR 前先讀 `docs/github-handoff.md`；`tests/test_github_handoff.sh` 有一個斷言檢查「AGENTS.md → protocol → contract」這條鏈可達。
- Skills、rules 與 managed 文件只能改 `template/`，再由 installer 安裝。本 repo 沒有 pre-commit hook，完整檢查是執行 `tests/` 下所有 `test_*.sh`。

## Goals / Non-Goals

**Goals:**

- 每個入口 Skill 自足：只靠該 Skill 與它自己的 references 就能完成操作。
- `docs/github-handoff.md` 只說明個人流程如何接上 GitHub 協作。
- 驗收題庫不隨 Skill 出貨；既有安裝的舊副本被安全地移除。
- 開立規格階段有 Issue-first 與 Change-first 兩個入口。
- 每條離開契約的規則都有具名的接收者；Review 與封存交付的行為不變。

**Non-Goals:**

- 改變任何貼文格式、欄位、Author 內容或操作的副作用。
- 改變 Review 與封存交付的順序、授權或結案條件。
- 為前兩個階段新增整合用的 Skill。
- 新增「只安裝 GitHub 入口」的 installer profile。
- 改寫案例的判定內容；本次只搬移與去重。
- 測試真實的 GitHub 寫入。

## Decisions

### D1. 持有關係反轉

```
現在                                  之後
----                                  ----
github-issue --+                      github-handoff.md（整合說明）
github-pr -----+--> github-handoff.md     | 說明何時呼叫、交接什麼
change-review -+    擁有全部格式         v
openspec-commit+    與流程規則        github-issue    github-pr
                                      各自持有格式、Author、核對
                                              ^
                                      change-review / openspec-commit
                                      透過既有的呼叫關係使用
```

判斷準則：回答「這則 Issue／PR／留言要怎麼寫、怎麼安全地寫入與讀回」的內容屬於執行該操作的 Skill；回答「流程的哪個時點要用 GitHub、用哪個入口、帶什麼資訊」的內容屬於整合說明；回答「現在可不可以進到下一階段」的內容屬於 `docs/openspec-workflow.md`。

替代方案是保留契約擁有格式、只移走流程規則（本 Change 的前一版設計）。不採用：Skill 仍要先讀一份外部大文件，整合說明也無法成為單純的流程銜接說明。

### D2. 契約各節的接收者

| 契約章節 | 行數 | 接收者 |
| --- | --- | --- |
| 開頭、§1 定位與範圍 | 18 | 整合說明的開頭（改寫）。操作邊界（只有 create 發布 Git、close 只處理指定目標）已在兩個 Skill 的操作表 |
| §2 前置條件 | 11 | `github-issue`、`github-pr` 的 SKILL.md |
| §3 寫入前的核對 | 27 | 兩個 Skill 的共同步驟（已有目標、工具與回讀步驟，補齊缺少的句子）。protocol 第 1 節保留一句最低要求 |
| §4.1 工具與認證分工、不輸出 credential | 20 | 兩個 Skill 的 SKILL.md |
| §4.2 明示的帳號限制 | 15 | 兩個 Skill 的 SKILL.md |
| §4.3 授權來自使用者指示 | 7 | `openspec-workflow.md` §3；「發布帳號不證明身分」隨批准紀錄到 `github-pr` |
| §5 關聯與既有紀錄 | 54 | Issue 的查重與關聯到 `github-issue`；PR 的關聯、fork 與既有 PR 到 `github-pr`；舊版標記的可讀性到兩者的 `examples.md` |
| §6 共用外框（Handoff、Next actions、Author） | 95 | 兩個 Skill 各持有一份，見 D4 |
| §6.1 Issue | 97 | `github-issue` |
| §6.2 PR 正文與審查、修正回覆 | 134 | `github-pr` |
| §6.3 批准事件 | 55 | `github-pr` 的 `references/approval-records.md` |
| §6.4 完整審查基線 | 58 | Finding 四種狀態的定義進入 D4 的審查識別區塊（`github-pr` 與 `change-review` 各一份）；完整基線表格到 `change-review` 的 `references/examples.md` |
| §6.5 可轉交訊息 | 16 | `change-review` 的 SKILL.md |
| §6.6 Checkpoint | 42 | 兩個 Skill（update／reply 的一種內容） |
| §6.7 Closure | 60 | 兩個 Skill（close）；`openspec-commit` 沿用既有的 `github-pr` 呼叫 |
| §7 Provenance | 23 | Author 規則隨共用外框；完整欄位表隨批准紀錄與審查基線到 `github-pr` 與 `change-review` |
| §8 Review 識別與 Finding | 22 | verdict、phase、review-id、Finding ID 進入 D4 的審查識別區塊（`github-pr` 與 `change-review` 各一份）；Accepted Finding 連到正式待辦、審查執行步驟與發布授權只到 `change-review` |
| §9 人類設計批准 | 73 | 授權判斷到 `openspec-workflow.md` §3；紀錄的發現與版本比對到 `github-pr` 的 `approval-records.md` |
| §10 流程與人工斷點 | 53 | 改寫成整合說明的觸點表；階段規則見 D7 |
| §11 PR 正文的更新規則 | 19 | `github-pr` 的 update 操作 |
| §12 人工案例與正式證據 | 44 | `tests/acceptance/README.md` |
| §13 常見問題 | 14 | 逐列歸入對應 Skill；已有相同處理的列不重複 |
| 附錄 A 共同案例 | 399 | `tests/acceptance/shared.md` |

實作時的順序固定為「接收者先就位並通過檢查，再刪除契約中的原文」，避免規則在兩次修改之間沒有任何陳述位置。

### D3. Skill 內的檔案配置與讀取時機

| 檔案 | 內容 | 何時讀取 |
| --- | --- | --- |
| `SKILL.md` | 操作步驟、寫入前核對、各類貼文的章節順序與必填欄位（骨架）、Author 的四個欄位與缺值規則 | Skill 觸發時載入 |
| `references/examples.md` | 完整範例、代發、缺少 metadata、人類直接發文、舊格式的讀法 | SKILL.md 寫明：第一次撰寫該類貼文，或遇到上述特殊情況時讀取 |
| `references/approval-records.md`（只有 `github-pr`） | 批准事件的欄位、發現、版本比對指令與取代規則 | SKILL.md 寫明：要記錄或讀取批准紀錄時讀取 |
| `references/checklists.md`（`change-review` 既有） | 不變 | 不變 |

每個 reference 在 SKILL.md 都有一句明確的讀取條件，不寫成「相關資料見…」。原因是 references 不會自動載入，Agent 只依 SKILL.md 的文字決定讀不讀；沒有條件的指向會讓它在不需要時整份讀入，或在需要時略過。

預估搬入後 `github-issue` 的 SKILL.md 約 450 行、`github-pr` 約 570 行（估計值，未實作）。批准紀錄獨立成檔，是因為它約 100 行，卻只有少數 reply 會用到。SKILL.md 的實際行數在驗證紀錄中回報修改前後的數字。

替代方案是把骨架也放進 `examples.md`。不採用：骨架每次撰寫都要用，放在 reference 等於每次都要多讀一個檔案。

### D4. 共用區塊各持有一份

有兩組規則需要在兩個 Skill 中各有一份：

| 區塊 | 內容 | 持有者 | 約略行數 |
| --- | --- | --- | --- |
| 共用外框 | Handoff、Next actions、Author 的欄位與缺值規則 | `github-issue`、`github-pr` | 30 |
| 審查識別 | verdict 只有 `pass`、`changes-required`、`blocked`；phase 為 design 或 implementation；review-id 在發布前指派、在 PR 內唯一；Finding ID 為 `<origin-review-id>/F-NN` 並跨輪沿用；Open、Accepted、Rejected、Resolved 的意思；實作者的「已修正」不是 Resolved | `github-pr`、`change-review` | 15 |

審查識別需要兩份，因為兩個入口都會單獨寫出審查內容：`github-pr reply` 被直接呼叫時，要寫第一輪 Review 或帶 Finding 狀態的修正回覆；`change-review` 沒有 PR 時要寫本地報告，不經過 `github-pr`。只屬於審查流程的規則（Accepted Finding 連到正式待辦、審查的執行步驟、發布授權、完整基線）只放在 `change-review`。

每個區塊在兩份檔案中以相同的起訖註解標記，測試逐位元比對兩份是否一致。

替代方案一是讓 `github-issue` 引用 `github-pr` 的檔案；不採用，這違反自足。替代方案二是由 installer 把單一來源複製進兩個 Skill；不採用，為了約 30 行規則而改變 installer 的複製模型不值得，重複加上一致性測試已足夠。

### D5. 整合說明的內容

`docs/github-handoff.md` 保留路徑與 managed 身分，重寫為約百餘行：

1. 定位：本文件說明個人開發流程如何接上 GitHub 協作；格式與寫入規則在各 Skill；是否可以進到下一階段見 `openspec-workflow.md`。
2. 入口對照：`github-issue`、`github-pr`、`change-review`、`openspec-commit` 各自負責什麼，以及它們的安裝位置（`.claude/skills/<名稱>/`、`.agents/skills/<名稱>/`），供不會自動載入 Skill 的工具直接開檔。
3. 觸點表：四個階段各自在什麼時點接上 GitHub、呼叫哪個 Skill 的哪個操作、帶入什麼、取回什麼、哪些是選用。開立規格階段列出兩個入口（D10）。
4. 不在本文件的事項與對應來源。

不保留原章節編號；Skills 與文件中所有「契約第 N 節」的引用都改掉，不留任何依賴編號的引用。文件中以路徑文字指出 Skill 位置，不用相對連結，因為 template 目錄與安裝目錄的相對位置不同。

`docs/diagrams/github-handoff.svg` 繼續由 installer 管理，是這份整合說明的配圖；內容更新為兩個入口（D10）。

### D6. 必讀依賴與可達性

| 檔案 | 現在 | 之後 |
| --- | --- | --- |
| `docs/agent-protocol.md` §1 | 操作 Issue／PR 前先讀 `docs/github-handoff.md` | 操作 Issue／PR 或發布 Review 時使用已安裝的對應 Skill，格式與核對由 Skill 提供。保留一句與工具無關的最低要求：每次寫入前確認完整 repository 目標、操作與授權，寫入後回讀。協調 Change 與 Issue／PR 的關係時才讀整合說明。版本由 2.7.0 改為 2.8.0 |
| `.claude/rules/github-handoff.md` | 先讀並遵守契約 | 改為指向對應 Skill 的入口；檔名不變，避免退役既有安裝 |
| seed `AGENTS.md` | 用 Issue／PR 交接 Change 時先讀契約 | 改為使用對應 Skill，整合說明作為流程銜接的參考 |
| `docs/openspec-workflow.md`「GitHub handoff (optional)」 | 依契約處理關聯、核對與範本 | 改為指向整合說明與各 Skill |
| 四個 Skill 的 SKILL.md | 先讀契約的指定章節 | 移除；格式在本 Skill 內 |

相容性：seed `AGENTS.md` 只在不存在時複製，既有專案的舊文字仍會指向 `docs/github-handoff.md`。該路徑保留，且開頭就指向各 Skill，因此舊指向仍能到達正確的規則。

只讀 `AGENTS.md` 的工具沿「`AGENTS.md` → `docs/agent-protocol.md` → `docs/github-handoff.md` → `.agents/skills/<名稱>/SKILL.md`」到達入口。原本檢查鏈結可達的測試延伸到最後一段。

### D7. 流程規則與批准紀錄的接收者

- **Apply 授權**（可接受的指示來源、不構成授權的情形、需要釐清的情形、暫停與撤回、實作授權不含發布授權）併入 `openspec-workflow.md` §3，以該文件的語言（英文）撰寫，不重複已有的句子。
- **各階段不得互相推定**：`openspec-workflow.md` §5 補上設計審查、實作審查、資料驗收與 Issue 關閉；設計 PR 合併不取代實作驗收；必要的資料驗收未完成時不提前 archive；Review 未通過回到修訂。
- **批准紀錄的讀寫**（事件欄位、在 PR 上的發現、與目前工作區的版本比對、只差 tasks 勾選不算設計改變、無法核對的結果、以新事件取代而不改舊事件）到 `github-pr` 的 `approval-records.md`。這些規則依賴事件欄位，是紀錄的讀寫語意，不是授權判斷。
- **最終複審的範圍**：「差異僅為搬移、spec 同步與文件更新才縮小範圍；出現語意變動就擴大」目前只寫在契約第 10 節，`change-review` 只有對應案例 CR-42。這條規則補進 `change-review` 的 SKILL.md。它是既有規則的接收，不是新行為。
- 第 10 節其餘段落在新位置都已有相同規則，只刪不搬：Closure 先發布再關閉與關閉原因的依據（將隨 §6.7 進入兩個 Skill）、Checkpoint、既有 PR 不重開第二張（`github-pr` create）、修正複審的往返（`change-review`）、等待真實資料時 Issue 要寫的欄位（隨 §6.1 進入 `github-issue`）、交付整理後的最終版本複審與原 PR 已合併的處理（`openspec-commit` Step 7a）。

### D8. 驗收題庫移到 `tests/acceptance/`

目錄配置：

```
tests/acceptance/
  README.md            重播方法、案例欄位、證據位置（來自契約第 12 節）、刪除案例對照表
  shared.md            來自契約附錄 A
  github-issue.md      github-pr.md      change-review.md
  openspec-commit.md   git-commit-writer.md
```

各來源的決定：

| 來源 | 案例數 | 決定 | 理由 |
| --- | --- | --- | --- |
| `openspec-commit` | 31 | 全部搬移 | 測試以案例標題作為回歸錨點；沒有執行時讀者；未發現檔內重複 |
| `github-pr` | 66 | 全部搬移 | 同上。與 `github-issue` 相似的四對（GP-58／GI-46、GP-65／GI-33、GP-46／GI-41、GP-21／GI-02）是兩個入口各自的同類情境，保留 |
| `github-issue` | 50 | 全部搬移 | 同上 |
| `git-commit-writer` | 16 | 全部搬移 | 同上。WC-14 與 GP-90 分屬 commit 與 PR create 兩個入口，保留 |
| `change-review` | 91 | 先抽出、再搬移 | CR-60 至 CR-63 內含完整報告，是執行時唯一的報告範例。先把報告本文抽到 `change-review/references/examples.md`，案例改為引用該範例，再搬移 |
| 契約附錄 A | 49 | 全部搬移；去重候選逐案評估，預設保留 | 候選為 C-16／CR-42、C-18／OC-16、C-05／CR-08、C-20／CR-15、C-21／GI-15、C-35／GI-49，依禁止與判定文字相似度找出，實作時依下列準則逐欄比對後決定 |

刪除準則（全部符合才刪除）：

1. 題庫中另有一案具有相同的情境與相同的判定。
2. 該案的禁止項目涵蓋被刪案例的全部禁止項目。
3. 沒有其他案例以「同 X」沿用被刪案例的 Fixture、模擬回覆或預期呼叫；有的話，先在引用案例中寫出沿用的內容。

每組候選在 `README.md` 的對照表記下比對結果：刪除時寫被刪代號與涵蓋它的代號，保留時寫不符合的準則。相似但屬於不同入口的案例不算重複。

前一版設計寫「C-16、C-18 已逐欄比對，刪除」，這不成立：C-16 的「重新 archive」「建立空 commit」兩項禁止不在 CR-42 中；OC-09 是沒有最終 Review 授權而停止的情境，判定與 C-16 不同；C-17 的 Fixture 與預期呼叫寫「同 C-16」。C-18 的「宣稱已合併」也不在 OC-16 的禁止中。兩案目前都不符合準則，與其他候選一樣留待逐欄比對。

測試的調整：

- 讀取路徑改為 `tests/acceptance/`；檢查案例標題的斷言保留，因為它們各自對應一條需求。
- 移除把題庫當品質代理的斷言：「SKILL.md 有連結題庫」「題庫檔存在」「至少 N 個案例」。
- 以題庫為探針的內容檢查改為直接檢查 Skill 的執行檔（例如 `XIRP-SESSION-ID` 應出現在 SKILL.md 或 `examples.md`）。
- 以題庫為探針的重裝覆寫檢查改用 `references/examples.md`。
- 新增題庫本身的檢查：每案五個欄位齊全、代號在整個題庫中唯一、案例之間的互相引用可解析、對照表中的涵蓋代號存在。
- 新增出貨內容的檢查：`template/common/skills/` 下沒有 `acceptance-cases.md`，也沒有任何檔案提到它。

替代方案是直接刪除題庫。不採用：這些 Skill 是指令文件，沒有其他回歸定義；刪除後修改 Skill 時無從比對行為是否改變。替代方案二是留在 Skill 內但加註「執行時不要讀」；不採用，它仍隨安裝散布，而且與使用者的要求相反。

### D9. 既有安裝副本的退役

範圍限定十個路徑：`.claude/skills/` 與 `.agents/skills/` 下，`openspec-commit`、`github-pr`、`github-issue`、`git-commit-writer`、`change-review` 各自的 `references/acceptance-cases.md`。installer 不管理 `.codex/skills/`，不處理。

每個路徑的處理：

1. 不存在：略過。
2. 是 symlink：保留並回報。
3. 以 `git hash-object --no-filters` 計算 blob；與該 Skill 曾出貨的任一版本相同：移除。
4. 其他情形（改過或來源不明）：保留並回報，說明題庫已移到來源 repo 的 `tests/acceptance/`，由使用者決定是否刪除。
5. 移除後，該 Skill 的 `references/` 目錄若為空才移除目錄。

出貨版本清單寫在 installer 內，內容是五份檔案在 Git 歷史中的所有 blob（目前 27 個，另加搬移前的最後版本），在實作時以 `git log` 與 `git rev-parse <commit>:<path>` 產生。沿用 `check-identity.sh` 退役的作法與訊息格式，不重構既有區塊。

不使用 `rm -rf`、`rsync --delete` 或針對整個 skills 目錄的清除。替代方案 `rsync --delete` 會刪掉使用者自行加入的檔案與第三方 Skill 的內容，不採用。

### D10. 開立規格的兩個入口

| | Issue-first | Change-first |
| --- | --- | --- |
| 起點 | 同仁或自己已開 Issue | 需求已可在本機描述 |
| 步驟 | 讀取 Issue 的問題、影響、驗收資訊與未決事項 → 準備分支 → 建立或沿用對應的 Change → 人工確認 | 準備分支 → 建立 Change → 人工確認 → 視需要建立或沿用 Issue，也可以不建立 |
| GitHub 入口 | 讀取既有 Issue；使用者要求時以 `github-issue update` 新增留言，記下 Change 與分支 | 需要追蹤時 `github-issue create`；已有同一件工作的 Issue 就沿用 |
| 交接資料 | 帶入：Issue URL、問題與影響、驗收資訊、未決事項。產出：Change、branch、proposal 中引用該 Issue | 產出：Change、branch；有 Issue 時加上 Issue URL |
| 不做的事 | 不另開新 Issue；不改寫他人的 Issue 正文；Issue 缺少驗收資訊時在規劃中列為未決事項，不自行補上 | 不為了補欄位而建立 Issue |

兩條路徑之後都交給實作階段，輸出相同：Change、branch、已確認的範圍與實作授權。原有的人工確認與選用的設計 Draft PR 不變，也不新增整合用的 Skill。`github-issue` 已支援沿用既有 Issue 與以留言補上關聯，不需要新的操作。

圖稿與文件：

- `docs/diagrams/local-development-define.svg` 改為兩個起點匯入同一個人工確認節點。不產生 PNG：使用者已決定 `docs/diagrams/` 只保留 SVG，並已刪除六張 PNG（第一輪審查要求的 define PNG 因此不再適用）。渲染檢查以 `rsvg-convert` 輸出到暫存目錄後目視，輸出檔不放進 repo。
- managed 的 `template/common/docs/diagrams/github-handoff.svg` 的前兩步改為兩個入口。
- `docs/workflow/local-development.md` 的 01 階段表格、`docs/diagrams/README.md` 的對應列（現在寫「先分支再 Change」）同步更新。
- `docs/diagrams/development-lifecycle.svg` 的第一步是「探索需求」，沒有規定 Issue 與 Change 的先後，不需修改。
- 仍指向已刪除 PNG 的 12 處連結改指向同名 SVG：`docs/diagrams/README.md` 6 處（PNG 欄移除）、`docs/workflow/local-development.md` 4 處、`docs/workflow/guide.md` 與 `docs/workflow/wt-work-flow.md` 各 1 處。這是刪除 PNG 的連帶修正，SVG 本身不變。

### D11. Review 與封存交付的回歸基線

這兩個階段的行為已由使用者確認，本次只允許三類修改：引用位置（契約章節改為 Skill 或流程文件）、移除題庫指向、D7 所列的規則接收（`change-review` 的複審範圍規則與 `examples.md`）。

基線在任何來源修改之前取得：`tests/test_change_review.sh`、`tests/test_openspec_commit.sh`、`tests/test_github_pr_publication.sh` 的結果，以及抽樣案例的預期判定。修改後除了路徑與已說明的斷言調整，結果必須相同。`change-review` 與 `openspec-commit` 的 SKILL.md 差異在驗證紀錄中逐段歸類到上述三類，出現第四類就退回。

### D12. Spec 的配置

| Capability | 處理 |
| --- | --- |
| `github-change-handoff` | ADDED：整合說明只描述流程觸點；開立規格有兩個入口。MODIFIED：需求權威、批准紀錄、Review 紀錄、共用外框、範例五個 requirement 改為不依賴共用契約。REMOVED：生命週期、交付整理後的複審 |
| `github-issue` | ADDED：入口自足。MODIFIED：範本由 Skill 持有 |
| `github-pr` | ADDED：入口自足。MODIFIED：範本與批准紀錄由 Skill 持有 |
| `change-review` | ADDED：最終複審的範圍。MODIFIED：三個 requirement 的引用改為 Skill 持有的格式，其中「Reports use the shared handoff contract」同時改名為「Reports use the review format and the PR reply entry」 |
| `openspec-commit` | MODIFIED：加上原 PR 已合併的情境 |
| `openspec-change-lifecycle` | 新增：Apply 授權、階段不得互相推定、驗收條件改變回到 OpenSpec |
| `skill-acceptance-cases` | 新增：題庫位置、出貨內容、刪除紀錄 |
| `install-profile-cli` | ADDED：題庫副本的退役 |

`git-commit-writer` 沒有 requirement 變更，只有檔案搬移。`github-change-handoff` 的 Purpose 在 archive 時直接更新主 spec。

### D13. TDD 策略與測試邊界

這次是指令文件、文件與 installer 的修改。installer 與檔案配置可以自動化；Agent 讀了新版後的判斷只能人工重播。

**自動化（每一組先寫斷言並取得 Red，再修改來源）：**

1. 題庫：D8 列出的題庫檢查與出貨內容檢查。
2. 自足：`github-issue`、`github-pr` 的 SKILL.md 與 references 不含讀取 `docs/github-handoff.md` 的指示，也不含「契約第 N 節」的引用；各自含有 Handoff、Next actions、Author 四欄位、寫入核對與回讀的規則；`github-pr` 另含審查識別區塊；D4 的兩組共用區塊各自兩份逐位元相同；每個 reference 在 SKILL.md 有讀取條件。
3. 整合說明：不含貼文範本的標題與 Author 欄位骨架；含四個階段的觸點與兩個入口；列出的 Skill 路徑在安裝後存在。
4. 接收者：D2、D7 的每一項在目的檔找得到對應文字；原本檢查契約章節內容的斷言（例如批准紀錄的 git 比對指令、Closure 的順序）改為檢查接收者。
5. 必讀依賴：protocol、rule、seed `AGENTS.md` 的措辭與版本號；AGENTS.md 到 Skill 檔案的鏈結可達。
6. Installer：在臨時 repo 驗證新安裝、含最新出貨版本的重裝、含較舊出貨版本的重裝、改過的副本、symlink、同目錄的其他檔案、第三方 Skill 目錄下的同名檔案、連跑兩次。

**人工重播（無法自動化）：** 在修改前記下抽樣案例的 Fixture 與預期判定，修改後以新啟動的 Session 重播並記錄實際結果。

- 自足：GI-02（重複呼叫 create）與 GP-21（唯一既有 PR 時的 create），重播時不提供 `docs/github-handoff.md`。GP-40（第一輪審查回覆）與 GP-44（複審沿用 Finding ID），重播時只提供 `github-pr` 的目錄，不提供 `change-review` 與整合說明。
- 流程規則：C-39（有明確指示、沒有 PR 事件）、C-14（只有技術 pass）。
- 回歸：CR-42（archive 後的最終複審）、OC-07（成功交付）、C-43（工作區設計已實質改變）。
- 兩個入口：為 Issue-first 與 Change-first 各寫一個新案例放進 `tests/acceptance/shared.md`。

**測試邊界：** 重播是離線的決策驗收，不宣稱做過真實的 GitHub 寫入；不新增 Agent 測試框架；圖稿除了 XML 檢查，要實際渲染後目視，無法渲染時如實回報未完成。

## Risks / Trade-offs

- [規則在搬入 Skill 時被改寫而變了意思] → 以現行 spec 的情境逐條對照；人工重播在修改前先固定預期判定；批准紀錄與 Closure 等有既有斷言的內容，斷言跟著搬到接收者。
- [規則在搬移途中消失] → D2 的對照表是驗收條件；實作順序固定為接收者先就位、再刪原文。
- [共用外框兩份逐漸不一致] → 逐位元比對的測試。
- [`github-pr` 的 SKILL.md 變長] → 骨架以外的內容都在 references；批准紀錄獨立成檔；修改前後的行數寫入驗證紀錄。
- [Agent 不讀整合說明就不知道流程] → 整合說明本來就只在協調 Change 與 Issue／PR 時需要；每個 Skill 單獨可用正是目標。是否可以開始實作由 `openspec-workflow.md` 規定，protocol 已要求 OpenSpec 工作前讀它。
- [出貨版本清單漏了某個歷史版本，導致未修改的舊副本被當成改過而保留] → 結果是保留並回報，不是誤刪；清單由 Git 歷史產生，測試以歷史中的較舊版本驗證。
- [使用者改過的題庫副本留在專案裡] → 這是刻意的；訊息會說明新位置。
- [`github-change-handoff` 這個名稱與新定位大致相符，但 Purpose 仍是舊描述] → archive 時更新主 spec 的 Purpose。

## Migration Plan

1. 在 `template/common/` 與 `tests/` 完成修改，執行 `scripts/skills/install.sh` 同步本 repo；本 repo 的十個題庫副本會由退役步驟移除。
2. 其他專案下次執行 installer 時取得新版 Skills 與 managed 文件，未修改的舊題庫副本同時被移除。
3. 已發布的 Issue／PR 與留言不受影響：格式、欄位與 marker 都沒有改變，舊格式的讀法隨格式一起搬進 Skill。
4. 回復方式是 revert 該 commit 並重新執行 installer；被移除的題庫副本會隨舊版 template 重新安裝。
