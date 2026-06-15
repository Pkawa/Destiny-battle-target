-- Central FourCC registry — named constants for object-type IDs.
-- Replaces scattered raw FourCC('xxxx') literals with self-documenting names so the
-- intent of data tables (levels, achievements, items, …) is readable. Phase 8 goal
-- (porting-phases.md): "replace raw FourCCs with named constants."
--
-- These are plain FourCC integers, usable anywhere an id is expected: CreateUnit,
-- GetUnitTypeId comparisons, ability/item checks, object-data DSL, etc.
-- Add to these tables as systems are threaded; nothing here creates WC3 objects.

-- ── Hero classes (playable heroes; confirmed via the death-cry roster, JASS 11066+) ──
UID = {
    ClericOfOrder    = FourCC('H001'),
    ClericSmallFolk  = FourCC('H003'),
    DwarvenAxeMaster = FourCC('H007'),
    RogueOfTheDark   = FourCC('E001'),
    MonkEbonyFist    = FourCC('E000'),
    MasterOfTheArt   = FourCC('H00E'),
    HumanEngineer    = FourCC('H00F'),
    ManAtArms        = FourCC('H013'),
    EarthenTemplar   = FourCC('H00S'),
    FeralArchon      = FourCC('O000'),
    SunSoulInitiate  = FourCC('E004'),
    PaladinOfJustice = FourCC('H01J'),
    DwarvenRockfighter = FourCC('H01M'),
    DiscipleOfGrace  = FourCC('H01N'),
    ArcaneArcher     = FourCC('H01O'),
    AxeBrother       = FourCC('E006'),
    CentaurDruid     = FourCC('H01U'),
    ClericElvenWord  = FourCC('H02C'),
    CrestedDrake     = FourCC('H02D'),
    HalfElvenBard    = FourCC('H02L'),
    ElvenSharpshooter= FourCC('H02N'),
    RecklessPyromancer = FourCC('E00E'),
    WildernessRunner = FourCC('H02U'),
    WarGuard         = FourCC('H02X'),
    HorizonWanderer  = FourCC('E011'),
    TundraBarbarian  = FourCC('H03A'),
    Swashbuckler     = FourCC('E015'),
    Illusionist      = FourCC('H03I'),
    Wildbond         = FourCC('H03J'),
    FireMagus        = FourCC('E01B'),
    ElvenCryptguard  = FourCC('E019'),
    BorderSkirmisher = FourCC('H03U'),
    DwarvenTrueborn  = FourCC('H041'),

    -- Companion / special
    Companion        = FourCC('H04Y'),  -- Sir Joshua (blue NPC)
    SpeedWisp        = FourCC('e01M'),  -- per-level enemy speed wisp (every level)

    -- Bosses (named only; the bulk of per-level enemy spawns stay raw FourCC in
    -- LevelData — single-use data, self-documented by the level intro text).
    PaladinCommander = FourCC('H00C'),  -- L6 miniboss (Meldokk)
    GoblinKing       = FourCC('O001'),  -- L10 boss
    UndeadBehemoth   = FourCC('O004'),  -- L20 boss
    Tidedweller      = FourCC('O002'),  -- L14 escort boss

    -- Cross-module level/escort actors (referenced from 2+ modules)
    Caravan          = FourCC('h01A'),  -- L14 escort caravan
    Prisoner         = FourCC('h006'),  -- L4 prisoner -> militia conversion
    SquireCaptive    = FourCC('h005'),  -- rescued Squire Captain (web victims)
    Militia          = FourCC('h045'),  -- Militia of Vern / rescued militia

    -- Hero-class decoy/flair units (excluded from the feat-area sweep; abilities + hero_selection)
    Decoy1           = FourCC('h03V'),  -- Border Skirmisher / Swashbuckler decoy
    Decoy2           = FourCC('h03W'),
    Decoy3           = FourCC('h03X'),  -- "Linna" flair decoy
}

-- ── Abilities (those referenced by ported systems; extend as heroes are added) ──
ABIL = {
    -- Cleric of Order
    Heal             = FourCC('A002'),
    MarkOfOrder      = FourCC('A001'),
    -- Cleric of the Small Folk
    SmallFolkHeal    = FourCC('A006'),
    FlurryOfSlingstones = FourCC('A005'),
    -- Dwarven Axemaster
    Aggression       = FourCC('A00C'),
    -- Monk of the Ebony Fist
    ChakraBurst      = FourCC('A00H'),
    FlurryOfBlows    = FourCC('A03V'),
    -- Master of the Art
    Blast            = FourCC('A00K'),
    EssenceShock     = FourCC('A00L'),
    -- Feral Archon
    Tantrum          = FourCC('A00X'),
    -- Man-at-Arms
    BattleShout      = FourCC('A024'),
    -- Sun Soul
    SolarBarrier     = FourCC('A02G'),
    Sunbeam          = FourCC('A02F'),
    -- Paladin of Justice
    LayOnHands       = FourCC('A02M'),
    -- Dwarven Rockfighter
    DwarvenStamina   = FourCC('A037'),
    IntimidatingShout= FourCC('A035'),
    -- Disciple of Grace
    MoonbeamRejuv    = FourCC('A039'),
    -- Arcane Archer
    FarShot          = FourCC('A03J'),
    EagleArrow       = FourCC('A03I'),
    -- Axe Brother
    WhirlwindAttack  = FourCC('A03M'),
    -- Cleric of Elven Word
    Regrowth         = FourCC('A05D'),
    ElvenBlessing    = FourCC('A05C'),
    -- Crested Drake
    FlameWreath      = FourCC('A05F'),
    Drakefang        = FourCC('A05H'),
    -- Systems
    Retrieve         = FourCC('A0KE'),  -- Supply Stocking retrieve
}

-- ── Item tokens (shop/loot-box/sell tokens referenced by the economy) ──
ITEM = {
    Lv1Box       = FourCC('I00N'),  -- purchase loot box (rarity-rolled)
    Lv1EpicBox   = FourCC('I0AR'),  -- purchase epic box
    SellUncommon = FourCC('I0C6'),
    SellRare     = FourCC('I0C7'),
    SellEpic     = FourCC('I0C8'),
    SellOther    = FourCC('I0C9'),
    SwallowAnchor = FourCC('I0C0'),  -- summons the defence ship (items + misc)
    RadleyTreats  = FourCC('I0BY'),  -- Radley the dog follows the holder (items + misc)
}

-- ── Research / upgrades ──
RES = {
    ItemShop      = FourCC('R00M'),
    ItemShopTrade = FourCC('R00N'),
    SupplyStocking= FourCC('R00J'),
}
