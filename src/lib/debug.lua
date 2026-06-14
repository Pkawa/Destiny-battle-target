-- Developer debug / cheat chat commands. Requirements: systems/DebugCommands.md.
--
-- `-debug` is the master gate: it toggles DebugMode, and every other command is a no-op
-- until it's on (so cheats can't fire by accident). Commands are registered for all
-- player slots and act on the *typing* player's hero where relevant.
-- ⚠ Development only — strip/disable before release (Phase 8). `-tp` uses the local mouse
-- position, so it is single-player only (would desync in multiplayer; debug is SP anyway).

DebugMode          = false
DebugNoAutoAdvance = false   -- read by levels.lua onLevelVictory (-stop)

local mouseX, mouseY = {}, {}   -- per-player-id last cursor world pos (for -tp)
local repickPending  = {}       -- [pid] = true while awaiting a new hero purchase

local function tell(p, msg) DisplayTimedTextToForce(GetForceOfPlayer(p), 14.0, msg) end

-- first hero owned by player p
local function heroOf(p)
    local g = GetUnitsOfPlayerMatching(p, Condition(function()
        return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO)
    end))
    local h = FirstOfGroup(g)
    DestroyGroup(g)
    return h
end

-- register a chat command for every slot; exact=false → prefix match (for args)
local function cmd(text, exact, fn)
    local t = CreateTrigger()
    for i = 0, 11 do TriggerRegisterPlayerChatEvent(t, Player(i), text, exact) end
    TriggerAddAction(t, fn)
end

-- wrap a handler so it only runs when debug mode is on
local function gated(fn)
    return function()
        if not DebugMode then
            tell(GetTriggerPlayer(), "|cffff0000Debug is off — type -debug to enable.|r")
            return
        end
        fn()
    end
end

local function argInt(default)
    return tonumber((GetEventPlayerChatString() or ""):match("(%-?%d+)")) or default
end
local function argWord()
    return ((GetEventPlayerChatString() or ""):match("%s+(%a+)") or ""):lower()
end

-- One message per line (DisplayText doesn't reliably honor "|n" newlines).
local HELP = {
    "|cff00ff00=== DEBUG COMMANDS (gate: -debug) ===|r",
    "-debug help : show this  |  -stop : toggle wave auto-advance",
    "-wave : next waves  |  -goto N : jump to level N  |  -kill : clear wave",
    "-weather N : force weather 15-31 (default 26 = Midnight Storm + lightning)",
    "-lvl N : set hero level  |  -gold N : give gold  |  -tp : hero to cursor",
    "-item POOL [name] : spawn loot — unc/rare/epic/arti/scroll/tarot/set/all (name = filter)",
    "-item treats : spawn Radley's Treats (the pup follows whoever holds them)",
    "-revealmap : reveal whole map  |  -revive : revive your dead hero(es)",
    "-repick : re-pick hero+feat  |  -defeat : lose  |  -megaboss : launch Megaboss 1",
}

function RegisterDebugCommands()
    -- cursor tracker for -tp (only does work while debug is on)
    local mt = CreateTrigger()
    for i = 0, 11 do TriggerRegisterPlayerEvent(mt, Player(i), EVENT_PLAYER_MOUSE_MOVE) end
    TriggerAddAction(mt, function()
        if not DebugMode then return end
        local pid = GetPlayerId(GetTriggerPlayer())
        mouseX[pid] = BlzGetTriggerPlayerMouseX()
        mouseY[pid] = BlzGetTriggerPlayerMouseY()
    end)

    -- -repick assignment: when a re-picking player buys a hero, assign it (bypassing the
    -- normal pick path so DonePicking/BeginningStart don't re-fire), then send it to the
    -- feat area so they can grab a fresh feat.
    local rp = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(rp, EVENT_PLAYER_UNIT_SELL)
    TriggerAddCondition(rp, Condition(function()
        return repickPending[GetPlayerId(GetOwningPlayer(GetBuyingUnit()))] == true
            and IsUnitType(GetSoldUnit(), UNIT_TYPE_HERO)
    end))
    TriggerAddAction(rp, function()
        local p = GetOwningPlayer(GetBuyingUnit())
        local pid = GetPlayerId(p)
        repickPending[pid] = nil
        AssignHero(GetSoldUnit(), pid)
        FeatPicked[GetSoldUnit()] = nil  -- fresh hero; ensure its feat guard is clear
        SetUnitPositionLoc(GetSoldUnit(), GetRectCenter(rct.FeatArea))
        CreateFogModifierRectBJ(true, p, FOG_OF_WAR_VISIBLE, rct.EntireFeatArea)
        PanCameraToTimedLocForPlayer(p, GetRectCenter(rct.FeatArea), 0)
        tell(p, "|cffaaffaa[debug] New hero assigned — buy a feat from a feat shop (you'll return to base).|r")
    end)

    -- ── master toggle + help ──
    cmd("-debug", false, function()
        if (GetEventPlayerChatString() or ""):lower():find("help") then
            local p = GetTriggerPlayer()
            for _, line in ipairs(HELP) do DisplayTimedTextToForce(GetForceOfPlayer(p), 25.0, line) end
            return
        end
        DebugMode = not DebugMode
        DisplayTimedTextToForce(GetPlayersAll(), 8.0, DebugMode
            and "|cff00ff00Debug mode ON|r — type |cffffff00-debug help|r for commands."
            or  "|cffff8800Debug mode OFF.|r")
    end)

    -- ── wave control ──
    cmd("-wave", true, gated(function()
        local n = (CurrentLevel or 0) + 1
        tell(GetTriggerPlayer(), "[debug] starting level " .. n)
        StartLevel(n)
    end))
    cmd("-stop", true, gated(function()
        DebugNoAutoAdvance = not DebugNoAutoAdvance
        DisplayTimedTextToForce(GetPlayersAll(), 8.0, DebugNoAutoAdvance
            and "|cffff8800[debug] wave auto-advance OFF — use -wave.|r"
            or  "|cff00ff00[debug] wave auto-advance ON.|r")
    end))
    cmd("-goto", false, gated(function()
        local n = argInt(1)
        CurrentLevel = n
        StartLevel(n)
    end))
    cmd("-weather", false, gated(function()
        local n = argInt(26)   -- default 26 = Midnight Storm (lightning + thunder)
        tell(GetTriggerPlayer(), "[debug] forcing weather " .. n)
        ForceWeather(n)
    end))
    cmd("-kill", true, gated(function()
        local g = GetUnitsInRectOfPlayer(rct.EntireGameArea, Player(9))
        ForGroup(g, function() KillUnit(GetEnumUnit()) end)
        DestroyGroup(g)
        tell(GetTriggerPlayer(), "[debug] current wave cleared")
    end))

    -- ── hero ──
    cmd("-lvl", false, gated(function()
        local h = heroOf(GetTriggerPlayer())
        if h then SetHeroLevelBJ(h, argInt(GetHeroLevel(h) + 1), true) end
    end))
    cmd("-gold", false, gated(function()
        AdjustPlayerStateBJ(argInt(500), GetTriggerPlayer(), PLAYER_STATE_RESOURCE_GOLD)
    end))
    cmd("-tp", true, gated(function()
        local p = GetTriggerPlayer()
        local h = heroOf(p)
        local pid = GetPlayerId(p)
        if h and mouseX[pid] then SetUnitPosition(h, mouseX[pid], mouseY[pid]) end
    end))
    cmd("-repick", true, gated(function()
        local p = GetTriggerPlayer()
        local pid = GetPlayerId(p)
        local h = heroOf(p)
        if h then RemoveUnit(h); FeatPicked[h] = nil end
        repickPending[pid] = true
        local wisp = CreateUnit(p, FourCC('ewsp'),
            GetRectCenterX(rct.PickModeStart), GetRectCenterY(rct.PickModeStart), bj_UNIT_FACING)
        CreateFogModifierRectBJ(true, p, FOG_OF_WAR_VISIBLE, rct.PickMode)
        PanCameraToTimedLocForPlayer(p, GetRectCenter(rct.PickMode), 0)
        if GetLocalPlayer() == p then ClearSelection(); SelectUnit(wisp, true) end
        tell(p, "|cffaaffaa[debug] Re-pick: walk your wisp into a hero tavern to buy a new hero.|r")
    end))

    -- ── items ──
    -- "-item <pool> [name]" — pool = unc/rare/epic/arti(+2)/scroll/tarot/set/all. With a name
    -- substring it spawns EVERY matching item (e.g. "-item set phal" → the Phalynx pieces).
    local function argTwo()
        local s = GetEventPlayerChatString() or ""
        local a, b = s:match("%s+(%a%w*)%s+(%S+)")
        if not a then a = s:match("%s+(%a%w*)") end
        return (a or ""):lower(), b and b:lower() or nil
    end
    local function spawnLoot(pool, sub)
        local h = heroOf(GetTriggerPlayer())
        if not h then return end
        local name = DebugSpawnItem(pool, sub, GetUnitX(h), GetUnitY(h))
        tell(GetTriggerPlayer(), name and ("[debug] spawned " .. name)
            or "[debug] usage: -item unc|rare|epic|arti|scroll|tarot|set|all|treats [name]")
    end
    cmd("-item", false, gated(function() spawnLoot(argTwo()) end))
    cmd("-mythic", true, gated(function() spawnLoot("artifact") end))
    cmd("-cursed", true, gated(function()
        local h = heroOf(GetTriggerPlayer())
        if not h then return end
        local id = Lv1CursedItemDrop[GetRandomInt(1, 2)]
        if not id then tell(GetTriggerPlayer(), "[debug] cursed pool empty"); return end
        CreateItem(id, GetUnitX(h), GetUnitY(h))
        tell(GetTriggerPlayer(), "[debug] dropped a cursed item")
    end))

    -- ── reveal + revive ──
    cmd("-revealmap", true, gated(function()
        FogEnable(false); FogMaskEnable(false)
        tell(GetTriggerPlayer(), "[debug] map revealed (fog disabled)")
    end))
    cmd("-revive", true, gated(function()
        local p = GetTriggerPlayer()
        local loc = GetRectCenter(rct.StartingPlayerArea)
        local g = GetUnitsOfPlayerMatching(p, Condition(function()
            return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO) and IsUnitDeadBJ(GetFilterUnit())
        end))
        local n = 0
        ForGroup(g, function()
            ReviveHero(GetEnumUnit(), GetLocationX(loc), GetLocationY(loc), true); n = n + 1
        end)
        DestroyGroup(g)
        RemoveLocation(loc)
        tell(p, n > 0 and ("[debug] revived " .. n .. " hero(es)")
            or "[debug] no dead hero to revive")
    end))

    -- ── encounters ──
    cmd("-defeat", true, gated(function()
        if unit_H02G then KillUnit(unit_H02G) else tell(GetTriggerPlayer(), "[debug] Princess Silmeria not found") end
    end))
    cmd("-megaboss", true, gated(function()
        tell(GetTriggerPlayer(), "[debug] Launching Megaboss 1 (Dark One + Fleshmaker) arena...")
        StartMegaboss1()
    end))
end
