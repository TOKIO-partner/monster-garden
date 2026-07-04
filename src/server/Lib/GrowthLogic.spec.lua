--[[
	GrowthLogic.spec
	成長計算ロジックの単体テスト（TestEZ）。
]]

return function()
	local GrowthLogic = require(script.Parent.GrowthLogic)

	local DURATIONS = {
		Seed = 300,
		Sprout = 900,
		Bud = 1800,
		Egg = 0,
		Juvenile = 3600,
		Adult = 7200,
	}

	describe("stageIndex / nextStage", function()
		it("ステージ順序を正しく返す", function()
			expect(GrowthLogic.stageIndex("Seed")).to.equal(1)
			expect(GrowthLogic.stageIndex("Ultimate")).to.equal(7)
			expect(GrowthLogic.nextStage("Seed")).to.equal("Sprout")
			expect(GrowthLogic.nextStage("Adult")).to.equal("Ultimate")
		end)

		it("最終ステージ・未知ステージは nil", function()
			expect(GrowthLogic.nextStage("Ultimate")).to.equal(nil)
			expect(GrowthLogic.nextStage("Bogus")).to.equal(nil)
			expect(GrowthLogic.stageIndex("Bogus")).to.equal(nil)
		end)
	end)

	describe("isManualStage", function()
		it("Egg と Ultimate のみ手動", function()
			expect(GrowthLogic.isManualStage("Egg")).to.equal(true)
			expect(GrowthLogic.isManualStage("Ultimate")).to.equal(true)
			expect(GrowthLogic.isManualStage("Seed")).to.equal(false)
		end)
	end)

	describe("advance", function()
		it("ステージ内の進捗を積む", function()
			local plot = { stage = "Seed", growthProgress = 0 }
			local changed = GrowthLogic.advance(plot, 100, 1.0, DURATIONS)
			expect(changed).to.equal(false)
			expect(plot.stage).to.equal("Seed")
			expect(plot.growthProgress).to.equal(100)
		end)

		it("必要秒数に達したら次ステージへ進む", function()
			local plot = { stage = "Seed", growthProgress = 250 }
			local changed = GrowthLogic.advance(plot, 50, 1.0, DURATIONS)
			expect(changed).to.equal(true)
			expect(plot.stage).to.equal("Sprout")
			expect(plot.growthProgress).to.equal(0)
		end)

		it("複数ステージをキャリーオーバーで一気に進む", function()
			local plot = { stage = "Seed", growthProgress = 0 }
			-- Seed(300) + Sprout(900) + 100 = 1300秒
			GrowthLogic.advance(plot, 1300, 1.0, DURATIONS)
			expect(plot.stage).to.equal("Bud")
			expect(plot.growthProgress).to.equal(100)
		end)

		it("Egg で停止する（自動進行しない）", function()
			local plot = { stage = "Seed", growthProgress = 0 }
			GrowthLogic.advance(plot, 999999, 1.0, DURATIONS)
			expect(plot.stage).to.equal("Egg")
		end)

		it("倍率が適用される", function()
			local plot = { stage = "Seed", growthProgress = 0 }
			local changed = GrowthLogic.advance(plot, 150, 2.0, DURATIONS)
			expect(changed).to.equal(true)
			expect(plot.stage).to.equal("Sprout")
		end)

		it("不正な plot は無視する", function()
			expect(GrowthLogic.advance(nil, 100, 1.0, DURATIONS)).to.equal(false)
			expect(GrowthLogic.advance({}, 100, 1.0, DURATIONS)).to.equal(false)
		end)
	end)

	describe("applyOfflineGrowth", function()
		it("全プロットに適用し変化プロットを返す", function()
			local garden = {
				[1] = { stage = "Seed", growthProgress = 0 },
				[2] = { stage = "Egg", growthProgress = 0 },
				[3] = { stage = "Sprout", growthProgress = 890 },
			}
			local changedPlots = GrowthLogic.applyOfflineGrowth(garden, 400, DURATIONS)
			expect(changedPlots[1]).to.equal(true) -- Seed(300) → Sprout
			expect(changedPlots[2]).to.equal(nil) -- Egg は停止
			expect(changedPlots[3]).to.equal(true) -- Sprout 残り10秒 → Bud
			expect(garden[2].stage).to.equal("Egg")
		end)

		it("オフライン秒数 0 以下は何もしない", function()
			local garden = { [1] = { stage = "Seed", growthProgress = 0 } }
			local changedPlots = GrowthLogic.applyOfflineGrowth(garden, 0, DURATIONS)
			expect(next(changedPlots)).to.equal(nil)
		end)
	end)
end
