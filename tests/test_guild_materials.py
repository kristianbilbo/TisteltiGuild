from pathlib import Path
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]/'TisteltiGuild'
lua=LuaRuntime(unpack_returned_tuples=True)
load=lua.eval('function(s) local f,e=loadstring(s); assert(f,e); return f end')
for path in root.glob('*.lua'):
    load(path.read_text(encoding='utf-8'))
print('Sintaxis Lua 5.1: todos los archivos correctos')
lua.execute('''
ui={} frames={} SlashCmdList={} now=100
function GetNormalizedRealmName() return 'CamWoWEuRealm' end
function time() return 1000 end
function date() return '08/11 17:00' end
function GetTime() return now end
function InCombatLockdown() return false end
function GetGuildInfo() return 'Guild' end
function wipe(t) for k in pairs(t) do t[k]=nil end end
function CreateFrame()
 local f={scripts={}}
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:RegisterEvent() end
 frames[#frames+1]=f return f
end
C_Item={GetItemNameByID=function(id) return ({[100]='Cobre',[101]='Cobre fino',[102]='Hierro'})[id] end}
db={recipes={
 a={who='Ana-Azul',name='Pendiente',prof='Ingeniería',professionID=202,learned=false,reagents={[100]=3},seen=900},
 b={who='Bea-Verde',name='Tornillo',prof='Ingeniería',professionID=202,learned=true,reagents={[100]=2},seen=800},
 c={who='Bea-Verde',name='Llave',prof='Herrería',professionID=164,learned=true,reagents={[100]=1},seen=700},
 d={who='Carlos-Rojo',name='Antigua',prof='Herrería',mats='2 × Cobre, 1 × Hierro'},
 e={who='Otro',name='No coincide',prof='Herrería',mats='2 × Cobre fino'},
}}
''')
load((root/'Tema.lua').read_text(encoding='utf-8'))('TisteltiGuild',lua.globals().ui)
load((root/'Materiales.lua').read_text(encoding='utf-8'))('TisteltiGuild',lua.globals().ui)
lua.execute('''
assert(ui.short('Nombre Apellido-CamWoWEuRealm')=='Nombre Apellido')
assert(ui.short('Nombre-Apellido')=='Nombre Apellido')
assert(ui.short('Nombre-CamWoWEuRealm')=='Nombre')
assert(ui.storyText('Ana-CamWoWEuRealm recibió |Hitem:100|h[Cobre]|h')=='Ana recibió |Hitem:100|h[Cobre]|h')
local r=ui.materialRecipients(db,100)
assert(#r==3 and r[1].who=='Bea-Verde' and r[1].known==2)
assert(r[2].who=='Carlos-Rojo' and r[3].future==1 and r[3].known==0)
assert(#ui.materialRecipients(db,101)==1,'sin coincidencias parciales')
assert(#ui.materialRecipients(db,999)==0)
ui.setMaterialFavorite(db,100,'Ana-Azul',true)
assert(ui.materialRecipients(db,100)[1].who=='Ana-Azul','favorito futuro antes del sugerido automático')
assert(not ui.materialRecipients(db,101)[1].favorite,'preferencia específica del material')
ui.setMaterialFavorite(db,100,'Bea-Verde',true)
assert(ui.materialRecipients(db,100)[1].who=='Bea-Verde','ponderación de recetas dentro de favoritos')
ui.setMaterialFavorite(db,100,'Bea-Verde',false)
ui.setMaterialFavorite(db,100,'Ana-Azul',false)
assert(ui.materialRecipients(db,100)[1].who=='Bea-Verde','restaura recomendación al quitar favoritos')
assert(db.materialFavorites['100']==nil,'limpia preferencias vacías')
local originalPrimary=ui.materialPrimaryProfession(db,100)
assert(originalPrimary==164,'empate entre oficios resuelto de forma estable')
ui.setMaterialFavorite(db,100,'Ana-Azul',true)
assert(ui.materialPrimaryProfession(db,100)==202,'el favorito decide el oficio del neón')
ui.setMaterialFavorite(db,100,'Ana-Azul',false)
assert(ui.materialPrimaryProfession(db,999)==nil,'sin usos no hay neón')
db.materialColors={[202]={.9,.1,.2}}
assert(ui.materialColor(202,db)[1]==.9 and ui.materialColor(171,db)[1]==.2,'colores por oficio')
db.materialColors=nil
local original={learned=false,professionID=202,rank=120,seen=950,reagents={[100]=2,[101]=4}}
local decoded={} ui.unpackMaterialRecipe(decoded,ui.packMaterialRecipe(original))
assert(decoded.learned==false and decoded.reagents[101]==4 and decoded.rank==120)
local invalid={} ui.unpackMaterialRecipe(invalid,'basura') assert(invalid.reagents==nil)
db.recipes.b=nil ui.invalidateMaterials()
assert(ui.materialRecipients(db,100)[1].known==1,'invalida el índice')
ui.guildState=function() return db end
local button={textures={}}
function button:GetWidth() return 40 end function button:GetHeight() return 40 end
function button:CreateTexture()
 local t={shown=false}
 setmetatable(t,{__index=function(_,k)
  if k=='Show' then return function(self) self.shown=true end end
  if k=='Hide' then return function(self) self.shown=false end end
  if k=='SetColorTexture' then return function(self,...) self.rgb={...} end end
  return function() end
 end})
 self.textures[#self.textures+1]=t return t
end
ui.materialBorder(button,100,false) assert(#button.textures==4,'un único oficio prioritario')
ui.materialBorder(button,100,true)
for _,t in ipairs(button.textures) do assert(not t.shown,'misión prioritaria') end
db.materialBorders=false ui.materialBorder(button,100,false)
for _,t in ipairs(button.textures) do assert(not t.shown,'opción desactivada') end
db.materialBorders=true ui.materialBorder(button,100,false)
ui.materialBorder(button,nil,false)
for _,t in ipairs(button.textures) do assert(not t.shown,'casilla reciclada') end
button.GetBagAndSlot=function() return 0,1 end
ContainerFrameCombinedBags={Items={button},size=0,IsShown=function() return true end,HookScript=function() end}
local occupied=true
C_Container={GetContainerItemInfo=function() if occupied then return {itemID=100} end end,
 GetContainerItemQuestInfo=function() return {isQuestItem=false,questID=0} end}
frames[1].scripts.OnUpdate(nil,.3)
assert(button.textures[1].shown,'bolsa combinada de Forever')
assert(button.textures[1].rgb[1]==1 and button.textures[1].rgb[2]==.35,'un color completo de Herrería')
ui.setMaterialFavorite(db,100,'Ana-Azul',true)
frames[1].scripts.OnUpdate(nil,.3)
assert(button.textures[1].rgb[1]==0 and button.textures[1].rgb[2]==.85,'cambio de favorito repinta Ingeniería sin mover el objeto')
ui.setMaterialFavorite(db,100,'Ana-Azul',false)
frames[1].scripts.OnUpdate(nil,.3)
assert(button.textures[1].rgb[1]==1 and button.textures[1].rgb[2]==.35,'quitar favorito recupera color recomendado')
occupied=false ui.invalidateMaterials() frames[1].scripts.OnUpdate(nil,.3)
assert(not button.textures[1].shown,'limpia casillas vacías en bolsa combinada')
''')
print('Nombres, recomendaciones, recetas futuras, protocolo, caché y bordes: correctos')

lua.execute('''
messages={} tickers={}
C_ChatInfo={RegisterAddonMessagePrefix=function() end,SendAddonMessage=function(p,m) messages[#messages+1]=m end}
C_Timer={NewTicker=function(_,f) tickers[#tickers+1]=f end}
C_Map={GetBestMapForUnit=function() return 1 end,GetPlayerMapPosition=function() return {GetXY=function() return .4,.6 end} end}
function UnitClass() return 'Sacerdote','PRIEST' end
''')
load((root/'Mapa.lua').read_text(encoding='utf-8'))('TisteltiGuild',lua.globals().ui)
lua.execute('''
local map=frames[#frames]
map.scripts.OnEvent(map,'PLAYER_LOGIN')
assert(not ui.locationShared(),'privacidad por defecto')
tickers[1]() assert(#messages==0,'no publica sin consentimiento')
ui.setLocationShared(true) assert(ui.locationShared() and messages[#messages]=='1:4000:6000')
ui.setLocationShared(false) assert(messages[#messages]=='-','retira posición al desactivar')
local n=#messages now=130 tickers[1]() assert(#messages==n,'sigue sin publicar')
''')
print('Ubicación: desactivada por defecto, activación y retirada correctas')

scanlua=LuaRuntime(unpack_returned_tuples=True)
scanlua.execute('''
ui={} frames={} SlashCmdList={}
function GetNormalizedRealmName() return 'Forever' end
function UnitFactionGroup() return 'Alliance' end
function GetGuildInfo() return 'Guild' end
function UnitExists() return true end
function UnitFullName() return 'Ana Azul','Forever' end
function InCombatLockdown() return false end
function time() return 1000 end
function wipe(t) for k in pairs(t) do t[k]=nil end end
function CreateFrame()
 local f={scripts={}}
 function f:RegisterEvent() end
 function f:SetScript(k,v) self.scripts[k]=v end
 frames[#frames+1]=f return f
end
C_Timer={After=function(_,f) f() end}
C_Item={GetItemNameByID=function(id) return 'Material '..id end}
C_TradeSkillUI={
 GetBaseProfessionInfo=function() return {professionID=202,professionName='Ingeniería',skillLevel=75} end,
 GetAllRecipeIDs=function() return {1,2} end,
 GetFilteredRecipeIDs=function() return {1} end,
 GetRecipeInfo=function(id) return {name='Receta '..id,learned=id==1} end,
 GetRecipeSchematic=function(id) return {reagentSlotSchematics={{required=true,quantityRequired=2,reagents={{itemID=100}}}}} end,
}
''')
loader=scanlua.eval('function(s) return assert(loadstring(s)) end')
loader((root/'Gestion.lua').read_text(encoding='utf-8'))('TisteltiGuild',scanlua.globals().ui)
loader((root/'Materiales.lua').read_text(encoding='utf-8'))('TisteltiGuild',scanlua.globals().ui)
scanlua.execute('''
frames[1].scripts.OnEvent(nil,'TRADE_SKILL_SHOW')
local db=ui.guildState()
assert(db.recipes['Ana-Azul:1'].learned==true)
assert(db.recipes['Ana-Azul:2'].learned==false)
assert(db.recipes['Ana-Azul:1'].reagents[100]==2)
local recipients=ui.materialRecipients(db,100)
assert(#recipients==1 and recipients[1].known==1 and recipients[1].future==1)
local r=db.recipes['Ana-Azul:2']
local payload=r.name..'\\t'..r.prof..'\\t'..r.mats..'\\t'..ui.packMaterialRecipe(r)
frames[1].scripts.OnEvent(nil,'CHAT_MSG_ADDON','TisteltiRec2','22 1 1 '..payload,'GUILD','Bea-Verde')
assert(db.recipes['Bea-Verde:22'].learned==false and db.recipes['Bea-Verde:22'].reagents[100]==2)
frames[1].scripts.OnEvent(nil,'CHAT_MSG_ADDON','TisteltiRec1','23 1 1 Antigua\\tHerrería\\t2 × Material 100','GUILD','Carlos-Rojo')
assert(db.recipes['Carlos-Rojo:23'].mats=='2 × Material 100')
assert(#ui.materialRecipients(db,100)==3,'sincronización moderna y antigua')
''')
print('Escaneo real del addon y recepción de recetas antiguas/nuevas: correctos')
scanlua.execute('''
local function frame()
 local f={scripts={},shown=true}
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:Show() self.shown=true end function f:Hide() self.shown=false end
 function f:IsShown() return self.shown end
 function f:SetText(v) self.text=v end function f:GetText() return self.text end
 function f:GetStringHeight() return 200 end
 function f:CreateFontString() return frame() end
 function f:CreateTexture() return frame() end
 function f:GetWidth() return 28 end function f:GetHeight() return 28 end
 for _,k in ipairs({'SetPoint','SetSize','SetScrollChild','SetJustifyH','SetVerticalScroll','SetWidth','SetBackdropBorderColor','SetEnabled','SetDisabledFontObject','SetAlpha','ClearAllPoints','SetHeight','SetTexture','SetAllPoints','SetDesaturated','SetVertexColor','SetColorTexture','SetBlendMode'}) do f[k]=function() end end
 frames[#frames+1]=f return f
end
CreateFrame=frame ui.button=frame ui.short=function(s) return s end
function date() return '08/11' end
C_Container={GetContainerNumSlots=function(b) return b==0 and 1 or 0 end,
 GetContainerItemInfo=function() return {itemID=100,stackCount=4} end}
local parent=frame()
local function refresh() ui.materials(parent,ui.guildState(),refresh) end
refresh()
ui.hideMaterials()
refresh()
local star,engineering,reset
for _,f in ipairs(frames) do
 if f.star and f.text.text:find('Bea',1,true) then star=f.star end
 if f.name and f.name.text:find('Ingeniería',1,true) then engineering=f end
 if f.text=='Restablecer colores' then reset=f end
 if type(f.text)=='string' then
  assert(not f.text:find('Orden:',1,true) and not f.text:find('El neón marca',1,true),'sin explicaciones repetidas')
 end
end
assert(star and engineering and reset,'controles de favoritos y colores')
star.scripts.OnClick()
assert(ui.materialRecipients(ui.guildState(),100)[1].who=='Bea-Verde','estrella cambia la prioridad')
local picker={Hide=function() end,GetColorRGB=function() return .1,.2,.3 end}
function picker:SetupColorPickerAndShow(info) self.info=info end
ColorPickerFrame=picker
engineering.scripts.OnClick()
picker.info.swatchFunc()
assert(ui.guildState().materialColors[202][2]==.2,'selector guarda el color')
picker.info.cancelFunc()
assert(ui.guildState().materialColors[202]==nil,'cancelar restaura el valor anterior')
engineering.scripts.OnClick() picker.info.swatchFunc()
engineering.scripts.OnClick() picker.info.cancelFunc()
assert(ui.guildState().materialColors[202][2]==.2,'cancelar conserva un color ya personalizado')
reset.scripts.OnClick()
assert(ui.guildState().materialColors==nil,'restablece colores originales')
-- Rama compatible con el selector antiguo del cliente.
picker.SetupColorPickerAndShow=nil
picker.SetColorRGB=function() end picker.Show=function() end
engineering.scripts.OnClick() picker.func()
assert(ui.guildState().materialColors[202][3]==.3)
picker.cancelFunc() assert(ui.guildState().materialColors[202]==nil)
''')
print('Vista de reparto, favoritos y selectores de color moderno/antiguo: correctos con API simulada')
