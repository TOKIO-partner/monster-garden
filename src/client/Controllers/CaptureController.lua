--[[
	CaptureController
	捕獲結果の演出（トースト・SE）を担当するコントローラ。
	捕獲入力自体はサーバー側 ProximityPrompt.Triggered が処理するため、
	クライアントは結果表示のみを担う。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)
local Languages = require(Shared.Localization.Languages)
local Net = require(Shared.Net)

-- ------------------------------------------------------------------ module

local CaptureController = {}

--- トースト表示関数（UIController.init 後に注入される）
local toastHandler = nil

-- ------------------------------------------------------------------ SE

--- SE を1回再生する。assetId 0 はスキップ。
---@param seKey string
local function playSe(seKey)
	local assetId = Audio.se[seKey]
	if not assetId or assetId == 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. assetId
	sound.Volume = Audio.seVolume
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- ------------------------------------------------------------------ public API

--- トースト表示関数を登録する（UIController から注入）。
---@param handler fun(title: string, body: string, rarity: string|nil)
function CaptureController.setToastHandler(handler)
	toastHandler = handler
end

-- ------------------------------------------------------------------ init

--- CaptureController を初期化する。
function CaptureController.init()
	Net.event("CaptureResult").OnClientEvent:Connect(function(success, monster, reason)
		if success and monster then
			playSe("captureSuccess")
			if toastHandler then
				toastHandler(Languages.get("capture_success"), monster.id, monster.rarity)
			end
		else
			playSe("captureFail")
			if toastHandler and reason == "escaped" then
				toastHandler(Languages.get("capture_escaped"), monster and monster.id or "", nil)
			end
		end
	end)

	print("[CaptureController] Initialized")
end

return CaptureController
