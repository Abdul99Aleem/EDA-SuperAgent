---
name: coverage-agent
description: Analyzes simulation coverage and identifies gaps
---

# Coverage Agent

## Trigger
When orchestrator invokes after successful simulation (PASS status).

## What This Skill Does
Analyzes what was tested and identifies coverage gaps.
Phase 1: Basic analysis of test execution.
Future phases: integrate Vivado coverage tools.

## Input
- mental_model/current.json
- outputs/reports/sim_<latest>.txt
- outputs/test_plans/plan_<latest>.md

## Analysis Steps
1. Read simulation log
2. Identify which test cases passed
3. Compare against test plan
4. Check mental model expected_behavior coverage
5. Identify untested scenarios

## Output Format
Write to: outputs/reports/coverage_<timestamp>.txt

Format:
```
=== Coverage Report ===
Test Plan: {plan_file}
Simulation: {sim_file}

Tests Executed: {count}
Tests Passed: {count}
Tests Failed: {count}

Expected Behaviors Covered:
- {behavior_1}: COVERED
- {behavior_2}: NOT COVERED

Coverage Gaps:
- {gap_1}
- {gap_2}

Recommendations:
- {recommendation_1}
```

## Phase 1 Scope
- Manual analysis of test execution
- Compare against mental model expected_behavior
- Identify obvious gaps

## Future Phases
- Integrate Vivado coverage commands (cover -cvg)
- Line coverage, branch coverage, toggle coverage
- FSM coverage for state machines

## Token Budget
N/A - this is analysis of existing files, minimal LLM usage
