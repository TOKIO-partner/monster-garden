--[[
	GardenService
	ガーデンの成長ロジック、植付け、水やり、孵化を担当するサービス。
	DataService に依存してプレイヤーデータを読み書きする。
]]

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)

-- ------------------------------------------------------------------ constants

--- 成長ステージ定義（順序が重要）
local GROWTH_STAGES = {
	"Seed",      -- 1
	"Sprout",    -- 2
	"Bud",       -- 3
	"Egg",       -- 4  ← タップが必要。自動進行しない
	"Juvenile",  -- 5
	"Adult",     -- 6
	"Ultimate",  -- 7  ← 最終形。自動進行しない
}

--- ステージインデックスの逆引きマップ
local STAGE_INDEX = {}
for i, stage in ipairs(GROWTH_STAGES) do
	STAGE_INDEX[stage] = i
end

--- 各ステージから次のステージに進むのに必要な秒数（GameConfig.Growth から取得）
local STAGE_DURATIONS = {
	Seed    = GameConfig.Growth.SeedToSprout,    -- 300
	Sprout  = GameConfig.Growth.SproutToBud,     -- 900
	Bud     = GameConfig.Growth.BudToEgg,        -- 1800
	Egg     = GameConfig.Growth.EggToHatch,      -- 0  (手動孵化のため使用しない)
	Juvenile = GameConfig.Growth.HatchToJuvenile, -- 3600
	Adult   = GameConfig.Growth.JuvenileToAdult, -- 7200
}

--- super_grow ゲームパスの成長速度倍率
local SUPER_GROW_MULTIPLIER = 2.0

--- 水やりによるボーナス秒数
local WATER_BONUS_SECONDS = 60

--- GrowthTickInterval（秒）
local GROWTH_TICK_INTERVAL = GameConfig.Garden.GrowthTickInterval  -- 1

-- ------------------------------------------------------------------ module

local GardenService = {}

-- DataService への参照（init 時に取得）
local DataService

-- 各プレイヤーの成長ティックタイマー: player.UserId → 累積秒数
local tickTimers = {}

-- ------------------------------------------------------------------ utility

--- SeedDatabase をキャッシュ（require は一度だけ）
local SeedDatabase = require(game.ReplicatedStorage.Shared.Config.SeedDatabase)

--- シード ID → シードデータのマップを構築する。
local seedMap = {}
for _, seed in ipairs(SeedDatabase) do
	seedMap[seed.id] = seed
end

--- RemoteEvent を取得するヘルパー。Remotes フォルダが存在することを前提とする。
---@param name string
---@return RemoteEvent|nil
local function getRemoteEvent(name)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return nil end
	return remotes:FindFirstChild(name)
end

--- プレイヤーが super_grow ゲームパスを持っているか確認する。
---@param player Player
---@return boolean
local function hasSuperGrow(player)
	local data = DataService.getData(player)
	if not data then return false end
	return data.gamePasses and data.gamePasses["super_grow"] == true
end

--- 指定ステージの次のステージ名を返す。存在しない場合は nil を返す。
---@param stage string
---@return string|nil
local function nextStage(stage)
	local idx = STAGE_INDEX[stage]
	if not idx then return nil end
	return GROWTH_STAGES[idx + 1]
end

-- ------------------------------------------------------------------ remote setup

--- GardenService 用の RemoteEvent を ReplicatedStorage/Remotes に作成する。
local function setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local eventNames = { "PlantSeed", "WaterPlot", "HatchEgg", "GardenUpdate", "MonsterHatched" }
	for _, name in ipairs(eventNames) do
		if not remotes:FindFirstChild(name) then
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = remotes
		end
	end
end

-- ------------------------------------------------------------------ offline growth

--- オフライン成長を処理する。
--- プレイヤーが離席していた秒数を全プロットに適用し、ステージを進める。
--- Egg ステージでは停止する（手動孵化が必要）。
---@param player Player
function GardenService.processOfflineGrowth(player)
	local data = DataService.getData(player)
	if not data then return end

	local offlineSeconds = data._offlineSeconds or 0
	if offlineSeconds <= 0 then return end

	-- super_grow は接続中にのみ適用（オフライン中は等速）
	local elapsed = offlineSeconds

	for plotIndex, plot in pairs(data.garden) do
		if type(plot) == "table" and plot.stage then
			local remaining = elapsed

			-- Egg・Ultimate では停止
			while remaining > 0 and plot.stage ~= "Egg" and plot.stage ~= "Ultimate" do
				local duration = STAGE_DURATIONS[plot.stage]
				if not duration or duration <= 0 then break end

				local needed = duration - (plot.growthProgress or 0)
				if remaining >= needed then
					-- 次のステージへ
					remaining = remaining - needed
					local ns = nextStage(plot.stage)
					if ns then
						plot.stage = ns
						plot.growthProgress = 0
						plot.watered = false
						-- Egg に到達したら停止
						if plot.stage == "Egg" then
							break
						end
					else
						break
					end
				else
					plot.growthProgress = (plot.growthProgress or 0) + remaining
					remaining = 0
				end
			end
		end
	end

	-- オフライン秒数を消費済みにする
	data._offlineSeconds = 0
	print(string.format("[GardenService] Offline growth applied for %s (%ds)", player.Name, elapsed))
end

-- ------------------------------------------------------------------ plant seed

--- 指定プロットに種を植える。
--- プロットが空でなければ失敗。所持していない場合はコインで購入試行。
---@param player Player
---@param plotIndex number
---@param seedId string
---@return boolean, string
function GardenService.plantSeed(player, plotIndex, seedId)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	-- プロット空きチェック
	if data.garden[plotIndex] then
		return false, "plot_occupied"
	end

	-- シード存在確認
	local seedData = seedMap[seedId]
	if not seedData then
		return false, "invalid_seed"
	end

	-- 所持種チェック
	local hasSeed = false
	local seedInventory = data.seeds or {}
	for i, ownedSeedId in ipairs(seedInventory) do
		if ownedSeedId == seedId then
			hasSeed = true
			table.remove(seedInventory, i)
			break
		end
	end

	-- 所持していない場合はコインで購入
	if not hasSeed then
		if seedData.currencyType == "coins" then
			local spent = DataService.spendCoins(player, seedData.cost)
			if not spent then
				return false, "insufficient_coins"
			end
		else
			-- robux 購入シードは所持していなければ植えられない
			return false, "no_seed"
		end
	end

	-- プロットデータ作成
	data.garden[plotIndex] = {
		seedId        = seedId,
		stage         = "Seed",
		growthProgress = 0,
		soilType      = "Normal",
		plantedAt     = os.time(),
		watered       = false,
	}

	print(string.format("[GardenService] %s planted %s at plot %d", player.Name, seedId, plotIndex))

	-- クライアントへ通知
	local gardenUpdate = getRemoteEvent("GardenUpdate")
	if gardenUpdate then
		gardenUpdate:FireClient(player, "plant", plotIndex, data.garden[plotIndex])
	end

	return true, "ok"
end

-- ------------------------------------------------------------------ water plot

--- 指定プロットに水をやる。watered フラグを立て、成長ボーナスを加算する。
---@param player Player
---@param plotIndex number
---@return boolean, string
function GardenService.waterPlot(player, plotIndex)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	local plot = data.garden[plotIndex]
	if not plot then return false, "no_plot" end
	if plot.watered then return false, "already_watered" end

	plot.watered = true
	plot.growthProgress = (plot.growthProgress or 0) + WATER_BONUS_SECONDS

	print(string.format("[GardenService] %s watered plot %d (+%ds)", player.Name, plotIndex, WATER_BONUS_SECONDS))

	local gardenUpdate = getRemoteEvent("GardenUpdate")
	if gardenUpdate then
		gardenUpdate:FireClient(player, "water", plotIndex, plot)
	end

	return true, "ok"
end

-- ------------------------------------------------------------------ hatch egg

--- Egg ステージのプロットを孵化させる。
--- MonsterService.rollMonster を呼び、モンスターをプレイヤーに追加する。
---@param player Player
---@param plotIndex number
---@return boolean, string
function GardenService.hatchEgg(player, plotIndex)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	local plot = data.garden[plotIndex]
	if not plot then return false, "no_plot" end
	if plot.stage ~= "Egg" then return false, "not_egg" end

	-- MonsterService からモンスターをロール
	local MonsterService = require(game.ServerScriptService.Server.Services.MonsterService)
	local monster = MonsterService.rollMonster(player, plot.seedId, plot.soilType)
	if not monster then
		return false, "roll_failed"
	end

	-- モンスター追加
	if not data.monsters then data.monsters = {} end
	table.insert(data.monsters, monster)

	-- コレクション更新
	if not data.collection then data.collection = {} end
	data.collection[monster.id] = true

	-- 統計更新
	data.stats.totalMonsters = (data.stats.totalMonsters or 0) + 1

	-- leaderstats 更新
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Monsters") then
		ls.Monsters.Value = data.stats.totalMonsters
	end

	-- Egg → Juvenile に進める
	plot.stage = "Juvenile"
	plot.growthProgress = 0
	plot.watered = false

	print(string.format("[GardenService] %s hatched %s from plot %d", player.Name, monster.id, plotIndex))

	-- MonsterHatched イベント
	local monsterHatched = getRemoteEvent("MonsterHatched")
	if monsterHatched then
		monsterHatched:FireClient(player, monster, plotIndex)
	end

	-- GardenUpdate イベント
	local gardenUpdate = getRemoteEvent("GardenUpdate")
	if gardenUpdate then
		gardenUpdate:FireClient(player, "hatch", plotIndex, plot)
	end

	return true, "ok"
end

-- ------------------------------------------------------------------ growth tick

--- 単一プロットの成長を dt 秒分進める。ステージが変化したら true を返す。
---@param plot table
---@param dt number
---@param multiplier number
---@return boolean stageChanged
local function tickPlot(plot, dt, multiplier)
	-- Egg・Ultimate は自動進行しない
	if plot.stage == "Egg" or plot.stage == "Ultimate" then
		return false
	end

	local duration = STAGE_DURATIONS[plot.stage]
	if not duration or duration <= 0 then
		return false
	end

	plot.growthProgress = (plot.growthProgress or 0) + dt * multiplier

	if plot.growthProgress >= duration then
		local ns = nextStage(plot.stage)
		if ns then
			plot.stage = ns
			plot.growthProgress = 0
			plot.watered = false
			return true
		end
	end

	return false
end

-- ------------------------------------------------------------------ update (game loop)

--- ゲームループから毎フレーム呼ばれる成長処理。
--- GROWTH_TICK_INTERVAL 秒ごとに全プレイヤーの全プロットを更新する。
---@param dt number
function GardenService.update(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		tickTimers[userId] = (tickTimers[userId] or 0) + dt

		if tickTimers[userId] >= GROWTH_TICK_INTERVAL then
			local tickDt = tickTimers[userId]
			tickTimers[userId] = 0

			local data = DataService.getData(player)
			if data and data.garden then
				local multiplier = hasSuperGrow(player) and SUPER_GROW_MULTIPLIER or 1.0

				for plotIndex, plot in pairs(data.garden) do
					if type(plot) == "table" then
						local changed = tickPlot(plot, tickDt, multiplier)
						if changed then
							-- ステージ変化をクライアントへ通知
							local gardenUpdate = getRemoteEvent("GardenUpdate")
							if gardenUpdate then
								gardenUpdate:FireClient(player, "stageChange", plotIndex, plot)
							end
							print(string.format(
								"[GardenService] %s plot %d → %s",
								player.Name, plotIndex, plot.stage
							))
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
	-- DataService 参照を取得
	DataService = require(game.ServerScriptService.Server.Services.DataService)

	-- Remotes セットアップ
	setupRemotes()

	-- PlantSeed リモートイベント
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	remotes:WaitForChild("PlantSeed").OnServerEvent:Connect(function(player, plotIndex, seedId)
		GardenService.plantSeed(player, plotIndex, seedId)
	end)

	remotes:WaitForChild("WaterPlot").OnServerEvent:Connect(function(player, plotIndex)
		GardenService.waterPlot(player, plotIndex)
	end)

	remotes:WaitForChild("HatchEgg").OnServerEvent:Connect(function(player, plotIndex)
		GardenService.hatchEgg(player, plotIndex)
	end)

	-- PlayerAdded: オフライン成長を処理
	Players.PlayerAdded:Connect(function(player)
		-- DataService.loadData が完了するまで待つ
		task.wait(1)
		GardenService.processOfflineGrowth(player)
	end)

	-- 既に入室済みプレイヤーの処理
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			GardenService.processOfflineGrowth(player)
		end)
	end

	print("[GardenService] Initialized.")
end

return GardenService
