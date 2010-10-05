local mediapath = "Interface\\AddOns\\FreebTip\\media\\"
local cfg = {
    font = mediapath.."expressway.ttf",
    fontsize = 13,
    outline = "OUTLINE",
    scale = 1.0,
    point = { "BOTTOMRIGHT", "BOTTOMRIGHT", -10, 215 },
    cursor = false,
    titles = false,
    tex = mediapath.."texture",
    backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
    bgcolor = { r=0.05, g=0.05, b=0.05, t=0.9 },
    bdrcolor = { r=0.3, g=0.3, b=0.3 },
    gcolor = { r=1, g=0.1, b=0.8 },
    you = "<You>",
}

local classification = {
    elite = "+|r",
    worldboss = "??|r",
    rare = "R|r",
    rareelite = "R+|r",
}

local hex
do 
    local format = string.format

    hex = function(color)
        return format('|cff%02x%02x%02x', color.r * 255, color.g * 255, color.b * 255)
    end
end

local function unitColor(unit)
    local color = { r=1, g=1, b=1 }
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        color = RAID_CLASS_COLORS[class]
        return color
    else
        local reaction = UnitReaction(unit, "player")
        if reaction then
            color = FACTION_BAR_COLORS[reaction]
            return color
        end
    end
    return color
end

function GameTooltip_UnitColor(unit)
    local color = unitColor(unit)
    return color.r, color.g, color.b
end

local function getTarget(unit)
    if UnitIsUnit(unit, "player") then
        return ("|cffff0000%s|r"):format(cfg.you)
    else
        return hex(unitColor(unit))..UnitName(unit).."|r"
    end
end

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local name, unit = self:GetUnit()
    if not unit then return end

    local color = unitColor(unit)

    if UnitIsPlayer(unit) then
        self:AppendText((" |cff00cc00%s|r"):format(UnitIsAFK(unit) and CHAT_FLAG_AFK or UnitIsDND(unit) and CHAT_FLAG_DND or not UnitIsConnected(unit) and "<DC>" or ""))

        local text = GameTooltipTextLeft1:GetText()
        if not cfg.titles then
            local title = UnitPVPName(unit)
            if title then
                title = title:gsub(name, "")
                text = text:gsub(title, "")
                if text then GameTooltipTextLeft1:SetText(text) end
            end
        end

        local unitGuild = GetGuildInfo(unit)
        local text2 = GameTooltipTextLeft2:GetText()
        if unitGuild and text2 and text2:find("^"..unitGuild) then	
            GameTooltipTextLeft2:SetTextColor(cfg.gcolor.r, cfg.gcolor.g, cfg.gcolor.b)
        end
    end

    local level = UnitLevel(unit)
    if level then
        local unitClass = UnitIsPlayer(unit) and hex(color)..UnitClass(unit).."|r" or ""
        local creature = not UnitIsPlayer(unit) and UnitCreatureType(unit) or ""
        local diff = GetQuestDifficultyColor(level)

        if level == -1 then level = "|cffff0000" end
        local textLevel = ("%s%s%s|r"):format(hex(diff), tostring(level), classification[UnitClassification(unit)] or "")

        for i=2, self:NumLines() do
            local tiptext = _G["GameTooltipTextLeft"..i]
            if tiptext:GetText():find(LEVEL) then
                tiptext:SetText(("%s %s%s %s"):format(textLevel, creature, UnitRace(unit) or "", unitClass):trim())
            end

            if tiptext:GetText():find(PVP) then
                tiptext:SetText(nil)
            end
        end
    end

    if UnitExists(unit.."target") then
        local tartext = ("%s: %s"):format(TARGET, getTarget(unit.."target"))
        self:AddLine(tartext)
    end

    GameTooltipStatusBar:SetStatusBarColor(color.r, color.g, color.b)

    if UnitIsDeadOrGhost(unit) then
        GameTooltipStatusBar:Hide()
    else
        self:AddLine(" ")
        GameTooltipStatusBar:ClearAllPoints()
        GameTooltipStatusBar:SetPoint("TOPLEFT", self:GetName().."TextLeft"..self:NumLines(), "TOPLEFT", 0, -4)
        GameTooltipStatusBar:SetPoint("TOPRIGHT", self, -10, 0)
    end
end)

GameTooltipStatusBar:SetStatusBarTexture(cfg.tex)
local bg = GameTooltipStatusBar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(GameTooltipStatusBar)
bg:SetTexture(cfg.tex)
bg:SetVertexColor(0.5, 0.5, 0.5, 0.5)

local numberize = function(val)
    if (val >= 1e6) then
        return ("%.1fm"):format(val / 1e6)
    elseif (val >= 1e3) then
        return ("%.1fk"):format(val / 1e3)
    else
        return ("%d"):format(val)
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
    local _, unit = GameTooltip:GetUnit()
    if unit then
        min, max = UnitHealth(unit), UnitHealthMax(unit)
        if not self.text then
            self.text = self:CreateFontString(nil, "OVERLAY")
            self.text:SetPoint("CENTER", GameTooltipStatusBar)
            self.text:SetFont(cfg.font, 12, cfg.outline)
        end
        self.text:Show()
        local hp = numberize(min).." / "..numberize(max)
        self.text:SetText(hp)
    end
end)

local tooltips = {
    GameTooltip, 
    ItemRefTooltip, 
    ShoppingTooltip1, 
    ShoppingTooltip2, 
    ShoppingTooltip3,
}

for i, v in ipairs(tooltips) do
    v:SetBackdrop(cfg.backdrop)
    v:SetScale(cfg.scale)
    v:SetScript("OnShow", function(self)
        self:SetBackdropColor(cfg.bgcolor.r, cfg.bgcolor.g, cfg.bgcolor.b, cfg.bgcolor.t)
        local name, item = self:GetItem()
        if(item) then
            local quality = select(3, GetItemInfo(item))
            if(quality) then
                local r, g, b = GetItemQualityColor(quality)
                self:SetBackdropBorderColor(r, g, b)
            end
        else
            self:SetBackdropBorderColor(cfg.bdrcolor.r, cfg.bdrcolor.g, cfg.bdrcolor.b)
        end

        for index=1, self:NumLines() do
            _G[self:GetName()..'TextLeft'..index]:SetFont(cfg.font, cfg.fontsize, cfg.outline)
            _G[self:GetName()..'TextRight'..index]:SetFont(cfg.font, cfg.fontsize, cfg.outline)
        end
    end)
end

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
    local frame = GetMouseFocus()
    if cfg.cursor and frame == WorldFrame then
        tooltip:SetOwner(parent, "ANCHOR_CURSOR")
    else
        tooltip:SetOwner(parent, "ANCHOR_NONE")	
        tooltip:SetPoint(cfg.point[1], UIParent, cfg.point[2], cfg.point[3], cfg.point[4])
    end
    tooltip.default = 1
end)
