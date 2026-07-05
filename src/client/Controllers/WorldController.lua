--[[
	WorldController
	クライアント側のワールド体験を担当するコントローラ。
	プレイヤー位置からバイオームを検知し、BGM をクロスフェード切替する。
	島滞在中は island BGM を再生する。WarpCompleted でエリア状態を同期する。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)
local BiomeConfig = require(Shared.Config.BiomeConfig)
local Net = require(Shared.Net)

-- ------------------------------------------------------------------ constants

--- バイオーム検知の間隔（秒）
local BIOME_CHECK_INTERVAL = 1.0
--- BGM フェード時間（秒）
local BGM_FADE_SECONDS = 1.5

-- ------------------------------------------------------------------ module

local WorldController = {}

local localPlayer = Players.LocalPlayer

--- 現在の場所: "world" | "island"
local currentLocation = "world"
--- 現在の BGM キー
local currentBgmKey = nil
--- 再生中の Sound インスタンス
local currentSound = nil
--- バイオーム検知タイマー
local checkTimer = 0

-- ------------------------------------------------------------------ BGM

--- BGM を指定キーに切り替える（クロスフェード）。assetId 0 は停止扱い。
---@param bgmKey string|nil
local function switchBgm(bgmKey)
	if bgmKey == currentBgmKey then
		return
	end
	currentBgmKey = bgmKey

	-- 既存 BGM をフェードアウトして破棄
	if currentSound then
		local oldSound = currentSound
		currentSound = nil
		local fadeOut = TweenService:Create(oldSound, TweenInfo.new(BGM_FADE_SECONDS), { Volume = 0 })
		fadeOut.Completed:Connect(function()
			oldSound:Destroy()
		end)
		fadeOut:Play()
	end

	local assetId = bgmKey and Audio.bgm[bgmKey] or 0
	if not assetId or assetId == 0 then
		return -- 未アップロード: 無音
	end

	local sound = Instance.new("Sound")
	sound.Name = "BGM_" .. bgmKey
	sound.SoundId = "rbxassetid://" .. assetId
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	currentSound = sound

	TweenService:Create(sound, TweenInfo.new(BGM_FADE_SECONDS), { Volume = Audio.bgmVolume }):Play()
end

-- ------------------------------------------------------------------ biome detection

--- 現在位置に応じた BGM キーを解決して切り替える。
local function updateBgmForPosition()
	if currentLocation == "island" then
		switchBgm("island")
		return
	end

	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local biomeId = BiomeConfig.biomeAt(rootPart.Position.X, rootPart.Position.Z)
	if biomeId then
		switchBgm(BiomeConfig.Biomes[biomeId].bgmKey)
	end
end

-- ------------------------------------------------------------------ public API

--- 現在の場所区分を返す。
---@return string "world" | "island"
function WorldController.getLocation()
	return currentLocation
end

-- ------------------------------------------------------------------ init

--- WorldController を初期化する。
function WorldController.init()
	-- ワープ完了で場所を同期
	Net.event("WarpCompleted").OnClientEvent:Connect(function(destination)
		currentLocation = destination
		updateBgmForPosition()
	end)

	-- 定期バイオーム検知
	RunService.Heartbeat:Connect(function(dt)
		checkTimer = checkTimer + dt
		if checkTimer >= BIOME_CHECK_INTERVAL then
			checkTimer = 0
			updateBgmForPosition()
		end
	end)

	print("[WorldController] Initialized")
end

return WorldController
