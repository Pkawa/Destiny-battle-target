-- Damage Detection System (DDS)
--
-- Port-side INFRASTRUCTURE — there is no equivalent in the reference war3map.j (it uses
-- zero damage-event natives), so this is general engine plumbing, not a clean-room port of
-- anything. It exists so the item/ability systems can react to combat damage: on-attack
-- procs (poison/frost-on-hit growth), damage-reduction items, thorns, lifesteal, etc.
--
-- One pair of native damage events drives a registry of handlers. A handler reads the
-- current event through the DDS.* accessors, may modify the pending damage (DDS.setAmount),
-- and may deal follow-up damage with DDS.damage (which is guarded so it can't re-trigger
-- handlers and spin into an infinite proc loop).
--
-- Usage:
--   DDS.register(function()
--       if not DDS.isAttack() then return end
--       local src, tgt = DDS.source(), DDS.target()
--       ... DDS.damage(src, tgt, 50, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC) ...
--   end)
-- and call RegisterDDS() once from main.lua (before any system that registers handlers runs).

DDS = {}

local handlers = {}   -- ordered sequence of fn(); iterated with a numeric loop (sync-safe)
local depth     = 0   -- recursion guard: >0 while a handler is itself dealing damage

-- ── Event accessors (valid only while a handler is running) ────────────────────
function DDS.source()     return GetEventDamageSource() end
function DDS.target()     return BlzGetEventDamageTarget() end
function DDS.amount()     return GetEventDamage() end
function DDS.setAmount(x) BlzSetEventDamage(x) end          -- modify the pending hit
function DDS.isAttack()   return BlzGetEventIsAttack() end  -- true for a normal attack (not a spell)
function DDS.attackType() return BlzGetEventAttackType() end
function DDS.damageType() return BlzGetEventDamageType() end

-- ── Registration ───────────────────────────────────────────────────────────────
-- fn() runs for every damage event EXCEPT damage dealt from inside a handler via
-- DDS.damage (the recursion guard skips those), so procs never loop.
function DDS.register(fn)
    handlers[#handlers + 1] = fn
end

-- Deal damage from inside a handler without re-entering the DDS. Use this for any
-- proc/thorns/bonus damage so the hit lands but does not spawn another round of handlers.
-- Defaults to a normal physical hit; pass attack/damage types for frost, poison, etc.
function DDS.damage(source, target, amount, attackType, damageType)
    depth = depth + 1
    UnitDamageTarget(source, target, amount, false, false,
        attackType or ATTACK_TYPE_NORMAL, damageType or DAMAGE_TYPE_NORMAL,
        WEAPON_TYPE_WHOKNOWS)
    depth = depth - 1
end

function RegisterDDS()
    local trg = CreateTrigger()
    -- DAMAGING fires before the hit is applied, so handlers can both read and modify it.
    TriggerRegisterAnyUnitEventBJ(trg, EVENT_PLAYER_UNIT_DAMAGING)
    TriggerAddAction(trg, function()
        if depth > 0 then return end   -- this hit came from a handler — don't re-run handlers
        for i = 1, #handlers do
            handlers[i]()
        end
    end)
end
