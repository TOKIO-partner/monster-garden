--[[
	GardenController
	自分の庭園島のプロット表示（ステージ別ビジュアル・ラベル）を担当するコントローラ。
	プロット操作（植える/水やり/孵化）はサーバー側 ClickDetector が処理するため、
	クライアントは GardenUpdate を受けた見た目更新のみを担う。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Languages = require(Shared.Localization.Languages)
local Net = require(Shared.Net)

-- ------------------------------------------------------------------ module

local GardenController = {}

local localPlayer = Players.LocalPlayer

-- ------------------------------------------------------------------ constants

--- 成長ステージのアイコン
local STAGE_ICONS = {
	Seed = "🌰",
	Sprout = "🌱",
	Bud = "🌸",
	Egg = "🥚",
	Juvenile = "🐣",
	Adult = "🐲",
	Ultimate = "✨",
}

--- 成長ステージのプロット色
local STAGE_COLORS = {
	Seed = Color3.fromRGB(124, 92, 62),
	Sprout = Color3.fromRGB(110, 140, 70),
	Bud = Color3.fromRGB(150, 170, 90),
	Egg = Color3.fromRGB(230, 220, 180),
	Juvenile = Color3.fromRGB(120, 190, 120),
	Adult = Color3.fromRGB(80, 170, 100),
	Ultimate = Color3.fromRGB(255, 215, 80),
}

--- 空プロットの色
local EMPTY_COLOR = Color3.fromRGB(124, 92, 62)

-- ------------------------------------------------------------------ island lookup

--- 自分の島モデルを返す（StreamingEnabled 対応で毎回検索）。
---@return Model|nil
local function getMyIsland()
	return Workspace:FindFirstChild("Island_" .. localPlayer.UserId)
end

--- 自分の島のプロット Part を返す。
---@param plotIndex number
---@return BasePart|nil
local function getPlotPart(plotIndex)
	local island = getMyIsland()
	return island and island:FindFirstChild("Plot_" .. plotIndex)
end

-- ------------------------------------------------------------------ visuals

--- プロットのビルボードラベルを更新（無ければ生成）する。
---@param plotPart BasePart
---@param text string
local function setPlotLabel(plotPart, text)
	local billboard = plotPart:FindFirstChild("StageBillboard")
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "StageBillboard"
		billboard.Size = UDim2.fromOffset(80, 28)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = plotPart

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.4
		label.TextSize = 16
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard
	end
	billboard.Label.Text = text
end

--- プロットの見た目をプロットデータに合わせて更新する。
---@param plotIndex number
---@param plot table|nil nil なら空プロット表示
function GardenController.refreshPlot(plotIndex, plot)
	local plotPart = getPlotPart(plotIndex)
	if not plotPart then
		return -- 島が未ストリーム/未生成
	end

	if not plot then
		plotPart.Color = EMPTY_COLOR
		local billboard = plotPart:FindFirstChild("StageBillboard")
		if billboard then
			billboard:Destroy()
		end
		return
	end

	plotPart.Color = STAGE_COLORS[plot.stage] or EMPTY_COLOR
	local icon = STAGE_ICONS[plot.stage] or "❓"
	local stageName = Languages.get("stage_" .. string.lower(plot.stage))
	setPlotLabel(plotPart, icon .. " " .. stageName)
end

--- 全プロットを初期同期する（入室時）。
local function syncAllPlots()
	local ok, data = pcall(function()
		return Net.func("GetPlayerData"):InvokeServer()
	end)
	if not ok or not data or not data.garden then
		return
	end
	for plotIndex = 1, 9 do
		GardenController.refreshPlot(plotIndex, data.garden.plots[plotIndex])
	end
end

-- ------------------------------------------------------------------ init

--- GardenController を初期化する。
function GardenController.init()
	-- サーバーからのプロット更新
	Net.event("GardenUpdate").OnClientEvent:Connect(function(_kind, plotIndex, plot)
		GardenController.refreshPlot(plotIndex, plot)
	end)

	-- 島の生成/ストリームインを待って初期同期
	task.spawn(function()
		local waited = 0
		while not getMyIsland() and waited < 30 do
			waited = waited + task.wait(1)
		end
		syncAllPlots()
	end)

	print("[GardenController] Initialized")
end

return GardenController
