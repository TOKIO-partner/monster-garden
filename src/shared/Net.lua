--[[
	Net
	RemoteEvent / RemoteFunction の定義・生成・取得を一元管理するモジュール。
	サーバー: Net.init() で全 Remote を生成する（起動時に1回）。
	クライアント: Net.event() / Net.func() で取得する（WaitForChild で待機）。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES_FOLDER_NAME = "Remotes"

--- RemoteEvent 名の一覧（単一情報源）
local EVENT_NAMES = {
	-- data
	"UpdatePlayerData", -- S→C: データキー更新通知
	-- garden
	"PlantSeed", -- C→S: 種を植える
	"WaterPlot", -- C→S: 水やり
	"HatchEgg", -- C→S: 孵化タップ
	"GardenUpdate", -- S→C: プロット状態変化
	"MonsterHatched", -- S→C: 孵化演出
	-- world
	"RequestWarp", -- C→S: 島⇄ワールドワープ要求
	"WarpCompleted", -- S→C: ワープ完了（バイオーム/島情報付き）
	-- capture
	"RequestCapture", -- C→S: 野生モンスター捕獲要求
	"CaptureResult", -- S→C: 捕獲結果（成功/失敗）
	"WildSpawned", -- S→C: 野生スポーン通知（演出用・任意購読）
	"WildDespawned", -- S→C: 野生デスポーン通知
	-- weather
	"WeatherUpdate", -- S→C: 天候変化通知
	-- shop
	"BuySeed", -- C→S: シードのコイン購入
}

--- RemoteFunction 名の一覧
local FUNCTION_NAMES = {
	"GetPlayerData", -- C→S: 自分のデータ取得
	"GetWeather", -- C→S: 現在の天候/季節取得
}

local Net = {}

--- Remotes フォルダを取得する（無ければ待つ／サーバーは生成）。
---@return Folder
local function getFolder()
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = REMOTES_FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME)
end

--- サーバー側で全 Remote を生成する。init.server.lua から最初に呼ぶこと。
function Net.init()
	assert(RunService:IsServer(), "[Net] init() はサーバー専用")
	local folder = getFolder()
	for _, name in ipairs(EVENT_NAMES) do
		if not folder:FindFirstChild(name) then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = name
			remoteEvent.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTION_NAMES) do
		if not folder:FindFirstChild(name) then
			local remoteFunction = Instance.new("RemoteFunction")
			remoteFunction.Name = name
			remoteFunction.Parent = folder
		end
	end
	print("[Net] Initialized: " .. #EVENT_NAMES .. " events, " .. #FUNCTION_NAMES .. " functions")
end

--- RemoteEvent を取得する。
---@param name string
---@return RemoteEvent
function Net.event(name)
	local remote = getFolder():WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), "[Net] Unknown RemoteEvent: " .. tostring(name))
	return remote
end

--- RemoteFunction を取得する。
---@param name string
---@return RemoteFunction
function Net.func(name)
	local remote = getFolder():WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteFunction"), "[Net] Unknown RemoteFunction: " .. tostring(name))
	return remote
end

return Net
