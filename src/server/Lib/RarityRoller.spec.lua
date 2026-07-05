--[[
	RarityRoller.spec
	レアリティ抽選ロジックの単体テスト（TestEZ）。rng 注入で決定論化。
]]

return function()
	local RarityRoller = require(script.Parent.RarityRoller)

	--- 固定値を返す rng を作る
	local function fixedRng(value)
		return function()
			return value
		end
	end

	describe("applyBonus", function()
		it("ボーナスを加算し負値は 0 にクランプ", function()
			local weights = RarityRoller.applyBonus({ Normal = 5, Rare = 10 }, { Normal = -10, Rare = 5 })
			expect(weights.Normal).to.equal(0)
			expect(weights.Rare).to.equal(15)
		end)

		it("ボーナス nil は変化なし", function()
			local weights = RarityRoller.applyBonus({ Normal = 60 }, nil)
			expect(weights.Normal).to.equal(60)
		end)
	end)

	describe("applySoilBonus", function()
		it("Normal 以外を (1+bonus) 倍する", function()
			local weights = RarityRoller.applySoilBonus({ Normal = 60, Rare = 20 }, 0.25)
			expect(weights.Normal).to.equal(60)
			expect(weights.Rare).to.equal(25)
		end)

		it("ボーナス 0 は同一テーブルを返す", function()
			local original = { Normal = 60 }
			expect(RarityRoller.applySoilBonus(original, 0)).to.equal(original)
		end)
	end)

	describe("roll", function()
		it("しきい値に応じたレアリティを返す（固定順 Normal→Mythic）", function()
			local weights = RarityRoller.BASE_WEIGHTS -- 60/25/10/4/1
			expect(RarityRoller.roll(weights, fixedRng(0.0))).to.equal("Normal")
			expect(RarityRoller.roll(weights, fixedRng(0.59))).to.equal("Normal")
			expect(RarityRoller.roll(weights, fixedRng(0.61))).to.equal("Rare")
			expect(RarityRoller.roll(weights, fixedRng(0.86))).to.equal("Epic")
			expect(RarityRoller.roll(weights, fixedRng(0.96))).to.equal("Legend")
			expect(RarityRoller.roll(weights, fixedRng(0.995))).to.equal("Mythic")
		end)

		it("重み合計 0 は Normal フォールバック", function()
			expect(RarityRoller.roll({}, fixedRng(0.5))).to.equal("Normal")
		end)
	end)

	describe("rollRarity", function()
		it("lucky で Normal が減り高レアが出やすくなる", function()
			-- lucky適用後: Normal50/Rare30/Epic13/Legend5.5/Mythic1.5 (合計100)
			expect(RarityRoller.rollRarity({ lucky = true, rng = fixedRng(0.55) })).to.equal("Rare")
			-- lucky なしなら 0.55 は Normal(60) 圏内
			expect(RarityRoller.rollRarity({ rng = fixedRng(0.55) })).to.equal("Normal")
		end)

		it("options 省略でも動く", function()
			local rarity = RarityRoller.rollRarity()
			expect(RarityRoller.RANK[rarity]).to.be.ok()
		end)
	end)
end
