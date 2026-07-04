#!/usr/bin/env bash
#
# generate-se.sh — ElevenLabs sound-generation API で SE 8音を生成し assets/audio/se/ に保存する。
#
# 鍵: Storix ルートの ai.env（ELEVENLABS_API_KEY）を読む。生成は課金対象。
# まず --capability-test で 1 音だけ疎通確認すること（nowordsescape 確立パターン）。
#
# 使い方:
#   scripts/generate-se.sh --capability-test   # uiClick だけ生成
#   scripts/generate-se.sh                     # 全 8 音（既存はスキップ）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/assets/audio/se"
API="https://api.elevenlabs.io/v1/sound-generation"

for ENV_FILE in "$ROOT/.env" "$ROOT/../../../ai.env" "$ROOT/../../../../Tokio-Agent/ai.env"; do
	if [ -f "$ENV_FILE" ]; then
		set -a; . "$ENV_FILE"; set +a
	fi
done
: "${ELEVENLABS_API_KEY:?ELEVENLABS_API_KEY が未設定（Storix/ai.env を確認）}"

mkdir -p "$OUT_DIR"

CAP_TEST=0
[ "${1:-}" = "--capability-test" ] && CAP_TEST=1

# slot|file|seconds|prompt
ENTRIES=(
	"uiClick|ui_click.mp3|1.0|Soft friendly UI click, short pop, clean, game menu tap"
	"captureSuccess|capture_success.mp3|2.0|Cheerful success jingle, ascending chime sparkle, monster caught celebration, bright and happy, kids game"
	"captureFail|capture_fail.mp3|1.5|Comical descending whiff, quick slide whistle down, monster escaped, playful failure, not scary"
	"hatch|hatch.mp3|2.5|Egg cracking open followed by magical sparkle burst, cute creature hatching, wonder and delight"
	"plant|plant.mp3|1.2|Soft soil digging and seed drop pop, gardening, earthy thump, satisfying"
	"water|water.mp3|1.5|Gentle watering can pouring water on soil, light splashing drops, garden care"
	"warp|warp.mp3|1.5|Magical teleport whoosh, shimmering portal swirl, quick rising sweep, fantasy game"
	"rareSeed|rare_seed.mp3|2.0|Sparkling treasure pickup, glittering rare item chime, magical discovery, exciting reward"
)

for entry in "${ENTRIES[@]}"; do
	slot="${entry%%|*}"
	rest="${entry#*|}"
	file="${rest%%|*}"
	rest="${rest#*|}"
	seconds="${rest%%|*}"
	prompt="${rest#*|}"

	if [ "$CAP_TEST" -eq 1 ] && [ "$slot" != "uiClick" ]; then
		continue
	fi
	if [ -s "$OUT_DIR/$file" ]; then
		echo "skip (exists): $file"
		continue
	fi

	echo "generate: $slot (${seconds}s)"
	http_code=$(curl -sS -o "$OUT_DIR/$file" -w "%{http_code}" -X POST "$API" \
		-H "xi-api-key: $ELEVENLABS_API_KEY" \
		-H "Content-Type: application/json" \
		-d "{\"text\":$(printf '%s' "$prompt" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))'),\"duration_seconds\":$seconds,\"prompt_influence\":0.6}")
	if [ "$http_code" != "200" ]; then
		echo "  ERROR http=$http_code: $(head -c 300 "$OUT_DIR/$file")" >&2
		rm -f "$OUT_DIR/$file"
		continue
	fi
	echo "  saved: $OUT_DIR/$file"
done
echo "done."
