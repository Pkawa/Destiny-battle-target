-- Adomach — the optional final boss, reached via the **-adomach** command after Level 31
-- unlocks it (`AdomachUnlocked`). A blink-caster in the star-shaped arena: it teleports between
-- 5 star points and cycles 3 signature spells (Paralyze Ray / Explosion / Pain Nova) + periodic
-- summons, with a one-time N015 add at 40 percent HP.
-- Requirements: bosses/Bosses.md §2. Source: war3map.j 35705-36461.
--
-- Crash-safety: the original leaves the spell rotation recursing forever (it never guards on
-- Adomach being alive). Here every step bails when Adomach is dead and a death handler stops the
-- encounter cleanly — the original has no formal Adomach-death victory trigger; it just dies and
-- drops its carried item I06S.

local P9 = Player(9)
local ADOMACH = FourCC('H02H')
local RAY, EXPLODE_SEED, NOVA = FourCC('e016'), FourCC('e017'), FourCC('e00J')
local BLINK_ABIL = FourCC('A0C6')
local UDEATH = "Objects\\Spawnmodels\\Undead\\UDeathMedium\\UDeath.mdl"

local STARS = { 'NorthStar', 'NWStar', 'NEStar', 'SWStar', 'SEStar' }
-- AdomachSummon roll 1-10 → add type (war3map.j 36378-36428).
local SUMMONS = {
    FourCC('h06P'), FourCC('h01R'), FourCC('h01E'), FourCC('h04R'), FourCC('h01G'),
    FourCC('h01F'), FourCC('h02Q'), FourCC('h06Q'), FourCC('h01S'), FourCC('h01Q'),
}

local started = false   -- once-guard
local active  = false   -- gates the spell rotation; cleared on Adomach death

local function adomachAlive()
    return AdomachHimself and GetUnitTypeId(AdomachHimself) ~= 0
        and GetUnitState(AdomachHimself, UNIT_STATE_LIFE) > 0.405
end
local function ax() return GetUnitX(AdomachHimself) end
local function ay() return GetUnitY(AdomachHimself) end
local function bossTag(text) if AdomachHimself then FloatText(AdomachHimself, text, 100, 0, 0, 4.0) end end

-- A random non-Player-9 unit in the arena (the heroes; the spell targets).
local function arenaTarget()
    local g = CreateGroup()
    GroupEnumUnitsInRect(g, rct.AdomachEntireArea, Condition(function()
        return GetOwningPlayer(GetFilterUnit()) ~= P9
    end))
    local u = GroupPickRandomUnit(g)
    DestroyGroup(g)
    return u
end

-- Aim Adomach at a random hero (used by Paralyze Ray).
local function faceRandomHero()
    local h = arenaTarget()
    if h then
        SetUnitFacingTimed(AdomachHimself, math.deg(math.atan(GetUnitY(h) - ay(), GetUnitX(h) - ax())), 0)
    end
end

-- ── The three signature spells (war3map.j 36036-36296) ─────────────────────────

-- Paralyze Ray: hold, aim at heroes, spit ~15 e016 ray missiles 0.25s apart. The rays patrol
-- forward (armed below) and paralyze on contact. (The original notes the rays were finicky.)
local function paralyzeRay()
    bossTag("Paralyze Ray")
    IssueImmediateOrder(AdomachHimself, "holdposition")
    faceRandomHero()
    for i = 1, 15 do
        if not (active and adomachAlive()) then return end
        if i == 3 or i == 4 or i == 8 then faceRandomHero() end
        local a = math.rad(GetUnitFacing(AdomachHimself))
        CreateUnit(P9, RAY, ax() + 10.0 * math.cos(a), ay() + 10.0 * math.sin(a), GetUnitFacing(AdomachHimself))
        TriggerSleepAction(0.25)
    end
end

-- Explosion: a seed (e017) crawls to the arena centre, then detonates in three nested rings
-- (radius 500/350/150 → 250/500/1000 damage) with a burst of effects (war3map.j 36176-36230).
local function explosion()
    bossTag("Explosion")
    IssueImmediateOrder(AdomachHimself, "holdposition")
    local cx, cy = GetRectCenterX(rct.AdomachCenter), GetRectCenterY(rct.AdomachCenter)
    local seed = CreateUnit(P9, EXPLODE_SEED, ax(), ay(), 0)
    IssuePointOrder(seed, "move", cx, cy)
    TriggerSleepAction(2.5)
    if snd.FlakCannon then PlaySoundBJ(snd.FlakCannon) end
    local sx, sy = GetUnitX(seed), GetUnitY(seed)
    local fx = {
        AddSpecialEffect("Objects\\Spawnmodels\\Other\\NeutralBuildingExplosion\\NeutralBuildingExplosion.mdl", sx, sy),
        AddSpecialEffect("Abilities\\Spells\\Human\\MarkOfChaos\\MarkOfChaosTarget.mdl", sx, sy),
        AddSpecialEffect("Abilities\\Spells\\Other\\Doom\\DoomDeath.mdl", sx, sy),
    }
    UnitDamagePoint(seed, 0, 500.0, sx, sy, 250.0,  false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
    UnitDamagePoint(seed, 0, 350.0, sx, sy, 500.0,  false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
    UnitDamagePoint(seed, 0, 150.0, sx, sy, 1000.0, false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
    RemoveUnit(seed)
    for _, e in ipairs(fx) do DestroyEffect(e) end
end

-- Pain Nova: a ring of 24 e00J nova units (every 15°) flung outward in three 1000-unit pulses,
-- then removed (war3map.j 36242-36295). The nova units do the contact damage via object data.
local function painNova()
    bossTag("Pain Nova")
    IssueImmediateOrder(AdomachHimself, "holdposition")
    local function pushOut()
        local g = GetUnitsOfPlayerAndTypeId(P9, NOVA)
        ForGroup(g, function()
            local u = GetEnumUnit()
            local a = math.rad(GetUnitFacing(u))
            IssuePointOrder(u, "move", GetUnitX(u) + 1000.0 * math.cos(a), GetUnitY(u) + 1000.0 * math.sin(a))
        end)
        DestroyGroup(g)
    end
    local deg = 0.0
    while deg < 360.0 do
        local a = math.rad(deg)
        CreateUnit(P9, NOVA, ax() + 30.0 * math.cos(a), ay() + 30.0 * math.sin(a), deg)
        deg = deg + 15.0
    end
    pushOut(); TriggerSleepAction(3.0)
    pushOut(); TriggerSleepAction(3.0)
    pushOut(); TriggerSleepAction(3.0)
    local g = GetUnitsOfPlayerAndTypeId(P9, NOVA)
    ForGroup(g, function() RemoveUnit(GetEnumUnit()) end)
    DestroyGroup(g)
end

-- Adomach Summon: drop one random add at the summon pit with an undead-death poof.
local function summon()
    local roll = GetRandomInt(1, 10)
    local loc = GetRandomLocInRect(rct.AdoSumArea)
    local u = CreateUnit(P9, SUMMONS[roll], GetLocationX(loc), GetLocationY(loc), bj_UNIT_FACING)
    DestroyEffect(AddSpecialEffect(UDEATH, GetUnitX(u), GetUnitY(u)))
    RemoveLocation(loc)
end

-- Adomach Blink: teleport to a random star (never the current one) (war3map.j 35995-36006).
local function blink()
    if not AdomachOkToBlink then return end
    local target = GetRandomInt(1, 5)
    if target == AdomachCurrentLocation then return end   -- skip a blink rather than re-roll forever
    local loc = GetRectCenter(rct[STARS[target]])
    IssuePointOrderLoc(AdomachHimself, "blink", loc)
    RemoveLocation(loc)
    TriggerSleepAction(0.5)
    AdomachCurrentLocation = target
end

-- ── Entry point ────────────────────────────────────────────────────────────────

function StartAdomach()
    if started then return end
    started = true
    active = true
    AdomachCurrentLocation = 0
    FinalBossMusicOn = true
    IntroMusicOn = false
    MusicOn = false
    if trg_Lv1ItemDrop then DisableTrigger(trg_Lv1ItemDrop) end   -- suspend kill-drops (Enable_adomach)
    StartToughBossMusic()   -- ChapterBoss track (music.lua); the original's OptionalBossMusic3D

    -- revive the team, reveal the arena, pull everyone in
    for i = 1, 8 do
        if Heroes[i] then
            local loc = GetRectCenter(rct.StartingPlayerArea)
            ReviveHeroLoc(Heroes[i], loc, true)
            RemoveLocation(loc)
        end
    end
    for i = 0, 7 do
        local p = Player(i)
        CreateFogModifierRectBJ(true, p, FOG_OF_WAR_VISIBLE, rct.AdomachEntireArea)
        local c = GetRectCenter(rct.AdomachCenter)
        PanCameraToTimedLocForPlayer(p, c, 0)
        RemoveLocation(c)
    end

    local function isArenaHero()
        local f = GetFilterUnit()
        local o = GetOwningPlayer(f)
        return IsUnitType(f, UNIT_TYPE_HERO)
            and o ~= Player(8) and o ~= P9 and o ~= Player(11)
    end
    local g = CreateGroup()
    GroupEnumUnitsInRect(g, GetPlayableMapRect(), Condition(isArenaHero))
    ForGroup(g, function()
        local h = GetEnumUnit()
        local loc = GetRandomLocInRect(rct.AdomachCenter)
        SetUnitPositionLoc(h, loc)
        RemoveLocation(loc)
        SetUnitFacingTimed(h, 90.0, 0)
    end)
    DestroyGroup(g)

    -- spawn Adomach, freeze the arena during the intro, hand it its boss item
    AdomachHimself = CreateUnit(P9, ADOMACH,
        GetRectCenterX(rct.AdomachStartArea), GetRectCenterY(rct.AdomachStartArea), 270.0)
    local pg = CreateGroup()
    GroupEnumUnitsInRect(pg, rct.AdomachEntireArea, nil)
    ForGroup(pg, function() PauseUnit(GetEnumUnit(), true) end)
    DestroyGroup(pg)
    TriggerSleepAction(1.0)
    UnitAddItemById(AdomachHimself, FourCC('I06S'))

    -- pre-fight taunt (war3map.j 35694-35700)
    local function taunt(msg, dur)
        TransmissionFromUnitWithNameBJ(GetPlayersAll(), AdomachHimself, "Adomach", nil,
            msg, bj_TIMETYPE_ADD, dur, true)
    end
    taunt("And so the would-be heroes appear before me. You've been quite the annoyance, you see.", 3.0)
    TriggerSleepAction(6.0)
    taunt("Brave words. I expected to less from the so-called \"saviours\". But your error lies in "
        .. "confronting me. You may have bested the pathetic vermin that threw themselves at you "
        .. "like fools, but to presume you could even defeat me...", 9.0)
    TriggerSleepAction(10.0)
    taunt("Why that is quite a grave error indeed...", 4.0)
    TriggerSleepAction(8.0)

    -- release the heroes and open the fight
    DisplayTextToForce(GetPlayersAll(),
        "|cff8a2be2Final Battle - Adomach|r  Enemies: Adomach, Lord of Despair  "
        .. "|cff32cd32Victory|r - Defeat of Adomach  |cffff0000Defeat|r - Death of all players "
        .. "|cffff0000OR|r Death of Princess Silmeria")
    DisplayTextToForce(GetPlayersAll(), "|cffff0000Final Battle - Begin!|r")
    local hg = CreateGroup()
    GroupEnumUnitsInRect(hg, rct.AdomachEntireArea, Condition(function()
        return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO)
            and GetOwningPlayer(GetFilterUnit()) ~= Player(8)
    end))
    ForGroup(hg, function() PauseUnit(GetEnumUnit(), false) end)
    DestroyGroup(hg)

    -- ── persistent arena triggers ────────────────────────────────────────────────

    -- Adomach_Tele_Facing: after a blink cast, snap to face the arena centre.
    local faceT = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(faceT, P9, EVENT_PLAYER_UNIT_SPELL_CAST)
    TriggerAddCondition(faceT, Condition(function()
        return GetSpellAbilityId() == BLINK_ABIL and GetSpellAbilityUnit() == AdomachHimself
    end))
    TriggerAddAction(faceT, function()
        TriggerSleepAction(0.5)
        if adomachAlive() then
            local c = GetRectCenter(rct.AdomachCenter)
            SetUnitFacingToFaceLocTimed(AdomachHimself, c, 0)
            RemoveLocation(c)
        end
    end)

    -- Paralyze_Ray_Move: a ray entering the arena patrols far forward.
    local rayMoveT = CreateTrigger()
    TriggerRegisterEnterRectSimple(rayMoveT, rct.AdomachEntireArea)
    TriggerAddCondition(rayMoveT, Condition(function()
        return GetUnitTypeId(GetEnteringUnit()) == RAY
    end))
    TriggerAddAction(rayMoveT, function()
        local r = GetEnteringUnit()
        local a = math.rad(GetUnitFacing(r))
        IssuePointOrder(r, "patrol", GetUnitX(r) + 4000.0 * math.cos(a), GetUnitY(r) + 4000.0 * math.sin(a))
    end)

    -- Para_Ray_Attacks: a ray hitting a fresh hero paralyzes it 8s (pause + freeze + purge FX),
    -- then frees it; hitting an already-paralyzed hero just consumes the ray (war3map.j 36115-36170).
    local rayHitT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(rayHitT, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(rayHitT, Condition(function()
        return GetUnitTypeId(GetAttacker()) == RAY
    end))
    TriggerAddAction(rayHitT, function()
        local victim, ray = GetAttackedUnitBJ(), GetAttacker()
        if IsUnitInGroup(victim, AdomachParalyzeRayGroup) then
            RemoveUnit(ray)
            return
        end
        RemoveUnit(ray)
        GroupAddUnit(AdomachParalyzeRayGroup, victim)
        PauseUnit(victim, true)
        SetUnitTimeScale(victim, 0.0)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Orc\\Purge\\PurgeBuffTarget.mdl", victim, "origin"))
        TriggerSleepAction(8.0)
        if GetUnitTypeId(victim) ~= 0 then
            PauseUnit(victim, false)
            SetUnitTimeScale(victim, 1.0)
        end
        GroupRemoveUnit(AdomachParalyzeRayGroup, victim)
    end)

    -- SE_Destroy: nova/ray units hitting the arena ceiling are removed.
    local ceilingT = CreateTrigger()
    for _, c in ipairs({ 'AdoCeilingDown', 'AdoCeilingLeft', 'AdoCeilingRight', 'AdoCeilingTop' }) do
        TriggerRegisterEnterRectSimple(ceilingT, rct[c])
    end
    TriggerAddCondition(ceilingT, Condition(function()
        local id = GetUnitTypeId(GetEnteringUnit())
        return id == NOVA or id == RAY
    end))
    TriggerAddAction(ceilingT, function() RemoveUnit(GetEnteringUnit()) end)

    -- Adom_sum_pit: a one-time N015 add when Adomach drops below 40 percent HP.
    local pitT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(pitT, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(pitT, Condition(function()
        local u = GetAttackedUnitBJ()
        if GetUnitTypeId(u) ~= ADOMACH then return false end
        local mx = GetUnitState(u, UNIT_STATE_MAX_LIFE)
        return mx > 0.0 and GetUnitState(u, UNIT_STATE_LIFE) / mx * 100.0 <= 40.0
    end))
    TriggerAddAction(pitT, function()
        DisableTrigger(pitT)
        local loc = GetRectCenter(rct.AdoSumArea)
        CreateUnit(P9, FourCC('N015'), GetLocationX(loc), GetLocationY(loc), bj_UNIT_FACING)
        RemoveLocation(loc)
    end)

    -- Victory / cleanup (crash-safe completion the original lacks): when Adomach dies, stop the
    -- rotation + music, clear the arena adds, restore kill-drops, mark DarkOneBeaten.
    local deathT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(deathT, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(deathT, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == ADOMACH and not IsUnitIllusion(GetDyingUnit())
    end))
    TriggerAddAction(deathT, function()
        active = false
        DarkOneBeaten = true
        FinalBossMusicOn = false
        ToughBossMusic = false
        DisableTrigger(faceT); DisableTrigger(rayMoveT); DisableTrigger(rayHitT)
        DisableTrigger(ceilingT)
        StopAllMusic()
        PlaySoundBJ(snd.RoundClear)
        DisplayTimedTextToForce(GetPlayersAll(), 15.0,
            "|cff32cd32Adomach, Lord of Despair, has been vanquished!|r")
        if trg_Lv1ItemDrop then EnableTrigger(trg_Lv1ItemDrop) end
        local cg = CreateGroup()
        GroupEnumUnitsInRect(cg, rct.AdomachEntireArea, Condition(function()
            return GetOwningPlayer(GetFilterUnit()) == P9
        end))
        ForGroup(cg, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(cg)
    end)

    -- ── spell rotation (war3map.j Adomach_Spells 35962-35969): blink → a random signature
    -- spell → 10s gap → a summon, repeating while Adomach lives. Starts 30s in.
    local rotationT = CreateTrigger()
    TriggerAddAction(rotationT, function()
        while active and adomachAlive() do
            blink()
            local s = GetRandomInt(1, 3)
            TriggerSleepAction(1.0)
            if not (active and adomachAlive()) then break end
            if     s == 1 then paralyzeRay()
            elseif s == 2 then explosion()
            else               painNova() end
            TriggerSleepAction(10.0)
            if active and adomachAlive() then summon() end
        end
    end)
    TriggerExecute(rotationT)
end

-- "-adomach": launch the final boss once Level 31 has unlocked it (war3map.j Enable_adomach).
-- A real player command (not debug-gated), for the 8 human slots + the Player(10) observer.
function RegisterAdomachTrigger()
    local t = CreateTrigger()
    for _, i in ipairs({ 0, 1, 2, 3, 4, 5, 6, 7, 10 }) do
        TriggerRegisterPlayerChatEvent(t, Player(i), "-adomach", true)
    end
    TriggerAddAction(t, function()
        if AdomachUnlocked and not started then
            StartAdomach()
        elseif not AdomachUnlocked then
            DisplayTimedTextToForce(GetForceOfPlayer(GetTriggerPlayer()), 6.0,
                "|cffaaaaaaAdomach is sealed until the campaign is won (defeat Level 31).|r")
        end
    end)
end
