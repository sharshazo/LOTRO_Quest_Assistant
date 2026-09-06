-- LOTRO_Quest_Assistant/Core/GatherEventParser.lua
-- Detecta en el chat cuando el jugador recolecta un nodo de una profesion de
-- recoleccion (Minero/Leñador/Granjero/Erudito). Mismo esqueleto que
-- Core/QuestEventParser.lua -- ver Arquitectura_GatherSync.md #3.2 para el
-- ejemplo real de chat que confirmo estos 2 patrones.
--
-- Ejemplo real de chat (minando una veta de cobre):
--   Has ganado 24 de experiencia para un total de 855,787 de experiencia.
--   Tomando los contenidos de los Veta de cobre...
--   Has adquirido: [Piedra de afilar rudimentaria].
--   Has adquirido: [2 Bloques de mineral de cobre].
--
-- La linea "Tomando los contenidos de X..." es el disparador PRINCIPAL: nombra
-- el nodo directamente, sin ambiguedad, y es el momento correcto para capturar
-- la coordenada (ver Legacy/LocationAdapter.lua). El articulo antes del
-- nombre del nodo varia segun genero/numero (salio "de los Veta de cobre" en
-- la captura real, con concordancia rara) -- por eso el patron captura texto
-- libre en vez de anclarse a un articulo fijo.
--
-- Las lineas "Has adquirido: [item]" son secundarias: confirman que
-- materiales concretos salieron (utiles para el detalle del punto guardado)
-- pero no hace falta que coincidan para saber que hubo un evento de
-- recoleccion -- eso ya lo dio la linea del nodo.
import "Turbine"

_G.GatherEventParser = {}

-- NODE ya no ancla el sufijo "..." en el patron -- se probo en vivo
-- (2026-08-23) y el mensaje real es "Tomando los contenidos de los Veta de
-- cobre..." donde el "..." final puede ser 3 puntos literales O el caracter
-- unicode de puntos suspensivos (U+2026, "\226\128\166" en UTF-8) segun como
-- lo mande el cliente -- adivinar cual de los 2 rompia el patron en silencio
-- (nodeNameRaw quedaba nil, ni el caso exito ni el de error se disparaban).
-- Ahora se captura TODO lo que sigue y se limpia en CleanNodeName().
local PATTERNS = {
    NODE = "^Tomando los contenidos de%s+(.+)$",
    ITEM = "^Has adquirido: %[(.-)%]%.$",
}

-- Mismo motivo que arriba: el mensaje real trae un articulo de mas antes del
-- nombre del nodo ("...de los Veta de cobre...", con "los" fijo sin importar
-- genero/numero real -- probablemente una plantilla generica del cliente).
-- GatherNodesDB.byNode esta indexado SIN articulo, asi que hay que sacarlo
-- antes de buscar. Loop en vez de patron con alternancia porque Lua no
-- soporta "(a|b|c)" en sus patrones.
local ARTICLES = { "el ", "la ", "los ", "las ", "un ", "una " }
local ELLIPSIS_UTF8 = "\226\128\166" -- U+2026 "…" en UTF-8

local function CleanNodeName(raw)
    local name = string.gsub(raw, "^%s*(.-)%s*$", "%1")
    name = string.gsub(name, "%.+$", "")
    name = string.gsub(name, ELLIPSIS_UTF8 .. "+$", "")
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    for _, article in ipairs(ARTICLES) do
        if string.sub(name, 1, #article) == article then
            name = string.sub(name, #article + 1)
            break
        end
    end
    return name
end

-- Separa una cantidad al frente ("2 Bloques de mineral de cobre" -> "Bloques
-- de mineral de cobre") -- GatherNodesDB.byItem esta indexado por el nombre
-- SIN cantidad.
local function StripQuantity(text)
    local rest = string.match(text, "^%d+%s+(.+)$")
    return rest or text
end

-- Ultimo nodo detectado por la linea "Tomando los contenidos de X..." --
-- las lineas "Has adquirido" que le siguen en el mismo evento de recoleccion
-- se acumulan aca hasta que EventBus dispara la captura de coordenada.
local pendingNode = nil
local pendingItems = nil
local pendingNodeTime = nil

-- El flujo soportado hoy (ver Arquitectura_GatherSync.md #6, Plan B) es
-- MANUAL: el jugador recolecta y despues escribe /loc el mismo a mano.
-- LocationAdapter.ParseLocationMessage procesa CUALQUIER respuesta de /loc,
-- sin importar por que se disparo -- si el jugador recolecta un nodo, se
-- distrae, camina a otro lado y recien ahi escribe /loc (por curiosidad, o
-- por otro addon que lo dispare), pendingNode seguia ahi indefinidamente y
-- ese /loc tardio le pegaba la coordenada NUEVA (equivocada) al nodo VIEJO.
-- 90s alcanza de sobra para el uso real (leer el loot + escribir /loc a
-- mano toma segundos, no minutos) sin ser tan corto como para descartar un
-- /loc levemente demorado.
local PENDING_TIMEOUT_SECONDS = 90

function GatherEventParser.ParseMessage(sender, message)
    if not message then return false end
    if LQA.Debug.Enabled then
        Turbine.Shell.WriteLine("<rgb=#00AAFF>GatherSync CHAT INTERCEPT: </rgb>" .. tostring(message))
    end

    local nodeNameRaw = string.match(message, PATTERNS.NODE)
    if nodeNameRaw ~= nil then
        local nodeName = CleanNodeName(nodeNameRaw)
        local entry = _G.GatherNodesDB.byNode[nodeName]
        if entry == nil then
            -- Confirmacion siempre visible (no gateada) mientras se valida
            -- el flujo end-to-end -- ver nota igual en GatherPointsStore.lua.
            Turbine.Shell.WriteLine("<rgb=#FF0000>GatherSync: nodo detectado en el chat pero NO esta en GatherNodesDB -> \"" ..
                tostring(nodeName) .. "\"</rgb>")
            pendingNode = nil
            pendingItems = nil
            pendingNodeTime = nil
            return false
        end

        pendingNode = entry
        pendingItems = {}
        pendingNodeTime = Turbine.Engine.GetGameTime()
        Turbine.Shell.WriteLine("<rgb=#00FF00>GatherSync: nodo reconocido -> " ..
            tostring(nodeName) .. " | " .. tostring(entry.profession) ..
            " tier " .. tostring(entry.tier) .. " (confianza=" .. tostring(entry.confidence) .. ")</rgb>")

        -- Dispara la captura de coordenada YA -- no esperamos a las lineas de
        -- "Has adquirido" porque no todas llegan en el mismo tick de chat.
        LQA.Core.EventBus:Publish("GATHER_NODE_DETECTED", { entry = entry, nodeName = nodeName })
        return true
    end

    local itemTextRaw = string.match(message, PATTERNS.ITEM)
    if itemTextRaw ~= nil then
        local itemName = StripQuantity(itemTextRaw)
        local entry = _G.GatherNodesDB.byItem[itemName]
        if entry ~= nil then
            if pendingNode ~= nil and pendingItems ~= nil then
                table.insert(pendingItems, itemName)
            end
            if LQA.Debug.Enabled then
                Turbine.Shell.WriteLine("<rgb=#00FF00>GatherSync DEBUG: item reconocido = " ..
                    tostring(itemName) .. " | profesion=" .. tostring(entry.profession) ..
                    " | tier=" .. tostring(entry.tier) .. "</rgb>")
            end
            LQA.Core.EventBus:Publish("GATHER_ITEM_RECEIVED", { entry = entry, itemName = itemName })
            return true
        end
        -- No es un material de recoleccion conocido (loot normal de mob,
        -- misiones, etc.) -- se ignora en silencio, no es un error.
        return false
    end

    return false
end

-- Devuelve el ultimo nodo detectado y los items acumulados desde entonces
-- (usado por LocationAdapter.lua al confirmar la coordenada, ver
-- Arquitectura_GatherSync.md #3.3/#3.4) y limpia el estado pendiente.
--
-- BUG REAL encontrado en revision (2026-08-27): GatherNodesDB.byNode es un
-- diccionario plano por nombre ES -- cuando 2 tiers distintos comparten el
-- MISMO nombre de nodo en español (pasa con Erudito T3 "Antique Vase" vs T5
-- "Ancient Vase", ambos "Jarrón antiguo" en el diccionario oficial, ver
-- LOTRO_recoleccion_tiers.md linea 162 y el comentario en
-- Data/GatherNodesDB.lua junto al registro de T5), la linea del NODO siempre
-- resuelve al tier que se registro primero (T3) -- el T5 quedaba SIEMPRE mal
-- guardado como T3, sin ningun aviso, y esa etiqueta erronea se propagaba
-- ademas a la anotacion de MoorMap (Main.lua GATHER_POINT_ADDED). Los nombres
-- de ITEM si son unicos entre tiers (confirmado por ID en el diccionario), asi
-- que si alguno de los items recibidos en este mismo evento resuelve a una
-- entrada mas especifica (mismo profession, pero objeto de tier distinto),
-- se prefiere esa sobre la resuelta por nombre de nodo.
local function _ResolveMoreSpecificEntry(nodeEntry, items)
    if nodeEntry == nil or items == nil then
        return nodeEntry
    end
    for _, itemName in ipairs(items) do
        local itemEntry = _G.GatherNodesDB.byItem[itemName]
        if itemEntry ~= nil and itemEntry.profession == nodeEntry.profession and itemEntry ~= nodeEntry then
            return itemEntry
        end
    end
    return nodeEntry
end

function GatherEventParser.ConsumePendingGather()
    local node, items, nodeTime = pendingNode, pendingItems, pendingNodeTime
    pendingNode = nil
    pendingItems = nil
    pendingNodeTime = nil

    if node == nil then
        return nil, nil
    end

    -- Ver nota de PENDING_TIMEOUT_SECONDS arriba: un /loc que llega mucho
    -- despues del nodo detectado probablemente no le corresponde (el
    -- jugador ya se movio) -- se descarta en vez de guardar una coordenada
    -- equivocada. Aviso siempre visible (mismo criterio que el resto de
    -- este archivo) para que el jugador entienda por que no se guardo nada.
    local elapsed = nodeTime ~= nil and (Turbine.Engine.GetGameTime() - nodeTime) or nil
    if elapsed ~= nil and elapsed > PENDING_TIMEOUT_SECONDS then
        Turbine.Shell.WriteLine("<rgb=#FF0000>GatherSync: /loc llego " ..
            string.format("%.0f", elapsed) .. "s despues del nodo detectado (\"" ..
            tostring(node.node) .. "\") -- descartado por posible desactualizacion, punto NO guardado.</rgb>")
        return nil, nil
    end

    return _ResolveMoreSpecificEntry(node, items), items
end
