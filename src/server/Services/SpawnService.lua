--[[
	SpawnService
	野生モンスターのスポーン管理を担当するサービス。
	バイオーム毎の上限を維持し、天候・季節に応じて SpawnPlanner で候補を抽選する。
	モデルは ServerStorage/WildModels の該当モデルを clone（無ければプリミティブ生成）。
	各スポーンには ProximityPrompt を付け、CaptureService が捕獲を検証する。
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BiomeConfig = require(game.ReplicatedStorage.Shared.Config.BiomeConfig)
local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local MonsterDatabase = require(game.ReplicatedStorage.Shared.Config.MonsterDatabase)
local Net = require(game.ReplicatedStorage.Shared.Net)
local SpawnPlanner = require(ServerScriptService.Server.Lib.SpawnPlanner)

-- ------------------------------------------------------------------ constants

--- レアリティ → 表示色（プレースホルダモデル用）
local RARITY_COLORS = {
	Normal = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(85, 170, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legend = Color3.fromRGB(255, 170, 0),
	Mythic = Color3.fromRGB(255, 85, 127),
}

-- ------------------------------------------------------------------ module

local SpawnService = {}

-- 遅延解決するサービス参照
local MonsterService

--- 捕獲ハンドラ（CaptureService.init が登録する。循環 require 回避）
local captureHandler

--- アクティブなスポーン: spawnId → { monster, biomeId, model, spawnedAt }
local activeSpawns = {}
--- バイオーム毎のアクティブ数: biomeId → number
local biomeCounts = {}
--- スポーンID採番カウンタ
local nextSpawnId = 0
--- スポーン充足チェックタイマー
local respawnTimer = 0

--- スポーンモデル格納フォルダ
local spawnFolder

-- ------------------------------------------------------------------ model

--- モンスターのスポーンモデルを取得する。
--- ServerStorage/WildModels/<monsterId> があれば clone、無ければプリミティブ生成。
---@param monster table
---@return Model
local function getSpawnModel(monster)
	local wildModels = ServerStorage:FindFirstChild("WildModels")
	local template = wildModels and wildModels:FindFirstChild(monster.id)
	if template then
		return template:Clone()
	end

	-- プレースホルダ: レアリティ色の球体
	local model = Instance.new("Model")
	model.Name = monster.id

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3, 3, 3)
	body.Anchored = true
	body.Material = Enum.Material.SmoothPlastic
	body.Color = RARITY_COLORS[monster.rarity] or RARITY_COLORS.Normal
	body.Parent = model
	model.PrimaryPart = body

	return model
end

--- バイオーム内のランダムなスポーン位置を返す。
---@param biome table
---@return Vector3
local function randomSpawnPosition(biome)
	local region = biome.region
	local half = region.size / 2 - 16 -- 端は避ける
	local x = region.centerX + (math.random() * 2 - 1) * half
	local z = region.centerZ + (math.random() * 2 - 1) * half

	-- Raycast で地表の高さを取得
	local origin = Vector3.new(x, 100, z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -200, 0))
	local y = result and (result.Position.Y + 2) or (biome.groundY + 4)
	return Vector3.new(x, y, z)
end

-- ------------------------------------------------------------------ spawn / despawn

--- 1体スポーンさせる。
---@param biomeId string
---@return string|nil spawnId
function SpawnService.spawnOne(biomeId)
	local biome = BiomeConfig.Biomes[biomeId]
	local environment = {
		weather = MonsterService.getWeather(),
		season = MonsterService.getSeason(),
		timeOfDay = MonsterService.getTimeOfDay(),
	}

	-- 候補選定（環境不一致時はフォールバック）
	local eligible = SpawnPlanner.eligibleSpecies(MonsterDatabase, biome.attributes, environment)
	if #eligible == 0 then
		eligible = SpawnPlanner.fallbackSpecies(MonsterDatabase, biome.attributes)
	end

	local monster = SpawnPlanner.pickSpawn(eligible)
	if not monster then
		return nil
	end

	nextSpawnId = nextSpawnId + 1
	local spawnId = "spawn_" .. nextSpawnId

	local model = getSpawnModel(monster)
	local position = randomSpawnPosition(biome)
	model:PivotTo(CFrame.new(position))
	model:SetAttribute("SpawnId", spawnId)
	model:SetAttribute("MonsterId", monster.id)
	model:SetAttribute("Rarity", monster.rarity)

	-- 捕獲用 ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CapturePrompt"
	prompt.ActionText = "つかまえる"
	prompt.ObjectText = monster.name
	prompt.HoldDuration = 1.0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")

	-- ProximityPrompt はサーバー側で発火する（クライアント不要・改ざん不能）
	prompt.Triggered:Connect(function(player)
		if captureHandler then
			captureHandler(player, spawnId)
		end
	end)

	model.Parent = spawnFolder

	activeSpawns[spawnId] = {
		monster = monster,
		biomeId = biomeId,
		model = model,
		spawnedAt = os.time(),
	}
	biomeCounts[biomeId] = (biomeCounts[biomeId] or 0) + 1

	Net.event("WildSpawned"):FireAllClients(spawnId, monster.id, biomeId)
	return spawnId
end

--- スポーンを取り除く。
---@param spawnId string
function SpawnService.despawn(spawnId)
	local record = activeSpawns[spawnId]
	if not record then
		return
	end
	activeSpawns[spawnId] = nil
	biomeCounts[record.biomeId] = math.max(0, (biomeCounts[record.biomeId] or 1) - 1)

	if record.model then
		record.model:Destroy()
	end
	Net.event("WildDespawned"):FireAllClients(spawnId)
end

--- スポーン記録を返す（CaptureService の検証用）。
---@param spawnId string
---@return table|nil
function SpawnService.getSpawn(spawnId)
	return activeSpawns[spawnId]
end

--- 捕獲ハンドラを登録する（CaptureService.init から呼ばれる）。
---@param handler fun(player: Player, spawnId: string)
function SpawnService.setCaptureHandler(handler)
	captureHandler = handler
end

-- ------------------------------------------------------------------ maintain loop

--- バイオーム毎の上限までスポーンを補充し、放置分をデスポーンする。
function SpawnService.maintain()
	local now = os.time()

	-- 放置デスポーン
	for spawnId, record in pairs(activeSpawns) do
		if now - record.spawnedAt >= GameConfig.Spawn.DespawnAfter then
			SpawnService.despawn(spawnId)
		end
	end

	-- 補充
	for _, biomeId in ipairs(BiomeConfig.Order) do
		local deficit = SpawnPlanner.deficit(biomeCounts[biomeId] or 0, GameConfig.Spawn.MaxPerBiome)
		for _ = 1, deficit do
			SpawnService.spawnOne(biomeId)
		end
	end
end

--- 毎フレーム呼ばれ、定期チェック間隔を管理する。
---@param dt number
function SpawnService.update(dt)
	respawnTimer = respawnTimer + dt
	if respawnTimer >= GameConfig.Spawn.RespawnCheckInterval then
		respawnTimer = 0
		SpawnService.maintain()
	end
end

--- 天候変化時に全スポーンをリフレッシュする（条件不一致の湧きを整理）。
function SpawnService.onWeatherChanged()
	-- シンプルに全デスポーン → maintain で再抽選（α版方針）
	for spawnId in pairs(activeSpawns) do
		SpawnService.despawn(spawnId)
	end
	SpawnService.maintain()
end

-- ------------------------------------------------------------------ init

--- SpawnService を初期化する。
function SpawnService.init()
	MonsterService = require(ServerScriptService.Server.Services.MonsterService)

	spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "WildSpawns"
	spawnFolder.Parent = Workspace

	-- 初期スポーン
	SpawnService.maintain()

	print("[SpawnService] Initialized")
end

return SpawnService
