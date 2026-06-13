-- Circle-scroll spell learning (Pattern A) — war3map.j 27586-29020.
-- Requirements: combat/Abilities.md §Pattern A, misc/TarotAndScrolls.md.
-- Using a scroll teaches the hero its spell; a hero can know only ONE scroll spell at a
-- time (Remove_Skills strips any previously learned one first). Class-restricted scrolls
-- refund themselves with a warning. The original's ~46 per-scroll triggers collapse into
-- this one table + a single USE_ITEM dispatch (data extracted via dirty/extract_scrolls.py).
--
-- Deviations (documented in KNOWN_BUGS §12): the original announces learns only to
-- Player(10) (bj_FORCE_PLAYER[10] — an observer-only quirk); we show the learning player.
-- Blood Pulse listed item I0C4 in the original — the same item as Devouring Plague (both
-- triggers fired on one use, teaching both spells), leaving its own scroll I0C5 dead.
-- Mapped to I0C5 here so the Gnasher's second spell scroll works.

-- Every scroll-taught ability — stripped before a new one is learned (one-scroll rule).
local STRIP = {
    'A08F','A08D','A08B','A08C','A08E','A09L','A0AL','A092','A096','A0AS','A0AT','A0AU',
    'A0AV','A04G','A0AW','A0AX','A04J','A0G3','A0G2','A0G4','A0G6','A0G5','A0H4','A0H3',
    'A06X','A06Y','A0H5','A06U','A0HA','A06T','A0H6','A0H9','A0H7','A0G8','A0HB','A0HL',
    'A0HI','A0HM','A0HH','A0HG','A0HD','A0G7','A0KD','A0G9',
}
for i, code in ipairs(STRIP) do STRIP[i] = FourCC(code) end

-- [scroll item] = { abil, name [, notClass = {unit ids that may NOT learn it} ] }
local SCROLLS = {}
local function scroll(item, abil, name, notClass)
    SCROLLS[FourCC(item)] = {
        abil = FourCC(abil), name = name,
        notClass = notClass and (function()
            local t = {}
            for _, c in ipairs(notClass) do t[FourCC(c)] = true end
            return t
        end)() or nil,
    }
end

scroll('I059', 'A096', "Catfeet")
scroll('I05H', 'A09L', "Cut")
scroll('I065', 'A092', "Arcane Shield", { 'H001', 'H02X' })
scroll('I064', 'A0AL', "Acid Ball")
scroll('I067', 'A0AT', "Daze")
scroll('I068', 'A0AU', "Detect Magic")
scroll('I069', 'A0AV', "Smite")
scroll('I06A', 'A04G', "Flare")
scroll('I06B', 'A0AW', "Zap")
scroll('I01A', 'A0AX', "Mcbaine's Filching")
scroll('I07X', 'A04J', "Ray of Frost")
scroll('I08S', 'A0G3', "Spark Shower")
scroll('I08R', 'A0G2', "Lesser Fix")
scroll('I08T', 'A0G4', "Summon Squire Captain", { 'H03I' })
scroll('I08V', 'A0G5', "Spire")
scroll('I08U', 'A0G6', "Fury of the Mountains")
scroll('I09R', 'A0H7', "Minor Cure")
scroll('I09Q', 'A0H6', "Bless")
scroll('I09T', 'A0H9', "Magic Rations")
scroll('I09J', 'A06T', "Burning Palm")
scroll('I09U', 'A0HA', "Acid Wave")
scroll('I09K', 'A06U', "Lesser Charm Person")
scroll('I09P', 'A0H5', "Lesser Energy Burst")
scroll('I09M', 'A06Y', "Giant Growth")
scroll('I09L', 'A06X', "Mending")
scroll('I09N', 'A0H3', "Summon Creature I")
scroll('I09O', 'A0H4', "Sharpen")
scroll('I08X', 'A0G8', "Whirlpool")
scroll('I08W', 'A0G7', "Vortex")
scroll('I09V', 'A0HB', "Acid Lance")
scroll('I0A2', 'A0HL', "Animate Water")
scroll('I0A1', 'A0HI', "Breath of Life")
scroll('I0A3', 'A0HM', "Death Armor")
scroll('I0A0', 'A0HH', "Invisibility")
scroll('I09X', 'A0HG', "Summon Creature II")
scroll('I09W', 'A0HD', "Web")
scroll('I0C4', 'A0G9', "Devouring Plague")
scroll('I0C5', 'A0KD', "Blood Pulse")          -- original said I0C4 (duplicate) — fixed
scroll('I04M', 'A08F', "Challenge")
scroll('I04L', 'A08E', "Crushing Blow")
scroll('I04J', 'A08C', "Sprint")
scroll('I03R', 'A08B', "Shield Block")
scroll('I04K', 'A08D', "Poisoned Weapons")

-- Published for the `-item scroll [name]` debug command (debug.lua → items.DebugSpawnItem).
DEBUG_SCROLL_CODES = {}
for id in pairs(SCROLLS) do DEBUG_SCROLL_CODES[#DEBUG_SCROLL_CODES + 1] = id end

-- Remove_Skills (war3map.j 27520-27586): strip every scroll spell from the hero.
local function removeScrollSkills(hero)
    for _, abil in ipairs(STRIP) do
        UnitRemoveAbility(hero, abil)
    end
end

-- ── Circle scroll DROP system (war3map.j 33677-33918) ──────────────────────────
-- A separate kill-counter (ScrollDrop / TotalScrollDrop, shared across tiers) that drops a
-- random scroll item from the active Circle pool on Player(9) deaths. Three tiers, only one
-- active at a time: Circle 0 from the start, -> Circle 1 at the Level-10 victory (war3map.j
-- 20540), -> Circle 2 at the Level-20 victory (war3map.j 22492). The original's three
-- near-identical triggers collapse into one drop trigger that reads the active tier.
--
-- Faithful draw bounds (note Circle 0 draws 0..13 over a table whose index 6 is never set —
-- ~1/14 of drops land on the empty slot and spill nothing; preserved). Tables built 0-indexed
-- to match the original GetRandomInt(lo, hi) inclusive draws.
local CIRCLE_TIERS = {}
do
    local function tier(maxDraw, entries)  -- entries: { [index] = 'Ixxx', ... }
        local t = { maxDraw = maxDraw }
        for idx, code in pairs(entries) do t[idx] = FourCC(code) end
        return t
    end
    -- Circle 0 (war3map.j 33848): indices 0-18 with a gap at 6; drop draws 0..13.
    CIRCLE_TIERS[0] = tier(13, {
        [0]='I064', [1]='I065', [2]='I059', [3]='I05H', [4]='I067', [5]='I068',
        [7]='I069', [8]='I06A', [9]='I06B', [10]='I01A', [11]='I07X', [12]='I08S',
        [13]='I08R', [14]='I04M', [15]='I04K', [16]='I03R', [17]='I04J', [18]='I04L',
    })
    -- Circle 1 (war3map.j 33879): indices 0-10; drop draws 0..10.
    CIRCLE_TIERS[1] = tier(10, {
        [0]='I09U', [1]='I09J', [2]='I09Q', [3]='I09M', [4]='I09K', [5]='I09P',
        [6]='I09T', [7]='I09L', [8]='I09R', [9]='I09O', [10]='I09N',
    })
    -- Circle 2 (war3map.j 33903): indices 0-6; drop draws 0..6.
    CIRCLE_TIERS[2] = tier(6, {
        [0]='I09V', [1]='I0A2', [2]='I0A1', [3]='I0A3', [4]='I0A0', [5]='I09X', [6]='I09W',
    })
end
local scrollTier = 0

-- Advance to the next scroll-drop tier (Level-10 victory: 0->1; Level-20 victory: 1->2).
function UpgradeScrollTier()
    if scrollTier < 2 then scrollTier = scrollTier + 1 end
end

function RegisterScrollDropTriggers()
    local t = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(t, Player(9), EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(t, Condition(function()
        local id = GetUnitTypeId(GetDyingUnit())
        return id ~= FourCC('e002') and id ~= FourCC('e003') and id ~= FourCC('e007')
    end))
    TriggerAddAction(t, function()
        if ScrollDrop < TotalScrollDrop then
            ScrollDrop = ScrollDrop + GetRandomInt(0, 5) + 1
            return
        end
        ScrollDrop = 0
        local tier = CIRCLE_TIERS[scrollTier]
        local code = tier[GetRandomInt(0, tier.maxDraw)]   -- may be nil on Circle 0's gap
        if code then
            CreateItem(code, GetUnitX(GetDyingUnit()), GetUnitY(GetDyingUnit()))
        end
    end)
end

-- ── Scroll loot-boxes (war3map.j 34942-35011) ──
-- Three base-shop tokens grant a random scroll from a FIXED Circle pool (not the active
-- drop tier): I0AM->Circle 0, I0AN->Circle 1, I0AO->Circle 2. The original draws over the
-- same inclusive bounds as the drop system (Circle 0 has the index-6 gap → ~1/14 spill).
-- economy/Economy.md §5.
function RegisterScrollBoxTriggers()
    local function scrollBox(tokenCode, circle)
        local token = FourCC(tokenCode)
        local tier = CIRCLE_TIERS[circle]
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_PICKUP_ITEM)
        TriggerAddCondition(t, Condition(function()
            return GetItemTypeId(GetManipulatedItem()) == token
        end))
        TriggerAddAction(t, function()
            RemoveItem(GetManipulatedItem())
            local code = tier[GetRandomInt(0, tier.maxDraw)]   -- may be nil on Circle 0's gap
            if code then UnitAddItemByIdSwapped(code, GetManipulatingUnit()) end
        end)
    end
    scrollBox('I0AM', 0)   -- Lv0 scroll box (war3map.j 34944)
    scrollBox('I0AN', 1)   -- Lv1 scroll box (war3map.j 34968)
    scrollBox('I0AO', 2)   -- Lv2 scroll box (war3map.j 34992)
end

function RegisterScrollTriggers()
    OnAnyUnit(EVENT_PLAYER_UNIT_USE_ITEM, function()
        return SCROLLS[GetItemTypeId(GetManipulatedItem())] ~= nil
    end, function()
        local item = GetManipulatedItem()
        local s = SCROLLS[GetItemTypeId(item)]
        local hero = GetManipulatingUnit()
        local owner = GetOwningPlayer(hero)
        if s.notClass and s.notClass[GetUnitTypeId(hero)] then
            -- class restriction: warn + drop the scroll back on the ground (war3map.j 27674)
            DisplayTextToForce(GetForceOfPlayer(owner),
                "This hero may not learn this spell due to a spell restriction.")
            TriggerSleepAction(1.0)
            CreateItem(GetItemTypeId(item), GetUnitX(hero), GetUnitY(hero))
            return
        end
        removeScrollSkills(hero)
        RemoveItem(item)
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(owner) .. " Learned " .. s.name .. ".")
        TriggerSleepAction(1.0)
        if GetUnitTypeId(hero) ~= 0 then
            UnitAddAbility(hero, s.abil)
        end
    end)

    registerScrollEffects()
end

-- ── Learned-spell EFFECT triggers (war3map.j 28761-29020) ──────────────────────
-- Six learned spells carry trigger-side effects beyond their object data.
function registerScrollEffects()
    -- Cut (A09L): the slash deals STR + 50 bonus damage to the target.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A09L')
    end, function()
        local c = GetSpellAbilityUnit()
        UnitDamageTarget(c, GetSpellTargetUnit(), GetHeroStr(c, true) + 50.0,
            false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
    end)

    -- Devouring Plague (A0G9): 30s after casting, the caster recovers 450 HP.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0G9')
    end, function()
        local c = GetSpellAbilityUnit()
        TriggerSleepAction(30.0)
        if GetUnitTypeId(c) ~= 0 then
            SetUnitLifeBJ(c, GetUnitState(c, UNIT_STATE_LIFE) + 450.0)
            FloatText(c, "+450", 0, 100, 0, 6.0)
        end
    end)

    -- Blood Pulse (A0KD): a ring of 8 e007 pulse dummies + 250 damage in 100 around the caster.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0KD')
    end, function()
        local c = GetSpellAbilityUnit()
        local x, y = GetUnitX(c), GetUnitY(c)
        for _, off in ipairs({ {-50,0},{50,0},{0,50},{0,-50},{-50,-50},{-50,50},{50,-50},{50,50} }) do
            CreateUnit(Player(8), FourCC('e007'), x + off[1], y + off[2], bj_UNIT_FACING)
        end
        UnitDamagePoint(c, 0, 250.0, x, y, 100.0, false, false,
            ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
    end)

    -- Demon Lights (A0AS): four wandering lights (e010/e00Y/e00Z/e00X) around the caster
    -- for ~20s. Simplified: the original choreographs per-second move orders; here the
    -- lights wander on a 1s tick and are removed at the end (cosmetic).
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0AS')
    end, function()
        local c = GetSpellAbilityUnit()
        local owner = GetOwningPlayer(c)
        local lights = {}
        for _, id in ipairs({ 'e010', 'e00Y', 'e00Z', 'e00X' }) do
            local a = math.rad(GetRandomReal(0.0, 360.0))
            local d = GetRandomReal(0.0, 200.0)
            lights[#lights + 1] = CreateUnit(owner, FourCC(id),
                GetUnitX(c) + d * math.cos(a), GetUnitY(c) + d * math.sin(a), bj_UNIT_FACING)
        end
        for _ = 1, 20 do
            TriggerSleepAction(1.0)
            for _, u in ipairs(lights) do
                if GetUnitTypeId(u) ~= 0 then
                    local a = math.rad(GetRandomReal(0.0, 360.0))
                    IssuePointOrder(u, "move",
                        GetUnitX(u) + 150.0 * math.cos(a), GetUnitY(u) + 150.0 * math.sin(a))
                end
            end
        end
        for _, u in ipairs(lights) do RemoveUnit(u) end
    end)

    -- Macbaine's Filching (A0AX): steal AGI + 1d50 gold ("N Gold stolen!").
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0AX')
    end, function()
        local c = GetSpellAbilityUnit()
        local amount = GetHeroAgi(c, true) + GetRandomInt(1, 50)
        AdjustPlayerStateBJ(amount, GetOwningPlayer(c), PLAYER_STATE_RESOURCE_GOLD)
        FloatText(c, tostring(amount) .. " Gold stolen!", 100, 100, 0, 3.0)
    end)

    -- Magic Rations (A0H9): conjure a rations item (I09S) at the caster's feet.
    OnAnyUnit(EVENT_PLAYER_UNIT_SPELL_EFFECT, function()
        return GetSpellAbilityId() == FourCC('A0H9')
    end, function()
        local c = GetSpellAbilityUnit()
        CreateItem(FourCC('I09S'), GetUnitX(c), GetUnitY(c))
    end)
end
