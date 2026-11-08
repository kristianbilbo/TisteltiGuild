import sys
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime()
lua.execute(r'''
now=100; units={player={'Yo Verde','Forever'}}; raid=false; partyCount=0; raidCount=0
frames={}; tickers={}; SlashCmdList={}; RAID_CLASS_COLORS={PRIEST={r=1,g=1,b=1}}
C_Map={GetMapInfo=function() return {} end}
C_ChatInfo={RegisterAddonMessagePrefix=function() end}
C_Timer={NewTicker=function(_,f) tickers[#tickers+1]=f end}
function GetTime() return now end
function GetGuildInfo() return 'Guild' end
function GetNormalizedRealmName() return 'Forever' end
function UnitFullName(u) if units[u] then return unpack(units[u]) end end
function IsInRaid() return raid end
function GetNumGroupMembers() return raidCount end
function GetNumSubgroupMembers() return partyCount end
function wipe(t) for k in pairs(t) do t[k]=nil end end
function CreateFrame()
 local f={scripts={}}
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:Hide() self.shown=false end
 function f:Show() self.shown=true end
 function f:CreateTexture() return setmetatable({}, {__index=function() return function() end end}) end
 setmetatable(f,{__index=function(_,k) if k=="location" or k=="member" then return nil end return function() end end})
 frames[#frames+1]=f; return f
end
canvas={GetWidth=function() return 1000 end,GetHeight=function() return 600 end,GetFrameLevel=function() return 1 end}
WorldMapFrame={IsShown=function() return true end,GetCanvas=function() return canvas end,GetMapID=function() return 1 end}
function visible()
 local names={}
 for _,f in ipairs(frames) do if rawget(f,'shown') and rawget(f,'member') then names[f.member]=true end end
 return names
end
''')
lua.execute("assert(loadstring(...))('TisteltiGuild', {})", (Path(__file__).resolve().parents[1]/'TisteltiGuild/Mapa.lua').read_text(encoding='utf-8'))
lua.execute(r'''
function event(e,...) frames[1].scripts.OnEvent(frames[1],e,...) end
function send(n) event('CHAT_MSG_ADDON','TisteltiMap1','1:3000:4000','GUILD',n) end
function draw() tickers[2]() end
event('PLAYER_LOGIN')
send('Yo-Verde'); send('Yo Verde-Forever'); send('Blanco-Uno'); send('Blanco Uno-Forever'); send('Lejos-Forever'); draw()
assert(not visible()['Yo-Verde'],'self surname echo')
local n=0 for _ in pairs(visible()) do n=n+1 end
assert(n==2 and visible()['Blanco-Uno'] and visible()['Lejos-Forever'],'guild pins canonicalized')
units.party1={'Blanco Uno','Forever'}; partyCount=1; event('GROUP_ROSTER_UPDATE')
assert(not visible()['Blanco-Uno'] and visible()['Lejos-Forever'],'party suppressed immediately')
partyCount=0; units.party1=nil; event('GROUP_ROSTER_UPDATE')
assert(visible()['Blanco-Uno'],'leaving group restores pin')
raid=true; raidCount=2; units.raid1=units.player; units.raid2={'Blanco','Uno'}; event('GROUP_ROSTER_UPDATE')
assert(not visible()['Blanco-Uno'],'raid and surname in second field')
raid=false; raidCount=0; units.player={'Yo',''}; send('Yo-Forever'); draw()
assert(not visible()['Yo-Forever'],'empty realm')
partyCount=1; units.party1={'Lejos','OtroReino'}; event('GROUP_ROSTER_UPDATE')
assert(visible()['Lejos-Forever'],'different realm preserved')
now=146; draw(); assert(next(visible())==nil,'expiry')
''')
print('OK: Lua 5.1; propio personaje, apellidos, grupo/banda, salida del grupo, reinos y caducidad.')

