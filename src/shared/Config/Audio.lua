--[[
	Audio
	BGM / SE の Roblox アセットID定義（単一情報源）。
	ID 0 はプレースホルダ（未アップロード）。再生側は 0 をスキップする。
	Phase 5 のアセット生成パイプラインが rbxassetid を書き込む。
]]

return {
	--- バイオーム/エリア別 BGM（bgmKey → assetId）
	bgm = {
		meadow = 0, -- そよかぜ草原
		volcano = 0, -- ごうか火山
		lakeside = 0, -- みずうみのほとり
		island = 0, -- 庭園島（ホーム）
	},

	--- 効果音
	se = {
		captureSuccess = 0, -- 捕獲成功
		captureFail = 0, -- 捕獲失敗（逃走）
		hatch = 0, -- 孵化
		plant = 0, -- 種植え
		water = 0, -- 水やり
		warp = 0, -- ワープ
		uiClick = 0, -- UI操作
		rareSeed = 0, -- レアシード採取
	},

	--- BGM 音量（0-1）
	bgmVolume = 0.4,
	--- SE 音量（0-1）
	seVolume = 0.7,
}
