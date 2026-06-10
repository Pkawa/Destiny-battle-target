-- Item effects & hero-level scaling.
-- Requirements: items/ItemEffects.md. Audit: dirty/item_audit.py.
--
-- A feats.lua-style registry: each custom item ability gets one row { base, perLevel, apply }.
-- A single SPELL_EFFECT dispatch (plus a USE_ITEM twin for charge/consumable actives) looks
-- the ability up and runs apply() with the scaled amount:
--
--     amount = Scaled(base, perLevel, caster) * ItemScaleFactor      -- = (base + perLevel*lvl) * factor
--
-- Scaling convention is LINEAR (base + perLevel × heroLevel); see util.Scaled.
--
-- IMPORTANT (avoid double-dipping): for a *damage* item, the object-data ability must deal
-- 0 base damage (a dummy/trigger ability) so only the scripted amount lands. That's a
-- build-time object-data change recorded per item in the worklist (ItemEffects.md §4).
--
-- This module is the framework only. The 85 Lv1-pool custom items (and the rest) are
-- registered tier by tier after per-item triage — see ItemEffects.md §3-4.

-- Global balance dial: multiplies every item-effect amount. Tune for a quick balance pass.
ItemScaleFactor = 1.0

-- Registries (keyed by the engine's event ids):
ItemFX    = {}   -- [abilityId] = { base, perLevel, apply(caster, target, amount) }  -- cast actives
ItemUseFX = {}   -- [itemId]    = { base, perLevel, apply(user,  item,   amount) }   -- use/charge actives

-- Register a scaling effect for a custom item ABILITY (fires on spell effect).
function registerItemFX(abilId, base, perLevel, apply)
    ItemFX[abilId] = { base = base, perLevel = perLevel, apply = apply }
end

-- Register a scaling effect for a charge/consumable ITEM (fires on item use, no spell).
function registerItemUseFX(itemId, base, perLevel, apply)
    ItemUseFX[itemId] = { base = base, perLevel = perLevel, apply = apply }
end

-- ── apply-builders (common effect shapes; reduce per-item boilerplate) ─────────
-- apply runs inside the triggering spell's context, so point-target spells can read
-- GetSpellTargetX()/Y() directly inside a custom apply when there's no target unit.

-- Spell-damage the target unit (magic by default). No-op if the spell had no unit target.
function fxDamage(attackType, damageType)
    return function(caster, target, amount)
        if not target then return end
        -- attack=false so this reads as a spell hit (no on-attack procs / no weapon lifesteal).
        UnitDamageTarget(caster, target, amount, false, false,
            attackType or ATTACK_TYPE_NORMAL, damageType or DAMAGE_TYPE_MAGIC,
            WEAPON_TYPE_WHOKNOWS)
    end
end

-- Heal the target unit (engine clamps to max HP).
function fxHeal()
    return function(_, target, amount)
        if not target then return end
        SetUnitState(target, UNIT_STATE_LIFE,
            GetUnitState(target, UNIT_STATE_LIFE) + amount)
    end
end

-- Spell-damage every enemy within `radius` of the cast point (or the caster, if
-- `aroundCaster`). Approximate AoE — it hits enemies near the impact, not the template's
-- exact line/cone, which is fine for an additive bonus on Shockwave / War Stomp nukes.
function fxDamageArea(radius, aroundCaster, attackType, damageType)
    return function(caster, target, amount)
        local x, y
        if aroundCaster then
            x, y = GetUnitX(caster), GetUnitY(caster)
        elseif target then
            x, y = GetUnitX(target), GetUnitY(target)
        else
            x, y = GetSpellTargetX(), GetSpellTargetY()
        end
        local owner = GetOwningPlayer(caster)
        ForUnitsInRange(x, y, radius, function()
            local u = GetFilterUnit()
            return IsUnitEnemy(u, owner)
                and not IsUnitType(u, UNIT_TYPE_STRUCTURE)
                and GetUnitState(u, UNIT_STATE_LIFE) > 0.405
        end, function()
            UnitDamageTarget(caster, GetEnumUnit(), amount, false, false,
                attackType or ATTACK_TYPE_NORMAL, damageType or DAMAGE_TYPE_MAGIC,
                WEAPON_TYPE_WHOKNOWS)
        end)
    end
end

-- ── Dispatch ──────────────────────────────────────────────────────────────────

local function runFX(fx, caster, target)
    if not fx then return end
    fx.apply(caster, target, Scaled(fx.base, fx.perLevel, caster) * ItemScaleFactor)
end

function RegisterItemEffectTriggers()
    -- Cast actives: most custom item abilities are spells → fire on SPELL_EFFECT.
    -- The lookup is nil for every non-item ability (hero spells, etc.), so this is cheap.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, nil, function()
        runFX(ItemFX[GetSpellAbilityId()], GetSpellAbilityUnit(), GetSpellTargetUnit())
    end)

    -- Charge/consumable actives that fire USE_ITEM without a spell (self/AoE effects:
    -- the apply reads what it needs from the user). Empty until such items are ported.
    OnAnyUnit(EVENT_PLAYER_UNIT_USE_ITEM, nil, function()
        local item = GetManipulatedItem()
        local fx = ItemUseFX[GetItemTypeId(item)]
        if not fx then return end
        local user = GetManipulatingUnit()
        fx.apply(user, item, Scaled(fx.base, fx.perLevel, user) * ItemScaleFactor)
    end)
end

-- ── Registered item effects ───────────────────────────────────────────────────
-- Lv1 Uncommon damage items (triage: items/ItemEffects.md §4). ADDITIVE scaling — the
-- object-data ability keeps its flat base damage (+ stun/visual), and the script adds
-- perLevel × heroLevel on top, so the total is "<base> + perLevel*lvl" with NO object-data
-- change. (Level-scaling is a deliberate enhancement; the originals dealt flat damage.)
-- Tune perLevel per item, or ItemScaleFactor for all at once.
do
    local nuke = fxDamage(ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC)
    registerItemFX(FourCC('A03Z'), 0, 5, nuke)  -- I049/I01J  Storm Bolt (200 base + 5/lvl)
    registerItemFX(FourCC('A084'), 0, 5, nuke)  -- I04B       Storm Bolt (200 base + 5/lvl)
    registerItemFX(FourCC('A0AE'), 0, 5, nuke)  -- I05U       Storm Bolt (200 base + 5/lvl)
    registerItemFX(FourCC('A0BO'), 0, 5, nuke)  -- I06K       Storm Bolt (200 base + 5/lvl, 4s stun)
    registerItemFX(FourCC('A0BP'), 0, 5, nuke)  -- I06L       Holy Bolt  (200 base + 5/lvl)
    registerItemFX(FourCC('A0BQ'), 0, 5, nuke)  -- I06M (Rare) Storm Bolt (200 base + 5/lvl)
    -- AoE nukes: additive bonus to enemies near the impact (Shockwave) / caster (War Stomp).
    registerItemFX(FourCC('A00F'), 0, 5,
        fxDamageArea(220, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC))  -- I01F  Shockwave (150 base + 5/lvl)
    registerItemFX(FourCC('A08W'), 0, 5,
        fxDamageArea(250, true,  ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC))  -- I04T  War Stomp (AoE + 5/lvl)
end

-- To register more: read the item's A0xx ability base in dirty/objects_items.json +
-- objects_abilities.json (triage via dirty/item_triage2.py), pick perLevel, add a row.
-- AoE/point nukes (Shockwave, War Stomp) need a custom apply that reads GetSpellTargetX/Y
-- and damages a group. For an item whose base the SCRIPT should own entirely, zero the
-- template damage via objediting and set base to the full value.
