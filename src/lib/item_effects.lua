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

-- On-attack proc items (require the DDS — items/ItemEffects.md §4). Ordered sequence so the
-- per-attack scan is sync-safe. Each item grants a native on-hit proc (poison/frost) in its
-- object data that deals a FLAT amount; we add an ADDITIVE hero-level bonus on the same proc
-- chance through the DDS, so base 0 (native keeps its flat hit) + perLevel × heroLevel — no
-- object-data change, no double-dip.
ItemProcFX = {}   -- [n] = { itemId, chance, base, perLevel, attackType, damageType }
function registerItemProcFX(itemCode, chance, base, perLevel, attackType, damageType)
    ItemProcFX[#ItemProcFX + 1] = {
        itemId     = FourCC(itemCode),
        chance     = chance,
        base       = base,
        perLevel   = perLevel,
        attackType = attackType or ATTACK_TYPE_NORMAL,
        damageType = damageType or DAMAGE_TYPE_NORMAL,
    }
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

-- Heal the caster itself (for self-use heal items with no spell target).
function fxHealSelf()
    return function(caster, _, amount)
        if not caster then return end
        SetUnitState(caster, UNIT_STATE_LIFE,
            GetUnitState(caster, UNIT_STATE_LIFE) + amount)
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

    -- On-attack procs: when an attack lands, each registered proc item the attacker
    -- carries rolls its chance and adds scaled bonus damage via the DDS. Cheap — only
    -- runs on attack damage, and the inventory check short-circuits for units without
    -- the item. Bonus damage is dealt with DDS.damage so it can't re-trigger the proc.
    if #ItemProcFX > 0 then
        DDS.register(function()
            if not DDS.isAttack() then return end
            local src = DDS.source()
            if not src or GetUnitTypeId(src) == 0 then return end
            local tgt = DDS.target()
            for i = 1, #ItemProcFX do
                local p = ItemProcFX[i]
                if UnitHasItemOfTypeBJ(src, p.itemId) and GetRandomInt(1, 100) <= p.chance then
                    local amount = Scaled(p.base, p.perLevel, src) * ItemScaleFactor
                    if amount > 0 then
                        DDS.damage(src, tgt, amount, p.attackType, p.damageType)
                    end
                end
            end
        end)
    end
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

-- Confirmed by item tooltip text (war3map.wts, resolved via dirty/item_tooltips.py) —
-- these custom-template actives couldn't be classified from object-data field codes alone,
-- so each is verified against what the item literally says it does. Still ADDITIVE: the
-- ability keeps its own base damage/heal, the script only adds perLevel × heroLevel.
do
    local nuke = fxDamage(ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC)
    registerItemFX(FourCC('A02D'), 0, 5, nuke)  -- I00S Edge's Gauntlets: chain lightning, 75/bounce (+5/lvl on primary)
    registerItemFX(FourCC('A0D7'), 0, 5, nuke)  -- I078 Thunder Rod: periodic 50-dmg bolt (+5/lvl)
    registerItemFX(FourCC('A0D9'), 0, 5, nuke)  -- I079 Rillan Blowdarts: 300 dmg over 15s (+5/lvl burst on cast)
    registerItemFX(FourCC('A04A'), 0, 5,
        fxDamageArea(900, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC))  -- I01Q Wand of Infernos: 450 AoE (+5/lvl)
    registerItemFX(FourCC('A02B'), 0, 5, fxHealSelf())  -- I00Q Ankh of Vitality: heal 50 on use (+5/lvl)
end

-- Lv2 / set-pool damage & heal actives (triage: dirty/item_triage_lv2.py → dirty/lv2_triage.txt,
-- ItemEffects.md §3-E). Same ADDITIVE convention: the object-data ability keeps its flat
-- base damage/heal, the script adds perLevel × heroLevel on top — no object-data change, no
-- double-dip. These ability ids are all distinct from the Lv1 rows above, so they slot into
-- the existing SPELL_EFFECT dispatch unchanged. (Lv1-pool set members that reuse a Lv1
-- ability — I049/A03Z, I04B/A084 — are already covered by the shared Lv1 registrations.)
do
    local nuke = fxDamage(ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC)
    registerItemFX(FourCC('A06L'), 0, 5, nuke)         -- I03B Wand of Lightning Bolts: Storm Bolt 150 (+5/lvl)
    registerItemFX(FourCC('A06G'), 0, 5, nuke)         -- I034 Hooked Dagger: Shadow Strike 175 +125 DoT (+5/lvl burst)
    registerItemFX(FourCC('A06E'), 0, 5,
        fxDamageArea(290, true, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC))  -- I030 Halflings Sling: Fan of Knives 45 AoE (+5/lvl, r290 around hero)
    registerItemFX(FourCC('A0DE'), 0, 5, fxHeal())     -- I07I Woolen Bandages: heal 500/8s to target (+5/lvl burst)
end

-- On-attack proc items (routed through the DDS, see RegisterItemEffectTriggers). The item's
-- object-data proc keeps dealing its flat poison/frost; these rows add the hero-level GROWTH
-- (base 0 + perLevel × heroLevel) on the same chance, so the proc scales into the late game.
-- (ItemEffects.md §4: I01K Rusty Maul = 10% poison-on-hit; I01M Blade of the Coral Masters =
--  15% 100-frost-on-hit. Tune chance/perLevel or ItemScaleFactor for balance.)
registerItemProcFX('I01K', 10, 0, 5, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_POISON)  -- Rusty Maul
registerItemProcFX('I01M', 15, 0, 5, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_COLD)    -- Blade of the Coral Masters

-- NOT registered here (intentional): AIpr "Replenish Life/Mana over Duration" passives —
-- I05T (A0AD) and I0A8 (A0HQ, Mendicant's Gloves, 225 HP/20s). AIpr is a passive
-- replenish-on-acquire ability (Health-Stone family): no order string, no cooldown, so it
-- never fires SPELL_EFFECT or USE_ITEM, and the reference war3map.j has zero trigger logic
-- for it (only the drop-pool slot udg_Lv2Rare[23]='I0A8', line 35484). It is engine-applied
-- object-data, handled by workstream D, not this registry. See ItemEffects.md §4-I0A8 / §4-D.
--
-- To register more: read the item's A0xx ability base in dirty/objects_items.json +
-- objects_abilities.json (triage via dirty/item_triage2.py), pick perLevel, add a row.
-- AoE/point nukes (Shockwave, War Stomp) need a custom apply that reads GetSpellTargetX/Y
-- and damages a group. For an item whose base the SCRIPT should own entirely, zero the
-- template damage via objediting and set base to the full value.
