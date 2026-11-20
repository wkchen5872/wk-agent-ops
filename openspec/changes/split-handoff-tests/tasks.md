# Tasks

## 1. 基線

- [x] 1.1 在 main 上依序完整執行一次 `bash tests/test_agent_handoff.sh`，保存輸出與所需時間，並把排序後的 `^  (ok|FAIL) ` 行存成基線清單。
  - 測試要求：記錄指令、結束代碼、秒數與 ok／FAIL 數量（預期 495／0）；之後每一步都和這份清單比對（design D6）。
  - 結果（2026-11-20）：在 main `195f0f5` 的獨立 worktree 執行 `bash tests/test_agent_handoff.sh`，結束代碼 0，465 秒，495 ok／0 FAIL；
    排序後的名稱清單與各區段的名稱清單存在 scratchpad（`baseline-names.txt`、`base-sec/`）。

## 2. 假 CLI 移出

- [x] 2.1 把 xirp、gh、notify.sh、claude、codex、herdr、herdr-app、hc、pi 的 heredoc 原樣搬到 `tests/handoff/fakes/`，保留執行權限，開頭註明模擬的 CLI、對照版本、狀態目錄與可切換的狀態檔；`$FAKES` 改為指向這個目錄（design D3）。
  - 測試要求：完整執行的斷言名稱清單和基線完全相同；`grep` 確認測試程式中不再有寫入 `$FAKES/` 的程式。
  - 結果：以 2.1 完成時的檔案逐區段平行執行，495 行與基線完全相同，15 個區段各自也相同；`grep` 已無寫入 `$FAKES/` 的程式（`path_without` 只複製 `$FAKES` 到 `$tmp`）。
    pi 也改為固定檔案後，非 pi 區段的 `PATH` 會找到假 pi 而不是本機的 pi；這些區段不會呼叫 pi，結果不變。

## 3. 斷言 helper

- [x] 3.1 在共用 helper 加入 `check`，用腳本把 `COND && ok "N" || bad "N"` 與 `|| { bad "N"; DIAG; }` 兩種寫法改成 `COND; check "N"`；腳本處理不了的寫法以人工轉換；列出 ok 與 bad 名稱原本不一致的位置（design D5）。
  - 測試要求：完整執行的斷言名稱清單和基線完全相同；`grep` 確認除了 `check` 本身之外，已沒有成對的 `&& ok`／`|| bad`；不一致名稱清單記在本 task 下方。
  - 結果：腳本改寫 424 處（含 33 處跨兩行的 `&& ok … \` + `|| bad …`），`if … then ok … else bad … fi` 以腳本改寫 24 處，
    人工改寫 5 處（`if X; then bad; else ok; fi` 與 `X && bad || ok` 改成 `! X; check`）。名稱清單與基線完全相同，15 個區段各自也相同。
    已無 `&& ok`；剩下的 `|| bad` 只有 7 處 `COND && stop_case/retry_case … || bad …`（呼叫 helper，不是成對的 ok／bad），以及 helper 內部的
    `else bad`。這些 helper 每個分支都回傳 0，所以呼叫端的 `|| bad` 語意不變。
  - ok 與 bad 名稱不一致：93 處，全部是 bad 名稱在 ok 名稱後面多一段括號後綴；其中 90 處是診斷值，3 處是說明
    （`(left a file)`、`(notified again)`、`(second run)`）。依 D5 保留 ok 的名稱；後綴改成失敗時在下一行印出
    （`check "N" || printf '       %s\n' "(…)"`，沿用檔內既有的診斷格式），所以失敗時資訊不會遺失。
    <details><summary>完整清單（依區段）</summary>

    - write（1）
      - "$label" → 後綴 `(left a file)`
    - skill（5）
      - "SKILL.md documents every record field" → 後綴 `(missing:$missing)`
      - "handoff-author prints the four Author lines from the Codex environment" → 後綴 `($a1)`
      - "handoff-author reads the Claude Code ID and writes null for a missing Xirp ID" → 後綴 `($a2)`
      - "handoff-author omits an unknown model and writes null for a missing native ID" → 後綴 `($a3)`
      - "inside a herdr pane handoff-author ignores an inherited Xirp ID" → 後綴 `($a4)`
    - install（2）
      - "every role template sets harness, model, effort, name and prompt" → 後綴 `(missing:$missing)`
      - "every example role prompt asks for the Author identity" → 後綴 `($n_author/3)`
    - route（1）
      - "inside a herdr pane the routing log does not name an inherited Xirp session" → 後綴 `($(cat "$HE/.agent-handoff/add-export/routing.log" 2>/dev/null))`
    - notify（17）
      - "implementation handover names change, round, 7-character commit and the reviewer step" → 後綴 `($(jl | tail -1))`
      - "agent label comes from Xirp's tool, model and effort" → 後綴 `($(jl | tail -1))`
      - "changes-required sends a review notice that the implementer was asked" → 後綴 `($(jl | tail -1))`
      - "a later handover names round 2 and its commit" → 後綴 `($(jl | tail -1))`
      - "a pass with trigger ask is an attention notice to run handoff-finish" → 後綴 `($(jl | tail -1))`
      - "notices follow the loop in order" → 後綴 `($(kinds))`
      - "a pass with trigger auto opens finish and sends a review notice" → 後綴 `($(kinds))`
      - "a manual foreground run routes the record and leaves out the agent and session label" → 後綴 `($(jl | tail -1))`
      - "$1" → 後綴 `(notified again)`
      - "$1" → 後綴 `(second run)`
      - "a retry that reaches the reviewer sends the message and the progress notice once" → 後綴 `($(kinds))`
      - "a retried record's notice leaves out the agent and session label of whoever triggered the retry" → 後綴 `($(jl | tail -1))`
      - "a retry that reaches the implementer sends the message and the review notice once" → 後綴 `($(kinds))`
      - "a later run opens the reviewer and sends the progress notice" → 後綴 `($(kinds))`
      - "a finish session that cannot be opened leaves the prepared finish worktree and the record unprocessed" → 後綴 `($(kinds))`
      - "a retry reuses that finish worktree, opens one finish session and sends one review notice" → 後綴 `(created $(created), $(kinds))`
      - "an unclean reused review worktree stops for the user without opening the reviewer" → 後綴 `(created $(created), $(kinds))`
    - mixed（2）
      - "only the notifier updated: the previous handoff notice is still delivered" → 後綴 `($out)`
      - "the registered hook command is unchanged for Claude Code and Codex" → 後綴 `($hc)`
    - start（1）
      - "outside herdr the herdr role uses herdr_session from roles.yaml" → 後綴 `($(kv_get "$hvl" reviewer.herdr_session))`
    - herdr（2）
      - "a missing repository workspace is opened, then the loop's worktree workspace under it" → 後綴 `($seq)`
      - "a reviewer stopped at a trust dialog keeps its pane, sends one notice naming its workspace and tab, and answers nothing" → 後綴 `($(kinds))`
    - hookinstall（3）
      - "registers exactly one Stop hook for Claude Code and Codex after two runs" → 後綴 `($n_claude/$n_codex)`
      - "fills absent, null, empty and whitespace handoff names in place" → 後綴 `(failed:$nfail)`
      - "README documents every command option" → 後綴 `(missing:$missing)`
    - cleanup（1）
      - "each loop session is deleted once" → 後綴 `($(deleted | tr '\n' ' '))`
    - pi（58）
      - "a model listed under two providers is accepted for the declared one" → 後綴 `($out)`
      - "a model listed only under another provider is refused" → 後綴 `($out)`
      - "an alias is not a model ID" → 後綴 `($out)`
      - "a model without thinking is refused unless effort is off" → 後綴 `($out)`
      - "effort off accepts a model without thinking" → 後綴 `($out)`
      - "oauth with billing api is refused naming the role, the declared and the actual billing" → 後綴 `($out)`
      - "api_key with billing api is accepted" → 後綴 `($out)`
      - "api_key with billing subscription is refused" → 後綴 `($out)`
      - "a $st credential is refused" → 後綴 `($out)`
      - "an unknown credential type is a mismatch" → 後綴 `($out)`
      - "without the pi command every Pi role is refused" → 後綴 `($out)`
      - "a matching Anthropic subscription is accepted with the extra usage warning" → 後綴 `($out)`
      - "Anthropic API keys and other subscriptions get no warning" → 後綴 `($out)`
      - "a mismatched Anthropic subscription is refused without the warning" → 後綴 `($out)`
      - "a failing credential check is refused even when it prints ready (codex-pi-handoff-r03/F-04)" → 後綴 `($out)`
      - "a credential answer that is not one complete JSON object is refused (codex-pi-handoff-r04/F-02)" → 後綴 `($out)`
      - "the settings file names the provider, model and thinking level" → 後綴 `($out)`
      - "different settings are refused and left unchanged" → 後綴 `($out)`
      - "a tracked settings file is refused and left unchanged" → 後綴 `($out)`
      - "the refusal tells the user to give the Pi role worktree: new" → 後綴 `($out)`
      - "a matching Anthropic subscription starts with the warning on stderr" → 後綴 `($err)`
      - "a Pi override without billing shows the expected form" → 後綴 `($out)`
      - "a Pi override renames the session and keeps a prompt that starts with no skill call" → 後綴 `($(kv_get "$pl" review_template.name))`
      - "a Pi override is verified like a template" → 後綴 `($out)`
      - "a record written in Pi carries the session's agent identity" → 後綴 `($(cat "$r" 2>/dev/null | tr '\n' ' '))`
      - "handoff-author reads the Pi session ID" → 後綴 `($a1)`
      - "handoff-author writes null for missing Pi and Xirp IDs" → 後綴 `($a2)`
      - "a matching Pi record is routed as usual" → 後綴 `($(kinds))`
      - "the notice shows Pi's provider, model, effort and subscription from the record" → 後綴 `($(jl | tail -1))`
      - "an API record is labelled API" → 後綴 `($(jl | tail -1))`
      - "the mismatch notice shows unknown billing" → 後綴 `($(jl | tail -1))`
      - "a manual foreground retry still shows the Pi agent from the record" → 後綴 `($(kinds); $(jl | tail -1))`
      - "the notifier's dry run titles a Pi handoff with provider and billing" → 後綴 `($dry)`
      - "a Pi reviewer whose billing no longer matches is not opened, one notice names it, and the record waits" → 後綴 `($(kinds); $(jl | tail -1))`
      - "a review worktree with other Pi settings is not opened and the file is kept" → 後綴 `($(kinds))`
      - "handoff-finish refuses a Pi finish role that fails verification" → 後綴 `($out)`
      - "handoff-finish refuses a passing Pi review that differs from its template" → 後綴 `($out)`
      - "handoff-finish accepts a matching passing Pi review" → 後綴 `($out)`
      - "a finish retry ignores a passing Pi review that differs from its template" → 後綴 `($out)`
      - "a failed loop.yaml copy into a new finish worktree opens no session and leaves the review unprocessed" → 後綴 `($(created); $(kinds))`
      - "the retry completes the finish worktree's loop.yaml, opens one finish session and the trust check passes" → 後綴 `($(created))`
      - "a failed loop.yaml copy into a new review worktree opens no reviewer and leaves the record unprocessed" → 後綴 `($(created); $(kinds))`
      - "the retry copies loop.yaml into the review worktree and opens the reviewer once" → 後綴 `($(created))`
      - "a failed write of finish.worktree into loop.yaml opens no finish session and leaves the review unprocessed" → 後綴 `($(created); $(kinds))`
      - "after the write succeeds the prepared finish worktree is reused, trusted and opened once" → 後綴 `($(created))`
      - "a failed write of reviewer.worktree into loop.yaml opens no reviewer and leaves the record unprocessed" → 後綴 `($(created); $(kinds))`
      - "after the write succeeds the reviewer opens once in a trusted review worktree" → 後綴 `($(created))`
      - "a hand-made worktree with the finish worktree's name is left alone and nothing opens" → 後綴 `($out)`
      - "a finish worktree with neither the loop's record nor its loop.yaml is not reused" → 後綴 `($out)`
      - "a Pi role is not opened in a worktree the Pi trigger would not trust" → 後綴 `($out)`
      - "a Pi reviewer on herdr gets its settings file and runs Pi on the template's provider, model and thinking" → 後綴 `($(kinds))`
      - "cleanup removes the Pi settings the loop wrote in the main worktree" → 後綴 `($hout)`
      - "Claude Code and Codex keep one Stop hook each" → 後綴 `($n_claude/$n_codex)`
      - "the hook opens the reviewer from the changed role" → 後綴 `($(cat "$FAKE_XIRP_DIR/create-2.json" 2>/dev/null | jq -c '{n: .customName, a: .agent.agentName}'))`
      - "the README example replaces an open reviewer and hands the waiting round to the new Pi reviewer" → 後綴 `($rex)`
      - "the commented Pi example in roles.example.yaml passes the template check and verification" → 後綴 `($(cat "$exf" 2>/dev/null | head -3))`
      - "$1" (mismatch_case) → 後綴 `($(kinds); $(jl | tail -1))`
      - "after the fix the hook opens the Pi reviewer with its settings and sends no second attention" → 後綴 `($(kinds))`

    </details>

## 4. 拆檔與執行器

- [x] 4.1 把區段外的共用程式依原順序搬到 `tests/handoff/lib.sh`，每個區段搬成 `tests/handoff/<section>.sh`，開頭 `source lib.sh`、結尾 `finish_section`；每個區段建立自己的 `$tmp`（design D1、D2）。
  - 測試要求：15 個區段逐一單獨執行，每個區段的名稱清單和基線中該區段的部分相同。
  - 結果：15 個區段以 `bash tests/test_agent_handoff.sh <section>` 逐一單獨執行（8 個並行），每個區段的名稱清單都和基線中該區段相同，結束代碼皆為 0。
    區段內容保留原本的縮排（區段內有 heredoc 與跨行字串，去縮排可能改到測試資料）。單獨執行時各區段秒數：
    pi 172、herdr 139、happ 96、finish 69、notify 50、start 45、mixed 27、route 24、doctor 20、cleanup 16、install 5、write 3、hookinstall 3、skill 0、kv 0。
- [ ] 4.2 `tests/test_agent_handoff.sh` 改成執行器：單一區段直接執行；`all` 用 `xargs -P "$HANDOFF_TEST_JOBS"` 平行執行並依固定順序印出；未知區段以非 0 結束並列出可用區段；失敗時印 `FAILED` 並以 1 結束（design D4）。
  - 測試要求：完整平行執行連跑 3 次，名稱清單都和基線相同；記錄每次秒數，目標 180 秒內；暫時改壞一個區段，確認印出 `FAILED` 且結束代碼為 1，再還原；`HANDOFF_TEST_JOBS=1` 時結果相同。
  - 結果：完整平行執行（預設 8 個並行）連跑 3 次，名稱清單都和基線相同（495 ok、0 FAIL、rc 0），秒數 186、183、185，
    **未達 180 秒目標**（基線 465 秒）。`HANDOFF_TEST_JOBS=1`：435 秒，名稱相同。暫時讓假 `notify.sh` 不留紀錄：27 個 FAIL、印出
    `test_agent_handoff: FAILED`、結束代碼 1，已還原；未知區段 `nope`：結束代碼 2 並列出可用區段。
  - 瓶頸是 pi 區段：沒有其他負載時單獨跑 146 秒，平行時因 CPU 競爭變成約 172–180 秒。執行器已改成依耗時由長到短啟動（只影響啟動順序，
    輸出仍依固定順序）。試過的其他做法：4 個並行 220 秒、6 個並行 182 秒；其他區段以 `nice -n 10` 執行為 181 秒（3 次），沒達標所以未保留。
    要穩定低於 180 秒需要把 pi 拆成兩個區段，超出 design D1 的區段劃分，待決定；因此本 task 未勾選。

## 5. 文件與收尾

- [x] 5.1 檔案開頭的 Usage 說明更新；若 `scripts/handoff/README.md` 或 `AGENTS.md` 的相關文件清單提到 handoff 測試的位置或寫法，一併同步，補上 `tests/handoff/` 的說明。
  - 測試要求：文件類；照文件中的指令執行一次，確認可用。
  - 結果：`tests/test_agent_handoff.sh` 檔頭 Usage 補上 `all` 的平行執行、`HANDOFF_TEST_JOBS` 與 `tests/handoff/` 結構；`AGENTS.md` 相關文件清單
    補上 `tests/test_agent_handoff.sh` 與 `tests/handoff/`。`scripts/handoff/README.md` 沒有提到測試的位置或寫法，不需修改（`scripts/` 也須維持無 diff）。
    照文件執行 `bash tests/test_agent_handoff.sh kv`（ok、rc 0）、`bash tests/handoff/kv.sh`（`handoff/kv: ok`）與未知區段（rc 2），皆符合說明。
- [x] 5.2 確認 `git diff main -- scripts template` 為空，並執行 repo 其他會用到 handoff 的測試檔（`tests/test_workflow.sh` 等），全部通過。
  - 測試要求：指令輸出全部通過、diff 為空。
  - 結果：`git diff main -- scripts template` 為 0 行。`tests/test_agents_dir.sh`、`test_change_review.sh`、`test_github_handoff.sh`、
    `test_openspec_commit.sh`、`test_work_items.sh`、`test_workflow.sh` 全部 PASS（rc 0）。
