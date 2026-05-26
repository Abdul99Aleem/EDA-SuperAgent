# Dual-Model Review Protocol

## Model Roles
- **Primary (Qwen2.5-Coder)**: Generation model
  - Generates test plans, testbenches, debug fixes
  - Optimized for code generation
  - Temperature: 0.1 (deterministic)

- **Review (Mistral)**: Validation model
  - Reviews generated artifacts
  - Flags issues, gaps, errors
  - Temperature: 0.1 (deterministic)

## Review Cycle
1. Primary generates artifact
2. Review validates artifact
3. If issues found: Primary patches
4. Max 2 cycles before escalation

## Review Criteria

### Test Plan Review
- All expected behaviors covered?
- Corner cases included?
- Protocol compliance tests present?
- Priority ordering correct (P0 first)?

### Testbench Review
- Clock generation correct?
- Reset sequence correct?
- Stimuli match test case?
- Self-checking assertions present?
- Vivado xsim compatible?

### Debug Fix Review
- Root cause correctly identified?
- Fix addresses the actual error?
- No new issues introduced?
- Verilog syntax correct?

## Output Format
Review model MUST return JSON:
```json
{
  "approved": true/false,
  "issues": ["list of issues found"],
  "missing_tests": ["for test plans"],
  "line_fixes": ["for code"]
}
```

## Escalation
If not approved after 2 cycles:
- Write detailed report
- Include all attempts
- Flag to human for decision
