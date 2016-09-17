local ADDON_NAME, ns = ...

local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local ITEM_LEVEL_ABBR = ITEM_LEVEL_ABBR
local GetMouseFocus = GetMouseFocus
local GameTooltip = GameTooltip
local GetTime = GetTime
local UnitGUID = UnitGUID

local ItemUpgradeInfo = LibStub("LibItemUpgradeInfo-1.0")
local LibInspect = LibStub("LibInspect")

local maxage = 900 --number of secs to cache each player
LibInspect:SetMaxAge(maxage)

local cache = {
	ilvlText = "|cffFFFFFF%d|r"
}
FreebTipiLvl_cache = cache

local function getUnit()
	local mFocus = GetMouseFocus()
	local unit = mFocus and (mFocus.unit or mFocus:GetAttribute("unit")) or "mouseover"
	return unit
end

local function ShowiLvl(score)
	if(not GameTooltip.freebtipiLvlSet) then
		GameTooltip:AddDoubleLine(ITEM_LEVEL_ABBR, cache.ilvlText:format(score), NORMAL_FONT_COLOR.r,
		NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		GameTooltip.freebtipiLvlSet = true
		GameTooltip:Show()
	end
end

local iLvlUpdate = CreateFrame"Frame"
iLvlUpdate:SetScript("OnUpdate", function(self, elapsed)
	self.update = (self.update or 0) + elapsed
	if(self.update < .1) then return end

	local unit = getUnit()
	local guid = UnitGUID(unit)
	local cacheGUID = cache[guid]
	if(cacheGUID) then
		ShowiLvl(cacheGUID.score)
	end

	self.update = 0
	self:Hide()
end)

local slotIDs = {
	INVSLOT_HEAD,INVSLOT_NECK,INVSLOT_SHOULDER,INVSLOT_CHEST,INVSLOT_WAIST,
	INVSLOT_LEGS,INVSLOT_FEET,INVSLOT_WRIST,INVSLOT_HAND,INVSLOT_FINGER1,INVSLOT_FINGER2,
	INVSLOT_TRINKET1,INVSLOT_TRINKET2,INVSLOT_BACK,INVSLOT_MAINHAND,INVSLOT_OFFHAND
}

local function getItems(guid, data, age)
	if((not guid) or (data and type(data.items) ~= "table")) then return end

	local cacheGUID = cache[guid]
	if(cacheGUID and cacheGUID.time > (GetTime()-maxage)) then
		return iLvlUpdate:Show()
	end

	local numItems = 0
	local itemsScore = 0

	for i, id in next, slotIDs do
		local link = data.items[id]

		if(link) then
			local ilvl = ItemUpgradeInfo:GetUpgradedItemLevel(link)

			if(id == INVSLOT_OFFHAND or id == INVSLOT_MAINHAND) then
				local quality = select(3, GetItemInfo(link))

				if(quality == 6 and ilvl == 750) then
					local slot = (id == INVSLOT_OFFHAND) and INVSLOT_MAINHAND or INVSLOT_OFFHAND
					link = data.items[slot]
					ilvl = ItemUpgradeInfo:GetUpgradedItemLevel(link)
				end
			end

			if(ilvl) then
				numItems = numItems + 1
				itemsScore = itemsScore + ilvl
			end
		end
	end

	if(numItems > 0) then
		local score = itemsScore / numItems
		cache[guid] = { score = score, time = GetTime() }
		iLvlUpdate:Show()
	end
end
LibInspect:AddHook(ADDON_NAME, "items", function(...) getItems(...) end)

local function OnSetUnit(self)
	local unit = getUnit()
	local caninspect = LibInspect:RequestData("items", unit)
	iLvlUpdate:Show()
end
GameTooltip:HookScript("OnTooltipSetUnit", OnSetUnit)

local tipCleared = function(self)
	self.freebtipiLvlSet = false
end
GameTooltip:HookScript("OnTooltipCleared", tipCleared)
