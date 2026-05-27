#!/usr/bin/env bash
# Clone pinned juice-shop for hosted validation smoke (keeps pipeline.yml interpolation-safe).
set -euo pipefail

: "${JUICE_SHOP_DIR:?JUICE_SHOP_DIR is required}"
: "${JUICE_SHOP_REF:?JUICE_SHOP_REF is required}"

rm -rf "${JUICE_SHOP_DIR}"
mkdir -p "$(dirname "${JUICE_SHOP_DIR}")" "$(dirname "${BUILDKITE_BUILD_CHECKOUT_PATH:-.}")/.local/scans"

git clone --depth 1 --branch v20.0.0 https://github.com/juice-shop/juice-shop.git "${JUICE_SHOP_DIR}"
git -C "${JUICE_SHOP_DIR}" checkout "${JUICE_SHOP_REF}"
echo "juice-shop at $(git -C "${JUICE_SHOP_DIR}" rev-parse HEAD)"
