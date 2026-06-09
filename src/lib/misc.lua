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
        return GetUnitTypeId(GetDyingUnit()) == FourCC('H03J')
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

function RegisterMiscTriggers()
    registerLevelUpFloaters()
    RegisterHeroDeathCries()
end
