-- Object editing (warcraft-vscode objediting DSL).
--
-- Display-only passive abilities for the STAT feats so a picked feat shows as an icon on
-- the hero's command card. The original applies stat bonuses via a hidden per-level-up
-- trigger with NO ability, so nothing showed. These are based on Evasion (like the map's
-- own Acrobat feat A063:AEev) with 0% chance — they display + do nothing; the real
-- +stat/level effect is applied in src/lib/feats.lua.
-- Requirements: hero-selection/Feats.md.

local ICON = "ReplaceableTextures\\CommandButtons\\"

-- Create a cosmetic (0%-evasion) passive that displays as a feat marker on the command card.
local function featPassive(id, name, tooltip, icon)
    local a = AbilityDefinitionEvasion:new(id)
    a:setChancetoEvade(1, 0.0)          -- never actually evades; purely a display marker
    a:setLevels(1)
    a:setHeroAbility(false)
    a:setItemAbility(false)
    a:setName(name)
    a:setTooltipNormal(1, name)
    a:setTooltipNormalExtended(1, tooltip)
    a:setIconNormal(icon)
end

featPassive('fea1', "Feat: Extra Strong", "Gains +2 Strength each level.",     ICON .. "BTNGauntletsOfOgrePower.blp")
featPassive('fea2', "Feat: Extra Fast",   "Gains +2 Agility each level.",      ICON .. "BTNBootsOfSpeed.blp")
featPassive('fea3', "Feat: Extra Smart",  "Gains +2 Intelligence each level.", ICON .. "BTNSobiMask.blp")
featPassive('fea4', "Feat: Iron Skin",    "Gains +1 Armor each level.",        ICON .. "BTNDefend.blp")
