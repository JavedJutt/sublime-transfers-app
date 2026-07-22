#!/usr/bin/env python3
"""Seed auth users via the Auth Admin API.

Creates 2 admins and 3 drivers (one pending) with a known dev password. The
handle_new_user trigger turns each into a profile / driver_profile from the
metadata we pass here. Idempotent-ish: if a user exists the API 422s and we
skip, then fetch the existing id.
"""
import json
import os
import urllib.request
import urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.environ.get("SUPABASE_PROJECT_REF", "ktmkirodwdwpzjxqwboo")
BASE = f"https://{REF}.supabase.co"
SERVICE = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
PASSWORD = os.environ.get("SUPABASE_TEST_PASSWORD", "Password123!")

USERS = [
    ("ava.admin@sublimetransfers.test", "admin", {"role": "admin", "full_name": "Ava Whitfield", "phone": "+44 20 7946 0011"}),
    ("noah.admin@sublimetransfers.test", "admin", {"role": "admin", "full_name": "Noah Bergström", "phone": "+44 20 7946 0022"}),
    ("marcus.driver@sublimetransfers.test", "driver", {"role": "driver", "full_name": "Marcus Bell", "phone": "+44 7700 900101", "approval_status": "approved", "vehicle_type": "executive", "vehicle_make": "Mercedes E-Class", "vehicle_plate": "LX21 ATE"}),
    ("priya.driver@sublimetransfers.test", "driver", {"role": "driver", "full_name": "Priya Raman", "phone": "+44 7700 900102", "approval_status": "approved", "vehicle_type": "mpv", "vehicle_make": "VW Sharan", "vehicle_plate": "LM70 KRP"}),
    ("sam.driver@sublimetransfers.test", "driver", {"role": "driver", "full_name": "Sam Okafor", "phone": "+44 7700 900103", "approval_status": "pending", "vehicle_type": "sedan", "vehicle_make": "Toyota Prius", "vehicle_plate": "YK19 OKF"}),
]


def _req(method, path, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={
            "apikey": SERVICE,
            "Authorization": f"Bearer {SERVICE}",
            "Content-Type": "application/json",
            "User-Agent": "sublime-transfers-seed/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")


def find_user(email):
    # Admin list with a filter.
    status, payload = _req("GET", f"/auth/v1/admin/users?page=1&per_page=200")
    if status != 200:
        return None
    for u in payload.get("users", []):
        if u.get("email") == email:
            return u["id"]
    return None


def main():
    out = {}
    for email, role, meta in USERS:
        status, payload = _req("POST", "/auth/v1/admin/users", {
            "email": email,
            "password": PASSWORD,
            "email_confirm": True,
            "user_metadata": meta,
        })
        if status in (200, 201):
            out[email] = payload["id"]
            print(f"created {role:6} {email} -> {payload['id']}")
        else:
            existing = find_user(email)
            if existing:
                out[email] = existing
                print(f"exists  {role:6} {email} -> {existing}")
            else:
                print(f"FAIL    {email}: {status} {payload}")
    json.dump(out, open(os.path.join(HERE, "seed_user_ids.json"), "w"), indent=2)
    print(f"\nwrote {len(out)} user ids")


if __name__ == "__main__":
    main()
