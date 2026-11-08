from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]/'TisteltiGuild'
lua=LuaRuntime()
lua.execute('''
ui={} frames={} calls={} requests=0 combat=false
function InCombatLockdown() return combat end
function CreateFrame()
 local f={scripts={}}
 function f:RegisterEvent() end function f:SetScript(k,v) self.scripts[k]=v end
 frames[#frames+1]=f return f
end
function frame()
 local f={shown=true,hooks={}}
 function f:IsVisible() return self.shown end
 function f:HookScript(k,v) self.hooks[k]=v end
 function f:CreateTexture() end
 return f
end
function button(bag,slot)
 local b=frame()
 function b:GetBagAndSlot() return bag,slot end
 return b
end
ui.requestMaterialUpdate=function() requests=requests+1 end
ui.materialBorder=function(b,id,quest) calls[b]={id=id,quest=quest} end
C_Timer={After=function(_,f) f() end}
hooksecurefunc=function(owner,key,fn)
 local old=owner[key] owner[key]=function(...) old(...) fn(...) end
end
items={['7:1']=100,['8:1']=101,['-1:1']=102}
C_Container={GetContainerItemInfo=function(b,s) return items[b..':'..s] and {itemID=items[b..':'..s]} end,
 GetContainerItemQuestInfo=function(b,s) return {isQuestItem=b==8,questID=0} end}
BankFrame=frame() BankPanel=frame() BankFrame.BankPanel=BankPanel
local a=button(7,1) local b=button(8,1)
BankPanel.Items={a,b} BankPanel.selectedTabID=7
BankPanel.SelectTab=function(self,id) self.selectedTabID=id end
modern=a quest=b
BankFrameItem1=frame() classic=BankFrameItem1
function classic:GetID() return 1 end
''')
lua.execute("assert(loadstring(...))('TisteltiGuild',ui)",(root/'BancosMateriales.lua').read_text(encoding='utf-8'))
lua.execute('''
local event=frames[1].scripts.OnEvent
event(nil,'BANKFRAME_OPENED') ui.refreshMaterialBanks()
assert(calls[modern].id==100 and calls[quest].id==101 and calls[quest].quest)
assert(calls[classic].id==102,'banco clásico')
items['7:1']=nil ui.refreshMaterialBanks() assert(calls[modern].id==nil,'casilla vacía reciclada')
local n=requests BankPanel:SelectTab(8) assert(requests>n,'cambio de pestaña solicita actualización')
BankPanel.Items={} BankPanel.itemButtonPool={EnumerateActive=function() return pairs({[modern]=true}) end}
items['7:1']=103 ui.refreshMaterialBanks() assert(calls[modern].id==103,'pool de casillas modernas')
combat=true items['7:1']=104 ui.refreshMaterialBanks() assert(calls[modern].id==103,'difiere en combate')
combat=false ui.refreshMaterialBanks() assert(calls[modern].id==104)
BankFrame.shown=false BankPanel.shown=false event(nil,'BANKFRAME_CLOSED') ui.refreshMaterialBanks()
assert(calls[modern].id==nil and calls[classic].id==nil,'limpia al cerrar')
GuildBankFrame=frame() GuildBankColumn2=frame()
local g=frame() function g:GetID() return 1 end
GuildBankColumn2.Button1=g
GetCurrentGuildBankTab=function() return 2 end
GetGuildBankItemLink=function(t,s) if t==2 and s==15 then return '|Hitem:100|h[Cobre]|h' end end
event(nil,'GUILDBANKFRAME_OPENED') ui.refreshMaterialBanks()
assert(calls[g].id==100,'slot global correcto del banco de hermandad')
GuildBankFrame.shown=false event(nil,'GUILDBANKFRAME_CLOSED') ui.refreshMaterialBanks()
assert(calls[g].id==nil)
''')
print('Banco moderno/clásico/hermandad, pestañas, pools, misión, casillas vacías y combate: correctos')
