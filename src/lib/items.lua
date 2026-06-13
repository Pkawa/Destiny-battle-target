-- Item rarity pools (Lv1) + the level-based loot drop system.
-- Requirements: items/Items.md §3 (pools + Lv_1_Item), economy/Economy.md.
-- Source: war3map.j 35253-35408 (Lv1 Unc/Rare/Epic/Artifact pool inits),
--   34107-34176 (Lv_1_Item drop), 2552 (ItemDropTotal = 50), 33546-33549 (totals).
--
-- Every Player(9) kill adds 1-6 to ItemDrop; once it reaches ItemDropTotal (50) an item
-- drops at the corpse — rarity-rolled 60% uncommon / 30% rare / 7% epic / 3% artifact —
-- and the counter resets. These pools are the shared loot source the rest of the economy
-- (Purchase loot-boxes, Auction House, Sell) will read once those are ported.
-- The drop is tier-aware: UpgradeLootTier() (fired from LevelData[10].onCleared) switches
-- to the Lv2 pools at the Level-10 victory (war3map.j 20538, Lv_2_Item). Circle scroll drops
-- live in scrolls.lua. Not yet ported: cursed drops, ItemDropTotal research reductions.

-- Build a 0-indexed FourCC pool (matches the original's GetRandomInt(0, total) inclusive draw).
local function pool(codes)
    local t = { max = #codes - 1 }
    for i = 1, #codes do t[i - 1] = FourCC(codes[i]) end
    return t
end

local Lv1Uncommon = pool{
    'I000','I004','I002','I005','I007','I006','I008','I003','I001','I009',
    'I00C','I00B','I00D','I00O','I00V','I01B','I01F','I01E','I01N','I01K',
    'I01I','I01S','I01X','I01Z','I01Y','I020','I04B','I04D','I04E','I049',
    'I048','I047','I043','I044','I045','I04N','I04P','I04Q','I04S','I04T',
    'I04R','I05U','I05T','I05V','I06H','I06I','I06J','I06K','I06L','I06R',
}
local Lv1Rare = pool{
    'I00L','I00M','I00A','I00E','I00G','I00K','I00F','I00H','I00J','I00I',
    'I01C','I01G','I01H','I01T','I01J','I021','I05W','I05X','I05Y','I060',
    'I05Z','I061','I06M','I06N','I06O','I01O','I0CA','I0CD','I0CB',
}
local Lv1Epic = pool{
    'I00Q','I00R','I00S','I00P','I00T','I01D','I01L','I01P','I01R','I023',
    'I079','I04F','I04G','I05B','I05C','I05E','I05F','I06Q','I06P','I078',
}
local Lv1Artifact = pool{
    'I01M','I01U','I01Q','I024','I025','I063','I062','I06E','I07A','I07B',
}

-- Lv2 pools (war3map.j 35417-35520) — higher-tier loot, used by the Coral dungeon chest
-- (h05G), the Lv2 boss/level drops, and the Lv2 loot-boxes (ported as those land).
local Lv2Uncommon = pool{
    'I02W','I02X','I02Y','I02Z','I030','I031','I032','I033','I034','I035',
    'I036','I037','I09A','I08Y','I038','I07C','I07D','I07E','I04O','I07F',
    'I07G','I07H','I07I','I07J','I07K','I090','I08Z','I09C','I09D','I09E','I09F',
}
local Lv2Rare = pool{
    'I039','I03A','I03B','I03C','I03D','I03E','I03F','I03G','I03H','I03I',
    'I092','I091','I093','I09Z','I09Y','I03X','I0AA','I0A9','I0AB','I0AJ',
    'I0B3','I0B2','I0B1','I0A8','I0B6','I0B5','I03Y',
}
local Lv2Epic = pool{
    'I03J','I03K','I03L','I03M','I03N','I03O','I03P','I0AK','I02R','I022',
    'I050','I04X','I08K','I0B7','I0BA','I0BB','I0BC',
}
local Lv2Artifact = pool{
    'I04I','I06D','I01M','I024',
}

-- Level-based loot tiers (war3map.j 34107 Lv_1_Item / 34242 Lv_2_Item). The two JASS
-- triggers are identical bar the pool set and which is enabled; we keep one drop trigger
-- that reads the active tier. Tier flips to 2 at the Level-10 victory (UpgradeLootTier,
-- war3map.j 20538: DisableTrigger Lv_1_Item / EnableTrigger Lv_2_Item).
local LOOT_TIERS = {
    { unc = Lv1Uncommon, rare = Lv1Rare, epic = Lv1Epic, arti = Lv1Artifact },
    { unc = Lv2Uncommon, rare = Lv2Rare, epic = Lv2Epic, arti = Lv2Artifact },
}
local lootTier = 1

-- Set-item pools the Auction House stocks (war3map.j 32848-32891 / 33554+). 0-indexed to
-- match the original's GetRandomInt(0, Total) inclusive draw. Totals (war3map.j 2699-2702):
-- Lv1 rare = 11, Lv1 epic = 5, Lv2 rare = 8, Lv2 epic = 5.
local Lv1RareSetItem = pool{
    'I043','I044','I045','I047','I048','I049','I04D','I04E','I04B','I0CA','I0CB','I0CD',
}
local Lv1EpicSetItem = pool{ 'I04G','I04F','I05B','I05C','I05F','I05E' }
local Lv2RareSetItem = pool{ 'I092','I091','I093','I0AB','I0A9','I0AA','I0B3','I0B2','I0B1' }
-- Faithful quirk: the original sets only indices 1-4 yet TotalEpicSetItems = 5, so a
-- GetRandomInt(0,5) draw lands on an empty slot (0 or 5) ~1/3 of the time and stocks nothing.
-- Preserved (guarded against nil where it's drawn).
local Lv2EpicSetItem = { max = 5 }
Lv2EpicSetItem[1] = FourCC('I04X')
Lv2EpicSetItem[2] = FourCC('I050')
Lv2EpicSetItem[3] = FourCC('I0BC')
Lv2EpicSetItem[4] = FourCC('I0BB')

local function drawFrom(p)
    return p[GetRandomInt(0, p.max)]
end

-- Dramlor's Guarantee (Swashbuckler ult, war3map.j 42991): drop 1 Lv2 + 2 Lv1 artifacts at (x,y).
-- Exposed so abilities.lua can reuse the encapsulated artifact pools.
function DropDramlorGuarantee(x, y)
    CreateItem(drawFrom(Lv2Artifact), x, y)
    CreateItem(drawFrom(Lv1Artifact), x, y)
    CreateItem(drawFrom(Lv1Artifact), x, y)
end

-- Luck outcome 3 (Cleric of the Small Folk, war3map.j 38900): drop one random Lv1 epic at (x,y).
-- Exposed so abilities.lua can reuse the encapsulated epic pool.
function DropEpicItem(x, y)
    CreateItem(drawFrom(Lv1Epic), x, y)
end

-- Lv_1_Item (war3map.j 34107) — enabled from the start (Lv_2_Item is for later levels).
function RegisterItemDropTriggers()
    local t = CreateTrigger()
    trg_Lv1ItemDrop = t   -- exposed so the Adomach fight can suspend kill-drops (adomach.lua)
    TriggerRegisterPlayerUnitEventSimple(t, Player(9), EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(t, Condition(function()
        local id = GetUnitTypeId(GetDyingUnit())
        return id ~= FourCC('e002') and id ~= FourCC('e003') and id ~= FourCC('e007')
    end))
    TriggerAddAction(t, function()
        if ItemDrop < ItemDropTotal then
            ItemDrop = ItemDrop + GetRandomInt(0, 5) + 1
            return
        end
        ItemDrop = 0
        RandomItemChance = GetRandomInt(1, 100)
        if ArtificierFeatOn then RandomItemChance = RandomItemChance + 1 end

        local tier = LOOT_TIERS[lootTier]
        local loc = GetUnitLoc(GetDyingUnit())
        if RandomItemChance <= 60 then
            CreateItemLoc(drawFrom(tier.unc), loc)
        elseif RandomItemChance <= 90 then
            CreateItemLoc(drawFrom(tier.rare), loc)
        elseif RandomItemChance <= 97 then
            CreateItemLoc(drawFrom(tier.epic), loc)
        else
            CreateItemLoc(drawFrom(tier.arti), loc)
            local killer = GetKillingUnitBJ()
            local who = killer and GetPlayerName(GetOwningPlayer(killer)) or "Someone"
            DisplayTextToForce(GetPlayersAll(),
                who .. " |cffff0000discovered |r" .. GetItemName(GetLastCreatedItem()))
            PlaySoundBJ(snd.AllianceSound)
        end
        RemoveLocation(loc)
    end)
end

-- Loot-tier upgrade fired by the Level-10 victory (war3map.j 20538-20543): kill-drops and
-- the treasure-chest pinata switch to the Lv2 pools / Lv2 chest model (h05E). The matching
-- scroll-drop upgrade (Circle 0 -> 1) lives in scrolls.lua (UpgradeScrollTier).
function UpgradeLootTier()
    lootTier = 2
    TreasureChestLevel2 = true
end

-- ── Dungeon / Treasure chests (war3map.j 34602-34935; Dungeon Chest Level 0/1/2) ──
-- Each dungeon's chest is invulnerable (Avul) until its boss dies — discover.lua removes
-- Avul on the boss death. Destroying the now-vulnerable chest spills tiered loot and may
-- spring a trap when the party's Locksmithing research is low:
--   ChestTrap = rand(1,10) - Locksmithing; if >= 6 one of four traps fires.
-- Loot per chest type (one item drawn from each listed pool):
local CHEST_LOOT = {
    [FourCC('h06I')] = { Lv1Rare, Lv1Rare, Lv1Uncommon, Lv1Uncommon, Lv1Uncommon }, -- Sewers / Treasure Cove
    [FourCC('h056')] = { Lv1Rare, Lv1Rare, Lv1Epic, Lv1Epic, Lv1Artifact },          -- Outskirts
    [FourCC('h05G')] = { Lv2Rare, Lv2Rare, Lv2Epic, Lv2Epic, Lv2Artifact },          -- Coral Cove
}
local CHEST_TRAP_SFX = {
    "Abilities\\Spells\\Orc\\SpikeBarrier\\SpikeBarrier.mdl",
    "Abilities\\Spells\\NightElf\\FanOfKnives\\FanOfKnivesCaster.mdl",
    "Abilities\\Spells\\Human\\FlameStrike\\FlameStrike1.mdl",
    "Abilities\\Spells\\Undead\\DeathPact\\DeathPactTarget.mdl",
}
local CHEST_TRAP_MSG = {
    "TRAPPED! - Spike Trap", "TRAPPED! - Needle Trap",
    "TRAPPED! - Self Destruct!!", "TRAPPED! - Mana Shear!",
}

local function chestTrapText(loc, msg)
    CreateTextTagLocBJ(msg, loc, 0, 10, 100, 100, 100, 0)
    SetTextTagPermanentBJ(GetLastCreatedTextTag(), false)
    SetTextTagLifespanBJ(GetLastCreatedTextTag(), 5)
end

-- The low-Locksmithing trap shared by both chest systems (pre-placed dungeon chests and
-- the dropped treasure chests). With a bad lockpick roll one of four traps fires.
-- Does NOT remove `loc` — the caller owns it.
local function springChestTrap(d, loc)
    -- Locksmithing reduces the trap chance; <6 means the lock was picked safely.
    if GetRandomInt(1, 10) - (Locksmithing or 0) < 6 then return end
    local trap = GetRandomInt(1, 4)
    chestTrapText(loc, CHEST_TRAP_MSG[trap])
    if trap == 1 then  -- Spike Trap: 200 dmg in r225
        local sfx = AddSpecialEffectLocBJ(loc, CHEST_TRAP_SFX[1])
        UnitDamagePointLoc(d, 0, 225.0, loc, 200.0, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL)
        TriggerSleepAction(3.0)
        DestroyEffect(sfx)
    elseif trap == 2 then  -- Needle Trap: 100 dmg in r450
        local sfx = AddSpecialEffectLocBJ(loc, CHEST_TRAP_SFX[2])
        UnitDamagePointLoc(d, 0, 450.0, loc, 100.0, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL)
        TriggerSleepAction(3.0)
        DestroyEffect(sfx)
    elseif trap == 3 then  -- Self Destruct: delayed 500 dmg in r350
        UnitDamagePointLoc(d, 5.0, 350.0, loc, 500.0, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL)
        TriggerSleepAction(5.0)
        local sfx = AddSpecialEffectLocBJ(loc, CHEST_TRAP_SFX[3])
        TriggerSleepAction(3.0)
        DestroyEffect(sfx)
    else  -- Mana Shear: drain the opener's mana
        local killer = GetKillingUnitBJ()
        if killer then SetUnitManaPercentBJ(killer, 0.0) end
        local sfx = AddSpecialEffectLocBJ(loc, CHEST_TRAP_SFX[4])
        TriggerSleepAction(3.0)
        DestroyEffect(sfx)
    end
end

function RegisterChestTriggers()
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(t, Condition(function()
        return CHEST_LOOT[GetUnitTypeId(GetDyingUnit())] ~= nil
    end))
    TriggerAddAction(t, function()
        local d = GetDyingUnit()
        local loot = CHEST_LOOT[GetUnitTypeId(d)]
        local loc = GetUnitLoc(d)
        for _, p in ipairs(loot) do
            CreateItemLoc(drawFrom(p), loc)
        end
        springChestTrap(d, loc)
        RemoveLocation(loc)
    end)
end

-- ── Treasure Chest Drop (war3map.j 34292-34600) ──
-- A loot pinata separate from the pre-placed dungeon chests above: every Player(9) kill
-- accumulates TreasureChestDrop by 1-6, and at >=300 a Treasure Chest unit spawns at the
-- corpse owned by Player(11) (so the party must kill it). Destroying that chest spills
-- 2 Uncommon + 2 Rare + 1 Epic from the tier pools, plus a possible Locksmithing trap.
-- The Lv2 swap (h05E + Lv2 pools) fires at the Level 10->11 loot-tier upgrade; until that
-- upgrade is ported the system stays on Lv1 (h04E) — set TreasureChestLevel2 to flip it.
local TREASURE_CHEST_LOOT = {
    [FourCC('h04E')] = { Lv1Uncommon, Lv1Uncommon, Lv1Rare, Lv1Rare, Lv1Epic },
    [FourCC('h05E')] = { Lv2Uncommon, Lv2Uncommon, Lv2Rare, Lv2Rare, Lv2Epic },
}
function RegisterTreasureChestDrop()
    -- Accumulate on Player(9) deaths (skip the three corpse dummies) and spawn the chest.
    local acc = CreateTrigger()
    TriggerRegisterPlayerUnitEventSimple(acc, Player(9), EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(acc, Condition(function()
        local id = GetUnitTypeId(GetDyingUnit())
        return id ~= FourCC('e002') and id ~= FourCC('e003') and id ~= FourCC('e007')
    end))
    TriggerAddAction(acc, function()
        if TreasureChestDrop < 300 then
            TreasureChestDrop = TreasureChestDrop + GetRandomInt(0, 5) + 1
            return
        end
        TreasureChestDrop = 0
        local d = GetDyingUnit()
        local x, y = GetUnitX(d), GetUnitY(d)
        local chest = TreasureChestLevel2 and FourCC('h05E') or FourCC('h04E')
        CreateUnit(Player(11), chest, x, y, bj_UNIT_FACING)
        DisplayTextToForce(GetPlayersAll(), "Treasure Chest Spawn")
        PingMinimap(x, y, 5.0)
    end)

    -- Killing the spawned chest -> tiered loot + possible trap.
    local kill = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(kill, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(kill, Condition(function()
        return TREASURE_CHEST_LOOT[GetUnitTypeId(GetDyingUnit())] ~= nil
    end))
    TriggerAddAction(kill, function()
        local d = GetDyingUnit()
        local loot = TREASURE_CHEST_LOOT[GetUnitTypeId(d)]
        local loc = GetUnitLoc(d)
        for _, p in ipairs(loot) do
            CreateItemLoc(drawFrom(p), loc)
        end
        springChestTrap(d, loc)
        RemoveLocation(loc)
    end)
end

-- Fixed single-item drops for four specific world units (war3map.j 2790-2920 +
-- 4140-4189: Unit000180/278/299/300_DropItems). Each guarantees one item at the corpse.
local WORLD_UNIT_DROPS = {
    [FourCC('h039')] = FourCC('I0CG'),  -- southern overseer (22305,-4069)
    [FourCC('h06H')] = FourCC('I0BV'),  -- Dire Rat / "gargantuan rat" (Vern Sewers boss)
    [FourCC('h06K')] = FourCC('I0C0'),  -- (-409,-9183)
    [FourCC('n016')] = FourCC('I0CE'),  -- Ice Dragon
}
function RegisterWorldDropTriggers()
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(t, Condition(function()
        return WORLD_UNIT_DROPS[GetUnitTypeId(GetDyingUnit())] ~= nil
    end))
    TriggerAddAction(t, function()
        local d = GetDyingUnit()
        if IsUnitHidden(d) then return end
        CreateItem(WORLD_UNIT_DROPS[GetUnitTypeId(d)], GetUnitX(d), GetUnitY(d))
    end)
end

-- ── Cursed item drop (war3map.j 33603-33672, 35240-35249; items/Items.md §3) ──
-- A one-cursed-drop-per-game mechanic. Each level start runs a d10 roll
-- (Cursed_Item_Drop_1_to_10, war3map.j 33603) escalated by CursedItemBonus, which
-- starts at 0 (InitGlobals 2632) and self-increments by 1 on every failed roll
-- (war3map.j 33628) — so the chance of arming climbs each level. The FIRST roll that
-- hits >=10 disarms the roll (CursedItemOn=false) and arms the actual-drop trigger.
-- That trigger (Cursed_Actual_Drop_For_Level_1_to_10, war3map.j 33642) starts DISABLED
-- and, once armed, waits for 20 further Player(9) deaths (CursedKillDropCounter) before
-- dropping one of two cursed items (I095 / I0B8) at the 21st kill's corpse, then disables
-- itself. The two cursed item ids are seeded by Lv_1_Cursed_Item_Drop (war3map.j 35240,
-- a T+30s timer in the original); since registration already runs after load we seed the
-- Lv1CursedItemDrop pool here directly. (The original's DEBUG DisplayTextToForce spam at
-- 33619/33623/33624 is intentionally not ported.)
local cursedActualDrop  -- the armed-but-disabled drop trigger, shared by the roll

function RegisterCursedItemTriggers()
    -- Seed the cursed pool (war3map.j 35241-35242 — originally a T+30s single timer).
    Lv1CursedItemDrop[1] = FourCC('I095')
    Lv1CursedItemDrop[2] = FourCC('I0B8')

    -- Cursed_Actual_Drop_For_Level_1_to_10 (war3map.j 33642) — starts disabled; armed by
    -- CursedItemRoll(). Fires on the 21st Player(9) death after arming, then disables itself.
    local t = CreateTrigger()
    cursedActualDrop = t
    DisableTrigger(t)
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(t, Condition(function()
        return GetOwningPlayer(GetDyingUnit()) == Player(9)
    end))
    TriggerAddAction(t, function()
        if CursedKillDropCounter >= 20 then
            local d = GetDyingUnit()
            CreateItem(Lv1CursedItemDrop[GetRandomInt(1, 2)], GetUnitX(d), GetUnitY(d))
            DisableTrigger(t)
        else
            CursedKillDropCounter = CursedKillDropCounter + 1
        end
    end)
end

-- Cursed_Item_Drop_1_to_10 (war3map.j 33603) — the per-level roll. Wire into the per-level
-- start (the original fires it via ConditionalTriggerExecute at war3map.j 7405 / 19181).
-- No-op once a cursed drop has been armed (CursedItemOn=false). On a roll of >=10 it disarms
-- itself and arms the actual-drop trigger; otherwise it bumps CursedItemBonus for next level.
function CursedItemRoll()
    if not CursedItemOn then return end
    CursedItemDrop = GetRandomInt(1, 10) + CursedItemBonus
    if CursedItemDrop >= 10 then
        CursedItemOn = false
        if cursedActualDrop then EnableTrigger(cursedActualDrop) end
    else
        CursedItemBonus = CursedItemBonus + 1
    end
end

-- ── Boss drops (war3map.j 31906-32033; bosses/Bosses.md §1) ──
-- Each level boss drops one random GEAR item + one random SPELL scroll at its corpse.
-- The four per-boss JASS triggers collapse into one registry + one death dispatch.
-- (Meldokk's spell table lists I08T twice in the original — it always drops I08T.)
local BOSS_DROPS = {
    [FourCC('H00C')] = {  -- Meldokk (Level 6 miniboss)
        gear   = { FourCC('I075'), FourCC('I076'), FourCC('I074'), FourCC('I077') },
        spells = { FourCC('I08T') },
    },
    [FourCC('O001')] = {  -- Goblin King (Level 10)
        gear   = { FourCC('I0A4'), FourCC('I0A5'), FourCC('I0A6'), FourCC('I0A7') },
        spells = { FourCC('I08V'), FourCC('I08U') },
    },
    [FourCC('O002')] = {  -- Tidedweller (Level 14)
        gear   = { FourCC('I0AE'), FourCC('I0AD'), FourCC('I0AF') },
        spells = { FourCC('I08W'), FourCC('I08X') },
    },
    [FourCC('O004')] = {  -- Gnasher / Undead Behemoth (Level 20)
        gear   = { FourCC('I0C1'), FourCC('I0C2'), FourCC('I0C3') },
        spells = { FourCC('I0C4'), FourCC('I0C5') },
    },
}

function RegisterBossDropTriggers()
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(t, Condition(function()
        return BOSS_DROPS[GetUnitTypeId(GetDyingUnit())] ~= nil
            and not IsUnitIllusion(GetDyingUnit())
    end))
    TriggerAddAction(t, function()
        local u = GetDyingUnit()
        local d = BOSS_DROPS[GetUnitTypeId(u)]
        local x, y = GetUnitX(u), GetUnitY(u)
        CreateItem(d.gear[GetRandomInt(1, #d.gear)], x, y)
        CreateItem(d.spells[GetRandomInt(1, #d.spells)], x, y)
    end)
end

-- ── Dojo stat training (war3map.j 9513-9812; progression/Training.md §1) ──
-- Buying a training item from the Dojo gives ALL player heroes a permanent stat boost.
-- Only ONE training can be active: buying a new one first reverts the previous
-- (Turn_Off_Old_Training). The four near-identical SELL_ITEM triggers + the 4-branch
-- revert collapse into one table.
local DOJO = {
    { item = 'I06U', flag = 'DojoStrLv1Active', str = 10, agi = 0,  int = 0,
      on  = "|cff00ff00Strength training in the dojo has been activated.  All heroes gain 10 strength.|r",
      off = "|cffff0000Strength training in the dojo has been deactivated.  All heroes lose 10 strength.|r" },
    { item = 'I06V', flag = 'DojoAgiLv1Active', str = 0,  agi = 10, int = 0,
      on  = "|cff00ff00Reflex training in the dojo has been activated.  All heroes gain 10 agility.|r",
      off = "|cffff0000Reflex training in the dojo has been deactivated.  All heroes lose 10 agility.|r" },
    { item = 'I06W', flag = 'DojoIntLv1Active', str = 0,  agi = 0,  int = 10,
      on  = "|cff00ff00Focus training in the dojo has been activated.  All heroes gain 10 intelligence.|r",
      off = "|cffff0000Focus training in the dojo has been deactivated.  All heroes lose 10 intelligence.|r" },
    { item = 'I06X', flag = 'DojoAllLv1Active', str = 5,  agi = 5,  int = 5,
      on  = "|cff00ff00Balanced training in the dojo has been activated.  All heroes gain 5 to all stats.|r",
      off = "|cffff0000Balanced training in the dojo has been deactivated.  All heroes lose 5 to all stats.|r" },
}
local dojoByItem = {}
for _, d in ipairs(DOJO) do dojoByItem[FourCC(d.item)] = d end

-- Apply ±1× a training's stats to every player hero (heroes not owned by Player 9).
local function dojoApply(d, sign)
    local g = GetUnitsInRectMatching(GetPlayableMapRect(), Condition(function()
        return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO)
            and GetOwningPlayer(GetFilterUnit()) ~= Player(9)
    end))
    ForGroup(g, function()
        local u = GetEnumUnit()
        if d.str ~= 0 then ModifyHeroStat(bj_HEROSTAT_STR, u, bj_MODIFYMETHOD_ADD, sign * d.str) end
        if d.agi ~= 0 then ModifyHeroStat(bj_HEROSTAT_AGI, u, bj_MODIFYMETHOD_ADD, sign * d.agi) end
        if d.int ~= 0 then ModifyHeroStat(bj_HEROSTAT_INT, u, bj_MODIFYMETHOD_ADD, sign * d.int) end
    end)
    DestroyGroup(g)
end

local function turnOffOldTraining()
    for _, d in ipairs(DOJO) do
        if _G[d.flag] then
            DisplayTextToForce(GetPlayersAll(), d.off)
            dojoApply(d, -1)
            _G[d.flag] = false
        end
    end
end

function RegisterDojoTriggers()
    OnAnyUnit(EVENT_PLAYER_UNIT_SELL_ITEM, function()
        return dojoByItem[GetItemTypeId(GetSoldItem())] ~= nil
    end, function()
        local d = dojoByItem[GetItemTypeId(GetSoldItem())]
        RemoveItem(GetSoldItem())
        turnOffOldTraining()
        TriggerSleepAction(1.0)
        dojoApply(d, 1)
        _G[d.flag] = true
        DisplayTextToForce(GetPlayersAll(), d.on)
    end)
end

-- ── Set items (war3map.j 32601-33430; items/Items.md) ──
-- Picking up a set piece while holding ALL of that set's pieces consumes them and grants
-- the combined item (the Golem set spawns a golem unit instead; its flavor transmission is
-- omitted — cosmetic). Smithyworks may only be completed once. Recipes extracted from the
-- 11 per-set JASS triggers into one PICKUP_ITEM dispatch.
local SETS = {
    { pieces = { 'I04B', 'I04D', 'I04E' }, give = 'I04C', name = "the Apprentice's Regalia set" },
    { pieces = { 'I047', 'I048', 'I049' }, give = 'I04A', name = "the Bowman's Friend set" },
    { pieces = { 'I043', 'I044', 'I045' }, give = 'I046', name = "the Squire's Arnament set" },
    { pieces = { 'I0CA', 'I0CB', 'I0CD' }, give = 'I0CC', name = "the Leech set" },
    { pieces = { 'I091', 'I092', 'I093' }, give = 'I094', name = "Don Para's Inquisitor set" },
    { pieces = { 'I0A9', 'I0AA', 'I0AB' }, give = 'I0AC', name = "The Primal Fury set" },
    { pieces = { 'I0B1', 'I0B2', 'I0B3' }, give = 'I0B4', name = "The Mists set" },
    { pieces = { 'I05B', 'I05C' },         give = 'I05D', name = "the outrunner set" },
    { pieces = { 'I05E', 'I05F' },         give = 'I05G', name = "the Phalynx Guard Set" },
    { pieces = { 'I04X', 'I050' },         spawn = 'h04T', name = "the Golem Set" },
    { pieces = { 'I0BB', 'I0BC' },         give = 'I0BD', name = "the Smithyworks Set", once = true },
    -- Rainbow Orb artifact (war3map.j 33521 — its own standalone trigger in the original,
    -- folded into the set dispatch here): left + right halves combine into the whole orb.
    { pieces = { 'I063', 'I06E' },         give = 'I06F', name = "the Rainbow Orb Artifact" },
    -- Blackweave set (war3map.j 33119) — once-only. Set bonus (a 750 HP skeleton on the
    -- wearer's death, via HeroWithBlackweave) is a separate mechanic, not yet ported (⬜).
    { pieces = { 'I04F', 'I04G' },         give = 'I04H', once = true,
      name = "the blackweave set!  This set may not be completed again" },
}
local setByPiece = {}
for _, s in ipairs(SETS) do
    s.pieceIds = {}
    for i, p in ipairs(s.pieces) do
        local id = FourCC(p)
        s.pieceIds[i] = id
        setByPiece[id] = s
    end
    s.giveId = s.give and FourCC(s.give) or nil
    s.spawnId = s.spawn and FourCC(s.spawn) or nil
end

function RegisterSetTriggers()
    OnAnyUnit(EVENT_PLAYER_UNIT_PICKUP_ITEM, function()
        return setByPiece[GetItemTypeId(GetManipulatedItem())] ~= nil
    end, function()
        local s = setByPiece[GetItemTypeId(GetManipulatedItem())]
        local hero = GetManipulatingUnit()
        TriggerSleepAction(1.0)
        if s.done or GetUnitTypeId(hero) == 0 then return end
        for _, id in ipairs(s.pieceIds) do
            if not UnitHasItemOfTypeBJ(hero, id) then return end
        end
        for _, id in ipairs(s.pieceIds) do
            RemoveItem(GetItemOfTypeFromUnitBJ(hero, id))
        end
        if s.giveId then UnitAddItemById(hero, s.giveId) end
        if s.spawnId then
            local a = math.rad(GetRandomReal(0.0, 360.0))
            CreateUnit(GetOwningPlayer(hero), s.spawnId,
                GetUnitX(hero) + 200.0 * math.cos(a), GetUnitY(hero) + 200.0 * math.sin(a),
                bj_UNIT_FACING)
        end
        if s.once then s.done = true end
        PlaySoundBJ(snd.RestorationPotion or snd.AllianceSound)
        DisplayTextToForce(GetPlayersAll(), GetPlayerName(GetOwningPlayer(hero))
            .. " |cff32cd32Has finished " .. s.name .. "!|r")
    end)
end

-- ── Purchase loot-boxes (war3map.j 35013-35235) ──
-- Players buy a token item from a base shop (e.g. n000 sells the Lv1 box 'I00N'); picking
-- it up consumes it and grants a random item from the rarity pools straight to inventory.
-- Four tokens map to two box types × two tiers; the four near-identical JASS triggers
-- collapse into two parameterized helpers. economy/Economy.md §5.
function RegisterPurchaseTriggers()
    -- One PICKUP trigger per token id, running the given grant action.
    local function onBoxPickup(tokenId, grant)
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_PICKUP_ITEM)
        TriggerAddCondition(t, Condition(function()
            return GetItemTypeId(GetManipulatedItem()) == tokenId
        end))
        TriggerAddAction(t, function()
            RemoveItem(GetManipulatedItem())
            grant(GetManipulatingUnit())
        end)
    end

    -- Full-rarity box: rarity-rolled (60/30/7/3%), item added to the buyer. The artifact
    -- roll (>=98) announces the find. Artificier feat nudges the roll +1 (war3map.j 35067).
    local function fullBox(tokenId, tier)
        onBoxPickup(tokenId, function(buyer)
            RandomItemChance = GetRandomInt(1, 100)
            if ArtificierFeatOn then RandomItemChance = RandomItemChance + 1 end
            if RandomItemChance <= 60 then
                UnitAddItemByIdSwapped(drawFrom(tier.unc), buyer)
            elseif RandomItemChance <= 90 then
                UnitAddItemByIdSwapped(drawFrom(tier.rare), buyer)
            elseif RandomItemChance <= 97 then
                UnitAddItemByIdSwapped(drawFrom(tier.epic), buyer)
            else
                UnitAddItemByIdSwapped(drawFrom(tier.arti), buyer)
                DisplayTextToForce(GetPlayersAll(),
                    GetPlayerName(GetOwningPlayer(buyer)) .. " |cffff0000discovered |r" .. GetItemName(GetLastCreatedItem()))
                PlaySoundBJ(snd.AllianceSound)
            end
        end)
    end

    -- Epic box: always grants a random epic from the tier.
    local function epicBox(tokenId, tier)
        onBoxPickup(tokenId, function(buyer)
            UnitAddItemByIdSwapped(drawFrom(tier.epic), buyer)
        end)
    end

    fullBox(FourCC('I00N'), LOOT_TIERS[1])   -- Lv1 item box   (war3map.j 35016)
    epicBox(FourCC('I0AR'), LOOT_TIERS[1])   -- Lv1 epic box   (war3map.j 35105)
    fullBox(FourCC('I03S'), LOOT_TIERS[2])   -- Lv2 item box   (war3map.j 35151)
    epicBox(FourCC('I0AV'), LOOT_TIERS[2])   -- Lv2 epic box   (war3map.j 35128)
end

-- ── Auction House (war3map.j 6283-6375, 10066-10152; economy/Economy.md §1) ──
-- A buildable set-item market. Buying the token 'I0BF' from a base shop transforms that shop
-- into a Tier-1 Auction House (n00X); 'I0BG' upgrades it to Tier-2 (n00Y). Each tier stocks
-- unique set items (2 rare + 1 epic per cycle) and rotates its stock every 180s. Buying an
-- item from the AH removes it from stock, so every listing is one-of-a-kind.

-- Run fn(unit) for every unit of the given type id on the map; cleans up the enum group.
local function forUnitsOfType(unitid, fn)
    local g = GetUnitsOfTypeIdAll(unitid)
    ForGroup(g, function() fn(GetEnumUnit()) end)
    DestroyGroup(g)
end

-- Stock one cycle onto an AH unit: 2 random rare + 1 random epic set item (war3map.j 6287-6290).
local function stockAH(unit, rarePool, epicPool)
    AddItemToStock(unit, drawFrom(rarePool), 1, 1)
    AddItemToStock(unit, drawFrom(rarePool), 1, 1)
    local epic = drawFrom(epicPool)
    if epic then AddItemToStock(unit, epic, 1, 1) end  -- Lv2 epic pool has empty slots (faithful)
end

-- Rotate an AH unit's stock: drop 6 random level-1 items, then add a fresh cycle (war3map.j 6325-6334).
local function restockAH(unit, rarePool, epicPool)
    for _ = 1, 6 do RemoveItemFromStock(unit, ChooseRandomItem(1)) end
    stockAH(unit, rarePool, epicPool)
end

function RegisterAuctionHouseTriggers()
    local AH1, AH2 = FourCC('n00X'), FourCC('n00Y')

    -- 180s stock rotations, one per tier; start disabled, armed when an AH of that tier is built.
    -- Tier-1 also restocks on Player(0)'s "-ah" debug chat (war3map.j 6345).
    local rotate1 = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(rotate1, 180.0)
    TriggerRegisterPlayerChatEvent(rotate1, Player(0), "-ah", true)
    TriggerAddAction(rotate1, function()
        forUnitsOfType(AH1, function(u) restockAH(u, Lv1RareSetItem, Lv1EpicSetItem) end)
    end)
    DisableTrigger(rotate1)

    local rotate2 = CreateTrigger()
    TriggerRegisterTimerEventPeriodic(rotate2, 180.0)
    TriggerAddAction(rotate2, function()
        forUnitsOfType(AH2, function(u) restockAH(u, Lv2RareSetItem, Lv2EpicSetItem) end)
    end)
    DisableTrigger(rotate2)

    -- Build Tier-1: buy 'I0BF' → the selling building becomes n00X; stock every n00X + arm rotation.
    OnAnyUnit(EVENT_PLAYER_UNIT_SELL_ITEM, function()
        return GetItemTypeId(GetSoldItem()) == FourCC('I0BF')
    end, function()
        ReplaceUnitBJ(GetSellingUnit(), AH1, bj_UNIT_STATE_METHOD_DEFAULTS)
        RemoveItem(GetSoldItem())
        PlaySoundBJ(snd.AllianceSound)
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(GetOwningPlayer(GetBuyingUnit())) .. "|cff00ff00 has built an Auction House!|r")
        EnableTrigger(rotate1)
        forUnitsOfType(AH1, function(u) stockAH(u, Lv1RareSetItem, Lv1EpicSetItem) end)
    end)

    -- Upgrade to Tier-2: buy 'I0BG' → n00Y; stock every n00Y + arm the Lv2 rotation.
    OnAnyUnit(EVENT_PLAYER_UNIT_SELL_ITEM, function()
        return GetItemTypeId(GetSoldItem()) == FourCC('I0BG')
    end, function()
        ReplaceUnitBJ(GetSellingUnit(), AH2, bj_UNIT_STATE_METHOD_DEFAULTS)
        RemoveItem(GetSoldItem())
        PlaySoundBJ(snd.AllianceSound)
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(GetOwningPlayer(GetBuyingUnit())) .. "|cff00ff00 has upgraded an Auction House!|r")
        EnableTrigger(rotate2)
        forUnitsOfType(AH2, function(u) stockAH(u, Lv2RareSetItem, Lv2EpicSetItem) end)
    end)

    -- Buying an item from an AH unit removes that item from its stock (each listing is unique).
    -- The Lv2 upgrade token 'I0BG' is exempt so upgrading doesn't strip itself (war3map.j 10132-10143).
    OnAnyUnit(EVENT_PLAYER_UNIT_SELL_ITEM, function()
        local seller = GetUnitTypeId(GetSellingUnit())
        return (seller == AH1 or seller == AH2) and GetItemTypeId(GetSoldItem()) ~= FourCC('I0BG')
    end, function()
        RemoveItemFromStock(GetSellingUnit(), GetItemTypeId(GetSoldItem()))
    end)
end

-- Debug helper: drop a random Lv1 item of the given rarity at (x,y). Returns its name or nil.
-- Flatten a 0-indexed rarity pool to a plain list of FourCC ids.
local function poolList(p)
    local t = {}
    for i = 0, p.max do t[#t + 1] = p[i] end
    return t
end
-- Tarot cards (war3map.j 32203-32360): Hierophant/Wheel/Death/Tower/Star/Judgement + I03P.
local TAROT_CODES = {
    FourCC('I089'), FourCC('I08E'), FourCC('I08H'),
    FourCC('I08M'), FourCC('I08N'), FourCC('I08Q'), FourCC('I03P'),
}
local SET_PIECE_CODES = {}
for _, s in ipairs(SETS) do
    for _, id in ipairs(s.pieceIds) do SET_PIECE_CODES[#SET_PIECE_CODES + 1] = id end
    if s.giveId then SET_PIECE_CODES[#SET_PIECE_CODES + 1] = s.giveId end
end
local DEBUG_POOLS = {
    unc = poolList(Lv1Uncommon), uncommon = poolList(Lv1Uncommon), rare = poolList(Lv1Rare),
    epic = poolList(Lv1Epic), arti = poolList(Lv1Artifact),
    artifact = poolList(Lv1Artifact), mythic = poolList(Lv1Artifact),
    unc2 = poolList(Lv2Uncommon), rare2 = poolList(Lv2Rare),
    epic2 = poolList(Lv2Epic), arti2 = poolList(Lv2Artifact),
    tarot = TAROT_CODES, set = SET_PIECE_CODES,
}

local function allDebugCodes()
    local t = {}
    for _, list in pairs(DEBUG_POOLS) do for _, id in ipairs(list) do t[#t + 1] = id end end
    if DEBUG_SCROLL_CODES then  -- list of scroll item ids, published by scrolls.lua
        for _, id in ipairs(DEBUG_SCROLL_CODES) do t[#t + 1] = id end
    end
    return t
end

-- Debug item spawner. `-item <pool>` drops one random item from that pool; `-item <pool>
-- <substr>` (or `-item all <substr>`) drops EVERY item whose name contains <substr> — e.g.
-- "-item set phal" spawns the Phalynx pieces. Pools: unc/rare/epic/arti(+2), scroll, tarot,
-- set, all. Returns a short description for the chat ack, or nil on an unknown pool.
function DebugSpawnItem(arg1, arg2, x, y)
    local function resolve(name)
        if name == 'scroll' or name == 'scrolls' then return DEBUG_SCROLL_CODES end
        if name == 'all' or name == nil or name == '' then return allDebugCodes() end
        return DEBUG_POOLS[name]
    end

    -- `-item treats` spawns Radley's Treats (I0BY) — the pup follows whoever holds it
    -- (see misc.lua registerRadley). Not part of any loot pool, so it's a special case.
    if arg1 == 'treats' or arg1 == 'treat' then
        return GetItemName(CreateItem(FourCC('I0BY'), x, y)) or "Treats"
    end

    -- `-item set` spawns one COMPLETE set (all its pieces) instead of a single piece;
    -- `-item set <name>` spawns every set whose name contains <name>. (The piece-substring
    -- behaviour stays available via `-item all <name>`.)
    if arg1 == 'set' then
        local function spawnSet(s)
            for _, id in ipairs(s.pieceIds) do CreateItem(id, x, y) end
        end
        if arg2 and arg2 ~= '' then
            local n = 0
            for _, s in ipairs(SETS) do
                if s.name:lower():find(arg2, 1, true) then spawnSet(s); n = n + 1 end
            end
            return n > 0 and (n .. " set(s) matching '" .. arg2 .. "'") or nil
        end
        local s = SETS[GetRandomInt(1, #SETS)]
        spawnSet(s)
        return "a full " .. s.name
    end

    if arg2 and arg2 ~= '' then
        local search = resolve(arg1) or allDebugCodes()
        local n = 0
        for _, id in ipairs(search) do
            local it = CreateItem(id, x, y)
            if it and (GetItemName(it) or ""):lower():find(arg2, 1, true) then
                n = n + 1
            elseif it then
                RemoveItem(it)
            end
        end
        return n > 0 and (n .. " item(s) matching '" .. arg2 .. "'") or nil
    end
    local p = resolve(arg1)
    if not p or #p == 0 then return nil end
    return GetItemName(CreateItem(p[GetRandomInt(1, #p)], x, y))
end

-- ── Bulk sell system (war3map.j 25280-25525) ──────────────────────────────────
-- Buying a tier token from a sell shop enumerates items in the matching zone,
-- totals their ITEM_IF_MAX_HIT_POINTS field (repurposed as sell value), removes
-- them, and distributes equally to all active human players.
function RegisterSellTriggers()
    local function countActive()
        local n = 0
        for i = 0, 7 do
            local p = Player(i)
            if GetPlayerController(p) == MAP_CONTROL_USER
                and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING then
                n = n + 1
            end
        end
        return n > 0 and n or 1
    end

    local tiers = {
        { id = 'I0C6', zone = rct.UncommonSell, msg = "|cff00ff00 has sold all uncommons in the Supply!|r" },
        { id = 'I0C7', zone = rct.RareSell,     msg = "|cff8080ff has sold all rares in the Supply!|r" },
        { id = 'I0C8', zone = rct.EpicSell,     msg = "|cffff0000 has sold all epics and artifacts in the supply!|r" },
        { id = 'I0C9', zone = rct.OtherSell,    msg = "|cffd45e19 has sold all scrolls and \"Other\" items in the supply!|r" },
    }
    for _, tier in ipairs(tiers) do
        local token = FourCC(tier.id)
        local zone  = tier.zone
        local msg   = tier.msg
        local t = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SELL_ITEM)
        TriggerAddCondition(t, Condition(function()
            return GetItemTypeId(GetSoldItem()) == token
        end))
        TriggerAddAction(t, function()
            local total    = 0
            local numPlayers = countActive()
            RemoveItem(GetSoldItem())
            DisplayTextToForce(GetPlayersAll(),
                GetPlayerName(GetOwningPlayer(GetBuyingUnit())) .. msg)
            EnumItemsInRectBJ(zone, function()
                total = total + BlzGetItemIntegerField(GetEnumItem(), ITEM_IF_MAX_HIT_POINTS)
                RemoveItem(GetEnumItem())
            end)
            local share = total // numPlayers
            DisplayTextToForce(GetPlayersAll(),
                "|cff00ff00Total Gold: |r|cffffff00+|r" .. tostring(total))
            DisplayTextToForce(GetPlayersAll(),
                "|cff00ff00Your share: |r|cffffff00+|r" .. tostring(share))
            for i = 0, 7 do
                local p = Player(i)
                if GetPlayerController(p) == MAP_CONTROL_USER
                    and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING then
                    AdjustPlayerStateBJ(share, p, PLAYER_STATE_RESOURCE_GOLD)
                end
            end
        end)
    end
end

-- ── Item Shop (war3map.j 25527-25615) ─────────────────────────────────────────
-- R00M research builds n004 at rct.ItemShop. R00N upgrades n004→n005→n006.
function RegisterItemShopTriggers()
    local function propagate(r, rank)
        for i = 0, 8 do SetPlayerTechResearchedSwap(FourCC(r), rank, Player(i)) end
    end

    local shopT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(shopT, EVENT_PLAYER_UNIT_RESEARCH_FINISH)
    TriggerAddCondition(shopT, Condition(function()
        return GetResearched() == FourCC('R00M')
    end))
    TriggerAddAction(shopT, function()
        PlaySoundBJ(snd.ResurrectTarget)
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(GetOwningPlayer(GetResearchingUnit()))
            .. " has researched Item Shop (Creates an Item Shop that players may purchase potions from for free.)")
        propagate('R00M', 1)
        CreateNUnitsAtLoc(1, FourCC('n004'), Player(PLAYER_NEUTRAL_PASSIVE),
            GetRectCenter(rct.ItemShop), bj_UNIT_FACING)
    end)

    local upgradeT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(upgradeT, EVENT_PLAYER_UNIT_RESEARCH_FINISH)
    TriggerAddCondition(upgradeT, Condition(function()
        return GetResearched() == FourCC('R00N')
    end))
    TriggerAddAction(upgradeT, function()
        PlaySoundBJ(snd.ResurrectTarget)
        local name = GetPlayerName(GetOwningPlayer(GetResearchingUnit()))
        if ItemSHopUpgrade == 1 then
            ItemSHopUpgrade = 2
            DisplayTextToForce(GetPlayersAll(),
                name .. " has researched Land Route Trade! (The Item Shop selection and restock times have improved further!)")
            propagate('R00N', 2)
            ReplaceUnitBJ(GroupPickRandomUnit(GetUnitsOfTypeIdAll(FourCC('n005'))),
                FourCC('n006'), bj_UNIT_STATE_METHOD_RELATIVE)
        else
            ItemSHopUpgrade = 1
            DisplayTextToForce(GetPlayersAll(),
                name .. " has researched Overseas Trade! (The Item Shop selection and restock times have improved!)")
            propagate('R00N', 1)
            ReplaceUnitBJ(GroupPickRandomUnit(GetUnitsOfTypeIdAll(FourCC('n004'))),
                FourCC('n005'), bj_UNIT_STATE_METHOD_RELATIVE)
        end
    end)
end

-- ── Supply Stocking (war3map.j 24465-24748) ───────────────────────────────────
-- SupplyStockingItems: called at level end; sorts ground items from stocking
-- zones into tiered cleanup zones by item level. Level 1=unc, 2=rare,
-- 3/4=epic/arti, other=scrolls/stones. Called from onLevelVictory in levels.lua.
function SupplyStockingItems()
    if not ItemCleanUpOn then return end
    local function sortItem()
        local item = GetEnumItem()
        local lvl  = GetItemLevel(item)
        local dest
        if lvl == 1 then
            dest = GetRandomLocInRect(rct.ItemCleanupUNC)
        elseif lvl == 2 then
            dest = GetRandomLocInRect(rct.ItemCleanupRare)
        elseif lvl == 3 or lvl == 4 then
            dest = GetRandomLocInRect(rct.ItemCleanupEpicArti)
        else
            dest = GetRandomLocInRect(rct.ItemCleanupScrollStones)
        end
        SetItemPositionLoc(item, dest)
        RemoveLocation(dest)
    end
    EnumItemsInRectBJ(rct.SupplyStockingA, sortItem)
    EnumItemsInRectBJ(rct.SupplyStockingB, sortItem)
    EnumItemsInRectBJ(rct.SupplyStocking3, sortItem)
end

-- R00J research: enable stocking + add Retrieve ability to all h02W depots.
-- A0KE cast: move items near the caster's owner hero to near the depot building.
function RegisterSupplyStockingTriggers()
    local stockT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(stockT, EVENT_PLAYER_UNIT_RESEARCH_FINISH)
    TriggerAddCondition(stockT, Condition(function()
        return GetResearched() == FourCC('R00J')
    end))
    TriggerAddAction(stockT, function()
        PlaySoundBJ(snd.ResurrectTarget)
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(GetOwningPlayer(GetResearchingUnit()))
            .. " has researched Supply Stocking! |cff00ff00(Items are sorted and brought to base at the end of every level.)|r")
        for i = 0, 7 do
            local p = Player(i)
            if GetPlayerController(p) == MAP_CONTROL_USER
                and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING then
                SetPlayerTechResearchedSwap(FourCC('R00J'), 1, p)
            end
        end
        ItemCleanUpOn = true
        local depots = GetUnitsOfTypeIdAll(FourCC('h02W'))
        ForGroup(depots, function() UnitAddAbilityBJ(FourCC('A0KE'), GetEnumUnit()) end)
        DestroyGroup(depots)
    end)

    local retrieveT = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(retrieveT, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddCondition(retrieveT, Condition(function()
        return GetSpellAbilityId() == FourCC('A0KE')
    end))
    TriggerAddAction(retrieveT, function()
        local caster = GetSpellAbilityUnit()
        local owner  = GetOwningPlayer(caster)
        local heroes = { Heroes[1], Heroes[2], Heroes[3], Heroes[4],
                         Heroes[5], Heroes[6], Heroes[7], Heroes[8] }
        for _, hero in ipairs(heroes) do
            if hero and GetOwningPlayer(hero) == owner then
                local cx = GetUnitX(hero)
                local cy = GetUnitY(hero)
                local zone = Rect(cx - 125.0, cy - 125.0, cx + 125.0, cy + 125.0)
                local dest = Location(GetUnitX(caster), GetUnitY(caster) + 150.0)
                EnumItemsInRectBJ(zone, function()
                    SetItemPositionLoc(GetEnumItem(), dest)
                end)
                RemoveRect(zone)
                RemoveLocation(dest)
                break
            end
        end
    end)
end
