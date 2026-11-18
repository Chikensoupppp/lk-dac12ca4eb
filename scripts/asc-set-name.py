"""Sets the App Store name (and the subtitle, only if it still says Nogbox) on the editable App Info,
US English, through the App Store Connect API. Values come from docs/BRANDING.md.
Runs in .github/workflows/asc-name.yml with the ASC_* repo secrets. Prints no secret values."""
import os, sys, time
import jwt, requests

BUNDLE = "com.brandon132199.lockin"
NAME = "SwipeLater: Focus App Blocker"
SUBTITLE = "Block Apps. Lock In."
API = "https://api.appstoreconnect.apple.com/v1"

def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, **kw):
    r = requests.request(method, API + path, headers={"Authorization": "Bearer " + token()}, timeout=60, **kw)
    if r.status_code >= 400:
        print(f"{method} {path.split('?')[0]} -> {r.status_code}: {r.text[:800]}")
        sys.exit(1)
    return r.json() if r.content else {}

assert len(NAME) <= 30 and len(SUBTITLE) <= 30
app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
infos = call("GET", f"/apps/{app_id}/appInfos")["data"]
for i in infos:
    print("app info state:", i["attributes"].get("appStoreState") or i["attributes"].get("state"))
info = next((i for i in infos if (i["attributes"].get("appStoreState") or i["attributes"].get("state")) not in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION")), infos[0])
done = False
for loc in call("GET", f"/appInfos/{info['id']}/appInfoLocalizations")["data"]:
    a = loc["attributes"]
    print("before:", a["locale"], "| name:", a.get("name"), "| subtitle:", a.get("subtitle"))
    if a["locale"] != "en-US":
        continue
    attrs = {"name": NAME}
    if not a.get("subtitle") or "nogbox" in a["subtitle"].lower():
        attrs["subtitle"] = SUBTITLE
    out = call("PATCH", f"/appInfoLocalizations/{loc['id']}", json={"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": attrs}})
    b = out["data"]["attributes"]
    print("after: ", b["locale"], "| name:", b.get("name"), "| subtitle:", b.get("subtitle"))
    done = True
if not done:
    print("No en-US App Info localization found."); sys.exit(1)
