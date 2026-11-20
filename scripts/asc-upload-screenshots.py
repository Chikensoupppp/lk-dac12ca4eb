"""Uploads the App Store screenshots in docs/aso/screenshots/6.9/ (1320x2868, sorted by name) to the
iPhone 6.9" slot of the editable App Store version, for every localization, replacing what is there.

Runs in .github/workflows/asc-screenshots.yml with ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 from the
repo secrets. Prints no secret values. Uses the App Store Connect API: appScreenshotSets and the
appScreenshots reserve -> upload parts -> commit flow.
"""
import glob, hashlib, os, sys, time
import jwt, requests

BUNDLE = "com.brandon132199.lockin"
DISPLAY = "APP_IPHONE_67"  # the 6.9"/6.7" slot; takes 1320x2868
API = "https://api.appstoreconnect.apple.com/v1"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}

def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

S = requests.Session()
def call(method, path, **kw):
    S.headers["Authorization"] = "Bearer " + token()
    r = S.request(method, path if path.startswith("http") else API + path, timeout=60, **kw)
    if r.status_code >= 400:
        print(f"{method} {path.split('?')[0]} -> {r.status_code}: {r.text[:600]}")
        sys.exit(1)
    return r.json() if r.content else {}

files = sorted(glob.glob("docs/aso/screenshots/6.9/*.png"))
# Apple takes 1 to 10 screenshots per device size.
assert 1 <= len(files) <= 10, files

app = call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"]
assert app, "no app with that bundle ID"
app_id = app[0]["id"]
print("app:", app[0]["attributes"]["name"])

versions = call("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
for v in versions:
    print("version", v["attributes"]["versionString"], v["attributes"]["appStoreState"])
editable = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE]
if not editable:
    print("No App Store version can take new screenshots right now.")
    sys.exit(1)
version = editable[0]
print("using version", version["attributes"]["versionString"])

for loc in call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]:
    locale = loc["attributes"]["locale"]
    sets = call("GET", f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?filter[screenshotDisplayType]={DISPLAY}")["data"]
    if sets:
        set_id = sets[0]["id"]
        for old in call("GET", f"/appScreenshotSets/{set_id}/appScreenshots?limit=50")["data"]:
            call("DELETE", f"/appScreenshots/{old['id']}")
            print(locale, "removed old", old["attributes"].get("fileName"))
    else:
        set_id = call("POST", "/appScreenshotSets", json={"data": {"type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": DISPLAY},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]["id"]
        print(locale, "made a new screenshot set")

    ids = []
    for path in files:
        data = open(path, "rb").read()
        name = os.path.basename(path)
        shot = call("POST", "/appScreenshots", json={"data": {"type": "appScreenshots",
            "attributes": {"fileName": name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            part = data[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            r = requests.request(op["method"], op["url"], data=part, headers=headers, timeout=120)
            if r.status_code >= 400:
                print(name, "part upload failed", r.status_code); sys.exit(1)
        call("PATCH", f"/appScreenshots/{shot['id']}", json={"data": {"type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        ids.append((shot["id"], name))
        print(locale, "uploaded", name)

    # Apple processes each picture; wait until every one is done or failed.
    for sid, name in ids:
        for _ in range(40):
            state = call("GET", f"/appScreenshots/{sid}")["data"]["attributes"].get("assetDeliveryState") or {}
            if state.get("state") in ("COMPLETE", "FAILED"):
                break
            time.sleep(5)
        print(locale, name, "->", state.get("state"), state.get("errors") or "")
        if state.get("state") == "FAILED":
            sys.exit(1)

    call("PATCH", f"/appScreenshotSets/{set_id}/relationships/appScreenshots",
         json={"data": [{"type": "appScreenshots", "id": sid} for sid, _ in ids]})
    print(locale, f"order set: 1 to {len(ids)}")
print("done")
