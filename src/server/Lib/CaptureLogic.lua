--[[
	CaptureLogic
	野生モンスター捕獲の成功率計算と判定（純粋ロジック・Instance非依存）。
	成功率テーブルは GameConfig.Capture から注入する。
]]

local CaptureLogic = {}

--- 成功率の下限・上限（確率 0 / 1 を避けゲーム性を保つ）
local MIN_RATE = 0.01
local MAX_RATE = 0.95

--- レアリティと補正から捕獲成功率を計算する。
---@param rarity string
---@param config { rates: table<string, number>, luckyBonus: number }
---@param hasLuckyGardener boolean|nil
---@return number rate [MIN_RATE, MAX_RATE] にクランプ済み
function CaptureLogic.successRate(rarity, config, hasLuckyGardener)
	local base = config.rates[rarity]
	if not base then
		-- 未知レアリティは最も渋い扱い
		base = MIN_RATE
	end
	if hasLuckyGardener then
		base = base + (config.luckyBonus or 0)
	end
	return math.clamp(base, MIN_RATE, MAX_RATE)
end

--- 捕獲判定を行う。
---@param rarity string
---@param config { rates: table<string, number>, luckyBonus: number }
---@param hasLuckyGardener boolean|nil
---@param rng (fun(): number)|nil 0-1 を返す乱数関数（省略時 math.random）
---@return boolean success
---@return number rate 使用した成功率（結果通知用）
function CaptureLogic.roll(rarity, config, hasLuckyGardener, rng)
	rng = rng or math.random
	local rate = CaptureLogic.successRate(rarity, config, hasLuckyGardener)
	return rng() <= rate, rate
end

--- 距離検証。プレイヤーとスポーンの距離が許容範囲内か。
---@param distance number
---@param maxDistance number
---@return boolean
function CaptureLogic.isWithinDistance(distance, maxDistance)
	return type(distance) == "number" and distance >= 0 and distance <= maxDistance
end

return CaptureLogic
