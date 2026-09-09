## 1. Contract Tests

- [x] 1.1 Add focused static assertions for exact runtime provenance, generic family/alias rejection, switched-model ambiguity, and the session-log/documentation exclusions; 測試要求：run `bash tests/test_openspec_commit.sh` first and record the expected attribution-contract failure as Red.

  Red evidence: `bash tests/test_openspec_commit.sh` exited 1 because the existing templates lacked the newly required provenance, ambiguity, and forbidden-source statements; unrelated existing assertions passed.

## 2. Attribution Workflow

- [x] 2.1 Update the `openspec-commit` source template with provider-specific resolution and user-confirmation fallback; 測試要求：rerun `bash tests/test_openspec_commit.sh` and verify the coordinator assertions pass.
- [x] 2.2 Update the portable and provider-native commit-writer source templates to reject unresolved or generic attribution without changing their runtime model settings; 測試要求：rerun `bash tests/test_openspec_commit.sh` and verify every writer variant passes.
- [x] 2.3 Run `bash scripts/skills/install.sh` to regenerate managed project targets from templates; 測試要求：verify source/target synchronization through the installer test coverage and `git diff`.

## 3. Documentation and Verification

- [x] 3.1 Update the relevant attribution documentation with the provider boundary and ambiguity behavior; 測試要求：verify documented inputs and examples match the templates and delta specs.
- [x] 3.2 Run the affected shell suites and `openspec validate exact-model-attribution --strict`; 測試要求：all commands pass without bypassing hooks or weakening assertions.
- [x] 3.3 Run `/openspec-verify-change` or the provider equivalent and record replayable evidence that the implementation matches both modified capabilities.

  Verify evidence: all 7 tasks complete; `rg` mapped both modified requirements to source templates and focused assertions; six template/installed-target `diff -q` checks and `git diff --check` exited 0.
