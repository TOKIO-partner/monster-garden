--[[
	init.client.lua
	クライアント側エントリポイント。全コントローラを順番に初期化する。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
if not Shared then
	warn("[Client] Shared modules not found!")
	return
end

--- モジュールを安全に require する。失敗時は nil を返す。
local function safeRequire(path, name)
	local ok, result = pcall(function()
		return require(path)
	end)
	if ok then
		print("[Client] ✓ Loaded: " .. name)
		return result
	else
		warn("[Client] ✗ FAILED: " .. name .. " → " .. tostring(result))
		return nil
	end
end

--- モジュールの init() を安全に呼ぶ。失敗時は警告のみ。
local function safeInit(mod, name)
	if not mod or not mod.init then
		return
	end
	local ok, err = pcall(function()
		mod.init()
	end)
	if ok then
		print("[Client] ✓ Init: " .. name)
	else
		warn("[Client] ✗ Init FAILED: " .. name .. " → " .. tostring(err))
	end
end

print("[Client] === Monster Garden Client Starting ===")

local UIController = safeRequire(script.Controllers.UIController, "UIController")
local WorldController = safeRequire(script.Controllers.WorldController, "WorldController")
local GardenController = safeRequire(script.Controllers.GardenController, "GardenController")
local CaptureController = safeRequire(script.Controllers.CaptureController, "CaptureController")
local ShopController = safeRequire(script.Controllers.ShopController, "ShopController")
local CollectionController = safeRequire(script.Controllers.CollectionController, "CollectionController")

safeInit(UIController, "UIController")
safeInit(WorldController, "WorldController")
safeInit(GardenController, "GardenController")
safeInit(CaptureController, "CaptureController")
safeInit(ShopController, "ShopController")
safeInit(CollectionController, "CollectionController")

-- 捕獲トーストを UIController に接続
if CaptureController and UIController then
	CaptureController.setToastHandler(UIController.showToast)
end

print("[Client] === Monster Garden Client Ready ===")
