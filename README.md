# TisteltiGuild

Addon para WoW Forever (interfaz 16001). Versión actual **0.10.3-beta**.

Panel de grupo y hermandad, profesiones, encargos, equipo, diario de aventuras y mapa.

## Materiales y privacidad

**Grupo → Ubicación: sí/no** activa el envío de posición a la hermandad por personaje; empieza desactivado y al apagarlo se retira el marcador. Los nombres visibles conservan los apellidos de Forever y ocultan el reino interno.

**Profesiones → Repartir materiales** muestra los destinatarios de cada objeto de las bolsas, sus recetas aprendidas y los posibles usos futuros. Abre los libros de oficios de cada personaje para actualizar los datos. Las recetas por aprender dependen de conseguirlas; los datos antiguos sólo aportan recetas aprendidas. La sincronización ampliada requiere la versión 0.10 en los otros clientes.

La estrella guarda favoritos por material y los coloca primero, manteniendo entre ellos la valoración de recetas aprendidas y por aprender. El tooltip respeta el mismo orden. El borde usa un único color: el oficio del destinatario prioritario, con preferencia por recetas aprendidas si tiene varios oficios. El dorado de misión mantiene prioridad.

La leyenda muestra iconos con su neón. Pulsa un oficio para editar su color o **Restablecer colores** para recuperar los originales; **Neón: sí/no** permite apagar los bordes. Favoritos y colores se guardan localmente y no se publican a la hermandad.

El borde se aplica también al banco nativo personal (pestañas modernas o casillas clásicas), sus bolsas y al banco de hermandad. Se actualiza al cambiar pestaña, recibir datos o vaciar una casilla. La vista Banco del addon reconoce también los objetos antiguos de hermandad guardados sólo como enlace.

## Consejo y Auctionator

El tooltip de las bolsas y del banco muestra una acción principal: enviar al destinatario prioritario, reservar para una receta futura, subastar o vender al vendedor. Los favoritos tienen prioridad explícita. Los objetos ligados y de misión se conservan; no se recomiendan para subastar. Vender al vendedor sólo se propone para grises o materiales con una comparación de precios favorable, no para equipo sin evaluar.

Auctionator es opcional. Se consulta su API pública de último precio escaneado y antigüedad, sin modificar su base de datos ni publicar subastas. Los precios de más de tres días o con fecha desconocida se muestran como pendientes de actualizar y no generan el aviso de precio alto. La referencia de vendedor es el valor de venta de `C_Item.GetItemInfo`, no el coste de compra a un vendedor.

Un halo exterior dorado pulsante con moneda marca precios altos: por defecto al menos **1 oro por unidad y cinco veces su valor de venta al vendedor**. En Repartir materiales se puede apagar el aviso y cambiar ambos umbrales. El borde interior conserva el oficio prioritario; las misiones no reciben el halo de venta. El precio guardado es una referencia bruta, no una garantía de venta ni un cálculo de rentabilidad de fabricación.

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

Regresión del mapa: `python tests/test_guild_map_zoom.py` (requiere Python con `lupa`). Incluye zoom de 0,25 a 8, desplazamiento, cambios de mapa y filtrado de grupo. El usuario confirmó que el mapa funciona en el juego después de cargar la versión 0.9.2 con `/reload`.

Después de actualizar los archivos con el juego abierto, ejecutar `/reload`. `/tisteltimapa` debe mostrar 0.10.3 para comprobar que la versión está cargada.

Pendiente de confirmar en el juego la lectura visual del banco.

`python tests/test_guild_materials.py` (Python con `lupa`) comprueba la sintaxis Lua 5.1, favoritos por material, prioridad de un solo neón, colores y cancelación/restablecimiento del selector, recetas aprendidas/futuras, sincronización antigua/nueva y privacidad de ubicación. La interfaz se comprueba con marcos simulados; falta validar visualmente los últimos ajustes en WoW.

`python tests/test_material_banks.py` cubre bancos moderno, clásico y de hermandad, cambio de pestaña, pools, prioridad de misión, limpieza de casillas y combate. `python tests/test_material_advice.py` cubre recomendaciones, Auctionator ausente, precios recientes/antiguos/restringidos, favoritos, objetos ligados/de misión, umbrales configurables, tooltip sin duplicados y halo de subasta.
