--[[
	GameConfig
	ゲーム全体の定数設定（ふるまいを持たない純粋テーブル）。
	v2: オープンワールド化に伴い World / Spawn / Capture セクションを追加。
]]

return {
	Garden = {
		InitialSize = 3,
		MaxPlots = 9,
		GrowthTickInterval = 1,
		OfflineGrowthEnabled = true,
		OfflineGrowthRate = 1.0,
	},

	Growth = {
		SeedToSprout = 300,
		SproutToBud = 900,
		BudToEgg = 1800,
		EggToHatch = 0,
		HatchToJuvenile = 3600,
		JuvenileToAdult = 7200,
	},

	Soil = {
		Normal = { rarityBonus = 0, cost = 0 },
		Magic = { rarityBonus = 0.10, cost = 500 },
		Golden = { rarityBonus = 0.25, cost = 0 },
	},

	Weather = {
		Types = { "Sunny", "Rainy", "Snowy", "Stormy", "Rainbow" },
		ChangeInterval = 600,
		RainbowChance = 0.05,
	},

	Season = {
		Types = { "Spring", "Summer", "Autumn", "Winter" },
		DurationSeconds = 604800,
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

	-- ============================================================ v2: open world

	World = {
		--- 庭園島の空中Y座標
		IslandHeight = 1000,
		--- 島スロット間の間隔（studs）。StreamingEnabled で他人の島は自動ストリームアウト
		IslandSpacing = 2048,
		--- サーバー最大人数分の島スロット
		MaxIslandSlots = 50,
		--- ワールド側スポーン地点（Meadow 中心付近）
		WorldSpawn = { x = 0, y = 8, z = 40 },
		--- Terrain 生成の決定論シード
		TerrainSeed = 20260705,
	},

	Spawn = {
		--- バイオーム毎の野生モンスター同時上限
		MaxPerBiome = 8,
		--- スポーン充足チェック間隔（秒）
		RespawnCheckInterval = 5,
		--- 放置デスポーンまでの秒数
		DespawnAfter = 300,
		--- レアシード採取ノードのバイオーム毎上限
		MaxSeedNodesPerBiome = 3,
	},

	Capture = {
		--- 捕獲リクエストの許容距離（studs）。サーバー検証用
		MaxDistance = 15,
		--- レアリティ別の基本捕獲成功率
		RatesByRarity = {
			Normal = 0.90,
			Rare = 0.60,
			Epic = 0.35,
			Legend = 0.15,
			Mythic = 0.05,
		},
		--- lucky_gardener ゲームパス保持時の成功率加算
		LuckyGardenerBonus = 0.10,
	},
}
