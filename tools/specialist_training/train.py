"""Unsloth-driven LoRA training for the note-merging specialist.

This script is uploaded to an Oxen.ai Marimo notebook and run on a remote
A10G (or RTX 4090, or H100). The Oxen runtime provides Unsloth + CUDA;
locally, this script's imports gate behind a runtime check so the file
type-checks and lints in a CPU-only Python env.

Usage on Oxen:
    python3 train.py --config train_config.yaml --train data/synthetic_filtered.jsonl

Locally (smoke-test CPU shape only, no actual training):
    python3 train.py --dry-run --config train_config.yaml

Output:
    adapter/                — standard PEFT adapter (safetensors + config)
    adapter/trainer_state.json
    eval_results/training_log.jsonl  — per-epoch smoke-test scores

Why Unsloth and not vanilla transformers:
    Cactus's official finetuning guide recommends Unsloth. Unsloth's
    FastLanguageModel gives 1.5-2× speed and 20-80% VRAM savings on
    QLoRA — the difference between a 45-min A10G run and a 90-min one.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "ERROR: PyYAML not installed. Run:\n"
        "  pip install -r tools/specialist_training/requirements.txt\n"
    )
    sys.exit(1)


def _load_config(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def _format_chat(row: dict) -> str:
    """Format one training row in the model's chat template.

    The instruction is fixed across all examples — the specialist learns
    a single behavior (note merging), not a multi-task surface."""
    system = (
        "You are a note-merging assistant. Given two short study notes "
        "about the same topic, produce a single merged note that preserves "
        "every distinct claim from both inputs, drops duplicates, and stays "
        "under 200 tokens. Use a neutral third-person voice. Output ONLY "
        "the merged note — no preamble, no metadata, no Markdown."
    )
    user = (
        f"Topic: {row['topic']}\n\n"
        f"Note A: {row['note_a']}\n\n"
        f"Note B: {row['note_b']}\n\n"
        "Merge these into one consolidated note."
    )
    assistant = row["merged"]
    # Qwen 3 chat template. Unsloth applies the model's tokenizer template
    # automatically when `formatting_func` returns a string, so we return
    # the conversation as-is and let the tokenizer do the rest.
    return (
        f"<|im_start|>system\n{system}<|im_end|>\n"
        f"<|im_start|>user\n{user}<|im_end|>\n"
        f"<|im_start|>assistant\n{assistant}<|im_end|>"
    )


def _load_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def _smoke_test_bleu(
    model,
    tokenizer,
    holdout: list[dict],
    config: dict,
) -> dict:
    """Quick per-epoch eval: BLEU of generated merge vs ground truth on
    the first `eval_subset_size` holdout rows. Not a substitute for the
    full three-layer eval at U5 — just a directional signal during
    training."""
    from nltk.translate.bleu_score import sentence_bleu  # local import

    subset = holdout[: config["data"]["eval_subset_size"]]
    scores = []
    for row in subset:
        prompt = (
            f"<|im_start|>system\nYou are a note-merging assistant…<|im_end|>\n"
            f"<|im_start|>user\nTopic: {row['topic']}\n\nNote A: {row['note_a']}"
            f"\n\nNote B: {row['note_b']}\n\nMerge these into one consolidated "
            f"note.<|im_end|>\n<|im_start|>assistant\n"
        )
        inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
        outputs = model.generate(**inputs, max_new_tokens=300, temperature=0.0)
        gen = tokenizer.decode(outputs[0][inputs["input_ids"].shape[1] :], skip_special_tokens=True)
        ref = row["merged"].split()
        hyp = gen.strip().split()
        scores.append(sentence_bleu([ref], hyp))
    return {
        "subset_size": len(subset),
        "mean_bleu": float(sum(scores) / max(len(scores), 1)),
        "min_bleu": float(min(scores)) if scores else 0.0,
        "max_bleu": float(max(scores)) if scores else 0.0,
    }


def train(config_path: Path, *, dry_run: bool) -> int:
    config = _load_config(config_path)

    print(f"base model: {config['base_model']}", file=sys.stderr)
    print(f"LoRA r={config['lora']['r']} alpha={config['lora']['alpha']}", file=sys.stderr)
    print(f"epochs={config['training']['num_train_epochs']} lr={config['training']['learning_rate']}", file=sys.stderr)

    train_path = Path(config["data"]["train_path"])
    if not train_path.exists():
        sys.stderr.write(f"ERROR: training data not found: {train_path}\n")
        sys.stderr.write(
            "  Run `just specialist-generate && just specialist-filter` first.\n"
        )
        return 2
    train_rows = _load_jsonl(train_path)
    print(f"training rows: {len(train_rows)}", file=sys.stderr)

    if dry_run:
        print("--dry-run: skipping model load + training", file=sys.stderr)
        # Smoke-format the first row to confirm the chat template parses.
        sample = _format_chat(train_rows[0])
        print(f"sample formatted row ({len(sample)} chars):", file=sys.stderr)
        print(sample[:500] + ("…" if len(sample) > 500 else ""), file=sys.stderr)
        return 0

    # The heavy imports live here so the file lints on CPU-only envs and
    # the --dry-run path doesn't need a CUDA box.
    try:
        from unsloth import FastLanguageModel  # type: ignore[import-not-found]
    except ImportError:
        sys.stderr.write(
            "ERROR: unsloth not installed. This script runs on Oxen.ai's Marimo "
            "notebook (Unsloth provisioned there). For local smoke-test only, "
            "use --dry-run.\n"
        )
        return 2
    from transformers import TrainingArguments
    from trl import SFTTrainer
    from datasets import Dataset

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=config["base_model"],
        max_seq_length=config["training"]["max_seq_length"],
        load_in_4bit=config["load_in_4bit"],
        dtype=None,  # auto: bf16 on Ampere+, fp16 elsewhere
    )

    model = FastLanguageModel.get_peft_model(
        model,
        r=config["lora"]["r"],
        lora_alpha=config["lora"]["alpha"],
        lora_dropout=config["lora"]["dropout"],
        target_modules=config["lora"]["target_modules"],
        bias=config["lora"]["bias"],
        use_gradient_checkpointing="unsloth",
        random_state=config["training"]["seed"],
    )

    formatted = [{"text": _format_chat(r)} for r in train_rows]
    dataset = Dataset.from_list(formatted)

    output_dir = Path(config["output"]["adapter_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)

    args = TrainingArguments(
        per_device_train_batch_size=config["training"]["per_device_train_batch_size"],
        gradient_accumulation_steps=config["training"]["gradient_accumulation_steps"],
        warmup_ratio=config["training"]["warmup_ratio"],
        num_train_epochs=config["training"]["num_train_epochs"],
        learning_rate=config["training"]["learning_rate"],
        lr_scheduler_type=config["training"]["lr_scheduler_type"],
        weight_decay=config["training"]["weight_decay"],
        max_grad_norm=config["training"]["max_grad_norm"],
        optim=config["training"]["optim"],
        logging_steps=config["output"]["logging_steps"],
        save_strategy=config["output"]["save_strategy"],
        report_to=config["output"]["report_to"],
        seed=config["training"]["seed"],
        output_dir=str(output_dir),
    )

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset,
        dataset_text_field="text",
        max_seq_length=config["training"]["max_seq_length"],
        args=args,
    )

    print("starting training…", file=sys.stderr)
    trainer.train()
    print("training complete, saving adapter…", file=sys.stderr)
    model.save_pretrained(str(output_dir))
    tokenizer.save_pretrained(str(output_dir))

    # Optional smoke-test gate after training completes.
    eval_path = Path(config["data"]["eval_path"])
    if eval_path.exists():
        holdout = _load_jsonl(eval_path)
        log_path = Path("eval_results") / "training_log.jsonl"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        smoke = _smoke_test_bleu(model, tokenizer, holdout, config)
        with log_path.open("a") as f:
            f.write(json.dumps(smoke) + "\n")
        print(f"smoke test: {smoke}", file=sys.stderr)

    print(f"✓ adapter saved to {output_dir}", file=sys.stderr)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Train the note-merging specialist (LoRA SFT).")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("train_config.yaml"),
        help="Path to the training config YAML.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Skip model load + training. Useful for local CPU lint/format checks.",
    )
    args = parser.parse_args()
    return train(args.config, dry_run=args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
