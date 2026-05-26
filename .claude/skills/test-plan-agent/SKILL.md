---
name: test-plan-agent
description: Generates test cases from mental model using dual-model review
---

# Test Plan Agent

## Trigger
When orchestrator invokes after mental model is built.

## Input
- mental_model/current.json (MUST exist)
- memory/debugging.md (check for known failure patterns to include)

## Dual-Model Process
1. Qwen2.5-Coder generates test plan
2. Mistral reviews for completeness and RTL correctness
3. Qwen patches if Mistral flags gaps

## Qwen Prompt Template (keep under 512 tokens)
System: You are a Verilog verification expert. Output ONLY JSON.
User: 
Mental model summary:
- Module: {name}
- Interfaces: {interface_types}
- Key constraints: {constraints[0:3]}
- Expected behavior: {expected_behavior[0:3]}

Generate test cases. Format:
{
  "test_cases": [
    {
      "id": "TC001",
      "name": "string",
      "category": "functional | corner | stress | protocol",
      "inputs": {"signal": "value"},
      "expected_output": {"signal": "value"},
      "pass_criteria": "string",
      "priority": "P0 | P1 | P2"
    }
  ]
}

## Mistral Review Prompt
System: You are a senior RTL verification engineer reviewing a test plan.
User:
Test plan: {test_plan_json}
Mental model constraints: {constraints}
Flag: missing corner cases, protocol violations, unreachable states.
Output JSON: {"approved": bool, "issues": ["list"], "missing_tests": ["list"]}

## Output
Write to: outputs/test_plans/plan_<YYYYMMDD_HHMM>.md
Also update: memory/MEMORY.md with summary of what was planned

## Gotchas
- Always include: reset behavior test (TC-RST-001)
- Always include: back-pressure test for AXI interfaces
- Always include: max burst length test
- P0 tests must run first. Do not skip P0 for coverage.

## Token Budget
- Mental model summary: ~300 tokens
- Generated test plan: ~400 tokens
- Review: ~200 tokens
- Total: ~900 tokens per cycle
