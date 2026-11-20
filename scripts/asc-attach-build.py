"""Attaches the newest processed (VALID) build to App Store version 1.0. Does NOT submit for review
and does not release anything: the version stays "Prepare for Submission".
Runs in .github/workflows/asc-attach-build.yml with the ASC_* repo secrets. Prints no secret values.
WAIT_MINUTES (default 45): how long to wait for a just-uploaded build to finish processing.
MIN_BUILD: the lowest build number to accept (so an older build is never attached by mistake)."""
import os, sys, time
import jwt, requests

BUNDLE = "com.brandon132199.lockin"
API = "https://api.appstoreconnect.apple.com/v1"
VERSION = os.environ.get("VERSION", "1.0")
MIN_BUILD = int(os.environ.get("MIN_BUILD", "0") or 0)
WAIT = int(os.environ.get("WAIT_MINUTES", "45"))

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
versions = call("GET", f"/apps/{app_id}/appStoreVersions?filter[versionString]={VERSION}&filter[platform]=IOS")["data"]
if not versions: sys.exit(f"no App Store version {VERSION}")
version = versions[0]
print(f"version {VERSION}: {version['attributes']['appStoreState']}")

deadline = time.time() + WAIT * 60
while True:
    builds = call("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5")["data"]
    newest = max(builds, key=lambda b: int(b["attributes"]["version"])) if builds else None
    if newest and int(newest["attributes"]["version"]) >= MIN_BUILD:
        state = newest["attributes"]["processingState"]
        print(f"newest build {newest['attributes']['version']}: {state}")
        if state == "VALID": break
        if state in ("FAILED", "INVALID"): sys.exit("newest build failed processing")
    else:
        print(f"no build >= {MIN_BUILD} yet")
    if time.time() > deadline: sys.exit("timed out waiting for the build")
    time.sleep(60)

call("PATCH", f"/appStoreVersions/{version['id']}/relationships/build",
     json={"data": {"type": "builds", "id": newest["id"]}})
attached = call("GET", f"/appStoreVersions/{version['id']}/build")["data"]
print(f"attached build {attached['attributes']['version']} to version {VERSION} (not submitted)")
