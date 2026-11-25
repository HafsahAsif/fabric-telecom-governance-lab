#!/usr/bin/env python3
"""
gen_telecom_data.py
Generates a SYNTHETIC telecom dataset for Microsoft Fabric / Purview practice.
All names, CNICs, MSISDNs and emails are random and fake. No real PTCL data.

Tables (CSV):
  plans.csv, regions.csv, subscribers.csv, cdrs.csv, service_requests.csv

Optional dirty-data injection (--dirty-rate) adds nulls, bad emails,
duplicate rows and negative values so you can practise data quality rules later.

Author : Hafsah Asif
Usage  : python gen_telecom_data.py --subscribers 5000 --cdrs-per-sub 20 \
             --srs 3000 --out ./telecom_data --seed 42 --dirty-rate 0.02
Deps   : Python 3.8+ standard library only
"""

import argparse
import csv
import os
import random
from datetime import datetime, timedelta

# ---------------------------------------------------------------- reference data
REGIONS = [
    # region_id, region, city, province
    ("R01", "North", "Islamabad", "ICT"),
    ("R01", "North", "Rawalpindi", "Punjab"),
    ("R02", "Central", "Lahore", "Punjab"),
    ("R02", "Central", "Faisalabad", "Punjab"),
    ("R02", "Central", "Sialkot", "Punjab"),
    ("R03", "South Punjab", "Multan", "Punjab"),
    ("R04", "South", "Karachi", "Sindh"),
    ("R04", "South", "Hyderabad", "Sindh"),
    ("R05", "KP", "Peshawar", "Khyber Pakhtunkhwa"),
    ("R06", "Balochistan", "Quetta", "Balochistan"),
]

PLANS = [
    # plan_id, plan_name, plan_type, monthly_fee_pkr, data_gb, voice_mins
    ("P01", "Basic Prepaid", "Prepaid", 500, 5, 200),
    ("P02", "Smart Prepaid", "Prepaid", 1200, 20, 1000),
    ("P03", "Mega Prepaid", "Prepaid", 2000, 50, 3000),
    ("P04", "Postpaid Silver", "Postpaid", 2500, 40, 2000),
    ("P05", "Postpaid Gold", "Postpaid", 4500, 100, 5000),
    ("P06", "Broadband 20Mbps", "Broadband", 3500, 0, 0),
    ("P07", "Broadband 50Mbps", "Broadband", 6000, 0, 0),
]

FIRST_NAMES = {
    "M": ["Ali", "Ahmed", "Hamza", "Usman", "Bilal", "Fahad", "Zain", "Saad",
          "Hassan", "Omer", "Kashif", "Danish"],
    "F": ["Ayesha", "Fatima", "Zainab", "Maryam", "Hira", "Sana", "Iqra", "Amna",
          "Noor", "Mahnoor", "Areeba", "Rabia"],
}
LAST_NAMES = ["Khan", "Ahmed", "Malik", "Butt", "Qureshi", "Sheikh", "Chaudhry",
              "Raza", "Hussain", "Siddiqui", "Abbasi", "Mirza", "Javed", "Iqbal"]
EMAIL_DOMAINS = ["example.com", "example.org", "example.net"]  # reserved, never real

SR_CATEGORIES = ["No Service", "Slow Internet", "Billing Dispute", "Fault Repair",
                 "New Connection", "Plan Change", "Number Port", "Complaint - Staff"]
SR_CHANNELS = ["Call Centre", "App", "Web", "Walk-in", "WhatsApp"]
SR_PRIORITY = ["P1", "P2", "P3", "P4"]
SR_MTTR_HOURS = {"P1": (1, 8), "P2": (4, 24), "P3": (12, 72), "P4": (24, 168)}


# ---------------------------------------------------------------- helpers
def sub_window(sub, end):
    """Active window for a subscriber: activation date -> churn date (or data end)."""
    s = datetime.strptime(sub[11], "%Y-%m-%d")
    e = datetime.strptime(sub[13], "%Y-%m-%d") + timedelta(hours=23) if sub[13] else end
    return s, max(s, e)


def rand_dt(rng, start, end):
    return start + timedelta(seconds=rng.randint(0, int((end - start).total_seconds())))


def fake_cnic(rng):
    # 99xxx prefix is used deliberately so it never looks like a real district code
    return f"99{rng.randint(100, 999)}-{rng.randint(1000000, 9999999)}-{rng.randint(1, 9)}"


def fake_msisdn(rng):
    # 0399 is used deliberately as a fake prefix
    return f"0399{rng.randint(1000000, 9999999)}"


def maybe(rng, rate, value, dirty_value=None):
    """Return dirty_value (default None/blank) with probability rate."""
    return dirty_value if rng.random() < rate else value


def write_csv(path, header, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  {os.path.basename(path):<24} {len(rows):>9,} rows")


# ---------------------------------------------------------------- generators
def gen_subscribers(rng, n, start, end, dirty):
    rows = []
    for i in range(1, n + 1):
        gender = rng.choice(["M", "F"])
        first, last = rng.choice(FIRST_NAMES[gender]), rng.choice(LAST_NAMES)
        _, region, city, province = rng.choice(REGIONS)
        plan = rng.choice(PLANS)
        act = rand_dt(rng, start, end)
        status = rng.choices(["Active", "Suspended", "Churned"], weights=[80, 7, 13])[0]
        churn = rand_dt(rng, act, end).date().isoformat() if status == "Churned" else ""
        dob = (datetime(1960, 1, 1) + timedelta(days=rng.randint(0, 16000))).date()
        email = f"{first.lower()}.{last.lower()}{rng.randint(1, 999)}@{rng.choice(EMAIL_DOMAINS)}"
        rows.append([
            f"S{i:07d}",
            f"{first} {last}",
            maybe(rng, dirty, fake_cnic(rng), ""),
            fake_msisdn(rng),
            maybe(rng, dirty, email, email.replace("@", "")),   # bad email
            dob.isoformat(),
            gender,
            maybe(rng, dirty, city, ""),
            region,
            province,
            plan[0],
            act.date().isoformat(),
            status,
            churn,
        ])
    # duplicate a few rows (same subscriber_id) for DQ practice
    for _ in range(int(n * dirty / 2)):
        rows.append(list(rng.choice(rows)))
    return rows


def gen_cdrs(rng, subs, per_sub, start, end, dirty):
    rows, cid = [], 0
    for s in subs:
        sub_id, plan_id = s[0], s[10]
        w_start, w_end = sub_window(s, end)
        if plan_id in ("P06", "P07"):        # broadband: data sessions only
            types, weights = ["Data"], [1]
        else:
            types, weights = ["Voice", "SMS", "Data"], [50, 20, 30]
        for _ in range(rng.randint(max(1, per_sub // 2), per_sub * 2)):
            cid += 1
            ctype = rng.choices(types, weights=weights)[0]
            ts = rand_dt(rng, w_start, w_end)
            dur = rng.randint(5, 1800) if ctype == "Voice" else 0
            mb = round(rng.uniform(0.5, 2000), 2) if ctype == "Data" else 0
            charge = {"Voice": dur / 60 * 2.5, "SMS": 1.5, "Data": mb * 0.05}[ctype]
            charge = round(charge, 2)
            rows.append([
                f"C{cid:010d}",
                sub_id,
                ts.strftime("%Y-%m-%d %H:%M:%S"),
                ctype,
                dur,
                mb,
                fake_msisdn(rng) if ctype in ("Voice", "SMS") else "",
                maybe(rng, dirty, charge, -charge),             # negative charge
                f"CELL{rng.randint(1, 500):04d}",
            ])
    return rows


def gen_srs(rng, subs, n, start, end, dirty):
    rows = []
    for i in range(1, n + 1):
        s = rng.choice(subs)
        pr = rng.choices(SR_PRIORITY, weights=[5, 20, 50, 25])[0]
        w_start, w_end = sub_window(s, end)
        opened = rand_dt(rng, w_start, w_end)
        status = rng.choices(["Closed", "Open", "In Progress"], weights=[85, 8, 7])[0]
        lo, hi = SR_MTTR_HOURS[pr]
        hours = round(rng.uniform(lo, hi), 1)
        closed = (opened + timedelta(hours=hours)).strftime("%Y-%m-%d %H:%M:%S") if status == "Closed" else ""
        rows.append([
            f"SR{i:08d}",
            s[0],
            opened.strftime("%Y-%m-%d %H:%M:%S"),
            closed,
            rng.choice(SR_CATEGORIES),
            pr,
            rng.choice(SR_CHANNELS),
            status,
            hours if status == "Closed" else "",
            s[7] or "",                                         # city
        ])
    return rows


# ---------------------------------------------------------------- main
def main():
    p = argparse.ArgumentParser(description="Synthetic telecom data generator (Fabric practice)")
    p.add_argument("--subscribers", type=int, default=5000)
    p.add_argument("--cdrs-per-sub", type=int, default=20, help="average CDRs per subscriber")
    p.add_argument("--srs", type=int, default=3000, help="number of service requests")
    p.add_argument("--start", default="2025-01-01", help="data window start YYYY-MM-DD")
    p.add_argument("--end", default=datetime.now().strftime("%Y-%m-%d"), help="data window end YYYY-MM-DD")
    p.add_argument("--dirty-rate", type=float, default=0.02, help="0 for clean data")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="./telecom_data")
    a = p.parse_args()

    rng = random.Random(a.seed)
    start = datetime.strptime(a.start, "%Y-%m-%d")
    end = datetime.strptime(a.end, "%Y-%m-%d")
    os.makedirs(a.out, exist_ok=True)

    print(f"Generating into {os.path.abspath(a.out)}  (seed={a.seed}, dirty={a.dirty_rate})")

    write_csv(os.path.join(a.out, "regions.csv"),
              ["region_id", "region", "city", "province"], REGIONS)
    write_csv(os.path.join(a.out, "plans.csv"),
              ["plan_id", "plan_name", "plan_type", "monthly_fee_pkr", "data_gb", "voice_mins"], PLANS)

    subs = gen_subscribers(rng, a.subscribers, start, end, a.dirty_rate)
    write_csv(os.path.join(a.out, "subscribers.csv"),
              ["subscriber_id", "full_name", "cnic", "msisdn", "email", "date_of_birth", "gender",
               "city", "region", "province", "plan_id", "activation_date", "status", "churn_date"], subs)

    cdrs = gen_cdrs(rng, subs[:a.subscribers], a.cdrs_per_sub, start, end, a.dirty_rate)
    write_csv(os.path.join(a.out, "cdrs.csv"),
              ["cdr_id", "subscriber_id", "event_ts", "event_type", "duration_sec", "data_mb",
               "other_party_msisdn", "charge_pkr", "cell_id"], cdrs)

    srs = gen_srs(rng, subs[:a.subscribers], a.srs, start, end, a.dirty_rate)
    write_csv(os.path.join(a.out, "service_requests.csv"),
              ["sr_id", "subscriber_id", "opened_ts", "closed_ts", "category", "priority",
               "channel", "status", "resolution_hours", "city"], srs)

    print("Done.")


if __name__ == "__main__":
    main()
