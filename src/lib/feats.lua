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
        if IsUnitType(hero, UNIT_TYPE_HERO) then
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
