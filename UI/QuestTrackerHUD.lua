-- LOTRO_Quest_Assistant/UI/QuestTrackerHUD.lua
--
-- REDISEÑO VISUAL "libro" (2026-08-28, pedido explicito del usuario, mismo
-- criterio que QuestBookWindow.lua): SOLO lo cosmetico -- toda la logica
-- funcional de este archivo (suscripciones a EventBus, sinergia con
-- DeedTracker, boton "Ir" con su Quickslot real, SizeChanged) queda
-- IDENTICA, pedido explicito del usuario de no tocar la estructura
-- funcional. Los colores de ESTADO (LightBlue para mision activa, violeta
-- para proezas de DeedTracker, Yellow del encabezado ya alineado a
-- proposito con DeedTracker/MainWin.lua) tampoco cambian -- ver la nota
-- original de cada uno mas abajo, siguen siendo la MISMA decision de
-- paleta de antes, no algo nuevo.
--
-- V2 (mismo dia, pedido explicito del usuario: "adaptemos esta imagen...
-- integremos esto en nuestra ventana flotante tracker"): el panel de
-- fondo tibio de un solo color plano se reemplaza por pergamino con marco
-- de madera y adornos de metal (imagen generada con IA, "Gemini_Generated_
-- Image_8od5y08od5y08od5-Photoroom.png" en Documentos/The Lord of the
-- Rings Online/), recortada a su contenido real (450,14,981,750 del PNG
-- original).
--
-- V3 (mismo dia, pedido explicito del usuario: "sigue el bug al agrandar
-- un poco... que la ventana pueda adaptarse, achicarse, y que se adapte la
-- imagen y lo interno"): la v2 usaba UNA sola imagen de 300x416 con
-- SetMaximumSize como tope -- igual se veia el mosaico si el resize se
-- pasaba un poco, y ademas el pedido real era que se adapte de VERDAD, no
-- que se le ponga un techo. Fix: pergamino partido en 3 pedazos, mismo
-- patron "9-slice" que ya se uso para armar el launcher (extremos fijos +
-- tramo del medio que se estira), pero armado EN VIVO con Lua en vez de
-- pre-compuesto con Pillow porque esta ventana si necesita adaptarse en
-- tiempo real:
--   * tracker_parchment_top.tga (300x130) -- borde de madera + cartel +
--     adornos de esquina de ARRIBA. Tamaño fijo, nunca se estira.
--   * tracker_parchment_bottom.tga (300x88) -- adornos de esquina +
--     borde de madera de ABAJO. Tamaño fijo, se reposiciona en
--     SizeChanged para quedar pegado siempre al borde inferior.
--   * tracker_parchment_mid.tga (300x113) -- tira de papel liso sin
--     adornos (recortada de una zona plana confirmada por pixel, sin
--     ningun borde ondulado de la hoja) -- esta SI se redimensiona en
--     SizeChanged para llenar el hueco entre los otros 2. Se probo con un
--     tile mas chico (40px) primero: al repetirse mostraba un patron de
--     "ola" visible en el borde ondulado de la hoja -- 113px (una porcion
--     bastante mas grande, casi sin ondulacion propia) casi no necesita
--     repetirse en el rango normal de uso y la costura es practicamente
--     invisible.
-- Sin SetMaximumSize -- ya no hace falta, la ventana se puede agrandar o
-- achicar libremente y el pergamino se adapta solo.
import "Turbine"
import "Turbine.UI"
import "Turbine.UI.Lotro"

_G.LQA = _G.LQA or {}
LQA.UI = LQA.UI or {}

LQA.UI.QuestTrackerHUD = class(Turbine.UI.Lotro.Window)

-- BUG CORREGIDO (2026-08-20, captura de pantalla del usuario: nombres de
-- mision largos, ej. "Libro 3. Capítulo 7: El Consejo Reunido", se veian
-- cortados/superpuestos con los botones "Ir"/"X" de la misma fila). 34px
-- alcanzaba para 2 lineas de nombre solo cuando NO habia progreso "(N/M)"
-- concatenado -- la misma clase de bug ya corregida en QuestSyncWindow.lua
-- (sesion 16/19/39: "la fila tiene que crecer con el texto, no al reves"),
-- pero esa correccion nunca se aplico a este HUD, que tiene su propia copia
-- de la logica de fila. Subido 34->48 (mismo criterio: 3 lineas visibles
-- antes de que el label empiece a recortar contra la fila de botones).
--
-- V3 -- pedido explicito del usuario ("adapta las letras, que sean mas
-- grande y legible... dejemos visualmente 3 misiones y que tengamos una
-- bajada con la rueda del raton"): 48->64 para acompañar la fuente mas
-- grande (BookAntiqua12->16, ver PopulateActive). Con filas mas altas
-- entran ~3 a la vista antes de necesitar scroll (la ListBox+ScrollBar de
-- mas abajo ya soportan rueda del mouse de forma nativa, sin codigo
-- extra).
local ROW_HEIGHT = 64

-- Piezas del pergamino en 3 partes (ver nota V3 grande arriba) -- tamaños
-- FIJOS de los archivos reales, usados tanto para el layout inicial como
-- para SizeChanged.
local PAGE_TOP_H = 130
local PAGE_BOTTOM_H = 88
-- Alto nativo real de tracker_parchment_mid.tga (300x112, confirmado con
-- Pillow). SetBackground() nunca estira una imagen -- si el control mide
-- MAS que esto, Turbine repite/tilea la imagen en mosaico. V9 (mas abajo)
-- usa esto para redondear el alto de pageMid a un multiplo exacto.
local MID_TILE_H = 112

-- V8 -- pedido explicito del usuario ("el boton de recoleccion puede
-- estar mas arriba, hay mucho espacio perdido"): el adorno de esquina de
-- pageTop (dentro de sus 130px) SOLO ocupa el lado DERECHO hasta el
-- fondo -- el lado IZQUIERDO (x=10, donde vive este boton) ya esta libre
-- de decoracion mucho antes, cerca de y=80 relativo a pageTop. Antes se
-- posicionaba a 30+130+8=168 (asumiendo que hacia falta esperar a que
-- terminara TODO pageTop) dejando ~50px de pergamino en blanco sin usar
-- arriba del boton.
local GATHER_BTN_Y = 30 + 88

-- Interruptor de idioma (LanguageSettings.lua): mismo patron que
-- QuestSyncWindow.lua, version reducida ya que este HUD solo tiene 3
-- strings fijas.
-- V4 -- pedido explicito del usuario ("la letra de 'misiones activas en
-- el mapa' es demasiado chica para el cuadro... que sea 'Misiones
-- activas' mas grande que ocupe todo el cuadrado"): texto acortado (el
-- cartel del pergamino es angosto, 215px) para poder subir la fuente sin
-- que quede apretado.
local HUD_STRINGS = {
    ES = { header = "Misiones activas", empty = "No hay misiones activas", go = "Ir" },
    EN = { header = "Active quests", empty = "No active quests", go = "Go" },
}
local function HT(key)
    local lang = LanguageSettings.IsSpanish() and "ES" or "EN"
    return HUD_STRINGS[lang][key] or key
end
local function HudQuestName(ndx, quest)
    if LanguageSettings.IsSpanish() then
        return QuestLocResolver.GetQuestNameES(ndx, quest.nameEN)
    end
    return quest.nameEN
end

-- V6 -- pedido explicito del usuario ("las misiones deeds son del mismo
-- color... colores distintos a las que son en grupo, deeds, mision
-- principal, repetibles"): QuestDB.quests[ndx].category es un string real
-- (ej. "Epic - Vol. II, Book 1: The Walls of Moria", "Mûr Ghala
-- Instances", "Raid: The Abyss of Mordath", "Skirmish Assaults") --
-- "Epic" aparece en 999 misiones (historia principal/vol.), "Instance"/
-- "Raid"/"Skirmish" en 135 (contenido de grupo). .repeatable es un
-- booleano real, 4231 misiones lo tienen en true. Ningun campo de
-- "grupo" generico existe aparte de esto -- se usa el category como
-- proxy, es lo unico con dato real disponible (no se inventa nada).
local function ClassifyQuest(quest)
    local cat = quest.category or ""
    if string.find(cat, "Epic", 1, true) then
        return "epic"
    end
    if string.find(cat, "Instance", 1, true) or string.find(cat, "Raid", 1, true) or string.find(cat, "Skirmish", 1, true) then
        return "group"
    end
    if quest.repeatable == true then
        return "repeatable"
    end
    return "normal"
end

local QUEST_TYPE_COLOR -- se arma mas abajo (necesita MEMBookStyle.Color.BodyText ya cargado)
local function InitQuestTypeColors()
    if QUEST_TYPE_COLOR then return end
    QUEST_TYPE_COLOR = {
        epic = Turbine.UI.Color(0.55, 0.12, 0.10),       -- rojo oscuro: mision principal/epica
        group = Turbine.UI.Color(0.62, 0.36, 0.05),      -- naranja/oxido: grupo, instancia, redada, escaramuza
        repeatable = Turbine.UI.Color(0.10, 0.42, 0.32), -- verde azulado: repetible
        normal = LQA.UI.MEMBookStyle.Color.BodyText,     -- gris-cafe de siempre: mision normal, sin cambios
    }
end

function LQA.UI.QuestTrackerHUD:Constructor()
    Turbine.UI.Lotro.Window.Constructor(self)

    self:SetPosition(Turbine.UI.Display.GetWidth() - 320, 200)
    -- Alto por defecto: 500 -- con ROW_HEIGHT=64 (subido de 48, V3) entran
    -- ~3 filas completas a la vista antes de necesitar scroll (pedido
    -- explicito del usuario), mas el cartel/boton/adornos de arriba y
    -- abajo.
    self:SetSize(300, 500)
    -- BUG CORREGIDO (visto en captura con zoom del usuario: el titulo
    -- nativo se cortaba, "QuestSync Tracke" sin la "r" final) -- el chrome
    -- nativo de Lotro.Window trunca el titulo si no entra en el ancho de
    -- la ventana (300px); "QuestSync Tracker" (18 caracteres) no entraba,
    -- "Tracker" si.
    self:SetText("Tracker")
    self:SetOpacity(0.9)
    self:SetVisible(true)
    -- Adaptable: mismo mecanismo confirmado en QuestSyncWindow.lua/MoorMap
    -- (SetResizable + SetMinimumSize + SizeChanged son APIs reales).
    self:SetResizable(true)
    -- Minimo: 290 (V3) -> 370 (V6). Con el redondeo de listH a multiplos
    -- de ROW_HEIGHT (ver SizeChanged mas abajo), 290 ya no alcanzaba para
    -- mostrar ni una fila completa sin que se superpusiera con el adorno
    -- de abajo (88 + 10 + 200(listTop) + 64(1 fila) = 362 es el piso real
    -- -- 370 deja un pequeño margen).
    self:SetMinimumSize(220, 370)
    -- V5 -- BUG CORREGIDO (screenshot del usuario: al ENSANCHAR la ventana
    -- se veia el pergamino repetido en mosaico varias veces de lado a
    -- lado) -- el sistema de 9-slice de la V3 solo resuelve el ALTO
    -- (pageTop/pageMid/pageBottom se acomodan bien verticalmente a
    -- cualquier alto), pero pageMid seguia usando el ANCHO completo de la
    -- ventana (self.pageMid:SetSize(w, ...) en SizeChanged, ver mas abajo)
    -- -- al ensanchar mas alla de 300 esa pieza (nativamente de 300px)
    -- tambien se repetia en mosaico, esta vez de lado a lado. Pedido
    -- explicito del usuario ("deja el limite que no se pueda ampliar pero
    -- si que se pueda achicar"): en vez de armar un 9-slice horizontal
    -- tambien (mucho mas complicado por los adornos redondeados de las
    -- esquinas), se le pone techo a AMBAS dimensiones al tamaño por
    -- defecto -- se puede seguir achicando libre hasta el minimo de
    -- arriba, pero no agrandar mas alla de 300x500.
    self:SetMaximumSize(300, 500)

    -- currentZone: cambiamos de area a zone para el HUD. A diferencia de la
    -- ventana principal (que lista TODAS las misiones del juego y necesita
    -- separarlas por area para no abrumar con 1000 misiones de Bree), el
    -- Tracker solo muestra las ACTIVAS. Filtrar por 'area' ocultaba misiones
    -- vecinas (ej. Greenway vs Trestlebridge) provocando que la ventana
    -- saltara entre ellas. Filtrar por 'zone' las mantiene todas juntas.
    self.currentZone = nil

    -- Pergamino en 3 piezas (V3, ver nota grande arriba) -- HIJOS de la
    -- ventana (nunca la ventana en si, mismo criterio que
    -- QuestBookWindow.lua).
    local BOOK_RES = LQA.UI.MEMBookStyle.RES_BASE
    self.pageTop = Turbine.UI.Control()
    self.pageTop:SetParent(self)
    self.pageTop:SetPosition(0, 30)
    self.pageTop:SetSize(300, PAGE_TOP_H)
    self.pageTop:SetBackground(BOOK_RES .. "tracker_parchment_top.tga")
    self.pageTop:SetMouseVisible(false)

    self.pageMid = Turbine.UI.Control()
    self.pageMid:SetParent(self)
    self.pageMid:SetPosition(0, 30 + PAGE_TOP_H)
    self.pageMid:SetBackground(BOOK_RES .. "tracker_parchment_mid.tga")
    self.pageMid:SetMouseVisible(false)

    self.pageBottom = Turbine.UI.Control()
    self.pageBottom:SetParent(self)
    self.pageBottom:SetSize(300, PAGE_BOTTOM_H)
    self.pageBottom:SetBackground(BOOK_RES .. "tracker_parchment_bottom.tga")
    self.pageBottom:SetMouseVisible(false)

    -- lblHeader vive DENTRO del cartel recortado en pageTop (x=[51,266],
    -- y=[31,72] relativo a pageTop -- ver nota grande arriba). Posicion
    -- FIJA (pageTop nunca se estira) -- multilinea + centrado porque el
    -- cartel (215px) es mas angosto que el texto completo en una linea.
    -- V4: BookAntiquaBold14 -> BookAntiquaBold24 (el mas grande
    -- disponible en MEMBookStyle) -- con el texto acortado a "Misiones
    -- activas" ahora entra y llena el cartel en vez de perderse chico en
    -- el medio.
    self.lblHeader = Turbine.UI.Label()
    self.lblHeader:SetParent(self)
    self.lblHeader:SetPosition(51, 30 + 30)
    self.lblHeader:SetSize(215, 44)
    self.lblHeader:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiquaBold24)
    self.lblHeader:SetMultiline(true)
    self.lblHeader:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    -- Yellow, igual que los encabezados de QuestSyncWindow.lua y de
    -- DeedTracker (MainWin.lua) -- antes era un dorado apagado a mano.
    -- Sin cambios de color en este rediseño (pedido explicito del usuario
    -- de mantener la paleta de estado) -- solo cambia la fuente/posicion.
    self.lblHeader:SetForeColor(Turbine.UI.Color.Yellow)
    self.lblHeader:SetText(HT("header"))

    -- Boton a GatherWindow.lua (pedido explicito del usuario) -- ver
    -- GATHER_BTN_Y arriba (subido, ya no espera a que termine TODO
    -- pageTop -- el lado izquierdo, donde vive este boton, esta libre de
    -- decoracion mucho antes que el lado derecho).
    self.btnGather = Turbine.UI.Lotro.Button()
    self.btnGather:SetParent(self)
    self.btnGather:SetPosition(10, GATHER_BTN_Y)
    self.btnGather:SetSize(150, 22)
    self.btnGather:SetText("Recolección")
    self.btnGather.MouseClick = function()
        if _G.GatherWindow then
            _G.GatherWindow:SetVisible(not _G.GatherWindow:IsVisible())
        end
    end

    self.listContainer = Turbine.UI.Control()
    self.listContainer:SetParent(self)
    self.listContainer:SetPosition(10, GATHER_BTN_Y + 22 + 10)

    self.listBox = Turbine.UI.ListBox()
    self.listBox:SetParent(self.listContainer)
    self.listBox:SetPosition(0, 0)
    self.listBox:SetWidth(265)

    self.scrollBar = Turbine.UI.Lotro.ScrollBar()
    self.scrollBar:SetOrientation(Turbine.UI.Orientation.Vertical)
    self.scrollBar:SetParent(self.listContainer)
    self.scrollBar:SetPosition(270, 0)
    self.scrollBar:SetWidth(10)
    self.listBox:SetVerticalScrollBar(self.scrollBar)

    -- V3 -- pedido explicito del usuario ("que la ventana pueda adaptarse,
    -- achicarse, y que se adapte la imagen y lo interno"): pageMid se
    -- redimensiona para llenar EXACTO el hueco entre pageTop (fijo) y
    -- pageBottom (fijo, reposicionado para quedar siempre pegado al borde
    -- inferior) -- asi el pergamino se adapta de verdad a cualquier alto,
    -- sin mosaico visible en los adornos (solo repite/recorta la tira
    -- lisa del medio, invisible por diseño). El listContainer usa la MISMA
    -- cuenta para no pisar pageBottom.
    self.SizeChanged = function()
        local w, h = self:GetSize()
        if not w or not h then return end

        local bottomY = h - PAGE_BOTTOM_H
        local minBottomY = 30 + PAGE_TOP_H
        if bottomY < minBottomY then bottomY = minBottomY end

        -- V9 -- BUG CORREGIDO (pedido del usuario: "corte visual mal que
        -- deforma la imagen original y no es continua"): el alto de
        -- pageMid se ponia EXACTO al hueco disponible (bottomY-minBottomY)
        -- -- casi nunca un multiplo de MID_TILE_H (112), asi que el mosaico
        -- (SetBackground repite la imagen si el control es mas alto que
        -- ella) quedaba CORTADO a mitad de patron justo contra el borde de
        -- pageBottom -- ahi se veia la costura. Redondeado hacia ARRIBA al
        -- proximo multiplo de 112: el mosaico siempre termina en un limite
        -- de repeticion limpio, y el sobrante (menos de 1 tile) queda
        -- oculto DETRAS de pageBottom (creado despues en este archivo =
        -- mas z-order = se dibuja encima; el click en pageBottom sigue
        -- funcionando igual, pageMid solo pinta por debajo).
        local gap = bottomY - minBottomY
        local midH = math.ceil(gap / MID_TILE_H) * MID_TILE_H
        self.pageMid:SetSize(w, midH)
        self.pageBottom:SetPosition(0, bottomY)

        -- V6 -- BUG CORREGIDO (pedido explicito del usuario: "se mira que
        -- esta cortado la imagen y pegada"): listH salia de un resto
        -- (altura disponible - margenes) que casi nunca es multiplo
        -- exacto de ROW_HEIGHT -- la ListBox mostraba la ULTIMA fila
        -- MEDIO cortada justo pegada al borde inferior del pergamino
        -- (choca visualmente contra el adorno de madera, se ve "cortado y
        -- pegado"). Redondeando para abajo al multiplo de ROW_HEIGHT mas
        -- cercano, la lista SIEMPRE termina en una fila completa -- el
        -- resto (menos de 1 fila) queda como margen de pergamino en
        -- blanco antes del adorno, no como texto a medias.
        local listH = bottomY - 10 - self.listContainer:GetTop()
        if listH < ROW_HEIGHT then listH = ROW_HEIGHT end
        listH = math.floor(listH / ROW_HEIGHT) * ROW_HEIGHT
        self.listContainer:SetSize(w - 20, listH)
        self.listBox:SetHeight(listH)
        self.scrollBar:SetHeight(listH)
    end
    -- SizeChanged solo dispara en un resize real del jugador, no en la
    -- construccion -- se llama a mano una vez para que el layout inicial
    -- (pageMid/pageBottom/listContainer) ya salga bien acomodado desde el
    -- primer frame, sin depender de que el jugador redimensione primero.
    self.SizeChanged()

    local function OnQuestEvent(data)
        if data and data.ndx and QuestDB.quests[data.ndx] then
            local q = QuestDB.quests[data.ndx]
            if q.zone and q.zone ~= "" then
                self.currentZone = q.zone
            end
        end
        self:PopulateActive()
    end
    LQA.Core.EventBus:Subscribe("QUEST_STATE_CHANGED", OnQuestEvent)
    LQA.Core.EventBus:Subscribe("QUEST_PROGRESS", OnQuestEvent)
    -- BUG CORREGIDO (pedido explicito del usuario: "al hacer click en la
    -- mision dentro de este tracker desaparece el resto de las misiones
    -- trackeadas"): QUEST_TRACKED se publica desde
    -- QuestStateManager.SetTrackedQuest(ndx), que a su vez se dispara con
    -- CADA click en una fila de este mismo Tracker (via FocusQuest ->
    -- SelectQuest -> SetTrackedQuest en QuestSyncWindow.lua) -- NO es una
    -- señal real de "el jugador esta ahora en la zona de esta mision", es
    -- solo "el jugador clickeo para VER esta mision en la UI". Estar
    -- suscripto a ese evento hacia que self.currentZone se pisara con la
    -- zona de CUALQUIER mision que se clickeara aca mismo, angostando el
    -- filtro de zona del Tracker a esa sola mision y escondiendo al resto.
    -- QUEST_STATE_CHANGED/QUEST_PROGRESS si reflejan progreso real del
    -- jugador (aceptar/completar/avanzar objetivos), esos se dejan.
    LQA.Core.EventBus:Subscribe("LANGUAGE_CHANGED", function()
        self.lblHeader:SetText(HT("header"))
        self:PopulateActive()
    end)

    -- Sinergia con DeedTracker: _G.LQA_InProgressDeeds lo actualiza el OTRO
    -- addon, no publica ningun evento propio en nuestro EventBus -- sin esto
    -- el HUD solo se enteraria de una proeza nueva la proxima vez que una
    -- MISION propia cambiara de estado. Chequeo liviano cada 2s (compara
    -- cuantas entradas tiene la tabla, no repuebla la lista entera salvo que
    -- el numero haya cambiado).
    self.lastDeedCount = 0
    self.deedWatcher = Turbine.UI.Control()
    self.deedWatcher.nextCheck = Turbine.Engine.GetGameTime() + 2
    self.deedWatcher.Update = function()
        if Turbine.Engine.GetGameTime() >= self.deedWatcher.nextCheck then
            self.deedWatcher.nextCheck = Turbine.Engine.GetGameTime() + 2
            local n = 0
            if _G.LQA_InProgressDeeds then
                for _ in pairs(_G.LQA_InProgressDeeds) do n = n + 1 end
            end
            if n ~= self.lastDeedCount then
                self.lastDeedCount = n
                self:PopulateActive()
            end
        end
    end
    self.deedWatcher:SetWantsUpdates(true)

    self:PopulateActive()
end

function LQA.UI.QuestTrackerHUD:PopulateActive()
    InitQuestTypeColors()
    self.listBox:ClearItems()

    local cZone = self.currentZone and string.lower(self.currentZone) or nil

    local count = 0
    for ndx, data in pairs(QuestStateManager.State.active) do
        if not data.hidden then
            local quest = QuestDB.quests[ndx]
            if quest then
                local qZone = string.lower(quest.zone or "")
                if not cZone or qZone == cZone then
                    count = count + 1

                    local item = Turbine.UI.Control()
                    item:SetSize(265, ROW_HEIGHT)

                    local esName = HudQuestName(ndx, quest)

                    -- V2 (pedido explicito del usuario: "mejora la letra,
                    -- tamaño y colores adaptandolos a la nueva imagen") --
                    -- el LightBlue (elegido para contrastar contra el panel
                    -- OSCURO de antes) se lee mal sobre el pergamino CLARO
                    -- nuevo. La insignia (badge, un punto chico) se deja
                    -- igual -- un acento de color se distingue bien sobre
                    -- cualquier fondo -- pero el TEXTO pasa a
                    -- MEMBookStyle.Color.BodyText (80,80,80, el mismo tono
                    -- ya usado en el resto del addon para texto genuinamente
                    -- sobre pergamino).
                    -- V3 (pedido explicito del usuario: "que sean mas
                    -- grande y legible... 3 misiones visibles con scroll"):
                    -- BookAntiqua12 -> BookAntiqua16 (el ROW_HEIGHT ya subio
                    -- de 48 a 64 mas arriba para acompañar, asi que subir la
                    -- fuente aca ya NO reabre el bug viejo de superposicion
                    -- con los botones Ir/X).
                    -- V4 (pedido explicito del usuario: "es mucho el
                    -- espacio entre separacion por mision") -- la insignia
                    -- y los botones estaban CENTRADOS en toda la fila de
                    -- 64px (pensada para 3 lineas de texto largo), pero la
                    -- mayoria de los nombres de mision son 1 sola linea --
                    -- eso dejaba un hueco vacio grande antes de que
                    -- empezara la fila siguiente. Se pegan arriba, junto al
                    -- texto (que ya arranca en y=0), en vez de centrarse en
                    -- toda la altura -- ROW_HEIGHT se queda en 64 igual
                    -- (sigue haciendo falta para nombres largos de 3
                    -- lineas), pero ahora el espacio libre queda SIEMPRE al
                    -- final de la fila (antes de la siguiente), no
                    -- repartido raro en el medio.
                    -- V6 (pedido explicito del usuario: "colores distintos
                    -- para las que son en grupo, deeds, mision principal,
                    -- repetibles" + "el grosor de la letra, se ve muy
                    -- fina"): la insignia y el texto ahora toman el color
                    -- de ClassifyQuest(quest) (ver la funcion grande al
                    -- principio del archivo) en vez de un LightBlue/
                    -- BodyText fijo para TODAS las misiones por igual.
                    -- BookAntiqua16 (fino) -> BookAntiquaBold18 (negrita,
                    -- ademas un toque mas grande -- no existe una variante
                    -- "Bold16" real en MEMCommon/Fonts.lua, Bold18 es la
                    -- mas cercana disponible).
                    local qType = ClassifyQuest(quest)
                    local qColor = QUEST_TYPE_COLOR[qType]

                    local badge = Turbine.UI.Control()
                    badge:SetParent(item)
                    badge:SetPosition(0, 6)
                    badge:SetSize(10, 10)
                    badge:SetBackColor(qColor)

                    local lbl = Turbine.UI.Label()
                    lbl:SetParent(item)
                    lbl:SetPosition(16, 0)
                    lbl:SetSize(148, ROW_HEIGHT)
                    lbl:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiquaBold18)
                    lbl:SetForeColor(qColor)
                    -- V7 (revertido) -- se probo sumar FontStyle.Outline
                    -- para engordar el trazo (pedido explicito del
                    -- usuario), pero el usuario reporto que a este tamaño
                    -- el contorno se ve BORROSO en vez de mas grueso (el
                    -- anti-aliasing del contorno se mezcla con el relleno
                    -- a 18pt). Se saca -- BookAntiquaBold18 solo, sin
                    -- contorno, se queda como la mejora de grosor real.
                    local prog = data.progress
                    local displayText = (prog and prog ~= "") and (esName .. "  " .. prog) or esName
                    lbl:SetText(displayText)

                    -- V10 -- pedido del usuario: los botones "Ir"/"X"
                    -- quedaban pegados arriba (y=4, ver nota V4 abajo) sin
                    -- importar si el nombre de la mision ocupaba 1 o 2
                    -- lineas -- con nombres largos ("El desafio de
                    -- Crannog", "Depredadores en las estribaciones") el
                    -- texto se ve 2 lineas altas pero los botones quedan
                    -- "flotando" arriba, desalineados. No hay una API de
                    -- medicion de texto real disponible en este addon (se
                    -- reviso, no se usa en ningun lado) -- heuristica de
                    -- cantidad de caracteres: a BookAntiquaBold18 en 148px
                    -- de ancho, ~20 caracteres es el punto donde el texto
                    -- deja de entrar en 1 sola linea (confirmado contra la
                    -- captura del usuario: "Trofeos de guerra" 18 caract.
                    -- entraba en 1 linea, "El desafio de Crannog" 22
                    -- caracteres ya envolvia a 2). Si envuelve, se corren
                    -- los botones mas abajo para centrarse contra el
                    -- bloque de 2 lineas en vez de solo la primera.
                    local buttonY = 4
                    if #displayText > 20 then
                        buttonY = 4 + 14
                    end

                    -- FocusQuest (no SelectQuest): abre la ventana maestra
                    -- directo en la pestaña QuestSync mostrando SOLO esta
                    -- mision -- antes SelectQuest llenaba el panel de
                    -- detalle bien pero dejaba la lista de la izquierda con
                    -- TODAS las misiones del area, sin forma de distinguir
                    -- cual era la seleccionada (bug reportado por el
                    -- usuario). Ver QuestSyncWindow:FocusQuest.
                    item.MouseClick = function()
                        if _G.MainWindow then
                            _G.MainWindow:SetVisible(true)
                            _G.MainWindow:FocusQuest(ndx)
                        end
                    end
                    lbl.MouseClick = item.MouseClick
                    badge.MouseClick = item.MouseClick

                    -- Info al pasar el mouse (ver UI/QuestInfoTooltip.lua,
                    -- portado de CubePlugins/DeedTracker) -- pedido
                    -- explicito del usuario, tambien en el Tracker.
                    lbl.MouseHover = function()
                        QuestInfoTooltip.GetInstance():ShowFor(ndx, quest, esName)
                    end
                    lbl.MouseLeave = function()
                        QuestInfoTooltip.GetInstance():Hide()
                    end

                    -- V4: pegado arriba (y=4, junto al texto) en vez de
                    -- centrado en toda la fila -- ver nota grande del badge
                    -- mas arriba (menos espacio vacio para nombres cortos).
                    local loc = MoorMapAdapter.ResolveQuestLoc(ndx, quest)
                    if loc and MoorMapAdapter then
                        -- Se mantiene Turbine.UI.Lotro.Button a proposito
                        -- (mismo motivo que btnGo de QuestBookWindow.lua):
                        -- lleva un Quickslot real detras via MoorMapAdapter,
                        -- y esa combinacion es la UNICA confirmada sin
                        -- cierres en este addon -- no se cambia el TIPO de
                        -- control por estetica, pero si se le puede poner
                        -- la tipografia "libro" (SetFont/SetForeColor son
                        -- API real del boton, no tocan el Quickslot).
                        local btnGo = Turbine.UI.Lotro.Button()
                        btnGo:SetParent(item)
                        btnGo:SetPosition(168, buttonY)
                        btnGo:SetSize(70, 26)
                        btnGo:SetText(HT("go"))
                        btnGo:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiquaBold14)

                        local qs = MoorMapAdapter.CreateQuickslot()
                        MoorMapAdapter.AttachToButton(qs, btnGo)

                        local ns, ew = MoorMapAdapter.ParseCoord(loc)
                        MoorMapAdapter.SetQuestMarker(qs, {
                            mapID = MoorMapAdapter.ResolveMapID(quest),
                            ns = ns or 0,
                            ew = ew or 0,
                            name = string.gsub(esName, ":", "-"),
                            description = "Objetivo"
                        })
                    end

                    -- V10 -- pedido del usuario ("estilo generico, no
                    -- combina con el pergamino"): este boton NO lleva
                    -- Quickslot (a diferencia de btnGo) -- solo oculta la
                    -- mision (data.hidden), asi que es seguro cambiarlo del
                    -- Lotro.Button generico al icono redondo "libro" que ya
                    -- existe en Resources/Book/ (close_button.tga, mismo
                    -- pack MEM que el resto de esta identidad visual).
                    local btnHide = LQA.UI.MEMBookStyle.CreateIconButton("close_button", 25, 25)
                    btnHide:SetParent(item)
                    btnHide:SetPosition(237, buttonY - 2)
                    btnHide.ButtonClicked = function()
                        data.hidden = true
                        QuestStateManager.Save()
                        self:PopulateActive()
                    end

                    self.listBox:AddItem(item)
                end
            end
        end
    end

    -- Sinergia con CubePlugins/DeedTracker (mismo dueño/autor, pedido
    -- explicito del usuario): DeedTracker ya expone las proezas en curso en
    -- el global compartido _G.LQA_InProgressDeeds[deedID]=true (ver
    -- ChatLogger.lua) -- se muestran aca con una insignia de color distinta
    -- (violeta) para diferenciarlas de las misiones (azul/verde). Guardado
    -- defensivo con DataFiles and DataFiles._DEED_DATA: si DeedTracker no
    -- esta instalado/activo, este bloque simplemente no agrega nada.
    -- LIMITACION CONOCIDA: _G.LQA_InProgressDeeds nunca se limpia cuando una
    -- proeza se completa (grep confirmado, no hay ninguna asignacion a nil
    -- de esa clave en todo DeedTracker) -- una proeza que ya se completo puede seguir apareciendo
    -- aca como "en curso" hasta que se cierre sesion. No se intento resolver
    -- eso en esta pasada (requeriria exponer el estado real de completado de
    -- DeedTracker via otro global, que hoy no existe).
    if _G.LQA_InProgressDeeds and _G.DataFiles and _G.DataFiles._DEED_DATA then
        for deedID, _ in pairs(_G.LQA_InProgressDeeds) do
            local deed = _G.DataFiles._DEED_DATA[deedID]
            if deed and deed.NAME then
                count = count + 1

                local item = Turbine.UI.Control()
                item:SetSize(265, ROW_HEIGHT)

                -- V4: pegado arriba (y=6), mismo criterio que la fila de
                -- misiones (ver nota grande mas arriba).
                -- V6: badge e texto ahora usan el MISMO violeta oscuro
                -- (antes el badge era un lila claro (0.7,0.45,0.9) que no
                -- coincidia con el texto oscuro -- se ven como si fueran
                -- 2 colores de "deed" distintos). BookAntiqua16 ->
                -- BookAntiquaBold18, mismo criterio de negrita/tamaño que
                -- la fila de misiones.
                local deedColor = Turbine.UI.Color(0.35, 0.20, 0.45)
                local badge = Turbine.UI.Control()
                badge:SetParent(item)
                badge:SetPosition(0, 6)
                badge:SetSize(10, 10)
                badge:SetBackColor(deedColor)

                local lbl = Turbine.UI.Label()
                lbl:SetParent(item)
                lbl:SetPosition(16, 0)
                lbl:SetSize(249, ROW_HEIGHT)
                lbl:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiquaBold18)
                lbl:SetForeColor(deedColor)
                -- V7 (revertido, ver nota grande de la fila de misiones):
                -- sin contorno -- se veia borroso a este tamaño.
                lbl:SetText(tostring(deed.NAME))

                self.listBox:AddItem(item)
            end
        end
    end

    if count == 0 then
        local empty = Turbine.UI.Control()
        empty:SetSize(265, 26)

        local lbl = Turbine.UI.Label()
        lbl:SetParent(empty)
        lbl:SetPosition(0, 0)
        lbl:SetSize(265, 26)
        lbl:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiqua12)
        -- V2: gris (0.6,0.6,0.6) tenia buen contraste sobre el panel OSCURO
        -- de antes -- sobre pergamino claro es casi invisible. HeadingGray
        -- de MEMBookStyle (140,140,140) tampoco alcanzaria aca (pensado
        -- para otro fondo); se usa un gris mas oscuro a mano, mismo
        -- criterio que BodyText pero un poco mas claro para que se note
        -- que es un estado "vacio", no una fila real.
        lbl:SetForeColor(Turbine.UI.Color(0.45, 0.42, 0.38))
        lbl:SetText(HT("empty"))

        self.listBox:AddItem(empty)
    end
end
