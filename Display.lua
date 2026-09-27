local ADDON_NAME, ns = ...

-- On-screen alerts: the "OVERPOWER!" text and the Overpower spell icon.
-- Each can be unlocked and dragged anywhere; positions are saved in
-- OverpowerAlertDB.textPos / iconPos.

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local TEXT = "OVERPOWER!"
local HOLD, FADE = 1.2, 0.5
-- Overpower stays usable for up to 5 seconds after a dodge; the icon stays
-- up while it's usable, capped at this.
local ICON_MAX_HOLD = 5
local DEFAULT_ICON = "Interface\\Icons\\Ability_MeleeDamage"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

ns.GLOW_STYLES = {
    { value = "none",     label = "None" },
    { value = "proc",     label = "Proc Glow" },
    { value = "button",   label = "Action Button Glow" },
    { value = "pixel",    label = "Pixel Glow" },
    { value = "autocast", label = "Autocast Shine" },
}

local elements = {}

--------------------------------------------------------------------------------
-- Movable element shared by the text and the icon
--------------------------------------------------------------------------------

local function ApplyPosition(el)
    local f = el.frame
    f:ClearAllPoints()
    local pos = OverpowerAlertDB[el.posKey]
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", el.defaultX, el.defaultY)
    end
end

local function StartFade(el)
    el.fading = true
    el.fade:Play()
end

local function CreateElement(which, frameName, posKey, defaultY, holdWhile)
    local f = CreateFrame("Frame", frameName, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    -- We save the position ourselves; keep the client's layout cache out of it.
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f:RegisterForDrag("LeftButton")
    f:Hide()

    local el = {
        which = which, frame = f, posKey = posKey,
        defaultX = 0, defaultY = defaultY,
        holdWhile = holdWhile, unlocked = false, shownAt = 0,
    }

    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", -6, 6)
    bg:SetPoint("BOTTOMRIGHT", 6, -6)
    bg:SetColorTexture(0, 0.5, 1, 0.35)
    bg:Hide()
    el.bg = bg

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", f, "BOTTOM", 0, -8)
    hint:SetText("Drag to move - right-click to lock")
    hint:Hide()
    el.hint = hint

    el.fade = f:CreateAnimationGroup()
    local alpha = el.fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(FADE)
    el.fade:SetScript("OnFinished", function()
        el.fading = false
        if not el.unlocked then f:Hide() end
    end)

    -- Hold for at least HOLD seconds, then for as long as holdWhile() says.
    f:SetScript("OnUpdate", function()
        if el.unlocked or el.fading then return end
        local t = GetTime() - el.shownAt
        if t >= HOLD and not (el.holdWhile and el.holdWhile(t)) then
            StartFade(el)
        end
    end)

    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.SetUnlocked(which, false) end
    end)
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        OverpowerAlertDB[posKey] = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
    end)

    elements[which] = el
    return el
end

local function ShowElement(el)
    if not el or el.unlocked then return end
    el.fade:Stop()
    el.fading = false
    el.shownAt = GetTime()
    el.frame:SetAlpha(1)
    el.frame:Show()
    if el.onShow then el.onShow() end
end

--------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------

local label

function ns.ApplyTextStyle()
    local el = elements.text
    if not el then return end
    local size = OverpowerAlertDB.textSize or 36
    label:SetFont(FONT, size, "THICKOUTLINE")
    el.frame:SetSize(math.max(label:GetStringWidth(), size * 5) + 20, size + 16)
end

function ns.ShowText()
    ShowElement(elements.text)
end

--------------------------------------------------------------------------------
-- Icon
--------------------------------------------------------------------------------

local icon

local function StopGlow(f)
    if not LCG then return end
    LCG.ProcGlow_Stop(f)
    LCG.ButtonGlow_Stop(f)
    LCG.PixelGlow_Stop(f)
    LCG.AutoCastGlow_Stop(f)
end

local function StartGlow(f)
    StopGlow(f)
    if not LCG then return end
    local style = OverpowerAlertDB.iconGlow
    if style == "proc" then
        LCG.ProcGlow_Start(f, { startAnim = true })
    elseif style == "button" then
        LCG.ButtonGlow_Start(f)
    elseif style == "pixel" then
        LCG.PixelGlow_Start(f, nil, 8, 0.25, nil, 3)
    elseif style == "autocast" then
        LCG.AutoCastGlow_Start(f, nil, 4, 0.125, 1.5)
    end
end

local function RefreshIconTexture()
    local id = ns.GetOverpowerID and ns.GetOverpowerID() or 7384
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        or (GetSpellTexture and GetSpellTexture(id))
    icon:SetTexture(tex or DEFAULT_ICON)
end

function ns.ApplyIconStyle()
    local el = elements.icon
    if not el then return end
    local size = OverpowerAlertDB.iconSize or 64
    el.frame:SetSize(size, size)
    -- Glows are sized when they start, so restart any that's showing.
    if el.frame:IsShown() then StartGlow(el.frame) else StopGlow(el.frame) end
end

function ns.ShowIcon()
    ShowElement(elements.icon)
end

--------------------------------------------------------------------------------
-- Setup and shared controls
--------------------------------------------------------------------------------

function ns.InitDisplay()
    local textEl = CreateElement("text", "OverpowerAlertTextFrame", "textPos", 180)
    label = textEl.frame:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER")
    label:SetTextColor(1, 0.4, 0.1)
    label:SetFont(FONT, 36, "THICKOUTLINE")
    label:SetText(TEXT)
    ApplyPosition(textEl)
    ns.ApplyTextStyle()

    local iconEl = CreateElement("icon", "OverpowerAlertIconFrame", "iconPos", 100, function(t)
        return t < ICON_MAX_HOLD and ns.IsOverpowerUsable and ns.IsOverpowerUsable()
    end)
    local f = iconEl.frame
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconEl.onShow = function()
        RefreshIconTexture()
        StartGlow(f)
    end
    f:HookScript("OnHide", StopGlow)
    ApplyPosition(iconEl)
    ns.ApplyIconStyle()
end

function ns.IsUnlocked(which)
    return elements[which] ~= nil and elements[which].unlocked
end

-- which = "text", "icon", or nil for both.
function ns.SetUnlocked(which, value)
    if not which then
        for w in pairs(elements) do ns.SetUnlocked(w, value) end
        return
    end
    local el = elements[which]
    if not el then return end
    el.unlocked = value and true or false
    el.fade:Stop()
    el.fading = false
    el.frame:EnableMouse(el.unlocked)
    el.bg:SetShown(el.unlocked)
    el.hint:SetShown(el.unlocked)
    el.frame:SetAlpha(1)
    el.frame:SetShown(el.unlocked)
    if el.unlocked and el.onShow then el.onShow() end
    if ns.OnUnlockChanged then ns.OnUnlockChanged(which, el.unlocked) end
end

function ns.ResetPosition(which)
    local el = elements[which]
    if not el then return end
    OverpowerAlertDB[el.posKey] = nil
    ApplyPosition(el)
end
