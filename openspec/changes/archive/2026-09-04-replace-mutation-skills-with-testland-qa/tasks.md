## 1. Test-first installer contract

- [x] 1.1 將 legacy mutation skill 測試改成 third-party profile mapping acceptance test；測試要求：先執行測試並保留因 installer 尚未呼叫 `npx skills add` 而失敗的 Red evidence。
- [x] 1.2 以暫存 fake `npx` 覆蓋 node、python、jvm、dotnet、multi-profile、common-only、缺少 npx 與 command failure；測試要求：驗證 argv、去重、project scope、三個 Provider、link mode、非零 fallback 與可重播命令。

## 2. Profile 與 installer 實作

- [x] 2.1 新增最小 `jvm`、`dotnet` profile 並擴充有效 profile 清單；測試要求：四個語言 profile 可選、未知 profile 在任何 third-party call 前失敗。
- [x] 2.2 在 `scripts/skills/install.sh` 依 profiles 組成一次 project-local `testland/qa` 安裝命令；測試要求：fake npx acceptance cases 全綠，且命令不含 global 或 copy 選項。
- [x] 2.3 實作缺少 npx / third-party failure 的命令提示與精確 legacy skill 清理；測試要求：失敗回傳非零、可重播命令完整，且非 legacy skill fixture 不被刪除。

## 3. 移除自有 skills 與更新政策文件

- [x] 3.1 移除 `template/common/skills/mutation-setup` 與 `mutation-check` source；測試要求：template 與安裝目標皆不存在兩個 legacy skills，其他 common skills 仍正常同步。
- [x] 3.2 更新 `template/common/docs/mutation-testing.md`，納入四語言 mapping、五步閉環、triage 分類、執行頻率、score baseline/no-regression/ratchet 與 legacy state migration；測試要求：文件關鍵字與外部 references 檢查通過。
- [x] 3.3 更新 `template/common/docs/agent-protocol.md` 的 TDD/mutation 邊界與本地政策優先規則；測試要求：managed source 與安裝後 `docs/agent-protocol.md` 一致，且不再引用 `/mutation-check`。
- [x] 3.4 更新 project-owned `docs/architecture.md`、`README.md`、`AGENTS.md` 與其他仍引用 legacy skills 的相關文件；測試要求：repo 搜尋只允許 migration/OpenSpec history 中的 legacy 名稱，現行使用說明全部指向 testland runner + triage。

## 4. 同步與完整驗證

- [x] 4.1 對本 repo 重跑 installer，同步 `.claude/`、`.agents/` 與 managed docs；測試要求：template propagation diff 為零，third-party install 以受控 fake/既有安裝策略驗證，不在測試中依賴真實網路。
- [x] 4.2 執行 shell syntax、installer regression tests、OpenSpec strict validation 與專案 required checks；測試要求：所有命令 exit code 為 0，並記錄本 change 的 Red/Green 與最終驗證證據。

## Verification Evidence

- Red: `rtk bash tests/test_mutation_skills.sh` → exit 1；舊 installer 未呼叫 `npx skills add`、不支援 `jvm`/`dotnet`、無失敗提示且未清理 legacy skills。
- Green: `rtk bash tests/test_mutation_skills.sh` → exit 0，所有 mapping、scope、Provider、fallback、cleanup 與 managed docs scenarios 通過。
- Syntax/hygiene: `bash -n`（installer 與新 test）及 `git diff --check` → exit 0。
- Regression: `test_agents_dir.sh`、`test_openspec_commit.sh`、`test_portable_agents_md.sh`、`test_tdd_enforcement.sh`、`test_workflow.sh` → 全部 PASS；profile tests 使用 fake `npx`，不依賴網路。
- Spec: `openspec validate replace-mutation-skills-with-testland-qa --strict` → valid。
