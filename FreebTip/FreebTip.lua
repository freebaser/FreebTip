local ADDON_NAME, ns = ...

local mediapath = "Interface\\AddOns\\"..ADDON_NAME.."\\media\\"

--[[ Defaults. OVERRIDE THESE IN SETTINGS.LUA ]]--
local settings = {
	--font = STANDARD_TEXT_FONT,
	font = mediapath.."font.ttf"
	fontflag = "OUTLINE",

	scale = 1.1,

	backdrop = {
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = mediapath.."glowTex",
		tile = false,
		tileSize = 16,
		edgeSize = 3,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	},

	bgcolor = { r=10/255, g=10/255, b=10/255, t=1 }, -- background
	bdrcolor = { r=0, g=0, b=0 }, -- border

	statusbar = mediapath.."statusbar",

	factionIconSize = 30,
	factionIconAlpha = 1,

	pBar = false,

	guildText = "|cffE41F9B<%s>|r |cffA0A0A0%s|r",
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
local qqColor = { r=1, g=0, b=0 }
local nilColor = { r=1, g=1, b=1 }
local tappedColor = { r=.6, g=.6, b=.6 }
local deadColor = { r=.6, g=.6, b=.6 }

local powerColors = {}
for power, color in next, PowerBarColor do
	powerColors[power] = color
end
powerColors['MANA'] = { r=.31, g=.45, b=.72 }
powerColors['RAGE'] = { r=.69, g=.31, b=.31 }

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
		return ("%.0fm"):format(val / 1e6)
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

local function getUnit(self)
	local _, unit = self and self:GetUnit()
	if(not unit) then
		local mFocus = GetMouseFocus()
		unit = mFocus and (mFocus.unit or mFocus:GetAttribute("unit")) or "mouseover"
	end

	return unit
end

FreebTip_Cache = {}
local Cache = FreebTip_Cache
local function getPlayer(unit)
	local guid = UnitGUID(unit)
	if not (Cache[guid]) then
		local class, _, race, _, _, name, realm = GetPlayerInfoByGUID(guid)
		if not name then return end

		Cache[guid] = {
			name = name,
			class = class,
			race = race,
			realm = realm and ((realm ~= "") and (" - "..realm)),
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

	self.ftipNumLines = numLines
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

local function check4Ilvl(self, guid)
	if(not guid) then return end

	local cache = FreebTipiLvl_cache
	if(cache and cache[guid]) then
		self:AddDoubleLine(ITEM_LEVEL_ABBR, cache.ilvlText:format(cache[guid].score), NORMAL_FONT_COLOR.r,
		NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		self.freebtipiLvlSet = true
	end
end

-------------------------------------------------------------------------------
--[[ GameTooltip HookScripts ]] --

local function OnSetUnit(self)
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
		local isPlayer = UnitIsPlayer(unit)

		if(isPlayer) then
			player, guid = getPlayer(unit)

			local Name = player and (player.name .. (player.realm or ""))
			if(Name) then GameTooltipTextLeft1:SetText(Name) end

			local guild, gRank = GetGuildInfo(unit)
			if(guild and gRank) then
				isInGuild = true
				GameTooltipTextLeft2:SetFormattedText(cfg.guildText, guild, gRank or "")
			end
		end

		local status = (UnitIsAFK(unit) and CHAT_FLAG_AFK) or (UnitIsDND(unit) and CHAT_FLAG_DND) or
		(not UnitIsConnected(unit) and "<DC>")
		if(status) then
			self:AppendText((" |cff00cc00%s|r"):format(status))
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

		local isBattlePet = UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)
		local level = isBattlePet and UnitBattlePetLevel(unit) or UnitLevel(unit)

		if(level) then
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
				local creature = not isPlayer and UnitCreatureType(unit)
				local race = player and player.race or UnitRace(unit)
				local dead = UnitIsDeadOrGhost(unit) and hex(deadColor)..CORPSE.."|r"
				local classify = UnitClassification(unit)

				local class = player and hex(unitColor(unit))..(player.class or "").."|r"
				if(isBattlePet) then
					class = ("|cff80ACEF(%s)|r"):format(_G["BATTLE_PET_NAME_"..UnitBattlePetType(unit)])
				end

				local lvltxt, diff
				if(level == -1) then
					level = classification.worldboss
					lvltxt = level
				else
					level = ("%d"):format(level)
					diff = not isBattlePet and GetQuestDifficultyColor(level)
					lvltxt = ("%s%s|r%s"):format(hex(diff), level, (classify and classification[classify] or ""))
				end

				if(dead) then
					levelLine:SetFormattedText("%s %s", lvltxt, dead)
					GameTooltipStatusBar:Hide()
				else
					levelLine:SetFormattedText("%s %s", lvltxt, (creature or race) or "")
				end

				if(class) then
					lvltxt = levelLine:GetText()
					levelLine:SetFormattedText("%s %s", lvltxt, class)
				end

				if(UnitIsPVP(unit) and UnitCanAttack("player", unit)) then
					lvltxt = levelLine:GetText()
					levelLine:SetFormattedText("%s |cff00FF00(%s)|r", lvltxt, PVP)
				end
			end
		end

		if(cfg.pBar) then
			self.ftipPowerBar.unit = unit
			local pMin, pMax = UnitPower(unit), UnitPowerMax(unit)
			if(pMin > 0) then
				self.ftipPowerBar:SetMinMaxValues(0, pMax)
				self.ftipPowerBar:SetValue(pMin)

				local pType, pToken = UnitPowerType(unit)
				local pColor = powerColors[pToken]
				self.ftipPowerBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
				self.ftipPowerBar:Show()
			else
				self.ftipPowerBar:Hide()
			end
		end

		ShowTarget(self, unit)

		check4Spec(self, guid)
		check4Ilvl(self, guid)
	end

	formatLines(self)
end
GameTooltip:HookScript("OnTooltipSetUnit", OnSetUnit)

local tipCleared = function(self)
	if(self.factionIcon) then
		self.factionIcon:Hide()
	end

	self.ftipUpdate = 1
	self.ftipNumLines = 0
end
GameTooltip:HookScript("OnTooltipCleared", tipCleared)

local function GTUpdate(self, elapsed)
	self.ftipUpdate = (self.ftipUpdate or 0) + elapsed
	if(self.ftipUpdate < .1) then return end

	self:SetBackdropColor(cfg.bgcolor.r, cfg.bgcolor.g, cfg.bgcolor.b, cfg.bgcolor.t)

	local numLines = self:NumLines()
	self.ftipNumLines = self.ftipNumLines or 0
	if not (self.ftipNumLines == numLines) then
		if(GameTooltipStatusBar:IsShown() and self.ftipPowerBar:IsShown()) then
			local height = (GameTooltipStatusBar:GetHeight() * 2)-2
			self:SetHeight((self:GetHeight()+height))
		end

		formatLines(self)
	end

	self.ftipUpdate = 0
end
GameTooltip:HookScript("OnUpdate", GTUpdate)

-------------------------------------------------------------------------------
--[[ GameTooltipStatusBar ]]--

GameTooltipStatusBar:SetStatusBarTexture(cfg.statusbar)
GameTooltipStatusBar:SetHeight(2)
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
		self.text:SetPoint("CENTER", GameTooltipStatusBar, 0, 0)
		self.text:SetFont(cfg.font, 10, "THICKOUTLINE")
	end
	--self.text:Show()
	self.text:Hide()
	local hp = numberize(self:GetValue())
	self.text:SetText(hp)
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
--[[ FreebTipPowerBar ]]--

local powerbar = CreateFrame("StatusBar", "FreebTipPowerBar", GameTooltipStatusBar)
powerbar:SetFrameLevel(GameTooltipStatusBar:GetFrameLevel())
powerbar:SetHeight(GameTooltipStatusBar:GetHeight())
powerbar:SetWidth(0)
powerbar:SetStatusBarTexture(cfg.statusbar)
powerbar:ClearAllPoints()
powerbar:SetPoint("BOTTOMLEFT", GameTooltipStatusBar, "TOPLEFT", 0, 1)
powerbar:SetPoint("BOTTOMRIGHT", GameTooltipStatusBar, "TOPRIGHT", 0, 1)
powerbar:Hide()
GameTooltip.ftipPowerBar = powerbar

local function UpdatePower(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if(self.elapsed < .2) then return end
	self.elapsed = 0

	local unit = self.unit
	if(UnitExists(unit)) then
		local pMin, pMax = UnitPower(unit), UnitPowerMax(unit)
		if(pMin > 0) then
			self:SetMinMaxValues(0, pMax)
			self:SetValue(pMin)
		end
	end
end
powerbar:SetScript("OnUpdate", UpdatePower)

local gtPBbg = powerbar:CreateTexture(nil, "BACKGROUND")
gtPBbg:SetAllPoints(powerbar)
gtPBbg:SetTexture(cfg.statusbar)
gtPBbg:SetVertexColor(0.3, 0.3, 0.3, 0.5)

-------------------------------------------------------------------------------
--[[ Style ]] --

local shopping = {
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
	"FloatingGarrisonFollowerTooltip"
}

local itemUpdate = {}
local function style(frame)
	local frameName = frame and frame:GetName()
	if not (frameName) then return end
	ns.Debug(frameName)

	if(not frame.ftipBD) then
		frame:SetBackdrop(cfg.backdrop)
		frame.ftipBD = true
	end
	frame:SetBackdropColor(cfg.bgcolor.r, cfg.bgcolor.g, cfg.bgcolor.b, cfg.bgcolor.t)
	frame:SetBackdropBorderColor(cfg.bdrcolor.r, cfg.bdrcolor.g, cfg.bdrcolor.b)
	frame:SetScale(cfg.scale)

	if(frame.GetItem) then
		local _, item = frame:GetItem()
		if(item) then
			local quality = select(3, GetItemInfo(item))
			if(quality) then
				local r, g, b = GetItemQualityColor(quality)
				frame:SetBackdropBorderColor(r, g, b)
				itemUpdate[frameName] = nil
			else
				itemUpdate[frameName] = true
			end
		end
	end

	if(frame.hasMoney and frame.numMoneyFrames ~= frame.ftipNumMFrames) then
		for i=1, frame.numMoneyFrames do
			_G[frameName.."MoneyFrame"..i.."PrefixText"]:SetFontObject(GameTooltipText)
			_G[frameName.."MoneyFrame"..i.."SuffixText"]:SetFontObject(GameTooltipText)
			_G[frameName.."MoneyFrame"..i.."GoldButtonText"]:SetFontObject(GameTooltipText)
			_G[frameName.."MoneyFrame"..i.."SilverButtonText"]:SetFontObject(GameTooltipText)
			_G[frameName.."MoneyFrame"..i.."CopperButtonText"]:SetFontObject(GameTooltipText)

			ns.Debug("mframe update")
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
		_G[frameName.."TextRight4"]:SetFontObject(GameTooltipTextSmall)

		frame.ftipFontSet = true
	end

	if(frame.BorderTopLeft) then
		
	end

	if(frame.BattlePet and not frame.ftipBPfont) then
		frame.Name:SetFontObject(GameTooltipHeaderText)
		frame.BattlePet:SetFontObject(GameTooltipText)
		frame.PetType:SetFontObject(GameTooltipText)
		frame.Health:SetFontObject(GameTooltipText)
		frame.Level:SetFontObject(GameTooltipText)
		frame.Power:SetFontObject(GameTooltipText)
		frame.Speed:SetFontObject(GameTooltipText)
		frame.Owned:SetFontObject(GameTooltipText)
		frame.ftipBPfont = true

		frame.BorderTop:Hide()
		frame.BorderRight:Hide()
		frame.BorderBottom:Hide()
		frame.BorderLeft:Hide()
		frame.BorderTopLeft:Hide()
		frame.BorderTopRight:Hide()
		frame.BorderBottomLeft:Hide()
		frame.BorderBottomRight:Hide()
	end

	if(frame.BackdropFrame) then
		frame.BackdropFrame:Hide()
	end
end
ns.style = style

local function OverrideGetBackdropColor()
	return cfg.bgcolor.r, cfg.bgcolor.g, cfg.bgcolor.b, cfg.bgcolor.t
end
GameTooltip.GetBackdropColor = OverrideGetBackdropColor
GameTooltip:SetBackdropColor(OverrideGetBackdropColor)

local function OverrideGetBackdropBorderColor()
	return cfg.bdrcolor.r, cfg.bdrcolor.g, cfg.bdrcolor.b
end
GameTooltip.GetBackdropBorderColor = OverrideGetBackdropBorderColor
GameTooltip:SetBackdropBorderColor(OverrideGetBackdropBorderColor)

local frameload = CreateFrame"Frame"
frameload:RegisterEvent("PLAYER_ENTERING_WORLD")
frameload:SetScript("OnEvent", function(self)
	self:UnregisterEvent"PLAYER_ENTERING_WORLD"

	local function hook(tip)
		ns.Debug(frame:GetName())
		frame:HookScript("OnShow", function(self)
			style(self)
		end)
	end

	for i, tip in ipairs(tooltips) do
		frame = _G[tip]
		if(frame) then
			hook(frame)
		end
	end
	for i, tip in ipairs(shopping) do
		frame = _G[tip]
		if(frame) then
			hook(frame)
			frame.shopping = true
		end
	end
end)

local itemEvent = CreateFrame"Frame"
itemEvent:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemEvent:SetScript("OnEvent", function(self, event, arg1)
	ns.Debug("item info received: ", arg1)

	for k in next, itemUpdate do
		local tip = _G[k]
		if(tip and tip:IsShown()) then
			style(tip)
		end
	end
end)

-------------------------------------------------------------------------------
--[[ Aura Tooltip info ]] --

local function addAuraInfo(self, caster, spellID)
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
	local _,_,_,_,_,_,_, caster,_,_, spellID = UnitAura(...)
	addAuraInfo(self, caster, spellID)
end)
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self,...)
	local _,_,_,_,_,_,_, caster,_,_, spellID = UnitBuff(...)
	addAuraInfo(self, caster, spellID)
end)
hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self,...)
	local _,_,_,_,_,_,_, caster,_,_, spellID = UnitDebuff(...)
	addAuraInfo(self, caster, spellID)
end)
