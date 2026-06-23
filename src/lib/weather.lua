-- Weather system. Requirements: environment/Weather.md. Source: war3map.j 30196-31660.
--
-- Each level rolls a weather (1-31); IDs 15-31 have an effect, 1-14 = clear. The matching
-- visual weather plays over the map for 90s with a flavor announce. The Meteorologist feat
-- (MeteorlogistFeatOn) gives a 50% chance to cancel a rolled *negative* weather.
--
-- Ported: the roll + visual weather + names + Meteorologist deny + the mechanical
-- sub-effects (Acid Rain damage, Mageslayer drain, Mute silence, Fortune loot mods, etc.).

-- ── Shared helpers (declared before the mechEffect closures that capture them) ───

-- Apply fn (using GetEnumUnit()) to every non-P8/P9 non-structure unit on the map.
local function allPlayerUnits(fn)
    ForUnitsInRect(GetPlayableMapRect(), function()
        return GetOwningPlayer(GetFilterUnit()) ~= Player(8)
            and GetOwningPlayer(GetFilterUnit()) ~= Player(9)
            and not IsUnitType(GetFilterUnit(), UNIT_TYPE_STRUCTURE)
    end, fn)
end

-- Spawn a temporary weather-entity unit at WeatherTarget and remove it after `dur` seconds.
local function spawnWeatherUnit(unitId, dur)
    CreateNUnitsAtLoc(1, FourCC(unitId), Player(11),
        GetRectCenter(rct.WeatherTarget), bj_UNIT_FACING)
    After(dur, function()
        local grp = GetUnitsOfPlayerAndTypeId(Player(11), FourCC(unitId))
        ForGroup(grp, function() RemoveUnit(GetEnumUnit()) end)
        DestroyGroup(grp)
    end)
end

-- W[n] = { name, negative, effect = WC3 weather FourCC (or nil for a text-only weather) }
local W = {}
local function w(n, name, negative, effect)
    W[n] = { name = name, negative = negative, effect = effect and FourCC(effect) or nil }
end
--   #   name                      neg     visual (war3map.j AddWeatherEffectSaveLast)
w(15, "Acid Rain",            true,  'RLlr')  -- heavy Lordaeron rain
w(16, "Wind Gusts",           true,  'WOlw')  -- light Outland wind
w(17, "Holy Winds",           false, 'LRma')
w(18, "Deluge",               true,  'RLhr')
w(19, "Manastorm",            true,  'MEds')
w(20, "Haunt Fog",            true,  'FDgh')  -- green dungeon fog
w(22, "Heat Wave",            true,  nil)
w(23, "Blizzard",             true,  'SNbs')  -- northrend blizzard
w(24, "Mageslayer Mists",     true,  'FDrh')  -- red dungeon fog
w(25, "Mute Breezes",         true,  'FDwh')  -- white dungeon fog
w(26, "Midnight Storm",       true,  nil)
w(27, "Dryad's Tears",        false, nil)
w(28, "Invigorating Breezes", false, nil)
w(29, "Angelic Rainbow",      false, nil)
w(30, "Fortune's Favor",      false, nil)
w(31, "Fortune's Gloom",      true,  nil)

-- ── Mechanical sub-effects (war3map.j 30196-31660) ─────────────────────────────

-- W15 Acid Rain: -1% HP every 5s for 90s to all non-P8/P9 non-structure units.
W[15].mechEffect = function()
    local tick, gen = 0, RandomWeather
    Every(5.0, function()
        tick = tick + 1
        if RandomWeather ~= gen or tick > 18 then return true end   -- stop
        allPlayerUnits(function()
            local u = GetEnumUnit()
            local hp = GetUnitStateSwap(UNIT_STATE_LIFE, u)
            SetUnitLifeBJ(u, hp - hp / 100.0)
        end)
    end)
end

-- W16 Wind Gusts: spawn tornado unit (e00B) at WeatherTarget for 90s.
W[16].mechEffect = function() spawnWeatherUnit('e00B', 90.0) end

-- W17 Holy Winds: spawn holy-wind unit (e00C) at WeatherTarget for 90s.
W[17].mechEffect = function() spawnWeatherUnit('e00C', 90.0) end

-- W18 Deluge: unit e00A casts cloudoffog over the WeatherTarget zone.
W[18].mechEffect = function()
    if unit_e00A then
        IssuePointOrderLoc(unit_e00A, "cloudoffog", GetRectCenter(rct.WeatherTarget))
    end
end

-- W19 Manastorm: spawn mana-storm unit (e009) at WeatherTarget for 90s.
W[19].mechEffect = function() spawnWeatherUnit('e009', 90.0) end

-- W20 Haunt Fog: unit e008 casts acid bomb over the WeatherTarget zone.
W[20].mechEffect = function()
    if unit_e008 then
        IssuePointOrderLoc(unit_e008, "acidbomb", GetRectCenter(rct.WeatherTarget))
    end
end

-- W22 Heat Wave: disables Energy Regeneration for 90s (war3map.j 30924-30929 — the JASS
-- DisableTriggers gg_trg_Energy_Regeneration, sleeps 90s, EnableTriggers it). misc.lua's
-- StartEnergyRegeneration now exposes its periodic trigger as trg_EnergyRegeneration, so we
-- can pause/resume it the same way. Guarded in case regen hasn't started (pre-gameplay).
W[22].mechEffect = function()
    DisplayTimedTextToForce(GetPlayersAll(), 8.0,
        "|cffff4400Heat Wave: Energy regeneration halted for 90 seconds!|r")
    if trg_EnergyRegeneration then DisableTrigger(trg_EnergyRegeneration) end
    After(90.0, function()
        if trg_EnergyRegeneration then EnableTrigger(trg_EnergyRegeneration) end
    end)
end

-- W23 Blizzard: spawn blizzard unit (e00F) at WeatherTarget for 90s.
W[23].mechEffect = function() spawnWeatherUnit('e00F', 90.0) end

-- W24 Mageslayer Mists: drain 20 mana from all non-P8/P9 non-structure units every 5s for 90s.
W[24].mechEffect = function()
    local tick, gen = 0, RandomWeather
    Every(5.0, function()
        tick = tick + 1
        if RandomWeather ~= gen or tick > 18 then return true end   -- stop
        allPlayerUnits(function()
            local u = GetEnumUnit()
            local mana = GetUnitStateSwap(UNIT_STATE_MANA, u)
            SetUnitManaBJ(u, math.max(0.0, mana - 20.0))
        end)
    end)
end

-- W25 Mute Breezes: unit e008 casts silence over the WeatherTarget zone for 75s.
W[25].mechEffect = function()
    if unit_e008 then
        IssuePointOrderLoc(unit_e008, "silence", GetRectCenter(rct.WeatherTarget))
    end
end

-- W26 Midnight Storm: night + rain + lightning flashes + thunder for 90s (storm.lua).
-- StartStorm(..., night=true) freezes the day/night cycle at midnight so the directional-light
-- flashes dramatically reveal the dark terrain (the Storm-example look). This replaces the
-- original's flat black cinematic filter, which dimmed everything uniformly (incl. the flashes)
-- and so couldn't produce the reveal. Deviation — see environment/Weather.md §Deviation.
W[26].mechEffect = function()
    StartStorm(rct.EntireGameArea, 90.0, true)
end

-- W27 Dryad's Tears: boosts energy regen (+2) for 90s (EnergyRegenTotal system).
W[27].mechEffect = function()
    EnergyRegenTotal = EnergyRegenTotal + 2
    local gen = RandomWeather
    After(90.0, function()
        if RandomWeather == gen then EnergyRegenTotal = EnergyRegenTotal - 2 end
    end)
end

-- W28 Invigorating Breezes: spawn morale-aura unit (e00Q) at WeatherTarget for 90s.
W[28].mechEffect = function() spawnWeatherUnit('e00Q', 90.0) end

-- W29 Angelic Rainbow: instantly restore all non-P8/P9 units to full HP and mana.
W[29].mechEffect = function()
    allPlayerUnits(function()
        local u = GetEnumUnit()
        SetUnitLifePercentBJ(u, 100)
        SetUnitManaPercentBJ(u, 100)
    end)
end

-- W30 Fortune's Favor: ItemDropTotal -= 5 for 60s (more loot drops).
W[30].mechEffect = function()
    ItemDropTotal = ItemDropTotal - 5
    local gen = RandomWeather
    After(60.0, function()
        if RandomWeather == gen then ItemDropTotal = ItemDropTotal + 5 end
    end)
end

-- W31 Fortune's Gloom: ItemDropTotal += 5 for 60s (fewer loot drops).
W[31].mechEffect = function()
    ItemDropTotal = ItemDropTotal + 5
    local gen = RandomWeather
    After(60.0, function()
        if RandomWeather == gen then ItemDropTotal = ItemDropTotal - 5 end
    end)
end

local activeWeather = nil

-- Remove the currently-showing weather visual, if any. Safe to call repeatedly.
local function clearWeather()
    if activeWeather then
        RemoveWeatherEffect(activeWeather)
        activeWeather = nil
    end
end

local function applyWeather(entry)
    DisplayTimedTextToForce(GetPlayersAll(), 12.0, "|cffaaccffWeather: " .. entry.name .. "|r")
    -- ALWAYS drop the prior weather first — even when this weather has no visual of its own.
    -- BUG FIX (triage-5): previously the remove lived inside `if entry.effect`, so switching from
    -- Blizzard (has a visual) to a no-visual weather like Midnight Storm (26) left the snow falling
    -- forever ("Blizzard doesn't clear").
    clearWeather()
    if entry.effect then
        activeWeather = AddWeatherEffectSaveLast(rct.EntireGameArea, entry.effect)
        EnableWeatherEffect(activeWeather, true)   -- AddWeatherEffect(SaveLast) creates it DISABLED;
        -- the JASS enables it on the next line every time (war3map.j 30316 etc.).
        local e = activeWeather
        After(90.0, function()
            -- Only remove if a newer weather hasn't already replaced (and removed) this one —
            -- otherwise we'd double-free e.
            if activeWeather == e then clearWeather() end
        end)
    end
    if entry.mechEffect then entry.mechEffect() end
end

-- Roll and apply a level's weather. Called after each level starts (levels.lua).
function RollWeather()
    -- Border Skirmisher's Sabotage temporarily lowers DifficultyModifier; the JASS undoes it here,
    -- at each per-level weather roll (war3map.j 30286). trg_Sabotage_Reset is created in abilities.lua;
    -- ConditionalTriggerExecute only restores when SabotageOn is set (matching the JASS condition).
    if trg_Sabotage_Reset then ConditionalTriggerExecute(trg_Sabotage_Reset) end
    StopStorm()   -- end any lightning storm left over from a previous level's Midnight Storm
    local n = GetRandomInt(1, 31)
    RandomWeather = n
    DenyWeather = 0
    local entry = W[n]
    if not entry then clearWeather(); return end  -- 1-14 / unmapped → clear (and drop prior visual)
    if entry.negative and MeteorlogistFeatOn and GetRandomInt(1, 2) == 2 then
        DenyWeather = 2
        clearWeather()                            -- denied → no new weather; clear the prior one too
        DisplayTimedTextToForce(GetPlayersAll(), 8.0,
            "|cff88ccffNegative weather (" .. entry.name .. ") prevented by the Meteorologist feat.|r")
        return
    end
    applyWeather(entry)
end

-- Debug-only: force weather N right now, bypassing the roll (debug.lua "-weather"). Lets you
-- watch a specific effect (e.g. 26 = Midnight Storm + lightning) without level-rolling for it.
function ForceWeather(n)
    StopStorm()
    DisplayCineFilterBJ(false)   -- clear a lingering Midnight Storm darken when hopping weathers via -weather
    RandomWeather = n
    DenyWeather = 0
    local entry = W[n]
    if not entry then
        clearWeather()
        DisplayTimedTextToForce(GetPlayersAll(), 6.0, "|cffaaccffWeather " .. n .. " = clear (no effect).|r")
        return
    end
    applyWeather(entry)
end
