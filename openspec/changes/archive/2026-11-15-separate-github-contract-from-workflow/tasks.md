# Tasks

所有來源修改都在 `template/common/`、`tests/`、`scripts/` 與本 repo 的 `docs/` 進行，不直接編輯 `.claude/`、`.agents/` 或 managed `docs/` 的安裝副本。每一組先寫斷言並取得 Red，再修改來源取得 Green。規則搬移的順序固定為：接收者先就位並通過檢查，再刪除契約中的原文（第 7 組）。各項的依據見 design.md 的 D2 至 D11。

## 1. 基線

- [x] 1.1 在任何來源修改之前，建立驗證紀錄（原訂 `docs/verification/`；使用者確認 Review 與驗證紀錄只放 Work Item 或 GitHub PR 後，已原文移到 `work-items/WI-20261114-separate-github-design-review/agents/claude-16460157-implementation-verification.md`），記下 `tests/test_github_handoff.sh`、`test_change_review.sh`、`test_openspec_commit.sh`、`test_github_pr_publication.sh` 的執行結果，以及五個 Skill 的 SKILL.md 行數。測試要求：文件含每支腳本的指令、結束碼與通過／失敗數；`git status` 顯示此時 `template/`、`tests/`、`scripts/` 沒有修改。
- [x] 1.2 在同一份文件記下抽樣重播案例的 Fixture、模擬回覆與預期判定：GI-02、GP-21、GP-40、GP-44、C-39、C-14、CR-42、OC-07、C-43，並註明案例檔當時的 commit。測試要求：九案齊全；只寫預期，不填實際結果；之後不得為了追認結果而修改這些預期。

## 2. 驗收題庫移到 tests/acceptance

- [x] 2.1 新增 `tests/test_acceptance_bank.sh`，斷言：`tests/acceptance/` 有 `README.md`、`shared.md` 與五個 Skill 各一份題庫；每案有 Fixture、模擬回覆、預期呼叫、禁止、判定五個欄位；代號在整個題庫中唯一；案例之間的互相引用可解析（包含 Fixture、模擬回覆與預期呼叫中的「同 X-NN」）；對照表中的涵蓋代號存在；`template/common/skills/` 下沒有 `acceptance-cases.md`，也沒有任何檔案提到它；每個 Skill 的 reference 都在 SKILL.md 中帶有讀取條件。測試要求：執行後取得預期 Red，記錄指令、失敗的斷言與非零結束碼；失敗原因是題庫尚未搬移，不是語法或路徑錯誤。
- [x] 2.2 把 `change-review` 題庫中 CR-60 至 CR-63 的完整報告本文抽到新的 `template/common/skills/change-review/references/examples.md`，原案例改為引用該範例；在 `change-review` 的 SKILL.md 寫明何時讀取 `examples.md`。測試要求：以 `diff` 確認四份報告本文與抽出前逐字相同；`tests/test_change_review.sh` 中檢查完整報告含 `## Next actions` 與共用 Author 的斷言改為檢查 `examples.md` 並通過；此時題庫仍在原位，其他斷言不受影響。
- [x] 2.3 以 `git mv` 把五份 `references/acceptance-cases.md` 搬到 `tests/acceptance/<skill>.md`；把契約附錄 A 複製為 `tests/acceptance/shared.md`、第 12 節的重播方法複製為 `tests/acceptance/README.md`（契約中的原文在第 7 組刪除）。移除五個 SKILL.md 的「Replay cases」段落與三份 `examples.md` 開頭對題庫的指向；題庫內「契約第 N 節」的引用改為對應的 Skill 或文件名稱。測試要求：2.1 中除對照表以外的斷言通過；搬移前後各檔的案例代號集合相同（以排序後的代號清單比對），沒有案例在搬移中遺失。
- [x] 2.4 去重評估：對 design.md D8 的六組候選（C-16／CR-42、C-18／OC-16、C-05／CR-08、C-20／CR-15、C-21／GI-15、C-35／GI-49）逐欄比對情境、判定與禁止項目，並檢查是否有其他案例以「同 X」沿用候選的內容；三項準則都符合才刪除，預設保留。在 `tests/acceptance/README.md` 的對照表記下每組的結果：刪除時寫被刪與涵蓋的代號，保留時寫不符合的準則。測試要求：2.1 的對照表與互相引用斷言通過；C-17 的 Fixture 與預期呼叫仍可完整解析；每筆刪除的禁止項目都能在涵蓋案例中找到；分屬不同入口的相似案例（GP-58／GI-46 等四對、WC-14／GP-90）仍然存在。
- [x] 2.5 更新 `tests/test_github_handoff.sh`、`test_change_review.sh`、`test_openspec_commit.sh`：題庫路徑改為 `tests/acceptance/`；移除「SKILL.md 連結題庫」「題庫檔存在」「至少 N 個案例」三類斷言；把以題庫為探針的內容檢查改為檢查 Skill 的 SKILL.md 或 `examples.md`；重裝覆寫的探針改用 `references/examples.md`。測試要求：三支腳本通過；與 1.1 的基線逐項比對，除了被移除與改指向的斷言，其餘斷言名稱與結果相同，差異清單寫入驗證文件。

## 3. github-issue 自足

- [x] 3.1 在 `tests/test_github_handoff.sh` 新增斷言：`github-issue` 的 SKILL.md 與 references 不含讀取 `docs/github-handoff.md` 的指示，也不含「契約第 N 節」或 `section N` 的契約引用；含有 Handoff、Next actions、Author 四個欄位與缺值規則、寫入前的目標與授權核對、明示的帳號限制、不輸出 credential、回讀、結果不明先查核、查重與關聯、Checkpoint、Closure、舊格式的讀法；`examples.md` 的讀取條件寫在 SKILL.md。測試要求：取得預期 Red，失敗原因是規則尚未搬入。
- [x] 3.2 依 design.md D2、D3 把契約第 2 至 5 節的 Issue 部分、共用外框、第 6.1、6.6、6.7 節與第 13 節的相關列搬入 `template/common/skills/github-issue/`：骨架與每次適用的規則放 SKILL.md，完整範例、代發、缺值、人類直接發文與舊格式放 `references/examples.md`；共用外框段落加上起訖註解；移除「先讀契約」與章節引用。測試要求：3.1 與既有的 Issue 相關斷言通過（原本檢查契約第 6.1 節內容的斷言改為檢查本 Skill）；欄位名稱、順序與 Author 內容與現行契約逐項相同；SKILL.md 修改前後的行數寫入驗證文件。

## 4. github-pr 自足

- [x] 4.1 新增斷言：`github-pr` 與 3.1 相同的自足檢查，另含 PR 的 base／head 與 fork 核對、既有 PR 的沿用、正文更新規則、審查與修正回覆的骨架、design.md D4 的審查識別區塊；`references/approval-records.md` 存在並在 SKILL.md 寫明讀取條件；`github-issue` 與 `github-pr` 以起訖註解標記的共用外框段落逐位元相同。測試要求：取得預期 Red（審查識別區塊兩份一致的檢查在 5.1 加入）。
- [x] 4.2 依 D2、D3、D4 把契約第 2 至 5 節的 PR 部分、共用外框、第 6.2、6.6、6.7、11 節、第 8 節與第 6.4 節的審查識別部分，以及第 13 節的相關列搬入 `template/common/skills/github-pr/` 的 SKILL.md 與 `references/examples.md`；Approval events 小節的第一段改為一句指向 `docs/openspec-workflow.md` 的授權規則；移除「先讀契約」與章節引用。測試要求：4.1 的自足與一致性斷言通過；`tests/test_github_pr_publication.sh` 與 1.1 的基線相同；發布步驟（commit、push、Draft PR）的文字以 `git diff` 確認沒有變動。
- [x] 4.3 建立 `template/common/skills/github-pr/references/approval-records.md`，內容為契約第 6.3 節的批准事件、第 9 節的紀錄發現與版本比對、第 7 節用於 `recorded_by` 的完整欄位。測試要求：原本檢查契約第 6.3 節與第 9 節的斷言（欄位、`unpublished-snapshot`、git 比對指令、只差 tasks 勾選、無法核對不當成相同）改為檢查本檔並通過；以真實 Git 演練版本比對的既有測試仍通過。

## 5. change-review、openspec-commit、git-commit-writer 的引用

- [x] 5.1 新增斷言：`change-review` 的 SKILL.md 持有 design.md D4 的審查識別區塊，且與 `github-pr` 的同一區塊逐位元相同；持有 Accepted Finding 連到正式待辦的規則、可轉交訊息，以及「差異僅為搬移與同步才縮小範圍、語意變動要擴大」的規則；`references/examples.md` 含完整審查基線；三個 Skill 都沒有契約章節引用；`change-review` 與 `openspec-commit` 以 `github-pr` 的 reply／update／close 取得回覆外框與 Closure。測試要求：取得預期 Red。
- [x] 5.2 修改 `template/common/skills/change-review/` 的 SKILL.md、`references/checklists.md` 與 `references/examples.md`：搬入審查識別區塊（與 `github-pr` 相同）、契約第 8 節中只屬於審查流程的規則、第 6.4 節的完整基線、第 6.5 節與複審範圍規則，批准判斷改為引用 `docs/openspec-workflow.md`。測試要求：5.1 與 `bash tests/test_change_review.sh` 通過；SKILL.md 的差異逐段歸類為 design.md D11 的三類（引用位置、移除題庫指向、規則接收），歸類表寫入驗證文件，出現其他類別就退回；Reviewer 不因此取得修改、commit 或 push 的權限。
- [x] 5.3 修改 `template/common/skills/openspec-commit/` 與 `git-commit-writer/`：只調整引用位置。測試要求：5.1 與 `bash tests/test_openspec_commit.sh` 通過；兩個 SKILL.md 的差異只屬於「引用位置」與「移除題庫指向」兩類；archive、文件更新、commit、交付與結案的步驟文字沒有變動。

## 6. 流程規則併入 OpenSpec workflow

- [x] 6.1 新增斷言：`openspec-workflow.md` 含可接受的指示來源、不構成授權的情形、需要釐清的情形、暫停與撤回、實作授權不含發布授權；Review 未通過回到修訂；第 5 節的階段清單含設計審查、實作審查、資料驗收與 Issue 關閉，設計 PR 合併不取代實作驗收，資料驗收未完成不提前 archive。原本檢查契約第 9 節授權用語的六個斷言改為檢查本檔的對應英文用語。測試要求：取得預期 Red，失敗原因是文字尚未出現在本檔。
- [x] 6.2 修改 `template/common/docs/openspec-workflow.md` 的第 3、5 節與「GitHub handoff (optional)」一段，以英文撰寫，不重複已有的句子，不加入 git 比對指令。測試要求：6.1 通過；`openspec-change-lifecycle` 的每個情境都能在本檔找到對應規則，對照寫入驗證文件。

## 7. 整合說明與 managed 圖稿

- [x] 7.1 新增斷言：`template/common/docs/github-handoff.md` 不含貼文範本的標題骨架與 Author 欄位骨架，不含編號的契約章節；含定位、入口對照與安裝位置、四個階段的觸點表、開立規格的兩個入口；design.md D2 的每一列都有一個代表性用語能在對應的接收者檔案中找到（對照表寫在測試中）。測試要求：取得預期 Red；D2 對照檢查在此時應全數通過，因為接收者已在第 2 至 6 組就位，若有缺漏先補接收者再繼續。
- [x] 7.2 依 design.md D5 重寫 `template/common/docs/github-handoff.md`，刪除已有接收者的全部原文、附錄 A 與第 12 節；依 `docs/okf-conventions.md` 撰寫。測試要求：7.1 通過；文件中列出的每個 Skill 路徑在安裝後存在；既有專案 seed `AGENTS.md` 的舊指向沿此文件能到達各 Skill。
- [x] 7.3 更新 `template/common/docs/diagrams/github-handoff.svg`：前兩步改為 Issue-first 與 Change-first 兩個入口，其餘觸點與整合說明的觸點表一致。測試要求：XML 格式正確；以 `rsvg-convert` 實際渲染並目視確認文字不溢出、不重疊、箭頭方向清楚；圖中名稱與文件一致；既有檢查圖中文字的斷言更新後通過。無法渲染時如實回報未完成，不宣稱通過。

## 8. 必讀依賴

- [x] 8.1 新增斷言：`template/common/docs/agent-protocol.md` 第 1 節改為使用對應 Skill 並保留「寫入前確認目標、操作與授權，寫入後回讀」的最低要求，版本為 2.8.0；`template/common/.claude/rules/github-handoff.md` 與 `template/common/AGENTS.md` 指向 Skill 入口；三者都不再要求每次寫入前先讀整合說明；`AGENTS.md → docs/agent-protocol.md → docs/github-handoff.md → .agents/skills/<名稱>/SKILL.md` 在臨時安裝的專案中逐段可達。測試要求：取得預期 Red；`bash tests/test_portable_agents_md.sh` 在修改前後都通過。
- [x] 8.2 修改上述三個檔案。測試要求：8.1 通過；rule 檔名不變，`.claude/rules/` 與 `.agents/rules/` 的鏡像內容相同；rule 不寫死特定的次要工具名稱。

## 9. Installer 退役與安裝

- [x] 9.1 在 `tests/test_acceptance_bank.sh` 以臨時 repo 新增 installer 斷言，各情境獨立：全新安裝後十個路徑都沒有題庫檔；放入最新出貨版本後重裝會移除；放入由 Git 歷史取出的較舊出貨版本後重裝會移除；改過的副本保留並輸出說明；symlink 保留並輸出說明；同一個 `references/` 下的其他檔案不動，且目錄只在清空後才移除；不在清單內的 Skill 目錄下的同名檔案不動；連跑兩次第二次不再移除任何檔案。測試要求：取得預期 Red，失敗原因是 installer 尚無退役步驟。
- [x] 9.2 在 `scripts/skills/install.sh` 新增退役步驟：範圍限定 design.md D9 的十個路徑；出貨版本清單由 `git log` 與 `git rev-parse <commit>:<path>` 產生，包含五份檔案的所有歷史 blob 與搬移前的最後版本；沿用 `check-identity.sh` 退役的判斷與訊息格式，不重構既有區塊，不使用 `rm -rf` 或 `rsync --delete`。測試要求：9.1 全數通過；清單中的 blob 數量與 Git 歷史查得的相同，產生清單的指令與結果寫入驗證文件；腳本符合 `docs/conventions.md`，以 `CLAUDE_PROJECT_DIR` 優先、`PWD` 次之偵測專案根的既有行為不變。
- [x] 9.3 執行 `bash scripts/skills/install.sh` 同步本 repo。測試要求：以 `diff -r` 確認五個 Skill 在 `template/common/skills/`、`.claude/skills/`、`.agents/skills/` 三處一致，managed `docs/` 與 template 一致；本 repo 的十個題庫副本已移除；`git status` 中沒有 installer 管理範圍以外的 `.codex/` 變更。

## 10. 開立規格的兩個入口

- [x] 10.1 在 `tests/acceptance/shared.md` 新增 Issue-first 與 Change-first 各一個案例，Fixture 與預期判定對應 `github-change-handoff`「Define stage accepts Issue-first and Change-first entry」的情境；新增斷言：`docs/workflow/local-development.md` 的 01 階段與 `docs/diagrams/README.md` 的對應列都描述兩個入口，`docs/diagrams/local-development-define.svg` 的文字含兩個起點。測試要求：取得預期 Red；兩個新案例通過 2.1 的題庫檢查。
- [x] 10.2 依 design.md D10 更新 `docs/workflow/local-development.md` 的 01 階段：兩個入口的起點、步驟、GitHub 入口、交接資料與不做的事；人工確認與選用的設計 Draft PR 維持不變。測試要求：10.1 的文件斷言通過；02 至 04 階段除了引用位置以外沒有變動（以 `git diff` 確認）。
- [x] 10.3 更新 `docs/diagrams/local-development-define.svg`，兩個起點匯入同一個人工確認節點；更新 `docs/diagrams/README.md` 的對應列。不產生 PNG。測試要求：10.1 的圖稿斷言通過；SVG 的 XML 格式正確並保有標題與描述；以 `rsvg-convert` 輸出到 `$CLAUDE_JOB_DIR/tmp` 或其他暫存目錄後實際開啟，目視確認文字不溢出、不重疊、箭頭方向清楚，兩個入口與文件一致（記下指令），輸出檔不加入 repo。無法渲染時如實回報未完成。

## 11. 本 repo 文件

- [x] 11.1 把指向已刪除 PNG 的 12 處連結改指向同名 SVG：`docs/diagrams/README.md` 6 處（移除 PNG 欄）、`docs/workflow/local-development.md` 4 處、`docs/workflow/guide.md` 與 `docs/workflow/wt-work-flow.md` 各 1 處。另更新 `docs/workflow/commit.md`（原引用契約章節的註腳）、`docs/skills/` 下五份 Skill 說明、`docs/architecture.md`（測試與 managed 檔案的描述）、退役舊圖稿目錄 `docs/diagrams/github-change-handoff/`（已由使用者與 Codex 移除，不重建；現行入口由 `docs/diagrams/README.md` 與 `docs/architecture.md` 承接，確認沒有連結指向該目錄）、`AGENTS.md` 的 Skills 與相關文件段落（題庫位置、整合說明的定位）、`README.md` 的安裝產物表。依 `docs/okf-conventions.md` 撰寫。測試要求：`bash tests/test_documentation_authoring.sh` 通過；文件中的相對連結都能解析到存在的檔案；`docs/`、`README.md` 與 `AGENTS.md` 中沒有指向 `docs/diagrams/` 下 PNG 的連結（以 grep 確認）；本 repo 文件中不再出現「契約第 N 節」的引用，也不再把 `acceptance-cases.md` 描述為 Skill 的 reference。

## 12. 整合驗證

- [x] 12.1 執行 `tests/` 下所有 `test_*.sh`。測試要求：全部結束碼為 0；與 1.1 的基線比對，`test_change_review.sh`、`test_openspec_commit.sh`、`test_github_pr_publication.sh` 除了已記錄的路徑與斷言調整，結果相同；既有的基線失敗若存在，與本次修改分開說明。
- [x] 12.2 以新啟動的 Session 重播 1.2 的九個案例與 10.1 的兩個新案例，把實際的呼叫與判定寫入驗證文件並逐項比對。GI-02 與 GP-21 重播時不提供 `docs/github-handoff.md`；GP-40 與 GP-44 重播時只提供 `github-pr` 的目錄，不提供 `change-review` 與整合說明。測試要求：十一案判定與預期相同，沒有出現任何禁止項目；記下實際使用的工具與模型；重播是離線決策驗收，不宣稱做過真實的 GitHub 寫入；任何差異都回到對應的來源修正，不修改預期。
- [x] 12.3 執行 `openspec validate separate-github-contract-from-workflow --strict` 並以 `openspec-verify-change` 驗證。測試要求：validate 通過；verify 沒有 CRITICAL；每個 delta spec 情境都對應到一個自動斷言或一個重播案例，對照表寫入驗證文件；design.md D2 的接收者對照表每一列都標明已完成與證據位置。

## Workflow follow-up

- 最新規劃版本（digest `0f099bd…`）未經設計複審，依使用者的 `/openspec-apply-change` 指示開始實作；實作完成後需要一輪 Review。
- 不因規劃完成而自動 commit、push、建立 PR 或安裝。Review、封存與交付依各自授權執行。
- Archive 時直接更新主 spec `openspec/specs/github-change-handoff/spec.md` 的 Purpose（delta 無法修改既有 capability 的 Purpose），改為描述個人流程與 GitHub 協作的整合。
