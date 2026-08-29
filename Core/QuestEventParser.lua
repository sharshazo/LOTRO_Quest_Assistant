-- LOTRO_Quest_Assistant/Core/QuestEventParser.lua
import "Turbine"

_G.QuestEventParser = {}

-- NOTA: "misi?n" NUNCA coincidio con "misión" -- el "?" solo hace opcional la
-- segunda "i", no cubre la tilde. Se listan ambas variantes (con y sin tilde)
-- como patrones literales separados, porque Lua no soporta alternancia (a|b)
-- ni clases de caracteres multibyte seguras para UTF-8 como "[oó]".
-- ":%s*" en vez de ": " -- LOTRO a veces pone el nombre de la mision en la
-- siguiente linea (p.ej. "Completado:\nIntro: El cazador exiliado"), y un
-- espacio literal no coincide con un salto de linea.
local PATTERNS = {
    ACCEPTED = {
        "^Nueva misión:%s*(.*)$",
        "^Nueva mision:%s*(.*)$",
        "^New Quest:%s*(.*)$",
        "^Has aceptado la misión:%s*(.*)$",
        "^Has aceptado la mision:%s*(.*)$",
        "^Misión nueva:%s*(.*)$",
        "^Mision nueva:%s*(.*)$",
        "^Has aceptado (.*)$"
    },
    COMPLETED = {
        "^Completado:%s*(.*)$",
        "^Completed:%s*(.*)$",
        "^Misión completada:%s*(.*)$",
        "^Mision completada:%s*(.*)$",
        "^Has completado (.*)$"
    },
    -- BUG (escaneo 2026-08-18): igual que ACCEPTED/COMPLETED/ABANDONED mas
    -- arriba, estos patrones tenian un espacio literal (" (" y ": ") en vez
    -- de "%s*" -- si LOTRO llega a partir "Nombre:" y "2/4" en dos lineas (ya
    -- confirmado que pasa con el nombre de mision completo), el contador de
    -- progreso tampoco coincidiria y la barra se quedaria sin actualizar.
    PROGRESS = {
        "^(.*)%s*%((%d+)/(%d+)%)$",
        "^(.*):%s*(%d+)/(%d+)$"
    },
    ABANDONED = {
        "^Has abandonado la misión:%s*(.*)$",
        "^Has abandonado la mision:%s*(.*)$",
        "^You have abandoned the quest:%s*(.*)$",
        "^Has abandonado:%s*(.*)$"
    }
}

function QuestEventParser.ParseMessage(sender, message)
    if not message then return end
    if LQA.Debug.Enabled then
        Turbine.Shell.WriteLine("<rgb=#FFAA00>QuestSync CHAT INTERCEPT: </rgb>" .. tostring(message))
    end

    -- PROGRESS (Check first since it has numbers at the end)
    for _, pattern in ipairs(PATTERNS.PROGRESS) do
        local desc, cur, max = string.match(message, pattern)
        if desc and cur and max then
            if LQA.Debug.Enabled then
                Turbine.Shell.WriteLine("<rgb=#FFFF00>QuestSync DEBUG: PROGRESS RAW = " .. tostring(message) .. "</rgb>")
                Turbine.Shell.WriteLine("<rgb=#FFFF00>QuestSync DEBUG: PROGRESS TEXT = " .. tostring(desc) .. "</rgb>")
                Turbine.Shell.WriteLine("<rgb=#FFFF00>QuestSync DEBUG: PROGRESS VALUE = " .. cur .. "/" .. max .. "</rgb>")
            end

            local qNameClean = string.gsub(desc, "%.", ""):gsub("^%s*(.-)%s*$", "%1")
            local status, ndx, res = QuestLocResolver.FindQuestByAnyName(qNameClean)

            if status == "SUCCESS" then
                local q = QuestDB.quests[ndx]
                if q then
                    local stateBefore = QuestStateManager.GetQuestState(ndx) or "UNKNOWN"
                    if stateBefore ~= "ACTIVE" then
                        QuestStateManager.SetQuestActive(ndx)
                    end
                    QuestStateManager.UpdateProgress(ndx, cur .. "/" .. max)
                    if LQA.Debug.Enabled then
                        local esName = QuestLocResolver.GetQuestNameES(ndx, q.nameEN)
                        Turbine.Shell.WriteLine("<rgb=#00FF00>QuestSync DEBUG: PROGRESS RESOLUTION = SUCCESS | ndx=" ..
                            tostring(ndx) .. " | NAME ES = " .. tostring(esName) .. "</rgb>")
                    end
                end
            elseif LQA.Debug.Enabled then
                Turbine.Shell.WriteLine("<rgb=#FF0000>QuestSync DEBUG: PROGRESS RESOLUTION = FAIL</rgb>")
            end
            return true
        end
    end

    -- ACCEPTED
    --
    -- BUG (escaneo 2026-08-18, evaluacion de "como se activan las
    -- misiones"): si un patron especifico (p.ej. "Has aceptado la misión:
    -- X") capturaba un nombre pero la resolucion fallaba (quest sin
    -- localizacion, typo, etc.), el bucle seguia probando los patrones MAS
    -- GENERICOS de la misma categoria contra el MISMO mensaje -- p.ej.
    -- "^Has aceptado (.*)$" capturaria "la misión: X" (con el prefijo
    -- incluido, un texto distinto y peor) y reintentaria la resolucion con
    -- eso. En la practica casi siempre fallaba tambien (ruido, no
    -- incorrecto), pero es logicamente fragil: en cuanto un patron coincide
    -- con la SINTAXIS del mensaje, se corta el intento en esta categoria en
    -- vez de seguir degradando la extraccion.
    for _, pattern in ipairs(PATTERNS.ACCEPTED) do
        local qName = string.match(message, pattern)
        if qName then
            local qNameClean = string.gsub(qName, "%.", ""):gsub("^%s*(.-)%s*$", "%1")
            local status, ndx, res = QuestLocResolver.FindQuestByAnyName(qNameClean)
            if status == "SUCCESS" then
                QuestStateManager.SetQuestActive(ndx)
                return true
            end
            if LQA.Debug.Enabled then
                Turbine.Shell.WriteLine("<rgb=#FF0000>QuestSync DEBUG: QUEST NAME RESOLUTION = " ..
                    tostring(status) .. " (" .. tostring(qNameClean) .. ")</rgb>")
            end
            return false
        end
    end

    -- COMPLETED
    -- BUG (encontrado 2026-08-20): FindQuestByAnyName solo desambigua un
    -- nombre compartido por 2+ misiones ("resType=NAME") si hay cadena
    -- "prev" resoluble -- 218/552 grupos de nombre no la tienen y quedaban
    -- en AMBIGUA para siempre. Para ACEPTAR una mision nueva eso es correcto
    -- (no hay que asumir que el jugador ya la tiene activa). Pero para
    -- COMPLETAR/ABANDONAR una mision que YA esta trackeada, ese mismo nombre
    -- ambiguo bloqueaba SIEMPRE el cambio de estado: la mision se quedaba
    -- azul/trackeada para siempre y nunca pasaba a verde, aunque el chat
    -- confirmara la completacion. Aqui, si hay ambiguedad, se resuelve por
    -- "de las candidatas, ¿hay exactamente 1 que el jugador ya tiene
    -- ACTIVA?" -- señal real (no una suposicion), misma logica que ya se usa
    -- para resType=OBJECTIVE en el resolver, aplicada ahora tambien aqui
    -- para el caso NAME que antes quedaba sin cubrir.
    for _, pattern in ipairs(PATTERNS.COMPLETED) do
        local qName = string.match(message, pattern)
        if qName then
            local qNameClean = string.gsub(qName, "%.", ""):gsub("^%s*(.-)%s*$", "%1")
            local status, result = QuestLocResolver.FindQuestByAnyName(qNameClean)
            if status == "SUCCESS" then
                QuestStateManager.SetQuestCompleted(result)
                return true
            elseif status == "AMBIGUA" then
                local activeMatch, activeCount = nil, 0
                for _, cndx in ipairs(result) do
                    if QuestStateManager.State.active[cndx] then
                        activeMatch = cndx
                        activeCount = activeCount + 1
                    end
                end
                if activeCount == 1 then
                    QuestStateManager.SetQuestCompleted(activeMatch)
                    return true
                end
            end
            return false
        end
    end

    -- ABANDONED (mismo fix que COMPLETED arriba, mismo motivo)
    for _, pattern in ipairs(PATTERNS.ABANDONED) do
        local qName = string.match(message, pattern)
        if qName then
            local qNameClean = string.gsub(qName, "%.", ""):gsub("^%s*(.-)%s*$", "%1")
            local status, result = QuestLocResolver.FindQuestByAnyName(qNameClean)
            if status == "SUCCESS" then
                QuestStateManager.SetQuestAbandoned(result)
                return true
            elseif status == "AMBIGUA" then
                local activeMatch, activeCount = nil, 0
                for _, cndx in ipairs(result) do
                    if QuestStateManager.State.active[cndx] then
                        activeMatch = cndx
                        activeCount = activeCount + 1
                    end
                end
                if activeCount == 1 then
                    QuestStateManager.SetQuestAbandoned(activeMatch)
                    return true
                end
            end
            return false
        end
    end

    -- FALLBACK: texto de objetivo/narrativa sin contador ni palabra clave
    -- (p.ej. "recogiste las cartas...", dialogo de NPC al completar una etapa).
    -- Si coincide exactamente con un nombre u objetivo conocido, reafirmamos
    -- el estado ACTIVE y forzamos un refresco de la UI, aunque no cambie el
    -- contador N/M.
    local qNameClean = string.gsub(message, "%.", ""):gsub("^%s*(.-)%s*$", "%1")
    local status, ndx, res = QuestLocResolver.FindQuestByAnyName(qNameClean)
    if status == "SUCCESS" then
        local stateBefore = QuestStateManager.GetQuestState(ndx)
        if stateBefore ~= "ACTIVE" and stateBefore ~= "COMPLETED" then
            -- Solo activamos por esta via si la coincidencia fue por texto de
            -- OBJETIVO, no por NOMBRE: un NPC puede mencionar el nombre de una
            -- mision en dialogo normal sin que el jugador la haya aceptado
            -- (falso positivo), pero un texto de objetivo exacto es mucho mas
            -- especifico y casi nunca aparece fuera de contexto.
            if res == "OBJECTIVE" or res == "OBJECTIVE_CHAIN" then
                QuestStateManager.SetQuestActive(ndx)
            end
        else
            LQA.Core.EventBus:Publish("QUEST_STATE_CHANGED", {ndx=ndx, status=stateBefore})
        end
        return true
    end

    return false
end



