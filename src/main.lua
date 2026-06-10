-- Game logic entry point — runs after war3map.lua's main() completes.
-- Phase 5: init, unit creation, hero selection, Level 1.

require('lib')  -- loads lib/init.lua which requires all modules

-- Initialize objects that need InitBlizzard to have run first
InitGameGlobals()

-- Enemy kills pay gold in EVERY mode. The original sets this in each of its 4 mode-start
-- paths (war3map.j 16856/17329/18221/18856); our port only covered 2, so some modes paid
-- no bounty (KNOWN_BUGS §12). Setting it once at startup covers all modes.
SetPlayerFlagBJ(PLAYER_STATE_GIVES_BOUNTY, true, Player(9))

-- Enemy HEROES (bosses) don't gain XP from nearby player-hero deaths. Deliberate deviation:
-- the original leaves vanilla hero-XP on for Player(9), so its bosses leveled off player
-- deaths — reported as a bug in playtesting (KNOWN_BUGS §12).
SetPlayerHandicapXP(Player(9), 0.0)

-- Create all regions, cameras and sounds
CreateAllRegions()
CreateCameras()
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
-- Vanilla gameplay music begins later, right before wave 1 (BeginningStart2 → BeginWaveMusic).

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
    -- Solo title + subtitle as one two-line tag so they don't overlap (same rect center).
    tag("|cff00ccffSolo Mode|r\n|cffaaaaaa(1 player only)|r", rct.SoloMode, 0.0, 100.0, 100.0)
    tag("|cffaaaaaa→ Walk your wisp into a circle to choose|r",
        rct.ModeTypeSelection, 80.0, 80.0, 80.0)
end
AddModeSelectionLabels()

-- Register per-level bonus tracking triggers (halfway markers + Stalwart Defender)
RegisterLevelTriggers()

-- Register class achievement detection + level challenge bonus triggers
RegisterAchievementTriggers()

-- Register the hero death loop: gold loss, death tracking, near-defeat music, defeat condition
RegisterHeroDeathTriggers()

-- Register the loot drop system (enemies drop rarity-rolled Lv1 items on death)
RegisterItemDropTriggers()

-- Register boss drops (each level boss drops 1 random gear + 1 spell scroll)
RegisterBossDropTriggers()

-- Register loot-box purchases (buy a box token from a base shop -> random pool item)
RegisterPurchaseTriggers()

-- Register the item-effect dispatch (scaling actives; registry filled per item — items/ItemEffects.md)
RegisterItemEffectTriggers()

-- Register bulk sell, item shop, and supply stocking systems (economy/Economy.md §3-6)
RegisterSellTriggers()
RegisterItemShopTriggers()
RegisterSupplyStockingTriggers()

-- Register the research-upgrade dispatch (Training XP, Princess upgrades, tower upgrades,
-- Seafaring; researched at the per-player h00Z buildings — progression/Training.md)
RegisterResearchTriggers()

-- Register circle-scroll spell learning (use scroll -> learn spell, one at a time)
RegisterScrollTriggers()

-- Register misc/flavor systems (hero level-up floaters)
RegisterMiscTriggers()

-- Register the "-camera" zoom-out command (systems/Cameras.md)
RegisterCameraTriggers()

-- Register the "-adomach" final-boss command (unlocked by Level 31 victory; bosses/Bosses.md §2)
RegisterAdomachTrigger()

-- Register per-hero class abilities (Phase 7; combat/Abilities.md) — Earthen Templar, Engineer, …
RegisterAbilityTriggers()

-- Register developer debug/cheat chat commands (gated by -debug)
RegisterDebugCommands()

-- Keep fog of war ENABLED (like the original). Reveal only the mode-selection area now
-- so the menu is navigable; the main game area is revealed at game start (RevealGameArea
-- in BeginningStart2), and distant areas (islands, boss arenas) stay fogged until their
-- encounters. (war3map.j STARTING_TRIGGER reveals Select_Mode + StoryBattle_Type_Select.)
for i = 0, 7 do
    local p = Player(i)
    if GetPlayerController(p) == MAP_CONTROL_USER
        and GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING then
        CreateFogModifierRectBJ(true, p, FOG_OF_WAR_VISIBLE, rct.ModeTypeSelection)
        CreateFogModifierRectBJ(true, p, FOG_OF_WAR_VISIBLE, rct.StoryBattleTypeSelect)
        CreateFogModifierRectBJ(true, p, FOG_OF_WAR_VISIBLE, rct.SelectMode)
    end
end

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
