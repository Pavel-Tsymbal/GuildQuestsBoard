local _, ns = ...

local Catalog = {}
ns.AchievementCatalog = Catalog

Catalog.allById = {}
Catalog.questById = {}
Catalog.questByQuestId = {}
Catalog.speedrunByTargetLevel = {}

local SPEEDRUN_ICON = "Interface\\Icons\\Ability_Rogue_Sprint"

local SPEEDRUN_ACHIEVEMENTS = {
    { id = "SpeedrunnerTen", type = "speedrun", faction = "Common", levelCap = 10, targetLevel = 10, playedTimeThreshold = 2 * 60 * 60, icon = SPEEDRUN_ICON },
    { id = "SpeedrunnerFifteen", type = "speedrun", faction = "Common", levelCap = 15, targetLevel = 15, playedTimeThreshold = 10 * 60 * 60, icon = SPEEDRUN_ICON },
    { id = "SpeedrunnerTwenty", type = "speedrun", faction = "Common", levelCap = 20, targetLevel = 20, playedTimeThreshold = 12 * 60 * 60, icon = SPEEDRUN_ICON },
    { id = "SpeedrunnerThirty", type = "speedrun", faction = "Common", levelCap = 30, targetLevel = 30, playedTimeThreshold = 27 * 60 * 60, icon = SPEEDRUN_ICON },
    { id = "SpeedrunnerForty", type = "speedrun", faction = "Common", levelCap = 40, targetLevel = 40, playedTimeThreshold = 50 * 60 * 60, icon = SPEEDRUN_ICON },
    { id = "SpeedrunnerFortyFive", type = "speedrun", faction = "Common", levelCap = 45, targetLevel = 45, playedTimeThreshold = 65 * 60 * 60, icon = SPEEDRUN_ICON },
    { id = "SpeedrunnerFifty", type = "speedrun", faction = "Common", levelCap = 50, targetLevel = 50, playedTimeThreshold = 81 * 60 * 60, icon = SPEEDRUN_ICON },
    { id = "SpeedrunnerSixty", type = "speedrun", faction = "Common", levelCap = 60, targetLevel = 60, playedTimeThreshold = 120 * 60 * 60, icon = SPEEDRUN_ICON },
}

local QUEST_ACHIEVEMENTS = {
    { id = "DruidOfTheClawQuest", faction = "Alliance", questId = 2561, levelCap = 9, zone = "Teldrassil", questName = "Druid of the Claw", icon = "Interface\\Icons\\Ability_Druid_CatForm" },
    { id = "Vagash", faction = "Alliance", questId = 314, levelCap = 10, zone = "Dun Morogh", questName = "Protecting the Herd", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath" },
    { id = "Hogger", faction = "Alliance", questId = 176, levelCap = 11, zone = "Elwynn Forest", questName = "Wanted: \"Hogger\"", icon = "Interface\\Icons\\INV_Misc_Bone_Skull_01" },
    { id = "RitesOfTheEarthmother", faction = "Horde", questId = 776, levelCap = 11, zone = "Mulgore", questName = "Rites of the Earthmother", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear" },
    { id = "TheFamilyCrypt", faction = "Horde", questId = 408, levelCap = 11, zone = "Tirisfal Glades", questName = "The Family Crypt", icon = "Interface\\Icons\\Spell_Shadow_RaiseDead" },
    { id = "BurningShadows", faction = "Horde", questId = 832, levelCap = 12, zone = "Durotar", questName = "Burning Shadows", icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
    { id = "TheForgottenHeirloom", faction = "Alliance", questId = 64, levelCap = 12, zone = "Westfall", questName = "The Forgotten Heirloom", icon = "Interface\\Icons\\INV_Fabric_Wool_02" },
    { id = "InDefenseOfTheKing", faction = "Alliance", questId = 217, levelCap = 16, zone = "Loch Modan", questName = "In Defense of the King's Land", icon = "Interface\\Icons\\Ability_Warrior_Charge" },
    { id = "AbsentMindedProspector", faction = "Alliance", questId = 731, levelCap = 19, zone = "Darkshore", questName = "Absent Minded Prospector", icon = "Interface\\Icons\\INV_Misc_Spyglass_03" },
    { id = "Counterattack", faction = "Horde", questId = 4021, levelCap = 20, zone = "The Barrens", questName = "Counterattack!", icon = "Interface\\Icons\\Ability_Warrior_Charge" },
    { id = "EarthenArise", faction = "Horde", questId = 6481, levelCap = 20, zone = "Stonetalon Mountains", questName = "Earthen Arise", icon = "Interface\\Icons\\Spell_Nature_Earthquake" },
    { id = "TheWeaver", faction = "Horde", questId = 480, levelCap = 20, zone = "Silverpine Forest", questName = "The Weaver", icon = "Interface\\Icons\\Spell_Arcane_StarFire" },
    { id = "Fangore", faction = "Alliance", questId = 180, levelCap = 23, zone = "Redridge", questName = "Wanted: Lieutenant Fangore", icon = "Interface\\Icons\\INV_Sword_04" },
    { id = "MageSummoner", faction = "Alliance", questId = 1017, levelCap = 23, zone = "Ashenvale", questName = "Mage Summoner", icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing" },
    { id = "TheHuntCompleted", faction = "Horde", questId = 247, levelCap = 26, zone = "Ashenvale", questName = "The Hunt Completed", icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
    { id = "TestOfEndurance", faction = "Horde", questId = 1150, levelCap = 30, zone = "Thousand Needles", questName = "Test of Endurance", icon = "Interface\\Icons\\Ability_Hunter_EagleEye" },
    { id = "DefeatNekrosh", faction = "Alliance", questId = 474, levelCap = 31, zone = "Wetlands", questName = "Defeath Nek'rosh", icon = "Interface\\Icons\\Ability_Warrior_Cleave" },
    { id = "BattleOfHillsbrad", faction = "Horde", questId = 550, levelCap = 33, zone = "Hillsbrad Foothills", questName = "Battle of Hillsbrad", icon = "Interface\\Icons\\INV_Sword_04" },
    { id = "Morladim", faction = "Alliance", questId = 228, levelCap = 33, zone = "Duskwood", questName = "Mor'Ladim", icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
    { id = "HintsOfANewPlague", faction = "Alliance", questId = 658, levelCap = 34, zone = "Hillsbrad Foothills", questName = "Hints of a New Plague", icon = "Interface\\Icons\\INV_Potion_04" },
    { id = "StinkysEscape", faction = "Common", questId = 1270, questIdAlt = 1222, levelCap = 34, zone = "Dustwallow Marsh", questName = "Stinky's Escape", icon = "Interface\\Icons\\INV_Misc_Foot_Centaur" },
    { id = "GalensEscape", faction = "Common", questId = 1393, levelCap = 38, zone = "Swamp of Sorrows", questName = "Galen's Escape", icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { id = "KingOfTheJungle", faction = "Common", questId = 208, levelCap = 39, zone = "Stranglethorn Vale", questName = "Big Game Hunter", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath" },
    { id = "NothingButTheTruth", faction = "Horde", questId = 1383, levelCap = 40, zone = "Duskwood", questName = "Nothing but the Truth", icon = "Interface\\Icons\\INV_Potion_04" },
    { id = "SealOfEarth", faction = "Horde", questId = 782, levelCap = 40, zone = "Badlands", questName = "Broken Alliances", icon = "Interface\\Icons\\Spell_Nature_EarthBind" },
    { id = "TremorsOfEarth", faction = "Alliance", questId = 732, levelCap = 40, zone = "Badlands", questName = "Tremors of the Earth", icon = "Interface\\Icons\\Spell_Nature_EarthBind" },
    { id = "GetMeOutOfHere", faction = "Common", questId = 6132, levelCap = 41, zone = "Desolace", questName = "Get Me Out of Here!", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { id = "AgainstLordShalzaru", faction = "Alliance", questId = 2870, levelCap = 43, zone = "Feralas", questName = "Against Lord Shalzaru", icon = "Interface\\Icons\\Ability_Rogue_SliceDice" },
    { id = "TheCrownOfWill", faction = "Horde", questId = 521, levelCap = 43, zone = "Alterac Mountains", questName = "The Crown of Will", icon = "Interface\\Icons\\INV_Crown_02" },
    { id = "CuergosGold", faction = "Common", questId = 2882, levelCap = 45, zone = "Tanaris", questName = "Cuergo's Gold", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
    { id = "DarkHeart", faction = "Horde", questId = 3062, levelCap = 48, zone = "Feralas", questName = "Dark Heart", icon = "Interface\\Icons\\Ability_Hunter_EagleEye" },
    { id = "KimjaelIndeed", faction = "Common", questId = 3601, levelCap = 51, zone = "Azshara", questName = "Kim'Jael Indeed!", icon = "Interface\\Icons\\INV_Misc_Book_11" },
    { id = "Kromgrul", faction = "Horde", questId = 3822, levelCap = 51, zone = "Burning Steppes", questName = "Krom'Grul", icon = "Interface\\Icons\\INV_Misc_Bone_Skull_01" },
    { id = "TheStonesThatBindUs", faction = "Common", questId = 2681, levelCap = 54, zone = "Blasted Lands", questName = "The Stones That Bind Us", icon = "Interface\\Icons\\Spell_Nature_Strength" },
    { id = "AFinalBlow", faction = "Common", questId = 5242, levelCap = 55, zone = "Felwood", questName = "A Final Blow", icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges" },
    { id = "SummoningThePrincess", faction = "Common", questId = 656, levelCap = 55, zone = "Arathi Highlands", questName = "Summoning the Princess", icon = "Interface\\Icons\\Spell_Nature_Earthquake" },
    { id = "Maltorious", faction = "Common", questId = 7701, levelCap = 56, zone = "Searing Gorge", questName = "WANTED: Overseer Maltorious", icon = "Interface\\Icons\\INV_Hammer_05" },
    { id = "PawnCapturesQueen", faction = "Common", questId = 4507, levelCap = 56, zone = "Un'Goro Crater", questName = "Pawn Captures Queen", icon = "Interface\\Icons\\INV_Misc_MonsterClaw_04" },
    { id = "RecoverTheKey", faction = "Horde", questId = 7846, levelCap = 56, zone = "Hinterlands", questName = "Recover the Key", icon = "Interface\\Icons\\INV_Misc_Key_03" },
    { id = "DragonkinMenace", faction = "Alliance", questId = 4182, levelCap = 57, zone = "Burning Steppes", questName = "Dragonkin Menace", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
    { id = "OfForgottenMemories", faction = "Common", questId = 5781, levelCap = 57, zone = "Eastern Plaguelands", questName = "Of Forgotten Memories", icon = "Interface\\Icons\\Spell_Shadow_RaiseDead" },
    { id = "Deathclasp", faction = "Common", questId = 8283, levelCap = 59, zone = "Silithus", questName = "Wanted: Deathclasp, Terror of the Sands", icon = "Interface\\Icons\\INV_Misc_Bone_Skull_01" },
    { id = "HighChiefWinterfall", faction = "Common", questId = 5121, levelCap = 59, zone = "Winterspring", questName = "High Chief Winterfall", icon = "Interface\\Icons\\INV_Misc_Head_Centaur_01" },
}

for _, entry in ipairs(QUEST_ACHIEVEMENTS) do
    entry.type = entry.type or "quest"
    Catalog.allById[entry.id] = entry
    Catalog.questById[entry.id] = entry
    Catalog.questByQuestId[entry.questId] = entry
    if entry.questIdAlt then
        Catalog.questByQuestId[entry.questIdAlt] = entry
    end
end

for _, entry in ipairs(SPEEDRUN_ACHIEVEMENTS) do
    Catalog.allById[entry.id] = entry
    Catalog.speedrunByTargetLevel[entry.targetLevel] = entry
end

function Catalog:GetPlayerFaction()
    return UnitFactionGroup("player")
end

function Catalog:CanPlayerEarn(entry, playerFaction)
    if not entry then
        return false
    end
    playerFaction = playerFaction or self:GetPlayerFaction()
    if entry.faction == "Horde" then
        return playerFaction == "Horde"
    end
    if entry.faction == "Alliance" then
        return playerFaction == "Alliance"
    end
    return true
end

function Catalog:PassesFilter(entry, filters, playerFaction)
    if not entry then
        return false
    end
    if not self:CanPlayerEarn(entry, playerFaction) then
        return false
    end
    if filters and filters.excludeSpeedrun and entry.type == "speedrun" then
        return false
    end
    return true
end

function Catalog:SortEntries(list)
    table.sort(list, function(a, b)
        if a.levelCap ~= b.levelCap then
            return a.levelCap < b.levelCap
        end
        return self:GetTitle(a) < self:GetTitle(b)
    end)
    return list
end

function Catalog:CountEarnable()
    local count = 0
    local playerFaction = self:GetPlayerFaction()
    for _, entry in ipairs(QUEST_ACHIEVEMENTS) do
        if self:CanPlayerEarn(entry, playerFaction) then
            count = count + 1
        end
    end
    for _, entry in ipairs(SPEEDRUN_ACHIEVEMENTS) do
        if self:CanPlayerEarn(entry, playerFaction) then
            count = count + 1
        end
    end
    return count
end

function Catalog:GetAchievements(filters)
    local list = {}
    local playerFaction = self:GetPlayerFaction()
    filters = filters or {}
    for _, entry in ipairs(QUEST_ACHIEVEMENTS) do
        if self:PassesFilter(entry, filters, playerFaction) then
            list[#list + 1] = entry
        end
    end
    for _, entry in ipairs(SPEEDRUN_ACHIEVEMENTS) do
        if self:PassesFilter(entry, filters, playerFaction) then
            list[#list + 1] = entry
        end
    end
    return self:SortEntries(list)
end

function Catalog:GetQuestAchievements()
    return self:GetAchievements()
end

function Catalog:GetHordeQuests()
    return self:GetAchievements()
end

function Catalog:FindByQuery(query)
    if not query or query == "" then
        return nil
    end
    query = query:lower()
    local exact = self:GetById(query)
    if exact then
        return exact
    end
    for id, entry in pairs(self.allById) do
        if id:lower() == query then
            return entry
        end
    end
    for id, entry in pairs(self.allById) do
        if id:lower():find(query, 1, true) then
            return entry
        end
    end
end

function Catalog:GetSpeedrunByTargetLevel(level)
    return self.speedrunByTargetLevel[tonumber(level)]
end

function Catalog:GetDefaultTestEntry()
    return self:GetById("StinkysEscape") or self:GetAchievements()[1]
end

function Catalog:GetById(id)
    return self.allById[id]
end

function Catalog:GetByQuestId(questId)
    return self.questByQuestId[questId]
end

function Catalog:GetTitle(entry)
    if not entry then
        return "?"
    end
    local key = "ACHIEV_" .. entry.id .. "_TITLE"
    return ns.L[key] or entry.id
end

function Catalog:GetDescription(entry)
    if not entry then
        return ""
    end
    local key = "ACHIEV_" .. entry.id .. "_DESC"
    return ns.L[key] or ""
end

function Catalog:GetLevelCapText(entry)
    if not entry then
        return ""
    end
    if entry.type == "speedrun" then
        return string.format(
            ns.L["ACHIEV_SPEEDRUN_META"],
            entry.targetLevel or entry.levelCap,
            (entry.playedTimeThreshold or 0) / 3600
        )
    end
    return string.format(ns.L["ACHIEV_LEVEL_CAP"], entry.levelCap + 1)
end

function Catalog:GetFactionLabel(entry)
    if not entry then
        return ""
    end
    if entry.type == "speedrun" then
        return ns.L["ACHIEV_TYPE_SPEEDRUN"]
    end
    if not entry.faction then
        return ""
    end
    if entry.faction == "Horde" then
        return ns.L["ACHIEV_FACTION_HORDE"]
    end
    if entry.faction == "Alliance" then
        return ns.L["ACHIEV_FACTION_ALLIANCE"]
    end
    return ns.L["ACHIEV_FACTION_COMMON"]
end

function Catalog:GetFactionColor(entry)
    if not entry then
        return 0.7, 0.7, 0.7
    end
    if entry.type == "speedrun" then
        return 1.0, 0.55, 0.0
    end
    if not entry.faction then
        return 0.7, 0.7, 0.7
    end
    if entry.faction == "Horde" then
        return 0.55, 0.09, 0.09
    end
    if entry.faction == "Alliance" then
        return 0.0, 0.29, 0.58
    end
    return 0.7, 0.7, 0.7
end

function Catalog:GetFactionTagText(entry)
    local label = self:GetFactionLabel(entry)
    if label == "" then
        return ""
    end
    local r, g, b = self:GetFactionColor(entry)
    return string.format(
        "|cff%02x%02x%02x%s|r",
        math.floor(r * 255),
        math.floor(g * 255),
        math.floor(b * 255),
        label
    )
end
