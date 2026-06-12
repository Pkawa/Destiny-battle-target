-- Shared engine-call helpers.
-- Collapses the repetitive WC3 rituals for groups, timers, triggers, and text tags
-- that otherwise get copy-pasted across every module. Purely sugar over natives/BJs;
-- no behavior of its own. All helpers are leak-free (groups/timers always cleaned up).
--
-- Filters/actions are plain Lua closures: use GetFilterUnit() inside a filter, and
-- GetEnumUnit() inside an action (same as ForGroup).

-- ── Group enumeration ─────────────────────────────────────────────────────────
-- The group AND the filter boolexpr are created and destroyed internally, so callers
-- can never leak one. (A `Condition(luaFn)` is a handle that must be DestroyBoolExpr'd —
-- skipping it leaks a boolexpr + its pinned closure on every call, and these run in hot
-- per-attack / per-second loops.)

-- Run a unit enumeration with an optional Lua filter, cleaning up both the group and the
-- boolexpr. `enumFn(group, boolexpr)` performs the actual GroupEnum* call.
local function enumClean(filterFn, enumFn, useFn)
    local g = CreateGroup()
    local b = filterFn and Condition(filterFn) or nil
    enumFn(g, b)
    local result = useFn(g)
    DestroyGroup(g)
    if b then DestroyBoolExpr(b) end
    return result
end

function CountInRange(x, y, r, filterFn)
    return enumClean(filterFn,
        function(g, b) GroupEnumUnitsInRange(g, x, y, r, b) end, CountUnitsInGroup)
end

function ForUnitsInRange(x, y, r, filterFn, actionFn)
    enumClean(filterFn,
        function(g, b) GroupEnumUnitsInRange(g, x, y, r, b) end,
        function(g) ForGroup(g, actionFn) end)
end

function CountInRect(rect, filterFn)
    return enumClean(filterFn,
        function(g, b) GroupEnumUnitsInRect(g, rect, b) end, CountUnitsInGroup)
end

function ForUnitsInRect(rect, filterFn, actionFn)
    enumClean(filterFn,
        function(g, b) GroupEnumUnitsInRect(g, rect, b) end,
        function(g) ForGroup(g, actionFn) end)
end

-- ── Timers ────────────────────────────────────────────────────────────────────

-- Run fn once after `delay` seconds, then self-destruct. Returns the timer handle.
function After(delay, fn)
    local t = CreateTimer()
    TimerStart(t, delay, false, function()
        fn()
        DestroyTimer(t)
    end)
    return t
end

-- Run fn every `interval` seconds. fn returns a truthy value to stop (timer destroyed).
-- Returns the timer handle so a caller can DestroyTimer it externally too.
function Every(interval, fn)
    local t = CreateTimer()
    TimerStart(t, interval, true, function()
        if fn() then DestroyTimer(t) end
    end)
    return t
end

-- ── Trigger factories ─────────────────────────────────────────────────────────
-- condFn may be nil (no condition). Returns the trigger so callers can keep a handle
-- (e.g. to DisableTrigger inside the action via GetTriggeringTrigger, or to expose it).

function OnAnyUnit(event, condFn, actionFn)
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, event)
    if condFn then TriggerAddCondition(t, Condition(condFn)) end
    TriggerAddAction(t, actionFn)
    return t
end

function OnPlayerUnit(player, event, condFn, actionFn)
    local t = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(t, player, event)
    if condFn then TriggerAddCondition(t, Condition(condFn)) end
    TriggerAddAction(t, actionFn)
    return t
end

function OnEnterRect(rect, condFn, actionFn)
    local t = CreateTrigger()
    TriggerRegisterEnterRectSimple(t, rect)
    if condFn then TriggerAddCondition(t, Condition(condFn)) end
    TriggerAddAction(t, actionFn)
    return t
end

-- ── Floating combat text ──────────────────────────────────────────────────────
-- A non-permanent text tag above `unit` that fades out after `life` seconds (default 5).
-- Colors default to white; pass r/g/b as 0-100 percentages (matching CreateTextTagUnitBJ).
function FloatText(unit, text, r, g, b, life)
    CreateTextTagUnitBJ(text, unit, 0, 10, r or 100, g or 100, b or 100, 0)
    local tag = GetLastCreatedTextTag()
    SetTextTagPermanentBJ(tag, false)
    SetTextTagLifespanBJ(tag, life or 5.0)
    return tag
end

-- ── Scaling ───────────────────────────────────────────────────────────────────
-- Linear hero-level scaling: base + perLevel per hero level. GetHeroLevel returns 0 for
-- non-heroes, so a non-hero caster gets `base`. (See items/ItemEffects.md convention.)
function Scaled(base, perLevel, unit)
    return base + perLevel * GetHeroLevel(unit)
end
