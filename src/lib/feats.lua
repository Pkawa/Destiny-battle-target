-- Feat selection system
-- Requirements: hero-selection/HeroSelection.md (Pick_Feat), war3map.j ~14400-16700
--
-- Each feat is an item sold by the feat shops (n00J/n00E/n00B/n00L). Buying one
-- fires EVENT_PLAYER_UNIT_PICKUP_ITEM. The reference has ~44 individual feat
-- triggers, all sharing this flow:
--   remove item -> move hero to StartingPlayerArea -> apply effect -> Start_Game_After_Feats
--
-- This module implements that flow generically for every feat item, with real
-- effects for the simple stat feats. Moving the hero out of EntireFeatArea fires
-- the leave-rect trigger in hero_selection.lua (CheckAllLeftFeatArea), which starts
-- the game once all heroes have picked.
--
-- The reference set its per-feat hero global AFTER a 2s sleep, which let a fast
-- player buy two feats. We set FeatPicked immediately (no sleep) so a second
-- purchase is rejected — fixes the double-feat exploit.

FeatPicked = {}  -- [playerId] = true once that player has chosen a feat

-- Heroes that gain a per-level-up bonus, and the function that applies it.
local statLevelHeroes = {}  -- [heroHandle] = function(hero)

-- ── Feat registry: itemId(int) -> { name = string, onPick = function(hero) } ──
local featRegistry = {}

-- All feat item codes carried by the four feat shops (object data useu/usei lists).
-- Items without a specific effect below still register as feats so the pick flow
-- (move out + one-feat-per-player guard) works; their effect is a no-op for now.
local ALL_FEAT_ITEMS = {
    -- n00B
    'I02J','I02K','I02B','I02C','I02A','I02D','I02H','I02E','I02G','I02I','I02F',
    -- n00E
    'I03W','I02L','I02M','I02N','I02O','I02P','I03U','I02S','I03V','I02V','I03T',
    -- n00J
    'I08L','I083','I02Q','I04U','I04W','I04Y','I051','I053','I052','I04Z','I04V',
    -- n00L
    'I09I','I09G','I09H','I09B','I099','I098','I097','I07Y','I081','I080','I07Z','I082',
}

-- Register a feat that grants a stat (or armor) bonus every hero level-up.
-- The original applies these via a hidden level-up trigger with no ability, so nothing
-- showed on the hero. We additionally grant a cosmetic display passive (`displayAbil`,
-- authored in objediting/main.lua) so the feat appears as a command-card skill, and the
-- `desc` is shown in the pick message (matches the original's "(+2 STR per Level Up.)").
local function registerStatFeat(itemCode, featName, desc, displayAbil, applyFn)
    local abil = FourCC(displayAbil)
    featRegistry[FourCC(itemCode)] = {
        name = featName,
        desc = desc,
        onPick = function(hero)
            UnitAddAbilityBJ(abil, hero)        -- command-card display passive (objediting)
            statLevelHeroes[hero] = applyFn     -- actual +stat applied on each level-up
        end,
    }
end

-- Extra Strong / Fast / Smart — +2 of a stat per level (war3map.j 15046-15217)
registerStatFeat('I02A', "Extra Strong", "+2 STR per Level Up",   'fea1', function(h) ModifyHeroStat(bj_HEROSTAT_STR, h, bj_MODIFYMETHOD_ADD, 2) end)
registerStatFeat('I02B', "Extra Fast",   "+2 AGI per Level Up",   'fea2', function(h) ModifyHeroStat(bj_HEROSTAT_AGI, h, bj_MODIFYMETHOD_ADD, 2) end)
registerStatFeat('I02C', "Extra Smart",  "+2 INT per Level Up",   'fea3', function(h) ModifyHeroStat(bj_HEROSTAT_INT, h, bj_MODIFYMETHOD_ADD, 2) end)
-- Iron Skin — +1 armor per level (war3map.j 15220-15266)
registerStatFeat('I02V', "Iron Skin",    "+1 Armor per Level Up", 'fea4', function(h) BlzSetUnitArmor(h, BlzGetUnitArmor(h) + 1) end)

-- Familiar — spawn a random animal companion (war3map.j 14428-14456)
featRegistry[FourCC('I03T')] = {
    name = "Familiar",
    onPick = function(hero)
        local owner = GetOwningPlayer(hero)
        local pets = { FourCC('h02I'), FourCC('h02K'), FourCC('h02J') }
        local pet = CreateUnit(owner, pets[GetRandomInt(1, 3)],
            GetRectCenterX(rct.StartingPlayerArea), GetRectCenterY(rct.StartingPlayerArea), bj_UNIT_FACING)
        FamiliarPet  = pet
        FamiliarHero = hero
    end,
}

-- ── Ability feats: grant the hero a passive/active skill (war3map.j 14730-16118) ──
-- These are the feats that "appear as a skill" on the command card. Each does
-- UnitAddAbilityBJ(<ability>, hero) in the original; the item token is consumed.
local function registerAbilityFeat(itemCode, featName, desc, abilityCode)
    local abil = FourCC(abilityCode)
    featRegistry[FourCC(itemCode)] = {
        name = featName, desc = desc,
        onPick = function(hero) UnitAddAbilityBJ(abil, hero) end,
    }
end
registerAbilityFeat('I02M', "Acrobat",         "+10% Evasion",             'A063')
registerAbilityFeat('I02L', "Fleetfooted",     "Hero moves faster",        'A078')
registerAbilityFeat('I02P', "Weapon Focus",    "Never misses",             'A066')
registerAbilityFeat('I03U', "Snakeblood",      "Reflect 50% of damage",    'A064')
registerAbilityFeat('I02S', "Weapon Finesse",  "+30% Attack Speed",        'A079')
registerAbilityFeat('I02G', "Spell Eater",     "Blocks harmful spells",    'A05X')
registerAbilityFeat('I02N', "First Aid",       "Learns a healing spell",   'A060')
registerAbilityFeat('I02H', "Magic Prodigy",   "+50% Mana Regen",          'A05Y')
registerAbilityFeat('I02I', "Troll Blood",     "+5 HP/sec Regen",          'A05Z')
registerAbilityFeat('I02E', "Numb Body",       "Damage Soak 3/-",          'A05W')
registerAbilityFeat('I02K', "Combat Mastery",  "Chance to critically hit", 'A062')
registerAbilityFeat('I02J', "Charismatic",     "Aura of Leadership",       'A061')
registerAbilityFeat('I04U', "Natural Balance", "-25% ranged damage taken", 'A095')

-- Wealthy (I02F, war3map.j 14730) — passive bonus-gold ability + a one-time 600 gold.
featRegistry[FourCC('I02F')] = {
    name = "Wealthy", desc = "+600 Gold",
    onPick = function(hero)
        UnitAddAbilityBJ(FourCC('A05V'), hero)
        AdjustPlayerStateBJ(600, GetOwningPlayer(hero), PLAYER_STATE_RESOURCE_GOLD)
    end,
}

-- Jack of All Trades (I03V, war3map.j 14932) — +8 to all stats immediately.
featRegistry[FourCC('I03V')] = {
    name = "Jack of All Trades", desc = "+8 to all stats",
    onPick = function(hero)
        ModifyHeroStat(bj_HEROSTAT_STR, hero, bj_MODIFYMETHOD_ADD, 8)
        ModifyHeroStat(bj_HEROSTAT_AGI, hero, bj_MODIFYMETHOD_ADD, 8)
        ModifyHeroStat(bj_HEROSTAT_INT, hero, bj_MODIFYMETHOD_ADD, 8)
    end,
}

-- ── Flag feats: set a global the (already-ported) consuming system reads ──
local function registerFlagFeat(itemCode, featName, desc, applyFn)
    featRegistry[FourCC(itemCode)] = { name = featName, desc = desc, onPick = applyFn }
end
registerFlagFeat('I02Q', "Miser",        "No gold lost on death",      function(h) MiserPlayer = GetOwningPlayer(h) end)
registerFlagFeat('I07Y', "Artificier",   "Better artifact odds",       function()  ArtificierFeatOn = true end)
registerFlagFeat('I07Z', "Meteorologist","50% chance to deny bad weather", function() MeteorlogistFeatOn = true end)
registerFlagFeat('I09G', "Champion of the Fallen", "Last hero alive recovers full HP", function() ChampionOfTheFallenFeat = true end)

-- ── Per-level HP / Mana / Damage scaling feats ────────────────────────────────
-- Same pattern as registerStatFeat but use BlzSet* instead of ModifyHeroStat.

-- Hardiness (I02D, war3map.j 14893-14985) — +50 Max HP per level
featRegistry[FourCC('I02D')] = {
    name = "Hardiness", desc = "+50 Max HP per Level Up",
    onPick = function(hero)
        statLevelHeroes[hero] = function(h) BlzSetUnitMaxHP(h, BlzGetUnitMaxHP(h) + 50) end
    end,
}

-- Mana Mastery (I03W, war3map.j 14988-15043) — +50 Max Mana per level
featRegistry[FourCC('I03W')] = {
    name = "Mana Mastery", desc = "+50 Max Mana per Level Up",
    onPick = function(hero)
        statLevelHeroes[hero] = function(h) BlzSetUnitMaxMana(h, BlzGetUnitMaxMana(h) + 50) end
    end,
}

-- Brute Force (I083, war3map.j 15682-15738) — +3 base damage per level
featRegistry[FourCC('I083')] = {
    name = "Brute Force", desc = "+3 base damage per Level Up",
    onPick = function(hero)
        statLevelHeroes[hero] = function(h)
            BlzSetUnitBaseDamage(h, BlzGetUnitBaseDamage(h, 0) + 3, 0)
        end
    end,
}

-- ── Immediate combat-modifier feats ───────────────────────────────────────────

-- Power Attack (I02O, war3map.j 15307-15336): double damage output, double cooldown.
featRegistry[FourCC('I02O')] = {
    name = "Power Attack", desc = "Double damage, halved attack speed",
    onPick = function(hero)
        BlzSetUnitAttackCooldown(hero, BlzGetUnitAttackCooldown(hero, 1) * 2.0, 0)
        BlzSetUnitBaseDamage(hero, BlzGetUnitBaseDamage(hero, 1) * 2, 0)
        BlzSetUnitDiceNumber(hero, BlzGetUnitDiceNumber(hero, 1) * 2, 0)
        BlzSetUnitDiceSides(hero, BlzGetUnitDiceSides(hero, 1) * 2, 0)
    end,
}

-- Apothecary (I052, war3map.j 15787-15814): random poison ability.
featRegistry[FourCC('I052')] = {
    name = "Apothecary", desc = "Coats attacks in a random poison",
    onPick = function(hero)
        local poisons = { FourCC('A08Z'), FourCC('A091'), FourCC('A090') }
        UnitAddAbilityBJ(poisons[GetRandomInt(1, 3)], hero)
    end,
}

-- Combat Veteran / "Improvisational Combat" (I051, war3map.j 15073-15101):
-- +2 all stats, +3 dmg, -10% cooldown, +2 armor.
featRegistry[FourCC('I051')] = {
    name = "Combat Veteran", desc = "+2 all stats, +3 dmg, 10% faster atk, +2 armor",
    onPick = function(hero)
        ModifyHeroStat(bj_HEROSTAT_STR, hero, bj_MODIFYMETHOD_ADD, 2)
        ModifyHeroStat(bj_HEROSTAT_AGI, hero, bj_MODIFYMETHOD_ADD, 2)
        ModifyHeroStat(bj_HEROSTAT_INT, hero, bj_MODIFYMETHOD_ADD, 2)
        BlzSetUnitBaseDamage(hero, BlzGetUnitBaseDamage(hero, 0) + 3, 0)
        BlzSetUnitAttackCooldown(hero, BlzGetUnitAttackCooldown(hero, 0) * 0.90, 0)
        BlzSetUnitArmor(hero, BlzGetUnitArmor(hero) + 2.0)
    end,
}

-- ── Team feats (give +100 XP on pick plus a team-wide effect) ─────────────────
local function xp100(hero) AddHeroXP(hero, 100, false) end

-- Fortuitous (I081, war3map.j 16249-16276): +100 XP, drops increase (ItemDropTotal -=5)
featRegistry[FourCC('I081')] = {
    name = "Fortuitous", desc = "+100 XP, +10% item drop rate",
    onPick = function(hero)
        xp100(hero)
        ItemDropTotal = ItemDropTotal - 5
    end,
}

-- Scribe (I082, war3map.j 16279-16306): +100 XP, scroll drop rate increases.
featRegistry[FourCC('I082')] = {
    name = "Scribe", desc = "+100 XP, increased scroll drop rate",
    onPick = function(hero)
        xp100(hero)
        TotalScrollDrop = 180
    end,
}

-- Pillar of Light (I080, war3map.j 16218-16238): +100 XP, Prince starts at level 10.
featRegistry[FourCC('I080')] = {
    name = "Pillar of Light", desc = "+100 XP, Princess Silmeria starts at level 10",
    onPick = function(hero)
        xp100(hero)
        if unit_H02G then SetHeroLevelBJ(unit_H02G, 10, true) end
    end,
}

-- Architect (I097, war3map.j 16367-16397): +100 XP, extra plot + building HP research.
featRegistry[FourCC('I097')] = {
    name = "Architect", desc = "+100 XP, extra build plot, +100% building HP",
    onPick = function(hero)
        xp100(hero)
        SetPlayerTechResearchedSwap(FourCC('R00T'), 1, Player(8))
        SetPlayerTechResearchedSwap(FourCC('R00D'), 1, Player(8))
        CreateNUnitsAtLoc(1, FourCC('h036'), Player(8),
            GetRectCenter(rct.ArchitectPlotPoint), bj_UNIT_FACING)
    end,
}

-- General (I098, war3map.j 16399-16428): +100 XP, +15 food supply unit + army unit.
featRegistry[FourCC('I098')] = {
    name = "General", desc = "+100 XP, +15 food supply, extra army unit",
    onPick = function(hero)
        xp100(hero)
        local owner = GetOwningPlayer(hero)
        CreateNUnitsAtLoc(1, FourCC('h06N'), owner,
            GetRandomLocInRect(rct.HeroFeatArea), bj_UNIT_FACING)
        CreateNUnitsAtLoc(1, FourCC('h04B'), owner,
            GetRectCenter(rct.StartingPlayerArea), bj_UNIT_FACING)
    end,
}

-- Scholar (I099, war3map.j 16430-16483): +100 XP, each future research gives all heroes EXP.
-- Scholar_Research_Bonus: starts at 30 XP, grows by 10 per research.
ResearchBonus = 0
featRegistry[FourCC('I099')] = {
    name = "Scholar", desc = "+100 XP, researches earn bonus EXP for all heroes",
    onPick = function(hero)
        xp100(hero)
        local trg = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_RESEARCH_FINISH)
        TriggerAddAction(trg, function()
            local xp = 30 + ResearchBonus
            DisplayTextToForce(GetPlayersAll(),
                "|cff32cd32Research Experience Bonus: |r" .. tostring(xp))
            local heroes = GetUnitsInRectMatching(GetPlayableMapRect(),
                Condition(function() return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO) end))
            ForGroup(heroes, function() AddHeroXP(GetEnumUnit(), xp, true) end)
            DestroyGroup(heroes)
            ResearchBonus = ResearchBonus + 10
        end)
    end,
}

-- Master of the Well (I09B, war3map.j 16486-16535):
-- +100 XP, well researches, fountain restores 50% mana at end of each round.
MasterOfWellActive = false
featRegistry[FourCC('I09B')] = {
    name = "Master of the Well", desc = "+100 XP, doubled well capacity, fountain mana restore per round",
    onPick = function(hero)
        xp100(hero)
        MasterOfWellActive = true
        SetPlayerTechResearchedSwap(FourCC('R02K'), 1, Player(8))
        SetPlayerTechResearchedSwap(FourCC('R02L'), 1, Player(8))
    end,
}

-- Trained Guardians (I09H, war3map.j 16567-16596):
-- +100 XP, city garrison units upgraded (+HP/dmg/armor).
featRegistry[FourCC('I09H')] = {
    name = "Trained Guardians", desc = "+100 XP, city garrison units gain HP/damage/armor",
    onPick = function(hero)
        xp100(hero)
        SetPlayerTechResearchedSwap(FourCC('R00U'), 1, Player(8))
        SetPlayerTechResearchedSwap(FourCC('R00V'), 1, Player(8))
    end,
}

-- Herbalism (I09I, war3map.j 16599-16654):
-- +100 XP, give 3 herbs to all heroes, buff flower seller.
featRegistry[FourCC('I09I')] = {
    name = "Herbalism", desc = "+100 XP, all heroes start with healing herbs",
    onPick = function(hero)
        xp100(hero)
        if unit_n00H then
            UnitAddAbilityBJ(FourCC('ACba'), unit_n00H)  -- brilliance aura
            UnitAddAbilityBJ(FourCC('Avul'), unit_n00H)  -- invulnerability
        end
        local herbs = { FourCC('I040'), FourCC('I042'), FourCC('I05K') }
        local allHeroes = GetUnitsInRectMatching(GetPlayableMapRect(),
            Condition(function()
                return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO)
                    and GetOwningPlayer(GetFilterUnit()) ~= Player(8)
                    and GetOwningPlayer(GetFilterUnit()) ~= Player(11)
            end))
        ForGroup(allHeroes, function()
            local h = GetEnumUnit()
            for _, herbId in ipairs(herbs) do UnitAddItemByIdSwapped(herbId, h) end
        end)
        DestroyGroup(allHeroes)
    end,
}

-- Applied Knowledge (I053, war3map.j 15816-15864):
-- Hero earns CurrentLevel×10 bonus XP at the end of each level.
-- (Original was "probably broken" — trigger had no event; here wired to level completion.)
AppliedKnowledgeHero = nil
featRegistry[FourCC('I053')] = {
    name = "Applied Knowledge", desc = "Earns CurrentLevel×10 bonus XP at each level end",
    onPick = function(hero) AppliedKnowledgeHero = hero end,
}

-- ── Event-trigger feats ────────────────────────────────────────────────────────

-- Diehard (I08L, war3map.j 16309-16365):
-- Hero auto-revives once per level at Front-of-Silmeria when they die.
-- DieHardActivated resets each level via BonusReset in levels.lua.
DieHard = nil
featRegistry[FourCC('I08L')] = {
    name = "Diehard", desc = "Auto-revive once per level next to Silmeria",
    onPick = function(hero)
        DieHard = hero
        local trg = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddCondition(trg, Condition(function()
            return GetDyingUnit() == DieHard and not DieHardActivated
        end))
        TriggerAddAction(trg, function()
            DieHardActivated = true
            TriggerSleepAction(5.0)
            ReviveHeroLoc(DieHard, GetRectCenter(rct.FrontOfSilmeria), true)
            PanCameraToTimedLocForPlayer(GetOwningPlayer(DieHard),
                GetRectCenter(rct.FrontOfSilmeria), 0)
            DisplayTextToForce(GetPlayersAll(),
                GetPlayerName(GetOwningPlayer(DieHard))
                .. "|cff32cd32 Diehard - Activated!|r")
        end)
    end,
}

-- Defensive Posture (I04W, war3map.j 15866-15931):
-- Temporary invulnerability (10s) when attacked at ≤25% HP. 60s cooldown.
DefensivePosture = nil
featRegistry[FourCC('I04W')] = {
    name = "Defensive Posture", desc = "Invulnerable for 10s when near death (60s cooldown)",
    onPick = function(hero)
        DefensivePosture = hero
        local trg = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_ATTACKED)
        TriggerAddCondition(trg, Condition(function()
            return GetAttackedUnitBJ() == DefensivePosture
                and GetUnitLifePercent(DefensivePosture) <= 25.0
        end))
        TriggerAddAction(trg, function()
            DisableTrigger(trg)
            SetUnitInvulnerable(DefensivePosture, true)
            TriggerSleepAction(10.0)
            SetUnitInvulnerable(DefensivePosture, false)
            TriggerSleepAction(50.0)
            EnableTrigger(trg)
        end)
    end,
}

-- Flurry (I04Y, war3map.j 15933-16068):
-- On attack: 11% → ×1 extra hit, 4% → ×2 extra hits, 1% → ×5 extra hits.
FlurryHero = nil
FlurryVar   = 0
featRegistry[FourCC('I04Y')] = {
    name = "Flurry", desc = "Chance to strike extra times per attack",
    onPick = function(hero)
        FlurryHero = hero
        local trg = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_ATTACKED)
        TriggerAddCondition(trg, Condition(function()
            return GetAttacker() == FlurryHero
        end))
        TriggerAddAction(trg, function()
            DisableTrigger(trg)
            FlurryVar = GetRandomInt(1, 100)
            local tgt = GetAttackedUnitBJ()
            local dmg = I2R(BlzGetUnitBaseDamage(FlurryHero, 0)) + GetRandomReal(1.0, 15.0)
            if FlurryVar >= 84 and FlurryVar < 95 then
                -- 11%: ×1 extra hit
                UnitDamageTargetBJ(FlurryHero, tgt, dmg, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL)
            elseif FlurryVar >= 95 and FlurryVar <= 98 then
                -- 4%: ×2 extra hits
                UnitDamageTargetBJ(FlurryHero, tgt, dmg * 2.0, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL)
            elseif FlurryVar >= 99 then
                -- 1%: ×5 extra hits
                UnitDamageTargetBJ(FlurryHero, tgt, dmg * 5.0, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL)
            end
            TriggerSleepAction(3.0)
            EnableTrigger(trg)
        end)
    end,
}

-- Ambidextrous (I04Z, war3map.j 15653-15783):
-- On attack: 30% chance to deal extra damage equal to hero's AGI stat.
AmbidextrousUnit = nil
ADexVar          = 0
featRegistry[FourCC('I04Z')] = {
    name = "Ambidextrous", desc = "30% chance to deal extra AGI damage on attack",
    onPick = function(hero)
        AmbidextrousUnit = hero
        local trg = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_ATTACKED)
        TriggerAddCondition(trg, Condition(function()
            return GetAttacker() == AmbidextrousUnit
        end))
        TriggerAddAction(trg, function()
            DisableTrigger(trg)
            ADexVar = GetRandomInt(1, 10)
            if ADexVar >= 8 then
                local bonusDmg = I2R(GetHeroStatBJ(bj_HEROSTAT_AGI, AmbidextrousUnit, true))
                UnitDamageTargetBJ(AmbidextrousUnit, GetAttackedUnitBJ(),
                    bonusDmg, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL)
            end
            TriggerSleepAction(2.0)
            EnableTrigger(trg)
        end)
    end,
}

-- Aggressive Spellcaster (I04V, war3map.j 15600-15651):
-- When this hero casts any spell, the hidden unit e00R casts Inner Fire on them for 10s.
AggressiveSpellcaster = nil
featRegistry[FourCC('I04V')] = {
    name = "Aggressive Spellcaster", desc = "Increased damage for 10s after casting a spell",
    onPick = function(hero)
        AggressiveSpellcaster = hero
        local trg = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_SPELL_EFFECT)
        TriggerAddCondition(trg, Condition(function()
            return GetSpellAbilityUnit() == AggressiveSpellcaster
        end))
        TriggerAddAction(trg, function()
            DisableTrigger(trg)
            if unit_e00R then
                IssueTargetOrderBJ(unit_e00R, "innerfire", AggressiveSpellcaster)
            end
            TriggerSleepAction(10.0)
            EnableTrigger(trg)
        end)
    end,
}

-- ── Enhance existing Spell Eater + First Aid with their sub-trigger effects ────

-- Override Spell Eater (I02G) to also register the absorb-spell heal effect.
-- When P9 or P12 casts a spell targeting the Spell Eater hero, restore +25% HP+mana
-- with a 20s cooldown. (war3map.j 15417-15458)
do
    local prev = featRegistry[FourCC('I02G')]
    SpellEaterHero = nil
    featRegistry[FourCC('I02G')] = {
        name = prev.name, desc = prev.desc,
        onPick = function(hero)
            prev.onPick(hero)
            SpellEaterHero = hero
            local trg = CreateTrigger()
            TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_SPELL_EFFECT)
            TriggerAddCondition(trg, Condition(function()
                local casterOwner = GetOwningPlayer(GetSpellAbilityUnit())
                return (casterOwner == Player(9) or casterOwner == Player(12))
                    and GetSpellTargetUnit() == SpellEaterHero
            end))
            TriggerAddAction(trg, function()
                DisableTrigger(trg)
                SetUnitLifePercentBJ(SpellEaterHero,
                    GetUnitLifePercent(SpellEaterHero) + 25.0)
                SetUnitManaPercentBJ(SpellEaterHero,
                    GetUnitManaPercent(SpellEaterHero) + 25.0)
                TriggerSleepAction(20.0)
                EnableTrigger(trg)
            end)
        end,
    }
end

-- Override First Aid (I02N) to also register the scaling heal-on-cast effect.
-- A060 cast: heals target for INT% HP (min 25%) — war3map.j 15368-15413.
do
    local prev = featRegistry[FourCC('I02N')]
    featRegistry[FourCC('I02N')] = {
        name = prev.name, desc = prev.desc,
        onPick = function(hero)
            prev.onPick(hero)  -- grants ability A060
            local trg = CreateTrigger()
            TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_SPELL_EFFECT)
            TriggerAddCondition(trg, Condition(function()
                return GetSpellAbilityId() == FourCC('A060')
                    and GetSpellAbilityUnit() == hero
            end))
            TriggerAddAction(trg, function()
                local caster = GetSpellAbilityUnit()
                local intStat = GetHeroStatBJ(bj_HEROSTAT_INT, caster, true)
                local healPct = intStat < 25 and 25.0 or I2R(intStat)
                local tgt = GetSpellTargetUnit()
                SetUnitLifePercentBJ(tgt, GetUnitLifePercent(tgt) + healPct)
            end)
        end,
    }
end

-- Register every remaining feat item as a generic (no-effect-yet) feat so the
-- pick flow still works. Individual effects to be filled in during combat phase.
for _, code in ipairs(ALL_FEAT_ITEMS) do
    local id = FourCC(code)
    if not featRegistry[id] then
        featRegistry[id] = { name = "Feat", onPick = nil }
    end
end

-- ── Pickup handler ────────────────────────────────────────────────────────────

local function OnFeatItemPickup()
    local itm   = GetManipulatedItem()
    local entry = featRegistry[GetItemTypeId(itm)]
    if not entry then return end  -- not a feat item

    local hero  = GetManipulatingUnit()
    local owner = GetOwningPlayer(hero)
    local pid   = GetPlayerId(owner)

    -- Validation: one feat per player. Guard is set with no preceding sleep,
    -- so a rapid second purchase is caught here.
    if FeatPicked[pid] then
        RemoveItem(itm)
        DisplayTextToForce(GetForceOfPlayer(owner),
            "|cffff0000You have already chosen a feat.|r")
        return
    end
    FeatPicked[pid] = true

    RemoveItem(itm)
    -- Move the hero out of the feat area — this fires the EntireFeatArea
    -- leave-rect trigger (CheckAllLeftFeatArea) which starts the game when all done.
    SetUnitPositionLoc(hero, GetRandomLocInRect(rct.StartingPlayerArea))

    if entry.name == "Feat" then
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(owner) .. " has chosen a feat.")
    else
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(owner) .. " has selected the \"" .. entry.name .. "\" Feat."
            .. (entry.desc and (" (" .. entry.desc .. ")") or ""))
    end

    if entry.onPick then entry.onPick(hero) end

    PanCameraToTimedLocForPlayer(owner, GetRectCenter(rct.StartingPlayerArea), 0)
end

-- ── Per-level-up stat bonus handler ──────────────────────────────────────────

local function OnHeroLevelForFeat()
    local u = GetLevelingUnit()
    local fn = statLevelHeroes[u]
    if fn then fn(u) end
end

-- ── AI companion auto-pick (called when all human players have picked) ────────
-- The blue companion (H04Y, Player 1 in Story/Battle/Solo) is swept into the
-- feat area by PickFeat but won't buy a feat itself. Rather than stall the game
-- until the 120s timer, it picks last: any hero still in the feat area gets a
-- thematic stat feat (Extra Strong — it's a Paladin-based tank) and is moved out.
function ResolveCompanionFeats()
    local grp = GetUnitsInRectAll(rct.EntireFeatArea)
    ForGroup(grp, function()
        local hero = GetEnumUnit()
        if IsPlayerHero(hero) then
            ModifyHeroStat(bj_HEROSTAT_STR, hero, bj_MODIFYMETHOD_ADD, 2)
            statLevelHeroes[hero] = function(h)
                ModifyHeroStat(bj_HEROSTAT_STR, h, bj_MODIFYMETHOD_ADD, 2)
            end
            SetUnitPositionLoc(hero, GetRectCenter(rct.StartingPlayerArea))
            DisplayTextToForce(GetPlayersAll(),
                GetUnitName(hero) .. " has selected the \"Extra Strong\" Feat.")
        end
    end)
    DestroyGroup(grp)
end

-- ── Registration ──────────────────────────────────────────────────────────────

function RegisterFeatTriggers()
    local pickTrg = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(pickTrg, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddAction(pickTrg, OnFeatItemPickup)

    local lvlTrg = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(lvlTrg, EVENT_PLAYER_HERO_LEVEL)
    TriggerAddAction(lvlTrg, OnHeroLevelForFeat)
end
