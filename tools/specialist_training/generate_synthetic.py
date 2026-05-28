"""Magpie-style synthetic data generation for the note-merging specialist.

Hits an OpenAI-compatible endpoint hosting Qwen 2.5-72B-Instruct (Together AI
by default; configurable via env) and produces (note_a, note_b, merged)
triples for U2 of the specialist-training plan.

Why Magpie:
    Magpie generates plausible task-shaped data from an instruct model by
    prompting it with the chat-template prefix and letting it autocomplete
    both the user query and the assistant response. We adapt this by giving
    the teacher a structured-output instruction and parsing JSON back.

Usage:
    export TOGETHER_API_KEY=...                # or OPENAI_API_KEY for that endpoint
    python3 generate_synthetic.py --limit 2000 --output data/synthetic_raw.jsonl

The script is idempotent — it appends to the output file and skips rows
already present (by topic+note_a hash), so a long run can be resumed.

Output JSONL row schema:
    {"topic_bucket": str, "topic": str, "note_a": str, "note_b": str,
     "merged": str}

Failure modes handled:
    - Endpoint 429 / 5xx: exponential backoff via tenacity (1s, 2s, 4s, 8s, 16s)
    - JSON parse failure: row skipped with a warning; doesn't kill the run
    - Empty merged field: row skipped (caller's filter pass will catch real
      empties; we drop the obviously-broken ones at generation time)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path
from typing import Iterator

from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)
from tqdm import tqdm

# OpenAI SDK reads OPENAI_API_KEY by default but speaks the OpenAI-compat
# protocol against any endpoint (Together AI exposes one at
# https://api.together.xyz/v1).
try:
    from openai import OpenAI, APIError, APIStatusError, RateLimitError
except ImportError:
    sys.stderr.write(
        "ERROR: openai package not installed. Run:\n"
        "  pip install -r tools/specialist_training/requirements.txt\n"
    )
    sys.exit(1)


DEFAULT_TEACHER_MODEL = "Qwen/Qwen2.5-72B-Instruct-Turbo"
DEFAULT_ENDPOINT = "https://api.together.xyz/v1"
DEFAULT_PROMPT_TEMPLATE = (
    Path(__file__).parent / "configs" / "magpie_prompt_template.txt"
)


def _row_key(row: dict) -> str:
    """Stable hash for dedup on resume — topic + note_a are sufficient."""
    payload = f"{row.get('topic', '')}|{row.get('note_a', '')}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()[:16]


def _load_existing_keys(path: Path) -> set[str]:
    keys: set[str] = set()
    if not path.exists():
        return keys
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                # Skip malformed lines from any prior crash mid-write.
                continue
            keys.add(_row_key(row))
    return keys


@retry(
    retry=retry_if_exception_type((RateLimitError, APIStatusError, APIError)),
    wait=wait_exponential(multiplier=1, min=1, max=16),
    stop=stop_after_attempt(5),
    reraise=True,
)
def _call_teacher(client: OpenAI, model: str, prompt: str, temperature: float) -> str:
    """One teacher call. Tenacity handles transient endpoint failures."""
    response = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        temperature=temperature,
        max_tokens=1024,
    )
    content = response.choices[0].message.content
    if not content:
        raise APIError("Teacher returned empty content", request=None, body=None)
    return content


def _parse_row(raw: str) -> dict | None:
    """Parse one teacher response. Returns None if unusable."""
    raw = raw.strip()
    # Strip accidental markdown code fences.
    if raw.startswith("```"):
        # Remove leading fence + optional language hint
        first_newline = raw.find("\n")
        if first_newline > 0:
            raw = raw[first_newline + 1 :]
        if raw.endswith("```"):
            raw = raw[:-3]
        raw = raw.strip()
    try:
        row = json.loads(raw)
    except json.JSONDecodeError:
        return None
    required = {"topic_bucket", "topic", "note_a", "note_b", "merged"}
    if not required.issubset(row.keys()):
        return None
    if not row.get("merged") or not row.get("note_a") or not row.get("note_b"):
        return None
    return row


def generate(
    *,
    output: Path,
    limit: int,
    prompt: str,
    client: OpenAI,
    model: str,
    temperature: float,
) -> Iterator[dict]:
    seen = _load_existing_keys(output)
    output.parent.mkdir(parents=True, exist_ok=True)

    produced = 0
    consecutive_failures = 0
    with output.open("a") as f:
        with tqdm(total=limit, initial=len(seen), desc="generate") as pbar:
            while produced + len(seen) < limit:
                try:
                    raw = _call_teacher(client, model, prompt, temperature)
                except Exception as exc:  # noqa: BLE001 - log + skip
                    sys.stderr.write(f"\nteacher call failed: {exc}\n")
                    consecutive_failures += 1
                    if consecutive_failures >= 10:
                        sys.stderr.write(
                            "10 consecutive teacher failures; aborting. "
                            "Check endpoint health and API key.\n"
                        )
                        return
                    time.sleep(2)
                    continue
                consecutive_failures = 0

                row = _parse_row(raw)
                if row is None:
                    # Parse failure is common during generation; just skip.
                    continue
                key = _row_key(row)
                if key in seen:
                    continue
                seen.add(key)

                f.write(json.dumps(row, ensure_ascii=False) + "\n")
                f.flush()
                produced += 1
                pbar.update(1)
                yield row


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Magpie-style synthetic data generator (note-merging task)."
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=2000,
        help="Target row count (resumable; counts existing rows in --output).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/synthetic_raw.jsonl"),
        help="Output JSONL path. Appended; safe to re-run.",
    )
    parser.add_argument(
        "--prompt-template",
        type=Path,
        default=DEFAULT_PROMPT_TEMPLATE,
        help="Path to the Magpie prompt template.",
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("TEACHER_MODEL", DEFAULT_TEACHER_MODEL),
        help="Teacher model identifier (must be Apache-2.0/MIT licensed for "
        "clean redistribution).",
    )
    parser.add_argument(
        "--endpoint",
        default=os.environ.get("TEACHER_ENDPOINT", DEFAULT_ENDPOINT),
        help="OpenAI-compatible endpoint base URL.",
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.9,
        help="Sampling temperature. Higher = more diverse topics.",
    )
    args = parser.parse_args()

    api_key = os.environ.get("TOGETHER_API_KEY") or os.environ.get("OPENAI_API_KEY")
    if not api_key:
        sys.stderr.write(
            "ERROR: set TOGETHER_API_KEY (or OPENAI_API_KEY) before running.\n"
        )
        return 2

    prompt = args.prompt_template.read_text()
    client = OpenAI(api_key=api_key, base_url=args.endpoint)

    print(
        f"generating up to {args.limit} rows via {args.model} @ {args.endpoint}",
        file=sys.stderr,
    )
    print(f"output: {args.output}", file=sys.stderr)

    rows = list(
        generate(
            output=args.output,
            limit=args.limit,
            prompt=prompt,
            client=client,
            model=args.model,
            temperature=args.temperature,
        )
    )
    print(f"wrote {len(rows)} new rows", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
