# TisteltiGuild

Addon para WoW Forever (interfaz 16001). Versión inicial del repositorio: **0.8.1-beta**.

Panel de grupo y hermandad, profesiones, encargos, equipo, diario de aventuras y mapa.

## Instalación

Copia la carpeta `TisteltiGuild` de este repositorio dentro de `_forever_/Interface/AddOns/`. Debe quedar `AddOns/TisteltiGuild/TisteltiGuild.toc`. Activa el addon en el juego.

Abre el panel con `/tisteltiguild` o `/guildpanel`, y el diario con `/diarioguild`.

## Código y datos

Los archivos Lua y el manifiesto TOC están en `TisteltiGuild/`; las texturas están en `TisteltiGuild/Media/`. El manifiesto define el orden de carga.

El addon se mantiene separado de TisteltiPlates. `DiarioGuild` es una dependencia opcional de compatibilidad con datos anteriores, no necesaria para instalaciones nuevas.

La configuración se guarda en `TisteltiGuildDB` y `TisteltiJourneyDB`. Este repositorio no incluye SavedVariables, datos de jugadores ni credenciales.

## Estado

Código importado del paquete `TisteltiGuild-0.8.1-beta-para-compartir.zip` sin modificar su comportamiento. La comprobación de archivos y manifiesto no sustituye las pruebas dentro del juego.
