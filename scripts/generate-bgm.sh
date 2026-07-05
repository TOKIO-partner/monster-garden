#!/usr/bin/env bash
#
# generate-bgm.sh — sunoapi.org で BGM 4曲を一括生成し assets/audio/bgm/ に保存する。
#
# 非同期フロー（nowordsescape 確立パターン）:
#   submit: 全曲 generate(POST) を一括投入 → taskId を .tasks/<slot>.taskid に保存
#   collect: record-info をポーリング → audioUrl DL（同期ポーリング6分TOを回避）
#
# 鍵: Storix ルートの ai.env（SUNO_API_KEY / SUNO_API_BASE）を読む。生成は課金対象。
# instrumental=true 固定。
#
# 使い方:
#   scripts/generate-bgm.sh submit    # 4曲一括投入
#   scripts/generate-bgm.sh collect   # taskId から回収（何度でも再実行可）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/assets/audio/bgm"
TASK_DIR="$OUT_DIR/.tasks"
MODEL="V4_5"

# 鍵の読み込み: .env → Storix/ai.env → Tokio-Agent/ai.env の順
for ENV_FILE in "$ROOT/.env" "$ROOT/../../../ai.env" "$ROOT/../../../../Tokio-Agent/ai.env"; do
	if [ -f "$ENV_FILE" ]; then
		set -a; . "$ENV_FILE"; set +a
	fi
done
BASE="${SUNO_API_BASE:-https://api.sunoapi.org}"
: "${SUNO_API_KEY:?SUNO_API_KEY が未設定（Storix/ai.env を確認）}"

mkdir -p "$OUT_DIR" "$TASK_DIR"

# slot|file|prompt（instrumental 前提の英語ディスクリプション・全年齢向け）
ENTRIES=(
	"meadow|meadow.mp3|Cheerful pastoral instrumental for a kids monster collecting game meadow, acoustic guitar, light flute melody, warm strings, gentle bouncy rhythm, sunny and friendly, no vocals, C major, 100 bpm"
	"volcano|volcano.mp3|Adventurous energetic instrumental for a volcano zone in a kids game, taiko-style drums, bold brass hits, exciting but not scary, playful danger, no vocals, D minor, 112 bpm"
	"lakeside|lakeside.mp3|Calm mysterious instrumental for a misty lakeside at twilight in a kids game, soft marimba, water-like harp arpeggios, airy pads, gentle wonder, no vocals, A minor, 84 bpm"
	"island|island.mp3|Cozy warm instrumental for a home garden island in a kids game, ukulele, music box sparkle, soft whistling melody, relaxing and happy, no vocals, F major, 92 bpm"
)

MODE="${1:-}"
case "$MODE" in
	submit)
		for entry in "${ENTRIES[@]}"; do
			slot="${entry%%|*}"
			rest="${entry#*|}"
			file="${rest%%|*}"
			prompt="${rest#*|}"

			if [ -s "$OUT_DIR/$file" ]; then
				echo "skip (exists): $file"
				continue
			fi
			if [ -s "$TASK_DIR/$slot.taskid" ]; then
				echo "skip (submitted): $slot ($(cat "$TASK_DIR/$slot.taskid"))"
				continue
			fi

			echo "submit: $slot"
			response=$(curl -sS -X POST "$BASE/api/v1/generate" \
				-H "Authorization: Bearer $SUNO_API_KEY" \
				-H "Content-Type: application/json" \
				-d "{\"prompt\":$(printf '%s' "$prompt" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))'),\"customMode\":false,\"instrumental\":true,\"model\":\"$MODEL\",\"callBackUrl\":\"https://example.com/callback\"}")
			taskId=$(printf '%s' "$response" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("data",{}).get("taskId",""))')
			if [ -z "$taskId" ]; then
				echo "  ERROR: $response" >&2
				continue
			fi
			printf '%s' "$taskId" > "$TASK_DIR/$slot.taskid"
			echo "  taskId=$taskId"
		done
		echo "done. 数分後に: scripts/generate-bgm.sh collect"
		;;

	collect)
		pending=0
		for entry in "${ENTRIES[@]}"; do
			slot="${entry%%|*}"
			rest="${entry#*|}"
			file="${rest%%|*}"

			if [ -s "$OUT_DIR/$file" ]; then
				echo "ok (exists): $file"
				continue
			fi
			if [ ! -s "$TASK_DIR/$slot.taskid" ]; then
				echo "skip (not submitted): $slot"
				continue
			fi
			taskId=$(cat "$TASK_DIR/$slot.taskid")

			info=$(curl -sS "$BASE/api/v1/generate/record-info?taskId=$taskId" \
				-H "Authorization: Bearer $SUNO_API_KEY")
			status=$(printf '%s' "$info" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("data",{}).get("status",""))' 2>/dev/null || echo "PARSE_ERROR")
			audioUrl=$(printf '%s' "$info" | python3 -c '
import json, sys
d = json.load(sys.stdin)
items = (d.get("data", {}).get("response", {}) or {}).get("sunoData", []) or []
print(items[0].get("audioUrl", "") if items else "")
' 2>/dev/null || echo "")

			if [ -n "$audioUrl" ]; then
				echo "download: $slot ← $audioUrl"
				curl -sSL -o "$OUT_DIR/$file" "$audioUrl"
				echo "  saved: $OUT_DIR/$file"
			else
				echo "pending: $slot (status=$status)"
				pending=$((pending + 1))
			fi
		done
		if [ "$pending" -gt 0 ]; then
			echo "$pending 曲が生成中。数分後に再実行。"
			exit 1
		fi
		echo "all collected."
		;;

	*)
		echo "usage: $0 submit|collect" >&2
		exit 2
		;;
esac
