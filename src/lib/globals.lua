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
-- Per-player chosen hero, 1-indexed: Heroes[n] belongs to player index (n-1).
-- (Heroes[2] is the blue companion "Sir Joshua" in story/battle/solo modes —
-- the original's udg_P2Hero.)
Heroes = {}
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
FleshmakerVar           = 0      -- Megaboss 1 Fleshmaker spell-rotation selector (megaboss.lua)
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
TreasureChestLevel2     = false  -- flips to Lv2 chests (h05E) at the L10->11 loot-tier upgrade
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
-- Per-player kill counts, 1-indexed (misc.lua registerKillScoring credits the killer's owner).
Kills = {}; Score = {}; MoveCount = {}
for i = 1, 8 do Kills[i] = 0; Score[i] = 0; MoveCount[i] = 0 end
MostKills       = 0

-- Midas' Touch item system (misc.lua registerMidas; items I095 cursed / I096 blessing).
MidasTouchPlayer        = nil    -- current holder; set on pickup, reset to Player(10) on drop
MidasHero               = nil    -- the unit carrying the Midas item
MidasPurifiedAlready    = false  -- once the curse is broken (>=1500 gold) it stays blessed
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
SanctuaryChance         = 0    -- Disciple of Grace: Sanctuary freeze chance (+5/rank)
LastStand               = 0    -- Dwarven Axemaster: Last Stand rank (heal/cost tier)
ChaosChord              = 8
AssaultChance           = 5
FlameWreathDamage       = 25
TorchDamage             = 100.0
Salamando               = nil  -- Crested Drake: the active Salamando fire-elemental summon (h02E)
LavaAxeLearn            = 0     -- Dwarven Trueborn: Lava Axe rank (1-5; gates the on-attack fireball spread)
Petrify                 = 0     -- Dwarven Trueborn: Petrify rank (ally-stasis @>=2, enemy-hero freeze @>=3)
PetrifyTarget           = nil   -- Dwarven Trueborn: the unit currently being petrified
CurrentRootTrapLevel    = 0     -- Wilderness Runner: Root Trap rank (selects which root unit the trap spawns)
RootTrapUnits           = {}    -- Wilderness Runner: per-rank root-unit FourCC table (set on Root Trap learn)
CurrentForage           = 0     -- Wilderness Runner: Forage rank (1-5; selects the loot pool)
ForageItems             = {}    -- Wilderness Runner: forageable item FourCC pool (indices 0-16; set 40s in)
SurvivalistRank         = 0     -- Wilderness Runner: Survivalist rank (1-5; swaps which aura ability is granted)
Thornbush               = nil   -- Wilderness Runner: the active Birth of Thorns thornbush (h033)
SpiritBondHeal          = 35.0
LifeLinkMultiplier      = 3.0
TranscendTime           = 75.0
HavenManaRepelCost      = 15.0
MeteorStormManaDrain    = 35.0
FireFlowerManaDrain     = { 2.0, 5.0, 10.0, 15.0 }  -- Reckless Pyromancer: per-rune mana drain/5s (raised by Pyrotech 2 rank 3)
CrescendoMaxAttacks     = 29
CrescendoCurrentAttacks = 0
ElvenRebirthCooldown    = 10.0
EnergyRegenTotal        = 1
ExplosiveGrowthTotal    = 25
ExplosiveGrowth         = 0    -- Centaur Druid: Explosive Vegetation rank (plants per spot)
TotalMysticTowerAllowed = 5
EngineerMaxBuildings    = 5
-- Human Engineer tech-unlock ranks (abilities.lua / progression/Training.md)
ConstructionResearch    = 0
SchematicsResearch      = 0
MarvelResearch          = 0
EngineerPlayer          = nil
-- Earthen Templar — Earthen Presence proc state (abilities.lua)
EarthenPresence         = 0   -- current rank (0 = unlearned)
EarthenChance           = 0   -- last proc roll (1-50)
-- Rogue of the Dark — Stealth stack state (abilities.lua)
RogueDamageStacks       = 0   -- built every 2s while not attacking; discharged on attack
RogueMaxDamageStacks    = 0   -- +5 per Stealth rank
HasRogueAttacked        = false
-- Dojo training — which stat buff is active (items.lua RegisterDojoTriggers; one at a time)
DojoStrLv1Active        = false
DojoAgiLv1Active        = false
DojoIntLv1Active        = false
DojoAllLv1Active        = false
-- Wildbond — pet-kit state (abilities.lua setupWildbond)
LifeLinkTotal           = 0.0 -- HP drained from the owner per Lifelink cast (+100/rank)
LifelinkRank            = 0
EagleEyeLearn           = 0   -- Eagle Eye ranks (R00O range tech, pet twin of Far Shot)
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

-- Companion slot arrays, 1-indexed: Companion[player][slot] (player 1-8, slot 0-10).
Companion = {}
for p = 1, 8 do
    Companion[p] = {}
    for i = 0, 10 do Companion[p][i] = 0 end
end

-- Companion relationship level, 1-indexed (per player).
RelationLevel = {}
for i = 1, 8 do RelationLevel[i] = 1 end

-- Scroll / circle arrays (populated at T+16s)
Circle0Scrolls = {}; Circle1Scrolls = {}; Circle2Scrolls = {}

-- Consumable / special-item buff state (items/Items.md §4)
CoralBladeBlessingCurrent = nil   -- hero currently carrying an active Coral Blade Blessing
CoralBlessingOn           = false -- true for the 20s the blessing's mana-on-attack is live
RobeBloodInt              = false -- flags the Robe of Blood's on-cast detonation as active

-- Weather
RandomWeather       = 0
RandomWeatherEffect = {}
DenyWeather         = 0
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
AdomachUnlocked         = false  -- set true by Level 31 victory; gates the -adomach command
trg_Lv1ItemDrop         = nil    -- Lv1 kill-drop trigger handle (items.lua); Adomach suspends it
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

-- Guard post (war3map.j InitGlobals 2706/2710: melee=h04Z City Guard, ranged=n00Z City Archer).
-- Bugfix: a stray re-init reset these to 0 right after setting them, so guards spawned as null.
-- (GuardPost*Built / *Location coords now live as module-locals in buildings.lua.)
GuardPostMeleeType  = FourCC('h04Z')
GuardPostRangedType = FourCC('n00Z')

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
HiredWagesPlayer        = nil   -- Man-at-Arms owner (set when Hired Wages A026 is learned)
HiredWagesUnit          = nil   -- the Man-at-Arms hero (Battle-Exp XP floater target)
BattleEXPRank           = 0
BattleEXPPlayer         = nil
BattleEXPUnit           = nil
BattleExpBonus          = 0
Aggression              = 0
Locksmithing            = 0
SabotageOn              = false  -- Border Skirmisher: Sabotage difficulty reduction active this level
DecoysRetinue           = 0      -- Border Skirmisher: Decoy's Retinue rank
BorderSkirmisherHero    = nil    -- Border Skirmisher: caster of the last Bait and Switch
SquireCapKills          = 0
MegaBoss1Beaten         = false
DefendingSilmeria       = false
Seafaring               = {}

-- Leaver system
PlayersLeft = 0
LeaverGold  = 0

-- ── Per-class achievement flags + player handles (Achievements.md / HeroClassAchievements.md)
-- Flags are set by detection triggers (Phase 7); payouts are in BonusesAndUpkeep (levels.lua).
-- All start false / nil; detection triggers set them when milestones are hit.
ClericofOrderBonusA = false;  ClericofOrderBonusB = false;   ClericofOrderPlayer = nil
ClericOTSFBonusA    = false;  ClericOTSFBonusB    = false;   ClericOTSFPlayer    = nil
EarthenTemplarBonusA= false;  EarthenTemplarBonusB= false;   EarthenTemplarPlayer= nil
DwarvenAxeMasterBonusA= false; DwarvenAxeMasterBonusB= false; DwarvenAMPlayer    = nil
MonkEFBonusA        = false;  MonkEFBonusB        = false;   MonkEFPlayer        = nil
ManAtArmsBonusA     = false;  ManAtArmsBonusB     = false;   ManAtArmsPlayer     = nil
MasterOTABonusA     = false;  MasterOTABonusB     = false;   MasterOfTheArtPlayer= nil
FeralArchonBonus    = false;  FeralArchonBonusB   = false;   FeralArchonPlayer   = nil
HumanEngineerBonusA = false;  HumanEngineerBonusB = false;   HumanEngineerPlayer = nil
SunSoulBonusA       = false;  SunSoulBonusB       = false;   SunSoulPenalty      = false; SunSoulPlayer = nil
PaladinJusticeBonusA= false;  PaladinJusticeBonusB= false;   PaladinJusticePlayer= nil
DwarvenRFBonusA     = false;  DwarvenRFBonusB     = false;   DwarvenRFPlayer     = nil
DiscipleBonusA      = false;  DiscipleBonusB      = false;   DisciplePlayer      = nil
GraceBonusObtained  = false
ArcaneArcherBonusA  = false;  ArcaneArcherBonusB  = false;   ArcaneArcherPlayer  = nil
AxeBrotherBonusA    = false;  AxeBrotherBonusB    = false;   AxeBrotherPlayer    = nil
CentaurDruidBonusA  = false;  CentaurDruidBonusB  = false;   CentaurDruidPlayer  = nil
ClericElvenWordBonusA= false; ClericElvenWordBonusB= false;   ClericEWPlayer      = nil
CrestedDrakeBonusA  = false;  CrestedDrakeBonusB  = false;   CrestedDrakePlayer  = nil
HEBardBonusA        = false;  HEBardBonusB        = false;   BardPlayer          = nil
HarmonyRank         = 0    -- Half-Elven Bard Harmony rank (1 = ally P9 vision; 2 = also ally P8)
RogueOTDBonusA      = false;  RogueOTDBonusB      = false;   RogueOTDBonusC      = false
SharpshooterBonusB  = false;  SharpshooterPlayer  = nil
MajinPlayer         = nil  -- set when Reckless Pyromancer kills an ally with a spell
RogueOTDPlayer      = nil

-- ── Achievement detection counters (achievements.lua) ────────────────────────
-- Incremented by class ability triggers; thresholds checked in RegisterAchievementTriggers.
ClericSmallFolkHealBonusTotal  = 0   -- times OTSF healed others with A006
ClericSmallFolkSlingshotBonus  = 0   -- times OTSF used Flurry of Slingstones (A005)
LivingAxeKills                 = 0   -- kills by Living Axe (h00A/h009/h008)
FlurryCount                    = 0   -- times Monk used Flurry of Blows (A03V)
AssassinateCount               = 0   -- times Rogue cast Assassinate; incremented by spell trigger
BlastCast                      = 0   -- times MoTA cast Blast (A00K)
EssenceShockCast               = 0   -- times MoTA cast Essence Shock (A00L)
TantrumCast                    = 0   -- times Feral Archon cast Tantrum (A00X)
TotalEngyKills                 = 0   -- units killed by H00F (Engineer hero)
TotalETKills                   = 0   -- units killed by H00S (Earthen Templar)
BattleShoutCount               = 0   -- times Man-at-Arms used Battle Shout (A024)
SolarCount                     = 0   -- times Sun Soul used Solar Barrier (A02G)
SunbeamCount                   = 0   -- times Sun Soul used Sunbeam (A02F)
TotalPoJKills                  = 0   -- units killed by H01J (Paladin of Justice)
DwarvenStamina                 = 0   -- ranks of Dwarven Stamina (A037) learned
DiscipleMRCount                = 0   -- times Disciple used Moonbeam Rejuvenation (A039)
FarShotTotal                   = 0   -- ranks of Far Shot (A03J) learned
EagleArrowTotal                = 0   -- times Arcane Archer used Eagle Arrow (A03I)
WhirlwindAttack                = 0   -- times Axe Brother used Whirlwind Attack (A03M)
DecimateCount                  = 0   -- Decimate procs; incremented by Decimate proc trigger
SavageFighter                  = false  -- latched true once Axe Brother Savage Fighter fires
DecimateChance                 = 0   -- Axe Brother Decimate proc chance (+5/rank, +Fang Strike burst)
FangStrikeRank                 = 0   -- ranks of Fang Strike (A03P) learned
FangStrikeActive               = false  -- true while a Fang Strike window is open (Decimate burst variant)
AssaultMultiplier              = 0   -- Axe Brother Assault damage = KillsForAxeBrother × this (+15/rank)
KillsForAxeBrother             = 0   -- units the Axe Brother has killed (feeds Assault damage)
TotalAssaultDamage             = 0   -- last computed Assault hit (display)
TrampleDuration                = 0   -- Horizon Wanderer Trample: seconds of stomping (+2/rank)
SkillshotChance                = 0   -- Horizon Wanderer Skillshot: rolled 1-80 vs INT for the bonus slow
HewDamage                      = 0   -- Horizon Wanderer Hew: base cleave damage (+40/rank)
RecuperateMultiplier           = 0   -- Horizon Wanderer Recuperate: heal multiplier (+1/rank)
RecuperateChance               = 0   -- Horizon Wanderer Recuperate: rolled 1-80 vs INT for the bonus inner fire
TravelerTricksCurrentLevel     = 0   -- Horizon Wanderer Traveler's Tricks rank (1-3; selects the on-attack proc table)
HWStrChance                    = 0   -- Horizon Wanderer Traveler's Tricks: rolled 1-100 vs STR (cleave proc)
HWDexChance                    = 0   -- Horizon Wanderer Traveler's Tricks: rolled 1-100 vs AGI (bloodlust proc)
HWIntChance                    = 0   -- Horizon Wanderer Traveler's Tricks: rolled 1-100 vs INT (faerie fire / cripple proc)
VengefulSpiritLvl              = 0   -- Elven Cryptguard Vengeful Spirit rank → which spirit a dead hero raises
HavenIsOn                      = false  -- Elven Cryptguard Haven channel currently active
LayOnHands                     = 0   -- Paladin of Justice Lay on Hands (A02M) rank → heal divisor
CrusadeLevel                   = 0   -- Paladin of Justice Crusade (A02Q) rank → per-level stat gain
TundraStrikeRank               = 0   -- Tundra Barbarian Tundra Strike (A0BK) rank → ice-shard volley size
TotemicSpiritRank              = 0   -- Tundra Barbarian Spirit Wolf (A0BY) rank → which wolf/totem
CurrentTotemicSpirit           = nil -- the active spirit totem the summoned wolves leash to
BloodFeast                     = 0.0 -- Tundra Barbarian Blood Feast: %HP healed per kill (+4/rank)
DaggerTossDamage               = 0   -- Swashbuckler Dagger Toss (A0C7) rank → which damage tier
DerringDoChance                = 0   -- Swashbuckler Derring-Do proc chance (+10/rank)
DerringDoProc                  = 0   -- last Derring-Do roll (display)
SwashbucklerPlayer             = nil -- owner of the Swashbuckler (E015) — receives Opportunist gold
OpportunistTotalGold           = 0   -- gold the Swashbuckler collects per bonus award (+10/rank)
IllusionistPlayer              = nil -- owner of the Illusionist (H03I) — phantasm illusions transfer to them
ClericOfTheSmallFolk           = nil -- the Cleric of the Small Folk (H003) hero (set on learning Flip a Coin)
LuckEffect                     = 0   -- last Flip a Coin (A009) outcome roll (1–7)
InversionSkillRank             = 0   -- Cleric of Order Inversion (A003) rank
InversionMaxHealth             = 0.0 -- Inversion: max %HP an enemy can be drained toward the caster (25/33/50)
ReplenishLearn                 = 0   -- Cleric of Elven Word Replenish (A05D) rank → heal amount tier
SolStrike                      = nil -- Sun Soul Initiate charging Sol Strike (the casting unit)
SolStrikeAttacks               = 0   -- attacks landed since Sol Strike was cast
SolStrikeTotalAttacks          = 0   -- attacks needed to discharge Sol Strike (+1/rank)
WarGuard                       = nil -- the War Guard (H02X) hero unit (set on learning its skills)
AidAnother                     = nil -- ally currently protected by Aid Another (attackers redirected)
PerfectDefense                 = 0   -- War Guard Perfect Defense (A0AC) rank → dummy aura tier
PerfectDefenseTotalCount       = 0   -- attacks on the War Guard since the last Inner Fire / reset
RescueTarget                   = nil -- ally watched by Rescue (rescued when it drops below 20% HP)
FireballRank                   = 0   -- ranks of Fireball (A0HZ) learned — picks the missile/damage tier
FireNovaRank                   = 0   -- ranks of Fire Nova (A08O) learned — picks the ring density/missile
TotalPlantKills                = 0   -- enemy units killed by Centaur Druid treant structures
ElvenBlessingCount             = 0   -- times Cleric of Elven Word used Elven Blessing (A05C)
FlameWreathCount               = 0   -- times Crested Drake used Flame Wreath (A05F)
DrakeFangCount                 = 0   -- ranks of Drakefang (A05H) learned
SniperMarkTarget               = nil -- unit marked by Sniper's Mark; set by that ability trigger
SniperMarkKills                = 0   -- times Sharpshooter killed a Sniper's Mark target
SnipersMark                    = 0   -- gold bounty paid when a marked target dies (+20/rank)
ElvenSniper                    = nil -- the Elven Sharpshooter (H02N) hero unit
ElvenSniperPlayer              = nil -- owner of the Elven Sharpshooter
Lv5SpellBonus                  = 0   -- spells cast at P9 Knights in level 5

-- ── Exposed trigger handles (set by RegisterAchievementTriggers) ─────────────
trg_Level_1_Bonus         = nil
trg_Level_2_Bonus         = nil
trg_Level_2_Bonus_Add     = nil
trg_Level_3_Bonus         = nil
trg_Level_4_Bonus         = nil
trg_Level_5_Bonus         = nil
trg_EarthenTemplarRageOfEarth  = nil  -- call when h011 summons are created
trg_AxeBrotherSavageFighter    = nil  -- call when Decimate procs
trg_ManAtArmsPayRaise          = nil  -- call when WageTotal updates
trg_RogueApprenticeAssassin    = nil  -- disabled; enabled when Rogue class active
trg_RogueVeteranAssassin       = nil
trg_RogueMasterAssassin        = nil
