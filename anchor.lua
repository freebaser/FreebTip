local ADDON_NAME, ns = ...

local setframe
do
	local OnDragStart = function(self)
		self:StartMoving()
	end

	local OnDragStop = function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(true)

		local point = self:GetPoint()

		if point == "CENTER" then
			point = "BOTTOMRIGHT"
		end

		local tooltip = _G["GameTooltip"]
		tooltip:ClearAllPoints()
		tooltip:SetPoint(point, _anchor, point)
	end

	setframe = function(frame)
		frame:SetHeight(15)
		frame:SetWidth(80)
		frame:SetFrameStrata"TOOLTIP"
		frame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background";})
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
		frame:RegisterForDrag"LeftButton"
		frame:SetBackdropBorderColor(0, .9, 0)
		frame:SetBackdropColor(0, .9, 0)
		frame:Hide()

		frame:SetScript("OnDragStart", OnDragStart)
		frame:SetScript("OnDragStop", OnDragStop)
		frame:SetScript("OnHide", OnDragStop)

		frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.text:SetPoint"CENTER"
		frame.text:SetJustifyH"CENTER"
		frame.text:SetFont(GameFontNormal:GetFont(), 12)
		frame.text:SetTextColor(1, 1, 1)

		return frame
	end
end

local _anchor = CreateFrame("Frame", "FreebTip_Anchor", UIParent)
setframe(_anchor)
_anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -25, 200)
_anchor.text:SetText("FreebTip")

local _LOCK
SLASH_FREEBTIP1 = "/freebtip"
SlashCmdList["FREEBTIP"] = function(inp)
	if not _LOCK then
		_anchor:Show()
		_LOCK = true
	else
		_anchor:Hide()
		_LOCK = nil
	end
end

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
	local frame = GetMouseFocus()
	if ns.cfg.cursor and frame == WorldFrame then
		tooltip:SetOwner(parent, "ANCHOR_CURSOR")
	else
		local point = _anchor:GetPoint()

		if point == "CENTER" then
			point = "BOTTOMRIGHT"
		end

		tooltip:SetOwner(parent, "ANCHOR_NONE")
		tooltip:SetPoint(point, _anchor, point)
	end
	tooltip.default = 1
end)

