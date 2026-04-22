#!/usr/bin/env bash
set -euxo pipefail

# Usage:
# ./scripts/release.sh <version> <path-to-private-key> <artifacts-dir>
#
# Example:
# ./scripts/release.sh 0.0.1 ~/secure/nemoclaw-sk.pem ./build/v0.0.1

VERSION="$1"
SK="$2"
ARTIFACTS="$3"
REPO="harshit664/nemoclaw-releases"

if [[ -z "${VERSION:-}" || -z "${SK:-}" || -z "${ARTIFACTS:-}" ]]; then
  echo "Usage: $0 <version> <private-key> <artifacts-dir>"
  exit 1
fi

if [[ ! -f "$SK" ]]; then
  echo "Private key not found: $SK"
  exit 1
fi

if [[ ! -d "$ARTIFACTS" ]]; then
  echo "Artifacts directory not found: $ARTIFACTS"
  exit 1
fi

gh auth status >/dev/null

MANIFEST="$ARTIFACTS/manifest.json"
BASE_URL="https://github.com/$REPO/releases/download/v$VERSION"

echo "Generating manifest.json"

cat > "$MANIFEST" <<EOF
{
  "version": "$VERSION",
  "releasedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "ollamaModel": "qwen2.5:3b",
  "components": [
EOF

FIRST=1
for f in "$ARTIFACTS"/*; do
  name="$(basename "$f")"
  [[ "$name" == "manifest.json" || "$name" == "manifest.json.sig" ]] && continue

  sha="$(shasum -a 256 "$f" | awk '{print $1}')"
  size="$(stat -f%z "$f")"

  [[ $FIRST -eq 0 ]] && echo "," >> "$MANIFEST"
  FIRST=0

  cat >> "$MANIFEST" <<EOF
    {
      "name": "$name",
      "sha256": "$sha",
      "size": $size,
      "url": "$BASE_URL/$name"
    }
EOF
done

cat >> "$MANIFEST" <<EOF
  ]
}
EOF

echo "Signing manifest.json"
openssl pkeyutl -sign -inkey "$SK" -rawin -in "$MANIFEST" | base64 > "$MANIFEST.sig"

echo "Publishing GitHub release v$VERSION"
gh release create "v$VERSION" \
  --repo "$REPO" \
  --title "v$VERSION" \
  --notes "Release v$VERSION" \
  "$MANIFEST" "$MANIFEST.sig" "$ARTIFACTS"/*

echo "Release v$VERSION published successfully"
