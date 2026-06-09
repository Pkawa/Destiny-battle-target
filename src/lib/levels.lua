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

-- A "boss reacts when attacked" trigger for Player(9) units: when a `unitType` unit is
-- attacked and `pred(u)` holds, run `act(u, attacker)`. Keeps the register/condition
-- boilerplate in one place. (Level AIs that need a generation guard or mute themselves
-- across a TriggerSleepAction stay written out explicitly — see setupLevel26/28/29.)
local function onAttackedTypeAI(unitType, pred, act)
    local trg = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(trg, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(trg, Condition(function()
        local u = GetAttackedUnitBJ()
        return GetUnitTypeId(u) == FourCC(unitType) and pred(u)
    end))
    TriggerAddAction(trg, function()
        act(GetAttackedUnitBJ(), GetAttacker())
    end)
    return trg
end

-- ─── Shared per-level infrastructure (war3map.j 19035-19120, 7436-7449, 6414-6422) ──

function ThingsToDoBeforeEveryLevelBegins()
    local function revive(hero)
        if hero then ReviveHeroLoc(hero, GetRectCenter(rct.StartingPlayerArea), true) end
    end
    for i = 1, 8 do revive(Heroes[i]) end
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
    DieHardActivated          = false   -- Diehard feat rearms each level (war3map.j 16352)
    if underAttackTrg then EnableTrigger(underAttackTrg) end  -- re-arm warning (war3map.j 6420)
end

-- ─── Bonuses & Upkeep (war3map.j 6431-7317, Upkeep_2 7319-7414) ──────────────

-- Per-class achievement payouts (war3map.j 6991-7308). Each row: the detection flag
-- (set in achievements.lua), the player-handle global, the gold, the message printed
-- after the player's name, and an optional `after` post-hook. BonusesAndUpkeep loops
-- this, paying + resetting any latched flag. Adding a class = adding one row.
local CLASS_PAYOUTS = {
    { flag='ClericofOrderBonusA',    player='ClericofOrderPlayer',  gold=200,  msg=" - |cffff0000- Dedicated Healer! - |cffffcc00+200 Gold|r - (Healed an ally that was about to die.)" },
    { flag='ClericofOrderBonusB',    player='ClericofOrderPlayer',  gold=100,  msg=" - |cffff0000- Symbol of Hope! - |cffffcc00+100 Gold|r - (Protected an ally in grave danger.)" },
    { flag='ClericOTSFBonusA',       player='ClericOTSFPlayer',     gold=75,   msg=" - |cffff0000- Chaplain! - |cffffcc00+75 Gold|r - (Frequent use of heals on allies.)" },
    { flag='ClericOTSFBonusB',       player='ClericOTSFPlayer',     gold=75,   msg=" - |cffff0000- Slingshot Pro! - |cffffcc00+75 Gold|r - (Frequent Flurry of Slingstones.)" },
    { flag='EarthenTemplarBonusA',   player='EarthenTemplarPlayer', gold=150,  msg=" - |cffff0000- Rage of the Earth! - |cffffcc00+150 Gold|r - (6+ earth elementals.)" },
    { flag='EarthenTemplarBonusB',   player='EarthenTemplarPlayer', gold=100,  msg=" - |cffff0000- Supreme Smasher! - |cffffcc00+100 Gold|r - (100+ units killed.)" },
    { flag='DwarvenAxeMasterBonusA', player='DwarvenAMPlayer',      gold=200,  msg=" - |cffff0000- Slice and Dice! - |cffffcc00+200 Gold|r - (Living Axe killed 30+ units.)" },
    { flag='DwarvenAxeMasterBonusB', player='DwarvenAMPlayer',      gold=25,   msg=" - |cffff0000- Naturally Aggressive! - |cffffcc00+25 Gold|r - (4 Ranks of Aggression.)" },
    { flag='MonkEFBonusA',           player='MonkEFPlayer',         gold=100,  msg=" - |cffff0000- One with Chakra! - |cffffcc00+100 Gold|r - (Chakra Burst healed 5+ heroes.)" },
    { flag='MonkEFBonusB',           player='MonkEFPlayer',         gold=150,  msg=" - |cffff0000- Blistering Speed! - |cffffcc00+150 Gold|r - (Frequent use of Blazing Speed.)" },
    { flag='ManAtArmsBonusA',        player='HiredWagesPlayer',     gold=150,  msg=" - |cffff0000- Pay Raise! - |cffffcc00+150 Gold|r - (4 Ranks of Hired Wages.)" },
    { flag='ManAtArmsBonusB',        player='ManAtArmsPlayer',      gold=100,  msg=" - |cffff0000- Hoarse Throat! - |cffffcc00+100 Gold|r - (Frequent Battle Shout.)" },
    { flag='MasterOTABonusA',        player='MasterOfTheArtPlayer', gold=100,  msg=" - |cffff0000- Bombardier! - |cffffcc00+100 Gold|r - (Blast cast 50+ times.)" },
    { flag='MasterOTABonusB',        player='MasterOfTheArtPlayer', gold=100,  msg=" - |cffff0000- Wielder of the Art! - |cffffcc00+100 Gold|r - (Essence Shock 50+ times.)" },
    { flag='FeralArchonBonus',       player='FeralArchonPlayer',    gold=100,  msg=" - |cffff0000- Beast Within! - |cffffcc00+100 Gold|r - (Tantrum slew multiple enemies.)" },
    { flag='FeralArchonBonusB',      player='FeralArchonPlayer',    gold=125,  msg=" - |cffff0000- Predator! - |cffffcc00+125 Gold|r - (Got the killing blow on a boss.)" },
    { flag='HumanEngineerBonusA',    player='HumanEngineerPlayer',  gold=150,  msg=" - |cffff0000- Master Crafter! - |cffffcc00+150 Gold|r - (Built 10+ structures.)" },
    { flag='HumanEngineerBonusB',    player='HumanEngineerPlayer',  gold=200,  msg=" - |cffff0000- Violent Engineer! - |cffffcc00+200 Gold|r - (Killed 50+ units as engineer.)" },
    { flag='SunSoulBonusA',          player='SunSoulPlayer',        gold=100,  msg=" - |cffff0000- Solar Guard! - |cffffcc00+100 Gold|r - (Frequent Solar Barrier.)" },
    { flag='SunSoulBonusB',          player='SunSoulPlayer',        gold=100,  msg=" - |cffff0000- Lightcaster! - |cffffcc00+100 Gold|r - (Frequent sunbeam.)" },
    { flag='SunSoulPenalty',         player='SunSoulPlayer',        gold=-400, msg=" - |cffff0000- Incinerated an Ally... - |cffffcc00-400 Gold|r - (Killed an ally with sunbeam.)" },
    { flag='PaladinJusticeBonusA',   player='PaladinJusticePlayer', gold=175,  msg=" - |cffff0000- Shining Beacon! - |cffffcc00+175 Gold|r - (Saved an ally from death.)" },
    { flag='PaladinJusticeBonusB',   player='PaladinJusticePlayer', gold=100,  msg=" - |cffff0000- Crusader! - |cffffcc00+100 Gold|r - (100+ units killed.)" },
    { flag='DwarvenRFBonusA',        player='DwarvenRFPlayer',      gold=25,   msg=" - |cffff0000- Titan's Stamina! - |cffffcc00+25 Gold|r - (4 Ranks of Dwarven Stamina.)" },
    { flag='DwarvenRFBonusB',        player='DwarvenRFPlayer',      gold=125,  msg=" - |cffff0000- Fearful Presence! - |cffffcc00+125 Gold|r - (Caused 15+ units to flee.)" },
    { flag='DiscipleBonusA',         player='DisciplePlayer',       gold=75,   msg=" - |cffff0000- Aura of Grace! - |cffffcc00+75 Gold|r - (Frequent Mass Restore.)" },
    { flag='DiscipleBonusB',         player='DisciplePlayer',       gold=200,  msg=" - |cffff0000- Cheat Death! - |cffffcc00+200 Gold|r - (Rescued an ally with Death Ward.)", after=function() GraceBonusObtained = true end },
    { flag='ArcaneArcherBonusA',     player='ArcaneArcherPlayer',   gold=50,   msg=" - |cffff0000- Power Shot! - |cffffcc00+50 Gold|r - (4 Ranks of Far Shot.)" },
    { flag='ArcaneArcherBonusB',     player='ArcaneArcherPlayer',   gold=100,  msg=" - |cffff0000- Sniper! - |cffffcc00+100 Gold|r - (Frequent Eagle Arrow.)" },
    { flag='AxeBrotherBonusA',       player='AxeBrotherPlayer',     gold=100,  msg=" - |cffff0000- Whirling Dervish! - |cffffcc00+100 Gold|r - (Frequent Whirlwind Attack.)" },
    { flag='AxeBrotherBonusB',       player='AxeBrotherPlayer',     gold=100,  msg=" - |cffff0000- Savage Fighter! - |cffffcc00+100 Gold|r - (50+ Decimate kills.)" },
    { flag='CentaurDruidBonusA',     player='CentaurDruidPlayer',   gold=100,  msg=" - |cffff0000- Cultivator! - |cffffcc00+100 Gold|r - (5+ treants created.)" },
    { flag='CentaurDruidBonusB',     player='CentaurDruidPlayer',   gold=100,  msg=" - |cffff0000- Nature's Wrath! - |cffffcc00+100 Gold|r - (Treants killed 50+ units.)" },
    { flag='ClericElvenWordBonusA',  player='ClericEWPlayer',       gold=150,  msg=" - |cffff0000- Mender! - |cffffcc00+150 Gold|r - (Frequent Regrowth healing.)" },
    { flag='ClericElvenWordBonusB',  player='ClericEWPlayer',       gold=100,  msg=" - |cffff0000- Mistress of Elven Heart! - |cffffcc00+100 Gold|r - (Absorbed a spell.)" },
    { flag='CrestedDrakeBonusA',     player='CrestedDrakePlayer',   gold=100,  msg=" - |cffff0000- Firebreather! - |cffffcc00+100 Gold|r - (Frequent Flame Wreath.)" },
    { flag='CrestedDrakeBonusB',     player='CrestedDrakePlayer',   gold=50,   msg=" - |cffff0000- Fangterror! - |cffffcc00+50 Gold|r - (4 Ranks of Drakefang.)" },
    { flag='HEBardBonusA',           player='BardPlayer',           gold=100,  msg=" - |cffff0000- Harmonic Healing! - |cffffcc00+100 Gold|r - (Frequent Melody of Mending.)" },
    { flag='HEBardBonusB',           player='BardPlayer',           gold=150,  msg=" - |cffff0000- Sower of Chaos! - |cffffcc00+150 Gold|r - (50+ units confused.)" },
}

function BonusesAndUpkeep(levelIndex)
    -- Helper: award gold + message to ALL human players.
    local function awardAll(gold, msg)
        DisplayTimedTextToForce(GetPlayersAll(), 10.0, msg)
        for i = 0, 7 do
            if IsHumanPlayer(Player(i)) then
                AdjustPlayerStateBJ(gold, Player(i), PLAYER_STATE_RESOURCE_GOLD)
            end
        end
        TotalBonusGold = TotalBonusGold + gold
    end

    -- Helper: award gold + message to ONE specific player.
    local function awardOne(gold, player, msg)
        if not player then return end
        DisplayTimedTextToForce(GetPlayersAll(), 10.0, msg)
        AdjustPlayerStateBJ(gold, player, PLAYER_STATE_RESOURCE_GOLD)
        TotalBonusGold = TotalBonusGold + gold
    end

    -- ── Universal bonuses (war3map.j 6886-6960) ───────────────────────────────
    if HeroFlawlessDeath then
        awardAll(100, "|cff00ff00Flawless!|r No hero died this round — |cffffcc00+100 Gold|r each.")
    elseif PlayerTotalDeathsForRound == 0 then
        awardAll(50, "|cff00ff00No hero deaths this round — |cffffcc00+50 Gold|r each.")
    end
    if StalwartDefender then
        awardAll(50, "|cff00ff00Stalwart Defender!|r No enemy reached the base — |cffffcc00+50 Gold|r each.")
    end
    -- Fountain bonus: is it at max mana? (war3map.j 6915-6923)
    if unit_h010 and GetUnitStateSwap(UNIT_STATE_MANA, unit_h010)
        >= GetUnitStateSwap(UNIT_STATE_MAX_MANA, unit_h010) then
        awardAll(50, "|cff00ccffFountain Full!|r Fountain at max mana — |cffffcc00+50 Gold|r each.")
    end
    if BlazingVictory then
        awardAll(200, "|cff00ff00Blazing Victory!|r Won in under 60s — |cffffcc00+200 Gold|r each.")
    elseif SpeedyVictory then
        awardAll(100, "|cff00ff00Speedy Victory!|r Won in under 120s — |cffffcc00+100 Gold|r each.")
    end
    -- Plant Hater: cleared all plant/treant enemies (war3map.j 6945-6953)
    if PlantHater then
        awardAll(200, "|cff00ff00Plant Hater!|r Cleansed the plant scourge — |cffffcc00+200 Gold|r each.")
        PlantHater = false
    end
    -- Prince is in danger: HP ≤ 150 (war3map.j 6954-6961)
    if unit_H02G and GetUnitStateSwap(UNIT_STATE_LIFE, unit_H02G) <= 150.0 then
        awardAll(10, "|cffff8800Prince is in danger! — |cffffcc00+10 Gold|r each.")
    end

    -- ── Level challenge bonus (already armed in StartLevel) ───────────────────
    if levelIndex and LevelBonuses[levelIndex] then
        awardAll(100, "|cff00ff00Level Bonus — |cffffcc00+100 Gold|r (level challenge met!)")
        LevelBonuses[levelIndex] = false
    end

    -- ── Milestone bonuses (war3map.j 6966-6990) ───────────────────────────────
    if FirstToDingOn then
        awardOne(50, FirstToDing,
            GetPlayerName(FirstToDing) .. " - |cffff0000- Leading the Way! - |r|cffffcc00+50 Gold|r - (First to hit level 2.)")
        FirstToDingOn = false
    end
    if bonusFirstToBuildOn then
        awardOne(100, FirstToBuild,
            GetPlayerName(FirstToBuild) .. " - |cffff0000- Constructor! - |r|cffffcc00+100 Gold|r - (First to build.)")
        bonusFirstToBuildOn = false
    end
    if bonusFirstToResearchOn then
        awardOne(100, FirstToResearch,
            GetPlayerName(FirstToResearch) .. " - |cffff0000- Researcher! - |r|cffffcc00+100 Gold|r - (First to research.)")
        bonusFirstToResearchOn = false
    end

    -- ── Man-at-Arms Hired Wages (war3map.j 6863-6882) ─────────────────────────
    local wagePayouts = { 25, 50, 75, 100, 150 }
    if HiredWages >= 1 and HiredWages <= 5 and HiredWagesPlayer then
        local pay = wagePayouts[HiredWages]
        AdjustPlayerStateBJ(pay, HiredWagesPlayer, PLAYER_STATE_RESOURCE_GOLD)
        WageTotal = WageTotal + pay
        TotalBonusGold = TotalBonusGold + pay
    end

    -- ── Per-class achievement bonuses (war3map.j 6991-7308) ───────────────────
    -- Data-driven from CLASS_PAYOUTS (above): flags/players are set by achievements.lua;
    -- here we pay out, announce, reset the flag, and run any post-hook.
    for _, b in ipairs(CLASS_PAYOUTS) do
        if _G[b.flag] then
            local p = _G[b.player]
            awardOne(b.gold, p, GetPlayerName(p) .. b.msg)
            _G[b.flag] = false
            if b.after then b.after() end
        end
    end

    -- ── Upkeep_2 equivalents (war3map.j 7369-7408) ────────────────────────────
    -- Reckless Pyromancer penalty (MajinPenalty, war3map.j 7370-7376)
    if MajinPenalty and MajinPlayer then
        DisplayTimedTextToForce(GetPlayersAll(), 10.0,
            GetPlayerName(MajinPlayer) .. " - |cffff0000- Incinerated an ally... - |cffffcc00-400 Gold|r - (Killed an allied hero.)")
        AdjustPlayerStateBJ(-400, MajinPlayer, PLAYER_STATE_RESOURCE_GOLD)
        MajinPenalty = false
    end
    -- Elven Sharpshooter: survived L1-10 without dying (war3map.j 7377-7382)
    if SharpshooterBonusA and CurrentLevel == 10 then
        local h02NGroup = GetUnitsOfTypeIdAll(FourCC('H02N'))
        local ss = GroupPickRandomUnit(h02NGroup)
        if ss then
            local ssPl = GetOwningPlayer(ss)
            DisplayTimedTextToForce(GetPlayersAll(), 10.0,
                GetPlayerName(ssPl) .. " - |cffff0000- Smart Survivalist - |cffffcc00+200 Gold|r - (Survived the first 10 levels.)")
            AdjustPlayerStateBJ(200, ssPl, PLAYER_STATE_RESOURCE_GOLD)
            TotalBonusGold = TotalBonusGold + 200
        end
        DestroyGroup(h02NGroup)
    end
    -- Elven Sharpshooter: Sniper's Mark kills (war3map.j 7383-7388)
    if SharpshooterBonusB and SharpshooterPlayer then
        awardOne(200, SharpshooterPlayer,
            GetPlayerName(SharpshooterPlayer) .. " - |cffff0000- Shoot to Kill - |cffffcc00+200 Gold|r - (10 Sniper's Mark kills.)")
        SharpshooterBonusB = false
    end
    -- Master of the Well: restore 50% mana to Fountain (war3map.j 7407, feat effect)
    if MasterOfWellActive and unit_h010 then
        SetUnitManaBJ(unit_h010, GetUnitStateSwap(UNIT_STATE_MANA, unit_h010)
            + GetUnitStateSwap(UNIT_STATE_MAX_MANA, unit_h010) * 0.50)
    end

    -- ── Applied Knowledge feat (war3map.j 15850-15857) ────────────────────────
    if AppliedKnowledgeHero then
        local xp = CurrentLevel * 10
        AddHeroXP(AppliedKnowledgeHero, xp, true)
        DisplayTextToForce(GetPlayersAll(),
            "|cff00ccff+" .. tostring(xp) .. " EXP! (Applied Knowledge)|r")
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

    -- heal self when attacked below 125 HP; divine shield when below 500 HP
    onAttackedTypeAI('H00C',
        function(u) return GetUnitState(u, UNIT_STATE_LIFE) <= 125.0 end,
        function(b) IssueTargetOrderBJ(b, "healingwave", b) end)
    onAttackedTypeAI('H00C',
        function(u) return GetUnitState(u, UNIT_STATE_LIFE) <= 500.0 end,
        function(b) IssueImmediateOrderBJ(b, "divineshield") end)
end

-- Level 8 enemy AI: h00Y casts firebolt at its attacker when ≤125 HP, then retreats
-- to the fortress entrance (war3map.j 20113-20127).
local function setupLevel8AI()
    onAttackedTypeAI('h00Y',
        function(u) return GetUnitState(u, UNIT_STATE_LIFE) <= 125.0 end,
        function(u, attacker)
            IssueTargetOrderBJ(u, "firebolt", attacker)
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
    -- ── Levels 13–29 ──────────────────────────────────────────────────────────
    [13] = {
        intro = "|cff66cc66Level 13|r — The ancient forest erupts! Find and slay the Ancient Treant.",
        track = 3, next = 14,
        spawns = {},         -- all initial spawns in setup hook
        victory = { type='itemPickup', item=FourCC('I00U') },
        setup = setupLevel13,
    },
    [14] = {
        -- Caravan escort — full pathing/trap mechanic not yet ported. Simplified.
        intro = "|cffff8800Level 14|r — Escort the caravan! Defend against ambushes.",
        track = 1, next = 15,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h01E'), n=3, dm=1, at=ABC },
            { u=FourCC('h01F'), n=2, dm=1, at=ABC },
            { u=FourCC('h01G'), n=1, dm=1, at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h01E'), FourCC('h01F'), FourCC('h01G') } },
        setup = setupLevel14,
    },
    [15] = {
        intro = "|cffff8800Level 15|r — Undead infantry with hellspawn support.",
        track = 2, next = 16,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h01E'), n=3, dm=1, at=ABC },
            { u=FourCC('h01F'), n=2, dm=1, at=ABC },
            { u=FourCC('h01R'), n=0, dm=1, at='HellSpawn' },
            { u=FourCC('h06Q'), n=1,       at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h01E'), FourCC('h01F'), FourCC('h01R'), FourCC('h06Q') } },
    },
    [16] = {
        intro = "|cffff8800Level 16|r — Warlocks (h01G) slow your heroes.",
        track = 3, next = 17,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h01E'), n=3, dm=1, at=ABC },
            { u=FourCC('h01F'), n=2, dm=1, at=ABC },
            { u=FourCC('h01G'), n=2, dm=1, at=ABC },
            { u=FourCC('h03T'), n=1, dm=1, at='HellSpawn' },
            { u=FourCC('h01R'), n=1, dm=1, at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h01E'), FourCC('h01F'), FourCC('h01G'), FourCC('h01R'), FourCC('h03T') } },
        setup = setupLevel16AI,
    },
    [17] = {
        intro = "|cffff8800Level 17|r — Necromancers (h01H) join the undead host.",
        track = 1, next = 18,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h01E'), n=3, dm=1, at=ABC },
            { u=FourCC('h01F'), n=2, dm=1, at=ABC },
            { u=FourCC('h01G'), n=2, dm=1, at=ABC },
            { u=FourCC('h01H'), n=1, dm=1, at=ABC },
            { u=FourCC('h01R'), n=1, dm=1, at='HellSpawn' },
            { u=FourCC('h03T'), n=1, dm=1, at='HellSpawn' },
            { u=FourCC('h06Q'), n=0, dm=1, at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h01E'), FourCC('h01F'), FourCC('h01G'), FourCC('h01H'),
            FourCC('h01R'), FourCC('h03T'), FourCC('h06Q') } },
        setup = setupLevel16AI,   -- h01G AI still present
    },
    [18] = {
        -- Death Blast level: enemies placed at MarkDamnation regions, not standard lanes.
        -- h01I periodically casts deathcoil. Victory when all h01I are slain.
        intro = "|cffff3300Level 18 — DEATH BLAST!|r Destroy the Plague Casters before they destroy you.",
        track = 2, next = 19,
        spawns = {},   -- all spawns in setup hook
        victory = { type='lastOfType', unit=FourCC('h01I') },
        setup = setupLevel18,
    },
    [19] = {
        -- Enemy HP boosted to 125% (SetPlayerHandicap). Adds h01Q + h06P.
        intro = "|cffff4400Level 19|r — Boosted enemy HP! The undead surge forward.",
        track = 3, next = 20,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h06O'), n=1,       at='CaravanPathA' },
            { u=FourCC('h01E'), n=3, dm=1, at=ABC },
            { u=FourCC('h01F'), n=2, dm=1, at=ABC },
            { u=FourCC('h01G'), n=2, dm=1, at=ABC },
            { u=FourCC('h01H'), n=1, dm=1, at=ABC },
            { u=FourCC('h01Q'), n=1, dm=1, at=ABC },
            { u=FourCC('h06P'), n=1,       at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h06O'), FourCC('h01E'), FourCC('h01F'), FourCC('h01G'),
            FourCC('h01H'), FourCC('h01Q'), FourCC('h06P') } },
        setup = setupLevel19,
    },
    [20] = {
        intro = "|cffff0000Level 20 — BOSS: Undead Behemoth!|r",
        next = 21, boss = true,
        spawns = {
            { u=FourCC('e01M'), n=1,  at=ABC },
            { u=FourCC('h01E'), n=5,  at='B' },
            { u=FourCC('h01G'), n=3,  at='B' },
            { u=FourCC('h01H'), n=3,  at='B' },
            { u=FourCC('h01Q'), n=3,  at='B' },
            { u=FourCC('O004'), n=1,  at='B' },   -- Undead Behemoth
            { u=FourCC('h04R'), n=1,  at='B' },
        },
        victory = { type='boss', unit=FourCC('O004') },
        setup = setupLevel20,
    },
    [21] = {
        -- Random placement level with Mimics. Simplified: spawn from Level21 regions.
        intro = "|cffff8800Level 21|r — The enemy scatters across the land. Hunt them all!",
        track = 1, next = 22,
        spawns = {},   -- all spawns in setup hook (Level21A-H regions)
        victory = { type='clearAll', units={ FourCC('h01S'), FourCC('h01R') } },
        setup = setupLevel21,
        noAutoPatrol = true,  -- patrol handled inside setup
    },
    [22] = {
        intro = "|cffff8800Level 22|r — Spectral undead (h01S) and river trolls (n00F) advance.",
        track = 2, next = 23,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h01S'), n=3, dm=1, at=ABC },
            { u=FourCC('h01R'), n=3, dm=1, at=ABC },
            { u=FourCC('n00F'), n=2, dm=1, at=ABC },
            { u=FourCC('h01R'), n=1, dm=1, at='HellSpawn' },
            { u=FourCC('h03T'), n=1, dm=1, at='HellSpawn' },
            { u=FourCC('h06Q'), n=0, dm=1, at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h01R'), FourCC('h01S'), FourCC('n00F'), FourCC('h06Q'), FourCC('h03T') } },
    },
    [23] = {
        intro = "|cffff8800Level 23|r — Gargoyles (h02O) and a massed undead assault.",
        track = 3, next = 24,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h01S'), n=3, dm=1, at=ABC },
            { u=FourCC('h01R'), n=3, dm=1, at=ABC },
            { u=FourCC('n00F'), n=2, dm=1, at=ABC },
            { u=FourCC('h02O'), n=0, dm=1, at='A' },
            { u=FourCC('h02O'), n=1, dm=1, at='B' },
            { u=FourCC('h02O'), n=0, dm=1, at='C' },
            { u=FourCC('h01R'), n=4, dm=1, at='HellSpawn' },
            { u=FourCC('h06P'), n=0, dm=1, at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h01R'), FourCC('h01S'), FourCC('n00F'), FourCC('h02O'), FourCC('h06P') } },
    },
    [24] = {
        intro = "|cffff4400Level 24|r — The final wave before the Megaboss!",
        track = 3, next = nil,  -- chains to Megaboss 1 (not yet ported)
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h06O'), n=1,       at='CaravanPathA' },
            { u=FourCC('h01S'), n=3, dm=1, at=ABC },
            { u=FourCC('h01R'), n=2, dm=1, at=ABC },
            { u=FourCC('h02O'), n=1, dm=1, at=ABC },
            { u=FourCC('h03T'), n=1, dm=1, at=ABC },
            { u=FourCC('h01R'), n=2, dm=1, at='HellSpawn' },
            { u=FourCC('h03T'), n=2, dm=1, at='HellSpawn' },
            { u=FourCC('h06P'), n=0, dm=1, at='HellSpawn' },
            { u=FourCC('h06Q'), n=1, dm=1, at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h06O'), FourCC('h01R'), FourCC('h01S'), FourCC('n00F'),
            FourCC('h02O'), FourCC('h03T'), FourCC('h06P'), FourCC('h06Q') } },
    },
    -- No Level 25 in original (numbering skips 24→Megaboss1→26)
    [26] = {
        intro = "|cffff4400Level 26|r — Boosted HP and damage! Dark Warlocks (h04M) lead the charge.",
        track = 3, next = 27,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h04M'), n=3, dm=1, at=ABC },
            { u=FourCC('h04N'), n=1, dm=1, at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h04M'), FourCC('h04N') } },
        setup = setupLevel26,
    },
    [27] = {
        intro = "|cffff8800Level 27|r — Summoners (h04O) reinforce the dark warlocks.",
        track = 3, next = 28,
        spawns = {
            { u=FourCC('e01M'), n=1,        at=ABC },
            { u=FourCC('h04M'), n=3, dm=1,  at=ABC },
            { u=FourCC('h04N'), n=1, dm=1,  at=ABC },
            { u=FourCC('h04O'), n=0, dm=4,  at=ABC },  -- 4*DM summons (multiply variant)
        },
        victory = { type='clearAll', units={ FourCC('h04M'), FourCC('h04N'), FourCC('h04O') } },
    },
    [28] = {
        intro = "|cffff8800Level 28|r — Spider webs across the land! Guardians (h04U) defend key zones.",
        track = 3, next = 29,
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h04M'), n=3, dm=1, at=ABC },
            { u=FourCC('h04N'), n=1, dm=1, at=ABC },
            { u=FourCC('h04O'), n=0, dm=4, at=ABC },
            { u=FourCC('h04V'), n=1, dm=1, at=ABC },
            -- h04U web guardians spawned in setup (random within spider web zones)
        },
        victory = { type='clearAll', units={
            FourCC('h04M'), FourCC('h04N'), FourCC('h04O'), FourCC('h04V') } },
        setup = function()
            -- spawn h04U × 2 per web zone then call AI setup
            for _, z in ipairs({'SpiderWebsA','SpiderWebsB','SpiderWebsC','SpiderWebsD'}) do
                CreateNUnitsAtLoc(1, FourCC('h04U'), P9, GetRandomLocInRect(rct[z]), bj_UNIT_FACING)
                CreateNUnitsAtLoc(1, FourCC('h04U'), P9, GetRandomLocInRect(rct[z]), bj_UNIT_FACING)
            end
            setupLevel28AI()
        end,
    },
    [29] = {
        intro = "|cffff8800Level 29|r — Shamans (h04W) summon spirits and a caravan raider strikes.",
        track = 3, next = 30,  -- L30 is a boss, not yet ported
        spawns = {
            { u=FourCC('e01M'), n=1,       at=ABC },
            { u=FourCC('h06O'), n=1,       at='CaravanPathA' },
            { u=FourCC('h04M'), n=3, dm=1, at=ABC },
            { u=FourCC('h04N'), n=1, dm=1, at=ABC },
            { u=FourCC('h04O'), n=0, dm=4, at=ABC },
            { u=FourCC('h04V'), n=1, dm=1, at=ABC },
            { u=FourCC('h04W'), n=1, dm=1, at=ABC },
        },
        victory = { type='clearAll', units={
            FourCC('h06O'), FourCC('h04M'), FourCC('h04N'), FourCC('h04O'), FourCC('h04V') } },
        setup = setupLevel29AI,
    },
}

-- ─── Generic spawn + victory plumbing ──────────────────────────────────────────

local activeVictoryTrigger = nil
local levelGen = 0   -- bumped each StartLevel; lets an in-flight victory abort if the level changed

-- ── Per-level setup hooks (levels 13-29) ──────────────────────────────────────

-- Level 13: Ancient Forest (war3map.j 20755-21012)
-- h018×DM at 13 ForestOverrun zones + h019 (Ancient Treant) at AngryEnt.
-- Victory: pick up I00U dropped by h019. Periodic reinforcement waves from SpawnA.
-- Hurry-up: warning at T+180s/240s, punishment wave at T+300s.
local function setupLevel13()
    local gen = levelGen
    local TREANT = FourCC('h018')
    local BOSS   = FourCC('h019')
    local FOREST_ZONES = {
        'ForestOverRunA','ForestOverrunB','ForestOverrunC','ForestOverrunD',
        'ForestOverrunE','ForestOverrunF','ForestOverrunG','ForestOverrunH',
        'ForestOverrunI','ForestOverrunJ','ForestOverrunK','ForestOverrunL',
        'ForestOverrunM',
    }
    -- initial spawn
    for _, zone in ipairs(FOREST_ZONES) do
        local n = DifficultyModifier
        if n > 0 then
            CreateNUnitsAtLoc(n, TREANT, P9, GetRectCenter(rct[zone]), bj_UNIT_FACING)
        end
    end
    CreateNUnitsAtLoc(1, BOSS, P9, GetRectCenter(rct.AngryEnt), bj_UNIT_FACING)

    -- h019 drops I00U on death (Level_13_ItemSpawn, war3map.j 20914)
    local itemDropTrg = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(itemDropTrg, P9, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(itemDropTrg, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == BOSS
    end))
    TriggerAddAction(itemDropTrg, function()
        CreateItemLoc(FourCC('I00U'), GetUnitLoc(GetDyingUnit()))
        DisableTrigger(itemDropTrg)
    end)

    -- periodic reinforcement waves from SpawnA (war3map.j 20973-21006)
    -- delays: +22s, +22s, +18s, +22s after level start
    local base = GetRectCenter(rct.StartingPlayerArea)
    local function patrolAll()
        local all = GetUnitsOfPlayerAll(P9)
        ForGroup(all, function() IssuePointOrderLoc(GetEnumUnit(), "patrol", base) end)
        DestroyGroup(all)
    end
    local waves = {
        { delay = 22, fn = function()
            CreateNUnitsAtLoc(2, FourCC('h014'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            if DifficultyModifier > 0 then
                CreateNUnitsAtLoc(DifficultyModifier, FourCC('h016'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            end
            CreateNUnitsAtLoc(1, FourCC('h00W'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
        end },
        { delay = 44, fn = function()
            CreateNUnitsAtLoc(3, FourCC('h014'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            CreateNUnitsAtLoc(2, FourCC('h016'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            CreateNUnitsAtLoc(4, FourCC('h014'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            CreateNUnitsAtLoc(2, FourCC('h00W'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
        end },
        { delay = 62, fn = function()
            CreateNUnitsAtLoc(1, FourCC('h016'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            CreateNUnitsAtLoc(3, FourCC('h014'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            CreateNUnitsAtLoc(1, FourCC('h017'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
        end },
        { delay = 84, fn = function()
            CreateNUnitsAtLoc(2, FourCC('h016'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            CreateNUnitsAtLoc(3, FourCC('h017'), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
        end },
    }
    for _, w in ipairs(waves) do
        local t = CreateTimer()
        TimerStart(t, w.delay, false, function()
            if not Level13Beaten and levelGen == gen then w.fn(); patrolAll() end
            DestroyTimer(t)
        end)
    end

    -- hurry-up (war3map.j 20870-20896): warns at T+180s, T+240s, spawns h039 at T+300s
    local t180 = CreateTimer()
    TimerStart(t180, 180.0, false, function()
        if not Level13Beaten and levelGen == gen then
            DisplayTextToForce(GetPlayersAll(), "|cffff8800The forest stirs — hurry up!|r")
            PlaySoundBJ(snd.CreepAggroWhat1)
        end
        DestroyTimer(t180)
    end)
    local t240 = CreateTimer()
    TimerStart(t240, 240.0, false, function()
        if not Level13Beaten and levelGen == gen then
            DisplayTextToForce(GetPlayersAll(), "|cffff4400The forest is erupting — kill the Ancient Treant!|r")
            PlaySoundBJ(snd.CreepAggroWhat1)
        end
        DestroyTimer(t240)
    end)
    local t300 = CreateTimer()
    TimerStart(t300, 300.0, false, function()
        if not Level13Beaten and levelGen == gen then
            DisplayTextToForce(GetPlayersAll(), "|cffff0000TOO SLOW! The forest strikes back!|r")
            PlaySoundBJ(snd.CreepAggroWhat1)
            for _, lane in ipairs({'SpawnA','SpawnB','SpawnC'}) do
                CreateNUnitsAtLoc(4, FourCC('h039'), P9, GetRectCenter(rct[lane]), bj_UNIT_FACING)
            end
            patrolAll()
        end
        DestroyTimer(t300)
    end)
end

-- Level 14: Caravan Escort stub (war3map.j 21017-21043 + 21147+)
-- Full pathing + trap/miniboss mechanic not yet ported.
-- Simplified: spawn attacker enemies + place caravan as flavor unit.
local function setupLevel14()
    CreateNUnitsAtLoc(1, FourCC('h01A'), Player(8), GetRectCenter(rct.StartingPlayerArea), bj_UNIT_FACING)
    CreateNUnitsAtLoc(1, FourCC('h01B'), Player(8), GetRectCenter(rct.Hermit), bj_UNIT_FACING)
end

-- Level 16 AI: h01G casts slow on its attacker (war3map.j 21789-21798)
local function setupLevel16AI()
    local gen = levelGen
    local aiTrg = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(aiTrg, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(aiTrg, Condition(function()
        return GetUnitTypeId(GetAttacker()) == FourCC('h01G') and levelGen == gen
    end))
    TriggerAddAction(aiTrg, function()
        IssueTargetOrderBJ(GetAttacker(), "slow", GetAttackedUnitBJ())
    end)
end

-- Level 18: Death Blast (war3map.j 21933-22278)
-- Units placed in MarkDamnation regions + h03T@HellSpawn. Periodic wave spawns
-- from ABC. All h01I die every 10s cast deathcoil at a random enemy. Victory when
-- last h01I dies (armLastOfTypeVictory handles this).
local function setupLevel18()
    local gen = levelGen
    local DAMNATION = {rct.MarkDamnationA, rct.MarkDamnationB, rct.MarkDamnationC, rct.MarkDamnationD}
    -- initial placement at MarkDamnation zones
    for _, zone in ipairs(DAMNATION) do
        CreateNUnitsAtLoc(1, FourCC('h01I'), P9, GetRectCenter(zone), bj_UNIT_FACING)
        if DifficultyModifier > 0 then
            CreateNUnitsAtLoc(DifficultyModifier, FourCC('h01E'), P9, GetRandomLocInRect(zone), bj_UNIT_FACING)
        end
        CreateNUnitsAtLoc(1, FourCC('h01E'), P9, GetRandomLocInRect(zone), bj_UNIT_FACING)
        CreateNUnitsAtLoc(1, FourCC('h01E'), P9, GetRandomLocInRect(zone), bj_UNIT_FACING)
        CreateNUnitsAtLoc(1, FourCC('h01E'), P9, GetRandomLocInRect(zone), bj_UNIT_FACING)
        CreateNUnitsAtLoc(2, FourCC('h01G'), P9, GetRandomLocInRect(zone), bj_UNIT_FACING)
        CreateNUnitsAtLoc(1, FourCC('h01H'), P9, GetRandomLocInRect(zone), bj_UNIT_FACING)
    end
    CreateNUnitsAtLoc(7 + DifficultyModifier, FourCC('h03T'), P9,
        GetRectCenter(rct.HellSpawn), bj_UNIT_FACING)

    -- Death Blast: h01I casts deathcoil every 10s (war3map.j 22268-22278)
    local deathBlast = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(deathBlast, 10.0)
    TriggerAddAction(deathBlast, function()
        if levelGen ~= gen then DisableTrigger(deathBlast); return end
        local grp = GetUnitsOfTypeIdAll(FourCC('h01I'))
        ForGroup(grp, function()
            local tgt = GroupPickRandomUnit(GetUnitsInRangeOfLocMatching(
                1500.0, GetUnitLoc(GetEnumUnit()),
                Condition(function()
                    return GetOwningPlayer(GetFilterUnit()) ~= P9
                        and GetOwningPlayer(GetFilterUnit()) ~= Player(8)
                end)))
            if tgt then IssueTargetOrderBJ(GetEnumUnit(), "deathcoil", tgt) end
        end)
        DestroyGroup(grp)
    end)

    -- Periodic reinforcement waves (war3map.j 22146-22240), intervals ~20-32s
    -- Simplified to fixed 26s intervals (midpoint of original rand(20,32))
    local waveCount = 0
    local waveData = {
        -- wave 1
        { {2,'h01F','B'},{2,'h01E','B'},{2,'h01E','A'},{2,'h01F','C'},{2,'h01E','C'},{2,'h01F','A'},
          {1,'h01G','A'},{1,'h01G','C'},{1,'h01G','B'} },
        -- wave 2
        { {1,'h01E','A'},{1,'h01E','B'},{1,'h01E','C'},{1,'h01F','C'},{1,'h01F','B'},{1,'h01F','A'},
          {1,'h01G','A'},{1,'h01G','C'},{1,'h01G','B'},{1,'h01H','C'},{1,'h01H','B'},{1,'h01H','A'} },
        -- wave 3
        { {1,'h01E','A'},{1,'h01E','B'},{1,'h01E','C'},{3,'h01F','C'},{1,'h01F','B'},{3,'h01F','A'},
          {1,'h01G','A'},{1,'h01G','C'},{1,'h01G','B'},{1,'h01H','B'} },
        -- wave 4 (big push)
        { {6,'h01E','A'},{6,'h01E','B'},{6,'h01E','C'} },
        -- wave 5
        { {2,'h01E','A'},{1,'h01E','B'},{1,'h01E','C'},{1,'h01F','C'},{2,'h01F','B'},{1,'h01F','A'},
          {1,'h01G','A'},{2,'h01G','C'},{1,'h01G','B'} },
        -- wave 6
        { {3,'h01E','A'},{1,'h01E','B'},{3,'h01E','C'},{2,'h01F','C'},{2,'h01F','B'},{1,'h01F','A'},
          {1,'h01G','A'},{1,'h01G','C'},{1,'h01G','B'} },
    }
    local function spawnWave18(idx)
        for _, s in ipairs(waveData[idx]) do
            local n, uid, lane = s[1], s[2], s[3]
            CreateNUnitsAtLoc(n, FourCC(uid), P9,
                GetRectCenter(rct['Spawn' .. lane]), bj_UNIT_FACING)
        end
        local base = GetRectCenter(rct.StartingPlayerArea)
        for _, lane in ipairs({'SpawnA','SpawnB','SpawnC'}) do
            local inLane = GetUnitsInRectOfPlayer(rct['Spawn' .. lane:sub(-1)], P9)
            ForGroup(inLane, function()
                IssuePointOrderLoc(GetEnumUnit(), "patrol", base)
            end)
            DestroyGroup(inLane)
        end
    end
    local function scheduleWave(delay, idx)
        local t = CreateTimer()
        TimerStart(t, delay, false, function()
            if not Level18Beaten and levelGen == gen then spawnWave18(idx) end
            DestroyTimer(t)
        end)
    end
    -- stagger waves; original uses rand(20,32) per gap — use midpoint 26s
    local acc = 26.0
    for i = 1, #waveData do
        scheduleWave(acc, i)
        acc = acc + 26.0
    end
end

-- Level 19: HP boost wave (war3map.j 22289-22332)
-- Sets Player(9) handicap to 125% HP, spawns h06O + dense undead + h06P.
local function setupLevel19()
    SetPlayerHandicapBJ(P9, 125.0)
end

-- Level 20: Undead Behemoth Boss O004 (war3map.j 22415-22453)
-- AI: Call to Grave (faeriefire+HP-cut), Blood Pulse (AoE + self-heal), Devouring Plague (shadowstrike)
local function setupLevel20()
    local gen = levelGen
    -- configure boss
    local O004 = FourCC('O004')
    local grp = GetUnitsOfTypeIdAll(O004)
    ForGroup(grp, function()
        local b = GetEnumUnit()
        local lvl = math.max(1, 6 * DifficultyModifier)
        SetHeroLevelBJ(b, lvl, false)
        SelectHeroSkill(b, FourCC('AEsh'))  -- shadow strike / call to grave ability
    end)
    DestroyGroup(grp)

    -- AI1 (every 35s): Call to the Grave — faeriefire + HP reduced to 25% after countdown
    local ai1 = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(ai1, 35.0)
    TriggerAddAction(ai1, function()
        if levelGen ~= gen then DisableTrigger(ai1); return end
        local boss = GroupPickRandomUnit(GetUnitsOfTypeIdAll(O004))
        if not boss then return end
        local tgt = GroupPickRandomUnit(GetUnitsInRangeOfLocMatching(
            2000.0, GetUnitLoc(boss),
            Condition(function()
                return GetOwningPlayer(GetFilterUnit()) ~= P9
                    and IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO)
            end)))
        if not tgt then return end
        IssueTargetOrderBJ(boss, "faeriefire", tgt)
        DisplayTextToForce(GetPlayersAll(),
            "|cffff0000" .. GetUnitName(tgt) .. " — Call to the Grave! Will take massive damage in 30s!|r")
        -- 30s later: cut HP to 25%
        local capturedTgt = tgt
        local tTimer = CreateTimer()
        TimerStart(tTimer, 30.0, false, function()
            if levelGen == gen and GetUnitTypeId(capturedTgt) ~= 0 then
                SetUnitLifeBJ(capturedTgt,
                    GetUnitStateSwap(UNIT_STATE_LIFE, capturedTgt) / 4.0)
            end
            DestroyTimer(tTimer)
        end)
    end)

    -- AI2 (every 24s): Blood Pulse — AoE around boss + self-heal
    local ai2 = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(ai2, 24.0)
    TriggerAddAction(ai2, function()
        if levelGen ~= gen then DisableTrigger(ai2); return end
        local boss = GroupPickRandomUnit(GetUnitsOfTypeIdAll(O004))
        if not boss then return end
        DisplayTextToForce(GetPlayersAll(), "|cffff8800Blood Pulse!|r")
        local bx, by = GetUnitX(boss), GetUnitY(boss)
        UnitDamagePoint(boss, 0, 125.0, bx, by, 200.0,
            true, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        SetUnitLifeBJ(boss, GetUnitStateSwap(UNIT_STATE_LIFE, boss) + 400.0)
    end)

    -- AI3 (every 20s): Devouring Plague — shadowstrike on nearby enemy
    local ai3 = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(ai3, 20.0)
    TriggerAddAction(ai3, function()
        if levelGen ~= gen then DisableTrigger(ai3); return end
        local boss = GroupPickRandomUnit(GetUnitsOfTypeIdAll(O004))
        if not boss then return end
        local tgt = GroupPickRandomUnit(GetUnitsInRangeOfLocMatching(
            600.0, GetUnitLoc(boss),
            Condition(function()
                return GetOwningPlayer(GetFilterUnit()) ~= P9
            end)))
        if tgt then IssueTargetOrderBJ(boss, "shadowstrike", tgt) end
    end)
end

-- Level 21: Random mob placement + Mimics stub (war3map.j 22818-23212)
-- Simplified: sparse spawn at Level21A-H regions, clearAll h01S+h01R.
local function setupLevel21()
    local gen = levelGen
    local base = GetRectCenter(rct.StartingPlayerArea)
    local zones = {
        'Level21A','Level21B','Level21C','Level21D',
        'Level21E','Level21F','Level21G','Level21H',
    }
    for _, z in ipairs(zones) do
        CreateNUnitsAtLoc(4, FourCC('h01S'), P9, GetRandomLocInRect(rct[z]), bj_UNIT_FACING)
        CreateNUnitsAtLoc(4, FourCC('h01R'), P9, GetRandomLocInRect(rct[z]), bj_UNIT_FACING)
    end
    -- h01S casts curse on attacker (Level_21_AI, war3map.j 22857-22862)
    local aiTrg = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(aiTrg, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(aiTrg, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == FourCC('h01S') and levelGen == gen
    end))
    TriggerAddAction(aiTrg, function()
        DisableTrigger(aiTrg)
        IssueTargetOrderBJ(GetAttackedUnitBJ(), "curse", GetAttacker())
        local t = CreateTimer()
        TimerStart(t, 1.0, false, function()
            if levelGen == gen then EnableTrigger(aiTrg) end
            DestroyTimer(t)
        end)
    end)
    -- patrol to base
    local all = GetUnitsOfPlayerAll(P9)
    ForGroup(all, function() IssuePointOrderLoc(GetEnumUnit(), "patrol", base) end)
    DestroyGroup(all)
    -- hurry-up: after 300s spawn h04L from SpawnC
    local t300 = CreateTimer()
    TimerStart(t300, 300.0, false, function()
        if not Level21Beaten and levelGen == gen then
            DisplayTextToForce(GetPlayersAll(), "|cffff0000The hidden guardian appears!|r")
            PlaySoundBJ(snd.CreepAggroWhat1)
            CreateNUnitsAtLoc(1, FourCC('h04L'), P9, GetRectCenter(rct.SpawnC), bj_UNIT_FACING)
        end
        DestroyTimer(t300)
    end)
end

-- Level 26: HP+DMG boost, cleanup e00U units (war3map.j 23497-23533)
-- h04M casts carrionswarm at attacker when ≤50% HP (Level_26_AI, war3map.j 23593-23613)
local function setupLevel26()
    SetPlayerHandicapBJ(P9, 135.0)
    SetPlayerHandicapDamageBJ(P9, 125.0)
    local e00U = GetUnitsOfTypeIdAll(FourCC('e00U'))
    ForGroup(e00U, function() RemoveUnit(GetEnumUnit()) end)
    DestroyGroup(e00U)

    local gen = levelGen
    local aiTrg = CreateTrigger()
    DisableTrigger(aiTrg)
    TriggerRegisterPlayerUnitEventSimple(aiTrg, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(aiTrg, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == FourCC('h04M')
            and GetUnitLifePercent(GetAttackedUnitBJ()) <= 50.0
            and levelGen == gen
    end))
    TriggerAddAction(aiTrg, function()
        local u = GetAttackedUnitBJ()
        local atkLoc = GetUnitLoc(GetAttacker())
        for _ = 1, 5 do
            IssuePointOrderLoc(u, "carrionswarm", atkLoc)
            TriggerSleepAction(2.0)
        end
        RemoveLocation(atkLoc)
    end)
    EnableTrigger(aiTrg)
end

-- Level 28: h04V windwalk + retreat (Level_28_AI, war3map.j 23824-23837)
local function setupLevel28AI()
    local gen = levelGen
    local aiTrg = CreateTrigger()
    DisableTrigger(aiTrg)
    TriggerRegisterPlayerUnitEventSimple(aiTrg, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(aiTrg, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == FourCC('h04V')
            and GetUnitLifePercent(GetAttackedUnitBJ()) <= 50.0
            and levelGen == gen
    end))
    TriggerAddAction(aiTrg, function()
        local u = GetAttackedUnitBJ()
        IssueImmediateOrderBJ(u, "windwalk")
        TriggerSleepAction(2.0)
        IssuePointOrderLoc(u, "move", GetRectCenter(rct.EntranceToFortress))
    end)
    EnableTrigger(aiTrg)
end

-- Level 29: h04W (Shaman) casts spiritwolf when attacked at ≤80% HP and full mana
-- (Level_29_AI, war3map.j 23996-24025)
local function setupLevel29AI()
    local gen = levelGen
    local aiTrg = CreateTrigger()
    DisableTrigger(aiTrg)
    TriggerRegisterPlayerUnitEventSimple(aiTrg, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(aiTrg, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == FourCC('h04W')
            and GetUnitLifePercent(GetAttackedUnitBJ()) <= 80.0
            and GetUnitManaPercent(GetAttackedUnitBJ()) >= 99.0
            and levelGen == gen
    end))
    TriggerAddAction(aiTrg, function()
        local u = GetAttackedUnitBJ()
        for _ = 1, 8 do
            IssueImmediateOrderBJ(u, "spiritwolf")
            TriggerSleepAction(2.0)
        end
    end)
    EnableTrigger(aiTrg)
end

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
    local myGen = levelGen
    MusicOn     = false
    BossMusic   = false
    StopAllMusic()        -- silence boss track on victory; vanilla wave music resumes via WaveMusicTick
    LevelBeaten = true
    PlaySoundBJ(snd.RoundClear)
    ThingsToDoImmediatelyFollowingVictory()
    SupplyStockingItems()  -- sort ground items into cleanup zones if researched (economy/Economy.md §3)
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
    if levelGen ~= myGen then return end   -- level changed during the victory sequence (e.g. -goto)
    if data.next and LevelData[data.next] then
        CurrentLevel = data.next
        StartLevel(data.next)
    else
        CurrentLevel = data.next or levelIndex
        DisplayTextToForce(GetPlayersAll(),
            "|cffff8800Level " .. (data.next or "?") .. "+ not yet ported (Phase 6 in progress).|r")
    end
end

-- Victory: player picks up the specific item (e.g. Level 13 drop).
local function armItemPickupVictory(data, levelIndex)
    local trg = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(trg, Condition(function()
        return GetItemTypeId(GetManipulatedItem()) == data.victory.item
    end))
    TriggerAddAction(trg, function()
        DisableTrigger(trg)
        RemoveItem(GetManipulatedItem())
        local grp = GetUnitsInRectOfPlayer(rct.EntireGameArea, P9)
        ForGroup(grp, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(grp)
        onLevelVictory(data, levelIndex)
    end)
    activeVictoryTrigger = trg
end

-- Victory: fires on Player(9) unit death; checks if the last unit of that type died.
local function armLastOfTypeVictory(data, levelIndex)
    local trg = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(trg, P9, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(trg, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == data.victory.unit
            and CountLivingPlayerUnitsOfTypeId(data.victory.unit, P9) == 0
    end))
    TriggerAddAction(trg, function()
        DisableTrigger(trg)
        local grp = GetUnitsInRectOfPlayer(rct.EntireGameArea, P9)
        ForGroup(grp, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(grp)
        onLevelVictory(data, levelIndex)
    end)
    activeVictoryTrigger = trg
end

local function armClearAllVictory(data, levelIndex)
    local trg = CreateTrigger()   -- capture our OWN trigger (not the shared upvalue)
    DisableTrigger(trg)
    TriggerRegisterTimerEventPeriodic(trg, 8.0)
    TriggerAddAction(trg, function()
        for _, u in ipairs(data.victory.units) do
            if CountLivingPlayerUnitsOfTypeId(u, P9) > 0 then return end
        end
        DisableTrigger(trg)
        onLevelVictory(data, levelIndex)
    end)
    EnableTrigger(trg)
    activeVictoryTrigger = trg
end

local function armBossVictory(data, levelIndex)
    local trg = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(trg, P9, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(trg, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == data.victory.unit
    end))
    TriggerAddAction(trg, function()
        DisableTrigger(trg)
        -- clear remaining trash so the next level starts clean
        local grp = GetUnitsInRectOfPlayer(rct.EntireGameArea, P9)
        ForGroup(grp, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(grp)
        onLevelVictory(data, levelIndex)
    end)
    activeVictoryTrigger = trg
end

-- ─── The generic level entry point ─────────────────────────────────────────────

StartLevel = function(n)
    local data = LevelData[n]
    if not data then
        DisplayTextToForce(GetPlayersAll(), "|cffff0000Level " .. n .. " has no data.|r")
        return
    end
    -- Cancel any previous level's victory poll/trigger (e.g. when jumping via -goto/-wave
    -- before the current level was cleared) so it can't fire for the wrong level.
    if activeVictoryTrigger then DisableTrigger(activeVictoryTrigger); activeVictoryTrigger = nil end
    levelGen = levelGen + 1

    CurrentLevel = n
    ThingsToDoBeforeEveryLevelBegins()
    LevelBonuses[n] = true

    TriggerSleepAction(1.0)
    PlaySoundBJ(snd.Courageous)
    DisplayTimedTextToForce(GetPlayersAll(), 20.0, data.intro)
    TriggerSleepAction(1.0)

    -- Enable per-level challenge bonus trigger (achievements.lua, JASS 9167-9348)
    if     n == 1 then
        if trg_Level_1_Bonus     then EnableTrigger(trg_Level_1_Bonus) end
    elseif n == 2 then
        if trg_Level_2_Bonus     then EnableTrigger(trg_Level_2_Bonus) end
        if trg_Level_2_Bonus_Add then EnableTrigger(trg_Level_2_Bonus_Add) end
    elseif n == 3 then
        if trg_Level_3_Bonus     then EnableTrigger(trg_Level_3_Bonus) end
    elseif n == 4 then
        if trg_Level_4_Bonus     then EnableTrigger(trg_Level_4_Bonus) end
    elseif n == 5 then
        if trg_Level_5_Bonus     then EnableTrigger(trg_Level_5_Bonus) end
    end

    spawnLevel(data)
    if data.prisoners then spawnPrisoners() end
    if data.setup then data.setup() end

    TriggerSleepAction(1.0)
    if not data.noAutoPatrol then patrolEnemiesToBase() end
    StartFastVictoriesTimer()
    MusicOn = true
    if data.track then CurrentTrackMusic = data.track end  -- nil = keep previous (e.g. L6 miniboss)
    PlaySoundBJ(snd.SlowRezzSound)   -- per-level reinforcement cue (war3map.j level actions)

    TriggerSleepAction(0.75)
    if data.victory.type == 'boss' then
        armBossVictory(data, n)
    elseif data.victory.type == 'itemPickup' then
        armItemPickupVictory(data, n)
    elseif data.victory.type == 'lastOfType' then
        armLastOfTypeVictory(data, n)
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
