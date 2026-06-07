-- サーバーブートストラップ
print("[Server] ===== Monster Garden BOOT START =====")

local RunService = game:GetService("RunService")

-- 安全な require（失敗してもクラッシュしない）
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

-- 安全な init
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

-- サービス読み込み
local DataService    = safeRequire(script.Services.DataService,    "DataService")
local WeatherService = safeRequire(script.Services.WeatherService, "WeatherService")
local MonsterService = safeRequire(script.Services.MonsterService, "MonsterService")
local GardenService  = safeRequire(script.Services.GardenService,  "GardenService")
local ShopService    = safeRequire(script.Services.ShopService,    "ShopService")

print("[Server] All modules loaded. Starting initialization...")

-- 初期化（依存順）
safeInit(DataService,    "DataService")
safeInit(WeatherService, "WeatherService")
safeInit(MonsterService, "MonsterService")
safeInit(GardenService,  "GardenService")
safeInit(ShopService,    "ShopService")

-- ゲームループ
RunService.Heartbeat:Connect(function(dt)
	if GardenService  and GardenService.update  then pcall(GardenService.update,  dt) end
	if WeatherService and WeatherService.update then pcall(WeatherService.update, dt) end
end)

print("[Server] ===== Monster Garden BOOT COMPLETE =====")
