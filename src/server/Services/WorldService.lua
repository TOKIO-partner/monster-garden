--[[
	WorldService
	オープンワールドの3バイオーム地形生成（Roblox Terrain API・決定論シード）、
	ワールドスポーン、島⇄ワールドのワープを担当するサービス。
	地形はサーバー起動時にコードから生成する（コード＝地形の単一情報源）。
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BiomeConfig = require(game.ReplicatedStorage.Shared.Config.BiomeConfig)
local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(game.ReplicatedStorage.Shared.Net)

-- ------------------------------------------------------------------ constants

--- 地形生成の解像度（studs/セル）。粗いほど生成が速い
local CELL_SIZE = 16
--- 地形の基本厚み（studs）
local GROUND_DEPTH = 24
--- 起伏の最大高さ（studs）
local HILL_HEIGHT = 12
--- ノイズのスケール（小さいほどなだらか）
local NOISE_SCALE = 0.01

-- ------------------------------------------------------------------ module

local WorldService = {}

-- 遅延解決するサービス参照
local GardenService

--- プレイヤーの現在地: userId → "world" | "island"
local playerLocations = {}

-- ------------------------------------------------------------------ terrain generation

--- 1バイオーム分の地形を Terrain:FillBlock で生成する。
--- 決定論: math.noise + 固定シードで毎回同じ起伏になる。
---@param biome table BiomeConfig.Biomes の1要素
---@param seed number
local function generateBiomeTerrain(biome, seed)
	local terrain = Workspace.Terrain
	local region = biome.region
	local half = region.size / 2
	local material = Enum.Material[biome.terrainMaterial]

	local cellCount = math.floor(region.size / CELL_SIZE)

	for cellX = 0, cellCount - 1 do
		for cellZ = 0, cellCount - 1 do
			local worldX = region.centerX - half + cellX * CELL_SIZE + CELL_SIZE / 2
			local worldZ = region.centerZ - half + cellZ * CELL_SIZE + CELL_SIZE / 2

			-- 決定論ノイズで起伏を作る（seed をオフセットに混ぜる）
			local noise = math.noise((worldX + seed % 1000) * NOISE_SCALE, (worldZ + seed % 1000) * NOISE_SCALE)
			local height = GROUND_DEPTH + math.max(0, noise * HILL_HEIGHT)

			terrain:FillBlock(
				CFrame.new(worldX, biome.groundY - GROUND_DEPTH / 2 + height / 2 - GROUND_DEPTH / 2, worldZ),
				Vector3.new(CELL_SIZE, height, CELL_SIZE),
				material
			)
		end
	end
end

--- 湖畔バイオームに水面を追加する。
---@param biome table
local function generateLake(biome)
	local terrain = Workspace.Terrain
	local region = biome.region
	-- バイオーム中央に円形の湖（FillCylinder）
	terrain:FillCylinder(
		CFrame.new(region.centerX, biome.groundY - 2, region.centerZ),
		8, -- height
		region.size / 4, -- radius
		Enum.Material.Water
	)
end

--- 火山バイオームに溶岩池を追加する。
---@param biome table
local function generateLavaPool(biome)
	local terrain = Workspace.Terrain
	local region = biome.region
	terrain:FillCylinder(
		CFrame.new(region.centerX, biome.groundY - 1, region.centerZ),
		6,
		region.size / 8,
		Enum.Material.CrackedLava
	)
end

--- 全バイオームの地形を生成する。
function WorldService.generateWorld()
	local seed = GameConfig.World.TerrainSeed
	for _, biomeId in ipairs(BiomeConfig.Order) do
		local biome = BiomeConfig.Biomes[biomeId]
		generateBiomeTerrain(biome, seed)

		if biomeId == "Lakeside" then
			generateLake(biome)
		elseif biomeId == "Volcano" then
			generateLavaPool(biome)
		end
		print("[WorldService] Generated biome: " .. biomeId)
	end
end

-- ------------------------------------------------------------------ spawn / warp

--- ワールドスポーンの CFrame を返す。
---@return CFrame
function WorldService.getWorldSpawn()
	local spawn = GameConfig.World.WorldSpawn
	return CFrame.new(spawn.x, spawn.y, spawn.z)
end

--- プレイヤーをワールド⇄島間でワープさせる。
---@param player Player
---@param destination string "world" | "island"
---@return boolean
function WorldService.warp(player, destination)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	if destination == "island" then
		local islandSpawn = GardenService.getIslandSpawn(player)
		if not islandSpawn then
			return false
		end
		rootPart.CFrame = islandSpawn
		playerLocations[player.UserId] = "island"
	elseif destination == "world" then
		rootPart.CFrame = WorldService.getWorldSpawn() + Vector3.new(0, 4, 0)
		playerLocations[player.UserId] = "world"
	else
		return false
	end

	Net.event("WarpCompleted"):FireClient(player, destination)
	return true
end

--- プレイヤーの現在地区分を返す。
---@param player Player
---@return string "world" | "island"
function WorldService.getLocation(player)
	return playerLocations[player.UserId] or "world"
end

-- ------------------------------------------------------------------ init

--- WorldService を初期化する。
function WorldService.init()
	GardenService = require(ServerScriptService.Server.Services.GardenService)

	-- 地形生成（起動時1回）
	WorldService.generateWorld()

	-- ワープ要求（検証: 文字列のみ許可）
	Net.event("RequestWarp").OnServerEvent:Connect(function(player, destination)
		if destination == "world" or destination == "island" then
			WorldService.warp(player, destination)
		end
	end)

	-- キャラクタースポーン時はワールドスポーンへ
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if rootPart then
				task.wait(0.1)
				rootPart.CFrame = WorldService.getWorldSpawn() + Vector3.new(0, 4, 0)
				playerLocations[player.UserId] = "world"
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerLocations[player.UserId] = nil
	end)

	print("[WorldService] Initialized")
end

return WorldService
