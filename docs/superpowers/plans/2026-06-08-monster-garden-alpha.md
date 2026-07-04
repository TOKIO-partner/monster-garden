# Monster Garden α版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** モンスターガーデンのα版（コアループ: 植える→育てる→孵化、モンスター20種、基本UI、ショップ骨格）を実装し、Roblox Studio上で動作するプレイ可能なプロトタイプを完成させる。

**Architecture:** Rojo 7.4.4 ベースのプロジェクト。サーバーはServicesパターン（DataService, GardenService, MonsterService, ShopService）、クライアントはControllersパターン（UIController, GardenController, InputController）。共有Config/Constantsで全データを一元管理。deep-sea-explorerプロジェクトのsafeRequire/safeInitパターンを採用。

**Tech Stack:** Luau, Rojo 7.4.4, Aftman, Selene 0.27.1, StyLua 0.20.0, Wally (Knit + Signal + Promise)

**Reference Projects:**
- `/Users/tokiohata/Projects/Storix/ゲーム開発/Roblox/deep-sea-explorer/` — safeRequire/safeInit パターン
- `/Users/tokiohata/Projects/Storix/ゲーム開発/Roblox/jurassic-survival/` — GameConfig/Service 構造

---

## File Structure

```
monster-garden/
├── default.project.json          # Rojo config
├── aftman.toml                   # Tool versions
├── wally.toml                    # Dependencies (Knit, Signal, Promise)
├── selene.toml                   # Linter config
├── stylua.toml                   # Formatter config
├── .gitignore                    # Roblox-specific ignores
├── .env.example                  # API key placeholders
├── README.md                     # Project documentation
├── game-design-document.md       # GDD v2.0 (existing)
├── docs/                         # Plans & specs
└── src/
    ├── server/
    │   ├── init.server.lua       # Server bootstrap (safeRequire/safeInit)
    │   └── Services/
    │       ├── DataService.lua       # ProfileService wrapper
    │       ├── GardenService.lua     # Garden plot logic
    │       ├── MonsterService.lua    # Monster generation & growth
    │       ├── WeatherService.lua    # Weather & season system
    │       └── ShopService.lua       # GamePass & DevProduct handling
    ├── client/
    │   ├── init.client.lua       # Client bootstrap (safeRequire/safeInit)
    │   └── Controllers/
    │       ├── UIController.lua      # HUD & screen management
    │       ├── GardenController.lua  # Plot interaction (click/tap)
    │       ├── ShopController.lua    # Shop UI
    │       └── CollectionController.lua  # Monster collection/codex UI
    ├── shared/
    │   ├── Config/
    │   │   ├── GameConfig.lua        # Global game settings
    │   │   ├── MonsterDatabase.lua   # 20 monster definitions
    │   │   ├── SeedDatabase.lua      # Seed types & rarity
    │   │   └── ShopPrices.lua        # All monetization prices
    │   └── Localization/
    │       └── Languages.lua         # i18n (JP/EN)
    └── replicated-first/
        └── LoadingScreen.client.lua  # Loading screen
```

---

## Task 1: Project Scaffolding

**Files:**
- Create: `default.project.json`
- Create: `aftman.toml`
- Create: `wally.toml`
- Create: `selene.toml`
- Create: `stylua.toml`
- Create: `.gitignore`
- Create: `.env.example`

- [ ] **Step 1: Create default.project.json**

```json
{
  "name": "MonsterGarden",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "Server": {
        "$path": "src/server"
      }
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "Client": {
          "$path": "src/client"
        }
      }
    },
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": {
        "$path": "src/shared"
      }
    },
    "ReplicatedFirst": {
      "$className": "ReplicatedFirst",
      "$path": "src/replicated-first"
    },
    "ServerStorage": {
      "$className": "ServerStorage"
    }
  }
}
```

- [ ] **Step 2: Create aftman.toml**

```toml
[tools]
rojo = "rojo-rbx/rojo@7.4.4"
selene = "Kampfkarren/selene@0.27.1"
stylua = "JohnnyMorganz/StyLua@0.20.0"
rbxcloud = "Sleitnick/rbxcloud@0.17.0"
```

- [ ] **Step 3: Create wally.toml**

```toml
[package]
name = "tokio-partner/monster-garden"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
Knit = "sleitnick/knit@1.6.0"
Signal = "sleitnick/signal@2.0.0"
Promise = "evaera/promise@4.0.0"
```

- [ ] **Step 4: Create selene.toml and stylua.toml**

`selene.toml`:
```toml
std = "roblox"
```

`stylua.toml`:
```toml
column_width = 120
line_endings = "Unix"
indent_type = "Tabs"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

- [ ] **Step 5: Create .gitignore and .env.example**

`.gitignore`:
```
.DS_Store
Thumbs.db
*.rbxl
*.rbxlx
*.rbxm
*.rbxmx
node_modules/
Packages/
build/
dist/
.vscode/
.idea/
*.swp
*.log
.env
.env.local
```

`.env.example`:
```
ROBLOX_API_KEY=your_api_key_here
ROBLOX_UNIVERSE_ID=TODO_CREATE_NEW_EXPERIENCE
ROBLOX_PLACE_ID=TODO_CREATE_NEW_EXPERIENCE
```

- [ ] **Step 6: Create src directory structure**

```bash
mkdir -p src/server/Services src/client/Controllers src/shared/Config src/shared/Localization src/replicated-first
```

- [ ] **Step 7: Commit scaffolding**

```bash
git add -A
git commit -m "chore: project scaffolding (Rojo, Aftman, Wally, Selene, StyLua)"
```

---

## Task 2: Shared Config & Monster Database

**Files:**
- Create: `src/shared/Config/GameConfig.lua`
- Create: `src/shared/Config/MonsterDatabase.lua`
- Create: `src/shared/Config/SeedDatabase.lua`
- Create: `src/shared/Config/ShopPrices.lua`
- Create: `src/shared/Localization/Languages.lua`

- [ ] **Step 1: Create GameConfig.lua**

```lua
return {
	Garden = {
		InitialSize = 3, -- 3x3 grid
		MaxPlots = 9, -- InitialSize^2
		GrowthTickInterval = 1, -- seconds between growth ticks
		OfflineGrowthEnabled = true,
		OfflineGrowthRate = 1.0, -- 100% of normal rate
	},

	Growth = {
		-- Duration in seconds for each stage
		SeedToSprout = 300, -- 5 min
		SproutToBud = 900, -- 15 min
		BudToEgg = 1800, -- 30 min
		EggToHatch = 0, -- instant on tap
		HatchToJuvenile = 3600, -- 60 min
		JuvenileToAdult = 7200, -- 120 min
	},

	Soil = {
		Normal = { rarityBonus = 0, cost = 0 },
		Magic = { rarityBonus = 0.10, cost = 500 },
		Golden = { rarityBonus = 0.25, cost = 0 }, -- Robux only
	},

	Weather = {
		Types = { "Sunny", "Rainy", "Snowy", "Stormy", "Rainbow" },
		ChangeInterval = 600, -- 10 minutes between weather changes
		RainbowChance = 0.05,
	},

	Season = {
		Types = { "Spring", "Summer", "Autumn", "Winter" },
		DurationSeconds = 604800, -- 1 real week
	},

	DailyLogin = {
		Rewards = {
			[1] = { type = "coins", amount = 100 },
			[2] = { type = "seed", rarity = "Normal" },
			[3] = { type = "coins", amount = 250 },
			[4] = { type = "seed", rarity = "Normal" },
			[5] = { type = "coins", amount = 500 },
			[6] = { type = "seed", rarity = "Rare" },
			[7] = { type = "premiumSeed", rarity = "Epic" },
		},
	},
}
```

- [ ] **Step 2: Create MonsterDatabase.lua — 20 monsters**

```lua
--[[
	Monster Database — α版 20種
	Rarity: Normal(60%), Rare(25%), Epic(10%), Legend(4%), Mythic(1%)
	Attributes: Fire, Water, Grass, Light, Dark
]]
return {
	-- === FIRE (4 monsters) ===
	FlameBunny = {
		id = "flame_bunny",
		name = "フレイムバニー",
		nameEN = "Flame Bunny",
		attribute = "Fire",
		rarity = "Normal",
		baseValue = 50,
		description = "耳から小さな炎を出す可愛いうさぎ。",
		spawnCondition = { weather = "Sunny" },
	},
	MagmaTurtle = {
		id = "magma_turtle",
		name = "マグマタートル",
		nameEN = "Magma Turtle",
		attribute = "Fire",
		rarity = "Rare",
		baseValue = 200,
		description = "甲羅が常に赤熱している頑丈な亀。",
		spawnCondition = { weather = "Sunny" },
	},
	InfernoFox = {
		id = "inferno_fox",
		name = "インフェルノフォックス",
		nameEN = "Inferno Fox",
		attribute = "Fire",
		rarity = "Epic",
		baseValue = 800,
		description = "9本の炎の尾を持つ伝説の狐。",
		spawnCondition = { weather = "Sunny", season = "Summer" },
	},
	PhoenixChick = {
		id = "phoenix_chick",
		name = "フェニックスチック",
		nameEN = "Phoenix Chick",
		attribute = "Fire",
		rarity = "Legend",
		baseValue = 5000,
		description = "不死鳥のヒナ。倒れても灰から蘇る。",
		spawnCondition = { weather = "Sunny", season = "Summer" },
	},

	-- === WATER (4 monsters) ===
	BubbleFish = {
		id = "bubble_fish",
		name = "バブルフィッシュ",
		nameEN = "Bubble Fish",
		attribute = "Water",
		rarity = "Normal",
		baseValue = 50,
		description = "泡に包まれた空飛ぶ魚。",
		spawnCondition = { weather = "Rainy" },
	},
	RainSlime = {
		id = "rain_slime",
		name = "レインスライム",
		nameEN = "Rain Slime",
		attribute = "Water",
		rarity = "Normal",
		baseValue = 30,
		description = "雨粒から生まれた透明なスライム。",
		spawnCondition = { weather = "Rainy" },
	},
	TidalSeahorse = {
		id = "tidal_seahorse",
		name = "タイダルシーホース",
		nameEN = "Tidal Seahorse",
		attribute = "Water",
		rarity = "Rare",
		baseValue = 250,
		description = "小さな潮流を操るタツノオトシゴ。",
		spawnCondition = { weather = "Rainy" },
	},
	FrostWhale = {
		id = "frost_whale",
		name = "フロストホエール",
		nameEN = "Frost Whale",
		attribute = "Water",
		rarity = "Epic",
		baseValue = 1000,
		description = "氷の息を吐く小型クジラ。",
		spawnCondition = { weather = "Snowy" },
	},

	-- === GRASS (4 monsters) ===
	LeafCat = {
		id = "leaf_cat",
		name = "リーフキャット",
		nameEN = "Leaf Cat",
		attribute = "Grass",
		rarity = "Normal",
		baseValue = 40,
		description = "葉っぱの耳を持つ緑色の猫。",
		spawnCondition = { season = "Spring" },
	},
	MossBear = {
		id = "moss_bear",
		name = "モスベア",
		nameEN = "Moss Bear",
		attribute = "Grass",
		rarity = "Rare",
		baseValue = 300,
		description = "体全体に苔が生えたのんびり熊。",
		spawnCondition = { season = "Spring" },
	},
	BloomDeer = {
		id = "bloom_deer",
		name = "ブルームディア",
		nameEN = "Bloom Deer",
		attribute = "Grass",
		rarity = "Epic",
		baseValue = 900,
		description = "角から花が咲く神秘的な鹿。",
		spawnCondition = { season = "Spring", weather = "Rainy" },
	},
	AncientTreent = {
		id = "ancient_treent",
		name = "エンシェントトレント",
		nameEN = "Ancient Treent",
		attribute = "Grass",
		rarity = "Legend",
		baseValue = 4500,
		description = "千年を生きた歩く大樹。",
		spawnCondition = { season = "Spring", weather = "Rainbow" },
	},

	-- === LIGHT (4 monsters) ===
	StarFox = {
		id = "star_fox",
		name = "スターフォックス",
		nameEN = "Star Fox",
		attribute = "Light",
		rarity = "Rare",
		baseValue = 350,
		description = "星屑を纏った黄金の狐。",
		spawnCondition = { weather = "Rainbow" },
	},
	SunBird = {
		id = "sun_bird",
		name = "サンバード",
		nameEN = "Sun Bird",
		attribute = "Light",
		rarity = "Normal",
		baseValue = 60,
		description = "太陽の光を翼に宿す小鳥。",
		spawnCondition = { weather = "Sunny" },
	},
	HolyUnicorn = {
		id = "holy_unicorn",
		name = "ホーリーユニコーン",
		nameEN = "Holy Unicorn",
		attribute = "Light",
		rarity = "Legend",
		baseValue = 6000,
		description = "虹の角を持つ聖なるユニコーン。",
		spawnCondition = { weather = "Rainbow" },
	},
	CelestialDragon = {
		id = "celestial_dragon",
		name = "セレスティアルドラゴン",
		nameEN = "Celestial Dragon",
		attribute = "Light",
		rarity = "Mythic",
		baseValue = 50000,
		description = "天界から降りた伝説の龍。全モンスターの頂点。",
		spawnCondition = { weather = "Rainbow", season = "Spring" },
	},

	-- === DARK (4 monsters) ===
	ShadowWolf = {
		id = "shadow_wolf",
		name = "シャドウウルフ",
		nameEN = "Shadow Wolf",
		attribute = "Dark",
		rarity = "Normal",
		baseValue = 55,
		description = "影に溶け込む漆黒の狼。",
		spawnCondition = { timeOfDay = "Night" },
	},
	MoonOwl = {
		id = "moon_owl",
		name = "ムーンオウル",
		nameEN = "Moon Owl",
		attribute = "Dark",
		rarity = "Rare",
		baseValue = 280,
		description = "月光を目に宿すフクロウ。",
		spawnCondition = { timeOfDay = "Night" },
	},
	VoidCat = {
		id = "void_cat",
		name = "ヴォイドキャット",
		nameEN = "Void Cat",
		attribute = "Dark",
		rarity = "Epic",
		baseValue = 1200,
		description = "次元の狭間を歩く不思議な猫。",
		spawnCondition = { timeOfDay = "Night", weather = "Stormy" },
	},
	AbyssalSerpent = {
		id = "abyssal_serpent",
		name = "アビサルサーペント",
		nameEN = "Abyssal Serpent",
		attribute = "Dark",
		rarity = "Legend",
		baseValue = 5500,
		description = "深淵から這い出た巨大な蛇。",
		spawnCondition = { timeOfDay = "Night", season = "Winter" },
	},
}
```

- [ ] **Step 3: Create SeedDatabase.lua**

```lua
--[[
	Seed Database — seeds available for planting
	Each seed can produce monsters from its attribute pool
]]
return {
	FireSeed = {
		id = "fire_seed",
		name = "火の種",
		nameEN = "Fire Seed",
		attribute = "Fire",
		rarity = "Normal",
		cost = 100,
		possibleMonsters = { "flame_bunny", "magma_turtle" },
	},
	WaterSeed = {
		id = "water_seed",
		name = "水の種",
		nameEN = "Water Seed",
		attribute = "Water",
		rarity = "Normal",
		cost = 100,
		possibleMonsters = { "bubble_fish", "rain_slime" },
	},
	GrassSeed = {
		id = "grass_seed",
		name = "草の種",
		nameEN = "Grass Seed",
		attribute = "Grass",
		rarity = "Normal",
		cost = 100,
		possibleMonsters = { "leaf_cat" },
	},
	LightSeed = {
		id = "light_seed",
		name = "光の種",
		nameEN = "Light Seed",
		attribute = "Light",
		rarity = "Rare",
		cost = 500,
		possibleMonsters = { "sun_bird", "star_fox" },
	},
	DarkSeed = {
		id = "dark_seed",
		name = "闇の種",
		nameEN = "Dark Seed",
		attribute = "Dark",
		rarity = "Rare",
		cost = 500,
		possibleMonsters = { "shadow_wolf", "moon_owl" },
	},
	RainbowSeed = {
		id = "rainbow_seed",
		name = "虹の種",
		nameEN = "Rainbow Seed",
		attribute = "All",
		rarity = "Epic",
		cost = 2000,
		possibleMonsters = "any_epic_or_above",
	},
	MysticSeed = {
		id = "mystic_seed",
		name = "神秘の種",
		nameEN = "Mystic Seed",
		attribute = "All",
		rarity = "Legend",
		cost = 0, -- Robux only
		possibleMonsters = "any_legend_or_above",
	},
}
```

- [ ] **Step 4: Create ShopPrices.lua**

```lua
--[[
	Shop Prices — all monetization items
	priceType: "coins" (in-game) or "robux"
]]
return {
	GamePasses = {
		VIP = { id = "vip_pass", name = "VIPパス", robux = 499, description = "VIPエリア+毎日ボーナス2倍+庭園20x20" },
		MutationBoost = { id = "mutation_4x", name = "4倍変異確率", robux = 399, description = "変異発生確率が4倍" },
		LuckyGardener = { id = "lucky_gardener", name = "ラッキーガーデナー", robux = 299, description = "レア出現率+15%" },
		SuperGrow = { id = "super_grow", name = "スーパーグロウ", robux = 199, description = "成長速度2倍" },
		AutoWater = { id = "auto_water", name = "自動水やり", robux = 149, description = "全マス自動水やり" },
	},

	DevProducts = {
		BasicEgg = { id = "basic_egg", name = "ベーシックペットエッグ", robux = 49 },
		GoldEgg = { id = "gold_egg", name = "ゴールドペットエッグ", robux = 149 },
		PremiumSeedPack = { id = "premium_seed_5", name = "プレミアムシードパック(5個)", robux = 199 },
		GrowthBoost1h = { id = "growth_boost_1h", name = "成長ブースター(2倍/1h)", robux = 49 },
		InstantHatch3 = { id = "instant_hatch_3", name = "即時孵化チケット(3枚)", robux = 99 },
		GardenExpand = { id = "garden_expand", name = "庭園拡張チケット", robux = 199 },
		GoldenSoil5 = { id = "golden_soil_5", name = "黄金土(5枚)", robux = 49 },
		DecoPackFantasy = { id = "deco_fantasy", name = "ファンタジーデコパック", robux = 149 },
	},

	SeasonPass = {
		price = 749,
		levels = 50,
		durationWeeks = 5,
	},
}
```

- [ ] **Step 5: Create Languages.lua**

```lua
local Languages = {}

local translations = {
	ja = {
		welcome = "モンスターガーデンへようこそ！",
		plant = "植える",
		water = "水やり",
		fertilize = "肥料",
		hatch = "孵化！",
		collect = "図鑑",
		shop = "ショップ",
		coins = "コイン",
		seeds = "種",
		monsters = "モンスター",
		garden = "庭園",
		rarity_normal = "ノーマル",
		rarity_rare = "レア",
		rarity_epic = "エピック",
		rarity_legend = "レジェンド",
		rarity_mythic = "ミシック",
		weather_sunny = "晴れ",
		weather_rainy = "雨",
		weather_snowy = "雪",
		weather_stormy = "嵐",
		weather_rainbow = "虹",
		growth_seed = "種",
		growth_sprout = "芽",
		growth_bud = "つぼみ",
		growth_egg = "卵",
		growth_juvenile = "幼体",
		growth_adult = "成体",
		growth_ultimate = "究極体",
		tap_to_hatch = "タップで孵化！",
		not_enough_coins = "コインが足りません",
		monster_obtained = "を手に入れた！",
	},
	en = {
		welcome = "Welcome to Monster Garden!",
		plant = "Plant",
		water = "Water",
		fertilize = "Fertilize",
		hatch = "Hatch!",
		collect = "Collection",
		shop = "Shop",
		coins = "Coins",
		seeds = "Seeds",
		monsters = "Monsters",
		garden = "Garden",
		rarity_normal = "Normal",
		rarity_rare = "Rare",
		rarity_epic = "Epic",
		rarity_legend = "Legend",
		rarity_mythic = "Mythic",
		weather_sunny = "Sunny",
		weather_rainy = "Rainy",
		weather_snowy = "Snowy",
		weather_stormy = "Stormy",
		weather_rainbow = "Rainbow",
		growth_seed = "Seed",
		growth_sprout = "Sprout",
		growth_bud = "Bud",
		growth_egg = "Egg",
		growth_juvenile = "Juvenile",
		growth_adult = "Adult",
		growth_ultimate = "Ultimate",
		tap_to_hatch = "Tap to Hatch!",
		not_enough_coins = "Not enough coins",
		monster_obtained = " obtained!",
	},
}

function Languages.getText(key: string, lang: string?): string
	local l = lang or "ja"
	local t = translations[l]
	if t and t[key] then
		return t[key]
	end
	-- Fallback to Japanese
	if translations.ja[key] then
		return translations.ja[key]
	end
	return key
end

return Languages
```

- [ ] **Step 6: Commit shared config**

```bash
git add src/shared/
git commit -m "feat: shared config (GameConfig, MonsterDB 20種, SeedDB, ShopPrices, i18n)"
```

---

## Task 3: Server Bootstrap & DataService

**Files:**
- Create: `src/server/init.server.lua`
- Create: `src/server/Services/DataService.lua`

- [ ] **Step 1: Create server init.server.lua**

```lua
--!strict
--[[
	Monster Garden — Server Bootstrap
	Uses safeRequire/safeInit pattern from deep-sea-explorer
]]

local RunService = game:GetService("RunService")

-- Safe require wrapper
local function safeRequire(path: ModuleScript, name: string): any?
	local ok, result = pcall(function()
		return require(path)
	end)
	if ok then
		print("[Server] ✓ Loaded: " .. name)
		return result
	else
		warn("[Server] ✗ FAILED to load: " .. name .. " → " .. tostring(result))
		return nil
	end
end

-- Safe init wrapper
local function safeInit(service: any?, name: string)
	if not service then
		warn("[Server] ✗ SKIP init: " .. name .. " (not loaded)")
		return
	end
	if not service.init then
		warn("[Server] ✗ SKIP init: " .. name .. " (no init function)")
		return
	end
	local ok, err = pcall(function()
		service.init()
	end)
	if ok then
		print("[Server] ✓ Initialized: " .. name)
	else
		warn("[Server] ✗ FAILED init: " .. name .. " → " .. tostring(err))
	end
end

print("[Server] === Monster Garden Server Starting ===")

-- Load services
local DataService = safeRequire(script.Services.DataService, "DataService")
local GardenService = safeRequire(script.Services.GardenService, "GardenService")
local MonsterService = safeRequire(script.Services.MonsterService, "MonsterService")
local WeatherService = safeRequire(script.Services.WeatherService, "WeatherService")
local ShopService = safeRequire(script.Services.ShopService, "ShopService")

-- Initialize in dependency order
safeInit(DataService, "DataService")
safeInit(WeatherService, "WeatherService")
safeInit(MonsterService, "MonsterService")
safeInit(GardenService, "GardenService")
safeInit(ShopService, "ShopService")

-- Game loop
RunService.Heartbeat:Connect(function(dt: number)
	if GardenService and GardenService.update then
		pcall(GardenService.update, dt)
	end
	if WeatherService and WeatherService.update then
		pcall(WeatherService.update, dt)
	end
end)

print("[Server] === Monster Garden Server Ready ===")
```

- [ ] **Step 2: Create DataService.lua**

```lua
--!strict
--[[
	DataService — Player data persistence
	Uses DataStoreService with retry logic
	Handles: save/load player data, offline time calculation
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local DataService = {}

local DATA_STORE_NAME = "MonsterGarden_v1"
local AUTOSAVE_INTERVAL = 120 -- seconds
local MAX_RETRIES = 3

local store: DataStore? = nil
local playerData: { [number]: any } = {}
local lastSave: { [number]: number } = {}

-- Default player data template
local DEFAULT_DATA = {
	coins = 500,
	seeds = { "fire_seed", "water_seed", "grass_seed" }, -- starter seeds
	garden = {}, -- { [plotIndex] = { seedId, stage, growthProgress, soilType, plantedAt } }
	monsters = {}, -- { [monsterId] = { id, rarity, attribute, mutation, obtainedAt } }
	collection = {}, -- { [monsterId] = true } — discovered monsters
	stats = {
		totalMonsters = 0,
		totalSeeds = 0,
		loginStreak = 0,
		lastLoginDate = "",
		lastLogoutTime = 0,
	},
	gamePasses = {},
	settings = {
		language = "ja",
	},
}

-- Retry utility
local function retry(fn: () -> any, maxRetries: number?): (boolean, any)
	local retries = maxRetries or MAX_RETRIES
	for i = 1, retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if i < retries then
			task.wait(1 * i) -- exponential-ish backoff
		else
			return false, result
		end
	end
	return false, "Max retries exceeded"
end

-- Deep copy
local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

function DataService.init()
	if not RunService:IsStudio() or RunService:IsStudio() then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(DATA_STORE_NAME)
		end)
		if ok then
			store = result
			print("[DataService] DataStore connected: " .. DATA_STORE_NAME)
		else
			warn("[DataService] DataStore unavailable (Studio?): " .. tostring(result))
		end
	end

	-- Setup RemoteEvents
	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage

	local getDataRemote = Instance.new("RemoteFunction")
	getDataRemote.Name = "GetPlayerData"
	getDataRemote.Parent = remotes
	getDataRemote.OnServerInvoke = function(player: Player)
		return DataService.getData(player)
	end

	local updateDataRemote = Instance.new("RemoteEvent")
	updateDataRemote.Name = "UpdatePlayerData"
	updateDataRemote.Parent = remotes

	-- Player connections
	Players.PlayerAdded:Connect(function(player: Player)
		DataService.loadData(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		DataService.saveData(player)
		playerData[player.UserId] = nil
		lastSave[player.UserId] = nil
	end)

	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.saveData(player)
			end
		end
	end)

	-- BindToClose
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.saveData(player)
		end
	end)
end

function DataService.loadData(player: Player)
	local userId = player.UserId
	local data = deepCopy(DEFAULT_DATA)

	if store then
		local ok, savedData = retry(function()
			return store:GetAsync("Player_" .. userId)
		end)

		if ok and savedData then
			-- Merge saved data with defaults (handles new fields)
			for key, value in pairs(savedData) do
				if data[key] ~= nil then
					data[key] = value
				end
			end
			print("[DataService] Loaded data for " .. player.Name)
		else
			print("[DataService] New player: " .. player.Name)
		end
	end

	-- Calculate offline growth
	if data.stats.lastLogoutTime > 0 then
		local offlineSeconds = os.time() - data.stats.lastLogoutTime
		data._offlineSeconds = math.min(offlineSeconds, 28800) -- max 8 hours
		print("[DataService] Offline time: " .. math.floor(offlineSeconds / 60) .. " min")
	end

	-- Update login streak
	local today = os.date("%Y-%m-%d")
	if data.stats.lastLoginDate ~= today then
		local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
		if data.stats.lastLoginDate == yesterday then
			data.stats.loginStreak = (data.stats.loginStreak or 0) + 1
		else
			data.stats.loginStreak = 1
		end
		data.stats.lastLoginDate = today
	end

	-- Setup leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = data.coins
	coinsValue.Parent = leaderstats

	local monstersValue = Instance.new("IntValue")
	monstersValue.Name = "Monsters"
	monstersValue.Value = data.stats.totalMonsters
	monstersValue.Parent = leaderstats

	playerData[userId] = data
	lastSave[userId] = os.time()
end

function DataService.saveData(player: Player)
	local userId = player.UserId
	local data = playerData[userId]
	if not data or not store then
		return
	end

	data.stats.lastLogoutTime = os.time()

	-- Remove transient fields
	local saveData = deepCopy(data)
	saveData._offlineSeconds = nil

	local ok, err = retry(function()
		store:SetAsync("Player_" .. userId, saveData)
	end)

	if ok then
		lastSave[userId] = os.time()
	else
		warn("[DataService] Failed to save for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.getData(player: Player): any
	return playerData[player.UserId]
end

function DataService.updateData(player: Player, key: string, value: any)
	local data = playerData[player.UserId]
	if data then
		data[key] = value
		-- Sync leaderstats
		if key == "coins" then
			local ls = player:FindFirstChild("leaderstats")
			if ls then
				local cv = ls:FindFirstChild("Coins")
				if cv then
					cv.Value = value
				end
			end
		end
	end
end

function DataService.addCoins(player: Player, amount: number)
	local data = playerData[player.UserId]
	if data then
		data.coins = data.coins + amount
		DataService.updateData(player, "coins", data.coins)
	end
end

function DataService.spendCoins(player: Player, amount: number): boolean
	local data = playerData[player.UserId]
	if data and data.coins >= amount then
		data.coins = data.coins - amount
		DataService.updateData(player, "coins", data.coins)
		return true
	end
	return false
end

return DataService
```

- [ ] **Step 3: Commit server bootstrap + DataService**

```bash
git add src/server/
git commit -m "feat: server bootstrap + DataService (save/load, offline calc, leaderstats)"
```

---

## Task 4: GardenService — Core Growth Loop

**Files:**
- Create: `src/server/Services/GardenService.lua`

- [ ] **Step 1: Create GardenService.lua**

```lua
--!strict
--[[
	GardenService — Core garden mechanics
	Handles: plot management, planting, growth ticks, watering, harvesting
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local SeedDatabase = require(Shared.Config.SeedDatabase)

local DataService -- forward declaration, set in init

local GardenService = {}

local GROWTH_STAGES = { "Seed", "Sprout", "Bud", "Egg", "Juvenile", "Adult", "Ultimate" }
local STAGE_DURATIONS = {
	Seed = GameConfig.Growth.SeedToSprout,
	Sprout = GameConfig.Growth.SproutToBud,
	Bud = GameConfig.Growth.BudToEgg,
	Egg = 0, -- requires player tap
	Juvenile = GameConfig.Growth.HatchToJuvenile,
	Adult = GameConfig.Growth.JuvenileToAdult,
	Ultimate = 0, -- requires special materials
}

local gardenTimers: { [number]: number } = {} -- userId -> accumulated dt

function GardenService.init()
	-- Get DataService reference
	local ServerScriptService = game:GetService("ServerScriptService")
	DataService = require(ServerScriptService.Server.Services.DataService)

	-- Setup RemoteEvents
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local plantRemote = Instance.new("RemoteEvent")
	plantRemote.Name = "PlantSeed"
	plantRemote.Parent = remotes
	plantRemote.OnServerEvent:Connect(function(player: Player, plotIndex: number, seedId: string)
		GardenService.plantSeed(player, plotIndex, seedId)
	end)

	local waterRemote = Instance.new("RemoteEvent")
	waterRemote.Name = "WaterPlot"
	waterRemote.Parent = remotes
	waterRemote.OnServerEvent:Connect(function(player: Player, plotIndex: number)
		GardenService.waterPlot(player, plotIndex)
	end)

	local hatchRemote = Instance.new("RemoteEvent")
	hatchRemote.Name = "HatchEgg"
	hatchRemote.Parent = remotes
	hatchRemote.OnServerEvent:Connect(function(player: Player, plotIndex: number)
		GardenService.hatchEgg(player, plotIndex)
	end)

	local gardenUpdateRemote = Instance.new("RemoteEvent")
	gardenUpdateRemote.Name = "GardenUpdate"
	gardenUpdateRemote.Parent = remotes

	-- Process offline growth on player join
	Players.PlayerAdded:Connect(function(player: Player)
		task.wait(1) -- wait for DataService to load
		GardenService.processOfflineGrowth(player)
	end)

	print("[GardenService] Initialized")
end

function GardenService.update(dt: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		gardenTimers[userId] = (gardenTimers[userId] or 0) + dt

		if gardenTimers[userId] >= GameConfig.Garden.GrowthTickInterval then
			gardenTimers[userId] = 0
			GardenService.growthTick(player)
		end
	end
end

function GardenService.growthTick(player: Player)
	local data = DataService.getData(player)
	if not data or not data.garden then
		return
	end

	local changed = false
	for plotIndex, plot in pairs(data.garden) do
		if plot.stage and plot.stage ~= "Egg" and plot.stage ~= "Ultimate" then
			local duration = STAGE_DURATIONS[plot.stage]
			if duration and duration > 0 then
				-- Apply growth speed multiplier from gamepasses
				local multiplier = 1.0
				if data.gamePasses and data.gamePasses.super_grow then
					multiplier = multiplier * 2.0
				end

				plot.growthProgress = (plot.growthProgress or 0) + (GameConfig.Garden.GrowthTickInterval * multiplier)

				if plot.growthProgress >= duration then
					plot.growthProgress = 0
					local currentIdx = table.find(GROWTH_STAGES, plot.stage)
					if currentIdx and currentIdx < #GROWTH_STAGES then
						plot.stage = GROWTH_STAGES[currentIdx + 1]
						changed = true
					end
				end
			end
		end
	end

	if changed then
		-- Notify client
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local gardenUpdate = remotes:FindFirstChild("GardenUpdate")
			if gardenUpdate then
				gardenUpdate:FireClient(player, data.garden)
			end
		end
	end
end

function GardenService.plantSeed(player: Player, plotIndex: number, seedId: string)
	local data = DataService.getData(player)
	if not data then
		return
	end

	-- Validate plot index
	local maxPlots = GameConfig.Garden.MaxPlots
	if plotIndex < 1 or plotIndex > maxPlots then
		return
	end

	-- Check plot is empty
	if data.garden[tostring(plotIndex)] then
		return
	end

	-- Check player has the seed
	local seedIdx = table.find(data.seeds, seedId)
	if not seedIdx then
		-- Try buying with coins
		local seedData = nil
		for _, seed in pairs(SeedDatabase) do
			if seed.id == seedId then
				seedData = seed
				break
			end
		end
		if seedData and seedData.cost > 0 then
			if not DataService.spendCoins(player, seedData.cost) then
				return -- not enough coins
			end
		else
			return -- seed not found or no coins
		end
	else
		table.remove(data.seeds, seedIdx)
	end

	-- Plant the seed
	data.garden[tostring(plotIndex)] = {
		seedId = seedId,
		stage = "Seed",
		growthProgress = 0,
		soilType = "Normal",
		plantedAt = os.time(),
		watered = false,
	}

	-- Notify client
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local gardenUpdate = remotes:FindFirstChild("GardenUpdate")
		if gardenUpdate then
			gardenUpdate:FireClient(player, data.garden)
		end
	end

	print("[GardenService] " .. player.Name .. " planted " .. seedId .. " at plot " .. plotIndex)
end

function GardenService.waterPlot(player: Player, plotIndex: number)
	local data = DataService.getData(player)
	if not data then
		return
	end

	local plot = data.garden[tostring(plotIndex)]
	if not plot then
		return
	end

	if not plot.watered then
		plot.watered = true
		-- Bonus growth progress for watering
		plot.growthProgress = (plot.growthProgress or 0) + 60 -- +1 minute bonus
		print("[GardenService] " .. player.Name .. " watered plot " .. plotIndex)
	end
end

function GardenService.hatchEgg(player: Player, plotIndex: number)
	local data = DataService.getData(player)
	if not data then
		return
	end

	local plot = data.garden[tostring(plotIndex)]
	if not plot or plot.stage ~= "Egg" then
		return
	end

	-- Determine which monster hatches
	local MonsterService = require(game:GetService("ServerScriptService").Server.Services.MonsterService)
	local monster = MonsterService.rollMonster(player, plot.seedId)

	if monster then
		-- Add to player's monsters
		local monsterId = monster.id .. "_" .. os.time()
		data.monsters[monsterId] = {
			id = monster.id,
			name = monster.name,
			rarity = monster.rarity,
			attribute = monster.attribute,
			mutation = 0,
			obtainedAt = os.time(),
		}

		-- Add to collection
		data.collection[monster.id] = true

		-- Update stats
		data.stats.totalMonsters = (data.stats.totalMonsters or 0) + 1
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			local mv = ls:FindFirstChild("Monsters")
			if mv then
				mv.Value = data.stats.totalMonsters
			end
		end

		-- Progress to Juvenile stage
		plot.stage = "Juvenile"
		plot.growthProgress = 0
		plot.hatchedMonsterId = monsterId

		-- Notify client
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local gardenUpdate = remotes:FindFirstChild("GardenUpdate")
			if gardenUpdate then
				gardenUpdate:FireClient(player, data.garden)
			end

			-- Fire hatch notification
			local hatchNotify = Instance.new("RemoteEvent")
			hatchNotify.Name = "MonsterHatched"
			if not remotes:FindFirstChild("MonsterHatched") then
				hatchNotify.Parent = remotes
			else
				hatchNotify = remotes.MonsterHatched
			end
			hatchNotify:FireClient(player, monster)
		end

		print("[GardenService] " .. player.Name .. " hatched: " .. monster.name .. " (" .. monster.rarity .. ")")
	end
end

function GardenService.processOfflineGrowth(player: Player)
	local data = DataService.getData(player)
	if not data or not data._offlineSeconds then
		return
	end

	local offlineSeconds = data._offlineSeconds
	if offlineSeconds <= 0 then
		return
	end

	local multiplier = 1.0
	if data.gamePasses and data.gamePasses.super_grow then
		multiplier = 2.0
	end

	local totalGrowth = offlineSeconds * multiplier
	print("[GardenService] Processing " .. math.floor(totalGrowth) .. "s offline growth for " .. player.Name)

	for _, plot in pairs(data.garden) do
		if plot.stage and plot.stage ~= "Egg" and plot.stage ~= "Ultimate" then
			local remainingGrowth = totalGrowth
			while remainingGrowth > 0 do
				local duration = STAGE_DURATIONS[plot.stage]
				if not duration or duration <= 0 then
					break
				end

				local needed = duration - (plot.growthProgress or 0)
				if remainingGrowth >= needed then
					remainingGrowth = remainingGrowth - needed
					plot.growthProgress = 0
					local currentIdx = table.find(GROWTH_STAGES, plot.stage)
					if currentIdx and currentIdx < #GROWTH_STAGES then
						local nextStage = GROWTH_STAGES[currentIdx + 1]
						if nextStage == "Egg" then
							plot.stage = "Egg"
							break -- Egg requires manual tap
						end
						plot.stage = nextStage
					else
						break
					end
				else
					plot.growthProgress = (plot.growthProgress or 0) + remainingGrowth
					remainingGrowth = 0
				end
			end
		end
	end

	data._offlineSeconds = nil
end

return GardenService
```

- [ ] **Step 2: Commit GardenService**

```bash
git add src/server/Services/GardenService.lua
git commit -m "feat: GardenService (plant, water, growth ticks, hatch, offline growth)"
```

---

## Task 5: MonsterService & WeatherService

**Files:**
- Create: `src/server/Services/MonsterService.lua`
- Create: `src/server/Services/WeatherService.lua`

- [ ] **Step 1: Create MonsterService.lua**

```lua
--!strict
--[[
	MonsterService — Monster generation, rarity rolling, collection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterDatabase = require(Shared.Config.MonsterDatabase)
local SeedDatabase = require(Shared.Config.SeedDatabase)

local MonsterService = {}

-- Rarity weights (normal distribution)
local RARITY_WEIGHTS = {
	Normal = 60,
	Rare = 25,
	Epic = 10,
	Legend = 4,
	Mythic = 1,
}

local currentWeather = "Sunny"
local currentSeason = "Spring"
local currentTimeOfDay = "Day"

function MonsterService.init()
	print("[MonsterService] Initialized with " .. MonsterService.getMonsterCount() .. " monsters")
end

function MonsterService.setWeather(weather: string)
	currentWeather = weather
end

function MonsterService.setSeason(season: string)
	currentSeason = season
end

function MonsterService.setTimeOfDay(tod: string)
	currentTimeOfDay = tod
end

function MonsterService.getMonsterCount(): number
	local count = 0
	for _ in pairs(MonsterDatabase) do
		count = count + 1
	end
	return count
end

function MonsterService.rollRarity(player: any?): string
	local weights = {}
	for rarity, weight in pairs(RARITY_WEIGHTS) do
		weights[rarity] = weight
	end

	-- Apply lucky gardener bonus
	if player then
		local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
		local data = DataService.getData(player)
		if data and data.gamePasses and data.gamePasses.lucky_gardener then
			weights.Rare = weights.Rare + 5
			weights.Epic = weights.Epic + 3
			weights.Legend = weights.Legend + 1.5
			weights.Mythic = weights.Mythic + 0.5
			weights.Normal = weights.Normal - 10
		end
	end

	local totalWeight = 0
	for _, w in pairs(weights) do
		totalWeight = totalWeight + w
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for rarity, weight in pairs(weights) do
		cumulative = cumulative + weight
		if roll <= cumulative then
			return rarity
		end
	end

	return "Normal"
end

function MonsterService.rollMonster(player: any?, seedId: string): any?
	local rarity = MonsterService.rollRarity(player)

	-- Find eligible monsters based on seed, rarity, and conditions
	local eligible = {}
	local seedData = nil
	for _, seed in pairs(SeedDatabase) do
		if seed.id == seedId then
			seedData = seed
			break
		end
	end

	for _, monster in pairs(MonsterDatabase) do
		local matchesRarity = monster.rarity == rarity
		local matchesSeed = false

		if seedData then
			if seedData.possibleMonsters == "any_epic_or_above" then
				matchesSeed = (monster.rarity == "Epic" or monster.rarity == "Legend" or monster.rarity == "Mythic")
				matchesRarity = true
			elseif seedData.possibleMonsters == "any_legend_or_above" then
				matchesSeed = (monster.rarity == "Legend" or monster.rarity == "Mythic")
				matchesRarity = true
			elseif type(seedData.possibleMonsters) == "table" then
				matchesSeed = table.find(seedData.possibleMonsters, monster.id) ~= nil
			end

			-- Attribute match for normal seeds
			if seedData.attribute ~= "All" then
				if monster.attribute ~= seedData.attribute then
					matchesSeed = false
				end
			end
		end

		-- Check spawn conditions
		local conditionsMet = true
		if monster.spawnCondition then
			if monster.spawnCondition.weather and monster.spawnCondition.weather ~= currentWeather then
				conditionsMet = false
			end
			if monster.spawnCondition.season and monster.spawnCondition.season ~= currentSeason then
				conditionsMet = false
			end
			if monster.spawnCondition.timeOfDay and monster.spawnCondition.timeOfDay ~= currentTimeOfDay then
				-- Relax time-of-day for now, make it a bonus instead of requirement
				conditionsMet = true
			end
		end

		if matchesRarity and (matchesSeed or seedData == nil) and conditionsMet then
			table.insert(eligible, monster)
		end
	end

	-- If no eligible monsters at this rarity, fall back to Normal
	if #eligible == 0 then
		for _, monster in pairs(MonsterDatabase) do
			if monster.rarity == "Normal" then
				local attributeMatch = true
				if seedData and seedData.attribute ~= "All" then
					attributeMatch = monster.attribute == seedData.attribute
				end
				if attributeMatch then
					table.insert(eligible, monster)
				end
			end
		end
	end

	-- Still empty? Return first Normal monster
	if #eligible == 0 then
		for _, monster in pairs(MonsterDatabase) do
			if monster.rarity == "Normal" then
				return monster
			end
		end
	end

	-- Random pick from eligible
	return eligible[math.random(#eligible)]
end

return MonsterService
```

- [ ] **Step 2: Create WeatherService.lua**

```lua
--!strict
--[[
	WeatherService — Weather & season management
	Changes weather periodically, tracks seasons
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local WeatherService = {}

local currentWeather = "Sunny"
local currentSeason = "Spring"
local weatherTimer = 0
local seasonStartTime = os.time()

function WeatherService.init()
	-- Determine initial season based on real date
	local month = tonumber(os.date("%m"))
	if month >= 3 and month <= 5 then
		currentSeason = "Spring"
	elseif month >= 6 and month <= 8 then
		currentSeason = "Summer"
	elseif month >= 9 and month <= 11 then
		currentSeason = "Autumn"
	else
		currentSeason = "Winter"
	end

	-- Setup remote for clients
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local weatherRemote = Instance.new("RemoteEvent")
	weatherRemote.Name = "WeatherUpdate"
	weatherRemote.Parent = remotes

	local getWeatherRemote = Instance.new("RemoteFunction")
	getWeatherRemote.Name = "GetWeather"
	getWeatherRemote.Parent = remotes
	getWeatherRemote.OnServerInvoke = function()
		return { weather = currentWeather, season = currentSeason }
	end

	-- Roll initial weather
	WeatherService.rollWeather()

	print("[WeatherService] Season: " .. currentSeason .. ", Weather: " .. currentWeather)
end

function WeatherService.update(dt: number)
	weatherTimer = weatherTimer + dt
	if weatherTimer >= GameConfig.Weather.ChangeInterval then
		weatherTimer = 0
		WeatherService.rollWeather()
	end
end

function WeatherService.rollWeather()
	local prevWeather = currentWeather

	-- Weighted random weather
	local roll = math.random()
	if roll < GameConfig.Weather.RainbowChance then
		currentWeather = "Rainbow"
	elseif roll < 0.30 then
		currentWeather = "Rainy"
	elseif roll < 0.45 then
		if currentSeason == "Winter" then
			currentWeather = "Snowy"
		else
			currentWeather = "Rainy"
		end
	elseif roll < 0.55 then
		currentWeather = "Stormy"
	else
		currentWeather = "Sunny"
	end

	-- Update MonsterService
	local ok, MonsterService = pcall(function()
		return require(game:GetService("ServerScriptService").Server.Services.MonsterService)
	end)
	if ok and MonsterService then
		MonsterService.setWeather(currentWeather)
		MonsterService.setSeason(currentSeason)
	end

	-- Notify all clients
	if currentWeather ~= prevWeather then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local weatherUpdate = remotes:FindFirstChild("WeatherUpdate")
			if weatherUpdate then
				for _, player in ipairs(Players:GetPlayers()) do
					weatherUpdate:FireClient(player, { weather = currentWeather, season = currentSeason })
				end
			end
		end
		print("[WeatherService] Weather changed: " .. prevWeather .. " → " .. currentWeather)
	end
end

function WeatherService.getWeather(): string
	return currentWeather
end

function WeatherService.getSeason(): string
	return currentSeason
end

return WeatherService
```

- [ ] **Step 3: Commit MonsterService + WeatherService**

```bash
git add src/server/Services/MonsterService.lua src/server/Services/WeatherService.lua
git commit -m "feat: MonsterService (rarity roll, spawn conditions) + WeatherService (weather/season cycle)"
```

---

## Task 6: ShopService — Monetization Backend

**Files:**
- Create: `src/server/Services/ShopService.lua`

- [ ] **Step 1: Create ShopService.lua**

```lua
--!strict
--[[
	ShopService — GamePass & Developer Product handling
	Manages all monetization transactions
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopPrices = require(Shared.Config.ShopPrices)

local ShopService = {}

-- GamePass IDs (set after publishing to Roblox)
-- These are placeholder IDs — replace with real IDs after creating in Roblox
local GAMEPASS_IDS = {
	vip_pass = 0, -- TODO: Set after creating GamePass
	mutation_4x = 0,
	lucky_gardener = 0,
	super_grow = 0,
	auto_water = 0,
}

-- Developer Product IDs (set after publishing)
local DEVPRODUCT_IDS = {
	basic_egg = 0, -- TODO: Set after creating
	gold_egg = 0,
	premium_seed_5 = 0,
	growth_boost_1h = 0,
	instant_hatch_3 = 0,
	garden_expand = 0,
	golden_soil_5 = 0,
	deco_fantasy = 0,
}

function ShopService.init()
	local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)

	-- Handle GamePass purchases
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, purchased: boolean)
		if not purchased then
			return
		end

		local passKey = nil
		for key, id in pairs(GAMEPASS_IDS) do
			if id == gamePassId then
				passKey = key
				break
			end
		end

		if passKey then
			local data = DataService.getData(player)
			if data then
				data.gamePasses[passKey] = true
				print("[ShopService] " .. player.Name .. " purchased GamePass: " .. passKey)
			end
		end
	end)

	-- Handle Developer Product purchases
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local data = DataService.getData(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local productKey = nil
		for key, id in pairs(DEVPRODUCT_IDS) do
			if id == receiptInfo.ProductId then
				productKey = key
				break
			end
		end

		if not productKey then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local success = ShopService.grantProduct(player, data, productKey)
		if success then
			print("[ShopService] " .. player.Name .. " purchased DevProduct: " .. productKey)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Check owned GamePasses on join
	Players.PlayerAdded:Connect(function(player: Player)
		task.wait(2) -- wait for data load
		ShopService.checkOwnedPasses(player)
	end)

	-- Setup shop remote
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local buySeedRemote = Instance.new("RemoteEvent")
	buySeedRemote.Name = "BuySeed"
	buySeedRemote.Parent = remotes
	buySeedRemote.OnServerEvent:Connect(function(player: Player, seedId: string)
		ShopService.buySeedWithCoins(player, seedId)
	end)

	print("[ShopService] Initialized")
end

function ShopService.grantProduct(player: Player, data: any, productKey: string): boolean
	local SeedDatabase = require(ReplicatedStorage:WaitForChild("Shared").Config.SeedDatabase)

	if productKey == "basic_egg" then
		-- Grant a random basic pet egg (placeholder for pet system)
		DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
		DataService.addCoins(player, 500) -- temporary: give coins instead
		return true
	elseif productKey == "gold_egg" then
		DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
		DataService.addCoins(player, 2000)
		return true
	elseif productKey == "premium_seed_5" then
		-- Grant 5 premium seeds (1 epic guaranteed)
		table.insert(data.seeds, "rainbow_seed")
		for _ = 1, 4 do
			local seedTypes = { "fire_seed", "water_seed", "grass_seed", "light_seed", "dark_seed" }
			table.insert(data.seeds, seedTypes[math.random(#seedTypes)])
		end
		return true
	elseif productKey == "growth_boost_1h" then
		-- Set temporary growth boost
		data._growthBoostUntil = os.time() + 3600
		return true
	elseif productKey == "instant_hatch_3" then
		data._instantHatchTickets = (data._instantHatchTickets or 0) + 3
		return true
	elseif productKey == "garden_expand" then
		local currentSize = GameConfig.Garden.InitialSize
		-- Logic to expand garden handled by GardenService
		data._pendingExpand = true
		return true
	elseif productKey == "golden_soil_5" then
		data._goldenSoilCount = (data._goldenSoilCount or 0) + 5
		return true
	elseif productKey == "deco_fantasy" then
		data._unlockedDecos = data._unlockedDecos or {}
		data._unlockedDecos.fantasy = true
		return true
	end

	return false
end

function ShopService.checkOwnedPasses(player: Player)
	local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
	local data = DataService.getData(player)
	if not data then
		return
	end

	for passKey, passId in pairs(GAMEPASS_IDS) do
		if passId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owns then
				data.gamePasses[passKey] = true
			end
		end
	end
end

function ShopService.buySeedWithCoins(player: Player, seedId: string)
	local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
	local SeedDatabase = require(ReplicatedStorage:WaitForChild("Shared").Config.SeedDatabase)

	local seedData = nil
	for _, seed in pairs(SeedDatabase) do
		if seed.id == seedId then
			seedData = seed
			break
		end
	end

	if not seedData or seedData.cost <= 0 then
		return
	end

	if DataService.spendCoins(player, seedData.cost) then
		local data = DataService.getData(player)
		if data then
			table.insert(data.seeds, seedId)
			print("[ShopService] " .. player.Name .. " bought seed: " .. seedId .. " for " .. seedData.cost .. " coins")
		end
	end
end

return ShopService
```

- [ ] **Step 2: Commit ShopService**

```bash
git add src/server/Services/ShopService.lua
git commit -m "feat: ShopService (GamePass, DevProduct, coin shop, receipt processing)"
```

---

## Task 7: Client Bootstrap & UIController

**Files:**
- Create: `src/client/init.client.lua`
- Create: `src/client/Controllers/UIController.lua`
- Create: `src/replicated-first/LoadingScreen.client.lua`

- [ ] **Step 1: Create client init.client.lua**

```lua
--!strict
--[[
	Monster Garden — Client Bootstrap
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
if not Shared then
	warn("[Client] ✗ Shared modules not found!")
	return
end

-- Safe require wrapper
local function safeRequire(path: ModuleScript, name: string): any?
	local ok, result = pcall(function()
		return require(path)
	end)
	if ok then
		print("[Client] ✓ Loaded: " .. name)
		return result
	else
		warn("[Client] ✗ FAILED: " .. name .. " → " .. tostring(result))
		return nil
	end
end

local function safeInit(mod: any?, name: string)
	if not mod then
		return
	end
	if not mod.init then
		return
	end
	local ok, err = pcall(function()
		mod.init()
	end)
	if ok then
		print("[Client] ✓ Init: " .. name)
	else
		warn("[Client] ✗ Init FAILED: " .. name .. " → " .. tostring(err))
	end
end

print("[Client] === Monster Garden Client Starting ===")

-- Load controllers
local UIController = safeRequire(script.Controllers.UIController, "UIController")
local GardenController = safeRequire(script.Controllers.GardenController, "GardenController")
local ShopController = safeRequire(script.Controllers.ShopController, "ShopController")
local CollectionController = safeRequire(script.Controllers.CollectionController, "CollectionController")

-- Initialize
safeInit(UIController, "UIController")
safeInit(GardenController, "GardenController")
safeInit(ShopController, "ShopController")
safeInit(CollectionController, "CollectionController")

print("[Client] === Monster Garden Client Ready ===")
```

- [ ] **Step 2: Create UIController.lua**

```lua
--!strict
--[[
	UIController — HUD and screen management
	Manages: top bar (coins, weather), navigation buttons, notifications
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Languages = require(Shared.Localization.Languages)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIController = {}

local screenGui: ScreenGui? = nil

function UIController.init()
	-- Create main ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MonsterGardenUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	UIController.createHUD()
	UIController.createNavBar()
	UIController.setupRemoteListeners()

	print("[UIController] UI created")
end

function UIController.createHUD()
	if not screenGui then
		return
	end

	-- Top bar frame
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 50)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	topBar.BackgroundTransparency = 0.2
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui

	local topBarCorner = Instance.new("UICorner")
	topBarCorner.CornerRadius = UDim.new(0, 0)
	topBarCorner.Parent = topBar

	-- Coins display
	local coinsFrame = Instance.new("Frame")
	coinsFrame.Name = "CoinsFrame"
	coinsFrame.Size = UDim2.new(0, 160, 0, 36)
	coinsFrame.Position = UDim2.new(0, 10, 0.5, -18)
	coinsFrame.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	coinsFrame.BackgroundTransparency = 0.3
	coinsFrame.Parent = topBar

	local coinsCorner = Instance.new("UICorner")
	coinsCorner.CornerRadius = UDim.new(0, 8)
	coinsCorner.Parent = coinsFrame

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.new(1, -10, 1, 0)
	coinsLabel.Position = UDim2.new(0, 10, 0, 0)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text = "🪙 500"
	coinsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	coinsLabel.TextSize = 18
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinsLabel.Parent = coinsFrame

	-- Weather display
	local weatherFrame = Instance.new("Frame")
	weatherFrame.Name = "WeatherFrame"
	weatherFrame.Size = UDim2.new(0, 120, 0, 36)
	weatherFrame.Position = UDim2.new(1, -140, 0.5, -18)
	weatherFrame.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	weatherFrame.BackgroundTransparency = 0.3
	weatherFrame.Parent = topBar

	local weatherCorner = Instance.new("UICorner")
	weatherCorner.CornerRadius = UDim.new(0, 8)
	weatherCorner.Parent = weatherFrame

	local weatherLabel = Instance.new("TextLabel")
	weatherLabel.Name = "WeatherLabel"
	weatherLabel.Size = UDim2.new(1, -10, 1, 0)
	weatherLabel.Position = UDim2.new(0, 10, 0, 0)
	weatherLabel.BackgroundTransparency = 1
	weatherLabel.Text = "☀️ 晴れ"
	weatherLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	weatherLabel.TextSize = 16
	weatherLabel.Font = Enum.Font.GothamBold
	weatherLabel.TextXAlignment = Enum.TextXAlignment.Left
	weatherLabel.Parent = weatherFrame

	-- Monster count
	local monsterFrame = Instance.new("Frame")
	monsterFrame.Name = "MonsterFrame"
	monsterFrame.Size = UDim2.new(0, 140, 0, 36)
	monsterFrame.Position = UDim2.new(0, 180, 0.5, -18)
	monsterFrame.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
	monsterFrame.BackgroundTransparency = 0.3
	monsterFrame.Parent = topBar

	local monsterCorner = Instance.new("UICorner")
	monsterCorner.CornerRadius = UDim.new(0, 8)
	monsterCorner.Parent = monsterFrame

	local monsterLabel = Instance.new("TextLabel")
	monsterLabel.Name = "MonsterLabel"
	monsterLabel.Size = UDim2.new(1, -10, 1, 0)
	monsterLabel.Position = UDim2.new(0, 10, 0, 0)
	monsterLabel.BackgroundTransparency = 1
	monsterLabel.Text = "🐾 0/250"
	monsterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	monsterLabel.TextSize = 16
	monsterLabel.Font = Enum.Font.GothamBold
	monsterLabel.TextXAlignment = Enum.TextXAlignment.Left
	monsterLabel.Parent = monsterFrame
end

function UIController.createNavBar()
	if not screenGui then
		return
	end

	-- Bottom navigation bar
	local navBar = Instance.new("Frame")
	navBar.Name = "NavBar"
	navBar.Size = UDim2.new(1, -20, 0, 60)
	navBar.Position = UDim2.new(0, 10, 1, -70)
	navBar.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	navBar.BackgroundTransparency = 0.2
	navBar.BorderSizePixel = 0
	navBar.Parent = screenGui

	local navCorner = Instance.new("UICorner")
	navCorner.CornerRadius = UDim.new(0, 12)
	navCorner.Parent = navBar

	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Padding = UDim.new(0, 15)
	navLayout.Parent = navBar

	local buttons = {
		{ name = "Garden", icon = "🌱", label = "庭園" },
		{ name = "Collection", icon = "📖", label = "図鑑" },
		{ name = "Shop", icon = "🛒", label = "ショップ" },
		{ name = "Settings", icon = "⚙️", label = "設定" },
	}

	for _, btn in ipairs(buttons) do
		local button = Instance.new("TextButton")
		button.Name = btn.name .. "Button"
		button.Size = UDim2.new(0, 70, 0, 50)
		button.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
		button.BackgroundTransparency = 0.5
		button.Text = btn.icon .. "\n" .. btn.label
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 12
		button.Font = Enum.Font.GothamBold
		button.Parent = navBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = button

		button.MouseButton1Click:Connect(function()
			UIController.onNavButtonClicked(btn.name)
		end)
	end
end

function UIController.onNavButtonClicked(screenName: string)
	print("[UIController] Nav: " .. screenName)
	-- Screen switching handled by respective controllers
end

function UIController.setupRemoteListeners()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotes then
		return
	end

	-- Weather updates
	local weatherUpdate = remotes:WaitForChild("WeatherUpdate", 5)
	if weatherUpdate then
		weatherUpdate.OnClientEvent:Connect(function(weatherData)
			UIController.updateWeatherDisplay(weatherData)
		end)
	end

	-- Monster hatched notification
	local monsterHatched = remotes:WaitForChild("MonsterHatched", 5)
	if monsterHatched then
		monsterHatched.OnClientEvent:Connect(function(monster)
			UIController.showHatchNotification(monster)
		end)
	end

	-- Get initial weather
	local getWeather = remotes:WaitForChild("GetWeather", 5)
	if getWeather then
		local ok, result = pcall(function()
			return getWeather:InvokeServer()
		end)
		if ok and result then
			UIController.updateWeatherDisplay(result)
		end
	end

	-- Update coins from leaderstats
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local coins = leaderstats:WaitForChild("Coins", 5)
		if coins then
			coins.Changed:Connect(function(newValue)
				UIController.updateCoinsDisplay(newValue)
			end)
			UIController.updateCoinsDisplay(coins.Value)
		end

		local monsters = leaderstats:WaitForChild("Monsters", 5)
		if monsters then
			monsters.Changed:Connect(function(newValue)
				UIController.updateMonsterCount(newValue)
			end)
			UIController.updateMonsterCount(monsters.Value)
		end
	end
end

function UIController.updateCoinsDisplay(amount: number)
	if not screenGui then
		return
	end
	local label = screenGui:FindFirstChild("TopBar")
	if label then
		local coinsFrame = label:FindFirstChild("CoinsFrame")
		if coinsFrame then
			local coinsLabel = coinsFrame:FindFirstChild("CoinsLabel")
			if coinsLabel then
				coinsLabel.Text = "🪙 " .. tostring(amount)
			end
		end
	end
end

function UIController.updateWeatherDisplay(weatherData: any)
	if not screenGui then
		return
	end
	local weatherIcons = {
		Sunny = "☀️",
		Rainy = "🌧️",
		Snowy = "❄️",
		Stormy = "⛈️",
		Rainbow = "🌈",
	}
	local weatherNames = {
		Sunny = "晴れ",
		Rainy = "雨",
		Snowy = "雪",
		Stormy = "嵐",
		Rainbow = "虹",
	}

	local icon = weatherIcons[weatherData.weather] or "☀️"
	local name = weatherNames[weatherData.weather] or weatherData.weather

	local topBar = screenGui:FindFirstChild("TopBar")
	if topBar then
		local weatherFrame = topBar:FindFirstChild("WeatherFrame")
		if weatherFrame then
			local weatherLabel = weatherFrame:FindFirstChild("WeatherLabel")
			if weatherLabel then
				weatherLabel.Text = icon .. " " .. name
			end
		end
	end
end

function UIController.updateMonsterCount(count: number)
	if not screenGui then
		return
	end
	local topBar = screenGui:FindFirstChild("TopBar")
	if topBar then
		local monsterFrame = topBar:FindFirstChild("MonsterFrame")
		if monsterFrame then
			local monsterLabel = monsterFrame:FindFirstChild("MonsterLabel")
			if monsterLabel then
				monsterLabel.Text = "🐾 " .. tostring(count) .. "/250"
			end
		end
	end
end

function UIController.showHatchNotification(monster: any)
	if not screenGui then
		return
	end

	local rarityColors = {
		Normal = Color3.fromRGB(200, 200, 200),
		Rare = Color3.fromRGB(100, 150, 255),
		Epic = Color3.fromRGB(180, 100, 255),
		Legend = Color3.fromRGB(255, 200, 50),
		Mythic = Color3.fromRGB(255, 100, 150),
	}

	local notif = Instance.new("Frame")
	notif.Name = "HatchNotification"
	notif.Size = UDim2.new(0, 300, 0, 80)
	notif.Position = UDim2.new(0.5, -150, 0.3, 0)
	notif.BackgroundColor3 = rarityColors[monster.rarity] or Color3.fromRGB(200, 200, 200)
	notif.BackgroundTransparency = 0.1
	notif.Parent = screenGui

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(0, 12)
	notifCorner.Parent = notif

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -20, 1, 0)
	text.Position = UDim2.new(0, 10, 0, 0)
	text.BackgroundTransparency = 1
	text.Text = "🎉 " .. (monster.name or "???") .. " を手に入れた！\n(" .. (monster.rarity or "Normal") .. ")"
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextSize = 18
	text.Font = Enum.Font.GothamBold
	text.TextWrapped = true
	text.Parent = notif

	-- Auto-dismiss after 3 seconds
	task.delay(3, function()
		if notif and notif.Parent then
			notif:Destroy()
		end
	end)
end

return UIController
```

- [ ] **Step 3: Create LoadingScreen.client.lua**

```lua
--!strict
--[[
	Loading Screen — Shows while game assets load
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove default loading screen
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Create loading screen
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "LoadingScreen"
loadingGui.IgnoreGuiInset = true
loadingGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
bg.BorderSizePixel = 0
bg.Parent = loadingGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 60)
title.Position = UDim2.new(0, 0, 0.35, 0)
title.BackgroundTransparency = 1
title.Text = "🌱 Monster Garden 🌱"
title.TextColor3 = Color3.fromRGB(100, 255, 150)
title.TextSize = 36
title.Font = Enum.Font.GothamBold
title.Parent = bg

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 30)
subtitle.Position = UDim2.new(0, 0, 0.45, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "育てて、集めて、見せびらかせ！"
subtitle.TextColor3 = Color3.fromRGB(200, 200, 255)
subtitle.TextSize = 18
subtitle.Font = Enum.Font.Gotham
subtitle.Parent = bg

local loadingText = Instance.new("TextLabel")
loadingText.Name = "LoadingText"
loadingText.Size = UDim2.new(1, 0, 0, 30)
loadingText.Position = UDim2.new(0, 0, 0.55, 0)
loadingText.BackgroundTransparency = 1
loadingText.Text = "Loading..."
loadingText.TextColor3 = Color3.fromRGB(150, 150, 200)
loadingText.TextSize = 14
loadingText.Font = Enum.Font.Gotham
loadingText.Parent = bg

-- Wait for game to load
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Brief display then fade out
task.wait(1)

for i = 1, 10 do
	bg.BackgroundTransparency = i / 10
	title.TextTransparency = i / 10
	subtitle.TextTransparency = i / 10
	loadingText.TextTransparency = i / 10
	task.wait(0.05)
end

loadingGui:Destroy()
```

- [ ] **Step 4: Commit client bootstrap + UI + loading screen**

```bash
git add src/client/ src/replicated-first/
git commit -m "feat: client bootstrap + UIController (HUD, nav, notifications) + loading screen"
```

---

## Task 8: GardenController — Plot Interaction

**Files:**
- Create: `src/client/Controllers/GardenController.lua`

- [ ] **Step 1: Create GardenController.lua**

```lua
--!strict
--[[
	GardenController — Garden plot interaction on client side
	Handles: plot clicks, seed selection, visual updates
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeedDatabase = require(Shared.Config.SeedDatabase)
local Languages = require(Shared.Localization.Languages)

local GardenController = {}

local gardenData = {}
local selectedSeed: string? = nil
local gardenUI: Frame? = nil

local STAGE_COLORS = {
	Seed = Color3.fromRGB(139, 90, 43),
	Sprout = Color3.fromRGB(100, 200, 100),
	Bud = Color3.fromRGB(200, 150, 255),
	Egg = Color3.fromRGB(255, 220, 100),
	Juvenile = Color3.fromRGB(150, 200, 255),
	Adult = Color3.fromRGB(100, 255, 200),
	Ultimate = Color3.fromRGB(255, 100, 255),
}

local STAGE_ICONS = {
	Seed = "🌰",
	Sprout = "🌱",
	Bud = "🌸",
	Egg = "🥚",
	Juvenile = "🐣",
	Adult = "🐾",
	Ultimate = "⭐",
}

function GardenController.init()
	GardenController.createGardenGrid()
	GardenController.createSeedSelector()
	GardenController.setupRemoteListeners()
	print("[GardenController] Initialized")
end

function GardenController.createGardenGrid()
	local mainUI = playerGui:WaitForChild("MonsterGardenUI", 10)
	if not mainUI then
		return
	end

	gardenUI = Instance.new("Frame")
	gardenUI.Name = "GardenGrid"
	gardenUI.Size = UDim2.new(0, 320, 0, 320)
	gardenUI.Position = UDim2.new(0.5, -160, 0.5, -180)
	gardenUI.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
	gardenUI.BackgroundTransparency = 0.3
	gardenUI.Parent = mainUI

	local gardenCorner = Instance.new("UICorner")
	gardenCorner.CornerRadius = UDim.new(0, 12)
	gardenCorner.Parent = gardenUI

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 100, 0, 100)
	gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gardenUI

	-- Create 3x3 grid of plots
	for i = 1, 9 do
		local plot = Instance.new("TextButton")
		plot.Name = "Plot_" .. i
		plot.LayoutOrder = i
		plot.BackgroundColor3 = Color3.fromRGB(100, 80, 50)
		plot.Text = "空きマス\n🌱"
		plot.TextColor3 = Color3.fromRGB(200, 200, 200)
		plot.TextSize = 14
		plot.Font = Enum.Font.GothamBold
		plot.TextWrapped = true
		plot.Parent = gardenUI

		local plotCorner = Instance.new("UICorner")
		plotCorner.CornerRadius = UDim.new(0, 8)
		plotCorner.Parent = plot

		local plotStroke = Instance.new("UIStroke")
		plotStroke.Color = Color3.fromRGB(60, 50, 30)
		plotStroke.Thickness = 2
		plotStroke.Parent = plot

		plot.MouseButton1Click:Connect(function()
			GardenController.onPlotClicked(i)
		end)
	end
end

function GardenController.createSeedSelector()
	local mainUI = playerGui:WaitForChild("MonsterGardenUI", 10)
	if not mainUI then
		return
	end

	local seedBar = Instance.new("Frame")
	seedBar.Name = "SeedBar"
	seedBar.Size = UDim2.new(0, 320, 0, 50)
	seedBar.Position = UDim2.new(0.5, -160, 0.5, 150)
	seedBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	seedBar.BackgroundTransparency = 0.3
	seedBar.Parent = mainUI

	local seedCorner = Instance.new("UICorner")
	seedCorner.CornerRadius = UDim.new(0, 8)
	seedCorner.Parent = seedBar

	local seedLayout = Instance.new("UIListLayout")
	seedLayout.FillDirection = Enum.FillDirection.Horizontal
	seedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	seedLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	seedLayout.Padding = UDim.new(0, 5)
	seedLayout.Parent = seedBar

	local seedIcons = {
		fire_seed = { icon = "🔥", name = "火" },
		water_seed = { icon = "💧", name = "水" },
		grass_seed = { icon = "🌿", name = "草" },
		light_seed = { icon = "✨", name = "光" },
		dark_seed = { icon = "🌙", name = "闇" },
	}

	for seedId, info in pairs(seedIcons) do
		local seedBtn = Instance.new("TextButton")
		seedBtn.Name = "Seed_" .. seedId
		seedBtn.Size = UDim2.new(0, 55, 0, 40)
		seedBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		seedBtn.Text = info.icon .. "\n" .. info.name
		seedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		seedBtn.TextSize = 11
		seedBtn.Font = Enum.Font.GothamBold
		seedBtn.Parent = seedBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = seedBtn

		seedBtn.MouseButton1Click:Connect(function()
			GardenController.selectSeed(seedId)
		end)
	end
end

function GardenController.selectSeed(seedId: string)
	selectedSeed = seedId
	print("[GardenController] Selected seed: " .. seedId)

	-- Visual feedback: highlight selected seed button
	local mainUI = playerGui:FindFirstChild("MonsterGardenUI")
	if mainUI then
		local seedBar = mainUI:FindFirstChild("SeedBar")
		if seedBar then
			for _, btn in ipairs(seedBar:GetChildren()) do
				if btn:IsA("TextButton") then
					if btn.Name == "Seed_" .. seedId then
						btn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
					else
						btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
					end
				end
			end
		end
	end
end

function GardenController.onPlotClicked(plotIndex: number)
	local plot = gardenData[tostring(plotIndex)]

	if not plot then
		-- Empty plot: plant selected seed
		if selectedSeed then
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			if remotes then
				local plantRemote = remotes:FindFirstChild("PlantSeed")
				if plantRemote then
					plantRemote:FireServer(plotIndex, selectedSeed)
				end
			end
		else
			print("[GardenController] Select a seed first!")
		end
	elseif plot.stage == "Egg" then
		-- Egg: hatch it
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local hatchRemote = remotes:FindFirstChild("HatchEgg")
			if hatchRemote then
				hatchRemote:FireServer(plotIndex)
			end
		end
	elseif plot.stage == "Seed" or plot.stage == "Sprout" then
		-- Water it
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local waterRemote = remotes:FindFirstChild("WaterPlot")
			if waterRemote then
				waterRemote:FireServer(plotIndex)
			end
		end
	end
end

function GardenController.updatePlotVisual(plotIndex: number, plotData: any?)
	if not gardenUI then
		return
	end

	local plotBtn = gardenUI:FindFirstChild("Plot_" .. plotIndex)
	if not plotBtn then
		return
	end

	if not plotData then
		plotBtn.Text = "空きマス\n🌱"
		plotBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 50)
		return
	end

	local stage = plotData.stage or "Seed"
	local icon = STAGE_ICONS[stage] or "❓"
	local color = STAGE_COLORS[stage] or Color3.fromRGB(100, 80, 50)

	local stageText = Languages.getText("growth_" .. string.lower(stage))
	plotBtn.Text = icon .. "\n" .. stageText
	plotBtn.BackgroundColor3 = color

	if stage == "Egg" then
		plotBtn.Text = icon .. "\nタップで孵化！"
	end
end

function GardenController.setupRemoteListeners()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotes then
		return
	end

	local gardenUpdate = remotes:WaitForChild("GardenUpdate", 5)
	if gardenUpdate then
		gardenUpdate.OnClientEvent:Connect(function(newGardenData)
			gardenData = newGardenData
			for i = 1, 9 do
				local plotData = newGardenData[tostring(i)]
				GardenController.updatePlotVisual(i, plotData)
			end
		end)
	end
end

return GardenController
```

- [ ] **Step 2: Create placeholder ShopController.lua and CollectionController.lua**

`src/client/Controllers/ShopController.lua`:
```lua
--!strict
--[[
	ShopController — Shop UI (α版: skeleton only)
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopPrices = require(Shared.Config.ShopPrices)

local player = Players.LocalPlayer

local ShopController = {}

function ShopController.init()
	print("[ShopController] Initialized (skeleton)")
end

function ShopController.promptGamePass(passId: number)
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
end

function ShopController.promptProduct(productId: number)
	pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end

return ShopController
```

`src/client/Controllers/CollectionController.lua`:
```lua
--!strict
--[[
	CollectionController — Monster collection/codex UI (α版: skeleton only)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterDatabase = require(Shared.Config.MonsterDatabase)

local CollectionController = {}

function CollectionController.init()
	local count = 0
	for _ in pairs(MonsterDatabase) do
		count = count + 1
	end
	print("[CollectionController] Initialized — " .. count .. " monsters in database")
end

return CollectionController
```

- [ ] **Step 3: Commit GardenController + placeholder controllers**

```bash
git add src/client/Controllers/
git commit -m "feat: GardenController (3x3 grid, plot interaction, seed selector) + Shop/Collection skeletons"
```

---

## Task 9: README & Final Commit

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README.md**

```markdown
# 🌱 Monster Garden

モンスター育成 × ガーデニングシミュレーター for Roblox

## Overview

| Item | Detail |
|------|--------|
| Genre | Monster Breeding × Gardening Simulator |
| Platform | Roblox (PC / Mobile / PS / Xbox) |
| Target | All ages (8-14 core) |
| Players | 50 per server |
| Languages | 日本語, English |

## Core Loop

```
Plant Seed → Water & Care → Monster Hatches → Raise & Evolve → Display in Garden
```

## Features (α版)

- 🌰 3×3 Garden Grid with planting, watering, and growth
- 🐾 20 Monster species across 5 attributes (Fire/Water/Grass/Light/Dark)
- 🎲 Rarity system (Normal → Rare → Epic → Legend → Mythic)
- 🌦️ Dynamic weather & season system affecting spawns
- 💰 Shop skeleton (GamePass + DevProduct ready)
- 💾 DataStore persistence with offline growth
- 🌍 Japanese + English localization

## Tech Stack

| Tool | Version |
|------|---------|
| Roblox Studio | Latest |
| Rojo | 7.4.4 |
| Selene | 0.27.1 |
| StyLua | 0.20.0 |
| Aftman | Latest |

## Setup

```bash
aftman install
rojo serve
# Open Roblox Studio → Connect to Rojo
```

## Project Structure

```
src/
├── server/Services/     — DataService, GardenService, MonsterService, WeatherService, ShopService
├── client/Controllers/  — UIController, GardenController, ShopController, CollectionController
├── shared/Config/       — GameConfig, MonsterDatabase, SeedDatabase, ShopPrices
└── replicated-first/    — LoadingScreen
```

## License

Proprietary — Tokio-Partner
```

- [ ] **Step 2: Final commit**

```bash
git add README.md
git commit -m "docs: README with project overview, setup, and structure"
git push
```

---

## Verification

1. **Rojo build test**: `rojo build -o game.rbxl` — ビルドがエラーなく完了すること
2. **Roblox Studio test**: Rojo serve → Studio接続 → プレイテスト
   - サーバーログに全Service ✓ 表示
   - クライアントログに全Controller ✓ 表示
   - HUD（コイン・天候・モンスター数）表示
   - 3×3庭園グリッド表示
   - シード選択 → 空きマスクリック → 種が植わる
   - 成長が自動進行（5分後にSproutへ）
   - Egg段階でタップ → モンスター孵化通知
   - 天候が10分ごとに変化
   - leaderstatsにCoins/Monsters表示
3. **データ永続化**: プレイ → 退出 → 再参加でデータが保持されること
