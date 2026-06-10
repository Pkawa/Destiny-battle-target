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

-- Seafaring (R00Y) — unlocks the harbor ships. The ship-spawn system is not yet ported, so
-- this sets the flag + announces (progression/Training.md §3; misc/MidasShipsAndMisc.md ⬜).
registerResearch('R00Y', " has researched Seafaring! (Basic ships will begin to dock at Vern's Harbor.)",
    function() SeafaringLv1 = true end)
