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

function RegisterAchievementTriggers()

    -- ── Cleric of Order ───────────────────────────────────────────────────────
    -- BonusA: cast Heal (A002) on a different hero at ≤75 HP (JASS 7486)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A002')
        end))
        TriggerAddAction(t, function()
            local tgt = GetSpellTargetUnit()
            if GetUnitTypeId(tgt) ~= FourCC('H001')
                and GetUnitStateSwap(UNIT_STATE_LIFE, tgt) <= 75
                and IsUnitType(tgt, UNIT_TYPE_HERO) then
                DisableTrigger(GetTriggeringTrigger())
                ClericofOrderBonusA = true
                ClericofOrderPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A005')
        end))
        TriggerAddAction(t, function()
            if ClericSmallFolkSlingshotBonus > 24 then
                DisableTrigger(GetTriggeringTrigger())
                ClericOTSFBonusB = true
                ClericOTSFPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                ClericSmallFolkSlingshotBonus = ClericSmallFolkSlingshotBonus + 1
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_HERO_SKILL)
        TriggerAddCondition(t, Condition(function()
            return GetLearnedSkillBJ() == FourCC('A00C')
        end))
        TriggerAddAction(t, function()
            Aggression = Aggression + 1
            if Aggression == 4 then
                DisableTrigger(GetTriggeringTrigger())
                DwarvenAxeMasterBonusB = true
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A00K')
        end))
        TriggerAddAction(t, function()
            if BlastCast > 49 then
                DisableTrigger(GetTriggeringTrigger())
                MasterOTABonusA = true
                MasterOfTheArtPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                BlastCast = BlastCast + 1
            end
        end)
    end

    -- BonusB: Essence Shock (A00L) used 35+ times (JASS 7937)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A00L')
        end))
        TriggerAddAction(t, function()
            if EssenceShockCast > 34 then
                DisableTrigger(GetTriggeringTrigger())
                MasterOTABonusB = true
                MasterOfTheArtPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                EssenceShockCast = EssenceShockCast + 1
            end
        end)
    end

    -- ── Feral Archon ──────────────────────────────────────────────────────────
    -- BonusA: Tantrum (A00X) used 5+ times (JASS 7974)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A00X')
        end))
        TriggerAddAction(t, function()
            if TantrumCast > 4 then
                DisableTrigger(GetTriggeringTrigger())
                FeralArchonBonus = true
                FeralArchonPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                TantrumCast = TantrumCast + 1
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetKillingUnitBJ()) == FourCC('H00F')
        end))
        TriggerAddAction(t, function()
            if TotalEngyKills > 39 then
                DisableTrigger(GetTriggeringTrigger())
                HumanEngineerPlayer = GetOwningPlayer(GetKillingUnitBJ())
                HumanEngineerBonusB = true
            else
                TotalEngyKills = TotalEngyKills + 1
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetKillingUnitBJ()) == FourCC('H00S')
        end))
        TriggerAddAction(t, function()
            if TotalETKills > 99 then
                DisableTrigger(GetTriggeringTrigger())
                EarthenTemplarPlayer = GetOwningPlayer(GetKillingUnitBJ())
                EarthenTemplarBonusB = true
            else
                TotalETKills = TotalETKills + 1
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A024')
        end))
        TriggerAddAction(t, function()
            if BattleShoutCount > 14 then
                DisableTrigger(GetTriggeringTrigger())
                ManAtArmsBonusB = true
                ManAtArmsPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                BattleShoutCount = BattleShoutCount + 1
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A02G')
        end))
        TriggerAddAction(t, function()
            if SolarCount > 9 then
                DisableTrigger(GetTriggeringTrigger())
                SunSoulPlayer = GetOwningPlayer(GetSpellAbilityUnit())
                SunSoulBonusA = true
            else
                SolarCount = SolarCount + 1
            end
        end)
    end

    -- BonusB: Sunbeam (A02F) used 15+ times (JASS 8323)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A02F')
        end))
        TriggerAddAction(t, function()
            if SunbeamCount > 14 then
                DisableTrigger(GetTriggeringTrigger())
                SunSoulPlayer = GetOwningPlayer(GetSpellAbilityUnit())
                SunSoulBonusB = true
            else
                SunbeamCount = SunbeamCount + 1
            end
        end)
    end

    -- ── Paladin of Justice ────────────────────────────────────────────────────
    -- BonusA: Holy Healer — Lay on Hands (A02M) on another hero at ≤175 HP (JASS 8360)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A02M')
        end))
        TriggerAddAction(t, function()
            local tgt = GetSpellTargetUnit()
            if GetUnitTypeId(tgt) ~= FourCC('H01J')
                and GetUnitStateSwap(UNIT_STATE_LIFE, tgt) <= 175
                and IsUnitType(tgt, UNIT_TYPE_HERO) then
                DisableTrigger(GetTriggeringTrigger())
                PaladinJusticeBonusA = true
                PaladinJusticePlayer = GetOwningPlayer(GetSpellAbilityUnit())
            end
        end)
    end

    -- BonusB: Crusader — H01J kills 50+ units (JASS 8403)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetKillingUnitBJ()) == FourCC('H01J')
        end))
        TriggerAddAction(t, function()
            if TotalPoJKills > 49 then
                DisableTrigger(GetTriggeringTrigger())
                PaladinJusticePlayer = GetOwningPlayer(GetKillingUnitBJ())
                PaladinJusticeBonusB = true
            else
                TotalPoJKills = TotalPoJKills + 1
            end
        end)
    end

    -- ── Dwarven Rockfighter ───────────────────────────────────────────────────
    -- BonusA: Titan Strength — all 4 ranks of Dwarven Stamina (A037) (JASS 8440)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_HERO_SKILL)
        TriggerAddCondition(t, Condition(function()
            return GetLearnedSkillBJ() == FourCC('A037')
        end))
        TriggerAddAction(t, function()
            DwarvenStamina = DwarvenStamina + 1
            if DwarvenStamina == 4 then
                DisableTrigger(GetTriggeringTrigger())
                DwarvenRFBonusA = true
                DwarvenRFPlayer = GetOwningPlayer(GetLearningUnit())
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A039')
        end))
        TriggerAddAction(t, function()
            if DiscipleMRCount > 19 then
                DisableTrigger(GetTriggeringTrigger())
                DiscipleBonusA = true
                DisciplePlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                DiscipleMRCount = DiscipleMRCount + 1
            end
        end)
    end

    -- ── Arcane Archer ─────────────────────────────────────────────────────────
    -- BonusA: Power Shot — all 4 ranks of Far Shot (A03J) learned (JASS 8565)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_HERO_SKILL)
        TriggerAddCondition(t, Condition(function()
            return GetLearnedSkillBJ() == FourCC('A03J')
        end))
        TriggerAddAction(t, function()
            FarShotTotal = FarShotTotal + 1
            if FarShotTotal == 4 then
                DisableTrigger(GetTriggeringTrigger())
                ArcaneArcherBonusA = true
                ArcaneArcherPlayer = GetOwningPlayer(GetLearningUnit())
            end
        end)
    end

    -- BonusB: Sniper — Eagle Arrow (A03I) used 15+ times (JASS 8603)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A03I')
        end))
        TriggerAddAction(t, function()
            if EagleArrowTotal > 14 then
                DisableTrigger(GetTriggeringTrigger())
                ArcaneArcherBonusB = true
                ArcaneArcherPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                EagleArrowTotal = EagleArrowTotal + 1
            end
        end)
    end

    -- ── Axe Brother ───────────────────────────────────────────────────────────
    -- BonusA: Whirling Dervish — Whirlwind Attack (A03M) used 20+ times (JASS 8640)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A03M')
        end))
        TriggerAddAction(t, function()
            if WhirlwindAttack > 19 then
                DisableTrigger(GetTriggeringTrigger())
                AxeBrotherBonusA = true
                AxeBrotherPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                WhirlwindAttack = WhirlwindAttack + 1
            end
        end)
    end

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
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A05D')
        end))
        TriggerAddAction(t, function()
            local tgt = GetSpellTargetUnit()
            if GetUnitTypeId(tgt) ~= FourCC('H02C')
                and GetUnitStateSwap(UNIT_STATE_LIFE, tgt) <= 100
                and IsUnitType(tgt, UNIT_TYPE_HERO) then
                DisableTrigger(GetTriggeringTrigger())
                ClericElvenWordBonusA = true
                ClericEWPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            end
        end)
    end

    -- BonusB: Mistress of Blessings — Elven Blessing (A05C) used 10+ times (JASS 8846)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A05C')
        end))
        TriggerAddAction(t, function()
            if ElvenBlessingCount > 9 then
                DisableTrigger(GetTriggeringTrigger())
                ClericElvenWordBonusB = true
                ClericEWPlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                ElvenBlessingCount = ElvenBlessingCount + 1
            end
        end)
    end

    -- ── Crested Drake ─────────────────────────────────────────────────────────
    -- BonusA: Firebreather — Flame Wreath (A05F) used 25+ times (JASS 8883)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
        TriggerAddCondition(t, Condition(function()
            return GetSpellAbilityId() == FourCC('A05F')
        end))
        TriggerAddAction(t, function()
            if FlameWreathCount > 24 then
                DisableTrigger(GetTriggeringTrigger())
                CrestedDrakeBonusA = true
                CrestedDrakePlayer = GetOwningPlayer(GetSpellAbilityUnit())
            else
                FlameWreathCount = FlameWreathCount + 1
            end
        end)
    end

    -- BonusB: Fangterror — all 4 ranks of Drakefang (A05H) learned (JASS 8920)
    do
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_HERO_SKILL)
        TriggerAddCondition(t, Condition(function()
            return GetLearnedSkillBJ() == FourCC('A05H')
        end))
        TriggerAddAction(t, function()
            DrakeFangCount = DrakeFangCount + 1
            if DrakeFangCount == 4 then
                DisableTrigger(GetTriggeringTrigger())
                CrestedDrakeBonusB = true
                CrestedDrakePlayer = GetOwningPlayer(GetLearningUnit())
            end
        end)
    end

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
