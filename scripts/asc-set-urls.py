"""Sets the privacy policy URL (App Info) and, only where empty, the support and marketing URLs
(the editable version), US English, through the App Store Connect API. Prints before and after.
Runs in .github/workflows/asc-urls.yml with the ASC_* repo secrets. Prints no secret values."""
import os, sys, time
import jwt, requests

BUNDLE = "com.brandon132199.lockin"
PRIVACY = "https://swipelater.app/privacy/"
SITE = "https://swipelater.app/"
API = "https://api.appstoreconnect.apple.com/v1"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}

def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, **kw):
    r = requests.request(method, API + path, headers={"Authorization": "Bearer " + token()}, timeout=60, **kw)
    if r.status_code >= 400:
        print(f"{method} {path.split('?')[0]} -> {r.status_code}: {r.text[:800]}"); sys.exit(1)
    return r.json() if r.content else {}

app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
info = next(i for i in call("GET", f"/apps/{app_id}/appInfos")["data"]
            if (i["attributes"].get("appStoreState") or i["attributes"].get("state")) not in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION"))
for loc in call("GET", f"/appInfos/{info['id']}/appInfoLocalizations")["data"]:
    if loc["attributes"]["locale"] != "en-US": continue
    print("privacy before:", loc["attributes"].get("privacyPolicyUrl"))
    out = call("PATCH", f"/appInfoLocalizations/{loc['id']}", json={"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": {"privacyPolicyUrl": PRIVACY}}})
    print("privacy after: ", out["data"]["attributes"].get("privacyPolicyUrl"))

version = next(v for v in call("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
               if v["attributes"]["appStoreState"] in EDITABLE)
for loc in call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]:
    a = loc["attributes"]
    if a["locale"] != "en-US": continue
    print("support before:", a.get("supportUrl"), "| marketing before:", a.get("marketingUrl"))
    attrs = {k: SITE for k in ("supportUrl", "marketingUrl") if not a.get(k)}
    if attrs:
        b = call("PATCH", f"/appStoreVersionLocalizations/{loc['id']}", json={"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": attrs}})["data"]["attributes"]
        print("support after: ", b.get("supportUrl"), "| marketing after:", b.get("marketingUrl"))
    else:
        print("support and marketing already set; left as they are")
