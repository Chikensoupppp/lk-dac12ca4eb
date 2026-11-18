"""Prints the App Store ID and public link for the app. Read-only. Runs in .github/workflows/asc-app-id.yml."""
import os, sys, time
import jwt, requests
BUNDLE = "com.brandon132199.lockin"
now = int(time.time())
t = jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
               os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})
r = requests.get(f"https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]={BUNDLE}", headers={"Authorization": "Bearer " + t}, timeout=60)
if r.status_code >= 400: print(r.status_code, r.text[:500]); sys.exit(1)
d = r.json()["data"][0]
print("APP_ID:", d["id"]); print("LINK: https://apps.apple.com/app/id" + d["id"])
