-- Discover areas & dungeons — war3map.j 13152-14385. Requirements: misc/DiscoverAreas.md.
-- Seven optional zones: walking onto a discover spot announces + pings + drops a Circle of
-- Power at the entrance (once); entrance/exit rects teleport heroes in and out (the Coral
-- Cave adds a multi-level dive network). One-shot flavor texts spook the spelunkers, and
-- killing a dungeon's boss removes invulnerability from its treasure chest.
-- Data extracted via dirty/extract_discover.py. Deviations: portals move only player-slot
-- (0-7) units (the original's filters varied between "not neutral"/"not P12" per portal);
-- the Underwater_sounds ambience loop (UnderwaterGroup) is not ported (cosmetic, ⬜).

local NCOP = FourCC('ncop')

-- { spot = discover rect, name, entrance = ping/circle rect }
local DISCOVERIES = {
    { spot = 'Region283',                name = "the Ruined Cathedral!",     entrance = 'Region283' },
    { spot = 'Region270',                name = "the Bears Cave!",           entrance = 'Region270' },
    { spot = 'Region266',                name = "the Treasure Cove!",        entrance = 'Region266' },
    { spot = 'IceDragonCaveEntrance',    name = "the Ice Dragon Cave!",      entrance = 'IceDragonCaveEntrance' },
    { spot = 'VernSewersDiscover',       name = "the Vern Sewers!",          entrance = 'VernSewersEntrance' },
    { spot = 'CaveOutskirtsDiscoverSpot', name = "the Cave on the Outskirts!", entrance = 'CaveOutskirtsEntrance' },
    { spot = 'CoralCaveDiscoverSpot',    name = "the Coral Cave!",           entrance = 'CoralCaveEntrance' },
}

-- Portal pairs: stepping into `from` teleports the hero to the centre of `to`.
local PORTALS = {
    -- Ruined Cathedral (+ its two inner caves)
    { from = 'Region283', to = 'Region284' }, { from = 'Region285', to = 'Region286' },
    { from = 'Region274', to = 'Region275' }, { from = 'Region276', to = 'Region277' },
    -- Bears Cave / Treasure Cove / Ice Dragon Cave
    { from = 'Region270', to = 'Region271' }, { from = 'Region272', to = 'Region273' },
    { from = 'Region266', to = 'Region267' }, { from = 'Region268', to = 'Region269' },
    { from = 'IceDragonCaveEntrance', to = 'IceDragonCave' },
    { from = 'IceDragonCaveExit',     to = 'IceDragonCaveExit2' },
    -- Vern Sewers / Cave on the Outskirts
    { from = 'VernSewersEntrance', to = 'VernSewersEntranceDest' },
    { from = 'VernSewersExit',     to = 'VernSewersExitDest' },
    { from = 'CaveOutskirtsEntrance', to = 'CaveOutskirtsEntranceDest' },
    { from = 'CaveOutskirtsLeave',    to = 'CaveOutskirtsExitDest' },
    -- Coral Cave + dive network (war3map.j 14010-14256)
    { from = 'CoralCaveEntrance', to = 'CoralCaveEntranceDest' },
    { from = 'CoralCaveExit',     to = 'CoralCaveExitDest' },
    { from = 'CoralCaveDiveEnt1', to = 'CoralCaveDive1Dest' },
    { from = 'CoralDive1ExitLeft',  to = 'CoralDive1ExitLeftDest' },
    { from = 'CoralDive1ExitRight', to = 'CoralDive1ExitRightDest' },
    { from = 'CoralReturnDive1',    to = 'CoralReturnDive1Dest' },
    { from = 'CoralSecretDive',       to = 'CoralSecretDiveDest' },
    { from = 'CoralSecretDiveReturn', to = 'CoralSecretDiveReturnDest' },
    { from = 'CoralDive2Ent',    to = 'CoralDive2Dest' },
    { from = 'CoralDive2Return', to = 'DestructibleTrapA' },
    { from = 'BossDiveEntrance', to = 'BossDiveEntranceDest' },
    { from = 'BossDiveReturn',   to = 'CoralCaveExitDest' },
}

-- One-shot flavor texts (shown to the entering unit's owner, then disarmed; a dungeon's
-- boss death also disarms its remaining flavor — handles kept in flavorTrg by group).
local FLAVOR = {
    iceDragon = {
        { rect = 'IceDragonFlavor', text = "|cffaaddffYou feel a frosty chill as you enter this cavern... theres a terrifying ice dragon staring right at you!|r" },
    },
    sewers = {
        { rect = 'VernSewersFlavor1', text = "The chittering of rats and the smell of sewage greets you as you enter." },
        { rect = 'VernSewersFlavor2', text = "A horrific pile of ooze slides towards you!" },
        { rect = 'VernSewersFlavor3', text = "Glowing red eyes peer at you from the darkness as a gargantuan rat comes stalking out!" },
    },
    outskirts = {
        { rect = 'CaveOutskirtsFlavor1', text = "The sounds of low growls fill your ears - wolves." },
        { rect = 'CaveOutskirtsFlavor2', text = "A roar greets you as you enter this chamber - a grizzly bear!" },
        { rect = 'CaveOutskirtsFlavor3', text = "The largest wolf you've ever seen stands at the end of the cavern!" },
    },
    coral = {
        { rect = 'CoralFlavor1', text = "You see a pool of dark water to your right... should you dive in?" },
        { rect = 'CoralFlavor2', text = "You hear the sounds of a haunting melody ahead..." },
    },
}

-- Dungeon boss → its chest (nearest unit of the chest type loses invulnerability) + which
-- flavor group goes quiet (war3map.j treasure/ice dragon/Dire Rat/Pack Leader/Coral *_Dies).
local BOSSES = {
    { boss = 'h05E', chest = 'h06I', flavor = nil },          -- Treasure Cove guardian
    { boss = 'n016', chest = nil,    flavor = 'iceDragon' },  -- Ice Dragon
    { boss = 'h06H', chest = 'h06I', flavor = 'sewers' },     -- Dire Rat (Vern Sewers)
    { boss = 'h05A', chest = 'h056', flavor = 'outskirts' },  -- Pack Leader (Outskirts)
    { boss = 'O00V', chest = 'h05G', flavor = 'coral' },      -- Coral boss ("ocean titan")
}

local function isPlayerUnit()
    return GetPlayerId(GetOwningPlayer(GetEnteringUnit())) <= 7
end

function RegisterDiscoverTriggers()
    -- discoveries: announce + ping + Circle of Power, once each
    for _, d in ipairs(DISCOVERIES) do
        local trg
        trg = OnEnterRect(rct[d.spot], isPlayerUnit, function()
            DisableTrigger(trg)
            if snd.BotWFound then PlaySoundBJ(snd.BotWFound) end
            DisplayTextToForce(GetPlayersAll(),
                GetPlayerName(GetOwningPlayer(GetEnteringUnit())) .. " has discovered " .. d.name)
            local e = rct[d.entrance]
            PingMinimap(GetRectCenterX(e), GetRectCenterY(e), 6.0)
            CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), NCOP,
                GetRectCenterX(e), GetRectCenterY(e), bj_UNIT_FACING)
        end)
    end

    -- portals: teleport + pan the owner's camera
    for _, p in ipairs(PORTALS) do
        OnEnterRect(rct[p.from], isPlayerUnit, function()
            local u = GetEnteringUnit()
            local dest = rct[p.to]
            local x, y = GetRectCenterX(dest), GetRectCenterY(dest)
            SetUnitPosition(u, x, y)
            PanCameraToTimedForPlayer(GetOwningPlayer(u), x, y, 0)
        end)
    end

    -- one-shot flavor (per group, so boss deaths can silence the leftovers)
    local flavorTrg = {}
    for group, list in pairs(FLAVOR) do
        flavorTrg[group] = {}
        for i, f in ipairs(list) do
            local trg
            trg = OnEnterRect(rct[f.rect], isPlayerUnit, function()
                DisableTrigger(trg)
                DisplayTextToForce(GetForceOfPlayer(GetOwningPlayer(GetEnteringUnit())), f.text)
            end)
            flavorTrg[group][i] = trg
        end
    end

    -- boss deaths: unlock the nearest chest + quiet the dungeon's flavor
    for _, b in ipairs(BOSSES) do
        local bossId = FourCC(b.boss)
        local chestId = b.chest and FourCC(b.chest) or nil
        OnAnyUnit(EVENT_PLAYER_UNIT_DEATH, function()
            return GetUnitTypeId(GetDyingUnit()) == bossId
        end, function()
            local d = GetDyingUnit()
            if chestId then
                -- nearest chest of the type (two h06I chests exist — pick this dungeon's)
                local g = GetUnitsOfTypeIdAll(chestId)
                local best, bestD = nil, nil
                ForGroup(g, function()
                    local c = GetEnumUnit()
                    local dx, dy = GetUnitX(c) - GetUnitX(d), GetUnitY(c) - GetUnitY(d)
                    local dist = dx * dx + dy * dy
                    if not bestD or dist < bestD then best, bestD = c, dist end
                end)
                DestroyGroup(g)
                if best then UnitRemoveAbility(best, FourCC('Avul')) end
            end
            if b.flavor and flavorTrg[b.flavor] then
                for _, trg in ipairs(flavorTrg[b.flavor]) do DisableTrigger(trg) end
            end
        end)
    end
end
