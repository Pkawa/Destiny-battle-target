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

-- Remove_Skills (war3map.j 27520-27586): strip every scroll spell from the hero.
local function removeScrollSkills(hero)
    for _, abil in ipairs(STRIP) do
        UnitRemoveAbility(hero, abil)
    end
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
end
