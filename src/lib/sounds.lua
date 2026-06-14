-- Sound handles — ported from InitSounds(), war3map.j lines 3192-4327
-- Only key sounds needed for Phase 5 MVP are created here.
-- Full set will be added as more systems are ported.
-- Naming: gg_snd_IntroMusic -> snd.IntroMusic

snd = {}

function InitSounds()
    -- Imported music tracks (Phase 5 core)
    snd.IntroMusic = CreateSound("war3mapImported/IntroMusic.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.IntroMusic, 154984)
    SetSoundChannel(snd.IntroMusic, 0)
    SetSoundVolume(snd.IntroMusic, 127)
    SetSoundPitch(snd.IntroMusic, 1.0)

    snd.BossMusic1 = CreateSound("war3mapImported/BossMusic1.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.BossMusic1, 270000)
    SetSoundChannel(snd.BossMusic1, 0)
    SetSoundVolume(snd.BossMusic1, 127)
    SetSoundPitch(snd.BossMusic1, 1.0)

    snd.ChapterBoss = CreateSound("war3mapImported/ChapterBoss.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.ChapterBoss, 310000)
    SetSoundChannel(snd.ChapterBoss, 0)
    SetSoundVolume(snd.ChapterBoss, 127)
    SetSoundPitch(snd.ChapterBoss, 1.0)

    snd.NearDefeatMusic = CreateSound("war3mapImported/NearDefeatMusic.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.NearDefeatMusic, 290000)
    SetSoundChannel(snd.NearDefeatMusic, 0)
    SetSoundVolume(snd.NearDefeatMusic, 127)
    SetSoundPitch(snd.NearDefeatMusic, 1.0)

    snd.GameOverToD = CreateSound("war3mapImported/GameOverToD.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.GameOverToD, 15000)
    SetSoundChannel(snd.GameOverToD, 0)
    SetSoundVolume(snd.GameOverToD, 127)
    SetSoundPitch(snd.GameOverToD, 1.0)

    snd.LevelUpSmall = CreateSound("war3mapImported/LevelUpSmall.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.LevelUpSmall, 3000)
    SetSoundChannel(snd.LevelUpSmall, 0)
    SetSoundVolume(snd.LevelUpSmall, 127)
    SetSoundPitch(snd.LevelUpSmall, 1.0)

    snd.RoundClear = CreateSound("war3mapImported/06 Round Clear.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.RoundClear, 5000)
    SetSoundChannel(snd.RoundClear, 0)
    SetSoundVolume(snd.RoundClear, 127)
    SetSoundPitch(snd.RoundClear, 1.0)

    -- Dark One "exposed" cue (Megaboss 1, megaboss.lua)
    snd.FacelessOneWhat1 = CreateSound("Units\\Creeps\\FacelessOne\\FacelessOneWhat1.wav", false, false, false, 10, 10, "DefaultEAXON")
    SetSoundDuration(snd.FacelessOneWhat1, 1500)
    SetSoundChannel(snd.FacelessOneWhat1, 0)
    SetSoundVolume(snd.FacelessOneWhat1, 100)
    SetSoundPitch(snd.FacelessOneWhat1, 1.0)

    snd.BotWFoundSFX = CreateSound("war3mapImported/BotW Found SFX.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.BotWFoundSFX, 3000)
    SetSoundChannel(snd.BotWFoundSFX, 0)
    SetSoundVolume(snd.BotWFoundSFX, 127)
    SetSoundPitch(snd.BotWFoundSFX, 1.0)

    snd.EpicEventSound = CreateSound("war3mapImported/EpicEventSound.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.EpicEventSound, 3000)
    SetSoundChannel(snd.EpicEventSound, 0)
    SetSoundVolume(snd.EpicEventSound, 127)
    SetSoundPitch(snd.EpicEventSound, 1.0)

    -- Gameplay background track (the only full-length non-boss track in the map) — war3map.j 3717
    snd.SeymourBattle = CreateSound("war3mapImported/85 - Seymour Battle_chunk_1 (2).mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.SeymourBattle, 113266)
    SetSoundChannel(snd.SeymourBattle, 0)
    SetSoundVolume(snd.SeymourBattle, 110)
    SetSoundPitch(snd.SeymourBattle, 1.0)

    snd.Courageous = CreateSound("war3mapImported/27 Courageous (Original Version) 1.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.Courageous, 10000)
    SetSoundChannel(snd.Courageous, 0)
    SetSoundVolume(snd.Courageous, 100)
    SetSoundPitch(snd.Courageous, 1.0)

    -- "Town under attack" horn (enemy reaches the base) — war3map.j 3240
    snd.HordeSound2 = CreateSound("war3mapImported/HordeSound2.wav", false, false, false, 10, 10, "DefaultEAXON")
    SetSoundDuration(snd.HordeSound2, 1208)
    SetSoundChannel(snd.HordeSound2, 0)
    SetSoundVolume(snd.HordeSound2, 127)
    SetSoundPitch(snd.HordeSound2, 1.0)

    -- Engine sounds used in UI / effects
    snd.CreepAggroWhat1 = CreateSound("Sound\\Creep\\CreepAggroWhat1.wav", false, false, false, 10, 10, "SpellsEAX")
    SetSoundDuration(snd.CreepAggroWhat1, 1000)
    SetSoundChannel(snd.CreepAggroWhat1, 0)
    SetSoundVolume(snd.CreepAggroWhat1, 80)
    SetSoundPitch(snd.CreepAggroWhat1, 1.0)

    snd.ResurrectTarget = CreateSound("Sound\\Interface\\ResurrectTarget.wav", false, false, false, 10, 10, "SpellsEAX")
    SetSoundDuration(snd.ResurrectTarget, 1000)
    SetSoundChannel(snd.ResurrectTarget, 0)
    SetSoundVolume(snd.ResurrectTarget, 80)
    SetSoundPitch(snd.ResurrectTarget, 1.0)

    snd.AllianceSound = CreateSound("war3mapImported/AllianceSound.wav", false, false, false, 10, 10, "DefaultEAXON")
    SetSoundDuration(snd.AllianceSound, 3000)
    SetSoundChannel(snd.AllianceSound, 0)
    SetSoundVolume(snd.AllianceSound, 100)
    SetSoundPitch(snd.AllianceSound, 1.0)

    snd.SlowRezzSound = CreateSound("Sound\\Interface\\SlowRezzSound.wav", false, false, false, 10, 10, "SpellsEAX")
    SetSoundDuration(snd.SlowRezzSound, 2000)
    SetSoundChannel(snd.SlowRezzSound, 0)
    SetSoundVolume(snd.SlowRezzSound, 80)
    SetSoundPitch(snd.SlowRezzSound, 1.0)

    snd.GameFound = CreateSound("Sound\\Interface\\GameFound.wav", false, false, false, 10, 10, "SpellsEAX")
    SetSoundDuration(snd.GameFound, 1000)
    SetSoundChannel(snd.GameFound, 0)
    SetSoundVolume(snd.GameFound, 80)
    SetSoundPitch(snd.GameFound, 1.0)

    snd.ReceiveGold = CreateSound("Sound\\Interface\\ReceiveGold.wav", false, false, false, 10, 10, "SpellsEAX")
    SetSoundDuration(snd.ReceiveGold, 1000)
    SetSoundChannel(snd.ReceiveGold, 0)
    SetSoundVolume(snd.ReceiveGold, 80)
    SetSoundPitch(snd.ReceiveGold, 1.0)

    snd.DivineShield = CreateSound("Sound\\Spells\\DivineShield.wav", false, false, false, 10, 10, "SpellsEAX")
    SetSoundDuration(snd.DivineShield, 2000)
    SetSoundChannel(snd.DivineShield, 0)
    SetSoundVolume(snd.DivineShield, 80)
    SetSoundPitch(snd.DivineShield, 1.0)

    snd.QuestLog = CreateSound("Sound\\Interface\\QuestLog.wav", false, false, false, 10, 10, "SpellsEAX")
    SetSoundDuration(snd.QuestLog, 1000)
    SetSoundChannel(snd.QuestLog, 0)
    SetSoundVolume(snd.QuestLog, 80)
    SetSoundPitch(snd.QuestLog, 1.0)

    -- Hero death cry sounds (war3map.j 3354-3363, 3597-3605, 3226-3230)
    -- gg_snd_13___sound_1 — male death cry (imported MP3)
    snd.s13 = CreateSound("war3mapImported\\13_-_sound_1.mp3", false, false, true, 10, 10, "DefaultEAXON")
    SetSoundDuration(snd.s13, 6480)
    SetSoundChannel(snd.s13, 0)
    SetSoundVolume(snd.s13, 127)
    SetSoundPitch(snd.s13, 1.0)

    -- gg_snd_14___sound_2 — female death cry (imported MP3)
    snd.s14 = CreateSound("war3mapImported\\14_-_sound_2.mp3", false, false, true, 10, 10, "DefaultEAXON")
    SetSoundDuration(snd.s14, 6480)
    SetSoundChannel(snd.s14, 0)
    SetSoundVolume(snd.s14, 127)
    SetSoundPitch(snd.s14, 1.0)

    -- gg_snd_DragonWhat1 — Crested Drake death cry (3D engine sound)
    snd.DragonWhat1 = CreateSound("Units\\Creeps\\AzureDragon\\DragonWhat1.wav", false, true, true, 10, 10, "DefaultEAXON")
    SetSoundDuration(snd.DragonWhat1, 1014)
    SetSoundChannel(snd.DragonWhat1, 0)
    SetSoundVolume(snd.DragonWhat1, 100)
    SetSoundPitch(snd.DragonWhat1, 0.7)

    -- gg_snd_PeasantYesAttack4 — extra line for Human Engineer cry 1
    snd.PeasantYesAttack4 = CreateSound("Units\\Human\\Peasant\\PeasantYesAttack4.wav", false, false, true, 10, 10, "DefaultEAXON")
    SetSoundDuration(snd.PeasantYesAttack4, 2328)
    SetSoundChannel(snd.PeasantYesAttack4, 0)
    SetSoundVolume(snd.PeasantYesAttack4, 100)
    SetSoundPitch(snd.PeasantYesAttack4, 1.0)

    -- Underwater ambience for the Coral Cave dive network (war3map.j 3678-3694).
    snd.WaterLakeLoop1 = CreateSound("Sound\\Ambient\\DoodadEffects\\WaterLakeLoop1.flac", true, true, true, 0, 0, "DoodadsEAX")
    SetSoundParamsFromLabel(snd.WaterLakeLoop1, "LakeLoop")
    SetSoundDuration(snd.WaterLakeLoop1, 3297)
    SetSoundVolume(snd.WaterLakeLoop1, 120)
    snd.WaterStreamLoop1 = CreateSound("Sound\\Ambient\\DoodadEffects\\WaterStreamLoop1.flac", true, true, true, 0, 0, "DoodadsEAX")
    SetSoundParamsFromLabel(snd.WaterStreamLoop1, "StreamLoop")
    SetSoundDuration(snd.WaterStreamLoop1, 2008)
    SetSoundVolume(snd.WaterStreamLoop1, 70)
    SetSoundPitch(snd.WaterStreamLoop1, 0.9)
    snd.WaterWavesLoop1 = CreateSound("Sound\\Ambient\\DoodadEffects\\WaterWavesLoop1.flac", true, true, true, 1, 1, "DoodadsEAX")
    SetSoundParamsFromLabel(snd.WaterWavesLoop1, "WavesLoop")
    SetSoundDuration(snd.WaterWavesLoop1, 7445)
    SetSoundVolume(snd.WaterWavesLoop1, 120)
    snd.WaterWaterFallLoop1 = CreateSound("Sound\\Ambient\\DoodadEffects\\WaterWaterFallLoop1.flac", true, true, true, 0, 0, "DoodadsEAX")
    SetSoundParamsFromLabel(snd.WaterWaterFallLoop1, "WaterfallLoop")
    SetSoundDuration(snd.WaterWaterFallLoop1, 16718)
    SetSoundVolume(snd.WaterWaterFallLoop1, 120)

    -- Thunder for the storm (storm.lua). T1-3.wav imported from the Storm v1.3.1 system
    -- (war3mapImported, listed in war3map.imp). 2D (global) sounds. WC3 caps per-sound volume at
    -- 127 (already max), so to make the growl LOUDER we create several handles per clip and start
    -- them together — the stacked copies sum to a louder result. snd.Thunder[clip] = {handles…}.
    local STACK = 3   -- copies played at once ≈ ~2x perceived loudness (bump for louder)
    snd.Thunder = {}
    for i = 1, 3 do
        snd.Thunder[i] = {}
        for j = 1, STACK do
            local s = CreateSound("war3mapImported/T" .. i .. ".wav", false, false, false, 0, 0, "DefaultEAXON")
            SetSoundVolume(s, 127)
            snd.Thunder[i][j] = s
        end
    end
end
