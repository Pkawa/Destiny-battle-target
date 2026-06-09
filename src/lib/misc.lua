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

function RegisterMiscTriggers()
    registerLevelUpFloaters()
end
