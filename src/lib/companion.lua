-- Blue NPC companion "Sir Joshua" (H04Y / Heroes[2]) AI.
-- Requirements: systems/BluePlayerCompanion.md
-- Source lines: war3map.j 5274-6031 (blues_patrol, UH_Patrol_Copy circuit, heal_self,
--   Heal_Nearby_Hero, Town_Attacked, Basic_AI_Go_Heal).
--
-- Ported: movement (patrol circuit + periodic push), combat help (self-heal, heal nearby
-- player heroes, defend the town), and prince protection (rush to Silmeria when she fights).
-- Deferred: the research/build chain (now optional — research buildings are pre-placed) and
-- item auto-discard.

local P1 = Player(1)

local function lifePct(u)
    local mx = GetUnitState(u, UNIT_STATE_MAX_LIFE)
    if mx <= 0.0 then return 100.0 end
    return GetUnitState(u, UNIT_STATE_LIFE) / mx * 100.0
end

local function companionGroup()
    return GetUnitsOfPlayerAndTypeId(P1, FourCC('H04Y'))
end

local function orderCompanion(order, rect)
    local g = companionGroup()
    ForGroup(g, function() IssuePointOrderLoc(GetEnumUnit(), order, GetRectCenter(rect)) end)
    DestroyGroup(g)
end

-- Start (or restart) the patrol circuit. Called at gameplay start, because the pre-game
-- PauseAllUnitsBJ(true)/(false) cycle drops the order issued when he first spawned.
-- No-op if no companion exists (random/pick mode where Player 1 is human).
function KickCompanionPatrol()
    orderCompanion("patrol", rct.VernPatrolB)
end

-- Registered once, when the companion is spawned (story/battle/solo modes only).
function RegisterCompanionAI()
    -- ── Patrol circuit: A → B → C → D → A (war3map.j UH_Patrol_Copy chain) ──
    local function leg(fromRect, toRect)
        local t = CreateTrigger()
        TriggerRegisterEnterRectSimple(t, fromRect)
        TriggerAddCondition(t, Condition(function()
            return GetUnitTypeId(GetEnteringUnit()) == FourCC('H04Y')
        end))
        TriggerAddAction(t, function()
            IssuePointOrderLoc(GetEnteringUnit(), "patrol", GetRectCenter(toRect))
        end)
    end
    leg(rct.VernPatrolA, rct.VernPatrolB)
    leg(rct.VernPatrolB, rct.VernPatrolC)
    leg(rct.VernPatrolC, rct.VernPatrolD)
    leg(rct.VernPatrolD, rct.VernPatrolA)

    -- Kick off the circuit so he doesn't stand idle at the spawn.
    orderCompanion("patrol", rct.VernPatrolB)

    -- ── blues_patrol: every 250s, +25 gold and push toward Young_Hero_Spawn ──
    local bp = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(bp, 250.0)
    TriggerAddAction(bp, function()
        AdjustPlayerStateBJ(25, P1, PLAYER_STATE_RESOURCE_GOLD)
        orderCompanion("attack", rct.YoungHeroSpawn)
    end)

    -- ── heal_self: attacked at ≤75% HP → Healing Wave on self (30s cooldown) ──
    local hs = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(hs, P1, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(hs, Condition(function()
        local u = GetAttackedUnitBJ()
        return GetUnitTypeId(u) == FourCC('H04Y') and lifePct(u) <= 75.0
    end))
    TriggerAddAction(hs, function()
        DisableTrigger(hs)
        local u = GetAttackedUnitBJ()
        IssueTargetOrderBJ(u, "healingwave", u)
        AdjustPlayerStateBJ(25, P1, PLAYER_STATE_RESOURCE_GOLD)
        TriggerSleepAction(30.0)
        EnableTrigger(hs)
    end)

    -- ── Heal_Nearby_Hero: a player hero ≤80% within 700 of the companion → heal it ──
    local hn = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(hn, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(hn, Condition(function()
        local u = GetAttackedUnitBJ()
        local owner = GetOwningPlayer(u)
        if not (Heroes[2] and IsUnitType(u, UNIT_TYPE_HERO)) then return false end
        if owner == P1 or owner == Player(8) or owner == Player(9) or owner == Player(11) then
            return false
        end
        if lifePct(u) > 80.0 then return false end
        local dx, dy = GetUnitX(u) - GetUnitX(Heroes[2]), GetUnitY(u) - GetUnitY(Heroes[2])
        return (dx * dx + dy * dy) <= 700.0 * 700.0
    end))
    TriggerAddAction(hn, function()
        DisableTrigger(hn)
        local target = GetAttackedUnitBJ()
        IssueTargetOrderBJ(Heroes[2], "healingwave", target)
        AdjustPlayerStateBJ(25, P1, PLAYER_STATE_RESOURCE_GOLD)
        TriggerSleepAction(30.0)
        EnableTrigger(hn)
    end)

    -- ── Town_Attacked: Player(8) unit attacked → go defend (45s cooldown) ──
    local ta = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(ta, Player(8), EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(ta, Condition(function()
        return Heroes[2] ~= nil and not DefendingSilmeria
    end))
    TriggerAddAction(ta, function()
        DisableTrigger(ta)
        local loc = GetUnitLoc(GetAttacker())
        IssuePointOrderLoc(Heroes[2], "patrol", loc)
        RemoveLocation(loc)
        AdjustPlayerStateBJ(25, P1, PLAYER_STATE_RESOURCE_GOLD)
        TriggerSleepAction(45.0)
        EnableTrigger(ta)
    end)

    -- ── Basic_AI_Go_Heal: companion at ≤20% HP → retreat to the fountain ──
    local gh = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(gh, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(gh, Condition(function()
        return GetUnitTypeId(GetAttackedUnitBJ()) == FourCC('H04Y')
            and Heroes[2] ~= nil and lifePct(Heroes[2]) <= 20.0
    end))
    TriggerAddAction(gh, function()
        orderCompanion("move", rct.FrontOfFountain)
    end)

    -- ── princes_is_attacked: when Princess Silmeria (H02G) is fighting (an enemy reached
    --    her, so she swung back), the companion teleports to her side and the routine AI
    --    pauses for 250s while he guards her (war3map.j princes_is_attacked 5781-5815). ──
    local pp = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(pp, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddCondition(pp, Condition(function()
        return unit_H02G ~= nil and GetAttacker() == unit_H02G
    end))
    TriggerAddAction(pp, function()
        DisableTrigger(pp); DisableTrigger(bp); DisableTrigger(ta); DisableTrigger(gh)
        DefendingSilmeria = true
        local px, py = GetUnitX(unit_H02G), GetUnitY(unit_H02G)
        local g = companionGroup()
        ForGroup(g, function() SetUnitPosition(GetEnumUnit(), px, py) end)
        DestroyGroup(g)
        if Heroes[2] then
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), Heroes[2], "Sir Joshua", nil,
                "Protect the Princess!", bj_TIMETYPE_SET, 5.0, true)
        end
        TriggerSleepAction(250.0)
        DefendingSilmeria = false
        EnableTrigger(pp); EnableTrigger(bp); EnableTrigger(ta); EnableTrigger(gh)
    end)

    -- ── Item auto-discard: the companion can wander over loot meant for the players. When an
    --    H04Y picks up a consumable (health potion I0BU, herbs I040/I042/I05K) it is removed
    --    from every H04Y so the AI never hoards/consumes it (war3map.j blue_removes_* 5908-6021).
    --    The four near-identical triggers collapse into one keyed on a small id set.
    local DISCARD = {
        [FourCC('I0BU')] = true, [FourCC('I040')] = true,
        [FourCC('I042')] = true, [FourCC('I05K')] = true,
    }
    local rm = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(rm, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(rm, Condition(function()
        return GetUnitTypeId(GetManipulatingUnit()) == FourCC('H04Y')
            and DISCARD[GetItemTypeId(GetManipulatedItem())] == true
    end))
    TriggerAddAction(rm, function()
        local id = GetItemTypeId(GetManipulatedItem())
        local g = companionGroup()
        ForGroup(g, function()
            RemoveItem(GetItemOfTypeFromUnitBJ(GetEnumUnit(), id))
        end)
        DestroyGroup(g)
    end)
end
