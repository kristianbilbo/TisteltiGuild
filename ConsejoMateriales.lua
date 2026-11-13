local _,ui=...
local function pack(...) return {n=select("#",...),...} end
local function call(fn,...)
    if type(fn)~="function" then return end
    local values=pack(pcall(fn,...))
    if not values[1] then return end
    for i=2,values.n do if issecretvalue and issecretvalue(values[i]) then return end end
    return unpack(values,2,values.n)
end
local function money(value)
    value=math.floor(value or 0)
    if GetCoinTextureString then return GetCoinTextureString(value) end
    return ("%do %dp %dc"):format(math.floor(value/10000),math.floor(value/100)%100,value%100)
end
ui.materialMoney=money
function ui.materialSaleContext(bag,slot)
    local info=call(C_Container and C_Container.GetContainerItemInfo,bag,slot)
    local quest=call(C_Container and C_Container.GetContainerItemQuestInfo,bag,slot)
    local bound=info and info.isBound
    if ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local location=call(ItemLocation.CreateFromBagAndSlot,ItemLocation,bag,slot)
        if location then
            local actual=call(C_Item and C_Item.IsBound,location)
            if actual~=nil then bound=actual end
        end
    end
    return {bound=bound,quest=quest and (quest.isQuestItem or (quest.questID and quest.questID>0)),count=info and info.stackCount or 1}
end
function ui.materialAdvice(db,id,context)
    context=context or {}
    local api=Auctionator and Auctionator.API and Auctionator.API.v1
    local price=call(api and api.GetAuctionPriceByItemID,"TisteltiGuild",id)
    local age=call(api and api.GetAuctionAgeByItemID,"TisteltiGuild",id)
    local name,_,quality,_,_,_,_,_,_,_,vendor,class,_,bindType=call(C_Item and C_Item.GetItemInfo,id)
    price=type(price)=="number" and price>0 and price or nil
    vendor=type(vendor)=="number" and vendor>=0 and vendor or nil
    local fresh=price and type(age)=="number" and age>=0 and age<=3
    local minimum=tonumber(db.materialAuctionMinimum) or 10000
    local multiple=tonumber(db.materialAuctionMultiple) or 5
    local bound=context.bound==true or bindType==1 or bindType==4
    local quest=context.quest or class==12
    local high=fresh and vendor~=nil and not bound and not quest and price>=minimum and price>=math.max(1,vendor*multiple)
    local entries=ui.materialRecipients(db,id)
    local best=entries[1]
    local advice={price=price,vendor=vendor,age=age,fresh=fresh,high=not not high,recipients=entries,count=context.count or 1}
    if quest then advice.action="keep" advice.text="Guardar para misión"
    elseif bound then advice.action="keep" advice.text="Conservar: objeto ligado"
    elseif best and best.favorite then
        advice.action="give" advice.target=best.who advice.text=(best.known>0 and "Enviar a " or "Reservar para ")..ui.short(best.who).." (favorito)"
    elseif high then advice.action="auction" advice.text="Subastar: precio alto"
    elseif best and best.known>0 then advice.action="give" advice.target=best.who advice.text="Enviar a "..ui.short(best.who)
    elseif fresh and price>math.max(1,(vendor or 0)*1.2) then advice.action="auction" advice.text="Subastar: supera al vendedor"
    elseif best then advice.action="reserve" advice.target=best.who advice.text="Reservar para "..ui.short(best.who).." (por aprender)"
    elseif vendor and vendor>0 and (quality==0 or ((class==7 or class==5) and fresh and price<=vendor)) then
        advice.action="vendor" advice.text="Vender a un vendedor"
    else advice.action="keep" advice.text="Conservar: sin destino o precio confirmado" end
    if not name and not best and not price then advice.text="Sin datos suficientes" end
    return advice
end
function ui.materialAdviceText(db,id,context)
    local a=ui.materialAdvice(db,id,context)
    local text=a.text
    if a.price then
        text=text.."\nAuctionator: "..money(a.price).."/u · "..(a.age==0 and "hoy" or (a.age and (a.age.." días") or "fecha desconocida"))
        if not a.fresh then text=text.." · actualizar precio" end
    elseif Auctionator then text=text.."\nAuctionator: sin precio guardado" end
    return text,a
end
function ui.addMaterialTooltip(tooltip,id,context)
    if InCombatLockdown() or not id then return end
    if tooltip.tisteltiMaterialID==id then return end
    local db=ui.guildState()
    local text,a=ui.materialAdviceText(db,id,context)
    tooltip:AddLine("TisteltiGuild · "..a.text,a.action=="auction" and 1 or .5,a.action=="auction" and .8 or 1,.35,true)
    if a.price then
        tooltip:AddLine("Auctionator: "..money(a.price).."/u"..(a.count>1 and (" · lote "..money(a.price*a.count)) or "")..
            " · "..(a.age==0 and "hoy" or (a.age and (a.age.." días") or "fecha desconocida"))..
            (a.fresh and "" or " · actualizar precio"),.85,.85,.85,true)
    end
    for i=1,math.min(3,#a.recipients) do
        local e=a.recipients[i]
        tooltip:AddLine((e.favorite and "|cffffd133Favorito|r · " or "")..ui.short(e.who).." · "..e.known.." aprendidas · "..e.future.." por aprender",.65,1,.8)
    end
    tooltip.tisteltiMaterialID=id
    tooltip:Show()
end

-- Halo exterior dorado intermitente + moneda: se distingue del borde de oficio
-- y nunca sustituye el dorado fijo de misión. Sólo se anima mientras es visible.
local glows=setmetatable({},{__mode="k"})
function ui.materialAuctionGlow(button,id,db,quest,context)
    local g=glows[button]
    context=context or {}
    local a=id and not quest and ui.materialAdvice(db,id,context)
    if not a or not a.high or db.materialAuctionAlerts==false then
        if g then g:Hide() end
        return
    end
    if not g then
        g=CreateFrame("Frame",nil,button)
        g:EnableMouse(false)
        g:SetPoint("TOPLEFT",-3,3) g:SetPoint("BOTTOMRIGHT",3,-3)
        g.edges={}
        for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
            local t=g:CreateTexture(nil,"OVERLAY")
            t:SetColorTexture(1,.7,.08,.8) t:SetBlendMode("ADD")
            if side=="TOP" or side=="BOTTOM" then
                t:SetPoint(side.."LEFT") t:SetPoint(side.."RIGHT") t:SetHeight(2)
            else t:SetPoint("TOP"..side) t:SetPoint("BOTTOM"..side) t:SetWidth(2) end
            g.edges[#g.edges+1]=t
        end
        g.coin=g:CreateTexture(nil,"OVERLAY") g.coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        g.coin:SetSize(10,10) g.coin:SetPoint("BOTTOMLEFT",1,1)
        g:SetScript("OnUpdate",function(self,dt)
            self.elapsed=(self.elapsed or 0)+dt
            self:SetAlpha(.55+.4*(.5+.5*math.sin(self.elapsed*4)))
        end)
        glows[button]=g
    end
    g:Show()
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","AUCTION_HOUSE_CLOSED","AUCTION_HOUSE_SHOW","ADDON_LOADED"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,addon)
    if event~="ADDON_LOADED" or addon=="Auctionator" then ui.requestMaterialUpdate() end
    if event=="AUCTION_HOUSE_SHOW" then
        local elapsed=0
        events:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=3 then elapsed=0 ui.requestMaterialUpdate() end
        end)
    elseif event=="AUCTION_HOUSE_CLOSED" then events:SetScript("OnUpdate",nil) end
    if event=="PLAYER_LOGIN" and GameTooltip and hooksecurefunc then
        if GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipCleared",function(tip) tip.tisteltiMaterialID=nil end) end
        if GameTooltip.SetGuildBankItem then
            hooksecurefunc(GameTooltip,"SetGuildBankItem",function(tip,tab,slot)
                local link=call(GetGuildBankItemLink,tab,slot)
                local _,count=call(GetGuildBankItemInfo,tab,slot)
                ui.addMaterialTooltip(tip,type(link)=="string" and tonumber(link:match("item:(%d+)")),{count=count or 1})
            end)
        end
        if GameTooltip.SetInventoryItem then
            hooksecurefunc(GameTooltip,"SetInventoryItem",function(tip,unit,slot)
                if unit~="player" or type(slot)~="number" or slot<=19 then return end
                local id=call(GetInventoryItemID,unit,slot)
                ui.addMaterialTooltip(tip,id,{count=call(GetInventoryItemCount,unit,slot) or 1})
            end)
        end
    end
end)
