---
name: debug-last
description: Debug the most recent simulation failure
---

Debug the most recent simulation failure.

Steps:
1. Read outputs/reports/ (find latest sim log with FAIL status)
2. Extract error lines (max 10 lines)
3. Load mental_model/current.json for context
4. Check memory/fixes.log for similar past issues
5. Invoke debug-agent skill
6. Show proposed fix
7. Ask user if they want to apply the fix

This command helps you understand why a simulation failed and get a suggested fix.
