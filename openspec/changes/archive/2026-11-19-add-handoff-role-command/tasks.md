# Tasks

## 1. override 換工具時改寫 skill 呼叫與名稱

- [x] 1.1 先寫失敗測試：start 區段以範例範本 `--impl codex:gpt-x:low --review claude:sonnet:max` 啟動後，審查 prompt 以 `/change-review` 開頭、名稱為 `claude - review - {change}`，實作者以 `codex - impl - add-export` 與 `$openspec-apply-change` 開啟；只換 model（`codex:gpt-6.1-terra:high`）時 prompt 與 name 不變。pi 區段以 `--review pi:openai-codex/gpt-6.2-sol:high:subscription` 啟動後名稱為 `pi - review - {change}`、非 skill 開頭的 prompt 不變。驗證：`bash tests/test_agent_handoff.sh start`、`pi` 以改寫案例失敗（Red）。
- [x] 1.2 在 `scripts/handoff/lib/handoff.sh` 新增 `ho_apply_override`（含 skill 呼叫與名稱改寫），`handoff-start` 改用它並移除 `apply_ov`。驗證：1.1 通過（Green），既有 start 與 Pi 測試維持通過。

## 2. `handoff-role` 指令

- [x] 2.1 先寫失敗測試（`pi` 區段末尾，沿用其假 `pi` 與 Pi HOME）：未開啟審查者時換成 Pi 後 `loop.yaml` 值、prompt、name 正確，交件後假 `xirp` 以新範本建立審查者；審查者已開啟、Pi 模型不在 provider 下、第二個 Pi 角色、override 格式錯誤時皆非零結束且 `loop.yaml` 位元組不變；`roles.yaml` 不變。驗證：`bash tests/test_agent_handoff.sh pi` 失敗（Red），原因是指令不存在。
- [x] 2.2 新增 `scripts/handoff/handoff-role`（流程見 design.md 決策 2）。驗證：2.1 通過（Green）。
- [x] 2.3 `scripts/handoff/install.sh` 安裝 `handoff-role`；hookinstall 區段測試加入其存在與可執行檢查，README 指令選項檢查涵蓋 `handoff-role --help`。驗證：`bash tests/test_agent_handoff.sh hookinstall` 先失敗（Red）後通過。
- [x] 2.4 更新文件：`scripts/handoff/README.md` 新增 `handoff-role` 指令段落並在 `handoff-start` override 說明補上換工具時的改寫；`docs/skills/agent-handoff.md` 對應說明。驗證：依 `docs/okf-conventions.md` 檢查；`bash tests/test_documentation_authoring.sh` 通過；README 中的指令範例以 `--help` 對照。

## 3. 整合驗收

- [x] 3.1 執行 `bash tests/test_agent_handoff.sh`、`bash tests/test_acceptance_bank.sh`、`openspec validate add-handoff-role-command --strict`。驗證：全部通過。

## Workflow follow-up

- 依專案流程封存本 change，確認 `openspec/specs/agent-crew-launcher/spec.md` 已加入兩條新需求。
- 合併後執行 `bash scripts/handoff/install.sh`。
