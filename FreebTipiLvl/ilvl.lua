local ADDON_NAME, ns = ...

local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local ITEM_LEVEL_ABBR = ITEM_LEVEL_ABBR
local GetMouseFocus = GetMouseFocus
local GameTooltip = GameTooltip
local GetTime = GetTime

local ilvlText = "|cffFFFFFF%d|r"
local cacheTime = 900 --number of secs to cache each player's ilvl

local ItemUpgradeInfo = LibStub("LibItemUpgradeInfo-1.0")
local LibInspect = LibStub("LibInspect")

local cache = {}

local function ShowiLvl(self, unit, uGUID)
	local cacheGUID = cache[uGUID]
	if(cacheGUID and cacheGUID.gtime > GetTime()-cacheTime) then

		if(not self.freebtipiLvlSet) then
			self:AddDoubleLine(ITEM_LEVEL_ABBR, ilvlText:format(cacheGUID.ilvl), NORMAL_FONT_COLOR.r,
			NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

			self.freebtipiLvlSet = true
		end

		self:Show()
	elseif(not InspectFrame or (InspectFrame and not InspectFrame:IsShown())) then
		if(cacheGUID) then cacheGUID = nil end
		local caninspect, unitfound, refreshing = LibInspect:RequestData("items", unit, true)
	end
end

local function getUnit()
	local mFocus = GetMouseFocus()
	local unit = mFocus and (mFocus.unit or mFocus:GetAttribute("unit")) or "mouseover"
	return unit
end

local updateiLvl = CreateFrame"Frame"
updateiLvl:SetScript("OnUpdate", function(self, elapsed)
	self.updateFreebiLvl = (self.updateFreebiLvl or 0) + elapsed
	if(self.updateFreebiLvl < .12) then return end

	local unit = getUnit()
	local mGUID = UnitGUID(unit)
	if(mGUID) then
		ShowiLvl(GameTooltip, unit, mGUID)
	end

	self.updateFreebiLvl = 0
	self:Hide()
end)
updateiLvl:Hide()

local slots = { "Back", "Chest", "Feet", "Finger0", "Finger1", "Hands", "Head", "Legs",
"MainHand", "Neck", "SecondaryHand", "Shoulder", "Trinket0", "Trinket1", "Waist", "Wrist" }

local slotIDs = {}
for i, slot in next, slots do
	local slotName = slot.."Slot"
	local id = GetInventorySlotInfo(slotName)

	if(id) then
		slotIDs[i] = id
	end
end

local function getItems(uGUID, data, age)
	if((uGUID and cache[uGUID]) or (data and type(data.items) ~= "table")) then return end

	local numItems = 0
	local itemsTotal = 0

	for i, id in next, slotIDs do
		local link = data.items[id]

		if(link) then
			local ilvl = ItemUpgradeInfo:GetUpgradedItemLevel(link)

			numItems = numItems + 1
			itemsTotal = itemsTotal + ilvl
		end
	end

	if(numItems > 0) then
		local score = itemsTotal / numItems
		cache[uGUID] = { ilvl = score, gtime = GetTime() }
		updateiLvl:Show()
	end
end
LibInspect:AddHook(ADDON_NAME, "items", function(...) getItems(...) end)

local function OnSetUnit(self)
	self.freebtipiLvlSet = false

	local unit = getUnit()
	if(UnitExists(unit) and UnitIsPlayer(unit)) then
		local canInspect = CanInspect(unit)
		--local uGUID = UnitGUID(unit)

		if(canInspect) then
			--ShowiLvl(self, unit, uGUID)
			self.updateFreebiLvl = .1
			updateiLvl:Show()
		end
	end
end
GameTooltip:HookScript("OnTooltipSetUnit", OnSetUnit)
