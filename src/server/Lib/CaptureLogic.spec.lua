--[[
	CaptureLogic.spec
	捕獲成功率計算・判定の単体テスト（TestEZ）。
]]

return function()
	local CaptureLogic = require(script.Parent.CaptureLogic)

	local CONFIG = {
		rates = {
			Normal = 0.90,
			Rare = 0.60,
			Epic = 0.35,
			Legend = 0.15,
			Mythic = 0.05,
		},
		luckyBonus = 0.10,
	}

	local function fixedRng(value)
		return function()
			return value
		end
	end

	describe("successRate", function()
		it("レアリティ別の基本成功率を返す", function()
			expect(CaptureLogic.successRate("Normal", CONFIG)).to.equal(0.90)
			expect(CaptureLogic.successRate("Mythic", CONFIG)).to.equal(0.05)
		end)

		it("lucky_gardener で加算される", function()
			expect(CaptureLogic.successRate("Rare", CONFIG, true)).to.equal(0.70)
		end)

		it("上限 0.95 でクランプされる", function()
			expect(CaptureLogic.successRate("Normal", CONFIG, true)).to.equal(0.95)
		end)

		it("未知レアリティは下限扱い", function()
			expect(CaptureLogic.successRate("Bogus", CONFIG)).to.equal(0.01)
		end)
	end)

	describe("roll", function()
		it("rng が成功率以下なら成功", function()
			local success = CaptureLogic.roll("Rare", CONFIG, false, fixedRng(0.60))
			expect(success).to.equal(true)
		end)

		it("rng が成功率を超えたら失敗", function()
			local success = CaptureLogic.roll("Rare", CONFIG, false, fixedRng(0.61))
			expect(success).to.equal(false)
		end)

		it("使用した成功率を第2戻り値で返す", function()
			local _, rate = CaptureLogic.roll("Epic", CONFIG, true, fixedRng(0.5))
			expect(rate).to.equal(0.45)
		end)
	end)

	describe("isWithinDistance", function()
		it("許容距離内は true", function()
			expect(CaptureLogic.isWithinDistance(10, 15)).to.equal(true)
			expect(CaptureLogic.isWithinDistance(15, 15)).to.equal(true)
		end)

		it("許容距離超過・不正値は false", function()
			expect(CaptureLogic.isWithinDistance(15.1, 15)).to.equal(false)
			expect(CaptureLogic.isWithinDistance(-1, 15)).to.equal(false)
			expect(CaptureLogic.isWithinDistance(nil, 15)).to.equal(false)
		end)
	end)
end
