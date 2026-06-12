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

-- ══ Wildbond (H03J) — pet kit, war3map.j 46619-47095 ════════════════════════════
-- Her spells are bound to the pet: Spell_Only_Pet cancels pet-spells aimed at anything
-- else. The pair share levels (Level_Matching / Pet_Scaling) and a death bond
-- (Wildbond_Dies — one dies, both die; the A0I8 ward disables it). Lifelink (A0CM)
-- drains the owner to heal the pet; Beast Training (A0CN) upgrades the pet's passive
-- per rank; Eagle Eye (A0D2) is the pet twin of Far Shot; Bear Protect (A0CS) recalls
-- the pet to the owner; Spirit Bond (A0D4) heals the other half on every kill.

local function petAlive()
    return WildbondPet and GetUnitTypeId(WildbondPet) ~= 0
end
local function ownerAlive()
    return Wildbond and GetUnitTypeId(Wildbond) ~= 0
end

local function setupWildbond()
    -- Spell_Only_Pet (A0CL): casting a pet-spell at anything but the pet is cancelled.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CAST, function()
        return GetSpellAbilityId() == FourCC('A0CL')
            and GetSpellTargetUnit() ~= WildbondPet
    end, function()
        IssueImmediateOrderBJ(GetSpellAbilityUnit(), "stop")
    end)

    -- Level sharing: the pet grows +5 scale per pet level (owner catches up if behind);
    -- the owner leveling pulls the pet up (war3map.j Pet_Scaling / Level_Matching).
    OnAnyUnit(EVENT_PLAYER_HERO_LEVEL, function()
        return GetLevelingUnit() == WildbondPet
    end, function()
        WildbondPetSize = WildbondPetSize + 5.0
        SetUnitScalePercent(WildbondPet, WildbondPetSize, WildbondPetSize, WildbondPetSize)
        if ownerAlive() and GetHeroLevel(Wildbond) < GetHeroLevel(WildbondPet) then
            SetHeroLevelBJ(Wildbond, GetHeroLevel(WildbondPet), true)
        end
    end)
    OnAnyUnit(EVENT_PLAYER_HERO_LEVEL, function()
        return GetLevelingUnit() == Wildbond
    end, function()
        if petAlive() and GetHeroLevel(WildbondPet) < GetHeroLevel(Wildbond) then
            SetHeroLevelBJ(WildbondPet, GetHeroLevel(Wildbond), true)
        end
    end)

    -- Death bond: if either half dies, both die 1s later (disabled by the A0I8 ward).
    local bondT = OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        local d = GetDyingUnit()
        return (d == Wildbond or d == WildbondPet) and Wildbond ~= nil and WildbondPet ~= nil
    end, function()
        TriggerSleepAction(1.0)
        if ownerAlive() then KillUnit(Wildbond) end
        if petAlive() then KillUnit(WildbondPet) end
    end)
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0I8')
    end, function()
        DisableTrigger(bondT)
    end)

    -- Lifelink (A0CM): learn = +100 drained per rank (sets the owner handle); cast =
    -- owner loses LifeLinkTotal HP, the pet heals LifeLinkTotal × multiplier.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0CM')
    end, function()
        Wildbond = GetLearningUnit()
        LifeLinkTotal = LifeLinkTotal + 100.0
        LifelinkRank = LifelinkRank + 1
        if LifelinkRank >= 5 then LifeLinkMultiplier = 3.0 end
    end)
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0CM')
    end, function()
        if not (ownerAlive() and petAlive()) then return end
        SetUnitLifeBJ(Wildbond, GetUnitState(Wildbond, UNIT_STATE_LIFE) - LifeLinkTotal)
        SetUnitLifeBJ(WildbondPet,
            GetUnitState(WildbondPet, UNIT_STATE_LIFE) + LifeLinkTotal * LifeLinkMultiplier)
    end)

    -- Eagle Eye (A0D2): pet twin of Far Shot — R00O range tech at the new rank.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0D2')
    end, function()
        EagleEyeLearn = EagleEyeLearn + 1
        TriggerSleepAction(2.0)
        SetPlayerTechResearchedSwap(FourCC('R00O'), EagleEyeLearn,
            GetOwningPlayer(GetLearningUnit()))
    end)

    -- Beast Training (A0CN): per rank, swap the pet's passive up the A0CO→A0CP→A0CQ→A0CR
    -- chain; rank 5 adds AIx5 on top (war3map.j 46956).
    local BEAST = { FourCC('A0CO'), FourCC('A0CP'), FourCC('A0CQ'), FourCC('A0CR') }
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0CN')
    end, function()
        BeastTrainingRank = BeastTrainingRank + 1
        if not petAlive() then return end
        local r = BeastTrainingRank
        if r == 1 then
            UnitAddAbility(WildbondPet, BEAST[1])
        elseif r >= 2 and r <= 4 then
            UnitRemoveAbility(WildbondPet, BEAST[r - 1])
            TriggerSleepAction(1.0)
            if petAlive() then UnitAddAbility(WildbondPet, BEAST[r]) end
        elseif r == 5 then
            UnitAddAbility(WildbondPet, FourCC('AIx5'))
        end
    end)

    -- Bear Protect the Master (A0CS): 0.5s later the pet is recalled to the owner's side.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0CS')
    end, function()
        TriggerSleepAction(0.5)
        if not (ownerAlive() and petAlive()) then return end
        local a = math.rad(GetRandomReal(0.0, 360.0))
        SetUnitPosition(WildbondPet,
            GetUnitX(Wildbond) + 40.0 * math.cos(a), GetUnitY(Wildbond) + 40.0 * math.sin(a))
    end)

    -- Spirit Bond (A0D4): every kill by one half heals the other (+SpiritBondHeal,
    -- +15 per rank); the kill triggers arm on first learn.
    local heroKillT = OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return Wildbond ~= nil and GetKillingUnit() == Wildbond
    end, function()
        if petAlive() then
            SetUnitLifeBJ(WildbondPet, GetUnitState(WildbondPet, UNIT_STATE_LIFE) + SpiritBondHeal)
        end
    end)
    local petKillT = OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return WildbondPet ~= nil and GetKillingUnit() == WildbondPet
    end, function()
        if ownerAlive() then
            SetUnitLifeBJ(Wildbond, GetUnitState(Wildbond, UNIT_STATE_LIFE) + SpiritBondHeal)
        end
    end)
    DisableTrigger(heroKillT)
    DisableTrigger(petKillT)
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0D4')
    end, function()
        Wildbond = GetLearningUnit()
        SpiritBondHeal = SpiritBondHeal + 15.0
        EnableTrigger(heroKillT)
        EnableTrigger(petKillT)
    end)
end

-- ══ Axe Brother (E006) — war3map.j 37529-37865 ═════════════════════════════════
-- A berserker whose attacks proc. Decimate (learn A03O): each rank +5% chance that an attack
-- erupts into a 5-hit ×40 flurry. Fang Strike (learn/cast A03P): a 15s window that adds a big
-- Decimate-chance burst (+20/40/60/100 by rank) and makes the flurry deal real CHAOS damage.
-- Assault (learn A03Q): the brother banks every kill (KillsForAxeBrother); a small chance per
-- attack discharges them all as KillsForAxeBrother × 15/rank bonus damage.

local AXE_BROTHER = FourCC('E006')
local DECIMATE_BLOOD = "Objects\\Spawnmodels\\NightElf\\NightElfBlood\\NightElfBloodHippogryph.mdl"
local FANG_BURST = { 20, 40, 60, 100 }   -- [rank] = Decimate chance added during the window

local function decimateFlurry(attacker, victim, chaos)
    -- 5 hits of 40 over ~2s gaps. CHAOS (real, mitigable) during a Fang Strike window; otherwise
    -- a flat life subtraction (armour-ignoring) — matches the two JASS branches.
    if snd.ArtilleryCorpseExplodeDeath1 then PlaySoundOnUnitBJ(snd.ArtilleryCorpseExplodeDeath1, 100, victim) end
    DestroyEffect(AddSpecialEffectTarget(DECIMATE_BLOOD, victim, "origin"))
    FloatText(victim, "Decimate!", 100, 0, 0, 2.0)
    TriggerSleepAction(2.0)
    if trg_AxeBrotherSavageFighter then ConditionalTriggerExecute(trg_AxeBrotherSavageFighter) end
    for _ = 1, 5 do
        if GetUnitTypeId(victim) == 0 then return end
        FloatText(victim, "40", 100, 100, 100, 1.0)
        if chaos then
            UnitDamageTarget(attacker, victim, 40.0, false, false,
                ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        else
            SetUnitLifeBJ(victim, GetUnitState(victim, UNIT_STATE_LIFE) - 40.0)
        end
        TriggerSleepAction(2.0)
    end
end

local function setupAxeBrother()
    -- Decimate Learn (A03O): +5% proc chance per rank.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A03O')
    end, function()
        DecimateChance = DecimateChance + 5
    end)

    -- Fang Strike Learn (A03P): bump the rank (drives the burst size).
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A03P')
    end, function()
        FangStrikeRank = FangStrikeRank + 1
    end)

    -- Fang Strike (cast A03P): open a 15s window — big Decimate-chance burst + CHAOS flurries.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CAST, function()
        return GetSpellAbilityId() == FourCC('A03P')
    end, function()
        local burst = FANG_BURST[FangStrikeRank]
        if not burst then return end
        FangStrikeActive = true
        DecimateChance = DecimateChance + burst
        TriggerSleepAction(15.0)
        DecimateChance = DecimateChance - burst
        FangStrikeActive = false
    end)

    -- Decimate Chance: on the brother attacking, roll the proc. Inside a Fang Strike window the
    -- flurry is CHAOS damage and the trigger stays hot; otherwise it's flat and the trigger is
    -- gated off during the ~10s flurry so it can't re-proc on itself (war3map.j 37582-37665).
    local decimateT
    decimateT = OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return GetUnitTypeId(GetAttacker()) == AXE_BROTHER
    end, function()
        if GetRandomInt(1, 100) > DecimateChance then return end
        local attacker, victim = GetAttacker(), GetAttackedUnitBJ()
        if FangStrikeActive then
            decimateFlurry(attacker, victim, true)
        else
            DisableTrigger(decimateT)
            decimateFlurry(attacker, victim, false)
            EnableTrigger(decimateT)
        end
    end)

    -- Assault: a kill-banking proc, armed once Assault (A03Q) is learned.
    local assaultT = OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return GetOwningPlayer(GetDyingUnit()) == P9
            and GetUnitTypeId(GetKillingUnit()) == AXE_BROTHER
    end, function()
        KillsForAxeBrother = KillsForAxeBrother + 1
    end)
    DisableTrigger(assaultT)

    local assaultChanceT
    assaultChanceT = OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return GetUnitTypeId(GetAttacker()) == AXE_BROTHER
    end, function()
        DisableTrigger(assaultChanceT)
        if GetRandomInt(1, 100) <= AssaultChance then
            local attacker, victim = GetAttacker(), GetAttackedUnitBJ()
            TotalAssaultDamage = KillsForAxeBrother * AssaultMultiplier
            if snd.ArtilleryCorpseExplodeDeath1 then PlaySoundOnUnitBJ(snd.ArtilleryCorpseExplodeDeath1, 100, victim) end
            FloatText(victim, tostring(TotalAssaultDamage), 100, 100, 100, 3.0)
            UnitDamageTarget(attacker, victim, TotalAssaultDamage * 1.0, false, false,
                ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        end
        EnableTrigger(assaultChanceT)
    end)
    DisableTrigger(assaultChanceT)

    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A03Q')
    end, function()
        EnableTrigger(assaultT)
        EnableTrigger(assaultChanceT)
        AssaultMultiplier = AssaultMultiplier + 15
    end)
end

-- ══ Elven Sharpshooter (H02N) — war3map.j 42590-42719 ══════════════════════════
-- Sniper's Mark (learn/cast A07O): marks a target for 30s; if the sniper's team kills it while
-- marked, they collect a gold bounty (+20/rank). Shock Arrows (learn A07R): every attack lands a
-- small terrain-rippling AoE burst (60+40+20 = 120 split over two radii) — armed once learned.

local SHARPSHOOTER = FourCC('H02N')

local function setupSharpshooter()
    -- Sniper's Mark Learn (A07O, real unit only): +20 gold bounty per rank; remember the sniper.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return not IsUnitIllusion(GetLearningUnit()) and GetLearnedSkillBJ() == FourCC('A07O')
    end, function()
        SnipersMark = SnipersMark + 20
        ElvenSniper = GetLearningUnit()
        ElvenSniperPlayer = GetOwningPlayer(ElvenSniper)
    end)

    -- Sniper's Mark Cast (A07O): tag the target as marked for 30s.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A07O')
    end, function()
        local target = GetSpellTargetUnit()
        FloatText(target, "Marked!", 100, 0, 0, 3.0)
        SniperMarkTarget = target
        TriggerSleepAction(30.0)
        if SniperMarkTarget == target then SniperMarkTarget = nil end
    end)

    -- Sniper Mark Kill: the sniper's team kills the marked target → gold bounty.
    -- (The "Kill Shots" achievement counts the same kill independently in achievements.lua.)
    OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return SniperMarkTarget ~= nil and GetDyingUnit() == SniperMarkTarget
            and GetOwningPlayer(GetKillingUnit()) == ElvenSniperPlayer
    end, function()
        local killer = GetOwningPlayer(GetKillingUnit())
        FloatText(GetDyingUnit(), "+" .. tostring(SnipersMark), 100, 100, 0, 3.0)
        AdjustPlayerStateBJ(SnipersMark, killer, PLAYER_STATE_RESOURCE_GOLD)
    end)

    -- Shock Arrows (attack by H02N): a small AoE burst at the struck unit, armed once learned.
    local shockT
    shockT = OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return GetUnitTypeId(GetAttacker()) == SHARPSHOOTER
    end, function()
        local attacker, victim = GetAttacker(), GetAttackedUnitBJ()
        TriggerSleepAction(0.5)
        if GetUnitTypeId(victim) == 0 then return end
        local x, y = GetUnitX(victim), GetUnitY(victim)
        local loc = Location(x, y)
        TerrainDeformationRippleBJ(2.4, false, loc, 196.0, 196.0, 96.0, 0.4, 49.0)
        RemoveLocation(loc)
        UnitDamagePoint(attacker, 0, 60.0, x, y, 25.0, false, false,
            ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        UnitDamagePoint(attacker, 0, 40.0, x, y, 25.0, false, false,
            ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        UnitDamagePoint(attacker, 0, 20.0, x, y, 50.0, false, false,
            ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
    end)
    DisableTrigger(shockT)
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A07R')
    end, function()
        ElvenSniper = GetLearningUnit()
        EnableTrigger(shockT)
    end)
end

-- ══ Fire Magus (E01B) — war3map.j 42026-42563 ══════════════════════════════════
-- The canonical Pattern-B class. Fireball (A0HZ): launches a missile whose tier scales with
-- rank; on the missile's death it bursts for rank-scaled AoE (175/300/400/500) and, at high
-- ranks, sprays cosmetic ember missiles. Fire Nova (A08O): a radiating ring of fire missiles
-- (denser per rank) that burn enemies they pass (damage is the missile units' own — no death
-- trigger), cleaned up after their lifetime.

local DEG2RAD = bj_DEGTORAD

-- Fireball: rank → launched missile type. (JASS Fireball[] 1..5 = e00G/e00H/e00I/e00P/e00P.)
local FIREBALL_MISSILE = {
    FourCC('e00G'), FourCC('e00H'), FourCC('e00I'), FourCC('e00P'), FourCC('e00P'),
}
-- Missile type → its impact (damage in 320 AoE + count of cosmetic e00K ember missiles).
local FIREBALL_IMPACT = {
    [FourCC('e00G')] = { dmg = 175.0, embers = 0 },
    [FourCC('e00H')] = { dmg = 300.0, embers = 0 },
    [FourCC('e00I')] = { dmg = 400.0, embers = 5 },
    [FourCC('e00P')] = { dmg = 500.0, embers = 10 },
}
local FIRE_EMBER = FourCC('e00K')   -- cosmetic scatter missile
local FIRE_IMPACT_SFX = FourCC('e00L')  -- impact flash dummy

-- Fire Nova: rank → { ring missile, angle step (deg), missile lifetime }. (JASS FireNova[] +
-- the Lv1..4 cast triggers: step 40/30/20/20, life 5/5/5/8, types e00M/e00N/e00O/e00O.)
local FIRE_NOVA = {
    { missile = FourCC('e00M'), step = 40, life = 5.0 },
    { missile = FourCC('e00N'), step = 30, life = 5.0 },
    { missile = FourCC('e00O'), step = 20, life = 5.0 },
    { missile = FourCC('e00O'), step = 20, life = 8.0 },
}

local function setupFireMagus()
    -- Fireball Learn (A0HZ): bump the rank (selects the missile tier).
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0HZ')
    end, function()
        FireballRank = FireballRank + 1
    end)

    -- Fireball cast (A0HZ): launch the rank's missile straight ahead; kill it after 1–3s so its
    -- death trigger bursts (the original's "order/kill all of type" collapses to one missile here).
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0HZ')
    end, function()
        local caster = GetSpellAbilityUnit()
        local mtype = FIREBALL_MISSILE[FireballRank]
        if not mtype then return end
        local facing = GetUnitFacing(caster)
        local rad = facing * DEG2RAD
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        local m = CreateUnit(GetOwningPlayer(caster), mtype,
            cx + 110.0 * math.cos(rad), cy + 110.0 * math.sin(rad), facing)
        if snd.FireBallMissileDeath then PlaySoundOnUnitBJ(snd.FireBallMissileDeath, 100, caster) end
        IssuePointOrder(m, "move", cx + 2000.0 * math.cos(rad), cy + 2000.0 * math.sin(rad))
        After(GetRandomReal(1.0, 3.0), function()
            if GetUnitTypeId(m) ~= 0 then KillUnit(m) end
        end)
    end)

    -- Fireball missile death: rank-scaled AoE burst + impact flash + (high ranks) ember spray.
    OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return FIREBALL_IMPACT[GetUnitTypeId(GetDyingUnit())] ~= nil
    end, function()
        local missile = GetDyingUnit()
        local info = FIREBALL_IMPACT[GetUnitTypeId(missile)]
        local x, y = GetUnitX(missile), GetUnitY(missile)
        if snd.CatapultMissile3 then
            local loc = Location(x, y)
            PlaySoundAtPointBJ(snd.CatapultMissile3, 100, loc, 0)
            RemoveLocation(loc)
        end
        local flash = CreateUnit(P8, FIRE_IMPACT_SFX, x, y, bj_UNIT_FACING)
        After(1.0, function() if GetUnitTypeId(flash) ~= 0 then RemoveUnit(flash) end end)
        for _ = 1, info.embers do
            local ang = GetRandomReal(0.0, 360.0) * DEG2RAD
            local k = CreateUnit(P8, FIRE_EMBER, x, y, bj_UNIT_FACING)
            IssuePointOrder(k, "move", x + 5000.0 * math.cos(ang), y + 5000.0 * math.sin(ang))
            After(2.5, function() if GetUnitTypeId(k) ~= 0 then RemoveUnit(k) end end)
        end
        ForUnitsInRange(x, y, 320.0, function()
            return GetOwningPlayer(GetFilterUnit()) == P9
        end, function()
            UnitDamageTarget(missile, GetEnumUnit(), info.dmg, false, false,
                ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        end)
    end)

    -- Fire Nova Learn (A08O): bump the rank (selects ring density + missile).
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A08O')
    end, function()
        FireNovaRank = FireNovaRank + 1
    end)

    -- Fire Nova cast (A08O): spawn a full ring of outward-radiating fire missiles, owned by the
    -- caster so they burn enemies; remove them after the rank's lifetime.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A08O')
    end, function()
        local spec = FIRE_NOVA[FireNovaRank]
        if not spec then return end
        local caster = GetSpellAbilityUnit()
        local owner = GetOwningPlayer(caster)
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        if snd.FireBallMissileDeath then PlaySoundBJ(snd.FireBallMissileDeath) end
        local ring = {}
        for a = 0, 360, spec.step do
            local rad = a * DEG2RAD
            local m = CreateUnit(owner, spec.missile,
                cx + 90.0 * math.cos(rad), cy + 90.0 * math.sin(rad), a)
            IssuePointOrder(m, "move", cx + 2000.0 * math.cos(rad), cy + 2000.0 * math.sin(rad))
            ring[#ring + 1] = m
        end
        After(spec.life, function()
            for _, m in ipairs(ring) do
                if GetUnitTypeId(m) ~= 0 then KillUnit(m) end
            end
        end)
    end)
end

-- ══ Horizon Wanderer (E011) — war3map.j 41740-41836 ════════════════════════════
-- A roaming bruiser. Dimension Door (A00U): casting the outward blink instantly refreshes the
-- return blink (A00V) so the pair chains freely. Trample (learn A0JJ / cast A0JJ): for
-- TrampleDuration (+2s/rank) the Wanderer grows, ignores pathing, and each second stomps every
-- non-hero enemy within 175 — STR damage + a 100-unit knockback away from her.

local STAMPEDE_SFX = "Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl"

local function setupHorizonWanderer()
    -- Dimension Door Reset CD (A00U): refresh the paired return-blink (A00V).
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A00U')
    end, function()
        BlzEndUnitAbilityCooldown(GetSpellAbilityUnit(), FourCC('A00V'))
    end)

    -- Learn Trample (A0JJ): +2s of stomping per rank.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0JJ')
    end, function()
        TrampleDuration = TrampleDuration + 2
    end)

    -- Trample cast (A0JJ): a TrampleDuration-second stomp that follows the moving Wanderer.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0JJ')
    end, function()
        local caster = GetSpellAbilityUnit()
        SetUnitPathing(caster, false)
        SetUnitScalePercent(caster, 125.0, 125.0, 125.0)
        local sfx = AddSpecialEffectTarget(STAMPEDE_SFX, caster, "origin")
        for _ = 1, TrampleDuration do
            local cx, cy = GetUnitX(caster), GetUnitY(caster)
            ForUnitsInRange(cx, cy, 175.0, function()
                local f = GetFilterUnit()
                return GetOwningPlayer(f) == P9 and not IsUnitType(f, UNIT_TYPE_HERO)
            end, function()
                local e = GetEnumUnit()
                BlzPlaySpecialEffect(sfx, ANIM_TYPE_BIRTH)
                UnitDamageTarget(caster, e, GetHeroStr(caster, true) * 1.0, false, false,
                    ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                -- shove the victim 100 outward (away from the Wanderer), then face her.
                local ang = Atan2(GetUnitY(e) - cy, GetUnitX(e) - cx)
                SetUnitPosition(e, GetUnitX(e) + 100.0 * math.cos(ang), GetUnitY(e) + 100.0 * math.sin(ang))
                SetUnitFacing(e, (ang + bj_PI) * bj_RADTODEG)
            end)
            TriggerSleepAction(1.0)
        end
        DestroyEffect(sfx)
        SetUnitScalePercent(caster, 100.0, 100.0, 100.0)
        SetUnitPathing(caster, true)
    end)
end

-- ══ Elven Cryptguard (E019) — war3map.j 41839-41897 ════════════════════════════
-- A necromancer-knight. Vengeful Spirit (learn A0GG): once learned, whenever ANY player hero
-- dies (not the enemy P9 / neutral P8 sides), it rises 2s later as a vengeful spirit summon for
-- its owner, the spirit's tier set by the Cryptguard's rank in the skill.

-- Vengeful Spirit: rank → the spirit unit a fallen hero raises (JASS VengefulSpiritUnits[1..5]).
local VENGEFUL_SPIRIT = {
    FourCC('n00N'), FourCC('n00O'), FourCC('n00P'), FourCC('n00Q'), FourCC('n00U'),
}
local UNDEAD_DISSIPATE = "Objects\\Spawnmodels\\Undead\\UndeadDissipate\\UndeadDissipate.mdl"
local vengefulAnim   -- the last raise effect (destroyed before the next, as in the original)

local function setupCryptguard()
    -- Vengeful Spirit Make: a fallen player hero rises as a spirit. Armed once the skill is learned.
    local makeT = OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        local d = GetDyingUnit()
        return GetOwningPlayer(d) ~= P8 and GetOwningPlayer(d) ~= P9
            and IsUnitType(d, UNIT_TYPE_HERO)
    end, function()
        local dead = GetDyingUnit()
        local owner = GetOwningPlayer(dead)
        local x, y = GetUnitX(dead), GetUnitY(dead)
        local spirit = VENGEFUL_SPIRIT[VengefulSpiritLvl]
        if vengefulAnim then DestroyEffect(vengefulAnim) end
        vengefulAnim = AddSpecialEffect(UNDEAD_DISSIPATE, x, y)
        TriggerSleepAction(2.0)
        if spirit then CreateUnit(owner, spirit, x, y, bj_UNIT_FACING) end
    end)
    DisableTrigger(makeT)

    -- Vengeful Spirit Learn (A0GG): arm the rise + bump the spirit tier.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0GG')
    end, function()
        EnableTrigger(makeT)
        VengefulSpiritLvl = VengefulSpiritLvl + 1
    end)

    -- ── Haven (A0GK) — a channeled repel ward (Tranquility-based) ──────────────
    -- While the Cryptguard channels, every non-hero enemy entering the defended area is blinked
    -- back out to a random outer path (draining her mana per repel). Each rank cheapens the repel
    -- and the channel itself drains 5 mana/s; it ends when she stops or runs dry.
    local SPELL_SHIELD = "Abilities\\Spells\\Items\\SpellShieldAmulet\\SpellShieldCaster.mdl"
    local havenAnim
    local havenCaster
    local TRANQUILITY = OrderId("tranquility")

    -- Haven Channel: blink an intruder back out, drain the Cryptguard, then send it walking back.
    local channelT = OnEnterRect(rct.AreaToDefend, function()
        return GetOwningPlayer(GetEnteringUnit()) == P9
            and not IsUnitType(GetEnteringUnit(), UNIT_TYPE_HERO)
    end, function()
        local intruder = GetEnteringUnit()
        if havenAnim then DestroyEffect(havenAnim) end
        if snd.HavenImpact then PlaySoundOnUnitBJ(snd.HavenImpact, 100, intruder) end
        local areas = { rct.WestPathOutside, rct.NorthPathOutside1, rct.NorthPathOutside2, rct.EastPathOutside }
        local loc = GetRandomLocInRect(areas[GetRandomInt(1, 4)])
        SetUnitPositionLoc(intruder, loc)
        RemoveLocation(loc)
        havenAnim = AddSpecialEffectTarget(SPELL_SHIELD, intruder, "origin")
        if havenCaster and GetUnitTypeId(havenCaster) ~= 0 then
            SetUnitState(havenCaster, UNIT_STATE_MANA,
                GetUnitState(havenCaster, UNIT_STATE_MANA) - HavenManaRepelCost)
        end
        TriggerSleepAction(2.0)
        IssuePointOrder(intruder, "patrol",
            GetRectCenterX(rct.EntranceToFortress), GetRectCenterY(rct.EntranceToFortress))
    end)
    DisableTrigger(channelT)

    -- The per-second channel upkeep: drain 5 mana, end if she stopped channeling or ran dry.
    local function havenTick(caster)
        if not HavenIsOn then return end
        if GetUnitTypeId(caster) == 0 or GetUnitCurrentOrder(caster) ~= TRANQUILITY then
            DisplayCineFilterBJ(false)
            HavenIsOn = false
            DisableTrigger(channelT)
            return
        end
        SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MANA) - 5.0)
        if GetUnitState(caster, UNIT_STATE_MANA) < 5.0 then
            DisplayCineFilterBJ(false)
            IssueImmediateOrder(caster, "stop")
            HavenIsOn = false
            DisableTrigger(channelT)
            return
        end
        After(1.0, function() havenTick(caster) end)
    end

    -- Haven Learn (A0GK): set the repel destinations (no-op here — read live) + cheapen the repel.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0GK')
    end, function()
        HavenManaRepelCost = HavenManaRepelCost - 5.0
    end)

    -- Haven Cast (A0GK, channel start): raise the ward + begin the upkeep loop.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CHANNEL, function()
        return GetSpellAbilityId() == FourCC('A0GK')
    end, function()
        local caster = GetSpellAbilityUnit()
        havenCaster = caster
        if not HavenIsOn then
            DisplayTimedTextToForce(GetPlayersAll(), 8.0,
                GetPlayerName(GetOwningPlayer(caster)) .. "  casts |cff995500Haven|r!")
            CinematicFilterGenericBJ(8.0, BLEND_MODE_BLEND,
                "ReplaceableTextures\\CameraMasks\\White_mask.blp",
                100.0, 0.0, 100.0, 70.0, 100.0, 0.0, 100.0, 70.0)
            DisplayCineFilterBJ(true)
            if snd.HavenStart then PlaySoundBJ(snd.HavenStart) end
            HavenIsOn = true
        end
        EnableTrigger(channelT)
        After(1.0, function() havenTick(caster) end)
    end)
end

function RegisterAbilityTriggers()
    setupEarthenTemplar()
    setupEngineer()
    setupArcaneArcher()
    setupRogue()
    setupWildbond()
    setupAxeBrother()
    setupSharpshooter()
    setupFireMagus()
    setupHorizonWanderer()
    setupCryptguard()
end
