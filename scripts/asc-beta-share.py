"""Gives a TestFlight build to the external tester group (default "Manny") so testers always get the
newest one: waits until App Store Connect has processed the build, adds it to the group, and sends it
to Beta App Review (Apple reviews builds for external testers; after the first one it is usually
quick). Safe to run twice: steps already done are reported and skipped.

BUILD=<build number> picks a build (the TestFlight workflow passes its run number); without it, the
newest uploaded build. BETA_GROUP overrides the group name. Needs the ASC_* repo secrets; prints no
secret values. Runs from .github/workflows/ios-testflight.yml and asc-beta-share.yml."""
import os, sys, time
import jwt, requests

BUNDLE = "com.brandon132199.lockin"
API = "https://api.appstoreconnect.apple.com/v1"
GROUP = os.environ.get("BETA_GROUP") or "Manny"
BUILD = os.environ.get("BUILD", "").strip()
WAIT_MINUTES = int(os.environ.get("WAIT_MINUTES", "45"))

def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, fatal=True, **kw):
    r = requests.request(method, API + path, headers={"Authorization": "Bearer " + token()}, timeout=60, **kw)
    if r.status_code >= 400:
        print(f"{method} {path.split('?')[0]} -> {r.status_code}: {r.text[:600]}")
        if fatal: sys.exit(1)
        return None
    return r.json() if r.content else {}

app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]

groups = call("GET", f"/betaGroups?filter[app]={app_id}&filter[name]={GROUP}")["data"]
if not groups:
    sys.exit(f"No TestFlight group named {GROUP!r}")
for g in groups:
    a = g["attributes"]
    testers = call("GET", f"/betaGroups/{g['id']}/betaTesters?limit=50", fatal=False) or {"data": []}
    print(f"Group {a.get('name')!r}: internal={a.get('isInternalGroup')} "
          f"allBuilds={a.get('hasAccessToAllBuilds')} testers={len(testers['data'])}")
    # An internal group cannot be handed builds one by one; it gets every build once
    # "automatic distribution" (hasAccessToAllBuilds) is on.
    if a.get("isInternalGroup") and not a.get("hasAccessToAllBuilds"):
        if call("PATCH", f"/betaGroups/{g['id']}", fatal=False, json={"data": {
                "type": "betaGroups", "id": g["id"], "attributes": {"hasAccessToAllBuilds": True}}}) is not None:
            print("  Turned on automatic distribution: every new build reaches this group")
external_groups = [g for g in groups if not g["attributes"].get("isInternalGroup")]

# Wait for the build to show up and finish processing.
deadline = time.time() + WAIT_MINUTES * 60
build = None
while True:
    q = f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=1"
    if BUILD: q += f"&filter[version]={BUILD}"
    found = call("GET", q)["data"]
    if found:
        build = found[0]
        state = build["attributes"].get("processingState")
        print(f"Build {build['attributes']['version']}: {state}")
        if state == "VALID": break
        if state in ("FAILED", "INVALID"): sys.exit("App Store Connect could not process this build")
    else:
        print(f"Build {BUILD or '(newest)'} not in App Store Connect yet")
    if time.time() > deadline: sys.exit(f"Gave up after {WAIT_MINUTES} minutes")
    time.sleep(60)

bid, version = build["id"], build["attributes"]["version"]

# External groups get the build one at a time (an error here usually means it is already in).
for group in external_groups:
    if call("POST", f"/betaGroups/{group['id']}/relationships/builds", fatal=False,
            json={"data": [{"type": "builds", "id": bid}]}) is not None:
        print(f"Build {version} added to {GROUP} (external)")

# Testers outside the team only get builds Apple's Beta App Review has passed.
if external_groups:
    detail = call("GET", f"/builds/{bid}/buildBetaDetail")["data"]["attributes"]
    print(f"External testing state: {detail.get('externalBuildState')}")
    if detail.get("externalBuildState") in ("READY_FOR_BETA_SUBMISSION", "MISSING_EXPORT_COMPLIANCE", None):
        made = call("POST", "/betaAppReviewSubmissions", fatal=False, json={"data": {
            "type": "betaAppReviewSubmissions",
            "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
        if made is not None:
            print("Sent to Beta App Review")
    detail = call("GET", f"/builds/{bid}/buildBetaDetail")["data"]["attributes"]
    print(f"External testing state now: {detail.get('externalBuildState')}")
