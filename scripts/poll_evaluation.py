#!/usr/bin/env python3
"""Poll EXECUTE_AI_EVALUATION for a given run_name until terminal."""
from __future__ import annotations
import argparse, sys, time
import snowflake.connector

TERMINAL = {"COMPLETED", "FAILED", "CANCELLED"}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--run-name", required=True)
    p.add_argument("--agent", required=True)
    p.add_argument("--connection", required=True)
    p.add_argument("--timeout", type=int, default=900)
    args = p.parse_args()

    start = time.time()
    with snowflake.connector.connect(connection_name=args.connection) as conn:
        cur = conn.cursor()
        while True:
            cur.execute(
                "SELECT STATUS FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA("
                f"CURRENT_DATABASE(), 'AGENTS', '{args.agent}', 'CORTEX AGENT', '{args.run_name}'))"
                " LIMIT 1;"
            )
            row = cur.fetchone()
            status = (row[0] if row else "UNKNOWN").upper()
            print(f"[{int(time.time() - start):3d}s] status={status}")
            if status in TERMINAL:
                return 0 if status == "COMPLETED" else 2
            if time.time() - start > args.timeout:
                print("TIMEOUT", file=sys.stderr)
                return 3
            time.sleep(10)


if __name__ == "__main__":
    sys.exit(main())
