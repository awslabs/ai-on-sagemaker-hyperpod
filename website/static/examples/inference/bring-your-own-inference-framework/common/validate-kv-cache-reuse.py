#!/usr/bin/env python3
"""Store/replay probe for HyperPod managed KV cache examples.

The probe sends a deterministic long-prefix request, optionally scrapes metrics,
and writes a JSON artifact. Run it once before restarting the serving deployment
with --phase store, then run it again with --phase replay after the restart.
"""

import argparse
import json
import time
import urllib.request
from pathlib import Path


DEFAULT_MODEL = "Qwen/Qwen3-0.6B"
METRIC_PREFIXES = (
    "vllm:external_prefix_cache",
    "vllm:prefix_cache",
    "vllm:request_success_total",
    "lmcache:num_",
    "lmcache:lookup",
    "lmcache:retrieve",
    "lmcache:remote",
)
PROMPT_PHRASE = "SageMaker HyperPod LMCache managed L2 replay stable key. "
PROMPT_REPEATS = 45


def request(method, url, body=None, timeout=10):
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {} if body is None else {"Content-Type": "application/json"}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.status, response.read().decode("utf-8")


def selected_metrics(metrics_url):
    if not metrics_url:
        return []
    try:
        _, text = request("GET", metrics_url, timeout=10)
    except Exception as exc:
        return [f"# metrics fetch failed: {exc}"]
    return [line for line in text.splitlines() if line.startswith(METRIC_PREFIXES)]


def build_prompt():
    prefix = PROMPT_PHRASE * PROMPT_REPEATS
    prompt = prefix + "\nAnswer in one short sentence: what cache path is being validated?"
    return prompt, len(prefix)


def openai_request(base_url, model, prompt, max_tokens):
    body = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": 0,
        "stream": False,
    }
    status, raw = request("POST", f"{base_url}/v1/chat/completions", body=body, timeout=180)
    response = json.loads(raw)
    choice = response.get("choices", [{}])[0]
    message = choice.get("message", {})
    return status, response, {
        "usage": response.get("usage"),
        "finish_reason": choice.get("finish_reason"),
        "content": message.get("content", "")[:240],
    }


def sglang_request(base_url, model, prompt, max_tokens):
    body = {
        "text": prompt,
        "sampling_params": {
            "temperature": 0,
            "max_new_tokens": max_tokens,
        },
    }
    status, raw = request("POST", f"{base_url}/generate", body=body, timeout=180)
    response = json.loads(raw)
    return status, response, {
        "usage": response.get("meta_info"),
        "finish_reason": response.get("finish_reason"),
        "content": str(response.get("text", ""))[:240],
    }


def try_get(url):
    try:
        status, raw = request("GET", url, timeout=10)
        return {"status": status, "body": raw[:1000]}
    except Exception as exc:
        return {"error": str(exc)}


def run(args):
    base_url = args.base_url.rstrip("/")
    prompt, common_prefix_chars = build_prompt()

    health = try_get(f"{base_url}/health")
    models = try_get(f"{base_url}/v1/models") if args.endpoint_mode == "openai" else None
    metrics_before = selected_metrics(args.metrics_url)

    start = time.time()
    if args.endpoint_mode == "openai":
        status, raw_response, request_summary = openai_request(
            base_url, args.model, prompt, args.max_tokens
        )
    else:
        status, raw_response, request_summary = sglang_request(
            base_url, args.model, prompt, args.max_tokens
        )
    latency_ms = round((time.time() - start) * 1000, 2)

    time.sleep(args.metrics_settle_seconds)
    metrics_after = selected_metrics(args.metrics_url)

    artifact = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "phase": args.phase,
        "endpoint_mode": args.endpoint_mode,
        "endpoint": base_url,
        "model": args.model,
        "common_prefix_chars": common_prefix_chars,
        "health": health,
        "models": models,
        "request": {
            "status": status,
            "latency_ms": latency_ms,
            **request_summary,
        },
        "selected_metrics_before": metrics_before,
        "selected_metrics_after": metrics_after,
        "raw_response": raw_response,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output), "request": artifact["request"]}, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["store", "replay"], required=True)
    parser.add_argument("--base-url", default="http://127.0.0.1:18000")
    parser.add_argument("--metrics-url", default=None)
    parser.add_argument("--endpoint-mode", choices=["openai", "sglang"], default="openai")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--max-tokens", type=int, default=16)
    parser.add_argument("--metrics-settle-seconds", type=float, default=2.0)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    run(args)


if __name__ == "__main__":
    main()
