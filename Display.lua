local ADDON_NAME, ns = ...

-- On-screen alerts: a text and a spell icon for each ability. Each can be
-- unlocked and dragged anywhere; positions are saved in the ability's
-- textPos / iconPos.

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local HOLD, FADE = 1.2, 0.5
-- Overpower and Revenge stay usable for up to 5 seconds after the trigger;
-- the icon stays up while the ability is usable, capped at this.
local ICON_MAX_HOLD = 5
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local KINDS = { "text", "icon" }

ns.GLOW_STYLES = {
    { value = "none",     label = "None" },
    { value = "proc",     label = "Proc Glow" },
    { value = "button",   label = "Action Button Glow" },
    { value = "pixel",    label = "Pixel Glow" },
    { value = "autocast", label = "Autocast Shine" },
}

local elements = {} -- [abilityKey][kind] = element

local function Element(abilityKey, kind)
    return elements[abilityKey] and elements[abilityKey][kind]
end

--------------------------------------------------------------------------------
-- Movable element shared by the texts and icons
--------------------------------------------------------------------------------

local function ApplyPosition(el)
    local f = el.frame
    f:ClearAllPoints()
    local pos = ns.Config(el.abilityKey)[el.kind .. "Pos"]
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

local function CreateElement(ability, kind, defaultX, defaultY, holdWhile)
    local frameName = "OverpowerAlert" .. ability.name .. (kind == "text" and "Text" or "Icon") .. "Frame"
    local f = CreateFrame("Frame", frameName, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    -- We save the position ourselves; keep the client's layout cache out of it.
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f:RegisterForDrag("LeftButton")
    f:Hide()

    local el = {
        abilityKey = ability.key, kind = kind, frame = f,
        defaultX = defaultX, defaultY = defaultY,
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
    hint:SetText(ability.name .. " " .. kind .. ": drag to move, right-click to lock")
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
        if button == "RightButton" then ns.SetUnlocked(ability.key, kind, false) end
    end)
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        ns.Config(ability.key)[kind .. "Pos"] =
            { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
    end)

    elements[ability.key] = elements[ability.key] or {}
    elements[ability.key][kind] = el
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

function ns.ApplyTextStyle(abilityKey)
    local el = Element(abilityKey, "text")
    if not el then return end
    local size = ns.Config(abilityKey).textSize or 36
    el.label:SetFont(FONT, size, "THICKOUTLINE")
    el.frame:SetSize(math.max(el.label:GetStringWidth(), size * 5) + 20, size + 16)
end

function ns.ShowText(abilityKey)
    ShowElement(Element(abilityKey, "text"))
end

--------------------------------------------------------------------------------
-- Icon
--------------------------------------------------------------------------------

local function StopGlow(f)
    if not LCG then return end
    LCG.ProcGlow_Stop(f)
    LCG.ButtonGlow_Stop(f)
    LCG.PixelGlow_Stop(f)
    LCG.AutoCastGlow_Stop(f)
end

local function StartGlow(f, style)
    StopGlow(f)
    if not LCG then return end
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

local function RefreshIconTexture(el, ability)
    local id = ns.GetSpellID(ability.key) or ability.ids[#ability.ids]
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        or (GetSpellTexture and GetSpellTexture(id))
    el.texture:SetTexture(tex or ability.icon)
end

function ns.ApplyIconStyle(abilityKey)
    local el = Element(abilityKey, "icon")
    if not el then return end
    local cfg = ns.Config(abilityKey)
    local size = cfg.iconSize or 64
    el.frame:SetSize(size, size)
    -- Glows are sized when they start, so restart any that's showing.
    if el.frame:IsShown() then StartGlow(el.frame, cfg.iconGlow) else StopGlow(el.frame) end
end

function ns.ShowIcon(abilityKey)
    ShowElement(Element(abilityKey, "icon"))
end

--------------------------------------------------------------------------------
-- Setup and shared controls
--------------------------------------------------------------------------------

function ns.InitDisplay()
    for _, ability in ipairs(ns.ABILITIES) do
        local d = ability.defaults

        local textEl = CreateElement(ability, "text", 0, d.textY)
        local label = textEl.frame:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER")
        label:SetTextColor(unpack(ability.color))
        label:SetFont(FONT, 36, "THICKOUTLINE")
        label:SetText(ability.text)
        textEl.label = label
        ApplyPosition(textEl)
        ns.ApplyTextStyle(ability.key)

        local iconEl = CreateElement(ability, "icon", d.iconX, d.iconY, function(t)
            return t < ICON_MAX_HOLD and ns.IsActive(ability.key)
        end)
        local f = iconEl.frame
        local border = f:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0, 0, 0, 1)
        local texture = f:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        iconEl.texture = texture
        iconEl.onShow = function()
            RefreshIconTexture(iconEl, ability)
            StartGlow(f, ns.Config(ability.key).iconGlow)
        end
        f:HookScript("OnHide", StopGlow)
        ApplyPosition(iconEl)
        ns.ApplyIconStyle(ability.key)
    end
end

function ns.IsUnlocked(abilityKey, kind)
    local el = Element(abilityKey, kind)
    return el ~= nil and el.unlocked
end

-- abilityKey and kind ("text" or "icon") can each be nil to mean all.
function ns.SetUnlocked(abilityKey, kind, value)
    if not abilityKey or not kind then
        for _, ability in ipairs(ns.ABILITIES) do
            if not abilityKey or abilityKey == ability.key then
                for _, k in ipairs(KINDS) do
                    if not kind or kind == k then ns.SetUnlocked(ability.key, k, value) end
                end
            end
        end
        return
    end
    local el = Element(abilityKey, kind)
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
    if ns.OnUnlockChanged then ns.OnUnlockChanged(abilityKey, kind, el.unlocked) end
end

function ns.ResetPosition(abilityKey, kind)
    local el = Element(abilityKey, kind)
    if not el then return end
    ns.Config(abilityKey)[kind .. "Pos"] = nil
    ApplyPosition(el)
end
