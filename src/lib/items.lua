-- Item rarity pools (Lv1) + the level-based loot drop system.
-- Requirements: items/Items.md §3 (pools + Lv_1_Item), economy/Economy.md.
-- Source: war3map.j 35253-35408 (Lv1 Unc/Rare/Epic/Artifact pool inits),
--   34107-34176 (Lv_1_Item drop), 2552 (ItemDropTotal = 50), 33546-33549 (totals).
--
-- Every Player(9) kill adds 1-6 to ItemDrop; once it reaches ItemDropTotal (50) an item
-- drops at the corpse — rarity-rolled 60% uncommon / 30% rare / 7% epic / 3% artifact —
-- and the counter resets. These pools are the shared loot source the rest of the economy
-- (Purchase loot-boxes, Auction House, Sell) will read once those are ported.
-- Not yet ported: Lv2 pools / Lv_2_Item (higher levels), cursed drops, ItemDropTotal
-- research reductions (Scavenging etc.).

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

local function drawFrom(p)
    return p[GetRandomInt(0, p.max)]
end

-- Lv_1_Item (war3map.j 34107) — enabled from the start (Lv_2_Item is for later levels).
function RegisterItemDropTriggers()
    local t = CreateTrigger()
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

        local loc = GetUnitLoc(GetDyingUnit())
        if RandomItemChance <= 60 then
            CreateItemLoc(drawFrom(Lv1Uncommon), loc)
        elseif RandomItemChance <= 90 then
            CreateItemLoc(drawFrom(Lv1Rare), loc)
        elseif RandomItemChance <= 97 then
            CreateItemLoc(drawFrom(Lv1Epic), loc)
        else
            CreateItemLoc(drawFrom(Lv1Artifact), loc)
            local killer = GetKillingUnitBJ()
            local who = killer and GetPlayerName(GetOwningPlayer(killer)) or "Someone"
            DisplayTextToForce(GetPlayersAll(),
                who .. " |cffff0000discovered |r" .. GetItemName(GetLastCreatedItem()))
            PlaySoundBJ(snd.AllianceSound)
        end
        RemoveLocation(loc)
    end)
end

-- ── Purchase loot-boxes (war3map.j 35016-35123) ──
-- Players buy a token item from a base shop (e.g. n000 sells the Lv1 box 'I00N'); picking
-- it up consumes it and grants a random item from the rarity pools straight to inventory.
-- Lv1 only for now (Lv2 pools + scroll boxes not ported). economy/Economy.md §5.
function RegisterPurchaseTriggers()
    -- 'I00N' — Lv1 item box: rarity-rolled (60/30/7/3%), item added to the buyer.
    local box = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(box, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(box, Condition(function()
        return GetItemTypeId(GetManipulatedItem()) == FourCC('I00N')
    end))
    TriggerAddAction(box, function()
        RemoveItem(GetManipulatedItem())
        local buyer = GetManipulatingUnit()
        RandomItemChance = GetRandomInt(1, 100)
        if ArtificierFeatOn then RandomItemChance = RandomItemChance + 1 end
        if RandomItemChance <= 60 then
            UnitAddItemByIdSwapped(drawFrom(Lv1Uncommon), buyer)
        elseif RandomItemChance <= 90 then
            UnitAddItemByIdSwapped(drawFrom(Lv1Rare), buyer)
        elseif RandomItemChance <= 97 then
            UnitAddItemByIdSwapped(drawFrom(Lv1Epic), buyer)
        else
            UnitAddItemByIdSwapped(drawFrom(Lv1Artifact), buyer)
            DisplayTextToForce(GetPlayersAll(),
                GetPlayerName(GetOwningPlayer(buyer)) .. " |cffff0000discovered |r" .. GetItemName(GetLastCreatedItem()))
            PlaySoundBJ(snd.AllianceSound)
        end
    end)

    -- 'I0AR' — Lv1 epic box: always grants a random Lv1 epic.
    local epicBox = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(epicBox, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(epicBox, Condition(function()
        return GetItemTypeId(GetManipulatedItem()) == FourCC('I0AR')
    end))
    TriggerAddAction(epicBox, function()
        RemoveItem(GetManipulatedItem())
        UnitAddItemByIdSwapped(drawFrom(Lv1Epic), GetManipulatingUnit())
    end)
end

-- Debug helper: drop a random Lv1 item of the given rarity at (x,y). Returns its name or nil.
local DEBUG_POOLS = {
    unc = Lv1Uncommon, uncommon = Lv1Uncommon, rare = Lv1Rare,
    epic = Lv1Epic, arti = Lv1Artifact, artifact = Lv1Artifact, mythic = Lv1Artifact,
}
function DebugSpawnItem(rarity, x, y)
    local p = DEBUG_POOLS[rarity]
    if not p then return nil end
    return GetItemName(CreateItem(drawFrom(p), x, y))
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
        local heroes = { P1Hero, P2Hero, P3Hero, P4Hero, P5Hero, P6Hero, P7Hero, P8Hero }
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
