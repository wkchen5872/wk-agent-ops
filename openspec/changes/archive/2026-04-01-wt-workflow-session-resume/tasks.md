## 1. 建立 wt-work.sh（取代 wt-new.sh）

- [x] 1.1 建立 `scripts/workflow/wt-work.sh`，複製 wt-new.sh 作為起點
- [x] 1.2 更新 usage header 與腳本說明，反映 wt-work 語意
- [x] 1.3 新增 `--session / -s` 參數解析（argument parsing 區段）
- [x] 1.4 新增 `gemini` 為合法 `--agent` 選項（驗證邏輯）
- [x] 1.5 實作 resume path（目錄已存在）的各 agent 指令：
  - 無 --session: Claude `--resume "RD: $NAME" "/opsx:apply $NAME" --enable-auto-mode`
  - 有 --session: Claude `--resume <SESSION> "/opsx:apply $NAME" --enable-auto-mode`
  - 無 --session: Copilot `--resume --allow-all -i "/openspec-apply-change $NAME"`
  - 有 --session: Copilot `--resume=<SESSION> --allow-all -i "/openspec-apply-change $NAME"`
  - 無 --session: Gemini `--resume latest -i "/opsx:apply $NAME"`（已驗證：`-i` 為互動模式，`latest` 為自動恢復最新）
  - 有 --session: Gemini `--resume <SESSION> -i "/opsx:apply $NAME"`
- [x] 1.6 實作 new path（目錄不存在）的各 agent 指令：
  - 無 --session: Claude `--name "RD: $NAME" "/opsx:apply $NAME" --enable-auto-mode`（現有）
  - 有 --session: Claude `--resume <SESSION> "/opsx:apply $NAME" --enable-auto-mode`
  - 無 --session: Copilot `--allow-all -i "/openspec-apply-change $NAME"`（現有）
  - 有 --session: Copilot `--resume=<SESSION> --allow-all -i "/openspec-apply-change $NAME"`
  - Gemini new: `gemini -i "/opsx:apply $NAME"`（驗證：`-i` 為互動模式，非 `-p` headless）
  - Gemini new + session: `gemini --resume <SESSION> -i "/opsx:apply $NAME"`
- [x] 1.7 更新 banner 輸出：新增 `Session` 欄位（有 --session 時顯示）
- [x] 1.8 驗證 Gemini `-p` flag 語法（`gemini --help`），必要時修正

## 2. 修改 wt-resume.sh

- [x] 2.1 新增 `--session / -s` 參數解析
- [x] 2.2 新增 `gemini` 為合法 `--agent` 選項
- [x] 2.3 修改 Claude 無 session 行為：`claude --resume`（顯示清單，移除 "RD: $NAME" 自動帶入）
- [x] 2.4 實作各 agent 有 --session 的指令：
  - Claude: `claude --resume <SESSION>`
  - Copilot: `copilot --resume=<SESSION> --allow-all`
  - Gemini: `gemini --resume <SESSION>`
- [x] 2.5 實作 Gemini 無 session 行為：`gemini --resume latest`（auto latest）
- [x] 2.6 驗證 Copilot `--resume` 無 session 時的行為（確認會顯示清單）

## 3. 更新 Zsh Completion (_wt)

- [x] 3.1 新增 `wt-work` 指令到補全清單（取代 `wt-new`）
- [x] 3.2 `wt-work` 和 `wt-resume` 的 `--agent` 補全加入 `gemini` 選項
- [x] 3.3 新增 `--session / -s` flag 補全（hint: "session ID or name"）
- [x] 3.4 驗證補全：`wt-work <TAB>`、`wt-work f --agent <TAB>`、`wt-work f --session <TAB>`

## 4. 更新 install.sh

- [x] 4.1 安裝目標改為 `wt-work`（取代 `wt-new`）
- [x] 4.2 新增舊版 `wt-new` 自動刪除邏輯：若 `~/.local/bin/wt-new` 存在，刪除並印 `"✓ Removed stale binary: wt-new"`
- [x] 4.3 確認 `_wt` completion 也一起被 install 到正確位置

## 5. 更新文件

- [x] 5.1 `docs/workflow/guide.md`：將所有 `wt-new` 改為 `wt-work`
- [x] 5.2 `docs/workflow/guide.md`：新增 `--session` 使用說明段落
- [x] 5.3 `docs/workflow/guide.md`：新增 wt-work vs wt-resume 語意對比說明
- [x] 5.4 `scripts/workflow/README.md`：更新腳本名稱與參數文件

## 6. 部署與驗證

- [x] 6.1 執行 `bash scripts/workflow/install.sh`，確認 wt-work 已安裝
- [x] 6.2 驗證 `wt-work feature-test`（新建 worktree，Claude）
- [x] 6.3 驗證 `wt-work feature-test`（已存在 worktree，Claude resume + /opsx:apply）
- [x] 6.4 驗證 `wt-work feature-test --session <uuid>`（指定 session）
- [x] 6.5 驗證 `wt-resume feature-test`（Claude 顯示清單，不自動帶 session name）
- [x] 6.6 驗證 `wt-resume feature-test --session <uuid>`（Claude 指定 session）
- [x] 6.7 驗證 `wt-work feature-test --agent gemini`（Gemini 新 session）
- [x] 6.8 驗證 `wt-resume feature-test --agent gemini`（Gemini auto latest resume）
