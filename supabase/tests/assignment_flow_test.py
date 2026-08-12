#!/usr/bin/env python3
"""End-to-end assignment lifecycle test against the live project.

Exercises the full Phase 4 flow through the same RPCs the Flutter app calls:
direct assign -> accept, direct assign -> decline (reverts + notifies),
broadcast -> claim, and admin override (reassign / cancel). Verifies the ride
state and the notifications each step produces.
"""
import json
import os
import urllib.request
import urllib.error

REF = os.environ.get("SUPABASE_PROJECT_REF", "ktmkirodwdwpzjxqwboo")
BASE = f"https://{REF}.supabase.co"
ANON = os.environ["SUPABASE_ANON_KEY"]
TOKEN = os.environ["SUPABASE_ACCESS_TOKEN"]
PASSWORD = os.environ.get("SUPABASE_TEST_PASSWORD", "Password123!")
passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1; print(f"  PASS  {name}")
    else:
        failed += 1; print(f"  FAIL  {name}  {detail}")


def signin(email):
    r = urllib.request.Request(
        f"{BASE}/auth/v1/token?grant_type=password",
        data=json.dumps({"email": email, "password": PASSWORD}).encode(),
        method="POST",
        headers={"apikey": ANON, "Content-Type": "application/json", "User-Agent": "a/1"})
    return json.loads(urllib.request.urlopen(r).read())["access_token"]


def mgmt(sql):
    r = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{REF}/database/query",
        data=json.dumps({"query": sql}).encode(), method="POST",
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json",
                 "User-Agent": "a/1"})
    return json.loads(urllib.request.urlopen(r).read().decode() or "null")


def rpc(token, fn, args):
    r = urllib.request.Request(
        f"{BASE}/rest/v1/rpc/{fn}", data=json.dumps(args).encode(), method="POST",
        headers={"apikey": ANON, "Authorization": f"Bearer {token}",
                 "Content-Type": "application/json", "User-Agent": "a/1"})
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "null")


def ride(ref_):
    return mgmt(f"select id,status,assigned_driver_id,broadcast_open,assignment_method "
                f"from rides where reference='{ref_}'")[0]


def uid(email):
    return mgmt(f"select id from profiles where email='{email}'")[0]["id"]


def main():
    admin = signin("ava.admin@sublimetransfers.test")
    marcus = signin("marcus.driver@sublimetransfers.test")
    priya = signin("priya.driver@sublimetransfers.test")
    marcus_id = uid("marcus.driver@sublimetransfers.test")
    priya_id = uid("priya.driver@sublimetransfers.test")

    # Reset two seed rides to a clean unassigned state to work with.
    mgmt("""
      update rides set status='unassigned', assigned_driver_id=null,
        assigning_admin_id=null, assignment_method=null, broadcast_open=false
      where reference in ('ST-SEED01','ST-SEED02');
      delete from ride_offers where ride_id in
        (select id from rides where reference in ('ST-SEED01','ST-SEED02'));
    """)
    r1 = ride("ST-SEED01")["id"]

    print("Direct assign -> accept:")
    s, _ = rpc(admin, "assign_ride_direct", {"p_ride_id": r1, "p_driver_id": marcus_id})
    check("admin assigns directly", s == 200)
    check("ride is 'offered' after direct assign", ride("ST-SEED01")["status"] == "offered")
    # Marcus has a pending offer + a notification.
    n = mgmt(f"select count(*) c from notifications where user_id='{marcus_id}' "
             f"and type='offer' and ride_id='{r1}'")[0]["c"]
    check("driver notified of the offer", n >= 1, f"n={n}")

    s, _ = rpc(marcus, "respond_to_offer", {"p_ride_id": r1, "p_accept": True})
    check("driver accepts", s == 200)
    row = ride("ST-SEED01")
    check("ride assigned to the driver after accept",
          row["status"] == "assigned" and row["assigned_driver_id"] == marcus_id)

    print("\nDirect assign -> decline reverts + notifies admin:")
    mgmt(f"update rides set status='unassigned', assigned_driver_id=null where id='{r1}';"
         f"delete from ride_offers where ride_id='{r1}';")
    rpc(admin, "assign_ride_direct", {"p_ride_id": r1, "p_driver_id": marcus_id})
    s, _ = rpc(marcus, "respond_to_offer",
               {"p_ride_id": r1, "p_accept": False, "p_reason": "Too far"})
    check("driver declines", s == 200)
    check("ride reverts to unassigned on decline",
          ride("ST-SEED01")["status"] == "unassigned")
    admin_id = uid("ava.admin@sublimetransfers.test")
    n = mgmt(f"select count(*) c from notifications where user_id='{admin_id}' "
             f"and type='offer_declined' and ride_id='{r1}'")[0]["c"]
    check("admin notified of the decline", n >= 1, f"n={n}")

    print("\nBroadcast -> claim:")
    mgmt("update driver_profiles set is_on_duty=true where id in "
         f"('{marcus_id}','{priya_id}');")
    s, _ = rpc(admin, "broadcast_ride", {"p_ride_id": r1})
    check("admin broadcasts", s == 200)
    check("ride is open for broadcast", ride("ST-SEED01")["broadcast_open"] is True)
    # Both on-duty drivers got an offer notification.
    n = mgmt(f"select count(*) c from ride_offers where ride_id='{r1}' and status='pending'")[0]["c"]
    check("offer fanned out to on-duty drivers", n >= 2, f"n={n}")
    s, _ = rpc(priya, "claim_broadcast_ride", {"p_ride_id": r1})
    check("a driver claims the broadcast", s == 200)
    row = ride("ST-SEED01")
    check("claim assigns the ride and closes the broadcast",
          row["assigned_driver_id"] == priya_id and row["broadcast_open"] is False)

    print("\nAdmin override -> reassign then cancel:")
    s, _ = rpc(admin, "admin_override_assignment",
               {"p_ride_id": r1, "p_action": "reassign", "p_driver_id": marcus_id})
    check("admin reassigns to another driver", s == 200)
    check("ride now belongs to the new driver",
          ride("ST-SEED01")["assigned_driver_id"] == marcus_id)
    # The bumped driver (priya) is notified.
    n = mgmt(f"select count(*) c from notifications where user_id='{priya_id}' "
             f"and ride_id='{r1}' and title='Ride reassigned'")[0]["c"]
    check("bumped driver notified of reassignment", n >= 1, f"n={n}")

    s, _ = rpc(admin, "admin_override_assignment",
               {"p_ride_id": r1, "p_action": "cancel", "p_reason": "Customer cancelled"})
    check("admin cancels the ride", s == 200)
    check("ride is cancelled", ride("ST-SEED01")["status"] == "cancelled")

    print("\nDriver cannot call an admin override:")
    s, out = rpc(marcus, "admin_override_assignment",
                 {"p_ride_id": r1, "p_action": "cancel"})
    check("driver override is forbidden", s >= 400 and "forbidden" in json.dumps(out))

    print(f"\n==== {passed} passed, {failed} failed ====")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
