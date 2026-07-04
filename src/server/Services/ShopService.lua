--[[
	ShopService
	GamePass購入処理、DevProduct購入処理、コインショップを担当するサービス。
	MarketplaceService を使用し、購入完了時にプレイヤーデータを更新する。
	v2: Remote を Net.lua 経由に統一。シード在庫は data.inventory.seeds を使用。
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local ShopService = {}

-- ------------------------------------------------------------------ constants

--- GamePass ID マップ（本番環境では実際のIDに差し替える）
local GAMEPASS_IDS = {
	vip_pass = 0,
	mutation_4x = 0,
	lucky_gardener = 0,
	super_grow = 0,
	auto_water = 0,
}

--- DevProduct ID マップ（本番環境では実際のIDに差し替える）
local DEVPRODUCT_IDS = {
	basic_egg = 0,
	gold_egg = 0,
	premium_seed_5 = 0,
	growth_boost_1h = 0,
	instant_hatch_3 = 0,
	garden_expand = 0,
	golden_soil_5 = 0,
	deco_fantasy = 0,
}

-- ------------------------------------------------------------------ grant product

--- DevProduct の特典をプレイヤーに付与する。
---@param player Player
---@param data table
---@param productKey string
---@param DataService table
---@return boolean
function ShopService.grantProduct(player, data, productKey, DataService)
	if productKey == "basic_egg" then
		DataService.addCoins(player, 500)
		return true
	elseif productKey == "gold_egg" then
		DataService.addCoins(player, 2000)
		return true
	elseif productKey == "premium_seed_5" then
		table.insert(data.inventory.seeds, "rainbow_seed")
		local types = { "fire_seed", "water_seed", "grass_seed", "light_seed", "dark_seed" }
		for _ = 1, 4 do
			table.insert(data.inventory.seeds, types[math.random(#types)])
		end
		return true
	elseif productKey == "growth_boost_1h" then
		data._growthBoostUntil = os.time() + 3600
		return true
	elseif productKey == "instant_hatch_3" then
		data._instantHatchTickets = (data._instantHatchTickets or 0) + 3
		return true
	elseif productKey == "garden_expand" then
		data._pendingExpand = true
		return true
	elseif productKey == "golden_soil_5" then
		data._goldenSoilCount = (data._goldenSoilCount or 0) + 5
		return true
	elseif productKey == "deco_fantasy" then
		data._unlockedDecos = data._unlockedDecos or {}
		data._unlockedDecos.fantasy = true
		return true
	end
	return false
end

-- ------------------------------------------------------------------ check owned passes

--- プレイヤーが所持している GamePass を確認し、データに反映する。
---@param player Player
---@param DataService table
function ShopService.checkOwnedPasses(player, DataService)
	local data = DataService.getData(player)
	if not data then
		return
	end
	for passKey, passId in pairs(GAMEPASS_IDS) do
		if passId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owns then
				data.gamePasses[passKey] = true
			end
		end
	end
end

-- ------------------------------------------------------------------ coin shop

--- コインを使って種を購入する。
---@param player Player
---@param seedId string
---@param DataService table
function ShopService.buySeedWithCoins(player, seedId, DataService)
	local SeedDatabase = require(Shared.Config.SeedDatabase)
	local seedData = nil
	for _, seed in pairs(SeedDatabase) do
		if seed.id == seedId then
			seedData = seed
			break
		end
	end
	-- robux 建てシードはコイン購入不可
	if not seedData or seedData.cost <= 0 or seedData.currencyType ~= "coins" then
		return
	end
	if DataService.spendCoins(player, seedData.cost) then
		local data = DataService.getData(player)
		if data then
			table.insert(data.inventory.seeds, seedId)
		end
	end
end

-- ------------------------------------------------------------------ init

--- ShopService を初期化する。
function ShopService.init()
	local DataService = require(ServerScriptService.Server.Services.DataService)

	-- GamePass 購入完了ハンドラ
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		local passKey = nil
		for key, id in pairs(GAMEPASS_IDS) do
			if id == gamePassId then
				passKey = key
				break
			end
		end
		if passKey then
			local data = DataService.getData(player)
			if data then
				data.gamePasses[passKey] = true
				print("[ShopService] " .. player.Name .. " purchased GamePass: " .. passKey)
			end
		end
	end)

	-- DevProduct 購入処理（ProcessReceipt）
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = DataService.getData(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local productKey = nil
		for key, id in pairs(DEVPRODUCT_IDS) do
			if id == receiptInfo.ProductId then
				productKey = key
				break
			end
		end
		if not productKey then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local success = ShopService.grantProduct(player, data, productKey, DataService)
		if success then
			print("[ShopService] " .. player.Name .. " purchased: " .. productKey)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- プレイヤー入室時にGamePass所持チェック
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		ShopService.checkOwnedPasses(player, DataService)
	end)

	-- シードのコイン購入
	Net.event("BuySeed").OnServerEvent:Connect(function(player, seedId)
		ShopService.buySeedWithCoins(player, seedId, DataService)
	end)

	print("[ShopService] Initialized")
end

return ShopService
