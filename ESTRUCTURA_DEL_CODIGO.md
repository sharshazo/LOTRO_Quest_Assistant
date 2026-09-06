# Estructura del Código — QuestSync (`LOTRO_Quest_Assistant`)

**Addon:** `LOTRO_Quest_Assistant` (nombre final/interno: **QuestSync**)
**Autor:** Cube (también autor de WarbandsSlayer y DeedTracker, ambos reutilizados/integrados aquí)
**Última actualización de este documento:** 2026-08-20.

Este archivo vive DENTRO de la carpeta del addon (se copia junto con todo lo demás en cada `deploy.py`) para que la estructura y el historial de bugs queden guardados con el propio addon, no solo en apuntes externos. Describe el estado ACTUAL del código: qué hace cada archivo, cómo se conectan entre sí, y por qué está construido así — no es una bitácora cronológica completa (eso vive en la memoria de la sesión de desarrollo), pero sí resume los bugs reales más importantes y por qué se resolvieron como se resolvieron.

---

## 1. Qué hace el addon

QuestSync lee el chat de LOTRO en tiempo real, detecta cuándo el jugador acepta, avanza, completa o abandona una misión, y muestra esa información en español (traducción profesional del cliente, nunca traducción automática) en una ventana única con pestañas (más un HUD chico flotante). Permite saltar directo a la ubicación de cualquier misión, punto de interés, amenaza o colección usando dos addons ya existentes — **MoorMap** (mapa con marcador) y **Waypoint** (flecha direccional) — sin que el jugador escriba el comando a mano. También se integra con **DeedTracker** (mismo autor): comparte el gancho de chat y muestra las proezas en curso de ese addon en su propio Tracker.

LOTRO no permite que un addon ejecute comandos de chat por código directamente. El mecanismo "click en un botón → se abre MoorMap/Waypoint" pasa por un truco: cada botón visible tiene, escondido detrás y del mismo tamaño, un `Turbine.UI.Lotro.Quickslot` invisible con un `Shortcut` (alias) ya cargado con el comando exacto. Al hacer click, LOTRO ejecuta el shortcut como si el jugador lo hubiera tecleado.

## 2. Estructura de carpetas

```
LOTRO_Quest_Assistant/
├── QuestSync.plugin                  # manifest (unico -- ver §10, duplicado borrado 2026-09-05)
├── Main.lua                          # orquestador: orden de carga, /questsync, /cofres, chat hook compartido
├── ESTRUCTURA_DEL_CODIGO.md          # este archivo
├── Core/
│   ├── EventBus.lua                  # namespace _G.LQA, pub/sub, LQA.Debug.Enabled
│   ├── QuestEventParser.lua          # detecta ACEPTADA/PROGRESO/COMPLETADA/ABANDONADA en chat
│   ├── QuestLocResolver.lua          # texto de chat -> ndx (con desambiguación), NormalizeES
│   ├── QuestStateManager.lua         # única fuente de verdad del estado (activa/completada/rastreada)
│   ├── LanguageSettings.lua          # toggle ES/EN, persistido, publica LANGUAGE_CHANGED
│   ├── NavigationParser.lua          # NO usado (ver §8)
│   ├── QuestManager.lua              # NO usado (legacy, ver §8)
│   └── QuestResolver.lua             # NO usado (legacy, ver §8)
├── Data/
│   ├── QuestDatabase.lua             # loader maestro: importa los 10 bloques de abajo
│   ├── QuestDatabase_001..010.lua    # catálogo de las 14.824 misiones (id, ndx, area, zone, nivel, prev/next...)
│   ├── QuestNameIndex.lua            # nombre EN (minúscula) -> ndx
│   ├── QuestZoneIndex.lua            # índice por zona (EN)
│   ├── QuestNameESIndex_Full.lua     # nombre ES -> lista de ndx candidatos (base completa, 14.824)
│   ├── QuestNameESIndex_Lv1_10.lua   # igual, extracción más rica de nivel 1-10 (se fusiona encima)
│   ├── QuestObjectiveESIndex_Full.lua # texto de objetivo ES -> lista de ndx (base completa)
│   ├── QuestLocES_Full.lua           # ndx -> {nameES=...} (base completa, 14.824)
│   ├── QuestLocalization_Full.lua    # ndx -> {nameES=..., objectivesES={...}} (base completa) — fuente real de _G.QuestLocES
│   ├── QuestLocCoords.lua            # ndx -> "NS, EW" (una coordenada por misión)
│   ├── QuestStagesCoords.lua         # ndx -> {{name, nameES, loc}, ...} (todas las coordenadas conocidas)
│   ├── ZoneMapIndex.lua              # nombre de área/zona (EN, normalizado) -> mapID de MoorMap (703 entradas, ver §6.3)
│   ├── ChestsDB.lua                  # cacerías de tesoro (extraído de WarbandsSlayer)
│   ├── ThreatsDB.lua                 # jefes/amenazas itinerantes con nombre propio
│   ├── LostLoreDB.lua                # colecciones extraídas de LostLore 3.7.3 (277 entradas, 1.962 puntos)
│   ├── WarbandMapBounds.lua          # caja delimitadora NS/EW de cada mapa interno usado (53 mapas)
│   ├── QuestLocES.lua                # VIEJO, con mojibake — NO se importa (ver §8)
│   └── FarmingDB.lua                 # generado pero NO se importa (ver §8)
├── Legacy/
│   ├── MoorMapAdapter.lua            # integración con MoorMap (SÍ se usa pese al nombre de carpeta)
│   ├── WaypointAdapter.lua           # integración con Waypoint (SÍ se usa)
│   ├── QuestDatabase.lua             # NO usado (legacy, ver §8)
│   └── QuestObjectiveIndex.lua       # NO usado (legacy, ver §8)
├── UI/
│   ├── QuestSyncWindow.lua           # ventana ÚNICA ("QuestSync") — misiones + puntos de interés + tropas + colecciones
│   ├── QuestTrackerHUD.lua           # ventana chica flotante ("QuestSync Tracker") — misiones activas + proezas de DeedTracker
│   ├── QuestSyncLauncher.lua         # icono flotante arrastrable "QS" que abre/cierra ventana + HUD
│   ├── QuestInfoTooltip.lua          # tooltip al pasar el mouse (portado de DeedTracker/DeedTooltipWindow.lua)
│   ├── ChestsWindow.lua              # NO IMPORTADO desde sesión 35 (fusionado en QuestSyncWindow.lua, ver §7.1)
│   └── NavigationPanel.lua           # NO usado (ver §8)
├── Resources/
│   ├── Maps/                         # 53 imágenes .jpg de mapa (copiadas de WarbandsSlayer)
│   ├── ProgressBar.tga / ProgressBar_Back.tga / ProgressBarComplete.tga   # copiadas de DeedTracker
│   ├── lostlore_book.tga / lostlore_treasure.tga
│   └── chest.jpg / chestFound.jpg
├── Map/ Nav/ Persistence/ Utils/     # vacías (quedaron del plan original, todo terminó en Core/Data/Legacy/UI)
└── tools/QuestSync/
    ├── validate_lua_project.py       # backticks/llaves-paréntesis desbalanceados/BOM
    └── deploy.py                     # valida + copia a Plugins/ real + compara hash SHA-256
```

## 3. Orden de carga (`Main.lua`)

El orden importa: la localización en español tiene que estar lista ANTES de crear la UI (si no, las misiones se muestran en inglés — bug de la sesión 1, corregido).

```
1. Core/EventBus.lua              (declara _G.LQA y LQA.Debug.Enabled)
2. Data/QuestDatabase.lua + índices + ZoneMapIndex + ChestsDB/ThreatsDB/LostLoreDB + WarbandMapBounds
2b. FUSIÓN de localización (en Main.lua):
    _G.QuestNameESIndex = QuestNameESIndex_Full
    _G.QuestObjectiveESIndex = QuestObjectiveESIndex_Full
    _G.QuestLocES = QuestLocalization_Full
3. Core/QuestLocResolver.lua → QuestStateManager.lua → QuestEventParser.lua → LanguageSettings.lua
4. Legacy/MoorMapAdapter.lua → WaypointAdapter.lua
5. UI/QuestInfoTooltip.lua → QuestTrackerHUD.lua → QuestSyncWindow.lua → QuestSyncLauncher.lua
   QuestStateManager.Initialize()      -- carga async del guardado anterior
   LanguageSettings.Initialize()
   _G.HUD = QuestTrackerHUD()
   _G.MainWindow = QuestSyncWindow()   -- oculta por defecto
   _G.Launcher = QuestSyncLauncher()
   registro de /questsync (alias /qs) y /cofres (alias /qcofres)
   instalación del dispatcher de chat compartido con DeedTracker (ver §4b)
```

## 4. Flujo de extremo a extremo (chat → pantalla)

```
Chat de LOTRO (Turbine.ChatType.Quest, o Standard si contiene "/" o ":")
   │
   ▼
Main.lua: dispatcher compartido (_G.LQA_ChatHookRef) → OnChatReceived
   - descarta mensajes propios (contienen "QuestSync:" o "<rgb=")
   │
   ▼
QuestEventParser.ParseMessage(sender, message)
   - PROGRESO   "Texto (N/M)" o "Texto: N/M"   → primero, es lo más frecuente
   - ACEPTADA   "Nueva misión: X" / "Has aceptado la misión: X" / etc.
   - COMPLETADA "Completado: X" / "Misión completada: X" / etc.
   - ABANDONADA "Has abandonado la misión: X" / etc.
   - FALLBACK   si nada coincidió, prueba el mensaje ENTERO contra nombres/objetivos
                conocidos (reafirma estado, solo activa si la coincidencia fue por
                OBJETIVO exacto — nunca por nombre suelto, evita falsos positivos
                de diálogo de NPC)
   │
   ▼
QuestLocResolver.FindQuestByAnyName(texto)
   - normaliza (minúsculas + tildes, byte a byte, UTF-8-seguro)
   - busca en QuestNameESIndex, si no QuestObjectiveESIndex, si no QuestNameIndex (EN)
   - 1 candidato → SUCCESS
   - varios candidatos: ¿exactamente 1 ya ACTIVA? (solo para OBJETIVO) → esa
                        si no, ¿exactamente 1 con "prev" completada/activa? → esa
                        si no → AMBIGUA, nunca se adivina
   │
   ▼
QuestStateManager.SetQuestActive / UpdateProgress / SetQuestCompleted / SetQuestAbandoned
   - actualiza State.active / State.completed / State.tracked
   - Turbine.PluginData.Save (persiste entre sesiones)
   - EventBus:Publish("QUEST_STATE_CHANGED" / "QUEST_PROGRESS" / "QUEST_TRACKED", {ndx=...})
   │
   ▼
QuestSyncWindow / QuestTrackerHUD (suscritos a esos 3 eventos)
   - QuestSyncWindow: si está VISIBLE, repuebla la lista; si está oculta, solo marca
     self.pendingRepopulate=true y repuebla una vez al reabrirse (VisibleChanged) —
     evita escanear las 14.824 misiones en cada línea de chat mientras la ventana
     está cerrada (bug de rendimiento real, corregido 2026-08-20)
   - colores de estado (StateColor): Beige=disponible, LightBlue=activa, (0,1,0)=completada
     — paleta alineada a propósito con la de DeedTracker (mismo autor, mismo criterio visual)
   - piden a MoorMapAdapter/WaypointAdapter que actualicen los Quickslots detrás de
     cada botón "Ir"/"Mapa"/"Ruta" con la coordenada correcta
```

## 4b. Gancho de chat compartido con DeedTracker

`_G.LQA_ChatListeners` (tabla `nombre -> función`), `_G.LQA_ChatHookRef`, `_G.LQA_ChatHookInstalled`, `_G.LQA_ChatHookWatcher`. Cualquiera de los 2 addons que cargue primero instala UN dispatcher compartido que encadena sobre lo que hubiera antes en `Turbine.Chat.Received` (nil, una función, o una TABLA de funciones — confirmado que MoorMap usa esa 3ª forma) y llama a cada listener registrado. Un watchdog (control con `SetWantsUpdates(true)`, chequea cada 1s) reinstala el dispatcher si un 3er addon mal comportado (Waypoint/WarbandsSlayer/ChatNotif, todos hacen `Turbine.Chat.Received = function...end` sin encadenar) lo pisa. `QuestSync` se registra como `_G.LQA_ChatListeners["QuestSync"] = OnChatReceived`; `DeedTracker` se registra igual bajo `"DeedTracker"`. Ambos archivos (`Main.lua` aquí, `ChatLogger.lua` en DeedTracker) implementan el MISMO contrato — si alguna vez se toca uno, revisar que el otro siga siendo idéntico en la firma del dispatcher.

## 5. Módulos `Core/`

### 5.1 `EventBus.lua`
Namespace `_G.LQA` (`LQA.Core`, `LQA.Data`, `LQA.UI`, `LQA.Map`, `LQA.Nav`, `LQA.Localization`, `LQA.Debug`) y pub/sub (`Subscribe`/`Publish`). `LQA.Debug.Enabled` es el único interruptor de depuración de todo el addon — `false` por defecto.

### 5.2 `QuestEventParser.lua`
Tabla `PATTERNS` (ACCEPTED/COMPLETED/PROGRESS/ABANDONED), cada patrón usa `%s*` en vez de espacio literal (LOTRO a veces parte el nombre en una línea separada del contador). Los acentos van como variantes literales lado a lado ("misión"/"mision") porque Lua no tiene alternancia `(a|b)` ni clases de caracteres UTF-8-seguras. Función pública única: `ParseMessage(sender, message)`.

### 5.3 `QuestLocResolver.lua`
- `GetQuestNameES(ndx_or_nombreEN, fallbackEN)`
- `FindQuestByAnyName(nameRaw)` → `status, ndx_o_lista, resType` (`"SUCCESS"`/`"AMBIGUA"`/`"FAIL"`; `resType` = `"NAME"`/`"OBJECTIVE"`/`"..._CHAIN"`/`"..._ACTIVE"`)
- `NormalizeES(s)` — minúsculas + plegado de tildes byte-a-byte, expuesto para que otros archivos (buscador de `QuestSyncWindow.lua`) no dupliquen la lógica.

### 5.4 `QuestStateManager.lua`
Única fuente de verdad. `State = {active={}, completed={}, tracked=nil}`. `SetQuestActive` limpia `completed[ndx]` (repetibles). `SetQuestCompleted` mueve de `active` a `completed` sin exigir que estuviera activa antes. `ResetQuest` es el "Desmarcar" manual de la UI.

## 6. Adapters (`Legacy/MoorMapAdapter.lua`, `WaypointAdapter.lua`)

### 6.1 El truco del Quickslot
```lua
function MoorMapAdapter.CreateQuickslot()
    local qs = Turbine.UI.Lotro.Quickslot()
    qs:SetSize(32, 32)
    qs:SetVisible(true)   -- debe ser true para recibir clics
    qs:SetOpacity(0)      -- se oculta con opacidad, no con Visible(false)
    qs:SetAllowDrop(false) -- evita que acepte arrastrar-soltar (bug de sesión pasada)
    return qs
end

function MoorMapAdapter.AttachToButton(quickslot, button)
    quickslot:SetParent(button)
    local w, h = button:GetSize()
    quickslot:SetPosition(0, 0)
    quickslot:SetSize(w, h)
    quickslot:SetZOrder(10)
end
```
Cada botón visible (`Turbine.UI.Lotro.Button`, nunca una `Label` plana) tiene su PROPIO Quickslot como HIJO, mismo tamaño, `SetZOrder(10)` para recibir el clic. **Nunca se comparte un Quickslot entre 2 botones** — un control solo puede tener un padre a la vez.

**Sangrado de texto "/MOO"/"/WAY" — investigado a fondo, no resuelto, y por qué no se sigue intentando a ciegas:** un `Turbine.UI.Lotro.Quickslot` con un shortcut de tipo Alias muestra su propio tooltip nativo ("ALIAS: <comando completo>") al pasar el mouse — **esto NO es un bug de este addon, es el comportamiento nativo e inevitable de LOTRO para cualquier control que reciba un clic real de esa forma** (confirmado con una captura de pantalla real del usuario mostrando el tooltip completo). Se intentó una restructuración (Quickslot como hermano del botón en vez de hijo, con `SetMouseVisible(false)` en el botón para dejar pasar el clic) pero se **revirtió** en la misma sesión que se probó: no se encontró en NINGÚN addon de este entorno un caso real y comprobado de ese patrón exacto de "clic atravesando un hermano invisible al mouse hacia otro control detrás" — todos los usos reales de `SetMouseVisible(false)` en este entorno son de un HIJO decorativo dejando que su PADRE reciba el clic (burbujeo normal), no de hermano a hermano. Arriesgar que los botones de navegación dejen de responder por una hipótesis cosmética no verificada no valía la pena. La estructura actual (child + Opacity(0) + ZOrder(10)) es la versión SEGURA, con clic garantizado — el sangrado visual queda como limitación conocida, no un bug abierto a "arreglar" con otro intento a ciegas.

### 6.2 `MoorMapAdapter.ParseCoord(texto)`
Convierte `"25.29S, 47.61W"` a un par de números con signo (`-25.29, -47.61}`) — MoorMap exige signo, no letra pegada.

### 6.3 `MoorMapAdapter.ResolveMapID(quest)` — el más complejo del addon
Compara `quest.area`/`quest.zone` (inglés, Compendium) contra `ZoneMapIndex` probando hasta 16 variantes: con/sin paréntesis, con/sin sufijo tras coma, con/sin prefijo "the ", con/sin acentos plegados. Cubre ~85,9% de las 14.824 misiones. El resto son mayormente misiones de instancia sin `area`/`zone` (no hay nada que resolver) o zonas que MoorMap 1.66 no tiene mapeadas bajo ningún nombre. **`ZoneMapIndex.lua` fue verificado el 2026-08-20 contra el archivo real `Defaults.lua` de MoorMap (fórmula de validación real extraída de `GaranStuff/MoorMap/Main.lua` línea ~6117) y está limpio — 0 ids inexistentes, 0 discrepancias reales de nombre.**

### 6.4 `MoorMapAdapter.ResolveQuestLoc(ndx, quest)`
Coordenada "por defecto" de una misión: `quest.loc` (nunca presente hoy) → primer lugar de `QuestStagesCoords` → `QuestLocCoords`. Punto único usado por ambas ventanas.

### 6.5 `WaypointAdapter`
Más simple: solo necesita el string crudo de coordenada, Waypoint lo parsea solo, sin mapID. Por eso casi el 100% de las misiones con coordenada conocida tienen flecha de Waypoint funcional aunque MoorMap no pueda ubicarlas.

### 6.6 Limitación conocida y aceptada: "sub-mapa vs. mapa general"
Una coordenada de una sub-zona específica (ej. "Nain Enidh" dentro de "Ered Luin") a veces no encaja en el sistema de coordenadas del mapa GENERAL de MoorMap para esa región amplia — no es un signo invertido, es una escala/proyección distinta que ni corrigiendo el signo se arregla. Investigado a fondo en varias sesiones (incluida una verificación cruzada contra una guía real de la comunidad para un caso concreto) — **no se intenta corregir en masa por heurística**, cada caso necesitaría verificación externa real. Cuando MoorMap tira "Coordenada NS/EO del mapa no válida", primero comprobar con la fórmula real (§6.3, misma que usa DeedTracker) si es este caso antes de asumir que es un bug nuevo.

## 7. UI

### 7.1 `QuestSyncWindow.lua` — ventana única con pestañas
700×720 (mínimo 700×600, redimensionable). Pestañas: "QuestSync" (misiones), "Puntos de Interes" (ChestsDB), "Tropas y Amenazas" (ThreatsDB), "Colecciones" (LostLoreDB) + botón de idioma ES/EN. Banda superior fija: misión activa/rastreada + progreso + botón "Ir". Columna izquierda (270px): lista agrupada por área/zona, plegable. Columna derecha: panel de detalle (misión seleccionada O punto de interés/amenaza/colección seleccionado), comparten la misma lista `pointsList` para el desglose de lugares.

**Buscador** (solo en la pestaña QuestSync): busca por nombre (ES/EN) o texto de objetivo entre las 14.824 misiones, debounce de 0.35s, resultados planos con `[Área]` de sufijo, tope de 200 con aviso visible (nunca trunca en silencio).

**`AddQuestListRow`**: fila de la lista principal — el texto más visto de todo el addon. Tenía una fuente sin especificar (usaba lo que fuera el default del SDK) hasta que se detectó en una auditoría explícita el 2026-08-20; ahora usa `Verdana12` explícito (no `Verdana14` como DeedTracker usa para sus nombres — sus nombres son de una sola línea, los de QuestSync necesitan 2-3, y una fuente más grande reduciría caracteres por línea forzando una 4ª línea sin recalcular la altura de fila).

**Rendimiento**: `OnQuestEvent` (suscrito a los 3 eventos de misión) solo repuebla la lista si `self:IsVisible()` es verdadero — si la ventana está cerrada, solo marca `self.pendingRepopulate=true`, y `self.VisibleChanged` la repuebla una sola vez al reabrirse. Antes de este fix (2026-08-20), cada línea de chat con progreso escaneaba las 14.824 misiones DOS VECES para repintar una lista que nadie estaba viendo.

### 7.2 `QuestTrackerHUD.lua` — ventana chica flotante
Mínimo 220×160, redimensionable. Lista TODAS las misiones activas del mapa actual con nombre+progreso+botón "Ir" en `LightBlue` (mismo color que DeedTracker usa para "en progreso"). También lista, con una insignia violeta separada, las proezas en curso de DeedTracker (`_G.LQA_InProgressDeeds`, chequeado cada 2s) — **limitación conocida**: esa tabla nunca se limpia cuando una proeza se completa en DeedTracker (no hay ningún global que exponga "completada" del otro lado), así que puede seguir apareciendo como "en curso" hasta cerrar sesión.

### 7.3 `QuestSyncLauncher.lua` — icono flotante "QS"
40×40, arrastrable, posición persistida (`Turbine.PluginData`, clave `QuestSync_LauncherPos`). Clic simple → `ToggleWindows()` (muestra/oculta MainWindow+HUD juntas). Sin Quickslot — solo llama funciones Lua propias, no dispara comandos de LOTRO.

### 7.4 `QuestInfoTooltip.lua` — tooltip al pasar el mouse
Ventana flotante (patrón portado de `DeedTracker/DeedTooltipWindow.lua`). Muestra nivel/área y hasta 2 líneas de objetivo REAL, filtrando frases de diálogo/flavor-text: **bug real corregido 2026-08-20** — antes usaba `objectivesES[1]`/`[2]` por índice fijo asumiendo que [1] es "resumen" y [2] "objetivo corto"; en el 23,5% de las 14.824 misiones esa suposición es falsa (el array trae citas de PNJ mezcladas, en cualquier posición). Ahora `IsFlavorText(s, nameEN)` descarta cualquier entrada que empiece con `'`/`"`/¡/¿ (comparando el byte correcto: ¡/¿ ocupan 2 bytes en UTF-8, un bug de "un byte vs. dos" que se coló en la primera versión de este mismo fix y se corrigió el mismo día) o que sea igual al nombre en inglés, y usa las primeras 2 entradas limpias que encuentre en cualquier posición. Medido: **0 de las 14.824 misiones tienen el array completamente vacío de texto limpio** — la corrección cubre toda la base sin necesitar curar contenido a mano.

### 7.5 Paleta de colores — alineada con DeedTracker a propósito
`StateColor()` en `QuestSyncWindow.lua`: `Beige` (disponible, antes gris plano), `LightBlue` (activa, antes azul RGB a mano), `(0,1,0)` (completada, antes verde RGB a mano) — igualada el 2026-08-20 a los colores reales que usa `DeedTracker/MainWin.lua` (`deedForeColor`/`LightBlue`/`(0,1,0)`), a pedido explícito del usuario de unificar el formato visual entre los dos addons del mismo autor. Encabezados de sección: `Turbine.UI.Color.Yellow` (antes un dorado apagado a mano), mismo criterio.

## 8. Código NO usado (no tocar sin pedirlo explícitamente)

`Core/NavigationParser.lua`, `Core/QuestManager.lua`, `Core/QuestResolver.lua`, `Legacy/QuestDatabase.lua`, `Legacy/QuestObjectiveIndex.lua`, `UI/NavigationPanel.lua`, `UI/ChestsWindow.lua` (fusionado dentro de `QuestSyncWindow.lua`), `Data/QuestLocES.lua` (mojibake heredado de una extracción TSV vieja), `Data/FarmingDB.lua` (solo 8/34 entradas con coordenada, la pestaña que lo usaba se sacó). Inofensivos porque `Main.lua` nunca los importa — no asumir que hacen algo.

## 9. Herramientas de build (`tools/QuestSync/`)

- **`validate_lua_project.py`** — antes de cada deploy: sin backticks sueltos, sin llaves/paréntesis desbalanceados, sin BOM de UTF-8.
- **`deploy.py`** — valida, copia `LOTRO_Quest_Assistant/` a la carpeta `Plugins/` real, compara hash SHA-256 origen/destino. **Nunca se edita `Plugins/` a mano.**
- No hay verificador de balance `function/if/for/while/do/repeat` vs `end` en el repo (el validador solo chequea llaves/paréntesis/backticks/BOM) — se escribió uno ad-hoc en Python durante la auditoría del 2026-08-20 (vive en el scratchpad de esa sesión, no en el repo) que SÍ detecta ese tipo de desbalance; considerar agregarlo a `tools/QuestSync/` si se repiten sesiones de auditoría estructural.

## 10. Notas y advertencias estructurales

- **Resuelto 2026-09-05**: había dos archivos `.plugin` (`LOTRO_Quest_Assistant.plugin`/`QuestSync.plugin`) apuntando al mismo `Package` — riesgo de doble carga si el usuario tildaba los dos en el gestor de addons. Se borró `LOTRO_Quest_Assistant.plugin` (dev y desplegado), queda `QuestSync.plugin` como único manifest.
- Lua no garantiza el orden de `pairs()` — cualquier lista que dependa de orden estable debe ordenarse explícitamente por `ndx` (ya hecho en `PopulateList`).
- Los archivos de `Data/` con texto en español están en UTF-8 literal (sin escapes `\DDD`) — mantener esa convención al generar datos nuevos.
- **Nunca usar PowerShell `Set-Content`/`Out-File -Encoding utf8` sobre archivos `.lua`** — agrega BOM y rompe el parser de Lua. Usar herramientas de edición directa (Read/Edit) o Python con `encoding='utf-8'` explícito sin BOM.

## 11. Reglas permanentes del proyecto

- El `ndx` es la única identidad real de una misión — nunca el nombre en inglés o español.
- Compendium = fuente de estructura; el DAT profesional / extracción de LOTRO Companion = fuente de verdad de traducción. Nunca traducir con IA si ya existe un string profesional en español; nunca inventar nombres.
- `QuestStateManager` es la única autoridad sobre el estado de una misión; `QuestDatabase` es solo catálogo.
- MoorMap y Waypoint se reutilizan vía sus adapters, nunca se reconstruyen.
- Nunca editar la carpeta `Plugins/` en vivo directamente — siempre desplegar vía `deploy.py`.
- Antes de "corregir" el sangrado de texto bajo los botones MoorMap/Waypoint otra vez: leer §6.1 completo primero. Ya se investigó a fondo, se intentó una vez, y se revirtió por falta de evidencia — no es terreno nuevo.
