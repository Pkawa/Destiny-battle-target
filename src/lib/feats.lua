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
local function registerStatFeat(itemCode, featName, applyFn)
    featRegistry[FourCC(itemCode)] = {
        name = featName,
        onPick = function(hero)
            statLevelHeroes[hero] = applyFn
        end,
    }
end

-- Extra Strong / Fast / Smart — +2 of a stat per level (war3map.j 15046-15217)
registerStatFeat('I02A', "Extra Strong", function(h) ModifyHeroStat(bj_HEROSTAT_STR, h, bj_MODIFYMETHOD_ADD, 2) end)
registerStatFeat('I02B', "Extra Fast",   function(h) ModifyHeroStat(bj_HEROSTAT_AGI, h, bj_MODIFYMETHOD_ADD, 2) end)
registerStatFeat('I02C', "Extra Smart",  function(h) ModifyHeroStat(bj_HEROSTAT_INT, h, bj_MODIFYMETHOD_ADD, 2) end)
-- Iron Skin — +1 armor per level (war3map.j 15220-15266)
registerStatFeat('I02V', "Iron Skin",    function(h) BlzSetUnitArmor(h, BlzGetUnitArmor(h) + 1) end)

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
            GetPlayerName(owner) .. " has selected the \"" .. entry.name .. "\" Feat.")
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
