#!/usr/bin/env bash
# Checks the App Store Connect API key without printing any secret value.
# Expects ASC_KEY_ID, ASC_ISSUER_ID and the key file path as $1.
set -u
K="$1"
echo "key id length: ${#ASC_KEY_ID} (expect 10)"
if [[ "$ASC_ISSUER_ID" =~ ^[0-9a-fA-F-]{36}$ ]]; then echo "issuer looks like a UUID: yes"; else echo "issuer looks like a UUID: NO (length ${#ASC_ISSUER_ID})"; fi
echo "p8 first line: $(head -1 "$K")"
echo "p8 last line: $(tail -1 "$K")"
echo "p8 line count: $(wc -l < "$K" | tr -d ' ') (expect 4 or 5)"

b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
NOW=$(date +%s)
H=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64)
P=$(printf '{"iss":"%s","iat":%s,"exp":%s,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$NOW" "$((NOW + 600))" | b64)
SIG=$(printf '%s.%s' "$H" "$P" | openssl dgst -sha256 -sign "$K" | python3 -c '
import sys
d = sys.stdin.buffer.read()
i = 3 if d[1] & 0x80 == 0 else 4
rl = d[i]; r = d[i + 1:i + 1 + rl]
j = i + 1 + rl + 1; sl = d[j - 1 + 0] if False else d[j]; s = d[j + 1:j + 1 + sl]
r = r.lstrip(bytes([0])).rjust(32, bytes([0]))
s = s.lstrip(bytes([0])).rjust(32, bytes([0]))
sys.stdout.buffer.write(r + s)
' | b64)
OUT="${RUNNER_TEMP:-/tmp}/asc.json"
CODE=$(curl -s -o "$OUT" -w '%{http_code}' -H "Authorization: Bearer $H.$P.$SIG" https://api.appstoreconnect.apple.com/v1/apps)
echo "App Store Connect API status: $CODE (200 = key works, 401 = Apple rejects it)"
head -c 300 "$OUT" | tr -d '\n' | sed -E 's/"id" *: *"[^"]*"/"id":"..."/g'
echo
