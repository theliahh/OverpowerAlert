local ADDON_NAME, ns = ...

-- On-screen "OVERPOWER!" text. Unlock it to drag it anywhere; the position
-- is saved in OverpowerAlertDB.textPos.

local TEXT = "OVERPOWER!"
local HOLD, FADE = 1.2, 0.5

local frame, label, bg, fadeAnim
local unlocked = false

local function ApplyPosition()
    frame:ClearAllPoints()
    local pos = OverpowerAlertDB.textPos
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    end
end

function ns.ApplyTextStyle()
    if not frame then return end
    local size = OverpowerAlertDB.textSize or 36
    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    label:SetFont(fontPath, size, "THICKOUTLINE")
    frame:SetSize(math.max(label:GetStringWidth(), size * 5) + 20, size + 16)
end

function ns.InitDisplay()
    frame = CreateFrame("Frame", "OverpowerAlertTextFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    -- We save the position ourselves; keep the client's layout cache out of it.
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.5, 1, 0.35)
    bg:Hide()

    label = frame:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER")
    label:SetTextColor(1, 0.4, 0.1)
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 36, "THICKOUTLINE")
    label:SetText(TEXT)

    fadeAnim = frame:CreateAnimationGroup()
    local alpha = fadeAnim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetStartDelay(HOLD)
    alpha:SetDuration(FADE)
    fadeAnim:SetScript("OnFinished", function()
        if not unlocked then frame:Hide() end
    end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    hint:SetText("Drag to move - right-click to lock")
    hint:Hide()
    frame.hint = hint

    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.SetTextUnlocked(false) end
    end)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        OverpowerAlertDB.textPos = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
    end)

    ApplyPosition()
    ns.ApplyTextStyle()
end

function ns.ShowText()
    if not frame or unlocked then return end
    fadeAnim:Stop()
    frame:SetAlpha(1)
    frame:Show()
    fadeAnim:Play()
end

function ns.IsTextUnlocked()
    return unlocked
end

function ns.SetTextUnlocked(value)
    if not frame then return end
    unlocked = value and true or false
    fadeAnim:Stop()
    frame:EnableMouse(unlocked)
    bg:SetShown(unlocked)
    frame.hint:SetShown(unlocked)
    frame:SetAlpha(1)
    frame:SetShown(unlocked)
    if ns.OnUnlockChanged then ns.OnUnlockChanged(unlocked) end
end

function ns.ResetTextPosition()
    OverpowerAlertDB.textPos = nil
    if frame then ApplyPosition() end
end
