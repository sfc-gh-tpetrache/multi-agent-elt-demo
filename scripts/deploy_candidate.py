#!/usr/bin/env python3
"""Deploy a candidate agent version from a Git ref.

Usage:
    python scripts/deploy_candidate.py \
        --agent MARKETING_AGENT \
        --connection frostbyte_dev \
        --git-ref branches/feature-xyz \
        --alias dev

Calls:
    ALTER AGENT <agent> ADD VERSION FROM @ARTIFACTS.GIT_REPO/<git-ref>/agents/<agent_lower>
    ALTER AGENT <agent> MODIFY VERSION VERSION$N SET ALIAS = <alias>
"""
from __future__ import annotations

import argparse
import sys

import snowflake.connector


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--agent", required=True)
    p.add_argument("--connection", required=True)
    p.add_argument("--git-ref", required=True, help="e.g. branches/main, tags/prod-7")
    p.add_argument("--alias", default="dev")
    args = p.parse_args()

    agent_path_dir = args.agent.lower().replace("_agent", "")
    src = f"@ARTIFACTS.GIT_REPO/{args.git_ref}/agents/{agent_path_dir}"

    with snowflake.connector.connect(connection_name=args.connection) as conn:
        cur = conn.cursor()
        cur.execute("ALTER GIT REPOSITORY ARTIFACTS.GIT_REPO FETCH;")
        print(f"Adding version to {args.agent} from {src}")
        cur.execute(f"ALTER AGENT AGENTS.{args.agent} ADD VERSION FROM {src};")
        cur.execute(f"SHOW VERSIONS IN AGENT AGENTS.{args.agent};")
        versions = cur.fetchall()
        latest = versions[-1][1] if versions else None
        print(f"Latest version: {latest}")
        cur.execute(
            f"ALTER AGENT AGENTS.{args.agent} MODIFY VERSION {latest} SET ALIAS = {args.alias};"
        )
        print(f"Aliased {latest} -> {args.alias}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
