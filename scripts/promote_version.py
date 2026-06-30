#!/usr/bin/env python3
"""Promote a specific agent version to a target alias (e.g. production)."""
from __future__ import annotations
import argparse, sys
import snowflake.connector


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--agent", required=True)
    p.add_argument("--version", required=True, help="VERSION$N or LAST")
    p.add_argument("--alias", default="production")
    p.add_argument("--connection", required=True)
    args = p.parse_args()

    with snowflake.connector.connect(connection_name=args.connection) as conn:
        cur = conn.cursor()
        cur.execute(
            f"ALTER AGENT AGENTS.{args.agent} "
            f"MODIFY VERSION {args.version} SET ALIAS = {args.alias};"
        )
        print(f"{args.agent}: {args.version} -> alias={args.alias}")
        cur.execute(f"SHOW VERSIONS IN AGENT AGENTS.{args.agent};")
        for r in cur.fetchall():
            print(r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
