-- Hero pool, tarot cards, hero intro locations, wildbond pets
-- Ported from war3map.j:
--   Trig_Tarot_Cards_Actions (line 33677) — fires T+6s
--   Trig_Heroes_Actions (line 33977) — fires T+10s
--   Trig_Hero_Preview_Text_Actions (line 34023) — fires T+10s
--   Trig_Locations_Actions (line ~33940) — fires T+10s
--   Trig_Wildbond_Random_Pet_Table_Actions (line 46756) — fires T+10s

function InitHeroPool_T6()
    -- Tarot card pool (21 cards, indices 0-20)
    TarotCards[0]  = FourCC('I08H')   -- The Death
    TarotCards[1]  = FourCC('I08J')
    TarotCards[2]  = FourCC('I08F')
    TarotCards[3]  = FourCC('I08I')
    TarotCards[4]  = FourCC('I08B')
    TarotCards[5]  = FourCC('I088')
    TarotCards[6]  = FourCC('I086')
    TarotCards[7]  = FourCC('I084')
    TarotCards[8]  = FourCC('I08G')
    TarotCards[9]  = FourCC('I08D')
    TarotCards[10] = FourCC('I089')
    TarotCards[11] = FourCC('I08A')
    TarotCards[12] = FourCC('I085')
    TarotCards[13] = FourCC('I087')
    TarotCards[14] = FourCC('I08C')
    TarotCards[15] = FourCC('I08E')   -- Wheel of Fortune
    TarotCards[16] = FourCC('I08M')   -- The Tower
    TarotCards[17] = FourCC('I08N')   -- The Star
    TarotCards[18] = FourCC('I08O')
    TarotCards[19] = FourCC('I08P')
    TarotCards[20] = FourCC('I08Q')   -- Judgement
end

function InitHeroPool_T10()
    -- Hero FourCC pool (33 entries, indices 0-32)
    -- Note: indices 5 and 6 are swapped in original — preserved exactly
    HeroPicked[0]  = FourCC('H003')  -- Nils, Cleric of the Small Folk
    HeroPicked[1]  = FourCC('H001')  -- Infinitivus, Cleric of Order
    HeroPicked[2]  = FourCC('H00F')  -- Mustadio, Human Engineer
    HeroPicked[3]  = FourCC('H00E')  -- Arathil, Master of the Art
    HeroPicked[4]  = FourCC('H013')  -- Boyd Axer, Man-at-Arms
    HeroPicked[5]  = FourCC('H01J')  -- Haniel, Paladin of Justice  (swapped with 6)
    HeroPicked[6]  = FourCC('H00S')  -- Bouldergravel, Earthen Templar (swapped with 5)
    HeroPicked[7]  = FourCC('H007')  -- Vorthin Smashfist, Dwarven Axemaster
    HeroPicked[8]  = FourCC('O000')  -- Newten Will'o, Feral Archon
    HeroPicked[9]  = FourCC('E000')  -- Venille Quickstrike, Monk
    HeroPicked[10] = FourCC('E001')  -- Scratch the Knife, Rogue of the Dark
    HeroPicked[11] = FourCC('E004')  -- Paladeus Sparkflame, Sun Soul Initiate
    HeroPicked[12] = FourCC('H01M')  -- Tordek Hammercrafter, Dwarven Rockfighter
    HeroPicked[13] = FourCC('H01N')  -- Faiya Hopecraft, Disciple of Grace
    HeroPicked[14] = FourCC('H01O')  -- Azrae, Arcane Archer
    HeroPicked[15] = FourCC('E006')  -- Faxanadu Skullcrush, Axe Brother
    HeroPicked[16] = FourCC('H01U')  -- Eldrad Leafrunner, Centaur Druid
    HeroPicked[17] = FourCC('H02C')  -- Lyrra Wyndhaar, Cleric of Elven Word
    HeroPicked[18] = FourCC('H02D')  -- Scorchmaw, Crested Drake
    HeroPicked[19] = FourCC('H02L')  -- Melody Starsong, Half-Elven Bard
    HeroPicked[20] = FourCC('H02N')  -- Amy Fletcher, Elven Sharpshooter
    HeroPicked[21] = FourCC('E00E')  -- Majin Flarefire, Reckless Pyromancer
    HeroPicked[22] = FourCC('H02U')  -- Leylana Woodwillow, Wilderness Runner
    HeroPicked[23] = FourCC('H02X')  -- Karl Ironstance, War Guard
    HeroPicked[24] = FourCC('E011')  -- Eros Farltravel, Horizon Wanderer
    HeroPicked[25] = FourCC('H03A')  -- Truhbold Wolfheart, Tundra Barbarian
    HeroPicked[26] = FourCC('E015')  -- Dramlor Mal'chazzen, Rogue
    HeroPicked[27] = FourCC('H03I')  -- Cyril Everglow, Gnome Illusionist
    HeroPicked[28] = FourCC('H03J')  -- Lilithia Primalfang, Wildbond
    HeroPicked[29] = FourCC('E01B')  -- Krellen Wythel, Fire Magus
    HeroPicked[30] = FourCC('E019')  -- Faye the Forgotten, Elven Cryptguard
    HeroPicked[31] = FourCC('H03U')  -- Tomi Wittaker, Border Skirmisher
    HeroPicked[32] = FourCC('H041')  -- Khelgar the First, Dwarven Trueborn

    -- Hero display names / preview descriptions (indices 0-32, matching HeroPicked)
    HeroText[0]  = "Nils, Cleric of the Small Folk"
    HeroText[1]  = "Infinitivus, Cleric of Order"
    HeroText[2]  = "Mustadio, Human Engineer"
    HeroText[3]  = "Arathil, Master of the Art"
    HeroText[4]  = "Boyd Axer, Man-at-Arms"
    HeroText[5]  = "Haniel, Paladin of Justice"
    HeroText[6]  = "Bouldergravel, Earthen Templar"
    HeroText[7]  = "Vorthin Smashfist, Dwarven Axemaster"
    HeroText[8]  = "Newten Will'o, Feral Archon"
    HeroText[9]  = "Venille Quickstrike"
    HeroText[10] = "Scratch the Knife, Rogue of the Dark"
    HeroText[11] = "Paladeus Sparkflame, Sun Soul Initiate"
    HeroText[12] = "Tordek Hammercrafter, Dwarven Rockfighter"
    HeroText[13] = "Faiya Hopecraft, Disciple of Grace"
    HeroText[14] = "Azrae, Arcane Archer"
    HeroText[15] = "Faxanadu Skullcrush, Axe Brother"
    HeroText[16] = "Eldrad Leafrunner, Centaur Druid"
    HeroText[17] = "Lyrra Wyndhaar, Cleric of Elven Word"
    HeroText[18] = "Scorchmaw, Crested Drake"
    HeroText[19] = "Melody Starsong, Half-Elven Bard"
    HeroText[20] = "Amy Fletcher, Elven Sharpshooter"
    HeroText[21] = "Majin Flarefire, Reckless Pyromancer"
    HeroText[22] = "Leylana Woodwillow, Wilderness Runner"
    HeroText[23] = "Karl Ironstance, War Guard"
    HeroText[24] = "Eros Farltravel, Horizon Wanderer"
    HeroText[25] = "Truhbold Wolfheart, Tundra Barbarian"
    HeroText[26] = "Dramlor Mal'chazzen"
    HeroText[27] = "Cyril Everglow, Gnome Illusionist"
    HeroText[28] = "Lilithia Primalfang, Wildbond"
    HeroText[29] = "Krellen Wythel, Fire Magus"
    HeroText[30] = "Faye the Forgotten, Elven Cryptguard"
    HeroText[31] = "Tomi Wittaker, Border Skirmisher"
    HeroText[32] = "Khelgar the First, Dwarven Trueborn"

    -- Hero intro camera positions per player slot (war3map.j ~33940)
    CurrentHeroIntroLoc[0] = rct.P1Intro
    CurrentHeroIntroLoc[1] = rct.P2Intro
    CurrentHeroIntroLoc[2] = rct.P3Intro
    CurrentHeroIntroLoc[3] = rct.P4Intro
    CurrentHeroIntroLoc[4] = rct.P5Intro
    CurrentHeroIntroLoc[5] = rct.P6Intro
    CurrentHeroIntroLoc[6] = rct.P7Intro
    CurrentHeroIntroLoc[7] = rct.P8Intro

    -- Enemy spawn locations
    EnemyStartLoc[0] = rct.SpawnA
    EnemyStartLoc[1] = rct.SpawnB
    EnemyStartLoc[2] = rct.SpawnC

    -- Wildbond pet table (4 possible pets, indices 1-4)
    WildbondPetTable = {}
    WildbondPetTable[1] = FourCC('H03N')
    WildbondPetTable[2] = FourCC('H03K')
    WildbondPetTable[3] = FourCC('H03M')
    WildbondPetTable[4] = FourCC('H03L')
end

function RegisterHeroPoolTimers()
    local t6  = CreateTimer()
    local t10 = CreateTimer()
    TimerStart(t6,  6.0, false, InitHeroPool_T6)
    TimerStart(t10, 10.0, false, InitHeroPool_T10)
end
