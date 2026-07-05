--[[
	DataService
	プレイヤーデータの永続化・読み込み・更新を担当するサービス。
	v2: オープンワールド化スキーマ。inventory（seeds/capturedMonsters）と
	garden.plots 構造を導入し、v1 データ（MonsterGardenData_v1）を初回ロード時に
	自動マイグレーションする。v1 ストアは削除せず残す（ロールバック保険）。
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require(game.ReplicatedStorage.Shared.Net)

-- ------------------------------------------------------------------ constants

local DATASTORE_NAME_V2 = "MonsterGardenData_v2"
local DATASTORE_NAME_V1 = "MonsterGardenData_v1"
local MAX_RETRIES = 3
local AUTOSAVE_INTERVAL = 120 -- seconds
local MAX_OFFLINE_SECONDS = 28800 -- 8 hours

-- ------------------------------------------------------------------ defaults

--- プレイヤーデータのデフォルト値テンプレート（スキーマ v2）。
local DEFAULT_DATA = {
	schemaVersion = 2,
	coins = 500,
	inventory = {
		seeds = { "fire_seed", "water_seed", "grass_seed" },
		capturedMonsters = {}, -- 野生捕獲したモンスター（庭園展示前の手持ち）
	},
	garden = {
		plots = {}, -- plotIndex → plotData
	},
	monsters = {}, -- 孵化・捕獲済みモンスターの配列
	collection = {}, -- 発見済み図鑑: { monsterId = true }
	stats = {
		totalMonsters = 0,
		totalCaptures = 0,
		loginStreak = 0,
		lastLoginDate = "",
		lastLogoutTime = 0,
	},
	gamePasses = {}, -- { passId = true }
	settings = {
		language = "ja",
	},
}

-- ------------------------------------------------------------------ module

local DataService = {}

-- DataStore インスタンス
local dataStoreV2
local dataStoreV1

-- ランタイムキャッシュ: player.UserId → table
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

--- デフォルト値で欠損キーを再帰的に補完する（既存値は保持）。
---@param data table
---@param defaults table
local function mergeWithDefaults(data, defaults)
	for key, defaultValue in pairs(defaults) do
		if data[key] == nil then
			if type(defaultValue) == "table" then
				data[key] = deepCopy(defaultValue)
			else
				data[key] = defaultValue
			end
		elseif type(defaultValue) == "table" and type(data[key]) == "table" then
			-- 配列（連番）はそのまま、辞書のみ再帰補完
			if #defaultValue == 0 then
				mergeWithDefaults(data[key], defaultValue)
			end
		end
	end
end

--- 今日の日付文字列（YYYY-MM-DD）を返す。
---@return string
local function todayString()
	return tostring(os.date("%Y-%m-%d"))
end

-- ------------------------------------------------------------------ migration

--- v1 スキーマのデータを v2 に変換する。
--- v1: { coins, seeds, garden(plotIndex→plotData), monsters, collection, stats, gamePasses, settings }
---@param v1Data table
---@return table v2Data
local function migrateV1ToV2(v1Data)
	local v2Data = deepCopy(DEFAULT_DATA)

	v2Data.coins = v1Data.coins or DEFAULT_DATA.coins
	v2Data.inventory.seeds = v1Data.seeds or deepCopy(DEFAULT_DATA.inventory.seeds)
	v2Data.garden.plots = v1Data.garden or {}
	v2Data.monsters = v1Data.monsters or {}
	v2Data.collection = v1Data.collection or {}
	v2Data.gamePasses = v1Data.gamePasses or {}
	v2Data.settings = v1Data.settings or deepCopy(DEFAULT_DATA.settings)

	if v1Data.stats then
		for key, value in pairs(v1Data.stats) do
			v2Data.stats[key] = value
		end
	end
	v2Data.stats.totalCaptures = v2Data.stats.totalCaptures or 0

	return v2Data
end

-- ------------------------------------------------------------------ DataStore I/O

--- DataStore からデータを取得する（リトライ付き・指数バックオフ）。
---@param store DataStore
---@param key string
---@return table|nil
local function getFromStore(store, key)
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return result
		end
		warn("[DataService] GetAsync failed (attempt " .. attempt .. "/" .. MAX_RETRIES .. "): " .. tostring(result))
		if attempt < MAX_RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	return nil
end

--- DataStore にデータを保存する（リトライ付き・指数バックオフ）。
---@param store DataStore
---@param key string
---@param data table
---@return boolean
local function setToStore(store, key, data)
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(function()
			store:SetAsync(key, data)
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

-- ------------------------------------------------------------------ login streak

--- 連続ログイン日数を更新する。
---@param stats table
local function updateLoginStreak(stats)
	local today = todayString()
	if stats.lastLoginDate == today then
		return -- 同日ログイン: 変更なし
	end

	local secondsSinceLogout = os.time() - (stats.lastLogoutTime or 0)
	if stats.lastLoginDate ~= "" and secondsSinceLogout < 172800 then
		-- 48時間以内なら連続ログインとみなす
		stats.loginStreak = (stats.loginStreak or 0) + 1
	else
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

	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
	end
	coins.Value = data.coins or 0

	local monsters = leaderstats:FindFirstChild("Monsters")
	if not monsters then
		monsters = Instance.new("IntValue")
		monsters.Name = "Monsters"
		monsters.Parent = leaderstats
	end
	monsters.Value = (data.stats and data.stats.totalMonsters) or 0
end

-- ------------------------------------------------------------------ public API

--- プレイヤーデータを読み込みキャッシュに格納する。
--- v2 に無ければ v1 を読んでマイグレーションし、v2 として保存する。
---@param player Player
function DataService.loadData(player)
	local key = "player_" .. player.UserId

	local data = getFromStore(dataStoreV2, key)
	if not data then
		-- v1 からのマイグレーションを試みる
		local v1Data = getFromStore(dataStoreV1, key)
		if v1Data then
			data = migrateV1ToV2(v1Data)
			print("[DataService] Migrated v1 → v2 for " .. player.Name)
			-- 即時 v2 保存（v1 は残す）
			setToStore(dataStoreV2, key, data)
		else
			data = deepCopy(DEFAULT_DATA)
			print("[DataService] New player: " .. player.Name)
		end
	end

	mergeWithDefaults(data, DEFAULT_DATA)
	data.schemaVersion = 2

	-- オフライン経過秒数を一時フィールドに記録（GardenService が消費）
	local lastLogout = (data.stats and data.stats.lastLogoutTime) or 0
	if lastLogout > 0 then
		data._offlineSeconds = math.min(os.time() - lastLogout, MAX_OFFLINE_SECONDS)
	else
		data._offlineSeconds = 0
	end

	updateLoginStreak(data.stats)

	playerCache[player.UserId] = data
	setupLeaderstats(player, data)

	print("[DataService] Loaded data for " .. player.Name)
end

--- プレイヤーデータを DataStore に保存する。
---@param player Player
function DataService.saveData(player)
	local data = playerCache[player.UserId]
	if not data then
		warn("[DataService] saveData: no cache for " .. player.Name)
		return
	end

	data.stats.lastLogoutTime = os.time()
	-- _offlineSeconds は一時フィールドなので保存しない
	data._offlineSeconds = nil

	local key = "player_" .. player.UserId
	local success = setToStore(dataStoreV2, key, data)
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

--- プレイヤーデータの特定キーを更新し、クライアントに通知する。
---@param player Player
---@param key string
---@param value any
function DataService.updateData(player, key, value)
	local data = playerCache[player.UserId]
	if not data then
		return
	end
	data[key] = value

	-- leaderstats の同期
	if key == "coins" then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and leaderstats:FindFirstChild("Coins") then
			leaderstats.Coins.Value = value
		end
	end

	Net.event("UpdatePlayerData"):FireClient(player, key, value)
end

--- コインを加算する。
---@param player Player
---@param amount number
function DataService.addCoins(player, amount)
	local data = playerCache[player.UserId]
	if not data then
		return
	end
	data.coins = (data.coins or 0) + amount
	DataService.updateData(player, "coins", data.coins)
end

--- コインを消費する。残高不足なら false。
---@param player Player
---@param amount number
---@return boolean
function DataService.spendCoins(player, amount)
	local data = playerCache[player.UserId]
	if not data then
		return false
	end
	if (data.coins or 0) < amount then
		return false
	end
	data.coins = data.coins - amount
	DataService.updateData(player, "coins", data.coins)
	return true
end

--- 統計値をインクリメントし leaderstats を同期する。
---@param player Player
---@param statKey string
---@param delta number|nil 省略時 1
function DataService.incrementStat(player, statKey, delta)
	local data = playerCache[player.UserId]
	if not data then
		return
	end
	data.stats[statKey] = (data.stats[statKey] or 0) + (delta or 1)

	if statKey == "totalMonsters" then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and leaderstats:FindFirstChild("Monsters") then
			leaderstats.Monsters.Value = data.stats.totalMonsters
		end
	end
end

-- ------------------------------------------------------------------ init

--- DataService を初期化する。
function DataService.init()
	dataStoreV2 = DataStoreService:GetDataStore(DATASTORE_NAME_V2)
	dataStoreV1 = DataStoreService:GetDataStore(DATASTORE_NAME_V1)

	-- クライアントからのデータ取得
	Net.func("GetPlayerData").OnServerInvoke = function(player)
		return playerCache[player.UserId]
	end

	-- PlayerAdded / 既接続プレイヤー
	Players.PlayerAdded:Connect(function(player)
		DataService.loadData(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		DataService.loadData(player)
	end

	-- PlayerRemoving
	Players.PlayerRemoving:Connect(function(player)
		DataService.saveData(player)
		playerCache[player.UserId] = nil
	end)

	-- Autosave ループ
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

	print("[DataService] Initialized (schema v2).")
end

return DataService
