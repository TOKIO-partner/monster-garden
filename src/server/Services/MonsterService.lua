--[[
	MonsterService
	モンスターの抽選ロジック（レアリティロール、スポーン条件チェック）を担当するサービス。
	WeatherService からの天候・季節・時間帯情報を受け取り、スポーン条件に反映する。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterDatabase = require(game.ReplicatedStorage.Shared.Config.MonsterDatabase)
local SeedDatabase    = require(game.ReplicatedStorage.Shared.Config.SeedDatabase)

-- ------------------------------------------------------------------ constants

--- レアリティごとの基本重み（合計 100）
local RARITY_WEIGHTS = {
	Normal = 60,
	Rare   = 25,
	Epic   = 10,
	Legend = 4,
	Mythic = 1,
}

--- lucky_gardener ゲームパス保持時のボーナス重み
local LUCKY_GARDENER_BONUS = {
	Normal = -10,
	Rare   = 5,
	Epic   = 3,
	Legend = 1.5,
	Mythic = 0.5,
}

--- レアリティの序列（any_epic_or_above / any_legend_or_above フィルタ用）
local RARITY_RANK = {
	Normal = 1,
	Rare   = 2,
	Epic   = 3,
	Legend = 4,
	Mythic = 5,
}

-- ------------------------------------------------------------------ module

local MonsterService = {}

-- ------------------------------------------------------------------ state

--- 現在の天候（WeatherService から更新される）
local currentWeather   = "Sunny"
--- 現在の季節（WeatherService から更新される）
local currentSeason    = "Spring"
--- 現在の時間帯（将来的に昼夜サイクルから更新される）
local currentTimeOfDay = "Day"

-- ------------------------------------------------------------------ prebuilt maps

--- id → モンスターデータ のマップ
local monsterMap = {}
for _, monster in ipairs(MonsterDatabase) do
	monsterMap[monster.id] = monster
end

--- id → シードデータ のマップ
local seedMap = {}
for _, seed in ipairs(SeedDatabase) do
	seedMap[seed.id] = seed
end

-- ------------------------------------------------------------------ utility

--- 重みテーブルから加重ランダムにキーを選択して返す。
---@param weights table<string, number>
---@return string
local function weightedRandom(weights)
	local total = 0
	for _, w in pairs(weights) do
		total = total + w
	end

	local roll = math.random() * total
	local cumulative = 0
	for key, w in pairs(weights) do
		cumulative = cumulative + w
		if roll <= cumulative then
			return key
		end
	end

	-- フォールバック（浮動小数点誤差対策）
	local lastKey
	for key in pairs(weights) do
		lastKey = key
	end
	return lastKey
end

--- スポーン条件を現在の環境と照合する。
--- spawnCondition に指定されたキーがすべて一致する場合に true を返す。
---@param condition table
---@return boolean
local function checkSpawnCondition(condition)
	if condition.weather and condition.weather ~= currentWeather then
		return false
	end
	if condition.season and condition.season ~= currentSeason then
		return false
	end
	if condition.timeOfDay and condition.timeOfDay ~= currentTimeOfDay then
		return false
	end
	-- soilType は plantSeed 時に渡されるので、ここでは無視する（rollMonster の引数で対応）
	return true
end

-- ------------------------------------------------------------------ public API

--- サービスを初期化する。
function MonsterService.init()
	local count = MonsterService.getMonsterCount()
	print(string.format("[MonsterService] Initialized. Monster count: %d", count))
end

--- 現在の天候を更新する（WeatherService から呼ばれる）。
---@param weather string
function MonsterService.setWeather(weather)
	currentWeather = weather
end

--- 現在の季節を更新する（WeatherService から呼ばれる）。
---@param season string
function MonsterService.setSeason(season)
	currentSeason = season
end

--- 現在の時間帯を更新する（昼夜サイクルサービスから呼ばれる）。
---@param tod string
function MonsterService.setTimeOfDay(tod)
	currentTimeOfDay = tod
end

--- MonsterDatabase に登録されているモンスターの総数を返す。
---@return number
function MonsterService.getMonsterCount()
	local count = 0
	for _ in pairs(monsterMap) do
		count = count + 1
	end
	return count
end

--- プレイヤーのゲームパス状況を考慮してレアリティを抽選する。
---@param player Player
---@return string rarity
function MonsterService.rollRarity(player)
	-- 基本重みをコピー
	local weights = {}
	for rarity, w in pairs(RARITY_WEIGHTS) do
		weights[rarity] = w
	end

	-- lucky_gardener ゲームパスのボーナス適用
	local hasLuckyGardener = false
	local DataService = require(game.ServerScriptService.Server.Services.DataService)
	local data = DataService.getData(player)
	if data and data.gamePasses and data.gamePasses["lucky_gardener"] == true then
		hasLuckyGardener = true
	end

	if hasLuckyGardener then
		for rarity, bonus in pairs(LUCKY_GARDENER_BONUS) do
			weights[rarity] = math.max(0, (weights[rarity] or 0) + bonus)
		end
	end

	return weightedRandom(weights)
end

--- 種の属性・現在環境・スポーン条件を考慮してモンスターをロールする。
--- ガーデンから孵化時（GardenService.hatchEgg）に呼ばれる。
---@param player Player
---@param seedId string
---@return table|nil monster
function MonsterService.rollMonster(player, seedId)
	local rarity = MonsterService.rollRarity(player)
	local seed   = seedMap[seedId]

	-- 特殊シード判定
	local isAnyEpicOrAbove   = (seedId == "any_epic_or_above")
	local isAnyLegendOrAbove = (seedId == "any_legend_or_above")
	local skipAttributeFilter = isAnyEpicOrAbove or isAnyLegendOrAbove

	-- any_epic_or_above / any_legend_or_above のレアリティ下限補正
	if isAnyEpicOrAbove and RARITY_RANK[rarity] < RARITY_RANK["Epic"] then
		rarity = "Epic"
	elseif isAnyLegendOrAbove and RARITY_RANK[rarity] < RARITY_RANK["Legend"] then
		rarity = "Legend"
	end

	local attribute = seed and seed.attribute or nil

	-- 候補モンスターを収集
	local eligible = {}
	for _, monster in ipairs(MonsterDatabase) do
		-- レアリティ一致
		if monster.rarity ~= rarity then
			goto continue
		end

		-- 属性フィルタ（特殊シードはスキップ）
		if not skipAttributeFilter then
			if attribute and attribute ~= "All" and monster.attribute ~= attribute then
				goto continue
			end
		end

		-- スポーン条件チェック（soilType は除外して天候/季節/時間帯のみ）
		local cond = monster.spawnCondition or {}
		local condCheck = {
			weather   = cond.weather,
			season    = cond.season,
			timeOfDay = cond.timeOfDay,
		}
		if not checkSpawnCondition(condCheck) then
			goto continue
		end

		table.insert(eligible, monster)

		::continue::
	end

	-- 候補がなければフォールバック: 同属性の Normal モンスター（条件無視）
	if #eligible == 0 then
		warn(string.format(
			"[MonsterService] No eligible monster (rarity=%s, attr=%s, weather=%s, season=%s). Falling back to Normal.",
			rarity, tostring(attribute), currentWeather, currentSeason
		))
		for _, monster in ipairs(MonsterDatabase) do
			if monster.rarity == "Normal" then
				if not skipAttributeFilter and attribute and attribute ~= "All" then
					if monster.attribute == attribute then
						table.insert(eligible, monster)
					end
				else
					table.insert(eligible, monster)
				end
			end
		end
	end

	-- それでも候補がなければ nil を返す
	if #eligible == 0 then
		warn("[MonsterService] Fallback also found no candidates. Returning nil.")
		return nil
	end

	-- ランダムに1体選択
	local chosen = eligible[math.random(1, #eligible)]

	-- 返却テーブル（データベースエントリのシャローコピー + 追加フィールド）
	local result = {}
	for k, v in pairs(chosen) do
		result[k] = v
	end
	result.hatchedAt = os.time()
	result.uniqueId  = chosen.id .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))

	print(string.format(
		"[MonsterService] Rolled %s (%s, %s) for %s",
		result.id, result.rarity, result.attribute, player.Name
	))

	return result
end

-- ------------------------------------------------------------------ state accessors

--- 現在の天候を返す。
---@return string
function MonsterService.getWeather()
	return currentWeather
end

--- 現在の季節を返す。
---@return string
function MonsterService.getSeason()
	return currentSeason
end

--- 現在の時間帯を返す。
---@return string
function MonsterService.getTimeOfDay()
	return currentTimeOfDay
end

return MonsterService
