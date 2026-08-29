-- LOTRO_Quest_Assistant/UI/QuestBookWindow.lua
-- Ventana "libro" que se abre SOLA al aceptar o completar cualquier mision
-- (pedido explicito del usuario, inspirado en como el addon de terceros
-- MEMLotro presenta sus 3 aventuras propias como paginas narradas en vez de
-- una simple linea de chat). A diferencia de MEMLotro, esto NO es un arbol
-- de dialogo ramificado con PNJs/eventos -- esa estructura la arma a mano
-- un autor en un editor visual para historias chicas, y no existe (ni se
-- puede inventar sin falsear el contenido real) para las 14.824 misiones
-- oficiales de la base de este addon. Lo que SI se puede automatizar para
-- las 14.824 sin trabajo manual es la PRESENTACION: texto narrado en una
-- pagina en vez de una fila de lista, con el mismo dato que ya usa
-- QuestInfoTooltip.lua (QuestLocResolver.GetCleanObjectiveLines).
--
-- V2 (correccion del usuario despues de ver la V1 en el juego): la V1 usaba
-- book_menu.tga (panel unico, columna izquierda oscura tipo "Series" vacia
-- + columna derecha clara). El usuario pidio en cambio calcar el libro de
-- 2 paginas de pergamino de MEMLotro/MEMCommon/MEMQuestsBook.lua -- ver
-- captura "Mystery At The Pony": pagina izquierda con titulo + info +
-- descripcion, pagina derecha con encabezado "Quests" + lista, cinta roja
-- de nivel en la esquina, ambas paginas del mismo tono de pergamino. Las
-- coordenadas de abajo (levelTag en 304,3 / adventureTitle en 77,43 /
-- adventureDescription en 77,219 / questListTitle en 416,43 / questsList
-- en 378,86 tamaño 334x288) son las MISMAS que usa MEMQuestsBook.lua sobre
-- este mismo questbook.tga (756x471) -- leidas de su codigo real, no
-- adivinadas. No hay arte de portada por mision (14.824 misiones oficiales,
-- no 1 memoir hecho a mano) asi que el hueco de la imagen (77,81,256,128 en
-- MEM) se usa aca para Nivel/Zona en texto; la lista de la derecha ya no es
-- 1 bloque de texto narrado sino 1 fila por linea de objetivo (mismo dato
-- que antes, presentado como checklist en vez de parrafo).
--
-- Se mantiene Turbine.UI.Lotro.Window (chrome nativo) como clase base EN
-- VEZ de Turbine.UI.Window (que es lo que usa MEM) -- decision deliberada,
-- no un descuido: este mismo addon tuvo 3 cierres reales del juego
-- probando ventanas nuevas sin skin de Lotro con botones nativos adentro
-- (ver historial completo en Arquitectura_GatherSync.md #6 y el comentario
-- de GatherCaptureButton.lua). El chrome nativo de Lotro.Window ya esta
-- probado sin cierres en las otras ventanas de este addon -- el fondo de
-- libro se agrega como un Control HIJO con SetBackground(questbook.tga), el
-- mismo mecanismo ya usado sin problemas en GatherWindow.lua
-- (mapControl:SetBackground(zone.image)), no reemplazando la ventana en si.
import "Turbine"
import "Turbine.UI"
import "Turbine.UI.Lotro"

_G.LQA = _G.LQA or {}
LQA.UI = LQA.UI or {}

LQA.UI.QuestBookWindow = class(Turbine.UI.Lotro.Window)

-- Mismo offset de "debajo del titulo nativo" que ya usa GatherWindow.lua
-- (CONTENT_TOP=40) para una Turbine.UI.Lotro.Window -- constante ya
-- validada en este addon, no un numero nuevo sin probar.
local CHROME_TOP = 40
local PAGE_W, PAGE_H = 756, 471
local WIDTH = PAGE_W
local HEIGHT = PAGE_H + CHROME_TOP

-- Hasta 6 lineas limpias de objectivesES (vs. 2 en el tooltip chico) --
-- esta es una ventana para LEER, no un tooltip de paso; con mas lugar
-- disponible tiene sentido mostrar mas narrativa real en vez de cortarla
-- antes de lo necesario.
local MAX_NARRATIVE_LINES = 6

local BANNER_TEXT = {
    ACCEPTED = { ES = "¡Nueva misión!", EN = "New Quest!" },
    COMPLETED = { ES = "¡Misión completada!", EN = "Quest Completed!" },
}
local BANNER_COLOR = {
    ACCEPTED = Turbine.UI.Color(0.4, 0.85, 0.4),
    COMPLETED = Turbine.UI.Color(1, 0.82, 0.3),
}

local function BT(kind)
    local lang = (_G.LanguageSettings and LanguageSettings.IsSpanish()) and "ES" or "EN"
    return BANNER_TEXT[kind][lang]
end

function LQA.UI.QuestBookWindow:Constructor()
    Turbine.UI.Lotro.Window.Constructor(self)

    -- Sin SetResizable(true): en todo este addon esa llamada solo aparece
    -- cuando SE QUIERE que la ventana redimensione -- esta es a tamaño fijo
    -- (tamaño nativo real de questbook.tga), el default ya es fijo.
    self:SetSize(WIDTH, HEIGHT)
    self:SetVisible(false)

    -- Fondo de pagina (libro de 2 paginas de pergamino, 756x471), HIJO de
    -- la ventana (nunca la ventana en si) -- ver la nota grande arriba.
    self.pageBg = Turbine.UI.Control()
    self.pageBg:SetParent(self)
    self.pageBg:SetPosition(0, CHROME_TOP)
    self.pageBg:SetSize(PAGE_W, PAGE_H)
    self.pageBg:SetBackground(LQA.UI.MEMBookStyle.RES_BASE .. "questbook.tga")
    self.pageBg:SetMouseVisible(false)

    -- Cinta de nivel (esquina superior de la pagina izquierda) -- MISMA
    -- posicion/blend que self.summaryComponents.levelTag de
    -- MEMQuestsBook.lua sobre este mismo questbook.tga.
    self.levelTag = Turbine.UI.Control()
    self.levelTag:SetParent(self.pageBg)
    self.levelTag:SetPosition(304, 3)
    self.levelTag:SetSize(44, 70)
    self.levelTag:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
    self.levelTag:SetBackground(LQA.UI.MEMBookStyle.RES_BASE .. "level_ribbon.tga")
    self.levelTag:SetMouseVisible(false)

    self.lblLevel = Turbine.UI.Label()
    self.lblLevel:SetParent(self.pageBg)
    self.lblLevel:SetPosition(310, 22)
    self.lblLevel:SetSize(31, 16)
    self.lblLevel:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiquaBold18)
    self.lblLevel:SetForeColor(Turbine.UI.Color(219 / 255, 219 / 255, 219 / 255))
    self.lblLevel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.lblLevel:SetMouseVisible(false)

    -- Pagina IZQUIERDA: banner + nombre de la mision + zona + narrativa.
    -- Misma columna (x=77, ancho=256) que adventureTitle/adventureDescription
    -- de MEMQuestsBook.lua.
    self.lblBanner = Turbine.UI.Label()
    self.lblBanner:SetParent(self.pageBg)
    self.lblBanner:SetPosition(77, 43)
    self.lblBanner:SetSize(220, 26)
    self.lblBanner:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiquaBold24)
    self.lblBanner:SetMouseVisible(false)
    self.lblBanner:SetSelectable(false)

    -- BUG CORREGIDO (visto en captura con zoom del usuario: el nombre de
    -- la mision se superponia con la zona -- "...Elrohir, Capitulo 5" y
    -- "Taur Hith" se leian pisados uno sobre otro): lblTitle solo tenia
    -- 20px de alto para 1 sola linea, pero nombres largos como
    -- "Miniaventura: Las nuevas aventuras de Elladan y Elrohir, Capitulo
    -- 5" necesitan 2 -- la segunda linea se salia de su caja y caia
    -- encima de lblInfo, que empezaba muy cerca (24px mas abajo). Ahora
    -- lblTitle reserva 2 lineas reales (SetMultiline + 40px) y lblInfo se
    -- corre mas abajo para no chocar.
    self.lblTitle = Turbine.UI.Label()
    self.lblTitle:SetParent(self.pageBg)
    self.lblTitle:SetPosition(77, 71)
    self.lblTitle:SetSize(220, 40)
    -- Pedido explicito del usuario: "mejorar el tamaño de la letra, que no
    -- sea demasiado pequeña" -- hay sobra de espacio en blanco en la
    -- pagina (ver captura), 14pt quedaba chico. Bold18 en vez de Bold14.
    self.lblTitle:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiquaBold18)
    -- Pedido del usuario: el titulo de la mision tiene que distinguirse de
    -- la historia "como un libro de verdad" -- tinta bordo en vez del
    -- mismo gris que el cuerpo.
    self.lblTitle:SetForeColor(LQA.UI.MEMBookStyle.Color.TitleInk)
    self.lblTitle:SetMultiline(true)
    self.lblTitle:SetMouseVisible(false)
    self.lblTitle:SetSelectable(false)

    -- Zona -- ocupa el hueco donde MEM pone la imagen de portada de su
    -- memoir (no hay arte de portada por mision, 14.824 misiones oficiales
    -- vs 1 memoir hecho a mano).
    -- BUG CORREGIDO (visto en la misma captura: "Taur Hith" casi
    -- invisible, muy claro sobre el pergamino) -- HeadingGray (140,140,140)
    -- es apenas mas oscuro que el pergamino real (~151,119,80) medido esta
    -- sesion en book_menu.tga -- questbook.tga es el mismo tono de
    -- pergamino, mismo problema de contraste. Se usa BodyText (80,80,80,
    -- el mismo tono oscuro que ya usa lblTitle) en vez de HeadingGray.
    self.lblInfo = Turbine.UI.Label()
    self.lblInfo:SetParent(self.pageBg)
    self.lblInfo:SetPosition(77, 113)
    self.lblInfo:SetSize(256, 24)
    self.lblInfo:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiqua18)
    -- Nombre del NPC en dorado-tostado (TagText, ya usado en los botones)
    -- en vez del gris del cuerpo -- lee como una "firma", distinto del
    -- titulo (bordo) y de la narrativa (gris).
    self.lblInfo:SetForeColor(LQA.UI.MEMBookStyle.Color.TagText)
    self.lblInfo:SetMultiline(true)
    self.lblInfo:SetMouseVisible(false)
    self.lblInfo:SetSelectable(false)

    -- Cuerpo narrado -- MISMA posicion que adventureDescription de
    -- MEMQuestsBook.lua (77,219,256,156), alargada hasta 231 de alto
    -- (termina en 370, corrido 5px por el nuevo alto de lblTitle/lblInfo
    -- arriba, mismo limite en espiritu que la lista de la pagina derecha).
    self.bodyScrollBar = Turbine.UI.Lotro.ScrollBar()
    self.bodyScrollBar:SetOrientation(Turbine.UI.Orientation.Vertical)
    self.bodyScrollBar:SetParent(self.pageBg)
    self.bodyScrollBar:SetPosition(77 + 256 + 6, 139)
    self.bodyScrollBar:SetSize(10, 231)

    self.lblBody = Turbine.UI.Label()
    self.lblBody:SetParent(self.pageBg)
    self.lblBody:SetPosition(77, 139)
    self.lblBody:SetSize(256, 231)
    self.lblBody:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiqua18)
    self.lblBody:SetForeColor(LQA.UI.MEMBookStyle.Color.BodyText)
    self.lblBody:SetMultiline(true)
    self.lblBody:SetMouseVisible(false)
    self.lblBody:SetSelectable(false)
    self.lblBody:SetVerticalScrollBar(self.bodyScrollBar)

    -- Pagina DERECHA: encabezado "Objetivos" + checklist -- MISMAS
    -- coordenadas que questListTitle/questsList de MEMQuestsBook.lua
    -- (416,43 y 378,86,334,288) sobre este mismo questbook.tga.
    self.lblObjectivesHeader = Turbine.UI.Label()
    self.lblObjectivesHeader:SetParent(self.pageBg)
    self.lblObjectivesHeader:SetPosition(416, 43)
    self.lblObjectivesHeader:SetSize(256, 28)
    self.lblObjectivesHeader:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiquaBold24)
    -- Mismo tinte bordo que lblTitle -- los 2 encabezados ("nombre de la
    -- mision" a la izquierda, "Objetivos" a la derecha) quedan consistentes
    -- entre si y distintos del cuerpo/lista.
    self.lblObjectivesHeader:SetForeColor(LQA.UI.MEMBookStyle.Color.TitleInk)
    self.lblObjectivesHeader:SetMouseVisible(false)
    self.lblObjectivesHeader:SetSelectable(false)
    -- BUG CORREGIDO (visto en captura del usuario: la pagina derecha no
    -- tenia ningun titulo arriba de la lista): el Label se creaba pero
    -- nunca se le llamaba SetText, quedaba con el string vacio por
    -- defecto.
    self.lblObjectivesHeader:SetText((_G.LanguageSettings and LanguageSettings.IsSpanish()) and "Objetivos" or "Objectives")

    self.objectivesScroll = Turbine.UI.Lotro.ScrollBar()
    self.objectivesScroll:SetOrientation(Turbine.UI.Orientation.Vertical)
    self.objectivesScroll:SetParent(self.pageBg)
    self.objectivesScroll:SetPosition(378 + 334 + 15, 86)
    self.objectivesScroll:SetSize(10, 288)

    self.objectivesList = Turbine.UI.ListBox()
    self.objectivesList:SetParent(self.pageBg)
    self.objectivesList:SetPosition(378, 86)
    self.objectivesList:SetSize(334, 288)
    self.objectivesList:SetVerticalScrollBar(self.objectivesScroll)

    -- Progreso "(N/M)", solo si la mision esta ACTIVA y tiene dato real
    -- guardado -- mismo assets que QuestInfoTooltip.lua (nunca se inventa
    -- un porcentaje sin dato detras). Debajo de la lista de la pagina
    -- derecha (que termina en y=374).
    self.progressBack = Turbine.UI.Control()
    self.progressBack:SetParent(self.pageBg)
    self.progressBack:SetSize(200, 18)
    self.progressBack:SetPosition(378 + (334 - 200) / 2, 388)
    self.progressBack:SetBackground("LOTRO_Quest_Assistant/Resources/ProgressBar_Back.tga")
    self.progressBack:SetBlendMode(Turbine.UI.BlendMode.Overlay)
    self.progressBack:SetMouseVisible(false)
    self.progressBack:SetVisible(false)

    self.progressFill = Turbine.UI.Control()
    self.progressFill:SetParent(self.progressBack)
    self.progressFill:SetPosition(10, 5)
    self.progressFill:SetSize(0, 9)
    self.progressFill:SetBackground("LOTRO_Quest_Assistant/Resources/ProgressBar.tga")
    self.progressFill:SetBlendMode(Turbine.UI.BlendMode.Overlay)
    self.progressFill:SetMouseVisible(false)

    self.lblProgress = Turbine.UI.Label()
    self.lblProgress:SetParent(self.progressBack)
    self.lblProgress:SetPosition(0, 0)
    self.lblProgress:SetSize(200, 18)
    self.lblProgress:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.lblProgress:SetForeColor(Turbine.UI.Color.Beige)
    self.lblProgress:SetOutlineColor(Turbine.UI.Color(0.1, 0.1, 0.1))
    self.lblProgress:SetFontStyle(Turbine.UI.FontStyle.Outline)
    self.lblProgress:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.lblProgress:SetMouseVisible(false)

    -- Boton "Ir": se mantiene Turbine.UI.Lotro.Button (NO el
    -- MEMBookStyle.CreateIconButton nuevo) a proposito -- este boton lleva
    -- un Quickslot real detras (MoorMapAdapter), y Lotro.Button+Quickslot
    -- dentro de una Lotro.Window es la UNICA combinacion de boton+ventana
    -- ya confirmada sin cierres en este addon (QuestTrackerHUD/
    -- QuestSyncWindow). El estilo visual "libro" se limita a lo cosmetico
    -- (fondo, fuentes, colores) -- no se arriesga el mecanismo de clic real
    -- por estetica.
    self.btnGo = Turbine.UI.Lotro.Button()
    self.btnGo:SetParent(self.pageBg)
    -- Pedido del usuario: el boton quedaba sobre el borde de madera del
    -- atril, no sobre la hoja -- medido pixel a pixel en questbook.tga: el
    -- pergamino real (tono claro ~150-175) se apaga y pasa a madera oscura
    -- alrededor de y=405-420 segun la columna (mas tarde cerca del borde
    -- derecho, que es donde cae este boton). Subido de y=414 a y=386 para
    -- que quede entero dentro del pergamino, en la esquina.
    self.btnGo:SetPosition(378 + 334 - 70, 386)
    self.btnGo:SetSize(70, 26)
    self.btnGo:SetVisible(false)

    self:SetPosition((Turbine.UI.Display.GetWidth() - WIDTH) / 2, 90)

    if LQA and LQA.Core and LQA.Core.EventBus then
        -- Ver la nota junto a QUEST_JUST_ACCEPTED/QUEST_JUST_COMPLETED en
        -- QuestStateManager.lua: son eventos APARTE de QUEST_STATE_CHANGED,
        -- garantizados a disparar solo en la transicion real (no en cada
        -- reafirmacion por texto de objetivo/narrativa), asi que esta
        -- ventana nunca se reabre sola por una mision que ya estaba activa.
        LQA.Core.EventBus:Subscribe("QUEST_JUST_ACCEPTED", function(data)
            if data and data.ndx then self:ShowFor(data.ndx, "ACCEPTED") end
        end)
        LQA.Core.EventBus:Subscribe("QUEST_JUST_COMPLETED", function(data)
            if data and data.ndx then self:ShowFor(data.ndx, "COMPLETED") end
        end)
    end
end

function LQA.UI.QuestBookWindow:ShowFor(ndx, kind)
    local quest = _G.QuestDB and QuestDB.quests and QuestDB.quests[ndx]
    if not quest then return end

    local esName = QuestLocResolver.GetQuestNameES(ndx, quest.nameEN)
    self:SetText(esName) -- titulo nativo de la ventana (chrome de Lotro)
    self.lblTitle:SetText(esName) -- repetido adentro de la pagina, estilo libro

    self.lblBanner:SetText(BT(kind))
    self.lblBanner:SetForeColor(BANNER_COLOR[kind] or BANNER_COLOR.ACCEPTED)

    self.lblLevel:SetText(tostring(quest.level or "?"))
    local area = (quest.area and quest.area ~= "" and quest.area) or quest.zone
    self.lblInfo:SetText(area and tostring(area) or "")

    local narrative = QuestLocResolver.GetCleanObjectiveLines(ndx, quest, MAX_NARRATIVE_LINES)
    local bodyText
    if #narrative > 0 then
        bodyText = table.concat(narrative, "\n\n")
    else
        bodyText = (_G.LanguageSettings and LanguageSettings.IsSpanish())
            and "(sin texto narrativo disponible para esta misión)"
            or "(no narrative text available for this quest)"
    end
    -- Sin scrollBar:SetValue(0) aca: esa API no tiene ningun precedente
    -- confirmado en este addon (ni en LUI) -- mismo criterio que el resto
    -- de este codebase, que solo llama APIs ya vistas en uso real (ver el
    -- historial de SetWordWrap en QuestInfoTooltip.lua, una API que NO
    -- existia y rompio esa ventana). Si la scrollbar queda desplazada al
    -- reabrir para otra mision, el jugador la puede arrastrar arriba a
    -- mano; no vale el riesgo de una API sin confirmar por ese costo chico.
    self.lblBody:SetText(bodyText)

    -- Checklist de la pagina derecha (estilo "Quests" de MEMQuestsBook.lua,
    -- ver captura de referencia): 1 fila por linea de objetivo/narrativa,
    -- mismo dato que arriba pero presentado como lista en vez de parrafo.
    self.objectivesList:ClearItems()
    for _, line in ipairs(narrative) do
        local row = Turbine.UI.Label()
        -- Alto 52 (no 40): mismo criterio que el resto de la sesion --
        -- letra mas grande (18pt) necesita mas alto real por linea.
        row:SetSize(320, 52)
        row:SetFont(LQA.UI.MEMBookStyle.Font.BookAntiqua18)
        row:SetForeColor(LQA.UI.MEMBookStyle.Color.BodyText)
        row:SetMultiline(true)
        row:SetMouseVisible(false)
        row:SetText("- " .. line)
        self.objectivesList:AddItem(row)
    end

    if kind == "ACCEPTED" then
        local cur, total = nil, nil
        local progressText = _G.QuestStateManager and QuestStateManager.GetQuestProgress(ndx)
        if progressText and progressText ~= "" then
            cur, total = string.match(progressText, "(%d+)%s*/%s*(%d+)")
            cur, total = tonumber(cur), tonumber(total)
        end
        if cur and total and total > 0 then
            local pct = math.min(1, cur / total)
            self.progressFill:SetWidth(math.max(2, math.floor(179 * pct)))
            self.lblProgress:SetText(cur .. "/" .. total)
            self.progressBack:SetVisible(true)
        else
            self.progressBack:SetVisible(false)
        end
    else
        self.progressBack:SetVisible(false)
    end

    local loc = _G.MoorMapAdapter and MoorMapAdapter.ResolveQuestLoc(ndx, quest)
    if loc and _G.MoorMapAdapter then
        self.btnGo:SetText((_G.LanguageSettings and LanguageSettings.IsSpanish()) and "Ir" or "Go")
        self.btnGo:SetVisible(true)

        if self.goQuickslot == nil then
            self.goQuickslot = MoorMapAdapter.CreateQuickslot()
            MoorMapAdapter.AttachToButton(self.goQuickslot, self.btnGo)
        end
        local ns, ew = MoorMapAdapter.ParseCoord(loc)
        MoorMapAdapter.SetQuestMarker(self.goQuickslot, {
            mapID = MoorMapAdapter.ResolveMapID(quest),
            ns = ns or 0,
            ew = ew or 0,
            name = string.gsub(esName, ":", "-"),
            description = "Objetivo",
        })
    else
        self.btnGo:SetVisible(false)
    end

    self:SetVisible(true)
end
