# Database verification scripts

Faithful RLS / concurrency / flow tests that run against a live Supabase
project using real signed JWTs — the tier that matters most, since an RLS bug
is invisible in the UI and catastrophic in production.

## Running

```bash
export SUPABASE_ACCESS_TOKEN=sbp_...          # personal access token
export SUPABASE_ANON_KEY=eyJ...               # project anon/publishable key
export SUPABASE_PROJECT_REF=ktmkirodwdwpzjxqwboo
export SUPABASE_TEST_PASSWORD='Password123!'  # seeded dev password

python3 rls_test.py          # 14 checks: column hiding, row scope, write denial
python3 claim_race_test.py   # 20 concurrent broadcast claims -> exactly one winner
python3 flow_test.py         # status flow, illegal-transition rejection, idempotency, audit
```

The seeded accounts these expect are created by `scripts/seed_users.py`, and
`../seed.sql` populates the rides.
