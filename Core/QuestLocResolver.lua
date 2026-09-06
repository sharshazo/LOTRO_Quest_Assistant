-- LOTRO_Quest_Assistant/Core/QuestLocResolver.lua
import "Turbine"

_G.QuestLocResolver = {}

function QuestLocResolver.GetQuestNameES(ndx_or_nameEN, fallbackEN)
    local ndx = nil
    if type(ndx_or_nameEN) == "number" then
        ndx = ndx_or_nameEN
    elseif type(ndx_or_nameEN) == "string" then
        ndx = QuestNameIndex and QuestNameIndex[string.lower(ndx_or_nameEN)]
    end
    
    if ndx and QuestLocES and QuestLocES[ndx] then
        local entry = QuestLocES[ndx]
        if type(entry) == "table" and entry.nameES then
            return entry.nameES
        elseif type(entry) == "string" then
            return entry
        end
    end
    return fallbackEN
end

-- BUG (encontrado en escaneo 2026-08-18): la version anterior usaba una
-- character class "[ÁÉÍÓÚÑÜ]" para elegir que reemplazar. En UTF-8 cada
-- letra ocupa 2 bytes, y una character class en Lua compara byte a byte,
-- no caracter a caracter -- así que en la práctica esa clase nunca
-- encontraba las secuencias completas y el gsub no reemplazaba nada.
-- Ademas string.lower() de Lua es solo-ASCII y deja intactas las
-- mayusculas acentuadas. Resultado: cualquier texto de chat con una
-- mayuscula acentuada (frecuente al inicio de una oracion en español,
-- p.ej. "Único", "Área") nunca coincidia con las claves en minuscula de
-- QuestNameESIndex/QuestObjectiveESIndex (esas si estan bien minusculizadas,
-- se generaron con Python). Aqui se reemplaza cada secuencia de 2 bytes
-- completa de forma literal, no por clase de caracteres.
-- Movida a nivel de modulo (2026-08-20, antes vivia solo dentro de
-- FindQuestByAnyName) y expuesta como QuestLocResolver.NormalizeES para que
-- el buscador de QuestSyncWindow.lua use la MISMA normalizacion en vez de
-- duplicar esta logica -- justo el patron de "la misma logica repetida en 2
-- lugares" que ya causo el bug de "misi?n" y el de mapID=0 antes.
local function toLowerES(s)
    local lower_s = string.lower(s)
    local accentPairs = {
        {"\195\129", "\195\161"}, -- Á -> á
        {"\195\137", "\195\169"}, -- É -> é
        {"\195\141", "\195\173"}, -- Í -> í
        {"\195\147", "\195\179"}, -- Ó -> ó
        {"\195\154", "\195\186"}, -- Ú -> ú
        {"\195\145", "\195\177"}, -- Ñ -> ñ
        {"\195\156", "\195\188"}, -- Ü -> ü
    }
    for _, pair in ipairs(accentPairs) do
        lower_s = string.gsub(lower_s, pair[1], pair[2])
    end
    lower_s = string.gsub(lower_s, "%s+", " ")
    lower_s = string.gsub(lower_s, "^%s*(.-)%s*$", "%1")
    return lower_s
end

function QuestLocResolver.NormalizeES(s)
    if not s or s == "" then return "" end
    return toLowerES(s)
end

-- Filtro de texto de dialogo/exclamacion de PNJ vs. objetivo real, extraido
-- de UI/QuestInfoTooltip.lua (2026-08-28) para que QuestBookWindow.lua use
-- el MISMO filtro en vez de duplicarlo -- ver la nota grande junto a
-- MoorMapAdapter.ResolveMapID sobre por que "la misma logica repetida en 2
-- lugares" ya causo bugs reales en este addon. Logica sin cambios: se
-- descarta cualquier entrada vacia, con placeholder "${...}" sin resolver,
-- igual al nombre de la mision, o que empiece con comilla/exclamacion/
-- interrogacion (marcas de dialogo citado). string.sub() opera por BYTES
-- -- "¡"/"¿" ocupan 2 bytes en UTF-8, por eso se comparan los primeros 2
-- bytes contra esos literales, no 1 caracter.
local function isCleanText(s)
    return s ~= nil and s ~= "" and not string.find(s, "${", 1, true)
end

function QuestLocResolver.IsFlavorText(s, nameEN)
    if not isCleanText(s) then return true end
    if s == nameEN then return true end
    local first1 = string.sub(s, 1, 1)
    local first2 = string.sub(s, 1, 2)
    if first1 == "'" or first1 == '"' then return true end
    if first2 == "¡" or first2 == "¿" then return true end
    return false
end

-- Hasta maxLines entradas LIMPIAS de QuestLocES[ndx].objectivesES (sin
-- dialogo/exclamacion de PNJ, ver IsFlavorText), en el orden en que
-- aparezcan -- nunca inventa texto, solo filtra mejor lo que LOTRO
-- Companion ya extrajo. Devuelve {} (nunca nil) si no hay nada limpio.
function QuestLocResolver.GetCleanObjectiveLines(ndx, quest, maxLines)
    local lines = {}
    local loc = _G.QuestLocES and _G.QuestLocES[ndx]
    local obj = loc and type(loc) == "table" and loc.objectivesES
    if obj and type(obj) == "table" then
        for i = 1, #obj do
            if not QuestLocResolver.IsFlavorText(obj[i], quest and quest.nameEN) then
                table.insert(lines, obj[i])
                if #lines >= (maxLines or 2) then break end
            end
        end
    end
    return lines
end

function QuestLocResolver.FindQuestByAnyName(nameRaw)
    if not nameRaw or nameRaw == "" then return "FAIL", nil, "No input" end

    local cleanName = toLowerES(nameRaw)

    -- Priority 1: Exact Match in Spanish / English (QuestNameESIndex mapping)
    local ndxs = QuestNameESIndex and QuestNameESIndex[cleanName]
    local resType = "NAME"

    if not ndxs then
        ndxs = QuestObjectiveESIndex and QuestObjectiveESIndex[cleanName]
        resType = "OBJECTIVE"
    end

    if not ndxs then
        -- Fallback to old english index if needed
        local ndx = QuestNameIndex and QuestNameIndex[cleanName]
        if ndx then ndxs = { ndx } end
    end

    if not ndxs then
        if LQA.Debug.Enabled then
            Turbine.Shell.WriteLine("<rgb=#FFFF00>QuestSync DEBUG: Candidates = NONE (" .. tostring(cleanName) .. ")</rgb>")
        end
        return "FAIL", nil, "No match"
    end

    -- Parse ndxs list (stored as "123,456" in string if multiple, or just number if single)
    local candidates = {}
    if type(ndxs) == "table" then
        candidates = ndxs
    elseif type(ndxs) == "number" then
        candidates = { ndxs }
    elseif type(ndxs) == "string" then
        for n in string.gmatch(ndxs, "%d+") do
            table.insert(candidates, tonumber(n))
        end
    end

    if #candidates == 1 then
        if LQA.Debug.Enabled then
            Turbine.Shell.WriteLine("<rgb=#FFFF00>QuestSync DEBUG: Runtime QuestID = " .. tostring(candidates[1]) .. "</rgb>")
        end
        return "SUCCESS", candidates[1], resType
    end

    -- BUG (escaneo 2026-08-18, fiabilidad de activacion en tiempo real):
    -- 552 nombres y 69 textos de objetivo de la base los comparten 2+
    -- misiones (verificado con un script Python contra los indices
    -- reales). La desambiguacion por cadena "prev" de abajo solo puede
    -- resolver un grupo si AL MENOS una candidata tiene datos de prev -- 218
    -- de los 552 grupos de nombre y 48 de los 69 de objetivo no tienen
    -- ningun candidato con prev, asi que nunca se resolvian por chat en
    -- absoluto (quedaban en AMBIGUA para siempre, sin importar el progreso
    -- del jugador) -- el sintoma exacto de "esta mision nunca se activa
    -- sola" que reporto el usuario. Se agrega una señal MEJOR y disponible
    -- antes que la cadena de prev: si el jugador YA tiene exactamente una
    -- de las candidatas marcada ACTIVA en nuestro propio registro (p.ej. un
    -- contador de progreso "(N/M)" que coincide con el objetivo compartido
    -- de una mision que ya esta activa), esa es casi con certeza la
    -- correcta -- es mas confiable que inferir por cadena, porque no es una
    -- suposicion: es el estado real que el jugador ya confirmo al aceptarla.
    --
    -- IMPORTANTE: solo para resType=="OBJECTIVE" (coincidencia por texto de
    -- objetivo/progreso, lo que usan PROGRESS y el fallback narrativo), NO
    -- para "NAME" (lo que usa ACCEPTED). Si se aplicara tambien a NAME,
    -- aceptar una mision NUEVA que comparte nombre con una YA activa (p.ej.
    -- la 2da de 3 "Ithildín Coin" mientras la 1ra sigue activa) resolveria
    -- mal hacia la vieja -- SetQuestActive(vieja) es un no-op porque ya
    -- esta activa, y la nueva nunca se activa. Para PROGRESS ese riesgo no
    -- existe: el contador "(N/M)" siempre pertenece a una mision que el
    -- jugador ya tiene activa, nunca a una recien aceptada.
    if QuestStateManager and resType == "OBJECTIVE" then
        local activeMatch, activeCount = nil, 0
        for _, cndx in ipairs(candidates) do
            if QuestStateManager.State.active[cndx] then
                activeMatch = cndx
                activeCount = activeCount + 1
            end
        end
        if activeCount == 1 then
            if LQA.Debug.Enabled then
                Turbine.Shell.WriteLine("<rgb=#00FFFF>QuestSync DEBUG: AMBIGUA -> desambiguada por mision ya activa = " .. tostring(activeMatch) .. "</rgb>")
            end
            return "SUCCESS", activeMatch, resType .. "_ACTIVE"
        end
    end

    -- Varias quests comparten el mismo nombre/texto (p.ej. ramas paralelas de
    -- una introduccion, una para cada bestower). Regla #10 y #42 del
    -- documento maestro: nunca elegir al azar, pero SI se puede desambiguar
    -- por continuidad de cadena -- si el jugador ya completo o tiene activa
    -- alguna de las quests "prev" de exactamente una candidata, esa es la
    -- correcta.
    local best, bestScore, tie = nil, 0, false
    for _, cndx in ipairs(candidates) do
        local q = QuestDB and QuestDB.quests and QuestDB.quests[cndx]
        if q and q.prev then
            local score = 0
            for _, pndx in ipairs(q.prev) do
                local pstate = QuestStateManager and QuestStateManager.GetQuestState(pndx)
                if pstate == "COMPLETED" or pstate == "ACTIVE" then
                    score = score + 1
                end
            end
            if score > bestScore then
                best, bestScore, tie = cndx, score, false
            elseif score > 0 and score == bestScore then
                tie = true
            end
        end
    end

    if best and bestScore > 0 and not tie then
        if LQA.Debug.Enabled then
            Turbine.Shell.WriteLine("<rgb=#00FFFF>QuestSync DEBUG: AMBIGUA -> desambiguada por cadena previa = " .. tostring(best) .. "</rgb>")
        end
        return "SUCCESS", best, resType .. "_CHAIN"
    end

    return "AMBIGUA", candidates, resType
end