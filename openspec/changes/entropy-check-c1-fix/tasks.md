## 1. Fix Bash function detection

- [ ] 1.1 In `template/common/skills/entropy-check/SKILL.md`, replace the C1 bash detection block: change `grep -rl ... | grep -v "^$sh_file$" | wc -l` → `grep -rn "$fn_name" "$PROJECT_ROOT" --include="*.sh" | wc -l`, and change threshold from `[ "$count" -eq 0 ]` to `[ "$total" -le 1 ]`
- [ ] 1.2 Sync the same fix to `.claude/skills/entropy-check/SKILL.md`
- [ ] 1.3 Sync the same fix to `.agent/skills/entropy-check/SKILL.md`

## 2. Fix Python import name extraction

- [ ] 2.1 In `template/common/skills/entropy-check/SKILL.md`, add `| tr -d ','` after the `awk '{print $1}'` step in the Python C1 block
- [ ] 2.2 Sync the same fix to `.claude/skills/entropy-check/SKILL.md`
- [ ] 2.3 Sync the same fix to `.agent/skills/entropy-check/SKILL.md`

## 3. Update spec

- [ ] 3.1 Apply delta spec to `openspec/specs/entropy-check-c1-unused-code/spec.md`: update bash detection requirement and add multi-name import scenario
