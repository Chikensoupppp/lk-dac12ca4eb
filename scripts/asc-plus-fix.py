"""Fills in the SwipeLater Plus subscription text App Store Connect needs (en-US): the group's
display name, each plan's display name and description (the old "Nogbox" names), and a review
note per plan. Prices, trial and availability are left alone. Prints before and after.
Runs in .github/workflows/asc-plus-fix.yml with the ASC_* repo secrets. Prints no secret values."""
import os, sys, time
import jwt, requests

BUNDLE = "com.brandon132199.lockin"
API = "https://api.appstoreconnect.apple.com/v1"
GROUP_NAME = "SwipeLater Plus"
PLANS = {
    "com.brandon132199.lockin.plus.yearly": ("SwipeLater Plus Yearly", "Locked mode, a partner key, all history."),
    "com.brandon132199.lockin.plus.monthly": ("SwipeLater Plus Monthly", "Locked mode, a partner key, all history."),
}
REVIEW_NOTE = ("Offered on the last intro slide and from the Locked mode switch on the Focus screen. "
               "Plus adds Locked mode (no quit button), partner unlock, and the full weekly history. "
               "Restore Purchases is on the offer screen.")

def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, **kw):
    r = requests.request(method, API + path, headers={"Authorization": "Bearer " + token()}, timeout=60, **kw)
    if r.status_code >= 400:
        print(f"{method} {path.split('?')[0]} -> {r.status_code}: {r.text[:800]}"); sys.exit(1)
    return r.json() if r.content else {}

for d in PLANS.values():
    assert len(d[1]) <= 45, d[1]

app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
group = call("GET", f"/apps/{app_id}/subscriptionGroups")["data"][0]

glocs = call("GET", f"/subscriptionGroups/{group['id']}/subscriptionGroupLocalizations")["data"]
en = next((l for l in glocs if l["attributes"]["locale"] == "en-US"), None)
if en:
    print("group name before:", en["attributes"].get("name"))
    call("PATCH", f"/subscriptionGroupLocalizations/{en['id']}",
         json={"data": {"type": "subscriptionGroupLocalizations", "id": en["id"], "attributes": {"name": GROUP_NAME}}})
else:
    call("POST", "/subscriptionGroupLocalizations",
         json={"data": {"type": "subscriptionGroupLocalizations", "attributes": {"name": GROUP_NAME, "locale": "en-US"},
                        "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": group["id"]}}}}})
print("group name after:", GROUP_NAME)

for s in call("GET", f"/subscriptionGroups/{group['id']}/subscriptions")["data"]:
    pid = s["attributes"]["productId"]
    if pid not in PLANS: continue
    name, desc = PLANS[pid]
    for l in call("GET", f"/subscriptions/{s['id']}/subscriptionLocalizations")["data"]:
        if l["attributes"]["locale"] != "en-US": continue
        print(f"{pid} before: {l['attributes'].get('name')!r} / {l['attributes'].get('description')!r}")
        out = call("PATCH", f"/subscriptionLocalizations/{l['id']}",
                   json={"data": {"type": "subscriptionLocalizations", "id": l["id"], "attributes": {"name": name, "description": desc}}})
        print(f"{pid} after:  {out['data']['attributes'].get('name')!r} / {out['data']['attributes'].get('description')!r}")
    call("PATCH", f"/subscriptions/{s['id']}",
         json={"data": {"type": "subscriptions", "id": s["id"], "attributes": {"reviewNote": REVIEW_NOTE}}})
    after = call("GET", f"/subscriptions/{s['id']}")["data"]["attributes"]
    print(f"{pid} review note set; state now {after.get('state')}")
