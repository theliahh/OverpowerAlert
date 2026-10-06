local ADDON_NAME, ns = ...

local category

local CHANNELS = {
    { value = "Master",   label = "Master" },
    { value = "SFX",      label = "Sound Effects" },
    { value = "Dialog",   label = "Dialog" },
    { value = "Ambience", label = "Ambience" },
    { value = "Music",    label = "Music" },
}

local TEXT_SIZES = {
    { value = 24, label = "Small (24)" },
    { value = 30, label = "Medium (30)" },
    { value = 36, label = "Large (36)" },
    { value = 48, label = "Huge (48)" },
    { value = 64, label = "Massive (64)" },
}

local ICON_SIZES = {
    { value = 40,  label = "Small (40)" },
    { value = 52,  label = "Medium (52)" },
    { value = 64,  label = "Large (64)" },
    { value = 80,  label = "Huge (80)" },
    { value = 100, label = "Massive (100)" },
}

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

local unlockButtons = {} -- ["<abilityKey>/<kind>"] = { button, noun }

function ns.OnUnlockChanged(abilityKey, kind, isUnlocked)
    local b = unlockButtons[abilityKey .. "/" .. kind]
    if b then b.button:SetText((isUnlocked and "Lock " or "Unlock ") .. b.noun) end
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

    local enabled = CreateCheckbox(content, "Enable " .. ability.name .. " alert", abilityKey, "enabled", desc, -10)
    enabled:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -4, -10)
    -- Only abilities with a reliable out-of-stance signal offer this.
    local lastCheckbox = enabled
    if ability.anyStanceLabel then
        lastCheckbox = CreateCheckbox(content, ability.anyStanceLabel, abilityKey, "anyStance", enabled, -4)
    end

    ---------------------------------------------------------------------------
    -- Sound
    ---------------------------------------------------------------------------
    local soundLabel = Label(content, "Alert sound")
    soundLabel:SetPoint("TOPLEFT", lastCheckbox, "BOTTOMLEFT", 4, -20)

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
        local group = root:CreateButton(string.format("%s (%d)", groupName, #list))
        if group.SetScrollMode then group:SetScrollMode(MENU_MAX_HEIGHT) end
        for _, s in ipairs(list) do
            group:CreateRadio(s.label, IsSound, SetSound, s.key)
        end
        return group
    end

    soundDD:SetupMenu(function(_, root)
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
            AddGroup(root, "Shared Media", shared)
        else
            local none = root:CreateButton("Shared Media (none installed)")
            none:SetEnabled(false)
        end
        root:CreateDivider()
        root:CreateRadio("Custom (path or file ID)", IsSound, SetSound, "CUSTOM")
    end)
    menus[#menus + 1] = soundDD

    local test = CreateButton(content, "Test", 80)
    test:SetPoint("LEFT", soundDD, "RIGHT", 10, 0)
    test:SetScript("OnClick", function() ns.PlayAlertSound(abilityKey) end)

    local smHint = Label(content,
        "Shared Media lists every sound registered through LibSharedMedia by other addons\n" ..
        "(BigWigs, SharedMedia packs, WeakAuras, etc.). Install those to get more sounds.",
        "GameFontDisableSmall")
    smHint:SetJustifyH("LEFT")
    smHint:SetPoint("TOPLEFT", soundDD, "BOTTOMLEFT", 0, -6)

    -- Custom sound path / FileDataID
    customBox = CreateFrame("Frame", nil, content)
    customBox:SetPoint("TOPLEFT", smHint, "BOTTOMLEFT", 0, -10)
    customBox:SetSize(420, 44)

    local customLabel = Label(customBox,
        "Sound file path or FileDataID (e.g. Interface\\AddOns\\OverpowerAlert\\Sounds\\alert.ogg)",
        "GameFontHighlightSmall")
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
    local channelLabel = Label(content, "Sound channel")
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

        local unlock = CreateButton(content, "Unlock " .. s.noun, 120)
        unlock:SetPoint("LEFT", sizeDD, "RIGHT", 10, 0)
        unlock:SetScript("OnClick", function()
            ns.SetUnlocked(abilityKey, s.kind, not ns.IsUnlocked(abilityKey, s.kind))
        end)
        unlockButtons[abilityKey .. "/" .. s.kind] = { button = unlock, noun = s.noun }

        local reset = CreateButton(content, "Reset Position", 120)
        reset:SetPoint("LEFT", unlock, "RIGHT", 6, 0)
        reset:SetScript("OnClick", function() ns.ResetPosition(abilityKey, s.kind) end)

        local preview = CreateButton(content, "Preview", 80)
        preview:SetPoint("LEFT", reset, "RIGHT", 6, 0)
        preview:SetScript("OnClick", s.preview)

        return sizeDD
    end

    local textSizeDD = BuildDisplaySection(channelDD, {
        kind = "text", noun = "Text", title = "On-screen text",
        showLabel = "Show \"" .. ability.text .. "\" on screen", showKey = "showText",
        sizeLabel = "Text size", sizeKey = "textSize", sizes = TEXT_SIZES,
        applyStyle = function() ns.ApplyTextStyle(abilityKey) end,
        preview = function() ns.ShowText(abilityKey) end,
    })

    local iconSizeDD = BuildDisplaySection(textSizeDD, {
        kind = "icon", noun = "Icon", title = "Spell icon",
        showLabel = "Show the " .. ability.name .. " icon (stays up while " .. ability.name .. " is usable)",
        showKey = "showIcon",
        sizeLabel = "Icon size", sizeKey = "iconSize", sizes = ICON_SIZES,
        applyStyle = function() ns.ApplyIconStyle(abilityKey) end,
        preview = function() ns.ShowIcon(abilityKey) end,
    })

    local glowLabel = Label(content, "Icon glow")
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

    local moveHint = Label(content,
        "Unlock, then drag the highlighted box anywhere. Right-click it (or /opa lock) to lock.",
        "GameFontDisableSmall")
    moveHint:SetPoint("TOPLEFT", glowDD, "BOTTOMLEFT", 0, -16)

    local slashHint = Label(content,
        "Slash commands: /opa (options), /opa test [overpower|revenge], /opa toggle [ability],\n" ..
        "/opa unlock [ability], /opa lock [ability]. Without an ability, toggle/unlock/lock\n" ..
        "apply to both and test plays Overpower.",
        "GameFontDisableSmall")
    slashHint:SetJustifyH("LEFT")
    slashHint:SetPoint("TOPLEFT", moveHint, "BOTTOMLEFT", 0, -20)

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
    panel.name = "Overpower Alert"

    local title = Label(panel, "Overpower Alert", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local sub = Label(panel, "Plays an alert when Overpower or Revenge becomes usable. Each has its own settings.",
        "GameFontHighlightSmall")
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
        content:SetSize(600, 1000)
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
