-- Level 1 — and the shared per-level infrastructure
-- Requirements: levels/Level_1.md
-- Source lines: war3map.j 19141-19250

-- ─── Shared pre-level routine (called at start of every level) ────────────────
-- war3map.j lines 19035-19053

function ThingsToDoBeforeEveryLevelBegins()
    -- Revive all heroes at the starting area
    local function revive(hero)
        if hero then
            ReviveHeroLoc(hero, GetRectCenter(rct.StartingPlayerArea), true)
        end
    end
    revive(P1Hero); revive(P2Hero); revive(P3Hero); revive(P4Hero)
    revive(P5Hero); revive(P6Hero); revive(P7Hero); revive(P8Hero)
    revive(WildbondPet)

    -- Spawn garrison guards (stubs — full garrison system analyzed separately)
    -- SpawnMeleeGuards()
    -- SpawnArcherGuards()

    DieHardActivated = false
end

-- ─── Post-victory routine ─────────────────────────────────────────────────────
-- war3map.j line 19064-19072

function ThingsToDoImmediatelyFollowingVictory()
    -- Miser hero gets 100 gold per victory
    if MiserPlayer then
        AdjustPlayerStateBJ(100, MiserPlayer, PLAYER_STATE_RESOURCE_GOLD)
    end
end

-- ─── Between-level countdown timer ───────────────────────────────────────────
-- war3map.j lines 19077-19120

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

-- ─── Fast Victories timer (runs concurrently during each wave) ───────────────
-- war3map.j lines 7436-7449

function StartFastVictoriesTimer()
    local t = CreateTimer()
    TimerStart(t, 60.0, false, function()
        if not LevelBeaten then
            BlazingVictory = false
        end
        TimerStart(t, 60.0, false, function()
            if not LevelBeaten then
                SpeedyVictory = false
            end
        end)
    end)
end

-- ─── Bonus Reset (called at start of each new level) ─────────────────────────
-- war3map.j lines 6414-6422

function BonusReset()
    HeroAssassination       = false
    BlazingVictory          = true
    SpeedyVictory           = true
    StalwartDefender        = true
    PlayerTotalDeathsForRound = 0
end

-- ─── Level 1 ──────────────────────────────────────────────────────────────────

local trgLevel1Victory = nil

function Level1Start()
    ThingsToDoBeforeEveryLevelBegins()
    LevelBonuses[1] = true

    TriggerSleepAction(1.0)
    PlaySoundBJ(snd.Courageous)
    DisplayTimedTextToForce(GetPlayersAll(), 20.0,
        "|cffff8800Level 1|r — Squires approach from the north and east. Defend the town!")
    TriggerSleepAction(1.0)

    -- Spawn enemies — (5 + DifficultyModifier) footmen from each of 3 spawns
    local count = 5 + DifficultyModifier
    CreateNUnitsAtLoc(1,     FourCC('e01M'), Player(9), GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
    CreateNUnitsAtLoc(1,     FourCC('e01M'), Player(9), GetRectCenter(rct.SpawnB), bj_UNIT_FACING)
    CreateNUnitsAtLoc(1,     FourCC('e01M'), Player(9), GetRectCenter(rct.SpawnC), bj_UNIT_FACING)
    CreateNUnitsAtLoc(count, FourCC('h002'), Player(9), GetRectCenter(rct.SpawnA), bj_UNIT_FACING)
    CreateNUnitsAtLoc(count, FourCC('h002'), Player(9), GetRectCenter(rct.SpawnB), bj_UNIT_FACING)
    CreateNUnitsAtLoc(count, FourCC('h002'), Player(9), GetRectCenter(rct.SpawnC), bj_UNIT_FACING)

    TriggerSleepAction(1.0)

    -- Issue patrol order — all Player(9) units march toward the base
    local grp = GetUnitsInRectOfPlayer(GetPlayableMapRect(), Player(9))
    ForGroup(grp, function()
        IssuePointOrderLoc(GetEnumUnit(), "patrol", GetRectCenter(rct.StartingPlayerArea))
    end)
    DestroyGroup(grp)

    DisplayTextToForce(GetPlayersAll(), "|cffaaaaff" .. (5 + DifficultyModifier) .. "x Squires per lane — stop them!|r")

    StartFastVictoriesTimer()
    MusicOn          = true
    CurrentTrackMusic = 1

    TriggerSleepAction(0.75)

    -- Arm the victory-check trigger
    trgLevel1Victory = CreateTrigger()
    DisableTrigger(trgLevel1Victory)
    TriggerRegisterTimerEventPeriodic(trgLevel1Victory, 8.0)
    TriggerAddAction(trgLevel1Victory, Level1VictoryCheck)
    EnableTrigger(trgLevel1Victory)

    -- Destroy speed wisps after 10s
    local wipTimer = CreateTimer()
    TimerStart(wipTimer, 10.0, false, function()
        local wisps = GetUnitsOfPlayerAndTypeId(Player(9), FourCC('e01M'))
        ForGroup(wisps, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(wisps)
    end)
end

-- ─── Level 1 victory check (polled every 8s) ──────────────────────────────────

function Level1VictoryCheck()
    if CountLivingPlayerUnitsOfTypeId(FourCC('h002'), Player(9)) == 0 then
        DisableTrigger(trgLevel1Victory)
        MusicOn  = false
        LevelBeaten = true

        PlaySoundBJ(snd.RoundClear)
        ThingsToDoImmediatelyFollowingVictory()
        TimerForNextLevel(false)

        TriggerSleepAction(0.25)
        DisplayTextToForce(GetPlayersAll(), "|cff00ff00Level 1 cleared!|r")
        TriggerSleepAction(0.25)

        BonusesAndUpkeep()

        TriggerSleepAction(3.0)
        BonusReset()
        LevelBeaten = false
        CurrentLevel = 2

        -- Level 2 not yet implemented — announce and stop
        TriggerSleepAction(8.0)
        DestroyNextLevelTimer()
        DisplayTextToForce(GetPlayersAll(),
            "|cffff8800Level 2 and beyond are not yet implemented in this Phase 5 build.|r")
    end
end

-- ─── Bonuses and Upkeep (called on level victory) ─────────────────────────────
-- Requirements: progression/Achievements.md — only universal bonuses implemented for Phase 5

function BonusesAndUpkeep()
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
        awardAll(100, "|cff00ff00Flawless! No hero died this round — |cffffcc00+100 Gold|r each.")
    elseif PlayerTotalDeathsForRound == 0 then
        awardAll(50, "|cff00ff00No deaths this round — |cffffcc00+50 Gold|r each.")
    end

    if StalwartDefender then
        awardAll(50, "|cff00ff00Stalwart Defender! No enemy reached the base — |cffffcc00+50 Gold|r each.")
    end

    if BlazingVictory then
        awardAll(200, "|cff00ff00Blazing Victory! Won in under 60 seconds — |cffffcc00+200 Gold|r each.")
    elseif SpeedyVictory then
        awardAll(100, "|cff00ff00Speedy Victory! Won in under 120 seconds — |cffffcc00+100 Gold|r each.")
    end

    -- Level bonus (Level 1: no enemy crossed the halfway point)
    if LevelBonuses[1] then
        awardAll(100, "|cff00ff00Level Bonus — |cffffcc00+100 Gold|r (No enemy crossed the halfway marker!)")
        LevelBonuses[1] = false
    end
end

-- ─── Register Level 1 bonus halfway check ─────────────────────────────────────

function RegisterLevel1BonusTrigger()
    local trg = CreateTrigger()
    TriggerRegisterEnterRectSimple(trg, rct.HalfwayMarkerA)
    TriggerRegisterEnterRectSimple(trg, rct.HalfwayMarkerB)
    TriggerRegisterEnterRectSimple(trg, rct.HalfwayMarkerC)
    TriggerAddCondition(trg, Condition(function()
        return GetOwningPlayer(GetEnteringUnit()) == Player(9)
    end))
    TriggerAddAction(trg, function()
        if LevelBonuses[1] then
            LevelBonuses[1] = false
            DisableTrigger(trg)
        end
    end)

    -- Stalwart Defender — enemy enters base area
    local trgStalwart = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgStalwart, rct.AreaToDefend)
    TriggerAddCondition(trgStalwart, Condition(function()
        return GetOwningPlayer(GetEnteringUnit()) == Player(9)
    end))
    TriggerAddAction(trgStalwart, function()
        StalwartDefender = false
    end)
end
