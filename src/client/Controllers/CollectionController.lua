--!strict
--[[
	CollectionController
	モンスター図鑑UIを担当するコントローラ（スケルトン）。
	MonsterDatabase の全種を表示する予定。
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonsterDatabase = require(ReplicatedStorage:WaitForChild("Shared").Config.MonsterDatabase)

local CollectionController = {}

--- CollectionController を初期化する。
function CollectionController.init()
	local count = 0
	for _ in pairs(MonsterDatabase) do
		count = count + 1
	end
	print("[CollectionController] Initialized — " .. count .. " monsters in database")
end

return CollectionController
