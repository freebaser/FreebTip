local ADDON_NAME, ns = ...

local _G = _G
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local ITEM_LEVEL_ABBR = ITEM_LEVEL_ABBR
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
	else
		cache[uGUID] = nil
		local caninspect, unitfound, refreshing = LibInspect:RequestData("items", unit, true)
	end
end

local timer = 0
local updateiLvl = CreateFrame"Frame"
updateiLvl:SetScript("OnUpdate", function(self, elapsed)
	timer = timer + elapsed
	if(timer < .1) then return end
	
	local mGUID = UnitGUID("mouseover")
	if(mGUID) then
		ShowiLvl(GameTooltip, "mouseover", mGUID)
	end

	timer = 0
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

		-- delay output (prefer ilvl to be last in the tooltip)
		updateiLvl:Show()
	end
end

LibInspect:AddHook(ADDON_NAME, "items", function(...) getItems(...) end)

GameTooltip:HookScript("OnTooltipCleared", function(self)
	self.freebtipiLvlSet = false
end)

local function OnSetUnit(self)
	local _, unit = self:GetUnit()

	if(UnitExists(unit) and UnitIsPlayer(unit)) then
		local level = UnitLevel(unit) or 0
		local canInspect = CanInspect(unit)
		local uGUID = UnitGUID(unit)

		if(canInspect or level > 9) then
			--ShowiLvl(self, unit, uGUID)
			updateiLvl:Show()
		end
	end
end

GameTooltip:HookScript("OnTooltipSetUnit", OnSetUnit)
