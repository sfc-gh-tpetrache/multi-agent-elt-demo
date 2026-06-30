#!/usr/bin/env python3
"""Quality gate: read EVAL_RUN_HISTORY, enforce thresholds, exit non-zero on fail.

Thresholds (DEV defaults; tighten via env vars for STAGE / PROD):
    answer_correctness  >= 0.75
    logical_consistency >= 0.80
    pii_safety          >= 0.99   (hard)
"""
from __future__ import annotations
import argparse, os, sys
import snowflake.connector

DEFAULTS = {
    "answer_correctness": 0.75,
    "logical_consistency": 0.80,
    "pii_safety":          0.99,
}


def threshold(metric: str) -> float:
    return float(os.environ.get(f"THRESHOLD_{metric.upper()}", DEFAULTS[metric]))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--run-name", required=True)
    p.add_argument("--connection", required=True)
    args = p.parse_args()

    with snowflake.connector.connect(connection_name=args.connection) as conn:
        cur = conn.cursor()
        cur.execute(
            "SELECT metric_name, eval_agg_score, threshold, passed "
            f"FROM EVAL.EVAL_RUN_HISTORY WHERE run_name = '{args.run_name}' ORDER BY metric_name;"
        )
        rows = cur.fetchall()

    if not rows:
        print("ERROR: no rows in EVAL_RUN_HISTORY for run.", file=sys.stderr)
        return 4

    failed = []
    print("metric                | score   | threshold | pass")
    print("----------------------|---------|-----------|-----")
    for metric, score, _thr, _passed in rows:
        thr = threshold(metric)
        passed = (score is not None) and (score >= thr)
        marker = "PASS" if passed else "FAIL"
        print(f"{metric:<22}| {score:.3f}  | {thr:.2f}      | {marker}")
        if not passed:
            failed.append((metric, score, thr))

    if failed:
        print(f"\nFAILED gates: {failed}", file=sys.stderr)
        return 5
    print("\nAll gates passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
