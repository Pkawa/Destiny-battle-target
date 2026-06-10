-- Per-hero class abilities (Phase 7). Requirements: combat/Abilities.md.
-- Grown hero by hero; RegisterAbilityTriggers() wires each hero's setup. Started with the
-- "quirky" classes: the Earthen Templar (proc-summon + earthquake ult) and the Human Engineer
-- (a builder whose tech ranks unlock structures + raise a building cap).

local P9 = Player(9)
local P8 = Player(8)

-- ══ Earthen Templar (H00S) — war3map.j 41081-41738 ══════════════════════════════
-- Earthen Presence (learn A01X): each rank, when the templar is attacked, a chance to summon a
-- scaling earth elemental (capped at 8 except the top rank). Seismic Collapse (cast A020): a
-- map-wide earthquake — debris (u002) rains everywhere, each chunk dealing 500 to nearby enemies.

local EARTHEN_TEMPLAR = FourCC('H00S')
local DEBRIS = FourCC('u002')
local EP = {  -- [rank] = { elemental, proc chance (out of 50), cooldown, cap (nil = uncapped) }
    [1] = { elem = FourCC('h011'), chance = 2, cd = 15.0, cap = 8 },
    [2] = { elem = FourCC('h03P'), chance = 3, cd = 13.0, cap = 8 },
    [3] = { elem = FourCC('h03Q'), chance = 4, cd = 11.0, cap = 8 },
    [4] = { elem = FourCC('h03R'), chance = 5, cd = 10.0, cap = 8 },
    [5] = { elem = FourCC('h03R'), chance = 5, cd = 6.0,  cap = nil },
}
local earthenOnCooldown = false

local function setupEarthenTemplar()
    -- Earthen Presence Learn (A01X) → bump the rank. (The original juggles 5 per-rank triggers;
    -- one proc trigger reading EarthenPresence + a cooldown flag is equivalent.)
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A01X')
    end, function()
        EarthenPresence = EarthenPresence + 1
    end)

    -- Earthen Presence proc: on the templar being attacked, maybe summon the rank's elemental.
    OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == EARTHEN_TEMPLAR
            and EarthenPresence >= 1 and not earthenOnCooldown
    end, function()
        local d = EP[EarthenPresence]
        if not d then return end
        local templar = GetAttackedUnitBJ()
        local owner = GetOwningPlayer(templar)
        if d.cap and CountLivingPlayerUnitsOfTypeId(d.elem, owner) >= d.cap then return end
        EarthenChance = GetRandomInt(1, 50)
        if EarthenChance > d.chance then return end
        earthenOnCooldown = true
        CreateUnit(owner, d.elem, GetUnitX(templar), GetUnitY(templar), bj_UNIT_FACING)
        if trg_EarthenTemplarRageOfEarth then ConditionalTriggerExecute(trg_EarthenTemplarRageOfEarth) end
        After(d.cd, function() earthenOnCooldown = false end)
    end)

    -- Seismic Collapse (cast A020): screen shake + a map-wide barrage of debris.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_FINISH, function()
        return GetSpellAbilityId() == FourCC('A020')
    end, function()
        local caster = GetSpellAbilityUnit()
        ForForce(GetPlayersAll(), function() CameraSetEQNoiseForPlayer(GetEnumPlayer(), 5.0) end)
        if snd.BuildingDeathLargeHuman then PlaySoundBJ(snd.BuildingDeathLargeHuman) end
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(GetOwningPlayer(caster)) .. " casts |cff995500Seismic Collapse|r!")
        TriggerSleepAction(1.0)
        -- ~70 debris chunks across the whole map over ~6s (the original spawns them in waves).
        for _ = 1, 10 do
            for _ = 1, 7 do
                local loc = GetRandomLocInRect(rct.EntireGameArea)
                CreateUnit(P8, DEBRIS, GetLocationX(loc), GetLocationY(loc), bj_UNIT_FACING)
                RemoveLocation(loc)
            end
            if snd.BuildingDeathLargeOrc then PlaySoundBJ(snd.BuildingDeathLargeOrc) end
            TriggerSleepAction(0.4)
        end
        ForForce(GetPlayersAll(), function() CameraClearNoiseForPlayer(GetEnumPlayer()) end)
        TriggerSleepAction(3.0)
        local g = GetUnitsOfPlayerAndTypeId(P8, DEBRIS)   -- sweep up any debris still standing
        ForGroup(g, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(g)
    end)

    -- Seismic debris (u002): 1.5s after landing, deal 500 flat to nearby enemies, then crumble
    -- (war3map.j Seismic_Collapse_Despawn_Dam 41710-41730). Enter-event fires when each is spawned.
    OnEnterRect(GetPlayableMapRect(), function()
        return GetUnitTypeId(GetEnteringUnit()) == DEBRIS
    end, function()
        local chunk = GetEnteringUnit()
        TriggerSleepAction(1.5)
        if GetUnitTypeId(chunk) == 0 then return end
        ForUnitsInRange(GetUnitX(chunk), GetUnitY(chunk), 400.0, function()
            return GetOwningPlayer(GetFilterUnit()) == P9
        end, function()
            local e = GetEnumUnit()
            SetUnitLifeBJ(e, GetUnitState(e, UNIT_STATE_LIFE) - 500.0)   -- flat (armour-ignoring) hit
        end)
        TriggerSleepAction(0.1)
        KillUnit(chunk)
    end)
end

-- ══ Human Engineer (H00F) — war3map.j 44472-44792 ═══════════════════════════════
-- A builder: Construction/Schematics/Marvel skills unlock buildable structures (mark tech
-- researched) and raise a building cap; Limited Buildings enforces the cap; Build Wonder
-- (ult A01B) erects the Wonder of the World. See progression/Training.md §5.

local function setResearched(player, codes)
    for _, code in ipairs(codes) do SetPlayerTechResearchedSwap(FourCC(code), 1, player) end
end

local function setupEngineer()
    -- Construction (A01E): per rank, unlock a pair of structure techs (+ enable Gold Fabricators).
    local CONSTRUCTION = {
        { 'R01L', 'R005' }, { 'R008', 'R01R' }, { 'R01V', 'R020' },
        { 'R022', 'R026' }, { 'R02A', 'R02H' },
    }
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A01E')
    end, function()
        EngineerPlayer = GetOwningPlayer(GetLearningUnit())
        ConstructionResearch = ConstructionResearch + 1
        -- (Gold Fabricators economy trigger is ⬜ — its enable is skipped until that lands.)
        local batch = CONSTRUCTION[ConstructionResearch]
        if batch then setResearched(EngineerPlayer, batch) end
        BlzUnitHideAbility(GetLearningUnit(), FourCC('A01E'), true)
    end)

    -- Schematics (A01D): per rank, raise the engineer's building cap.
    local SCHEMATICS_CAP = { 7, 10, 14, 18, 22 }
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A01D')
    end, function()
        SchematicsResearch = SchematicsResearch + 1
        EngineerMaxBuildings = SCHEMATICS_CAP[SchematicsResearch] or EngineerMaxBuildings
        BlzUnitHideAbility(GetLearningUnit(), FourCC('A01D'), true)
    end)

    -- Marvel of Engineering (A00Z): per rank, unlock a large batch of high-tier techs.
    local MARVEL = {
        { 'R002', 'R006', 'R01N', 'R009', 'R01S', 'R01X', 'R01Z', 'R025', 'R027', 'R02B', 'R02F' },
        { 'R003', 'R007', 'R01M', 'R00A', 'R01Q', 'R01U', 'R01Y', 'R023', 'R028', 'R02C', 'R02E' },
        { 'R004', 'R000', 'R01O', 'R01P', 'R01T', 'R01W', 'R021', 'R024', 'R029', 'R02D', 'R02G' },
    }
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A00Z')
    end, function()
        MarvelResearch = MarvelResearch + 1
        local batch = MARVEL[MarvelResearch]
        if batch then setResearched(GetOwningPlayer(GetLearningUnit()), batch) end
        BlzUnitHideAbility(GetLearningUnit(), FourCC('A00Z'), true)
    end)

    -- Limited Buildings: an Engineer-owning player who exceeds the cap loses the new structure.
    OnAnyUnit(EVENT_PLAYER_UNIT_CONSTRUCT_START, function()
        local p = GetOwningPlayer(GetConstructingStructure())
        local eng = GetUnitsOfPlayerAndTypeId(p, FourCC('H00F'))
        local isEng = CountUnitsInGroup(eng) >= 1
        DestroyGroup(eng)
        if not isEng then return false end
        local g = GetUnitsOfPlayerMatching(p, Condition(function()
            return IsUnitType(GetFilterUnit(), UNIT_TYPE_STRUCTURE) and IsUnitAliveBJ(GetFilterUnit())
        end))
        local n = CountUnitsInGroup(g)
        DestroyGroup(g)
        return n > EngineerMaxBuildings
    end, function()
        local s = GetConstructingStructure()
        KillUnit(s)
        DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(s)),
            "You have too many buildings.  Gain more ranks of the Schematics skill to build more "
            .. "structures.  Your current max is: " .. tostring(EngineerMaxBuildings - 2))
    end)

    -- Build Wonder (ult A01B): erect the Wonder of the World + its guardian.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A01B')
    end, function()
        local wx, wy = GetRectCenterX(rct.WonderOfTheWorld), GetRectCenterY(rct.WonderOfTheWorld)
        CreateUnit(P8, FourCC('h06S'), wx, wy, bj_UNIT_FACING)
        CreateUnit(P8, FourCC('h01K'),
            GetRectCenterX(rct.FrontOfSilmeria), GetRectCenterY(rct.FrontOfSilmeria), 110.0)
        DisplayTimedTextToForce(GetPlayersAll(), 30.0,
            "The Wonder of the World has been built! the princess has gained a new ally. "
            .. "all allies gain wonderous aura")
        PingMinimap(wx, wy, 5.0)
    end)
end

-- ══ Arcane Archer (H01O) — war3map.j 37439-37462 ════════════════════════════════
-- Far Shot (learn A03J): each rank applies the R00O range upgrade at the new rank and
-- extends the archer's acquisition range by 200 so she actually engages at the new range.

local function setupArcaneArcher()
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A03J')
    end, function()
        local archer = GetLearningUnit()
        FarShotTotal = FarShotTotal + 1
        local rank = FarShotTotal
        TriggerSleepAction(2.0)
        SetPlayerTechResearchedSwap(FourCC('R00O'), rank, GetOwningPlayer(archer))
        SetUnitAcquireRangeBJ(archer, GetUnitAcquireRange(archer) + 200.0)
    end)
end

-- ══ Rogue of the Dark (E001) — war3map.j 45544-45760 ════════════════════════════
-- Stealth (A00P): builds +1 damage stack every 2s while not attacking (cap +5/rank); the
-- next attack discharges AGI × stacks bonus damage. Learning it also adds the A059 display
-- passive (the command-card icon). Murder (A00R): instakill a non-hero target that is
-- ISOLATED (≤1 living enemy within 400). Dagger in the Dark (A0JI): refill stacks + reset
-- Murder's cooldown. Blind (A00Q): the e01A dummy paints a fog cloud at the target point.

local ROGUE = FourCC('E001')

local function setupRogue()
    local stacksT, attackT

    -- Stealth_Damage (2s tick, armed on first Stealth rank): build stacks while passive.
    stacksT = CreateTrigger()
    DisableTrigger(stacksT)
    TriggerRegisterTimerEventPeriodic(stacksT, 2.0)
    TriggerAddAction(stacksT, function()
        if not HasRogueAttacked then
            if RogueDamageStacks < RogueMaxDamageStacks then
                RogueDamageStacks = RogueDamageStacks + 1
            end
        else
            HasRogueAttacked = false
        end
    end)

    -- Rogue_Attacks: discharge the stacks as AGI × stacks bonus damage.
    attackT = CreateTrigger()
    DisableTrigger(attackT)
    TriggerRegisterAnyUnitEventBJ(attackT, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(attackT, Condition(function()
        return GetUnitTypeId(GetAttacker()) == ROGUE
    end))
    TriggerAddAction(attackT, function()
        local rogue, victim = GetAttacker(), GetAttackedUnitBJ()
        if RogueDamageStacks > 0 then
            TriggerSleepAction(0.25)
            local dmg = GetHeroAgi(rogue, true) * RogueDamageStacks
            FloatText(victim, tostring(dmg), 100, 0, 0, 3.0)
            UnitDamageTarget(rogue, victim, dmg, false, false,
                ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            RogueDamageStacks = 0
        end
        HasRogueAttacked = true
    end)

    -- Learn Stealth (A00P): +5 max stacks per rank, arm the stack system, and add the
    -- A059 display passive so the skill shows on the command card (Button_for_Stealth).
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A00P')
    end, function()
        RogueMaxDamageStacks = RogueMaxDamageStacks + 5
        UnitAddAbility(GetLearningUnit(), FourCC('A059'))
        TriggerSleepAction(1.0)
        EnableTrigger(stacksT)
        EnableTrigger(attackT)
    end)

    -- Murder_Cast (A00R on a NON-hero): instakill only when the target is isolated —
    -- at most 1 living Player(9) unit (itself) within 400 (war3map.j 45691-45729).
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A00R')
            and not IsUnitType(GetSpellTargetUnit(), UNIT_TYPE_HERO)
    end, function()
        local target = GetSpellTargetUnit()
        local near = CountInRange(GetUnitX(target), GetUnitY(target), 400.0, function()
            local f = GetFilterUnit()
            return GetOwningPlayer(f) == P9 and IsUnitAliveBJ(f)
        end)
        if near <= 1 then
            UnitDamageTarget(GetSpellAbilityUnit(), target, 99999.0, false, false,
                ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            FloatText(target, "Murder!", 100, 100, 100, 3.0)
        end
    end)

    -- Dagger in the Dark (A0JI): refill stacks to max + reset Murder's cooldown.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0JI')
    end, function()
        RogueDamageStacks = RogueMaxDamageStacks
        BlzEndUnitAbilityCooldown(GetSpellAbilityUnit(), FourCC('A00R'))
    end)

    -- Blind (A00Q): the e01A dummy paints a fog cloud on the target point.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A00Q')
    end, function()
        if unit_e01A and GetUnitTypeId(unit_e01A) ~= 0 then
            IssuePointOrder(unit_e01A, "cloudoffog", GetSpellTargetX(), GetSpellTargetY())
        end
    end)
end

function RegisterAbilityTriggers()
    setupEarthenTemplar()
    setupEngineer()
    setupArcaneArcher()
    setupRogue()
end
