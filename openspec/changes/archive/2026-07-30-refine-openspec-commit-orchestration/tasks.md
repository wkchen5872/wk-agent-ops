## 1. Contract Test

- [x] 1.1 Add `tests/test_openspec_commit.sh` covering ordered capability
  invocation, explicit archive hand-off, staging, resume behavior, and provider
  path boundaries.
  - 測試要求：先執行新測試並確認目前 skill 至少因 duplicated docs logic、
    `ls -t` rediscovery 或缺少 staging 而失敗。

## 2. Core Workflow

- [x] 2.1 Refactor `template/common/skills/openspec-commit/SKILL.md` into a thin
  coordinator over archive, doc-updater, and git-commit-writer.
  - 測試要求：`tests/test_openspec_commit.sh` 的 orchestration、resume 與
    provider-routing assertions 通過。
- [x] 2.2 Extend `doc-updater` skill and Claude wrapper with optional archived
  change context and reconcile Mode B's no-commit behavior.
  - 測試要求：contract test 確認 doc-updater 同時讀 archive context、Git status
    與 `git diff HEAD`，且 Mode B 不建立 commit。
- [x] 2.3 Restore explicit archive validation, final staging, empty-diff guard,
  and restaging-on-retry in `git-commit-writer` skill and Claude wrapper.
  - 測試要求：contract test 確認 explicit context 優先、`git add -A` 先於
    cached diff，pre-commit retry 會重新 staging。

## 3. Distribution and Documentation

- [x] 3.1 Update the OpenSpec commit workflow documentation with the thin
  coordinator, exact hand-offs, resume path, and Claude/Codex/Antigravity
  provider boundary.
  - 測試要求：文件中的 provider paths 與本機 OpenSpec 1.4.1 生成內容一致，
    且不宣稱 wk-agent-ops installer 會產生 `.codex/` 或 `.agent/`。
- [x] 3.2 Run `scripts/skills/install.sh` so project-owned template changes
  propagate to `.claude/` and `.agents/`.
  - 測試要求：三個 template skills 與兩個 installed skill copies逐一
    `diff -q` 相同；Claude agent wrappers 與 template copy 相同。

## 4. Verification

- [x] 4.1 Validate the OpenSpec change and run the focused workflow contract
  test.
  - 測試要求：`openspec validate refine-openspec-commit-orchestration` 與
    `bash tests/test_openspec_commit.sh` 均通過。
- [x] 4.2 Run the existing shell regression suite and repair only failures
  caused by this change.
  - 測試要求：所有 `tests/test_*.sh` 通過；不得略過既有 failing gate。
- [x] 4.3 Inspect the final diff for generated-directory edits, scope drift, and
  unresolved provider-name contradictions.
  - 測試要求：`.agent/` 與 `.codex/` 無本次修改；implementation 只包含
    change artifacts、project-owned template/install targets、tests 與相關 docs。
