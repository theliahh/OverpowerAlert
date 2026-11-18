local ADDON_NAME, ns = ...
local L = ns.L -- all text lives in Strings.lua

-- On-screen alerts: a text and a spell icon for each ability. Each can be
-- unlocked and dragged anywhere; positions are saved in the ability's
-- textPos / iconPos. The icons can instead be grouped (General tab): they
-- then sit side by side, growing from one spot that's dragged as a whole.

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- The text and icon show for at least HOLD seconds, then for as long as the
-- ability's opening lasts (ns.IsActive). Previews with no opening just show
-- for HOLD.
local HOLD, FADE = 1.2, 0.15
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

local function UpdateOneCountdown(el)
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

local function UpdateCountdown(el)
    UpdateOneCountdown(el)
    -- The icon's second copy on the nameplate shows the same number.
    local copy = el.plateCopy
    if copy then
        local fs = el.countdown
        copy.countdown:SetShown(fs:IsShown())
        if fs:IsShown() then copy.countdown:SetText(fs:GetText()) end
    end
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
    ns.SetFont(el.label, size, "THICKOUTLINE")
    ns.SetFont(el.countdown, size, "THICKOUTLINE")
    el.frame:SetSize(math.max(el.label:GetStringWidth(), size * 5) + 20, size + 16)
end

-- The font changed (General tab): restyle every text and icon.
function ns.ApplyFont()
    for _, ability in ipairs(ns.ABILITIES) do
        ns.ApplyTextStyle(ability.key)
        ns.ApplyIconStyle(ability.key)
    end
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

-- Turns the icon's glow on or off, on its nameplate copy too when that's up.
local function SetGlow(el, on)
    local style = ns.Config(el.abilityKey).iconGlow
    el.glowing = on
    if on then StartGlow(el.body, style) else StopGlow(el.body) end
    local copy = el.plateCopy
    if copy then
        if on and copy:IsShown() then StartGlow(copy, style) else StopGlow(copy) end
    end
end

local function RefreshIconTexture(el, ability)
    local id = ns.GetSpellID(ability.key) or ability.ids[#ability.ids]
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        or (GetSpellTexture and GetSpellTexture(id))
    el.texture:SetTexture(tex or ability.icon)
    if el.plateCopy then el.plateCopy.texture:SetTexture(tex or ability.icon) end
end

-- Grouped icons (General tab, "iconLayout" = "group"): every icon that's up
-- and not on a nameplate sits in one row or column, growing from the group's
-- spot the way "groupGrow" says. They're in the order they came up, so a new
-- icon goes on the end and the ones already up stay where they are. Icons
-- close up when one goes. The spot is an invisible anchor frame, saved in "groupPos"; while
-- unlocked, a highlighted handle over the whole group drags it, and every
-- enabled ability's icon shows so the layout can be seen.
local group = { unlocked = false, joined = 0 }

local function Grouped()
    return ns.General().iconLayout == "group"
end

local function ApplyGroupPosition()
    local anchor = group.anchor
    anchor:ClearAllPoints()
    local pos = ns.General().groupPos
    if pos then
        anchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end
end

-- Puts every icon in the group where it belongs. Called whenever one joins
-- or leaves, changes size, or the group's settings change.
function ns.LayoutGroup()
    local anchor = group.anchor
    if not anchor then return end
    local general = ns.General()
    local grow = ns.GROUP_GROW[general.groupGrow] or ns.GROUP_GROW.RIGHT
    local gap = tonumber(general.groupSpacing) or 0

    -- The icons in the group, oldest first. Each keeps the number it got
    -- when it joined until it leaves.
    local items, total = {}, 0
    for _, ability in ipairs(ns.ABILITIES) do
        local el = Element(ability.key, "icon")
        if el and el.inGroup and el.frame:IsShown() then
            if not el.groupJoined then
                group.joined = group.joined + 1
                el.groupJoined = group.joined
            end
            local size = el.frame:GetWidth()
            total = total + size + (#items > 0 and gap or 0)
            items[#items + 1] = { el = el, size = size }
        elseif el then
            el.groupJoined = nil
        end
    end
    table.sort(items, function(a, b) return a.el.groupJoined < b.el.groupJoined end)

    -- Each icon's centre, as a distance along the growing direction. The
    -- first icon sits on the spot; a centered group has its middle there.
    local lo, hi, across = -32, 32, 64
    if #items > 0 then
        local edge = grow.centered and -total / 2 or -items[1].size / 2
        lo, hi, across = edge, edge, 0
        for _, item in ipairs(items) do
            local centre = edge + item.size / 2
            item.el.frame:ClearAllPoints()
            item.el.frame:SetPoint("CENTER", anchor, "CENTER", grow[1] * centre, grow[2] * centre)
            edge = edge + item.size + gap
            hi = edge - gap
            across = math.max(across, item.size)
        end
    end

    -- The drag handle covers the whole group.
    local pad, half = 6, across / 2
    local x1, x2, y1, y2 = -half, half, -half, half
    if grow[1] ~= 0 then
        x1, x2 = math.min(grow[1] * lo, grow[1] * hi), math.max(grow[1] * lo, grow[1] * hi)
    else
        y1, y2 = math.min(grow[2] * lo, grow[2] * hi), math.max(grow[2] * lo, grow[2] * hi)
    end
    group.handle:ClearAllPoints()
    group.handle:SetPoint("BOTTOMLEFT", anchor, "CENTER", x1 - pad, y1 - pad)
    group.handle:SetPoint("TOPRIGHT", anchor, "CENTER", x2 + pad, y2 + pad)
end

local function SetGroupUnlocked(value)
    value = value and true or false
    if group.unlocked == value then return end
    group.unlocked = value
    group.handle:SetShown(value)
    for _, ability in ipairs(ns.ABILITIES) do
        local el = Element(ability.key, "icon")
        local cfg = ns.Config(ability.key)
        -- Show every icon that can come up, so the layout can be seen. They
        -- stay click-through: the handle underneath takes the drag.
        local show = value and cfg.enabled and cfg.showIcon
        if el and (show or el.unlocked) then
            el.unlocked = show and true or false
            el.fade:Stop()
            el.fading = false
            el.frame:SetFrameStrata(show and "FULLSCREEN_DIALOG" or "HIGH")
            el.frame:SetAlpha(1)
            el.frame:SetShown(el.unlocked)
            if show and el.onShow then el.onShow() end
        end
        if ns.OnUnlockChanged then ns.OnUnlockChanged(ability.key, "icon", value) end
    end
    if ns.OnUnlockChanged then ns.OnUnlockChanged("general", "icon", value) end
    ns.LayoutGroup()
end

local function CreateGroup()
    local anchor = CreateFrame("Frame", "OverpowerAlertIconGroupFrame", UIParent)
    anchor:SetSize(2, 2)
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    if anchor.SetDontSavePosition then anchor:SetDontSavePosition(true) end
    group.anchor = anchor

    local handle = CreateFrame("Frame", nil, anchor)
    handle:SetFrameStrata("FULLSCREEN_DIALOG")
    handle:SetFrameLevel(1) -- under the icons, which are click-through
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:Hide()
    group.handle = handle

    local bg = handle:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.5, 1, 0.35)
    local hint = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", handle, "BOTTOM", 0, -4)
    hint:SetText(L.MOVE_GROUP_HINT)

    handle:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then SetGroupUnlocked(false) end
    end)
    handle:SetScript("OnDragStart", function() anchor:StartMoving() end)
    handle:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        local point, _, relPoint, x, y = anchor:GetPoint(1)
        ns.General().groupPos = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
    end)

    ApplyGroupPosition()
    ns.LayoutGroup()
end

-- Optionally the icon sits on the target's nameplate instead of its fixed
-- position. With no nameplate to use (nameplates off, target out of range or
-- off-screen) it falls back to the fixed position, or hides if the fallback is
-- off. Checked every frame while the icon is up, so it follows target changes
-- and nameplates coming and going.
-- The icon's facing edge sits on the chosen side of the plate, then moves by
-- the X/Y offset (so two abilities on the same side can sit apart).
-- With "nameplateBoth" the icon shows in both places at once: the icon itself
-- stays at its normal position (or in the group), and a second copy of it
-- (el.plateCopy, a child frame, so it shows, fades and hides with the icon)
-- goes on the nameplate whenever there is one.
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
    local both = cfg.iconOnNameplate and cfg.nameplateBoth and not el.unlocked
    local mode
    if both then
        mode = "fixed"
    elseif plate then
        mode = "plate"
    elseif cfg.iconOnNameplate and not el.unlocked and not cfg.nameplateFallback then
        mode = "hidden"
    else
        mode = "fixed"
    end
    -- At its fixed position, it may be one of the grouped icons instead.
    local grouped = mode == "fixed" and Grouped()
    -- Only move the frame when something changed.
    local key = (grouped and "group" or mode) .. (both and "+" or "") .. tostring(plate) .. side .. x .. "," .. y
    if key == el.placedKey then return end
    el.placedKey = key

    local copy = el.plateCopy
    if both and plate then
        copy:ClearAllPoints()
        copy:SetPoint(OPPOSITE[side], plate, side, x, y)
        copy:Show()
        if el.glowing then StartGlow(copy, cfg.iconGlow) end
    else
        StopGlow(copy)
        copy:Hide()
    end

    el.inGroup = grouped
    if mode == "plate" then
        el.frame:ClearAllPoints()
        el.frame:SetPoint(OPPOSITE[side], plate, side, x, y)
    elseif mode == "fixed" and not grouped then
        ApplyPosition(el)
    end
    el.body:SetShown(mode ~= "hidden")
    ns.LayoutGroup() -- it joined or left the group
end

-- With "alert even while on cooldown", the icon looks like an action button
-- on cooldown until it comes off: greyed out, a swipe for the time left, and
-- no glow. Checked a few times a second while the icon is up.
local COOLDOWN_CHECK = 0.1

-- Starts the swipe from the game's cooldown. In combat the start and duration
-- can be secret, so the duration object (which the swipe can draw without us
-- reading it) comes first.
local function StartSwipe(el, swipe)
    local id = ns.GetSpellID(el.abilityKey)
    if not id then return end
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
    local copy = el.plateCopy
    el.texture:SetDesaturated(cooling)
    copy.texture:SetDesaturated(cooling)
    if cooling then
        SetGlow(el, false)
        StartSwipe(el, el.swipe)
        StartSwipe(el, copy.swipe)
    else
        el.swipe:Clear()
        copy.swipe:Clear()
        if el.frame:IsShown() and not el.fading then SetGlow(el, true) end
    end
end

-- With "tintNoRage", the icon turns blue while the player is short on rage
-- for it, as action buttons do.
local NO_RAGE_TINT = { 0.5, 0.5, 1 }

local function SetShortOnRage(el, short)
    if el.shortOnRage == short then return end
    el.shortOnRage = short
    local r, g, b = 1, 1, 1
    if short then r, g, b = unpack(NO_RAGE_TINT) end
    el.texture:SetVertexColor(r, g, b)
    if el.plateCopy then el.plateCopy.texture:SetVertexColor(r, g, b) end
end

local function UpdateCooldownLook(el)
    local now = GetTime()
    if now < (el.nextCooldownCheck or 0) then return end
    el.nextCooldownCheck = now + COOLDOWN_CHECK
    -- Previews and moving the icon always show it ready.
    local real = not el.unlocked and not el.isPreview
    local cfg = ns.Config(el.abilityKey)
    local cooling = real and cfg.showOnCooldown and ns.OnCooldown(el.abilityKey)
    SetCoolingDown(el, cooling and true or false)
    local short = real and cfg.tintNoRage and ns.ShortOnRage(el.abilityKey)
    SetShortOnRage(el, short and true or false)
end

function ns.ApplyIconStyle(abilityKey)
    local el = Element(abilityKey, "icon")
    if not el then return end
    local cfg = ns.Config(abilityKey)
    local size = cfg.iconSize or 64
    el.frame:SetSize(size, size)
    el.plateCopy:SetSize(size, size)
    ns.SetFont(el.countdown, math.max(12, math.floor(size * 0.4)), "THICKOUTLINE")
    ns.SetFont(el.plateCopy.countdown, math.max(12, math.floor(size * 0.4)), "THICKOUTLINE")
    -- Glows are sized when they start, so restart any that's showing.
    SetGlow(el, el.frame:IsShown() and not el.coolingDown)
    ns.LayoutGroup() -- a different size moves its neighbours
end

function ns.ShowIcon(abilityKey)
    ShowElement(Element(abilityKey, "icon"))
end

--------------------------------------------------------------------------------
-- Setup and shared controls
--------------------------------------------------------------------------------

-- The parts of an icon, on `body`: border, spell texture, cooldown swipe and
-- countdown number. Returns the texture, swipe and countdown.
local function BuildIconParts(body)
    local border = body:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    local texture = body:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- Cooldown swipe, for alerts allowed while on cooldown. Our own
    -- countdown shows the opening, so the swipe has no numbers.
    local swipe = CreateFrame("Cooldown", nil, body, "CooldownFrameTemplate")
    swipe:SetAllPoints()
    swipe:SetDrawEdge(false)
    swipe:SetHideCountdownNumbers(true)
    if swipe.SetDrawBling then swipe:SetDrawBling(false) end
    swipe:SetFrameLevel(body:GetFrameLevel() + 2)
    -- On its own layer above the glow, so the glow never covers the number.
    local countdownLayer = CreateFrame("Frame", nil, body)
    countdownLayer:SetAllPoints()
    countdownLayer:SetFrameLevel(body:GetFrameLevel() + 20)
    local countdown = countdownLayer:CreateFontString(nil, "OVERLAY")
    countdown:SetPoint("CENTER")
    countdown:SetTextColor(1, 1, 1)
    ns.SetFont(countdown, 26, "THICKOUTLINE")
    countdown:Hide()
    return texture, swipe, countdown
end

function ns.InitDisplay()
    CreateGroup()
    for _, ability in ipairs(ns.ABILITIES) do
        local d = ability.defaults
        local function isActive() return ns.IsActive(ability.key) end

        local textEl = CreateElement(ability, "text", 0, d.textY, isActive)
        local label = textEl.frame:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER")
        label:SetTextColor(unpack(ability.color))
        ns.SetFont(label, 36, "THICKOUTLINE")
        label:SetText(ability.text)
        textEl.label = label
        local textCountdown = textEl.frame:CreateFontString(nil, "OVERLAY")
        textCountdown:SetPoint("LEFT", label, "RIGHT", 10, 0)
        textCountdown:SetTextColor(1, 1, 1)
        ns.SetFont(textCountdown, 36, "THICKOUTLINE")
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
        iconEl.texture, iconEl.swipe, iconEl.countdown = BuildIconParts(body)
        -- The second copy for the nameplate ("nameplateBoth").
        local copy = CreateFrame("Frame", nil, f)
        copy:SetSize(64, 64)
        copy:Hide()
        copy.texture, copy.swipe, copy.countdown = BuildIconParts(copy)
        iconEl.plateCopy = copy
        iconEl.onShow = function()
            RefreshIconTexture(iconEl, ability)
            iconEl.placedKey = nil
            PlaceIcon(iconEl)
            iconEl.coolingDown, iconEl.nextCooldownCheck = nil, 0
            SetShortOnRage(iconEl, false)
            UpdateCooldownLook(iconEl)
        end
        iconEl.onUpdate = function()
            PlaceIcon(iconEl)
            UpdateCooldownLook(iconEl)
        end
        f:HookScript("OnHide", function()
            SetGlow(iconEl, false)
            SetCoolingDown(iconEl, false)
            SetShortOnRage(iconEl, false)
            ns.LayoutGroup() -- the others close up
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
    if kind == "icon" and Grouped() then return group.unlocked end
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
    -- Grouped icons move together: unlocking any of them unlocks the group.
    if kind == "icon" and Grouped() then
        SetGroupUnlocked(value)
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
    if kind == "icon" and Grouped() then
        ns.General().groupPos = nil
        ApplyGroupPosition()
        return
    end
    local el = Element(abilityKey, kind)
    if not el then return end
    ns.Config(abilityKey)[kind .. "Pos"] = nil
    ApplyPosition(el)
    el.placedKey = nil -- the icon may belong on a nameplate instead
end

-- Switches between separate icon positions and the group ("separate" or
-- "group"), moving any icons that are up.
function ns.SetIconLayout(layout)
    ns.SetUnlocked(nil, "icon", false) -- lock under the old layout first
    ns.General().iconLayout = layout == "group" and "group" or "separate"
    for _, ability in ipairs(ns.ABILITIES) do
        local el = Element(ability.key, "icon")
        if el then
            el.placedKey, el.inGroup = nil, false
            if el.frame:IsShown() then PlaceIcon(el) end
        end
    end
    ns.LayoutGroup()
end
