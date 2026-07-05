--[[
	WeatherService
	天候・季節サイクルを管理するサービス。
	一定間隔で天候を抽選し、全クライアントへ通知する。
	季節はリアルの月から決定し、セッション中は固定する。
	v2: Remote を Net.lua 経由に統一。onChanged リスナーで他サービスへ同期する。
]]

local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(game.ReplicatedStorage.Shared.Net)

-- ------------------------------------------------------------------ constants

--- 天候ごとの基本重み（合計 100）
local WEATHER_WEIGHTS = {
	Sunny = 45,
	Rainy = 25,
	Snowy = 15, -- Winter 以外の場合は Rainy に統合
	Stormy = 10,
	Rainbow = 5,
}

--- 月 → 季節マッピング（12/1/2 は Winter フォールバック）
local MONTH_TO_SEASON = {
	[3] = "Spring",
	[4] = "Spring",
	[5] = "Spring",
	[6] = "Summer",
	[7] = "Summer",
	[8] = "Summer",
	[9] = "Autumn",
	[10] = "Autumn",
	[11] = "Autumn",
}

-- ------------------------------------------------------------------ module

local WeatherService = {}

-- ------------------------------------------------------------------ state

--- 現在の天候
local currentWeather = "Sunny"
--- 現在の季節（リアル月から決定）
local currentSeason = "Spring"
--- 天候変化タイマー（累積秒数）
local weatherTimer = 0
--- 天候変化リスナー（サーバー内サービス連携用）
local changeListeners = {}

-- ------------------------------------------------------------------ utility

--- 重みテーブルから加重ランダムにキーを選択して返す。
---@param weights table<string, number>
---@return string
local function weightedRandom(weights)
	local total = 0
	for _, weight in pairs(weights) do
		total = total + weight
	end
	local roll = math.random() * total
	local cumulative = 0
	local lastKey
	for key, weight in pairs(weights) do
		cumulative = cumulative + weight
		lastKey = key
		if roll <= cumulative then
			return key
		end
	end
	-- フォールバック（浮動小数点誤差対策）
	return lastKey
end

--- リアルの月から季節を決定して返す。
---@return string
local function getSeasonFromMonth()
	local month = tonumber(os.date("%m"))
	return MONTH_TO_SEASON[month] or "Winter"
end

-- ------------------------------------------------------------------ public API

--- 天候を抽選して更新し、変化があればクライアント・リスナーへ通知する。
function WeatherService.rollWeather()
	-- Winter 以外では Snowy の重みを Rainy に統合する
	local weights = table.clone(WEATHER_WEIGHTS)
	if currentSeason ~= "Winter" then
		weights.Rainy = weights.Rainy + weights.Snowy
		weights.Snowy = nil
	end

	local newWeather = weightedRandom(weights)
	if newWeather == currentWeather then
		return
	end

	currentWeather = newWeather
	print(string.format("[WeatherService] Weather changed → %s", currentWeather))

	Net.event("WeatherUpdate"):FireAllClients(currentWeather, currentSeason)
	for _, listener in ipairs(changeListeners) do
		local ok, err = pcall(listener, currentWeather, currentSeason)
		if not ok then
			warn("[WeatherService] listener error: " .. tostring(err))
		end
	end
end

--- 天候変化リスナーを登録する（サーバー内サービス用）。
---@param listener fun(weather: string, season: string)
function WeatherService.onChanged(listener)
	table.insert(changeListeners, listener)
end

--- 現在の天候を返す。
---@return string
function WeatherService.getWeather()
	return currentWeather
end

--- 現在の季節を返す。
---@return string
function WeatherService.getSeason()
	return currentSeason
end

--- 毎フレーム呼ばれ、天候変化間隔を管理する。
---@param dt number
function WeatherService.update(dt)
	weatherTimer = weatherTimer + dt
	if weatherTimer >= GameConfig.Weather.ChangeInterval then
		weatherTimer = 0
		WeatherService.rollWeather()
	end
end

-- ------------------------------------------------------------------ init

--- WeatherService を初期化する。
function WeatherService.init()
	currentSeason = getSeasonFromMonth()

	-- クライアントから現在状態を取得できる
	Net.func("GetWeather").OnServerInvoke = function(_player)
		return { weather = currentWeather, season = currentSeason }
	end

	-- 初期天候を抽選
	WeatherService.rollWeather()

	print(string.format("[WeatherService] Initialized. Season: %s, Weather: %s", currentSeason, currentWeather))
end

return WeatherService
