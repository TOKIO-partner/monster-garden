--!strict
--[[
	UIController
	HUD（TopBar・NavBar）の生成、天気/コイン/モンスター数の表示更新、
	孵化通知の表示を担当するコントローラ。
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local UIController = {}

-- ------------------------------------------------------------------ module state

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- UI要素への参照（init後に設定）
local coinsLabel   = nil
local monsterLabel = nil
local weatherLabel = nil

-- ------------------------------------------------------------------ weather icon map

local WEATHER_ICONS = {
	Sunny   = "☀️",
	Rainy   = "🌧️",
	Snowy   = "❄️",
	Stormy  = "⛈️",
	Rainbow = "🌈",
}

-- ------------------------------------------------------------------ rarity color map

local RARITY_COLORS = {
	Normal  = Color3.fromRGB(200, 200, 200),
	Rare    = Color3.fromRGB(80,  150, 255),
	Epic    = Color3.fromRGB(180,  80, 255),
	Legend  = Color3.fromRGB(255, 180,  30),
	Mythic  = Color3.fromRGB(255,  80,  80),
}

-- ------------------------------------------------------------------ UI creation helpers

--- TextLabel を生成する汎用ヘルパー。
local function makeLabel(parent, name, text, size, position, textColor, fontSize)
	local label = Instance.new("TextLabel")
	label.Name            = name
	label.Size            = size
	label.Position        = position
	label.BackgroundTransparency = 1
	label.Text            = text
	label.TextColor3      = textColor or Color3.fromRGB(255, 255, 255)
	label.TextScaled      = false
	label.TextSize        = fontSize or 14
	label.Font            = Enum.Font.GothamBold
	label.TextXAlignment  = Enum.TextXAlignment.Center
	label.TextYAlignment  = Enum.TextYAlignment.Center
	label.Parent          = parent
	return label
end

--- TextButton を生成するヘルパー。
local function makeButton(parent, name, text, size, fontSize, bgColor)
	local btn = Instance.new("TextButton")
	btn.Name              = name
	btn.Size              = size
	btn.BackgroundColor3  = bgColor or Color3.fromRGB(40, 40, 40)
	btn.BorderSizePixel   = 0
	btn.Text              = text
	btn.TextColor3        = Color3.fromRGB(255, 255, 255)
	btn.TextScaled        = false
	btn.TextSize          = fontSize or 13
	btn.Font              = Enum.Font.GothamBold
	btn.AutoButtonColor   = true
	btn.Parent            = parent
	return btn
end

--- UICorner を追加するヘルパー。
local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent       = instance
end

-- ------------------------------------------------------------------ build HUD

--- HUD の ScreenGui と全 UI 要素を作成する。
local function buildHUD()
	-- ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name              = "MonsterGardenHUD"
	screenGui.ResetOnSpawn      = false
	screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
	screenGui.Parent            = playerGui

	-- ============================================================
	-- TopBar（上部ステータスバー）
	-- ============================================================
	local topBar = Instance.new("Frame")
	topBar.Name                 = "TopBar"
	topBar.Size                 = UDim2.new(1, 0, 0, 50)
	topBar.Position             = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3     = Color3.fromRGB(20, 20, 20)
	topBar.BackgroundTransparency = 0.3
	topBar.BorderSizePixel      = 0
	topBar.Parent               = screenGui

	-- TopBar の内側パディング
	local topPadding = Instance.new("UIPadding")
	topPadding.PaddingLeft   = UDim.new(0, 10)
	topPadding.PaddingRight  = UDim.new(0, 10)
	topPadding.PaddingTop    = UDim.new(0, 5)
	topPadding.PaddingBottom = UDim.new(0, 5)
	topPadding.Parent        = topBar

	-- TopBar 横並びレイアウト
	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection   = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	topLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
	topLayout.Padding         = UDim.new(0, 12)
	topLayout.Parent          = topBar

	-- コインフレーム
	local coinsFrame = Instance.new("Frame")
	coinsFrame.Name             = "CoinsFrame"
	coinsFrame.Size             = UDim2.new(0, 110, 0, 36)
	coinsFrame.BackgroundColor3 = Color3.fromRGB(60, 50, 10)
	coinsFrame.BackgroundTransparency = 0.2
	coinsFrame.BorderSizePixel  = 0
	coinsFrame.Parent           = topBar
	addCorner(coinsFrame, 8)

	coinsLabel = makeLabel(
		coinsFrame, "CoinsLabel", "🪙 500",
		UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(255, 220, 50), 14
	)

	-- モンスター数フレーム
	local monsterFrame = Instance.new("Frame")
	monsterFrame.Name             = "MonsterFrame"
	monsterFrame.Size             = UDim2.new(0, 110, 0, 36)
	monsterFrame.BackgroundColor3 = Color3.fromRGB(10, 50, 60)
	monsterFrame.BackgroundTransparency = 0.2
	monsterFrame.BorderSizePixel  = 0
	monsterFrame.Parent           = topBar
	addCorner(monsterFrame, 8)

	monsterLabel = makeLabel(
		monsterFrame, "MonsterLabel", "🐾 0/250",
		UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(150, 220, 255), 14
	)

	-- 天気フレーム
	local weatherFrame = Instance.new("Frame")
	weatherFrame.Name             = "WeatherFrame"
	weatherFrame.Size             = UDim2.new(0, 110, 0, 36)
	weatherFrame.BackgroundColor3 = Color3.fromRGB(10, 40, 10)
	weatherFrame.BackgroundTransparency = 0.2
	weatherFrame.BorderSizePixel  = 0
	weatherFrame.Parent           = topBar
	addCorner(weatherFrame, 8)

	weatherLabel = makeLabel(
		weatherFrame, "WeatherLabel", "☀️ 晴れ",
		UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(200, 255, 180), 14
	)

	-- ============================================================
	-- NavBar（下部ナビゲーションバー）
	-- ============================================================
	local navBar = Instance.new("Frame")
	navBar.Name                   = "NavBar"
	navBar.Size                   = UDim2.new(1, 0, 0, 60)
	navBar.AnchorPoint            = Vector2.new(0, 1)
	navBar.Position               = UDim2.new(0, 0, 1, 0)
	navBar.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
	navBar.BackgroundTransparency = 0.3
	navBar.BorderSizePixel        = 0
	navBar.Parent                 = screenGui

	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection        = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
	navLayout.VerticalAlignment    = Enum.VerticalAlignment.Center
	navLayout.Padding              = UDim.new(0, 4)
	navLayout.Parent               = navBar

	local navPadding = Instance.new("UIPadding")
	navPadding.PaddingLeft   = UDim.new(0, 8)
	navPadding.PaddingRight  = UDim.new(0, 8)
	navPadding.PaddingTop    = UDim.new(0, 6)
	navPadding.PaddingBottom = UDim.new(0, 6)
	navPadding.Parent        = navBar

	-- ナビボタン定義
	local navButtons = {
		{ name = "BtnGarden",     label = "🌱庭園" },
		{ name = "BtnCollection", label = "📖図鑑" },
		{ name = "BtnShop",       label = "🛒ショップ" },
		{ name = "BtnSettings",   label = "⚙️設定" },
	}

	for _, def in ipairs(navButtons) do
		local btn = makeButton(
			navBar, def.name, def.label,
			UDim2.new(0.23, -4, 1, -12),
			13,
			Color3.fromRGB(40, 40, 50)
		)
		addCorner(btn, 8)
	end

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
---@param weatherData table  { weather: string, weatherJP: string? }
function UIController.updateWeatherDisplay(weatherData)
	if not weatherLabel then return end
	if not weatherData then return end
	local icon = WEATHER_ICONS[weatherData.weather] or "🌤️"
	local name = weatherData.weatherJP or weatherData.weather or "晴れ"
	weatherLabel.Text = icon .. " " .. name
end

--- モンスター数表示を更新する。
---@param count number
function UIController.updateMonsterCount(count)
	if monsterLabel then
		monsterLabel.Text = "🐾 " .. tostring(count) .. "/250"
	end
end

--- 孵化通知を画面中央に表示し、3秒後に自動消去する。
---@param monster table  { name: string, rarity: string }
function UIController.showHatchNotification(monster)
	local gui = playerGui:FindFirstChild("MonsterGardenHUD")
	if not gui then return end

	local rarityColor = RARITY_COLORS[monster.rarity] or RARITY_COLORS.Normal

	-- 通知フレーム（画面中央）
	local notifFrame = Instance.new("Frame")
	notifFrame.Name                   = "HatchNotification"
	notifFrame.Size                   = UDim2.new(0, 300, 0, 120)
	notifFrame.AnchorPoint            = Vector2.new(0.5, 0.5)
	notifFrame.Position               = UDim2.new(0.5, 0, 0.5, 0)
	notifFrame.BackgroundColor3       = Color3.fromRGB(15, 15, 25)
	notifFrame.BackgroundTransparency = 0.1
	notifFrame.BorderSizePixel        = 3
	notifFrame.BorderColor3           = rarityColor
	notifFrame.ZIndex                 = 10
	notifFrame.Parent                 = gui
	addCorner(notifFrame, 12)

	-- タイトル
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name                   = "Title"
	titleLabel.Size                   = UDim2.new(1, 0, 0, 36)
	titleLabel.Position               = UDim2.new(0, 0, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text                   = "🥚 孵化！"
	titleLabel.TextColor3             = rarityColor
	titleLabel.TextSize               = 20
	titleLabel.Font                   = Enum.Font.GothamBold
	titleLabel.TextXAlignment         = Enum.TextXAlignment.Center
	titleLabel.ZIndex                 = 11
	titleLabel.Parent                 = notifFrame

	-- モンスター名
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                    = "MonsterName"
	nameLabel.Size                    = UDim2.new(1, -20, 0, 28)
	nameLabel.Position                = UDim2.new(0, 10, 0, 46)
	nameLabel.BackgroundTransparency  = 1
	nameLabel.Text                    = monster.name or monster.id or "Unknown"
	nameLabel.TextColor3              = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize                = 16
	nameLabel.Font                    = Enum.Font.Gotham
	nameLabel.TextXAlignment          = Enum.TextXAlignment.Center
	nameLabel.ZIndex                  = 11
	nameLabel.Parent                  = notifFrame

	-- レアリティラベル
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name                  = "Rarity"
	rarityLabel.Size                  = UDim2.new(1, -20, 0, 24)
	rarityLabel.Position              = UDim2.new(0, 10, 0, 76)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text                  = "[ " .. (monster.rarity or "Normal") .. " ]"
	rarityLabel.TextColor3            = rarityColor
	rarityLabel.TextSize              = 14
	rarityLabel.Font                  = Enum.Font.GothamBold
	rarityLabel.TextXAlignment        = Enum.TextXAlignment.Center
	rarityLabel.ZIndex                = 11
	rarityLabel.Parent                = notifFrame

	-- 3秒後にフェードアウトして消去
	task.delay(3, function()
		if not notifFrame or not notifFrame.Parent then return end
		local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(notifFrame, tweenInfo, {
			BackgroundTransparency = 1,
			Position               = UDim2.new(0.5, 0, 0.4, 0),
		})
		-- 子要素もフェード
		for _, child in ipairs(notifFrame:GetChildren()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, tweenInfo, { TextTransparency = 1 }):Play()
			end
		end
		tween.Completed:Connect(function()
			notifFrame:Destroy()
		end)
		tween:Play()
	end)
end

-- ------------------------------------------------------------------ remote listeners

--- サーバーからのリモートイベントを購読する。
local function setupRemoteListeners()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if not remotes then
		warn("[UIController] Remotes folder not found")
		return
	end

	-- 天気更新
	local weatherUpdate = remotes:WaitForChild("WeatherUpdate", 10)
	if weatherUpdate then
		weatherUpdate.OnClientEvent:Connect(function(weatherData)
			UIController.updateWeatherDisplay(weatherData)
		end)
	end

	-- 孵化通知
	local monsterHatched = remotes:WaitForChild("MonsterHatched", 10)
	if monsterHatched then
		monsterHatched.OnClientEvent:Connect(function(monster, _plotIndex)
			UIController.showHatchNotification(monster)
		end)
	end

	-- 初回天気取得（RemoteFunction）
	local getWeather = remotes:FindFirstChild("GetWeather")
	if getWeather and getWeather:IsA("RemoteFunction") then
		task.spawn(function()
			local ok, result = pcall(function()
				return getWeather:InvokeServer()
			end)
			if ok and result then
				UIController.updateWeatherDisplay(result)
			end
		end)
	end

	-- leaderstats 変化を監視
	local leaderstats = localPlayer:WaitForChild("leaderstats", 10)
	if leaderstats then
		local coinsVal   = leaderstats:WaitForChild("Coins",    10)
		local monstersVal = leaderstats:WaitForChild("Monsters", 10)
		if coinsVal then
			UIController.updateCoinsDisplay(coinsVal.Value)
			coinsVal.Changed:Connect(function(newVal)
				UIController.updateCoinsDisplay(newVal)
			end)
		end
		if monstersVal then
			UIController.updateMonsterCount(monstersVal.Value)
			monstersVal.Changed:Connect(function(newVal)
				UIController.updateMonsterCount(newVal)
			end)
		end
	end
end

-- ------------------------------------------------------------------ init

--- UIController を初期化する。
function UIController.init()
	buildHUD()
	setupRemoteListeners()
	print("[UIController] Initialized")
end

return UIController
