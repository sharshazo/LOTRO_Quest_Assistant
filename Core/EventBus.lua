-- LOTRO_Quest_Assistant/Core/EventBus.lua
_G.LQA = _G.LQA or {}
LQA.Core = LQA.Core or {}
LQA.Data = LQA.Data or {}
LQA.UI = LQA.UI or {}
LQA.Map = LQA.Map or {}
LQA.Nav = LQA.Nav or {}
LQA.Localization = LQA.Localization or {}
LQA.Debug = LQA.Debug or {}
-- Interruptor unico de depuracion para todo el addon (EventBus, parser de
-- chat, resolver, MoorMap). En false por defecto para uso real: docenas de
-- lineas de color por cada mensaje de chat / cambio de estado son utiles
-- para diagnosticar pero son ruido puro en una sesion de juego normal.
-- Cambiar a true solo cuando se este investigando un problema.
LQA.Debug.Enabled = false

LQA.Core.EventBus = {
    listeners = {}
}

function LQA.Core.EventBus:Subscribe(eventName, callback)
    if not self.listeners[eventName] then
        self.listeners[eventName] = {}
    end
    table.insert(self.listeners[eventName], callback)
end

function LQA.Core.EventBus:Publish(eventName, data)
    if LQA.Debug.Enabled then
        -- BUG (escaneo 2026-08-18): este texto no tenia el prefijo "QuestSync:"
        -- ni las etiquetas <rgb=...> que Main.lua usa para reconocer y
        -- descartar nuestros propios mensajes de depuracion (ver OnChatReceived
        -- en Main.lua). Sin eso, CADA publicacion de evento se reenviaba al
        -- parser de chat como si fuera un mensaje real del juego -- ruido y
        -- trabajo de mas en cada cambio de estado, con cada nuevo evento
        -- generando otro mas (aunque no en bucle infinito, si acumulativo).
        local debugStr = "<rgb=#888888>QuestSync DEBUG: [EventBus] " .. tostring(eventName)
        if type(data) == "table" then
            if data.questName then debugStr = debugStr .. " | Quest: " .. tostring(data.questName) end
            if data.description then debugStr = debugStr .. " | Obj: " .. tostring(data.description) end
            if data.progressCurrent then debugStr = debugStr .. " | Prog: " .. tostring(data.progressCurrent) .. "/" .. tostring(data.progressTotal) end
            if data.status then debugStr = debugStr .. " | Status: " .. tostring(data.status) end
        end
        debugStr = debugStr .. "</rgb>"
        import "Turbine"
        Turbine.Shell.WriteLine(debugStr)
    end

    if self.listeners[eventName] then
        for _, callback in ipairs(self.listeners[eventName]) do
            callback(data)
        end
    end
end
