# Graph Report - .  (2026-06-26)

## Corpus Check
- 1 files · ~0 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 29 nodes · 45 edges · 5 communities detected
- Extraction: 62% EXTRACTED · 38% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)
1. `analyze_all()` - 7 edges
2. `write_report()` - 7 edges
3. `main()` - 6 edges
4. `parse_session()` - 5 edges
5. `print_summary()` - 5 edges
6. `get_cutoff()` - 4 edges
7. `format_tokens()` - 4 edges
8. `find_costly_sessions()` - 4 edges
9. `extract_text_content()` - 3 edges
10. `is_human_prompt()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `analyze_all()` --calls--> `parse_session()`  [INFERRED]
  scripts/token_analysis.py → scripts/token_analysis.py  _Bridges community 1 → community 0_
- `write_report()` --calls--> `get_cutoff()`  [INFERRED]
  scripts/token_analysis.py → scripts/token_analysis.py  _Bridges community 0 → community 4_
- `main()` --calls--> `analyze_all()`  [INFERRED]
  scripts/token_analysis.py → scripts/token_analysis.py  _Bridges community 0 → community 3_
- `write_report()` --calls--> `format_tokens()`  [INFERRED]
  scripts/token_analysis.py → scripts/token_analysis.py  _Bridges community 2 → community 4_
- `main()` --calls--> `write_report()`  [INFERRED]
  scripts/token_analysis.py → scripts/token_analysis.py  _Bridges community 4 → community 3_

## Communities

### Community 0 - "Community 0"
Cohesion: 0.36
Nodes (7): analyze_all(), get_cutoff(), get_project_name(), Convert directory name to readable project name., Return a UTC-aware datetime cutoff, or None for all time., Analyze all projects and sessions., session_in_range()

### Community 1 - "Community 1"
Cohesion: 0.33
Nodes (6): extract_text_content(), is_human_prompt(), parse_session(), Extract text from message content (string or list)., Check if this is a human-originated prompt (not tool result)., Parse a single JSONL session file.

### Community 2 - "Community 2"
Cohesion: 0.33
Nodes (6): find_costly_sessions(), format_tokens(), print_summary(), Format token count with commas., Find the most token-heavy sessions across all projects., Print a quick summary to stdout.

### Community 3 - "Community 3"
Cohesion: 0.4
Nodes (5): main(), Build per-project summary., Write all user prompts for each project to separate files., summarize_projects(), write_prompts_by_project()

### Community 4 - "Community 4"
Cohesion: 0.5
Nodes (4): find_costly_subagents(), Find the most token-heavy subagent sessions., Write the main analysis report., write_report()

## Knowledge Gaps
- **13 isolated node(s):** `Extract text from message content (string or list).`, `Check if this is a human-originated prompt (not tool result).`, `Parse a single JSONL session file.`, `Convert directory name to readable project name.`, `Return a UTC-aware datetime cutoff, or None for all time.` (+8 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `write_report()` connect `Community 4` to `Community 0`, `Community 2`, `Community 3`?**
  _High betweenness centrality (0.109) - this node is a cross-community bridge._
- **Why does `analyze_all()` connect `Community 0` to `Community 1`, `Community 3`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
- **Why does `parse_session()` connect `Community 1` to `Community 0`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `analyze_all()` (e.g. with `get_cutoff()` and `get_project_name()`) actually correct?**
  _`analyze_all()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `write_report()` (e.g. with `get_cutoff()` and `format_tokens()`) actually correct?**
  _`write_report()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `main()` (e.g. with `analyze_all()` and `summarize_projects()`) actually correct?**
  _`main()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `parse_session()` (e.g. with `extract_text_content()` and `is_human_prompt()`) actually correct?**
  _`parse_session()` has 3 INFERRED edges - model-reasoned connections that need verification._