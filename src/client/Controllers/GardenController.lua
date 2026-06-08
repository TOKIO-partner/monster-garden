--!strict
--[[
	GardenController
	3x3 ガーデングリッドの表示・インタラクション、種選択バーを担当するコントローラ。
	PlantSeed / WaterPlot / HatchEgg のリモートイベントをサーバーへ発火する。
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GardenController = {}

-- ------------------------------------------------------------------ constants

--- 成長ステージのアイコンマップ
local STAGE_ICONS = {
	Seed     = "🌰",
	Sprout   = "🌱",
	Bud      = "🌸",
	Egg      = "🥚",
	Juvenile = "🐣",
	Adult    = "🐾",
	Ultimate = "⭐",
}

--- 成長ステージの背景色マップ
local STAGE_COLORS = {
	Seed     = Color3.fromRGB(139,  90,  43),
	Sprout   = Color3.fromRGB(100, 180,  50),
	Bud      = Color3.fromRGB(255, 150, 200),
	Egg      = Color3.fromRGB(255, 220, 100),
	Juvenile = Color3.fromRGB(100, 200, 255),
	Adult    = Color3.fromRGB( 50, 150, 255),
	Ultimate = Color3.fromRGB(255, 200,   0),
}

--- 種ボタン定義（id・ラベル・ハイライト色）
local SEED_DEFS = {
	{ id = "fire_seed",    label = "🔥火",  color = Color3.fromRGB(200,  80,  20) },
	{ id = "water_seed",   label = "💧水",  color = Color3.fromRGB( 30, 120, 220) },
	{ id = "grass_seed",   label = "🌿草",  color = Color3.fromRGB( 60, 160,  40) },
	{ id = "light_seed",   label = "✨光",  color = Color3.fromRGB(220, 200,  50) },
	{ id = "dark_seed",    label = "🌙闇",  color = Color3.fromRGB( 80,  40, 140) },
}

-- ------------------------------------------------------------------ module state

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

--- 現在選択中の種ID（nil = 未選択）
local selectedSeed = nil

--- 種ボタン参照: seedId → TextButton
local seedButtons = {}

--- プロットボタン参照: plotIndex → TextButton
local plotButtons = {}

--- クライアント側プロットデータキャッシュ: plotIndex → plotData or nil
local plotData = {}

-- ------------------------------------------------------------------ remote references

local remotes     = nil
local plantSeedRE = nil
local waterPlotRE = nil
local hatchEggRE  = nil

-- ------------------------------------------------------------------ helpers

--- UICorner を追加するヘルパー。
local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent       = instance
end

-- ------------------------------------------------------------------ plot visual update

--- 指定プロットのボタン見た目を更新する。
---@param plotIndex number
---@param data table|nil  nil の場合は空きマス表示
function GardenController.updatePlotVisual(plotIndex, data)
	local btn = plotButtons[plotIndex]
	if not btn then return end

	if not data or not data.stage then
		-- 空きマス
		btn.Text            = "空きマス\n🌱"
		btn.BackgroundColor3 = Color3.fromRGB(60, 80, 50)
		btn.TextColor3       = Color3.fromRGB(180, 220, 160)
	else
		local stage = data.stage
		local icon  = STAGE_ICONS[stage] or "?"
		local color = STAGE_COLORS[stage] or Color3.fromRGB(80, 80, 80)
		btn.Text             = icon .. "\n" .. stage
		btn.BackgroundColor3 = color
		btn.TextColor3       = Color3.fromRGB(255, 255, 255)
	end
end

-- ------------------------------------------------------------------ plot click handler

--- プロットボタンクリック時の処理。
---@param plotIndex number
local function onPlotClicked(plotIndex)
	local data = plotData[plotIndex]

	if not data then
		-- 空きマス：種が選択されていれば植える
		if selectedSeed then
			if plantSeedRE then
				plantSeedRE:FireServer(plotIndex, selectedSeed)
			end
		end
	elseif data.stage == "Egg" then
		-- 孵化
		if hatchEggRE then
			hatchEggRE:FireServer(plotIndex)
		end
	elseif data.stage == "Seed" or data.stage == "Sprout" or data.stage == "Bud" then
		-- 水やり
		if waterPlotRE then
			waterPlotRE:FireServer(plotIndex)
		end
	end
end

-- ------------------------------------------------------------------ seed selection

--- 種ボタン選択状態を更新する。
---@param seedId string|nil
local function selectSeed(seedId)
	-- 以前の選択をリセット
	for _, def in ipairs(SEED_DEFS) do
		local btn = seedButtons[def.id]
		if btn then
			btn.BorderSizePixel = 0
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		end
	end

	if selectedSeed == seedId then
		-- 同じ種を再クリック → 選択解除
		selectedSeed = nil
	else
		selectedSeed = seedId
		local btn = seedButtons[seedId]
		if btn then
			btn.BorderSizePixel = 3
			-- 対応する色でハイライト
			for _, def in ipairs(SEED_DEFS) do
				if def.id == seedId then
					btn.BackgroundColor3 = def.color
					break
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ build UI

--- ガーデンUI全体を構築する。
local function buildGardenUI()
	-- ScreenGui（既存 HUD の上に重ねる）
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "MonsterGardenGarden"
	screenGui.ResetOnSpawn   = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent         = playerGui

	-- 外側コンテナ（画面中央下寄り）
	local container = Instance.new("Frame")
	container.Name                   = "GardenContainer"
	container.Size                   = UDim2.new(0, 340, 0, 420)
	container.AnchorPoint            = Vector2.new(0.5, 0.5)
	container.Position               = UDim2.new(0.5, 0, 0.5, -10)
	container.BackgroundColor3       = Color3.fromRGB(30, 40, 25)
	container.BackgroundTransparency = 0.15
	container.BorderSizePixel        = 0
	container.Parent                 = screenGui
	addCorner(container, 12)

	-- ============================================================
	-- 3x3 グリッドフレーム
	-- ============================================================
	local gridFrame = Instance.new("Frame")
	gridFrame.Name             = "GardenGrid"
	gridFrame.Size             = UDim2.new(0, 320, 0, 320)
	gridFrame.AnchorPoint      = Vector2.new(0.5, 0)
	gridFrame.Position         = UDim2.new(0.5, 0, 0, 10)
	gridFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 15)
	gridFrame.BackgroundTransparency = 0.2
	gridFrame.BorderSizePixel  = 0
	gridFrame.Parent           = container
	addCorner(gridFrame, 8)

	-- UIGridLayout（3x3、セル100x100、パディング5）
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize    = UDim2.new(0, 100, 0, 100)
	gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
	gridLayout.SortOrder   = Enum.SortOrder.LayoutOrder
	gridLayout.StartCorner = Enum.StartCorner.TopLeft
	gridLayout.Parent      = gridFrame

	-- グリッドパディング（上下左右5px）
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingLeft   = UDim.new(0, 5)
	gridPadding.PaddingRight  = UDim.new(0, 5)
	gridPadding.PaddingTop    = UDim.new(0, 5)
	gridPadding.PaddingBottom = UDim.new(0, 5)
	gridPadding.Parent        = gridFrame

	-- 9枚のプロットボタンを生成
	for i = 1, 9 do
		local btn = Instance.new("TextButton")
		btn.Name             = "Plot" .. i
		btn.LayoutOrder      = i
		btn.BackgroundColor3 = Color3.fromRGB(60, 80, 50)
		btn.BorderSizePixel  = 0
		btn.Text             = "空きマス\n🌱"
		btn.TextColor3       = Color3.fromRGB(180, 220, 160)
		btn.TextScaled       = false
		btn.TextSize         = 12
		btn.Font             = Enum.Font.GothamBold
		btn.AutoButtonColor  = true
		btn.Parent           = gridFrame
		addCorner(btn, 6)

		plotButtons[i] = btn

		-- クリックイベント（クロージャでインデックスをキャプチャ）
		local plotIndex = i
		btn.MouseButton1Click:Connect(function()
			onPlotClicked(plotIndex)
		end)
	end

	-- ============================================================
	-- 種選択バー（グリッド下・5ボタン）
	-- ============================================================
	local seedBar = Instance.new("Frame")
	seedBar.Name             = "SeedBar"
	seedBar.Size             = UDim2.new(0, 320, 0, 50)
	seedBar.AnchorPoint      = Vector2.new(0.5, 0)
	seedBar.Position         = UDim2.new(0.5, 0, 0, 338)
	seedBar.BackgroundColor3 = Color3.fromRGB(20, 25, 20)
	seedBar.BackgroundTransparency = 0.3
	seedBar.BorderSizePixel  = 0
	seedBar.Parent           = container
	addCorner(seedBar, 8)

	local seedLayout = Instance.new("UIListLayout")
	seedLayout.FillDirection       = Enum.FillDirection.Horizontal
	seedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	seedLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
	seedLayout.Padding             = UDim.new(0, 4)
	seedLayout.Parent              = seedBar

	local seedPadding = Instance.new("UIPadding")
	seedPadding.PaddingLeft   = UDim.new(0, 6)
	seedPadding.PaddingRight  = UDim.new(0, 6)
	seedPadding.PaddingTop    = UDim.new(0, 5)
	seedPadding.PaddingBottom = UDim.new(0, 5)
	seedPadding.Parent        = seedBar

	for _, def in ipairs(SEED_DEFS) do
		local btn = Instance.new("TextButton")
		btn.Name             = "Seed_" .. def.id
		btn.Size             = UDim2.new(0, 54, 1, -10)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		btn.BorderSizePixel  = 0
		btn.Text             = def.label
		btn.TextColor3       = Color3.fromRGB(255, 255, 255)
		btn.TextScaled       = false
		btn.TextSize         = 12
		btn.Font             = Enum.Font.GothamBold
		btn.AutoButtonColor  = true
		btn.Parent           = seedBar
		addCorner(btn, 6)

		seedButtons[def.id] = btn

		local seedId = def.id
		btn.MouseButton1Click:Connect(function()
			selectSeed(seedId)
		end)
	end
end

-- ------------------------------------------------------------------ remote listeners

--- サーバーからの GardenUpdate イベントを購読する。
local function setupRemoteListeners()
	remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if not remotes then
		warn("[GardenController] Remotes folder not found")
		return
	end

	plantSeedRE = remotes:WaitForChild("PlantSeed",  10)
	waterPlotRE = remotes:WaitForChild("WaterPlot",  10)
	hatchEggRE  = remotes:WaitForChild("HatchEgg",   10)

	-- GardenUpdate: サーバーからのプロット変化通知
	local gardenUpdate = remotes:WaitForChild("GardenUpdate", 10)
	if gardenUpdate then
		gardenUpdate.OnClientEvent:Connect(function(action, plotIndex, data)
			-- キャッシュを更新してビジュアルを反映
			if action == "plant" or action == "water" or action == "hatch" or action == "stageChange" then
				plotData[plotIndex] = data
				GardenController.updatePlotVisual(plotIndex, data)
			end
		end)
	end
end

-- ------------------------------------------------------------------ init

--- GardenController を初期化する。
function GardenController.init()
	buildGardenUI()
	setupRemoteListeners()
	print("[GardenController] Initialized")
end

return GardenController
