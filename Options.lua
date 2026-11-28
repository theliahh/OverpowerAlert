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

local NAMEPLATE_SIDES = {
    { value = "TOP",    label = L.SIDE_TOP },
    { value = "BOTTOM", label = L.SIDE_BOTTOM },
    { value = "LEFT",   label = L.SIDE_LEFT },
    { value = "RIGHT",  label = L.SIDE_RIGHT },
}

local ICON_LAYOUTS = {
    { value = "separate", label = L.ICON_LAYOUT_SEPARATE },
    { value = "group",    label = L.ICON_LAYOUT_GROUP },
}

local GROUP_GROWS = {
    { value = "RIGHT",   label = L.GROW_RIGHT },
    { value = "LEFT",    label = L.GROW_LEFT },
    { value = "UP",      label = L.GROW_UP },
    { value = "DOWN",    label = L.GROW_DOWN },
    { value = "HCENTER", label = L.GROW_HCENTER },
    { value = "VCENTER", label = L.GROW_VCENTER },
}

local MAX_OFFSET = 500

local MENU_MAX_HEIGHT = 400

local function CreateCheckbox(parent, label, abilityKey, key, anchor, yOff)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -8)
    local text = cb.Text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    text:SetText(label)
    cb.label = text
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
-- `onChange`, if given, runs after a new value is saved.
local function CreateNumberBox(parent, abilityKey, key, onChange)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(60, 22)
    box:SetAutoFocus(false)
    local function Load(self) self:SetText(tostring(ns.Config(abilityKey)[key] or 0)) end
    box:SetScript("OnShow", Load)
    box:SetScript("OnEditFocusLost", function(self)
        local v = tonumber(self:GetText())
        if v then
            ns.Config(abilityKey)[key] = math.max(-MAX_OFFSET, math.min(MAX_OFFSET, math.floor(v + 0.5)))
            if onChange then onChange() end
        end
        Load(self)
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) Load(self); self:ClearFocus() end)
    return box
end

-- A slider for a whole number from minValue to maxValue, with steppers, and
-- a box on its right showing the value that a size can also be typed into
-- (saved on Enter or when it loses focus; out of range is clamped, anything
-- else puts the value back). `getValue` is read when the page shows;
-- `setValue` runs as it changes. Returns the slider, and a function that
-- loads the saved value into it.
local function CreateNumberSlider(parent, width, minValue, maxValue, getValue, setValue)
    local slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(width)
    local loading = false

    local box = CreateFrame("EditBox", nil, slider, "InputBoxTemplate")
    box:SetSize(44, 22)
    box:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    box:SetAutoFocus(false)
    box:SetNumeric(true) -- digits only; the range is checked below
    box:SetMaxLetters(3)
    box:SetJustifyH("CENTER")
    slider.input = box

    local function Show(value) box:SetText(tostring(math.floor(value + 0.5))) end

    slider:Init(getValue(), minValue, maxValue, maxValue - minValue, nil)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not box:HasFocus() then Show(value) end
        if not loading then setValue(math.floor(value + 0.5)) end
    end, slider)

    local function Apply()
        local v = tonumber(box:GetText())
        if v then
            v = math.max(minValue, math.min(maxValue, math.floor(v + 0.5)))
            slider.Slider:SetValue(v) -- saves it, through OnValueChanged
        end
        Show(slider.Slider:GetValue())
    end
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", Apply)
    box:SetScript("OnEscapePressed", function(self)
        Show(slider.Slider:GetValue())
        self:ClearFocus()
    end)

    local function Load()
        loading = true
        slider.Slider:SetValue(getValue())
        loading = false
        Show(getValue())
    end
    Show(getValue())
    return slider, Load
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

-- A faint line across the page, `gap` below `anchor`, between sections.
-- Returns it, for the next section to hang from.
local function Divider(parent, anchor, gap)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    return line
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
    local sizeLoaders = {} -- reload each size slider's saved value

    local desc = Label(content, ability.description, "GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
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

    -- Execute has no cooldown, so no "even while on cooldown" option.
    local soundLabel = Label(content, L.ALERT_SOUND)
    if ability.untimed then
        soundLabel:SetPoint("TOPLEFT", stanceHint, "BOTTOMLEFT", 0, -16)
    else
        local onCooldown = CreateCheckbox(content, L.SHOW_ON_COOLDOWN:format(ability.name),
            abilityKey, "showOnCooldown", stanceHint, -8)
        onCooldown:SetPoint("TOPLEFT", stanceHint, "BOTTOMLEFT", -4, -8)
        soundLabel:SetPoint("TOPLEFT", onCooldown, "BOTTOMLEFT", 4, -16)
    end

    ---------------------------------------------------------------------------
    -- Sound
    ---------------------------------------------------------------------------

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
        customBox.Place()
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

    -- Channel: below the custom sound box when it's showing, otherwise right
    -- under the hint, so the hidden box leaves no gap.
    local channelLabel = Label(content, L.SOUND_CHANNEL)
    local function PlaceChannel()
        channelLabel:ClearAllPoints()
        if customBox:IsShown() then
            channelLabel:SetPoint("TOPLEFT", customBox, "BOTTOMLEFT", 0, -8)
        else
            channelLabel:SetPoint("TOPLEFT", smHint, "BOTTOMLEFT", 0, -16)
        end
    end
    customBox.Place = PlaceChannel
    customBox:SetShown(cfg().sound == "CUSTOM")
    PlaceChannel()

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
        if s.buildExtra then
            -- Extra controls between the checkbox and the size; returns the
            -- last of them, lined up with the size label.
            sizeLabel:SetPoint("TOPLEFT", s.buildExtra(show), "BOTTOMLEFT", 0, -12)
        else
            sizeLabel:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 4, -12)
        end

        -- A size slider (s.range = { min, max }) or a dropdown of set sizes.
        local sizeControl, gap
        if s.range then
            local load
            sizeControl, load = CreateNumberSlider(content, 200, s.range[1], s.range[2],
                function() return cfg()[s.sizeKey] end,
                function(value) cfg()[s.sizeKey] = value; s.applyStyle() end)
            sizeControl:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", -4, -2)
            sizeLoaders[#sizeLoaders + 1] = load
            gap = 64 -- room for the size box on its right
        else
            sizeControl = CreateRadioDropdown(content, 160,
                function() return s.sizes end,
                function() return cfg()[s.sizeKey] end,
                function(value) cfg()[s.sizeKey] = value; s.applyStyle() end)
            sizeControl:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -6)
            menus[#menus + 1] = sizeControl
            gap = 10
        end

        local unlock = CreateButton(content, s.unlockText, 120)
        unlock:SetPoint("LEFT", sizeControl, "RIGHT", gap, 0)
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

        return sizeControl
    end

    local textSizeDD = BuildDisplaySection(channelDD, {
        kind = "text", unlockText = L.UNLOCK_TEXT, lockText = L.LOCK_TEXT, title = L.ONSCREEN_TEXT,
        showLabel = L.SHOW_TEXT:format(ns.AlertText(abilityKey)), showKey = "showText",
        sizeLabel = L.TEXT_SIZE, sizeKey = "textSize", sizes = TEXT_SIZES,
        -- The player's own text in place of "OVERPOWER!" etc.
        buildExtra = function(show)
            local label = Label(content, L.CUSTOM_TEXT)
            label:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 4, -8)
            local box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
            box:SetSize(240, 22)
            box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -4)
            box:SetAutoFocus(false)
            box:SetMaxLetters(ns.CUSTOM_TEXT_MAX)
            local hint = Label(content, L.CUSTOM_TEXT_HINT:format(ability.text), "GameFontDisableSmall")
            hint:SetPoint("LEFT", box, "RIGHT", 10, 0)
            local function ShowLabel() show.label:SetText(L.SHOW_TEXT:format(ns.AlertText(abilityKey))) end
            box:SetScript("OnShow", function(self) self:SetText(cfg().customText or ""); ShowLabel() end)
            box:SetScript("OnTextChanged", function(self, userInput)
                if not userInput then return end
                cfg().customText = self:GetText()
                ns.ApplyTextStyle(abilityKey) -- updates it on screen if it's up
                ShowLabel()
            end)
            box:SetScript("OnEnterPressed", function(self)
                self:ClearFocus()
                if not ns.IsUnlocked(abilityKey, "text") then ns.ShowText(abilityKey) end
            end)
            box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            -- Something lined up with the label, under the box.
            local below = CreateFrame("Frame", nil, content)
            below:SetSize(1, 1)
            below:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, 0)
            return below
        end,
        applyStyle = function() ns.ApplyTextStyle(abilityKey) end,
        preview = function() ns.ShowText(abilityKey) end,
    })

    local iconSizeDD = BuildDisplaySection(textSizeDD, {
        kind = "icon", unlockText = L.UNLOCK_ICON, lockText = L.LOCK_ICON, title = L.SPELL_ICON,
        showLabel = L.SHOW_ICON:format(ability.name, ability.name),
        showKey = "showIcon",
        sizeLabel = L.ICON_SIZE, sizeKey = "iconSize", range = { ns.ICON_SIZE_MIN, ns.ICON_SIZE_MAX },
        applyStyle = function() ns.ApplyIconStyle(abilityKey) end,
        preview = function() ns.ShowIcon(abilityKey) end,
    })

    local glowLabel = Label(content, L.ICON_GLOW)
    glowLabel:SetPoint("TOPLEFT", iconSizeDD, "BOTTOMLEFT", 4, -8)

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

    local noRage = CreateCheckbox(content, L.TINT_NO_RAGE:format(ability.name), abilityKey, "tintNoRage", glowDD, -8)
    noRage:SetPoint("TOPLEFT", glowDD, "BOTTOMLEFT", -4, -8)

    -- Rage threshold: below it the icon is tinted or faded out. A shown icon
    -- re-reads these settings several times a second, so nothing needs applying.
    local rageLabel = Label(content, L.RAGE_THRESHOLD)
    rageLabel:SetPoint("TOPLEFT", noRage, "BOTTOMLEFT", 4, -12)
    local rageSlider, loadRage = CreateNumberSlider(content, 200, 0, 100,
        function() return cfg().rageThreshold end,
        function(value) cfg().rageThreshold = value end)
    rageSlider:SetPoint("TOPLEFT", rageLabel, "BOTTOMLEFT", -4, -2)
    sizeLoaders[#sizeLoaders + 1] = loadRage

    local lookLabel = Label(content, L.RAGE_LOOK)
    lookLabel:SetPoint("TOPLEFT", rageSlider, "BOTTOMLEFT", 4, -12)

    local swatch = CreateFrame("Button", nil, content, "ColorSwatchTemplate")
    local swatchLabel = Label(content, L.RAGE_COLOR, "GameFontHighlight")
    swatchLabel:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
    local function ShowColour()
        local c = cfg().rageColor
        swatch:SetColorRGB(c.r, c.g, c.b)
        local tint = cfg().rageLook == "tint"
        swatch:SetShown(tint)
        swatchLabel:SetShown(tint)
    end
    local function SetColour(r, g, b)
        -- A new table each time, never the saved one changed in place.
        cfg().rageColor = { r = r, g = g, b = b }
        swatch:SetColorRGB(r, g, b)
    end
    swatch:SetScript("OnShow", ShowColour)
    swatch:SetScript("OnClick", function()
        local old = cfg().rageColor
        ColorPickerFrame:SetupColorPickerAndShow({
            r = old.r, g = old.g, b = old.b, hasOpacity = false,
            swatchFunc = function() SetColour(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() SetColour(old.r, old.g, old.b) end,
        })
    end)

    local lookDD = CreateRadioDropdown(content, 160,
        function()
            return { { value = "tint", label = L.RAGE_LOOK_TINT }, { value = "fade", label = L.RAGE_LOOK_FADE } }
        end,
        function() return cfg().rageLook end,
        function(value)
            cfg().rageLook = value
            ShowColour()
        end)
    lookDD:SetPoint("TOPLEFT", lookLabel, "BOTTOMLEFT", 0, -6)
    menus[#menus + 1] = lookDD
    swatch:SetSize(24, 24)
    swatch:SetPoint("LEFT", lookDD, "RIGHT", 12, 0)

    local rageHint = Label(content, L.RAGE_THRESHOLD_HINT, "GameFontDisableSmall")
    rageHint:SetJustifyH("LEFT")
    rageHint:SetPoint("TOPLEFT", lookDD, "BOTTOMLEFT", 0, -10)

    local moveHint = Label(content, L.MOVE_HINT, "GameFontDisableSmall")
    moveHint:SetJustifyH("LEFT")
    moveHint:SetPoint("TOPLEFT", rageHint, "BOTTOMLEFT", 0, -16)

    ---------------------------------------------------------------------------
    -- Icon on the target's nameplate
    ---------------------------------------------------------------------------
    local plateHeader = Label(content, L.NAMEPLATE, "GameFontNormalLarge")
    plateHeader:SetPoint("TOPLEFT", moveHint, "BOTTOMLEFT", 0, -24)

    local onPlate = CreateCheckbox(content, L.ICON_ON_NAMEPLATE,
        abilityKey, "iconOnNameplate", plateHeader, -6)
    onPlate:SetPoint("TOPLEFT", plateHeader, "BOTTOMLEFT", -4, -6)

    -- On the nameplate and at its normal position (or in the group) at once.
    local both = CreateCheckbox(content, L.NAMEPLATE_BOTH, abilityKey, "nameplateBoth", onPlate, 0)

    local sideLabel = Label(content, L.SIDE)
    if abilityKey == "overpower" then
        -- Which mob the opening belongs to is worked out from dodge reports.
        local dodgerNote = Label(content, L.OVERPOWER_NAMEPLATE_NOTE, "GameFontDisableSmall")
        dodgerNote:SetJustifyH("LEFT")
        dodgerNote:SetPoint("TOPLEFT", both, "BOTTOMLEFT", 4, -4)
        sideLabel:SetPoint("TOPLEFT", dodgerNote, "BOTTOMLEFT", 0, -10)
    else
        sideLabel:SetPoint("TOPLEFT", both, "BOTTOMLEFT", 4, -10)
    end
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
    -- Execute has no set length, so nothing to count down.
    local slashHint = Label(content, L.SLASH_HINT, "GameFontDisableSmall")
    slashHint:SetJustifyH("LEFT")
    if ability.untimed then
        slashHint:SetPoint("TOPLEFT", barHint, "BOTTOMLEFT", 0, -24)
    else
        local countdownHeader = Label(content, L.COUNTDOWN, "GameFontNormalLarge")
        countdownHeader:SetPoint("TOPLEFT", barHint, "BOTTOMLEFT", 0, -24)

        local countdown = CreateCheckbox(content, L.SHOW_COUNTDOWN, abilityKey, "showCountdown", countdownHeader, -6)
        countdown:SetPoint("TOPLEFT", countdownHeader, "BOTTOMLEFT", -4, -6)

        slashHint:SetPoint("TOPLEFT", countdown, "BOTTOMLEFT", 4, -20)
    end

    return function()
        customBox:SetShown(cfg().sound == "CUSTOM")
        customBox.Place()
        for _, load in ipairs(sizeLoaders) do load() end
        for _, dd in ipairs(menus) do dd:GenerateMenu() end
        RefreshSoundText()
        ShowColour()
    end
end

--------------------------------------------------------------------------------
-- The profile dialog: one small window for naming a profile, confirming a
-- delete or reset, and showing or pasting an export string.
--------------------------------------------------------------------------------

local dialog

local function BuildDialog()
    local d = CreateFrame("Frame", "OverpowerAlertProfileDialog", UIParent)
    d:SetSize(420, 200)
    d:SetPoint("CENTER", 0, 80)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetToplevel(true)
    d:EnableMouse(true) -- clicks don't fall through to the options window
    d:Hide()

    local border = d:CreateTexture(nil, "BACKGROUND", nil, -1)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetColorTexture(0.6, 0.5, 0.2, 1)
    local bg = d:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.06, 0.97)

    d.title = Label(d, "", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", 16, -14)
    d.title:SetPoint("RIGHT", -16, 0)
    d.title:SetJustifyH("LEFT")

    d.message = Label(d, "", "GameFontHighlight")
    d.message:SetJustifyH("LEFT")
    d.message:SetWidth(388)

    d.nameLabel = Label(d, L.PROFILE_NAME)
    d.name = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    d.name:SetSize(260, 22)
    d.name:SetAutoFocus(false)
    d.name:SetMaxLetters(ns.PROFILE_NAME_MAX)

    -- The export string, or where an import is pasted.
    d.scroll = CreateFrame("ScrollFrame", nil, d, "UIPanelScrollFrameTemplate")
    d.scroll:SetSize(362, 120)
    d.body = CreateFrame("EditBox", nil, d.scroll)
    d.body:SetMultiLine(true)
    d.body:SetAutoFocus(false)
    d.body:SetFontObject(ChatFontNormal)
    d.body:SetWidth(362)
    d.scroll:SetScrollChild(d.body)
    local bodyBg = d:CreateTexture(nil, "ARTWORK")
    bodyBg:SetPoint("TOPLEFT", d.scroll, -4, 4)
    bodyBg:SetPoint("BOTTOMRIGHT", d.scroll, 4, -4)
    bodyBg:SetColorTexture(0, 0, 0, 0.6)
    d.bodyBg = bodyBg

    d.error = Label(d, "", "GameFontNormal")
    d.error:SetTextColor(1, 0.25, 0.25)
    d.error:SetJustifyH("LEFT")
    d.error:SetWidth(388)

    d.ok = CreateButton(d, OKAY or "OK", 100)
    d.ok:SetPoint("BOTTOMRIGHT", -124, 14)
    d.cancel = CreateButton(d, CANCEL or "Cancel", 100)
    d.cancel:SetPoint("BOTTOMRIGHT", -16, 14)
    d.cancel:SetScript("OnClick", function() d:Hide() end)

    local function Confirm()
        if not d.onOK then d:Hide(); return end
        local ok, reason = d.onOK(d.name:GetText(), d.body:GetText())
        if ok then
            d:Hide()
        else
            d.error:SetText(reason or "")
            d.error:Show()
            d:Layout()
        end
    end
    d.ok:SetScript("OnClick", Confirm)
    d.name:SetScript("OnEnterPressed", Confirm)
    for _, box in ipairs({ d.name, d.body }) do
        box:SetScript("OnEscapePressed", function() d:Hide() end)
    end
    d.name:SetScript("OnTextChanged", function(_, userInput)
        if userInput then d.nameTyped = true end
    end)
    d.body:SetScript("OnTextChanged", function(self, userInput)
        if userInput and d.onBodyChanged then d.onBodyChanged(self:GetText()) end
    end)

    -- Stacks the parts in use and sizes the window to fit them.
    function d:Layout()
        local anchor, height = self.title, 14 + self.title:GetStringHeight()
        local function Place(region, gap, x)
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, -gap)
            anchor = region
        end
        if self.message:GetText() ~= "" then
            Place(self.message, 10)
            height = height + 10 + self.message:GetStringHeight()
        end
        if self.scroll:IsShown() then
            Place(self.scroll, 14, 4)
            height = height + 14 + 120
        end
        if self.name:IsShown() then
            Place(self.nameLabel, 14, self.scroll:IsShown() and -4 or 0)
            Place(self.name, 4, 6)
            height = height + 14 + self.nameLabel:GetStringHeight() + 4 + 22
        end
        if self.error:IsShown() then
            Place(self.error, 10, self.name:IsShown() and -6 or 0)
            height = height + 10 + self.error:GetStringHeight()
        end
        self:SetHeight(height + 14 + 24 + 14)
    end
    return d
end

-- Opens the dialog. `opts`: title, message, name (pre-filled; nil hides the
-- box), body (shows the text box; a string pre-fills it), okText, onOK(name,
-- body) returning true or nil and a reason, onBodyChanged(body), noCancel.
local function OpenDialog(opts)
    dialog = dialog or BuildDialog()
    local d = dialog
    d.title:SetText(opts.title or "")
    d.message:SetText(opts.message or "")
    d.error:SetText("")
    d.error:Hide()
    d.nameTyped = false
    d.name:SetShown(opts.name ~= nil)
    d.nameLabel:SetShown(opts.name ~= nil)
    d.name:SetText(opts.name or "")
    d.scroll:SetShown(opts.body ~= nil)
    d.bodyBg:SetShown(opts.body ~= nil)
    d.body:SetText(type(opts.body) == "string" and opts.body or "")
    d.ok:SetText(opts.okText or OKAY or "OK")
    d.cancel:SetShown(not opts.noCancel)
    d.ok:ClearAllPoints()
    d.ok:SetPoint("BOTTOMRIGHT", opts.noCancel and -16 or -124, 14)
    d.onOK = opts.onOK
    d.onBodyChanged = opts.onBodyChanged
    d:Layout()
    d:Show()
    if opts.body ~= nil then
        d.body:SetFocus()
        d.body:HighlightText()
    elseif opts.name ~= nil then
        d.name:SetFocus()
        d.name:HighlightText()
    end
end

--------------------------------------------------------------------------------
-- The General page: settings shared by every ability. Returns its refresher.
--------------------------------------------------------------------------------

local function BuildGeneralPage(content)
    local desc = Label(content, L.GENERAL_DESCRIPTION, "GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
    desc:SetPoint("TOPLEFT", 16, -8)

    ---------------------------------------------------------------------------
    -- Profiles: every setting on every tab, saved under a name. Shared by all
    -- the account's characters; each character uses the one chosen here.
    ---------------------------------------------------------------------------
    local profileLabel = Label(content, L.PROFILE)
    profileLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)

    local function ProfileOptions()
        local list = {}
        for _, name in ipairs(ns.ProfileNames()) do list[#list + 1] = { value = name, label = name } end
        return list
    end
    local profileDD = CreateRadioDropdown(content, 220, ProfileOptions,
        function() return ns.ActiveProfileName() end,
        function(name) ns.SetProfile(name) end)
    profileDD:SetPoint("TOPLEFT", profileLabel, "BOTTOMLEFT", 0, -6)

    local newB = CreateButton(content, L.PROFILE_NEW, 78)
    newB:SetPoint("LEFT", profileDD, "RIGHT", 10, 0)
    local copyB = CreateButton(content, L.PROFILE_COPY, 78)
    copyB:SetPoint("LEFT", newB, "RIGHT", 4, 0)
    local renameB = CreateButton(content, L.PROFILE_RENAME, 78)
    renameB:SetPoint("LEFT", copyB, "RIGHT", 4, 0)
    local deleteB = CreateButton(content, L.PROFILE_DELETE, 78)
    deleteB:SetPoint("LEFT", renameB, "RIGHT", 4, 0)

    local resetB = CreateButton(content, L.PROFILE_RESET, 120)
    resetB:SetPoint("TOPLEFT", profileDD, "BOTTOMLEFT", 0, -8)
    local exportB = CreateButton(content, L.PROFILE_EXPORT, 90)
    exportB:SetPoint("LEFT", resetB, "RIGHT", 4, 0)
    local importB = CreateButton(content, L.PROFILE_IMPORT, 90)
    importB:SetPoint("LEFT", exportB, "RIGHT", 4, 0)

    local profileHint = Label(content, L.PROFILE_HINT, "GameFontDisableSmall")
    profileHint:SetJustifyH("LEFT")
    profileHint:SetPoint("TOPLEFT", resetB, "BOTTOMLEFT", 0, -8)

    newB:SetScript("OnClick", function()
        OpenDialog({ title = L.PROFILE_NEW_TITLE, name = "", onOK = function(name) return ns.NewProfile(name) end })
    end)
    copyB:SetScript("OnClick", function()
        local current = ns.ActiveProfileName()
        OpenDialog({
            title = L.PROFILE_COPY_TITLE:format(current),
            name = L.PROFILE_COPY_NAME:format(current):sub(1, ns.PROFILE_NAME_MAX),
            onOK = function(name) return ns.CopyProfile(name) end,
        })
    end)
    renameB:SetScript("OnClick", function()
        local current = ns.ActiveProfileName()
        OpenDialog({
            title = L.PROFILE_RENAME_TITLE:format(current), name = current,
            onOK = function(name) return ns.RenameProfile(current, name) end,
        })
    end)
    deleteB:SetScript("OnClick", function()
        local current = ns.ActiveProfileName()
        OpenDialog({
            title = L.PROFILE_DELETE_TITLE, message = L.PROFILE_DELETE_CONFIRM:format(current),
            okText = L.PROFILE_DELETE, onOK = function() return ns.DeleteProfile(current) end,
        })
    end)
    resetB:SetScript("OnClick", function()
        local current = ns.ActiveProfileName()
        OpenDialog({
            title = L.PROFILE_RESET_TITLE, message = L.PROFILE_RESET_CONFIRM:format(current),
            okText = L.PROFILE_RESET, onOK = function() return ns.ResetProfile() end,
        })
    end)
    exportB:SetScript("OnClick", function()
        local text, reason = ns.ExportProfile()
        OpenDialog({
            title = L.PROFILE_EXPORT_TITLE:format(ns.ActiveProfileName()),
            message = text and L.PROFILE_EXPORT_HINT or reason,
            body = text or "", okText = CLOSE or "Close", noCancel = true,
        })
    end)
    importB:SetScript("OnClick", function()
        OpenDialog({
            title = L.PROFILE_IMPORT_TITLE, message = L.PROFILE_IMPORT_HINT, body = true, name = "",
            okText = L.PROFILE_IMPORT,
            -- Offer the name in the string, unless the player typed their own.
            onBodyChanged = function(body)
                if not dialog.nameTyped then dialog.name:SetText(ns.ImportName(body) or "") end
            end,
            onOK = function(name, body) return ns.ImportProfile(body, name) end,
        })
    end)

    ---------------------------------------------------------------------------
    -- Talent sets: a profile for primary and one for secondary talents
    ---------------------------------------------------------------------------
    local specLabel = Label(content, L.TALENT_SETS)
    specLabel:SetPoint("TOPLEFT", Divider(content, profileHint, 14), "BOTTOMLEFT", 0, -14)

    -- The talent set the player is on now, whether or not it's turned on.
    local currentSet = Label(content, "", "GameFontHighlight")
    currentSet:SetPoint("LEFT", specLabel, "RIGHT", 12, 0)
    function ns.RefreshCurrentSet()
        local group = ns.ActiveSpecGroup()
        currentSet:SetText(group and L.CURRENT_SET:format(group == 2 and L.SET_SECONDARY or L.SET_PRIMARY) or "")
    end

    local perSpec = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    perSpec:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", -4, -4)
    local perSpecText = perSpec.Text or perSpec:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    perSpecText:SetPoint("LEFT", perSpec, "RIGHT", 4, 1)
    perSpecText:SetText(L.PER_SPEC)
    perSpec:SetScript("OnClick", function(self) ns.SetPerSpec(self:GetChecked()) end)

    -- Each set's profile, usable while the option is on.
    local setDDs = {}
    local prev
    for group = 1, 2 do
        local label = Label(content, group == 1 and L.SET_PRIMARY or L.SET_SECONDARY, "GameFontHighlightSmall")
        if prev then
            label:SetPoint("LEFT", prev, "RIGHT", 20, 0)
        else
            label:SetPoint("TOPLEFT", perSpec, "BOTTOMLEFT", 4, -6)
        end
        local dd = CreateRadioDropdown(content, 200, ProfileOptions,
            function() return ns.SpecProfile(group) end,
            function(name) ns.SetSpecProfile(group, name) end)
        dd:SetPoint("LEFT", label, "RIGHT", 8, 0)
        setDDs[group] = dd
        prev = dd
    end

    local specHint = Label(content, L.PER_SPEC_HINT, "GameFontDisableSmall")
    specHint:SetJustifyH("LEFT")
    specHint:SetPoint("TOPLEFT", perSpec, "BOTTOMLEFT", 4, -40)

    local function RefreshProfiles()
        local isDefault = ns.ActiveProfileName() == ns.DEFAULT_PROFILE
        renameB:SetEnabled(not isDefault)
        deleteB:SetEnabled(not isDefault)
        local canShare = C_EncodingUtil ~= nil
        exportB:SetEnabled(canShare)
        importB:SetEnabled(canShare)
        -- With the talent-set option on, the profile chosen at the top is the
        -- current talent set's.
        local on = ns.PerSpec()
        profileLabel:SetText(on and L.PROFILE_FOR_SET:format(ns.SpecName(ns.ActiveSpecGroup() or 1)) or L.PROFILE)
        perSpec:SetChecked(on)
        profileDD:GenerateMenu()
        for _, dd in ipairs(setDDs) do
            dd:SetEnabled(on)
            dd:GenerateMenu()
        end
        ns.RefreshCurrentSet()
    end

    ---------------------------------------------------------------------------
    -- Only show alerts in combat
    ---------------------------------------------------------------------------
    local combatOnly = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    combatOnly:SetPoint("TOPLEFT", Divider(content, specHint, 14), "BOTTOMLEFT", -4, -8)
    local combatOnlyText = combatOnly.Text or combatOnly:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    combatOnlyText:SetPoint("LEFT", combatOnly, "RIGHT", 4, 1)
    combatOnlyText:SetText(L.COMBAT_ONLY)
    combatOnly:SetScript("OnShow", function(self) self:SetChecked(ns.General().combatOnly) end)
    combatOnly:SetScript("OnClick", function(self) ns.SetCombatOnly(self:GetChecked()) end)
    local combatOnlyHint = Label(content, L.COMBAT_ONLY_HINT, "GameFontDisableSmall")
    combatOnlyHint:SetJustifyH("LEFT")
    combatOnlyHint:SetPoint("TOPLEFT", combatOnly, "BOTTOMLEFT", 4, -2)

    local fontLabel = Label(content, L.FONT)
    fontLabel:SetPoint("TOPLEFT", Divider(content, combatOnlyHint, 14), "BOTTOMLEFT", 0, -14)

    local fontDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    fontDD:SetWidth(240)
    fontDD:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -6)

    -- A sample in the chosen font, as it shows on screen.
    local sample = content:CreateFontString(nil, "OVERLAY")
    sample:SetTextColor(1, 0.4, 0.1)
    sample:SetWordWrap(false) -- one line, whatever the font's width

    local function Refresh()
        ns.SetFont(sample, 28, "THICKOUTLINE")
        sample:SetText(L.FONT_SAMPLE)
    end

    local function IsFont(name) return ns.General().font == name end
    local function SetFontChoice(name)
        ns.General().font = name
        ns.ApplyFont()
        Refresh()
    end

    fontDD:SetupMenu(function(_, root)
        -- The list can be long with font packs installed.
        if root.SetScrollMode then root:SetScrollMode(MENU_MAX_HEIGHT) end
        root:CreateRadio(L.FONT_DEFAULT, IsFont, SetFontChoice, "DEFAULT")
        root:CreateDivider()
        for _, name in ipairs(ns.GetSharedMediaFonts()) do
            root:CreateRadio(name, IsFont, SetFontChoice, name)
        end
    end)

    local hint = Label(content, L.FONT_HINT, "GameFontDisableSmall")
    hint:SetJustifyH("LEFT")
    hint:SetPoint("TOPLEFT", fontDD, "BOTTOMLEFT", 0, -6)

    sample:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    Refresh()

    ---------------------------------------------------------------------------
    -- Icon positions: separate, or grouped and growing from one spot
    ---------------------------------------------------------------------------
    local general = ns.General
    local layoutLabel = Label(content, L.ICON_LAYOUT)
    layoutLabel:SetPoint("TOPLEFT", Divider(content, sample, 20), "BOTTOMLEFT", 0, -14)

    local growDD, spacingBox, unlock, reset
    local function RefreshGroupControls()
        local grouped = general().iconLayout == "group"
        growDD:SetEnabled(grouped)
        spacingBox:SetEnabled(grouped)
        unlock:SetEnabled(grouped)
        reset:SetEnabled(grouped)
    end

    local layoutDD = CreateRadioDropdown(content, 320,
        function() return ICON_LAYOUTS end,
        function() return general().iconLayout end,
        function(value)
            ns.SetIconLayout(value)
            RefreshGroupControls()
        end)
    layoutDD:SetPoint("TOPLEFT", layoutLabel, "BOTTOMLEFT", 0, -6)

    local growLabel = Label(content, L.GROUP_GROW)
    growLabel:SetPoint("TOPLEFT", layoutDD, "BOTTOMLEFT", 0, -12)
    growDD = CreateRadioDropdown(content, 160,
        function() return GROUP_GROWS end,
        function() return general().groupGrow end,
        function(value)
            general().groupGrow = value
            ns.LayoutGroup()
        end)
    growDD:SetPoint("TOPLEFT", growLabel, "BOTTOMLEFT", 0, -6)

    local spacingLabel = Label(content, L.GROUP_SPACING)
    spacingLabel:SetPoint("LEFT", growLabel, "LEFT", 180, 0)
    spacingBox = CreateNumberBox(content, "general", "groupSpacing", ns.LayoutGroup)
    spacingBox:SetPoint("TOPLEFT", spacingLabel, "BOTTOMLEFT", 6, -6)

    unlock = CreateButton(content, L.UNLOCK_GROUP, 120)
    unlock:SetPoint("TOPLEFT", growDD, "BOTTOMLEFT", 0, -12)
    unlock:SetScript("OnClick", function()
        ns.SetUnlocked(nil, "icon", not ns.IsUnlocked(nil, "icon"))
    end)
    unlockButtons["general/icon"] = { button = unlock, unlockText = L.UNLOCK_GROUP, lockText = L.LOCK_GROUP }

    reset = CreateButton(content, L.RESET_POSITION, 120)
    reset:SetPoint("LEFT", unlock, "RIGHT", 6, 0)
    reset:SetScript("OnClick", function() ns.ResetPosition(nil, "icon") end)

    local groupHint = Label(content, L.GROUP_HINT, "GameFontDisableSmall")
    groupHint:SetJustifyH("LEFT")
    groupHint:SetPoint("TOPLEFT", unlock, "BOTTOMLEFT", 0, -10)

    return function()
        combatOnly:SetChecked(ns.General().combatOnly)
        RefreshProfiles()
        fontDD:GenerateMenu()
        layoutDD:GenerateMenu()
        growDD:GenerateMenu()
        RefreshGroupControls()
        Refresh()
    end
end

--------------------------------------------------------------------------------
-- Panel with a General tab, then one tab per ability
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
    local GENERAL = "general"
    local selected = GENERAL

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
    -- Adds a tab and its scrolling page; returns the page's content frame.
    local function AddTab(key, text, height)
        local tab = CreateTab(panel, text)
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
            divider:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", -4, 0)
            divider:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
        end
        tab:SetScript("OnClick", function() SelectTab(key) end)
        tabs[key] = tab
        prevTab = tab

        -- Each page scrolls, since it can be taller than the settings window.
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOP", divider, "BOTTOM", 0, -4)
        scroll:SetPoint("LEFT", panel, "LEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -28, 4)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(600, height)
        scroll:SetScrollChild(content)
        scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)
        scroll:Hide()
        pages[key] = scroll
        return content
    end

    refreshers[GENERAL] = BuildGeneralPage(AddTab(GENERAL, L.GENERAL, 820))
    for _, ability in ipairs(ns.ABILITIES) do
        refreshers[ability.key] = BuildAbilityPage(AddTab(ability.key, ability.name, 1680), ability)
    end

    panel:SetScript("OnShow", function() SelectTab(selected) end)

    -- Every setting changed at once (a talent set swap): reload the page
    -- being shown. Hiding it first makes its checkboxes re-read on show.
    function ns.RefreshOptions()
        if not panel:IsVisible() then return end
        pages[selected]:Hide()
        SelectTab(selected)
    end

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
