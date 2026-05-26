# Agent Workflow Rules

## General Principles
- Always read mental_model/current.json before any agent task
- Check memory/ for past learnings before starting
- Keep prompts under 2048 tokens (i5 CPU constraint)
- Use dual-model review for all generation tasks
- Update memory after completing tasks

## Agent Invocation Order
1. Mental Model Builder (foundation)
2. Test Plan Agent (what to test)
3. Code Gen Agent (generate testbench)
4. Simulation Agent (run test)
5. Coverage Agent (analyze results)
6. Debug Agent (only if FAIL)
7. VLSI Doc Writer (document learnings)

## Token Budget Management
- Parse RTL with tools/parse_rtl.py (don't read full files)
- Extract only relevant sections from specs
- Pass summaries to LLMs, not full documents
- Generate ONE test case at a time
- Generate ONE testbench at a time

## Dual-Model Protocol
1. Qwen2.5-Coder generates (primary)
2. Mistral reviews (secondary)
3. Qwen patches if issues found
4. Max 2 review cycles before escalation

## Memory Updates
After each task:
- Write key findings to memory/ (auto memory)
- Update memory/fixes.log for bugs fixed
- Update memory/MEMORY.md index
- Keep memory files concise (<200 lines each)

## Error Handling
- Max 3 debug cycles before escalating to human
- Write escalation report to outputs/reports/debug_escalation.md
- Include full context: error, attempts, why stuck
