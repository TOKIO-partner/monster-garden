--[[
	init.server.lua
	サーバーブートストラップ。Net 初期化 → 全サービスを依存順に初期化し、
	Heartbeat でゲームループ（成長・天候・スポーン）を回す。
]]

print("[Server] ===== Monster Garden BOOT START =====")

local RunService = game:GetService("RunService")

local Net = require(game.ReplicatedStorage.Shared.Net)

--- モジュールを安全に require する（失敗してもクラッシュしない）。
local function safeRequire(path, name)
	local ok, result = pcall(function()
		return require(path)
	end)
	if ok then
		print("[Server] ✓ Loaded: " .. name)
		return result
	else
		warn("[Server] ✗ FAILED to load: " .. name .. " → " .. tostring(result))
		return nil
	end
end

--- モジュールの init() を安全に呼ぶ。
local function safeInit(service, name)
	if not service then
		warn("[Server] ✗ SKIP init: " .. name .. " (not loaded)")
		return
	end
	local ok, err = pcall(function()
		service.init()
	end)
	if ok then
		print("[Server] ✓ Initialized: " .. name)
	else
		warn("[Server] ✗ FAILED init: " .. name .. " → " .. tostring(err))
	end
end

-- Remote を最初に生成する（全サービスが依存）
Net.init()

-- サービス読み込み
local DataService = safeRequire(script.Services.DataService, "DataService")
local WeatherService = safeRequire(script.Services.WeatherService, "WeatherService")
local MonsterService = safeRequire(script.Services.MonsterService, "MonsterService")
local GardenService = safeRequire(script.Services.GardenService, "GardenService")
local WorldService = safeRequire(script.Services.WorldService, "WorldService")
local SpawnService = safeRequire(script.Services.SpawnService, "SpawnService")
local CaptureService = safeRequire(script.Services.CaptureService, "CaptureService")
local ShopService = safeRequire(script.Services.ShopService, "ShopService")

print("[Server] All modules loaded. Starting initialization...")

-- 初期化（依存順: Data → Weather → Monster → Garden → World → Spawn → Capture → Shop）
safeInit(DataService, "DataService")
safeInit(WeatherService, "WeatherService")
safeInit(MonsterService, "MonsterService")
safeInit(GardenService, "GardenService")
safeInit(WorldService, "WorldService")
safeInit(SpawnService, "SpawnService")
safeInit(CaptureService, "CaptureService")
safeInit(ShopService, "ShopService")

-- 天候変化をモンスター条件・野生スポーンへ連動
if WeatherService and MonsterService then
	WeatherService.onChanged(function(weather, season)
		MonsterService.setWeather(weather)
		MonsterService.setSeason(season)
		if SpawnService then
			SpawnService.onWeatherChanged()
		end
	end)
	-- 初期同期
	MonsterService.setWeather(WeatherService.getWeather())
	MonsterService.setSeason(WeatherService.getSeason())
end

-- ゲームループ
RunService.Heartbeat:Connect(function(dt)
	if GardenService and GardenService.update then
		pcall(GardenService.update, dt)
	end
	if WeatherService and WeatherService.update then
		pcall(WeatherService.update, dt)
	end
	if SpawnService and SpawnService.update then
		pcall(SpawnService.update, dt)
	end
end)

print("[Server] ===== Monster Garden BOOT COMPLETE =====")
