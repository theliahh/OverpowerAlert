local ADDON_NAME, ns = ...
local L = ns.L -- all text lives in Strings.lua

-- On-screen alerts: a text and a spell icon for each ability. Each can be
-- unlocked and dragged anywhere; positions are saved in the ability's
-- textPos / iconPos.

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- The text and icon show for at least HOLD seconds, then for as long as the
-- ability's opening lasts (ns.IsActive). Previews with no opening just show
-- for HOLD.
local HOLD, FADE = 1.2, 0.15
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local KINDS = { "text", "icon" }

ns.GLOW_STYLES = {
    { value = "none",     label = L.GLOW_NONE },
    { value = "proc",     label = L.GLOW_PROC },
    { value = "button",   label = L.GLOW_BUTTON },
    { value = "pixel",    label = L.GLOW_PIXEL },
    { value = "autocast", label = L.GLOW_AUTOCAST },
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

-- Countdown of the seconds left in the opening, to one decimal place. Shown
-- on the icon, or beside the text when the icon is turned off.
-- Previews (/opa test, Preview) have no real opening; they count down from
-- the ability's duration.

local function CountdownWanted(el)
    local cfg = ns.Config(el.abilityKey)
    if not cfg.showCountdown or ns.ABILITY_BY_KEY[el.abilityKey].untimed then return false end
    return el.kind == "icon" or not cfg.showIcon
end

local function UpdateCountdown(el)
    local fs = el.countdown
    if not CountdownWanted(el) then
        fs:Hide()
        return
    end
    -- Keep the last number while fading out.
    if el.fading then return end
    local remaining
    if el.unlocked then
        remaining = ns.Duration(el.abilityKey)
    else
        remaining = ns.GetRemaining(el.abilityKey)
        if not remaining then
            -- No opening: a preview counts down from when it showed; a real
            -- alert whose opening just ended stays at 0.
            remaining = el.isPreview and (el.shownAt + ns.Duration(el.abilityKey) - GetTime()) or 0
        end
    end
    fs:SetFormattedText("%.1f", math.max(remaining, 0))
    fs:Show()
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
    hint:SetText((kind == "text" and L.MOVE_TEXT_HINT or L.MOVE_ICON_HINT):format(ability.name))
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
        if el.onUpdate then el.onUpdate() end
        if el.countdown then UpdateCountdown(el) end
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
    -- Setting mouse scripts turns the mouse on; keep alerts click-through
    -- (camera turning, clicking the world) until unlocked to move.
    f:EnableMouse(false)

    elements[ability.key] = elements[ability.key] or {}
    elements[ability.key][kind] = el
    return el
end

local function ShowElement(el)
    if not el or el.unlocked then return end
    el.fade:Stop()
    el.fading = false
    el.shownAt = GetTime()
    el.isPreview = ns.GetRemaining(el.abilityKey) == nil
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
    el.countdown:SetFont(FONT, size, "THICKOUTLINE")
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

-- Optionally the icon sits on the target's nameplate instead of its fixed
-- position. With no nameplate to use (nameplates off, target out of range or
-- off-screen) it falls back to the fixed position, or hides if the fallback is
-- off. Checked every frame while the icon is up, so it follows target changes
-- and nameplates coming and going.
-- The icon's facing edge sits on the chosen side of the plate, then moves by
-- the X/Y offset (so two abilities on the same side can sit apart).
local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }

-- The nameplate the icon belongs on: the target's, except that Overpower's
-- stays with the mob that dodged when the player changes target, since
-- Overpower only works on that mob.
local function AbilityNameplate(abilityKey)
    local plate
    if abilityKey == "overpower" and ns.OverpowerNameplate then
        plate = ns.OverpowerNameplate()
        if plate == false then return nil end -- that mob has no nameplate now
    end
    if not plate then
        if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
        local ok, found = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        if not ok or type(found) ~= "table" then return nil end
        plate = found
    end
    -- Some nameplates (friendly ones in instances) can't be touched by addons.
    if plate.IsForbidden and plate:IsForbidden() then return nil end
    return plate
end

local function PlaceIcon(el)
    local cfg = ns.Config(el.abilityKey)
    local plate = cfg.iconOnNameplate and not el.unlocked and AbilityNameplate(el.abilityKey) or nil
    local side = OPPOSITE[cfg.nameplateSide] and cfg.nameplateSide or "TOP"
    local x, y = tonumber(cfg.nameplateX) or 0, tonumber(cfg.nameplateY) or 0
    local mode
    if plate then
        mode = "plate"
    elseif cfg.iconOnNameplate and not el.unlocked and not cfg.nameplateFallback then
        mode = "hidden"
    else
        mode = "fixed"
    end
    -- Only move the frame when something changed.
    local key = mode .. tostring(plate) .. side .. x .. "," .. y
    if key == el.placedKey then return end
    el.placedKey = key

    if mode == "plate" then
        el.frame:ClearAllPoints()
        el.frame:SetPoint(OPPOSITE[side], plate, side, x, y)
    elseif mode == "fixed" then
        ApplyPosition(el)
    end
    el.body:SetShown(mode ~= "hidden")
end

-- With "alert even while on cooldown", the icon looks like an action button
-- on cooldown until it comes off: greyed out, a swipe for the time left, and
-- no glow. Checked a few times a second while the icon is up.
local COOLDOWN_CHECK = 0.1

-- Starts the swipe from the game's cooldown. In combat the start and duration
-- can be secret, so the duration object (which the swipe can draw without us
-- reading it) comes first.
local function StartSwipe(el)
    local id = ns.GetSpellID(el.abilityKey)
    if not id then return end
    local swipe = el.swipe
    if C_Spell.GetSpellCooldownDuration and swipe.SetCooldownFromDurationObject then
        local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, id, true) -- true: not the GCD
        if ok and dur and pcall(swipe.SetCooldownFromDurationObject, swipe, dur) then return end
    end
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if ok and type(info) == "table" then
        pcall(swipe.SetCooldown, swipe, info.startTime, info.duration)
    end
end

local function SetCoolingDown(el, cooling)
    if el.coolingDown == cooling then return end
    el.coolingDown = cooling
    el.texture:SetDesaturated(cooling)
    if cooling then
        StopGlow(el.body)
        StartSwipe(el)
    else
        el.swipe:Clear()
        if el.frame:IsShown() and not el.fading then
            StartGlow(el.body, ns.Config(el.abilityKey).iconGlow)
        end
    end
end

local function UpdateCooldownLook(el)
    local now = GetTime()
    if now < (el.nextCooldownCheck or 0) then return end
    el.nextCooldownCheck = now + COOLDOWN_CHECK
    -- Previews and moving the icon always show it ready.
    local cooling = not el.unlocked and not el.isPreview
        and ns.Config(el.abilityKey).showOnCooldown and ns.OnCooldown(el.abilityKey)
    SetCoolingDown(el, cooling and true or false)
end

function ns.ApplyIconStyle(abilityKey)
    local el = Element(abilityKey, "icon")
    if not el then return end
    local cfg = ns.Config(abilityKey)
    local size = cfg.iconSize or 64
    el.frame:SetSize(size, size)
    el.countdown:SetFont(FONT, math.max(12, math.floor(size * 0.4)), "THICKOUTLINE")
    -- Glows are sized when they start, so restart any that's showing.
    if el.frame:IsShown() and not el.coolingDown then StartGlow(el.body, cfg.iconGlow) else StopGlow(el.body) end
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
        local function isActive() return ns.IsActive(ability.key) end

        local textEl = CreateElement(ability, "text", 0, d.textY, isActive)
        local label = textEl.frame:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER")
        label:SetTextColor(unpack(ability.color))
        label:SetFont(FONT, 36, "THICKOUTLINE")
        label:SetText(ability.text)
        textEl.label = label
        local textCountdown = textEl.frame:CreateFontString(nil, "OVERLAY")
        textCountdown:SetPoint("LEFT", label, "RIGHT", 10, 0)
        textCountdown:SetTextColor(1, 1, 1)
        textCountdown:SetFont(FONT, 36, "THICKOUTLINE")
        textCountdown:Hide()
        textEl.countdown = textCountdown
        ApplyPosition(textEl)
        ns.ApplyTextStyle(ability.key)

        local iconEl = CreateElement(ability, "icon", d.iconX, d.iconY, isActive)
        local f = iconEl.frame
        -- Everything visible goes on `body`, so the icon can be hidden (no
        -- nameplate, no fallback) while the frame keeps running its timing.
        local body = CreateFrame("Frame", nil, f)
        body:SetAllPoints()
        iconEl.body = body
        local border = body:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0, 0, 0, 1)
        local texture = body:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        iconEl.texture = texture
        -- Cooldown swipe, for alerts allowed while on cooldown. Our own
        -- countdown shows the opening, so the swipe has no numbers.
        local swipe = CreateFrame("Cooldown", nil, body, "CooldownFrameTemplate")
        swipe:SetAllPoints()
        swipe:SetDrawEdge(false)
        swipe:SetHideCountdownNumbers(true)
        if swipe.SetDrawBling then swipe:SetDrawBling(false) end
        swipe:SetFrameLevel(body:GetFrameLevel() + 2)
        iconEl.swipe = swipe
        -- On its own layer above the glow, so the glow never covers the number.
        local countdownLayer = CreateFrame("Frame", nil, body)
        countdownLayer:SetAllPoints()
        countdownLayer:SetFrameLevel(body:GetFrameLevel() + 20)
        local iconCountdown = countdownLayer:CreateFontString(nil, "OVERLAY")
        iconCountdown:SetPoint("CENTER")
        iconCountdown:SetTextColor(1, 1, 1)
        iconCountdown:SetFont(FONT, 26, "THICKOUTLINE")
        iconCountdown:Hide()
        iconEl.countdown = iconCountdown
        iconEl.onShow = function()
            RefreshIconTexture(iconEl, ability)
            iconEl.placedKey = nil
            PlaceIcon(iconEl)
            iconEl.coolingDown, iconEl.nextCooldownCheck = nil, 0
            UpdateCooldownLook(iconEl)
        end
        iconEl.onUpdate = function()
            PlaceIcon(iconEl)
            UpdateCooldownLook(iconEl)
        end
        f:HookScript("OnHide", function()
            StopGlow(body)
            SetCoolingDown(iconEl, false)
        end)
        ApplyPosition(iconEl)
        ns.ApplyIconStyle(ability.key)
    end
end

-- Fades out an ability's text and icon now, e.g. once the player has used
-- the ability. (The game still reports Revenge as usable after it's cast,
-- since usability ignores the cooldown, so the icon wouldn't drop by itself.)
function ns.HideAlert(abilityKey)
    for _, kind in ipairs(KINDS) do
        local el = Element(abilityKey, kind)
        if el and el.frame:IsShown() and not el.unlocked and not el.fading then
            StartFade(el)
        end
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
    -- The options window shares the HIGH strata and rises above us when
    -- clicked, which would catch the drag. Sit above it while unlocked.
    el.frame:SetFrameStrata(el.unlocked and "FULLSCREEN_DIALOG" or "HIGH")
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
    el.placedKey = nil -- the icon may belong on a nameplate instead
end
