local ADDON_NAME, ns = ...
local L = ns.L -- all text lives in Strings.lua

-- Reactive abilities we alert on. Each has its own settings table in
-- OverpowerAlertDB[key]. Spell IDs are listed highest rank first; the highest
-- known rank is watched.
ns.ABILITIES = {
    {
        key = "overpower", name = L.OVERPOWER,
        ids = { 11585, 11584, 7887, 7384 },
        text = L.OVERPOWER_ALERT_TEXT, color = { 1, 0.4, 0.1 },
        icon = "Interface\\Icons\\Ability_MeleeDamage",
        description = L.OVERPOWER_DESCRIPTION,
        defaults = {
            sound = "cdm:316723", -- Warhorn
            stances = { battle = true, defensive = false, berserker = false },
            textY = 180, iconX = 0, iconY = 100,
        },
    },
    {
        key = "revenge", name = L.REVENGE,
        ids = { 25288, 11601, 11600, 7379, 6574, 6572 },
        text = L.REVENGE_ALERT_TEXT, color = { 1, 0.82, 0 },
        icon = "Interface\\Icons\\Ability_Warrior_Revenge",
        description = L.REVENGE_DESCRIPTION,
        defaults = {
            sound = "cdm:353421", -- Sword Shing
            stances = { battle = false, defensive = true, berserker = false },
            textY = 240, iconX = 80, iconY = 100,
        },
    },
    {
        key = "victoryrush", name = L.VICTORY_RUSH,
        ids = { 402927, 34428 }, -- Forever (rune version), then other game versions
        duration = 20, -- after a kill, rather than the usual 5
        text = L.VICTORY_RUSH_ALERT_TEXT, color = { 0.3, 1, 0.3 },
        icon = 132342, -- Ability_Warrior_Devastate
        description = L.VICTORY_RUSH_DESCRIPTION,
        defaults = {
            -- Just the icon: no sound or text unless the player turns them on.
            sound = "NONE",
            showText = false,
            -- Castable in any stance (confirmed in game); the ticks are there so
            -- players can limit the alert to the stances they want.
            stances = { battle = true, defensive = true, berserker = true },
            textY = 300, iconX = 160, iconY = 100,
        },
    },
}
ns.ABILITY_BY_KEY = {}
for _, ability in ipairs(ns.ABILITIES) do ns.ABILITY_BY_KEY[ability.key] = ability end

-- Warrior stances, in stance bar order. Each ability alerts only in the
-- stances ticked in its settings (cfg.stances[key]).
ns.STANCES = {
    { key = "battle",    name = L.BATTLE_STANCE,    spellID = 2457 },
    { key = "defensive", name = L.DEFENSIVE_STANCE, spellID = 71 },
    { key = "berserker", name = L.BERSERKER_STANCE, spellID = 2458 },
}

local function Defaults(ability)
    local stances = {}
    for k, v in pairs(ability.defaults.stances) do stances[k] = v end
    return {
        enabled = true,
        sound = ability.defaults.sound,
        customSound = "",
        channel = "Master",
        stances = stances,
        showText = ability.defaults.showText ~= false,
        textSize = 36,
        textPos = nil, -- { point, relPoint, x, y }; nil = default spot
        showIcon = true,
        iconSize = 64,
        iconGlow = "proc",
        iconPos = nil,
        iconOnNameplate = false,   -- anchor the icon to the target's nameplate
        nameplateSide = "TOP",     -- TOP, BOTTOM, LEFT or RIGHT of the nameplate
        nameplateX = 0,            -- offset from that side of the nameplate, in pixels
        nameplateY = 8,
        nameplateFallback = true,  -- no nameplate: show at iconPos instead of hiding
        showCountdown = false,
        barGlow = false,           -- glow the ability's action bar buttons
        barGlowStyle = "proc",
        showOnCooldown = false,    -- alert even while the ability is on cooldown
    }
end

-- Settings for one ability.
function ns.Config(abilityKey)
    return OverpowerAlertDB[abilityKey]
end

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
--   "NONE"              no sound
local cdmLabels = {}
for _, category in ipairs(ns.CDM_SOUNDS) do
    for _, s in ipairs(category[2]) do
        cdmLabels["cdm:" .. s[1]] = s[2]
    end
end

function ns.IsValidSoundKey(key)
    return type(key) == "string"
        and (cdmLabels[key] ~= nil or key:find("^sm:") ~= nil or key == "CUSTOM" or key == "NONE")
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
    if key == "CUSTOM" then return L.SOUND_CUSTOM end
    if key == "NONE" then return L.SOUND_NONE end
    local smName = key and key:match("^sm:(.+)")
    if smName then return smName end
    return cdmLabels[key] or key or "?"
end

-- Plays an ability's alert sound, or `key` instead when given (menu previews).
function ns.PlayAlertSound(abilityKey, key)
    local cfg = ns.Config(abilityKey)
    key = key or cfg.sound
    local channel = cfg.channel or "Master"

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
        local custom = strtrim(cfg.customSound or "")
        if custom ~= "" then
            PlaySoundFile(tonumber(custom) or custom, channel)
        end
    end
end

-- Sound, text and icon, as configured. Always plays (used by alerts and /opa test).
function ns.PreviewAlert(abilityKey)
    local cfg = ns.Config(abilityKey)
    ns.PlayAlertSound(abilityKey)
    if cfg.showText and ns.ShowText then ns.ShowText(abilityKey) end
    if cfg.showIcon and ns.ShowIcon then ns.ShowIcon(abilityKey) end
end

--------------------------------------------------------------------------------
-- Saved variables
--
-- Up to 1.1.x, OverpowerAlertDB held Overpower's settings directly. It now
-- holds one table per ability.
--------------------------------------------------------------------------------

local LEGACY_KEYS = {
    "enabled", "sound", "customSound", "channel", "anyStance", "throttle",
    "showText", "textSize", "textPos", "showIcon", "iconSize", "iconGlow", "iconPos",
}

local function LoadSettings()
    local db = OverpowerAlertDB or {}
    OverpowerAlertDB = db

    if not db.overpower and db.sound ~= nil then
        local old = {}
        for _, k in ipairs(LEGACY_KEYS) do
            old[k] = db[k]
            db[k] = nil
        end
        db.overpower = old
    end

    for _, ability in ipairs(ns.ABILITIES) do
        local cfg = db[ability.key] or {}
        db[ability.key] = cfg
        -- Before per-stance settings there was one "any stance" checkbox;
        -- ticked meant every stance.
        if cfg.stances == nil and cfg.anyStance then
            cfg.stances = { battle = true, defensive = true, berserker = true }
        end
        cfg.anyStance = nil
        -- The nameplate icon used to have a single gap away from its side.
        if cfg.nameplateGap ~= nil and cfg.nameplateX == nil then
            local gap = tonumber(cfg.nameplateGap) or 0
            local side = cfg.nameplateSide
            cfg.nameplateX = side == "LEFT" and -gap or side == "RIGHT" and gap or 0
            cfg.nameplateY = side == "BOTTOM" and -gap or (side == "LEFT" or side == "RIGHT") and 0 or gap
        end
        cfg.nameplateGap = nil
        local defaults = Defaults(ability)
        for k, v in pairs(defaults) do
            if cfg[k] == nil then cfg[k] = v end
        end
        for _, stance in ipairs(ns.STANCES) do
            if type(cfg.stances[stance.key]) ~= "boolean" then
                cfg.stances[stance.key] = defaults.stances[stance.key]
            end
        end
        -- Older versions offered a different built-in list (SOUNDKIT names);
        -- move those selections to the default.
        if not ns.IsValidSoundKey(cfg.sound) then cfg.sound = ability.defaults.sound end
    end
end

--------------------------------------------------------------------------------
-- Detection
--
-- The combat log isn't available to addons on this client, so openings are
-- pieced together from other signals:
--   * Revenge: UNIT_COMBAT on the player reports the player's own blocks,
--     dodges and parries, in any stance.
--   * Overpower: the opening is the player's combo point (power type 4): 1 for
--     the 5 seconds after the target dodges the player's attack, in any stance.
--   * Victory Rush: the "Victorious" buff the player gets for 20 seconds after
--     a kill.
--   * All: C_Spell.IsSpellUsable turns true during an opening, but only in
--     the stances the ability can be cast in. Used as a backup signal.
-- An opening lasts the ability's duration (5 seconds, or 20 for Victory Rush)
-- from its last trigger, until the player casts the ability, or until the
-- Overpower combo point or Victorious buff goes away.
--
-- Each opening alerts at most once: the first moment it's up while the player
-- is in a stance ticked for that ability and the ability is off cooldown. So
-- switching into a ticked stance partway through an opening alerts then, and
-- switching stances again doesn't alert a second time.
--------------------------------------------------------------------------------

local OPENING = 5.0   -- how long an ability stays available after a trigger, unless it says otherwise
local EVENT_LAG = 0.2 -- a "usable" signal this soon after an opening ended belongs to it

local frame = CreateFrame("Frame")
-- [abilityKey] = { spellID, wasUsable, activeUntil, alerted, consumedUntil }
local state = {}
local ticker

for _, ability in ipairs(ns.ABILITIES) do
    state[ability.key] = { wasUsable = false, activeUntil = 0, alerted = false, consumedUntil = 0 }
end

local function IsKnown(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function FindKnownRank(ability)
    for _, id in ipairs(ability.ids) do
        if IsKnown(id) then return id end
    end
end

local function Readable(v)
    return not (issecretvalue and issecretvalue(v))
end

function ns.GetSpellID(abilityKey)
    return state[abilityKey].spellID
end

function ns.IsUsable(abilityKey)
    local id = state[abilityKey].spellID
    if not id then return false end
    local usable, noPower
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noPower = C_Spell.IsSpellUsable(id)
    elseif IsUsableSpell then
        usable, noPower = IsUsableSpell(id)
    end
    -- Treat "usable except for rage" as available too; you'll have the rage
    -- by the time you react.
    return usable == true or noPower == true
end

-- Whether the ability is on its own cooldown (not just the global cooldown).
-- If the game won't say, assume it isn't.
local function OnCooldown(abilityKey)
    local id = state[abilityKey].spellID
    if not (id and C_Spell and C_Spell.GetSpellCooldown) then return false end
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if not ok or type(info) ~= "table" then return false end
    local active, onGCD = info.isActive, info.isOnGCD
    if active ~= nil and Readable(active) and Readable(onGCD) then
        return active == true and onGCD ~= true
    end
    local duration = info.duration
    return type(duration) == "number" and Readable(duration) and duration > 1.6
end
ns.OnCooldown = OnCooldown

-- The stance the player is in ("battle", "defensive", "berserker"), or nil.
local STANCE_BY_SPELL = {}
for _, stance in ipairs(ns.STANCES) do STANCE_BY_SPELL[stance.spellID] = stance.key end

function ns.CurrentStance()
    local index = GetShapeshiftForm and GetShapeshiftForm()
    if type(index) ~= "number" or not Readable(index) or index == 0 then return nil end
    if GetShapeshiftFormInfo then
        local _, _, _, spellID = GetShapeshiftFormInfo(index)
        if Readable(spellID) and STANCE_BY_SPELL[spellID] then return STANCE_BY_SPELL[spellID] end
    end
    -- Stance bar order; warriors learn the stances in this order.
    return ns.STANCES[index] and ns.STANCES[index].key
end

-- Seconds the ability stays available after a trigger.
function ns.Duration(abilityKey)
    return ns.ABILITY_BY_KEY[abilityKey].duration or OPENING
end

local function InOpening(abilityKey)
    return GetTime() < state[abilityKey].activeUntil
end

-- Keeps the end time (rather than clearing it) so a late "usable" signal
-- right after can still be recognised as belonging to this opening.
local function EndOpening(abilityKey)
    local st = state[abilityKey]
    st.activeUntil, st.alerted = math.min(st.activeUntil, GetTime()), false
end

-- Alert for the current opening if it hasn't been yet and everything allows
-- it. Called whenever something relevant changes, and on a timer in combat.
local function MaybeAlert(abilityKey)
    local st, cfg = state[abilityKey], ns.Config(abilityKey)
    if st.alerted or not st.spellID or not cfg.enabled or not InOpening(abilityKey) then return end
    local stance = ns.CurrentStance()
    if not (stance and cfg.stances[stance]) then return end
    -- On cooldown: wait for it, unless the player wants the alert anyway (the
    -- icon then shows greyed out with the cooldown swipe).
    if not cfg.showOnCooldown and OnCooldown(abilityKey) then return end
    st.alerted = true
    ns.PreviewAlert(abilityKey)
end

-- A real trigger (block, dodge or parry for Revenge; a new combo point for
-- Overpower; the Victorious buff): starts a new opening or extends the
-- current one. `untilTime` is when it ends, if the game says.
local function OnTrigger(abilityKey, untilTime)
    local st = state[abilityKey]
    if not InOpening(abilityKey) then st.alerted = false end
    st.activeUntil = untilTime or (GetTime() + ns.Duration(abilityKey))
    MaybeAlert(abilityKey)
end

local ReadComboPoints, ReadVictorious -- with the Overpower and Victory Rush code below

-- The ability just became usable. Normally that's an opening we already know
-- about (the player switched into its stance). It only starts one if we
-- missed the trigger, and never right after one ended or was used up: Revenge
-- stays "usable" after it's cast, since usability ignores the cooldown.
local function OnBecameUsable(abilityKey)
    local st, now = state[abilityKey], GetTime()
    if not InOpening(abilityKey) then
        if now < st.activeUntil + EVENT_LAG or now < st.consumedUntil then return end
        -- When Overpower's combo point can be read, it's the real signal:
        -- usable without one is a stale update (e.g. the target dying).
        if abilityKey == "overpower" and ReadComboPoints() == 0 then return end
        -- Likewise the Victorious buff, when the aura can be read.
        if abilityKey == "victoryrush" and ReadVictorious() == false then return end
        st.alerted = false
        st.activeUntil = now + ns.Duration(abilityKey)
    end
    MaybeAlert(abilityKey)
end

local CheckVictorious -- with the Victory Rush code below

local function Check()
    CheckVictorious()
    for _, ability in ipairs(ns.ABILITIES) do
        local key = ability.key
        local st = state[key]
        local usable = ns.IsUsable(key)
        if usable and not st.wasUsable then OnBecameUsable(key) end
        st.wasUsable = usable
        -- Stance changes, cooldowns ending, settings changes.
        MaybeAlert(key)
    end
end
ns.Check = Check

-- Overpower: the opening is tracked as the player's combo points. It's
-- normally readable in combat. If it's ever a secret value, a combo point
-- change within PAIR_WINDOW of the target dodging counts as a new opening
-- instead (UNIT_COMBAT reports the dodge about half a second after the point).
local COMBO_POINTS = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
local PAIR_WINDOW = 1.0
local comboPoints = 0 -- last readable value
local lastHiddenComboChange, lastTargetDodge = -math.huge, -math.huge

function ReadComboPoints()
    local ok, v = pcall(UnitPower, "player", COMBO_POINTS)
    if not ok or not Readable(v) or type(v) ~= "number" then return nil end
    return v
end

local function OnComboPointsChanged()
    local v = ReadComboPoints()
    if v then
        -- Each dodge adds a point (seen going 1 -> 2) and restarts the
        -- 5 seconds, so any increase is a new trigger.
        local gained = v > comboPoints
        comboPoints = v
        if gained then
            OnTrigger("overpower")
        elseif v == 0 then
            -- Used, expired or the target changed: the opening is over.
            EndOpening("overpower")
        end
        return
    end
    comboPoints = 0
    local now = GetTime()
    lastHiddenComboChange = now
    if now - lastTargetDodge <= PAIR_WINDOW then OnTrigger("overpower") end
end

local function OnTargetDodge()
    local now = GetTime()
    lastTargetDodge = now
    if now - lastHiddenComboChange <= PAIR_WINDOW then OnTrigger("overpower") end
end

-- Revenge: the player's own blocks, dodges and parries.
local function OnPlayerCombat(action, flagText)
    if not (Readable(action) and Readable(flagText)) then return end
    local avoided = action == "BLOCK" or action == "DODGE" or action == "PARRY"
        -- A hit that was partly blocked comes as WOUND with BLOCK_REDUCED (how
        -- Blizzard's CombatFeedback.lua reads it); BLOCK is a hit fully
        -- blocked. Shield Block makes these the usual case.
        or flagText == "BLOCK_REDUCED" or flagText == "BLOCK"
    if avoided then OnTrigger("revenge") end
end

-- Victory Rush: the "Victorious" buff, up for 20 seconds after a kill that
-- gives experience or honor. Read with C_UnitAuras; ReadVictorious returns
-- the buff's end time (or true if it's up but the time can't be read), false
-- if it's not up, or nil if the game won't say.
local VICTORIOUS = 402975 -- confirmed in game on Forever
local victorious = false -- last readable answer: buff up or not

function ReadVictorious()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, VICTORIOUS)
    if not ok or not Readable(aura) then return nil end
    if aura == nil then
        -- In combat the game hides the buff (it only shows up once combat
        -- ends), so "not found" means "can't tell" there, and Victory Rush
        -- becoming usable is the signal instead.
        if InCombatLockdown() then return nil end
        return false
    end
    local expires = aura.expirationTime
    if type(expires) == "number" and Readable(expires) and expires > 0 then return expires end
    return true
end

function CheckVictorious()
    local v = ReadVictorious()
    if v == nil then return end
    local up = v ~= false
    -- ReadVictorious can't see the buff in combat, so there the opening ends
    -- when Victory Rush is cast (OnSpellCast) or the buff's time runs out.
    local st = state.victoryrush
    if up and (not victorious or (type(v) == "number" and v > st.activeUntil + 0.5)) then
        -- Gained, or refreshed by another kill.
        OnTrigger("victoryrush", type(v) == "number" and v or nil)
    elseif not up and victorious then
        -- Used or expired.
        EndOpening("victoryrush")
    end
    victorious = up
end

-- Casting the ability uses up its opening and hides its text and icon. The
-- next real trigger starts a new opening; until this one would have run out,
-- the ability turning usable again (stance switch) doesn't.
local spellOwner = {} -- [spellID] = abilityKey
for _, ability in ipairs(ns.ABILITIES) do
    for _, id in ipairs(ability.ids) do spellOwner[id] = ability.key end
end

local function OnSpellCast(spellID)
    if not Readable(spellID) then return end
    local key = spellOwner[spellID]
    if not key then return end
    EndOpening(key)
    -- Victory Rush's usability follows the buff, so after a short grace period
    -- it turning usable again means another kill.
    state[key].consumedUntil = GetTime() + (key == "victoryrush" and 1 or ns.Duration(key))
    if ns.HideAlert then ns.HideAlert(key) end
end

-- Whether the ability's opening is up, in any stance. Keeps the text and icon
-- up while this is true.
function ns.IsActive(abilityKey)
    if InOpening(abilityKey) then return true end
    -- Victory Rush's opening runs to the buff's own end time.
    if abilityKey == "victoryrush" then return false end
    return abilityKey == "overpower" and comboPoints > 0
end

-- Seconds left in the current opening, or nil if there isn't one. Drives
-- the countdown.
function ns.GetRemaining(abilityKey)
    if not InOpening(abilityKey) then return nil end
    return state[abilityKey].activeUntil - GetTime()
end

local function StartTicker()
    if not ticker then ticker = C_Timer.NewTicker(0.1, Check) end
end

local function StopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
end

local function Refresh()
    for _, ability in ipairs(ns.ABILITIES) do
        local st = state[ability.key]
        st.spellID = FindKnownRank(ability)
        st.wasUsable = ns.IsUsable(ability.key)
    end
    -- Take the current values without alerting on an opening already up.
    comboPoints = ReadComboPoints() or 0
    victorious = (ReadVictorious() or false) ~= false
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        LoadSettings()
        if ns.InitDisplay then ns.InitDisplay() end
        if ns.InitActionBars then ns.InitActionBars() end
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
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        pcall(self.RegisterUnitEvent, self, "UNIT_COMBAT", "player", "target")
        pcall(self.RegisterUnitEvent, self, "UNIT_POWER_UPDATE", "player")
        pcall(self.RegisterUnitEvent, self, "UNIT_SPELLCAST_SUCCEEDED", "player")
        pcall(self.RegisterUnitEvent, self, "UNIT_AURA", "player")
        if InCombatLockdown() then StartTicker() end
        return
    end

    if event == "SPELLS_CHANGED" then
        Refresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Events can lag; check lightly while in combat as a backstop.
        StartTicker()
    elseif event == "PLAYER_REGEN_ENABLED" then
        StopTicker()
        Check()
    elseif event == "UNIT_COMBAT" then
        local unit, action, flagText = ...
        if not Readable(action) then return end
        if unit == "player" then
            OnPlayerCombat(action, flagText)
        elseif unit == "target" and action == "DODGE" then
            OnTargetDodge()
        end
    elseif event == "UNIT_POWER_UPDATE" then
        local unit, powerType = ...
        if unit == "player" and powerType == "COMBO_POINTS" then OnComboPointsChanged() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then OnSpellCast(spellID) end
    elseif event == "UNIT_AURA" then
        if ... == "player" then CheckVictorious() end
    else
        Check()
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

local ABILITY_ALIASES = {
    op = "overpower", overpower = "overpower",
    rev = "revenge", revenge = "revenge",
    vr = "victoryrush", victoryrush = "victoryrush", victory = "victoryrush",
}

local function Print(text)
    print("|cffff6619" .. L.ADDON_TITLE .. "|r " .. text)
end

SLASH_OVERPOWERALERT1 = "/opa"
SLASH_OVERPOWERALERT2 = "/overpoweralert"
SlashCmdList.OVERPOWERALERT = function(msg)
    local cmd, arg = strlower(strtrim(msg or "")):match("^(%S*)%s*(.-)$")
    local abilityKey = ABILITY_ALIASES[arg]
    if arg ~= "" and not abilityKey then
        Print(L.UNKNOWN_ABILITY:format(arg))
        return
    end

    if cmd == "test" then
        ns.PreviewAlert(abilityKey or "overpower")
        if ns.Config(abilityKey or "overpower").barGlow and ns.PreviewBarGlow then
            ns.PreviewBarGlow(abilityKey or "overpower")
        end
    elseif cmd == "toggle" then
        local keys = {}
        for _, ability in ipairs(ns.ABILITIES) do
            if not abilityKey or abilityKey == ability.key then keys[#keys + 1] = ability.key end
        end
        -- With several, turn them all off if any is on, otherwise all on.
        local anyOn = false
        for _, k in ipairs(keys) do anyOn = anyOn or ns.Config(k).enabled end
        for _, k in ipairs(keys) do
            ns.Config(k).enabled = not anyOn
            Print((anyOn and L.ALERT_DISABLED or L.ALERT_ENABLED):format(ns.ABILITY_BY_KEY[k].name))
        end
    elseif cmd == "unlock" or cmd == "move" then
        ns.SetUnlocked(abilityKey, nil, true)
    elseif cmd == "lock" then
        ns.SetUnlocked(abilityKey, nil, false)
    elseif cmd == "probe" then -- TEMPORARY, see the probe below
        ns.ToggleProbe()
    elseif ns.OpenOptions then
        ns.OpenOptions()
    end
end

--------------------------------------------------------------------------------
-- TEMPORARY probe (/opa probe): which enemy's dodge gives the Overpower combo
-- point, and what happens to the combo point when the target changes. Prints
-- to chat; secret values print as <secret>. Remove once answered.
--------------------------------------------------------------------------------

do
    local probe, t0, lastPrinted, lastUsable
    local OVERPOWER_IDS = {}
    for _, id in ipairs(ns.ABILITY_BY_KEY.overpower.ids) do OVERPOWER_IDS[id] = true end

    local function Show(v)
        if issecretvalue and issecretvalue(v) then return "<secret>" end
        return tostring(v)
    end

    local function Out(text)
        print(string.format("|cffff6619OPA|r %.2f %s", GetTime() - t0, text))
    end

    -- Whether `unit` is the current target: yes / no / <secret>.
    local function IsTarget(unit)
        local ok, same = pcall(UnitIsUnit, unit, "target")
        if not ok then return "?" end
        if issecretvalue and issecretvalue(same) then return "<secret>" end
        return same and "yes" or "no"
    end

    local function Name(unit)
        local ok, name = pcall(UnitName, unit)
        return ok and Show(name) or "?"
    end

    -- The nameplate token showing the target, if any.
    local function TargetPlate()
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if UnitExists(unit) and IsTarget(unit) == "yes" then return unit end
        end
        return "none"
    end

    -- Combo points two ways: the player's power (what the addon reads) and
    -- the old per-target API, if this client has it.
    local function Combo()
        local ok1, power = pcall(UnitPower, "player", 4)
        local onTarget = "n/a"
        if GetComboPoints then
            local ok2, v = pcall(GetComboPoints, "player", "target")
            onTarget = ok2 and Show(v) or "err"
        end
        return "power=" .. (ok1 and Show(power) or "err") .. " onTarget=" .. onTarget
    end

    local function Usable()
        local id = ns.GetSpellID("overpower")
        if not id then return "unknown" end
        local ok, usable, noPower = pcall(C_Spell.IsSpellUsable, id)
        if not ok then return "err" end
        return Show(usable) .. "/" .. Show(noPower)
    end

    local function Poll()
        local combo = Combo()
        if combo ~= lastPrinted then
            Out("COMBO " .. combo)
            lastPrinted = combo
        end
        local usable = Usable()
        if usable ~= lastUsable then
            Out("OP usable=" .. usable)
            lastUsable = usable
        end
    end

    local function OnEvent(_, event, ...)
        if event == "UNIT_COMBAT" then
            local unit, action, flagText = ...
            if unit == "player" then return end -- the enemy side is what we want
            local a = Show(action)
            if a ~= "DODGE" and a ~= "<secret>" then return end
            Out(string.format("DODGE unit=%s target=%s name=%s flag=%s",
                Show(unit), IsTarget(unit), Name(unit), Show(flagText)))
        elseif event == "PLAYER_TARGET_CHANGED" then
            Out(string.format("TARGET -> %s plate=%s %s", Name("target"), TargetPlate(), Combo()))
            C_Timer.After(0.1, function() if probe then Out("  +0.1s " .. Combo()) end end)
            C_Timer.After(0.5, function() if probe then Out("  +0.5s " .. Combo()) end end)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellID = ...
            if unit == "player" and not (issecretvalue and issecretvalue(spellID)) and OVERPOWER_IDS[spellID] then
                Out("CAST Overpower on " .. Name("target") .. " " .. Combo())
            end
        elseif event == "UI_ERROR_MESSAGE" then
            local _, message = ...
            Out("ERROR " .. Show(message))
        end
        Poll()
    end

    function ns.ToggleProbe()
        if probe then
            probe:UnregisterAllEvents()
            probe:SetScript("OnUpdate", nil)
            probe = nil
            print("|cffff6619OPA|r probe off")
            return
        end
        t0, lastPrinted, lastUsable = GetTime(), nil, nil
        probe = CreateFrame("Frame")
        probe:RegisterEvent("UNIT_COMBAT") -- every unit, nameplates included
        probe:RegisterEvent("PLAYER_TARGET_CHANGED")
        probe:RegisterEvent("UI_ERROR_MESSAGE")
        pcall(probe.RegisterUnitEvent, probe, "UNIT_SPELLCAST_SUCCEEDED", "player")
        probe:SetScript("OnEvent", OnEvent)
        local elapsed = 0
        probe:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 0.1 then return end
            elapsed = 0
            Poll()
        end)
        print("|cffff6619OPA|r probe on (/opa probe again to stop). " .. Combo())
    end
end
