-------------------------------------------------------------------------------------
--Config
-------------------------------------------------------------------------------------
local scale = 1.0
local relpoint = "BOTTOMRIGHT"
local point = "BOTTOMRIGHT"
local xpoint = -10
local ypoint = 215
local cursor = false
local playerTitles = false
local texture = "Interface\\AddOns\\FreebTip\\media\\texture" --Health Bar
local backdrop = {
		bgFile = "Interface\\AddOns\\FreebTip\\media\\backdrop",
		--bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\AddOns\\FreebTip\\media\\border",
		--edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tileSize = 16,
		edgeSize = 14,
		insets = {left = -1, right = -1, top = -1, bottom = -1},
}
local bdcR, bdcG, bdcB = .15, .15, .15	--Background color
local bdbcR, bdbcG, bdbcB = 1, 1, 1	--Border color
local gColorR, gColorG, gColorB = 0, .4, .9	--Guild Color
local TARGET = "|cfffed100"..TARGET..":|r "
local TARGETYOU = "|cffff0000YOU!!!|r"
local worldBoss = "??"
local rareElite = "Rare+"
local rare = "Rare"
-------------------------------------------------------------------------------------
--End Config
-------------------------------------------------------------------------------------

local UPDATE_INTERVAL = 0.2

local function GetHexColor(color)
	return ("|cff%.2x%.2x%.2x"):format(color.r * 255, color.g * 255, color.b * 255)
end

local ClassColors = {}
for class, color in pairs(RAID_CLASS_COLORS) do
	ClassColors[class] = GetHexColor(RAID_CLASS_COLORS[class])
end

local Reaction = {}
for i = 1, #FACTION_BAR_COLORS do
	Reaction[i] = GetHexColor(FACTION_BAR_COLORS[i])
end

local function getTargetLine(unit)
	if UnitIsUnit(unit, "player") then
		return ("|cffffffff%s|r"):format(TARGETYOU)
	elseif UnitIsPlayer(unit, "player")then
		return ClassColors[select(2, UnitClass(unit, "player"))]..UnitName(unit).."|r"
	elseif UnitReaction(unit, "player") then
		return ("%s%s|r"):format(Reaction[UnitReaction(unit, "player")], UnitName(unit))
	else
		return ("|cffffffff%s|r"):format(UnitName(unit))
	end
end

local function ShowTargets(GameTooltip, unit)
	if UnitExists(unit) and UnitExists(unit.."target") then
		local lines = GameTooltip:NumLines()
		for i = 1, lines do
			local line = _G["GameTooltipTextLeft"..i]
			local text = ("%s%s"):format(TARGET, getTargetLine(unit.."target"))
			if line:GetText() and line:GetText():find(TARGET) then
				line:SetText(text)
				if not GameTooltip:IsVisible() or lastTarget ~= UnitName(unit.."target") then GameTooltip:Show() end
				break
			elseif i == lines then
				lastTarget = UnitName(unit.."target")
				GameTooltip:AddLine(text)
				GameTooltip:Show()
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function(self, elapsed)
	if not self.lastUpdate then
		self.lastUpdate = 0 
	end
	self.lastUpdate = self.lastUpdate + elapsed
	if self.lastUpdate > UPDATE_INTERVAL then
		local unit = select(2, GameTooltip:GetUnit())
		if unit then
			ShowTargets(GameTooltip, unit)
		end
	end
end)

function GameTooltip_UnitColor(unit)
	local r, g, b
	local reaction = UnitReaction(unit, "player")
	if reaction then
		r = FACTION_BAR_COLORS[reaction].r
		g = FACTION_BAR_COLORS[reaction].g
		b = FACTION_BAR_COLORS[reaction].b
	else
		r = 1.0
		g = 1.0
		b = 1.0
	end
	if UnitPlayerControlled(unit) then
		if UnitCanAttack(unit, "player") then
			if not UnitCanAttack("player", unit) then
				r = 1.0
				g = 1.0
				b = 1.0
			else
				r = FACTION_BAR_COLORS[2].r
				g = FACTION_BAR_COLORS[2].g
				b = FACTION_BAR_COLORS[2].b
			end
		elseif UnitCanAttack("player", unit) then
			r = FACTION_BAR_COLORS[4].r
			g = FACTION_BAR_COLORS[4].g
			b = FACTION_BAR_COLORS[4].b
		elseif UnitIsPVP(unit) then
			r = FACTION_BAR_COLORS[6].r
			g = FACTION_BAR_COLORS[6].g
			b = FACTION_BAR_COLORS[6].b
		end
	end
	if UnitIsPlayer(unit) then
		local class = select(2, UnitClass(unit))
		if class then
			r = RAID_CLASS_COLORS[class].r
			g = RAID_CLASS_COLORS[class].g
			b = RAID_CLASS_COLORS[class].b
		end
	end
	return r, g, b
end


GameTooltip:HookScript("OnTooltipSetUnit", function(self)
local unit = select(2, self:GetUnit())
  if unit then
	local level = UnitLevel(unit)
	local color = GetDifficultyColor(level)
	local textLevel = ("%s%d|r"):format(GetHexColor(color), level)
	local unitPvP = ""
	local pattern = "%s"
	if level == "??" or level == -1 then
		textLevel = "|cffff0000??|r"
	end
	
	if UnitIsPlayer(unit) then
			local unitRace = UnitRace(unit)
			local unitClass = UnitClass(unit)
			
			if UnitIsAFK(unit) then
				self:AppendText((" |cff00cc00%s|r"):format(CHAT_FLAG_AFK))
			elseif UnitIsDND(unit) then 
				self:AppendText((" |cff00cc00%s|r"):format(CHAT_FLAG_DND))
			end
			
			for i = 2, GameTooltip:NumLines() do
				if _G["GameTooltipTextLeft"..i]:GetText():find(LEVEL) then
					pattern = pattern.." %s %s %s"
					_G["GameTooltipTextLeft"..i]:SetText((pattern):format(unitPvP, textLevel, unitRace, unitClass):trim())
					break
				end
			end
			
			local unitGuild = GetGuildInfo(unit)
			local text = GameTooltipTextLeft2:GetText()
			if unitGuild and text and text:find("^"..unitGuild) then	
				GameTooltipTextLeft2:SetTextColor(gColorR, gColorG, gColorB)
			end
		else
			local text = GameTooltipTextLeft2:GetText()
			local reaction = UnitReaction(unit, "player")
			if reaction and text and not text:find(LEVEL) then
				GameTooltipTextLeft2:SetTextColor(FACTION_BAR_COLORS[reaction].r + .1, FACTION_BAR_COLORS[reaction].g + .1, FACTION_BAR_COLORS[reaction].b + .1)
			end
			if level ~= 0 then
				
					local class = UnitClassification(unit)
					if class == "worldboss" then
						textLevel = ("|cffff0000%s|r"):format(worldBoss)
					elseif class == "rareelite" then
						if level == -1 then
							textLevel = ("|cffff0000??+|r %s"):format(rareElite)
						else
							textLevel = ("%s%d+|r %s"):format(GetHexColor(color), level, rareElite)
						end
					elseif class == "elite" then
						if level == -1 then
							textLevel = "|cffff0000??+|r"
						else
							textLevel = ("%s%d+|r"):format(GetHexColor(color), level)
						end
					elseif class == "rare" then
						if level == -1 then
							textLevel = ("|cffff0000??+|r %s"):format(rare)
						else
							textLevel = ("%s%d|r %s"):format(GetHexColor(color), level, rare)
						end
					end
				
				local creatureType = UnitCreatureType(unit)
				for i = 2, GameTooltip:NumLines() do
					if _G["GameTooltipTextLeft"..i]:GetText():find(LEVEL) then
						pattern = pattern.." %s %s"
						_G["GameTooltipTextLeft"..i]:SetText((pattern):format(unitPvP, textLevel, creatureType or ""):trim())
						break
					end
				end
			end
		end
  end
end)

local function ShortValue(value)
	if value >= 1e7 then
		return ('%.1fm'):format(value / 1e6):gsub('%.?0+([km])$', '%1')
	elseif value >= 1e6 then
		return ('%.2fm'):format(value / 1e6):gsub('%.?0+([km])$', '%1')
	elseif value >= 1e5 then
		return ('%.0fk'):format(value / 1e3)
	elseif value >= 1e3 then
		return ('%.1fk'):format(value / 1e3):gsub('%.?0+([km])$', '%1')
	else
		return value
	end
end

GameTooltipStatusBar:SetScript("OnValueChanged", function(self, value)
	if not value then
		return
	end
	local min, max = self:GetMinMaxValues()
	if (value < min) or (value > max) then
		return
	end
	local unit  = select(2, GameTooltip:GetUnit())
	if unit then
		self:SetStatusBarColor(0, .9, .1)
		min, max = UnitHealth(unit), UnitHealthMax(unit)
		if not self.text then
			self.text = self:CreateFontString(nil, "OVERLAY")
			self.text:SetPoint("CENTER", GameTooltipStatusBar, 0, -1)
			self.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
		end
		self.text:Show()
		local hp = ShortValue(min).." / "..ShortValue(max)
		self.text:SetText(hp)
	end
end)
GameTooltipStatusBar:SetStatusBarTexture(texture)
GameTooltipStatusBar:SetHeight(7)

local Tooltips = {GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3}
for i, v in ipairs(Tooltips) do
	v:SetBackdrop(backdrop)
	v:SetScale(scale)
	v:SetScript("OnShow", function(self)
		self:SetBackdropColor(bdcR, bdcG, bdcB)
		local name, item = self:GetItem()
		if(item) then
			local quality = select(3, GetItemInfo(item))
			if(quality) then
				local r, g, b = GetItemQualityColor(quality)
				self:SetBackdropBorderColor(r, g, b)
			end
		else
			self:SetBackdropBorderColor(bdbcR, bdbcG, bdbcB)
		end
	end)
end

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
	local frame = GetMouseFocus()
	if cursor and frame == WorldFrame then
		tooltip:SetOwner(parent, "ANCHOR_CURSOR")
	else
		tooltip:SetOwner(parent, "ANCHOR_NONE")	
		tooltip:SetPoint(point, UIParent, relpoint, xpoint, ypoint)
	end
	tooltip.default = 1
end)

if playerTitles then return end
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
	local unitName, unit = self:GetUnit()
	if unit and UnitIsPlayer(unit) then
		local title = UnitPVPName(unit)
		if title then
			title = title:gsub(unitName, "")
			name = GameTooltipTextLeft1:GetText()
			name = name:gsub(title, "")
			if name then GameTooltipTextLeft1:SetText(name) end
		end
	end
end)
