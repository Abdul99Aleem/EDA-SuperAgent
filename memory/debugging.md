# Debugging Patterns

This file tracks common failure patterns and their fixes.
Updated automatically as debug-agent resolves issues.

## Common Patterns

### Clock Issues
- **Pattern**: Simulation fails immediately at cycle 0
- **Cause**: Clock not initialized in initial block
- **Fix**: Add `initial clk = 0;` before always block

### Reset Issues
- **Pattern**: Signals show X values after reset
- **Cause**: Reset not held long enough or not applied correctly
- **Fix**: Hold reset for minimum 5 clock cycles

### Width Mismatches
- **Pattern**: Vivado xvlog reports width mismatch
- **Cause**: Signal widths don't match between modules
- **Fix**: Ensure port widths match exactly in instantiation

### Undriven Signals
- **Pattern**: Vivado reports undriven signal
- **Cause**: Signal declared but never assigned
- **Fix**: Add default assignment or remove unused signal

## Module-Specific Patterns
(Will be populated as you debug specific modules)
