-- QuestSync Data/GatherNodesDB.lua
-- Generado a partir de LOTRO_recoleccion_tiers.md (ver ese archivo para fuentes y metodologia).
-- Todos los nombres en espanol vienen confirmados por ID compartido con el diccionario maestro
-- (LotRO Companion/app/data/lore/labels/{en,es}/items.xml y crafting.xml) -- ninguno fue
-- traducido a mano. Entradas donde el nombre en espanol no estaba confirmado en el diccionario
-- se dejaron afuera a proposito (mejor no reconocer un nodo/item que reconocerlo mal).
--
-- Estructura: _G.GatherNodesDB.byNode[nombreDelNodoEnChat] y .byItem[nombreDelItemEnChat]
-- apuntan al MISMO objeto "entry" para un nodo dado -- asi el detector puede confirmar el
-- evento por la linea "Tomando los contenidos de X..." (la mas confiable, ver
-- Arquitectura_GatherSync.md #3.2) o por la linea "Has adquirido: [item]" si hace falta.
--
-- confidence: "alta" | "media" | "baja" -- copiado directo de LOTRO_recoleccion_tiers.md,
-- para que la UI pueda mostrar "Tier ~11 (sin confirmar del todo)" en vez de afirmarlo como
-- un hecho cuando la fuente original no estaba segura.

_G.GatherNodesDB = {
    byNode = {},
    byItem = {},
}

local function register(entry, nodeNames, itemNames)
    -- BUG (encontrado en vivo 2026-08-23): ninguna entrada traia el campo
    -- "node" -- GatherPointsStore/GatherEventParser lo leen para mostrar el
    -- nombre (confirmado en el chat real: "punto nuevo guardado -> nil").
    -- Se deriva del primer nombre de nodeNames (el nombre "principal", ej.
    -- "Veta de cobre" antes que su variante "Depósito abundante de cobre").
    if entry.node == nil and nodeNames ~= nil and nodeNames[1] ~= nil then
        entry.node = nodeNames[1]
    end
    for _, n in ipairs(nodeNames or {}) do
        _G.GatherNodesDB.byNode[n] = entry
    end
    for _, i in ipairs(itemNames or {}) do
        _G.GatherNodesDB.byItem[i] = entry
    end
end

---------------------------------------------------------------------
-- MINERO (Prospector)
---------------------------------------------------------------------

register({ profession = "MINERO", tier = 1, zone = "Apprentice", confidence = "alta" },
    { "Veta de cobre", "Depósito abundante de cobre" },
    { "Bloque de mineral de cobre" })

register({ profession = "MINERO", tier = 1, zone = "Apprentice", confidence = "alta" },
    { "Veta de estaño" },
    {}) -- item "Chunk of Tin Ore" sin confirmar en diccionario

register({ profession = "MINERO", tier = 2, zone = "Journeyman", confidence = "alta" },
    { "Veta de hierro tumulario", "Depósito abundante de hierro de los túmulos" },
    { "Trozo de mineral de hierro de los túmulos" })

register({ profession = "MINERO", tier = 2, zone = "Journeyman", confidence = "alta" },
    { "Veta de plata", "Depósito abundante de plata" },
    { "Trozo de mineral de plata" })

register({ profession = "MINERO", tier = 3, zone = "Expert", confidence = "alta" },
    { "Veta de hierro enriquecido", "Depósito abundante de hierro enriquecido" },
    { "Trozo de mineral de hierro enriquecido" })

register({ profession = "MINERO", tier = 3, zone = "Expert", confidence = "alta" },
    { "Veta de oro", "Depósito abundante de oro" },
    { "Trozo de mineral de oro" })

register({ profession = "MINERO", tier = 4, zone = "Artisan", confidence = "alta" },
    { "Veta de hierro enano", "Depósito abundante de hierro enano" },
    { "Trozo de mineral de hierro enano" })

register({ profession = "MINERO", tier = 4, zone = "Artisan", confidence = "alta" },
    { "Veta de platino", "Depósito abundante de platino" },
    { "Trozo de mineral de platino" })

register({ profession = "MINERO", tier = 5, zone = "Master", confidence = "alta" },
    { "Veta de hierro antiguo", "Depósito abundante de hierro antiguo" },
    { "Trozo de mineral de hierro antiguo" })

register({ profession = "MINERO", tier = 5, zone = "Master", confidence = "alta" },
    { "Veta de plata antigua", "Depósito abundante de plata antigua" },
    { "Trozo de mineral de plata antigua" })

register({ profession = "MINERO", tier = 6, zone = "Khazâd-dûm (Moria)", confidence = "alta" },
    { "Veta de skarn de Khazâd" },
    { "Trozo de skarn khazâd" })

register({ profession = "MINERO", tier = 7, zone = "Calenard", confidence = "alta" },
    { "Veta de skarn de Calenard" },
    { "Trozo de skarn de Calenard", "Trozo de skarn de alta calidad de Calenard" })

register({ profession = "MINERO", tier = 8, zone = "Eastemnet", confidence = "alta" },
    { "Veta de skarn de la Marca de los Jinetes" },
    { "Trozo de skarn de la Marca de los Jinetes", "Trozo de skarn de alta calidad de la Marca de los Jinetes" })

register({ profession = "MINERO", tier = 9, zone = "Westemnet", confidence = "alta" },
    { "Veta de skarn de los Eorlingas" },
    { "Trozo de skarn de los Eorlingas", "Trozo de skarn de alta calidad de los Eorlingas" })

register({ profession = "MINERO", tier = 10, zone = "Anórien", confidence = "alta" },
    { "Veta de skarn de Anórien" },
    { "Trozo de skarn de Anórien", "Trozo de skarn de Anórien de alta calidad" })

register({ profession = "MINERO", tier = 11, zone = "Dagorlad", confidence = "media" },
    { "Veta de chatarra de Dagorlad", "Depósito rico de chatarra de Dagorlad" },
    {})

register({ profession = "MINERO", tier = 11, zone = "Doomfold (Valle de la Perdición)", confidence = "baja" },
    {}, -- nombre del nodo no localizado
    { "Trozo de skarn del Valle de la Perdición", "Trozo de skarn de alta calidad del Valle de la Perdición" })

register({ profession = "MINERO", tier = 11, zone = "Gorgoroth", confidence = "media" },
    { "Veta de skarn de Gorgoroth", "Depósito rico de skarn de Gorgoroth" },
    {})

register({ profession = "MINERO", tier = 12, zone = "Erebor", confidence = "media" },
    { "Veta de skarn de Erebor", "Depósito rico de skarn de Erebor" },
    {})

register({ profession = "MINERO", tier = 12, zone = "Ironfold (Valle del Hierro)", confidence = "media" },
    { "Veta de skarn del Valle del Hierro" },
    { "Trozo de skarn del Valle del Hierro", "Trozo de skarn de alta calidad del Valle del Hierro" })

register({ profession = "MINERO", tier = 13, zone = "Vales de Anduin", confidence = "media-alta" },
    { "Veta de skarn de los Valles", "Depósito rico de skarn de los Valles" },
    {})

register({ profession = "MINERO", tier = 13, zone = "Minas Ithil", confidence = "alta" },
    { "Veta de skarn de Ithil" },
    { "Trozo de skarn de Minas Ithil", "Trozo de skarn de alta calidad de Minas Ithil" })

register({ profession = "MINERO", tier = 13, zone = "Langflood", confidence = "media" },
    { "Veta de skarn del Langflood" },
    { "Trozo de skarn de Langflood", "Trozo de skarn de alta calidad de Langflood" })

register({ profession = "MINERO", tier = 13, zone = "Khazâd-plata (nodo bonus)", confidence = "baja" },
    { "Veta de plata khazâd", "Depósito rico de plata khazâd" },
    {})

register({ profession = "MINERO", tier = 14, zone = "Gundabad", confidence = "alta" },
    { "Veta de skarn brillante" },
    { "Trozo de skarn de Gundabad", "Trozo de skarn de alta calidad de Gundabad" })

register({ profession = "MINERO", tier = 14, zone = "Khazâd (variante de nieve)", confidence = "baja" },
    { "Yacimiento de Skarn Khazâd Cubierto de Nieve", "Yacimiento Rico de Skarn Khazâd Cubierto de Nieve" },
    {})

register({ profession = "MINERO", tier = 15, zone = "Umbar", confidence = "alta" },
    { "Yacimiento de Mineral Iridiscente" },
    { "Trozo de hierro shagâni", "Trozo de hierro shagâni de alta calidad" })

register({ profession = "MINERO", tier = 16, zone = "Sul Madásh", confidence = "alta" },
    { "Veta de mena argentada" },
    {})

register({ profession = "MINERO", tier = 17, zone = "Mûrai", confidence = "media" },
    {}, -- nombre del nodo sin traduccion ES en el diccionario
    { "Trozo de mineral de hierro mûrai", "Trozo de mineral espejado mûrai" })

---------------------------------------------------------------------
-- LEÑADOR (Forester)
---------------------------------------------------------------------

register({ profession = "LEÑADOR", tier = 1, zone = "Apprentice", confidence = "alta" },
    { "Ramas de serbal" },
    { "Tronco de serbal" })

register({ profession = "LEÑADOR", tier = 2, zone = "Journeyman", confidence = "alta" },
    { "Ramas de fresno" },
    { "Tronco de fresno" })

register({ profession = "LEÑADOR", tier = 3, zone = "Expert", confidence = "alta" },
    { "Ramas de tejo" },
    { "Tronco de madera de tejo" })

register({ profession = "LEÑADOR", tier = 4, zone = "Artisan", confidence = "alta" },
    { "Ramas de lebethron" },
    { "Tronco de madera de Lebethron" })

register({ profession = "LEÑADOR", tier = 5, zone = "Master", confidence = "alta" },
    { "Ramas de fresno negro" },
    { "Tronco de fresno negro" })

register({ profession = "LEÑADOR", tier = 6, zone = "Eregion", confidence = "alta" },
    { "Ramas de acebo" },
    { "Tronco de madera de acebo" })

register({ profession = "LEÑADOR", tier = 7, zone = "Westfold", confidence = "alta" },
    { "Ramas de abedul" },
    { "Tronco de madera de abedul" })

register({ profession = "LEÑADOR", tier = 8, zone = "Eastemnet", confidence = "alta" },
    { "Ramas de roble" },
    { "Tronco de madera de roble" })

register({ profession = "LEÑADOR", tier = 9, zone = "Westemnet", confidence = "alta" },
    { "Ramas de nogal" },
    { "Tronco de madera de nogal" })

register({ profession = "LEÑADOR", tier = 10, zone = "Anórien", confidence = "alta" },
    { "Ramas de álamo", "Ramas nudosas" },
    {})

register({ profession = "LEÑADOR", tier = 11, zone = "Doomfold (Valle de la Perdición)", confidence = "media" },
    { "Ramas de Gorgoroth", "Ramas de Lasgalen" },
    {})

register({ profession = "LEÑADOR", tier = 12, zone = "Ironfold (Vales de Anduin)", confidence = "media" },
    { "Ramas de los Valles", "Ramas de Thornholt" },
    {})

register({ profession = "LEÑADOR", tier = 14, zone = "Gundabad", confidence = "media" },
    { "Ramas de fresno negro barridas por el viento" },
    {})

register({ profession = "LEÑADOR", tier = 15, zone = "Umbar", confidence = "media" },
    { "Ramas de Fresno Negro Costero" },
    {})

---------------------------------------------------------------------
-- GRANJERO (Farmer)
---------------------------------------------------------------------

register({ profession = "GRANJERO", tier = 1, zone = "Apprentice", confidence = "alta" },
    { "Campo de hoja Valle Largo" },
    {})

register({ profession = "GRANJERO", tier = 1, zone = "Apprentice", confidence = "alta" },
    { "Campo de Cebollas Amarillas" },
    { "Cebolla Amarilla" })

register({ profession = "GRANJERO", tier = 2, zone = "Journeyman", confidence = "alta" },
    { "Campo de Southern Star" },
    {})

register({ profession = "GRANJERO", tier = 2, zone = "Journeyman", confidence = "alta" },
    { "Campo de Repollos" },
    { "Repollo" })

register({ profession = "GRANJERO", tier = 3, zone = "Expert", confidence = "alta" },
    { "Campo de Galenas dulce" },
    {})

register({ profession = "GRANJERO", tier = 3, zone = "Expert", confidence = "alta" },
    { "Campo de Cebollas Verdes" },
    { "Cebolla verde" })

register({ profession = "GRANJERO", tier = 4, zone = "Artisan", confidence = "alta" },
    { "Campo de Fresas" },
    {})

register({ profession = "GRANJERO", tier = 4, zone = "Artisan", confidence = "alta" },
    { "Manzano de la Comarca" },
    { "Manzana de la Comarca" })

register({ profession = "GRANJERO", tier = 5, zone = "Master", confidence = "alta" },
    { "Campo de Zarzamoras" },
    {})

register({ profession = "GRANJERO", tier = 5, zone = "Master", confidence = "alta" },
    { "Campo de patatas doradas de la Comarca" },
    { "Patata dorada de la Comarca" })

register({ profession = "GRANJERO", tier = 6, zone = "Supreme", confidence = "alta" },
    { "Campo de guisantes verdes" },
    { "Guisantes verdes" })

register({ profession = "GRANJERO", tier = 6, zone = "Supreme", confidence = "alta" },
    { "Campo de patata real" },
    { "Patata real" })

register({ profession = "GRANJERO", tier = 7, zone = "Westfold", confidence = "alta" },
    { "Campo de cebada negra" },
    {})

register({ profession = "GRANJERO", tier = 7, zone = "Westfold", confidence = "alta" },
    { "Campo de puerros" },
    { "Puerros" })

register({ profession = "GRANJERO", tier = 7, zone = "Westfold", confidence = "alta" },
    { "Campo de arándanos" },
    {})

register({ profession = "GRANJERO", tier = 10, zone = "Anórien", confidence = "media" },
    {}, -- nombre del campo no localizado, solo el cultivo procesado
    { "Patata de Anórien" })

---------------------------------------------------------------------
-- ERUDITO (Scholar)
---------------------------------------------------------------------

register({ profession = "ERUDITO", tier = 1, zone = "Apprentice", confidence = "alta" },
    { "Jarra rota" },
    { "Trozo de Texto Antiguo" })

register({ profession = "ERUDITO", tier = 2, zone = "Journeyman", confidence = "alta" },
    { "Urna rota" },
    { "Fragmento de Tableta Desgastada" })

register({ profession = "ERUDITO", tier = 3, zone = "Expert", confidence = "alta" },
    { "Jarrón antiguo" }, -- ojo: mismo nombre ES que tier 5 (item ingles distinto, ver nota Tier 5)
    { "Tallado Enano Agrietado" })

register({ profession = "ERUDITO", tier = 4, zone = "Artisan", confidence = "alta" },
    { "Texto olvidado" },
    { "Fragmento de Escritura Dúnedain" })

register({ profession = "ERUDITO", tier = 5, zone = "Master", confidence = "alta" },
    {}, -- "Jarrón antiguo" ya registrado como nodo del tier 3 (mismo nombre ES, ambiguo -- no
        -- se puede distinguir tier 3 vs 5 solo por el nombre del nodo en chat)
    { "Tallado de elfo desgastado" })

register({ profession = "ERUDITO", tier = 6, zone = "Supreme", confidence = "alta" },
    { "Casillero del sabio", "Cofre del sabio", "Caja de seguridad del sabio" },
    { "Tableta tallada con runas" })

register({ profession = "ERUDITO", tier = 7, zone = "Westfold", confidence = "alta" },
    { "Cofre con bandas" },
    { "Trozo de texto dunlendino desgastado" })

register({ profession = "ERUDITO", tier = 8, zone = "Eastemnet", confidence = "alta" },
    { "Caché ornamentado" },
    { "Fragmento de texto rohirrim" })

register({ profession = "ERUDITO", tier = 9, zone = "Westemnet", confidence = "alta" },
    { "Cofre ornamentado" },
    { "Pergamino rohirrim raído" })

register({ profession = "ERUDITO", tier = 10, zone = "Anórien", confidence = "alta" },
    { "Cofre opulento" },
    { "Pergamino andrajoso de Anórien" })

register({ profession = "ERUDITO", tier = 12, zone = "Ironfold (Valle del Hierro)", confidence = "media" },
    { "Cofre de artefactos del Valle del Hierro" },
    {})

register({ profession = "ERUDITO", tier = 13, zone = "Minas Ithil", confidence = "alta" },
    { "Cofre de artefactos de Ithil" },
    { "Pergamino raído de Minas Ithil" })

register({ profession = "ERUDITO", tier = 14, zone = "Gundabad", confidence = "media" },
    {}, -- "Gundabad Artifact Chest" mencionado por la wiki, nombre exacto ES sin confirmar
    { "Pergamino andrajoso de Gundabad" })
