#!/usr/bin/env python3
"""
Extracts port list from Verilog file.
Outputs compact JSON for mental model building.
Keeps context small — don't pass full RTL to LLM.
"""
import re
import sys
import json

def parse_verilog_ports(filepath: str) -> dict:
    with open(filepath) as f:
        content = f.read()

    # Extract module name
    mod_match = re.search(r'\bmodule\s+(\w+)', content)
    module_name = mod_match.group(1) if mod_match else "unknown"

    # Extract port directions
    ports = {"inputs": [], "outputs": [], "inouts": []}

    for direction in ["input", "output", "inout"]:
        pattern = rf'\b{direction}\s+(?:reg\s+|wire\s+)?(?:\[(\d+):(\d+)\]\s+)?(\w+)'
        for match in re.finditer(pattern, content):
            msb, lsb, name = match.group(1), match.group(2), match.group(3)
            width = (int(msb) - int(lsb) + 1) if msb and lsb else 1
            ports[direction + "s"].append({"name": name, "width": width})

    # Extract parameters
    params = {}
    for match in re.finditer(r'\bparameter\s+(\w+)\s*=\s*(\w+)', content):
        params[match.group(1)] = match.group(2)

    return {
        "module": module_name,
        "file": filepath,
        "ports": ports,
        "parameters": params
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 parse_rtl.py <verilog_file>")
        sys.exit(1)
    result = parse_verilog_ports(sys.argv[1])
    print(json.dumps(result, indent=2))
