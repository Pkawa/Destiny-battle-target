-- Class achievement detection + level challenge bonus + misc milestone triggers
-- Source: war3map.j 7506–9458
-- Requirements: combat/HeroClassAchievements.md, progression/Achievements.md
--
-- Pattern: each trigger watches a class-specific gameplay milestone, disables itself
-- on hit, and sets a flag + player handle. BonusesAndUpkeep (levels.lua) pays out
-- gold at level end. Flags are reset to false by BonusesAndUpkeep after payout.
--
-- Exposed handles (nil until RegisterAchievementTriggers runs):
--   trg_Level_1_Bonus .. trg_Level_5_Bonus  — enabled by levels 1-5 startLevel
--   trg_EarthenTemplarRageOfEarth           — called when h011 elementals are summoned
--   trg_AxeBrotherSavageFighter             — called by Decimate proc
--   trg_ManAtArmsPayRaise                   — called when WageTotal updates
--   trg_RogueApprenticeAssassin / Veteran / Master — start disabled; Assassinate system enables

-- ── Detection archetype factories ─────────────────────────────────────────────
-- The 23 most repetitive triggers reduce to four shapes. Per-class flags/counters/
-- player handles stay as individual globals (the contract shared with BonusesAndUpkeep,
-- feats.lua, and Phase-7 ability code), so the factories address them by name via _G.
-- Each trigger disables itself once its milestone latches; the flag is reset by the
-- payout pass in levels.lua. (The remaining ~29 triggers have per-trigger quirks and
-- stay written out explicitly below.)

-- Count casts of `abil`; once the counter exceeds `threshold`, latch flag + caster's owner.
local function spellCounter(abil, counter, threshold, flag, playerVar)
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CAST, function()
        return GetSpellAbilityId() == abil
    end, function()
        if _G[counter] > threshold then
            DisableTrigger(GetTriggeringTrigger())
            _G[flag] = true
            _G[playerVar] = GetOwningPlayer(GetSpellAbilityUnit())
        else
            _G[counter] = _G[counter] + 1
        end
    end)
end

-- Cast `abil` on a DIFFERENT hero (not `selfType`) at/below `hpThreshold` life → latch.
local function spellOnOtherHero(abil, selfType, hpThreshold, flag, playerVar)
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_CAST, function()
        return GetSpellAbilityId() == abil
    end, function()
        local tgt = GetSpellTargetUnit()
        if GetUnitTypeId(tgt) ~= selfType
            and GetUnitStateSwap(UNIT_STATE_LIFE, tgt) <= hpThreshold
            and IsUnitType(tgt, UNIT_TYPE_HERO) then
            DisableTrigger(GetTriggeringTrigger())
            _G[flag] = true
            _G[playerVar] = GetOwningPlayer(GetSpellAbilityUnit())
        end
    end)
end

-- Learn `abil` to its 4th rank → latch. `playerVar` may be nil (some classes don't set it).
local function skillRankCounter(abil, counter, flag, playerVar)
    OnAnyUnit(EVENT_PLAYER_HERO_SKILL, function()
        return GetLearnedSkillBJ() == abil
    end, function()
        _G[counter] = _G[counter] + 1
        if _G[counter] == 4 then
            DisableTrigger(GetTriggeringTrigger())
            _G[flag] = true
            if playerVar then _G[playerVar] = GetOwningPlayer(GetLearningUnit()) end
        end
    end)
end

-- `killerType` gets `threshold`+1 kills → latch flag + the killer's owner.
local function killCounter(killerType, counter, threshold, flag, playerVar)
    OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        return GetUnitTypeId(GetKillingUnitBJ()) == killerType
    end, function()
        if _G[counter] > threshold then
            DisableTrigger(GetTriggeringTrigger())
            _G[playerVar] = GetOwningPlayer(GetKillingUnitBJ())
            _G[flag] = true
        else
            _G[counter] = _G[counter] + 1
        end
    end)
end

function RegisterAchievementTriggers()

    -- ── Cleric of Order ───────────────────────────────────────────────────────
    -- BonusA: cast Heal (A002) on a different hero at ≤75 HP (JASS 7486)
    spellOnOtherHero(ABIL.Heal, UID.ClericOfOrder, 75, 'ClericofOrderBonusA', 'ClericofOrderPlayer')

    -- BonusB: cast Mark of Order (A001) when target has >9 units within 350 (JASS 7529)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A001')
        end))
        TriggerAddAction(t, function()
            local tgt = GetSpellTargetUnit()
            local g = CreateGroup()
            GroupEnumUnitsInRange(g, GetUnitX(tgt), GetUnitY(tgt), 350, nil)
            local n = CountUnitsInGroup(g)
            DestroyGroup(g)
            if n > 9 and IsUnitType(tgt, UNIT_TYPE_HERO) then
                DisableTrigger(GetTriggeringTrigger())
                ClericofOrderBonusB = true
                ClericofOrderPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            end
        end)
    end

    -- ── Cleric of the Small Folk ──────────────────────────────────────────────
    -- BonusA: cast Heal (A006) on others >10 times (JASS 7569)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A006')
        end))
        TriggerAddAction(t, function()
            if GetUnitTypeId(GetSpellTargetUnit()) ~= FourCC('H003')
                and ClericSmallFolkHealBonusTotal > 9 then
                DisableTrigger(GetTriggeringTrigger())
                ClericOTSFBonusA = true
                ClericOTSFPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                ClericSmallFolkHealBonusTotal = ClericSmallFolkHealBonusTotal + 1
            end
        end)
    end

    -- BonusB: cast Flurry of Slingstones (A005) >25 times (JASS 7609)
    spellCounter(ABIL.FlurryOfSlingstones, 'ClericSmallFolkSlingshotBonus', 24, 'ClericOTSFBonusB', 'ClericOTSFPlayer')

    -- ── Dwarven Axemaster ─────────────────────────────────────────────────────
    -- BonusA: Living Axe (h00A/h009/h008) kills 10+ units (JASS 7646)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            local id = GetUnitTypeId(GetKillingUnitBJ())
            return id == FourCC('h00A') or id == FourCC('h009') or id == FourCC('h008')
        end))
        TriggerAddAction(t, function()
            if LivingAxeKills > 9 then
                DisableTrigger(GetTriggeringTrigger())
                DwarvenAxeMasterBonusA = true
            else
                LivingAxeKills = LivingAxeKills + 1
                DwarvenAMPlayer = GetOwningPlayer(GetKillingUnitBJ())
            end
        end)
    end

    -- BonusB: all 4 ranks of Aggression (A00C) learned (JASS 7696)
    skillRankCounter(ABIL.Aggression, 'Aggression', 'DwarvenAxeMasterBonusB')

    -- ── Monk of the Ebony Fist ────────────────────────────────────────────────
    -- BonusA: cast Chakra Burst (A00H) with >4 heroes within 600 (JASS 7733)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A00H')
        end))
        TriggerAddAction(t, function()
            local caster = GetSpellAbilityUnit()
            local g = CreateGroup()
            GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 600,
                Condition(function() return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO) end))
            local n = CountUnitsInGroup(g)
            DestroyGroup(g)
            if n > 4 then
                DisableTrigger(GetTriggeringTrigger())
                MonkEFBonusA = true
                MonkEFPlayer = GetOwningPlayer(caster)
            end
        end)
    end

    -- BonusB: Flurry of Blows (A03V) cast 75+ times (JASS 7774)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A03V')
        end))
        TriggerAddAction(t, function()
            FlurryCount = FlurryCount + 1
            if FlurryCount > 74 then
                DisableTrigger(GetTriggeringTrigger())
                MonkEFBonusB = true
                MonkEFPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            end
        end)
    end

    -- ── Rogue of the Dark ─────────────────────────────────────────────────────
    -- All three start disabled. AssassinateCount is incremented by the Assassinate
    -- spell trigger (ported in Phase 7). Enabled when Rogue class is active.
    -- BonusA: 15+ Assassinate uses; Rogue kills any unit (JASS 7812)
    do
        local t = CreateTrigger()
        DisableTrigger(t)
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetKillingUnitBJ()) == FourCC('E001')
                and AssassinateCount > 14
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            RogueOTDBonusA = true
            RogueOTDPlayer = GetOwningPlayer(GetKillingUnitBJ())
        end)
        trg_RogueApprenticeAssassin = t
    end

    -- BonusB: 40+ Assassinate uses (JASS 7842)
    do
        local t = CreateTrigger()
        DisableTrigger(t)
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetKillingUnitBJ()) == FourCC('E001')
                and AssassinateCount > 39
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            RogueOTDBonusB = true
        end)
        trg_RogueVeteranAssassin = t
    end

    -- BonusC: 100+ Assassinate uses (JASS 7871)
    do
        local t = CreateTrigger()
        DisableTrigger(t)
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetKillingUnitBJ()) == FourCC('E001')
                and AssassinateCount > 99
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            RogueOTDBonusC = true
        end)
        trg_RogueMasterAssassin = t
    end

    -- ── Master of the Art ─────────────────────────────────────────────────────
    -- BonusA: Blast (A00K) used 50+ times (JASS 7900)
    spellCounter(ABIL.Blast, 'BlastCast', 49, 'MasterOTABonusA', 'MasterOfTheArtPlayer')

    -- BonusB: Essence Shock (A00L) used 35+ times (JASS 7937)
    spellCounter(ABIL.EssenceShock, 'EssenceShockCast', 34, 'MasterOTABonusB', 'MasterOfTheArtPlayer')

    -- ── Feral Archon ──────────────────────────────────────────────────────────
    -- BonusA: Tantrum (A00X) used 5+ times (JASS 7974)
    spellCounter(ABIL.Tantrum, 'TantrumCast', 4, 'FeralArchonBonus', 'FeralArchonPlayer')

    -- BonusB: O000 (Feral Archon) kills a hero (JASS 8011)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetKillingUnitBJ()) == FourCC('O000')
                and IsUnitType(GetDyingUnit(), UNIT_TYPE_HERO)
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            FeralArchonBonusB = true
            FeralArchonPlayer = GetOwningPlayer(GetKillingUnitBJ())
        end)
    end

    -- ── Human Engineer ────────────────────────────────────────────────────────
    -- BonusA: Master Builder — player has >14 structures when construction starts (JASS 8077)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_CONSTRUCT_START)
        TriggerAddCondition(t, Condition(function()
            local p = GetOwningPlayer(GetConstructingStructure())
            local gEng = GetUnitsOfPlayerAndTypeId(p, FourCC('H00F'))
            local engCount = CountUnitsInGroup(gEng)
            DestroyGroup(gEng)
            if engCount ~= 1 then return false end
            local gStr = CreateGroup()
            GroupEnumUnitsOfPlayer(gStr, p,
                Condition(function() return IsUnitType(GetFilterUnit(), UNIT_TYPE_STRUCTURE) end))
            local strCount = CountUnitsInGroup(gStr)
            DestroyGroup(gStr)
            return strCount > 14
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            HumanEngineerPlayer = GetOwningPlayer(GetConstructingStructure())
            HumanEngineerBonusA = true
        end)
    end

    -- BonusB: Violent Engineer — H00F kills 40+ units (JASS 8040)
    killCounter(UID.HumanEngineer, 'TotalEngyKills', 39, 'HumanEngineerBonusB', 'HumanEngineerPlayer')

    -- ── Earthen Templar ───────────────────────────────────────────────────────
    -- BonusA: Rage of Earth — >5 living Earth Elementals (h011) on map (JASS 8110)
    -- No event. Called via TriggerExecute(trg_EarthenTemplarRageOfEarth) on elemental summon.
    do
        local t = CreateTrigger()
        TriggerAddAction(t, function()
            local g = CreateGroup()
            GroupEnumUnitsInRect(g, GetPlayableMapRect(),
                Condition(function()
                    return GetUnitTypeId(GetFilterUnit()) == FourCC('h011')
                        and GetUnitStateSwap(UNIT_STATE_LIFE, GetFilterUnit()) >= 1
                end))
            local n = CountUnitsInGroup(g)
            local owner = GroupPickRandomUnit(g)
            DestroyGroup(g)
            if n > 5 then
                DisableTrigger(t)
                EarthenTemplarBonusA = true
                if owner then EarthenTemplarPlayer = GetOwningPlayer(owner) end
            end
        end)
        trg_EarthenTemplarRageOfEarth = t
    end

    -- BonusB: Supreme Smasher — H00S kills 100+ units (JASS 8150)
    killCounter(UID.EarthenTemplar, 'TotalETKills', 99, 'EarthenTemplarBonusB', 'EarthenTemplarPlayer')

    -- ── Man-at-Arms ───────────────────────────────────────────────────────────
    -- BonusA: Pay Raise — WageTotal >= 500 (JASS 8205)
    -- No event. Called when HiredWages system awards gold to HiredWagesPlayer.
    do
        local t = CreateTrigger()
        TriggerAddAction(t, function()
            if WageTotal >= 500 then
                DisableTrigger(t)
                ManAtArmsBonusA = true
                ManAtArmsPlayer = HiredWagesPlayer
            end
        end)
        trg_ManAtArmsPayRaise = t
    end

    -- BonusB: Hoarse Throat — Battle Shout (A024) used 15+ times (JASS 8215)
    spellCounter(ABIL.BattleShout, 'BattleShoutCount', 14, 'ManAtArmsBonusB', 'ManAtArmsPlayer')

    -- ── Sun Soul ──────────────────────────────────────────────────────────────
    -- Penalty: E004 kills an ally hero (JASS 8252)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            local killer = GetKillingUnitBJ()
            local dying = GetDyingUnit()
            return GetUnitTypeId(killer) == FourCC('E004')
                and IsUnitType(dying, UNIT_TYPE_HERO)
                and GetOwningPlayer(dying) ~= Player(9)
                and GetOwningPlayer(dying) ~= GetOwningPlayer(killer)
        end))
        TriggerAddAction(t, function()
            SunSoulPenalty = true
            SunSoulPlayer = GetOwningPlayer(GetKillingUnitBJ())
        end)
    end

    -- BonusA: Solar Barrier (A02G) used 10+ times (JASS 8286)
    spellCounter(ABIL.SolarBarrier, 'SolarCount', 9, 'SunSoulBonusA', 'SunSoulPlayer')

    -- BonusB: Sunbeam (A02F) used 15+ times (JASS 8323)
    spellCounter(ABIL.Sunbeam, 'SunbeamCount', 14, 'SunSoulBonusB', 'SunSoulPlayer')

    -- ── Paladin of Justice ────────────────────────────────────────────────────
    -- BonusA: Holy Healer — Lay on Hands (A02M) on another hero at ≤175 HP (JASS 8360)
    spellOnOtherHero(ABIL.LayOnHands, UID.PaladinOfJustice, 175, 'PaladinJusticeBonusA', 'PaladinJusticePlayer')

    -- BonusB: Crusader — H01J kills 50+ units (JASS 8403)
    killCounter(UID.PaladinOfJustice, 'TotalPoJKills', 49, 'PaladinJusticeBonusB', 'PaladinJusticePlayer')

    -- ── Dwarven Rockfighter ───────────────────────────────────────────────────
    -- BonusA: Titan Strength — all 4 ranks of Dwarven Stamina (A037) (JASS 8440)
    skillRankCounter(ABIL.DwarvenStamina, 'DwarvenStamina', 'DwarvenRFBonusA', 'DwarvenRFPlayer')

    -- BonusB: Fearful Presence — Intimidating Shout (A035) hits >9 P9 living units (JASS 8478)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A035')
        end))
        TriggerAddAction(t, function()
            local caster = GetSpellAbilityUnit()
            local range = 45 * GetHeroLevel(caster)
            local g = CreateGroup()
            GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), range,
                Condition(function()
                    return GetOwningPlayer(GetFilterUnit()) == Player(9)
                        and GetUnitStateSwap(UNIT_STATE_LIFE, GetFilterUnit()) >= 1
                end))
            local n = CountUnitsInGroup(g)
            DestroyGroup(g)
            if n > 9 then
                DisableTrigger(GetTriggeringTrigger())
                DwarvenRFBonusB = true
                DwarvenRFPlayer = GetOwningPlayer(caster)
            end
        end)
    end

    -- ── Disciple of Grace ─────────────────────────────────────────────────────
    -- BonusA: Aura of Grace — Moonbeam Rejuvenation (A039) used 20+ times (JASS 8528)
    -- BonusB (Death Ward save) is handled in feats.lua when the Disciple feat is picked.
    spellCounter(ABIL.MoonbeamRejuv, 'DiscipleMRCount', 19, 'DiscipleBonusA', 'DisciplePlayer')

    -- ── Arcane Archer ─────────────────────────────────────────────────────────
    -- BonusA: Power Shot — all 4 ranks of Far Shot (A03J) learned (JASS 8565)
    skillRankCounter(ABIL.FarShot, 'FarShotTotal', 'ArcaneArcherBonusA', 'ArcaneArcherPlayer')

    -- BonusB: Sniper — Eagle Arrow (A03I) used 15+ times (JASS 8603)
    spellCounter(ABIL.EagleArrow, 'EagleArrowTotal', 14, 'ArcaneArcherBonusB', 'ArcaneArcherPlayer')

    -- ── Axe Brother ───────────────────────────────────────────────────────────
    -- BonusA: Whirling Dervish — Whirlwind Attack (A03M) used 20+ times (JASS 8640)
    spellCounter(ABIL.WhirlwindAttack, 'WhirlwindAttack', 19, 'AxeBrotherBonusA', 'AxeBrotherPlayer')

    -- BonusB: Savage Fighter — Decimate procs 50+ times (JASS 8677)
    -- No event. Called by Decimate proc trigger via TriggerExecute(trg_AxeBrotherSavageFighter).
    do
        local t = CreateTrigger()
        TriggerAddCondition(t, Condition(function() return not SavageFighter end))
        TriggerAddAction(t, function()
            if DecimateCount > 49 then
                DisableTrigger(t)
                AxeBrotherBonusB = true
                local g = GetUnitsOfTypeIdAll(FourCC('E006'))
                local u = GroupPickRandomUnit(g)
                if u then AxeBrotherPlayer = GetOwningPlayer(u) end
                DestroyGroup(g)
                SavageFighter = true
            else
                DecimateCount = DecimateCount + 1
            end
        end)
        trg_AxeBrotherSavageFighter = t
    end

    -- ── Centaur Druid ─────────────────────────────────────────────────────────
    -- BonusA: Cultivator — Centaur Druid player begins constructing their 5th structure (JASS 8751)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_CONSTRUCT_START)
        TriggerAddCondition(t, Condition(function()
            local p = GetOwningPlayer(GetConstructingStructure())
            local gCD = GetUnitsOfTypeIdAll(FourCC('H01U'))
            local cd = GroupPickRandomUnit(gCD)
            DestroyGroup(gCD)
            if cd == nil or GetOwningPlayer(cd) ~= p then return false end
            local gStr = CreateGroup()
            GroupEnumUnitsOfPlayer(gStr, p,
                Condition(function() return IsUnitType(GetFilterUnit(), UNIT_TYPE_STRUCTURE) end))
            local n = CountUnitsInGroup(gStr)
            DestroyGroup(gStr)
            return n >= 5
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            CentaurDruidBonusA = true
            CentaurDruidPlayer = GetOwningPlayer(GetConstructingStructure())
        end)
    end

    -- BonusB: Nature's Embrace — treants (structure units) owned by Centaur Druid kill 50+ (JASS 8763)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            local killer = GetKillingUnitBJ()
            if not IsUnitType(killer, UNIT_TYPE_STRUCTURE) then return false end
            local gCD = GetUnitsOfTypeIdAll(FourCC('H01U'))
            local cd = GroupPickRandomUnit(gCD)
            DestroyGroup(gCD)
            return cd ~= nil and GetOwningPlayer(killer) == GetOwningPlayer(cd)
        end))
        TriggerAddAction(t, function()
            if TotalPlantKills > 49 then
                DisableTrigger(GetTriggeringTrigger())
                local gCD = GetUnitsOfTypeIdAll(FourCC('H01U'))
                local cd = GroupPickRandomUnit(gCD)
                DestroyGroup(gCD)
                if cd then CentaurDruidPlayer = GetOwningPlayer(cd) end
                CentaurDruidBonusB = true
            else
                TotalPlantKills = TotalPlantKills + 1
            end
        end)
    end

    -- ── Cleric of Elven Word ──────────────────────────────────────────────────
    -- BonusA: Mender — Regrowth (A05D) on another hero at ≤100 HP (JASS 8803)
    spellOnOtherHero(ABIL.Regrowth, UID.ClericElvenWord, 100, 'ClericElvenWordBonusA', 'ClericEWPlayer')

    -- BonusB: Mistress of Blessings — Elven Blessing (A05C) used 10+ times (JASS 8846)
    spellCounter(ABIL.ElvenBlessing, 'ElvenBlessingCount', 9, 'ClericElvenWordBonusB', 'ClericEWPlayer')

    -- ── Crested Drake ─────────────────────────────────────────────────────────
    -- BonusA: Firebreather — Flame Wreath (A05F) used 25+ times (JASS 8883)
    spellCounter(ABIL.FlameWreath, 'FlameWreathCount', 24, 'CrestedDrakeBonusA', 'CrestedDrakePlayer')

    -- BonusB: Fangterror — all 4 ranks of Drakefang (A05H) learned (JASS 8920)
    skillRankCounter(ABIL.Drakefang, 'DrakeFangCount', 'CrestedDrakeBonusB', 'CrestedDrakePlayer')

    -- ── Reckless Pyromancer ───────────────────────────────────────────────────
    -- Penalty: E00E kills an ally hero with a spell (JASS 8958)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            local killer = GetKillingUnitBJ()
            local dying = GetDyingUnit()
            return GetUnitTypeId(killer) == FourCC('E00E')
                and IsUnitType(dying, UNIT_TYPE_HERO)
                and GetOwningPlayer(dying) ~= Player(9)
                and GetOwningPlayer(dying) ~= GetOwningPlayer(killer)
        end))
        TriggerAddAction(t, function()
            MajinPenalty = true
            MajinPlayer = GetOwningPlayer(GetKillingUnitBJ())
        end)
    end

    -- ── Elven Sharpshooter ────────────────────────────────────────────────────
    -- Survivalist: SharpshooterBonusA starts true; cleared if H02N dies (JASS 8992)
    -- BonusesAndUpkeep pays out only if flag survived through level 10.
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetDyingUnit()) == FourCC('H02N')
                and IsUnitType(GetDyingUnit(), UNIT_TYPE_HERO)
        end))
        TriggerAddAction(t, function()
            SharpshooterBonusA = false
        end)
    end

    -- Kill Shots: Sniper's Mark target killed by Sharpshooter, 11+ times (JASS 9019)
    -- SniperMarkTarget is set by the Sniper's Mark ability trigger (Phase 7).
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            if GetDyingUnit() ~= SniperMarkTarget then return false end
            local gSS = GetUnitsOfTypeIdAll(FourCC('H02N'))
            local ss = GroupPickRandomUnit(gSS)
            DestroyGroup(gSS)
            return ss ~= nil and GetOwningPlayer(GetKillingUnitBJ()) == GetOwningPlayer(ss)
        end))
        TriggerAddAction(t, function()
            if SniperMarkKills > 10 then
                DisableTrigger(GetTriggeringTrigger())
                SharpshooterPlayer = GetOwningPlayer(GetKillingUnitBJ())
                SharpshooterBonusB = true
            else
                SniperMarkKills = SniperMarkKills + 1
            end
        end)
    end

    -- ── Plant Hater (Level 13) ────────────────────────────────────────────────
    -- PlantHater = true when all h018 (Ents) of P9 are killed (JASS 9350)
    do
        local t = CreateTrigger()
        TriggerRegisterPlayerUnitEventSimple(t, Player(9), EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetDyingUnit()) == FourCC('h018')
        end))
        TriggerAddAction(t, function()
            if CountLivingPlayerUnitsOfTypeId(FourCC('h018'), Player(9)) == 0 then
                PlantHater = true
            end
        end)
    end

    -- ── Milestone: First to Ding / Build / Research ───────────────────────────
    -- First hero to level up (not P8) (JASS 9383)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_HERO_LEVEL)
        TriggerAddCondition(t, Condition(function()
            return GetOwningPlayer(GetTriggerUnit()) ~= Player(8)
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            FirstToDingOn = true
            FirstToDing = GetOwningPlayer(GetLevelingUnit())
        end)
    end

    -- First to buy a Silmeria Defense Kit (h036 sold from shop) (JASS 9407)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SELL_ITEM)
        TriggerAddCondition(t, Condition(function()
            return GetItemTypeId(GetSoldItem()) == FourCC('h036')
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            bonusFirstToBuildOn = true
            FirstToBuild = GetOwningPlayer(GetBuyingUnit())
        end)
    end

    -- First to research at h00Z or h01L (JASS 9431)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_RESEARCH_FINISH)
        TriggerAddCondition(t, Condition(function()
            local id = GetUnitTypeId(GetResearchingUnit())
            return id == FourCC('h00Z') or id == FourCC('h01L')
        end))
        TriggerAddAction(t, function()
            DisableTrigger(GetTriggeringTrigger())
            bonusFirstToResearchOn = true
            FirstToResearch = GetOwningPlayer(GetResearchingUnit())
        end)
    end

    -- ── Level challenge bonus triggers (start disabled; enabled at level N start) ─
    -- Level 1: no P9 unit crosses the halfway markers (JASS 9167)
    do
        local t = CreateTrigger()
        TriggerRegisterEnterRectSimple(t, rct.HalfwayMarkerA)
        TriggerRegisterEnterRectSimple(t, rct.HalfwayMarkerB)
        TriggerRegisterEnterRectSimple(t, rct.HalfwayMarkerC)
        TriggerAddCondition(t, Condition(function()
            return GetOwningPlayer(GetEnteringUnit()) == Player(9)
        end))
        TriggerAddAction(t, function()
            LevelBonuses[1] = false
            DisableTrigger(GetTriggeringTrigger())
        end)
        DisableTrigger(t)
        trg_Level_1_Bonus = t
    end

    -- Level 2: a Footman (h002) dies while SquireCapKills ≤ 3 (JASS 9200)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetDyingUnit()) == FourCC('h002') and SquireCapKills <= 3
        end))
        TriggerAddAction(t, function()
            LevelBonuses[2] = false
            DisableTrigger(GetTriggeringTrigger())
        end)
        DisableTrigger(t)
        trg_Level_2_Bonus = t
    end

    -- Level 2 Add: Squire Captain (h005) dies → SquireCapKills++ (JASS 9228)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetDyingUnit()) == FourCC('h005')
        end))
        TriggerAddAction(t, function()
            SquireCapKills = SquireCapKills + 1
        end)
        DisableTrigger(t)
        trg_Level_2_Bonus_Add = t
    end

    -- Level 3: any n001 (archer) attacks a P8 structure (JASS 9253)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_ATTACKED)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetAttacker()) == FourCC('n001')
                and IsUnitType(GetAttackedUnitBJ(), UNIT_TYPE_STRUCTURE)
                and GetOwningPlayer(GetAttackedUnitBJ()) == Player(8)
        end))
        TriggerAddAction(t, function()
            LevelBonuses[3] = false
            DisableTrigger(GetTriggeringTrigger())
        end)
        DisableTrigger(t)
        trg_Level_3_Bonus = t
    end

    -- Level 4: any h006 unit dies (JASS 9286)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetDyingUnit()) == FourCC('h006')
        end))
        TriggerAddAction(t, function()
            LevelBonuses[4] = false
            DisableTrigger(GetTriggeringTrigger())
        end)
        DisableTrigger(t)
        trg_Level_4_Bonus = t
    end

    -- Level 5: 4+ spells target a P9 h00B (Knight) (JASS 9313)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_EFFECT)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetSpellTargetUnit()) == FourCC('h00B')
                and GetOwningPlayer(GetSpellTargetUnit()) == Player(9)
        end))
        TriggerAddAction(t, function()
            Lv5SpellBonus = Lv5SpellBonus + 1
            if Lv5SpellBonus >= 4 then
                LevelBonuses[5] = false
                DisableTrigger(GetTriggeringTrigger())
            end
        end)
        DisableTrigger(t)
        trg_Level_5_Bonus = t
    end
end
