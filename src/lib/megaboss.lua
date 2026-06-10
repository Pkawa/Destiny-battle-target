-- Megaboss 1 — the Dark One (O003) + Fleshmaker (O006) arena encounter: the bridge between
-- Level 24 and Level 26 (the level numbering skips 25). Started by Level 24 victory
-- (levels.lua LevelData[24].onVictory) and by the -megaboss debug command.
-- Requirements: bosses/Bosses.md §3-4. Source: war3map.j 36478-36955 (+ Fleshmaker/Dark One
-- spells 36956-37260).
--
-- Signature mechanic (Check_Invul): the Dark One is INVULNERABLE until all four Fleshmakers
-- die; killing them exposes it for a 20s window, after which (if it still lives) the
-- Fleshmakers respawn and it re-shields. Tentacles (h02M) harass; enemies leaving the arena
-- die. Victory = the Dark One dies -> teleport heroes home -> Level 26.

local P9 = Player(9)
local O003, O006, TENTACLE = FourCC('O003'), FourCC('O006'), FourCC('h02M')
local ACID_ORB, ACID_SPRAY = FourCC('e00T'), FourCC('e00U')   -- roaming orb / spray missile
local FLAMESTRIKE = FourCC('A09D')                            -- Acid Surge cast ability

local CORNERS = { 'Megaboss1NWCorner', 'Megaboss1SECorner', 'Megaboss1SWCorner', 'Megaboss1NECorner' }
local TENTACLE_SPAWNS = {
    'TentacleSpawnA', 'TentacleSpawnB', 'TentacleSpawnC',
    'TentacleSpawnD', 'TentacleSpawnE', 'TentacleSpawnF',
}

-- A random living unit of type `id` owned by Player 9.
local function pickOf(id)
    local g = GetUnitsOfPlayerAndTypeId(P9, id)
    local u = GroupPickRandomUnit(g)
    DestroyGroup(g)
    return u
end

local function spawnFleshmakers()
    for _, c in ipairs(CORNERS) do
        CreateUnit(P9, O006, GetRectCenterX(rct[c]), GetRectCenterY(rct[c]), bj_UNIT_FACING)
    end
end

-- A random non-Player-9 unit (optionally hero-only) inside the arena.
local function arenaTarget(heroOnly)
    local g = CreateGroup()
    GroupEnumUnitsInRect(g, rct.Megaboss1EntireArea, Condition(function()
        local f = GetFilterUnit()
        return GetOwningPlayer(f) ~= P9 and (not heroOnly or IsUnitType(f, UNIT_TYPE_HERO))
    end))
    local u = GroupPickRandomUnit(g)
    DestroyGroup(g)
    return u
end

-- Order `u` to move `dist` along its current facing (the polar-projection move the acid
-- units use constantly).
local function moveForward(u, dist)
    local a = math.rad(GetUnitFacing(u))
    IssuePointOrder(u, "move", GetUnitX(u) + dist * math.cos(a), GetUnitY(u) + dist * math.sin(a))
end

local function bossTag(boss, text)
    if boss then FloatText(boss, text, 100, 0, 0, 4.0) end
end

-- The encounter setup + AI. Runs in a trigger-action thread (sleeps allowed).
function StartMegaboss1()
    ToughBossMusic = true
    MusicOn = false
    ThingsToDoBeforeEveryLevelBegins()
    StartToughBossMusic()   -- the tough-boss loop's first real trigger (music.lua)

    -- reveal the arena + zoom-out camera for every human
    for i = 0, 7 do
        local p = Player(i)
        CreateFogModifierRectBJ(true, p, FOG_OF_WAR_VISIBLE, rct.Megaboss1EntireArea)
        CameraSetupApplyForPlayer(true, cam.MegaBossZoomOut, p, 0)
    end

    -- a player hero = a hero not owned by the Princess(8)/enemy(9)/neutrals(11,12)
    local function isArenaHero()
        local f = GetFilterUnit()
        local o = GetOwningPlayer(f)
        return IsUnitType(f, UNIT_TYPE_HERO)
            and o ~= Player(8) and o ~= P9 and o ~= Player(11) and o ~= Player(12)
    end

    -- teleport every player hero into the arena start and freeze them during the intro
    local g = CreateGroup()
    GroupEnumUnitsInRect(g, GetPlayableMapRect(), Condition(isArenaHero))
    ForGroup(g, function()
        local h = GetEnumUnit()
        local loc = GetRandomLocInRect(rct.Megaboss1HeroStart)
        SetUnitPositionLoc(h, loc)
        RemoveLocation(loc)
        PauseUnit(h, true)
    end)
    DestroyGroup(g)

    DisplayTextToForce(GetPlayersAll(), "|cffff0000The Megaboss stirs in its lair...|r")
    TriggerSleepAction(10.0)

    -- spawn the bosses + tentacles
    CreateUnit(P9, O003, GetRectCenterX(rct.Megaboss1Center), GetRectCenterY(rct.Megaboss1Center), bj_UNIT_FACING)
    spawnFleshmakers()
    for _, s in ipairs(TENTACLE_SPAWNS) do
        CreateUnit(P9, TENTACLE, GetRectCenterX(rct[s]), GetRectCenterY(rct[s]), bj_UNIT_FACING)
    end
    TriggerSleepAction(1.0)
    local lvld = pickOf(O003)
    if lvld then SetHeroLevelBJ(lvld, math.max(1, 6 * DifficultyModifier), false) end
    TriggerSleepAction(9.0)

    -- release the heroes, shield the Dark One, announce the mechanic
    DisplayTextToForce(GetPlayersAll(), "|cffff0000Slay the Fleshmakers to expose the Dark One!|r")
    local g2 = CreateGroup()
    GroupEnumUnitsInRect(g2, rct.Megaboss1HeroStart, Condition(isArenaHero))
    ForGroup(g2, function() PauseUnit(GetEnumUnit(), false) end)
    DestroyGroup(g2)
    local intro = pickOf(O003)
    if intro then SetUnitInvulnerable(intro, true) end

    -- ── arm the encounter triggers (all stopped on victory) ──────────────────────
    local boundaryT, checkT, tentT, fleshT, victoryT
    local orbBounceT, sprayDespawnT, orbTickT
    local function stopAll()
        for _, t in ipairs({ boundaryT, checkT, tentT, fleshT,
                             orbBounceT, sprayDespawnT, orbTickT }) do
            if t then DisableTrigger(t) end
        end
    end

    -- Boundary: enemy units leaving the arena die (war3map.j Leave_Fireball_Kill).
    boundaryT = CreateTrigger()
    TriggerRegisterLeaveRectSimple(boundaryT, rct.Megaboss1EntireArea)
    TriggerAddCondition(boundaryT, Condition(function()
        return GetOwningPlayer(GetLeavingUnit()) == P9
    end))
    TriggerAddAction(boundaryT, function() KillUnit(GetLeavingUnit()) end)

    -- Check_Invul (every 1s): all Fleshmakers dead -> expose the Dark One for 20s, kill the
    -- tentacles; if it survives, respawn the Fleshmakers and re-shield (war3map.j 36652-36710).
    checkT = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(checkT, 1.0)
    TriggerAddCondition(checkT, Condition(function()
        return CountLivingPlayerUnitsOfTypeId(O006, P9) == 0 and not MegaBoss1Beaten
    end))
    TriggerAddAction(checkT, function()
        DisableTrigger(checkT)
        local tg = GetUnitsOfPlayerAndTypeId(P9, TENTACLE)
        ForGroup(tg, function() KillUnit(GetEnumUnit()) end)
        DestroyGroup(tg)
        if snd.FacelessOneWhat1 then PlaySoundBJ(snd.FacelessOneWhat1) end
        DisplayTimedTextToForce(GetPlayersAll(), 20.0, "|cff00ff00The Dark One is exposed! Strike now!|r")
        DarkOneWeakened = true
        local b = pickOf(O003); if b then SetUnitInvulnerable(b, false) end
        TriggerSleepAction(20.0)
        b = pickOf(O003); if b then SetUnitInvulnerable(b, true) end
        if not MegaBoss1Beaten then
            DisplayTimedTextToForce(GetPlayersAll(), 4.0, "|cffff0000The Dark One shields itself again!|r")
            spawnFleshmakers()
            EnableTrigger(checkT)
        end
        DarkOneWeakened = false
    end)

    -- Tentacles (every 12s): 15 random tentacle attacks on random arena targets (war3map.j 36849).
    tentT = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(tentT, 12.0)
    TriggerAddAction(tentT, function()
        for _ = 1, 15 do
            local tent, tgt = pickOf(TENTACLE), arenaTarget(false)
            if tent and tgt then IssueTargetOrderBJ(tent, "attack", tgt) end
        end
    end)

    -- Fleshmaker spells (every 3s): random drain / drain / slow / clusterrockets (war3map.j 36930).
    fleshT = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(fleshT, 3.0)
    TriggerAddAction(fleshT, function()
        FleshmakerVar = GetRandomInt(1, 4)
        local caster = pickOf(O006)
        if not caster then return end
        if FleshmakerVar == 1 or FleshmakerVar == 2 then
            local tgt = arenaTarget(false)
            if tgt then IssueTargetOrderBJ(caster, "drain", tgt) end
        elseif FleshmakerVar == 3 then
            local tgt = arenaTarget(false)
            if tgt then IssueTargetOrderBJ(caster, "slow", tgt) end
        else
            local loc = GetRandomLocInRect(rct.Megaboss1EntireArea)
            IssuePointOrderLoc(caster, "clusterrockets", loc)
            RemoveLocation(loc)
        end
    end)

    -- Dark One acid pressure (every 4s): mark a victim and splash acid damage around it.
    -- Simplified — the original's full spiral Acid Spray + Acid_Orb_Movement subsystem is a
    -- deferred refinement (bosses/Bosses.md §4); the boss still threatens during its window.
    pulseT = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(pulseT, 4.0)
    TriggerAddAction(pulseT, function()
        local boss = pickOf(O003)
        local victim = arenaTarget(true)
        if not (boss and victim) then return end
        DisplayTextToForce(GetPlayersAll(),
            "|cffff0000The Dark One sets eyes on |r" .. GetPlayerName(GetOwningPlayer(victim)) .. "!")
        ForUnitsInRange(GetUnitX(victim), GetUnitY(victim), 250.0, function()
            local f = GetFilterUnit()
            return GetOwningPlayer(f) ~= P9 and IsUnitType(f, UNIT_TYPE_HERO)
        end, function()
            UnitDamageTarget(boss, GetEnumUnit(), 75.0, false, false,
                ATTACK_TYPE_NORMAL, DAMAGE_TYPE_ACID, WEAPON_TYPE_WHOKNOWS)
        end)
    end)

    -- Victory: the Dark One dies -> clear the arena, send heroes home, advance to Level 26
    -- (war3map.j Megaboss_1_Victory 36724-36776).
    victoryT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(victoryT, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(victoryT, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == O003 and not IsUnitIllusion(GetDyingUnit())
    end))
    TriggerAddAction(victoryT, function()
        DisableTrigger(victoryT)
        MegaBoss1Beaten = true
        stopAll()
        local function clearArena(matchFn)
            local cg = CreateGroup()
            GroupEnumUnitsInRect(cg, rct.Megaboss1EntireArea, matchFn and Condition(matchFn) or nil)
            ForGroup(cg, function() RemoveUnit(GetEnumUnit()) end)
            DestroyGroup(cg)
        end
        clearArena(function() return GetOwningPlayer(GetFilterUnit()) == P9 end)
        clearArena(function() return IsUnitType(GetFilterUnit(), UNIT_TYPE_STRUCTURE) end)
        TriggerSleepAction(1.0)
        StopAllMusic()
        ToughBossMusic = false
        TriggerSleepAction(5.0)
        PlaySoundBJ(snd.RoundClear)
        DisplayTimedTextToForce(GetPlayersAll(), 10.0, "|cff32cd32The Megaboss falls! The path is clear.|r")
        TriggerSleepAction(5.0)
        -- teleport survivors back to town
        local hg = CreateGroup()
        GroupEnumUnitsInRect(hg, rct.Megaboss1EntireArea, Condition(function()
            return GetOwningPlayer(GetFilterUnit()) ~= P9
        end))
        ForGroup(hg, function()
            local loc = GetRectCenter(rct.StartingPlayerArea)
            SetUnitPositionLoc(GetEnumUnit(), loc)
            RemoveLocation(loc)
        end)
        DestroyGroup(hg)
        BonusesAndUpkeep(nil)
        TriggerSleepAction(10.0)
        BonusReset()
        StartLevel(26)
    end)
end
