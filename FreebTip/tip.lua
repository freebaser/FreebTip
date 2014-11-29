local ADDON_NAME, ns = ...

local mediapath = "Interface\\AddOns\\FreebTip\\media\\"
local cfg = {
	font = mediapath.."expressway.ttf",
	fontsize = 12, -- I'd suggest adjusting the scale instead of the fontsize
	outline = "OUTLINE",
	tex = mediapath.."texture",

	scale = 1.1,
	-- can use /freebtip or uncomment this to override SavedVars
	--point = { "BOTTOMRIGHT", -25, 200 },
	cursor = false,

	hideTitles = true,
	hideRealm = false,
	hideFaction = true,
	hidePvP = true,

	showFactionIcon = true,
	factionIconSize = 44,
	factionIconAlpha = .5,

	backdrop = {
		bgFile = "Interface\\Buttons\\WHITE8x8",
		-- original look
		--[[edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },]]

		-- glow border
		edgeFile = mediapath.."glowTex",
		tile = false,
		tileSize = 16,
		edgeSize = 3,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	},
	-- original
	--bgcolor = { r=0.05, g=0.05, b=0.05, t=0.9 }, -- background
	--bdrcolor = { r=0.3, g=0.3, b=0.3 }, -- border
	--
	-- glow border
	bgcolor = { r=0.05, g=0.05, b=0.05, t=1 }, -- background
	bdrcolor = { r=0, g=0, b=0 }, -- border

	gcolor = { r=1, g=0.1, b=0.8 }, -- guild

	you = "<You>",
	boss = BOSS,

	colorborderClass = false,
	colorborderItem = true,

	combathide = false,     -- world objects
	combathideALL = false,  -- everything

	multiTip = true, -- show more than one linked item tooltip

	hideHealthbar = false,

	powerbar = true, -- enable power bars
	powerManaOnly = true, -- only show mana users

	showRank = true, -- show guild rank

	auraID = true, -- show aura id
	auraCaster = true, -- show (if possible) who applied the aura
}
ns.cfg = cfg

local GetTime = GetTime
local find = string.find
local format = string.format
local select = select
local _G = _G
local GameTooltip = GameTooltip
local gtSB = GameTooltipStatusBar
local InCombatLockdown = InCombatLockdown
local PVP = PVP
local FACTION_ALLIANCE = FACTION_ALLIANCE
local FACTION_HORDE = FACTION_HORDE
local LEVEL = LEVEL
local CHAT_FLAG_AFK = CHAT_FLAG_AFK
local CHAT_FLAG_DND = CHAT_FLAG_DND
local ICON_LIST = ICON_LIST
local targettext = TARGET
local DEAD = DEAD
local RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR

local INTERACTIVE_SERVER_LABEL = INTERACTIVE_SERVER_LABEL
local FOREIGN_SERVER_LABEL = FOREIGN_SERVER_LABEL
local COALESCED_REALM_TOOLTIP1 = string.split(FOREIGN_SERVER_LABEL, COALESCED_REALM_TOOLTIP)
local INTERACTIVE_REALM_TOOLTIP1 = string.split(INTERACTIVE_SERVER_LABEL, INTERACTIVE_REALM_TOOLTIP)

if(freebDebug) then
	ns.Debug = function(...)
		freebDebug:Stuff(ADDON_NAME, ...)
	end
else
	ns.Debug = function() end
end

local colors = {power = {}}
for power, color in next, PowerBarColor do
	if(type(power) == 'string') then
		colors.power[power] = {color.r, color.g, color.b}
	end
end

colors.power['MANA'] = {.31,.45,.63}
colors.power['RAGE'] = {.69,.31,.31}

local classification = {
	elite = "+",
	rare = " |cff6699ffR|r",
	rareelite = " |cff6699ffR+|r",
}

local factionIcon = {
	["Alliance"] = "Interface\\Timer\\Alliance-Logo",
	["Horde"] = "Interface\\Timer\\Horde-Logo",
}

local numberize = function(val)
	if(val >= 1e6) then
		return ("%.0fm"):format(val / 1e6)
	elseif(val >= 1e3) then
		return ("%.0fk"):format(val / 1e3)
	else
		return ("%d"):format(val)
	end
end

local hex = function(color)
	return (color.r and format('|cff%02x%02x%02x', color.r * 255, color.g * 255, color.b * 255)) or "|cffFFFFFF"
end

local nilcolor = { r=1, g=1, b=1 }
local tapped = { r=.6, g=.6, b=.6 }

local function unitColor(unit)
	local color

	if(unit) then
		if(UnitIsPlayer(unit)) then
			local colors = RAID_CLASS_COLORS
			local _, class = UnitClass(unit)
			color = colors[class]
		elseif(UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)) then
			color = tapped
		else
			local reaction = UnitReaction(unit, "player")
			if(reaction) then
				color = FACTION_BAR_COLORS[reaction]
			end
		end
	end

	return (color or nilcolor)
end

local function GameTooltip_UnitColor(unit)
	local color = unitColor(unit)
	return color.r, color.g, color.b
end

local function getUnit(self)
	local _, unit = self and self:GetUnit()
	if(not unit) then
		local mFocus = GetMouseFocus()
		unit = mFocus and (mFocus.unit or mFocus:GetAttribute("unit"))	or "mouseover"
	end

	return unit
end

local function formatLines(self)
	for i=1, self:NumLines() do
		local tiptext = _G["GameTooltipTextLeft"..i]
		local point, relTo, relPoint, x, y = tiptext:GetPoint()
		tiptext:ClearAllPoints()

		if(i==1) then
			tiptext:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
		else
			local key = i-1

			while(true) do
				local preTiptext = _G["GameTooltipTextLeft"..key]

				if(preTiptext and not preTiptext:IsShown()) then
					key = key-1
				else
					break
				end
			end

			tiptext:SetPoint("TOPLEFT", _G["GameTooltipTextLeft"..key], "BOTTOMLEFT", x, -2)
		end
	end
end

local function hideLines(self)
	for i=3, self:NumLines() do
		local tiptext = _G["GameTooltipTextLeft"..i]
		local linetext = tiptext:GetText()

		if(linetext) then
			if(cfg.hidePvP and linetext:find(PVP)) then
				tiptext:SetText(nil)
				tiptext:Hide()
			elseif(linetext:find(COALESCED_REALM_TOOLTIP1) or linetext:find(INTERACTIVE_REALM_TOOLTIP1)) then
				tiptext:SetText(nil)
				tiptext:Hide()

				local pretiptext = _G["GameTooltipTextLeft"..i-1]
				pretiptext:SetText(nil)
				pretiptext:Hide()

				self:Show()
			elseif(linetext == FACTION_ALLIANCE) then
				if(cfg.hideFaction) then
					tiptext:SetText(nil)
					tiptext:Hide()
				else
					tiptext:SetText("|cff7788FF"..linetext.."|r")
				end
			elseif(linetext == FACTION_HORDE) then
				if(cfg.hideFaction) then
					tiptext:SetText(nil)
					tiptext:Hide()
				else
					tiptext:SetText("|cffFF4444"..linetext.."|r")
				end
			end
		end
	end
end

local function UpdatePower(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if(self.elapsed < .25) then return end

	local unit = getUnit(GameTooltip)
	if(unit) then
		local min, max = UnitPower(unit), UnitPowerMax(unit)
		if(max ~= 0) then
			self:SetValue(min)

			local pp = numberize(min).." / "..numberize(max)
			self.text:SetText(pp)
		end
	end

	self.elapsed = 0
end

local function HidePower(powerbar)
	if(powerbar) then
		powerbar:Hide()

		if(powerbar.text) then
			powerbar.text:SetText(nil)
		end
	end
end

local function ShowPowerBar(self, unit, statusbar)
	local powerbar = _G[self:GetName().."FreebTipPowerBar"]
	if(not unit) then return HidePower(powerbar) end

	local min, max = UnitPower(unit), UnitPowerMax(unit)
	local ptype, ptoken = UnitPowerType(unit)

	if(max == 0 or (cfg.powerManaOnly and ptoken ~= 'MANA')) then
		return HidePower(powerbar)
	end

	if(not powerbar) then
		powerbar = CreateFrame("StatusBar", self:GetName().."FreebTipPowerBar", statusbar)
		powerbar:SetHeight(statusbar:GetHeight())
		powerbar:SetFrameLevel(statusbar:GetFrameLevel())
		powerbar:SetWidth(0)
		powerbar:SetStatusBarTexture(cfg.tex, "OVERLAY")
		powerbar.elapsed = 0
		powerbar:SetScript("OnUpdate", UpdatePower)

		local bg = powerbar:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(powerbar)
		bg:SetTexture(cfg.tex)
		bg:SetVertexColor(0.3, 0.3, 0.3, 0.5)
	end
	powerbar.unit = unit

	powerbar:SetMinMaxValues(0, max)
	powerbar:SetValue(min)

	local pcolor = colors.power[ptoken]
	if(pcolor) then
		powerbar:SetStatusBarColor(pcolor[1], pcolor[2], pcolor[3])
	end

	powerbar:ClearAllPoints()
	powerbar:SetPoint("LEFT", statusbar, "LEFT", 0, -(statusbar:GetHeight()) - 4)
	powerbar:SetPoint("RIGHT", self, "RIGHT", -10, 0)

	powerbar:Show()

	if(not powerbar.text) then
		powerbar.text = powerbar:CreateFontString(nil, "OVERLAY")
		powerbar.text:SetPoint("CENTER", powerbar)
		powerbar.text:SetFont(cfg.font, 12, cfg.outline)
		powerbar.text:Show()
	end

	local pp = numberize(min).." / "..numberize(max)
	powerbar.text:SetText(pp)
end

local function PlayerTitle(self, unit)
	local unitName
	if(cfg.hideTitles and cfg.hideRealm) then
		unitName = UnitName(unit)
	elseif(cfg.hideTitles) then
		unitName = GetUnitName(unit, true)
	elseif(cfg.hideRealm) then
		unitName = UnitPVPName(unit) or UnitName(unit)
	end

	if(unitName) then GameTooltipTextLeft1:SetText(unitName) end

	local relationship = UnitRealmRelationship(unit)
	if(relationship == LE_REALM_RELATION_VIRTUAL) then
		self:AppendText(("|cffcccccc%s|r"):format(INTERACTIVE_SERVER_LABEL))
	end

	local status = UnitIsAFK(unit) and CHAT_FLAG_AFK or UnitIsDND(unit) and CHAT_FLAG_DND or
	not UnitIsConnected(unit) and "<DC>"

	if(status) then
		self:AppendText((" |cff00cc00%s|r"):format(status))
	end
end

local function PlayerGuild(self, unit, unitGuild, unitRank)
	if(unitGuild) then
		local text2 = GameTooltipTextLeft2
		local str = hex(cfg.gcolor).."<%s> |cff00E6A8%s|r"
		local unitRank = cfg.showRank and unitRank or ""

		text2:SetFormattedText(str, unitGuild, unitRank)
	end
end

local function SetStatusBar(self, unit)
	if(gtSB:IsShown()) then
		if(cfg.hideHealthbar) then
			GameTooltipStatusBar:Hide()
			return
		end

		if(cfg.powerbar) then
			ShowPowerBar(self, unit, gtSB)
		end

		gtSB:ClearAllPoints()

		local gtsbHeight = gtSB:GetHeight()
		if(GameTooltipFreebTipPowerBar and GameTooltipFreebTipPowerBar:IsShown()) then
			GameTooltipStatusBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 10, ((gtsbHeight)*2)+7)
			GameTooltipStatusBar:SetPoint("BOTTOMRIGHT", self, -10, 0)
		else
			GameTooltipStatusBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 10, gtsbHeight+3)
			GameTooltipStatusBar:SetPoint("BOTTOMRIGHT", self, -10, 0)
		end
	end

	if(unit) then
		GameTooltipStatusBar:SetStatusBarColor(GameTooltip_UnitColor(unit))
	else
		GameTooltipStatusBar:SetStatusBarColor(0, .9, 0)
	end
end

local function getTarget(unit)
	if(UnitIsUnit(unit, "player")) then
		return ("|cffff0000%s|r"):format(cfg.you)
	else
		return UnitName(unit)
	end
end

local function ShowTarget(self, unit)
	if(UnitExists(unit.."target")) then
		local tarRicon = GetRaidTargetIndex(unit.."target")
		local tar = ("%s%s"):format((tarRicon and ICON_LIST[tarRicon].."10|t") or "", getTarget(unit.."target"))

		self:AddDoubleLine(targettext, tar, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b,
		GameTooltip_UnitColor(unit.."target"))
	end
end

local function OnSetUnit(self)
	if(cfg.combathide and InCombatLockdown()) then
		return self:Hide()
	end

	hideLines(self)

	local unit = getUnit(self)
	if(UnitExists(unit)) then
		local isPlayer = UnitIsPlayer(unit)

		if not (self.factionIcon) then
			self.factionIcon = self:CreateTexture(nil, "BORDER")
			self.factionIcon:SetPoint("TOPRIGHT", 3, 3)
		end

		local faction = UnitFactionGroup(unit)
		if(cfg.showFactionIcon and faction and factionIcon[faction] and isPlayer) then
			--self.factionIcon:SetAtlas("MountJournalIcons-"..faction, true)
			self.factionIcon:SetTexture(factionIcon[faction])
			self.factionIcon:SetSize(cfg.factionIconSize,cfg.factionIconSize)
			self.factionIcon:SetAlpha(cfg.factionIconAlpha)
			self.factionIcon:Show()
		else
			self.factionIcon:Hide()
		end

		local color = unitColor(unit)
		local unitGuild, unitRank

		if(isPlayer) then
			PlayerTitle(self, unit)
			unitGuild, unitRank = GetGuildInfo(unit)
			PlayerGuild(self, unit, unitGuild, unitRank)
		end

		local ricon = GetRaidTargetIndex(unit)
		if(ricon) then
			local text = GameTooltipTextLeft1:GetText()
			GameTooltipTextLeft1:SetFormattedText(("%s %s"), ICON_LIST[ricon]..cfg.fontsize.."|t", text)
		end

		local line1 = GameTooltipTextLeft1:GetText()
		GameTooltipTextLeft1:SetFormattedText(("%s"), hex(color)..line1)
		GameTooltipTextLeft1:SetTextColor(GameTooltip_UnitColor(unit))

		local alive = not UnitIsDeadOrGhost(unit)

		local level
		if(UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)) then
			level = UnitBattlePetLevel(unit)
		else
			level = UnitLevel(unit)
		end

		if(level) then
			local unitClass = isPlayer and ("%s %s"):format((UnitRace(unit) or ""), hex(color)..(UnitClass(unit) or "").."|r") or ""
			local creature = not isPlayer and UnitCreatureType(unit) or ""
			local diff = GetQuestDifficultyColor(level)

			local boss
			if(level == -1) then
				boss = "|cffff0000"..cfg.boss
			end

			local classify = UnitClassification(unit) or ""
			local textLevel = ("%s%s%s|r"):format(hex(diff), boss or ("%d"):format(level), not boss and classification[classify] or "")

			local tiptextLevel
			for i=(unitGuild and 3) or 2, self:NumLines() do
				local tiptext = _G["GameTooltipTextLeft"..i]
				local linetext = tiptext:GetText()

				if(linetext and linetext:find(LEVEL)) then
					tiptextLevel = tiptext
				end
			end

			if(tiptextLevel) then
				tiptextLevel:SetFormattedText(("%s %s%s %s"), textLevel, creature, unitClass,
				(not alive and "|cffCCCCCC"..DEAD.."|r" or ""))
			end
		end

		ShowTarget(self, unit)

		if(not alive) then
			GameTooltipStatusBar:Hide()
		end
	end

	SetStatusBar(self, unit)

	self.freebHeightSet = nil
	self.freebtipUpdate = 0
end
GameTooltip:HookScript("OnTooltipSetUnit", OnSetUnit)

local tipCleared = function(self)
	if(self.factionIcon) then
		self.factionIcon:Hide()
	end
	if not (self.freebtipItem) then
		self:SetBackdropBorderColor(cfg.bdrcolor.r, cfg.bdrcolor.g, cfg.bdrcolor.b)
	end
end
GameTooltip:HookScript("OnTooltipCleared", tipCleared)

gtSB:SetStatusBarTexture(cfg.tex)
gtSB:SetHeight(9)
local bg = gtSB:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(GameTooltipStatusBar)
bg:SetTexture(cfg.tex)
bg:SetVertexColor(0.3, 0.3, 0.3, 0.5)

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
		self.text:SetPoint("CENTER", GameTooltipStatusBar)
		self.text:SetFont(cfg.font, 12, cfg.outline)
	end
	self.text:Show()
	local hp = numberize(self:GetValue()).." / "..numberize(max)
	self.text:SetText(hp)
end
gtSB:SetScript("OnValueChanged", gtSBValChange)

local itemTips = {}

local function style(frame)
	if(not frame) then return end
	local frameName = frame:GetName()

	if(not frame.freebtipBD) then
		frame:SetBackdrop(cfg.backdrop)
		frame.freebtipBD = true
	end
	frame:SetBackdropColor(cfg.bgcolor.r, cfg.bgcolor.g, cfg.bgcolor.b, cfg.bgcolor.t)
	frame:SetBackdropBorderColor(cfg.bdrcolor.r, cfg.bdrcolor.g, cfg.bdrcolor.b)
	frame:SetScale(cfg.scale)

	if(cfg.colorborderItem and frame.GetItem) then
		frame.freebtipItem = false
		local _, item = frame:GetItem()
		if(item) then
			local quality = select(3, GetItemInfo(item))
			if(quality) then
				local r, g, b = GetItemQualityColor(quality)
				frame:SetBackdropBorderColor(r, g, b)
				itemTips[frameName] = nil
				frame.freebtipItem = true
			else
				itemTips[frameName] = true
			end
		end
	end

	if(not frameName) then return end
	if(frameName ~= "GameTooltip" and frame.NumLines) then
		for index=1, frame:NumLines() do
			if(index==1) then
				_G[frameName..'TextLeft'..index]:SetFontObject(GameTooltipHeaderText)
			else
				_G[frameName..'TextLeft'..index]:SetFontObject(GameTooltipText)
			end
			_G[frameName..'TextRight'..index]:SetFontObject(GameTooltipText)
		end
	end

	if(_G[frameName.."MoneyFrame1"]) then
		_G[frameName.."MoneyFrame1PrefixText"]:SetFontObject(GameTooltipText)
		_G[frameName.."MoneyFrame1SuffixText"]:SetFontObject(GameTooltipText)
		_G[frameName.."MoneyFrame1GoldButtonText"]:SetFontObject(GameTooltipText)
		_G[frameName.."MoneyFrame1SilverButtonText"]:SetFontObject(GameTooltipText)
		_G[frameName.."MoneyFrame1CopperButtonText"]:SetFontObject(GameTooltipText)
	end

	if(_G[frameName.."MoneyFrame2"]) then
		_G[frameName.."MoneyFrame2PrefixText"]:SetFontObject(GameTooltipText)
		_G[frameName.."MoneyFrame2SuffixText"]:SetFontObject(GameTooltipText)
		_G[frameName.."MoneyFrame2GoldButtonText"]:SetFontObject(GameTooltipText)
		_G[frameName.."MoneyFrame2SilverButtonText"]:SetFontObject(GameTooltipText)
		_G[frameName.."MoneyFrame2CopperButtonText"]:SetFontObject(GameTooltipText)
	end
end

local itemEvent = CreateFrame"Frame"
itemEvent:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemEvent:SetScript("OnEvent", function(self, event, arg1)
	ns.Debug("item info received: ", arg1)

	for k in next, itemTips do
		local tip = _G[k]
		if(tip and tip:IsShown()) then
			style(tip)
		end
	end
end)

ns.style = style
FreebTipStyle = style

local tooltips = {
	"GameTooltip",
	"ItemRefTooltip",
	"ShoppingTooltip1",
	"ShoppingTooltip2",
	"ShoppingTooltip3",
	"AutoCompleteBox",
	"FriendsTooltip",
	"WorldMapTooltip",
	"WorldMapCompareTooltip1",
	"WorldMapCompareTooltip2",
	"WorldMapCompareTooltip3",
	"ItemRefShoppingTooltip1",
	"ItemRefShoppingTooltip2",
	"ItemRefShoppingTooltip3",
	"FloatingBattlePetTooltip",
	"BattlePetTooltip",
	"DropDownList1MenuBackdrop",
	"DropDownList2MenuBackdrop",
	"DropDownList3MenuBackdrop",
}

local frameload = CreateFrame"Frame"
frameload:RegisterEvent"PLAYER_LOGIN"
frameload:SetScript("OnEvent", function(self)
	self:UnregisterEvent"PLAYER_LOGIN"

	for i, tip in ipairs(tooltips) do
		frame = _G[tip]
		--ns.Debug(i.. " | ", frame)

		if(frame) then
			frame:HookScript("OnShow", function(self)
				if(cfg.combathideALL and InCombatLockdown()) then
					return self:Hide()
				end

				style(self)
			end)
		end
	end
end)

local timer = 0.1
local function GT_OnUpdate(self, elapsed)
	self:SetBackdropColor(cfg.bgcolor.r, cfg.bgcolor.g, cfg.bgcolor.b, cfg.bgcolor.t)

	self.freebtipUpdate = (self.freebtipUpdate or timer) - elapsed
	if(self.freebtipUpdate > 0) then return end
	self.freebtipUpdate = timer

	local unit = getUnit(self)
	if(self:IsUnit(unit)) then
		hideLines(self)

		if(cfg.colorborderClass and UnitIsPlayer(unit)) then
			local color = unitColor(unit)
			self:SetBackdropBorderColor(color.r,color.g,color.b)
		end
	end

	local numLines = self:NumLines()
	if(self.freebHeightSet ~= numLines) then
		if(gtSB:IsShown()) then
			local height = gtSB:GetHeight()+6

			local powbar = GameTooltipFreebTipPowerBar
			if(powbar and powbar:IsShown()) then
				height = (gtSB:GetHeight()*2)+9
			end

			self:SetHeight((self:GetHeight()+height))
		end

		self.freebHeightSet = numLines
	end

	formatLines(self)
end
GameTooltip:HookScript("OnUpdate", GT_OnUpdate)

-- Because if you're not hacking, you're doing it wrong
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

GameTooltipHeaderText:SetFont(cfg.font, cfg.fontsize+2, cfg.outline)
GameTooltipText:SetFont(cfg.font, cfg.fontsize, cfg.outline)
GameTooltipTextSmall:SetFont(cfg.font, cfg.fontsize-2, cfg.outline)

local function addAuraInfo(self, caster, spellID)
	if(cfg.auraID and spellID) then
		GameTooltip:AddLine("ID: "..spellID)
		GameTooltip:Show()
	end

	if(cfg.auraCaster and caster) then
		local color = unitColor(caster)
		if(color) then
			color = hex(color)
		else
			color = ""
		end

		GameTooltip:AddLine("Applied by "..color..UnitName(caster))
		GameTooltip:Show()
	end
end

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
