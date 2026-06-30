#!/usr/bin/env python3
"""Upload eval YAML to @CFG_STAGE and run EXECUTE_AI_EVALUATION."""
from __future__ import annotations
import argparse, os, sys
import snowflake.connector


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--agent", required=True)
    p.add_argument("--version", default="dev")
    p.add_argument("--dataset", required=True, help="Dataset YAML filename under eval/<agent>/")
    p.add_argument("--connection", required=True)
    args = p.parse_args()

    local = os.path.join("eval", args.agent.lower().replace("_agent", ""), args.dataset)
    if not os.path.isfile(local):
        print(f"ERROR: {local} not found", file=sys.stderr)
        return 1

    with snowflake.connector.connect(connection_name=args.connection) as conn:
        cur = conn.cursor()
        cur.execute(f"PUT file://{os.path.abspath(local)} @EVAL.CFG_STAGE/ OVERWRITE=TRUE AUTO_COMPRESS=FALSE;")
        dataset_name = os.path.splitext(os.path.basename(local))[0]
        print(f"Uploaded {local}; running eval for {args.agent}:{args.version}")
        cur.execute(
            f"CALL EVAL.RUN_EVAL('{args.agent}', '{args.version}', '{dataset_name}');"
        )
        row = cur.fetchone()
        print(row[0] if row else "(no result)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
