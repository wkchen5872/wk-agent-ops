## 1. Characterization and Red Tests

- [x] 1.1 Add a skill-installer upgrade test that seeds legacy entropy skill mirrors, state, and ignore content; verify the new assertions fail before implementation. **Test requirement:** preserve an unrelated sentinel ignore line.
- [x] 1.2 Add a workflow-installer upgrade test that seeds legacy entropy hook registrations and deployed files; verify the new assertions fail before implementation. **Test requirement:** preserve unrelated provider hook configuration.

## 2. Runtime Retirement

- [x] 2.1 Execute the existing `scripts/workflow/entropy-counter/uninstall.sh` for the current user and verify its managed registrations and deployed file are absent. **Test requirement:** inspect each supported provider target after execution.
- [x] 2.2 Add targeted legacy cleanup to the existing skill and workflow installers, remove the entropy skill/counter sources, and delete the standalone uninstaller. **Test requirement:** make both upgrade tests pass without adding a new framework.

## 3. Architecture Cleanup

- [x] 3.1 Delete entropy canonical specs and dedicated archived changes, surgically remove entropy lines from mixed history, and remove live documentation references. **Test requirement:** targeted searches find no entropy references outside this retirement change and cleanup tests.
- [x] 3.2 Run managed installation, all repository tests, strict OpenSpec validation, and diff hygiene checks. **Test requirement:** every existing test script passes and generated mirrors contain no entropy skill.
