-- Blue NPC companion "Sir Joshua" (H04Y / Heroes[2]) AI.
-- Requirements: systems/BluePlayerCompanion.md
-- Source lines: war3map.j 5274-6031 (blues_patrol, UH_Patrol_Copy circuit, heal_self,
--   Heal_Nearby_Hero, Town_Attacked, Basic_AI_Go_Heal).
--
-- Ported: movement (patrol circuit + periodic push), combat help (self-heal, heal nearby
-- player heroes, defend the town), prince protection (rush to Silmeria when she fights),
-- item auto-discard, and the gold-gated build/research ladder (Basic_AI_Research 1..10 +
-- build-fountain, war3map.j 5535-5729): as Player(1)'s gold accrues the AI auto-researches at
-- its h00Z building, builds the patrol Fountain (h038), and narrates each step through P2Hero.

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

-- Player(1)'s research building (h00Z): the AI issues its upgrade orders here, mirroring the
-- original's gg_unit_h00Z_0024. Pre-placed by units.lua/CreateResearchBuildings; fetched on
-- demand so we never hold a stale handle. Returns nil if (somehow) absent — callers no-op.
local function companionResearchBuilding()
    local g = GetUnitsOfPlayerAndTypeId(P1, FourCC('h00Z'))
    local b = FirstOfGroup(g)
    DestroyGroup(g)
    return b
end

-- The blue companion (P2Hero / Heroes[2]) announces a research step. Crash-safe if no companion
-- exists (random/pick mode where Player(1) is human). Mirrors the JASS
-- TransmissionFromUnitWithNameBJ(..., udg_P2Hero, "Sir Joshua", null, <line>, ...) calls.
local function joshuaSays(line)
    local who = Heroes[2]
    if who and GetUnitTypeId(who) ~= 0 then
        TransmissionFromUnitWithNameBJ(GetPlayersAll(), who, "Sir Joshua", nil,
            line, bj_TIMETYPE_SET, 6.0, true)
    end
end

-- ── Gold-gated build/research ladder (war3map.j 5535-5729) ──────────────────────────────
-- A chain of one-shot rungs. Each rung listens for Player(1)'s gold reaching a threshold; when
-- it fires it disables itself, performs its action (upgrade order or build the fountain),
-- speaks through P2Hero, then enables the next rung. Only one rung is armed at a time, so the
-- AI researches roughly one upgrade per gold milestone — exactly the original's pacing. The
-- first rung is enabled here (the JASS enables it from BeginningStart2, war3map.j 18217).
function RegisterCompanionResearchAI()
    -- Each entry: { gold threshold, action(building) }. nil building -> action skips its order.
    -- The fountain rung is the one non-upgrade step (it spends 500 gold and erects h038).
    local rungs = {
        -- Basic_AI_Research        (>=500)  R00X Basic Training
        { 500, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00X')) end
                           joshuaSays("I am researching Basic Training!") end },
        -- Basic_AI_Research_2      (>=250)  R00B Flowing Waters
        { 250, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00B')) end
                           joshuaSays("I am researching Flowing Waters!") end },
        -- Basic_AI_Research_3      (>=250)  R00C Improved Fountains
        { 250, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00C')) end
                           joshuaSays("I am researching Improved Fountains!") end },
        -- Basic_AI_Research_build_fountain (>=500) spend 500, build h038, ping minimap
        { 500, function()
                   AdjustPlayerStateBJ(-500, P1, PLAYER_STATE_RESOURCE_GOLD)
                   CreateNUnitsAtLoc(1, FourCC('h038'), Player(8),
                       GetRectCenter(rct.BuyFountainZone), bj_UNIT_FACING)
                   PingMinimapLocForForce(GetPlayersAll(), GetRectCenter(rct.BuyFountainZone), 4.0)
                   joshuaSays("this would be a great spot for a fountain for our city patrol")
               end },
        -- Basic_AI_Research_4      (>=600)  R00I Aerodynamics
        { 600, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00I')) end
                           joshuaSays("I am researching Aerodynamicst!") end },
        -- Basic_AI_Research_5      (>=200)  R00E Rebuildable Towers
        { 200, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00E')) end
                           joshuaSays("I am researching Rebuildable Towers!") end },
        -- Basic_AI_Research_6      (>=300)  R00W Militia of Vern
        { 300, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00W')) end
                           joshuaSays("I am researching Militia of Vern!") end },
        -- Basic_AI_Research_7      (>=200)  R00K Safe Pouches
        { 200, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00K')) end
                           joshuaSays("I am researching Safe Pouches!") end },
        -- Basic_AI_Research_8      (>=750)  R00H Energy Rush
        { 750, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00H')) end
                           joshuaSays("I am researching Energy Rush!") end },
        -- Basic_AI_Research_9      (>=500)  R00J Supply Stocking
        { 500, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00J')) end
                           joshuaSays("I am researching Supply Stocking!") end },
        -- Basic_AI_Research_10     (>=250)  R00Y Sea Faring (last rung, no successor)
        { 250, function(b) if b then IssueUpgradeOrderByIdBJ(b, FourCC('R00Y')) end
                           joshuaSays("I am researching Sea Faring!") end },
    }

    -- Build the triggers first, then chain them (each rung enables the next).
    local trigs = {}
    for i = 1, #rungs do
        local t = CreateTrigger()
        TriggerRegisterPlayerStateEvent(t, P1, PLAYER_STATE_RESOURCE_GOLD,
            GREATER_THAN_OR_EQUAL, rungs[i][1])
        DisableTrigger(t)
        trigs[i] = t
    end
    for i = 1, #rungs do
        local t, action, nextT = trigs[i], rungs[i][2], trigs[i + 1]
        TriggerAddAction(t, function()
            DisableTrigger(t)
            action(companionResearchBuilding())
            if nextT then EnableTrigger(nextT) end
        end)
    end

    -- Arm the first rung now (JASS: EnableTrigger(gg_trg_Basic_AI_Research) in BeginningStart2).
    EnableTrigger(trigs[1])
end

-- Registered once, when the companion is spawned (story/battle/solo modes only).
function RegisterCompanionAI()
    -- ── Gold-gated build/research ladder (war3map.j 5535-5729) ──
    -- Armed here rather than at BeginningStart2 (JASS 18217): the companion only exists in
    -- story/battle/solo modes (Player 1 = computer), which is exactly when this path runs, and
    -- rung 1 needs 500 gold while the AI starts with 325 — so it cannot fire before gameplay.
    RegisterCompanionResearchAI()

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
