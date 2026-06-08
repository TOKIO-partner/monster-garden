--!strict
--[[
	ShopController
	ショップUI・GamePass/DevProduct購入プロンプトを担当するコントローラ（スケルトン）。
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local ShopController = {}

--- ShopController を初期化する。
function ShopController.init()
	print("[ShopController] Initialized (skeleton)")
end

--- GamePass 購入プロンプトを表示する。
---@param passId number
function ShopController.promptGamePass(passId)
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, passId)
	end)
end

--- DevProduct 購入プロンプトを表示する。
---@param productId number
function ShopController.promptProduct(productId)
	pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
	end)
end

return ShopController
