#!/usr/bin/env python3
"""Rollback an agent's production alias to a previous version."""
from __future__ import annotations
import argparse, sys
import snowflake.connector


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--agent", required=True)
    p.add_argument("--to-version", required=True, help="e.g. VERSION$1 or LAST - 1")
    p.add_argument("--alias", default="production")
    p.add_argument("--connection", required=True)
    args = p.parse_args()

    with snowflake.connector.connect(connection_name=args.connection) as conn:
        cur = conn.cursor()
        cur.execute(
            f"ALTER AGENT AGENTS.{args.agent} "
            f"MODIFY VERSION {args.to_version} SET ALIAS = {args.alias};"
        )
        print(f"Rolled back {args.agent}: alias {args.alias} -> {args.to_version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
