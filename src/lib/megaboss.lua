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

    DisplayTextToForce(GetPlayersAll(),
        "Chapter Finale - Dark One |cffff0000MEGABOSS #1!!!|r  Enemies: Dark One, Fleshmakers, Tentacles  "
        .. "|cff32cd32Victory|r - Defeat the Dark One!  |cffff0000Defeat|r - Death of all players.")
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

    -- release the heroes, shield the Dark One (war3map.j 36608-36611)
    DisplayTextToForce(GetPlayersAll(), "|cffff0000Megaboss 1 - Begin!|r")
    local g2 = CreateGroup()
    GroupEnumUnitsInRect(g2, rct.Megaboss1HeroStart, Condition(isArenaHero))
    ForGroup(g2, function() PauseUnit(GetEnumUnit(), false) end)
    DestroyGroup(g2)
    local intro = pickOf(O003)
    if intro then SetUnitInvulnerable(intro, true) end

    -- ── arm the encounter triggers (all stopped on victory) ──────────────────────
    local boundaryT, checkT, tentT, fleshT, victoryT
    local orbBounceT, sprayDespawnT, orbTickT, spellTagT
    local function stopAll()
        for _, t in ipairs({ boundaryT, checkT, tentT, fleshT,
                             orbBounceT, sprayDespawnT, orbTickT, spellTagT }) do
            if t then DisableTrigger(t) end
        end
    end

    -- Spell_Display (war3map.j 36966-36984): float the spell's name above a casting
    -- Fleshmaker so players can react to drains/slows.
    spellTagT = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(spellTagT, P9, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddCondition(spellTagT, Condition(function()
        return GetUnitTypeId(GetSpellAbilityUnit()) == O006
    end))
    TriggerAddAction(spellTagT, function()
        FloatText(GetSpellAbilityUnit(), GetAbilityName(GetSpellAbilityId()), 100, 0, 0, 4.0)
    end)

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
        DisplayTimedTextToForce(GetPlayersAll(), 20.0, "|cffff0000The Dark One is Vulnerable!|r")
        DarkOneWeakened = true
        local b = pickOf(O003); if b then SetUnitInvulnerable(b, false) end
        TriggerSleepAction(20.0)
        b = pickOf(O003); if b then SetUnitInvulnerable(b, true) end
        if not MegaBoss1Beaten then
            DisplayTimedTextToForce(GetPlayersAll(), 4.0, "|cffff0000The Dark One rallies!|r")
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

    -- ── The Dark One's Acid kit (war3map.j 37147-37391 + Dark_One_Spells 37001-37137) ──
    -- Two support unit types do the contact damage via their object data: e00T "acid orb"
    -- (roams the arena, bouncing off the borders) and e00U "acid spray" (flies outward,
    -- despawning at the borders).

    -- Acid_Orb_Movement: an orb entering a border rect turns +120° and moves on (the bounce).
    orbBounceT = CreateTrigger()
    for _, b in ipairs({ 'MegabossNorthBorder', 'MegabossSouthBorder',
                         'MegabossWestBorder',  'MegabossEastBorder' }) do
        TriggerRegisterEnterRectSimple(orbBounceT, rct[b])
    end
    TriggerAddCondition(orbBounceT, Condition(function()
        return GetUnitTypeId(GetEnteringUnit()) == ACID_ORB
    end))
    TriggerAddAction(orbBounceT, function()
        local orb = GetEnteringUnit()
        SetUnitFacingTimed(orb, GetUnitFacing(orb) + 120.0, 1.0)
        TriggerSleepAction(1.0)
        if GetUnitTypeId(orb) ~= 0 then moveForward(orb, 600.0) end
    end)

    -- Remove_Acid: spray missiles despawn at the borders.
    sprayDespawnT = CreateTrigger()
    for _, b in ipairs({ 'MegabossNorthBorder', 'MegabossSouthBorder',
                         'MegabossWestBorder',  'MegabossEastBorder' }) do
        TriggerRegisterEnterRectSimple(sprayDespawnT, rct[b])
    end
    TriggerAddCondition(sprayDespawnT, Condition(function()
        return GetUnitTypeId(GetEnteringUnit()) == ACID_SPRAY
    end))
    TriggerAddAction(sprayDespawnT, function() RemoveUnit(GetEnteringUnit()) end)

    -- Acid_Orb_Movement2 (every 2s): every orb keeps roaming 900 along its facing.
    orbTickT = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(orbTickT, 2.0)
    TriggerAddAction(orbTickT, function()
        local og = GetUnitsOfPlayerAndTypeId(P9, ACID_ORB)
        ForGroup(og, function() moveForward(GetEnumUnit(), 900.0) end)
        DestroyGroup(og)
    end)

    -- Acid_Surge: 7 flamestrike casts at the victim's (fresh) position, 1.5s apart; the
    -- cast ability A09D is granted for each cast and removed afterwards (war3map.j 37291).
    local function acidSurge(victim)
        for _ = 1, 7 do
            if MegaBoss1Beaten then break end
            local b = pickOf(O003)
            if not b then break end
            UnitAddAbility(b, FLAMESTRIKE)
            if victim and GetUnitTypeId(victim) ~= 0 then
                IssuePointOrder(b, "flamestrike", GetUnitX(victim), GetUnitY(victim))
            end
            TriggerSleepAction(1.5)
        end
        local b = pickOf(O003)
        if b then UnitRemoveAbility(b, FLAMESTRIKE) end
    end

    -- A random arena hero with ≥10 HP — the Surge victim filter (war3map.j 37027-37045).
    local function surgeVictim()
        local g = CreateGroup()
        GroupEnumUnitsInRect(g, rct.Megaboss1EntireArea, Condition(function()
            local f = GetFilterUnit()
            return IsUnitType(f, UNIT_TYPE_HERO) and GetOwningPlayer(f) ~= P9
                and GetUnitState(f, UNIT_STATE_LIFE) >= 10.0
        end))
        local u = GroupPickRandomUnit(g)
        DestroyGroup(g)
        return u
    end

    -- Dark_One_Spells: the self-repeating, HP-gated escalation loop. Each pass (skipping
    -- steps while the boss is exposed/dead): always spawn a Greater Acid Orb → ≤80 percent
    -- HP: Acid Spray (30-step spiral of e00U missiles) → ≤60 percent: Acid Surge → ≤40
    -- percent: a second Surge. Step gaps 5/17/15/4s, then repeat (war3map.j 37093-37137).
    local function rotationStep(threshold)
        if DarkOneWeakened or MegaBoss1Beaten then return nil end
        local b = pickOf(O003)
        if not b then return nil end
        local mx = GetUnitState(b, UNIT_STATE_MAX_LIFE)
        if mx <= 0.0 or GetUnitState(b, UNIT_STATE_LIFE) / mx * 100.0 > threshold then
            return nil
        end
        return b
    end
    local rotationT = CreateTrigger()
    TriggerAddAction(rotationT, function()
        while not MegaBoss1Beaten do
            local b = rotationStep(100.0)
            if b then   -- Greater Acid Orb: spawn a roamer at a random arena point
                bossTag(b, "Greater Acid Orb")
                local x = GetRandomReal(GetRectMinX(rct.Megaboss1EntireArea), GetRectMaxX(rct.Megaboss1EntireArea))
                local y = GetRandomReal(GetRectMinY(rct.Megaboss1EntireArea), GetRectMaxY(rct.Megaboss1EntireArea))
                local orb = CreateUnit(P9, ACID_ORB, x, y, GetRandomReal(0.0, 360.0))
                moveForward(orb, 600.0)
            end
            TriggerSleepAction(5.0)

            b = rotationStep(80.0)
            if b then   -- Acid Spray: 30-step rotating spiral of outward missiles
                bossTag(b, "Acid Spray")
                for _ = 1, 30 do
                    if MegaBoss1Beaten or GetUnitTypeId(b) == 0 then break end
                    SetUnitFacingTimed(b, GetUnitFacing(b) + 10.0, 0)
                    local a = math.rad(GetUnitFacing(b))
                    local s = CreateUnit(P9, ACID_SPRAY,
                        GetUnitX(b) + 225.0 * math.cos(a),
                        GetUnitY(b) + 225.0 * math.sin(a), GetUnitFacing(b))
                    moveForward(s, 1500.0)
                    TriggerSleepAction(0.5)
                end
            end
            TriggerSleepAction(17.0)

            b = rotationStep(60.0)
            if b then   -- Acid Surge on a marked hero
                bossTag(b, "Acid Surge")
                local victim = surgeVictim()
                if victim then
                    DisplayTextToForce(GetPlayersAll(),
                        "|cffff0000The Dark One sets eyes on |r"
                        .. GetPlayerName(GetOwningPlayer(victim)) .. "!")
                    acidSurge(victim)
                end
            end
            TriggerSleepAction(15.0)

            b = rotationStep(40.0)
            if b then   -- second Surge at low HP
                bossTag(b, "Acid Surge")
                local victim = surgeVictim()
                if victim then
                    DisplayTextToForce(GetPlayersAll(),
                        "|cffff0000The Dark One sets eyes on |r"
                        .. GetPlayerName(GetOwningPlayer(victim)) .. "!")
                    acidSurge(victim)
                end
            end
            TriggerSleepAction(4.0)
        end
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
        DisplayTimedTextToForce(GetPlayersAll(), 10.0,
            "|cffff0000Chapter 1 - Birth of Conflict|r - |cff7777aaComplete!|r")
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

    -- The Dark One's spell rotation begins 30s after the fight opens (war3map.j 36616-36617).
    TriggerSleepAction(30.0)
    if not MegaBoss1Beaten then TriggerExecute(rotationT) end
end
