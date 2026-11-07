# TisteltiGuild

Addon para WoW Forever (interfaz 16001). Versión actual **0.9.2-beta**.

Panel de grupo y hermandad, profesiones, encargos, equipo, diario de aventuras y mapa.

## Instalación

Copia la carpeta `TisteltiGuild` de este repositorio dentro de `_forever_/Interface/AddOns/`. Debe quedar `AddOns/TisteltiGuild/TisteltiGuild.toc`. Activa el addon en el juego.

Abre el panel con `/tisteltiguild` o `/guildpanel`, y el diario con `/diarioguild`.

## Código y datos

Los archivos Lua y el manifiesto TOC están en `TisteltiGuild/`; las texturas están en `TisteltiGuild/Media/`. El manifiesto define el orden de carga.

El addon se mantiene separado de TisteltiPlates. `DiarioGuild` es una dependencia opcional de compatibilidad con datos anteriores, no necesaria para instalaciones nuevas.

La configuración se guarda en `TisteltiGuildDB` y `TisteltiJourneyDB`. Este repositorio no incluye SavedVariables, datos de jugadores ni credenciales.

## Estado

Banco con pestañas, casillas, iconos y cantidades. Las posiciones se registran al abrir el banco. Integración del mapa de hermandad con OpenMap y diagnóstico mediante `/tisteltimapa`.

El mapa excluye el personaje propio y los miembros del grupo o banda para evitar marcadores duplicados, teniendo en cuenta los apellidos de Forever. Equipo muestra fichas en dos columnas con nombres centrados y retratos de las unidades disponibles.

Comprobaciones en Lua 5.1: filtrado de marcadores, cambios de grupo, distribución de fichas, retratos y reutilización de filas.

En 0.9.2, los puntos de hermandad compensan el zoom mediante su tamaño, conservando los offsets en las unidades del lienzo. La posición y el tamaño se actualizan durante la animación de zoom y los cambios de mapa anfitrión de OpenMap.

Regresión del mapa: `python tests/test_guild_map_zoom.py` (requiere Python con `lupa`). Incluye zoom de 0,25 a 8, desplazamiento, cambios de mapa y filtrado de grupo; son pruebas simuladas, pendientes de verificación visual en el juego.

Pendiente de confirmar en el juego la lectura visual del banco y las posiciones compartidas entre dos jugadores.
