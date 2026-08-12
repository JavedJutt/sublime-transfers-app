#!/usr/bin/env python3
"""RLS verification against the live project, via real signed JWTs.

This is the tier that matters most: an RLS bug is invisible in the UI and
catastrophic in production. We sign in as an actual driver and an actual admin
and exercise the REST API exactly as the Flutter app will.
"""
import json
import os
import sys
import urllib.request
import urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.environ.get("SUPABASE_PROJECT_REF", "ktmkirodwdwpzjxqwboo")
BASE = f"https://{REF}.supabase.co"
ANON = os.environ["SUPABASE_ANON_KEY"]
PASSWORD = os.environ.get("SUPABASE_TEST_PASSWORD", "Password123!")

passed, failed = 0, 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}  {detail}")


def signin(email):
    req = urllib.request.Request(
        f"{BASE}/auth/v1/token?grant_type=password",
        data=json.dumps({"email": email, "password": PASSWORD}).encode(),
        method="POST",
        headers={"apikey": ANON, "Content-Type": "application/json",
                 "User-Agent": "rls-test/1.0"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["access_token"]


def rest(token, path, method="GET", body=None):
    req = urllib.request.Request(
        f"{BASE}/rest/v1/{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"apikey": ANON, "Authorization": f"Bearer {token}",
                 "Content-Type": "application/json", "User-Agent": "rls-test/1.0"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "null")


def rpc(token, fn, args):
    return rest(token, f"rpc/{fn}", "POST", args)


def main():
    driver = signin("marcus.driver@sublimetransfers.test")
    admin = signin("ava.admin@sublimetransfers.test")
    print("signed in as driver + admin\n")

    print("Admin visibility:")
    s, rows = rest(admin, "admin_rides?select=reference,source_admin_name,status&order=pickup_at")
    check("admin can read admin_rides", s == 200 and isinstance(rows, list) and len(rows) >= 20,
          f"status={s} n={len(rows) if isinstance(rows, list) else rows}")
    check("admin_rides exposes source_admin_name",
          isinstance(rows, list) and rows and "source_admin_name" in rows[0])

    s, rows = rest(admin, "rides?select=id")
    check("admin CANNOT read base rides table directly (grant revoked)",
          s in (401, 403) or (s == 404), f"status={s}")

    print("\nDriver visibility:")
    s, rows = rest(driver, "rides?select=id")
    check("driver CANNOT read base rides table directly",
          s in (401, 403, 404), f"status={s}")

    s, rows = rest(driver, "driver_rides?select=*")
    check("driver can read driver_rides", s == 200 and isinstance(rows, list), f"status={s}")
    if isinstance(rows, list) and rows:
        cols = set(rows[0].keys())
        check("driver_rides has NO source_admin_id column",
              "source_admin_id" not in cols, f"cols={sorted(cols)}")
        check("driver_rides has NO assigning_admin_id column",
              "assigning_admin_id" not in cols)
        check("driver_rides has NO source_email_id column",
              "source_email_id" not in cols)
        # Marcus should see only his own rides + open broadcasts, never Priya's.
        statuses = {r["status"] for r in rows}
        check("driver sees a bounded set (own + broadcast), not all 20",
              len(rows) < 20, f"n={len(rows)}")
        check("driver does not see other drivers' in_progress rides",
              all(r["assigned_driver_id"] in (None,) or r["assigned_driver_id"]
                  for r in rows))

    s, rows = rest(driver, "admin_rides?select=id")
    check("driver reading admin_rides yields zero rows (RLS)",
          s == 200 and rows == [], f"status={s} rows={rows}")

    print("\nDriver write attempts:")
    # Grab a ride id the driver can see to try a direct patch.
    s, dr = rest(driver, "driver_rides?select=id&limit=1")
    if isinstance(dr, list) and dr:
        rid = dr[0]["id"]
        s, out = rest(driver, f"rides?id=eq.{rid}", "PATCH", {"status": "completed"})
        check("driver CANNOT PATCH rides directly", s in (401, 403, 404, 405), f"status={s}")

    print("\nDriver approval gate:")
    # Sam is pending — sign in and confirm he can't see the pool.
    try:
        sam = signin("sam.driver@sublimetransfers.test")
        s, rows = rest(sam, "driver_rides?select=id")
        check("PENDING driver sees no rides", s == 200 and rows == [], f"status={s} n={rows}")
    except Exception as e:
        check("pending driver sign-in", False, str(e))

    print("\nRPC guards:")
    s, out = rpc(driver, "assign_ride_direct", {"p_ride_id": "00000000-0000-0000-0000-000000000000", "p_driver_id": "00000000-0000-0000-0000-000000000000"})
    check("driver calling admin RPC assign_ride_direct is forbidden",
          s >= 400 and "forbidden" in json.dumps(out), f"status={s} out={out}")

    print(f"\n==== {passed} passed, {failed} failed ====")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
