--[[
	GrowthLogic
	植栽プロットの成長計算（純粋ロジック・Instance非依存）。
	旧 GardenService の tickPlot / オフライン成長を関数化したもの。
	durations は呼び出し側（GameConfig.Growth）から注入する。
]]

local GrowthLogic = {}

--- 成長ステージ定義（順序が重要）
GrowthLogic.STAGES = {
	"Seed", -- 1
	"Sprout", -- 2
	"Bud", -- 3
	"Egg", -- 4 ← タップが必要。自動進行しない
	"Juvenile", -- 5
	"Adult", -- 6
	"Ultimate", -- 7 ← 最終形。自動進行しない
}

--- 自動進行しないステージ（手動アクション待ち／最終形）
local MANUAL_STAGES = {
	Egg = true,
	Ultimate = true,
}

--- ステージ名 → インデックスの逆引きマップ
local STAGE_INDEX = {}
for index, stage in ipairs(GrowthLogic.STAGES) do
	STAGE_INDEX[stage] = index
end

--- ステージ名からインデックスを返す。未知のステージは nil。
---@param stage string
---@return number|nil
function GrowthLogic.stageIndex(stage)
	return STAGE_INDEX[stage]
end

--- 次のステージ名を返す。最終ステージ・未知ステージは nil。
---@param stage string
---@return string|nil
function GrowthLogic.nextStage(stage)
	local index = STAGE_INDEX[stage]
	if not index then
		return nil
	end
	return GrowthLogic.STAGES[index + 1]
end

--- 自動進行しないステージかどうかを返す。
---@param stage string
---@return boolean
function GrowthLogic.isManualStage(stage)
	return MANUAL_STAGES[stage] == true
end

--- プロットを elapsed 秒分成長させる（複数ステージのキャリーオーバー対応）。
--- Egg / Ultimate では停止する。plot を直接変更し、ステージが変化したら true を返す。
---@param plot table { stage: string, growthProgress: number, ... }
---@param elapsed number 経過秒数
---@param multiplier number 成長速度倍率（ゲームパス等。1.0 = 等速）
---@param durations table<string, number> ステージ名 → 次ステージまでの必要秒数
---@return boolean changed ステージが1回以上変化したか
function GrowthLogic.advance(plot, elapsed, multiplier, durations)
	if type(plot) ~= "table" or not plot.stage then
		return false
	end

	local remaining = elapsed * (multiplier or 1.0)
	local changed = false

	while remaining > 0 and not GrowthLogic.isManualStage(plot.stage) do
		local duration = durations[plot.stage]
		if not duration or duration <= 0 then
			break
		end

		local needed = duration - (plot.growthProgress or 0)
		if remaining >= needed then
			-- 次のステージへ進む
			remaining = remaining - needed
			local newStage = GrowthLogic.nextStage(plot.stage)
			if not newStage then
				break
			end
			plot.stage = newStage
			plot.growthProgress = 0
			plot.watered = false
			changed = true
		else
			-- ステージ内で進捗を積む
			plot.growthProgress = (plot.growthProgress or 0) + remaining
			remaining = 0
		end
	end

	return changed
end

--- 庭園全プロットにオフライン成長を適用する。変化したプロット番号の配列を返す。
--- オフライン中はゲームパス倍率を適用しない（等速）。
---@param garden table<number, table> plotIndex → plotData
---@param offlineSeconds number
---@param durations table<string, number>
---@return table<number, boolean> changedPlots plotIndex → true
function GrowthLogic.applyOfflineGrowth(garden, offlineSeconds, durations)
	local changedPlots = {}
	if type(garden) ~= "table" or offlineSeconds <= 0 then
		return changedPlots
	end

	for plotIndex, plot in pairs(garden) do
		if type(plot) == "table" and plot.stage then
			if GrowthLogic.advance(plot, offlineSeconds, 1.0, durations) then
				changedPlots[plotIndex] = true
			end
		end
	end

	return changedPlots
end

return GrowthLogic
