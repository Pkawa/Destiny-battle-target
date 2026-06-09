-- Game logic entry point — runs after war3map.lua's main() completes.
-- Phase 5: init, unit creation, hero selection, Level 1.

require('lib')  -- loads lib/init.lua which requires all modules

-- Initialize objects that need InitBlizzard to have run first
InitGameGlobals()

-- Create all regions and sounds
CreateAllRegions()
InitSounds()

-- Spawn the whole game world: town, hero taverns, feat shops, prince, enemies.
-- (warcraft3mapUnits.doo holds only start locations — every unit is created here.)
CreateAllUnits()

-- Register T+6s and T+10s array population timers (hero pool, tarot, locations)
RegisterHeroPoolTimers()

-- Kill the WC3 stock ambient playlist (SetMapMusic from the generated main()) so it
-- can't bleed under our custom tracks, then start the looping intro music.
SilenceAmbientMusic()
StartIntroMusic()
-- Start the per-level background-music driver. It idles (MusicOn = false) during the
-- menu and while boss music plays, and plays the level track once a wave begins.
StartLevelMusic()

-- Register hero selection triggers (mode, difficulty, pick, feats)
RegisterHeroSelectionTriggers()

-- Register feat selection triggers (feat item pickup + per-level stat bonuses)
RegisterFeatTriggers()

-- Add floating text labels so players know where to walk
local function AddModeSelectionLabels()
    local function tag(text, rect, r, g, b)
        CreateTextTagLocBJ(text, GetRectCenter(rect), 0, 11.0, r, g, b, 0)
        SetTextTagPermanentBJ(GetLastCreatedTextTag(), true)
        ShowTextTagForceBJ(true, GetLastCreatedTextTag(), GetPlayersAll())
    end
    tag("|cff00ff00Story Mode|r",      rct.StoryMode,         0.0, 100.0, 0.0)
    tag("|cffffcc00Battle Mode|r",     rct.BattleMode,        100.0, 100.0, 0.0)
    tag("|cff00ccffSolo Mode|r",       rct.SoloMode,          0.0, 100.0, 100.0)
    tag("|cffaaaaaa(1 player only)|r", rct.SoloMode,          66.0, 66.0, 66.0)
    tag("|cffaaaaaa→ Walk your wisp into a circle to choose|r",
        rct.ModeTypeSelection, 80.0, 80.0, 80.0)
end
AddModeSelectionLabels()

-- Register per-level bonus tracking triggers (halfway markers + Stalwart Defender)
RegisterLevelTriggers()

-- Disable fog of war so players can see the menus and map
FogMaskEnable(false)
FogEnable(false)

-- Spawn one wisp per human player at the mode type selection starting position,
-- pan their camera there, and select it so they immediately have control.
for i = 0, 7 do
    local p = Player(i)
    if GetPlayerController(p) == MAP_CONTROL_USER
        and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING then
        local wisp = CreateUnit(p, FourCC('ewsp'),
            GetRectCenterX(rct.ModeTypeSelection),
            GetRectCenterY(rct.ModeTypeSelection),
            bj_UNIT_FACING)
        SetCameraPositionForPlayer(p,
            GetRectCenterX(rct.ModeTypeSelection),
            GetRectCenterY(rct.ModeTypeSelection))
        if GetLocalPlayer() == p then
            ClearSelection()
            SelectUnit(wisp, true)
        end
    end
end

DisplayTimedTextToForce(GetPlayersAll(), 30.0,
    "|cffffcc00Welcome to Destiny Battle!|r Move your wisp into a Circle of Power to choose a game mode.")
