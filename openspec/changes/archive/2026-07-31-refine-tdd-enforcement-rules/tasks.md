## 1. Test-first contract

- [x] 1.1 新增 `tests/test_tdd_enforcement.sh`，先斷言 managed protocol 的適用範圍、有效 Red、test integrity、分層驗證、conditional causal check，以及 Claude/Antigravity 薄入口與 Codex `AGENTS.md` pointer；在修改 template 前執行並確認因舊 policy 而 Red
  - 測試要求：記錄 test command、失敗 assertion、非零 exit code、預期失敗原因與最小輸出；不得把 syntax/setup failure 當作 Red

## 2. Policy and entrypoints

- [x] 2.1 重構 `template/common/docs/agent-protocol.md` 的 task-scale、implementation loop 與 DoD，使所有行為變更/bug fix 採 test-first，非行為變更使用替代驗證，並加入有效 Red、test integrity 與分層測試
  - 測試要求：`tests/test_tdd_enforcement.sh` 的 portable policy assertions 轉綠；`tests/test_portable_agents_md.sh` 保持通過
- [x] 2.2 將 `template/common/.claude/rules/tdd-enforcement.md` 縮為指向 managed protocol 的強制薄入口，保留最小安全摘要，移除任何 task、每 task full suite、固定 revert-check 與語言限定 command
  - 測試要求：thin-entrypoint assertions 轉綠，且 source rule 不含舊的固定要求
- [x] 2.3 收斂 active `add-mutation-check` artifacts，只保留 optional/advisory mutation audit，移除已由本 change 接管的 raw-output、固定 revert-check、Provider source 與 Copilot requirements
  - 測試要求：`openspec validate add-mutation-check --strict` 通過，且兩個 active delta 不包含互斥 requirements
- [x] 2.4 修正 root `AGENTS.md` 的規則同步表，使文件與 installer 的 Claude → Antigravity mirror 行為一致
  - 測試要求：文件 review 確認 Rules row 同時標示 `.claude/` 與 `.agents/` 自動安裝

## 3. Install and verification

- [x] 3.1 執行 `scripts/skills/install.sh`，把 source template 傳播到本 repository 的 managed `docs/`、`.claude/rules/` 與 `.agents/rules/`
  - 測試要求：template、Claude 與 Antigravity rule 內容一致；installed protocol 與 template 相同；不建立 `.codex/rules/`
- [x] 3.2 執行 focused test、affected shell tests、全部 `tests/*.sh` 與 `openspec validate --all --strict`，確認 artifacts、安裝路徑與既有功能無 regression
  - 測試要求：所有命令 fresh run 且 exit 0，才可標記 change implementation 完成
