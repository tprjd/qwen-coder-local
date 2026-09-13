#!/usr/bin/env python3
"""Run compact OpenAI-compatible validation requests against local TabbyAPI."""

from __future__ import annotations

import json
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
URL = "http://127.0.0.1:5000/v1/chat/completions"
MODEL = "TelperionAI/Qwen3.8-27B-EXL3-5.5bpw"
API_KEY = (ROOT / "client_api_key").read_text().strip()


def request(label: str, payload: dict) -> dict:
    body = json.dumps({"model": MODEL, **payload}).encode()
    req = urllib.request.Request(
        URL,
        body,
        {"Content-Type": "application/json", "Authorization": f"Bearer {API_KEY}"},
    )
    started = time.perf_counter()
    with urllib.request.urlopen(req, timeout=600) as response:
        result = json.load(response)
    elapsed = time.perf_counter() - started
    message = result["choices"][0]["message"]
    print(json.dumps({
        "test": label,
        "seconds": round(elapsed, 2),
        "finish_reason": result["choices"][0]["finish_reason"],
        "content": (message.get("content") or "")[:500],
        "reasoning": (message.get("reasoning_content") or "")[:500],
        "tool_calls": message.get("tool_calls"),
    }, ensure_ascii=False))
    return result


request("reasoning", {
    "messages": [{"role": "user", "content": "Think step by step: if 7 workers finish 7 tasks in 7 minutes, how many tasks do 14 workers finish in 14 minutes? Give a concise final answer."}],
    "reasoning_effort": "medium",
    "max_tokens": 256,
})

request("tool_call", {
    "messages": [{"role": "user", "content": "What is the weather in Budapest? Use the weather tool."}],
    "tools": [{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather for a city.",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}, "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}},
                "required": ["city", "unit"],
                "additionalProperties": False,
            },
        },
    }],
    "tool_choice": "auto",
    "max_tokens": 256,
})

request("coding", {
    "messages": [{"role": "user", "content": "Write a Python function is_palindrome(s: str) -> bool that ignores case and non-alphanumeric characters. Return only one fenced code block."}],
    "reasoning_effort": "medium",
    "max_tokens": 384,
})

request("long_prompt", {
    "messages": [{"role": "user", "content": ("alpha beta gamma delta " * 4096) + "\nReply with exactly: long prompt accepted"}],
    "reasoning_effort": "low",
    "max_tokens": 64,
})
