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
        DisplayTextToPlayer(GetOwningPlayer(s), 0, 0,   -- GetForceOfPlayer would leak a force/cap-hit
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
        local anim = AddSpecialEffect(UNDEAD_DISSIPATE, x, y)
        TriggerSleepAction(2.0)   -- let the dissipate play, then free it (no lingering handle)
        DestroyEffect(anim)
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
    local havenCaster
    local TRANQUILITY = OrderId("tranquility")

    -- Haven Channel: blink an intruder back out, drain the Cryptguard, then send it walking back.
    local channelT = OnEnterRect(rct.AreaToDefend, function()
        return GetOwningPlayer(GetEnteringUnit()) == P9
            and not IsUnitType(GetEnteringUnit(), UNIT_TYPE_HERO)
    end, function()
        local intruder = GetEnteringUnit()
        if snd.HavenImpact then PlaySoundOnUnitBJ(snd.HavenImpact, 100, intruder) end
        local areas = { rct.WestPathOutside, rct.NorthPathOutside1, rct.NorthPathOutside2, rct.EastPathOutside }
        local loc = GetRandomLocInRect(areas[GetRandomInt(1, 4)])
        SetUnitPositionLoc(intruder, loc)
        RemoveLocation(loc)
        local anim = AddSpecialEffectTarget(SPELL_SHIELD, intruder, "origin")
        if havenCaster and GetUnitTypeId(havenCaster) ~= 0 then
            SetUnitState(havenCaster, UNIT_STATE_MANA,
                GetUnitState(havenCaster, UNIT_STATE_MANA) - HavenManaRepelCost)
        end
        TriggerSleepAction(2.0)
        DestroyEffect(anim)   -- free the repel shield once it has played
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

-- ══ Paladin of Justice (H01J) — war3map.j 45181-45542 ══════════════════════════
-- A holy knight. Lay on Hands (A02M): sacrifices a fraction of the Paladin's own life as a heal
-- (bigger fraction per rank). Crusade (A02Q): a passive that, every level the team clears, grants
-- the Paladin escalating stats — executed from BonusesAndUpkeep, exposed as trg_Crusade. Exorcism
-- (A02P): smites a fixed roster of unholy enemy types for 300. Angel SFX: gives any spawned angel
-- guardian (h01K) a translucent holy glow.

local PALADIN = FourCC('H01J')
local ANGEL_GUARDIAN = FourCC('h01K')
-- Lay on Hands: heal = caster's current life / divisor[rank] (war3map.j 45248-45298).
local LOH_DIVISOR = { 5.0, 2.5, 1.67, 1.25, 1.25 }
-- Crusade: per rank, stats granted to the Paladin each level cleared (war3map.j 45340-45387).
local CRUSADE_STATS = {
    { str = 1, agi = 0, int = 0 },
    { str = 1, agi = 0, int = 2 },
    { str = 1, agi = 1, int = 1 },
    { str = 2, agi = 1, int = 1 },
}
-- Exorcism only smites these "unholy" target types (war3map.j 45450-45496).
local EXORCISM_TARGETS = {}
for _, c in ipairs({ 'h01H', 'h01Q', 'h01G', 'h01E', 'h01F', 'h03S', 'h02Q', 'h01R',
                     'h04R', 'h06Q', 'h06R', 'h06P', 'h04L', 'O004', 'N015' }) do
    EXORCISM_TARGETS[FourCC(c)] = true
end

local function addStat(unit, getter, setter, n)
    if n > 0 then setter(unit, getter(unit, false) + n, true) end
end

local function setupPaladin()
    -- LoH Learn (A02M): +1 rank (raises the heal fraction).
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A02M')
    end, function()
        LayOnHands = LayOnHands + 1
    end)

    -- Lay on Hands (cast A02M): heal the target for a fraction of the Paladin's own current life.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A02M')
    end, function()
        local div = LOH_DIVISOR[LayOnHands]
        if not div then return end
        TriggerSleepAction(0.5)
        local caster, target = GetSpellAbilityUnit(), GetSpellTargetUnit()
        local heal = GetUnitState(caster, UNIT_STATE_LIFE) / div
        SetUnitLifeBJ(target, GetUnitState(target, UNIT_STATE_LIFE) + heal)
        FloatText(target, "Lay on Hands: +" .. tostring(math.floor(heal)), 100, 100, 0, 3.0)
    end)

    -- Crusade Learn (A02Q): the original juggles two Learn triggers on this one skill (Crusade +
    -- Exorcism); ExorcismValue is never read, so only the Crusade rank matters.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A02Q')
    end, function()
        CrusadeLevel = CrusadeLevel + 1
    end)

    -- Crusade (no event — executed once per cleared level from BonusesAndUpkeep via trg_Crusade):
    -- grant the Paladin escalating stats by rank.
    local crusadeT = CreateTrigger()
    TriggerAddAction(crusadeT, function()
        TriggerSleepAction(2.0)
        local g = GetUnitsOfTypeIdAll(PALADIN)
        local pal = GroupPickRandomUnit(g)
        DestroyGroup(g)
        local bonus = CRUSADE_STATS[CrusadeLevel]
        if not pal or not bonus then return end
        TriggerSleepAction(1.0)
        FloatText(pal, "|cffffff00Crusade!|r", 100, 25, 100, 5.0)
        addStat(pal, GetHeroStr, SetHeroStr, bonus.str)
        addStat(pal, GetHeroAgi, SetHeroAgi, bonus.agi)
        addStat(pal, GetHeroInt, SetHeroInt, bonus.int)
    end)
    trg_Crusade = crusadeT

    -- Exorcism (cast A02P): 300 melee damage, but only to the fixed roster of unholy types.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A02P')
            and EXORCISM_TARGETS[GetUnitTypeId(GetSpellTargetUnit())] == true
    end, function()
        UnitDamageTarget(GetSpellAbilityUnit(), GetSpellTargetUnit(), 300.0, false, false,
            ATTACK_TYPE_MELEE, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
    end)

    -- Angel SFX: any spawned angel guardian (h01K) gets a translucent holy glow.
    OnEnterRect(GetEntireMapRect(), function()
        return GetUnitTypeId(GetEnteringUnit()) == ANGEL_GUARDIAN
    end, function()
        local angel = GetEnteringUnit()
        AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\Tranquility\\TranquilityTarget.mdl",
            angel, "origin")
        SetUnitVertexColorBJ(angel, 100, 100, 100, 40.0)
    end)
end

-- ══ Dwarven Rockfighter (H01M) — war3map.j 40450-40661 ═════════════════════════
-- An earth-shaking brawler. Intimidating Shout (A035): nearby enemies panic and flee to random
-- map points for ~8s, then resume marching on the base (+ arms the Enemy Nudge herder). Cave In
-- (A0I1): a cavern-dust visual over the channel. Crushing Slam (A0I2): a ground-pound that shoves
-- every enemy within 350 violently outward.

-- Order each unit in a group to bolt to a random spot on the map (the "fear" scatter).
local function scatterGroup(grp)
    ForGroup(grp, function()
        local loc = GetRandomLocInRect(GetPlayableMapRect())
        IssuePointOrder(GetEnumUnit(), "move", GetLocationX(loc), GetLocationY(loc))
        RemoveLocation(loc)
    end)
end

-- Crushing Slam knockback: shove one victim ~8/0.05s outward (opposite its facing) for 40 ticks.
local function crushKnockback(caster, victim)
    local steps = 0
    Every(0.05, function()
        steps = steps + 1
        if steps > 40 or GetUnitTypeId(victim) == 0 then return true end
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        local dx, dy = GetUnitX(victim) - cx, GetUnitY(victim) - cy
        local dist = math.sqrt(dx * dx + dy * dy) + 8.0
        local ang = (GetUnitFacing(victim) + 180.0) * DEG2RAD
        SetUnitPosition(victim, cx + dist * math.cos(ang), cy + dist * math.sin(ang))
        return false
    end)
end

local function setupRockfighter()
    -- Enemy Nudge (war3map.j 29478): every 30s herd all P9 enemies onward — game-area units patrol
    -- the fortress entrance, castle-area units patrol the prince. Armed by Intimidating Shout.
    local nudgeT = CreateTrigger()
    DisableTrigger(nudgeT)
    TriggerRegisterTimerEventPeriodic(nudgeT, 30.0)
    TriggerAddAction(nudgeT, function()
        local g1 = GetUnitsInRectOfPlayer(rct.EntireGameArea, P9)
        ForGroup(g1, function()
            IssuePointOrder(GetEnumUnit(), "patrol",
                GetRectCenterX(rct.EntranceToFortress), GetRectCenterY(rct.EntranceToFortress))
        end)
        DestroyGroup(g1)
        local g2 = GetUnitsInRectOfPlayer(rct.EntireCastleArea, P9)
        ForGroup(g2, function()
            IssuePointOrder(GetEnumUnit(), "patrol",
                GetRectCenterX(rct.PrinceArea), GetRectCenterY(rct.PrinceArea))
        end)
        DestroyGroup(g2)
    end)

    -- Intimidating Shout (A035): panic nearby enemies, scatter them 4×, then send them (and every
    -- other non-caravan enemy) marching back at the base. IntimShoutGroup is persistent (the
    -- original never clears it — faithful).
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CAST, function()
        return GetSpellAbilityId() == FourCC('A035')
    end, function()
        local caster = GetSpellAbilityUnit()
        local radius = 55.0 * GetHeroLevel(caster)
        -- Clear first so the group only ever holds this cast's nearby enemies. (The JASS never
        -- clears it — it would grow unboundedly with dead-unit refs and re-fear long-gone units.)
        GroupClear(IntimShoutGroup)
        ForUnitsInRange(GetUnitX(caster), GetUnitY(caster), radius, function()
            return GetOwningPlayer(GetFilterUnit()) == P9
        end, function()
            GroupAddUnit(IntimShoutGroup, GetEnumUnit())
        end)
        scatterGroup(IntimShoutGroup)
        FloatText(caster, "|cffff00ffIntimidate!|r", 100, 0, 100, 3.0)
        for _ = 1, 3 do
            TriggerSleepAction(2.0)
            scatterGroup(IntimShoutGroup)
        end
        TriggerSleepAction(2.0)
        ForGroup(IntimShoutGroup, function()
            local loc = GetRandomLocInRect(rct.CastleEntranceDest)
            IssuePointOrder(GetEnumUnit(), "patrol", GetLocationX(loc), GetLocationY(loc))
            RemoveLocation(loc)
        end)
        local g = GetUnitsOfPlayerMatching(P9, Condition(function()
            return GetUnitTypeId(GetFilterUnit()) ~= FourCC('h01A')
        end))
        ForGroup(g, function()
            IssuePointOrder(GetEnumUnit(), "patrol",
                GetRectCenterX(rct.StartingPlayerArea), GetRectCenterY(rct.StartingPlayerArea))
        end)
        DestroyGroup(g)
        EnableTrigger(nudgeT)
    end)

    -- Cave In (A0I1, channel): a cavern-dust plume at the caster for 5s. (The original captured a
    -- stale effect handle and leaked the dust; the port shows + cleans up the dust as intended.)
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CHANNEL, function()
        return GetSpellAbilityId() == FourCC('A0I1')
    end, function()
        local caster = GetSpellAbilityUnit()
        local dust = AddSpecialEffect("Doodads\\Cinematic\\CavernDust\\CavernDust.mdl",
            GetUnitX(caster), GetUnitY(caster))
        TriggerSleepAction(5.0)
        DestroyEffect(dust)
    end)

    -- Crushing Slam (A0I2): a ground-pound — terrain ripple + violently shove every enemy within
    -- 350 outward. (The JASS ripple uses a stale GetAttackedUnitBJ loc; the port ripples at the
    -- caster, the slam's actual centre.)
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0I2')
    end, function()
        local caster = GetSpellAbilityUnit()
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        local loc = Location(cx, cy)
        TerrainDeformationRippleBJ(2.4, false, loc, 196.0, 300.0, 96.0, 0.4, 49.0)
        RemoveLocation(loc)
        TriggerSleepAction(0.5)
        ForUnitsInRange(cx, cy, 350.0, function()
            return GetOwningPlayer(GetFilterUnit()) == P9
        end, function()
            crushKnockback(caster, GetEnumUnit())
        end)
    end)
end

-- ══ Tundra Barbarian (H03A) — war3map.j 45903-46315 ════════════════════════════
-- A frost berserker. Tundra Strike (A0BK): hurls a rank-scaling volley of ice shards that fly
-- outward from him. Spirit Wolf (A0BY): summons a totem-bound wolf that can't stray far from its
-- spirit totem (and all wolves vanish if the totem dies). Blood Feast (A0C0): each of his kills
-- heals him a % of max HP. Wolves/Fenrir get an ethereal tint when they spawn.

local TUNDRA_SHARD = FourCC('e014')
local WOLF_ETHEREAL_SFX = "Abilities\\Weapons\\ZigguratMissile\\ZigguratMissile.mdl"
-- Spirit Wolf: rank → summoned wolf + the spirit totem it binds to (JASS 46062-46075).
local TOTEMIC_WOLF = { FourCC('h03B'), FourCC('h03D'), FourCC('h03E'), FourCC('h03F'), FourCC('h03F') }
local SPIRIT_TOTEM = { FourCC('o008'), FourCC('o009'), FourCC('o00A'), FourCC('o007'), FourCC('o007') }
local WOLF_TYPE_LIST = { FourCC('h03B'), FourCC('h03D'), FourCC('h03E'), FourCC('h03F') }
local WOLF_TYPES = {}
for _, c in ipairs(WOLF_TYPE_LIST) do WOLF_TYPES[c] = true end
local TOTEM_TYPES = {}
for _, c in ipairs({ FourCC('o008'), FourCC('o009'), FourCC('o00A'), FourCC('o007') }) do
    TOTEM_TYPES[c] = true
end
local wolfEthereal = {}  -- summoned wolf → its attached glow effect (destroyed when the wolf disperses)

-- One Tundra Strike volley: `count` shards at (tx,ty), each flung 5000 outward from the caster
-- in its own random heading, cleared after a random delay.
local function tundraVolley(caster, tx, ty, count, minD, maxD)
    if snd.FrostNovaTarget1 then PlaySoundOnUnitBJ(snd.FrostNovaTarget1, 100, caster) end
    local owner = GetOwningPlayer(caster)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local shards = {}
    for _ = 1, count do
        local s = CreateUnit(owner, TUNDRA_SHARD, tx, ty, GetRandomDirectionDeg())
        local rad = GetUnitFacing(s) * DEG2RAD
        IssuePointOrder(s, "move", cx + 5000.0 * math.cos(rad), cy + 5000.0 * math.sin(rad))
        shards[#shards + 1] = s
    end
    TriggerSleepAction(GetRandomReal(minD, maxD))
    for _, s in ipairs(shards) do
        if GetUnitTypeId(s) ~= 0 then KillUnit(s) end
    end
end

local function setupTundraBarbarian()
    -- Tundra Strike Learn (A0BK): +1 rank.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0BK')
    end, function()
        TundraStrikeRank = TundraStrikeRank + 1
    end)

    -- Tundra Strike Use (cast A0BK): rank-gated volleys — 5 @r3, 9 @r≥4, +13 @r≥5 (the original
    -- runs both the ≥4 and ≥5 blocks at rank 5, two bursts).
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0BK')
    end, function()
        local caster = GetSpellAbilityUnit()
        local tx, ty = GetSpellTargetX(), GetSpellTargetY()
        if TundraStrikeRank == 3 then
            tundraVolley(caster, tx, ty, 5, 2.0, 4.0)
            return
        end
        if TundraStrikeRank >= 4 then tundraVolley(caster, tx, ty, 9, 2.0, 4.0) end
        if TundraStrikeRank >= 5 then tundraVolley(caster, tx, ty, 13, 2.0, 6.0) end
    end)

    -- Spirit Wolf Learn (A0BY): +1 rank (selects the wolf + totem tier).
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0BY')
    end, function()
        TotemicSpiritRank = TotemicSpiritRank + 1
    end)

    -- Spirit Wolf Cast (A0BY): summon the rank's wolf at the target; bind it to its spirit totem.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0BY')
    end, function()
        local wolf = TOTEMIC_WOLF[TotemicSpiritRank]
        if not wolf then return end
        CreateUnit(GetOwningPlayer(GetSpellAbilityUnit()), wolf,
            GetSpellTargetX(), GetSpellTargetY(), bj_UNIT_FACING)
        TriggerSleepAction(1.0)
        local g = GetUnitsOfTypeIdAll(SPIRIT_TOTEM[TotemicSpiritRank])
        CurrentTotemicSpirit = GroupPickRandomUnit(g)
        DestroyGroup(g)
    end)

    -- Spirit Wolf Disperse (DEATH of a spirit totem): all summoned wolves vanish (and their
    -- attached glow effects are destroyed so they don't orphan on RemoveUnit).
    OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return TOTEM_TYPES[GetUnitTypeId(GetDyingUnit())] == true
    end, function()
        for _, code in ipairs(WOLF_TYPE_LIST) do
            local g = GetUnitsOfTypeIdAll(code)
            ForGroup(g, function()
                local w = GetEnumUnit()
                if wolfEthereal[w] then
                    DestroyEffect(wolfEthereal[w])
                    wolfEthereal[w] = nil
                end
                RemoveUnit(w)
            end)
            DestroyGroup(g)
        end
    end)

    -- Wolf Ethereal (a wolf spawns): ghostly tint + ziggurat-missile glow (tracked so the glow
    -- is freed when the wolf disperses).
    OnEnterRect(GetPlayableMapRect(), function()
        return WOLF_TYPES[GetUnitTypeId(GetEnteringUnit())] == true
    end, function()
        local w = GetEnteringUnit()
        SetUnitVertexColorBJ(w, 60.0, 100, 100, 50.0)
        wolfEthereal[w] = AddSpecialEffectTarget(WOLF_ETHEREAL_SFX, w, "origin")
    end)

    -- Wolf Wander (a wolf is attacked while >300×rank from its totem): leash it back to the totem.
    OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        if not (WOLF_TYPES[GetUnitTypeId(GetAttacker())] == true) then return false end
        if not (CurrentTotemicSpirit and GetUnitTypeId(CurrentTotemicSpirit) ~= 0) then return false end
        local dx = GetUnitX(GetAttacker()) - GetUnitX(CurrentTotemicSpirit)
        local dy = GetUnitY(GetAttacker()) - GetUnitY(CurrentTotemicSpirit)
        local leash = 300.0 * TotemicSpiritRank
        return dx * dx + dy * dy >= leash * leash
    end, function()
        SetUnitPosition(GetAttacker(),
            GetUnitX(CurrentTotemicSpirit), GetUnitY(CurrentTotemicSpirit))
    end)

    -- Fenrir Ethereal (the ultimate wolf h03G spawns): its own ghostly tint + glow.
    OnEnterRect(GetPlayableMapRect(), function()
        return GetUnitTypeId(GetEnteringUnit()) == FourCC('h03G')
    end, function()
        local f = GetEnteringUnit()
        SetUnitVertexColorBJ(f, 30.0, 0.60, 100, 50.0)
        AddSpecialEffectTarget(WOLF_ETHEREAL_SFX, f, "origin")
    end)

    -- Blood Feast Kill (a H03A kills something): blood splatter + heal him BloodFeast% max HP.
    local bloodFeastT = OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return GetUnitTypeId(GetKillingUnit()) == FourCC('H03A')
    end, function()
        DestroyEffect(AddSpecialEffectTarget(
            "Objects\\Spawnmodels\\Other\\HumanBloodCinematicEffect\\HumanBloodCinematicEffect.mdl",
            GetDyingUnit(), "overhead"))
        local killer = GetKillingUnit()
        SetUnitLifePercentBJ(killer, GetUnitLifePercent(killer) + BloodFeast)
    end)
    DisableTrigger(bloodFeastT)

    -- Blood Feast Learn (A0C0): arm the kill-heal + +4% per rank.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0C0')
    end, function()
        EnableTrigger(bloodFeastT)
        BloodFeast = BloodFeast + 4.0
    end)
end

-- ══ War Guard (H02X) — war3map.j 46318-46599 ═══════════════════════════════════
-- A protector tank. Aid Another (A0AA): for a while, anyone attacking the chosen ally is taunted
-- onto the War Guard. Shield Bash (A0AB): single-target taunt. Perfect Defense (A0AC): a tier-up
-- aura on the e00V dummy that fires Inner Fire on him every 25 hits taken (count resets each 10s).
-- Rescue (A0AI): when the watched ally drops below 20% HP, he blinks to them and shields them
-- invulnerable for 5s. Oath (A0B6): a war-cry sound (its buff is object-data).

-- Perfect Defense: rank → the aura ability the e00V dummy carries (JASS PerfectDefenseAbil[1..5]).
local PERFECT_DEFENSE_ABIL = { FourCC('A0B2'), FourCC('A0B3'), FourCC('A0B4'), FourCC('A0B5'), FourCC('A01V') }

local function setupWarGuard()
    -- Aid Another Eff (an attacker hits the protected ally): taunt them onto the War Guard.
    local aidEffT = OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return GetAttackedUnitBJ() == AidAnother
    end, function()
        local g = GetUnitsOfTypeIdAll(FourCC('H02X'))
        local wg = GroupPickRandomUnit(g)
        DestroyGroup(g)
        if wg then IssueTargetOrder(GetAttacker(), "attack", wg) end
        FloatText(GetAttacker(), "Aid!", 100, 0, 0, 3.0)
    end)
    DisableTrigger(aidEffT)

    -- Aid Another Learn (A0AA): +5s protection per rank.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0AA')
    end, function()
        AidAnotherTimer = AidAnotherTimer + 5.0
    end)

    -- Aid Another (cast A0AA): protect the target for 10 + timer seconds.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0AA')
    end, function()
        AidAnother = GetSpellTargetUnit()
        EnableTrigger(aidEffT)
        TriggerSleepAction(10.0 + AidAnotherTimer)
        DisableTrigger(aidEffT)
    end)

    -- Perfect Defense Eff (the War Guard is attacked): every 25 hits, the dummy Inner Fires him.
    local pdEffT = OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return GetAttackedUnitBJ() == WarGuard
    end, function()
        PerfectDefenseTotalCount = PerfectDefenseTotalCount + 1
        if PerfectDefenseTotalCount >= 25 then
            PerfectDefenseTotalCount = 0
            FloatText(WarGuard, "|cffffff00Perfect Defense!|r", 100, 100, 0, 2.0)
            if unit_e00V and WarGuard then IssueTargetOrder(unit_e00V, "innerfire", WarGuard) end
        end
    end)
    DisableTrigger(pdEffT)

    -- Perfect Defense Reset (every 10s): the hit counter decays so the 25 must come in a burst.
    local pdResetT = CreateTrigger()
    DisableTrigger(pdResetT)
    TriggerRegisterTimerEventPeriodic(pdResetT, 10.0)
    TriggerAddAction(pdResetT, function() PerfectDefenseTotalCount = 0 end)

    -- Perfect Defense Learn (A0AC): swap the dummy's aura up a tier + arm the eff/reset triggers.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0AC')
    end, function()
        if unit_e00V and PERFECT_DEFENSE_ABIL[PerfectDefense] then
            UnitRemoveAbility(unit_e00V, PERFECT_DEFENSE_ABIL[PerfectDefense])
        end
        WarGuard = GetLearningUnit()
        EnableTrigger(pdEffT)
        EnableTrigger(pdResetT)
        PerfectDefense = PerfectDefense + 1
        if unit_e00V and PERFECT_DEFENSE_ABIL[PerfectDefense] then
            UnitAddAbility(unit_e00V, PERFECT_DEFENSE_ABIL[PerfectDefense])
        end
    end)

    -- Shield Bash (cast A0AB): single-target taunt onto the War Guard.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0AB')
    end, function()
        if WarGuard then IssueTargetOrder(GetSpellTargetUnit(), "attack", WarGuard) end
    end)

    -- Rescue Cast (the watched ally is attacked at ≤20% HP): blink in + shield it invuln 5s.
    local rescueCastT = OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return GetAttackedUnitBJ() == RescueTarget and GetUnitLifePercent(GetAttackedUnitBJ()) <= 20.0
    end, function()
        local ally = GetAttackedUnitBJ()
        SetUnitInvulnerable(ally, true)
        FloatText(RescueTarget, "|cff00ff00Rescued!|r", 100, 100, 0, 5.0)
        if WarGuard then
            SetUnitPosition(WarGuard, GetUnitX(ally), GetUnitY(ally))
            PanCameraToTimedForPlayer(GetOwningPlayer(WarGuard),
                GetUnitX(WarGuard), GetUnitY(WarGuard), 0)
        end
        local sfx = AddSpecialEffectTarget(
            "Abilities\\Spells\\Orc\\AncestralSpirit\\AncestralSpiritCaster.mdl", ally, "origin")
        DisableTrigger(GetTriggeringTrigger())
        TriggerSleepAction(5.0)
        SetUnitInvulnerable(ally, false)
        DestroyEffect(sfx)
    end)
    DisableTrigger(rescueCastT)

    -- Rescue (cast A0AI): start watching the target ally.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0AI')
    end, function()
        RescueTarget = GetSpellTargetUnit()
        FloatText(RescueTarget, "Rescue!", 100, 100, 0, 2.0)
        if WarGuard then
            -- Message the War Guard's player directly (GetForceOfPlayer would leak a force/cast).
            DisplayTextToPlayer(GetOwningPlayer(WarGuard), 0, 0,
                "Rescue: " .. GetPlayerName(GetOwningPlayer(RescueTarget)))
        end
        EnableTrigger(rescueCastT)
    end)

    -- Oath of the War Guard (cast A0B6): a war-cry (the actual aura is the ability's object data).
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0B6')
    end, function()
        if snd.HeartLong then PlaySoundBJ(snd.HeartLong) end
    end)
end

-- ══ Sun Soul Initiate (E004) — war3map.j 45762-45901 ═══════════════════════════
-- A radiant monk. Sol Strike (A02H): once cast, the next attack after a rank-scaling number of
-- swings discharges (strips the target's buffs — the spell's proc fires via object data). Aurora
-- Rays (A02I): a 120s aurora that pulses +30 HP to every non-structure, non-neutral unit every 5s.

local function setupSunSoul()
    -- Sol Strike Learn (A02H): +1 to the swings needed before a discharge.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A02H')
    end, function()
        SolStrikeTotalAttacks = SolStrikeTotalAttacks + 1
    end)

    -- Sol Strike On (cast A02H): arm the charge on the caster.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CAST, function()
        return GetSpellAbilityId() == FourCC('A02H')
    end, function()
        SolStrike = GetSpellAbilityUnit()
    end)

    -- Sol Strike Discharge (the charging Initiate attacks): count swings; on the Nth, disarm and
    -- strip the target's buffs. (Faithful quirk: SolStrikeAttacks is never reset, so after the
    -- first full charge later casts discharge on the very first swing — war3map.j 45823.)
    OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return GetAttacker() == SolStrike
    end, function()
        if SolStrikeAttacks >= SolStrikeTotalAttacks then
            local attacker = GetAttacker()
            SolStrike = nil
            TriggerSleepAction(1.0)
            UnitRemoveBuffs(attacker, true, true)
        else
            SolStrikeAttacks = SolStrikeAttacks + 1
        end
    end)

    -- Aurora Rays (cast A02I): a 120s healing aurora — weather + a 5s pulse healing everyone.
    local healT = CreateTrigger()
    DisableTrigger(healT)
    TriggerRegisterTimerEventPeriodic(healT, 5.0)
    TriggerAddAction(healT, function()
        ForUnitsInRect(GetPlayableMapRect(), function()
            local f = GetFilterUnit()
            return not IsUnitType(f, UNIT_TYPE_STRUCTURE) and GetOwningPlayer(f) ~= P8
        end, function()
            local u = GetEnumUnit()
            SetUnitLifeBJ(u, GetUnitState(u, UNIT_STATE_LIFE) + 30.0)
        end)
    end)

    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CAST, function()
        return GetSpellAbilityId() == FourCC('A02I')
    end, function()
        local caster = GetSpellAbilityUnit()
        EnableTrigger(healT)
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(GetOwningPlayer(caster)) .. " casts |cff995500Aurora Rays|r!")
        local beacon = CreateUnit(Player(0), FourCC('e005'),
            GetRectCenterX(rct.ResearchArea), GetRectCenterY(rct.ResearchArea), bj_UNIT_FACING)
        local auroraEffect = AddWeatherEffect(GetPlayableMapRect(), FourCC('LRaa'))
        EnableWeatherEffect(auroraEffect, true)
        TriggerSleepAction(120.0)
        EnableWeatherEffect(auroraEffect, false)
        RemoveWeatherEffect(auroraEffect)   -- free the weather handle (original only disabled it)
        if GetUnitTypeId(beacon) ~= 0 then RemoveUnit(beacon) end
        DisableTrigger(healT)
    end)
end

-- ══ Illusionist (H03I) — war3map.j 43007-43152 ═════════════════════════════════
-- A trickster. Blur (A0CF): every Illusionist shimmers to a random translucency, re-rolled every
-- 10s. Phantasm (A0CH): her o00B phantasms cripple whatever they attack (via the E018 dummy's
-- I073 item), get a Cripple glow on spawn, and illusions spawned under Player(11) transfer to her.

local ILLUSIONIST = FourCC('H03I')
local PHANTASM = FourCC('o00B')

local function blurIllusionists()
    local g = GetUnitsOfTypeIdAll(ILLUSIONIST)
    ForGroup(g, function()
        SetUnitVertexColorBJ(GetEnumUnit(), 100, 100, 100, GetRandomReal(10.0, 80.0))
    end)
    DestroyGroup(g)
end

local function setupIllusionist()
    -- Give the E018 dummy the I073 cripple item once, so its phantasms can proc it (war3map.j 17013).
    local phantasmItem
    if unit_E018 and GetUnitTypeId(unit_E018) ~= 0 then
        phantasmItem = CreateItem(FourCC('I073'), GetUnitX(unit_E018), GetUnitY(unit_E018))
        UnitAddItem(unit_E018, phantasmItem)
    end

    -- Blur (10s periodic, armed on learn): re-roll every Illusionist's translucency.
    local blurT = CreateTrigger()
    DisableTrigger(blurT)
    TriggerRegisterTimerEventPeriodic(blurT, 10.0)
    TriggerAddAction(blurT, blurIllusionists)

    -- Blur Learn (A0CF): shimmer now + arm the periodic re-roll.
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0CF')
    end, function()
        blurIllusionists()
        EnableTrigger(blurT)
    end)

    -- Phantasm Enter (a phantasm spawns): give it a Cripple glow (tracked so it frees on death).
    local phantasmGlow = {}
    OnEnterRect(GetPlayableMapRect(), function()
        return GetUnitTypeId(GetEnteringUnit()) == PHANTASM
    end, function()
        local p = GetEnteringUnit()
        phantasmGlow[p] = AddSpecialEffectTarget(
            "Abilities\\Spells\\Undead\\Cripple\\CrippleTarget.mdl", p, "origin")
    end)
    OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return GetUnitTypeId(GetDyingUnit()) == PHANTASM
    end, function()
        local d = GetDyingUnit()
        if phantasmGlow[d] then
            DestroyEffect(phantasmGlow[d])
            phantasmGlow[d] = nil
        end
    end)

    -- Phantasm (a phantasm attacks a real, non-structure, non-illusion unit): cripple it via the
    -- dummy's item.
    OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        local victim = GetAttackedUnitBJ()
        return GetUnitTypeId(GetAttacker()) == PHANTASM
            and GetUnitTypeId(victim) ~= PHANTASM
            and not IsUnitType(victim, UNIT_TYPE_STRUCTURE)
            and not IsUnitIllusion(victim)
    end, function()
        if unit_E018 and phantasmItem then
            UnitUseItemTarget(unit_E018, phantasmItem, GetAttackedUnitBJ())
        end
    end)

    -- Phantasm Learn (A0CH): record the Illusionist's owner (one-time).
    local learnT
    learnT = OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == FourCC('A0CH')
    end, function()
        IllusionistPlayer = GetOwningPlayer(GetLearningUnit())
        DisableTrigger(learnT)
    end)

    -- Phantasm Give (an illusion spawns under Player(11)): hand it to the Illusionist.
    OnEnterRect(GetPlayableMapRect(), function()
        return IsUnitIllusion(GetEnteringUnit()) and GetOwningPlayer(GetEnteringUnit()) == Player(11)
    end, function()
        if IllusionistPlayer then SetUnitOwner(GetEnteringUnit(), IllusionistPlayer, true) end
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
    setupPaladin()
    setupRockfighter()
    setupTundraBarbarian()
    setupWarGuard()
    setupSunSoul()
    setupIllusionist()
end
