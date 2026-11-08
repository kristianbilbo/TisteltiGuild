# TisteltiGuild 0.10.4-beta

- Corregido el error de concatenación cuando GetNormalizedRealmName devuelve nil durante cargas o traslados. Se conserva el contexto válido anterior o uno temporal en memoria sin crear perfiles con identidad incompleta. Las actualizaciones esperan al reino disponible.

- Neón en banco nativo personal moderno/clásico y banco de hermandad. Actualización al cambiar pestaña o vaciar casillas. La vista de banco del addon resuelve también IDs de enlaces antiguos de hermandad.
- Consejo principal en tooltip: enviar, reservar, subastar o vender al vendedor según recetas y precios. Se respetan los favoritos. Los objetos ligados o de misión no reciben recomendaciones de subasta.
- Integración opcional con la API pública de Auctionator para precio y antigüedad. Halo dorado pulsante con moneda para precios recientes de al menos 1 oro por unidad y cinco veces el valor de venta al vendedor; umbrales y avisos configurables en Repartir materiales. Los precios de más de tres días o sin fecha no activan el aviso. No se publica ninguna subasta ni se calcula rentabilidad de fabricación.

- Neón de un solo color para evitar mezclas difíciles de distinguir: usa el oficio del destinatario favorito o del mejor recomendado. Si ese personaje tiene varios oficios que consumen el material, se priorizan las recetas aprendidas, después las futuras y finalmente el nombre del oficio. Cambiar favorito actualiza también el borde.

- Estrella por destinatario y material: se guarda localmente, admite varios favoritos y los coloca primero. Entre favoritos se mantiene el orden por recetas aprendidas y por aprender. La preferencia también se aplica al resumen del tooltip.
- Vista de reparto sin los párrafos explicativos al final de cada objeto. Mantiene los nombres, los recuentos y los ejemplos de recetas.
- Leyenda de profesiones con iconos y muestras de neón. Al pulsar un oficio se abre el selector de color; cancelar recupera el color anterior. **Restablecer colores** recupera la paleta original. Los colores se guardan en la configuración local de la hermandad y se aplican a las bolsas y al banco del addon.

- En **Grupo → Ubicación: sí/no** se activa el envío de posición a la hermandad. Está desactivado inicialmente, se guarda por personaje y al desactivarlo se retira el marcador de los clientes conectados.
- Nombres visibles sin el reino interno, conservando los apellidos de Forever. Aventuras tolera visitas antiguas sin hora de cierre.
- En **Profesiones → Repartir materiales**, selecciona un objeto de tus bolsas para consultar sus posibles destinatarios y recetas. El tooltip de las bolsas resume hasta tres destinatarios.
- Se priorizan recetas aprendidas y después el número de usos. Las recetas registradas como no aprendidas se muestran como uso futuro, condicionado a conseguirlas; no se presupone que el personaje pueda aprenderlas inmediatamente.
- Abre el libro de cada oficio en cada personaje para actualizar sus componentes y recetas disponibles. Los datos de otros jugadores necesitan sincronización de hermandad. El nuevo formato se intercambia entre versiones 0.10; también se reciben libros antiguos, que sólo aportan recetas aprendidas y nombres de componentes.
- Bordes de profesión en las bolsas nativas y la vista de banco del addon. Los materiales compartidos entre oficios muestran el color del oficio prioritario. Los objetos de misión conservan prioridad. Se pueden desactivar con **Neón: sí/no** en la vista de reparto.
- Las recomendaciones dependen de los libros registrados; no calculan necesidades de encargos, existencias ajenas ni envían correo automáticamente. Los libros sin escanear pueden dejar materiales sin clasificar.

Después de actualizar, ejecuta `/reload`. Pendiente de validar visualmente dentro del cliente la distribución de los nuevos bordes y tooltips.
