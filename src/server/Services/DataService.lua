--[[
	DataService
	プレイヤーデータの永続化・読み込み・更新を担当するサービス。
	DataStoreService を使い、リトライ付きで安全に保存・取得する。
]]

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ------------------------------------------------------------------ constants

local DATASTORE_NAME = "MonsterGardenData_v1"
local MAX_RETRIES    = 3
local AUTOSAVE_INTERVAL = 120   -- seconds
local MAX_OFFLINE_SECONDS = 28800  -- 8 hours

-- ------------------------------------------------------------------ defaults

--- プレイヤーデータのデフォルト値テンプレート。
local DEFAULT_DATA = {
	coins   = 500,
	seeds   = { "fire_seed", "water_seed", "grass_seed" },
	garden  = {},   -- plotIndex → plotData
	monsters = {},  -- array of { monsterId, name, rarity, ... }
	collection = {},  -- set of discovered monster IDs: { monsterId = true }
	stats = {
		totalMonsters  = 0,
		loginStreak    = 0,
		lastLoginDate  = "",
		lastLogoutTime = 0,
	},
	gamePasses = {},  -- { passId = true }
	settings = {
		language = "ja",
	},
}

-- ------------------------------------------------------------------ module

local DataService = {}

-- DataStore インスタンス
local playerDataStore

-- ランタイムキャッシュ: player.UserId → data table
local playerCache = {}

-- autosave タイマー
local autosaveTimer = 0

-- ------------------------------------------------------------------ utility

--- テーブルのディープコピーを返す。
---@param original table
---@return table
local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

--- デフォルトデータをベースに、保存済みデータをマージして返す。
--- 保存済みデータに存在しないキーはデフォルト値で補完する。
---@param saved table
---@return table
local function mergeWithDefaults(saved)
	local result = deepCopy(DEFAULT_DATA)
	for key, value in pairs(saved) do
		if type(value) == "table" and type(result[key]) == "table" then
			-- ネストしたテーブルは再帰マージ
			for k, v in pairs(value) do
				result[key][k] = v
			end
		else
			result[key] = value
		end
	end
	return result
end

--- 今日の日付文字列を返す（YYYY-MM-DD）。
---@return string
local function getTodayDateString()
	return tostring(os.date("%Y-%m-%d"))
end

-- ------------------------------------------------------------------ DataStore I/O

--- DataStore からデータを取得する（リトライ付き）。
---@param key string
---@return table|nil
local function getFromStore(key)
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(function()
			return playerDataStore:GetAsync(key)
		end)
		if ok then
			return result
		end
		warn("[DataService] GetAsync failed (attempt " .. attempt .. "/" .. MAX_RETRIES .. "): " .. tostring(result))
		if attempt < MAX_RETRIES then
			-- 指数バックオフ: 2^attempt 秒待機
			task.wait(2 ^ attempt)
		end
	end
	return nil
end

--- DataStore にデータを保存する（リトライ付き）。
---@param key string
---@param data table
---@return boolean
local function setToStore(key, data)
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(function()
			playerDataStore:SetAsync(key, data)
		end)
		if ok then
			return true
		end
		warn("[DataService] SetAsync failed (attempt " .. attempt .. "/" .. MAX_RETRIES .. "): " .. tostring(err))
		if attempt < MAX_RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	return false
end

-- ------------------------------------------------------------------ RemoteStorage setup

--- ReplicatedStorage に Remotes フォルダと Remote オブジェクトを作成する。
local function setupRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	-- GetPlayerData: クライアントからのデータ取得リクエスト
	if not remotes:FindFirstChild("GetPlayerData") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "GetPlayerData"
		rf.Parent = remotes
	end

	-- UpdatePlayerData: サーバーからクライアントへのデータ同期
	if not remotes:FindFirstChild("UpdatePlayerData") then
		local re = Instance.new("RemoteEvent")
		re.Name = "UpdatePlayerData"
		re.Parent = remotes
	end

	-- GetPlayerData ハンドラ
	local getPlayerDataRF = remotes:WaitForChild("GetPlayerData")
	getPlayerDataRF.OnServerInvoke = function(player)
		return DataService.getData(player)
	end
end

-- ------------------------------------------------------------------ login streak

--- ログインストリークを計算して更新する。
---@param data table
local function updateLoginStreak(data)
	local today = getTodayDateString()
	local stats = data.stats

	if stats.lastLoginDate == "" then
		-- 初回ログイン
		stats.loginStreak   = 1
		stats.lastLoginDate = today
		return
	end

	if stats.lastLoginDate == today then
		-- 同日ログイン：変更なし
		return
	end

	-- 昨日ログインしていたか確認（簡易判定：lastLoginDate と today の差が ~1日）
	-- Roblox では os.date が使えるが差分計算は os.time() ベースで行う
	-- lastLoginDate は文字列なので os.time への変換は省略し、
	-- stats.lastLogoutTime（エポック秒）を使って判定する
	local secondsSinceLogout = os.time() - (stats.lastLogoutTime or 0)
	if secondsSinceLogout < 172800 then
		-- 48時間以内なら連続ログインとみなす
		stats.loginStreak   = (stats.loginStreak or 0) + 1
	else
		-- ストリークリセット
		stats.loginStreak = 1
	end
	stats.lastLoginDate = today
end

-- ------------------------------------------------------------------ leaderstats

--- プレイヤーの leaderstats を作成または更新する。
---@param player Player
---@param data table
local function setupLeaderstats(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	-- Coins
	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
	end
	coins.Value = data.coins or 0

	-- Monsters
	local monsters = leaderstats:FindFirstChild("Monsters")
	if not monsters then
		monsters = Instance.new("IntValue")
		monsters.Name = "Monsters"
		monsters.Parent = leaderstats
	end
	monsters.Value = data.stats and data.stats.totalMonsters or 0
end

-- ------------------------------------------------------------------ public API

--- プレイヤーデータを DataStore から読み込み、キャッシュに格納する。
---@param player Player
function DataService.loadData(player)
	local key = "player_" .. player.UserId
	local saved = getFromStore(key)

	local data
	if saved then
		data = mergeWithDefaults(saved)
	else
		data = deepCopy(DEFAULT_DATA)
		print("[DataService] New player: " .. player.Name)
	end

	-- オフライン経過秒数の計算（最大 8 時間）
	local offlineSeconds = 0
	if data.stats.lastLogoutTime and data.stats.lastLogoutTime > 0 then
		local elapsed = os.time() - data.stats.lastLogoutTime
		offlineSeconds = math.min(elapsed, MAX_OFFLINE_SECONDS)
	end
	data._offlineSeconds = offlineSeconds

	-- ログインストリーク更新
	updateLoginStreak(data)

	-- キャッシュ格納
	playerCache[player.UserId] = data

	-- leaderstats 作成
	setupLeaderstats(player, data)

	print(string.format("[DataService] Loaded data for %s (offline: %ds)", player.Name, offlineSeconds))
	return data
end

--- プレイヤーデータを DataStore に保存する。
---@param player Player
function DataService.saveData(player)
	local data = playerCache[player.UserId]
	if not data then
		warn("[DataService] saveData: no cache for " .. player.Name)
		return
	end

	-- 保存前に lastLogoutTime を更新
	data.stats.lastLogoutTime = os.time()
	-- _offlineSeconds は一時フィールドなので保存しない
	data._offlineSeconds = nil

	local key = "player_" .. player.UserId
	local success = setToStore(key, data)
	if success then
		print("[DataService] Saved data for " .. player.Name)
	else
		warn("[DataService] FAILED to save data for " .. player.Name)
	end
end

--- キャッシュからプレイヤーデータを返す。
---@param player Player
---@return table|nil
function DataService.getData(player)
	return playerCache[player.UserId]
end

--- プレイヤーデータの特定キーを更新し、RemoteEvent でクライアントに通知する。
---@param player Player
---@param key string
---@param value any
function DataService.updateData(player, key, value)
	local data = playerCache[player.UserId]
	if not data then return end
	data[key] = value

	-- leaderstats の同期
	if key == "coins" then
		local ls = player:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Coins") then
			ls.Coins.Value = value
		end
	end

	-- クライアントへ通知
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local updateEvent = remotes:FindFirstChild("UpdatePlayerData")
		if updateEvent then
			updateEvent:FireClient(player, key, value)
		end
	end
end

--- コインを加算する。
---@param player Player
---@param amount number
function DataService.addCoins(player, amount)
	local data = playerCache[player.UserId]
	if not data then return end
	data.coins = (data.coins or 0) + amount
	DataService.updateData(player, "coins", data.coins)
end

--- コインを消費する。所持金が足りなければ false を返す。
---@param player Player
---@param amount number
---@return boolean
function DataService.spendCoins(player, amount)
	local data = playerCache[player.UserId]
	if not data then return false end
	if (data.coins or 0) < amount then
		return false
	end
	data.coins = data.coins - amount
	DataService.updateData(player, "coins", data.coins)
	return true
end

-- ------------------------------------------------------------------ init

--- DataService を初期化する。DataStore・Remotes・PlayerAdded/Removing・autosave を設定する。
function DataService.init()
	-- DataStore 作成
	playerDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
	print("[DataService] DataStore ready: " .. DATASTORE_NAME)

	-- Remotes セットアップ
	setupRemotes()

	-- PlayerAdded
	Players.PlayerAdded:Connect(function(player)
		DataService.loadData(player)
	end)

	-- 既に入室済みのプレイヤーへの対応（テスト環境など）
	for _, player in ipairs(Players:GetPlayers()) do
		DataService.loadData(player)
	end

	-- PlayerRemoving
	Players.PlayerRemoving:Connect(function(player)
		DataService.saveData(player)
		playerCache[player.UserId] = nil
	end)

	-- Autosave ループ（RunService.Heartbeat で累積、120秒ごとに保存）
	RunService.Heartbeat:Connect(function(dt)
		autosaveTimer = autosaveTimer + dt
		if autosaveTimer >= AUTOSAVE_INTERVAL then
			autosaveTimer = 0
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.saveData(player)
			end
		end
	end)

	-- BindToClose: サーバーシャットダウン時に全プレイヤー保存
	game:BindToClose(function()
		print("[DataService] BindToClose: saving all players...")
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.saveData(player)
		end
		print("[DataService] BindToClose: done.")
	end)

	print("[DataService] Initialized.")
end

return DataService
