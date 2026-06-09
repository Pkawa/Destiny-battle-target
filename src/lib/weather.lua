-- Weather system. Requirements: environment/Weather.md. Source: war3map.j 30196-31660.
--
-- Each level rolls a weather (1-31); IDs 15-31 have an effect, 1-14 = clear. The matching
-- visual weather plays over the map for 90s with a flavor announce. The Meteorologist feat
-- (MeteorlogistFeatOn) gives a 50% chance to cancel a rolled *negative* weather.
--
-- Ported: the roll + visual weather + names + Meteorologist deny. ⬜ Deferred: the
-- mechanical sub-effects (Acid Rain damage, Mageslayer anti-caster, Mute silence, Heat
-- Wave, Fortune loot mods, etc.) — read the cited Weather_NN_* / sub-triggers when adding.

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

local activeWeather = nil

local function applyWeather(entry)
    DisplayTimedTextToForce(GetPlayersAll(), 12.0, "|cffaaccffWeather: " .. entry.name .. "|r")
    if not entry.effect then return end           -- text-only weather (mechanical effect TBD)
    if activeWeather then RemoveWeatherEffect(activeWeather) end
    activeWeather = AddWeatherEffectSaveLast(rct.EntireGameArea, entry.effect)  -- created + enabled
    local e = activeWeather
    local t = CreateTimer()
    TimerStart(t, 90.0, false, function()
        if activeWeather == e then activeWeather = nil end
        RemoveWeatherEffect(e)
        DestroyTimer(t)
    end)
end

-- Roll and apply a level's weather. Called after each level starts (levels.lua).
function RollWeather()
    local n = GetRandomInt(1, 31)
    RandomWeather = n
    DenyWeather = 0
    local entry = W[n]
    if not entry then return end                  -- 1-14 / unmapped → clear
    if entry.negative and MeteorlogistFeatOn and GetRandomInt(1, 2) == 2 then
        DenyWeather = 2
        DisplayTimedTextToForce(GetPlayersAll(), 8.0,
            "|cff88ccffNegative weather (" .. entry.name .. ") prevented by the Meteorologist feat.|r")
        return
    end
    applyWeather(entry)
end
