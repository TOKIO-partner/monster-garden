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
}
