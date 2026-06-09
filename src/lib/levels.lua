-- Generalized, data-driven level engine + shared per-level infrastructure.
-- Requirements: levels/Level_1.md, levels/Levels_2_to_31.md
-- Source lines: war3map.j 19035-19120 (shared), 19141-20360 (Levels 1-10)
--
-- A level is DATA (LevelData[n]); the engine (StartLevel / victory polling) is generic.
-- Victory types: 'clearAll' (all listed enemy unit types reach 0) and 'boss' (a named
-- boss unit dies). An optional per-level `setup` hook runs after spawning (boss stats,
-- skills, level-specific enemy AI). Levels 11-31 are added by extending LevelData.

local P9 = Player(9)
local underAttackTrg = nil  -- "town under attack" warning; re-armed each level by BonusReset

-- lane key -> spawn rect. 'A'/'B'/'C' are shorthand for SpawnA/B/C; any other key is
-- looked up directly in rct (e.g. 'HellSpawn', 'CaravanPathA'). Resolved at runtime.
local SPAWN_ALIAS = { A = 'SpawnA', B = 'SpawnB', C = 'SpawnC' }
local function laneRect(key)
    return rct[SPAWN_ALIAS[key] or key]
end

-- ─── Shared per-level infrastructure (war3map.j 19035-19120, 7436-7449, 6414-6422) ──

function ThingsToDoBeforeEveryLevelBegins()
    local function revive(hero)
        if hero then ReviveHeroLoc(hero, GetRectCenter(rct.StartingPlayerArea), true) end
    end
    revive(P1Hero); revive(P2Hero); revive(P3Hero); revive(P4Hero)
    revive(P5Hero); revive(P6Hero); revive(P7Hero); revive(P8Hero)
    revive(WildbondPet)
    -- SpawnMeleeGuards()/SpawnArcherGuards() — guard-post system, port later
    DieHardActivated = false
end

function ThingsToDoImmediatelyFollowingVictory()
    if MiserPlayer then
        AdjustPlayerStateBJ(100, MiserPlayer, PLAYER_STATE_RESOURCE_GOLD)
    end
end

function TimerForNextLevel(isBoss)
    local duration = isBoss and 15.0 or 8.0
    local label    = isBoss and "Boss Incoming!" or "Next Level"
    if isBoss then PlaySoundBJ(snd.EpicEventSound) end
    CreateTimerDialogBJ(TimerNextLevel, label)
    NextLevelTimerWindow = GetLastCreatedTimerDialogBJ()
    TimerDialogDisplayBJ(true, NextLevelTimerWindow)
    StartTimerBJ(TimerNextLevel, false, duration)
end

local function DestroyNextLevelTimer()
    if NextLevelTimerWindow then
        DestroyTimerDialogBJ(NextLevelTimerWindow)
        NextLevelTimerWindow = nil
    end
end

function StartFastVictoriesTimer()
    local t = CreateTimer()
    TimerStart(t, 60.0, false, function()
        if not LevelBeaten then BlazingVictory = false end
        TimerStart(t, 60.0, false, function()
            if not LevelBeaten then SpeedyVictory = false end
        end)
    end)
end

function BonusReset()
    HeroAssassination         = false
    BlazingVictory            = true
    SpeedyVictory             = true
    StalwartDefender          = true
    PlayerTotalDeathsForRound = 0
    if underAttackTrg then EnableTrigger(underAttackTrg) end  -- re-arm warning (war3map.j 6420)
end

-- ─── Bonuses & Upkeep (universal bonuses; per-class payouts pending — Achievements.md) ──

function BonusesAndUpkeep(levelIndex)
    local function awardAll(gold, msg)
        DisplayTimedTextToForce(GetPlayersAll(), 10.0, msg)
        for i = 0, 7 do
            if IsHumanPlayer(Player(i)) then
                AdjustPlayerStateBJ(gold, Player(i), PLAYER_STATE_RESOURCE_GOLD)
            end
        end
        TotalBonusGold = TotalBonusGold + gold
    end

    if HeroFlawlessDeath then
        awardAll(100, "|cff00ff00Flawless!|r No hero died this round — |cffffcc00+100 Gold|r each.")
    elseif PlayerTotalDeathsForRound == 0 then
        awardAll(50, "|cff00ff00No deaths this round — |cffffcc00+50 Gold|r each.")
    end
    if StalwartDefender then
        awardAll(50, "|cff00ff00Stalwart Defender!|r No enemy reached the base — |cffffcc00+50 Gold|r each.")
    end
    if BlazingVictory then
        awardAll(200, "|cff00ff00Blazing Victory!|r Won in under 60s — |cffffcc00+200 Gold|r each.")
    elseif SpeedyVictory then
        awardAll(100, "|cff00ff00Speedy Victory!|r Won in under 120s — |cffffcc00+100 Gold|r each.")
    end
    if levelIndex and LevelBonuses[levelIndex] then
        awardAll(100, "|cff00ff00Level Bonus — |cffffcc00+100 Gold|r (level challenge met!)")
        LevelBonuses[levelIndex] = false
    end
end

-- ─── Per-level setup hooks (boss stats/skills + enemy AI) ──────────────────────

-- Level 6 miniboss: Paladin commander H00C (war3map.j 19788-19960)
local function setupLevel6Boss()
    local grp = GetUnitsOfTypeIdAll(FourCC('H00C'))
    ForGroup(grp, function()
        local b = GetEnumUnit()
        SetHeroLevelBJ(b, 5 + DifficultyModifier, false)
        SelectHeroSkill(b, FourCC('AHds'))  -- Divine Shield
        SelectHeroSkill(b, FourCC('AOhw'))  -- Healing Wave
        SelectHeroSkill(b, FourCC('AHre'))  -- Resurrection
    end)
    DestroyGroup(grp)

    -- heal self when attacked below 125 HP
    local aiHeal = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(aiHeal, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(aiHeal, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == FourCC('H00C')
            and GetUnitState(GetAttackedUnitBJ(), UNIT_STATE_LIFE) <= 125.0
    end))
    TriggerAddAction(aiHeal, function()
        local b = GetAttackedUnitBJ()
        IssueTargetOrderBJ(b, "healingwave", b)
    end)

    -- divine shield when boss below 500 HP
    local aiShield = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(aiShield, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(aiShield, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == FourCC('H00C')
            and GetUnitState(GetAttackedUnitBJ(), UNIT_STATE_LIFE) <= 500.0
    end))
    TriggerAddAction(aiShield, function()
        IssueImmediateOrderBJ(GetAttackedUnitBJ(), "divineshield")
    end)
end

-- Level 8 enemy AI: h00Y casts firebolt at its attacker when ≤125 HP, then retreats
-- to the fortress entrance (war3map.j 20113-20127).
local function setupLevel8AI()
    local trg = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(trg, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(trg, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == FourCC('h00Y')
            and GetUnitState(GetAttackedUnitBJ(), UNIT_STATE_LIFE) <= 125.0
    end))
    TriggerAddAction(trg, function()
        local u = GetAttackedUnitBJ()
        IssueTargetOrderBJ(u, "firebolt", GetAttacker())
        TriggerSleepAction(2.0)
        IssuePointOrderLoc(u, "patrol", GetRectCenter(rct.EntranceToFortress))
    end)
end

-- Level 10 boss: Goblin King O001 (war3map.j 20290-20360).
-- Spells (Lackeys ANsq, Fury/Stampede AHtc, Spire ANst) are granted here; their
-- cast-AI is a later port — for now the boss is a high-level melee threat.
local function setupLevel10Boss()
    StartBossMusic()   -- BossMusic1.mp3 loop (war3map.j 20323-20325)
    GoblinSlayer = true
    local grp = GetUnitsOfTypeIdAll(FourCC('O001'))
    ForGroup(grp, function()
        local b = GetEnumUnit()
        local lvl = 6 * DifficultyModifier
        if lvl < 1 then lvl = 1 end
        SetHeroLevelBJ(b, lvl, false)
        SelectHeroSkill(b, FourCC('AHtc'))  -- Fury of the Mountain (Stampede)
        SelectHeroSkill(b, FourCC('ANsq'))  -- Summon Lackeys
        SelectHeroSkill(b, FourCC('ANst'))  -- Spire
    end)
    DestroyGroup(grp)
end

-- ─── Level data ───────────────────────────────────────────────────────────────
-- spawn directive: { u=FourCC, n=base, dm=mult(optional), at=lane | {lanes} }
--   count = n + (dm or 0) * DifficultyModifier, created at each lane in `at`.
-- victory: { type='clearAll', units={FourCC,...} } | { type='boss', unit=FourCC }

local ABC = { 'A', 'B', 'C' }

local LevelData = {
    [1] = {
        intro = "|cffff8800Level 1|r — Squires approach. Defend the town!",
        track = 1, next = 2,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h002'), n=5, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002') } },
    },
    [2] = {
        intro = "|cffff8800Level 2|r — More squires, now with riflemen.",
        track = 2, next = 3,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h002'), n=6, dm=1,  at=ABC },
            { u=FourCC('h005'), n=0, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002'), FourCC('h005') } },
    },
    [3] = {
        intro = "|cffff8800Level 3|r — Archers join the assault.",
        track = 3, next = 4,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h002'), n=4, dm=1,  at=ABC },
            { u=FourCC('h005'), n=0, dm=1,  at=ABC },
            { u=FourCC('n001'), n=2, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002'), FourCC('h005'), FourCC('n001') } },
    },
    [4] = {
        intro = "|cffff8800Level 4|r — Rescue the prisoners! Clear the attackers.",
        track = 1, next = 5, prisoners = true,
        spawns = {
            { u=FourCC('h002'), n=6, dm=1,  at=ABC },
            { u=FourCC('n001'), n=1, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002'), FourCC('n001') } },
    },
    [5] = {
        intro = "|cffff8800Level 5|r — Knights (h00B) reinforce the enemy.",
        track = 2, next = 6,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h002'), n=1, dm=1,  at=ABC },
            { u=FourCC('h005'), n=0, dm=1,  at=ABC },
            { u=FourCC('h00B'), n=1, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002'), FourCC('h005'), FourCC('h00B') } },
    },
    [6] = {
        intro = "|cffff3300Level 6 — MINIBOSS!|r A Paladin commander leads the charge.",
        next = 7, boss = true, setup = setupLevel6Boss,
        spawns = {
            { u=FourCC('e01M'), n=1,        at='B' },
            { u=FourCC('h002'), n=9, dm=1,  at='B' },
            { u=FourCC('h005'), n=5, dm=1,  at='B' },
            { u=FourCC('H00C'), n=1,        at='B' },   -- the miniboss
            { u=FourCC('h02P'), n=1,        at='B' },
            { u=FourCC('h02R'), n=1,        at='B' },
            { u=FourCC('h00B'), n=8, dm=1,  at='B' },
        },
        victory = { type='boss', unit=FourCC('H00C') },
    },
    [7] = {
        intro = "|cffff8800Level 7|r — Demons spill from the hell rift.",
        track = 1, next = 8,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h00X'), n=3, dm=1,  at=ABC },
            { u=FourCC('h015'), n=2, dm=1,  at=ABC },
            { u=FourCC('h01R'), n=1,        at='HellSpawn' },
        },
        victory = { type='clearAll', units={ FourCC('h00X'), FourCC('h015'), FourCC('h01R') } },
    },
    [8] = {
        intro = "|cffff8800Level 8|r — Fire-casters (h00Y) among the demons.",
        track = 2, next = 9, setup = setupLevel8AI,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h00X'), n=2, dm=1,  at=ABC },
            { u=FourCC('h015'), n=2, dm=1,  at=ABC },
            { u=FourCC('h00Y'), n=2, dm=1,  at=ABC },
            { u=FourCC('h01R'), n=1,        at='HellSpawn' },
            { u=FourCC('h03T'), n=1,        at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h00X'), FourCC('h015'), FourCC('h00Y'), FourCC('h01R'), FourCC('h03T') } },
    },
    [9] = {
        intro = "|cffff8800Level 9|r — A caravan raider (h06O) and brutes (n002) attack.",
        track = 3, next = 10,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h06O'), n=1,        at='CaravanPathA' },
            { u=FourCC('h00X'), n=2, dm=1,  at=ABC },
            { u=FourCC('h015'), n=2, dm=1,  at=ABC },
            { u=FourCC('n002'), n=1, dm=1,  at=ABC },
            { u=FourCC('h01R'), n=0, dm=1,  at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h06O'), FourCC('n002'), FourCC('h00X'), FourCC('h015'), FourCC('h01R') } },
    },
    [10] = {
        intro = "|cffff3300Level 10 — BOSS: The Goblin King!|r",
        next = 11, boss = true, setup = setupLevel10Boss,
        spawns = {
            { u=FourCC('e01M'), n=1,         at='B' },
            { u=FourCC('h00X'), n=9, dm=2,   at='B' },
            { u=FourCC('h015'), n=5, dm=1,   at='B' },
            { u=FourCC('n002'), n=1, dm=1,   at='B' },
            { u=FourCC('n002'), n=1, dm=1,   at='A' },
            { u=FourCC('h02S'), n=1,         at='A' },
            { u=FourCC('h00X'), n=2, dm=1,   at='A' },
            { u=FourCC('h015'), n=2, dm=1,   at='A' },
            { u=FourCC('n002'), n=1, dm=1,   at='C' },
            { u=FourCC('h00X'), n=2, dm=1,   at='C' },
            { u=FourCC('h015'), n=2, dm=1,   at='C' },
            { u=FourCC('h02S'), n=1,         at='C' },
            { u=FourCC('h01R'), n=0, dm=1,   at='HellSpawn' },
            { u=FourCC('O001'), n=1,         at='B' },   -- Goblin King
        },
        victory = { type='boss', unit=FourCC('O001') },
    },
    [11] = {
        intro = "|cffff8800Level 11|r — Heavier demons (h014/h00W) and infernals.",
        track = 1, next = 12,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h014'), n=2, dm=1,  at=ABC },
            { u=FourCC('h00W'), n=2, dm=1,  at=ABC },
            { u=FourCC('h016'), n=0, dm=1,  at=ABC },
            { u=FourCC('h01R'), n=1, dm=1,  at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h014'), FourCC('h00W'), FourCC('h016'), FourCC('h01R') } },
    },
    [12] = {
        intro = "|cffff8800Level 12|r — The demon horde swells (adds h017).",
        track = 2, next = 13,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h014'), n=2, dm=1,  at=ABC },
            { u=FourCC('h00W'), n=2, dm=1,  at=ABC },
            { u=FourCC('h016'), n=0, dm=1,  at=ABC },
            { u=FourCC('h017'), n=0, dm=1,  at=ABC },
            { u=FourCC('h03T'), n=1, dm=1,  at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h014'), FourCC('h00W'), FourCC('h016'), FourCC('h017'), FourCC('h03T') } },
    },
}

-- ─── Generic spawn + victory plumbing ──────────────────────────────────────────

local activeVictoryTrigger = nil

local function spawnLevel(data)
    for _, s in ipairs(data.spawns) do
        local count = s.n + (s.dm or 0) * DifficultyModifier
        if count > 0 then
            local lanes = s.at
            if type(lanes) == 'string' then lanes = { lanes } end
            for _, lane in ipairs(lanes) do
                CreateNUnitsAtLoc(count, s.u, P9, GetRectCenter(laneRect(lane)), bj_UNIT_FACING)
            end
        end
    end
end

local function patrolEnemiesToBase()
    local loc = GetRectCenter(rct.StartingPlayerArea)
    local grp = GetUnitsInRectOfPlayer(GetPlayableMapRect(), P9)
    ForGroup(grp, function()
        IssuePointOrderLoc(GetEnumUnit(), "patrol", loc)
    end)
    DestroyGroup(grp)
    RemoveLocation(loc)
end

local function removeSpeedWispsAfter(delay)
    local t = CreateTimer()
    TimerStart(t, delay, false, function()
        local wisps = GetUnitsOfPlayerAndTypeId(P9, FourCC('e01M'))
        ForGroup(wisps, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(wisps)
    end)
end

-- Level 4 escort prisoners (h006, Player 8); they flee to the base (flavor).
local function spawnPrisoners()
    for _, key in ipairs({ 'AlliedFlee', 'AlliedFlee2', 'AlliedFlee3' }) do
        CreateNUnitsAtLoc(3, FourCC('h006'), Player(8), GetRectCenter(rct[key]), bj_UNIT_FACING)
    end
    local grp = GetUnitsOfPlayerAndTypeId(Player(8), FourCC('h006'))
    ForGroup(grp, function()
        IssuePointOrderLoc(GetEnumUnit(), "move", GetRectCenter(rct.StartingPlayerArea))
    end)
    DestroyGroup(grp)
end

-- forward declaration (global so onLevelVictory can chain)
StartLevel = nil

local function onLevelVictory(data, levelIndex)
    MusicOn     = false
    BossMusic   = false
    StopAllMusic()        -- silence boss track on victory; vanilla wave music resumes via WaveMusicTick
    LevelBeaten = true
    PlaySoundBJ(snd.RoundClear)
    ThingsToDoImmediatelyFollowingVictory()
    TimerForNextLevel(LevelData[data.next] and LevelData[data.next].boss or false)
    TriggerSleepAction(0.25)
    DisplayTextToForce(GetPlayersAll(), "|cff00ff00Level " .. levelIndex .. " cleared!|r")
    TriggerSleepAction(0.25)
    BonusesAndUpkeep(levelIndex)
    TriggerSleepAction(3.0)
    BonusReset()
    LevelBeaten = false
    DestroyNextLevelTimer()

    if DebugNoAutoAdvance then   -- debug -stop: don't auto-start the next level
        DisplayTextToForce(GetPlayersAll(),
            "|cffaaaaaa[debug] auto-advance off — use -wave to start the next level.|r")
        return
    end
    if data.next and LevelData[data.next] then
        CurrentLevel = data.next
        StartLevel(data.next)
    else
        CurrentLevel = data.next or levelIndex
        DisplayTextToForce(GetPlayersAll(),
            "|cffff8800Level " .. (data.next or "?") .. "+ not yet ported (Phase 6 in progress).|r")
    end
end

local function armClearAllVictory(data, levelIndex)
    activeVictoryTrigger = CreateTrigger()
    DisableTrigger(activeVictoryTrigger)
    TriggerRegisterTimerEventPeriodic(activeVictoryTrigger, 8.0)
    TriggerAddAction(activeVictoryTrigger, function()
        for _, u in ipairs(data.victory.units) do
            if CountLivingPlayerUnitsOfTypeId(u, P9) > 0 then return end
        end
        DisableTrigger(activeVictoryTrigger)
        onLevelVictory(data, levelIndex)
    end)
    EnableTrigger(activeVictoryTrigger)
end

local function armBossVictory(data, levelIndex)
    activeVictoryTrigger = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(activeVictoryTrigger, P9, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(activeVictoryTrigger, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == data.victory.unit
    end))
    TriggerAddAction(activeVictoryTrigger, function()
        DisableTrigger(activeVictoryTrigger)
        -- clear remaining trash so the next level starts clean
        local grp = GetUnitsInRectOfPlayer(rct.EntireGameArea, P9)
        ForGroup(grp, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(grp)
        onLevelVictory(data, levelIndex)
    end)
end

-- ─── The generic level entry point ─────────────────────────────────────────────

StartLevel = function(n)
    local data = LevelData[n]
    if not data then
        DisplayTextToForce(GetPlayersAll(), "|cffff0000Level " .. n .. " has no data.|r")
        return
    end
    CurrentLevel = n
    ThingsToDoBeforeEveryLevelBegins()
    LevelBonuses[n] = true

    TriggerSleepAction(1.0)
    PlaySoundBJ(snd.Courageous)
    DisplayTimedTextToForce(GetPlayersAll(), 20.0, data.intro)
    TriggerSleepAction(1.0)

    spawnLevel(data)
    if data.prisoners then spawnPrisoners() end
    if data.setup then data.setup() end

    TriggerSleepAction(1.0)
    patrolEnemiesToBase()
    StartFastVictoriesTimer()
    MusicOn = true
    if data.track then CurrentTrackMusic = data.track end  -- nil = keep previous (e.g. L6 miniboss)
    PlaySoundBJ(snd.SlowRezzSound)   -- per-level reinforcement cue (war3map.j level actions)

    TriggerSleepAction(0.75)
    if data.victory.type == 'boss' then
        armBossVictory(data, n)
    else
        armClearAllVictory(data, n)
    end

    removeSpeedWispsAfter(10.0)
    RollWeather()   -- per-level random weather (lib/weather.lua)
end

-- Alias kept so hero_selection.BeginningStart2 (which calls Level1Start) still works.
function Level1Start()
    StartLevel(1)
end

-- ─── Level-challenge bonus + Stalwart Defender tracking ────────────────────────

function RegisterLevelTriggers()
    -- Level 1 challenge: no enemy crosses the halfway markers
    local trg = CreateTrigger()
    TriggerRegisterEnterRectSimple(trg, rct.HalfwayMarkerA)
    TriggerRegisterEnterRectSimple(trg, rct.HalfwayMarkerB)
    TriggerRegisterEnterRectSimple(trg, rct.HalfwayMarkerC)
    TriggerAddCondition(trg, Condition(function()
        return GetOwningPlayer(GetEnteringUnit()) == P9
    end))
    TriggerAddAction(trg, function()
        if CurrentLevel == 1 and LevelBonuses[1] then LevelBonuses[1] = false end
    end)

    -- Stalwart Defender: enemy reaches the base area (clears the per-level bonus)
    local trgStalwart = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgStalwart, rct.AreaToDefend)
    TriggerAddCondition(trgStalwart, Condition(function()
        return GetOwningPlayer(GetEnteringUnit()) == P9
    end))
    TriggerAddAction(trgStalwart, function()
        StalwartDefender = false
    end)

    -- "Town under attack!" — first enemy to reach the base each level pings the
    -- minimap, sounds the horn, and warns the players (war3map.j 30002-30022).
    -- Fires once per level (disables itself); BonusReset re-arms it.
    underAttackTrg = CreateTrigger()
    TriggerRegisterEnterRectSimple(underAttackTrg, rct.AreaToDefend)
    TriggerAddCondition(underAttackTrg, Condition(function()
        return GetOwningPlayer(GetEnteringUnit()) == P9
    end))
    TriggerAddAction(underAttackTrg, function()
        DisableTrigger(underAttackTrg)
        local loc = GetUnitLoc(GetEnteringUnit())
        PingMinimapLocForForce(GetPlayersAll(), loc, 5.0)
        RemoveLocation(loc)
        PlaySoundBJ(snd.HordeSound2)
        DisplayTimedTextToForce(GetPlayersAll(), 3.0, "|cffff0000Your town is under attack!|r")
    end)
end
