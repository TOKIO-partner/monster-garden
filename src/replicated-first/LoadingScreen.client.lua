--!strict
--[[
	LoadingScreen.client.lua
	ゲーム起動時のローディング画面。デフォルトローディング画面を置き換え、
	ゲーム読み込み完了後にフェードアウトして破棄する。
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- デフォルトのロード画面を非表示にする
ReplicatedFirst:RemoveDefaultLoadingScreen()

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- ------------------------------------------------------------------ ScreenGui 作成

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 100
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- 暗い背景フレーム（全画面）
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.Position = UDim2.fromScale(0, 0)
bg.BackgroundColor3 = Color3.fromRGB(15, 20, 15)
bg.BackgroundTransparency = 0
bg.BorderSizePixel = 0
bg.Parent = screenGui

-- ------------------------------------------------------------------ コンテンツ

-- タイトルラベル（緑）
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.fromOffset(400, 56)
titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
titleLabel.Position = UDim2.fromScale(0.5, 0.42)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌱 Monster Garden 🌱"
titleLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
titleLabel.TextScaled = false
titleLabel.TextSize = 36
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.Parent = bg

-- サブタイトルラベル（白）
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.fromOffset(400, 30)
subtitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
subtitleLabel.Position = UDim2.fromScale(0.5, 0.52)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "育てて、集めて、見せびらかせ！"
subtitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
subtitleLabel.TextScaled = false
subtitleLabel.TextSize = 18
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
subtitleLabel.Parent = bg

-- ローディングテキスト（グレー）
local loadingLabel = Instance.new("TextLabel")
loadingLabel.Name = "Loading"
loadingLabel.Size = UDim2.fromOffset(200, 22)
loadingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
loadingLabel.Position = UDim2.fromScale(0.5, 0.62)
loadingLabel.BackgroundTransparency = 1
loadingLabel.Text = "Loading..."
loadingLabel.TextColor3 = Color3.fromRGB(140, 160, 140)
loadingLabel.TextScaled = false
loadingLabel.TextSize = 14
loadingLabel.Font = Enum.Font.Gotham
loadingLabel.TextXAlignment = Enum.TextXAlignment.Center
loadingLabel.Parent = bg

-- ------------------------------------------------------------------ 読み込み完了待ち → フェードアウト

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- 0.5秒かけてフェードアウト
local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local bgTween = TweenService:Create(bg, tweenInfo, {
	BackgroundTransparency = 1,
})

TweenService:Create(titleLabel, tweenInfo, { TextTransparency = 1 }):Play()
TweenService:Create(subtitleLabel, tweenInfo, { TextTransparency = 1 }):Play()
TweenService:Create(loadingLabel, tweenInfo, { TextTransparency = 1 }):Play()

bgTween.Completed:Connect(function()
	screenGui:Destroy()
end)

bgTween:Play()
