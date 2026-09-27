local ADDON_NAME, ns = ...

-- Overpower ranks, highest first. The highest known rank is watched.
local OVERPOWER_IDS = { 11585, 11584, 7887, 7384 }

local DEFAULTS = {
    enabled = true,
    sound = "RAID_WARNING",
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

-- Built-in game sounds, keyed by SOUNDKIT name (played with PlaySound).
-- Keys that don't exist on this client are dropped at load.
local GAME_SOUNDS = {
    { "RAID_WARNING",                           "Raid Warning" },
    { "RAID_BOSS_EMOTE_WARNING",                "Boss Emote Warning" },
    { "UI_RAID_BOSS_WHISPER_WARNING",           "Boss Whisper Warning" },
    { "READY_CHECK",                            "Ready Check" },
    { "ALARM_CLOCK_WARNING_1",                  "Alarm Clock 1" },
    { "ALARM_CLOCK_WARNING_2",                  "Alarm Clock 2" },
    { "ALARM_CLOCK_WARNING_3",                  "Alarm Clock 3" },
    { "PVP_THROUGH_QUEUE",                      "PvP Queue Ready" },
    { "IG_PVP_UPDATE",                          "PvP Update" },
    { "MAP_PING",                               "Map Ping" },
    { "TELL_MESSAGE",                           "Whisper" },
    { "UI_BNET_TOAST",                          "Battle.net Toast" },
    { "IG_PLAYER_INVITE",                       "Group Invite" },
    { "LFG_REWARDS",                            "Dungeon Rewards" },
    { "IG_QUEST_LIST_COMPLETE",                 "Quest Complete" },
    { "IG_QUEST_LIST_OPEN",                     "Quest Open" },
    { "LEVELUP",                                "Level Up" },
    { "ACHIEVEMENT_MENU_OPEN",                  "Achievement Menu" },
    { "AUCTION_WINDOW_OPEN",                    "Auction Open" },
    { "AUCTION_WINDOW_CLOSE",                   "Auction Close" },
    { "LOOT_WINDOW_COIN_SOUND",                 "Coin Loot" },
    { "IG_MAINMENU_OPEN",                       "Menu Open" },
    { "IG_MAINMENU_OPTION_CHECKBOX_ON",         "Checkbox Click" },
    { "IG_SPELLBOOK_OPEN",                      "Spellbook Open" },
    { "IG_CHARACTER_INFO_TAB",                  "Tab Click" },
    { "IG_BACKPACK_OPEN",                       "Backpack Open" },
    { "IG_ABILITY_ICON_DROP",                   "Ability Drop" },
    { "PUT_DOWN_SMALL_CHAIN",                   "Chain" },
    { "GS_TITLE_OPTION_OK",                     "Menu OK" },
    { "UI_WORLDQUEST_START",                    "World Quest Start" },
    { "UI_WORLDQUEST_COMPLETE",                 "World Quest Complete" },
    { "UI_EPICLOOT_TOAST",                      "Epic Loot Toast" },
    { "UI_LEGENDARY_LOOT_TOAST",                "Legendary Loot Toast" },
    { "UI_BONUS_LOOT_ROLL_END",                 "Bonus Roll" },
    { "UI_GARRISON_TOAST_MISSION_COMPLETE",     "Mission Complete Toast" },
    { "UI_ORDERHALL_TALENT_READY_TOAST",        "Talent Ready Toast" },
    { "UI_PET_BATTLE_START",                    "Pet Battle Start" },
    { "UI_71_SOCIAL_QUEUEING_TOAST",            "Social Queue Toast" },
    { "UI_IG_STORE_PURCHASE_DELIVERED_TOAST_01","Store Delivery Toast" },
}

-- Sound keys:
--   "<SOUNDKIT name>"  built-in game sound
--   "sm:<name>"        LibSharedMedia sound (BigWigs, SharedMedia packs, etc.)
--   "CUSTOM"           user-entered path or FileDataID
ns.GAME_SOUNDS = {}
for _, s in ipairs(GAME_SOUNDS) do
    if SOUNDKIT and SOUNDKIT[s[1]] then
        ns.GAME_SOUNDS[#ns.GAME_SOUNDS + 1] = { key = s[1], label = s[2] }
    end
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
    for _, s in ipairs(ns.GAME_SOUNDS) do
        if s.key == key then return s.label end
    end
    return key or "?"
end

function ns.PlayAlertSound(key)
    local db = OverpowerAlertDB
    key = key or db.sound
    local channel = db.channel or "Master"

    local smName = key:match("^sm:(.+)")
    if smName then
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
    elseif SOUNDKIT and SOUNDKIT[key] then
        PlaySound(SOUNDKIT[key], channel, true)
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
        -- 1.0 used short aliases for sound keys; map them to SOUNDKIT names.
        local renamed = {
            ALARM_CLOCK = "ALARM_CLOCK_WARNING_3", PVP_QUEUE = "PVP_THROUGH_QUEUE",
            PLAYER_INVITE = "IG_PLAYER_INVITE", QUEST_COMPLETE = "IG_QUEST_LIST_COMPLETE",
            LEVEL_UP = "LEVELUP", AUCTION_OPEN = "AUCTION_WINDOW_OPEN",
            LOOT_COIN = "LOOT_WINDOW_COIN_SOUND",
        }
        local db = OverpowerAlertDB
        db.sound = renamed[db.sound] or db.sound
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
