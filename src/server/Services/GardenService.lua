--[[
	GardenService
	プレイヤーの庭園島（空中プライベート島）の割当・生成と、
	植付け・水やり・孵化・成長ティックを担当するサービス。
	v2: 成長計算を Lib/GrowthLogic に委譲。データは data.garden.plots /
	data.inventory.seeds（スキーマ v2）を使用。島は島スロット毎に
	CFrame オフセット配置し、StreamingEnabled で自動ストリーミングする。
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local SeedDatabase = require(game.ReplicatedStorage.Shared.Config.SeedDatabase)
local Net = require(game.ReplicatedStorage.Shared.Net)
local GrowthLogic = require(ServerScriptService.Server.Lib.GrowthLogic)

-- ------------------------------------------------------------------ constants

--- super_grow ゲームパスの成長速度倍率
local SUPER_GROW_MULTIPLIER = 2.0
--- 水やりによる成長ボーナス秒数
local WATER_BONUS_SECONDS = 60
--- 成長ティック間隔（秒）
local GROWTH_TICK_INTERVAL = GameConfig.Garden.GrowthTickInterval
--- 島のベースサイズ（studs）
local ISLAND_SIZE = 128
--- プロット1マスのサイズ（studs）
local PLOT_SIZE = 8

-- ------------------------------------------------------------------ module

local GardenService = {}

-- 遅延解決するサービス参照
local DataService

--- seedId → シードデータ
local seedMap = {}
for _, seed in ipairs(SeedDatabase) do
	seedMap[seed.id] = seed
end

--- プレイヤー毎の成長ティックタイマー: userId → number
local tickTimers = {}

--- 島スロット割当: userId → slotIndex
local islandSlots = {}
--- 使用中スロット: slotIndex → userId
local usedSlots = {}

--- 生成済み島モデル: userId → Model
local islandModels = {}

-- ------------------------------------------------------------------ island geometry

--- スロット番号から島の中心CFrameを返す。
--- 島は空中 IslandHeight に IslandSpacing 間隔で1列配置する。
---@param slotIndex number
---@return CFrame
local function islandCFrame(slotIndex)
	local world = GameConfig.World
	return CFrame.new(slotIndex * world.IslandSpacing, world.IslandHeight, 0)
end

--- プロット番号（1-9、3×3）から島中心からのオフセットを返す。
---@param plotIndex number
---@return Vector3
local function plotOffset(plotIndex)
	local size = GameConfig.Garden.InitialSize -- 3
	local row = math.floor((plotIndex - 1) / size)
	local column = (plotIndex - 1) % size
	local origin = -(size - 1) / 2 * PLOT_SIZE
	return Vector3.new(origin + column * PLOT_SIZE, 1, origin + row * PLOT_SIZE)
end

--- プレイヤーの庭園島を生成する（ベース地形＋プロットPart＋スポーン台）。
---@param player Player
---@param slotIndex number
---@return Model
local function buildIsland(player, slotIndex)
	local island = Instance.new("Model")
	island.Name = "Island_" .. player.UserId

	local center = islandCFrame(slotIndex)

	-- ベース地面
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(ISLAND_SIZE, 4, ISLAND_SIZE)
	base.CFrame = center
	base.Anchored = true
	base.Material = Enum.Material.Grass
	base.Color = Color3.fromRGB(106, 170, 100)
	base.Parent = island

	-- 3×3 プロット
	for plotIndex = 1, GameConfig.Garden.MaxPlots do
		local plot = Instance.new("Part")
		plot.Name = "Plot_" .. plotIndex
		plot.Size = Vector3.new(PLOT_SIZE - 1, 1, PLOT_SIZE - 1)
		plot.CFrame = center + plotOffset(plotIndex) + Vector3.new(0, 2, 0)
		plot.Anchored = true
		plot.Material = Enum.Material.Ground
		plot.Color = Color3.fromRGB(124, 92, 62)
		plot.Parent = island

		-- クライアント操作用属性
		plot:SetAttribute("PlotIndex", plotIndex)
		plot:SetAttribute("OwnerUserId", player.UserId)

		-- プロットのタップ操作（サーバー側で発火・スマートアクション）
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 24
		clickDetector.Parent = plot
		clickDetector.MouseClick:Connect(function(clicker)
			GardenService.handlePlotClick(clicker, player.UserId, plotIndex)
		end)
	end

	-- ワープ台（ワールドへ戻る）
	local warpPad = Instance.new("Part")
	warpPad.Name = "WarpPad"
	warpPad.Size = Vector3.new(6, 1, 6)
	warpPad.CFrame = center + Vector3.new(0, 2.5, ISLAND_SIZE / 2 - 8)
	warpPad.Anchored = true
	warpPad.Material = Enum.Material.Neon
	warpPad.Color = Color3.fromRGB(85, 170, 255)
	warpPad.Parent = island

	island.Parent = workspace
	return island
end

-- ------------------------------------------------------------------ island API

--- プレイヤーに島スロットを割当て、島を生成する。
---@param player Player
---@return number slotIndex
function GardenService.assignIsland(player)
	if islandSlots[player.UserId] then
		return islandSlots[player.UserId]
	end

	-- 空きスロットを探す
	for slotIndex = 1, GameConfig.World.MaxIslandSlots do
		if not usedSlots[slotIndex] then
			usedSlots[slotIndex] = player.UserId
			islandSlots[player.UserId] = slotIndex
			islandModels[player.UserId] = buildIsland(player, slotIndex)
			print(string.format("[GardenService] %s assigned island slot %d", player.Name, slotIndex))
			return slotIndex
		end
	end

	warn("[GardenService] No free island slot for " .. player.Name)
	return 0
end

--- プレイヤーの島スロットを解放し、島モデルを破棄する。
---@param player Player
function GardenService.releaseIsland(player)
	local slotIndex = islandSlots[player.UserId]
	if slotIndex then
		usedSlots[slotIndex] = nil
		islandSlots[player.UserId] = nil
	end
	if islandModels[player.UserId] then
		islandModels[player.UserId]:Destroy()
		islandModels[player.UserId] = nil
	end
	tickTimers[player.UserId] = nil
end

--- プレイヤーの島のスポーン位置（CFrame）を返す。未割当なら nil。
---@param player Player
---@return CFrame|nil
function GardenService.getIslandSpawn(player)
	local slotIndex = islandSlots[player.UserId]
	if not slotIndex then
		return nil
	end
	return islandCFrame(slotIndex) + Vector3.new(0, 6, 0)
end

-- ------------------------------------------------------------------ helpers

--- プレイヤーが super_grow パスを保持しているか。
---@param player Player
---@return boolean
local function hasSuperGrow(player)
	local data = DataService.getData(player)
	return data ~= nil and data.gamePasses ~= nil and data.gamePasses.super_grow == true
end

-- ------------------------------------------------------------------ offline growth

--- オフライン成長を処理する。Egg / Ultimate ステージでは停止する。
---@param player Player
function GardenService.processOfflineGrowth(player)
	local data = DataService.getData(player)
	if not data then
		return
	end

	local offlineSeconds = data._offlineSeconds or 0
	if offlineSeconds <= 0 or not GameConfig.Garden.OfflineGrowthEnabled then
		return
	end

	local changedPlots = GrowthLogic.applyOfflineGrowth(data.garden.plots, offlineSeconds, GameConfig.Growth)

	for plotIndex in pairs(changedPlots) do
		Net.event("GardenUpdate"):FireClient(player, "stageChange", plotIndex, data.garden.plots[plotIndex])
	end

	data._offlineSeconds = 0
	print(string.format("[GardenService] %s offline growth applied (%d sec)", player.Name, offlineSeconds))
end

-- ------------------------------------------------------------------ plant seed

--- 指定プロットに種を植える。
---@param player Player
---@param plotIndex number
---@param seedId string
---@return boolean, string
function GardenService.plantSeed(player, plotIndex, seedId)
	-- 引数検証（クライアント不信頼）
	if type(plotIndex) ~= "number" or plotIndex < 1 or plotIndex > GameConfig.Garden.MaxPlots then
		return false, "invalid_plot"
	end
	if type(seedId) ~= "string" then
		return false, "invalid_seed"
	end

	local data = DataService.getData(player)
	if not data then
		return false, "no_data"
	end

	-- プロット空きチェック
	if data.garden.plots[plotIndex] then
		return false, "plot_occupied"
	end

	-- シード存在確認
	local seedData = seedMap[seedId]
	if not seedData then
		return false, "invalid_seed"
	end

	-- 所持種チェック（所持していれば消費）
	local hasSeed = false
	local seedInventory = data.inventory.seeds
	for index, ownedSeedId in ipairs(seedInventory) do
		if ownedSeedId == seedId then
			hasSeed = true
			table.remove(seedInventory, index)
			break
		end
	end

	-- 所持していない場合はコインで購入
	if not hasSeed then
		if seedData.currencyType == "coins" then
			if not DataService.spendCoins(player, seedData.cost) then
				return false, "insufficient_coins"
			end
		else
			-- robux 購入シードは所持していなければ植えられない
			return false, "no_seed"
		end
	end

	-- プロットデータ作成
	data.garden.plots[plotIndex] = {
		seedId = seedId,
		stage = "Seed",
		growthProgress = 0,
		soilType = "Normal",
		plantedAt = os.time(),
		watered = false,
	}

	print(string.format("[GardenService] %s planted %s at plot %d", player.Name, seedId, plotIndex))
	Net.event("GardenUpdate"):FireClient(player, "plant", plotIndex, data.garden.plots[plotIndex])
	return true, "ok"
end

-- ------------------------------------------------------------------ water plot

--- 指定プロットに水をやる。watered フラグを立て、成長ボーナスを加算する。
---@param player Player
---@param plotIndex number
---@return boolean, string
function GardenService.waterPlot(player, plotIndex)
	if type(plotIndex) ~= "number" then
		return false, "invalid_plot"
	end

	local data = DataService.getData(player)
	if not data then
		return false, "no_data"
	end

	local plot = data.garden.plots[plotIndex]
	if not plot then
		return false, "no_plot"
	end
	if plot.watered then
		return false, "already_watered"
	end
	if GrowthLogic.isManualStage(plot.stage) then
		return false, "cannot_water"
	end

	plot.watered = true
	local changed = GrowthLogic.advance(plot, WATER_BONUS_SECONDS, 1.0, GameConfig.Growth)
	-- watered フラグは advance でステージ変化時にリセットされるため再設定
	if not changed then
		plot.watered = true
	end

	local updateKind = changed and "stageChange" or "water"
	Net.event("GardenUpdate"):FireClient(player, updateKind, plotIndex, plot)
	return true, "ok"
end

-- ------------------------------------------------------------------ hatch egg

--- Egg ステージのプロットを孵化させ、モンスターを付与する。
---@param player Player
---@param plotIndex number
---@return boolean, string
function GardenService.hatchEgg(player, plotIndex)
	if type(plotIndex) ~= "number" then
		return false, "invalid_plot"
	end

	local data = DataService.getData(player)
	if not data then
		return false, "no_data"
	end

	local plot = data.garden.plots[plotIndex]
	if not plot then
		return false, "no_plot"
	end
	if plot.stage ~= "Egg" then
		return false, "not_egg"
	end

	-- MonsterService からモンスターをロール
	local MonsterService = require(ServerScriptService.Server.Services.MonsterService)
	local monster = MonsterService.rollMonster(player, plot.seedId, plot.soilType)
	if not monster then
		return false, "roll_failed"
	end

	-- モンスター追加・図鑑・統計更新
	table.insert(data.monsters, monster)
	data.collection[monster.id] = true
	DataService.incrementStat(player, "totalMonsters")

	-- Egg → Juvenile に進める
	plot.stage = "Juvenile"
	plot.growthProgress = 0
	plot.watered = false

	print(string.format("[GardenService] %s hatched %s at plot %d", player.Name, monster.id, plotIndex))

	Net.event("MonsterHatched"):FireClient(player, monster, plotIndex)
	Net.event("GardenUpdate"):FireClient(player, "hatch", plotIndex, plot)
	return true, "ok"
end

-- ------------------------------------------------------------------ plot click (smart action)

--- プロットタップ時のスマートアクション。
--- 空 → 手持ち先頭の種を植える / Egg → 孵化 / 成長中 → 水やり。
--- 所有者本人のみ操作可能（サーバー検証）。
---@param clicker Player タップしたプレイヤー
---@param ownerUserId number プロット所有者の UserId
---@param plotIndex number
function GardenService.handlePlotClick(clicker, ownerUserId, plotIndex)
	-- 所有者検証
	if clicker.UserId ~= ownerUserId then
		return
	end

	local data = DataService.getData(clicker)
	if not data then
		return
	end

	local plot = data.garden.plots[plotIndex]
	if not plot then
		-- 空プロット: 手持ち先頭の種を植える
		local firstSeed = data.inventory.seeds[1]
		if firstSeed then
			GardenService.plantSeed(clicker, plotIndex, firstSeed)
		end
	elseif plot.stage == "Egg" then
		GardenService.hatchEgg(clicker, plotIndex)
	else
		GardenService.waterPlot(clicker, plotIndex)
	end
end

-- ------------------------------------------------------------------ growth tick

--- 全プレイヤーの庭園を dt 秒分成長させる。init.server.lua の Heartbeat から呼ばれる。
---@param dt number
function GardenService.update(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		tickTimers[userId] = (tickTimers[userId] or 0) + dt

		if tickTimers[userId] >= GROWTH_TICK_INTERVAL then
			local tickDt = tickTimers[userId]
			tickTimers[userId] = 0

			local data = DataService.getData(player)
			if data and data.garden and data.garden.plots then
				local multiplier = hasSuperGrow(player) and SUPER_GROW_MULTIPLIER or 1.0

				for plotIndex, plot in pairs(data.garden.plots) do
					if type(plot) == "table" then
						local changed = GrowthLogic.advance(plot, tickDt, multiplier, GameConfig.Growth)
						if changed then
							Net.event("GardenUpdate"):FireClient(player, "stageChange", plotIndex, plot)
							print(
								string.format("[GardenService] %s plot %d → %s", player.Name, plotIndex, plot.stage)
							)
						end
					end
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ init

--- GardenService を初期化する。
function GardenService.init()
	DataService = require(ServerScriptService.Server.Services.DataService)

	-- Remote ハンドラ
	Net.event("PlantSeed").OnServerEvent:Connect(function(player, plotIndex, seedId)
		GardenService.plantSeed(player, plotIndex, seedId)
	end)

	Net.event("WaterPlot").OnServerEvent:Connect(function(player, plotIndex)
		GardenService.waterPlot(player, plotIndex)
	end)

	Net.event("HatchEgg").OnServerEvent:Connect(function(player, plotIndex)
		GardenService.hatchEgg(player, plotIndex)
	end)

	-- プレイヤー入室: 島割当＋オフライン成長
	Players.PlayerAdded:Connect(function(player)
		-- DataService.loadData の完了を待つ（キャッシュ生成まで最大10秒）
		local waited = 0
		while not DataService.getData(player) and waited < 10 do
			waited = waited + task.wait(0.2)
		end
		GardenService.assignIsland(player)
		GardenService.processOfflineGrowth(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		GardenService.assignIsland(player)
	end

	-- プレイヤー退室: 島解放
	Players.PlayerRemoving:Connect(function(player)
		GardenService.releaseIsland(player)
	end)

	print("[GardenService] Initialized")
end

return GardenService
