#!/usr/bin/env bash
# Upload the staged ISO and its sha256 checksum to the distro-releases
# bucket on Hetzner Object Storage and emit the public download URLs.
#
# Usage: upload-artifacts.sh <iso-path> <sha256-path>
#
# Requires: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY in env.
# `aws` is provided via `nix shell nixpkgs#awscli2`, so the only host
# dependency is a working nix.
#
# When run inside GitHub Actions, writes `iso_url=<url>` and
# `sha256_url=<url>` to $GITHUB_OUTPUT.
set -euo pipefail

iso=${1:?iso path required}
sha=${2:?sha256 path required}

: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID required}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY required}"

endpoint=https://hel1.your-objectstorage.com
bucket=distro-releases
region=hel1

iso_key=$(basename "$iso")
sha_key=$(basename "$sha")

nix shell nixpkgs#awscli2 --command aws \
  --endpoint-url "$endpoint" --region "$region" \
  s3 cp "$iso" "s3://${bucket}/${iso_key}" --no-progress

nix shell nixpkgs#awscli2 --command aws \
  --endpoint-url "$endpoint" --region "$region" \
  s3 cp "$sha" "s3://${bucket}/${sha_key}" --no-progress

iso_url="${endpoint}/${bucket}/${iso_key}"
sha_url="${endpoint}/${bucket}/${sha_key}"

echo "$iso_url"
echo "$sha_url"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "iso_url=${iso_url}"
    echo "sha256_url=${sha_url}"
  } >>"$GITHUB_OUTPUT"
fi
