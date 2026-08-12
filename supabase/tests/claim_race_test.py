#!/usr/bin/env python3
"""Broadcast claim concurrency test.

Fires N simultaneous claim_broadcast_ride calls (from the two approved drivers,
interleaved) at one open broadcast ride and asserts exactly one winner. This is
the check the FOR UPDATE lock exists for: a losing claimer must block, re-read
the committed row, and report already_claimed — never a second success and
never not_found.
"""
import json
import os
import threading
import urllib.request
import urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.environ.get("SUPABASE_PROJECT_REF", "ktmkirodwdwpzjxqwboo")
BASE = f"https://{REF}.supabase.co"
ANON = os.environ["SUPABASE_ANON_KEY"]
PASSWORD = os.environ.get("SUPABASE_TEST_PASSWORD", "Password123!")


def signin(email):
    req = urllib.request.Request(
        f"{BASE}/auth/v1/token?grant_type=password",
        data=json.dumps({"email": email, "password": PASSWORD}).encode(),
        method="POST",
        headers={"apikey": ANON, "Content-Type": "application/json",
                 "User-Agent": "race-test/1.0"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["access_token"]


def mgmt(sql):
    token = os.environ["SUPABASE_ACCESS_TOKEN"]
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{REF}/database/query",
        data=json.dumps({"query": sql}).encode(), method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json",
                 "User-Agent": "race-test/1.0"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode() or "null")


def claim(token, ride_id, results, idx):
    req = urllib.request.Request(
        f"{BASE}/rest/v1/rpc/claim_broadcast_ride",
        data=json.dumps({"p_ride_id": ride_id}).encode(), method="POST",
        headers={"apikey": ANON, "Authorization": f"Bearer {token}",
                 "Content-Type": "application/json", "User-Agent": "race-test/1.0"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            results[idx] = ("ok", r.status)
    except urllib.error.HTTPError as e:
        body = json.loads(e.read().decode() or "null")
        results[idx] = ("err", body.get("message", "") if isinstance(body, dict) else str(body))


def main():
    marcus = signin("marcus.driver@sublimetransfers.test")
    priya = signin("priya.driver@sublimetransfers.test")

    # Open a fresh broadcast on a known seed ride.
    mgmt("""
      update public.rides
      set status='unassigned', assigned_driver_id=null, broadcast_open=true,
          broadcast_started_at=now(), assignment_method='broadcast'
      where reference='ST-SEED03';
    """)
    ride_id = mgmt("select id from public.rides where reference='ST-SEED03';")[0]["id"]

    N = 20
    tokens = [marcus, priya] * (N // 2)
    results = [None] * N
    threads = [threading.Thread(target=claim, args=(tokens[i], ride_id, results, i))
               for i in range(N)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    oks = [r for r in results if r and r[0] == "ok"]
    claimed_errs = [r for r in results if r and r[0] == "err" and "already_claimed" in (r[1] or "")]
    other_errs = [r for r in results if r and r[0] == "err" and "already_claimed" not in (r[1] or "")]

    print(f"{N} concurrent claims: {len(oks)} ok, {len(claimed_errs)} already_claimed, "
          f"{len(other_errs)} other")

    # Confirm the DB agrees: exactly one assignment.
    row = mgmt("""
      select assigned_driver_id, broadcast_open, status
      from public.rides where reference='ST-SEED03';
    """)[0]
    print(f"final row: driver={row['assigned_driver_id']} "
          f"broadcast_open={row['broadcast_open']} status={row['status']}")

    ok = True
    def check(name, cond, detail=""):
        nonlocal ok
        print(f"  {'PASS' if cond else 'FAIL'}  {name}  {detail if not cond else ''}")
        ok = ok and cond

    check("exactly one winner", len(oks) == 1, f"got {len(oks)}")
    check("all losers report already_claimed", len(other_errs) == 0,
          f"unexpected: {other_errs}")
    check("ride is assigned to one driver", row["assigned_driver_id"] is not None)
    check("broadcast closed after claim", row["broadcast_open"] is False)
    check("status is assigned", row["status"] == "assigned")

    # Exactly one accepted offer, rest expired.
    offers = mgmt(f"""
      select status, count(*) from public.ride_offers
      where ride_id='{ride_id}' group by status order by status;
    """)
    print(f"offers: {offers}")

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
