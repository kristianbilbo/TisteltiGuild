-- La carpeta antigua solo carga los datos anteriores, sin ejecutar su interfaz.
if TisteltiGuildDB == nil then TisteltiGuildDB = GestionGuildDB or {} end
if TisteltiJourneyDB == nil then TisteltiJourneyDB = DiarioGuildDB or {history={}} end
