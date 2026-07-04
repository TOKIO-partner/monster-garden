--[[
	CaptureService
	野生モンスターの捕獲要求を検証・処理するサービス。
	検証（クライアント不信頼）: スポーン実在・距離・成功率ロール（全部サーバー側）。
	成功時は inventory.capturedMonsters と図鑑・統計を更新する。
]]

local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(game.ReplicatedStorage.Shared.Net)
local CaptureLogic = require(ServerScriptService.Server.Lib.CaptureLogic)

-- ------------------------------------------------------------------ module

local CaptureService = {}

-- 遅延解決するサービス参照
local DataService
local SpawnService

--- 連打防止: userId → 最終捕獲試行時刻
local lastAttempt = {}
--- 捕獲試行のクールダウン（秒）
local ATTEMPT_COOLDOWN = 1.0

-- ------------------------------------------------------------------ capture

--- 捕獲要求を検証して処理する。
---@param player Player
---@param spawnId string
function CaptureService.requestCapture(player, spawnId)
	-- 引数検証
	if type(spawnId) ~= "string" then
		return
	end

	-- クールダウン
	local now = os.clock()
	if lastAttempt[player.UserId] and now - lastAttempt[player.UserId] < ATTEMPT_COOLDOWN then
		return
	end
	lastAttempt[player.UserId] = now

	-- スポーン実在検証
	local record = SpawnService.getSpawn(spawnId)
	if not record then
		Net.event("CaptureResult"):FireClient(player, false, nil, "not_found")
		return
	end

	-- 距離検証
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local modelPivot = record.model and record.model:GetPivot()
	if not rootPart or not modelPivot then
		Net.event("CaptureResult"):FireClient(player, false, nil, "invalid_state")
		return
	end
	local distance = (rootPart.Position - modelPivot.Position).Magnitude
	if not CaptureLogic.isWithinDistance(distance, GameConfig.Capture.MaxDistance) then
		Net.event("CaptureResult"):FireClient(player, false, nil, "too_far")
		return
	end

	-- データ取得
	local data = DataService.getData(player)
	if not data then
		Net.event("CaptureResult"):FireClient(player, false, nil, "no_data")
		return
	end

	-- 成功率ロール
	local monster = record.monster
	local hasLucky = data.gamePasses and data.gamePasses.lucky_gardener == true
	local captureConfig = {
		rates = GameConfig.Capture.RatesByRarity,
		luckyBonus = GameConfig.Capture.LuckyGardenerBonus,
	}
	local success, rate = CaptureLogic.roll(monster.rarity, captureConfig, hasLucky)

	if success then
		-- 捕獲成功: インベントリ・図鑑・統計更新
		local captured = {
			id = monster.id,
			rarity = monster.rarity,
			attribute = monster.attribute,
			baseValue = monster.baseValue,
			source = "capture",
			capturedAt = os.time(),
			biomeId = record.biomeId,
		}
		table.insert(data.inventory.capturedMonsters, captured)
		table.insert(data.monsters, captured)
		data.collection[monster.id] = true
		DataService.incrementStat(player, "totalCaptures")
		DataService.incrementStat(player, "totalMonsters")

		SpawnService.despawn(spawnId)

		print(
			string.format(
				"[CaptureService] %s captured %s (%s, rate=%.2f)",
				player.Name,
				monster.id,
				monster.rarity,
				rate
			)
		)
		Net.event("CaptureResult"):FireClient(player, true, captured, "ok")
	else
		-- 捕獲失敗: モンスター逃走（デスポーン）
		SpawnService.despawn(spawnId)
		print(string.format("[CaptureService] %s failed to capture %s (rate=%.2f)", player.Name, monster.id, rate))
		Net.event("CaptureResult"):FireClient(player, false, { id = monster.id, rarity = monster.rarity }, "escaped")
	end
end

-- ------------------------------------------------------------------ init

--- CaptureService を初期化する。
function CaptureService.init()
	DataService = require(ServerScriptService.Server.Services.DataService)
	SpawnService = require(ServerScriptService.Server.Services.SpawnService)

	-- ProximityPrompt 経由（主経路・サーバー内直結）
	SpawnService.setCaptureHandler(function(player, spawnId)
		CaptureService.requestCapture(player, spawnId)
	end)

	-- RemoteEvent 経由（UI からの捕獲ボタン等の予備経路）
	Net.event("RequestCapture").OnServerEvent:Connect(function(player, spawnId)
		CaptureService.requestCapture(player, spawnId)
	end)

	print("[CaptureService] Initialized")
end

return CaptureService
