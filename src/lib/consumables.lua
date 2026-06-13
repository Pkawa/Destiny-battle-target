-- Special / consumable item use-effects. Requirements: items/Items.md §4.
-- Source: war3map.j 32366-32597 (Chronoegg..Cleansed Orb), 32088-32198 (Green Mushroom,
-- Necronomicon, Sailor's Calling, Blooddrinker, Pot of Renewal).
--
-- The original ships ~13 near-identical one-item triggers, each a USE_ITEM event with a
-- GetItemTypeId condition. They collapse here into ONE USE_ITEM dispatch keyed by item id
-- (like scrolls.lua), plus two non-USE_ITEM handlers that don't fit the dispatch:
--   * Blooddrinker (war3map.j 32159) — a passive on UNIT_DEATH (the kill, not an item use).
--   * Coral Blade Blessing's "Blessing Effect" (war3map.j 32543) — an ATTACKED listener.
--
-- Already ported elsewhere, NOT handled here:
--   * Rainbow Orb (I063+I06E -> I06F) — folded into the set/combine dispatch (items.lua SETS).
--   * The Swallow's Anchor / Repair City / Midas / Tarot / Circle scrolls — misc.lua / scrolls.lua.

-- [item id] = handler(item, hero, owner). Dispatch fires on EVENT_PLAYER_UNIT_USE_ITEM.
local USE = {}
local function use(item, fn) USE[FourCC(item)] = fn end

-- ── Chronoegg (I03P) — war3map.j 32377 ─────────────────────────────────────────
-- Freeze time: pause every unit, unpause the user's own units, white flash + sound +
-- "Time is frozen!" announce, hold 15s, then unfreeze. (Same shape as abilities.lua's
-- Power Word: Stop.) The original PauseAllUnitsBJ(true) then re-unpauses only the user's
-- units (GetUnitsInRectOfPlayer of the manipulating player); we match that exactly.
use('I03P', function(item, hero, owner)
    TriggerSleepAction(0.5)
    PauseAllUnitsBJ(true)
    local pg = GetUnitsInRectOfPlayer(GetPlayableMapRect(), owner)
    ForGroup(pg, function() PauseUnitBJ(false, GetEnumUnit()) end)
    DestroyGroup(pg)
    CinematicFilterGenericBJ(15.0, BLEND_MODE_BLEND,
        "ReplaceableTextures\\CameraMasks\\White_mask.blp",
        0.0, 100, 0.0, 70.0, 100.0, 100.0, 100.0, 100.0)
    DisplayCineFilterBJ(true)
    if snd.ManaPotion then PlaySoundBJ(snd.ManaPotion) end
    if snd.Tomes then PlaySoundBJ(snd.Tomes) end
    DisplayTimedTextToForce(GetPlayersAll(), 15.0,
        GetPlayerName(owner) .. "  breaks open a Chronoegg! |cff995500Time is frozen!|r")
    TriggerSleepAction(15.0)
    DisplayCineFilterBJ(false)
    PauseAllUnitsBJ(false)
end)

-- ── Energy Drink (I00V) — war3map.j 32410 ──────────────────────────────────────
-- Restore "energy": +25 lumber (the map stores hero energy as lumber). No announce.
use('I00V', function(item, hero, owner)
    AdjustPlayerStateBJ(25, owner, PLAYER_STATE_RESOURCE_LUMBER)
end)

-- ── Pot of Renewal (I07J) — war3map.j 32188 ────────────────────────────────────
-- Likewise +50 lumber (the "regen" label is the flavor; mechanically it tops up energy).
use('I07J', function(item, hero, owner)
    AdjustPlayerStateBJ(50, owner, PLAYER_STATE_RESOURCE_LUMBER)
end)

-- ── Barrel (I03G) — war3map.j 32433 ────────────────────────────────────────────
-- Drop an explosive barrel (o005), owned by the user, jittered ±90 around the hero.
use('I03G', function(item, hero, owner)
    local x = GetUnitX(hero) + GetRandomReal(-90.0, 90.0)
    local y = GetUnitY(hero) + GetRandomReal(-90.0, 90.0)
    CreateUnit(owner, FourCC('o005'), x, y, bj_UNIT_FACING)
end)

-- ── Weather Control (I03K) — war3map.j 32456 ───────────────────────────────────
-- Gnomish device: clear the active weather entities (remove up to 4 random weather-target
-- units, stop the standing e008/e00A weather casters), announce, then re-roll the weather
-- via the shared weather API (RollWeather). The original calls the same
-- Random_Weather_And_Meteorologist trigger that RollWeather() reimplements.
use('I03K', function(item, hero, owner)
    -- The JASS does GroupPickRandomUnit four times over the weather-target zone, removing
    -- whatever it picks; emulate by removing up to 4 distinct random units in that zone.
    local g = CreateGroup()
    GroupEnumUnitsInRect(g, rct.WeatherTarget, nil)
    local picked = {}
    for _ = 1, 4 do
        local u = GroupPickRandomUnit(g)
        if u and not picked[u] then
            picked[u] = true
            GroupRemoveUnit(g, u)
            RemoveUnit(u)
        end
    end
    DestroyGroup(g)
    if unit_e008 then IssueImmediateOrder(unit_e008, "stop") end
    if unit_e00A then IssueImmediateOrder(unit_e00A, "stop") end
    DisplayTextToForce(GetPlayersAll(),
        GetPlayerName(owner) .. " uses a Gnomish Weather Control Device!")
    RollWeather()
end)

-- ── Coral Blade Blessing (I01M) — war3map.j 32487 ──────────────────────────────
-- Arm a 20s buff on the user: while CoralBlessingOn, the user regains 20 mana whenever
-- attacked (handled by the ATTACKED listener registered below).
use('I01M', function(item, hero, owner)
    CoralBladeBlessingCurrent = hero
    CoralBlessingOn = true
    TriggerSleepAction(20.0)
    CoralBlessingOn = false
end)

-- ── Robe of Blood Cast (I024) — war3map.j 32514 ────────────────────────────────
-- INT-on-cast self-detonation: the user deals (own current HP / 4) damage in a 500 radius
-- around itself after a 0.5s delay. (The "RobeBloodInt" global flags that the robe's
-- on-cast effect is live; preserved.)
use('I024', function(item, hero, owner)
    RobeBloodInt = true
    local dmg = GetUnitState(hero, UNIT_STATE_LIFE) / 4.0
    UnitDamagePoint(hero, 0.5, 500.0, GetUnitX(hero), GetUnitY(hero), dmg,
        false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
    RobeBloodInt = false
end)

-- ── Cleansed Orb of Light (I00W) — war3map.j 32577 ─────────────────────────────
-- Consume the orb and revive every player hero (slots 1-8) at the starting area, full HP.
use('I00W', function(item, hero, owner)
    RemoveItem(item)
    local cx = GetRectCenterX(rct.StartingPlayerArea)
    local cy = GetRectCenterY(rct.StartingPlayerArea)
    for i = 1, 8 do
        local h = Heroes[i]
        if h and GetUnitTypeId(h) ~= 0 then
            ReviveHero(h, cx, cy, true)
        end
    end
    if snd.SlowRezzSound then PlaySoundBJ(snd.SlowRezzSound) end
    DisplayTextToForce(GetPlayersAll(),
        GetPlayerName(owner) .. " has used the Orb of Light!  All heroes are revived!")
end)

-- ── Green Mushroom (I0BZ) — war3map.j 32095 ────────────────────────────────────
-- +5 INT, -3 STR to the user (permanent stat trade).
use('I0BZ', function(item, hero, owner)
    ModifyHeroStat(bj_HEROSTAT_INT, hero, bj_MODIFYMETHOD_ADD, 5)
    ModifyHeroStat(bj_HEROSTAT_STR, hero, bj_MODIFYMETHOD_SUB, 3)
end)

-- ── Necronomicon (I0C3) — war3map.j 32118 ──────────────────────────────────────
-- Build a necromantic research lab (n013, neutral passive) at the Necromantic Research
-- site; global announce + sound.
use('I0C3', function(item, hero, owner)
    DisplayTextToForce(GetPlayersAll(), GetPlayerName(owner) ..
        " |cff32cd32has read the Necronomicon... a necromantic research lab has been built in Vern!|r ")
    if snd.ZigguratUpgrade then PlaySoundBJ(snd.ZigguratUpgrade)
    elseif snd.AllianceSound then PlaySoundBJ(snd.AllianceSound) end
    CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('n013'),
        GetRectCenterX(rct.NecromanticResearch), GetRectCenterY(rct.NecromanticResearch), bj_UNIT_FACING)
end)

-- ── Sailor's Calling (I02R) — war3map.j 32142 ──────────────────────────────────
-- Summon a random tier-2 merchant ship (h04H/h04K/h04G) for Player(8) at the ship spawn;
-- global announce + sound. (These are Seafaring[4..6] in the original.)
local SAILOR_SHIPS = { FourCC('h04H'), FourCC('h04K'), FourCC('h04G') }
use('I02R', function(item, hero, owner)
    CreateUnit(Player(8), SAILOR_SHIPS[GetRandomInt(1, 3)],
        GetRectCenterX(rct.ShipSpawnStart), GetRectCenterY(rct.ShipSpawnStart), 0.0)
    DisplayTextToForce(GetPlayersAll(), GetPlayerName(owner) ..
        " |cff32cd32uses a Sailor's Calling, a ship shall soon sail to Vern!|r ")
    if snd.GoblinShipyardWhat1 then PlaySoundBJ(snd.GoblinShipyardWhat1)
    elseif snd.AllianceSound then PlaySoundBJ(snd.AllianceSound) end
end)

function RegisterConsumableTriggers()
    -- Shared USE_ITEM dispatch (war3map.j: 13 separate USE_ITEM triggers).
    OnAnyUnit(EVENT_PLAYER_UNIT_USE_ITEM, function()
        return USE[GetItemTypeId(GetManipulatedItem())] ~= nil
    end, function()
        local item = GetManipulatedItem()
        local hero = GetManipulatingUnit()
        USE[GetItemTypeId(item)](item, hero, GetOwningPlayer(hero))
    end)

    -- Blooddrinker (I06D) — war3map.j 32166: when a unit holding the Blooddrinker scores a
    -- kill, it heals 20 HP. Passive, fires on the kill (UNIT_DEATH), not on an item use.
    OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
        local killer = GetKillingUnit()
        return killer ~= nil and IsItemOwned(GetItemOfTypeFromUnitBJ(killer, FourCC('I06D')))
    end, function()
        local killer = GetKillingUnit()
        SetUnitLifeBJ(killer, GetUnitState(killer, UNIT_STATE_LIFE) + 20.0)
    end)

    -- Blessing Effect (Coral Blade) — war3map.j 32543: while the Coral Blade Blessing is
    -- active, the blessed hero regains 20 mana each time it is attacked (then a 2s internal
    -- cooldown before it can trigger again). The original disables/re-enables its own
    -- trigger to gate the cooldown; we emulate with a per-hero ready flag.
    local blessingReady = true
    OnAnyUnit(EVENT_PLAYER_UNIT_ATTACKED, function()
        return CoralBlessingOn and blessingReady
            and GetAttacker() ~= nil
            and GetTriggerUnit() == CoralBladeBlessingCurrent
    end, function()
        blessingReady = false
        local u = GetTriggerUnit()
        SetUnitManaBJ(u, GetUnitState(u, UNIT_STATE_MANA) + 20.0)
        FloatText(u, "+20 Mana", 30, 30, 100, 1.5)
        TriggerSleepAction(2.0)
        if CoralBlessingOn then blessingReady = true end
    end)
end
