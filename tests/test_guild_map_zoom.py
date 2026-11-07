from pathlib import Path
import runpy
ns=runpy.run_path(str(Path(__file__).with_name('test_guild_map.py')))
lua=ns['lua']
lua.execute(r'''
now=200; partyCount=0; raid=false
send('Blanco-Uno'); draw()
local pin
for _,f in ipairs(frames) do
 if rawget(f,'member')=='Blanco-Uno' and rawget(f,'location') then pin=f end
end
assert(pin,'guild marker outside group')
function pin:SetScale(s) self.scale=s end
function pin:SetSize(w,h) self.width=w self.height=h end
function pin:SetPoint(...) self.point={...} end
function pin:SetParent(p) self.parent=p end
zoom=1; host=1; cw=1000; ch=600; panX=0; panY=0
function canvas:GetWidth() return cw end
function canvas:GetHeight() return ch end
function WorldMapFrame:GetCanvasScale() return zoom end
function WorldMapFrame:GetMapID() return host end
function tick() frames[1].scripts.OnUpdate() end
local function close(a,b) assert(math.abs(a-b)<1e-8,tostring(a)..' != '..tostring(b)) end
local function check(x,y)
 close(pin.scale,1)
 close(pin.width*pin.scale*zoom,10)
 close(pin.height*pin.scale*zoom,10)
 close(pin.point[4]*pin.scale*zoom-panX,x*cw*zoom-panX)
 close(pin.point[5]*pin.scale*zoom-panY,-y*ch*zoom-panY)
 assert(pin.shown)
end
for _,z in ipairs({.25,.5,1,1.25,2,4,8}) do
 zoom=z; panX=87*z; panY=-41*z; tick(); check(.3,.4)
end
OpenMapAPI={IsStitched=function() return true end,
 WorldFromMap=function(map,x,y) return x+2,y+3 end,
 MapFromWorld=function(map,u,v) if map==2 then return u-2.5,v-3.5 else return u-2,v-3 end end,
 ArtTopLevel=function() return 100 end}
zoom=2.4; host=2; cw=1500; ch=900; tick(); check(-.2,-.1)
assert(pin.parent==canvas,'canvas parent follows map')
host=1; zoom=.7; tick(); check(.3,.4)
OpenMapAPI=nil; host=99; tick(); assert(not pin.shown,'unrelated map hides marker')
host=1; tick(); check(.3,.4)
units.party1={'Blanco Uno','Forever'}; partyCount=1; event('GROUP_ROSTER_UPDATE'); tick()
assert(not pin.shown and pin.location==nil,'animation must not resurrect excluded pins')
''')
print('OK: posicion y tamano constantes con zoom 0.25-8, desplazamiento, cambio de anfitrion OpenMap y filtrado de grupo.')
