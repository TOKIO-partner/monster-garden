#!/usr/bin/env bash
#
# deploy-place.sh — rojo build → Roblox Open Cloud で Place を publish する。
#
# 前提（jurassic/deep-sea と同パターン）:
#   - Universe/Place は Storix_Dev（UserId 10710842340）所有で作成済みであること
#     （初回のみ Studio で「Publish to Roblox As...」が必要。Open Cloud に Universe 作成 API は無い）
#   - .env に以下を設定:
#       RBXCLOUD_API_KEY   （universe-places:write 権限）
#       UNIVERSE_ID
#       PLACE_ID
#
# 使い方:
#   scripts/deploy-place.sh            # published として公開デプロイ
#   scripts/deploy-place.sh --saved    # saved（下書き保存のみ）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/game.rbxl"

if [ -f "$ROOT/.env" ]; then
	set -a; . "$ROOT/.env"; set +a
fi
: "${RBXCLOUD_API_KEY:?RBXCLOUD_API_KEY 未設定}"
: "${UNIVERSE_ID:?UNIVERSE_ID 未設定（初回は Studio で Publish して ID を .env に追記）}"
: "${PLACE_ID:?PLACE_ID 未設定（初回は Studio で Publish して ID を .env に追記）}"

VERSION_TYPE="published"
[ "${1:-}" = "--saved" ] && VERSION_TYPE="saved"

export PATH="$HOME/.aftman/bin:$PATH"

echo "build: rojo build → game.rbxl"
rojo build "$ROOT/default.project.json" -o "$BUILD"

echo "publish: universe=$UNIVERSE_ID place=$PLACE_ID ($VERSION_TYPE)"
rbxcloud experience publish \
	--api-key "$RBXCLOUD_API_KEY" \
	--universe-id "$UNIVERSE_ID" \
	--place-id "$PLACE_ID" \
	--version-type "$VERSION_TYPE" \
	--filename "$BUILD"

echo "done: https://www.roblox.com/games/$PLACE_ID"
