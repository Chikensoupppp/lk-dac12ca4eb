"""Uploads docs/design/plus-review-shot.png as the App Review screenshot of both SwipeLater Plus
subscriptions (the last thing they need to leave "Missing Metadata"). Replaces an existing one.
Runs in .github/workflows/asc-plus-shot.yml with the ASC_* repo secrets. Prints no secret values."""
import hashlib, os, sys, time
import jwt, requests

BUNDLE = "com.brandon132199.lockin"
API = "https://api.appstoreconnect.apple.com/v1"
SHOT = "docs/design/plus-review-shot.png"
IDS = {"com.brandon132199.lockin.plus.yearly", "com.brandon132199.lockin.plus.monthly"}

def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, fatal=True, **kw):
    r = requests.request(method, API + path, headers={"Authorization": "Bearer " + token()}, timeout=60, **kw)
    if r.status_code >= 400:
        print(f"{method} {path.split('?')[0]} -> {r.status_code}: {r.text[:800]}")
        if fatal: sys.exit(1)
        return None
    return r.json() if r.content else {}

data = open(SHOT, "rb").read()
app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
group = call("GET", f"/apps/{app_id}/subscriptionGroups")["data"][0]
for s in call("GET", f"/subscriptionGroups/{group['id']}/subscriptions")["data"]:
    pid = s["attributes"]["productId"]
    if pid not in IDS: continue
    old = call("GET", f"/subscriptions/{s['id']}/appStoreReviewScreenshot", fatal=False)
    if old and old.get("data"):
        call("DELETE", f"/subscriptionAppStoreReviewScreenshots/{old['data']['id']}", fatal=False)
    made = call("POST", "/subscriptionAppStoreReviewScreenshots", json={"data": {
        "type": "subscriptionAppStoreReviewScreenshots",
        "attributes": {"fileName": "plus-offer.png", "fileSize": len(data)},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": s["id"]}}}}})["data"]
    for op in made["attributes"]["uploadOperations"]:
        part = data[op["offset"]:op["offset"] + op["length"]]
        r = requests.request(op["method"], op["url"], data=part,
                             headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])}, timeout=120)
        if r.status_code >= 400: sys.exit(f"upload part failed: {r.status_code}")
    call("PATCH", f"/subscriptionAppStoreReviewScreenshots/{made['id']}", json={"data": {
        "type": "subscriptionAppStoreReviewScreenshots", "id": made["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    time.sleep(3)
    state = call("GET", f"/subscriptions/{s['id']}")["data"]["attributes"].get("state")
    print(f"{pid}: screenshot uploaded; state now {state}")
