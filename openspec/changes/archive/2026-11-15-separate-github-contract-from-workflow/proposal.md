# Proposal

## Why

GitHub 協作有兩個不同性質的部分，現在被綁在一起：

- **團隊協作**：Issue／PR 的統一格式、Agent 留下的標記（Author）、寫入前核對與寫後回讀。只要用 Issue／PR 協作就適用，由 `github-issue`、`github-pr` 執行。
- **個人開發流程**：開立規格、實作、Review、封存交付四個階段，以及各階段何時接上 GitHub。這只是其中一種工作方式，Issue 與 PR 在其中都是選用的。

目前的 `docs/github-handoff.md`（1375 行）同時擁有全部格式與流程規則，兩個 Skill 的開頭都寫著「先讀這份契約的第 3、4、5、6…節」。結果是：只想開一張 Issue 也要先讀一份含個人流程的大文件；讀者以為用這兩個 Skill 就必須走那套流程；五個 Skill 各帶一份只在開發時使用的驗收題庫（合計 254 案），隨安裝散布到每個專案；開立規格階段的文件與圖稿只描述「先建立 Change、再視需要開 Issue」，沒有「同仁先開 Issue、我再接手規劃」這條路。

## What Changes

格式、欄位、Author 與操作的內容不變；改變的是由誰持有、讀者要讀哪裡。Review 與封存交付兩個階段的既有行為保留，只調整引用。

- **格式由 Skill 自足持有。** Issue／PR 的格式、Author、操作與必要核對放進 `github-issue`、`github-pr` 各自的 SKILL.md 與必要 references：每次都要用的少量規則放 SKILL.md，骨架與完整範例放 `references/examples.md`。審查識別規則（verdict、phase、review-id、Finding ID 與四種狀態）約 15 行，由 `github-pr` 與 `change-review` 各持有一份相同的區塊，因為兩者都會單獨寫出審查內容；完整報告範例與審查流程規則只在 `change-review`。只執行其中一個 Skill 時，不需要讀其他文件。
- **`docs/github-handoff.md` 改為整合說明。** 只說明個人流程在哪些時點接上 GitHub、呼叫哪個 Skill 的哪個操作、交出與取回什麼資訊，並連到各 Skill；不再重貼任何貼文範本，也不保留原章節編號。
- **必讀依賴跟著調整。** `docs/agent-protocol.md`、rule `github-handoff.md`、seed `AGENTS.md` 與 `docs/openspec-workflow.md` 改為「操作 Issue／PR 時使用對應的 Skill」，不再要求每次寫入前先讀整合說明；寫入前核對目標、操作與授權並回讀的最低要求仍留在 protocol。
- **每條離開契約的規則都有接收者。** 寫入核對、工具與帳號限制、Checkpoint、Closure、批准紀錄、舊格式相容等歸入對應 Skill；Apply 授權與各階段不得互相推定歸入 `docs/openspec-workflow.md`；最終複審縮小範圍的規則歸入 `change-review`。
- **五份驗收題庫移出 Skill。** `openspec-commit`、`github-pr`、`github-issue`、`git-commit-writer`、`change-review` 的 `references/acceptance-cases.md` 與契約附錄 A 的共同案例，移到 `tests/acceptance/` 作為測試題庫；去重候選逐案比對，預設保留；只有情境、判定與全部禁止項目都被涵蓋，且沒有其他案例沿用其內容時才刪除，並留下對照。搬移前先把題庫裡執行時需要的內容（`change-review` 的完整報告範例）抽到該 Skill 的 `references/examples.md`。
- **既有安裝副本精確退役。** installer 的 rsync 不會刪除來源已不存在的檔案，因此新增退役步驟：只移除與曾經出貨版本逐位元相同的題庫副本，改過的副本、symlink 與無關檔案原地保留並回報。
- **開立規格階段有兩個入口。** Issue-first：同仁已開 Issue → 接手讀取問題與驗收資訊 → 規劃並建立或沿用 Change；Change-first：先在本機建立 Change → 視需要建立或沿用 Issue，也可以不建立。兩條路徑都不重複開 Issue。`local-development-define.svg`、managed 流程圖與相關文件同步更新。`docs/diagrams/` 改為只保留 SVG：使用者已刪除六張 PNG，仍指向它們的 12 處連結改指向同名 SVG。

### 驗收條件

1. 只給 `github-issue` 或 `github-pr` 的 Skill 目錄（不提供 `docs/github-handoff.md`），Agent 能完成授權範圍內的各項操作（Issue 的 create、update、close；PR 的 create、update、reply、close），產出的格式、Author 與核對步驟與現行相同；只給 `github-pr` 時，第一輪審查回覆與複審的 Finding 狀態也能依原規則寫出。
2. `docs/github-handoff.md` 不含任何完整的貼文範本；每個接上 GitHub 的時點都寫明呼叫的 Skill 操作與交接資訊；Skills、rule、protocol 與 seed `AGENTS.md` 不再要求寫入前先讀它。
3. 原契約的每一節都有記錄在案的去向（接收者或刪除理由），沒有規則因搬移而消失。
4. `template/common/skills/` 下沒有 `acceptance-cases.md`，也沒有檔案引用它；五份題庫與共同案例都在 `tests/acceptance/`，每個被刪除的案例都有「由哪一案涵蓋」的紀錄。
5. 新安裝的專案沒有題庫副本；既有專案重跑 installer 後，未修改的舊副本被移除，改過的副本、symlink、其他 references 與第三方 Skill 不受影響，再跑一次結果相同。
6. 開立規格階段的兩個入口各有可判定的情境與交接資料；`local-development-define.svg` 與文件一致並經實際渲染檢查；本 repo 文件中沒有指向 `docs/diagrams/` 下 PNG 的連結。
7. Review 與封存交付的既有測試在修改前後結果相同；抽樣重播的案例判定與修改前相同。
8. 執行 installer 後 template 與安裝位置一致，`tests/` 下所有測試通過。

## Capabilities

### New Capabilities

- `openspec-change-lifecycle`: OpenSpec Change 各階段的授權與證據規則——什麼指示可以開始實作、各階段不得互相推定、驗收條件改變時回到 OpenSpec。不論是否使用 GitHub 都適用。
- `skill-acceptance-cases`: 指令型 Skill 的可重播驗收案例放在 repo 的測試題庫，不隨 Skill 出貨；規定題庫位置、案例格式、刪除案例的紀錄，以及出貨的 Skill 只帶執行時需要的內容。

### Modified Capabilities

- `github-change-handoff`: 由「擁有格式的共用契約」改為「個人流程與 GitHub 協作的整合說明」；新增開立規格的兩個入口；移出生命週期 requirement；原本寫明由共用契約擁有範本與 Review schema 的 requirement 改為由各 Skill 持有。
- `github-issue`: Issue 的格式、Author 與寫入核對由 Skill 自己持有，不依賴整合說明。
- `github-pr`: PR 正文、各類回覆與批准紀錄的格式及讀寫規則由 Skill 自己持有；是否可以開始實作改由 `openspec-change-lifecycle` 定義。
- `change-review`: 報告格式由 Skill 持有並透過 `github-pr reply` 發布；新增「最終複審只有在差異證據支持時才縮小範圍」，承接原本只寫在契約的規則。審查準則與流程不變。
- `openspec-commit`: 補上「原 PR 已合併後才產生的交付變更」情境；既有行為不變。
- `install-profile-cli`: 新增已退役 Skill 題庫副本的移除規則。

## Impact

- **Skills**（`template/common/skills/`）：`github-issue`、`github-pr` 的 SKILL.md 與 `references/examples.md`，`github-pr` 新增 `references/approval-records.md`；`change-review` 的 SKILL.md、`references/checklists.md`，新增 `references/examples.md`；`openspec-commit`、`git-commit-writer` 的 SKILL.md 與 references 只調整引用。五個 Skill 的 `references/acceptance-cases.md` 移除。
- **Managed 文件**：`template/common/docs/github-handoff.md` 重寫；`template/common/docs/diagrams/github-handoff.svg`、`template/common/docs/agent-protocol.md`（版本遞增）、`template/common/docs/openspec-workflow.md`、`template/common/AGENTS.md`、`template/common/.claude/rules/github-handoff.md`。
- **測試**：新增 `tests/acceptance/`（五份題庫、共同案例、重播方法說明）；`tests/test_github_handoff.sh`、`tests/test_change_review.sh`、`tests/test_openspec_commit.sh` 改讀新位置並調整斷言。
- **Installer**：`scripts/skills/install.sh` 新增題庫副本的退役步驟。
- **本 repo 文件與圖稿**：`docs/workflow/local-development.md`、`docs/workflow/commit.md`、`docs/diagrams/local-development-define.svg`、`docs/workflow/guide.md` 與 `docs/workflow/wt-work-flow.md`（PNG 連結改為 SVG）、`docs/diagrams/README.md`、退役舊圖稿目錄 `docs/diagrams/github-change-handoff/`（現行入口由 `docs/diagrams/README.md` 與 `docs/architecture.md` 承接，新架構圖為 `docs/diagrams/skill-workflow-architecture.svg`）、`docs/skills/` 下五份 Skill 說明、`docs/architecture.md`、`AGENTS.md`、`README.md`。
- **相容性**：已發布的 Issue／PR、留言與舊格式仍可讀；既有專案的 seed `AGENTS.md` 仍指向 `docs/github-handoff.md`，該路徑保留並在開頭指向各 Skill。支援 Claude Code、Codex 與 Antigravity：Skills 安裝在 `.claude/skills/` 與 `.agents/skills/`，只讀 `AGENTS.md` 的工具可沿 protocol 與整合說明找到 Skill 檔案。
