# Vivado Simulation Rules

## Simulation Backend
- **Tool**: Vivado xsim (batch mode only)
- **No GUI**: All operations via TCL scripts
- **Workflow**: xvlog (compile) → xelab (elaborate) → xsim (simulate)

## Compilation (xvlog)
- Compiles both RTL and testbench
- Checks Verilog syntax
- Reports: %Error for syntax errors
- All files compiled together in one command

## Elaboration (xelab)
- Links compiled modules
- Finds top-level testbench module
- Creates simulation snapshot
- Reports: port mismatches, unresolved references

## Simulation (xsim)
- Runs the elaborated snapshot
- Executes testbench
- Captures $display output
- Timeout: 60 seconds (configurable in TCL)

## Output Parsing
Look for these status indicators:
- "PASS" → test passed
- "FAIL" → test failed
- "COMPILE_ERROR" → xvlog failed
- "ELABORATION_ERROR" → xelab failed
- "RUNTIME_FAIL" → simulation ran but assertions failed
- "TIMEOUT" → infinite loop

## Common Errors

### Compile Errors
- Undeclared signals
- Syntax errors
- Width mismatches
- Missing semicolons

### Elaboration Errors
- Module not found
- Port count mismatch
- Port width mismatch
- Unconnected ports

### Runtime Errors
- Division by zero
- Array index out of bounds
- X propagation
- Timing violations

## Debugging Tips
- Check xsim.log for detailed output
- Use $display to trace signal values
- Check reset sequence (5 cycles minimum)
- Verify clock initialization (clk = 0 in initial block)
