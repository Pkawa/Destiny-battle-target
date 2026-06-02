-- All rect handles — direct port of CreateRegions(), war3map.j lines 4328-4623
-- Naming: gg_rct_Starting_Player_Area -> rct.StartingPlayerArea (camelCase, no prefix)
-- rct is a global table; individual rects also aliased at top level for convenience.

rct = {}

function CreateAllRegions()
    -- Core gameplay areas
    rct.EntireGameArea          = Rect(-11648, -6848, 7328, 15584)
    rct.StartingPlayerArea      = Rect(-5856, -3104, -5408, -2752)
    rct.SpawnA                  = Rect(-1888, 14432, -1120, 15072)
    rct.SpawnB                  = Rect(5312, 13824, 6208, 14720)
    rct.SpawnC                  = Rect(5760, 3200, 6336, 4000)
    rct.EnemyArea               = Rect(5248, 13760, 6464, 15104)
    rct.AlliedFlee              = Rect(-2592, 9312, -2400, 9568)
    rct.AlliedFlee2             = Rect(2112, 5056, 2720, 5376)
    rct.AlliedFlee3             = Rect(3328, 2048, 3680, 2400)
    rct.AreaToDefend            = Rect(-5856, -5824, -2016, -448)
    rct.ResearchArea            = Rect(2688, -2912, 2976, -2496)

    -- Forest overrun zones
    rct.ForestOverRunA          = Rect(-5216, 3424, -5056, 3584)
    rct.ForestOverrunB          = Rect(-4032, 3520, -3872, 3712)
    rct.ForestOverrunC          = Rect(-5120, 4320, -4928, 4544)
    rct.ForestOverrunD          = Rect(-3776, 4448, -3584, 4672)
    rct.ForestOverrunE          = Rect(-3040, 4544, -2848, 4768)
    rct.ForestOverrunF          = Rect(-2304, 5376, -2144, 5568)
    rct.ForestOverrunG          = Rect(-5248, 5408, -5056, 5600)
    rct.ForestOverrunH          = Rect(-4768, 6688, -4480, 6912)
    rct.ForestOverrunI          = Rect(-3744, 6688, -3520, 6976)
    rct.ForestOverrunJ          = Rect(-4160, 5472, -3936, 5696)
    rct.ForestOverrunK          = Rect(-4512, 4864, -4320, 5056)
    rct.ForestOverrunL          = Rect(-3072, 5312, -2848, 5600)
    rct.ForestOverrunM          = Rect(-4704, 4192, -4416, 4448)
    rct.AngryEnt                = Rect(-4224, 6240, -3968, 6464)

    -- Caravan / misc world
    rct.CaravanPathA            = Rect(1408, 672, 1632, 864)
    rct.CaravanPathB            = Rect(1856, 5920, 2112, 6144)
    rct.Hermit                  = Rect(1888, 6368, 2016, 6496)
    rct.HermitTent              = Rect(2048, 6368, 2208, 6592)
    rct.DestructibleTrapA       = Rect(256, 1056, 736, 1600)
    rct.DestructibleTrapB       = Rect(1760, -832, 2272, -416)
    rct.DestructibleTrapC       = Rect(992, 5152, 1440, 5728)
    rct.AltarOfTides            = Rect(3392, -704, 3648, -480)
    rct.CaravanPathC            = Rect(3264, -480, 3424, -288)
    rct.DestructibleTrapD       = Rect(1952, 3136, 2368, 3584)
    rct.CaravanPathB2           = Rect(1184, 3264, 1408, 3488)
    rct.Lvl14BossSpawn          = Rect(4672, -736, 4928, -448)

    -- Player intro positions
    rct.P1Intro                 = Rect(-4288, -2048, -4064, -1920)
    rct.P2Intro                 = Rect(-4288, -2208, -4064, -2112)
    rct.P3Intro                 = Rect(-4288, -2336, -4096, -2272)
    rct.P4Intro                 = Rect(-4288, -2464, -4192, -2368)
    rct.P5Intro                 = Rect(-4288, -2720, -4192, -2624)  -- note: typo "P5Into" in original
    rct.P6Intro                 = Rect(-4160, -2720, -4032, -2624)
    rct.P7Intro                 = Rect(-4160, -2592, -4032, -2496)
    rct.P8Intro                 = Rect(-4288, -2592, -4192, -2496)

    -- Garrison locations
    rct.GarrisonLocationA       = Rect(-4832, -1920, -4736, -1824)
    rct.GarrisonLocationB       = Rect(-4480, -1920, -4384, -1824)
    rct.GarrisonLocationC       = Rect(-3552, -2944, -3456, -2848)
    rct.GarrisonLocationD       = Rect(-3552, -3264, -3456, -3168)
    rct.GarrisonLocationE       = Rect(-4992, -768, -4896, -672)
    rct.GarrisonLocationF       = Rect(-4608, -768, -4512, -672)
    rct.GarrisonLocationG       = Rect(-3040, -768, -2944, -672)
    rct.GarrisonLocationH       = Rect(-2688, -768, -2592, -672)
    rct.GarrisonLocationI       = Rect(-2368, -896, -2272, -800)
    rct.GarrisonLocationJ       = Rect(-2400, -1632, -2304, -1536)
    rct.GarrisonLocationK       = Rect(-5696, -992, -5600, -896)
    rct.GarrisonLocationL       = Rect(-5664, -1344, -5536, -1248)
    rct.GarrisonArcherA         = Rect(-3968, -512, -3872, -384)
    rct.GarrisonArcherB         = Rect(-3968, -96, -3872, 32)
    rct.GarrisonArcherC         = Rect(-3456, -128, -3360, 0)
    rct.GarrisonArcherD         = Rect(-3424, -512, -3328, -384)
    rct.GarrisonArcherE         = Rect(-5408, -1440, -5280, -1312)
    rct.GarrisonArcherF         = Rect(-5184, -1024, -5056, -896)
    rct.GarrisonArcherG         = Rect(-2528, -992, -2400, -864)
    rct.GarrisonArcherH         = Rect(-2592, -1664, -2464, -1536)

    -- Level 21 areas
    rct.Level21A                = Rect(-9184, -448, -8544, 32)
    rct.Level21B                = Rect(-7072, 4352, -6208, 4736)
    rct.Level21C                = Rect(-7872, 9696, -7200, 10336)
    rct.Level21D                = Rect(-2784, 2592, -2272, 3168)
    rct.Level21E                = Rect(-864, 8000, -192, 8672)
    rct.Level21F                = Rect(-1152, 3008, -512, 3744)
    rct.Level21G                = Rect(2816, -704, 3264, 32)
    rct.Level21H                = Rect(3776, 3712, 4384, 4416)

    -- Castle / fortress
    rct.EntranceToFortress      = Rect(-6336, -3808, -6080, -3584)
    rct.ExitToFortress          = Rect(3328, -4928, 4448, -4800)
    rct.CastleEntranceDest      = Rect(3648, -5792, 4160, -5376)
    rct.EntireCastleArea        = Rect(1952, -10752, 5792, -4512)
    rct.PrinceArea              = Rect(3680, -10304, 4000, -10144)
    rct.FrontOfSilmeria         = Rect(3552, -10208, 4128, -10016)

    -- Feat selection
    rct.FeatArea                = Rect(12512, 13952, 13280, 14496)
    rct.EntireFeatArea          = Rect(12128, 12992, 14016, 14848)
    rct.TeamFeats               = Rect(12800, 13792, 13056, 13984)
    rct.HeroFeatArea            = Rect(3840, -3200, 4928, -2176)

    -- Hero selection / mode selection UI
    rct.WeatherTarget           = Rect(6080, -3392, 6336, -3168)
    rct.PickModeStart           = Rect(8928, 9280, 10368, 9536)
    rct.HeroSelect              = Rect(8864, 10240, 10464, 11040)
    rct.PickMode                = Rect(8128, 9216, 10880, 11616)
    rct.PickModeSpot            = Rect(8640, 7904, 8960, 8160)
    rct.RandomModeSpot          = Rect(9600, 7904, 9920, 8160)
    rct.HeroPickMessage         = Rect(9408, 10400, 9856, 10560)
    rct.UnitPickPreview         = Rect(9216, 11200, 9408, 11360)
    rct.UnitPickPreviewText     = Rect(9408, 11008, 9824, 11168)
    rct.SelectMode              = Rect(8416, 6784, 10176, 8416)
    rct.SelectModeEnter         = Rect(9120, 7328, 9344, 7488)
    rct.ModeTypeSelection       = Rect(11136, 9536, 12832, 11104)
    rct.StoryMode               = Rect(11296, 10720, 11552, 10944)
    rct.BattleMode              = Rect(12384, 10720, 12640, 10976)
    rct.SoloMode                = Rect(11296, 9760, 11552, 9984)
    rct.ModeType4NA             = Rect(12384, 9760, 12640, 9984)
    rct.StoryBattleTypeSelect   = Rect(11840, 10240, 12064, 10496)
    rct.DifficultyNormal        = Rect(15840, 11008, 16384, 11456)
    rct.DifficultyHard          = Rect(16448, 11008, 16896, 11456)
    rct.DifficultyChampion      = Rect(16960, 11008, 17408, 11456)
    rct.DifficultyInsane        = Rect(17504, 11008, 17952, 11456)
    rct.SelectDifficulty        = Rect(15712, 9760, 18048, 11616)
    rct.SelectDifficultyStart   = Rect(16576, 10112, 17088, 10272)

    -- Megaboss 1 area
    rct.Megaboss1NWCorner       = Rect(8864, 5600, 9280, 5984)
    rct.Megaboss1NECorner       = Rect(11008, 5600, 11392, 5984)
    rct.Megaboss1SWCorner       = Rect(8864, 3456, 9280, 3840)
    rct.Megaboss1SECorner       = Rect(11008, 3456, 11392, 3776)
    rct.Megaboss1Center         = Rect(9760, 4256, 10432, 4928)
    rct.Megaboss1EntireArea     = Rect(8736, 3360, 11520, 6208)
    rct.Megaboss1HeroStart      = Rect(9760, 3456, 10560, 3840)
    rct.MegabossNorthBorder     = Rect(8864, 5856, 11392, 5984)
    rct.MegabossEastBorder      = Rect(11232, 3456, 11392, 5984)
    rct.MegabossSouthBorder     = Rect(8864, 3456, 11392, 3552)
    rct.MegabossWestBorder      = Rect(8864, 3456, 8960, 5984)
    rct.TentacleSpawnA          = Rect(8960, 4288, 9184, 4512)
    rct.TentacleSpawnB          = Rect(8992, 4768, 9184, 4992)
    rct.TentacleSpawnC          = Rect(9632, 5472, 9856, 5728)
    rct.TentacleSpawnD          = Rect(10208, 5440, 10400, 5696)
    rct.TentacleSpawnE          = Rect(11136, 4768, 11328, 4960)
    rct.TentacleSpawnF          = Rect(11136, 4352, 11328, 4576)

    -- Mark damnation
    rct.MarkDamnationA          = Rect(-5248, 2432, -4640, 2944)
    rct.MarkDamnationB          = Rect(-4832, 6240, -4320, 6624)
    rct.MarkDamnationC          = Rect(2080, 3904, 2528, 4352)
    rct.MarkDamnationD          = Rect(3744, 1312, 4256, 1728)

    -- Item cleanup / sell zones
    rct.ItemCleanupUNC          = Rect(-1248, -2464, -864, -2144)
    rct.ItemCleanupRare         = Rect(-864, -2464, -480, -2144)
    rct.ItemCleanupEpicArti     = Rect(-480, -2464, -96, -2144)
    rct.ItemCleanupScrollStones = Rect(-96, -2464, 288, -2144)
    rct.UncommonSell            = Rect(-1280, -2496, -864, -2112)
    rct.RareSell                = Rect(-864, -2496, -480, -2112)
    rct.EpicSell                = Rect(-480, -2496, -96, -2112)
    rct.OtherSell               = Rect(-96, -2496, 288, -2112)
    rct.ItemShop                = Rect(544, -3200, 768, -2976)
    rct.SupplyStockingA         = Rect(-11808, -4608, -2176, 14912)
    rct.SupplyStockingB         = Rect(-2016, -1984, 6720, 15744)
    rct.SupplyStocking3         = Rect(-2016, -4832, 832, -4480)

    -- IBW (In Between Waves) timers
    rct.IBW15Sec                = Rect(10848, 8032, 11040, 8192)
    rct.IBW25Sec                = Rect(11168, 8032, 11360, 8192)
    rct.IBW35Sec                = Rect(11488, 8032, 11680, 8192)
    rct.IBW45Sec                = Rect(11808, 8032, 12000, 8192)
    rct.IBW60Sec                = Rect(12128, 8032, 12320, 8192)
    rct.SelectTimeInBetweenWaves = Rect(11360, 7200, 11968, 7520)
    rct.TimeInbetweenWaves      = Rect(10720, 6816, 12512, 8352)

    -- Level 1 bonus checkpoints
    rct.HalfwayMarkerA          = Rect(-9504, 3552, -1152, 3840)
    rct.HalfwayMarkerB          = Rect(-832, 2048, 32, 4352)
    rct.HalfwayMarkerC          = Rect(160, -896, 704, 448)

    -- Stars (Adomach arena markers)
    rct.NorthStar               = Rect(9376, 14560, 9600, 14880)
    rct.NWStar                  = Rect(8320, 13856, 8608, 14048)
    rct.SWStar                  = Rect(8736, 12608, 9024, 12832)
    rct.SEStar                  = Rect(10048, 12672, 10304, 12864)
    rct.NEStar                  = Rect(10400, 13920, 10656, 14144)

    -- Adomach boss arena
    rct.AdomachCenter           = Rect(9184, 13120, 9952, 13440)
    rct.AdomachStartArea        = Rect(9312, 14144, 9664, 14464)
    rct.AdomachEntireArea       = Rect(7616, 11616, 11520, 15584)
    rct.AdoCeilingLeft          = Rect(8000, 12064, 8128, 15104)
    rct.AdoCeilingDown          = Rect(8064, 12128, 11136, 12192)
    rct.AdoCeilingRight         = Rect(11104, 12096, 11168, 15072)
    rct.AdoCeilingTop           = Rect(8096, 15040, 11104, 15168)
    rct.AdoSumArea              = Rect(8864, 12928, 10240, 14336)
    rct.DontEnterMe             = Rect(7488, 6592, 18880, 15584)

    -- Quickfire (Adomach attack sequence)
    rct.Quickfire               = Rect(14880, 12992, 16800, 13120)
    for i = 1, 20 do
        rct["Quickfire"..i] = Rect(14880 + (i-1)*96, 13152 + (i-1)*64, 14944 + (i-1)*96, 13216 + (i-1)*64)
    end

    -- Paths outside castle
    rct.WestPathOutside         = Rect(-6272, -1344, -5952, -640)
    rct.NorthPathOutside1       = Rect(-4992, -256, -4384, 32)
    rct.NorthPathOutside2       = Rect(-2976, -256, -2304, 32)
    rct.EastPathOutside         = Rect(-1888, -1408, -1600, -736)

    -- Ships / harbor
    rct.ShipSpawnStart          = Rect(-11552, -7040, -10976, -6592)
    rct.ShipDockArea            = Rect(-4512, -6144, -3008, -5856)
    rct.ShipLeaveA              = Rect(-4096, -7616, -3648, -7296)
    rct.ShipDespawn             = Rect(-11552, -8416, -10912, -8064)
    rct.HarborDistrictPlot      = Rect(-3328, -4608, -2976, -4320)

    -- Blue AI patrol
    rct.VernPatrolA             = Rect(-4768, -3232, -4288, -2880)
    rct.VernPatrolB             = Rect(-5568, -1184, -5312, -928)
    rct.VernPatrolC             = Rect(-2592, -1184, -2304, -864)
    rct.VernPatrolD             = Rect(-2816, -3296, -2464, -3008)
    rct.YoungHeroSpawn          = Rect(-4576, -3008, -4480, -2912)
    rct.YoungHeroMiliSpawn      = Rect(-4704, -3136, -4352, -3040)
    rct.FrontOfFountain         = Rect(-1984, -2496, -1760, -2400)

    -- Prince / junction
    rct.PrinceJunction          = Rect(3424, -7168, 4448, -6400)
    rct.LeftPrince              = Rect(2368, -7008, 3008, -6464)
    rct.RightPrince             = Rect(4928, -7008, 5568, -6432)
    rct.AltarOfAscendence       = Rect(-3744, -288, -3488, -32)

    -- Spider webs / Frostwhisper
    rct.SpiderWebsA             = Rect(-9440, 10400, -7264, 11040)
    rct.SpiderWebsB             = Rect(-5248, 7552, -3328, 9120)
    rct.SpiderWebsC             = Rect(-1728, 2272, 64, 3872)
    rct.SpiderWebsD             = Rect(5568, 9664, 6720, 11264)
    rct.FrostwhisperMountains   = Rect(-11520, 12224, -3648, 14752)

    -- Misc base structures
    rct.Caravaneers             = Rect(-1600, -2432, -1312, -2176)
    rct.ArchitectPlotPoint      = Rect(-2528, -4960, -2240, -4640)
    rct.Kettle                  = Rect(-1440, -3456, -1216, -3264)
    rct.NecromancticResearch    = Rect(-480, -3456, -288, -3264)
    rct.RadleyHangout           = Rect(-9664, -5472, -9504, -5312)
    rct.BuyFountainZone         = Rect(-3296, -2464, -3200, -2368)
    rct.WonderOfTheWorld        = Rect(3840, -8960, 4064, -8704)
    rct.GoblinBossStart         = Rect(11808, -1536, 12384, -704)
    rct.GoblinBossReinforcements = Rect(9056, -1536, 9248, -800)
    rct.AvalancheSpellTop       = Rect(9280, 1344, 12352, 1600)
    rct.AvalancheSpellBottom    = Rect(8992, -1632, 12384, -1440)
    rct.HellSpawn               = Rect(-10720, 3072, -10080, 3520)

    -- Discover: Treasure Cove (Region_266-269)
    rct.Region266               = Rect(-10400, -11488, -10240, -11328)
    rct.Region267               = Rect(12256, -9248, 12448, -9056)
    rct.Region268               = Rect(12512, -9440, 12672, -8864)
    rct.Region269               = Rect(-10208, -11616, -10048, -11424)

    -- Discover: Bear Cave (Region_270-273)
    rct.Region270               = Rect(-2592, 2176, -2400, 2368)
    rct.Region271               = Rect(20960, -1152, 21248, -832)
    rct.Region272               = Rect(20768, -1344, 20960, -608)
    rct.Region273               = Rect(-2624, 1952, -2432, 2144)

    -- Discover: Ruined Cathedral (Region_274-278, 283-287)
    rct.Region274               = Rect(6368, -672, 6560, -384)
    rct.Region275               = Rect(2784, 14496, 3008, 14688)
    rct.Region276               = Rect(2752, 14688, 3008, 14944)
    rct.Region277               = Rect(6176, -896, 6336, -672)
    rct.Region278               = Rect(-4736, -2816, -4480, -2368)
    rct.Region283               = Rect(-11104, 1408, -10912, 1600)
    rct.Region284               = Rect(20928, -10528, 21312, -10368)
    rct.Region285               = Rect(20832, -10752, 21376, -10560)
    rct.Region286               = Rect(-11168, 1184, -10880, 1408)
    rct.Region287               = Rect(-6496, -4032, -5056, -2592)

    -- Ice dragon cave
    rct.IceDragonCaveEntrance   = Rect(-4896, 13920, -4608, 14240)
    rct.IceDragonCave           = Rect(10560, -5088, 10912, -4832)
    rct.IceDragonCaveExit       = Rect(10240, -5504, 11200, -5248)
    rct.IceDragonCaveExit2      = Rect(-4800, 13664, -4576, 13888)
    rct.IceDragonFlavor         = Rect(10272, -4416, 11424, -4224)

    -- Vern Sewers
    rct.VernSewersDiscover      = Rect(-5376, -5408, -5216, -4800)
    rct.VernSewersEntrance      = Rect(-5664, -4800, -5440, -4640)
    rct.VernSewersExit          = Rect(13984, -9312, 14208, -9088)
    rct.VernSewersEntranceDest  = Rect(14240, -9376, 14368, -9056)
    rct.VernSewersExitDest      = Rect(-5600, -5216, -5408, -4928)
    rct.VernSewersFlavor1       = Rect(14368, -9792, 14496, -8928)
    rct.VernSewersFlavor2       = Rect(14912, -8800, 15104, -8288)
    rct.VernSewersFlavor3       = Rect(16032, -6976, 16800, -6816)

    -- Cave on Outskirts
    rct.CaveOutskirtsEntrance       = Rect(992, -1632, 1248, -1408)
    rct.CaveOutskirtsExitDest       = Rect(800, -1696, 960, -1536)
    rct.CaveOutskirtsLeave          = Rect(13856, 1472, 14176, 1760)
    rct.CaveOutskirtsEntranceDest   = Rect(13888, 1792, 14144, 1952)
    rct.CaveOutskirtsDiscoverSpot   = Rect(576, -2080, 704, -1344)
    rct.CaveOutskirtsFlavor1        = Rect(13696, 2016, 14464, 2112)
    rct.CaveOutskirtsFlavor2        = Rect(15744, 1696, 15904, 2080)
    rct.CaveOutskirtsFlavor3        = Rect(14976, 3616, 15072, 5184)

    -- Coral Cave dives
    rct.CoralCaveDiveEnt1           = Rect(14592, -2656, 14752, -2176)
    rct.CoralCaveDive1Dest          = Rect(18912, 4192, 19040, 4448)
    rct.CoralDive1ExitLeft          = Rect(18688, 4128, 18848, 4576)
    rct.CoralDive1ExitLeftDest      = Rect(14496, -2432, 14560, -2336)
    rct.CoralCaveEntrance           = Rect(-9184, -1824, -8832, -1664)
    rct.CoralCaveExitDest           = Rect(-8992, -2016, -8864, -1888)
    rct.CoralCaveExit               = Rect(14400, -4032, 14656, -3776)
    rct.CoralCaveEntranceDest       = Rect(14240, -4160, 14400, -4000)
    rct.CoralCaveDiscoverSpot       = Rect(-8768, -2592, -8640, -1600)
    rct.CoralDive1ExitRight         = Rect(21312, 4192, 21472, 4480)
    rct.CoralDive1ExitRightDest     = Rect(17376, -4256, 17472, -4032)
    rct.CoralReturnDive1            = Rect(17568, -4288, 17728, -4000)
    rct.CoralReturnDive1Dest        = Rect(20992, 4224, 21152, 4384)
    rct.CoralSecretDive             = Rect(17696, -160, 18208, 0)
    rct.CoralSecretDiveReturnDest   = Rect(17888, -480, 18112, -256)
    rct.CoralSecretDiveReturn       = Rect(18784, 2144, 18976, 2368)
    rct.CoralSecretDiveDest         = Rect(19072, 2304, 19200, 2432)
    rct.CoralDive2Ent               = Rect(14016, -1344, 14272, -1120)
    rct.CoralDive2ReturnDest        = Rect(14368, -1152, 14560, -992)
    rct.CoralDive2Return            = Rect(22528, 4992, 22752, 5152)
    rct.CoralDive2Dest              = Rect(22560, 4832, 22720, 4928)
    rct.BossDiveEntrance            = Rect(22528, 4160, 22752, 4320)
    rct.BossDiveReturnDest          = Rect(22560, 4384, 22720, 4480)
    rct.BossDiveReturn              = Rect(22784, 1536, 22944, 1760)
    rct.BossDiveEntranceDest        = Rect(22656, 1600, 22720, 1760)
    rct.CoralFlavor1                = Rect(13696, -2784, 14528, -2720)
    rct.CoralFlavor2                = Rect(15936, -4320, 16032, -3776)
    rct.CoralFlavor3                = Rect(22496, 4608, 22816, 4736)

    -- Populate EnemyStartLoc from rct
    EnemyStartLoc[0] = rct.SpawnA
    EnemyStartLoc[1] = rct.SpawnB
    EnemyStartLoc[2] = rct.SpawnC
end
