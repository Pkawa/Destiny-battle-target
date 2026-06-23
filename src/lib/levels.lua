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
    -- (Re)station the player-built garrison for this level (no-op until a guard post is built).
    SpawnMeleeGuards()   -- buildings.lua (war3map.j Spawn_Melee_Guards 9905)
    SpawnArcherGuards()  -- buildings.lua (war3map.j Spawn_Archer_Guards 9966)
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
    -- Swashbuckler Opportunist: skim bonus gold after every award (war3map.j 6888-6955, 9114-9151).
    local function opportunist()
        if trg_Opportunist_Gain then ConditionalTriggerExecute(trg_Opportunist_Gain) end
    end

    -- Helper: award gold + message to ALL human players.
    local function awardAll(gold, msg)
        DisplayTimedTextToForce(GetPlayersAll(), 10.0, msg)
        for i = 0, 7 do
            if IsHumanPlayer(Player(i)) then
                AdjustPlayerStateBJ(gold, Player(i), PLAYER_STATE_RESOURCE_GOLD)
            end
        end
        TotalBonusGold = TotalBonusGold + gold
        opportunist()
    end

    -- Helper: award gold + message to ONE specific player.
    local function awardOne(gold, player, msg)
        if not player then return end
        DisplayTimedTextToForce(GetPlayersAll(), 10.0, msg)
        AdjustPlayerStateBJ(gold, player, PLAYER_STATE_RESOURCE_GOLD)
        TotalBonusGold = TotalBonusGold + gold
        opportunist()
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
    -- Princess Silmeria (H02G) is in danger: HP ≤ 150 (war3map.j 6954-6961)
    if unit_H02G and GetUnitStateSwap(UNIT_STATE_LIFE, unit_H02G) <= 150.0 then
        awardAll(10, "|cffff8800Princess Silmeria is in danger! — |cffffcc00+10 Gold|r each.")
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
        local h02NGroup = GetUnitsOfTypeIdAll(UID.ElvenSharpshooter)
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

    -- ── Paladin of Justice Crusade (war3map.j 6858) ───────────────────────────
    -- Grants the Paladin escalating stats each cleared level (combat/Abilities.md).
    if trg_Crusade then ConditionalTriggerExecute(trg_Crusade) end

    -- ── Cursed item drop roll (war3map.j 7405: Upkeep_2 → Cursed_Item_Drop_1_to_10) ──
    -- Per-level d10 roll; the first success arms the one-shot cursed drop. Self-guards
    -- once CursedItemOn is false, so it's safe to call every level (items.lua).
    CursedItemRoll()

    -- ── Companionship (war3map.j 7390 + 7406: Check_Companionships + Companionship_Checking) ──
    -- Proximity-bond flavor tally + bond announcement (half-finished in the original; no
    -- stat buff). Faithful port lives in buildings.lua. Buildings.md §4.
    CheckCompanionships()
end

-- ─── Per-level setup hooks (boss stats/skills + enemy AI) ──────────────────────

-- Level 6 miniboss: Paladin commander H00C (war3map.j 19788-19960)
local function setupLevel6Boss()
    local grp = GetUnitsOfTypeIdAll(UID.PaladinCommander)
    ForGroup(grp, function()
        local b = GetEnumUnit()
        SetHeroLevelBJ(b, 5 + DifficultyModifier, false)
        SelectHeroSkill(b, FourCC('AHds'))  -- Divine Shield
        SelectHeroSkill(b, FourCC('AOhw'))  -- Healing Wave
        SelectHeroSkill(b, FourCC('AHre'))  -- Resurrection
    end)
    DestroyGroup(grp)

    -- heal self when attacked below 125 HP; divine shield when below 500 HP
    -- (Ai/Ai2 self-deactivate once H00C is removed at victory — the predicate stops matching.)
    onAttackedTypeAI('H00C',
        function(u) return GetUnitState(u, UNIT_STATE_LIFE) <= 125.0 end,
        function(b) IssueTargetOrderBJ(b, "healingwave", b) end)
    onAttackedTypeAI('H00C',
        function(u) return GetUnitState(u, UNIT_STATE_LIFE) <= 500.0 end,
        function(b) IssueImmediateOrderBJ(b, "divineshield") end)

    -- Boss Ai3 (war3map.j Level_6_Boss_Ai3 19946-19964): when his squire line thins to
    -- ≤4 living h002, Meldokk casts Resurrection to bring the fallen squires back. Fires on
    -- any Player(9) death; gated on a living H00C so it goes inert after victory (and never
    -- triggers on later levels, which also field h002).
    local res = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(res, P9, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(res, Condition(function()
        return CountLivingPlayerUnitsOfTypeId(FourCC('H00C'), P9) > 0
            and CountLivingPlayerUnitsOfTypeId(FourCC('h002'), P9) <= 4
    end))
    TriggerAddAction(res, function()
        local hg = GetUnitsOfTypeIdAll(FourCC('H00C'))
        local b = GroupPickRandomUnit(hg)
        DestroyGroup(hg)
        if b then IssueImmediateOrderBJ(b, "resurrection") end
    end)
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

-- Level 10 boss: Goblin King O001 (war3map.j 20290-20520).
-- Spells (Lackeys ANsq, Fury/Stampede AHtc, Spire ANst) are granted here, and the four
-- cast-AI triggers (Lv_10_Boss_AI_1..4, 20368-20499) drive them.
local function setupLevel10Boss()
    StartBossMusic()   -- BossMusic1.mp3 loop (war3map.j 20323-20325)
    GoblinSlayer = true
    local grp = GetUnitsOfTypeIdAll(UID.GoblinKing)
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

    -- ── Cast-AI (war3map.j Lv_10_Boss_AI_1..4) ───────────────────────────────────
    -- All four fire while a Goblin King lives; AI 1/2/4 key off "O001 attacked" and so go
    -- inert once he's removed at victory, and the periodic AI 3 disables itself when none
    -- remain. `bossGanked` (a shared upvalue, = the JASS udg_BossGanked) counts hits taken.
    local bossGanked = 0
    local kingGone = function() return CountLivingPlayerUnitsOfTypeId(UID.GoblinKing, P9) == 0 end
    local function forEachKing(order)
        local g = GetUnitsOfTypeIdAll(UID.GoblinKing)
        ForGroup(g, function() IssueImmediateOrderBJ(GetEnumUnit(), order) end)
        DestroyGroup(g)
    end
    local function patrolKingsHome()
        local g = GetUnitsOfTypeIdAll(UID.GoblinKing)
        ForGroup(g, function()
            IssuePointOrderLoc(GetEnumUnit(), "patrol", GetRectCenter(rct.StartingPlayerArea))
        end)
        DestroyGroup(g)
    end

    local ai1, ai2, ai3, ai4

    -- AI 1 (20368): once ganked 15×, Stampede the attacker's position, pause the other AIs
    -- for the channel, reset the counter, then patrol home. Created BEFORE AI 2 so on the same
    -- attack event the ==15 check reads the count before AI 2's increment — matching the JASS
    -- init order (Lv_10_Boss_AI_1 then _2). (ai2/3/4 are forward-declared upvalues, assigned below.)
    ai1 = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(ai1, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(ai1, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == UID.GoblinKing and bossGanked == 15
    end))
    TriggerAddAction(ai1, function()
        DisableTrigger(ai1); DisableTrigger(ai2); DisableTrigger(ai3); DisableTrigger(ai4)
        local g = GetUnitsOfTypeIdAll(UID.GoblinKing)
        local king = GroupPickRandomUnit(g)
        DestroyGroup(g)
        if king then
            IssuePointOrder(king, "stampede", GetUnitX(GetAttacker()), GetUnitY(GetAttacker()))
        end
        FloatText(GetAttackedUnitBJ(), "Fury of the Mountain", 100, 10, 10, 5.0)  -- TRIGSTR_1412
        TriggerSleepAction(14.0)
        bossGanked = 0
        if not kingGone() then
            EnableTrigger(ai1); EnableTrigger(ai2); EnableTrigger(ai3); EnableTrigger(ai4)
            TriggerSleepAction(2.0)
            patrolKingsHome()
        end
    end)

    -- AI 2 (20416): every hit on the King advances the gank counter.
    ai2 = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(ai2, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(ai2, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == UID.GoblinKing
    end))
    TriggerAddAction(ai2, function() bossGanked = bossGanked + 1 end)

    -- AI 3 (20437): every 20s summon Lackeys, then patrol home. Self-disables post-victory.
    ai3 = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(ai3, 20.0)
    TriggerAddAction(ai3, function()
        if kingGone() then DisableTrigger(ai3); return end
        forEachKing("summonquillbeast")
        TriggerSleepAction(1.25)
        if not kingGone() then patrolKingsHome() end
    end)

    -- AI 4 (20461): when a low-health (<400) attacker engages him, Spire/Thunderclap, then patrol.
    ai4 = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(ai4, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(ai4, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == UID.GoblinKing
            and GetUnitState(GetAttacker(), UNIT_STATE_LIFE) < 400.0
    end))
    TriggerAddAction(ai4, function()
        forEachKing("thunderclap")
        FloatText(GetAttackedUnitBJ(), "Spire", 100, 10, 10, 5.0)  -- TRIGSTR_1796
        TriggerSleepAction(1.0)
        if not kingGone() then patrolKingsHome() end
    end)
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
            { u=UID.SpeedWisp, n=1,        at=ABC },
            { u=FourCC('h002'), n=5, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002') } },
    },
    [2] = {
        intro = "|cffff8800Level 2|r — More squires, now with riflemen.",
        track = 2, next = 3,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
            { u=FourCC('h002'), n=6, dm=1,  at=ABC },
            { u=UID.SquireCaptive, n=0, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002'), UID.SquireCaptive } },
    },
    [3] = {
        intro = "|cffff8800Level 3|r — Archers join the assault.",
        track = 3, next = 4,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
            { u=FourCC('h002'), n=4, dm=1,  at=ABC },
            { u=UID.SquireCaptive, n=0, dm=1,  at=ABC },
            { u=FourCC('n001'), n=2, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002'), UID.SquireCaptive, FourCC('n001') } },
    },
    [4] = {
        intro = "|cffff8800Level 4|r — Rescue the prisoners! Clear the attackers.",
        track = 1, next = 5, prisoners = true,
        spawns = {
            { u=FourCC('h002'), n=6, dm=1,  at=ABC },
            { u=FourCC('n001'), n=1, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002'), FourCC('n001') } },
        -- Prisoner rescue payoff (war3map.j Level_4_Victory 19513-19575): surviving h006 with
        -- ≥3 HP become militia h045 (who join the Vern patrol); the rest are removed.
        onCleared = function()
            local g = GetUnitsOfPlayerAndTypeId(Player(8), UID.Prisoner)
            ForGroup(g, function()
                local u = GetEnumUnit()
                if GetUnitState(u, UNIT_STATE_LIFE) >= 3.0 then
                    ReplaceUnitBJ(u, UID.Militia, bj_UNIT_STATE_METHOD_MAXIMUM)
                else
                    RemoveUnit(u)
                end
            end)
            DestroyGroup(g)
            local m = GetUnitsOfPlayerAndTypeId(Player(8), UID.Militia)
            ForGroup(m, function()
                IssuePointOrderLoc(GetEnumUnit(), "patrol", GetRectCenter(rct.VernPatrolB))
            end)
            DestroyGroup(m)
        end,
    },
    [5] = {
        intro = "|cffff8800Level 5|r — Knights reinforce the enemy.",
        track = 2, next = 6,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
            { u=FourCC('h002'), n=1, dm=1,  at=ABC },
            { u=UID.SquireCaptive, n=0, dm=1,  at=ABC },
            { u=FourCC('h00B'), n=1, dm=1,  at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h002'), UID.SquireCaptive, FourCC('h00B') } },
    },
    [6] = {
        intro = "|cffff3300Level 6 — MINIBOSS!|r A Paladin commander leads the charge.",
        next = 7, boss = true, setup = setupLevel6Boss,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at='B' },
            { u=FourCC('h002'), n=9, dm=1,  at='B' },
            { u=UID.SquireCaptive, n=5, dm=1,  at='B' },
            { u=UID.PaladinCommander, n=1,        at='B' },   -- the miniboss
            { u=FourCC('h02P'), n=1,        at='B' },
            { u=FourCC('h02R'), n=1,        at='B' },
            { u=FourCC('h00B'), n=8, dm=1,  at='B' },
        },
        victory = { type='boss', unit=UID.PaladinCommander },
    },
    [7] = {
        intro = "|cffff8800Level 7|r — Demons spill from the hell rift.",
        track = 1, next = 8,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
            { u=FourCC('h00X'), n=3, dm=1,  at=ABC },
            { u=FourCC('h015'), n=2, dm=1,  at=ABC },
            { u=FourCC('h01R'), n=1,        at='HellSpawn' },
        },
        victory = { type='clearAll', units={ FourCC('h00X'), FourCC('h015'), FourCC('h01R') } },
    },
    [8] = {
        intro = "|cffff8800Level 8|r — Fire-casters among the demons.",
        track = 2, next = 9, setup = setupLevel8AI,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
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
        intro = "|cffff8800Level 9|r — A caravan raider and brutes attack.",
        track = 3, next = 10,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
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
            { u=UID.SpeedWisp, n=1,         at='B' },
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
            { u=UID.GoblinKing, n=1,         at='B' },   -- Goblin King
        },
        victory = { type='boss', unit=UID.GoblinKing },
    },
    [11] = {
        intro = "|cffff8800Level 11|r — Heavier demons and infernals.",
        track = 1, next = 12,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
            { u=FourCC('h014'), n=2, dm=1,  at=ABC },
            { u=FourCC('h00W'), n=2, dm=1,  at=ABC },
            { u=FourCC('h016'), n=0, dm=1,  at=ABC },
            { u=FourCC('h01R'), n=1, dm=1,  at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h014'), FourCC('h00W'), FourCC('h016'), FourCC('h01R') } },
    },
    [12] = {
        intro = "|cffff8800Level 12|r — The demon horde swells.",
        track = 2, next = 13,
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
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
        intro = "Level 13 - Dark Forest\nEnemies: ???\n|cff32cd32Victory|r - Figure out the cause "
            .. "of the forest's turn to evil and return home.\n|cffff0000Defeat|r - Death of Princess Silmeria",
        track = 3, next = 14,
        spawns = {},         -- all initial spawns in setup hook
        victory = { type='itemPickup', item=FourCC('I00U') },
        setup = setupLevel13,
    },
    [14] = {
        -- Caravan escort (full mechanic in setupLevel14, wired post-table).
        intro = "Level 14 - Unraveling the Mystery  Enemies: ???  |cff32cd32Victory|r - Escort "
            .. "the caravan with the artifact inside to the hermit, then on to the Altar of Tides.",
        track = 1, next = 15, noAutoPatrol = true,
        spawns = {},   -- caravan, camp NPCs, ambushes and waves all come from the setup hook
        victory = { type='boss', unit=UID.Tidedweller },   -- the Tidedweller at the last trap
        -- Victory payoff (war3map.j 21548-1564): caravan dissolves, the cleansed artifact
        -- I00W drops at the altar approach, chapter-phase fanfare.
        onCleared = function()
            local g = GetUnitsOfTypeIdAll(UID.Caravan)
            ForGroup(g, function() RemoveUnit(GetEnumUnit()) end)
            DestroyGroup(g)
            DisplayTextToForce(GetPlayersAll(), "|cffff0000The Dark Artifact has been cleansed!|r")
            CreateItem(FourCC('I00W'),
                GetRectCenterX(rct.CaravanPathC), GetRectCenterY(rct.CaravanPathC))
            PingMinimapLocForForce(GetPlayersAll(), GetRectCenter(rct.CaravanPathC), 10.0)
            DisplayTimedTextToForce(GetPlayersAll(), 10.0,
                "|cffff0000Phase 3: Troubles in the Wood|r - |cff7777aaComplete!|r")
        end,
    },
    [15] = {
        intro = "|cffff8800Level 15|r — Undead infantry with hellspawn support.",
        track = 2, next = 16,
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
            { u=FourCC('h01E'), n=3, dm=1, at=ABC },
            { u=FourCC('h01F'), n=2, dm=1, at=ABC },
            { u=FourCC('h01R'), n=0, dm=1, at='HellSpawn' },
            { u=FourCC('h06Q'), n=1,       at='HellSpawn' },
        },
        victory = { type='clearAll', units={
            FourCC('h01E'), FourCC('h01F'), FourCC('h01R'), FourCC('h06Q') } },
    },
    [16] = {
        intro = "|cffff8800Level 16|r — Warlocks slow your heroes.",
        track = 3, next = 17,
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
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
        intro = "|cffff8800Level 17|r — Necromancers join the undead host.",
        track = 1, next = 18,
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
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
            { u=UID.SpeedWisp, n=1,       at=ABC },
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
            { u=UID.SpeedWisp, n=1,  at=ABC },
            { u=FourCC('h01E'), n=5,  at='B' },
            { u=FourCC('h01G'), n=3,  at='B' },
            { u=FourCC('h01H'), n=3,  at='B' },
            { u=FourCC('h01Q'), n=3,  at='B' },
            { u=UID.UndeadBehemoth, n=1,  at='B' },   -- Undead Behemoth
            { u=FourCC('h04R'), n=1,  at='B' },
        },
        victory = { type='boss', unit=UID.UndeadBehemoth },
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
        intro = "|cffff8800Level 22|r — Spectral undead and river trolls advance.",
        track = 2, next = 23,
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
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
        intro = "|cffff8800Level 23|r — Gargoyles and a massed undead assault.",
        track = 3, next = 24,
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
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
        track = 3, next = nil,  -- next=nil → onVictory runs Megaboss 1 (wired below), which → L26
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
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
        intro = "|cffff4400Level 26|r — Boosted HP and damage! Dark Warlocks lead the charge.",
        track = 3, next = 27, patrolTo = 'EntranceToFortress',
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
            { u=FourCC('h04M'), n=3, dm=1, at=ABC },
            { u=FourCC('h04N'), n=1, dm=1, at=ABC },
        },
        victory = { type='clearAll', units={ FourCC('h04M'), FourCC('h04N') } },
        setup = setupLevel26,
    },
    [27] = {
        intro = "|cffff8800Level 27|r — Summoners reinforce the dark warlocks.",
        track = 3, next = 28, patrolTo = 'EntranceToFortress',
        spawns = {
            { u=UID.SpeedWisp, n=1,        at=ABC },
            { u=FourCC('h04M'), n=3, dm=1,  at=ABC },
            { u=FourCC('h04N'), n=1, dm=1,  at=ABC },
            { u=FourCC('h04O'), n=0, dm=4,  at=ABC },  -- 4*DM summons (multiply variant)
        },
        victory = { type='clearAll', units={ FourCC('h04M'), FourCC('h04N'), FourCC('h04O') } },
    },
    [28] = {
        intro = "|cffff8800Level 28|r — Spider webs across the land! Guardians defend key zones.",
        track = 3, next = 29, patrolTo = 'EntranceToFortress',
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
            { u=FourCC('h04M'), n=3, dm=1, at=ABC },
            { u=FourCC('h04N'), n=1, dm=1, at=ABC },
            { u=FourCC('h04O'), n=0, dm=4, at=ABC },
            { u=FourCC('h04V'), n=1, dm=1, at=ABC },
            -- h04U web guardians spawned in setup (random within spider web zones)
        },
        victory = { type='clearAll', units={
            FourCC('h04M'), FourCC('h04N'), FourCC('h04O'), FourCC('h04V') } },
        -- setup wired post-table: it calls setupLevel28AI(), which is a local defined AFTER
        -- this table — an inline closure here captured it as a nil global and errored at run
        -- time, which halted StartLevel before the victory trigger was armed (L28 unbeatable).
    },
    [29] = {
        intro = "|cffff8800Level 29|r — Shamans summon spirits and a caravan raider strikes.",
        track = 3, next = 30, patrolTo = 'EntranceToFortress',
        spawns = {
            { u=UID.SpeedWisp, n=1,       at=ABC },
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
local level13FailDialog = nil   -- L13 "Time until Disaster" countdown; cleared on victory (onCleared)

-- ── Per-level setup hooks (levels 13-29) ──────────────────────────────────────

-- Level 13: Ancient Forest (war3map.j 20755-21012)
-- h018×DM at 13 ForestOverrun zones + h019 (Ancient Treant) at AngryEnt.
-- Victory: pick up I00U dropped by h019. Periodic reinforcement waves from SpawnA.
-- Hurry-up: warning at T+180s/240s, punishment wave at T+300s.
local function setupLevel13()
    local gen = levelGen
    Level13Beaten = false   -- reset for replays (-goto); set true again on victory (onCleared wiring)
    local TREANT = FourCC('h018')
    local BOSS   = FourCC('h019')
    local FOREST_ZONES = {
        'ForestOverRunA','ForestOverrunB','ForestOverrunC','ForestOverrunD',
        'ForestOverrunE','ForestOverrunF','ForestOverrunG','ForestOverrunH',
        'ForestOverrunI','ForestOverrunJ','ForestOverrunK','ForestOverrunL',
        'ForestOverrunM',
    }
    -- initial spawn: DifficultyModifier treants per zone (war3map.j 20762-20774). Floored at 1
    -- so the "forest overrun" is never empty even when DM is 0 (e.g. a -goto test that skipped
    -- the difficulty pick) — otherwise only the ungated Angry Ent appears (KNOWN_BUGS T2 #4).
    local n = math.max(1, DifficultyModifier)
    for _, zone in ipairs(FOREST_ZONES) do
        CreateNUnitsAtLoc(n, TREANT, P9, GetRectCenter(rct[zone]), bj_UNIT_FACING)
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

    -- Visible fail timer + warnings (war3map.j 20870-20896). A 300s "Time until Disaster"
    -- countdown is shown; warnings at T+180s and T+240s; at T+300s the forest strikes back
    -- (4 h039 per lane). All gated on Level13Beaten so nothing fires once the level is won.
    local failT = CreateTimer()
    local failDlg = CreateTimerDialog(failT)
    TimerDialogSetTitle(failDlg, "Time until Disaster")
    TimerDialogDisplay(failDlg, true)
    level13FailDialog = failDlg

    local t180 = CreateTimer()
    TimerStart(t180, 180.0, false, function()
        if not Level13Beaten and levelGen == gen then
            DisplayTextToForce(GetPlayersAll(), "|cffff0000You feel a terrible unease.. as though a great calamity is coming.  You must hurry and calm the forest!|r")
            PlaySoundBJ(snd.CreepAggroWhat1)
        end
        DestroyTimer(t180)
    end)
    local t240 = CreateTimer()
    TimerStart(t240, 240.0, false, function()
        if not Level13Beaten and levelGen == gen then
            DisplayTextToForce(GetPlayersAll(), "|cffff0000You cannot shake a feeling of imminent disaster, if the forest cannot be calmed shortly!|r")
            PlaySoundBJ(snd.CreepAggroWhat1)
        end
        DestroyTimer(t240)
    end)
    TimerStart(failT, 300.0, false, function()
        if not Level13Beaten and levelGen == gen then
            DisplayTextToForce(GetPlayersAll(), "|cffff0000A horrible cry rends the air, and the ground shakes with uncontained rage.|r")
            PlaySoundBJ(snd.CreepAggroWhat1)
            for _, lane in ipairs({'SpawnA','SpawnB','SpawnC'}) do
                CreateNUnitsAtLoc(4, FourCC('h039'), P9, GetRectCenter(rct[lane]), bj_UNIT_FACING)
            end
            patrolAll()
        end
        if level13FailDialog == failDlg then level13FailDialog = nil end
        DestroyTimerDialog(failDlg)
        DestroyTimer(failT)
    end)
end

-- Level 14: the FULL caravan escort (war3map.j 21017-21581).
-- The caravan (h01A, P8) drives itself along CaravanPathA → B → (hermit dialogue) → B2 → C
-- via a 5s re-order tick; reaching each waypoint springs an ambush (the trap "gates" in the
-- Destructible_Trap rects are blasted open and attackers pour out, the caravan holds, then
-- rolls on). At CaravanPathC the Tidedweller (O002) rises with two periodic spells; killing
-- it is the level victory. Timed reinforcement waves harass the town all the while; the
-- caravan dying is a hard defeat.
local function setupLevel14()
    local gen = levelGen
    local CARAVAN = UID.Caravan

    -- Trap ambushers, kept locked onto the caravan. The town-harassment waves below re-order
    -- ALL Player-9 units to patrol the base every wave (faithful to war3map.j Spawn_Attack), which
    -- was yanking the trap ambushers off the caravan and sending them to the base too (triage-4
    -- #1). Deviation: ambushers are tracked here and excluded from that base re-order so they stay
    -- on the caravan — the escort threat the traps are meant to be.
    local ambush = {}

    local function caravan()
        local g = GetUnitsOfTypeIdAll(CARAVAN)
        local u = GroupPickRandomUnit(g)
        DestroyGroup(g)
        return u
    end
    local function holdCaravan()
        local c = caravan()
        if c then IssueImmediateOrderBJ(c, "holdposition") end
    end
    -- ambush helper: clear the trap gate destructibles, spawn attackers in the rect,
    -- and order everything there onto the caravan (war3map.j Trap_A/B/C shape).
    local function springTrap(rectKey, spawnsList)
        local r = rct[rectKey]
        EnumDestructablesInRect(r, nil, function() KillDestructable(GetEnumDestructable()) end)
        -- Floor the difficulty at 1 for ambush scaling so a -goto 14 test (DM 0) still
        -- springs the per-zone ambushes instead of near-empty traps (triage-3 #8; same
        -- guard as Level 13). At a real difficulty (DM>=1) this is identical to the JASS.
        local dm = math.max(1, DifficultyModifier)
        for _, s in ipairs(spawnsList) do
            local count = s[1] + (s[3] or 0) * dm
            if count > 0 then
                local loc = GetRandomLocInRect(r)
                CreateNUnitsAtLoc(count, FourCC(s[2]), P9, loc, bj_UNIT_FACING)
                RemoveLocation(loc)
            end
        end
        TriggerSleepAction(1.0)
        local g = GetUnitsInRectOfPlayer(r, P9)
        ForGroup(g, function()
            local e = GetEnumUnit()
            ambush[e] = true            -- exempt from the base-patrol re-order below
            local tgt = caravan()
            if tgt then IssueTargetOrderBJ(e, "attack", tgt) end
        end)
        DestroyGroup(g)
        holdCaravan()
    end

    -- caravan + hermit camp + altar NPCs (war3map.j 21024-21027)
    CreateNUnitsAtLoc(1, CARAVAN, Player(8), GetRectCenter(rct.StartingPlayerArea), bj_UNIT_FACING)
    CreateNUnitsAtLoc(1, FourCC('h01B'), Player(8), GetRectCenter(rct.Hermit), bj_UNIT_FACING)
    CreateNUnitsAtLoc(1, FourCC('nfr2'), Player(8), GetRectCenter(rct.HermitTent), bj_UNIT_FACING)
    CreateNUnitsAtLoc(1, FourCC('nnad'), Player(8), GetRectCenter(rct.AltarOfTides), bj_UNIT_FACING)
    local c0 = caravan()
    if c0 then PingMinimapLocForForce(GetPlayersAll(), GetUnitLoc(c0), 15.0) end

    -- caravan pathing tick: every 5s re-order it toward the current waypoint
    local pathTarget = 'CaravanPathA'
    local pathOn = true
    local pathT = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(pathT, 5.0)
    TriggerAddAction(pathT, function()
        if levelGen ~= gen then DisableTrigger(pathT); return end
        if not pathOn then return end
        local c = caravan()
        if c then IssuePointOrderLoc(c, "move", GetRectCenter(rct[pathTarget])) end
    end)

    -- caravan-under-attack warning (30s throttle, war3map.j 21481-21493)
    local warnT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(warnT, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(warnT, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == CARAVAN and levelGen == gen
    end))
    TriggerAddAction(warnT, function()
        DisableTrigger(warnT)
        DisplayTextToForce(GetPlayersAll(), "|cffff0000WARNING:|r - The Caravan is under ATTACK!")
        PlaySoundBJ(snd.HordeSound2)
        TriggerSleepAction(30.0)
        if levelGen == gen then EnableTrigger(warnT) end
    end)

    -- caravan destroyed = defeat (war3map.j 21438-1467; cinematic shortened)
    local defeatT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(defeatT, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(defeatT, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == CARAVAN and levelGen == gen
    end))
    TriggerAddAction(defeatT, function()
        MusicOn = false; BossMusic = false; NearDefeatMusic = false
        StopAllMusic()
        ForForce(GetPlayersAll(), function()
            CameraSetupApplyForPlayer(true, cam.DefeatCamera, GetEnumPlayer(), 0)
        end)
        TriggerSleepAction(1.0)
        PauseAllUnitsBJ(true)
        DisplayTextToForce(GetPlayersAll(),
            "|cffff0000Defeat...|r |cffff0000- The Caravan has been destroyed..|r")
        TriggerSleepAction(4.0)
        PlaySoundBJ(snd.GameOverToD)
        TriggerSleepAction(5.0)
        -- Closing narration (war3map.j 21461-21465, TRIGSTR_8094/8095/8096) then the credits
        -- roll (21467 ConditionalTriggerExecute(gg_trg_Credits)) — which actually ENDS the game.
        -- Without this the field stayed paused with no defeat declared (the port hung here).
        DisplayTextToForce(GetPlayersAll(),
            "|cffff0000With the caravan's destruction, Adomach's lackeys took opportunity of the confusion and stole the artifact.  Using Fell Magic, he perverted its true nature, creating an artifact of great evil.|r")
        TriggerSleepAction(5.0)
        DisplayTextToForce(GetPlayersAll(),
            "|cffff0000Drawing upon the artifact's perverted power, Adomach created a virulent plague and sent it into Vern.  Half the population fell within a week, including the Lady Silmeria.  Those who remained fought desperately, but in vain.|r")
        TriggerSleepAction(7.0)
        DisplayTextToForce(GetPlayersAll(),
            "|cffff0000With Vern conquered, Adomach turned to the south, using his new power to raise legions of plagued undead.  None could stand against his power, and a new reign of darkness began in the land.|r")
        TriggerSleepAction(5.0)
        RollDefeatCredits()
    end)

    -- waypoint reactions (each fires once, on the CARAVAN entering)
    local function onCaravanEnter(rectKey, fn)
        local t
        t = OnEnterRect(rct[rectKey], function()
            return GetUnitTypeId(GetEnteringUnit()) == CARAVAN and levelGen == gen
        end, function()
            DisableTrigger(t)
            fn()
        end)
    end

    -- Trap A (CaravanPathA): gates at Trap_A/B blow open (war3map.j 21182-21196)
    onCaravanEnter('CaravanPathA', function()
        pathOn = false
        TriggerSleepAction(3.0)
        springTrap('DestructibleTrapA', { { 2, 'h017', 1 } })
        springTrap('DestructibleTrapB', { { 2, 'h017', 1 }, { 0, 'h016', 1 } })
        TriggerSleepAction(15.0)
        pathTarget = 'CaravanPathB'
        pathOn = true
    end)

    -- Trap B (CaravanPathB) → hermit dialogue → onward (war3map.j 21229-21240, 21277-21285)
    onCaravanEnter('CaravanPathB', function()
        pathOn = false
        TriggerSleepAction(1.75)
        springTrap('DestructibleTrapC', { { 3, 'h00W', 1 }, { 0, 'h016', 1 } })
        TriggerSleepAction(15.0)
        holdCaravan()
        DisplayTimedTextToForce(GetPlayersAll(), 12.0,
            "|cff32cd32Hermit: You have done well to bring this to me. Though this once was a powerful force for good, it has since been corrupted into a former shadow of itself.|r")
        TriggerSleepAction(12.0)
        DisplayTimedTextToForce(GetPlayersAll(), 12.0,
            "|cff32cd32Hermit: Take this artifact to the Altar of Tides, where it may be cleansed of its taint. Go now, heroes, and be well.|r")
        TriggerSleepAction(12.0)
        DisplayTimedTextToForce(GetPlayersAll(), 12.0,
            "|cff32cd32New Victory Condition: Escort the Caravan to the Altar of Tides and protect it.|r")
        pathTarget = 'CaravanPathB2'
        pathOn = true
    end)

    -- Trap C (CaravanPathB2): the Trap_D ambush w/ mini-leader h04Q (war3map.j 21328-21340)
    onCaravanEnter('CaravanPathB2', function()
        pathOn = false
        TriggerSleepAction(1.75)
        springTrap('DestructibleTrapD', { { 0, 'h014', 2 }, { 1, 'h04Q' }, { 0, 'h016', 1 } })
        TriggerSleepAction(15.0)
        pathTarget = 'CaravanPathC'
        pathOn = true
    end)

    -- Last Trap (CaravanPathC): the Tidedweller O002 rises (war3map.j 21393-21424)
    onCaravanEnter('CaravanPathC', function()
        pathOn = false
        DisableTrigger(pathT)
        -- The caravan has arrived at the temple — pin it in place for the boss fight so
        -- it stops fleeing when the Tidedweller hits it (triage-3 #9). Move speed 0 keeps
        -- it from being kited off; it still dies (caravan death = defeat) if left undefended.
        local cHold = caravan()
        if cHold then
            SetUnitMoveSpeed(cHold, 0)
            IssueImmediateOrderBJ(cHold, "holdposition")
        end
        TriggerSleepAction(1.75)
        MusicOn = false
        PlaySoundBJ(snd.CreepAggroWhat1)
        DisplayTextToForce(GetPlayersAll(), "|cffff0000Something approaches...|r")
        PingMinimapLocForForceEx(GetPlayersAll(), GetRectCenter(rct.Lvl14BossSpawn),
            10.0, bj_MINIMAPPINGSTYLE_SIMPLE, 0.0, 0.0, 100)
        local bx, by = GetRectCenterX(rct.Lvl14BossSpawn), GetRectCenterY(rct.Lvl14BossSpawn)
        TriggerSleepAction(5.0)
        local fx = AddSpecialEffect("Abilities\\Spells\\Orc\\EarthQuake\\EarthQuakeTarget.mdl", bx, by)
        TriggerSleepAction(2.0); DestroyEffect(fx); TriggerSleepAction(2.0)
        fx = AddSpecialEffect("Abilities\\Spells\\Other\\FrostDamage\\FrostDamage.mdl", bx, by)
        TriggerSleepAction(2.0); DestroyEffect(fx); TriggerSleepAction(2.0)
        fx = AddSpecialEffect("Abilities\\Spells\\NightElf\\Blink\\BlinkTarget.mdl", bx, by)
        local boss = CreateUnit(P9, UID.Tidedweller, bx, by, bj_UNIT_FACING)
        TriggerSleepAction(2.0); DestroyEffect(fx)
        SetHeroLevelBJ(boss, math.max(1, 4 * DifficultyModifier), false)
        TriggerSleepAction(1.0)
        SelectHeroSkill(boss, FourCC('AHtb'))   -- Whirlpool (Storm Bolt stun)
        SelectHeroSkill(boss, FourCC('AEfk'))   -- Maelstrom (Fan of Knives)
        StartBossMusic()
        -- Tidedweller AI: fan of knives every 10s; thunderbolt a random nearby unit every 14s
        local ai1 = CreateTrigger()
        TriggerRegisterTimerEventPeriodic(ai1, 10.0)
        TriggerAddAction(ai1, function()
            if levelGen ~= gen then DisableTrigger(ai1); return end
            local g = GetUnitsOfTypeIdAll(UID.Tidedweller)
            local b = GroupPickRandomUnit(g)
            DestroyGroup(g)
            if b then IssueImmediateOrderBJ(b, "fanofknives") end
        end)
        local ai2 = CreateTrigger()
        TriggerRegisterTimerEventPeriodic(ai2, 14.0)
        TriggerAddAction(ai2, function()
            if levelGen ~= gen then DisableTrigger(ai2); return end
            local g = GetUnitsOfTypeIdAll(UID.Tidedweller)
            local b = GroupPickRandomUnit(g)
            DestroyGroup(g)
            if not b then return end
            local tg = CreateGroup()
            GroupEnumUnitsInRange(tg, GetUnitX(b), GetUnitY(b), 1100.0, nil)
            local tgt = GroupPickRandomUnit(tg)
            DestroyGroup(tg)
            if tgt then IssueTargetOrderBJ(b, "thunderbolt", tgt) end
        end)
        IssuePointOrderLoc(boss, "patrol", GetRectCenter(rct.StartingPlayerArea))
    end)

    -- timed town-harassment waves (war3map.j Spawn_Attack 21104-21143), patrol to base
    local wavesT = CreateTrigger()
    TriggerAddAction(wavesT, function()
        local WAVES = {
            { wait = 22, units = { { 1, 'h016' }, { 1, 'h00W' } } },
            { wait = 22, units = { { 2, 'h014' }, { 1, 'h016' }, { 1, 'h00W' } } },
            { wait = 18, units = { { 3, 'h014' }, { 1, 'h016' } } },
            { wait = 22, units = { { 2, 'h014' }, { 1, 'h016' }, { 2, 'h017' } } },
            { wait = 22, units = { { 1, 'h016' }, { 1, 'h00W' } } },
            { wait = 18, units = { { 2, 'h014' }, { 1, 'h016' }, { 1, 'h00W' } } },
            { wait = 22, units = { { 3, 'h014' }, { 1, 'h016' } } },
            { wait = 0,  units = { { 2, 'h014' }, { 1, 'h016' }, { 2, 'h017' } } },
        }
        TriggerSleepAction(15.0)
        if levelGen ~= gen then return end
        DisplayTimedTextToForce(GetPlayersAll(), 8.0, "|cffff0000The forest shakes with activity...|r")
        PlaySoundBJ(snd.CreepAggroWhat1)
        TriggerSleepAction(7.0)
        for _, w in ipairs(WAVES) do
            if levelGen ~= gen then return end
            for _, u in ipairs(w.units) do
                CreateNUnitsAtLoc(u[1], FourCC(u[2]), P9, GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
            end
            local g = GetUnitsOfPlayerAll(P9)
            ForGroup(g, function()
                local u = GetEnumUnit()
                -- Skip the boss AND trap ambushers — the latter stay on the caravan (triage-4 #1).
                if GetUnitTypeId(u) ~= UID.Tidedweller and not ambush[u] then
                    IssuePointOrderLoc(u, "patrol", GetRectCenter(rct.StartingPlayerArea))
                end
            end)
            DestroyGroup(g)
            if w.wait > 0 then TriggerSleepAction(w.wait) end
        end
    end)
    TriggerExecute(wavesT)
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
    local O004 = UID.UndeadBehemoth
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

    -- Web Kill (war3map.j 23840-23887): destroying a spider web (h04U) springs a webbed
    -- victim near the killer — a roll of 1-2 frees a hostile monster (Player 9), 3-6 rescues
    -- a friendly captive (Player 8) and rallies the rescued (h045/h04J/h04I) toward safety.
    local WEBBED_VICTIM = {
        FourCC('h014'), FourCC('h015'), UID.SquireCaptive,  -- 1-2 hostile, 3 friendly
        UID.Militia, FourCC('h04J'), FourCC('h04I'),  -- 4-6 friendly (rallied on rescue)
    }
    local webTrg = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(webTrg, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(webTrg, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == FourCC('h04U') and levelGen == gen
    end))
    TriggerAddAction(webTrg, function()
        local roll = GetRandomInt(1, 6)
        local killer = GetKillingUnitBJ()
        local from = (killer and GetUnitTypeId(killer) ~= 0) and GetUnitLoc(killer) or GetUnitLoc(GetDyingUnit())
        local spawnLoc = PolarProjectionBJ(from, 170.0, GetRandomDirectionDeg())
        if roll <= 2 then
            CreateNUnitsAtLoc(1, WEBBED_VICTIM[roll], P9, spawnLoc, bj_UNIT_FACING)
        else
            local rescued = CreateUnitAtLoc(Player(8), WEBBED_VICTIM[roll], spawnLoc, bj_UNIT_FACING)
            TriggerSleepAction(2.0)
            -- The JASS only sweeps victim types 4-6 toward Vern (war3map.j 23875-23877), so a
            -- freed type-3 Squire Captain (h005) is never ordered and relied on the Player-8
            -- ally AI to walk it home. We don't run that AI, so order the just-freed unit
            -- directly toward the base too (triage-3 #7).
            if rescued and GetUnitTypeId(rescued) ~= 0 then
                IssuePointOrderLoc(rescued, "patrol", GetRectCenter(rct.VernPatrolB))
            end
            for i = 4, 6 do
                local g = GetUnitsOfTypeIdAll(WEBBED_VICTIM[i])
                ForGroup(g, function()
                    IssuePointOrderLoc(GetEnumUnit(), "patrol", GetRectCenter(rct.VernPatrolB))
                end)
                DestroyGroup(g)
            end
        end
        RemoveLocation(from)
        RemoveLocation(spawnLoc)
    end)
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

local function patrolEnemiesToBase(rectKey)
    local loc = GetRectCenter(rct[rectKey or 'StartingPlayerArea'])
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
        local wisps = GetUnitsOfPlayerAndTypeId(P9, UID.SpeedWisp)
        ForGroup(wisps, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(wisps)
    end)
end

-- Level 4 escort prisoners (h006, Player 8); they flee to the base (flavor).
local function spawnPrisoners()
    for _, key in ipairs({ 'AlliedFlee', 'AlliedFlee2', 'AlliedFlee3' }) do
        CreateNUnitsAtLoc(3, UID.Prisoner, Player(8), GetRectCenter(rct[key]), bj_UNIT_FACING)
    end
    local grp = GetUnitsOfPlayerAndTypeId(Player(8), UID.Prisoner)
    ForGroup(grp, function()
        IssuePointOrderLoc(GetEnumUnit(), "move", GetRectCenter(rct.StartingPlayerArea))
    end)
    DestroyGroup(grp)
end

-- ─── Level 30-31: the boss climax (war3map.j 24037-24411) ──────────────────────

-- Level 30 boss: "The Hive Mastermind" / King of Spiders (O00U), level 6*DM.
-- Four reactive AIs escalate as it loses HP (war3map.j 24132-24307):
--   • Leech  — every 24s, drains a nearby enemy hero ("drain").
--   • Pound  — when meleed (attacker within 300), shockwaves a hero; 12s internal cd.
--   • Web Spray + Call Hive — below 7500 HP: war-stomp stun, then summon a hive.
--   • (again) below 4000 HP.
-- After every cast the boss patrols back to the fortress entrance. All AIs carry a
-- generation guard so they self-disable when the level changes (see setupLevel20).
local function setupLevel30()
    local gen  = levelGen
    local O00U = FourCC('O00U')
    local FX   = GetRectCenterX(rct.EntranceToFortress)
    local FY   = GetRectCenterY(rct.EntranceToFortress)
    StartBossMusic()   -- BossMusic1 (war3map.j 24058-24060: udg_BossMusic + Boss_Music)

    local function boss()
        local g = GetUnitsOfTypeIdAll(O00U)
        local b = GroupPickRandomUnit(g)
        DestroyGroup(g)
        return b
    end
    local function repatrol(b)
        if b and GetUnitTypeId(b) ~= 0 then IssuePointOrder(b, "patrol", FX, FY) end
    end
    -- A random enemy unit within `range` of the boss (heroOnly restricts to heroes).
    local function pickNear(b, range, heroOnly)
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, GetUnitX(b), GetUnitY(b), range, Condition(function()
            local f = GetFilterUnit()
            return GetOwningPlayer(f) ~= P9 and (not heroOnly or IsUnitType(f, UNIT_TYPE_HERO))
        end))
        local t = GroupPickRandomUnit(g)
        DestroyGroup(g)
        return t
    end

    -- configure the boss (war3map.j 24046-24048, 24072)
    local grp = GetUnitsOfTypeIdAll(O00U)
    ForGroup(grp, function()
        SetHeroLevelBJ(GetEnumUnit(), math.max(1, 6 * DifficultyModifier), false)
    end)
    DestroyGroup(grp)

    -- Leech (every 24s): drain a nearby enemy hero (war3map.j 24151-24159)
    local leech = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(leech, 24.0)
    TriggerAddAction(leech, function()
        if levelGen ~= gen then DisableTrigger(leech); return end
        local b = boss(); if not b then return end
        FloatText(b, "Leech", 100, 100, 100, 3.0)
        local tgt = pickNear(b, 490.0, true)
        if tgt then IssueTargetOrderBJ(b, "drain", tgt) end
        After(4.5, function() if levelGen == gen then repatrol(boss()) end end)
    end)

    -- Pound (on melee attack): shockwave a nearby hero, then a 12s internal cooldown
    -- (war3map.j 24174-24211).
    local pound = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(pound, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(pound, Condition(function()
        local u, a = GetAttackedUnitBJ(), GetAttacker()
        if GetUnitTypeId(u) ~= O00U then return false end
        local dx, dy = GetUnitX(u) - GetUnitX(a), GetUnitY(u) - GetUnitY(a)
        return dx * dx + dy * dy <= 300.0 * 300.0
    end))
    TriggerAddAction(pound, function()
        if levelGen ~= gen then DisableTrigger(pound); return end
        DisableTrigger(pound)
        local b = boss(); if not b then return end
        FloatText(b, "Pound", 100, 100, 100, 3.0)
        local tgt = pickNear(b, 500.0, true)
        if tgt then IssuePointOrder(b, "shockwave", GetUnitX(tgt), GetUnitY(tgt)) end
        After(4.0,  function() if levelGen == gen then repatrol(boss()) end end)
        After(12.0, function() if levelGen == gen then EnableTrigger(pound) end end)
    end)

    -- Web Spray + Call Hive: war-stomp stun, then raise a hive near the boss after `gap`s.
    -- The original orders the boss to cast its Carrion-Beetles ability ("summonfactory",
    -- war3map.j 24249) to spawn the hive (n00V), but Carrion Beetles needs a CORPSE at the
    -- target point — cast on bare ground it silently does nothing, so the hive never appeared
    -- (KNOWN_BUGS T2 #28). We create the hive directly and have it birth Spider Swarms (h04O)
    -- on a timer until it is destroyed or the level ends — the "hive that constantly spawns
    -- spider swarms" the boss was meant to call (war3map.j 24044).
    local function castHive(b, gap)
        FloatText(b, "Web Spray", 100, 100, 100, 3.0)
        IssueImmediateOrder(b, "stomp")
        After(gap, function()
            if levelGen ~= gen then return end
            local bb = boss(); if not bb then return end
            local ang = math.rad(GetRandomReal(0.0, 360.0))
            local d   = GetRandomReal(100.0, 300.0)
            local hx, hy = GetUnitX(bb) + d * math.cos(ang), GetUnitY(bb) + d * math.sin(ang)
            local hive = CreateUnit(P9, FourCC('n00V'), hx, hy, bj_UNIT_FACING)
            FloatText(bb, "Call Hive", 100, 100, 100, 3.0)
            local spawnT = CreateTimer()
            TimerStart(spawnT, 6.0, true, function()
                if levelGen ~= gen or GetUnitTypeId(hive) == 0
                    or GetUnitState(hive, UNIT_STATE_LIFE) <= 0.405 then
                    DestroyTimer(spawnT); return
                end
                local s = CreateUnit(P9, FourCC('h04O'), GetUnitX(hive), GetUnitY(hive), bj_UNIT_FACING)
                IssuePointOrder(s, "patrol",
                    GetRectCenterX(rct.EntranceToFortress), GetRectCenterY(rct.EntranceToFortress))
            end)
            After(1.5, function() if levelGen == gen then repatrol(boss()) end end)
        end)
    end

    -- Second stage (≤4000 HP), armed by the first (war3map.j 24273-24298).
    local web2 = CreateTrigger()
    DisableTrigger(web2)
    TriggerRegisterPlayerUnitEventSimple(web2, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(web2, Condition(function()
        local u = GetAttackedUnitBJ()
        return GetUnitTypeId(u) == O00U and GetUnitState(u, UNIT_STATE_LIFE) <= 4000.0
    end))
    TriggerAddAction(web2, function()
        if levelGen ~= gen then DisableTrigger(web2); return end
        DisableTrigger(web2)
        local b = boss(); if b then castHive(b, 1.5) end
    end)

    -- First stage (≤7500 HP) (war3map.j 24227-24257).
    local web1 = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(web1, P9, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(web1, Condition(function()
        local u = GetAttackedUnitBJ()
        return GetUnitTypeId(u) == O00U and GetUnitState(u, UNIT_STATE_LIFE) <= 7500.0
    end))
    TriggerAddAction(web1, function()
        if levelGen ~= gen then DisableTrigger(web1); return end
        DisableTrigger(web1)
        local b = boss(); if b then castHive(b, 2.0) end
        EnableTrigger(web2)
    end)
end

-- Level 31: the final boss "Boss of the Pit" (N015), level 6*DM, plus a heavy wave.
-- The original gives N015 no scripted AI — it fights with its own object-data abilities
-- (war3map.j 24310-24369). Victory unlocks the optional Adomach boss (Bosses ⬜).
local function setupLevel31()
    StartBossMusic()   -- BossMusic1 (war3map.j 24326-24328)
    local grp = GetUnitsOfTypeIdAll(FourCC('N015'))
    ForGroup(grp, function()
        SetHeroLevelBJ(GetEnumUnit(), math.max(1, 6 * DifficultyModifier), false)
    end)
    DestroyGroup(grp)
end

-- ── Wire setup hooks defined after the LevelData literal ───────────────────────
-- These hooks live below the LevelData table (they need `levelGen`, declared after it),
-- so a `setup = setupLevelNN` written inside the table literal captured nil (Lua evaluates
-- table values eagerly, before the function exists) and the hook silently never ran.
-- Bind them here, after definition, so they actually fire in StartLevel. (Levels 6/8/10
-- are unaffected — defined above the table; [28] wraps its call in an inline closure.)
LevelData[13].setup = setupLevel13
-- L13 victory sets Level13Beaten = true (war3map.j 20819), which silences the still-pending
-- hurry-up timers (they all guard on `not Level13Beaten`) and dismisses the fail-timer dialog
-- so neither warning text nor the "forest strikes back" wave can fire after the level is won.
LevelData[13].onCleared = function()
    Level13Beaten = true
    if level13FailDialog then
        TimerDialogDisplay(level13FailDialog, false)
        level13FailDialog = nil
    end
end
-- Loot-tier upgrades fired on victory (war3map.j Level_10_Victory 20538-20543 / Level_20
-- _Victory 22492): kill-drops + treasure chest jump to the Lv2 pools and scroll drops walk
-- up the Circle tiers (0->1 at L10, 1->2 at L20). items.lua / scrolls.lua own the state.
LevelData[10].onCleared = function()
    UpgradeLootTier()
    UpgradeScrollTier()
end
LevelData[20].onCleared = function()
    UpgradeScrollTier()
end
LevelData[14].setup = setupLevel14
LevelData[16].setup = setupLevel16AI
LevelData[17].setup = setupLevel16AI
LevelData[18].setup = setupLevel18
LevelData[19].setup = setupLevel19
LevelData[20].setup = setupLevel20
LevelData[21].setup = setupLevel21
LevelData[26].setup = setupLevel26
-- L28: raise the spider webs (h04U), then arm the flee + web-kill AI (setupLevel28AI is a
-- local defined above, so this closure — bound after it exists — captures it correctly).
LevelData[28].setup = function()
    for _, z in ipairs({'SpiderWebsA','SpiderWebsB','SpiderWebsC','SpiderWebsD'}) do
        CreateNUnitsAtLoc(1, FourCC('h04U'), P9, GetRandomLocInRect(rct[z]), bj_UNIT_FACING)
        CreateNUnitsAtLoc(1, FourCC('h04U'), P9, GetRandomLocInRect(rct[z]), bj_UNIT_FACING)
    end
    setupLevel28AI()
end
LevelData[29].setup = setupLevel29AI

-- Level 24 is terminal in the table (numbering skips 25); its victory launches the Megaboss 1
-- arena encounter (lib/megaboss.lua), which on its own victory advances to Level 26. Wrapped in
-- a closure so StartMegaboss1 resolves at runtime regardless of module require order.
LevelData[24].onVictory = function() StartMegaboss1() end

-- New boss levels (defined here so their setups, which need `levelGen`, resolve directly).
LevelData[30] = {
    intro = "Level 30 - The Hive Mastermind - |cffff0000Boss #5!!|r |cff32cd32Victory|r - Defeat of King of Spiders. |cffff0000Defeat|r - Death of Princess Silmeria",
    next = 31, boss = true, patrolTo = 'EntranceToFortress',
    spawns = {
        { u=UID.SpeedWisp, n=1,       at=ABC },
        { u=FourCC('h04M'), n=3, dm=1, at='B' },
        { u=FourCC('h04N'), n=1, dm=1, at='B' },
        { u=FourCC('h04V'), n=1, dm=1, at='B' },
        { u=FourCC('h04W'), n=1, dm=1, at='B' },
        { u=FourCC('O00U'), n=1,       at='B' },   -- boss: Lairlord Razormaw
    },
    victory = { type='boss', unit=FourCC('O00U') },
    setup = setupLevel30,
}

LevelData[31] = {
    intro = "Level 31 - Boss of the Pit and minions - |cffff0000Boss #6!!|r |cff32cd32Victory|r - Defeat of Boss of the Pit. |cffff0000Defeat|r - Death of Princess Silmeria",
    boss = true, patrolTo = 'EntranceToFortress',   -- next = nil → terminal: onVictory runs the climax
    spawns = {
        { u=UID.SpeedWisp, n=1,       at=ABC },
        { u=FourCC('h03T'), n=2, dm=1, at=ABC },
        { u=FourCC('h03T'), n=1, dm=1, at='HellSpawn' },
        { u=FourCC('h01R'), n=5, dm=1, at=ABC },
        { u=FourCC('h01R'), n=3, dm=1, at='HellSpawn' },
        { u=FourCC('h06Q'), n=3, dm=1, at=ABC },
        { u=FourCC('h06Q'), n=1, dm=1, at='HellSpawn' },
        { u=FourCC('h06P'), n=1, dm=1, at=ABC },
        { u=FourCC('h06P'), n=0, dm=1, at='HellSpawn' },
        { u=FourCC('h06R'), n=1,       at='HellSpawn' },
        { u=FourCC('N015'), n=1,       at='B' },   -- final boss: Boss of the Pit
    },
    victory = { type='boss', unit=FourCC('N015') },
    setup = setupLevel31,
    onVictory = function()
        -- Campaign climax (war3map.j 24385-24401).
        DisplayTimedTextToForce(GetPlayersAll(), 10.0, "Boss of the Pit|r - |cff7777aaComplete!|r")
        DisplayTextToForce(GetPlayersAll(), "|cff32cd32Victory!!|r the princess is saved!")
        DisplayTimedTextToForce(GetPlayersAll(), 60.0, "type -adomach to spawn the bonus last boss")
        AdomachUnlocked = true   -- optional post-game boss (Bosses ⬜); the -adomach command will read this
    end,
}

-- forward declaration (global so onLevelVictory can chain)
StartLevel = nil

local function onLevelVictory(data, levelIndex)
    local myGen = levelGen
    MusicOn     = false
    BossMusic   = false
    StopAllMusic()        -- silence boss track on victory; vanilla wave music resumes via WaveMusicTick
    LevelBeaten = true
    PlaySoundBJ(snd.RoundClear)
    if data.onCleared then data.onCleared() end   -- per-level victory hook (e.g. L4 prisoner rescue)
    ThingsToDoImmediatelyFollowingVictory()
    SupplyStockingItems()  -- sort ground items into cleanup zones if researched (economy/Economy.md §3)
    if data.next and LevelData[data.next] then
        TimerForNextLevel(LevelData[data.next].boss or false)
    end
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
    elseif data.onVictory then
        data.onVictory()   -- terminal level: run its climax instead of chaining onward
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
    if not data.noAutoPatrol then patrolEnemiesToBase(data.patrolTo) end
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

    -- ─── Level 4 prisoner system (h006, Player 8) ──────────────────────────────
    -- These three triggers are registered globally (as the original does) but only do
    -- anything while prisoners exist, i.e. during Level 4. They are what makes the rescue
    -- read correctly: the prisoners stream to the base, can't be slain by the party, and
    -- announce a dying line when an attacker gets one. Without the nudge the survivors
    -- were still scattered in their lanes at victory, so the militia they became marched
    -- back out (triage-3 #3).

    -- Prisoner Nudge (war3map.j 29460-29476): every 10s order all Player-8 prisoners
    -- toward the base so they gather there before the rescue resolves.
    local nudge = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(nudge, 10.0)
    TriggerAddAction(nudge, function()
        local g = GetUnitsOfPlayerAndTypeId(Player(8), UID.Prisoner)
        ForGroup(g, function()
            IssuePointOrderLoc(GetEnumUnit(), "move", GetRectCenter(rct.StartingPlayerArea))
        end)
        DestroyGroup(g)
    end)

    -- Cant Kill Prisoners (war3map.j 29437-29458): a non-enemy attacking a prisoner is
    -- stopped and scolded, so the party can't fail the level by killing the captives.
    local cantKill = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(cantKill, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(cantKill, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == UID.Prisoner
            and GetOwningPlayer(GetAttacker()) ~= P9
    end))
    TriggerAddAction(cantKill, function()
        IssueImmediateOrderBJ(GetAttacker(), "stop")
        DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(GetAttacker())),
            "You're supposed to save them, not slay them!")
    end)

    -- Prisoner Dies (war3map.j 29899-29981): a dying prisoner pings the map and cries
    -- out one of seven random death lines.
    local prisonerDeath = {
        "|cff32cd32Prisoner:|r Agh.. it.. hurts..!",
        "|cff32cd32Prisoner:|r I don't... want.. to die....",
        "|cff32cd32Prisoner:|r Is this... the end..?",
        "|cff32cd32Prisoner:|r My love.. I only wanted to see your face one.. last...",
        "|cff32cd32Prisoner:|r Darkness... closes in.. is this... death..?",
        "|cff32cd32Prisoner:|r Ugh...avenge... me...!",
        "|cff32cd32Prisoner:|r This can't be... how it all... ends...!",
    }
    local dies = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(dies, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(dies, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == UID.Prisoner
    end))
    TriggerAddAction(dies, function()
        PlaySoundBJ(snd.CreepAggroWhat1)
        local loc = GetUnitLoc(GetDyingUnit())
        PingMinimapLocForForce(GetPlayersAll(), loc, 1.0)
        RemoveLocation(loc)
        DisplayTimedTextToForce(GetPlayersAll(), 5.0, prisonerDeath[GetRandomInt(1, 7)])
    end)
end
