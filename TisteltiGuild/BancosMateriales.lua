local _,ui=...
local hooked=setmetatable({},{__mode="k"})
local painted=setmetatable({},{__mode="k"})
local personalOpen,guildOpen=false,false

local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c=pcall(fn,...)
    if not ok or (issecretvalue and (issecretvalue(a) or issecretvalue(b) or issecretvalue(c))) then return end
    return a,b,c
end
local function visible(frame)
    if not frame or read(frame.IsForbidden,frame) then return false end
    local method=frame.IsVisible or frame.IsShown
    return read(method,frame)==true
end
local function request() ui.requestMaterialUpdate() end
local function hook(frame)
    if not frame or hooked[frame] or read(frame.IsForbidden,frame) then return end
    hooked[frame]=true
    if frame.HookScript then
        frame:HookScript("OnShow",function() request() C_Timer.After(.05,request) end)
        frame:HookScript("OnHide",request)
    end
    if hooksecurefunc then
        for _,method in ipairs({"Refresh","Update","UpdateItems","SelectTab","SetBankType","GenerateItemSlotsForSelectedTab"}) do
            if type(frame[method])=="function" then hooksecurefunc(frame,method,request) end
        end
    end
end
local function paint(button,id,quest,context)
    if not button or not button.CreateTexture or read(button.IsForbidden,button) then return end
    ui.materialBorder(button,id,quest,context)
    painted[button]=true
end
local function questAt(bag,slot)
    local info=read(C_Container and C_Container.GetContainerItemQuestInfo,bag,slot)
    return type(info)=="table" and (info.isQuestItem or (info.questID and info.questID>0))
end
local function personalItem(button,defaultBag,defaultSlot)
    if not visible(button) then paint(button,nil) return end
    local bag,slot
    local location=read(button.GetItemLocation,button)
    if location then bag,slot=read(location.GetBagAndSlot,location) end
    if not bag or not slot then
        local b,s=read(button.GetBagAndSlot,button)
        bag,slot=bag or b,slot or s
    end
    bag=bag or read(button.GetBankTabID,button) or read(button.GetBagID,button) or button.bagID or defaultBag
    slot=slot or read(button.GetContainerSlotID,button) or read(button.GetID,button) or button.slotID or defaultSlot
    local id,quest
    if type(bag)=="number" and type(slot)=="number" and slot>0 then
        local info=read(C_Container and C_Container.GetContainerItemInfo,bag,slot)
        id=type(info)=="table" and info.itemID or read(C_Container and C_Container.GetContainerItemID,bag,slot)
        quest=questAt(bag,slot)
        -- Una ubicación válida vacía no debe recuperar el ID antiguo del botón.
    else
        id=location and read(C_Item and C_Item.GetItemID,location) or read(button.GetItemID,button)
        if not id then
            local link=read(button.GetItemLink,button)
            id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
        end
    end
    paint(button,id,quest,bag and slot and ui.materialSaleContext and ui.materialSaleContext(bag,slot))
end
local function enumerate(owner,method,accept)
    if type(method)~="function" then return end
    local ok,iterator,state,initial=pcall(method,owner)
    if not ok then return end
    if type(iterator)=="function" then
        for a,b in iterator,state,initial do accept(type(a)=="table" and a or b) end
    elseif type(iterator)=="table" then
        for _,button in pairs(iterator) do accept(button) end
    end
end
local function scan(frame,accept)
    if not frame then return end
    hook(frame)
    if not visible(frame) then return end
    for _,key in ipairs({"Items","ItemSlots","itemSlots","Buttons"}) do
        for _,button in pairs(type(frame[key])=="table" and frame[key] or {}) do accept(button) end
    end
    enumerate(frame,frame.EnumerateValidItems,accept)
    local pool=frame.itemButtonPool
    if pool then
        enumerate(pool,pool.EnumerateActive,accept)
        for button in pairs(pool.activeObjects or {}) do accept(button) end
    end
    if frame.GetChildren then
        for _,child in ipairs({frame:GetChildren()}) do
            if child.GetItemLocation or child.GetBankTabID or child.GetBagAndSlot or child.GetItemID then accept(child) end
        end
    end
end
function ui.refreshMaterialBanks()
    if InCombatLockdown() then return end
    -- Limpia primero las casillas recicladas, incluso al cerrar o cambiar pestaña.
    for button in pairs(painted) do ui.materialBorder(button,nil) end
    local bank=BankFrame
    local panel=BankPanel or (bank and bank.BankPanel)
    local slots=BankSlotsFrame or (bank and bank.BankSlotsFrame)
    hook(bank) hook(panel) hook(slots) hook(GuildBankFrame)
    if personalOpen or visible(bank) or visible(panel) then
        local bankBag=(Enum and Enum.BagIndex and Enum.BagIndex.Bank) or BANK_CONTAINER or -1
        local selected=panel and (read(panel.GetSelectedTabID,panel) or panel.selectedTabID)
        local seen={}
        local function accept(button)
            if type(button)~="table" or not button.CreateTexture or seen[button] then return end
            seen[button]=true
            personalItem(button,selected or bankBag)
        end
        scan(bank,accept) scan(panel,accept) scan(slots,accept)
        if visible(bank) or visible(slots) then
            for i=1,(NUM_BANKGENERIC_SLOTS or 28) do
                local button=(slots and slots["Item"..i]) or _G["BankFrameItem"..i]
                if button then personalItem(button,bankBag,i) end
            end
        end
    end
    if guildOpen and visible(GuildBankFrame) then
        local tab=read(GetCurrentGuildBankTab)
        local seen={}
        local function accept(button,defaultSlot)
            if type(button)~="table" or not button.CreateTexture or seen[button] then return end
            seen[button]=true
            local slot=button.slotID or defaultSlot or read(button.GetID,button)
            local link=visible(button) and tab and slot and read(GetGuildBankItemLink,tab,slot)
            paint(button,type(link)=="string" and tonumber(link:match("item:(%d+)")))
        end
        scan(GuildBankFrame,accept)
        for column=1,(NUM_GUILDBANK_COLUMNS or 7) do
            local col=_G["GuildBankColumn"..column]
            hook(col)
            for row=1,(NUM_SLOTS_PER_GUILDBANK_GROUP or 14) do
                local button=(col and col["Button"..row]) or _G["GuildBankColumn"..column.."Button"..row]
                if button then accept(button,(column-1)*14+row) end
            end
        end
    end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYERBANKSLOTS_CHANGED","BANK_TABS_CHANGED","GUILDBANKFRAME_OPENED","GUILDBANKFRAME_CLOSED","GUILDBANKBAGSLOTS_CHANGED","GUILDBANK_UPDATE_TABS"}) do
    pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function(_,event)
    if event=="BANKFRAME_OPENED" then personalOpen=true
    elseif event=="BANKFRAME_CLOSED" then personalOpen=false
    elseif event=="GUILDBANKFRAME_OPENED" then guildOpen=true
    elseif event=="GUILDBANKFRAME_CLOSED" then guildOpen=false end
    request()
    if event=="BANKFRAME_OPENED" or event=="GUILDBANKFRAME_OPENED" then
        C_Timer.After(.05,request) C_Timer.After(.25,request)
    end
end)
