#!/usr/bin/env bash
#
# upload-audio.sh — 音源を Roblox Open Cloud へアップロードし、Audio.lua に assetId を自動反映する。
#
# ⚠️ 実行前提: .env に正しい所有者情報を設定すること（2026-07-05 時点で未確定・保留中）。
#   RBXCLOUD_API_KEY     Open Cloud API キー（assets:read,write スコープ）
#   ROBLOX_CREATOR_ID    作成者 ID（user なら UserId、group なら GroupId）
#   ROBLOX_CREATOR_TYPE  user|group
#   ※ monster-garden の Roblox ゲーム本体と同じ所有者にすること。
#     所有者が違うと音声アセットがゲーム内で再生できない（音声はプライバシー制限あり）。
#
# 動作（nowordsescape 確立パターン・冪等）:
#   1. assets/audio/{bgm,se}/*.mp3 を rbxcloud assets create でアップロード
#   2. operation をポーリングして assetId を取得（モデレーションTO時は再実行で回収）
#   3. src/shared/Config/Audio.lua の該当キーを Python セクション置換で更新（sed 禁止: 同名キー誤爆）
#
# 使い方:
#   scripts/upload-audio.sh --dry-run
#   scripts/upload-audio.sh
#   scripts/upload-audio.sh --slot meadow
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIO_LUA="$ROOT/src/shared/Config/Audio.lua"

if [ -f "$ROOT/.env" ]; then
	set -a; . "$ROOT/.env"; set +a
fi
: "${RBXCLOUD_API_KEY:?RBXCLOUD_API_KEY 未設定（.env を作成。所有者確定待ちなら実行しない）}"
: "${ROBLOX_CREATOR_ID:?ROBLOX_CREATOR_ID 未設定}"
CREATOR_TYPE="${ROBLOX_CREATOR_TYPE:-group}"

DRY_RUN=0
ONLY_SLOT=""
while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--slot) ONLY_SLOT="${2:-}"; shift ;;
		-h|--help) sed -n '2,24p' "$0"; exit 0 ;;
		*) echo "unknown arg: $1" >&2; exit 2 ;;
	esac
	shift
done

# category|slot|file（slot は Audio.lua のキーと 1:1）
ENTRIES=(
	"bgm|meadow|audio/bgm/meadow.mp3"
	"bgm|volcano|audio/bgm/volcano.mp3"
	"bgm|lakeside|audio/bgm/lakeside.mp3"
	"bgm|island|audio/bgm/island.mp3"
	"se|captureSuccess|audio/se/capture_success.mp3"
	"se|captureFail|audio/se/capture_fail.mp3"
	"se|hatch|audio/se/hatch.mp3"
	"se|plant|audio/se/plant.mp3"
	"se|water|audio/se/water.mp3"
	"se|warp|audio/se/warp.mp3"
	"se|uiClick|audio/se/ui_click.mp3"
	"se|rareSeed|audio/se/rare_seed.mp3"
)

#--- Audio.lua の現在値を取得（0 なら未反映）
current_id() {
	local category="$1" slot="$2"
	python3 - "$AUDIO_LUA" "$category" "$slot" <<'PYEOF'
import re, sys
path, category, slot = sys.argv[1:4]
text = open(path).read()
section = re.search(rf"{category} = \{{(.*?)\n\t\}}", text, re.S)
if not section:
    print(0)
    sys.exit()
match = re.search(rf"\b{slot} = (\d+)", section.group(1))
print(match.group(1) if match else 0)
PYEOF
}

#--- Audio.lua の該当キーを更新（カテゴリセクション内のみ置換・sed 誤爆回避）
update_audio_lua() {
	local category="$1" slot="$2" asset_id="$3"
	python3 - "$AUDIO_LUA" "$category" "$slot" "$asset_id" <<'PYEOF'
import re, sys
path, category, slot, asset_id = sys.argv[1:5]
text = open(path).read()
pattern = rf"({category} = \{{.*?\b{slot} = )\d+"
updated, count = re.subn(pattern, rf"\g<1>{asset_id}", text, count=1, flags=re.S)
if count != 1:
    sys.exit(f"ERROR: {category}.{slot} を更新できなかった")
open(path, "w").write(updated)
print(f"  Audio.lua: {category}.{slot} = {asset_id}")
PYEOF
}

for entry in "${ENTRIES[@]}"; do
	category="${entry%%|*}"
	rest="${entry#*|}"
	slot="${rest%%|*}"
	file="$ROOT/assets/${rest#*|}"

	if [ -n "$ONLY_SLOT" ] && [ "$slot" != "$ONLY_SLOT" ]; then
		continue
	fi
	if [ ! -s "$file" ]; then
		echo "skip (no file): $slot"
		continue
	fi
	existing=$(current_id "$category" "$slot")
	if [ "$existing" != "0" ]; then
		echo "skip (uploaded): $slot → $existing"
		continue
	fi
	if [ "$DRY_RUN" -eq 1 ]; then
		echo "would upload: $slot ($file)"
		continue
	fi

	echo "upload: $slot"
	output=$(rbxcloud assets create \
		--api-key "$RBXCLOUD_API_KEY" \
		--asset-type audio-mp3 \
		--creator-id "$ROBLOX_CREATOR_ID" \
		--creator-type "$CREATOR_TYPE" \
		--display-name "MG_${category}_${slot}" \
		--description "Monster Garden ${category} ${slot}" \
		--filepath "$file" 2>&1) || {
		echo "  ERROR: $output" >&2
		continue
	}
	asset_id=$(printf '%s' "$output" | grep -oE 'assetId: ?"?[0-9]+' | grep -oE '[0-9]+' | head -1 || true)
	if [ -z "$asset_id" ]; then
		# モデレーション待ちで operationId のみの場合: id を控えて再実行で回収
		echo "  pending (moderation?): $output"
		continue
	fi
	update_audio_lua "$category" "$slot" "$asset_id"
done
echo "done."
