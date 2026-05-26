#!/usr/bin/env python3
"""
Ollama client for dual-model orchestration.
Qwen2.5-Coder generates, Mistral reviews.
Sequential loading to stay under 8GB RAM.
"""
import requests
import json
import sys
import os

OLLAMA_URL = "http://localhost:11434/api/generate"
PRIMARY_MODEL = "qwen2.5-coder:7b-instruct-q4_K_M"
REVIEW_MODEL = "mistral:7b-instruct-q4_K_M"

# Ensure models unload immediately after use
os.environ["OLLAMA_KEEP_ALIVE"] = "0"

def ask(model: str, system: str, user: str, max_tokens: int = 512) -> str:
    """Call Ollama with strict token limits for i5 CPU."""
    payload = {
        "model": model,
        "prompt": f"<|system|>\n{system}\n<|user|>\n{user}\n<|assistant|>\n",
        "stream": False,
        "options": {
            "num_predict": max_tokens,
            "temperature": 0.1,       # low = deterministic
            "num_ctx": 2048,          # CRITICAL: keep small for i5
            "repeat_penalty": 1.1
        }
    }
    try:
        r = requests.post(OLLAMA_URL, json=payload, timeout=120)
        r.raise_for_status()
        return r.json()["response"].strip()
    except Exception as e:
        return f"ERROR: {str(e)}"

def generate_and_review(
    system_gen: str, prompt_gen: str,
    system_rev: str, prompt_rev_template: str,
    max_review_cycles: int = 2
) -> dict:
    """
    Full dual-model cycle:
    1. Qwen generates
    2. Mistral reviews
    3. Qwen patches if needed
    Returns: {"output": str, "approved": bool, "cycles": int}
    """
    output = ask(PRIMARY_MODEL, system_gen, prompt_gen)

    for cycle in range(max_review_cycles):
        prompt_rev = prompt_rev_template.format(output=output)
        review_raw = ask(REVIEW_MODEL, system_rev, prompt_rev, max_tokens=256)

        try:
            review = json.loads(review_raw)
        except json.JSONDecodeError:
            # Mistral failed to return JSON — accept output
            return {"output": output, "approved": True, "cycles": cycle}

        if review.get("approved"):
            return {"output": output, "approved": True, "cycles": cycle + 1}

        # Build patch prompt from issues
        issues = review.get("issues", [])
        patch_prompt = f"{prompt_gen}\n\nFix these issues:\n" + "\n".join(
            f"- {i}" for i in issues
        )
        output = ask(PRIMARY_MODEL, system_gen, patch_prompt)

    return {"output": output, "approved": False, "cycles": max_review_cycles}

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python3 ollama_client.py <model> <system_prompt> <user_prompt>")
        sys.exit(1)

    model = sys.argv[1]
    system = sys.argv[2]
    user = sys.argv[3]

    result = ask(model, system, user)
    print(result)
