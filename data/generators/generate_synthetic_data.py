#!/usr/bin/env python3
"""
Frostbyte synthetic data generator.

Deterministic (fixed seed) Faker-based generator that produces CSVs for:
    REGIONS, PRODUCT_CATALOG,
    HR_EMPLOYEES, HR_TERMINATIONS, HR_POLICY_DOCS,
    SALES_ACCOUNTS, SALES_CONTACTS, SALES_OPPS,
    MKT_CAMPAIGNS, MKT_LEADS.

PII is deliberately embedded for the demo.

Usage:
    python data/generators/generate_synthetic_data.py
    snow stage put-file data/seeds/*.csv @ARTIFACTS.SEEDS --connection frostbyte_dev
"""
from __future__ import annotations

import csv
import json
import random
import uuid
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Iterable

try:
    from faker import Faker
except ImportError as exc:
    raise SystemExit(
        "Faker is required. Install with: pip install Faker"
    ) from exc

SEED = 20260101
random.seed(SEED)
fake = Faker()
Faker.seed(SEED)

OUTPUT_DIR = Path(__file__).resolve().parents[1] / "seeds"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ----------------------------------------------------------------------------
# Reference data
# ----------------------------------------------------------------------------
REGIONS = [
    ("NA-WEST",  "North America - West",  "NA"),
    ("NA-EAST",  "North America - East",  "NA"),
    ("EMEA-FR",  "France",                "EMEA"),
    ("EMEA-DE",  "Germany",               "EMEA"),
    ("EMEA-UK",  "United Kingdom",        "EMEA"),
    ("JP",       "Japan",                 "JP"),
]
ROLLUP_REGIONS = ["NA", "EMEA", "JP"]
PRODUCT_LINES = ["Cornice", "Glacier"]
CHANNELS = ["DTC", "Wholesale", "Frostbyte Pro"]
ORG_UNITS = ["Marketing", "Sales", "Engineering", "Operations", "Finance", "HR"]
LEVELS = ["IC", "Manager", "Director", "VP", "C-LEVEL"]
STAGES = ["Prospect", "Qualified", "Proposal", "Negotiation", "Closed Won", "Closed Lost"]


def write_csv(filename: str, header: list[str], rows: Iterable[Iterable]) -> None:
    path = OUTPUT_DIR / filename
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"wrote {path}")


# ----------------------------------------------------------------------------
# Generators
# ----------------------------------------------------------------------------
def gen_regions():
    write_csv("regions.csv",
              ["region_code", "region_name", "rollup_region"],
              REGIONS)


def gen_product_catalog():
    rows = []
    for line in PRODUCT_LINES:
        for i in range(1, 11):
            rows.append((
                f"{line[:3].upper()}-{i:03d}",
                line,
                f"{line} {fake.color_name()} {i}",
                round(random.uniform(199, 1499), 2),
            ))
    write_csv("product_catalog.csv",
              ["sku", "product_line", "product_name", "unit_price_usd"],
              rows)


def gen_hr_employees(n: int = 1200):
    employees = []
    # First: VPs / C-level to seed the manager chain
    leaders = []
    for org in ORG_UNITS:
        emp_id = f"FB-EMP-{len(employees) + 1:05d}"
        first, last = fake.first_name(), fake.last_name()
        leaders.append(emp_id)
        employees.append({
            "employee_id": emp_id,
            "first_name": first,
            "last_name": last,
            "full_name": f"{first} {last}",
            "work_email": f"{first.lower()}.{last.lower()}@frostbyte.example",
            "personal_email": fake.free_email(),
            "phone": fake.phone_number(),
            "ssn": fake.ssn(),
            "home_address": fake.address().replace("\n", ", "),
            "dob": fake.date_of_birth(minimum_age=35, maximum_age=60),
            "hire_date": fake.date_between(start_date="-10y", end_date="-5y"),
            "termination_date": "",
            "active_status": 1,
            "org_unit": org,
            "manager_id": "",
            "manager_chain": json.dumps([]),
            "title": f"VP {org}",
            "level": "VP",
            "region": random.choice(ROLLUP_REGIONS),
            "base_salary": round(random.uniform(240000, 380000), 2),
            "equity_grant": round(random.uniform(200000, 600000), 2),
            "snapshot_date": date.today(),
        })

    # Rest: ICs/Managers reporting up
    for _ in range(n - len(employees)):
        emp_id = f"FB-EMP-{len(employees) + 1:05d}"
        first, last = fake.first_name(), fake.last_name()
        org = random.choice(ORG_UNITS)
        level = random.choices(LEVELS[:-1], weights=[60, 25, 12, 3])[0]
        manager_id = random.choice(leaders)
        manager_chain = [manager_id]
        active = random.choices([1, 0], weights=[92, 8])[0]
        hire = fake.date_between(start_date="-5y", end_date="-30d")
        term = "" if active else fake.date_between(start_date=hire, end_date="today")
        salary_band = {
            "IC": (90000, 180000),
            "Manager": (140000, 220000),
            "Director": (200000, 320000),
            "VP": (300000, 460000),
        }[level]
        employees.append({
            "employee_id": emp_id,
            "first_name": first,
            "last_name": last,
            "full_name": f"{first} {last}",
            "work_email": f"{first.lower()}.{last.lower()}@frostbyte.example",
            "personal_email": fake.free_email(),
            "phone": fake.phone_number(),
            "ssn": fake.ssn(),
            "home_address": fake.address().replace("\n", ", "),
            "dob": fake.date_of_birth(minimum_age=22, maximum_age=60),
            "hire_date": hire,
            "termination_date": term,
            "active_status": active,
            "org_unit": org,
            "manager_id": manager_id,
            "manager_chain": json.dumps(manager_chain),
            "title": f"{level} {org}",
            "level": level,
            "region": random.choice(ROLLUP_REGIONS),
            "base_salary": round(random.uniform(*salary_band), 2),
            "equity_grant": round(random.uniform(salary_band[0] // 4, salary_band[1] // 2), 2),
            "snapshot_date": date.today(),
        })

    header = list(employees[0].keys())
    write_csv("hr_employees.csv", header, (e.values() for e in employees))
    return employees


def gen_hr_terminations(employees, n: int = 250):
    terms = [e for e in employees if e["termination_date"]]
    rows = []
    for e in terms[:n]:
        rows.append((
            e["employee_id"],
            e["termination_date"],
            random.choice(["Voluntary", "Involuntary", "Retired", "Relocation"]),
            f"Exit interview for {e['full_name']} (contact: {e['personal_email']}). "
            f"Reason: {fake.sentence()}",
        ))
    write_csv("hr_terminations.csv",
              ["employee_id", "termination_date", "reason", "exit_interview_notes"], rows)


def gen_hr_policy_docs():
    docs = [
        ("DOC-001", "Parental Leave Policy", "leave",
         "Effective immediately, Frostbyte employees in EMEA receive 18 weeks of paid parental leave. "
         "Contact your HRBP (e.g., Sarah Mueller, sarah.mueller@frostbyte.example) to initiate the request."),
        ("DOC-002", "Compensation Guidelines", "comp",
         "Base salary bands are reviewed annually. Equity grants vest over 4 years. "
         "For questions contact comp@frostbyte.example or call +1-415-555-0188."),
        ("DOC-003", "Employee Handbook", "handbook",
         "All Frostbyte employees must complete safety training. New hires: see your onboarding buddy "
         "(example: Jin Tanaka, jin.tanaka@frostbyte.example) within week 1."),
        ("DOC-004", "Avalanche Safety Training", "safety",
         "Required for all Whiteout-line product staff and Frostbyte Pro field reps."),
        ("DOC-005", "Remote Work Policy", "handbook",
         "Hybrid is the default. EMEA staff coordinate with their regional VP (currently Marie Dubois, "
         "marie.dubois@frostbyte.example) for in-office days."),
    ]
    rows = [(d[0], d[1], d[2], d[3], datetime.utcnow().isoformat()) for d in docs]
    write_csv("hr_policy_docs.csv",
              ["doc_id", "title", "category", "content", "last_updated"], rows)


def gen_sales_accounts(n: int = 2000):
    accounts = []
    for _ in range(n):
        acct_id = str(uuid.uuid4())
        accounts.append({
            "account_id": acct_id,
            "account_name": fake.company(),
            "channel": random.choice(CHANNELS),
            "region": random.choice(ROLLUP_REGIONS),
            "segment": random.choice(["SMB", "Mid-Market", "Enterprise"]),
            "created_date": fake.date_between(start_date="-3y", end_date="today"),
        })
    write_csv("sales_accounts.csv",
              list(accounts[0].keys()), (a.values() for a in accounts))
    return accounts


def gen_sales_contacts(accounts, per_account: int = 2):
    rows = []
    for a in accounts:
        for _ in range(per_account):
            first, last = fake.first_name(), fake.last_name()
            rows.append((
                str(uuid.uuid4()),
                a["account_id"],
                f"{first} {last}",
                f"{first.lower()}.{last.lower()}@{a['account_name'].split()[0].lower()}.example",
                fake.phone_number(),
                f"https://linkedin.com/in/{first.lower()}-{last.lower()}",
            ))
    write_csv("sales_contacts.csv",
              ["contact_id", "account_id", "full_name", "email", "phone", "linkedin_url"], rows)


def gen_sales_opps(accounts, employees, n: int = 5000):
    rep_ids = [e["employee_id"] for e in employees if e["org_unit"] == "Sales"]
    rows = []
    for _ in range(n):
        a = random.choice(accounts)
        created = fake.date_between(start_date="-1y", end_date="today")
        close = created + timedelta(days=random.randint(30, 200))
        stage = random.choices(STAGES, weights=[25, 25, 20, 15, 10, 5])[0]
        product = random.choice(PRODUCT_LINES)
        rep = random.choice(rep_ids) if rep_ids else ""
        contact_email = fake.email()
        rows.append((
            str(uuid.uuid4()),
            a["account_id"],
            product,
            a["channel"],
            a["region"],
            stage,
            round(random.uniform(5000, 250000), 2),
            random.choice([True, False]),
            rep,
            created,
            close,
            f"Spoke with {fake.name()} (cc: {contact_email}). Discussed {product} pre-orders for next season.",
        ))
    write_csv("sales_opps.csv",
              ["opp_id", "account_id", "product_line", "channel", "region",
               "stage", "arr_usd", "is_pre_order", "rep_employee_id",
               "created_date", "close_date", "opportunity_notes"], rows)


def gen_mkt_campaigns():
    rows = []
    for line in PRODUCT_LINES:
        for region in ROLLUP_REGIONS:
            rows.append((
                f"CAMP-{line}-{region}",
                f"{line} {region} Season Launch",
                line,
                region,
                random.choice(CHANNELS),
                date.today() - timedelta(days=90),
                date.today() + timedelta(days=30),
                round(random.uniform(50000, 500000), 2),
            ))
    write_csv("mkt_campaigns.csv",
              ["campaign_id", "campaign_name", "product_line", "region",
               "channel", "start_date", "end_date", "budget_usd"], rows)
    return rows


def gen_mkt_leads(campaigns, accounts, n: int = 10000):
    rows = []
    for _ in range(n):
        c = random.choice(campaigns)
        first, last = fake.first_name(), fake.last_name()
        converted = random.choice([None, None, None, random.choice(accounts)["account_id"]])
        rows.append((
            str(uuid.uuid4()),
            c[0],
            first,
            last,
            f"{first.lower()}.{last.lower()}@{fake.free_email_domain()}",
            fake.phone_number(),
            fake.company(),
            fake.country(),
            c[3],
            fake.date_between(start_date="-90d", end_date="today"),
            converted or "",
            f"Lead {first} {last} called from {fake.phone_number()} about {c[2]} pre-orders.",
        ))
    write_csv("mkt_leads.csv",
              ["lead_id", "campaign_id", "first_name", "last_name", "email",
               "phone", "company", "country", "region", "mql_date",
               "converted_account_id", "lead_comments"], rows)


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main() -> None:
    print(f"Frostbyte synthetic data generator (seed={SEED})")
    print(f"Output dir: {OUTPUT_DIR}")
    gen_regions()
    gen_product_catalog()
    employees = gen_hr_employees()
    gen_hr_terminations(employees)
    gen_hr_policy_docs()
    accounts = gen_sales_accounts()
    gen_sales_contacts(accounts)
    gen_sales_opps(accounts, employees)
    campaigns = gen_mkt_campaigns()
    gen_mkt_leads(campaigns, accounts)
    print("done.")


if __name__ == "__main__":
    main()
