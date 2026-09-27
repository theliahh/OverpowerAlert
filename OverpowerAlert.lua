local ADDON_NAME, ns = ...

-- Overpower ranks, highest first. The highest known rank is watched.
local OVERPOWER_IDS = { 11585, 11584, 7887, 7384 }

-- Warhorn, from the Instruments category.
local DEFAULT_SOUND = "cdm:316723"

local DEFAULTS = {
    enabled = true,
    sound = DEFAULT_SOUND,
    customSound = "",
    channel = "Master",
    showText = true,
    anyStance = false,
    throttle = 1.0,
    textSize = 36,
    textPos = nil, -- { point, relPoint, x, y }; nil = default spot
}

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
ns.LSM = LSM

-- The sound alert list from Blizzard's Cooldown Manager
-- (Blizzard_CooldownViewer/CooldownViewerSoundAlertData.lua), in the same
-- categories and order. Entries are { soundKitID, name }.
ns.CDM_SOUNDS = {
    { "Animals", {
        { 316401, "Cat" },
        { 316406, "Chicken" },
        { 316407, "Cow" },
        { 316409, "Gnoll" },
        { 316715, "Goat" },
        { 316411, "Lion" },
        { 316412, "Panther" },
        { 316413, "Rattlesnake" },
        { 316414, "Sheep" },
        { 316415, "Wolf" },
    } },
    { "Devices", {
        { 316442, "Boat Horn" },
        { 316436, "Air Horn" },
        { 316713, "Bike Horn" },
        { 316446, "Cash Register" },
        { 316717, "Jackpot Bell" },
        { 316718, "Jackpot Coins" },
        { 316719, "Jackpot Fail" },
        { 316433, "Rotary Phone Dial" },
        { 316492, "Rotary Phone Ring" },
        { 316425, "Stove Pipe" },
        { 316430, "Trashcan Lid" },
    } },
    { "Impacts", {
        { 316528, "Anvil Strike" },
        { 316419, "Bubble Smash" },
        { 316531, "Low Thud" },
        { 316532, "Metal Clanks" },
        { 316486, "Metal Rattle" },
        { 316484, "Metal Scrape" },
        { 316536, "Metal Warble" },
        { 316434, "Pop Click" },
        { 316453, "Strange Clang" },
        { 316535, "Sword Scrape" },
    } },
    { "Instruments", {
        { 316493, "Bell Ring" },
        { 316712, "Bell Trill" },
        { 316722, "Brass" },
        { 316447, "Chime Ascending" },
        { 316477, "Guitar Chug" },
        { 316482, "Guitar Pinch" },
        { 316509, "Pitch Pipe Distressed" },
        { 316501, "Pitch Pipe Note" },
        { 316540, "Synth Big" },
        { 316476, "Synth Buzz" },
        { 316460, "Synth High" },
        { 316723, "Warhorn" },
    } },
    { "Short", {
        { 353392, "Bell Strike" },
        { 353387, "Bell Tree" },
        { 353388, "Big Pot" },
        { 353389, "Blades" },
        { 353424, "Coffee Mug" },
        { 353393, "Cow Bell" },
        { 353395, "Finger Snap" },
        { 353404, "Guitar" },
        { 353405, "Kalimba" },
        { 353406, "Metal Blade Drop" },
        { 353407, "Metal Blade On Rod" },
        { 353408, "Metal Impact" },
        { 353410, "Mini Wood Xylophone" },
        { 353425, "Paper Cup" },
        { 353417, "Sheet Metal" },
        { 353419, "Stove Pipe" },
        { 353420, "Stove Pipe Blade" },
        { 353421, "Sword Shing" },
        { 353402, "Synth Bleep" },
        { 353400, "Synth Blurp" },
        { 353397, "Synth Error" },
        { 353399, "Synth High" },
        { 353423, "Triangle" },
        { 353426, "Water Drop" },
        { 353427, "Wine Bottle" },
        { 353428, "Wood Xylophone" },
    } },
    { "Warcraft II", {
        { 316731, "Abstract Whoosh" },
        { 316733, "Choir" },
        { 316735, "Construction" },
        { 316736, "Magic Chimes" },
        { 316745, "Pig Squeal" },
        { 316738, "Saws" },
        { 316746, "Seal" },
        { 316748, "Slow" },
        { 316749, "Smith" },
        { 316739, "Synth Stinger" },
        { 316740, "Trumpet Rally" },
        { 316737, "Zippy Magic" },
    } },
    { "Warcraft III", {
        { 316773, "Bell" },
        { 316774, "Crunchy Bell" },
        { 316768, "Drum Splash" },
        { 316775, "Error" },
        { 316769, "Fanfare" },
        { 316776, "Gate Open" },
        { 316770, "Gold" },
        { 316778, "Magic Shimmer" },
        { 316771, "Ringout" },
        { 316765, "Rooster" },
        { 316779, "Shimmer Bell" },
        { 316766, "Wolf Howl" },
    } },
}

-- Sound keys:
--   "cdm:<soundKitID>"  Cooldown Manager sound
--   "sm:<name>"         LibSharedMedia sound (BigWigs, SharedMedia packs, etc.)
--   "CUSTOM"            user-entered path or FileDataID
local cdmLabels = {}
for _, category in ipairs(ns.CDM_SOUNDS) do
    for _, s in ipairs(category[2]) do
        cdmLabels["cdm:" .. s[1]] = s[2]
    end
end

function ns.IsValidSoundKey(key)
    return type(key) == "string"
        and (cdmLabels[key] ~= nil or key:find("^sm:") ~= nil or key == "CUSTOM")
end

-- Every sound registered with LibSharedMedia, sorted, excluding "None".
-- Rebuilt each time the menu opens, since other addons may register late.
function ns.GetSharedMediaSounds()
    local list = {}
    if not LSM then return list end
    for _, name in ipairs(LSM:List("sound")) do
        if name ~= "None" then
            list[#list + 1] = { key = "sm:" .. name, label = name }
        end
    end
    return list
end

function ns.GetSoundLabel(key)
    if key == "CUSTOM" then return "Custom" end
    local smName = key and key:match("^sm:(.+)")
    if smName then return smName end
    return cdmLabels[key] or key or "?"
end

function ns.PlayAlertSound(key)
    local db = OverpowerAlertDB
    key = key or db.sound
    local channel = db.channel or "Master"

    local kitID = tonumber(key:match("^cdm:(%d+)$"))
    local smName = key:match("^sm:(.+)")
    if kitID then
        PlaySound(kitID, channel, true)
    elseif smName then
        local value = LSM and LSM:Fetch("sound", smName, true)
        -- LSM sounds are a file path/FileDataID, or occasionally a SoundKit ID.
        if type(value) == "string" then
            PlaySoundFile(value, channel)
        elseif type(value) == "number" and value > 1 then
            if not PlaySoundFile(value, channel) then PlaySound(value, channel, true) end
        end
    elseif key == "CUSTOM" then
        local custom = strtrim(db.customSound or "")
        if custom ~= "" then
            PlaySoundFile(tonumber(custom) or custom, channel)
        end
    end
end

--------------------------------------------------------------------------------
-- Detection
--
-- The combat log isn't available to addons on this client, so we watch
-- Overpower's usability instead: it's a reactive ability that only becomes
-- usable for a few seconds after the target dodges. We alert on the
-- not-usable -> usable transition.
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local overpowerID
local wasUsable = false
local lastAlert = 0
local ticker

local function IsKnown(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function FindOverpower()
    for _, id in ipairs(OVERPOWER_IDS) do
        if IsKnown(id) then return id end
    end
end

local function IsOverpowerUsable()
    if not overpowerID then return false end
    local usable, noPower
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noPower = C_Spell.IsSpellUsable(overpowerID)
    elseif IsUsableSpell then
        usable, noPower = IsUsableSpell(overpowerID)
    end
    -- Treat "usable except for rage" as available too; you'll have 5 rage
    -- by the time you react.
    return usable == true or noPower == true
end

local function Alert()
    local now = GetTime()
    if now - lastAlert < (OverpowerAlertDB.throttle or 1) then return end
    lastAlert = now
    ns.PlayAlertSound()
    if OverpowerAlertDB.showText and ns.ShowText then ns.ShowText() end
end

local function Check()
    if not OverpowerAlertDB.enabled then return end
    local usable = IsOverpowerUsable()
    if usable and not wasUsable then Alert() end
    wasUsable = usable
end
ns.Check = Check

local function StartTicker()
    if not ticker then ticker = C_Timer.NewTicker(0.1, Check) end
end

local function StopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
end

local function Refresh()
    overpowerID = FindOverpower()
    wasUsable = IsOverpowerUsable()
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        OverpowerAlertDB = OverpowerAlertDB or {}
        for k, v in pairs(DEFAULTS) do
            if OverpowerAlertDB[k] == nil then OverpowerAlertDB[k] = v end
        end
        -- Older versions offered a different built-in list (SOUNDKIT names);
        -- move those selections to the default.
        local db = OverpowerAlertDB
        if not ns.IsValidSoundKey(db.sound) then db.sound = DEFAULT_SOUND end
        if ns.InitDisplay then ns.InitDisplay() end
        if ns.CreateOptions then ns.CreateOptions() end
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        if class ~= "WARRIOR" then return end
        Refresh()
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("SPELL_UPDATE_USABLE")
        self:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        pcall(self.RegisterUnitEvent, self, "UNIT_COMBAT", "target")
        if InCombatLockdown() then StartTicker() end
        return
    end

    if event == "SPELLS_CHANGED" then
        Refresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Usability events can lag; poll lightly while in combat as a backstop.
        StartTicker()
    elseif event == "PLAYER_REGEN_ENABLED" then
        StopTicker()
        wasUsable = IsOverpowerUsable()
    elseif event == "UNIT_COMBAT" then
        -- Optional: alert on any target dodge even outside Battle Stance,
        -- where Overpower itself won't report usable.
        if not (OverpowerAlertDB.enabled and OverpowerAlertDB.anyStance) then return end
        local _, action = ...
        if issecretvalue and issecretvalue(action) then return end
        if action == "DODGE" then Alert() end
    else
        Check()
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

SLASH_OVERPOWERALERT1 = "/opa"
SLASH_OVERPOWERALERT2 = "/overpoweralert"
SlashCmdList.OVERPOWERALERT = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "test" then
        ns.PlayAlertSound()
    elseif msg == "toggle" then
        OverpowerAlertDB.enabled = not OverpowerAlertDB.enabled
        print("|cffff6619Overpower Alert|r " .. (OverpowerAlertDB.enabled and "enabled" or "disabled"))
    elseif msg == "unlock" or msg == "move" then
        ns.SetTextUnlocked(true)
    elseif msg == "lock" then
        ns.SetTextUnlocked(false)
    elseif ns.OpenOptions then
        ns.OpenOptions()
    end
end
