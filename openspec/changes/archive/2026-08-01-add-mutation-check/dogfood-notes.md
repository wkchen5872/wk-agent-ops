# Dogfood Notes: add-mutation-check

Date: 2026-08-01

## Environment

- Host: macOS
- Codex CLI: `0.146.0`
- Python launcher: uv `0.9.8`; dogfood environment: Python `3.13.11`
- mutmut: `3.7.0`
- Node: host probe `v22.15.0`; Stryker subprocess reported Node `v26.5.0`
- StrykerJS: `9.6.1`
- Fixtures: disposable Git repositories under `/private/tmp`; no wk-agent-ops dependency manifest was modified

## Python / mutmut

Fixture: `/private/tmp/wk-mutation-python.4Cd0ZB`

Changed production code: `src/calculator.py`, threshold `90 → 100`. The only
test asserts free shipping at `100`, intentionally leaving the paid-shipping
return unguarded.

### Setup and baseline

- `uv add --dev mutmut` installed mutmut `3.7.0` into the fixture and preserved
  the uv project/lockfile.
- `[tool.mutmut] source_paths = ["src/"]` and
  `pytest_add_cli_args_test_selection = ["tests/"]` were accepted.
- Baseline: `.venv/bin/python -m pytest -q tests/` → `1 passed`.

### Mutation result

- `uv run mutmut run` → 4 mutants: 3 killed, 1 survived; other reported
  categories were zero.
- `uv run mutmut results` →
  `calculator.x_shipping_fee__mutmut_4: survived`.
- `uv run mutmut show calculator.x_shipping_fee__mutmut_4` showed
  `return 10 → return 11` at `src/calculator.py:4`.

### Codex Provider replay

Codex session `019fbb0b-1523-7932-ac73-6450d85951f0` started from
`/private/tmp/wk-mutation-python.4Cd0ZB/tests` and invoked the installed
`mutation-check` skill by name, without a slash command.

- Resolved Git root/project unit:
  `/private/tmp/wk-mutation-python.4Cd0ZB`.
- Baseline: 1 passed.
- State written at repository root:

```text
last_scan_commit=7241d91791fe782ff251c904d85bd756eb3c6041
deferred=mutmut|.|src/calculator.py:4|calculator.x_shipping_fee__mutmut_4|return_10_to_11\t2026-08-01\tdogfood intentionally omits the paid-shipping assertion
```

- Final diff confirmed that the audit did not edit tracked production code or
  tests; only the intentionally prepared production/config changes remained.
- Nested Codex sandbox caused uv's macOS system-configuration code to panic.
  Using the same project's `.venv/bin/python` and `.venv/bin/mutmut` executables
  completed the run; this is an execution-environment limitation, not a skill
  root-resolution failure.

### Baseline failure gate

The fixture test was temporarily changed to expect `1` instead of `0`.
`.venv/bin/python -m pytest -q tests/` produced the expected assertion failure.
No mutation command was run, and `.mutation-state` retained SHA-256
`030ffb2155948b2e536df2f44fb2465d600e059dd86763fc5d5528956a7fddee` before and
after the failure. The test was then restored.

Running pytest without an explicit tests path after mutmut had generated
`mutants/` caused duplicate-module collection. This was not accepted as valid
baseline failure evidence. The source skill and playbook now require ignoring
`mutants/` and targeting/excluding it during baseline discovery.

## TS/JS / StrykerJS

Fixture: `/private/tmp/wk-mutation-js.3ecolg`

Changed production code: `src/shipping.js`, threshold `90 → 100`; the only test
covers free shipping at `100`.

### Setup and baseline

- Existing npm project/lockfile retained.
- Installed `@stryker-mutator/core` and `@stryker-mutator/vitest-runner` as dev
  dependencies.
- `npm test -- --reporter=dot` → 1 test passed.

### Mutation result and rerun

- `npx stryker run --incremental --force --mutate src/shipping.js` selected 1
  production file and generated 5 mutants.
- Result: 4 killed, 1 survived, 0 timeout, 0 no-coverage, 0 errors; tool-reported
  score 80% is recorded only as secondary evidence.
- Survivor: `ConditionalExpression` at `src/shipping.js:2:10`, changing the
  condition to `true`.
- A second incremental/force run again tested all 5 mutants and reproduced the
  same result.
- `.mutation-state` retained its `last_scan_commit` plus deferred record across
  the rerun; the audit did not change production/tests.

The first Stryker run inside the outer sandbox failed to bind its internal
logging socket (`listen EPERM 0.0.0.0`). Re-running with the required local
socket permission completed in 2 seconds.

## Monorepo ambiguity

Fixture: `/private/tmp/wk-mutation-monorepo.SV2gQw`

- Dirty production files existed under both `packages/a/src/` and
  `packages/b/src/`.
- Each package had its own `pyproject.toml` and `[tool.mutmut]` configuration.
- Codex session `019fbb11-2fe9-7521-af87-c3885edc13f7` started from `packages/`,
  resolved the repository root, listed both project units, and applied the
  skill's stop-for-selection rule.
- The run was read-only; no candidate was selected and no setup action ran.

## Corrections fed back to the template

1. Actual mutmut 3.7.0 help and run confirmed `results` is a public command.
   The earlier design assumption that it was stale was removed; reliance on
   undocumented `mutants/summary.json` remains forbidden.
2. mutmut leaves a `mutants/` working tree that can confuse later pytest root
   discovery. Setup now ignores it, and check requires the real test path or an
   exclusion.
3. No Provider interpretation divergence required a runtime helper. Codex used
   the portable skills correctly; observed failures came from nested sandbox
   access to uv/socket facilities and have explicit diagnostic fallbacks.
