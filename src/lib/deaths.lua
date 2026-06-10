-- Hero death loop: death tracking, gold loss, near-defeat music, and the defeat condition.
-- Requirements: economy/Economy.md §2 (Gold Loss), systems/MusicSystem.md (Hero Death Music),
--   progression/Achievements.md (Hero_Flawless_Bonus), misc/MiscSystems.md (Defeat Silmeria).
-- Source: war3map.j 6382-6406 (Hero_Flawless_Bonus), 6124-6282 (Hero_Death_Music),
--   10888-11009 (Gold_Loss), 29853-29893 (Defeat_Silmeria).
--
-- Revive of dead heroes is handled at the start of each level by
-- ThingsToDoBeforeEveryLevelBegins (levels.lua) — "revive at the beginning of the next level".

local P8, P9, P12 = Player(8), Player(9), Player(12)

local function isPlayerHero(u)
    local o = GetOwningPlayer(u)
    return IsUnitType(u, UNIT_TYPE_HERO) and o ~= P8 and o ~= P9
end

-- Cached filters: player heroes with life ≥ 1 (still standing) / ≥ 2 (the near-defeat check).
local filterRemaining = Condition(function()
    return isPlayerHero(GetFilterUnit()) and GetUnitState(GetFilterUnit(), UNIT_STATE_LIFE) >= 1.0
end)
local filterLiving = Condition(function()
    return isPlayerHero(GetFilterUnit()) and GetUnitState(GetFilterUnit(), UNIT_STATE_LIFE) >= 2.0
end)

local function countWith(filter)
    local grp = GetUnitsInRectMatching(GetPlayableMapRect(), filter)
    local n = CountUnitsInGroup(grp)
    DestroyGroup(grp)
    return n
end

-- Condition shared by the tracking + near-defeat triggers (dying unit is a player hero).
local function dyingIsPlayerHero()
    return isPlayerHero(GetDyingUnit())
end

function RegisterHeroDeathTriggers()
    -- ── Death tracking (Hero_Flawless_Bonus, war3map.j 6382) ──
    local track = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(track, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(track, Condition(dyingIsPlayerHero))
    TriggerAddAction(track, function()
        HeroFlawlessDeath         = false
        PlayerTotalDeathsForRound = PlayerTotalDeathsForRound + 1
        PlayerTotalDeaths         = PlayerTotalDeaths + 1
    end)

    -- ── Gold Loss (war3map.j 10888) ──
    local gl = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(gl, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(gl, Condition(function()
        local d = GetDyingUnit()
        local o = GetOwningPlayer(d)
        return IsUnitType(d, UNIT_TYPE_HERO)
            and o ~= P8 and o ~= P9 and o ~= P12
            and d ~= DeathWardedTarget and d ~= WildbondPet
    end))
    TriggerAddAction(gl, function()
        local d = GetDyingUnit()
        local p = GetOwningPlayer(d)
        DisplayTextToForce(GetForceOfPlayer(p),
            GetPlayerName(p) .. " - Will revive at the beginning of the next level.")
        DisplayTextToForce(GetPlayersAll(), countWith(filterRemaining) .. " Remaining Heroes")

        local function floater(text)
            CreateTextTagUnitBJ(text, d, 0, 10, 100, 0.0, 0.0, 0)
            SetTextTagPermanentBJ(GetLastCreatedTextTag(), false)
            SetTextTagLifespanBJ(GetLastCreatedTextTag(), 5)
        end

        if p == MiserPlayer then
            floater("|cffffcc00No gold lost|r")
            return
        end
        local gold = GetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD)
        local frac, label
        if CurrentGoldDeathUpgrade == 0 then frac, label = 0.50, "-50% Gold"
        elseif CurrentGoldDeathUpgrade == 1 then frac, label = 0.25, "-25% Gold"
        else frac, label = 0.10, "-10% Gold" end
        floater("|cffff0000" .. label .. "|r")
        AdjustPlayerStateBJ(-math.floor(gold * frac), p, PLAYER_STATE_RESOURCE_GOLD)
    end)

    -- ── Near-defeat music (Hero_Death_Music, war3map.j 6124) ──
    local nd = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(nd, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddCondition(nd, Condition(dyingIsPlayerHero))
    TriggerAddAction(nd, function()
        if countWith(filterLiving) ~= 1 then return end  -- only when ONE hero remains
        -- Champion of the Fallen feat: revive Player(11)'s hero to full
        if ChampionOfTheFallenFeat then
            local g = GetUnitsInRectMatching(GetPlayableMapRect(), Condition(function()
                return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO)
                    and GetOwningPlayer(GetFilterUnit()) == Player(11)
            end))
            ForGroup(g, function()
                SetUnitLifePercentBJ(GetEnumUnit(), 100)
                CreateTextTagUnitBJ("Back from the Brink!", GetEnumUnit(), 0, 10, 0.0, 100.0, 0.0, 0)
                SetTextTagPermanentBJ(GetLastCreatedTextTag(), false)
                SetTextTagLifespanBJ(GetLastCreatedTextTag(), 5)
            end)
            DestroyGroup(g)
        end
        NearDefeatMusic = true
        StopAllMusic()
        DisplayTimedTextToForce(GetPlayersAll(), 15.0,
            "|cffff0000Only one hero remains — it's all up to you!!|r")
        TriggerSleepAction(4.0)
        StartNearDefeatMusic()
    end)

    -- ── Defeat: Princess Silmeria (objective, H02G) dies (war3map.j 29853, simplified — no cinematic yet) ──
    if unit_H02G then
        local df = CreateTrigger()
        TriggerRegisterUnitEvent(df, unit_H02G, EVENT_UNIT_DEATH)
        TriggerAddAction(df, function()
            MusicOn = false; BossMusic = false; NearDefeatMusic = false
            StopAllMusic()
            StopMusicBJ(false)
            PlaySoundBJ(snd.GameOverToD)
            PauseAllUnitsBJ(true)
            DisplayTextToForce(GetPlayersAll(),
                "|cffff0000DEFEAT — Princess Silmeria has fallen. The town is lost.|r")
            -- TODO: full defeat cinematic (Defeat_Camera/Dead_Sil cameras + Credits) — deferred
        end)
    end
end
