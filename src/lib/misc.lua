-- Misc / flavor systems (small self-contained event handlers).
-- Requirements: misc/MidasShipsAndMisc.md, misc/MiscSystems.md.

-- Hero level-up floating text — war3map.j 29725-29813 (Level_up).
-- Shows "<player> hits level N" above the leveling hero for ~4s (players 0-7 only, so
-- bosses/NPCs don't spam it). Pairs with the per-level stat-feat bonuses in feats.lua.
local function registerLevelUpFloaters()
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_HERO_LEVEL)
    TriggerAddCondition(t, Condition(function()
        return GetPlayerId(GetOwningPlayer(GetLevelingUnit())) <= 7
    end))
    TriggerAddAction(t, function()
        local u = GetLevelingUnit()
        CreateTextTagUnitBJ(GetPlayerName(GetOwningPlayer(u)) .. " hits level " .. GetUnitLevel(u),
            u, 0, 8.0, 10.0, 100.0, 10.0, 0)
        local tag = GetLastCreatedTextTag()
        SetTextTagPermanentBJ(tag, false)
        SetTextTagLifespanBJ(tag, 4.0)
        SetTextTagFadepointBJ(tag, 3.0)
        ShowTextTagForceBJ(true, tag, GetPlayersAll())
    end)
end

-- Hero death cries — war3map.j 11066-13150.
-- One trigger per class in JASS; unified here as a single data-driven dispatch trigger
-- plus two special triggers for Wildbond/Pet cross-dialogue (JASS 12769-12901).
-- On death: play class sound, pick random 1-3 quote, ping minimap, show portrait line.
-- Summoned units and illusions are excluded.
local function RegisterHeroDeathCries()
    local entries = {}
    local function add(cc, s, q1, q2, q3)
        entries[FourCC(cc)] = {snd=s, q={q1, q2, q3}}
    end
    local function addX(cc, s, q1, q2, q3, xs)
        entries[FourCC(cc)] = {snd=s, q={q1, q2, q3}, xs=xs}
    end

    local m = snd.s13
    local f = snd.s14
    local dr = snd.DragonWhat1

    add('H001', m, "TRIGSTR_1452", "TRIGSTR_1451", "TRIGSTR_1450")
    add('H003', f, "TRIGSTR_1453", "TRIGSTR_1461", "TRIGSTR_1459")
    add('H007', m, "TRIGSTR_1456", "TRIGSTR_1457", "TRIGSTR_1458")
    add('E001', m, "TRIGSTR_1462", "TRIGSTR_1463", "TRIGSTR_1464")
    add('E000', m, "TRIGSTR_1465", "TRIGSTR_1466", "TRIGSTR_1467")
    add('H00E', f, "TRIGSTR_1468", "TRIGSTR_1469", "TRIGSTR_1470")
    addX('H00F', m, "TRIGSTR_1471", "TRIGSTR_1472", "TRIGSTR_1473", snd.PeasantYesAttack4)
    add('H013', m, "TRIGSTR_1474", "TRIGSTR_1475", "TRIGSTR_1476")
    add('H00S', m, "TRIGSTR_1477", "TRIGSTR_1478", "TRIGSTR_1479")
    add('O000', m, "TRIGSTR_1480", "TRIGSTR_1481", "TRIGSTR_1482")
    add('E004', m, "TRIGSTR_1484", "TRIGSTR_1485", "TRIGSTR_1486")
    add('H01J', f, "TRIGSTR_1668", "TRIGSTR_1669", "TRIGSTR_1670")
    add('H01M', m, "TRIGSTR_1936", "TRIGSTR_1937", "TRIGSTR_1938")
    add('H01N', f, "TRIGSTR_2043", "TRIGSTR_2044", "TRIGSTR_2045")
    add('H01O', f, "TRIGSTR_2273", "TRIGSTR_2274", "TRIGSTR_2275")
    add('E006', m, "TRIGSTR_2421", "TRIGSTR_2422", "TRIGSTR_2423")
    add('H01U', m, "TRIGSTR_2917", "TRIGSTR_2918", "TRIGSTR_2919")
    add('H02C', f, "TRIGSTR_3102", "TRIGSTR_3103", "TRIGSTR_3104")
    add('H02L', f, "TRIGSTR_3899", "TRIGSTR_3900", "TRIGSTR_3901")
    add('H02N', f, "TRIGSTR_4217", "TRIGSTR_4218", "TRIGSTR_4219")
    add('H02D', dr, "TRIGSTR_4651", "TRIGSTR_4652", "TRIGSTR_4653")
    add('E00E', m, "TRIGSTR_4599", "TRIGSTR_4600", "TRIGSTR_4601")
    add('H02U', f, "TRIGSTR_5306", "TRIGSTR_5307", "TRIGSTR_5308")
    add('H02X', m, "TRIGSTR_5920", "TRIGSTR_5921", "TRIGSTR_5922")
    add('E011', m, "TRIGSTR_6042", "TRIGSTR_6043", "TRIGSTR_6044")
    add('H03A', m, "TRIGSTR_6351", "TRIGSTR_6352", "TRIGSTR_6353")
    add('E015', m, "TRIGSTR_6477", "TRIGSTR_6478", "TRIGSTR_6479")
    add('H03I', m, "TRIGSTR_6602", "TRIGSTR_6603", "TRIGSTR_6604")
    add('E01B', m, "TRIGSTR_7624", "TRIGSTR_7625", "TRIGSTR_7626")
    add('E019', f, "TRIGSTR_8382", "TRIGSTR_8383", "TRIGSTR_8384")
    add('H03U', m, "TRIGSTR_8652", "TRIGSTR_8653", "TRIGSTR_8654")
    add('H041', m, "TRIGSTR_9414", "TRIGSTR_9415", "TRIGSTR_9416")

    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddAction(t, function()
        local u = GetDyingUnit()
        if IsUnitType(u, UNIT_TYPE_SUMMONED) or IsUnitIllusion(u) then return end
        local e = entries[GetUnitTypeId(u)]
        if not e then return end
        local n = math.random(1, 3)
        local x, y = GetUnitX(u), GetUnitY(u)
        SetSoundPosition(e.snd, x, y, 0)
        SetSoundVolume(e.snd, 100)
        StartSound(e.snd)
        PingMinimap(x, y, 1.0)
        TransmissionFromUnitWithNameBJ(GetPlayersAll(), u,
            GetPlayerName(GetOwningPlayer(u)), snd.CreepAggroWhat1,
            GetLocalizedString(e.q[n]), bj_TIMETYPE_ADD, 0, true)
        if n == 1 and e.xs then
            StartSound(e.xs)
        end
    end)

    -- Wildbond (H03J) and WildbondPet: each disables the other's trigger for 2s to
    -- prevent double-firing, then plays a two-unit exchange (JASS 12769-12901).
    local tWild, tPet
    tWild = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(tWild, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(tWild, Condition(function()
        return GetUnitTypeId(GetDyingUnit()) == UID.Wildbond
            and not IsUnitIllusion(GetDyingUnit())
    end))
    TriggerAddAction(tWild, function()
        DisableTrigger(tPet)
        local u = GetDyingUnit()
        local n = math.random(1, 3)
        local x, y = GetUnitX(u), GetUnitY(u)
        SetSoundVolume(f, 100)
        StartSound(f)
        PingMinimap(x, y, 1.0)
        local petName = WildbondPet and GetHeroProperName(WildbondPet) or "..."
        if n == 1 then
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), u,
                GetPlayerName(GetOwningPlayer(u)), snd.CreepAggroWhat1,
                "Ugh... No.. " .. petName .. "....",
                bj_TIMETYPE_ADD, 0, true)
            if WildbondPet then
                TransmissionFromUnitWithNameBJ(GetPlayersAll(), WildbondPet,
                    petName, snd.CreepAggroWhat1,
                    GetLocalizedString("TRIGSTR_6906"), bj_TIMETYPE_ADD, 0, true)
            end
        elseif n == 2 then
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), u,
                GetPlayerName(GetOwningPlayer(u)), snd.CreepAggroWhat1,
                GetLocalizedString("TRIGSTR_6902"), bj_TIMETYPE_ADD, 0, true)
            if WildbondPet then
                TransmissionFromUnitWithNameBJ(GetPlayersAll(), WildbondPet,
                    petName, snd.CreepAggroWhat1,
                    GetLocalizedString("TRIGSTR_6905"), bj_TIMETYPE_ADD, 0, true)
            end
        else
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), u,
                GetPlayerName(GetOwningPlayer(u)), snd.CreepAggroWhat1,
                GetLocalizedString("TRIGSTR_6903"), bj_TIMETYPE_ADD, 0, true)
            if WildbondPet then
                TransmissionFromUnitWithNameBJ(GetPlayersAll(), WildbondPet,
                    petName, snd.CreepAggroWhat1,
                    GetLocalizedString("TRIGSTR_6904"), bj_TIMETYPE_ADD, 0, true)
            end
        end
        TriggerSleepAction(2)
        EnableTrigger(tPet)
    end)

    tPet = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(tPet, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(tPet, Condition(function()
        return GetDyingUnit() == WildbondPet
            and not IsUnitIllusion(GetDyingUnit())
    end))
    TriggerAddAction(tPet, function()
        DisableTrigger(tWild)
        local u = GetDyingUnit()
        local n = math.random(1, 3)
        local x, y = GetUnitX(u), GetUnitY(u)
        PingMinimap(x, y, 1.0)
        local petName = WildbondPet and GetHeroProperName(WildbondPet) or "..."
        if n == 1 then
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), u,
                GetPlayerName(GetOwningPlayer(u)), snd.CreepAggroWhat1,
                GetLocalizedString("TRIGSTR_6912"), bj_TIMETYPE_ADD, 0, true)
            if Wildbond then
                TransmissionFromUnitWithNameBJ(GetPlayersAll(), Wildbond,
                    GetHeroProperName(Wildbond), snd.CreepAggroWhat1,
                    GetLocalizedString("TRIGSTR_6907"), bj_TIMETYPE_ADD, 0, true)
            end
        elseif n == 2 then
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), u,
                GetPlayerName(GetOwningPlayer(u)), snd.CreepAggroWhat1,
                GetLocalizedString("TRIGSTR_6913"), bj_TIMETYPE_ADD, 0, true)
            if Wildbond then
                TransmissionFromUnitWithNameBJ(GetPlayersAll(), Wildbond,
                    GetHeroProperName(Wildbond), snd.CreepAggroWhat1,
                    GetLocalizedString("TRIGSTR_6914"), bj_TIMETYPE_ADD, 0, true)
            end
        else
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), u,
                GetPlayerName(GetOwningPlayer(u)), snd.CreepAggroWhat1,
                GetLocalizedString("TRIGSTR_6915"), bj_TIMETYPE_ADD, 0, true)
            if Wildbond then
                TransmissionFromUnitWithNameBJ(GetPlayersAll(), Wildbond,
                    GetHeroProperName(Wildbond), snd.CreepAggroWhat1,
                    petName .. "!  No!  NO! Please wake up......Unh...",
                    bj_TIMETYPE_ADD, 0, true)
            end
        end
        TriggerSleepAction(2)
        EnableTrigger(tWild)
    end)
end

-- Per-player kill scoring — war3map.j 27352-27530 (P1-P8 Kill Score). The 8 near-identical
-- per-player triggers collapse into one: on any unit death, credit the killer's owner.
local function registerKillScoring()
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddAction(t, function()
        local killer = GetKillingUnit()
        if not killer then return end
        local pid = GetPlayerId(GetOwningPlayer(killer))
        if pid >= 0 and pid <= 7 then
            Kills[pid + 1] = Kills[pid + 1] + 1
        end
    end)
end

-- Midas' Touch — war3map.j 31669-31820. A cursed item (I095) costs its holder 10 gold per
-- kill until their gold reaches 1500, at which point it "purifies" into the Blessing (I096):
-- +20 gold per kill. Dropping either item detaches it (attune to Player(10) so kills stop
-- crediting anyone). State lives in MidasTouchPlayer / MidasHero / MidasPurifiedAlready.
local function registerMidas()
    local I095, I096 = FourCC('I095'), FourCC('I096')
    local creditsHolder = function()
        local k = GetKillingUnit()
        return k ~= nil and GetOwningPlayer(k) == MidasTouchPlayer
    end

    -- Curse + Blessing both fire on a kill by the holder; only one is enabled at a time.
    local curse, blessing
    curse = CreateTrigger()
    DisableTrigger(curse)
    TriggerRegisterAnyUnitEventBJ(curse, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(curse, Condition(creditsHolder))
    TriggerAddAction(curse, function()
        AdjustPlayerStateBJ(-10, MidasTouchPlayer, PLAYER_STATE_RESOURCE_GOLD)
        TriggerSleepAction(GetRandomReal(1.0, 3.0))
        if GetPlayerState(MidasTouchPlayer, PLAYER_STATE_RESOURCE_GOLD) >= 1500
            and not MidasPurifiedAlready then
            DisplayTextToForce(GetForceOfPlayer(MidasTouchPlayer),
                "|cffCD2600You have broken the Curse of the Midas' Touch!!|r")
            MidasPurifiedAlready = true
            if MidasHero then
                RemoveItem(GetItemOfTypeFromUnitBJ(MidasHero, I095))
                PlaySoundOnUnitBJ(snd.DivineShield, 100, MidasHero)
                UnitAddItemByIdSwapped(I096, MidasHero)
            end
            DisableTrigger(curse)
            EnableTrigger(blessing)
        end
    end)

    blessing = CreateTrigger()
    DisableTrigger(blessing)
    TriggerRegisterAnyUnitEventBJ(blessing, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(blessing, Condition(creditsHolder))
    TriggerAddAction(blessing, function()
        AdjustPlayerStateBJ(20, MidasTouchPlayer, PLAYER_STATE_RESOURCE_GOLD)
    end)

    -- Pick up the cursed item -> attune + arm the curse.
    local touch = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(touch, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(touch, Condition(function()
        return not IsUnitIllusion(GetManipulatingUnit())
            and GetItemTypeId(GetManipulatedItem()) == I095
    end))
    TriggerAddAction(touch, function()
        MidasTouchPlayer = GetOwningPlayer(GetManipulatingUnit())
        MidasHero = GetManipulatingUnit()
        EnableTrigger(curse)
    end)

    -- Pick up the purified Blessing -> re-attune.
    local equip = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(equip, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(equip, Condition(function()
        return not IsUnitIllusion(GetManipulatingUnit())
            and GetItemTypeId(GetManipulatedItem()) == I096
    end))
    TriggerAddAction(equip, function()
        DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(GetManipulatingUnit())),
            "The Midas' Touch is now attuned to you.")
        MidasTouchPlayer = GetOwningPlayer(GetManipulatingUnit())
    end)

    -- Drop either item -> detach (attune to Player(10) so curse/blessing stop crediting anyone).
    local unequip = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(unequip, EVENT_PLAYER_UNIT_DROP_ITEM)
    TriggerAddCondition(unequip, Condition(function()
        if IsUnitIllusion(GetManipulatingUnit()) then return false end
        local id = GetItemTypeId(GetManipulatedItem())
        return id == I095 or id == I096
    end))
    TriggerAddAction(unequip, function()
        DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(GetManipulatingUnit())),
            "The Midas' Touch is no longer attuned to you.")
        MidasTouchPlayer = Player(10)
    end)
end

-- Energy (= LUMBER) regeneration — war3map.j 14385-14423. Every 3s, each player below 100
-- energy gains +EnergyRegenTotal; 2s later, anyone above 100 decays by 1 (soft cap 100).
-- Powers the energy-based classes (Engineer's lumber, Energy Drink item) and the W22/W27
-- weather effects that tweak EnergyRegenTotal. Started at gameplay start (BeginningStart2).
local energyRegenStarted = false
function StartEnergyRegeneration()
    if energyRegenStarted then return end
    energyRegenStarted = true
    local t = CreateTrigger()   -- periodic trigger, not a timer: the action sleeps mid-way
    TriggerRegisterTimerEventPeriodic(t, 3.0)
    TriggerAddAction(t, function()
        ForForce(GetPlayersAll(), function()
            local p = GetEnumPlayer()
            if GetPlayerState(p, PLAYER_STATE_RESOURCE_LUMBER) < 100 then
                AdjustPlayerStateBJ(EnergyRegenTotal, p, PLAYER_STATE_RESOURCE_LUMBER)
            end
        end)
        TriggerSleepAction(2.0)
        ForForce(GetPlayersAll(), function()
            local p = GetEnumPlayer()
            if GetPlayerState(p, PLAYER_STATE_RESOURCE_LUMBER) > 100 then
                AdjustPlayerStateBJ(-1, p, PLAYER_STATE_RESOURCE_LUMBER)
            end
        end)
    end)
end

-- ── Harbor ships (war3map.j 27111-27276) ──────────────────────────────────────
-- Once Seafaring is researched, merchant ships sail in on a 240-360s loop: spawn at
-- ShipSpawnStart → sail to the dock → 90s layover → sail to ShipLeaveA → out to
-- ShipDespawn → removed. Improved Rudders (R015) starts the tier-2 ship loop.
-- The Swallow (h06L, the players' own ship) is exempt from all waypoint triggers.
local SHIP_TIERS = {
    [1] = { FourCC('h049'), FourCC('h04F'), FourCC('h04G') },
    [2] = { FourCC('h04H'), FourCC('h04K'), FourCC('h04G') },
}
local shipLoopOn = { false, false }

-- Set of all merchant-ship unit ids (flattened from SHIP_TIERS) for SELL detection.
local MERCHANT_SHIP_IDS = {}
for _, tier in ipairs(SHIP_TIERS) do
    for _, id in ipairs(tier) do MERCHANT_SHIP_IDS[id] = true end
end

local function isMerchantShip()
    local u = GetEnteringUnit()
    return GetOwningPlayer(u) == Player(8) and GetUnitTypeId(u) ~= FourCC('h06L')
end

local function randomIn(rect)
    return GetRandomReal(GetRectMinX(rect), GetRectMaxX(rect)),
           GetRandomReal(GetRectMinY(rect), GetRectMaxY(rect))
end

local function registerShipWaypoints()
    OnEnterRect(rct.ShipSpawnStart, isMerchantShip, function()
        local x, y = randomIn(rct.ShipDockArea)
        IssuePointOrder(GetEnteringUnit(), "move", x, y)
    end)
    OnEnterRect(rct.ShipDockArea, isMerchantShip, function()
        local ship = GetEnteringUnit()
        TriggerSleepAction(90.0)   -- layover at the dock
        if GetUnitTypeId(ship) ~= 0 then
            local x, y = randomIn(rct.ShipLeaveA)
            IssuePointOrder(ship, "move", x, y)
        end
    end)
    OnEnterRect(rct.ShipLeaveA, isMerchantShip, function()
        local x, y = randomIn(rct.ShipDespawn)
        IssuePointOrder(GetEnteringUnit(), "move", x, y)
    end)
    OnEnterRect(rct.ShipDespawn, isMerchantShip, function()
        RemoveUnit(GetEnteringUnit())
    end)
end

-- Deviation from JASS (playtest triage-2 bug #32): the merchant ships sell *land* units
-- (mercenaries), but the original map has no handler relocating the bought unit. WC3 parks
-- it next to the seller — which for a docked ship is deep water (unpathable) — so the
-- engine reports "no room to be placed" and the unit is stuck. There is NO such SELL
-- trigger in war3map.j (the ship cluster is purely waypoint movement, 27111-27276; the
-- only EVENT_PLAYER_UNIT_SELL triggers, 17620 / 25191 / 25241, handle spirit/ballista
-- tower rebuilds, not ship purchases). Fix: on SELL from a merchant ship, SetUnitPosition
-- the sold unit onto the dock area — SetUnitPosition snaps to the nearest pathable cell,
-- which lands the mercenary on the shore.
local function registerMercenaryDisembark()
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SELL)
    TriggerAddCondition(t, Condition(function()
        return MERCHANT_SHIP_IDS[GetUnitTypeId(GetSellingUnit())] == true
    end))
    TriggerAddAction(t, function()
        local bought = GetSoldUnit()
        if not bought or GetUnitTypeId(bought) == 0 then return end
        -- Snap to the nearest pathable cell around the dock (deep-water-safe).
        SetUnitPosition(bought, GetRectCenterX(rct.ShipDockArea), GetRectCenterY(rct.ShipDockArea))
    end)
end

-- Start a ship-spawn loop (tier 1 = Seafaring, tier 2 = Improved Rudders). Runs while
-- SeafaringLv1 holds; each pass waits 240-360s then sails one random tier ship in.
function StartShipSpawns(tier)
    if shipLoopOn[tier] then return end
    shipLoopOn[tier] = true
    local t = CreateTrigger()
    TriggerAddAction(t, function()
        while SeafaringLv1 do
            TriggerSleepAction(GetRandomReal(240.0, 360.0))
            if not SeafaringLv1 then break end
            CreateUnit(Player(8), SHIP_TIERS[tier][GetRandomInt(1, 3)],
                GetRectCenterX(rct.ShipSpawnStart), GetRectCenterY(rct.ShipSpawnStart), 0.0)
        end
        shipLoopOn[tier] = false
    end)
    TriggerExecute(t)
end

-- Radley the dog (war3map.j 29218-29264, 29267-29284, 33566-33578). The pup n011 idles at
-- his hangout (far SW) until someone picks up the "Treats" item (I0BY); then he periodically
-- pads over to whoever holds the treats, with a flavor line. Drop the treats and he goes home.
local RADLEY_FLAVOR = {
    "The pup wags his tail.",
    "The dog paws at your trouser legs.",
    "Puts his nose in the pouch you are holding.",
}
local radleyOwner = nil
local function registerRadley()
    local follow = CreateTrigger()
    DisableTrigger(follow)
    TriggerRegisterTimerEventPeriodic(follow, 120.0)
    TriggerAddAction(follow, function()
        if radleyOwner and unit_n011 then
            IssueTargetOrder(unit_n011, "move", radleyOwner)
            CreateTextTagUnitBJ(RADLEY_FLAVOR[GetRandomInt(1, 3)], unit_n011,
                0, 8.0, 0.0, 100, 0.0, 0)
            SetTextTagLifespanBJ(GetLastCreatedTextTag(), 5)
        end
    end)

    local pick = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(pick, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(pick, Condition(function()
        return GetItemTypeId(GetManipulatedItem()) == ITEM.RadleyTreats
    end))
    TriggerAddAction(pick, function()
        radleyOwner = GetManipulatingUnit()
        EnableTrigger(follow)
        if unit_n011 and radleyOwner then
            IssueTargetOrder(unit_n011, "move", radleyOwner)
        end
    end)

    local drop = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(drop, EVENT_PLAYER_UNIT_DROP_ITEM)
    TriggerAddCondition(drop, Condition(function()
        return GetItemTypeId(GetManipulatedItem()) == ITEM.RadleyTreats
    end))
    TriggerAddAction(drop, function()
        radleyOwner = nil
        DisableTrigger(follow)
        if unit_n011 then
            IssuePointOrder(unit_n011, "move",
                GetRectCenterX(rct.RadleyHangout), GetRectCenterY(rct.RadleyHangout))
        end
    end)
end

-- ── The Swallow's Anchor (war3map.j 32036-32083) ──────────────────────────────
-- The Anchor item (I0C0) summons the player's own defence ship, the Swallow (h06L), at
-- the dock when a hero picks it up; dropping the item dismisses the ship again. The ship
-- is the dim-blue exempt unit the merchant-ship loop already skips.
local function registerSwallowAnchor()
    local theSwallow = nil

    local pick = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(pick, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddCondition(pick, Condition(function()
        return IsUnitType(GetManipulatingUnit(), UNIT_TYPE_HERO)
            and GetItemTypeId(GetManipulatedItem()) == ITEM.SwallowAnchor
    end))
    TriggerAddAction(pick, function()
        local x, y = GetRectCenterX(rct.ShipDockArea), GetRectCenterY(rct.ShipDockArea)
        theSwallow = CreateUnit(GetOwningPlayer(GetManipulatingUnit()), FourCC('h06L'), x, y, bj_UNIT_FACING)
        SetUnitVertexColorBJ(theSwallow, 50.0, 50.0, 100.0, 50.0)
    end)

    local drop = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(drop, EVENT_PLAYER_UNIT_DROP_ITEM)
    TriggerAddCondition(drop, Condition(function()
        return GetItemTypeId(GetManipulatedItem()) == ITEM.SwallowAnchor
    end))
    TriggerAddAction(drop, function()
        if theSwallow then RemoveUnit(theSwallow); theSwallow = nil end
    end)
end

function RegisterMiscTriggers()
    registerLevelUpFloaters()
    RegisterHeroDeathCries()
    registerKillScoring()
    registerMidas()
    registerShipWaypoints()
    registerMercenaryDisembark()
    registerRadley()
    registerSwallowAnchor()
end
