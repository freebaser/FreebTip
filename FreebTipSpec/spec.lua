local ADDON_NAME, ns = ...

local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local SPECIALIZATION = SPECIALIZATION
local GetMouseFocus = GetMouseFocus
local GameTooltip = GameTooltip
local GetTime = GetTime
local UnitExists, UnitGUID = UnitExists, UnitGUID

local LibInspect = LibStub('LibInspect')

local maxage = 900 --number of secs to cache each player
LibInspect:SetMaxAge(maxage)

local cache = {
	specText = '|cffFFFFFF%s|r'
}
FreebTipSpec_cache = cache

local function getUnit()
	local mFocus = GetMouseFocus()

	if(mFocus) then
		unit = mFocus.unit or (mFocus.GetAttribute and mFocus:GetAttribute('unit'))
	end

	return (unit or 'mouseover')
end

local function ShowSpec(spec)
	if(not GameTooltip.freebtipSpecSet) then
		GameTooltip:AddDoubleLine(SPECIALIZATION, cache.specText:format(spec), NORMAL_FONT_COLOR.r,
		NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		GameTooltip.freebtipSpecSet = true
		GameTooltip:Show()
	end
end

local specUpdate = CreateFrame'Frame'
specUpdate:SetScript('OnUpdate', function(self, elapsed)
	self.update = (self.update or 0) + elapsed
	if(self.update < .08) then return end

	local unit = getUnit()
	local guid = UnitExists(unit) and UnitGUID(unit)
	local cacheGUID = guid and cache[guid]
	if(cacheGUID) then
		ShowSpec(cacheGUID.spec)
	end

	self.update = 0
	self:Hide()
end)

local function getTalents(guid, data, age)
	if((not guid) or (data and type(data.talents) ~= 'table')) then return end

	local cacheGUID = cache[guid]
	if(cacheGUID and cacheGUID.time > (GetTime()-maxage)) then
		return specUpdate:Show()
	end

	local spec = data.talents.name
	if(spec) then
		cache[guid] = { spec = spec, time = GetTime() }
		specUpdate:Show()
	end
end
LibInspect:AddHook(ADDON_NAME, 'talents', function(...) getTalents(...) end)

local function OnSetUnit(self)
	local unit = getUnit()
	local caninspect = LibInspect:RequestData('items', unit)
	specUpdate:Show()
end
GameTooltip:HookScript('OnTooltipSetUnit', OnSetUnit)

local tipCleared = function(self)
	self.freebtipSpecSet = false
end
GameTooltip:HookScript('OnTooltipCleared', tipCleared)
