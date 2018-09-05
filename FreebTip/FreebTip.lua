local ADDON_NAME, ns = ...

local mediapath = "Interface\\AddOns\\"..ADDON_NAME.."\\media\\"

--[[ Defaults. OVERRIDE THESE IN SETTINGS.LUA ]]--
local settings = {
	font = mediapath.."font.ttf",
	fontflag = "NONE",

	scale = 1.1,

	backdrop = {
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = mediapath.."glowTex",
		tile = false,
		tileEdge = true,
		tileSize = 16,
		edgeSize = 3,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	
		backdropBorderColor = CreateColor(0, 0, 0),
		backdropColor = CreateColor(0.05, 0.05, 0.05, .95),
	},

	bgcolor = { r=.05, g=.05, b=.05, t=1 }, -- background
	bdrcolor = { r=0, g=0, b=0 }, -- border

	statusbar = mediapath.."statusbar",
	sbHeight = 2,
	sbText = false,

	factionIconSize = 30,
	factionIconAlpha = 1,

	fadeOnUnit = true, -- fade from units instead of hiding instantly
	combathide = false, -- hide world tooltips in combat
	combathideALL = false,

	showGRank = true,
	guildText = "|cffE41F9B<%s>|r |cffA0A0A0%s|r",

	playerTitle = false,

	auraInfo = true,

	YOU = "<YOU>",
}

if(freebDebug) then
	ns.Debug = function(...)
		freebDebug:Stuff(ADDON_NAME, ...)
	end
else
	ns.Debug = function() end
end

local cfg = setmetatable(ns.cfg_override,
{__index = function(t, key)
	t[key] = settings[key] or false
	return t[key]
end})
ns.cfg = cfg

local _G = _G
local RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local qqColor = { r=1, g=0, b=0 }
local nilColor = { r=1, g=1, b=1 }
local tappedColor = { r=.6, g=.6, b=.6 }
local deadColor = { r=.6, g=.6, b=.6 }

local powerColors = {}
for power, color in next, PowerBarColor do
	powerColors[power] = color
end
powerColors["MANA"] = { r=.31, g=.45, b=.63 }

local classification = {
	elite = ("|cffFFCC00 %s|r"):format(ELITE),
	rare = ("|cffCC00FF %s|r"):format(ITEM_QUALITY3_DESC),
	rareelite = ("|cffCC00FF %s|r"):format(ELITE),
	worldboss = ("|cffFF0000?? %s|r"):format(BOSS)
}

local TooltipHeaderText = {}
TooltipHeaderText[1], TooltipHeaderText[2], TooltipHeaderText[3] = GameTooltipHeaderText:GetFont()
GameTooltipHeaderText:SetFont(cfg.font or TooltipHeaderText[1], TooltipHeaderText[2], cfg.fontflag or TooltipHeaderText[3])

local TooltipText = {}
TooltipText[1], TooltipText[2], TooltipText[3] = GameTooltipText:GetFont()
GameTooltipText:SetFont(cfg.font or TooltipText[1], TooltipText[2], cfg.fontflag or TooltipText[3])

local TooltipTextSmall = {}
TooltipTextSmall[1], TooltipTextSmall[2], TooltipTextSmall[3] = GameTooltipTextSmall:GetFont()
GameTooltipTextSmall:SetFont(cfg.font or TooltipTextSmall[1], TooltipTextSmall[2], cfg.fontflag or TooltipTextSmall[3])

local factionIcon = {
	["Alliance"] = "Interface\\Timer\\Alliance-Logo",
	["Horde"] = "Interface\\Timer\\Horde-Logo",
}

local hex = function(r, g, b)
	if(r and not b) then
		r, g, b = r.r, r.g, r.b
	end

	return (b and format('|cff%02x%02x%02x', r * 255, g * 255, b * 255)) or "|cffFFFFFF"
end

local numberize = function(val)
	if(val >= 1e6) then
		return ("%.1fm"):format(val / 1e6)
	elseif(val >= 1e3) then
		return ("%.0fk"):format(val / 1e3)
	else
		return ("%d"):format(val)
	end
end

local function unitColor(unit)
	local colors

	if(UnitPlayerControlled(unit)) then
		local _, class = UnitClass(unit)
		if(class and UnitIsPlayer(unit)) then
			-- Players have color
			colors = RAID_CLASS_COLORS[class]
		elseif(UnitCanAttack(unit, "player")) then
			-- Hostiles are red
			colors = FACTION_BAR_COLORS[2]
		elseif(UnitCanAttack("player", unit)) then
			-- Units we can attack but which are not hostile are yellow
			colors = FACTION_BAR_COLORS[4]
		elseif(UnitIsPVP(unit)) then
			-- Units we can assist but are PvP flagged are green
			colors = FACTION_BAR_COLORS[6]
		end
	elseif(UnitIsTapDenied(unit, "player")) then
		colors = tappedColor
	end

	if(not colors) then
		local reaction = UnitReaction(unit, "player")
		colors = reaction and FACTION_BAR_COLORS[reaction] or nilColor
	end

	return colors.r, colors.g, colors.b
end
GameTooltip_UnitColor = unitColor

local function getUnit(tooltip)
	local _, unit = tooltip and tooltip:GetUnit()
	if(not unit) then
		local mFocus = GetMouseFocus()

		if(mFocus) then
			unit = mFocus.unit or (mFocus.GetAttribute and mFocus:GetAttribute("unit"))
		end
	end

	return (unit or "mouseover")
end

FreebTip_Cache = {}
local Cache = FreebTip_Cache
local function getPlayer(unit, origName)
	local guid = UnitGUID(unit)
	if not (Cache[guid]) then
		local class, _, race, _, _, name, realm = GetPlayerInfoByGUID(guid)
		if not name then return end

		--use orig text to diplay name and title
		if(cfg.playerTitle) then
			-- strip realm though
			name = origName:gsub("-(.*)", "")
			ns.Debug(name)
		end

		if(realm and realm ~= "") then
			realm = ("-"..realm)
		end

		Cache[guid] = {
			name = name,
			class = class,
			race = race,
			realm = realm,
		}
	end
	return Cache[guid], guid
end

local function getTarget(unit)
	if(UnitIsUnit(unit, "player")) then
		return ("|cffff0000%s|r"):format(cfg.YOU)
	else
		return UnitName(unit)
	end
end

local function ShowTarget(self, unit)
	if(UnitExists(unit.."target")) then
		local tarRicon = GetRaidTargetIndex(unit.."target")
		local tar = ("%s %s"):format((tarRicon and ICON_LIST[tarRicon].."10|t") or "", getTarget(unit.."target"))

		self:AddDoubleLine(TARGET, tar, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b,
		unitColor(unit.."target"))
	end
end

local function hideLines(self)
	for i=3, self:NumLines() do
		local tipLine = _G["GameTooltipTextLeft"..i]
		local tipText = tipLine:GetText()

		if(tipText == FACTION_ALLIANCE) then
			tipLine:SetText(nil)
			tipLine:Hide()
		elseif(tipText == FACTION_HORDE) then
			tipLine:SetText(nil)
			tipLine:Hide()
		elseif(tipText == PVP) then
			tipLine:SetText(nil)
			tipLine:Hide()
		end
	end
end

local function formatLines(self)
	local hidden = {}
	local numLines = self:NumLines()

	for i=2, numLines do
		local tipLine = _G["GameTooltipTextLeft"..i]

		if(tipLine and not tipLine:IsShown()) then
			hidden[i] = tipLine
		end
	end

	for i, line in next, hidden do
		local nextLine = _G["GameTooltipTextLeft"..i+1]

		if(nextLine) then
			local point, relativeTo, relativePoint, x, y = line:GetPoint()
			nextLine:SetPoint(point, relativeTo, relativePoint, x, y)
		end
	end
end

local function check4Spec(self, guid)
	if(not guid) then return end

	local cache = FreebTipSpec_cache
	if(cache and cache[guid]) then
		self:AddDoubleLine(SPECIALIZATION, cache.specText:format(cache[guid].spec), NORMAL_FONT_COLOR.r,
		NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		self.freebtipSpecSet = true
	end
end

local function getLvldiff(lvl)
	--print(lvl)
	local diff = GetQuestDifficultyColor(lvl)
	return ("%s%s|r"):format(hex(diff), lvl)
end

local trimStr = {
	[LEVEL.." "] = "",
	["("..PLAYER..")"] = "",
	["Highmountain Tauren"] = "High Tauren",
	["Lightforged Draenei"] = "Light Draenei",
}

local function trimLvline(str)
	--print(str)
	return trimStr[str]
end

local classification = {
	rare = ("|cffCC00FF %s|r"):format(ITEM_QUALITY3_DESC),
	rareelite = ("|cffCC00FF %s|r"):format(ITEM_QUALITY3_DESC),
}

-------------------------------------------------------------------------------
--[[ GameTooltip HookScripts ]] --

local function OnSetUnit(self)
	if(cfg.combathide and InCombatLockdown()) then
		return self:Hide()
	end

	hideLines(self)

	if(not self.factionIcon) then
		self.factionIcon = self:CreateTexture(nil, "OVERLAY")
		self.factionIcon:SetPoint("TOPRIGHT", 8, 8)
		self.factionIcon:SetSize(cfg.factionIconSize,cfg.factionIconSize)
		self.factionIcon:SetAlpha(cfg.factionIconAlpha)
	end

	local unit = getUnit(self)
	local player, guid, isInGuild

	if(UnitExists(unit)) then
		self.ftipUnit = unit

		local isPlayer = UnitIsPlayer(unit)

		if(isPlayer) then
			player, guid = getPlayer(unit, GameTooltipTextLeft1:GetText())

			local Name = player and (player.name .. (player.realm or ""))
			if(Name) then GameTooltipTextLeft1:SetText(Name) end

			local guild, gRank = GetGuildInfo(unit)
			if(guild) then
				isInGuild = true

				if(not cfg.showGRank) then gRank = nil end
				GameTooltipTextLeft2:SetFormattedText(cfg.guildText, guild, gRank or "")
			end

			local status = (UnitIsAFK(unit) and CHAT_FLAG_AFK) or (UnitIsDND(unit) and CHAT_FLAG_DND) or
			(not UnitIsConnected(unit) and "<DC>")

			if(status) then
				self:AppendText((" |cff00cc00%s|r"):format(status))
			end
		end

		local ricon = GetRaidTargetIndex(unit)
		if(ricon) then
			local text = GameTooltipTextLeft1:GetText()
			GameTooltipTextLeft1:SetFormattedText(("%s %s"), ICON_LIST[ricon].."12|t", text)
		end

		local faction = UnitFactionGroup(unit)
		if(faction and factionIcon[faction]) then
			self.factionIcon:SetTexture(factionIcon[faction])
			self.factionIcon:Show()
		else
			self.factionIcon:Hide()
		end

		local levelLine
		for i = (isInGuild and 3) or 2, self:NumLines() do
			local line = _G["GameTooltipTextLeft"..i]
			local text = line:GetText()

			if(text and text:find(LEVEL)) then
				levelLine = line
				break
			end
		end

		if(levelLine) then
			lvltxt = levelLine:GetText()
			lvltxt = lvltxt:gsub("^%a+%s", trimLvline)
			lvltxt = lvltxt:gsub("%a+%s%a+", trimLvline)
			lvltxt = lvltxt:gsub("%b()", trimLvline)
			lvltxt = lvltxt:gsub("^[0-9]+", getLvldiff)

			local classify = UnitClassification(unit)
			if(classify and classification[classify]) then
				levelLine:SetFormattedText("%s%s", lvltxt:trim(), classification[classify])
			else
				levelLine:SetText(lvltxt:trim())
			end
		end

		local dead = UnitIsDeadOrGhost(unit)
		if(dead) then
			GameTooltipStatusBar:Hide()
		else
			GameTooltipStatusBar:SetStatusBarColor(unitColor(unit))
		end

		ShowTarget(self, unit)
		check4Spec(self, guid)
	end

	formatLines(self)
end
GameTooltip:HookScript("OnTooltipSetUnit", OnSetUnit)

local tipCleared = function(self)
	if(self.factionIcon) then
		self.factionIcon:Hide()
	end

	self.ftipNumLines = 0
	self.ftipUnit = nil
end
GameTooltip:HookScript("OnTooltipCleared", tipCleared)


local function GTUpdate(self, elapsed)
	self.ftipUpdate = (self.ftipUpdate or 0) + elapsed
	if(self.ftipUpdate < .1) then return end

	if(not cfg.fadeOnUnit) then
		if(self.ftipUnit and not UnitExists(self.ftipUnit)) then self:Hide() return end
	end

	self:SetBackdropColor()

	local numLines = self:NumLines()
	self.ftipNumLines = self.ftipNumLines or 0
	if not (self.ftipNumLines == numLines) then
		if(GameTooltipStatusBar:IsShown()) then
			local height = GameTooltipStatusBar:GetHeight()-2
			self:SetHeight((self:GetHeight()+height))
		end

		formatLines(self)

		self.ftipNumLines = numLines
	end

	self.ftipUpdate = 0
end
GameTooltip:HookScript("OnUpdate", GTUpdate)

local function fadeOut(self)
	if(not cfg.fadeOnUnit) then
		self:Hide()
	end
end
GameTooltip.FadeOut = fadeOut

-------------------------------------------------------------------------------
--[[ GameTooltipStatusBar ]]--

GameTooltipStatusBar:SetStatusBarTexture(cfg.statusbar)
GameTooltipStatusBar:SetHeight(cfg.sbHeight)
GameTooltipStatusBar:ClearAllPoints()
GameTooltipStatusBar:SetPoint("BOTTOMLEFT", 8, 5)
GameTooltipStatusBar:SetPoint("BOTTOMRIGHT", -8, 5)

local gtSBbg = GameTooltipStatusBar:CreateTexture(nil, "BACKGROUND")
gtSBbg:SetAllPoints(GameTooltipStatusBar)
gtSBbg:SetTexture(cfg.statusbar)
gtSBbg:SetVertexColor(0.3, 0.3, 0.3, 0.5)

local function gtSBValChange(self, value)
	if(not value) then
		return
	end
	local min, max = self:GetMinMaxValues()
	if(value < min) or (value > max) then
		return
	end

	if(not self.text) then
		self.text = self:CreateFontString(nil, "OVERLAY")
		self.text:SetPoint("CENTER", self, 0, 0)
		self.text:SetFont(cfg.font, 10, "OUTLINE")
	end

	if(cfg.sbText) then
		local hp = numberize(self:GetValue())
		self.text:SetText(hp)
	else
		self.text:SetText(nil)
	end
end
GameTooltipStatusBar:HookScript("OnValueChanged", gtSBValChange)

local ssbc = CreateFrame("StatusBar").SetStatusBarColor
GameTooltipStatusBar._SetStatusBarColor = ssbc
function GameTooltipStatusBar:SetStatusBarColor(...)
	local unit = getUnit(GameTooltip)
	if(UnitExists(unit)) then
		return self:_SetStatusBarColor(unitColor(unit))
	end
end

-------------------------------------------------------------------------------
--[[ Style ]]--

local tooltips = {
	"GameTooltip",
	"ItemRefTooltip",
	"WorldMapTooltip",
	"DropDownList1MenuBackdrop",
	"DropDownList2MenuBackdrop",
	"DropDownList3MenuBackdrop",
	"AutoCompleteBox",
	"FriendsTooltip",
	"FloatingBattlePetTooltip",
	"FloatingPetBattleAbilityTooltip",
	"FloatingGarrisonFollowerTooltip",
	"GarrisonFollowerAbilityTooltip",
	"NamePlateTooltip"
}

local shoppingtips = {
	"ShoppingTooltip1",
	"ShoppingTooltip2",
	"ShoppingTooltip3",
	"ItemRefShoppingTooltip1",
	"ItemRefShoppingTooltip2",
	"ItemRefShoppingTooltip3",
	"WorldMapCompareTooltip1",
	"WorldMapCompareTooltip2",
	"WorldMapCompareTooltip3"
}

local itemUpdate = {}

local _SetBackdrop = CreateFrame("Frame").SetBackdrop
local _SetBackdropBorderColor = CreateFrame("Frame").SetBackdropBorderColor
local _SetBackdropColor = CreateFrame("Frame").SetBackdropColor

local function sbd(...)
	local self = ...
	return self:_SetBackdrop(cfg.backdrop)
end

local function sbdbc(...)
	local self = ...

	if(self.GetItem) then
		local _, item = self:GetItem()
		if(item) then
			local quality = select(3, GetItemInfo(item))
			if(quality) then
				local r, g, b = GetItemQualityColor(quality)
				return self:_SetBackdropBorderColor(r, g, b)
			end
		end
	end

	return self:_SetBackdropBorderColor(cfg.backdrop.backdropBorderColor:GetRGB())
end

local function sbdc(...)
	local self = ...
	return self:_SetBackdropColor(cfg.backdrop.backdropColor:GetRGBA())
end

local function tip_style(frame)
	if(not frame.freebBD) then
		frame._SetBackdrop = _SetBackdrop
		frame._SetBackdropBorderColor = _SetBackdropBorderColor
		frame._SetBackdropColor = _SetBackdropColor

		frame.SetBackdrop = sbd
		frame.SetBackdropBorderColor = sbdbc
		frame.SetBackdropColor = sbdc

		frame:SetBackdrop()

		frame.freebBD = true
	end

	frame:SetBackdropBorderColor()
	frame:SetBackdropColor()
	frame:SetScale(cfg.scale)

	local frameName = frame and frame:GetName()
	if(not frameName) then return end

	if(frame.hasMoney and frame.numMoneyFrames ~= frame.ftipNumMFrames) then
		for i=1, frame.numMoneyFrames do
			_G[frameName.."MoneyFrame"..i.."PrefixText"]:SetFontObject(GameTooltipText)
			_G[frameName.."MoneyFrame"..i.."SuffixText"]:SetFontObject(GameTooltipText)
			_G[frameName.."MoneyFrame"..i.."GoldButtonText"]:SetFontObject(GameTooltipText)
			_G[frameName.."MoneyFrame"..i.."SilverButtonText"]:SetFontObject(GameTooltipText)
			_G[frameName.."MoneyFrame"..i.."CopperButtonText"]:SetFontObject(GameTooltipText)
		end

		frame.ftipNumMFrames = frame.numMoneyFrames
	end

	if(frame.shopping and not frame.ftipFontSet) then
		_G[frameName.."TextLeft1"]:SetFontObject(GameTooltipTextSmall)
		_G[frameName.."TextRight1"]:SetFontObject(GameTooltipText)
		_G[frameName.."TextLeft2"]:SetFontObject(GameTooltipHeaderText)
		_G[frameName.."TextRight2"]:SetFontObject(GameTooltipTextSmall)
		_G[frameName.."TextLeft3"]:SetFontObject(GameTooltipTextSmall)
		_G[frameName.."TextRight3"]:SetFontObject(GameTooltipTextSmall)

		frame.ftipFontSet = true
	end
end
ns.style = tip_style

local function hook_style(...)
	local self = ...
	if(cfg.combathideALL and InCombatLockdown()) then
		return self:Hide()
	end
	tip_style(self)
end

local freebtipFrame = CreateFrame("Frame")
freebtipFrame:RegisterEvent("ADDON_LOADED")
freebtipFrame:SetScript("OnEvent", function(frame, event, arg1)
	if(event == "ADDON_LOADED") then
		QuestScrollFrame.StoryTooltip:HookScript("OnShow", hook_style)
		QuestScrollFrame.WarCampaignTooltip:HookScript("OnShow", hook_style)

		local function hook(tooltip)
			tooltip:HookScript("OnShow", hook_style)
		end

		for i, tip in ipairs(tooltips) do
			tooltip = _G[tip]
			if(tooltip) then
				hook(tooltip)
			end
		end
		for i, tip in ipairs(shoppingtips) do
			tooltip = _G[tip]
			if(tooltip) then
				hook(tooltip)
				tooltip.shopping = true
			end
		end
	end
end)

-------------------------------------------------------------------------------
--[[ Aura Tooltip info ]] --

local function addAuraInfo(self, caster, spellID)
	if(not cfg.auraInfo) then return end

	if(spellID) then
		GameTooltip:AddLine("ID: "..spellID)
		GameTooltip:Show()
	end

	if(caster) then
		local color = hex(unitColor(caster))

		GameTooltip:AddLine("Applied by "..color..UnitName(caster))
		GameTooltip:Show()
	end
end

local UnitAura, UnitBuff, UnitDebuff = UnitAura, UnitBuff, UnitDebuff
hooksecurefunc(GameTooltip, "SetUnitAura", function(self,...)
	local _,_,_,_,_,_, caster,_,_, spellID = UnitAura(...)
	addAuraInfo(self, caster, spellID)
end)
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self,...)
	local _,_,_,_,_,_, caster,_,_, spellID = UnitBuff(...)
	addAuraInfo(self, caster, spellID)
end)
hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self,...)
	local _,_,_,_,_,_, caster,_,_, spellID = UnitDebuff(...)
	addAuraInfo(self, caster, spellID)
end)