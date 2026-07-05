--[[
	SpawnPlanner.spec
	野生スポーン候補選定ロジックの単体テスト（TestEZ）。
]]

return function()
	local SpawnPlanner = require(script.Parent.SpawnPlanner)

	--- テスト用ミニモンスターDB
	local MONSTERS = {
		{ id = "leaf_cat", attribute = "Grass", rarity = "Normal", spawnCondition = { season = "Spring" } },
		{ id = "sun_bird", attribute = "Light", rarity = "Rare", spawnCondition = { weather = "Sunny" } },
		{ id = "flame_bunny", attribute = "Fire", rarity = "Normal", spawnCondition = { weather = "Sunny" } },
		{ id = "moss_bear", attribute = "Grass", rarity = "Rare" }, -- 条件なし = 常時
		{
			id = "phoenix_chick",
			attribute = "Fire",
			rarity = "Legend",
			spawnCondition = { weather = "Sunny", season = "Summer", soilType = "Golden", timeOfDay = "Noon" },
		},
	}

	local MEADOW_ATTRIBUTES = { "Grass", "Light" }
	local VOLCANO_ATTRIBUTES = { "Fire" }

	local function fixedRng(value)
		return function()
			return value
		end
	end

	describe("matchesCondition", function()
		it("nil 条件は常に許可", function()
			local environment = { weather = "Rainy", season = "Winter", timeOfDay = "Night" }
			expect(SpawnPlanner.matchesCondition(nil, environment)).to.equal(true)
		end)

		it("soilType は野生では無視される", function()
			local condition = { weather = "Sunny", soilType = "Golden" }
			local environment = { weather = "Sunny", season = "Spring", timeOfDay = "Day" }
			expect(SpawnPlanner.matchesCondition(condition, environment)).to.equal(true)
		end)

		it("天候不一致は拒否", function()
			local condition = { weather = "Sunny" }
			local environment = { weather = "Rainy", season = "Spring", timeOfDay = "Day" }
			expect(SpawnPlanner.matchesCondition(condition, environment)).to.equal(false)
		end)
	end)

	describe("eligibleSpecies", function()
		it("バイオーム属性と環境条件で絞り込む", function()
			local environment = { weather = "Sunny", season = "Spring", timeOfDay = "Day" }
			local eligible = SpawnPlanner.eligibleSpecies(MONSTERS, MEADOW_ATTRIBUTES, environment)
			-- leaf_cat(春OK), sun_bird(晴れOK), moss_bear(常時) の3体。Fire属性は除外
			expect(#eligible).to.equal(3)
		end)

		it("環境が合わなければ候補が減る", function()
			local environment = { weather = "Rainy", season = "Winter", timeOfDay = "Day" }
			local eligible = SpawnPlanner.eligibleSpecies(MONSTERS, MEADOW_ATTRIBUTES, environment)
			-- moss_bear のみ
			expect(#eligible).to.equal(1)
			expect(eligible[1].id).to.equal("moss_bear")
		end)

		it("timeOfDay 条件も照合する（phoenix_chick は Noon 限定）", function()
			local environmentDay = { weather = "Sunny", season = "Summer", timeOfDay = "Day" }
			local eligibleDay = SpawnPlanner.eligibleSpecies(MONSTERS, VOLCANO_ATTRIBUTES, environmentDay)
			expect(#eligibleDay).to.equal(1) -- flame_bunny のみ

			local environmentNoon = { weather = "Sunny", season = "Summer", timeOfDay = "Noon" }
			local eligibleNoon = SpawnPlanner.eligibleSpecies(MONSTERS, VOLCANO_ATTRIBUTES, environmentNoon)
			expect(#eligibleNoon).to.equal(2) -- flame_bunny + phoenix_chick（soilType は無視）
		end)
	end)

	describe("fallbackSpecies", function()
		it("環境条件を無視して属性のみで返す", function()
			local fallback = SpawnPlanner.fallbackSpecies(MONSTERS, VOLCANO_ATTRIBUTES)
			expect(#fallback).to.equal(2)
		end)
	end)

	describe("pickSpawn", function()
		it("空候補は nil", function()
			expect(SpawnPlanner.pickSpawn({}, fixedRng(0.5))).to.equal(nil)
		end)

		it("レアリティ重みで抽選する（Normal 優勢）", function()
			local eligible = {
				{ id = "a", rarity = "Normal" }, -- weight 60
				{ id = "b", rarity = "Legend" }, -- weight 4
			}
			expect(SpawnPlanner.pickSpawn(eligible, fixedRng(0.1)).id).to.equal("a")
			expect(SpawnPlanner.pickSpawn(eligible, fixedRng(0.99)).id).to.equal("b")
		end)
	end)

	describe("deficit", function()
		it("不足数を返す（負にならない）", function()
			expect(SpawnPlanner.deficit(3, 8)).to.equal(5)
			expect(SpawnPlanner.deficit(9, 8)).to.equal(0)
		end)
	end)
end
