"""Before the first submission: reports the SwipeLater Plus subscriptions (state, free trial, prices,
names, review screenshot) and the version's App Review details, then sets the review notes from
docs/APP_REVIEW.md (between the notes markers). Changes nothing else.
Runs in .github/workflows/asc-review.yml with the ASC_* repo secrets. Prints no secret values."""
import os, re, sys, time
import jwt, requests

BUNDLE = "com.brandon132199.lockin"
API = "https://api.appstoreconnect.apple.com/v1"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}

def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, fatal=True, **kw):
    r = requests.request(method, API + path, headers={"Authorization": "Bearer " + token()}, timeout=60, **kw)
    if r.status_code >= 400:
        print(f"  ! {method} {path.split('?')[0]} -> {r.status_code}: {r.text[:600]}")
        if fatal: sys.exit(1)
        return None
    return r.json() if r.content else {}

app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
print("app", app_id)

print("\n== Subscriptions ==")
groups = call("GET", f"/apps/{app_id}/subscriptionGroups")["data"]
if not groups: print("  NO subscription groups. Create the group and both plans in App Store Connect.")
for g in groups:
    print(f"group: {g['attributes'].get('referenceName')}")
    glocs = call("GET", f"/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations", fatal=False) or {"data": []}
    print("  group display names:", [(l["attributes"]["locale"], l["attributes"].get("name"), l["attributes"].get("state")) for l in glocs["data"]] or "NONE (needed)")
    for s in call("GET", f"/subscriptionGroups/{g['id']}/subscriptions")["data"]:
        a = s["attributes"]
        print(f"\n  {a.get('productId')}  state={a.get('state')}  period={a.get('subscriptionPeriod')}  level={a.get('groupLevel')}")
        print(f"    review note: {'yes' if a.get('reviewNote') else 'none'}")
        locs = call("GET", f"/subscriptions/{s['id']}/subscriptionLocalizations", fatal=False) or {"data": []}
        print("    names:", [(l["attributes"]["locale"], l["attributes"].get("name"), l["attributes"].get("state")) for l in locs["data"]] or "NONE (needed)")
        offers = call("GET", f"/subscriptions/{s['id']}/introductoryOffers?limit=200", fatal=False) or {"data": []}
        modes = sorted({(o["attributes"].get("offerMode"), o["attributes"].get("duration")) for o in offers["data"]})
        print(f"    intro offers: {len(offers['data'])} territories {modes or ''}")
        prices = call("GET", f"/subscriptions/{s['id']}/prices?limit=200", fatal=False) or {"data": [], "meta": {}}
        total = (prices.get("meta") or {}).get("paging", {}).get("total", len(prices["data"]))
        print(f"    prices: {total} territories" + ("  <- NONE, needed" if not total else ""))
        avail = call("GET", f"/subscriptions/{s['id']}/subscriptionAvailability", fatal=False)
        if avail and avail.get("data"):
            print(f"    availability: new territories auto={avail['data']['attributes'].get('availableInNewTerritories')}")
        else:
            print("    availability: NOT SET (needed)")
        shot = call("GET", f"/subscriptions/{s['id']}/appStoreReviewScreenshot", fatal=False)
        print("    review screenshot:", "yes" if shot and shot.get("data") else "NONE (needed)")

print("\n== Version and App Review ==")
versions = call("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
for v in versions:
    print(f"version {v['attributes']['versionString']}: {v['attributes']['appStoreState']}")
version = next((v for v in versions if v["attributes"]["appStoreState"] in EDITABLE), None)
if not version:
    print("no editable version; notes not set"); sys.exit(0)
build = call("GET", f"/appStoreVersions/{version['id']}/build", fatal=False)
print("build attached:", build["data"]["attributes"]["version"] if build and build.get("data") else "none yet")

text = open("docs/APP_REVIEW.md", encoding="utf-8").read()
notes = re.search(r"<!-- notes:start -->\n(.*?)\n<!-- notes:end -->", text, re.S).group(1).strip()
print(f"notes: {len(notes)} characters (limit 4000)")
if len(notes) > 4000: sys.exit("notes too long")

detail = call("GET", f"/appStoreVersions/{version['id']}/appStoreReviewDetail", fatal=False)
if detail and detail.get("data"):
    d = detail["data"]; a = d["attributes"]
    print("contact:", "name set" if a.get("contactFirstName") else "NO NAME", "|", "email set" if a.get("contactEmail") else "NO EMAIL",
          "|", "phone set" if a.get("contactPhone") else "NO PHONE", "| demo account required:", a.get("demoAccountRequired"))
    call("PATCH", f"/appStoreReviewDetails/{d['id']}",
         json={"data": {"type": "appStoreReviewDetails", "id": d["id"], "attributes": {"notes": notes, "demoAccountRequired": False}}})
    print("review notes: updated")
else:
    call("POST", "/appStoreReviewDetails",
         json={"data": {"type": "appStoreReviewDetails", "attributes": {"notes": notes, "demoAccountRequired": False},
                        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
    print("review notes: created (contact name, email and phone still need filling in)")
