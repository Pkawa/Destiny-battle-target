-- Lightning-and-thunder storm effect. Requirements: environment/Weather.md §Midnight Storm.
--
-- A storm = rain + randomized lightning flashes over an area for a duration, with a thunder growl
-- every few strikes, and (optionally) frozen night so the flashes reveal the dark terrain.
-- High-level scheduling (a strike every 5-10s, the 90s end) runs on the vendored TimerQueue
-- (lib/vendor/timerqueue). The fast FLICKER inside each strike runs on a dedicated 0.03125s periodic
-- timer driving a countdown state machine — a direct port of the Storm system's own approach
-- (war3map.j s__Storm__TStorm_Function). The first cut used nested sub-0.1s TimerQueue callbacks,
-- which drifted/batched and smeared the strobe into a long flash after a few seconds; a fixed
-- periodic ticker is deterministic and matches the reference.
--
-- Uses the "Storm v1.3.1" Hive system's own assets (ideas/systems/Storm...), imported into
-- war3mapImported (L1-3.mdx light-flash models + T1-3.wav thunder; see war3map.imp). The system
-- imitates lightning as a directional-LIGHT FLASH (the area lights up blue) — not a drawn bolt, and
-- no impact model (the stock one carried a "vanilla" thunder-crack). Each strike is a rapid flicker
-- of 2-4 sub-flashes, with a thunder growl every few strikes whose delay scales with brightness.
--
-- Sync-safe: effect/sound creation and the index-ordered state machine + GetRandom* are all synced.

-- ── Config ───────────────────────────────────────────────────────────────────────
local C = {
    FLASH_MODELS = {
        "war3mapImported\\L1.mdx",   -- dim/distant
        "war3mapImported\\L2.mdx",
        "war3mapImported\\L3.mdx",   -- bright/near
    },
    -- Flicker timing (tick = PERIOD). Per the reference: each strike = COUNT sub-flashes, each lit
    -- for PLAY ticks then dark for STOP ticks (s__Storm__TStorm_Function: Play rand(2,4), Stop
    -- rand(1,3), Count rand(2,4)).
    PERIOD      = 0.03125,
    FLASHES_MIN = 2, FLASHES_MAX = 4,
    PLAY_MIN    = 2, PLAY_MAX    = 4,
    STOP_MIN    = 1, STOP_MAX    = 3,

    -- ► HOW DARK a `night` storm gets. Midnight (SetTimeOfDay 0) is already the darkest time of day,
    -- so this adds a black screen overlay ON TOP of it. 0 = just midnight; higher = darker (percent
    -- opacity, 0-100; ~70 is very dark). The flashes stay dramatic because they light the 3D scene
    -- *before* this 2D overlay, so flash-vs-dark contrast is preserved. ↑ raise this for more drama.
    DARKEN      = 65,

    -- Ashenvale heavy rain — the type the Storm example uses. Its ambient sound is the stock path
    -- Sound\Ambient\RainAmbience.wav, which we override with the example's clip (war3map.imp), so the
    -- rain plays that nicer ambience. (nil = no rain.)
    RAIN        = "RAhr",

    GAP_MIN     = 5.0,      -- seconds between strikes (random in [GAP_MIN, GAP_MAX])
    GAP_MAX     = 10.0,
    SPREAD      = 900.0,    -- strikes land within this radius of a player hero (so they're on-screen)
    THUNDER_EVERY = 3,      -- thunder growl roughly every Nth strike (jittered ±1), not every strike
    THUNDER_PITCH_MIN = 0.9, THUNDER_PITCH_MAX = 1.1,   -- per-growl pitch variety (Storm system: 0.9-1.1)

    -- Old stock chain-lightning bolt — looked cheap; kept as an optional accent. Set true to add it.
    USE_BOLT    = false,
    LIGHTNING   = "FORK",
    TOP_Z       = 1400.0,
    BOLT_LIFE   = 0.35,
    R = 0.60, G = 0.72, B = 1.0, A = 1.0,
}

-- ── State ────────────────────────────────────────────────────────────────────────
local queue          -- TimerQueue for the high-level schedule (strikes every 5-10s, 90s end)
local gen   = 0       -- generation token; bumping it cancels the running storm's scheduler
local rain           -- the storm's rain weather effect (one at a time)
local sinceThunder = 0   -- strikes since the last thunder growl
local thunderAt = 3      -- strikes needed before the next growl (jittered each time)

local active = {}    -- active flicker instances (a clean sequence; index-ordered iteration = synced)
local flashTimer     -- the dedicated 0.03125s periodic ticker driving `active`

local function ensureQueue()
    if not queue then queue = TimerQueue.create() end
    return queue
end

-- Remove the storm's rain, if any.
local function removeRain()
    if rain then RemoveWeatherEffect(rain); rain = nil end
end

-- Destroy any in-progress flicker effects and clear the list (storm end / replaced).
local function clearFlashes()
    for i = #active, 1, -1 do
        if active[i].fx then DestroyEffect(active[i].fx) end
        active[i] = nil
    end
end

-- Play a thunder growl (stacked handles → loud, random pitch). variant unused but kept for parity.
local function playThunder()
    local t = snd and snd.Thunder
    if t and #t > 0 then
        local pitch = GetRandomReal(C.THUNDER_PITCH_MIN, C.THUNDER_PITCH_MAX)
        for _, s in ipairs(t[GetRandomInt(1, #t)]) do
            SetSoundPitch(s, pitch)
            StartSound(s)
        end
    end
end

-- The flicker driver: one fixed tick. Each instance counts its `time` down; on expiry it toggles the
-- light (create/destroy) for COUNT sub-flashes, then — every ~Nth strike — waits a brightness-scaled
-- delay and growls thunder, then retires. Mirrors war3map.j s__Storm__TStorm_Function.
local function flashTick()
    for i = #active, 1, -1 do
        local f = active[i]
        f.time = f.time - C.PERIOD
        if f.time <= 0 then
            if f.current >= 1 and f.current <= f.count then
                if not f.on then                       -- dark → lit
                    f.on = true
                    f.time = GetRandomInt(C.PLAY_MIN, C.PLAY_MAX) * C.PERIOD
                    f.fx = AddSpecialEffect(C.FLASH_MODELS[f.variant], f.x, f.y)
                else                                   -- lit → dark
                    f.on = false
                    f.time = GetRandomInt(C.STOP_MIN, C.STOP_MAX) * C.PERIOD
                    if f.fx then DestroyEffect(f.fx); f.fx = nil end
                    f.current = f.current + 1
                    if f.current > f.count then         -- flicker done → thunder-delay phase
                        f.current = 0
                        f.time = f.doThunder
                            and (10 * (f.n * f.n - f.variant * f.variant) + GetRandomInt(0, 10)) * C.PERIOD
                            or 0
                    end
                end
            else                                       -- current == 0: retire (+ thunder if due)
                if f.doThunder then playThunder() end
                if f.fx then DestroyEffect(f.fx); f.fx = nil end
                table.remove(active, i)
            end
        end
    end
end

local function ensureFlashTimer()
    if not flashTimer then
        flashTimer = CreateTimer()
        TimerStart(flashTimer, C.PERIOD, true, flashTick)
    end
end

-- Collect living player heroes (Heroes[1..8]) so strikes land where players actually are.
local function livingHeroes()
    local hs = {}
    if Heroes then
        for i = 1, 8 do
            local h = Heroes[i]
            if h and GetUnitTypeId(h) ~= 0 and not IsUnitDeadBJ(h) then
                hs[#hs + 1] = h
            end
        end
    end
    return hs
end

-- A strike = queue one flicker instance near a random living player hero (the playable area is huge,
-- so uniform strikes would rarely be on-screen). Thunder is decided here (every ~Nth strike).
local function strike(rect)
    local n = #C.FLASH_MODELS
    if n == 0 then return end

    local x, y
    local hs = livingHeroes()
    if #hs > 0 then
        local h = hs[GetRandomInt(1, #hs)]
        x = GetUnitX(h) + GetRandomReal(-C.SPREAD, C.SPREAD)
        y = GetUnitY(h) + GetRandomReal(-C.SPREAD, C.SPREAD)
    else
        x = GetRandomReal(GetRectMinX(rect), GetRectMaxX(rect))
        y = GetRandomReal(GetRectMinY(rect), GetRectMaxY(rect))
    end

    sinceThunder = sinceThunder + 1
    local doThunder = sinceThunder >= thunderAt
    if doThunder then
        sinceThunder = 0
        thunderAt = math.max(1, C.THUNDER_EVERY + GetRandomInt(-1, 1))   -- jitter: ~every 3rd (2-4)
    end

    active[#active + 1] = {
        x = x, y = y, n = n,
        variant = GetRandomInt(1, n),
        count = GetRandomInt(C.FLASHES_MIN, C.FLASHES_MAX),
        current = 1, on = false, time = 0.0, fx = nil,
        doThunder = doThunder,
    }
    ensureFlashTimer()

    -- Optional cheap stock bolt (off by default).
    if C.USE_BOLT then
        local q = ensureQueue()
        local bolt = AddLightningEx(C.LIGHTNING, true, x, y, C.TOP_Z, x, y, 0.0)
        if bolt then
            SetLightningColor(bolt, C.R, C.G, C.B, C.A)
            q:callDelayed(C.BOLT_LIFE, DestroyLightning, bolt)
        end
    end
end

-- Night handling: freezing the day/night cycle at midnight is what makes the flashes "reveal"
-- the dark terrain. The map uses no time-of-day logic, so this is purely atmospheric (it does shrink
-- night sight range — thematic). Synced natives → no desync.
local nightActive = false
local nightSavedTime = 0.0

local function endNight()
    if nightActive then
        SetTimeOfDay(nightSavedTime)
        SetTimeOfDayScale(1.0)
        nightActive = false
        if C.DARKEN and C.DARKEN > 0 then DisplayCineFilterBJ(false) end
    end
end

-- ── Public API ───────────────────────────────────────────────────────────────────

-- Begin a storm over `rect` (default: whole battlefield) for `duration` seconds (default 90s).
-- night = freeze the day/night cycle at midnight for the duration so flashes reveal the dark.
-- Starting a new storm supersedes any running one.
function StartStorm(rect, duration, night)
    rect = rect or rct.EntireGameArea
    duration = duration or 90.0
    gen = gen + 1
    local myGen = gen
    local q = ensureQueue()

    sinceThunder = 0
    thunderAt = C.THUNDER_EVERY
    clearFlashes()   -- drop any prior storm's in-progress flickers

    -- Rain over the storm area for its whole duration (the Storm example pairs flashes with rain).
    removeRain()
    if C.RAIN then
        rain = AddWeatherEffect(rect, FourCC(C.RAIN))
        EnableWeatherEffect(rain, true)
    end

    endNight()   -- restore any prior storm's night first
    if night then
        nightSavedTime = GetTimeOfDay()
        SetTimeOfDayScale(0.0)
        SetTimeOfDay(0.0)
        nightActive = true
        if C.DARKEN and C.DARKEN > 0 then
            -- Black overlay on top of midnight (2s fade-in). Last arg = transparency: 100 = clear,
            -- (100 - DARKEN) = our target opacity. Removed in endNight.
            CinematicFilterGenericBJ(2.0, BLEND_MODE_BLEND,
                "ReplaceableTextures\\CameraMasks\\Black_mask.blp",
                0, 0, 0, 100,  0, 0, 0, 100 - C.DARKEN)
            DisplayCineFilterBJ(true)
        end
    end

    local function step()
        if myGen ~= gen then return end           -- a newer storm (or StopStorm) replaced us
        strike(rect)
        q:callDelayed(GetRandomReal(C.GAP_MIN, C.GAP_MAX), step)
    end
    step()

    -- End the storm after `duration`: halt the scheduler, drop rain/night, clear flickers.
    q:callDelayed(duration, function()
        if myGen == gen then gen = gen + 1; removeRain(); endNight(); clearFlashes() end
    end)
end

-- Stop the active storm immediately (e.g. when a new weather is rolled).
function StopStorm()
    gen = gen + 1
    removeRain()
    endNight()
    clearFlashes()
end
