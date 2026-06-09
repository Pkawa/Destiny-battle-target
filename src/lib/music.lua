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

-- ─── Wave (gameplay) music ────────────────────────────────────────────────────
-- The original ran the WC3 stock playlist via SetMapMusic("Music",...) during normal
-- gameplay (CurrentTrackMusic was written but never read, and the map shipped no
-- distinct gameplay tracks). We reproduce that "vanilla" feel: once gameplay begins,
-- the stock playlist plays continuously, pausing only for boss / near-defeat music and
-- resuming after. (The custom Seymour Battle track read too much like boss music.)

local waveMusicRunning = false
local waveStockOn = false

-- Polls every 2s. Yields the channel to boss / near-defeat tracks, otherwise keeps the
-- vanilla WC3 gameplay playlist running.
function WaveMusicTick()
    if not waveMusicRunning then return end
    local bossActive = BossMusic or ToughBossMusic or NearDefeatMusic
    if bossActive then
        if waveStockOn then StopMusicBJ(false); waveStockOn = false end
    elseif not waveStockOn then
        SetMapMusic("Music", true, 0)   -- (re)establish + play the vanilla playlist
        waveStockOn = true
    end
    TriggerSleepAction(2.0)
    return WaveMusicTick()
end

-- Begin vanilla gameplay music. Call once when the first wave is about to start.
function BeginWaveMusic()
    if waveMusicRunning then return end
    waveMusicRunning = true
    StartMusicLoop(WaveMusicTick)
end

-- Convenience starters (set the flag + kick the loop).
function StartIntroMusic()    IntroMusicOn = true;   StartMusicLoop(IntroMusicLoop)     end
function StartBossMusic()     BossMusic = true;      StartMusicLoop(BossMusicLoop)      end
function StartToughBossMusic() ToughBossMusic = true; StartMusicLoop(ToughBossMusicLoop) end
function StartNearDefeatMusic() NearDefeatMusic = true; StartMusicLoop(NearDefeatMusicLoop) end
