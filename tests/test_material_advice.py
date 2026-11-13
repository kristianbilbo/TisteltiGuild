from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.execute('''
ui={} frames={} recipients={{who='Ana',known=3,future=2}} price=50000 age=1 vendor=100 quality=1 class=7 bind=0
db={} secret={} now=100
issecretvalue=function(v) return v==secret end
function InCombatLockdown() return false end
ui.short=function(n) return n end
ui.guildState=function() return db end
requests=0 ui.requestMaterialUpdate=function() requests=requests+1 end
ui.materialRecipients=function() return recipients end
function frame()
 local f={scripts={},shown=false}
 function f:RegisterEvent() end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:Hide() self.shown=false end function f:Show() self.shown=true end
 function f:CreateTexture() return frame() end
 function f:SetAlpha(a) self.alpha=a end
 for _,k in ipairs({'EnableMouse','SetPoint','SetHeight','SetWidth','SetSize','SetColorTexture','SetBlendMode','SetTexture'}) do f[k]=function() end end
 frames[#frames+1]=f return f
end
CreateFrame=frame
C_Item={GetItemInfo=function() return 'Cobre',nil,quality,nil,nil,nil,nil,nil,nil,nil,vendor,class,nil,bind end}
Auctionator={API={v1={GetAuctionPriceByItemID=function(caller,id) assert(caller=='TisteltiGuild' and id==100) return price end,
 GetAuctionAgeByItemID=function() return age end}}}
''')
lua.execute("assert(loadstring(...))('TisteltiGuild',ui)",(root/'ConsejoMateriales.lua').read_text(encoding='utf-8'))
lua.execute('''
local a=ui.materialAdvice(db,100)
assert(a.action=='auction' and a.high and a.price==50000 and a.vendor==100,'precio alto guardado')
recipients[1].favorite=true
a=ui.materialAdvice(db,100) assert(a.action=='give' and a.target=='Ana' and a.high,'preferencia explícita con aviso económico')
recipients[1].favorite=false
age=4 a=ui.materialAdvice(db,100) assert(a.action=='give' and not a.high and not a.fresh,'precio antiguo no sugiere vender ni brilla')
age=nil assert(not ui.materialAdvice(db,100).high,'fecha desconocida no genera alerta')
age=0 bind=1 assert(ui.materialAdvice(db,100).action=='keep' and not ui.materialAdvice(db,100).high,'objeto ligado')
bind=0 assert(ui.materialAdvice(db,100,{bound=true}).action=='keep','ligado al equiparse')
assert(not ui.materialAdvice(db,100,{quest=true}).high,'misión tiene prioridad')
price=1000 a=ui.materialAdvice(db,100) assert(a.action=='give' and not a.high,'precio normal conserva uso de profesión')
recipients={} a=ui.materialAdvice(db,100) assert(a.action=='auction','sin uso registrado y subasta supera vendedor')
price=50 assert(ui.materialAdvice(db,100).action=='vendor','material con subasta inferior a vendedor')
quality=0 price=nil assert(ui.materialAdvice(db,100).action=='vendor','gris sin subasta')
quality=1 recipients={{who='Ana',known=0,future=2}}
assert(ui.materialAdvice(db,100).action=='reserve','reservar para receta futura')
price=50000 vendor=nil assert(not ui.materialAdvice(db,100).high,'sin precio vendedor no afirma múltiplo')
vendor=100 db.materialAuctionMinimum=100000 assert(not ui.materialAdvice(db,100).high,'mínimo configurable')
db.materialAuctionMinimum=nil db.materialAuctionMultiple=1000 assert(not ui.materialAdvice(db,100).high,'múltiplo configurable')
db.materialAuctionMultiple=nil
local api=Auctionator Auctionator=nil
assert(ui.materialAdvice(db,100).action=='reserve','Auctionator opcional') Auctionator=api
price=secret assert(not ui.materialAdvice(db,100).price,'precios restringidos')
price=50000
local button=frame() ui.materialAuctionGlow(button,100,db,false,{})
local glow=frames[#frames-1] -- identificar el marco por su OnUpdate
for _,f in ipairs(frames) do if f.scripts.OnUpdate then glow=f end end
assert(glow.shown,'halo separado de profesión')
glow.scripts.OnUpdate(glow,.25) assert(glow.alpha>=.55 and glow.alpha<=.95,'pulso visible')
ui.materialAuctionGlow(button,100,db,true,{}) assert(not glow.shown,'sin halo de subasta en misión')
ui.materialAuctionGlow(button,100,db,false,{bound=true}) assert(not glow.shown,'sin halo en ligados')
db.materialAuctionAlerts=false ui.materialAuctionGlow(button,100,db,false,{}) assert(not glow.shown,'alertas opcionales')
db.materialAuctionAlerts=true ui.materialAuctionGlow(button,100,db,false,{}) assert(glow.shown)
ui.materialAuctionGlow(button,nil,db,false,{}) assert(not glow.shown,'limpia halo al vaciar casilla')
local tip={lines={}}
function tip:AddLine(s) self.lines[#self.lines+1]=s end function tip:Show() end
ui.addMaterialTooltip(tip,100,{count=4})
assert(tip.lines[1]:find('Subastar',1,true) and tip.lines[2]:find('lote',1,true),'consejo y valor del lote')
local n=#tip.lines ui.addMaterialTooltip(tip,100,{count=4}) assert(#tip.lines==n,'tooltip sin duplicados')
local events=frames[1]
events.scripts.OnEvent(nil,'AUCTION_HOUSE_SHOW')
local n=requests events.scripts.OnUpdate(nil,3) assert(requests>n,'repinta precios mientras se escanea')
events.scripts.OnEvent(nil,'AUCTION_HOUSE_CLOSED') assert(events.scripts.OnUpdate==nil,'detiene revisión al cerrar subastas')
''')
print('Consejo: favoritos, dar/reservar/vender, Auctionator opcional, antigüedad, ligados/misión, umbrales y halo: correctos')
