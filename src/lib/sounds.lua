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

    snd.Courageous = CreateSound("war3mapImported/27 Courageous (Original Version) 1.mp3", false, false, false, 0, 0, "DefaultEAXON")
    SetSoundDuration(snd.Courageous, 10000)
    SetSoundChannel(snd.Courageous, 0)
    SetSoundVolume(snd.Courageous, 100)
    SetSoundPitch(snd.Courageous, 1.0)

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
end
