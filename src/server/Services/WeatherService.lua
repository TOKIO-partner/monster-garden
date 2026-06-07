--[[
	WeatherService
	天候・季節サイクルを管理するサービス。
	一定間隔で天候を抽選し、全クライアントへ通知する。
	季節はリアルの月から決定し、セッション中は固定する。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)

-- ------------------------------------------------------------------ constants

--- 天候ごとの基本重み（合計 100）
local WEATHER_WEIGHTS = {
	Rainbow = 5,
	Rainy   = 25,
	Snowy   = 15,  -- Winter 以外の場合は Rainy に差し替え
	Stormy  = 10,
	Sunny   = 45,
}

--- 月 → 季節マッピング
local MONTH_TO_SEASON = {
	[3]  = "Spring", [4]  = "Spring", [5]  = "Spring",
	[6]  = "Summer", [7]  = "Summer", [8]  = "Summer",
	[9]  = "Autumn", [10] = "Autumn", [11] = "Autumn",
}

-- ------------------------------------------------------------------ module

local WeatherService = {}

-- ------------------------------------------------------------------ state

--- 現在の天候
local currentWeather = "Sunny"
--- 現在の季節（リアル月から決定）
local currentSeason  = "Spring"
--- 天候変化タイマー（累積秒数）
local weatherTimer   = 0

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

--- リアルの月から季節を決定して返す。
---@return string
local function getSeasonFromMonth()
	local month = tonumber(os.date("%m"))
	return MONTH_TO_SEASON[month] or "Winter"
end

-- ------------------------------------------------------------------ remotes

--- WeatherUpdate RemoteEvent を取得するヘルパー。
---@return RemoteEvent|nil
local function getWeatherUpdateEvent()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return nil end
	return remotes:FindFirstChild("WeatherUpdate")
end

-- ------------------------------------------------------------------ weather roll

--- 天候を抽選して currentWeather を更新し、変化があれば各クライアントへ通知する。
function WeatherService.rollWeather()
	-- Winter 以外では Snowy を Rainy に統合した重みを使う
	local weights = {}
	for k, v in pairs(WEATHER_WEIGHTS) do
		weights[k] = v
	end

	if currentSeason ~= "Winter" then
		-- Snowy の重みを Rainy に加算して Snowy を除外
		weights["Rainy"]  = weights["Rainy"] + weights["Snowy"]
		weights["Snowy"]  = nil
	end

	local newWeather = weightedRandom(weights)

	local changed = (newWeather ~= currentWeather)
	currentWeather = newWeather

	-- MonsterService に天候変化を通知（循環依存を pcall で回避）
	local ok, err = pcall(function()
		local MonsterService = require(game.ServerScriptService.Server.Services.MonsterService)
		MonsterService.setWeather(currentWeather)
		MonsterService.setSeason(currentSeason)
	end)
	if not ok then
		warn("[WeatherService] Failed to update MonsterService: " .. tostring(err))
	end

	-- 変化があれば全クライアントへ通知
	if changed then
		local event = getWeatherUpdateEvent()
		if event then
			event:FireAllClients(currentWeather, currentSeason)
		end
		print(string.format("[WeatherService] Weather changed → %s (season: %s)", currentWeather, currentSeason))
	end
end

-- ------------------------------------------------------------------ public API

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

--- ゲームループから毎フレーム呼ばれる更新処理。
--- GameConfig.Weather.ChangeInterval 秒ごとに天候を再抽選する。
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
--- 季節を実際の月から決定し、Remotes を作成して初期天候を抽選する。
function WeatherService.init()
	-- 季節をリアル月から決定
	currentSeason = getSeasonFromMonth()

	-- Remotes フォルダ取得（DataService.init が先に実行済みで存在する）
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotes then
		warn("[WeatherService] Remotes folder not found.")
		return
	end

	-- WeatherUpdate RemoteEvent
	if not remotes:FindFirstChild("WeatherUpdate") then
		local re = Instance.new("RemoteEvent")
		re.Name   = "WeatherUpdate"
		re.Parent = remotes
	end

	-- GetWeather RemoteFunction
	if not remotes:FindFirstChild("GetWeather") then
		local rf = Instance.new("RemoteFunction")
		rf.Name   = "GetWeather"
		rf.Parent = remotes
	end

	-- GetWeather ハンドラ（クライアントから現在状態を取得できる）
	local getWeatherRF = remotes:WaitForChild("GetWeather")
	getWeatherRF.OnServerInvoke = function(_player)
		return { weather = currentWeather, season = currentSeason }
	end

	-- 初期天候を抽選
	WeatherService.rollWeather()

	print(string.format("[WeatherService] Initialized. Season: %s, Weather: %s", currentSeason, currentWeather))
end

return WeatherService
