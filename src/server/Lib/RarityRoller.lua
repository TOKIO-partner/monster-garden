--[[
	RarityRoller
	レアリティの重み付き抽選（純粋ロジック・Instance非依存）。
	旧 MonsterService の weightedRandom / rollRarity を関数化したもの。
	乱数は rng 関数（0-1 を返す）を注入でき、テストで決定論化できる。
]]

local RarityRoller = {}

--- レアリティごとの基本重み（合計 100）
RarityRoller.BASE_WEIGHTS = {
	Normal = 60,
	Rare = 25,
	Epic = 10,
	Legend = 4,
	Mythic = 1,
}

--- lucky_gardener ゲームパス保持時のボーナス重み（加算）
RarityRoller.LUCKY_GARDENER_BONUS = {
	Normal = -10,
	Rare = 5,
	Epic = 3,
	Legend = 1.5,
	Mythic = 0.5,
}

--- レアリティの序列（フィルタ・比較用）
RarityRoller.RANK = {
	Normal = 1,
	Rare = 2,
	Epic = 3,
	Legend = 4,
	Mythic = 5,
}

--- 抽選順序（pairs の順不定を避けるための固定順）
local RARITY_ORDER = { "Normal", "Rare", "Epic", "Legend", "Mythic" }

--- 重みテーブルのコピーにボーナスを加算して返す（負値は 0 でクランプ）。
---@param weights table<string, number>
---@param bonus table<string, number>|nil
---@return table<string, number>
function RarityRoller.applyBonus(weights, bonus)
	local result = {}
	for rarity, weight in pairs(weights) do
		local added = bonus and bonus[rarity] or 0
		result[rarity] = math.max(0, weight + added)
	end
	return result
end

--- 土壌ボーナスを適用する。Normal 以外の重みを (1 + soilBonus) 倍する。
---@param weights table<string, number>
---@param soilBonus number 0 = 補正なし、0.25 = 高レア重み +25%
---@return table<string, number>
function RarityRoller.applySoilBonus(weights, soilBonus)
	if not soilBonus or soilBonus <= 0 then
		return weights
	end
	local result = {}
	for rarity, weight in pairs(weights) do
		if rarity == "Normal" then
			result[rarity] = weight
		else
			result[rarity] = weight * (1 + soilBonus)
		end
	end
	return result
end

--- 重み付き抽選を行い、レアリティ名を返す。
---@param weights table<string, number>
---@param rng (fun(): number)|nil 0-1 を返す乱数関数（省略時 math.random）
---@return string rarity
function RarityRoller.roll(weights, rng)
	rng = rng or math.random

	local total = 0
	for _, rarity in ipairs(RARITY_ORDER) do
		total = total + (weights[rarity] or 0)
	end
	if total <= 0 then
		return "Normal"
	end

	local threshold = rng() * total
	local accumulated = 0
	for _, rarity in ipairs(RARITY_ORDER) do
		accumulated = accumulated + (weights[rarity] or 0)
		if threshold <= accumulated then
			return rarity
		end
	end
	return "Normal"
end

--- オプション付きの総合抽選。基本重み → luckyボーナス → 土壌ボーナス → 抽選。
---@param options { lucky: boolean|nil, soilBonus: number|nil, rng: (fun(): number)|nil }|nil
---@return string rarity
function RarityRoller.rollRarity(options)
	options = options or {}
	local weights = RarityRoller.BASE_WEIGHTS
	if options.lucky then
		weights = RarityRoller.applyBonus(weights, RarityRoller.LUCKY_GARDENER_BONUS)
	end
	weights = RarityRoller.applySoilBonus(weights, options.soilBonus or 0)
	return RarityRoller.roll(weights, options.rng)
end

return RarityRoller
