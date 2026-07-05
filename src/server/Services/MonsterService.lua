--[[
	MonsterService
	モンスターの抽選ロジック（レアリティロール、スポーン条件チェック）を担当するサービス。
	WeatherService からの天候・季節・時間帯情報を受け取り、スポーン条件に反映する。
	v2: レアリティ抽選を Lib/RarityRoller に委譲。孵化用 rollMonster を維持。
]]

local ServerScriptService = game:GetService("ServerScriptService")

local MonsterDatabase = require(game.ReplicatedStorage.Shared.Config.MonsterDatabase)
local SeedDatabase = require(game.ReplicatedStorage.Shared.Config.SeedDatabase)
local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local RarityRoller = require(ServerScriptService.Server.Lib.RarityRoller)

-- ------------------------------------------------------------------ module

local MonsterService = {}

-- ------------------------------------------------------------------ state

--- 現在の天候（WeatherService から更新される）
local currentWeather = "Sunny"
--- 現在の季節（WeatherService から更新される）
local currentSeason = "Spring"
--- 現在の時間帯（将来的に昼夜サイクルから更新される）
local currentTimeOfDay = "Day"

-- ------------------------------------------------------------------ prebuilt maps

--- monsterId → モンスターデータ
local monsterMap = {}
for _, monster in ipairs(MonsterDatabase) do
	monsterMap[monster.id] = monster
end

--- seedId → シードデータ
local seedMap = {}
for _, seed in ipairs(SeedDatabase) do
	seedMap[seed.id] = seed
end

-- ------------------------------------------------------------------ spawn condition

--- スポーン条件（天候/季節/時間帯）を満たすか。nil の条件は常に許可。
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
	-- soilType は rollMonster の引数で対応するため、ここでは無視する
	return true
end

-- ------------------------------------------------------------------ public API

--- サービスを初期化する。
function MonsterService.init()
	local count = MonsterService.getMonsterCount()
	print(string.format("[MonsterService] Initialized. Monster count: %d", count))
end

--- 現在の天候を更新する（WeatherService 連携）。
---@param weather string
function MonsterService.setWeather(weather)
	currentWeather = weather
end

--- 現在の季節を更新する（WeatherService 連携）。
---@param season string
function MonsterService.setSeason(season)
	currentSeason = season
end

--- 現在の時間帯を更新する（昼夜サイクルサービスから呼ばれる）。
---@param timeOfDay string
function MonsterService.setTimeOfDay(timeOfDay)
	currentTimeOfDay = timeOfDay
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

--- monsterId からモンスターデータを返す。
---@param monsterId string
---@return table|nil
function MonsterService.getMonsterById(monsterId)
	return monsterMap[monsterId]
end

--- プレイヤーのゲームパス・土壌を考慮してレアリティを抽選する。
---@param player Player
---@param soilType string|nil
---@return string rarity
function MonsterService.rollRarity(player, soilType)
	local DataService = require(ServerScriptService.Server.Services.DataService)
	local data = DataService.getData(player)
	local hasLucky = data and data.gamePasses and data.gamePasses.lucky_gardener == true

	local soilBonus = 0
	if soilType and GameConfig.Soil[soilType] then
		soilBonus = GameConfig.Soil[soilType].rarityBonus
	end

	return RarityRoller.rollRarity({ lucky = hasLucky, soilBonus = soilBonus })
end

--- シードと土壌からモンスターを1体抽選して返す（孵化用）。
--- 失敗時は nil を返す。
---@param player Player
---@param seedId string
---@param soilType string|nil
---@return table|nil monster { id, rarity, attribute, hatchedAt, ... }
function MonsterService.rollMonster(player, seedId, soilType)
	local seed = seedMap[seedId]
	local rarity = MonsterService.rollRarity(player, soilType)

	local attribute = seed and seed.attribute or nil
	local skipAttributeFilter = attribute == "All"

	-- 候補モンスターを収集
	local eligible = {}
	for _, monster in ipairs(MonsterDatabase) do
		local rarityOk = monster.rarity == rarity
		local attributeOk = skipAttributeFilter or not attribute or monster.attribute == attribute
		if rarityOk and attributeOk then
			local condition = monster.spawnCondition or {}
			if checkSpawnCondition(condition) then
				-- シードの possibleMonsters 制約（定義があれば適用）
				local inSeedPool = true
				if seed and seed.possibleMonsters then
					inSeedPool = false
					for _, possibleId in ipairs(seed.possibleMonsters) do
						if possibleId == monster.id then
							inSeedPool = true
							break
						end
					end
				end
				if inSeedPool then
					table.insert(eligible, monster)
				end
			end
		end
	end

	-- 候補がなければフォールバック: 同属性の Normal モンスター（条件無視）
	if #eligible == 0 then
		warn(
			string.format(
				"[MonsterService] No eligible monster (rarity=%s, attr=%s, weather=%s, season=%s). Falling back to Normal.",
				rarity,
				tostring(attribute),
				currentWeather,
				currentSeason
			)
		)
		for _, monster in ipairs(MonsterDatabase) do
			if monster.rarity == "Normal" then
				if skipAttributeFilter or not attribute or monster.attribute == attribute then
					table.insert(eligible, monster)
				end
			end
		end
	end

	-- それでも候補がなければ nil を返す
	if #eligible == 0 then
		warn("[MonsterService] Fallback also found no monster. seedId=" .. tostring(seedId))
		return nil
	end

	local chosen = eligible[math.random(#eligible)]
	return {
		id = chosen.id,
		rarity = chosen.rarity,
		attribute = chosen.attribute,
		baseValue = chosen.baseValue,
		source = "hatch",
		hatchedAt = os.time(),
	}
end

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
