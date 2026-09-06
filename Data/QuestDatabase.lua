-- QuestSync Data/QuestDatabase.lua
-- Master Loader

import "Turbine"
-- Ruido de chat en cada carga/reload (pedido explicito del usuario:
-- "cierra los ruidos en el chat") -- quedaban sin apagador desde que se
-- escribieron, a diferencia del resto del addon (LQA.Debug.Enabled ya
-- esta disponible aca, EventBus.lua carga primero, ver Main.lua).
if LQA.Debug.Enabled then
    Turbine.Shell.WriteLine("<rgb=#FF8800>QuestDatabase START</rgb>")
end

_G.QuestDB = {}
_G.QuestDB.quests = {}
if LQA.Debug.Enabled then
    Turbine.Shell.WriteLine("<rgb=#FF8800>QuestDatabase OBJECT CREATED</rgb>")
end

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

if LQA.Debug.Enabled then
    Turbine.Shell.WriteLine("<rgb=#FF8800>QuestDatabase END</rgb>")
end
