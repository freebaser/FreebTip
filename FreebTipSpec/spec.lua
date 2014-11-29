local ADDON_NAME, ns = ...

local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local SPECIALIZATION = SPECIALIZATION
local GetMouseFocus = GetMouseFocus
local GameTooltip = GameTooltip
local GetTime = GetTime

local specText = "|cffFFFFFF%s|r"
local cacheTime = 900 --number of secs to cache each player's spec

local LibInspect = LibStub("LibInspect")

local cache = {}

local function ShowSpec(self, unit, uGUID)
	local cacheGUID = cache[uGUID]
	if(cacheGUID and cacheGUID.gtime > GetTime()-cacheTime) then

		if(not self.freebtipSpecSet) then
			self:AddDoubleLine(SPECIALIZATION, specText:format(cacheGUID.spec), NORMAL_FONT_COLOR.r,
			NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

			self.freebtipSpecSet = true
		end

		self:Show()
	elseif(not InspectFrame or (InspectFrame and not InspectFrame:IsShown())) then
		if(cacheGUID) then cacheGUID = nil end
		local caninspect, unitfound, refreshing = LibInspect:RequestData("talents", unit, true)
	end
end

local function getUnit(self)
	local mFocus = GetMouseFocus()
	local unit = mFocus and (mFocus.unit or mFocus:GetAttribute("unit")) or "mouseover"
	return unit
end

local updateSpec = CreateFrame"Frame"
updateSpec:SetScript("OnUpdate", function(self, elapsed)
	self.updateFreebSpec = (self.updateFreebSpec or 0) + elapsed
	if(self.updateFreebSpec < .1) then return end

	local unit = getUnit()
	local mGUID = UnitGUID(unit)
	if(mGUID) then
		ShowSpec(GameTooltip, unit, mGUID)
	end

	self.updateFreebSpec = 0
	self:Hide()
end)
updateSpec:Hide()

local function getTalents(uGUID, data, age)
	if((uGUID and cache[uGUID]) or (data and type(data.talents) ~= "table")) then return end

	local spec = data.talents.name
	if(spec) then
		cache[uGUID] = { spec = spec, gtime = GetTime() }
		updateSpec:Show()
	end
end
LibInspect:AddHook(ADDON_NAME, "talents", function(...) getTalents(...) end)

local function OnSetUnit(self)
	self.freebtipSpecSet = false

	local unit = getUnit()
	if(UnitExists(unit) and UnitIsPlayer(unit)) then
		local level = UnitLevel(unit) or 0
		local canInspect = CanInspect(unit)
		--local uGUID = UnitGUID(unit)

		if(canInspect and level > 9) then
			--ShowSpec(self, unit, uGUID)
			self.updateFreebSpec = .1
			updateSpec:Show()
		end
	end
end
GameTooltip:HookScript("OnTooltipSetUnit", OnSetUnit)
