-- Buildable town structures, guard posts, Magister's Tower auto-cast, and Artificer loot.
-- Requirements: buildings/Buildings.md. Source: war3map.j 9830-10878.
--
-- A player buys a "build X" token item from a base plot building; on the SELL_ITEM the plot is
-- ReplaceUnit'd into the real structure (one dispatch covers them all). Guard posts station a
-- garrison that respawns each level; the Artificer's Post makes enemies drop crafting stones;
-- the Magister's Tower periodically buffs/heals the player heroes.
--
-- NOT here (ported elsewhere): the Auction House build (I0BF/I0BG → items.lua RegisterAuctionHouseTriggers)
-- and the -camera zoom-out (cameras.lua). The Companionship system (10479-10814) IS ported below
-- (CheckCompanionships) — a half-finished flavor system (the original author flags it so at
-- war3map.j 10500); see the §Companionship block for the faithful-port caveats.

local P8 = Player(8)
local P9 = Player(9)

local function buildAnnounce(buyer, msg)
    PlaySoundBJ(snd.AllianceSound)
    DisplayTextToForce(GetPlayersAll(), GetPlayerName(GetOwningPlayer(buyer)) .. msg)
end

-- ── Generic buildable structures (token → result unit) ────────────────────────
-- method 'relative' = keep current HP fraction across the swap (fountain upgrade); else defaults.
local BUILDABLE = {
    [FourCC('I06C')] = { result = 'h038', msg = " has built a Lesser Fountain of Replenishment!" },
    [FourCC('I0BH')] = { result = 'h03H', relative = true, msg = " has upgraded a Fountain of Replenishment!" },
    [FourCC('I0AG')] = { result = 'h043', msg = " builds a Library!" },
    [FourCC('I0AP')] = { result = 'h044', msg = " builds a Thieves' Den!" },
    [FourCC('I0B0')] = { result = 'h04S', msg = " builds a Magister's Tower!", magister = true },
}

-- ── Guard posts (war3map.j 9830-10013) ───────────────────────────────────────
-- Token I0AL builds up to two posts (melee A, then archer B); a third buy refunds 1500g.
local GUARD_TOKEN = FourCC('I0AL')
local guardPostA, guardPostB = false, false
local guardPostAx, guardPostAy = 0.0, 0.0   -- melee guard spawn point (plot, 100 south)
local guardPostBx, guardPostBy = 0.0, 0.0   -- archer guard spawn point
local MELEE_GARRISON  = { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L' }
local ARCHER_GARRISON = { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H' }

-- (Re)station the melee garrison: clear last round's City Guards, then send one to each
-- GarrisonLocation point. Called per level from levels.lua ThingsToDoBeforeEveryLevelBegins.
function SpawnMeleeGuards()
    if not guardPostA then return end
    local g = GetUnitsOfTypeIdAll(FourCC('h04Z'))
    ForGroup(g, function() RemoveUnit(GetEnumUnit()) end)
    DestroyGroup(g)
    for _, c in ipairs(MELEE_GARRISON) do
        local u = CreateUnit(P8, GuardPostMeleeType, guardPostAx, guardPostAy, 270.0)
        local r = rct['GarrisonLocation' .. c]
        IssuePointOrder(u, "move", GetRectCenterX(r), GetRectCenterY(r))
    end
end

function SpawnArcherGuards()
    if not guardPostB then return end
    local g = GetUnitsOfTypeIdAll(FourCC('n00Z'))
    ForGroup(g, function() RemoveUnit(GetEnumUnit()) end)
    DestroyGroup(g)
    for _, c in ipairs(ARCHER_GARRISON) do
        local u = CreateUnit(P8, GuardPostRangedType, guardPostBx, guardPostBy, 270.0)
        local r = rct['GarrisonArcher' .. c]
        IssuePointOrder(u, "move", GetRectCenterX(r), GetRectCenterY(r))
    end
end

-- ── Magister's Tower auto-cast (war3map.j 10271-10341) ────────────────────────
-- Once built, every 30s the tower cycles innerfire → healingwave → frostarmor on a random
-- player hero (any hero not owned by P8/P9). One loop regardless of how many towers exist.
local magisterStarted = false
local towerVictimFilter   -- cached boolexpr (created lazily, reused — no per-cast leak)

local function castTowerSpell(order)
    local tg = GetUnitsOfTypeIdAll(FourCC('h04S'))
    local tower = GroupPickRandomUnit(tg)
    DestroyGroup(tg)
    if not tower then return end
    if not towerVictimFilter then
        towerVictimFilter = Condition(function()
            local u = GetFilterUnit()
            return IsUnitType(u, UNIT_TYPE_HERO)
                and GetOwningPlayer(u) ~= P8 and GetOwningPlayer(u) ~= P9
        end)
    end
    local vg = GetUnitsInRectMatching(GetPlayableMapRect(), towerVictimFilter)
    local victim = GroupPickRandomUnit(vg)
    DestroyGroup(vg)
    if victim then IssueTargetOrderBJ(tower, order, victim) end
end

local function startMagisterTower()
    if magisterStarted then return end
    magisterStarted = true
    local t = CreateTrigger()
    TriggerAddAction(t, function()
        while CountLivingPlayerUnitsOfTypeId(FourCC('h04S'), P8) > 0 do
            TriggerSleepAction(30.0); castTowerSpell("innerfire")
            TriggerSleepAction(30.0); castTowerSpell("healingwave")
            TriggerSleepAction(30.0); castTowerSpell("frostarmor")
        end
        magisterStarted = false   -- all towers gone; allow a rebuild to restart the loop
    end)
    TriggerExecute(t)
end

-- ── Artificer's Post loot (war3map.j 10795-10859) ────────────────────────────
-- While an Artificer's Post stands, Player(9) kills accrue toward a stone drop: each kill adds
-- 1-6 to a counter and at ≥150 a random Artificer Stone drops at the corpse (counter resets).
local ARTIFICER_STONES = {
    FourCC('I07M'), FourCC('I070'), FourCC('I07N'), FourCC('I07O'), FourCC('I07P'),
    FourCC('I07Q'), FourCC('I07R'), FourCC('I07S'), FourCC('I07U'), FourCC('I07W'), FourCC('I07V'),
}
local artiRockDrop = 0
local artiRockTrg               -- enabled when the first Artificer's Post is built
local artificerEnabled = false

local function enableArtificerLoot()
    if artificerEnabled then return end
    artificerEnabled = true
    if artiRockTrg then EnableTrigger(artiRockTrg) end
end

-- ── One SELL_ITEM dispatch for every build token ─────────────────────────────
local function registerBuildHandlers()
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SELL_ITEM)
    TriggerAddAction(t, function()
        local item  = GetSoldItem()
        local id    = GetItemTypeId(item)
        local plot  = GetSellingUnit()
        local buyer = GetBuyingUnit()

        -- Generic buildables.
        local def = BUILDABLE[id]
        if def then
            ReplaceUnitBJ(plot, FourCC(def.result),
                def.relative and bj_UNIT_STATE_METHOD_RELATIVE or bj_UNIT_STATE_METHOD_DEFAULTS)
            RemoveItem(item)
            buildAnnounce(buyer, def.msg)
            if def.magister then startMagisterTower() end
            return
        end

        -- Guard posts (First → Second → No-More chain).
        if id == GUARD_TOKEN then
            if not guardPostA then
                guardPostAx, guardPostAy = GetUnitX(plot), GetUnitY(plot) - 100.0
                guardPostA = true
                ReplaceUnitBJ(plot, FourCC('h042'), bj_UNIT_STATE_METHOD_DEFAULTS)
                RemoveItem(item)
                buildAnnounce(buyer, " builds a Guard Post!  City Guards will begin spawning every round!")
            elseif not guardPostB then
                guardPostBx, guardPostBy = GetUnitX(plot), GetUnitY(plot) - 100.0
                guardPostB = true
                ReplaceUnitBJ(plot, FourCC('h042'), bj_UNIT_STATE_METHOD_DEFAULTS)
                RemoveItem(item)
                buildAnnounce(buyer, " builds a Guard Post!  City Archers will begin spawning every round!")
            else
                AdjustPlayerStateBJ(1500, GetOwningPlayer(buyer), PLAYER_STATE_RESOURCE_GOLD)
                DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(buyer)),
                    "Your team already has two Guard Posts.  You have been refunded.")
                RemoveItem(item)
            end
            return
        end

        -- Artificer's Post (I07L): one per team; a second buy refunds 1250g.
        if id == FourCC('I07L') then
            if CountLivingPlayerUnitsOfTypeId(FourCC('h03O'), P8) >= 1 then
                AdjustPlayerStateBJ(1250, GetOwningPlayer(buyer), PLAYER_STATE_RESOURCE_GOLD)
                DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(buyer)),
                    "Your team already has an Artificier's Post.  You have been refunded.")
                RemoveItem(item)
            else
                ReplaceUnitBJ(plot, FourCC('h03O'), bj_UNIT_STATE_METHOD_DEFAULTS)
                RemoveItem(item)
                buildAnnounce(buyer,
                    " has built an Artificier's Post!  Artificier Stones will begin dropping from enemies!")
                enableArtificerLoot()
            end
        end
    end)
end

-- Tower-cast flavor floaters (war3map.j Heal_Announce/Ice_Armor/Stoneskin 10350-10420).
local function registerTowerAnnounces()
    local ANNOUNCE = {
        [FourCC('A0IO')] = "Recovery Ray",
        [FourCC('A0IN')] = "Ice Armor",
        [FourCC('A07F')] = "Stoneskin",
    }
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_CAST)
    TriggerAddAction(t, function()
        local label = ANNOUNCE[GetSpellAbilityId()]
        if label then FloatText(GetSpellAbilityUnit(), label, 100, 0, 0, 3.0) end
    end)
end

local function registerArtificerLoot()
    artiRockTrg = CreateTrigger()
    DisableTrigger(artiRockTrg)
    TriggerRegisterPlayerUnitEventSimple(artiRockTrg, P9, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(artiRockTrg, Condition(function()
        local id = GetUnitTypeId(GetDyingUnit())
        return id ~= FourCC('e002') and id ~= FourCC('e003') and id ~= FourCC('e007')
    end))
    TriggerAddAction(artiRockTrg, function()
        if artiRockDrop >= 150 then
            artiRockDrop = 0
            local stone = ARTIFICER_STONES[GetRandomInt(1, #ARTIFICER_STONES)]
            CreateItem(stone, GetUnitX(GetDyingUnit()), GetUnitY(GetDyingUnit()))
        else
            artiRockDrop = artiRockDrop + GetRandomInt(1, 6)
        end
    end)

    -- AP Angelheart (I070): consume it to level up the Princess Silmeria (war3map.j 10862).
    local hd = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(hd, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(hd, Condition(function()
        return GetItemTypeId(GetManipulatedItem()) == FourCC('I070')
    end))
    TriggerAddAction(hd, function()
        RemoveItem(GetManipulatedItem())
        if unit_H02G then SetHeroLevelBJ(unit_H02G, GetHeroLevel(unit_H02G) + 1, true) end
        DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(GetManipulatingUnit())),
            "|cff32cd32Silmeria absorbs the power of the Angelheart Stone, gaining a level.|r")
    end)
end

-- ── Companionship (war3map.j 10479-10814) ───────────────────────────────────────
-- A half-finished proximity-bond flavor system — the original author's own note at
-- war3map.j 10500 reads "no clue what this does or is supposed to do". Ported faithfully
-- in BEHAVIOR; the original's pacing TriggerSleepActions are dropped to match how the
-- rest of Upkeep_2 was ported (the target already collapsed Upkeep_2's 12s sleep). The
-- sleeps were pure pacing — they don't affect the counts or the bond logic. Buildings.md §4.
--
-- What's observable in the original: only the P1 path. Check_Companionships (10600) tallies,
-- at each level-end, how many ally heroes linger within 1000 of P1Hero/P2Hero, into Comp
-- slots indexed by converted player id. Companionship_Checking (10667) then reads only
-- P1Companion[2..8]: the first slot to reach RelationLevel*5 announces a "companionship",
-- locks every OTHER slot to -9999, resets the matched slot to 0, and bumps RelationLevel.
-- The P2/P3 tallies and Comp_Check_2 are inert in the original (Comp_Check_2 is never
-- executed; nothing reads the P2/P3 counts). There is NO stat buff — only the message.

-- Tally ally heroes within 1000 of `hero` into Companion[slot][convertedPlayerId].
local function tallyCompanions(hero, slot)
    if not hero or GetUnitTypeId(hero) == 0 then return end
    ForUnitsInRange(GetUnitX(hero), GetUnitY(hero), 1000.0,
        function()
            local o = GetOwningPlayer(GetFilterUnit())
            return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO)
                and o ~= Player(9) and o ~= Player(10) and o ~= Player(11)
        end,
        function()
            local cid = GetConvertedPlayerId(GetOwningPlayer(GetEnumUnit()))
            Companion[slot][cid] = (Companion[slot][cid] or 0) + 1
        end)
end

-- Run from BonusesAndUpkeep at each level-end (war3map.j Upkeep_2 7390 + 7406).
function CheckCompanionships()
    -- Tally (Check_Companionships 10600-10607). NB: the original's third enum reads
    -- P2Hero's location, not P3Hero's — a bug we replicate faithfully (it only feeds the
    -- inert P3 slot anyway, so it changes nothing observable).
    tallyCompanions(Heroes[1], 1)
    tallyCompanions(Heroes[2], 2)
    tallyCompanions(Heroes[2], 3)   -- faithful: original uses P2Hero here, not P3Hero

    -- Bond check (Companionship_Checking 10667-10759): only P1's slots 2..8. The original's
    -- per-branch -9999 lockout means at most one slot can fire per call, so a single pass
    -- with `break` is equivalent to its sequential checks.
    local p1 = Companion[1]
    for slot = 2, 8 do
        if p1[slot] >= RelationLevel[1] * 5 then
            DisplayTimedTextToForce(GetPlayersAll(), 10.0,
                "|cffdda0ddCompanionship: |r" .. GetPlayerName(Player(0))
                .. " |cffdda0dd and |r" .. GetPlayerName(Player(slot - 1))
                .. "|cffdda0dd have started a companionship!|r")
            for other = 2, 8 do p1[other] = -9999 end
            p1[slot] = 0
            RelationLevel[1] = RelationLevel[1] + 1
            break
        end
    end
end

function RegisterBuildingTriggers()
    registerBuildHandlers()
    registerTowerAnnounces()
    registerArtificerLoot()
end
