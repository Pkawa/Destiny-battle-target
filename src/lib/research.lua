-- Research-upgrade system: players research upgrades at their h00Z research building, and
-- each finished research applies a global effect.
-- Requirements: progression/Training.md §2-7. Source: war3map.j 24775-26200.
--
-- Data-driven, like feats.lua / item_effects.lua: a single RESEARCH_FINISH trigger dispatches
-- by GetResearched(). On completion every entry:
--   1. plays the ResurrectTarget chime,
--   2. announces "<player> has researched <...>",
--   3. PROPAGATES the research to all 9 player slots — this is what makes a real WC3 *upgrade*
--      (e.g. Reinforced Towers +300 tower HP) apply to everyone's units and blocks re-research,
--   4. runs an optional onComplete(researcher) for special effects (XP, Princess level-ups, …).
--
-- Adding a research = one registerResearch(code, announce[, onComplete]) line. Pure-upgrade
-- researches need no onComplete — propagation alone applies their object-data bonus.

ResearchFX = {}   -- [researchId] = { announce = string, onComplete = fn(researcher) | nil }

function registerResearch(code, announce, onComplete)
    ResearchFX[FourCC(code)] = { announce = announce, onComplete = onComplete }
end

-- Mark the research complete for every player slot 0-8 so the upgrade applies globally and
-- can't be repeated (the originals propagate to Player(0)..Player(8) in every research action).
local function propagateResearch(code)
    for i = 0, 8 do SetPlayerTechResearchedSwap(code, 1, Player(i)) end
end

-- ── effect builders ────────────────────────────────────────────────────────────

-- Grant `xp` to every player-owned hero on the map (Basic/Advanced/Expert Training,
-- war3map.j 25083-25090 / 26134-26141 / 26175-26182). The original matched all heroes; we
-- exclude Player(9) so research can't level enemy bosses.
local function trainAll(xp)
    return function()
        ForUnitsInRect(GetPlayableMapRect(), function()
            local u = GetFilterUnit()
            return IsUnitType(u, UNIT_TYPE_HERO) and GetOwningPlayer(u) ~= Player(9)
        end, function()
            AddHeroXP(GetEnumUnit(), xp, true)
        end)
    end
end

-- Princess Silmeria (H02G) gains `levels` and learns `ability` (Pride of the People /
-- Pinnacle of Virtue, war3map.j 25787-25788 / 26082-26083).
local function princessBoost(levels, ability)
    local abil = FourCC(ability)
    return function()
        if unit_H02G and GetUnitTypeId(unit_H02G) ~= 0 then
            SetHeroLevelBJ(unit_H02G, GetHeroLevel(unit_H02G) + levels, false)
            UnitAddAbilityBJ(abil, unit_H02G)
        end
    end
end

-- ── Tower rebuild system (war3map.j 25146-25244, 24852-24873, 25965-25996) ──────
-- Once Rebuildable Towers (R00E) is researched: a destroyed guard tower leaves a rebuild
-- pad that SELLS a rebuild unit — buying it removes pad + sold unit and erects the tower
-- again. Ballista Mounts (R013) converts existing towers/pads to the ballista versions and
-- arms the equivalent ballista pair. The trigger pairs start disabled; the researches
-- enable them (stored in these module locals, assigned in RegisterResearchTriggers).
local towerPair, ballistaPair = {}, {}

-- tower dies -> pad; pad sells `soldId` -> tower again ("<player> has rebuilt a <label>!").
local function makeRebuildPair(towerCode, padCode, soldCode, label)
    local towerId, padId, soldId = FourCC(towerCode), FourCC(padCode), FourCC(soldCode)
    local deadT = OnPlayerUnit(Player(8), EVENT_PLAYER_UNIT_DEATH, function()
        return GetUnitTypeId(GetDyingUnit()) == towerId
    end, function()
        local d = GetDyingUnit()
        CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), padId, GetUnitX(d), GetUnitY(d), bj_UNIT_FACING)
    end)
    DisableTrigger(deadT)
    local sellT = OnAnyUnit(EVENT_PLAYER_UNIT_SELL, function()
        return GetUnitTypeId(GetSoldUnit()) == soldId
    end, function()
        local pad, sold = GetSellingUnit(), GetSoldUnit()
        local x, y = GetUnitX(pad), GetUnitY(pad)
        local buyer = GetOwningPlayer(GetBuyingUnit())
        RemoveUnit(pad)
        RemoveUnit(sold)
        CreateUnit(Player(8), towerId, x, y, bj_UNIT_FACING)
        PlaySoundBJ(snd.AllianceSound)
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(buyer) .. " has rebuilt a " .. label .. "!")
    end)
    DisableTrigger(sellT)
    return { deadT = deadT, sellT = sellT }
end

local function enablePair(pair)
    if pair.deadT then EnableTrigger(pair.deadT); EnableTrigger(pair.sellT) end
end

-- ── Dispatch ─────────────────────────────────────────────────────────────────

function RegisterResearchTriggers()
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_RESEARCH_FINISH)
    TriggerAddAction(t, function()
        local code = GetResearched()
        local fx = ResearchFX[code]
        if not fx then return end
        PlaySoundBJ(snd.ResurrectTarget)
        DisplayTextToForce(GetPlayersAll(),
            GetPlayerName(GetOwningPlayer(GetResearchingUnit())) .. fx.announce)
        propagateResearch(code)
        if fx.onComplete then fx.onComplete(GetResearchingUnit()) end
    end)

    -- guard tower h000 <-> pad n003 sells h012; ballista h04C <-> pad n00S sells h04D
    towerPair    = makeRebuildPair('h000', 'n003', 'h012', "tower")
    ballistaPair = makeRebuildPair('h04C', 'n00S', 'h04D', "ballista tower")
end

-- ── Registered researches (war3map.j 24775-26200; progression/Training.md §2-7) ──
-- Many more exist (Flowing Waters, Improved FOR, Strength of Unity, Militia, Engineer
-- Construction/Schematics/Marvel chains, …); add each as one line below. Pure WC3-upgrade
-- researches need only the announce (propagation applies the bonus); the ones below show all
-- four effect shapes (flat XP, hero boost+spell, upgrade-only, flag-set).

-- XP training tiers (R00X/R02N/R02O) — flat XP to all player heroes.
registerResearch('R00X', " has researched Basic Training! (All heroes gain 250 experience.)",    trainAll(250))
registerResearch('R02N', " has researched Advanced Training! (All heroes gain 1000 experience.)", trainAll(1000))
registerResearch('R02O', " has researched Expert Training! (All heroes gain 3000 experiencel.)",  trainAll(3000))  -- "experiencel." typo is in the original

-- Princess Silmeria upgrades (R012/R01B) — +levels + a learned spell.
registerResearch('R012',
    " has researched Pride of the People! (Princess Silmeria gains two levels, and learns Greater Cure.)",
    princessBoost(2, 'A0I5'))
registerResearch('R01B',
    " has researched Pinnacle of Virtue! (Princess Silmeria gains three levels, and learns Holy Aura.)",
    princessBoost(3, 'A0KI'))

-- Tower HP upgrade (R00D) — the +300 applies automatically via the propagated WC3 upgrade.
registerResearch('R00D', " has researched Reinforced Towers!  (+300 max HP to all guard towers!)")

-- Seafaring (R00Y) — basic ships begin docking at Vern's Harbor (loop in misc.lua).
registerResearch('R00Y', " has researched Seafaring! (Basic ships will begin to dock at Vern's Harbor.)",
    function()
        SeafaringLv1 = true
        StartShipSpawns(1)
    end)

-- Improved Rudders (R015, war3map.j Improved_Rudders) — the tier-2 ship loop.
registerResearch('R015', " has researched Improved Rudders (New ships shall begin to appear at Vern Harbor.)",
    function()
        SeafaringLv1 = true   -- rudders alone also get ships sailing
        StartShipSpawns(2)
    end)

-- Harbor Expansionism (R017) — the extra harbor building plot is upgrade-driven; the
-- propagation applies it (war3map.j Harbor_Expansionism).
registerResearch('R017', " has researched Harbor Expansionism (An additional building plot has been constructed at the Harbor.)")

-- Rebuildable Towers (R00E, war3map.j 24852-24873) — arms the tower-rebuild pair: destroyed
-- guard towers leave pads that sell the rebuild unit.
registerResearch('R00E',
    " has researched Rebuildable Towers!  (Guard towers can be rebuilt after being destroyed!)",
    function() enablePair(towerPair) end)

-- Ballista Mounts (R013, war3map.j 25965-25996) — converts existing towers/pads to the
-- ballista versions and arms the ballista rebuild pair.
registerResearch('R013',
    " has researched Ballista Mounts (Guard Towers turn into Ballista Towers.)",
    function()
        local g = GetUnitsOfPlayerAndTypeId(Player(8), FourCC('h000'))
        ForGroup(g, function() ReplaceUnitBJ(GetEnumUnit(), FourCC('h04C'), bj_UNIT_STATE_METHOD_RELATIVE) end)
        DestroyGroup(g)
        local pads = GetUnitsOfTypeIdAll(FourCC('n003'))
        ForGroup(pads, function() ReplaceUnitBJ(GetEnumUnit(), FourCC('n00S'), bj_UNIT_STATE_METHOD_RELATIVE) end)
        DestroyGroup(pads)
        enablePair(ballistaPair)
    end)
