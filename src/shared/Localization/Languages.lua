-- Languages: Localization module supporting "ja" (Japanese) and "en" (English)
local Languages = {}

local translations = {
	ja = {
		-- UI general
		welcome = "モンスターガーデンへようこそ！",
		plant = "植える",
		water = "水やり",
		fertilize = "肥料をあげる",
		hatch = "孵化させる",
		collect = "回収する",
		shop = "ショップ",
		coins = "コイン",
		seeds = "タネ",
		monsters = "モンスター",
		garden = "ガーデン",

		-- Rarity names
		rarity_normal = "ノーマル",
		rarity_rare = "レア",
		rarity_epic = "エピック",
		rarity_legend = "レジェンド",
		rarity_mythic = "ミシック",

		-- Weather names
		weather_sunny = "晴れ",
		weather_rainy = "雨",
		weather_snowy = "雪",
		weather_stormy = "嵐",
		weather_rainbow = "虹",

		-- Growth stage names
		stage_seed = "タネ",
		stage_sprout = "芽",
		stage_bud = "つぼみ",
		stage_egg = "タマゴ",
		stage_hatching = "孵化中",
		stage_juvenile = "子供",
		stage_adult = "成体",

		-- Action prompts
		tap_to_hatch = "タップして孵化させよう！",
		not_enough_coins = "コインが足りません！",
		monster_obtained = "モンスターをゲット！",
	},
	en = {
		-- UI general
		welcome = "Welcome to Monster Garden!",
		plant = "Plant",
		water = "Water",
		fertilize = "Fertilize",
		hatch = "Hatch",
		collect = "Collect",
		shop = "Shop",
		coins = "Coins",
		seeds = "Seeds",
		monsters = "Monsters",
		garden = "Garden",

		-- Rarity names
		rarity_normal = "Normal",
		rarity_rare = "Rare",
		rarity_epic = "Epic",
		rarity_legend = "Legend",
		rarity_mythic = "Mythic",

		-- Weather names
		weather_sunny = "Sunny",
		weather_rainy = "Rainy",
		weather_snowy = "Snowy",
		weather_stormy = "Stormy",
		weather_rainbow = "Rainbow",

		-- Growth stage names
		stage_seed = "Seed",
		stage_sprout = "Sprout",
		stage_bud = "Bud",
		stage_egg = "Egg",
		stage_hatching = "Hatching",
		stage_juvenile = "Juvenile",
		stage_adult = "Adult",

		-- Action prompts
		tap_to_hatch = "Tap to hatch!",
		not_enough_coins = "Not enough coins!",
		monster_obtained = "Monster obtained!",
	},
}

--- Returns the localized string for the given key and language.
-- Falls back to English if the key is not found in the requested language.
-- Falls back to the key itself if not found in any language.
-- @param key string  The localization key
-- @param lang string  The language code ("ja" or "en"), defaults to "en"
-- @return string  The localized text
function Languages.getText(key, lang)
	local language = lang or "en"
	local langTable = translations[language]

	if langTable and langTable[key] then
		return langTable[key]
	end

	-- Fallback to English
	if translations.en and translations.en[key] then
		return translations.en[key]
	end

	-- Last resort: return the key itself
	return key
end

return Languages
