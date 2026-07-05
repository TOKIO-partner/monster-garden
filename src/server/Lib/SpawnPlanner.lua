--[[
	SpawnPlanner
	野生モンスターのスポーン候補選定（純粋ロジック・Instance非依存）。
	バイオーム属性・天候・季節・時間帯でモンスターDBをフィルタし、
	レアリティ重みで1体を抽選する。
	庭園用 spawnCondition のうち soilType は野生では無視する。
]]

local RarityRoller = require(script.Parent.RarityRoller)

local SpawnPlanner = {}

--- 属性配列を set に変換する。
---@param attributes table<number, string>
---@return table<string, boolean>
local function toSet(attributes)
	local set = {}
	for _, attribute in ipairs(attributes) do
		set[attribute] = true
	end
	return set
end

--- スポーン条件（天候/季節/時間帯）を満たすか。nil の条件は常に許可。
---@param condition table|nil { weather, season, timeOfDay, soilType(無視) }
---@param environment { weather: string, season: string, timeOfDay: string }
---@return boolean
function SpawnPlanner.matchesCondition(condition, environment)
	if not condition then
		return true
	end
	if condition.weather and condition.weather ~= environment.weather then
		return false
	end
	if condition.season and condition.season ~= environment.season then
		return false
	end
	if condition.timeOfDay and condition.timeOfDay ~= environment.timeOfDay then
		return false
	end
	-- soilType は庭園専用条件のため野生スポーンでは無視する
	return true
end

--- バイオーム属性と環境条件でスポーン候補を絞り込む。
---@param monsterList table<number, table> MonsterDatabase 形式の配列
---@param biomeAttributes table<number, string> バイオーム対応属性（例 {"Grass","Light"}）
---@param environment { weather: string, season: string, timeOfDay: string }
---@return table<number, table> eligible 候補モンスター配列
function SpawnPlanner.eligibleSpecies(monsterList, biomeAttributes, environment)
	local attributeSet = toSet(biomeAttributes)
	local eligible = {}
	for _, monster in ipairs(monsterList) do
		if attributeSet[monster.attribute] and SpawnPlanner.matchesCondition(monster.spawnCondition, environment) then
			table.insert(eligible, monster)
		end
	end
	return eligible
end

--- 条件を満たす候補がいない場合のフォールバック: 環境条件を無視して属性のみで絞る。
---@param monsterList table<number, table>
---@param biomeAttributes table<number, string>
---@return table<number, table>
function SpawnPlanner.fallbackSpecies(monsterList, biomeAttributes)
	local attributeSet = toSet(biomeAttributes)
	local eligible = {}
	for _, monster in ipairs(monsterList) do
		if attributeSet[monster.attribute] then
			table.insert(eligible, monster)
		end
	end
	return eligible
end

--- 候補からレアリティ重みで1体抽選する。候補が空なら nil。
---@param eligible table<number, table>
---@param rng (fun(): number)|nil
---@return table|nil monster
function SpawnPlanner.pickSpawn(eligible, rng)
	if #eligible == 0 then
		return nil
	end
	rng = rng or math.random

	-- 各候補にレアリティ重みを割り当てて重み付き抽選
	local total = 0
	local weights = {}
	for index, monster in ipairs(eligible) do
		local weight = RarityRoller.BASE_WEIGHTS[monster.rarity] or 1
		weights[index] = weight
		total = total + weight
	end

	local threshold = rng() * total
	local accumulated = 0
	for index, monster in ipairs(eligible) do
		accumulated = accumulated + weights[index]
		if threshold <= accumulated then
			return monster
		end
	end
	return eligible[#eligible]
end

--- 現在数と上限から不足数を返す。
---@param currentCount number
---@param maxPerBiome number
---@return number deficit 0 以上
function SpawnPlanner.deficit(currentCount, maxPerBiome)
	return math.max(0, maxPerBiome - currentCount)
end

return SpawnPlanner
