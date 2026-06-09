-- Music system — ported from war3map.j 6022-6119 (Stop_All_Music, Boss/ToughBoss/
-- Near_Defeat_Music) + Intro_Music (18462-18484).
-- Requirements: systems/MusicSystem.md
--
-- Architecture: flag-gated, self-looping threads. The booleans are the API — other
-- code sets BossMusic / NearDefeatMusic / IntroMusicOn etc. then (re)starts the loop.
-- Each loop tail-calls itself (Lua TCO → no stack growth) and exits when its flag clears.
--
-- The custom tracks are SOUNDS (PlaySoundBJ); the WC3 stock ambient is the separate
-- music channel. SilenceAmbientMusic() kills the SetMapMusic("Music",...) playlist that
-- the generated main() starts, so only our tracks are ever heard.

-- Stop every custom music track immediately (war3map.j 6024-6029).
function StopAllMusic()
    StopSoundBJ(snd.ChapterBoss, true)
    StopSoundBJ(snd.BossMusic1, true)
    StopSoundBJ(snd.NearDefeatMusic, true)
    StopSoundBJ(snd.IntroMusic, true)
end

-- Kill the WC3 stock ambient playlist so it never bleeds under our tracks.
function SilenceAmbientMusic()
    ClearMapMusic()
    StopMusicBJ(false)
end

-- Run a looping music function in a context where TriggerSleepAction works.
function StartMusicLoop(fn)
    local t = CreateTrigger()
    TriggerAddAction(t, fn)
    ConditionalTriggerExecute(t)
end

-- Intro (pre-game selection) — war3map.j 18472-18476, plus an ambient kill so the
-- stock music does not play under it (the original's bug the player reported).
function IntroMusicLoop()
    if not IntroMusicOn then return end
    StopMusicBJ(false)
    PlaySoundBJ(snd.IntroMusic)
    TriggerSleepAction(156.0)
    StopSoundBJ(snd.IntroMusic, true)
    return IntroMusicLoop()
end

-- Standard boss fight — war3map.j 6050-6056. Blocked while Near Defeat is active.
function BossMusicLoop()
    if not (BossMusic and not NearDefeatMusic) then return end
    StopMusicBJ(false)
    PlaySoundBJ(snd.BossMusic1)
    TriggerSleepAction(270.0)
    StopSoundBJ(snd.BossMusic1, true)
    TriggerSleepAction(1.0)
    return BossMusicLoop()
end

-- Chapter / tough boss — war3map.j 6079-6085.
function ToughBossMusicLoop()
    if not (ToughBossMusic and not NearDefeatMusic) then return end
    StopMusicBJ(false)
    PlaySoundBJ(snd.ChapterBoss)
    TriggerSleepAction(310.0)
    StopSoundBJ(snd.ChapterBoss, true)
    TriggerSleepAction(4.0)
    return ToughBossMusicLoop()
end

-- Near defeat (highest priority — last hero alive) — war3map.j 6105-6111.
function NearDefeatMusicLoop()
    if not NearDefeatMusic then return end
    StopMusicBJ(false)
    PlaySoundBJ(snd.NearDefeatMusic)
    TriggerSleepAction(290.0)
    StopSoundBJ(snd.NearDefeatMusic, true)
    TriggerSleepAction(3.0)
    return NearDefeatMusicLoop()
end

-- ─── Per-level background music ───────────────────────────────────────────────
-- Drives gameplay music from CurrentTrackMusic (set 1/2/3 by each level). The
-- original wrote this global but never read it and shipped only one full-length
-- gameplay track, so all three map to it here. To add variety later, just point
-- the track numbers at different sounds in trackSound() below.

local levelMusicRunning = false
local curTrack = 0    -- track number currently playing (0 = none)
local secsLeft = 0    -- seconds until the current track ends and must re-loop

-- track number -> (sound, durationSeconds). Add cases as more tracks are imported.
local function trackSound(n)
    if n == 1 or n == 2 or n == 3 then
        return snd.SeymourBattle, 113.0
    end
    return nil, 0
end

-- Polls every 2s. Plays the desired track, loops it when it ends, and goes silent
-- whenever music is off or a boss / near-defeat track owns the channel.
function LevelMusicTick()
    if not levelMusicRunning then return end
    local blocked = (not MusicOn) or BossMusic or ToughBossMusic or NearDefeatMusic
    local desired = blocked and 0 or CurrentTrackMusic
    if desired ~= curTrack or (desired ~= 0 and secsLeft <= 0) then
        local oldS = trackSound(curTrack)
        if oldS then StopSoundBJ(oldS, true) end
        local newS, dur = trackSound(desired)
        curTrack = desired
        if newS then
            StopMusicBJ(false)
            PlaySoundBJ(newS)
            secsLeft = dur
        else
            curTrack = 0
        end
    end
    TriggerSleepAction(2.0)
    secsLeft = secsLeft - 2.0
    return LevelMusicTick()
end

function StartLevelMusic()
    if levelMusicRunning then return end
    levelMusicRunning = true
    StartMusicLoop(LevelMusicTick)
end

-- Immediately silence the level track (used on victory before the win sting).
function StopLevelMusic()
    local s = trackSound(curTrack)
    if s then StopSoundBJ(s, true) end
    curTrack  = 0
    secsLeft  = 0
end

-- Convenience starters (set the flag + kick the loop).
function StartIntroMusic()    IntroMusicOn = true;   StartMusicLoop(IntroMusicLoop)     end
function StartBossMusic()     BossMusic = true;      StartMusicLoop(BossMusicLoop)      end
function StartToughBossMusic() ToughBossMusic = true; StartMusicLoop(ToughBossMusicLoop) end
function StartNearDefeatMusic() NearDefeatMusic = true; StartMusicLoop(NearDefeatMusicLoop) end
