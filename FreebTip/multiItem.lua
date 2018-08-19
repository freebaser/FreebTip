local ADDON_NAME, ns = ...

local tips = { [1] = _G["ItemRefTooltip"] }

local types = {
	item = true,
	spell = true,
	quest = true,
	talent = true,
	enchant = true,
	achievement = true,
	instancelock = true,
}

local function CreateTip(link)
	-- Use existing tip
	for k, v in ipairs(tips) do
		-- Hide if tip is already shown
		for i, tip in ipairs(tips) do
			if(tip:IsShown() and tip.link == link) then
				tip.link = nil
				HideUIPanel(tip)
				return
			end
		end

		if(not v:IsShown()) then
			v.link = link
			return v
		end
	end

	-- Create new tip
	local num = #tips+1
	local tip = CreateFrame("GameTooltip", "ItemRefTooltip"..num, UIParent, "GameTooltipTemplate")
	tip:SetPoint("BOTTOM", 0, 80)
	tip:SetFrameStrata"TOOLTIP"
	tip:SetSize(128,64)
	tip:SetPadding(16, 0)
	tip:EnableMouse(true)
	tip:SetMovable(true)
	tip:SetToplevel(true)

	tip:SetScript("OnShow", function(self) ns.style(self) end)
	tip:SetScript("OnDragStart", function(self) self:StartMoving() end)
	tip:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	tip:RegisterForDrag("LeftButton")

	tip.CloseButton = CreateFrame("Button", nil, tip)
	tip.CloseButton:SetPoint("TOPRIGHT", 1, 0)
	tip.CloseButton:SetSize(32,32)
	tip.CloseButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	tip.CloseButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	tip.CloseButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	tip.CloseButton:SetScript("OnClick", function(self) HideUIPanel(self:GetParent()) end)

	table.insert(UISpecialFrames, tip:GetName())

	if(IDCard) then IDCard:RegisterTooltip(tip) end

	tip.link = link
	tips[num] = tip

	return tip
end

local function ShowTip(tip, link)
	ns.Debug("Show tip", tip, link)
	ShowUIPanel(tip)
	if not (tip:IsShown()) then
		tip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	end
	tip:SetHyperlink(link)
end

local _SetItemRef = SetItemRef
function SetItemRef(...)
	local link, text, button = ...
	local handled = strsplit(":", link)
	ns.Debug("link - "..link.. " - text "..text.." - button "..button)
	ns.Debug(handled)

	if((not IsModifiedClick()) and handled and types[handled]) then
		local tip = CreateTip(link)
		if(tip) then
			ShowTip(tip, link)
		end
	else
		return _SetItemRef(...)
	end
end
