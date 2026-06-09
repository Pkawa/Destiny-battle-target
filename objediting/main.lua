-- Object editing (warcraft-vscode objediting DSL).
--
-- Display-only passive abilities for the STAT feats so a picked feat shows as an icon on
-- the hero's command card. The original applies stat bonuses via a hidden per-level-up
-- trigger with NO ability, so nothing showed. These are based on Evasion (like the map's
-- own Acrobat feat A063:AEev) with 0% chance — they display + do nothing; the real
-- +stat/level effect is applied in src/lib/feats.lua.
--
-- Icon is intentionally NOT overridden: the feat shop items inherit base item 'rag1's
-- Evasion icon, and an Evasion-based ability's default icon is the same Evasion icon — so
-- leaving it default makes the command-card passive match the shop icon. (All four stat
-- feats share that icon; if distinct icons are wanted later, set both the item iico and
-- the ability aart to matching per-feat icons.)
-- Requirements: hero-selection/Feats.md.

-- Cosmetic (0%-evasion) passive that displays as a feat marker on the command card.
local function featPassive(id, name, tooltip)
    local a = AbilityDefinitionEvasion:new(id)
    a:setChancetoEvade(1, 0.0)          -- never actually evades; purely a display marker
    a:setLevels(1)
    a:setHeroAbility(false)
    a:setItemAbility(false)
    a:setName(name)
    a:setTooltipNormal(1, name)
    a:setTooltipNormalExtended(1, tooltip)
end

featPassive('fea1', "Feat: Extra Strong", "Gains +2 Strength each level.")
featPassive('fea2', "Feat: Extra Fast",   "Gains +2 Agility each level.")
featPassive('fea3', "Feat: Extra Smart",  "Gains +2 Intelligence each level.")
featPassive('fea4', "Feat: Iron Skin",    "Gains +1 Armor each level.")
