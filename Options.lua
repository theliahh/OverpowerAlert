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

local MENU_MAX_HEIGHT = 400

local function CreateCheckbox(parent, label, key, anchor, yOff)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -8)
    local text = cb.Text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    text:SetText(label)
    cb:SetScript("OnShow", function(self) self:SetChecked(OverpowerAlertDB[key]) end)
    cb:SetScript("OnClick", function(self) OverpowerAlertDB[key] = self:GetChecked() and true or false end)
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

function ns.CreateOptions()
    local panel = CreateFrame("Frame")
    panel.name = "Overpower Alert"

    local title = Label(panel, "Overpower Alert", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local sub = Label(panel, "Plays a sound when Overpower becomes usable after your target dodges.",
        "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    local enabled = CreateCheckbox(panel, "Enable alert", "enabled", sub, -12)
    local anyStance = CreateCheckbox(panel,
        "Also alert on any target dodge (any stance, including dodges of others' attacks)",
        "anyStance", enabled, -4)

    ---------------------------------------------------------------------------
    -- Sound
    ---------------------------------------------------------------------------
    local soundLabel = Label(panel, "Alert sound")
    soundLabel:SetPoint("TOPLEFT", anyStance, "BOTTOMLEFT", 4, -20)

    local customBox
    local soundDD = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    soundDD:SetWidth(240)
    soundDD:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -6)

    local function RefreshSoundText()
        if soundDD.OverrideText then
            soundDD:OverrideText(ns.GetSoundLabel(OverpowerAlertDB.sound))
        end
    end

    local function IsSound(key) return OverpowerAlertDB.sound == key end
    local function SetSound(key)
        OverpowerAlertDB.sound = key
        customBox:SetShown(key == "CUSTOM")
        RefreshSoundText()
        ns.PlayAlertSound(key)
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
        AddGroup(root, "Game Sounds", ns.GAME_SOUNDS)
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

    local test = CreateButton(panel, "Test", 80)
    test:SetPoint("LEFT", soundDD, "RIGHT", 10, 0)
    test:SetScript("OnClick", function() ns.PlayAlertSound() end)

    local smHint = Label(panel,
        "Shared Media lists every sound registered through LibSharedMedia by other addons\n" ..
        "(BigWigs, SharedMedia packs, WeakAuras, etc.). Install those to get more sounds.",
        "GameFontDisableSmall")
    smHint:SetJustifyH("LEFT")
    smHint:SetPoint("TOPLEFT", soundDD, "BOTTOMLEFT", 0, -6)

    -- Custom sound path / FileDataID
    customBox = CreateFrame("Frame", nil, panel)
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
    edit:SetScript("OnShow", function(self) self:SetText(OverpowerAlertDB.customSound or "") end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then OverpowerAlertDB.customSound = self:GetText() end
    end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ns.PlayAlertSound() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Channel
    local channelLabel = Label(panel, "Sound channel")
    channelLabel:SetPoint("TOPLEFT", customBox, "BOTTOMLEFT", 0, -8)

    local channelDD = CreateRadioDropdown(panel, 240,
        function() return CHANNELS end,
        function() return OverpowerAlertDB.channel end,
        function(value) OverpowerAlertDB.channel = value end)
    channelDD:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -6)

    ---------------------------------------------------------------------------
    -- On-screen text
    ---------------------------------------------------------------------------
    local textHeader = Label(panel, "On-screen text", "GameFontNormalLarge")
    textHeader:SetPoint("TOPLEFT", channelDD, "BOTTOMLEFT", 0, -24)

    local showText = CreateCheckbox(panel, "Show \"OVERPOWER!\" on screen", "showText", textHeader, -6)
    showText:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", -4, -6)

    local sizeLabel = Label(panel, "Text size")
    sizeLabel:SetPoint("TOPLEFT", showText, "BOTTOMLEFT", 4, -12)

    local sizeDD = CreateRadioDropdown(panel, 160,
        function() return TEXT_SIZES end,
        function() return OverpowerAlertDB.textSize end,
        function(value) OverpowerAlertDB.textSize = value; ns.ApplyTextStyle() end)
    sizeDD:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -6)

    local unlock = CreateButton(panel, "Unlock Text", 120)
    unlock:SetPoint("LEFT", sizeDD, "RIGHT", 10, 0)
    unlock:SetScript("OnClick", function() ns.SetTextUnlocked(not ns.IsTextUnlocked()) end)

    local reset = CreateButton(panel, "Reset Position", 120)
    reset:SetPoint("LEFT", unlock, "RIGHT", 6, 0)
    reset:SetScript("OnClick", function() ns.ResetTextPosition() end)

    local preview = CreateButton(panel, "Preview", 80)
    preview:SetPoint("LEFT", reset, "RIGHT", 6, 0)
    preview:SetScript("OnClick", function() ns.ShowText() end)

    local moveHint = Label(panel, "Unlock, then drag the highlighted text anywhere. Right-click it (or /opa lock) to lock.",
        "GameFontDisableSmall")
    moveHint:SetPoint("TOPLEFT", sizeDD, "BOTTOMLEFT", 0, -8)

    function ns.OnUnlockChanged(isUnlocked)
        unlock:SetText(isUnlocked and "Lock Text" or "Unlock Text")
    end

    local hint = Label(panel, "Slash commands: /opa (options), /opa test, /opa toggle, /opa unlock, /opa lock",
        "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", moveHint, "BOTTOMLEFT", 0, -20)

    panel:SetScript("OnShow", function()
        customBox:SetShown(OverpowerAlertDB.sound == "CUSTOM")
        soundDD:GenerateMenu()
        RefreshSoundText()
        channelDD:GenerateMenu()
        sizeDD:GenerateMenu()
    end)

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
