# Delta Spec: mutation-check

## ADDED Requirements

### Requirement: 兩個 skill 安裝到雙工具目錄
`template/common/skills/mutation-setup/SKILL.md` 與 `template/common/skills/mutation-check/SKILL.md` 必須存在，且執行 `scripts/skills/install.sh` 後兩者 SHALL 同時複製到目標專案的 `.claude/skills/` 與 `.agents/skills/`，各自兩份內容一致。

#### Scenario: install.sh 安裝兩個 skill 到兩個位置
- **WHEN** 對任一目標專案執行 `bash scripts/skills/install.sh`
- **THEN** `mutation-setup` 與 `mutation-check` 的 SKILL.md 在 `.claude/skills/` 與 `.agents/skills/` 皆存在且各自內容相同

#### Scenario: SKILL.md frontmatter 完整
- **WHEN** 讀取任一 mutation skill 的 SKILL.md
- **THEN** frontmatter 包含 name、description、compatibility、metadata.version 欄位

### Requirement: 依專案 manifest 偵測語言與工具
兩個 skill 執行時 SHALL 依 manifest 檔偵測語言：`pyproject.toml` 或 `setup.py` → mutmut；`package.json` → Stryker；兩者皆有則各自處理；皆無則中止並說明不支援。

#### Scenario: Python 專案選用 mutmut
- **WHEN** 專案根目錄存在 `pyproject.toml`
- **THEN** skill 使用 mutmut，範圍限定變更的 `*.py` 檔（排除 tests/）

#### Scenario: TS/JS 專案選用 Stryker
- **WHEN** 專案根目錄存在 `package.json`
- **THEN** skill 使用 Stryker，範圍限定變更的 `*.ts` / `*.js` 檔（排除 test/spec 檔）

#### Scenario: 不支援的專案類型中止
- **WHEN** 專案根目錄無 `pyproject.toml`、`setup.py`、`package.json`
- **THEN** skill 中止並說明僅支援 Python 與 TS/JS

### Requirement: mutation-setup 冪等處理安裝與設定，不由 installer 處理
`mutation-setup` skill SHALL 負責偵測與安裝/升級 mutation 工具、收集並寫入設定值；所有安裝與寫檔前 MUST 先詢問使用者。skill SHALL 為冪等：偵測到既有安裝或設定時顯示現值並讓使用者選擇保留或更新，MUST NOT 盲目覆蓋既有設定。`install.sh` MUST NOT 安裝套件或寫入目標專案的 manifest / 設定檔。

#### Scenario: 工具未安裝時詢問後安裝
- **WHEN** 偵測到 Python 專案但 mutmut 不在依賴中
- **THEN** setup 詢問使用者，同意後以 `uv add --dev mutmut`（或 pip fallback）安裝，拒絕則中止

#### Scenario: 重跑 setup 不覆蓋既有設定
- **WHEN** 專案已有 mutation 工具與設定，使用者再次執行 `mutation-setup`
- **THEN** setup 顯示目前設定值並讓使用者保留或更新，未經確認不覆蓋

#### Scenario: installer 不碰專案本體
- **WHEN** 執行 `bash scripts/skills/install.sh --target <project>`
- **THEN** 目標專案的 `pyproject.toml`、`package.json`、`stryker.config.json` 不被建立或修改

### Requirement: mutation-check 以 setup gate 銜接設定
`mutation-check` skill SHALL 在執行前偵測工具是否已安裝與設定；未就緒時 MUST NOT 自行安裝，而是停止並提示使用者先執行 `/mutation-setup`，並詢問是否現在執行 setup。

#### Scenario: 未設定時導向 setup
- **WHEN** 執行 `/mutation-check` 但 mutation 工具未安裝或設定缺失
- **THEN** skill 停止 mutation run，提示先執行 `/mutation-setup`，並詢問是否現在執行

#### Scenario: 已設定時直接執行
- **WHEN** 執行 `/mutation-check` 且工具與設定皆就緒
- **THEN** skill 不進行任何安裝，直接進入 diff scope 與 mutation run

### Requirement: diff-based 執行範圍
skill SHALL 只對變更檔執行 mutation testing：工作區有未 commit 變更時取 `git diff HEAD`；工作區乾淨時取與 default branch 的 merge-base 之後的變更；在 default branch 上則取上次 watermark 以來的變更。

#### Scenario: 工作區有未 commit 變更
- **WHEN** `git status` 顯示有未 commit 的程式碼變更
- **THEN** mutation 範圍為 `git diff --name-only HEAD` 中符合語言副檔名的檔案

#### Scenario: 工作區乾淨且在 feature branch
- **WHEN** 工作區乾淨且 HEAD 不在 default branch
- **THEN** mutation 範圍為 merge-base 之後變更的檔案

#### Scenario: 大範圍 diff 警告
- **WHEN** 估算的 mutant 數量超過 SKILL.md 定義的門檻
- **THEN** skill 先警告預估耗時並讓使用者確認或縮小範圍

### Requirement: 存活 mutant 報告與決策選單
執行完成後 skill SHALL 輸出 mutation score 與存活 mutant findings 表（檔案:行、mutation 內容、建議的測試方向），並提供決策選單：補測試、標記 equivalent、skip（記錄理由）。findings SHALL 依 mutation 類別排序，高風險類別（conditional logic、boundary、return value）優先於其他類別。結果 SHALL 為 advisory，MUST NOT 阻擋 commit 或標記任務失敗。

#### Scenario: 有存活 mutant
- **WHEN** mutation run 完成且存在測試未殺死的 mutant
- **THEN** 輸出 findings 表與三選項決策選單（補測試 / equivalent / skip）

#### Scenario: findings 依風險類別排序
- **WHEN** 存活 mutant 同時包含 conditional/boundary/return-value 類與語句刪除類
- **THEN** findings 表中高風險類別（conditional / boundary / return value）排在前面

#### Scenario: 全部 mutant 被殺死
- **WHEN** mutation run 完成且 mutation score 為 100%
- **THEN** 報告 score 並直接更新 watermark，不出決策選單

### Requirement: watermark 狀態持久化
skill SHALL 在每次執行後更新 watermark 檔（有 `openspec/` 時為 `openspec/.mutation-state`，否則 `.mutation-state`），記錄執行時點與 equivalent mutant 標記；後續執行 SHALL 略過已標記 equivalent 的 mutant。

#### Scenario: equivalent 標記跨執行保留
- **WHEN** 某 mutant 曾被標記 equivalent，且下次執行再度存活
- **THEN** 該 mutant 不出現在 findings 表，但摘要註明已略過的 equivalent 數量
