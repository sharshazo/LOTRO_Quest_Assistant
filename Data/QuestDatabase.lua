-- QuestSync Data/QuestDatabase.lua
-- Master Loader

import "Turbine"
Turbine.Shell.WriteLine("<rgb=#FF8800>QuestDatabase START</rgb>")

_G.QuestDB = {}
_G.QuestDB.quests = {}
Turbine.Shell.WriteLine("<rgb=#FF8800>QuestDatabase OBJECT CREATED</rgb>")

import "LOTRO_Quest_Assistant.Data.QuestDatabase_001"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_002"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_003"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_004"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_005"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_006"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_007"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_008"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_009"
import "LOTRO_Quest_Assistant.Data.QuestDatabase_010"

Turbine.Shell.WriteLine("<rgb=#FF8800>QuestDatabase END</rgb>")
