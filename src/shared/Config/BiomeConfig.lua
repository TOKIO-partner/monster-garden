--[[
	BiomeConfig
	オープンワールドの3バイオーム定義（単一情報源）。
	領域座標・対応属性・地形マテリアル・BGMキーを保持する。
	振分けルール: Grass/Light → Meadow、Fire → Volcano、Water/Dark → Lakeside。
]]

local BiomeConfig = {
	--- バイオーム定義（key = biomeId）
	Biomes = {
		Meadow = {
			id = "Meadow",
			name = "そよかぜ草原",
			nameEN = "Breezy Meadow",
			attributes = { "Grass", "Light" },
			--- ワールド上の領域（中心XZ・一辺サイズ studs）
			region = { centerX = 0, centerZ = 0, size = 512 },
			terrainMaterial = "Grass",
			accentMaterial = "LeafyGrass",
			bgmKey = "meadow",
			--- 野生スポーンの高さ基準（地表Y）
			groundY = 0,
		},
		Volcano = {
			id = "Volcano",
			name = "ごうか火山",
			nameEN = "Blazing Volcano",
			attributes = { "Fire" },
			region = { centerX = 768, centerZ = 0, size = 512 },
			terrainMaterial = "Basalt",
			accentMaterial = "CrackedLava",
			bgmKey = "volcano",
			groundY = 0,
		},
		Lakeside = {
			id = "Lakeside",
			name = "みずうみのほとり",
			nameEN = "Misty Lakeside",
			attributes = { "Water", "Dark" },
			region = { centerX = -768, centerZ = 0, size = 512 },
			terrainMaterial = "Ground",
			accentMaterial = "Mud",
			bgmKey = "lakeside",
			groundY = 0,
		},
	},

	--- バイオームの表示順・イテレーション順（pairs の順不定を避ける）
	Order = { "Meadow", "Volcano", "Lakeside" },
}

--- 属性からバイオームIDを引く逆引きマップを構築する。
---@return table<string, string> attribute → biomeId
function BiomeConfig.buildAttributeMap()
	local map = {}
	for _, biomeId in ipairs(BiomeConfig.Order) do
		local biome = BiomeConfig.Biomes[biomeId]
		for _, attribute in ipairs(biome.attributes) do
			map[attribute] = biomeId
		end
	end
	return map
end

--- ワールド座標(X,Z)が属するバイオームIDを返す。どこにも属さなければ nil。
---@param x number
---@param z number
---@return string|nil
function BiomeConfig.biomeAt(x, z)
	for _, biomeId in ipairs(BiomeConfig.Order) do
		local region = BiomeConfig.Biomes[biomeId].region
		local half = region.size / 2
		if math.abs(x - region.centerX) <= half and math.abs(z - region.centerZ) <= half then
			return biomeId
		end
	end
	return nil
end

return BiomeConfig
