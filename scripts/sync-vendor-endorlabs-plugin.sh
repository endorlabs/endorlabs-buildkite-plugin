#!/usr/bin/env bash
# Copy endorlabs-buildkite-plugin runtime files into a consumer repo vendor tree.
#
# Usage (from consumer repo root, e.g. repro-sandbox):
#   ENDORLABS_PLUGIN_SRC=/path/to/endorlabs-buildkite-plugin \
#     ./scripts/sync-vendor-endorlabs-plugin.sh
#
# Or clone this repo and point ENDORLABS_PLUGIN_SRC at the checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ENDORLABS_PLUGIN_SRC:-$ROOT}"
DST="${ENDORLABS_PLUGIN_DST:-$ROOT/.buildkite/vendor/endorlabs-buildkite-plugin}"

if [[ ! -f "$SRC/plugin.yml" || ! -f "$SRC/hooks/post-command" ]]; then
  echo "sync-vendor: invalid plugin source (need plugin.yml and hooks/post-command): $SRC" >&2
  exit 1
fi

mkdir -p "$DST/hooks" "$DST/lib"

install -m 0755 "$SRC/hooks/post-command" "$DST/hooks/post-command"
cp "$SRC/plugin.yml" "$DST/plugin.yml"
cp "$SRC/lib/"*.bash "$DST/lib/"
if compgen -G "$SRC/lib/"*.jq >/dev/null; then
  cp "$SRC/lib/"*.jq "$DST/lib/"
fi

if command -v git >/dev/null 2>&1 && git -C "$SRC" rev-parse HEAD >/dev/null 2>&1; then
  commit="$(git -C "$SRC" rev-parse HEAD)"
  branch="$(git -C "$SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  remote="$(git -C "$SRC" config --get remote.origin.url 2>/dev/null || echo unknown)"
else
  commit="unknown"
  branch="unknown"
  remote="unknown"
fi

cat >"$DST/VENDOR_SOURCE.json" <<EOF
{
  "source_path": "$SRC",
  "remote": "$remote",
  "branch": "$branch",
  "commit": "$commit",
  "synced_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"
}
EOF

echo "sync-vendor: updated $DST from $SRC @ ${commit:0:12}"
