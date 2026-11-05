local ADDON_NAME, ns = ...

-- Glows the ability's buttons on the action bars while its opening is up, in
-- any stance. Works with Blizzard's bars and with bar addons built on
-- LibActionButton (Bartender4, ElvUI and others). While any glow is wanted the
-- bars are rescanned every SCAN_INTERVAL, so the glow follows bar paging
-- (stance bars) and buttons being moved or changed.

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local GLOW_KEY = "OverpowerAlertBar" -- keeps our glows apart from other addons'
local SCAN_INTERVAL = 0.1
local PREVIEW_SECONDS = 5
local EUI_MAX_SLOT = 180 -- EllesmereUI names its buttons EABButton<slot>

local BLIZZARD_BARS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button",
    "MultiBar7Button",
}

local spellOwner = {} -- [spellID] = abilityKey, every rank
for _, ability in ipairs(ns.ABILITIES) do
    for _, id in ipairs(ability.ids) do spellOwner[id] = ability.key end
end

local previewUntil = {} -- [abilityKey] = time
local glowing = {}      -- [button] = glow style it has now

local function Readable(v)
    return not (issecretvalue and issecretvalue(v))
end

local function StartGlow(button, style)
    if not LCG then return end
    if style == "proc" then
        LCG.ProcGlow_Start(button, { key = GLOW_KEY, startAnim = true })
    elseif style == "button" then
        LCG.ButtonGlow_Start(button)
    elseif style == "pixel" then
        LCG.PixelGlow_Start(button, nil, 8, 0.25, nil, 2, 0, 0, false, GLOW_KEY)
    elseif style == "autocast" then
        LCG.AutoCastGlow_Start(button, nil, 4, 0.125, 1, 0, 0, GLOW_KEY)
    end
end

local function StopGlow(button, style)
    if not LCG then return end
    if style == "proc" then
        LCG.ProcGlow_Stop(button, GLOW_KEY)
    elseif style == "button" then
        LCG.ButtonGlow_Stop(button)
    elseif style == "pixel" then
        LCG.PixelGlow_Stop(button, GLOW_KEY)
    elseif style == "autocast" then
        LCG.AutoCastGlow_Stop(button, GLOW_KEY)
    end
end

-- Every action button we know how to read, each once.
local function ForEachButton(fn)
    local seen = {}
    local function visit(button)
        if type(button) == "table" and not seen[button] then
            seen[button] = true
            fn(button)
        end
    end
    -- Blizzard registers every button made from its action button template
    -- here, including ones other bar addons make from it.
    local registry = ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames
    if type(registry) == "table" then
        for _, button in pairs(registry) do visit(button) end
    end
    for _, prefix in ipairs(BLIZZARD_BARS) do
        for i = 1, 12 do visit(_G[prefix .. i]) end
    end
    -- EllesmereUI makes its own buttons, one per action slot, and takes them
    -- back out of Blizzard's registry.
    for slot = 1, EUI_MAX_SLOT do visit(_G["EABButton" .. slot]) end
    for _, major in ipairs({ "LibActionButton-1.0", "LibActionButton-1.0-ElvUI" }) do
        local lab = LibStub and LibStub(major, true)
        if lab and type(lab.buttonRegistry) == "table" then
            for button in pairs(lab.buttonRegistry) do visit(button) end
        end
    end
end

-- The spell a button casts, or nil. Spells and macros that cast a spell.
local function ButtonSpell(button)
    if button.GetSpellId then -- LibActionButton
        local ok, id = pcall(button.GetSpellId, button)
        if ok and Readable(id) then return id end
        return nil
    end
    -- Bars that page (stances) write the current slot to the "action"
    -- attribute; button.action mirrors it, and can be secret in combat.
    local slot = button.GetAttribute and button:GetAttribute("action")
    if slot == nil then slot = button.action end
    slot = Readable(slot) and tonumber(slot)
    if not slot or not GetActionInfo then return nil end
    local ok, actionType, id, subType = pcall(GetActionInfo, slot)
    if not ok or not (Readable(actionType) and Readable(id) and Readable(subType)) then return nil end
    if actionType == "spell" then return id end
    if actionType == "macro" then
        -- A macro showing a spell reports that spell's ID.
        if subType == "spell" then return id end
        local spell = GetMacroSpell and GetMacroSpell(id)
        if spell and Readable(spell) then return spell end
    end
    return nil
end

-- The glow style an ability wants right now, or nil for none.
local function WantedStyle(abilityKey)
    local cfg = ns.Config(abilityKey)
    if not (cfg and cfg.enabled and cfg.barGlow) or cfg.barGlowStyle == "none" then return nil end
    local previewing = GetTime() < (previewUntil[abilityKey] or 0)
    if previewing or (ns.IsActive(abilityKey) and not ns.OnCooldown(abilityKey)) then
        return cfg.barGlowStyle
    end
    return nil
end

local function Update()
    local styles, any = {}, false
    for _, ability in ipairs(ns.ABILITIES) do
        local style = WantedStyle(ability.key)
        styles[ability.key] = style
        any = any or style ~= nil
    end

    local want = {} -- [button] = style
    if any then
        ForEachButton(function(button)
            if not button:IsVisible() then return end
            local id = ButtonSpell(button)
            local style = id and styles[spellOwner[id]]
            if style then want[button] = style end
        end)
    end

    for button, style in pairs(glowing) do
        if want[button] ~= style then
            StopGlow(button, style)
            glowing[button] = nil
        end
    end
    for button, style in pairs(want) do
        if not glowing[button] then
            StartGlow(button, style)
            glowing[button] = style
        end
    end
end

-- Glows the ability's buttons for a few seconds (Preview, /opa test).
function ns.PreviewBarGlow(abilityKey)
    previewUntil[abilityKey] = GetTime() + PREVIEW_SECONDS
    Update()
end

function ns.InitActionBars()
    local driver = CreateFrame("Frame")
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < SCAN_INTERVAL then return end
        elapsed = 0
        Update()
    end)
end
