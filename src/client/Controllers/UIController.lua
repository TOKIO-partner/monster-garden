--[[
	UIController
	HUD（TopBar）の生成、天気/コイン/モンスター数の表示更新、
	ワープボタン、トースト通知（孵化・捕獲）を担当するコントローラ。
	v2: Remote を Net.lua 経由に統一。ワープUI・捕獲トーストを追加。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Languages = require(Shared.Localization.Languages)
local Net = require(Shared.Net)

-- ------------------------------------------------------------------ module

local UIController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- UI要素への参照（init後に設定）
local coinsLabel = nil
local monsterLabel = nil
local weatherLabel = nil
local warpButton = nil

--- 現在の場所: "world" | "island"（ワープボタン表示切替用）
local currentLocation = "world"

-- ------------------------------------------------------------------ maps

--- 天気アイコン
local WEATHER_ICONS = {
	Sunny = "☀️",
	Rainy = "🌧️",
	Snowy = "❄️",
	Stormy = "⛈️",
	Rainbow = "🌈",
}

--- レアリティ色
local RARITY_COLORS = {
	Normal = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legend = Color3.fromRGB(255, 180, 30),
	Mythic = Color3.fromRGB(255, 80, 80),
}

-- ------------------------------------------------------------------ UI helpers

--- 角丸を追加する。
local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

--- TextLabel を生成する汎用ヘルパー。
local function makeLabel(parent, name, text, size, position, textColor, fontSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextScaled = false
	label.TextSize = fontSize or 14
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

--- HUD 情報フレーム（TopBar の1項目）を生成する。
local function makeInfoFrame(parent, name, text, backgroundColor, textColor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(110, 36)
	frame.BackgroundColor3 = backgroundColor
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = parent
	addCorner(frame, 8)
	return makeLabel(frame, name .. "Label", text, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), textColor, 14)
end

-- ------------------------------------------------------------------ HUD creation

--- HUD（TopBar + ワープボタン）を生成する。
local function createHud()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MonsterGardenHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- TopBar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 46)
	topBar.Position = UDim2.fromOffset(0, 4)
	topBar.BackgroundTransparency = 1
	topBar.Parent = screenGui

	local topPadding = Instance.new("UIPadding")
	topPadding.PaddingLeft = UDim.new(0, 12)
	topPadding.PaddingTop = UDim.new(0, 5)
	topPadding.PaddingBottom = UDim.new(0, 5)
	topPadding.Parent = topBar

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.Padding = UDim.new(0, 12)
	topLayout.Parent = topBar

	coinsLabel = makeInfoFrame(topBar, "Coins", "🪙 500", Color3.fromRGB(60, 50, 10), Color3.fromRGB(255, 220, 50))
	monsterLabel =
		makeInfoFrame(topBar, "Monsters", "🐾 0/250", Color3.fromRGB(10, 50, 60), Color3.fromRGB(150, 220, 255))
	weatherLabel =
		makeInfoFrame(topBar, "Weather", "☀️ Sunny", Color3.fromRGB(10, 40, 10), Color3.fromRGB(200, 255, 200))

	-- ワープボタン（右下）
	warpButton = Instance.new("TextButton")
	warpButton.Name = "WarpButton"
	warpButton.Size = UDim2.fromOffset(160, 44)
	warpButton.AnchorPoint = Vector2.new(1, 1)
	warpButton.Position = UDim2.new(1, -16, 1, -16)
	warpButton.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
	warpButton.BackgroundTransparency = 0.1
	warpButton.Text = Languages.get("warp_to_island")
	warpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	warpButton.TextSize = 15
	warpButton.Font = Enum.Font.GothamBold
	warpButton.Parent = screenGui
	addCorner(warpButton, 10)

	warpButton.Activated:Connect(function()
		local destination = currentLocation == "world" and "island" or "world"
		Net.event("RequestWarp"):FireServer(destination)
	end)

	return screenGui
end

-- ------------------------------------------------------------------ public update functions

--- コイン表示を更新する。
---@param amount number
function UIController.updateCoinsDisplay(amount)
	if coinsLabel then
		coinsLabel.Text = "🪙 " .. tostring(amount)
	end
end

--- 天気表示を更新する。
---@param weather string
function UIController.updateWeatherDisplay(weather)
	if not weatherLabel or not weather then
		return
	end
	local icon = WEATHER_ICONS[weather] or "🌤️"
	local name = Languages.get("weather_" .. string.lower(weather))
	weatherLabel.Text = icon .. " " .. name
end

--- モンスター数表示を更新する。
---@param count number
function UIController.updateMonsterCount(count)
	if monsterLabel then
		monsterLabel.Text = "🐾 " .. tostring(count) .. "/250"
	end
end

--- トースト通知を画面中央上部に表示し、3秒後に自動消去する。
---@param title string
---@param body string
---@param rarity string|nil レアリティ色の縁取り（nil なら白）
function UIController.showToast(title, body, rarity)
	local gui = playerGui:FindFirstChild("MonsterGardenHUD")
	if not gui then
		return
	end

	local accentColor = rarity and RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.fromOffset(300, 90)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 70)
	toast.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	toast.BackgroundTransparency = 0.15
	toast.Parent = gui
	addCorner(toast, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 2
	stroke.Parent = toast

	makeLabel(toast, "Title", title, UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 6), accentColor, 20)
	makeLabel(toast, "Body", body, UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 48), Color3.fromRGB(230, 230, 230), 14)

	task.delay(3, function()
		if not toast.Parent then
			return
		end
		local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(toast, tweenInfo, {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 40),
		})
		for _, child in ipairs(toast:GetChildren()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, tweenInfo, { TextTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, tweenInfo, { Transparency = 1 }):Play()
			end
		end
		tween.Completed:Connect(function()
			toast:Destroy()
		end)
		tween:Play()
	end)
end

-- ------------------------------------------------------------------ remote listeners

--- サーバーからのリモートイベントを購読する。
local function setupRemoteListeners()
	-- 天気更新
	Net.event("WeatherUpdate").OnClientEvent:Connect(function(weather, _season)
		UIController.updateWeatherDisplay(weather)
	end)

	-- 孵化通知
	Net.event("MonsterHatched").OnClientEvent:Connect(function(monster, _plotIndex)
		UIController.showToast(Languages.get("monster_obtained"), monster.id, monster.rarity)
	end)

	-- ワープ完了でボタン表示切替
	Net.event("WarpCompleted").OnClientEvent:Connect(function(destination)
		currentLocation = destination
		if warpButton then
			warpButton.Text = destination == "world" and Languages.get("warp_to_island")
				or Languages.get("warp_to_world")
		end
	end)

	-- 初回天気取得
	task.spawn(function()
		local ok, result = pcall(function()
			return Net.func("GetWeather"):InvokeServer()
		end)
		if ok and result then
			UIController.updateWeatherDisplay(result.weather)
		end
	end)

	-- leaderstats 変化を監視
	task.spawn(function()
		local leaderstats = localPlayer:WaitForChild("leaderstats", 10)
		if not leaderstats then
			return
		end
		local coinsValue = leaderstats:WaitForChild("Coins", 10)
		local monstersValue = leaderstats:WaitForChild("Monsters", 10)
		if coinsValue then
			UIController.updateCoinsDisplay(coinsValue.Value)
			coinsValue.Changed:Connect(UIController.updateCoinsDisplay)
		end
		if monstersValue then
			UIController.updateMonsterCount(monstersValue.Value)
			monstersValue.Changed:Connect(UIController.updateMonsterCount)
		end
	end)
end

-- ------------------------------------------------------------------ init

--- UIController を初期化する。
function UIController.init()
	createHud()
	setupRemoteListeners()
	print("[UIController] Initialized")
end

return UIController
