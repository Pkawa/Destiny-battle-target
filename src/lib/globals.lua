-- Game state globals (ported from udg_* InitGlobals, war3map.j lines 2141-2741)
-- Naming: udg_CurrentLevel -> CurrentLevel, no prefixes per CLAUDE.md conventions

-- Game flow
CurrentLevel        = 1
GameStarted         = false
Testing             = 0
WatchMovie          = true

-- Mode selection
StoryMode           = false
SoloMode            = false
RandomMode          = true
SelectedMode        = false
PickModeDone        = false
PickModeStillGoing  = true

-- Difficulty
Difficulty          = ""
DifficultyModifier  = 0
LevelDiffModifier   = 0
StartingPotions     = false

-- Hero state
TotalHeroes         = 32
HeroSelected        = 0
P1Hero = nil; P2Hero = nil; P3Hero = nil; P4Hero = nil
P5Hero = nil; P6Hero = nil; P7Hero = nil; P8Hero = nil
CurrentIntroLocInt  = 0

HeroTaken       = {}
DuplicateHero   = {}
HeroText        = {}
HeroPicked      = {}
TarotCards      = {}
for i = 0, 200 do HeroTaken[i] = 0 end
for i = 0, 200 do DuplicateHero[i] = 0 end
for i = 0, 100 do HeroText[i] = "" end

-- Intro locations (set by Locations trigger at T+10s)
CurrentHeroIntroLoc = {}
for i = 0, 8 do CurrentHeroIntroLoc[i] = nil end
EnemyStartLoc = {}

-- Music
MusicOn         = false
IntroMusicOn    = true
BossMusic       = false
FastBossMusic   = false
ToughBossMusic  = false
NearDefeatMusic = false
FinalBossMusicOn = false
BaseAttackMusic = false
CurrentTrackMusic = 0

-- Level flags
LevelBeaten             = false
Level13Beaten           = false
Level18Beaten           = false
Level21Beaten           = false
MegaBoss1Beaten         = false
DarkOneBeaten           = false
DarkOneWeakened         = false
LevelBonus              = 0
LevelBonuses            = {}
for i = 0, 30 do LevelBonuses[i] = false end

-- Achievement flags (reset each level by Bonus_Reset)
HeroFlawlessDeath       = true
StalwartDefender        = true
BlazingVictory          = true
SpeedyVictory           = true
HeroAssassination       = false
PlayerTotalDeathsForRound = 0
PlayerTotalDeaths       = 0
HeroesDeadThisRound     = 0
AllPrisonersAlive       = false
CloseCall               = false
DeathWardedTarget       = nil    -- hero protected from Gold Loss by Death Ward (set by that ability)
ChampionOfTheFallenFeat = false  -- feat: revive Player(11) hero to full at near-defeat
MeteorlogistFeatOn      = false  -- feat: 50% chance to deny bad weather (weather system not yet ported)

-- Economy
CurrentGoldDeathUpgrade = 0
ItemCleanUpOn           = false
ItemSHopUpgrade         = 0
TotalBonusGold          = 0
ActivePlayers           = 0
UncSellOff              = 0
RareSellOff             = 0
EpicArtiSellOff         = 0
OtherSellOff            = 0

-- Item drop system
CurrentItemLevelDrops   = 1
RandomItemChance        = 0
ItemDrop                = 0
ItemDropTotal           = 50
ArtificierFeatOn        = false  -- Artificier class: shifts loot rarity odds by +1 (class not yet ported)
TotalScrollDrop         = 200
ScrollDrop              = 0
ScrollNumDrop           = 0
ItemDropUnitPoint       = nil
Lv1Uncommon = {}; Lv1Rare = {}; Lv1Epic = {}; Lv1Artifact = {}
Lv2Uncommon = {}; Lv2Rare = {}; Lv2Epic = {}; Lv2Artifact = {}
Lv1RareSetItem = {}; Lv1EpicSetItem = {}
Lv2RareSetItem = {}; Lv2EpicSetItem = {}
Lv1TotalUncommons = 9;  Lv1TotalRares = 9;  Lv1TotalEpics = 9
Lv1TotalArtifacts = 9;  Lv1TotalRareSetItems = 11; Lv1TotalEpicSetItems = 5
Lv2TotalUncommons = 30; Lv2TotalRares = 30; Lv2TotalEpics = 30
Lv2TotalArtifacts = 30; Lv2TotalRareSetItems = 8;  Lv2TotalEpicSetItems = 5
CursedItemOn            = true
CursedItemDrop          = 0
CursedItemBonus         = 0
CursedKillDropCounter   = 0
AuctioneerLevel         = 1
TreasureChestDrop       = 0
BossDrop                = 0
BossSpellDrop           = 0
RareMob                 = 0
Lv1CursedItemDrop       = {}

-- Garrison system (A-J)
GarrisonAOccupied = false; GarrisonBOccupied = false; GarrisonCOccupied = false
GarrisonDOccupied = false; GarrisonEOccupied = false; GarrisonFOccupied = false
GarrisonGOccupied = false; GarrisonHOccupied = false; GarrisonIOccupied = false
GarrisonJOccupied = false
UnitInGarrisonA = nil; UnitInGarrisonB = nil; UnitInGarrisonC = nil
UnitInGarrisonD = nil; UnitInGarrisonE = nil; UnitInGarrisonF = nil
UnitInGarrisonG = nil; UnitInGarrisonH = nil; UnitInGarrisonI = nil
UnitInGarrisonJ = nil

-- Unique class restrictions
Only1Engineer   = true
Only1ManAtArms  = true
Only1Paladin    = true
Only1Solar      = true

-- Player kill/score tracking
P1Kills = 0; P2Kills = 0; P3Kills = 0; P4Kills = 0
P5Kills = 0; P6Kills = 0; P7Kills = 0; P8Kills = 0
P1Score = 0; P2Score = 0; P3Score = 0; P4Score = 0
P5Score = 0; P6Score = 0; P7Score = 0; P8Score = 0
P1MoveCount = 0; P2MoveCount = 0; P3MoveCount = 0; P4MoveCount = 0
P5MoveCount = 0; P6MoveCount = 0; P7MoveCount = 0; P8MoveCount = 0
MostKills       = 0
TotalBonusGold  = 0
HighestLevel    = 0
TotalPlaying    = 0

-- Player connections
FirstToDing         = nil
FirstToDingOn       = false
bonusFirstToBuildOn = false
bonusFirstToResearchOn = false
FirstToBuild        = nil
FirstToResearch     = nil

-- Teams / wave tracking
TotalTeams              = 7
TotalTeamsLeft          = 5
TeamsLeft               = 0
TotalTeamMetDefeatLevel = {}
for i = 0, 100 do TotalTeamMetDefeatLevel[i] = 0 end
TotalTeamsLeftPercent   = 0
TotalTeamsPercentInt    = 0

-- Version
CurrentVersion  = "v0.21i"
Difficulty      = ""
LevelDiffModifier = 0

-- Misc ability values (non-zero at init)
TotalCharmAtOnce        = 2
DeathWardDuration       = 5
ChaosChord              = 8
AssaultChance           = 5
FlameWreathDamage       = 25
TorchDamage             = 100.0
SpiritBondHeal          = 35.0
LifeLinkMultiplier      = 3.0
TranscendTime           = 75.0
HavenManaRepelCost      = 15.0
MeteorStormManaDrain    = 35.0
CrescendoMaxAttacks     = 29
CrescendoCurrentAttacks = 0
ElvenRebirthCooldown    = 10.0
EnergyRegenTotal        = 1
ExplosiveGrowthTotal    = 25
TotalMysticTowerAllowed = 5
EngineerMaxBuildings    = 5
CentaurTreantTotal      = 2
AidAnotherTimer         = 5.0
SofUnityLowestLevel     = 100
WildbondPetSize         = 100.0
SharpshooterBonusA      = true

-- Force / group objects (created at init — need InitBlizzard to run first)
function InitGameGlobals()
    CurrentPlayerMSG    = CreateForce()
    DeathMSG            = CreateForce()
    FearGroup           = CreateGroup()
    TutorialGroup       = CreateForce()
    Leavers             = CreateForce()
    IntimShoutGroup     = CreateGroup()
    AdomachParalyzeRayGroup = CreateGroup()
    UnderwaterGroup     = CreateGroup()
    PickFeatTimer       = CreateTimer()
    BlazingVictoryTimer = CreateTimer()
    SpeedyVictoryTimer  = CreateTimer()
    TimerNextLevel      = CreateTimer()
    NextLevelTimerWindow = nil
end

-- Companion arrays
P1Companion = {}; P2Companion = {}; P3Companion = {}; P4Companion = {}
P5Companion = {}; P6Companion = {}; P7Companion = {}; P8Companion = {}
for i = 0, 10 do
    P1Companion[i] = 0; P2Companion[i] = 0; P3Companion[i] = 0; P4Companion[i] = 0
    P5Companion[i] = 0; P6Companion[i] = 0; P7Companion[i] = 0; P8Companion[i] = 0
end

-- Companion relationship levels
P1RelationLevel = 1
P2RelationLevel = 1
P3RelationLeve  = 1  -- note: typo preserved from original

-- Scroll / circle arrays (populated at T+16s)
Circle0Scrolls = {}; Circle1Scrolls = {}; Circle2Scrolls = {}

-- Weather
RandomWeather       = 0
RandomWeatherEffect = {}
WeatherName         = {}
for i = 0, 50 do WeatherName[i] = "" end

-- Dialogue prelude (vestigial — never actually populated in original)
DialoguePrelude = {}
for i = 0, 50 do DialoguePrelude[i] = "" end

-- Wildbond companion
Wildbond        = nil
WildbondPet     = nil
WildbondPlayer  = nil
WildbondPetTable = {}
WildbondRandomNum = 0
BeastTrainingRank = 0

-- Adomach boss
AdomachHimself          = nil
AdomachBlinkTarget      = 0
AdomachCurrentLocation  = 0
AdomachSpellList        = 0
AdomachOkToBlink        = true
AdomachSummon           = 0
FinalBossMusicOn        = false

-- Bard songs
TotalSongs          = 0
SongsBeingSung      = 0
BardicRepertoirRank = 0
HealingSongOn       = false; OdeToWarOn = false; SymphonyOfSearingOn = false
MovementMarchOn     = false; HymnofFrostOn = false; SongOfManaOn = false
SymphonyOfStormsOn  = false; TangoTenacityOn = false; SkullochSongOn = false
WhispersWindOn      = false
HealingSongRanks  = {}; TangoTenacityRanks = {}; OdeToWarRanks = {}
SymphonyOfFlameRanks = {}; MovementMarchRanks = {}; SymphonyOfStormRanks = {}
SongOfManaRanks   = {}; HymnOfFrostRanks = {}

-- Guard post
GuardPostMeleeType  = FourCC('h04Z')
GuardPostRangedType = FourCC('n00Z')
GuardPostABuilt = false; GuardPostBBuilt = false; GuardPostCBuilt = false
GuardPostLocationA = nil; GuardPostLocationB = nil; GuardPostLocationC = nil
GuardPostMeleeType = 0; GuardPostRangedType = 0

-- Miscellaneous
HeroWithBlackweave      = nil
AntiDuplicateTxt        = false
FeatSelectionDone       = false
SeafaringLv1            = false
GnasherDead             = false
DieHardActivated        = false
GameStarted             = false
MajinPenalty            = false
FireFlowerManaCounter   = 0
PlantHater              = false
GoblinSlayer            = false
WageTotal               = 0
HiredWages              = 0
BattleEXPRank           = 0
Aggression              = 0
Locksmithing            = 0
SabotageOn              = false
SquireCapKills          = 0
MegaBoss1Beaten         = false
DefendingSilmeria       = false
Seafaring               = {}

-- Leaver system
PlayersLeft = 0
LeaverGold  = 0
