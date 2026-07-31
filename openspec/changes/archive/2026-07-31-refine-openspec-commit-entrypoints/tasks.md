## 1. Contract Tests First

- [x] 1.1 Extend `tests/test_openspec_commit.sh` with provider-entrypoint
  assertions for optional input, exactly-once delegation, provider-correct
  terminology, and the Antigravity in-context fallback.
  - **測試要求:** Run the focused test before template changes and confirm it
    fails for the missing entrypoint contract rather than a test syntax error.
- [x] 1.2 Strengthen `tests/test_agents_dir.sh` to compare both temporary
  installed entrypoints byte-for-byte with their templates and to verify this
  repository's installed copies are synchronized.
  - **測試要求:** Run the test before installation and confirm it fails because
    the repository's `.agents/workflows/opsx-commit.md` target is absent.
- [x] 1.3 Add a linked-worktree installer regression covering root acceptance,
  exact entrypoint propagation, profile hook installation, and rejection of a
  repository subdirectory.
  - **測試要求:** Run it before changing the installer and confirm the linked
    worktree install fails at the directory-only `.git` validation.

## 2. Provider Entrypoint Adapters

- [x] 2.1 Replace the Claude Code command body with a thin adapter that declares
  `[change-name]`, forwards `$ARGUMENTS`, invokes `openspec-commit` exactly once,
  and prohibits separate completion actions.
  - **測試要求:** Re-run `tests/test_openspec_commit.sh`; all Claude entrypoint
    assertions must pass.
- [x] 2.2 Replace the Antigravity workflow body with a thin `/opsx-commit`
  adapter that activates `openspec-commit` exactly once and includes the
  in-context fallback without Claude-specific terminology.
  - **測試要求:** Re-run `tests/test_openspec_commit.sh`; all Antigravity
    entrypoint assertions must pass.
- [x] 2.3 Replace directory-only repository and hooks assumptions in
  `scripts/skills/install.sh` with Git top-level and hooks-path resolution.
  - **測試要求:** The linked-worktree regression must pass while a repository
    subdirectory remains rejected.

## 3. Installation and Documentation

- [x] 3.1 Run `scripts/skills/install.sh` to refresh the generated Claude target
  and restore the generated Antigravity workflow target.
  - **測試要求:** `tests/test_agents_dir.sh` must pass both temporary-install
    comparisons and repository synchronization checks.
- [x] 3.2 Update `docs/workflow/commit.md` to document `/opsx:commit` for Claude,
  `/opsx-commit` for Antigravity, and direct skill invocation for Codex.
  - **測試要求:** Verify the document contains all three entry routes and
    preserves the provider-owned versus project-owned boundary.

## 4. Verification

- [x] 4.1 Run the focused shell tests, `git diff --check`, and strict validation
  for `refine-openspec-commit-entrypoints`.
  - **測試要求:** Every command must exit zero with no failing assertion or
    OpenSpec validation error.
- [x] 4.2 Run the broader repository shell regression suite relevant to agent
  installation and portable configuration.
  - **測試要求:** Existing agent-directory and portability tests must remain
    green without bypassing any configured gate.
