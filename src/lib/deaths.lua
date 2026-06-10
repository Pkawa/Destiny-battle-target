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

    -- ── Defeat: Princess Silmeria (H02G) dies → full cinematic (war3map.j Defeat_Silmeria 29841-29893) ──
    if unit_H02G then
        local df = CreateTrigger()
        TriggerRegisterUnitEvent(df, unit_H02G, EVENT_UNIT_DEATH)
        TriggerAddAction(df, function()
            local sil = unit_H02G
            local sx, sy = GetUnitX(sil), GetUnitY(sil)
            local BLOOD = "Objects\\Spawnmodels\\Other\\HumanBloodCinematicEffect\\HumanBloodCinematicEffect.mdl"
            local function applyCam(c, dur)
                ForForce(GetPlayersAll(), function()
                    CameraSetupApplyForPlayer(true, c, GetEnumPlayer(), dur)
                end)
            end
            -- Keep her body in place (revived, invulnerable, 30 HP) so the cinematic plays on it.
            ReviveHero(sil, sx, sy, false)
            SetUnitLifeBJ(sil, 30.0)
            SetUnitInvulnerable(sil, true)
            PauseAllUnitsBJ(true)
            MusicOn = false; BossMusic = false; NearDefeatMusic = false
            StopAllMusic()
            applyCam(cam.DefeatCamera, 0)
            TriggerSleepAction(1.0)

            AddSpecialEffectTargetUnitBJ("origin", sil, BLOOD)
            PlaySoundBJ(snd.GameOverToD)
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), sil, "Princess Silmeria", nil,
                "I.. I wasn't strong enough..", bj_TIMETYPE_SET, 3.0, true)
            TriggerSleepAction(3.0)

            AddSpecialEffectTargetUnitBJ("chest", sil, BLOOD)
            TransmissionFromUnitWithNameBJ(GetPlayersAll(), sil, "Princess Silmeria", nil,
                "Everyone... Please forgive me. I... ...I....", bj_TIMETYPE_SET, 5.0, true)
            TriggerSleepAction(3.0)

            SetUnitAnimation(sil, "death")
            AddSpecialEffectTargetUnitBJ("origin", sil, BLOOD)
            applyCam(cam.DeadSil, 0)
            TriggerSleepAction(1.0)
            applyCam(cam.DeadSilZoomOut, 8.0)

            -- Fade to black, then the closing narration (war3map.j 29877-29885).
            CinematicFilterGenericBJ(8.0, BLEND_MODE_BLEND,
                "ReplaceableTextures\\CameraMasks\\Black_mask.blp",
                100, 100, 100, 100, 0, 0, 0, 0.0)
            DisplayCineFilterBJ(true)
            TriggerSleepAction(3.0)
            DisplayTextToForce(GetPlayersAll(),
                "|cffff0000Her death marked the end for all hopes and dreams...|r")
            TriggerSleepAction(4.0)
            DisplayTextToForce(GetPlayersAll(),
                "|cffff0000Like a twisted plague, Adomach's army swept across the world. Demoralized at the loss of their beloved princess, the last remnants of Vern's resistance crumbled within the month.|r")
            TriggerSleepAction(6.0)
            DisplayTextToForce(GetPlayersAll(),
                "|cffff0000In the end, Adomach's hold of the world grew strong. Tragedy and despair was all the world would know, evermore..|r")
            TriggerSleepAction(4.0)
            -- The credits roll (gg_trg_Credits) is a separate ⬜ system; the cinematic ends here.
        end)
    end
end
