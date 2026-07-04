# ASSET_LOG — Monster Garden アセット生成記録

生成過程の in-repo ログ（nowordsescape 方式）。生成コマンド・プロンプト・結果を記録する。

## 2026-07-05 オープンワールド化 α アセット

### BGM（Suno V4_5 / sunoapi.org）

一括投入→回収方式（`scripts/generate-bgm.sh submit` → `collect`）。instrumental固定。

| slot | ファイル | taskId | 用途 |
|------|---------|--------|------|
| meadow | audio/bgm/meadow.mp3 | 2c446e0588a7c5bf32fce761ccead1ad | そよかぜ草原（C major 100bpm パストラル） |
| volcano | audio/bgm/volcano.mp3 | be18da2cc32a3750b42abb658b8a7743 | ごうか火山（D minor 112bpm 太鼓+ブラス） |
| lakeside | audio/bgm/lakeside.mp3 | 978bde20c0896674171bd57218ed0a80 | みずうみのほとり（A minor 84bpm マリンバ+ハープ） |
| island | audio/bgm/island.mp3 | 859419c6a2ab73b60c72bebe883f75b7 | 庭園島ホーム（F major 92bpm ウクレレ+オルゴール） |

### SE（ElevenLabs sound-generation）

`scripts/generate-se.sh`（疎通テスト: uiClick → 全8音）。

| slot | ファイル | 秒数 | 用途 |
|------|---------|------|------|
| uiClick | audio/se/ui_click.mp3 | 1.0 | UI操作 |
| captureSuccess | audio/se/capture_success.mp3 | 2.0 | 捕獲成功ジングル |
| captureFail | audio/se/capture_fail.mp3 | 1.5 | 捕獲失敗（コミカル下降） |
| hatch | audio/se/hatch.mp3 | 2.5 | 孵化（卵割れ+キラキラ） |
| plant | audio/se/plant.mp3 | 1.2 | 種植え |
| water | audio/se/water.mp3 | 1.5 | 水やり |
| warp | audio/se/warp.mp3 | 1.5 | ワープ |
| rareSeed | audio/se/rare_seed.mp3 | 2.0 | レアシード採取 |

### 3Dモデル（既存・2026-06-09 生成）

`assets/models/*.glb` — 全20モンスター + 庭園プロップ8種（Blender産・オープンワールド化以前に生成済み）。

### Roblox アップロード状況

⚠️ **保留中（2026-07-05）**: monster-garden の Roblox ゲーム所有者が group 47115687（nowordsescape と同じ）**ではない**ことが判明。
正しい所有者（user/group + ID + APIキー）確定後に以下を実行する:

```bash
# .env を作成（.env.example 参照）して:
scripts/upload-audio.sh --dry-run
scripts/upload-audio.sh          # → Audio.lua に assetId 自動反映
```

- 音声アセットは**ゲーム本体と同一所有者でないと再生不可**（Roblox音声プライバシー制限）
- モデル（.glb）は Open Cloud が fbx/obj のみ対応のため、Blender で FBX 変換してからアップする（未実施）
- モデレーションタイムアウト時は operationId を控えて再実行で回収（nowordsescape 落とし穴集参照）

### 落とし穴メモ（横展開済み）

- macOS bash 3.2: `declare -A` 不可 → `ENTRIES=("slot|file|prompt")` パイプ区切り配列
- Audio.lua の ID 反映は sed 禁止（bgm/se で同名キー誤爆）→ Python セクション切出置換
- Suno は同期ポーリング6分TOあり → 一括 submit → 後で collect
