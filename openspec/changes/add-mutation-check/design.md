# Design: add-mutation-check

## Context

本 repo（wk-agent-ops）透過 `scripts/skills/install.sh` 將 skills / rules / docs 安裝到目標專案。現有 `entropy-check` skill 已建立「週期性健檢 skill」的形狀：偵測 context → 執行檢查 → findings 摘要表 → 決策選單 → 更新 watermark。mutation-check 是同型的 skill，檢查對象從「文件與程式碼熵」換成「測試強度」。

現況痛點：TDD 的流程證據無法量測測試是否真的能抓到程式碼缺陷。

## Goals / Non-Goals

**Goals:**

- 提供 `/mutation-check` skill：diff-based mutation testing，支援 Python（mutmut）與 TS/JS（Stryker）
- 存活 mutant 以 findings 表呈現，附決策選單（補測試 / equivalent / skip）
- 在共用 TDD policy 中將 mutation testing 保持為 optional/advisory audit
- 安裝面零改動：沿用 install.sh 既有複製路徑

**Non-Goals:**

- 不設 mutation score gate（不進 pre-commit、不進 CI 硬條件）——沿用「先有證據再上 gate」決策
- 不支援 bash mutation testing（無成熟工具；本 repo 自身的 bash 測試不在範圍）
- installer 不安裝 mutmut / Stryker、不生成或合併目標專案的 pyproject.toml / stryker 設定
- 不做全量（full-codebase）mutation run 的排程自動化——skill 只定義 diff-based 與手動觸發

## Decisions

### D1: Skill 形狀比照 entropy-check（純 SKILL.md，無附帶腳本）

指令式 markdown，由 agent 執行時解讀。與 entropy-check 一致，避免引入需要維護的 runtime 腳本。
*Alternative considered*: 附帶 bash helper script——被否決，diff 計算與工具呼叫都是單行指令，agent 可直接執行；腳本反而要多測多維護。

### D1b: 拆成 setup 與 check 兩個 skill

以「執行頻率 + 有無副作用」為切線拆分，而非硬把 mutation testing 塞成單一 skill：

| | `mutation-setup` | `mutation-check` |
|---|---|---|
| 頻率 | 偶爾（初次 / 升級 / 改設定） | 頻繁（每次 diff / verify） |
| 性質 | 互動、有副作用、**冪等** | 非互動、零設定 |
| 職責 | install/upgrade 套件、設定值、gitignore | setup gate → diff → run → report → triage → watermark |

*Rationale*: 原設計把 bootstrap 塞在 run 的一個 step，使每次執行都背著安裝/設定的互動邏輯。兩者性質不同（一個冪等偶發、一個頻繁純粹），拆開後各自可獨立維護，run 路徑保持精簡。
*Alternative considered*: 單一 skill 內分 step——被否決，維護時 setup 與 run 邏輯互相干擾，且 run 無法保持零設定。

### D1c: setup 冪等，check 靠 setup gate 銜接

- **setup 冪等**：重跑時先偵測既有安裝與設定 → 顯示目前值 → 讓使用者 keep 或 update，不盲目重問、不覆蓋既有設定。只有升級套件或變更設定值時才需再跑，隨時可安全重入。
- **check 的 setup gate**：`mutation-check` 開頭偵測工具未安裝或設定缺失時**不自行安裝**，而是停下提示「請先執行 `/mutation-setup`」，並詢問是否現在就跑 setup。安裝/設定的副作用只發生在 setup skill，符合單一職責。

### D2: 語言偵測與工具對應

| 偵測到 | 工具 | 執行範圍 |
|--------|------|---------|
| `pyproject.toml` / `setup.py` | mutmut | 變更的 `*.py`（排除 tests/） |
| `package.json` | Stryker | 變更的 `*.ts` / `*.js`（排除 `*.test.*` / `*.spec.*`） |
| 兩者皆有（monorepo） | 各跑各的 | 各自的變更檔 |
| 皆無 | 中止並說明 | — |

### D3: diff base 計算

1. 工作區有未 commit 變更 → `git diff --name-only HEAD`
2. 工作區乾淨 → `git diff --name-only $(git merge-base HEAD <default-branch>)`；若已在 default branch，fallback 為上次 watermark 以來的 commits
3. watermark 存於 `openspec/.mutation-state`（無 openspec/ 的專案存 `.mutation-state`），格式比照 entropy-check 的 `.entropy-state`

### D4: 工具 bootstrap 由 `mutation-setup` 執行時處理，不由 installer 處理

由 setup skill（非 installer、非 run skill）負責，皆先詢問使用者：

- **install/upgrade**：mutmut → `uv add --dev mutmut`（fallback `pip install`）；Stryker → `npx stryker init`（一鍵裝 `@stryker-mutator/core` + 生成 config）。升級走 `uv add --dev --upgrade mutmut` / 更新 devDependency。
- **設定值**：mutmut 需 source 目錄（`[tool.mutmut] paths_to_mutate`）——問一次；Stryker 的 `stryker init` 本身即互動式收集 test runner / reporter。偵測到既有設定則顯示現值供 keep/update（冪等）。
- **gitignore**：`.stryker-tmp/`、`reports/stryker-incremental.json`、`.mutation-state`。
- 理由：installer 的邊界是「agent config」，合併他人 pyproject.toml 或猜測 mutate globs 屬於專案本體，錯了會直接弄壞目標專案。集中於 setup skill 也讓 run skill 維持零副作用。

### D5: 報告與決策選單

findings 表逐條列出存活 mutant（檔案:行、mutation 內容、殺死它需要的測試方向），並依 mutation 類別分組排序，優先呈現高風險類別：**conditional logic**（`>` → `>=`、`&&` → `||`）、**boundary**（邊界值）、**return value**（回傳值竄改）優先於其他（如語句刪除）。此分類借鑑 test-architect agent 的 surviving-mutant 優先級。結尾提供：

1. 針對選定 mutant 補測試（開 OpenSpec change 或直接 Level 1 修）
2. 標記 equivalent mutant（記入 watermark，之後不再報）
3. skip 並更新 watermark（記錄理由）

### D6: TDD policy integration 不由 mutation capability 擁有

本 change 只提供 mutation audit，並在共用 policy 中保留 optional/advisory
入口。TDD 適用範圍、Red 證據、conditional causal checks 與 Provider routing
由 `refine-tdd-enforcement-rules` 統一維護，避免兩個 active changes 以不同
archive 順序產生互斥主規格。

### D8: 靈感來源與定位差異

本 change 參考了兩份社群現成方案，但定位不同（詳見將寫入 `docs/` 的參考連結）：

- **test-architect agent**：通用測試策略知識庫，mutation testing 僅一節，且用寫死的 `score < 80%` 硬閾值。我們只吸收 surviving-mutant 分類；固定 revert-check 經後續 TDD policy refactor 改為條件式，不採用固定 score 閾值（與本 repo no-coverage-gate 決策一致）。
- **add-mutation-testing command**：一次性 setup 大綱（10 步 × 名詞式 bullet），無實際指令、無 diff scope 主軸、重 CI gate、無 triage 循環。我們**不採用**其形狀。

我們的定位是**可重複執行、有 watermark 狀態、diff-based 預設、advisory 不設 gate 的稽核工具**，這三點是與上述兩者的根本分野。

### D7: 指令定案前以 ctx7 查證（已查證，2026-07）

以 ctx7 取得現行文件查證結果如下，SKILL.md 指令依此撰寫：

**mutmut（v3，來源 `/boxed/mutmut`）**
- 設定：`pyproject.toml` 的 `[tool.mutmut]` 段落，key `source_paths`（或 `setup.cfg` 的 `[mutmut]`）
- scope 機制是 **module 名稱 pattern**，非檔案路徑：`mutmut run "my_module*"`、`mutmut run "my_module.my_function*"`
- ⚠️ diff-based 需把變更的 `.py` 路徑轉為 module pattern（`src/pkg/mod.py` → `pkg.mod*`），這是 skill 要處理的轉換
- 執行 `mutmut run`；看存活用 `mutmut results` / `mutmut show <id>`；結果在 `mutants/summary.json`
- 平行：`--max-children N`（預設 `os.cpu_count()`）

**Stryker（StrykerJS，來源 `/stryker-mutator/stryker-js`）**
- 安裝+設定一鍵：`npx stryker init`（裝 `@stryker-mutator/core` + 生成 `stryker.config.json`）
- scope 用 `--mutate <glob>`，可精確到檔案甚至行號：`npx stryker run --mutate src/app.js` / `src/app.js:5-7` ← diff-based 的理想接口
- incremental：`--incremental`（config 設 `"incremental": true`），搭配 `--force` 可強制重跑 scope 內全部
- diff-based 建議：`npx stryker run --incremental --force --mutate <變更檔清單>`

**版本假設註記**：SKILL.md 開頭註明「以 mutmut v3 / StrykerJS 現行版為準；介面變動時以 ctx7 重新查證」，避免訓練資料漂移。

## TDD 策略與測試邊界

本 change 的產出是 markdown（skill + rules + docs），可機械驗證的邊界在「安裝正確性與鏡像一致性」，比照 `tests/test_agents_dir.sh` 的風格新增 `tests/test_mutation_check.sh`：

- install.sh 執行後，`.claude/skills/mutation-check/SKILL.md` 與 `.agents/skills/mutation-check/SKILL.md` 皆存在且相同
- install 後 `.claude/rules/tdd-enforcement.md` 與 `.agents/rules/tdd-enforcement.md` 內容一致
- SKILL.md frontmatter 欄位齊全（name / description / compatibility / version）
- `docs/agent-protocol.md` 含 `/mutation-check` 參照

SKILL.md 的行為本身（agent 解讀執行）無法單元測試——驗收靠實際專案手動跑一輪（見 tasks 的 dogfood task）。

## Risks / Trade-offs

- [mutmut / Stryker 介面再變動] → SKILL.md 指令寫成「意圖 + 現行指令」，並在 skill 內註明版本假設；entropy-check 週期時可順檢
- [mutation run 在大 diff 上仍很慢] → skill 開頭先估算 mutant 數量（變更行數 × 經驗係數），超過門檻時警告並讓使用者縮小範圍
- [equivalent mutant 誤標導致漏洞] → watermark 記錄標記理由與日期，決策選單顯示既有標記供翻案
- [agent 提供合規但守護力不足的測試] → mutation-check 作為事後稽核測試有效性的第二道防線

## Open Questions

- Stryker 的 `.stryker-tmp` / incremental 檔案應 gitignore 或 commit？（傾向 gitignore，實作時定案）
- 全量 mutation run（非 diff-based）是否值得做成 skill 的 `--full` 模式？先不做，等 diff-based 用出心得
