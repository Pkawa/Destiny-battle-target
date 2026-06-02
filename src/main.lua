-- Game logic entry point — runs after war3map.lua's main() completes.
-- Phase 5: init, hero selection, Level 1.

require('lib')  -- loads lib/init.lua which requires all modules

-- Initialize objects that need InitBlizzard to have run first
InitGameGlobals()

-- Create all regions and sounds
CreateAllRegions()
InitSounds()

-- Register T+6s and T+10s array population timers
RegisterHeroPoolTimers()

-- Disable built-in map music so our system controls it
StopMusicBJ(false)

-- Start intro music loop
local function PlayIntroMusicLoop()
    if not IntroMusicOn then return end
    StartSound(snd.IntroMusic)
    TriggerSleepAction(156.0)
    StopSoundBJ(snd.IntroMusic, true)
    PlayIntroMusicLoop()
end

local trgIntro = CreateTrigger()
TriggerAddAction(trgIntro, PlayIntroMusicLoop)
ConditionalTriggerExecute(trgIntro)

-- Register hero selection triggers (mode, difficulty, pick, feats)
RegisterHeroSelectionTriggers()

-- Register Level 1 bonus tracking trigger
RegisterLevel1BonusTrigger()

-- Disable fog of war for the pre-selection area so players can see the menus
FogMaskEnable(false)
FogEnable(false)

-- Spawn one wisp per human player at the mode type selection starting position
-- (gives players a unit to walk into the selection regions)
for i = 0, 7 do
    local p = Player(i)
    if GetPlayerController(p) == MAP_CONTROL_USER
        and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING then
        CreateUnit(p, FourCC('ewsp'),
            GetRectCenterX(rct.ModeTypeSelection),
            GetRectCenterY(rct.ModeTypeSelection),
            bj_UNIT_FACING)
    end
end
