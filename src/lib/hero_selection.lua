-- Hero Selection — full pre-game flow
-- Requirements: hero-selection/HeroSelection.md
-- Source lines: war3map.j 16659-18877
--
-- Flow: Mode Type → Difficulty → Random/Pick mode → Hero pick → Feats → BeginningStart2 → Level 1

-- Global so debug.lua (-repick) can reassign a hero. playerIndex 0-7 -> P1Hero..P8Hero.
function AssignHero(unit, playerIndex)
    if playerIndex == 0 then P1Hero = unit
    elseif playerIndex == 1 then P2Hero = unit
    elseif playerIndex == 2 then P3Hero = unit
    elseif playerIndex == 3 then P4Hero = unit
    elseif playerIndex == 4 then P5Hero = unit
    elseif playerIndex == 5 then P6Hero = unit
    elseif playerIndex == 6 then P7Hero = unit
    elseif playerIndex == 7 then P8Hero = unit
    end
end

-- Global so level1.lua and other modules can use it
function IsHumanPlayer(p)
    return GetPlayerController(p) == MAP_CONTROL_USER
        and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING
end

local function CountHumanPlayers()
    local n = 0
    for i = 0, 7 do
        if IsHumanPlayer(Player(i)) then n = n + 1 end
    end
    return n
end

-- StopAllMusic() is now provided globally by lib/music.lua.

-- Ends the intro music for good: clear the flag (stops the loop re-firing) and stop
-- the currently-playing intro sound immediately. Called when a game mode is chosen.
local function EndIntroMusic()
    IntroMusicOn = false
    StopAllMusic()
end

-- Spawn a wisp for a player at a rect
local function SpawnWisp(p, rect)
    return CreateUnit(p, FourCC('ewsp'), GetRectCenterX(rect), GetRectCenterY(rect), bj_UNIT_FACING)
end

-- Spawn NPC blue-player hero (H04Y) for story/battle/solo modes
local function SpawnBlueCompanion()
    CreateUnit(Player(1), FourCC('H04Y'), GetRectCenterX(rct.VernPatrolA), GetRectCenterY(rct.VernPatrolA), bj_UNIT_FACING)
    P2Hero = GetLastCreatedUnit()
    AdjustPlayerStateBJ(325, Player(1), PLAYER_STATE_RESOURCE_GOLD)
    RegisterCompanionAI()  -- patrol circuit + heal/defend behaviors (lib/companion.lua)
end

-- Reveal full map fog for all players
local function RevealGameArea()
    for i = 0, 7 do
        if IsHumanPlayer(Player(i)) then
            CreateFogModifierRectBJ(true, Player(i), FOG_OF_WAR_VISIBLE, rct.EntireGameArea)
            CreateFogModifierRectBJ(true, Player(i), FOG_OF_WAR_VISIBLE, rct.EntireCastleArea)
        end
    end
end

-- Spawn one selection wisp per active human player at PickModeStart
local function SpawnSelectionWisps()
    for i = 0, 7 do
        local p = Player(i)
        if IsHumanPlayer(p) then
            SpawnWisp(p, rct.PickModeStart)
        end
    end
end

-- Pan all cameras to a rect
local function PanAllCamerasTo(rect)
    for i = 0, 7 do
        if IsHumanPlayer(Player(i)) then
            PanCameraToTimedLocForPlayer(Player(i), GetRectCenter(rect), 0)
        end
    end
end

-- ─── Difficulty selection ────────────────────────────────────────────────────

local function ShowDifficultyLabels()
    CreateTextTagLocBJ("Normal",   GetRectCenter(rct.DifficultyNormal),   0, 10, 0.0,  0.0,  100.0, 0)
    ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
    CreateTextTagLocBJ("Hard",     GetRectCenter(rct.DifficultyHard),     0, 10, 0.0,  100.0, 0.0, 0)
    ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
    CreateTextTagLocBJ("Champion", GetRectCenter(rct.DifficultyChampion), 0, 10, 100.0, 100.0, 0.0, 0)
    ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
    CreateTextTagLocBJ("Insane",   GetRectCenter(rct.DifficultyInsane),   0, 10, 100.0, 0.0,  0.0, 0)
    ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
end

local function PickDifficulty()
    PanAllCamerasTo(rct.SelectDifficulty)
    for i = 0, 7 do
        if IsHumanPlayer(Player(i)) then
            CreateFogModifierRectBJ(true, Player(i), FOG_OF_WAR_VISIBLE, rct.SelectDifficulty)
        end
    end
    ShowDifficultyLabels()
    -- Difficulty regions handled by separate enter-rect triggers below
end

local function AfterDifficulty()
    PanAllCamerasTo(rct.SelectMode)
    CreateTextTagLocBJ("Random Mode", GetRectCenter(rct.RandomModeSpot), 0, 10, 100, 100, 100, 0)
    ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
    CreateTextTagLocBJ("Pick Mode",   GetRectCenter(rct.PickModeSpot),   0, 10, 100, 100, 100, 0)
    ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
end

-- ─── Mode type selection triggers ────────────────────────────────────────────

local function OnStoryMode(trigger)
    local entering = GetEnteringUnit()
    DisplayTimedTextToForce(GetPlayersAll(), 8.0, "Story Mode selected.")
    StoryMode = true
    RemoveUnit(entering)
    SpawnBlueCompanion()
    PickDifficulty()
    -- Spawn wisp at difficulty start area
    SpawnWisp(GetOwningPlayer(entering), rct.SelectDifficultyStart)
end

local function OnBattleMode(trigger)
    local entering = GetEnteringUnit()
    DisplayTimedTextToForce(GetPlayersAll(), 8.0, "Battle Mode selected.")
    StoryMode = false
    RemoveUnit(entering)
    SpawnBlueCompanion()
    PickDifficulty()
    SpawnWisp(GetOwningPlayer(entering), rct.SelectDifficultyStart)
end

local function OnSoloMode(trigger)
    local entering = GetEnteringUnit()
    if TotalPlaying > 1 then
        DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(entering)),
            "|cffff0000Solo Mode requires exactly 1 player.|r")
        return
    end
    DisplayTimedTextToForce(GetPlayersAll(), 8.0, "Solo Mode selected.")
    SoloMode    = true
    SelectedMode = true
    RemoveUnit(entering)
    SpawnBlueCompanion()
    TotalPlaying = CountHumanPlayers()
    RevealGameArea()
    DifficultyModifier = DifficultyModifier - 1
    TriggerSleepAction(2.0)
    SpawnSelectionWisps()
end

-- ─── Difficulty entry triggers ────────────────────────────────────────────────

local function SetDifficultyAndAdvance(label, mod, ldm, givePotions)
    Difficulty          = label
    DifficultyModifier  = DifficultyModifier + mod
    LevelDiffModifier   = ldm
    StartingPotions     = givePotions
    AfterDifficulty()
    -- Move triggering wisp to SelectModeEnter so it can enter the mode selection
    local entering = GetEnteringUnit()
    RemoveUnit(entering)
    SpawnWisp(GetOwningPlayer(entering), rct.SelectModeEnter)
end

-- ─── Mode selection (Random vs Pick) ─────────────────────────────────────────

-- Preview ghost loop (shows random heroes in the preview window while players pick)
local function RunPreviewGhosts()
    if PickModeDone then return end
    HeroSelected = GetRandomInt(0, TotalHeroes)
    TriggerSleepAction(1.0)
    local previewUnit = CreateUnit(Player(8), HeroPicked[HeroSelected],
        GetRectCenterX(rct.UnitPickPreview), GetRectCenterY(rct.UnitPickPreview), 0.0)
    SetUnitVertexColorBJ(previewUnit, 100, 100, 100, 30.0)
    CreateTextTagLocBJ(HeroText[HeroSelected], GetRectCenter(rct.UnitPickPreviewText), 0, 10, 100, 0.0, 60.0, 0)
    SetTextTagPermanentBJ(GetLastCreatedTextTag(), false)
    SetTextTagLifespanBJ(GetLastCreatedTextTag(), 20.0)
    ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
    TriggerSleepAction(4.0)
    SetUnitAnimation(previewUnit, "attack")
    TriggerSleepAction(2.0)
    ResetUnitAnimation(previewUnit)
    TriggerSleepAction(4.0)
    SetUnitAnimation(previewUnit, "victory")
    TriggerSleepAction(6.0)
    ResetUnitAnimation(previewUnit)
    TriggerSleepAction(2.0)
    RemoveUnit(previewUnit)
    TriggerSleepAction(1.0)
    RunPreviewGhosts()  -- recurse until PickModeDone
end

local function OnRandomMode(trigger)
    local entering = GetEnteringUnit()
    RemoveUnit(entering)
    DisableTrigger(trigger)
    SelectedMode = true
    TotalPlaying = CountHumanPlayers()
    if GetPlayerSlotState(Player(10)) == PLAYER_SLOT_STATE_PLAYING then
        TotalPlaying = TotalPlaying - 1
    end
    PauseAllUnitsBJ(true)
    SetSkyModel("Environment\\Sky\\LordaeronSummerSky\\LordaeronSummerSky.mdl")
    SetPlayerFlagBJ(PLAYER_STATE_GIVES_BOUNTY, true, Player(9))
    RevealGameArea()
    TriggerSleepAction(1.0)
    -- Assign random heroes to all active players
    RandomHeroNew()
    for i = 0, 7 do
        if IsHumanPlayer(Player(i)) then
            ResetToGameCameraForPlayer(Player(i), 0)
        end
    end
    TriggerSleepAction(24.0)
    -- Scale difficulty by player count
    DifficultyCheck()
    TriggerSleepAction(4.0)
    BeginningStart()
end

local function OnPickMode(trigger)
    local entering = GetEnteringUnit()
    RemoveUnit(entering)
    DisableTrigger(trigger)
    SelectedMode = true
    TotalPlaying = CountHumanPlayers()
    if GetPlayerSlotState(Player(10)) == PLAYER_SLOT_STATE_PLAYING then
        TotalPlaying = TotalPlaying - 1
    end
    SetSkyModel("Environment\\Sky\\LordaeronSummerSky\\LordaeronSummerSky.mdl")
    SetPlayerFlagBJ(PLAYER_STATE_GIVES_BOUNTY, true, Player(9))

    -- Pan all cameras toward the pick area so players see the hero taverns
    for i = 0, 7 do
        if IsHumanPlayer(Player(i)) then
            PanCameraToTimedLocForPlayer(Player(i), GetRectCenter(rct.PickMode), 0)
            CreateFogModifierRectBJ(true, Player(i), FOG_OF_WAR_VISIBLE, rct.PickMode)
        end
    end
    -- Start hero preview loop
    CreateTimer()  -- ghost loop runs in its own coroutine via trigger action
    local ghostTrg = CreateTrigger()
    TriggerAddAction(ghostTrg, RunPreviewGhosts)
    ConditionalTriggerExecute(ghostTrg)
    TriggerSleepAction(1.0)
    DisplayTimedTextToForce(GetPlayersAll(), 8.0, "Select your hero — walk to the hero selection area!")
    CreateTextTagLocBJ("Your Hero", GetRectCenter(rct.HeroPickMessage), 0, 10, 100, 100, 0.0, 0)
    ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
    SpawnSelectionWisps()
    TriggerSleepAction(1.0)
    DifficultyCheck()
    TriggerSleepAction(1.0)
end

-- ─── Random hero assignment ───────────────────────────────────────────────────

function RandomHeroNew()
    for i = 0, 7 do
        local p = Player(i)
        if IsHumanPlayer(p) and GetPlayerUnitCount(p, false) == 0 then
            -- retry until non-duplicate
            local idx
            repeat
                idx = GetRandomInt(0, TotalHeroes)
            until DuplicateHero[idx] ~= 1

            local heroUnit = CreateUnit(p,
                HeroPicked[idx],
                GetRectCenterX(CurrentHeroIntroLoc[CurrentIntroLocInt]),
                GetRectCenterY(CurrentHeroIntroLoc[CurrentIntroLocInt]),
                180.0)
            AssignHero(heroUnit, i)
            PauseUnit(heroUnit, true)
            DuplicateHero[idx] = 1
            CurrentIntroLocInt = CurrentIntroLocInt + 1
            UnitAddItemByIdSwapped(TarotCards[GetRandomInt(0, 20)], heroUnit)
            TriggerSleepAction(1.0)
        end
    end
end

-- ─── Manual hero pick ─────────────────────────────────────────────────────────

local function OnPickModeHero(trigger)
    local entering = GetEnteringUnit()
    if not IsUnitType(entering, UNIT_TYPE_HERO) then return end
    if GetOwningPlayer(entering) == Player(8) then return end

    local owner = GetOwningPlayer(entering)
    SetUnitPosition(entering, GetRectCenterX(rct.StartingPlayerArea), GetRectCenterY(rct.StartingPlayerArea))
    PauseUnit(entering, true)

    for i = 0, 7 do
        if GetOwningPlayer(entering) == Player(i) then
            AssignHero(entering, i)
            break
        end
    end

    UnitAddItemByIdSwapped(TarotCards[GetRandomInt(0, 20)], entering)
    DonePicking()
end

-- ─── Done picking check ───────────────────────────────────────────────────────

function DonePicking()
    -- Check if any non-computer, non-neutral units remain in pick zone
    local grp = GetUnitsInRectAll(rct.PickMode)
    local remaining = 0
    ForGroup(grp, function()
        local u = GetEnumUnit()
        local owner = GetOwningPlayer(u)
        if GetPlayerController(owner) ~= MAP_CONTROL_COMPUTER
            and owner ~= Player(PLAYER_NEUTRAL_PASSIVE) then
            remaining = remaining + 1
        end
    end)
    DestroyGroup(grp)

    if remaining == 0 then
        TriggerSleepAction(1.0)
        PickModeDone        = true
        PickModeStillGoing  = false
        BeginningStart()
    end
end

-- ─── BeginningStart ──────────────────────────────────────────────────────────

function BeginningStart()
    DisplayTextToForce(GetPlayersAll(), "Preparing the adventure...")
    AdjustPlayerStateBJ(100, Player(0), PLAYER_STATE_RESOURCE_GOLD)
    for i = 1, 7 do
        if IsHumanPlayer(Player(i)) then
            AdjustPlayerStateBJ(100, Player(i), PLAYER_STATE_RESOURCE_GOLD)
        end
    end

    -- Wait until all expected heroes exist
    local waited = 0
    while waited < 60 do
        local heroCount = 0
        local grp = GetUnitsInRectAll(GetPlayableMapRect())
        ForGroup(grp, function()
            if IsUnitType(GetEnumUnit(), UNIT_TYPE_HERO) then
                heroCount = heroCount + 1
            end
        end)
        DestroyGroup(grp)
        if heroCount >= TotalPlaying then break end
        TriggerSleepAction(10.0)
        waited = waited + 10
    end

    -- Give Wildbond pet if applicable
    GiveWildbondPet()

    TriggerSleepAction(10.0)

    -- Feat selection
    PickFeat()

    -- Reveal feat area fog
    for i = 0, 7 do
        if IsHumanPlayer(Player(i)) then
            CreateFogModifierRectBJ(true, Player(i), FOG_OF_WAR_VISIBLE, rct.EntireFeatArea)
        end
    end
end

-- ─── Wildbond pet ────────────────────────────────────────────────────────────

function GiveWildbondPet()
    -- Only if exactly one Wildbond hero exists
    local grp = GetUnitsOfTypeIdAll(FourCC('H03J'))
    if CountUnitsInGroup(grp) ~= 1 then
        DestroyGroup(grp)
        return
    end
    Wildbond        = GroupPickRandomUnit(grp)
    WildbondPlayer  = GetOwningPlayer(Wildbond)
    DestroyGroup(grp)

    TriggerSleepAction(1.0)
    WildbondRandomNum = GetRandomInt(1, 4)
    TriggerSleepAction(1.0)
    CreateUnit(WildbondPlayer, WildbondPetTable[WildbondRandomNum],
        GetRectCenterX(rct.StartingPlayerArea), GetRectCenterY(rct.StartingPlayerArea), bj_UNIT_FACING)
    WildbondPet = GetLastCreatedUnit()
end

-- ─── Feat selection ───────────────────────────────────────────────────────────

function PickFeat()
    PanAllCamerasTo(rct.FeatArea)
    DisplayTimedTextToForce(GetPlayersAll(), 20.0,
        "Select your Feat — enter the Feat Area and choose an ability! (120 seconds)")

    -- Move all player heroes to the feat area
    local grp = GetUnitsInRectAll(GetPlayableMapRect())
    ForGroup(grp, function()
        local u = GetEnumUnit()
        local owner = GetOwningPlayer(u)
        if IsUnitType(u, UNIT_TYPE_HERO)
            and owner ~= Player(8) and owner ~= Player(11) and owner ~= Player(12) then
            SetUnitPosition(u, GetRectCenterX(rct.FeatArea), GetRectCenterY(rct.FeatArea))
            PauseUnit(u, false)
        end
    end)
    DestroyGroup(grp)

    -- Start feat timer (120 seconds)
    StartTimerBJ(PickFeatTimer, false, 120.0)
    CreateTimerDialogBJ(PickFeatTimer, "Feat Selection")
    TimerDialogDisplayBJ(true, GetLastCreatedTimerDialogBJ())

    CreateTextTagLocBJ("Choose Your Feat!", GetRectCenter(rct.FeatArea), 0, 9.0, 100, 100, 0.0, 0)
    CreateTextTagLocBJ("Team Feats",        GetRectCenter(rct.TeamFeats), 0, 8.0, 0.0, 100, 0.0, 0)
end

-- ─── Feat timer expires → BeginningStart2 ────────────────────────────────────

local function OnFeatTimerExpires()
    if FeatSelectionDone then return end
    FeatSelectionDone = true  -- set before sleep to block concurrent feat-leave trigger

    -- Give default feat to anyone still in the feat area
    local grp = GetUnitsInRectAll(rct.EntireFeatArea)
    ForGroup(grp, function()
        local u = GetEnumUnit()
        if IsUnitType(u, UNIT_TYPE_HERO) then
            UnitAddAbilityBJ(FourCC('A05R'), u)
            SetUnitPosition(u, GetRectCenterX(rct.StartingPlayerArea), GetRectCenterY(rct.StartingPlayerArea))
        end
    end)
    DestroyGroup(grp)

    TriggerSleepAction(1.0)
    FeatSelectionDone = true
    DestroyTimerDialogBJ(GetLastCreatedTimerDialogBJ())
    BeginningStart2()
end

-- Fires when a hero leaves the feat area (each pick). The blue AI companion
-- (H04Y, Player 1, computer-controlled in Story/Battle/Solo) is also swept into
-- the feat area by PickFeat but never buys a feat on its own. So we only wait on
-- *human*-owned heroes; once they have all picked, the companion auto-picks last
-- (ResolveCompanionFeats in feats.lua) so the game starts immediately instead of
-- stalling for the full 120s timer.
local function CheckAllLeftFeatArea()
    if FeatSelectionDone then return end
    local grp = GetUnitsInRectAll(rct.EntireFeatArea)
    local humanHeroes = 0
    ForGroup(grp, function()
        local heroUnit = GetEnumUnit()
        if IsUnitType(heroUnit, UNIT_TYPE_HERO) and IsHumanPlayer(GetOwningPlayer(heroUnit)) then
            humanHeroes = humanHeroes + 1
        end
    end)
    DestroyGroup(grp)

    if humanHeroes == 0 then
        FeatSelectionDone = true  -- set before sleep to block any concurrent fires
        ResolveCompanionFeats()   -- blue companion picks last + leaves the area
        TriggerSleepAction(1.0)
        PauseTimerBJ(true, PickFeatTimer)
        DestroyTimerDialogBJ(GetLastCreatedTimerDialogBJ())
        BeginningStart2()
    end
end

-- ─── BeginningStart2 — the actual game start ─────────────────────────────────

function BeginningStart2()
    if GameStarted then return end
    GameStarted = true  -- set immediately to block any concurrent call during the sleeps below

    -- Intro music keeps playing through this sequence; it is stopped ~4s before wave 1
    -- (EndIntroMusic below), then vanilla gameplay music takes over.
    AntiDuplicateTxt = true
    PauseAllUnitsBJ(false)
    KickCompanionPatrol()  -- (re)start Sir Joshua now units are unpaused (pre-game pause dropped his order)

    TriggerSleepAction(5.0)

    -- Starting potions (Normal + Hard difficulty only)
    if StartingPotions then
        local grp = GetUnitsInRectAll(GetPlayableMapRect())
        ForGroup(grp, function()
            local u = GetEnumUnit()
            if IsUnitType(u, UNIT_TYPE_HERO)
                and GetOwningPlayer(u) ~= Player(8)
                and GetOwningPlayer(u) ~= Player(11)
                and GetOwningPlayer(u) ~= Player(12) then
                UnitAddItemByIdSwapped(FourCC('I0BU'), u)
            end
        end)
        DestroyGroup(grp)
    end

    -- Reveal full game area for all players (the fog-of-war fix)
    RevealGameArea()

    TriggerSleepAction(6.0)

    PlaySoundBJ(snd.GameFound)
    DisplayTextToForce(GetPlayersAll(), "The battle begins!")

    -- Ping spawn locations
    PingMinimapLocForForceEx(GetPlayersAll(), GetRectCenter(rct.SpawnA), 10.0, bj_MINIMAPPINGSTYLE_SIMPLE, 100, 0.0, 0.0)
    PingMinimapLocForForceEx(GetPlayersAll(), GetRectCenter(rct.SpawnB), 10.0, bj_MINIMAPPINGSTYLE_SIMPLE, 100, 0.0, 0.0)
    PingMinimapLocForForceEx(GetPlayersAll(), GetRectCenter(rct.SpawnC), 10.0, bj_MINIMAPPINGSTYLE_SIMPLE, 100, 0.0, 0.0)

    TriggerSleepAction(9.0)

    -- Stop the intro and bring in vanilla gameplay music ~4s before wave 1 spawns.
    EndIntroMusic()
    BeginWaveMusic()
    TriggerSleepAction(2.0)

    -- Start Level 1. (No GameStarted guard here — re-entry is already prevented by
    -- the GameStarted=true set at the top of this function. The reference set
    -- GameStarted inside Level_1 and guarded here; we moved it up to fix the
    -- triple-start race, so this call must be unconditional.)
    Level1Start()

    SetPlayerHandicapDamageBJ(Player(9), 75.0)
end

-- ─── Difficulty scaling by player count ──────────────────────────────────────

function DifficultyCheck()
    if TotalPlaying <= 3 then
        DifficultyModifier = DifficultyModifier + 1
    elseif TotalPlaying == 4 or TotalPlaying == 5 then
        DifficultyModifier = DifficultyModifier + 2
    elseif TotalPlaying >= 6 then
        DifficultyModifier = DifficultyModifier + 3
    end
end

-- ─── Boot AFKers (3-minute warning, called from Pick_Mode flow) ───────────────

local function BootAFKers()
    DisplayTextToForce(GetPlayersAll(), "|cffff8800Players are picking heroes...|r")
    TriggerSleepAction(60.0)
    if not PickModeStillGoing then return end
    DisplayTextToForce(GetPlayersAll(), "|cffff8800Warning: AFK players will be removed in 2 minutes.|r")
    PlaySoundBJ(snd.CreepAggroWhat1)
    TriggerSleepAction(60.0)
    if not PickModeStillGoing then return end
    DisplayTextToForce(GetPlayersAll(), "|cffff0000Final warning: AFK players removed in 1 minute.|r")
    PlaySoundBJ(snd.CreepAggroWhat1)
    TriggerSleepAction(60.0)
    if not PickModeStillGoing then return end

    -- Kick AFK players still in the pick zone
    local grp = GetUnitsInRectAll(rct.PickMode)
    ForGroup(grp, function()
        local u = GetEnumUnit()
        local owner = GetOwningPlayer(u)
        if GetPlayerController(owner) ~= MAP_CONTROL_COMPUTER then
            CustomDefeatBJ(owner, "Removed for inactivity.")
        end
        RemoveUnit(u)
    end)
    DestroyGroup(grp)

    PickModeStillGoing  = false
    PickModeDone        = true
    TriggerSleepAction(1.0)
    BeginningStart()
end

-- ─── Register all selection triggers ─────────────────────────────────────────

function RegisterHeroSelectionTriggers()
    -- Mode Type Selection
    local trgStory = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgStory, rct.StoryMode)
    TriggerAddAction(trgStory, function() OnStoryMode(trgStory) end)

    local trgBattle = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgBattle, rct.BattleMode)
    TriggerAddAction(trgBattle, function() OnBattleMode(trgBattle) end)

    local trgSolo = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgSolo, rct.SoloMode)
    TriggerAddCondition(trgSolo, Condition(function() return SelectedMode == false end))
    TriggerAddAction(trgSolo, function() OnSoloMode(trgSolo) end)

    -- Difficulty selection
    local trgNorm = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgNorm, rct.DifficultyNormal)
    TriggerAddAction(trgNorm, function()
        SetDifficultyAndAdvance("Normal", 0, 2, true)
    end)

    local trgHard = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgHard, rct.DifficultyHard)
    TriggerAddAction(trgHard, function()
        SetDifficultyAndAdvance("Hard", 1, 4, true)
    end)

    local trgChamp = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgChamp, rct.DifficultyChampion)
    TriggerAddAction(trgChamp, function()
        SetDifficultyAndAdvance("Champion", 2, 6, false)
    end)

    local trgInsane = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgInsane, rct.DifficultyInsane)
    TriggerAddAction(trgInsane, function()
        SetDifficultyAndAdvance("Insane", 3, 9, false)
    end)

    -- Mode selection (Random vs Pick)
    local trgRandom = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgRandom, rct.RandomModeSpot)
    TriggerAddAction(trgRandom, function() OnRandomMode(trgRandom) end)

    local trgPick = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgPick, rct.PickModeSpot)
    TriggerAddAction(trgPick, function()
        OnPickMode(trgPick)
        -- Boot AFKers trigger
        local bootTrg = CreateTrigger()
        TriggerAddAction(bootTrg, BootAFKers)
        ConditionalTriggerExecute(bootTrg)
    end)

    -- Remove Spirit — when a wisp buys a hero from a tavern, remove the wisp.
    -- war3map.j 17606-17623. EVENT_PLAYER_UNIT_SELL fires when a shop sells a UNIT;
    -- GetBuyingUnit() is the purchasing wisp. Without this the wisp lingers in
    -- rct.PickMode and DonePicking's "zero units remain" check never passes.
    local trgRemoveSpirit = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trgRemoveSpirit, EVENT_PLAYER_UNIT_SELL)
    TriggerAddCondition(trgRemoveSpirit, Condition(function()
        return GetUnitTypeId(GetBuyingUnit()) == FourCC('ewsp')
    end))
    TriggerAddAction(trgRemoveSpirit, function()
        RemoveUnit(GetBuyingUnit())
    end)

    -- Manual hero pick zone entry
    local trgPickHero = CreateTrigger()
    TriggerRegisterEnterRectSimple(trgPickHero, rct.PickMode)
    TriggerAddCondition(trgPickHero, Condition(function()
        return IsUnitType(GetEnteringUnit(), UNIT_TYPE_HERO)
            and GetOwningPlayer(GetEnteringUnit()) ~= Player(8)
    end))
    TriggerAddAction(trgPickHero, function() OnPickModeHero(trgPickHero) end)

    -- Feat timer expiry
    local trgFeatExpire = CreateTrigger()
    TriggerRegisterTimerExpireEventBJ(trgFeatExpire, PickFeatTimer)
    TriggerAddCondition(trgFeatExpire, Condition(function() return FeatSelectionDone == false end))
    TriggerAddAction(trgFeatExpire, OnFeatTimerExpires)

    -- Early start: all players left feat area
    local trgFeatLeave = CreateTrigger()
    TriggerRegisterLeaveRectSimple(trgFeatLeave, rct.EntireFeatArea)
    TriggerAddAction(trgFeatLeave, CheckAllLeftFeatArea)
end
