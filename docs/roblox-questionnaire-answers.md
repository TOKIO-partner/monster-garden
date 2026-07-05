# Roblox Experience Questionnaire 回答シート — Monster Garden

生成日: 2026-07-06 / 生成: roblox-questionnaire スキル（提出は人間が実施）

| 項目 | 値 |
|------|-----|
| Universe ID | **10450862860**（`.mantle-state.yml:16`） |
| Place ID | **124198108214483**（`.mantle-state.yml:17,25`） |
| 提出URL | https://create.roblox.com/dashboard/creations/experiences/10450862860/experience-questionnaire |
| ゲーム概要 | モンスター捕獲 × 庭園育成オープンワールド（全年齢 8-14歳中心、`mantle.yml:20-22` / `README.md:11`） |

**申告原則**: 最も高い成熟度側で申告 / 全アセット+コンテンツ対象 / UGCは対象外 / 虚偽申告禁止。

---

## 回答一覧

| # | 質問（短縮） | 回答 | 根拠（file:line） |
|---|-------------|------|-------------------|
| 1 | 暴力 | **いいえ** | 捕獲は確率ロールのみで力の行使描写なし: `src/server/Lib/CaptureLogic.lua:37-41`（rng()<=rate 判定）、失敗時はモンスター「逃走」デスポーン `src/server/Services/CaptureService.lua:112-115`。src/ 全体に `Damage/Health/weapon/attack/combat` ヒット0件（Grep確認）。HP・攻撃モーション・死亡演出なし |
| 2 | 血の描写 | **いいえ** | `blood/gore` ヒット0件（src/・assets/）。血テクスチャ/パーティクルなし。SE一覧にも該当なし（`assets/ASSET_LOG.md:22-31`） |
| 3 | 恐怖要素 | **いいえ** | BGM4曲すべてパストラル/明るい曲調（そよかぜ草原/ごうか火山/みずうみのほとり/庭園島オルゴール `assets/ASSET_LOG.md:13-16`）。`horror/creepy/jumpscare` ヒット0件。「Dark」ヒットは属性名（火/水/草/光/闇の5属性）のみで恐怖演出ではない（`src/shared/Config/MonsterDatabase.lua:225-269`、かわいい系デザイン: シャドウウルフ/ムーンアウル等） |
| 4 | 下品なユーモア | **いいえ** | `fart/burp/vomit/poop` ヒット0件（src/・assets/）。SE 8種はUI/捕獲/孵化/水やり系のみ（`assets/ASSET_LOG.md:22-31`） |
| 5 | プレイ不可ギャンブル描写 | **いいえ** | `casino/roulette/gamble/poker` ヒット0件。`slot` ヒットは庭園島スロット割当（`src/server/Services/GardenService.lua:47-50`）でスロットマシンではない。カジノ風モデル・演出なし（`assets/models/` は動物モンスター+庭園プロップのみ） |
| 6 | 強烈な表現 | **いいえ** | 卑語・侮辱表現ヒット0件。ローカライズ全文（`src/shared/Localization/Languages.lua` 159行）に `kill/die/死/殺` 等なし。全年齢向けの平易な文言のみ |
| 7 | 恋愛テーマ/成人向け空間が主舞台 | **いいえ** | `bed/bar/club/hotel/kiss/romance` ヒット0件。舞台は草原/火山/湖畔バイオーム+空中庭園島（`src/shared/Config/BiomeConfig.lua:5,39`、`src/shared/Config/GameConfig.lua:56-67`） |
| 8 | アルコール | **いいえ** | `beer/wine/alcohol/sake/drunk` ヒット0件（src/・assets/）。GDD にも該当要素なし |
| 9 | 社交の集いの場が主テーマ | **いいえ** | 主テーマ=モンスター捕獲×庭園育成。ゲーム説明文「モンスターを捕まえて自分だけの庭園を育てるオープンワールド」（`mantle.yml:20-22`）に社交/hangout言及なし。`hangout/social` ヒット0件。チャットはRoblox標準のみで主テーマではない |
| 10 | プライベート空間の存在 | **いいえ** | `toilet/shower/bedroom/tent/bath` ヒット0件。空間はオープンなバイオームと空中庭園島のみで密室なし（`src/shared/Config/GameConfig.lua:56-67`、`assets/models/`: fence/fountain/hub/plot等の屋外プロップのみ） |
| 11 | 自由形式ユーザー作品 | **いいえ** | `SurfaceGui draw/canvas/paint/spray` ヒット0件。プレイヤーができるのは種植え/水やり/捕獲/デコ配置（既製3Dアセット配置は非該当基準に合致） |
| 12 | センシティブなメインテーマ | **いいえ** | 政治/宗教/社会問題の要素ヒット0件。GDD全体がファンタジー育成シミュレーター（`game-design-document.md:35-41`） |
| 13 | 他空間キャプチャコンテンツ閲覧 | **いいえ** | `VideoFrame` ヒット0件。Grep の `CaptureService` ヒットは本ゲーム独自の**モンスター捕獲**サービス（`src/server/Services/CaptureService.lua:2,16`）であり、Roblox の画面キャプチャAPI（CaptureService）とは無関係 |
| 14 | 生成AIとの交流 | **いいえ** | `HttpService/openai/claude/TextGeneration` ヒット0件（src/）。BGM/SE/モデルの制作にAI（Suno/ElevenLabs/Blender）を使用したが（`assets/ASSET_LOG.md:7-35`）、「開発にAI使用しただけ」は明示的に非該当。ゲーム内にユーザー⇔AI交流機能なし |
| 15 | 有料ランダムアイテム | **⚠️要人間判断** | 理由: (a) コード上 `premium_seed_5` DevProduct はランダム報酬（rainbow_seed 1個固定 + 5属性から `math.random` で4個: `src/server/Services/ShopService.lua:56-61`）で、Robux→ランダム報酬の実装が存在。エッグ商品も商品説明が「ノーマル〜レアのモンスターが出るタマゴ」とガチャ表記（`src/shared/Config/ShopPrices.lua:37-47`）。 (b) 一方、現時点で GamePass/DevProduct ID がすべて `0`（プレースホルダ未登録: `src/server/Services/ShopService.lua:21-39`）のため**Robux購入は一切不可能**＝現状は非該当とも言える。→ 商品登録のタイミングと合わせて人間が判断。**商品を登録して公開するなら「はい」で申告**（または `premium_seed_5` の乱数を固定内容に改修+エッグ説明文修正で「いいえ」化） |
| 16 | ユーザー間アイテム取引 | **いいえ** | `trade` ヒット0件（src/）。トレードは GDD の将来機能（F13、`game-design-document.md:80`）で未実装。実装時に再申告要 |
| 17 | メディア共有 | **いいえ** | `share/gallery/upload` の共有機能ヒット0件。スクリーンショット/動画/テキストの投稿・閲覧機能なし |
| 18 | 継続フィード/自動再生 | **いいえ** | 自動再生メディアはバイオーム別**背景BGM**のみ（`src/shared/Config/Audio.lua:10-15`、bgmVolume 0.4）で、背景BGMは明示的に非該当。無限スクロールフィード実装なし（`feed/scroll` ヒット0件） |

---

## 補足・再申告トリガー

1. **Q15（最重要）**: DevProduct 実IDを登録して販売開始する場合、`premium_seed_5` のランダム4シードとエッグ系のガチャ的商品説明により「有料ランダムアイテム=はい」+ Paid Random Items 開示が必要になる。回避するなら販売前に (a) `ShopService.grantProduct` の `math.random` 排除、(b) `ShopPrices.lua` のエッグ説明文を固定報酬表記に修正。
   - **サブ設問（はい申告時）**: 「`ArePaidRandomItemsRestricted` のポリシーAPIを尊重していますか？」→ 現状 **PolicyService 未実装**（`PolicyService|GetPolicyInfoForPlayerAsync` grep 0件確認済 2026-07-06）。未実装のまま「はい（尊重）」申告は虚偽。**販売開始時は `PolicyService:GetPolicyInfoForPlayerAsync` で `ArePaidRandomItemsRestricted` を確認し、規制対象プレイヤーにはランダム商品を非表示にするガード実装が必須**（参照: https://create.roblox.com/docs/reference/engine/classes/PolicyService#GetPolicyInfoForPlayerAsync ）。
2. **Q1**: GDD F16「モンスターバトル（3vs3ターン制）」（`game-design-document.md:83`）は未実装（優先度:低）。実装したら軽度カートゥーン暴力として再申告要。
3. **Q16**: トレーディング（GDD F13）実装時は「はい」に更新要。
4. 提出後: `mantle deploy --environment production` 再実行 → `targetAccess: public` 反映。確認は Open Cloud `GET cloud/v2/universes/10450862860` で `visibility: PUBLIC`。
