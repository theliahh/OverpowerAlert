local ADDON_NAME, ns = ...
local L = ns.L -- all text lives in Strings.lua

local category

local CHANNELS = {
    { value = "Master",   label = L.CHANNEL_MASTER },
    { value = "SFX",      label = L.CHANNEL_SFX },
    { value = "Dialog",   label = L.CHANNEL_DIALOG },
    { value = "Ambience", label = L.CHANNEL_AMBIENCE },
    { value = "Music",    label = L.CHANNEL_MUSIC },
}

local SIZE_NAMES = { L.SIZE_SMALL, L.SIZE_MEDIUM, L.SIZE_LARGE, L.SIZE_HUGE, L.SIZE_MASSIVE }

local function Sizes(values)
    local list = {}
    for i, v in ipairs(values) do
        list[i] = { value = v, label = L.SIZE_LABEL:format(SIZE_NAMES[i], v) }
    end
    return list
end

local TEXT_SIZES = Sizes({ 24, 30, 36, 48, 64 })
local ICON_SIZES = Sizes({ 40, 52, 64, 80, 100 })

local NAMEPLATE_SIDES = {
    { value = "TOP",    label = L.SIDE_TOP },
    { value = "BOTTOM", label = L.SIDE_BOTTOM },
    { value = "LEFT",   label = L.SIDE_LEFT },
    { value = "RIGHT",  label = L.SIDE_RIGHT },
}

local MAX_OFFSET = 500

local MENU_MAX_HEIGHT = 400

local function CreateCheckbox(parent, label, abilityKey, key, anchor, yOff)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -8)
    local text = cb.Text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    text:SetText(label)
    cb:SetScript("OnShow", function(self) self:SetChecked(ns.Config(abilityKey)[key]) end)
    cb:SetScript("OnClick", function(self) ns.Config(abilityKey)[key] = self:GetChecked() and true or false end)
    return cb
end

local function CreateRadioDropdown(parent, width, options, getValue, setValue)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(width)
    dd:SetupMenu(function(_, root)
        for _, opt in ipairs(options()) do
            root:CreateRadio(opt.label,
                function() return getValue() == opt.value end,
                function() setValue(opt.value) end)
        end
    end)
    return dd
end

-- A box for a whole number of pixels (negative allowed), saved on Enter or
-- when it loses focus. Anything that isn't a number puts the saved value back.
local function CreateNumberBox(parent, abilityKey, key)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(60, 22)
    box:SetAutoFocus(false)
    local function Load(self) self:SetText(tostring(ns.Config(abilityKey)[key] or 0)) end
    box:SetScript("OnShow", Load)
    box:SetScript("OnEditFocusLost", function(self)
        local v = tonumber(self:GetText())
        if v then
            ns.Config(abilityKey)[key] = math.max(-MAX_OFFSET, math.min(MAX_OFFSET, math.floor(v + 0.5)))
        end
        Load(self)
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) Load(self); self:ClearFocus() end)
    return box
end

local function CreateButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(text)
    return b
end

local function Label(parent, text, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetText(text)
    return fs
end

local unlockButtons = {} -- ["<abilityKey>/<kind>"] = { button, unlockText, lockText }

function ns.OnUnlockChanged(abilityKey, kind, isUnlocked)
    local b = unlockButtons[abilityKey .. "/" .. kind]
    if b then b.button:SetText(isUnlocked and b.lockText or b.unlockText) end
end

--------------------------------------------------------------------------------
-- One page of settings for one ability. Returns a function that refreshes
-- the page's dropdowns and conditional controls.
--------------------------------------------------------------------------------

local function BuildAbilityPage(content, ability)
    local abilityKey = ability.key
    local function cfg() return ns.Config(abilityKey) end
    local menus = {}

    local desc = Label(content, ability.description, "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 16, -8)

    local enabled = CreateCheckbox(content, L.ENABLE_ALERT:format(ability.name), abilityKey, "enabled", desc, -10)
    enabled:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -4, -10)
    -- Which stances to alert in: one checkbox per stance, in a row.
    local stanceLabel = Label(content, L.ALERT_IN, "GameFontHighlight")
    stanceLabel:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -10)
    local prevText
    for _, stance in ipairs(ns.STANCES) do
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        if prevText then
            cb:SetPoint("LEFT", prevText, "RIGHT", 16, 0)
        else
            cb:SetPoint("LEFT", stanceLabel, "RIGHT", 8, 0)
        end
        local text = cb.Text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        text:SetText(stance.name)
        cb:SetScript("OnShow", function(self) self:SetChecked(cfg().stances[stance.key]) end)
        cb:SetScript("OnClick", function(self) cfg().stances[stance.key] = self:GetChecked() and true or false end)
        prevText = text
    end

    local stanceHint = Label(content, L.STANCE_HINT, "GameFontDisableSmall")
    stanceHint:SetPoint("TOPLEFT", stanceLabel, "BOTTOMLEFT", 0, -12)

    ---------------------------------------------------------------------------
    -- Sound
    ---------------------------------------------------------------------------
    local soundLabel = Label(content, L.ALERT_SOUND)
    soundLabel:SetPoint("TOPLEFT", stanceHint, "BOTTOMLEFT", 0, -20)

    local customBox
    local soundDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    soundDD:SetWidth(240)
    soundDD:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -6)

    local function RefreshSoundText()
        if soundDD.OverrideText then
            soundDD:OverrideText(ns.GetSoundLabel(cfg().sound))
        end
    end

    local function IsSound(key) return cfg().sound == key end
    local function SetSound(key)
        cfg().sound = key
        customBox:SetShown(key == "CUSTOM")
        RefreshSoundText()
        ns.PlayAlertSound(abilityKey, key)
    end

    local function AddGroup(root, groupName, list)
        local group = root:CreateButton(L.SOUND_GROUP:format(groupName, #list))
        if group.SetScrollMode then group:SetScrollMode(MENU_MAX_HEIGHT) end
        for _, s in ipairs(list) do
            group:CreateRadio(s.label, IsSound, SetSound, s.key)
        end
        return group
    end

    soundDD:SetupMenu(function(_, root)
        root:CreateRadio(L.SOUND_NONE, IsSound, SetSound, "NONE")
        root:CreateDivider()
        for _, group in ipairs(ns.CDM_SOUNDS) do
            local list = {}
            for _, s in ipairs(group[2]) do
                list[#list + 1] = { key = "cdm:" .. s[1], label = s[2] }
            end
            AddGroup(root, group[1], list)
        end
        root:CreateDivider()
        local shared = ns.GetSharedMediaSounds()
        if #shared > 0 then
            AddGroup(root, L.SHARED_MEDIA, shared)
        else
            local none = root:CreateButton(L.SHARED_MEDIA_NONE)
            none:SetEnabled(false)
        end
        root:CreateDivider()
        root:CreateRadio(L.SOUND_CUSTOM_MENU, IsSound, SetSound, "CUSTOM")
    end)
    menus[#menus + 1] = soundDD

    local test = CreateButton(content, L.TEST, 80)
    test:SetPoint("LEFT", soundDD, "RIGHT", 10, 0)
    test:SetScript("OnClick", function() ns.PlayAlertSound(abilityKey) end)

    local smHint = Label(content, L.SHARED_MEDIA_HINT, "GameFontDisableSmall")
    smHint:SetJustifyH("LEFT")
    smHint:SetPoint("TOPLEFT", soundDD, "BOTTOMLEFT", 0, -6)

    -- Custom sound path / FileDataID
    customBox = CreateFrame("Frame", nil, content)
    customBox:SetPoint("TOPLEFT", smHint, "BOTTOMLEFT", 0, -10)
    customBox:SetSize(420, 44)

    local customLabel = Label(customBox, L.CUSTOM_SOUND_LABEL, "GameFontHighlightSmall")
    customLabel:SetPoint("TOPLEFT")

    local edit = CreateFrame("EditBox", nil, customBox, "InputBoxTemplate")
    edit:SetSize(360, 22)
    edit:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 6, -6)
    edit:SetAutoFocus(false)
    edit:SetScript("OnShow", function(self) self:SetText(cfg().customSound or "") end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then cfg().customSound = self:GetText() end
    end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ns.PlayAlertSound(abilityKey) end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Channel
    local channelLabel = Label(content, L.SOUND_CHANNEL)
    channelLabel:SetPoint("TOPLEFT", customBox, "BOTTOMLEFT", 0, -8)

    local channelDD = CreateRadioDropdown(content, 240,
        function() return CHANNELS end,
        function() return cfg().channel end,
        function(value) cfg().channel = value end)
    channelDD:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -6)
    menus[#menus + 1] = channelDD

    ---------------------------------------------------------------------------
    -- On-screen text and spell icon. Both get the same controls: show
    -- checkbox, size, unlock/reset/preview.
    ---------------------------------------------------------------------------
    local function BuildDisplaySection(anchor, s)
        local header = Label(content, s.title, "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -24)

        local show = CreateCheckbox(content, s.showLabel, abilityKey, s.showKey, header, -6)
        show:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -6)

        local sizeLabel = Label(content, s.sizeLabel)
        sizeLabel:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 4, -12)

        local sizeDD = CreateRadioDropdown(content, 160,
            function() return s.sizes end,
            function() return cfg()[s.sizeKey] end,
            function(value) cfg()[s.sizeKey] = value; s.applyStyle() end)
        sizeDD:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -6)
        menus[#menus + 1] = sizeDD

        local unlock = CreateButton(content, s.unlockText, 120)
        unlock:SetPoint("LEFT", sizeDD, "RIGHT", 10, 0)
        unlock:SetScript("OnClick", function()
            ns.SetUnlocked(abilityKey, s.kind, not ns.IsUnlocked(abilityKey, s.kind))
        end)
        unlockButtons[abilityKey .. "/" .. s.kind] = { button = unlock, unlockText = s.unlockText, lockText = s.lockText }

        local reset = CreateButton(content, L.RESET_POSITION, 120)
        reset:SetPoint("LEFT", unlock, "RIGHT", 6, 0)
        reset:SetScript("OnClick", function() ns.ResetPosition(abilityKey, s.kind) end)

        local preview = CreateButton(content, L.PREVIEW, 80)
        preview:SetPoint("LEFT", reset, "RIGHT", 6, 0)
        preview:SetScript("OnClick", s.preview)

        return sizeDD
    end

    local textSizeDD = BuildDisplaySection(channelDD, {
        kind = "text", unlockText = L.UNLOCK_TEXT, lockText = L.LOCK_TEXT, title = L.ONSCREEN_TEXT,
        showLabel = L.SHOW_TEXT:format(ability.text), showKey = "showText",
        sizeLabel = L.TEXT_SIZE, sizeKey = "textSize", sizes = TEXT_SIZES,
        applyStyle = function() ns.ApplyTextStyle(abilityKey) end,
        preview = function() ns.ShowText(abilityKey) end,
    })

    local iconSizeDD = BuildDisplaySection(textSizeDD, {
        kind = "icon", unlockText = L.UNLOCK_ICON, lockText = L.LOCK_ICON, title = L.SPELL_ICON,
        showLabel = L.SHOW_ICON:format(ability.name, ability.name),
        showKey = "showIcon",
        sizeLabel = L.ICON_SIZE, sizeKey = "iconSize", sizes = ICON_SIZES,
        applyStyle = function() ns.ApplyIconStyle(abilityKey) end,
        preview = function() ns.ShowIcon(abilityKey) end,
    })

    local glowLabel = Label(content, L.ICON_GLOW)
    glowLabel:SetPoint("TOPLEFT", iconSizeDD, "BOTTOMLEFT", 0, -12)

    local glowDD = CreateRadioDropdown(content, 160,
        function() return ns.GLOW_STYLES end,
        function() return cfg().iconGlow end,
        function(value)
            cfg().iconGlow = value
            ns.ApplyIconStyle(abilityKey)
            if not ns.IsUnlocked(abilityKey, "icon") then ns.ShowIcon(abilityKey) end
        end)
    glowDD:SetPoint("TOPLEFT", glowLabel, "BOTTOMLEFT", 0, -6)
    menus[#menus + 1] = glowDD

    local moveHint = Label(content, L.MOVE_HINT, "GameFontDisableSmall")
    moveHint:SetJustifyH("LEFT")
    moveHint:SetPoint("TOPLEFT", glowDD, "BOTTOMLEFT", 0, -16)

    ---------------------------------------------------------------------------
    -- Icon on the target's nameplate
    ---------------------------------------------------------------------------
    local plateHeader = Label(content, L.NAMEPLATE, "GameFontNormalLarge")
    plateHeader:SetPoint("TOPLEFT", moveHint, "BOTTOMLEFT", 0, -24)

    local onPlate = CreateCheckbox(content, L.ICON_ON_NAMEPLATE,
        abilityKey, "iconOnNameplate", plateHeader, -6)
    onPlate:SetPoint("TOPLEFT", plateHeader, "BOTTOMLEFT", -4, -6)

    local sideLabel = Label(content, L.SIDE)
    sideLabel:SetPoint("TOPLEFT", onPlate, "BOTTOMLEFT", 4, -10)
    local sideDD = CreateRadioDropdown(content, 160,
        function() return NAMEPLATE_SIDES end,
        function() return cfg().nameplateSide end,
        function(value) cfg().nameplateSide = value end)
    sideDD:SetPoint("TOPLEFT", sideLabel, "BOTTOMLEFT", 0, -6)
    menus[#menus + 1] = sideDD

    local xLabel = Label(content, L.X_OFFSET)
    xLabel:SetPoint("LEFT", sideLabel, "LEFT", 180, 0)
    local xBox = CreateNumberBox(content, abilityKey, "nameplateX")
    xBox:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 6, -8)

    local yLabel = Label(content, L.Y_OFFSET)
    yLabel:SetPoint("LEFT", xLabel, "LEFT", 90, 0)
    local yBox = CreateNumberBox(content, abilityKey, "nameplateY")
    yBox:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 6, -8)

    local plateHint = Label(content, L.OFFSET_HINT, "GameFontDisableSmall")
    plateHint:SetJustifyH("LEFT")
    plateHint:SetPoint("TOPLEFT", sideDD, "BOTTOMLEFT", 0, -10)

    local fallback = CreateCheckbox(content, L.NAMEPLATE_FALLBACK, abilityKey, "nameplateFallback", plateHint, -8)
    fallback:SetPoint("TOPLEFT", plateHint, "BOTTOMLEFT", -4, -8)

    ---------------------------------------------------------------------------
    -- Action bar glow
    ---------------------------------------------------------------------------
    local barHeader = Label(content, L.ACTION_BARS, "GameFontNormalLarge")
    barHeader:SetPoint("TOPLEFT", fallback, "BOTTOMLEFT", 4, -24)

    local barGlow = CreateCheckbox(content, L.BAR_GLOW:format(ability.name), abilityKey, "barGlow", barHeader, -6)
    barGlow:SetPoint("TOPLEFT", barHeader, "BOTTOMLEFT", -4, -6)

    local barStyleLabel = Label(content, L.BUTTON_GLOW)
    barStyleLabel:SetPoint("TOPLEFT", barGlow, "BOTTOMLEFT", 4, -12)
    local barStyleDD = CreateRadioDropdown(content, 160,
        function() return ns.GLOW_STYLES end,
        function() return cfg().barGlowStyle end,
        function(value) cfg().barGlowStyle = value end)
    barStyleDD:SetPoint("TOPLEFT", barStyleLabel, "BOTTOMLEFT", 0, -6)
    menus[#menus + 1] = barStyleDD

    local barPreview = CreateButton(content, L.PREVIEW, 80)
    barPreview:SetPoint("LEFT", barStyleDD, "RIGHT", 10, 0)
    barPreview:SetScript("OnClick", function() ns.PreviewBarGlow(abilityKey) end)

    local barHint = Label(content, L.BAR_HINT, "GameFontDisableSmall")
    barHint:SetJustifyH("LEFT")
    barHint:SetPoint("TOPLEFT", barStyleDD, "BOTTOMLEFT", 0, -10)

    ---------------------------------------------------------------------------
    -- Countdown
    ---------------------------------------------------------------------------
    local countdownHeader = Label(content, L.COUNTDOWN, "GameFontNormalLarge")
    countdownHeader:SetPoint("TOPLEFT", barHint, "BOTTOMLEFT", 0, -24)

    local countdown = CreateCheckbox(content, L.SHOW_COUNTDOWN, abilityKey, "showCountdown", countdownHeader, -6)
    countdown:SetPoint("TOPLEFT", countdownHeader, "BOTTOMLEFT", -4, -6)

    local slashHint = Label(content, L.SLASH_HINT, "GameFontDisableSmall")
    slashHint:SetJustifyH("LEFT")
    slashHint:SetPoint("TOPLEFT", countdown, "BOTTOMLEFT", 4, -20)

    return function()
        customBox:SetShown(cfg().sound == "CUSTOM")
        for _, dd in ipairs(menus) do dd:GenerateMenu() end
        RefreshSoundText()
    end
end

--------------------------------------------------------------------------------
-- Panel with one tab per ability
--------------------------------------------------------------------------------

local function CreateTab(parent, text)
    -- Top-style tabs where the client has them, plain buttons otherwise.
    local ok, tab = pcall(CreateFrame, "Button", nil, parent, "PanelTopTabButtonTemplate")
    local isTab = ok and tab ~= nil
    if not isTab then tab = CreateButton(parent, text, 120) end
    tab:SetText(text)
    if isTab and PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 15) end

    function tab:SetSelected(selected)
        if isTab and PanelTemplates_SelectTab then
            if selected then PanelTemplates_SelectTab(self) else PanelTemplates_DeselectTab(self) end
        else
            self:SetEnabled(not selected)
        end
    end
    return tab
end

function ns.CreateOptions()
    local panel = CreateFrame("Frame")
    panel.name = L.ADDON_TITLE

    local title = Label(panel, L.ADDON_TITLE, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local sub = Label(panel, L.OPTIONS_SUBTITLE, "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    local pages, tabs, refreshers = {}, {}, {}
    local selected = ns.ABILITIES[1].key

    local function SelectTab(key)
        selected = key
        for k, page in pairs(pages) do page:SetShown(k == key) end
        for k, tab in pairs(tabs) do tab:SetSelected(k == key) end
        if refreshers[key] then refreshers[key]() end
    end

    -- Tab heights differ between templates, so the divider and pages hang
    -- off the tabs rather than a fixed offset.
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetHeight(1)

    local prevTab
    for _, ability in ipairs(ns.ABILITIES) do
        local tab = CreateTab(panel, ability.name)
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
            divider:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", -4, 0)
            divider:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
        end
        tab:SetScript("OnClick", function() SelectTab(ability.key) end)
        tabs[ability.key] = tab
        prevTab = tab

        -- Each page scrolls, since it's taller than the settings window.
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOP", divider, "BOTTOM", 0, -4)
        scroll:SetPoint("LEFT", panel, "LEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -28, 4)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(600, 1450)
        scroll:SetScrollChild(content)
        scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)
        scroll:Hide()
        pages[ability.key] = scroll

        refreshers[ability.key] = BuildAbilityPage(content, ability)
    end

    panel:SetScript("OnShow", function() SelectTab(selected) end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        category = panel
    end
end

function ns.OpenOptions()
    if Settings and Settings.OpenToCategory and category and category.GetID then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and category then
        InterfaceOptionsFrame_OpenToCategory(category)
        InterfaceOptionsFrame_OpenToCategory(category)
    end
end
