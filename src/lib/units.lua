-- CreateAllUnits() — ported from war3map.j lines 3899-4320
-- Creates every game unit: hero taverns, feat shops, town, prince, enemy units.
-- All unit placement that was scripted (nothing was in warcraft3mapUnits.doo).
-- Named handles used by other systems stored as globals (drop gg_unit_ prefix).

local np = Player(PLAYER_NEUTRAL_PASSIVE)
local p8 = Player(8)
local p9 = Player(9)
local p11 = Player(11)
local p12 = Player(12)

local function u(p, id, x, y, face)
    return BlzCreateUnitWithSkin(p, FourCC(id), x, y, face, FourCC(id))
end

function CreateNeutralPassiveBuildings()
    -- Town base building
    u(p8, 'n000', -1728.0, -3392.0, 270.0)

    -- Feat area shops (n00J, n00E, n00B = Goblin Merchants; n00L = another)
    unit_n00J = u(np, 'n00J', 13184.0, 14208.0, 270.0)  -- feat shop 1
    unit_n00E = u(np, 'n00E', 12864.0, 14528.0, 270.0)  -- feat shop 2
    unit_n00B = u(np, 'n00B', 12608.0, 14208.0, 270.0)  -- feat shop 3
    u(np, 'n00K', 14272.0, 11136.0, 270.0)

    -- Mode selection area markers (ncp2 = circle of power, ncop = sign posts)
    u(np, 'ncp2',  8800.0,  8032.0, 270.0)  -- Random Mode marker
    u(np, 'ncp2',  9760.0,  8032.0, 270.0)  -- Pick Mode marker
    u(np, 'ncop', 10944.0,  8128.0, 270.0)  -- mode select area sign
    u(np, 'ncop', 11264.0,  8128.0, 270.0)
    u(np, 'ncop', 11584.0,  8128.0, 270.0)
    u(np, 'ncop', 11904.0,  8128.0, 270.0)

    -- Town area
    u(np, 'ncop', -6208.0, -3712.0, 270.0)
    u(np, 'ncop',  3840.0, -4672.0, 270.0)

    -- Hero selection taverns (n007, n00G, n00M = ntav base, sells heroes)
    unit_n007 = u(np, 'n007', 8896.0, 11136.0, 270.0)
    SetUnitColor(unit_n007, ConvertPlayerColor(0))
    unit_n00G = u(np, 'n00G', 10304.0, 11136.0, 270.0)
    SetUnitColor(unit_n00G, ConvertPlayerColor(0))

    -- More mode type selection markers
    u(np, 'ncop', 12224.0,  8128.0, 270.0)
    u(np, 'ncp2', 11424.0, 10848.0, 270.0)  -- Story Mode area marker
    u(np, 'ncp2', 12512.0, 10848.0, 270.0)  -- Battle Mode area marker
    u(np, 'ncp2', 11424.0,  9888.0, 270.0)  -- Solo Mode area marker
    u(np, 'ncp2', 12512.0,  9888.0, 270.0)

    -- Feat area (n00L) and hero select 3rd tavern
    unit_n00L = u(np, 'n00L', 12928.0, 13888.0, 270.0)  -- feat shop 4
    unit_n00M = u(np, 'n00M',  8384.0, 10688.0, 270.0)  -- hero tavern 3
    SetUnitColor(unit_n00M, ConvertPlayerColor(0))

    -- Optional area vendors (Discover areas, Coral Cave, etc.)
    u(np, 'ncop', 14016.0,  1600.0, 270.0)
    u(np, 'ncop', 14528.0, -3904.0, 270.0)
    u(np, 'ncop', 14720.0, -2432.0, 270.0)
    u(np, 'ncop', 21440.0,  4352.0, 270.0)
    u(np, 'ncop', 18624.0,  4352.0, 270.0)
    u(np, 'ncop', 17664.0, -4160.0, 270.0)
    u(np, 'ncop', 14144.0, -1280.0, 270.0)
    u(np, 'ncop', 22656.0,  4224.0, 270.0)
    u(np, 'ncop', 22656.0,  5120.0, 270.0)
    u(np, 'ncop', 18880.0,  2240.0, 270.0)
    u(np, 'ncop', 22912.0,  1664.0, 270.0)
    u(np, 'ncop', 14080.0, -9216.0, 270.0)
end

function CreateNeutralPassive()
    -- Feat area decorative units (h00V = feat choice orbs, h00R = feat signs, etc.)
    -- These are paused and unpaused by Pick_Feat along with all feat area units
    u(np, 'h00V', 13637.4, 14451.6,  80.0)
    u(np, 'h00V', 13712.1, 14449.5,  90.6)
    u(np, 'h00V', 13787.8, 14496.5, 101.7)
    u(np, 'h00R', 13499.0, 14628.1,   0.0)
    u(np, 'h02T', 13625.9, 14576.2, 310.9)
    u(np, 'h00R', 12350.6, 14549.7, 100.0)
    u(np, 'h00R', 12254.9, 14611.9,  62.4)
    u(np, 'h00U', 12370.1, 14727.1, 230.8)
    u(np, 'h00T', 12313.1, 13257.5, 210.0)
    u(np, 'h00R', 12202.3, 13227.2,  16.1)

    -- World creature with a drop item
    local dropUnit = u(np, 'e01N', -10621.0, 6924.9, 114.0)
    local dropTrg = CreateTrigger()
    TriggerRegisterUnitEvent(dropTrg, dropUnit, EVENT_UNIT_DEATH)
    TriggerRegisterUnitEvent(dropTrg, dropUnit, EVENT_UNIT_CHANGE_OWNER)
    TriggerAddAction(dropTrg, function()
        -- Unit000065_DropItems equivalent: drops item 'I0CF' (100%)
        local dying = GetTriggerUnit()
        if dying and not IsUnitHidden(dying) then
            UnitDropItemPoint(dying, FourCC('I0CF'),
                GetUnitX(dying) + GetRandomReal(-50, 50),
                GetUnitY(dying) + GetRandomReal(-50, 50))
        end
    end)
end

function CreateBuildingsForPlayer8()
    -- Town wall / gate structures
    u(p8, 'h00D', -6720.0, -3904.0, 270.0)
    u(p8, 'h036', -3648.0,    64.0, 270.0)

    -- Town buildings (h000 = Town Hall variants, h036 = Blacksmith type)
    u(p8, 'h000', -4416.0, -1728.0, 270.0)
    u(p8, 'h000', -3392.0, -2752.0, 270.0)
    u(p8, 'h036', -2560.0, -2368.0, 270.0)
    u(p8, 'h000', -5056.0,  -704.0, 270.0)
    u(p8, 'h000', -4352.0,  -704.0, 270.0)
    u(p8, 'h000', -3136.0,  -704.0, 270.0)
    u(p8, 'h000', -2240.0, -1472.0, 270.0)
    u(p8, 'h036', -3776.0, -1920.0, 270.0)
    u(p8, 'h000', -2240.0, -2560.0, 270.0)

    -- Fountain of Life — referenced in BonusesAndUpkeep mana check
    unit_h010 = u(p8, 'h010', -1856.0, -2240.0, 270.0)

    -- Castle / fortress structures
    u(p8, 'h055',  4672.0, -7360.0, 270.0)
    u(p8, 'h055',  3264.0, -7360.0, 270.0)
    u(p8, 'h000', -5696.0, -1472.0, 270.0)
    u(p8, 'hhou', -4224.0,  -704.0, 270.0)
    u(p8, 'h036', -5248.0, -2496.0, 270.0)
    u(p8, 'n017',  5376.0,  1216.0, 270.0)
    u(p8, 'h036', -3584.0, -3904.0, 270.0)
    u(p8, 'nfrt', -3584.0, -4928.0, 270.0)
    u(p8, 'nbwd', -3072.0, -3584.0, 270.0)
    u(p8, 'nheb', -2240.0, -3904.0, 270.0)

    -- Houses
    u(p8, 'hhou', -3136.0, -3776.0, 270.0)
    u(p8, 'hhou', -3136.0, -3904.0, 270.0)
    u(p8, 'hhou', -3136.0, -4032.0, 270.0)
    u(p8, 'hhou', -3904.0,  -704.0, 270.0)
    u(p8, 'hhou', -2368.0,  -704.0, 270.0)
    u(p8, 'hhou', -2624.0, -1920.0, 270.0)
    u(p8, 'hhou', -3072.0, -4160.0, 270.0)
    u(p8, 'hhou', -3264.0, -1856.0, 270.0)
    u(p8, 'hhou', -3264.0, -1984.0, 270.0)
    u(p8, 'h000', -5696.0,  -768.0, 270.0)
    u(p8, 'hhou', -3264.0,  -704.0, 270.0)
    u(p8, 'h027', -4864.0, -1920.0, 270.0)
    u(p8, 'hhou', -5056.0, -1472.0, 270.0)
    u(p8, 'hhou', -4160.0, -1792.0, 270.0)
    u(p8, 'h028', -2944.0, -3840.0, 270.0)
    u(p8, 'hhou', -3584.0, -2368.0, 270.0)
    u(p8, 'hhou', -3712.0, -4480.0, 270.0)
    u(p8, 'hhou', -3584.0, -4480.0, 270.0)
    u(p8, 'h029', -3392.0, -4864.0, 270.0)
    u(p8, 'h000', -5824.0, -3904.0, 270.0)
    u(p8, 'hhou', -2304.0, -2240.0, 270.0)

    -- Watch towers — referenced by guard triggers
    unit_hwtw_A = u(p8, 'hwtw', -3904.0,  192.0, 270.0)
    unit_hwtw_B = u(p8, 'hwtw', -3392.0,  192.0, 270.0)
    unit_hwtw_C = u(p8, 'hwtw', -4608.0, -3968.0, 270.0)
    unit_hwtw_D = u(p8, 'hwtw', -3968.0, -3968.0, 270.0)

    u(p8, 'h053', -2464.0, -6048.0, 270.0)

    -- Market/vendor
    unit_n00H = u(p8, 'n00H', -4096.0, -768.0, 270.0)

    u(p8, 'h050', -6336.0, -2624.0, 270.0)
    u(p8, 'h000', -2240.0, -3392.0, 270.0)
    u(p8, 'h000', -3392.0, -3392.0, 270.0)
    u(p8, 'h000', -4864.0, -1728.0, 270.0)
    u(p8, 'h000', -2496.0,  -704.0, 270.0)
    u(p8, 'h000', -2240.0,  -960.0, 270.0)
    u(p8, 'hhou', -3456.0, -4480.0, 270.0)
    u(p8, 'hhou', -3840.0, -4480.0, 270.0)
    u(p8, 'hhou', -2240.0, -3520.0, 270.0)
    u(p8, 'hhou', -2240.0, -3648.0, 270.0)
    u(p8, 'hbla', -3968.0, -1408.0, 270.0)
    u(p8, 'hhou', -3776.0, -1472.0, 270.0)
    u(p8, 'hhou', -3648.0, -1472.0, 270.0)
    u(p8, 'hhou', -3520.0, -1472.0, 270.0)
    u(p8, 'hhou', -4288.0, -1472.0, 270.0)
    u(p8, 'hlum', -4960.0, -2080.0, 270.0)
    u(p8, 'hars', -5696.0, -2560.0, 270.0)
    u(p8, 'hhou', -4992.0, -2304.0, 270.0)
    u(p8, 'hhou', -4992.0, -1856.0, 270.0)
    u(p8, 'hhou', -3584.0, -2496.0, 270.0)
    u(p8, 'h053', -4832.0, -5920.0, 270.0)
    u(p8, 'hhou', -3968.0, -3392.0, 270.0)
    u(p8, 'hhou', -4096.0, -3520.0, 270.0)
    u(p8, 'hhou', -3840.0, -3520.0, 270.0)
    u(p8, 'hhou', -3968.0, -3648.0, 270.0)
    u(p8, 'h029', -2304.0, -3712.0, 270.0)
    u(p8, 'h034', -3008.0, -3648.0, 270.0)
    u(p8, 'h02A', -3520.0, -2688.0, 270.0)
    u(p8, 'h027', -2240.0, -4032.0, 270.0)
    u(p8, 'h027', -2432.0, -3904.0, 270.0)
    u(p8, 'nefm', -5536.0,  -736.0, 270.0)
    u(p8, 'nfrt', -5312.0,  -768.0, 270.0)
    u(p8, 'h054', -3776.0, -2752.0, 270.0)
    u(p8, 'hgra', -4928.0, -5376.0, 270.0)
    u(p8, 'h046', -5376.0, -7040.0, 270.0)
    u(p8, 'hhou', -2240.0, -5248.0, 270.0)
    u(p8, 'hhou', -2240.0, -5376.0, 270.0)
    u(p8, 'hhou', -4864.0, -4800.0, 270.0)
    u(p8, 'hhou', -4992.0, -4672.0, 270.0)
    u(p8, 'hhou', -4992.0, -4480.0, 270.0)
    u(p8, 'h047', -2432.0, -5504.0, 270.0)
    u(p8, 'h047', -4864.0, -5184.0, 270.0)
    u(p8, 'h027', -3904.0, -4608.0, 270.0)
    u(p8, 'nten', -6112.0, -5920.0, 270.0)
    u(p8, 'h051', -4960.0, -3424.0,  45.0)
    u(p8, 'h052', -5376.0, -3456.0, 270.0)
    u(p8, 'h000', -3840.0, -2368.0, 270.0)
    u(p8, 'hhou', -5888.0, -4032.0, 270.0)
    u(p8, 'hhou', -5632.0, -4032.0, 270.0)
    u(p8, 'hhou', -5760.0, -4160.0, 270.0)

    -- Named units referenced by triggers
    unit_n010 = u(p8, 'n010', -6272.0, -2944.0, 270.0)  -- referenced in misc triggers
    unit_n012 = u(p8, 'n012', -2944.0, -5888.0, 270.0)  -- referenced in misc triggers
    u(p8, 'h06T', -6336.0, -3840.0, 353.4)
end

function CreateUnitsForPlayer8()
    -- Gate guard units (h02B)
    unit_h02B_A = u(p8, 'h02B', -3386.3,   181.7, 355.0)
    unit_h02B_B = u(p8, 'h02B', -3900.9,   182.3,  33.2)
    unit_h02B_C = u(p8, 'h02B', -4599.6, -3985.4, 227.5)
    unit_h02B_D = u(p8, 'h02B', -3967.0, -3972.8, 300.7)

    -- The Prince — key NPC, protected objective
    unit_H02G = u(p8, 'H02G', 3827.3, -10232.8, 110.0)

    -- Prince guard retinue
    u(p8, 'h037',  3738.1,  -6309.0,  90.0)
    u(p8, 'h037',  4070.5,  -6307.5,  90.0)
    u(p8, 'h037',  2932.3,  -8808.2,  90.0)
    u(p8, 'h037',  3216.5,  -8805.9,  90.0)
    u(p8, 'h037',  4664.5,  -8806.7,  90.0)
    u(p8, 'h037',  4932.9,  -8803.4,  90.0)
    u(p8, 'h037',  3616.5, -10249.0,  90.0)
    u(p8, 'h037',  3709.9, -10246.9,  90.0)
    u(p8, 'h037',  3970.6, -10246.5,  90.0)
    u(p8, 'h037',  4062.4, -10244.5,  90.0)

    -- Radley NPC
    unit_n011 = u(p8, 'n011', -9574.2, -5354.8, 270.0)
end

function CreateUnitsForPlayer9()
    -- The difficulty-scaling enemy unit (referenced in Construction/ability triggers)
    unit_e01O = u(p9, 'e01O', 7718.4, -2025.1, 204.3)
end

function CreateUnitsForPlayer11()
    -- Optional content area units (Goblin boss zone etc.)
    unit_e00R  = u(p11, 'e00R',   5365.4,  -3764.3, 164.1)
    unit_e008  = u(p11, 'e008',   5808.1,  -3124.0, 151.3)
    unit_e00A  = u(p11, 'e00A',   5924.0,  -3113.2,  23.0)
    u(p11, 'e00S',  5523.4, -3755.8, 334.3)
    u(p11, 'e00V',  5688.5, -3762.4, 197.8)
    unit_e00V  = u(p11, 'e00V',   5869.2,  -3206.6, 338.0)
    unit_E018  = u(p11, 'E018',   5850.8,  -3741.7, 216.7)
    unit_e01A  = u(p11, 'e01A',   6015.9,  -3742.5,  94.7)
    u(p11, 'h04E', 17101.1,  2069.7, 180.0)
    unit_h056  = u(p11, 'h056',  13839.6,  4163.9,   0.0)
    u(p11, 'h05E', 19354.6,  2527.8, 248.9)
    u(p11, 'h05E', 15111.3, -1722.4, 326.5)
    unit_h05G  = u(p11, 'h05G',  21230.9,  1365.0, 289.8)
    unit_h05E  = u(p11, 'h05E',  12213.4, -6688.5, 317.9)  -- treasure guardian
end

function CreateUnitsForPlayer12()
    -- Optional content area units (coral cave / northern content)
    u(p12, 'h057', 13916.8,  2546.3,  90.0)
    u(p12, 'h057', 14041.1,  2615.6, 180.0)
    u(p12, 'h057', 14051.9,  2693.4, 180.0)
    u(p12, 'h058', 13891.3,  2673.0, 315.0)
    u(p12, 'h058', 15112.0,  2396.3,  45.0)
    u(p12, 'h058', 15271.9,  2579.9, 245.0)
    unit_h059  = u(p12, 'h059', 16743.8,  2057.1, 180.0)
    u(p12, 'h058', 17134.9,  2967.3,  45.0)
    u(p12, 'h058', 17284.5,  3095.7, 225.7)
    u(p12, 'h058', 16995.9,  3327.2, 176.7)
    u(p12, 'h057', 16831.4,  3450.0, 270.0)
    u(p12, 'h057', 16944.2,  3452.3, 270.0)
    u(p12, 'h057', 17034.2,  3454.6, 270.0)
    u(p12, 'h057', 17127.8,  3470.9, 270.0)
    u(p12, 'h058', 16198.2,  5100.7, 258.6)
    u(p12, 'h058', 16047.5,  5100.7, 320.0)
    u(p12, 'h058', 15743.1,  4163.9, 350.5)
    u(p12, 'h058', 15625.8,  4092.1,  39.4)
    unit_h05A  = u(p12, 'h05A', 14064.6,  4229.6,  34.6)
    u(p12, 'h058', 14263.8,  4415.7, 215.0)
    u(p12, 'h058', 14326.4,  4248.1, 215.0)
    u(p12, 'h057', 13914.9,  4424.6,  45.0)
    u(p12, 'h057', 14005.4,  4509.0, 215.0)
    u(p12, 'h057', 14052.4,  4126.6, 270.0)
    u(p12, 'h057', 14137.1,  4139.1, 270.0)
    u(p12, 'h057', 14935.3,  5076.3, 162.9)
    u(p12, 'h057', 14701.1,  3679.7, 187.3)
    u(p12, 'h057', 14792.6,  3679.7, 262.1)
    u(p12, 'h05B', 14059.1, -3468.0, 270.0)
    u(p12, 'h05B', 13887.3, -3460.7, 270.0)
    u(p12, 'h06E', 15173.4, -9421.4, 168.9)
    u(p12, 'h06F', 15103.5, -9387.1, 202.4)
    u(p12, 'h05C', 20646.6,  4247.5, 181.3)
end

function CreateAllUnits()
    CreateNeutralPassiveBuildings()
    CreateNeutralPassive()
    CreateBuildingsForPlayer8()
    CreateUnitsForPlayer8()
    CreateUnitsForPlayer9()
    CreateUnitsForPlayer11()
    CreateUnitsForPlayer12()
end
