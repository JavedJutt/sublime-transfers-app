#!/usr/bin/env python3
"""Driver status-flow, idempotency, and audit verification."""
import json
import os
import urllib.request
import urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.environ.get("SUPABASE_PROJECT_REF", "ktmkirodwdwpzjxqwboo")
BASE = f"https://{REF}.supabase.co"
ANON = os.environ["SUPABASE_ANON_KEY"]
PASSWORD = os.environ.get("SUPABASE_TEST_PASSWORD", "Password123!")
passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1; print(f"  PASS  {name}")
    else:
        failed += 1; print(f"  FAIL  {name}  {detail}")


def signin(email):
    req = urllib.request.Request(
        f"{BASE}/auth/v1/token?grant_type=password",
        data=json.dumps({"email": email, "password": PASSWORD}).encode(), method="POST",
        headers={"apikey": ANON, "Content-Type": "application/json", "User-Agent": "flow/1.0"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["access_token"]


def mgmt(sql):
    token = os.environ["SUPABASE_ACCESS_TOKEN"]
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{REF}/database/query",
        data=json.dumps({"query": sql}).encode(), method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json",
                 "User-Agent": "flow/1.0"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode() or "null")


def rpc(token, fn, args):
    req = urllib.request.Request(
        f"{BASE}/rest/v1/rpc/{fn}", data=json.dumps(args).encode(), method="POST",
        headers={"apikey": ANON, "Authorization": f"Bearer {token}",
                 "Content-Type": "application/json", "User-Agent": "flow/1.0"})
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "null")


def main():
    marcus = signin("marcus.driver@sublimetransfers.test")
    marcus_id = mgmt("select id from profiles where email='marcus.driver@sublimetransfers.test'")[0]["id"]

    # Assign a fresh ride directly to Marcus in 'assigned' state.
    mgmt(f"""
      update public.rides set status='assigned', assigned_driver_id='{marcus_id}',
        assignment_method='direct', assigned_at=now(), broadcast_open=false
      where reference='ST-SEED01';
    """)
    rid = mgmt("select id from public.rides where reference='ST-SEED01'")[0]["id"]

    print("Status flow (assigned -> en_route -> arrived -> in_progress -> completed):")
    seq = ["en_route", "arrived", "in_progress", "completed"]
    for i, to in enumerate(seq):
        s, out = rpc(marcus, "advance_ride_status", {
            "p_ride_id": rid, "p_to": to,
            "p_lat": 51.47 + i * 0.01, "p_lng": -0.45 + i * 0.01,
            "p_accuracy_m": 8.0, "p_captured_at": "2026-07-21T10:0%d:00Z" % i,
        })
        check(f"advance to {to}", s == 200 and isinstance(out, dict) and out.get("status") == to,
              f"status={s} out={out if not isinstance(out, dict) else out.get('status')}")

    # Location captured at every change: 4 status_advanced events with coords.
    ev = mgmt(f"""
      select count(*) as n from public.ride_status_events
      where ride_id='{rid}' and action='status_advanced'
        and lat is not null and driver_id='{marcus_id}';
    """)[0]["n"]
    check("4 location-stamped status events written", ev >= 4, f"n={ev}")

    print("\nIllegal transition rejection:")
    # Ride is now 'completed'; en_route from completed is illegal.
    s, out = rpc(marcus, "advance_ride_status", {"p_ride_id": rid, "p_to": "en_route"})
    check("illegal transition rejected", s >= 400 and "invalid_transition" in json.dumps(out),
          f"status={s} out={out}")

    print("\nOffline idempotency (same client_event_id twice):")
    mgmt(f"""
      update public.rides set status='assigned', assigned_driver_id='{marcus_id}'
      where reference='ST-SEED02';
    """)
    # SEED02 belongs to noah as source; assign to marcus for the test.
    rid2 = mgmt("select id from public.rides where reference='ST-SEED02'")[0]["id"]
    evt = "11111111-2222-3333-4444-555555555555"
    s1, o1 = rpc(marcus, "advance_ride_status",
                 {"p_ride_id": rid2, "p_to": "en_route", "p_client_event_id": evt})
    s2, o2 = rpc(marcus, "advance_ride_status",
                 {"p_ride_id": rid2, "p_to": "en_route", "p_client_event_id": evt})
    check("first replay call succeeds", s1 == 200)
    check("second identical call is a no-op (still 200, not double-applied)", s2 == 200)
    n_events = mgmt(f"""
      select count(*) as n from public.ride_status_events
      where ride_id='{rid2}' and action='status_advanced' and to_status='en_route'
        and metadata->>'rpc'='true';
    """)[0]["n"]
    check("exactly one event written for the replayed action", n_events == 1, f"n={n_events}")

    print("\nAudit trail on insert:")
    created = mgmt("""
      select count(*) as n from public.ride_status_events e
      join public.rides r on r.id=e.ride_id
      where r.reference like 'ST-SEED%' and e.action='created';
    """)[0]["n"]
    check("every seeded ride has a 'created' audit event", created >= 20, f"n={created}")

    print(f"\n==== {passed} passed, {failed} failed ====")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
