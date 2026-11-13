local _,ui=...
-- El índice usa IDs de componentes, nunca coincidencias parciales de nombres.
local colors={
    [171]={.2,1,.35,"Alquimia"},[333]={.8,.3,1,"Encantamiento"},
    [164]={1,.35,.15,"Herrería"},[202]={0,.85,1,"Ingeniería"},
    [165]={1,.55,.15,"Peletería"},[197]={1,.25,.65,"Sastrería"},
    [185]={1,.9,.15,"Cocina"},[129]={.25,1,.8,"Primeros auxilios"},
    [186]={.65,.75,1,"Minería"},[755]={.4,1,1,"Joyería"},
    [773]={.7,.6,1,"Inscripción"},
}
local byName={}
for id,c in pairs(colors) do byName[c[4]]=id end
byName.Costura=197
local professionOrder={171,333,164,202,165,197,185,129,186,755,773}
local professionIcons={
    [171]="Trade_Alchemy",[333]="Trade_Engraving",[164]="Trade_BlackSmithing",
    [202]="Trade_Engineering",[165]="Trade_LeatherWorking",[197]="Trade_Tailoring",
    [185]="INV_Misc_Food_15",[129]="Spell_Holy_SealOfSacrifice",[186]="Trade_Mining",
    [755]="INV_Misc_Gem_01",[773]="INV_Inscription_Tradeskill01",
}
local cache,cacheDB,legacyNames,panel,chosen,refreshPanel
local dirty=true
local function profession(r) return tonumber(r.professionID) or byName[r.prof] or r.prof end
local function color(id,db)
    local base=colors[id] or {.65,.85,1,tostring(id)}
    local custom=db and db.materialColors and db.materialColors[id]
    if custom then return {custom[1],custom[2],custom[3],base[4]} end
    return base
end
ui.materialColor=color
local function label(id) return color(id)[4] end
local function tint(id,text,db)
    local c=color(id,db)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1]*255),math.floor(c[2]*255),math.floor(c[3]*255),text)
end

function ui.packMaterialRecipe(r)
    local ids={}
    for id,qty in pairs(r.reagents or {}) do ids[#ids+1]=tonumber(id) end
    table.sort(ids)
    local parts={}
    for _,id in ipairs(ids) do parts[#parts+1]=id.."="..r.reagents[id] end
    return table.concat({r.learned==false and "0" or "1",r.professionID or 0,r.rank or 0,r.seen or time(),table.concat(parts,",")},";")
end
function ui.unpackMaterialRecipe(r,meta)
    local learned,p,rank,seen,items=meta:match("^([01]);(%d+);(%d+);(%d+);([%d,=]*)$")
    if not learned then return end
    r.learned=learned=="1" r.professionID=tonumber(p) r.rank=tonumber(rank) r.seen=tonumber(seen)
    r.reagents={}
    for id,qty in items:gmatch("(%d+)=(%d+)") do
        id,qty=tonumber(id),tonumber(qty)
        if id>0 and qty>0 then r.reagents[id]=qty end
    end
end
function ui.invalidateMaterials() cache=nil dirty=true end
function ui.requestMaterialUpdate() dirty=true end
function ui.setMaterialFavorite(db,id,who,enabled)
    local key=tostring(id)
    db.materialFavorites=db.materialFavorites or {}
    local favorites=db.materialFavorites[key] or {}
    favorites[who]=enabled and true or nil
    db.materialFavorites[key]=next(favorites) and favorites or nil
    dirty=true
end

local function index(db)
    if cache and cacheDB==db then return cache end
    cache,cacheDB,legacyNames={},db,{}
    for key,r in pairs(db.recipes or {}) do
        local reagents=r.reagents or {}
        -- Compatibilidad con registros antiguos: sólo nombres completos o #ID.
        if not r.reagents then
            reagents={}
            for id in (r.mats or ""):gmatch("#(%d+)") do reagents[tonumber(id)]=1 end
            for component in (r.mats or ""):gmatch("[^,]+") do
                local names=component:match("^%s*%d+%s*×%s*(.+)$")
                for name in (names or ""):gmatch("[^/]+") do
                    name=name:match("^%s*(.-)%s*$")
                    legacyNames[name]=legacyNames[name] or {}
                    legacyNames[name][#legacyNames[name]+1]={recipe=r,key=key,profession=profession(r)}
                end
            end
        end
        for id in pairs(reagents) do
            id=tonumber(id)
            if id then
                cache[id]=cache[id] or {}
                cache[id][#cache[id]+1]={recipe=r,key=key,profession=profession(r)}
            end
        end
    end
    return cache
end
local function matches(db,id)
    local found=index(db)[id] or {}
    local result,seen={},{}
    for _,m in ipairs(found) do result[#result+1]=m seen[m.key]=true end
    local name=C_Item.GetItemNameByID(id)
    for _,m in ipairs((name and legacyNames[name]) or {}) do
        if not seen[m.key] then result[#result+1]=m seen[m.key]=true end
    end
    return result
end
function ui.materialRecipients(db,id)
    id=tonumber(id)
    local entries,people={},{}
    local favorites=db.materialFavorites and db.materialFavorites[tostring(id)] or {}
    for _,m in ipairs(matches(db,id)) do
        local r=m.recipe
        local e=people[r.who]
        if not e then
            e={who=r.who,known=0,future=0,professions={},examples={},seen=r.seen,favorite=favorites[r.who]==true}
            people[r.who]=e entries[#entries+1]=e
        end
        e.professions[m.profession]=true
        if r.learned==false then e.future=e.future+1 else e.known=e.known+1 end
        if #e.examples<3 then e.examples[#e.examples+1]=r.name..(r.learned==false and " (por aprender)" or "") end
        e.seen=math.max(e.seen or 0,r.seen or 0)
    end
    table.sort(entries,function(a,b)
        if a.favorite~=b.favorite then return a.favorite end
        if (a.known>0)~=(b.known>0) then return a.known>0 end
        if a.known~=b.known then return a.known>b.known end
        if a.future~=b.future then return a.future>b.future end
        return a.who<b.who
    end)
    return entries
end
local function professions(db,id)
    local set,list={},{}
    for _,m in ipairs(matches(db,id)) do set[m.profession]=true end
    for p in pairs(set) do list[#list+1]=p end
    table.sort(list,function(a,b) return label(a)<label(b) end)
    return list
end
function ui.materialPrimaryProfession(db,id)
    -- Un único color para leerlo de un vistazo. El destinatario favorito o
    -- recomendado decide el oficio; dentro de él, aprendidas antes que futuras.
    local recipient=ui.materialRecipients(db,id)[1]
    if not recipient then return nil end
    local scores={}
    for _,m in ipairs(matches(db,tonumber(id))) do
        if m.recipe.who==recipient.who then
            local score=scores[m.profession] or {known=0,future=0}
            scores[m.profession]=score
            if m.recipe.learned==false then score.future=score.future+1 else score.known=score.known+1 end
        end
    end
    local best
    for p,s in pairs(scores) do
        local previous=best and scores[best]
        if not previous or s.known>previous.known or
            (s.known==previous.known and (s.future>previous.future or
            (s.future==previous.future and label(p)<label(best)))) then best=p end
    end
    return best
end
local function stock()
    local items={}
    if not C_Container then return items end
    for bag=0,(NUM_BAG_SLOTS or 4) do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            local info=C_Container.GetContainerItemInfo(bag,slot)
            if info and info.itemID then
                local item=items[info.itemID] or {id=info.itemID,count=0,icon=info.iconFileID,link=info.hyperlink}
                if ui.materialSaleContext then
                    local context=ui.materialSaleContext(bag,slot)
                    if not item.context or context.bound==false then item.context=context end
                end
                item.count=item.count+(info.stackCount or 1) items[info.itemID]=item
                if item.context then item.context.count=item.count end
            end
        end
    end
    return items
end
local function itemName(id) return C_Item.GetItemNameByID(id) or ("#"..id) end
local function editColor(db,id,refresh)
    if not ColorPickerFrame then
        if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_ColorPicker")
        elseif UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_ColorPicker") end
    end
    local picker=ColorPickerFrame
    if not picker then return end
    -- Cerrar primero el selector anterior, sin mezclar sus callbacks.
    picker:Hide()
    local c=color(id,db)
    local previous=db.materialColors and db.materialColors[id]
    previous=previous and {previous[1],previous[2],previous[3]} or nil
    local function changed()
        local r,g,b=picker:GetColorRGB()
        db.materialColors=db.materialColors or {}
        db.materialColors[id]={r,g,b}
        dirty=true refresh()
    end
    local function cancel()
        db.materialColors=db.materialColors or {}
        db.materialColors[id]=previous
        dirty=true refresh()
    end
    if picker.SetupColorPickerAndShow then
        picker:SetupColorPickerAndShow({r=c[1],g=c[2],b=c[3],hasOpacity=false,swatchFunc=changed,cancelFunc=cancel})
    else
        picker.func=nil picker.opacityFunc=nil picker.cancelFunc=nil
        picker.hasOpacity=false
        picker:SetColorRGB(c[1],c[2],c[3])
        picker.func=changed picker.cancelFunc=cancel
        picker:Show()
    end
end
local function renderRecipients(db,id,refresh,context)
    panel.text:SetText(id and ("|cffffd26a"..itemName(id).."|r") or "No tienes materiales en las bolsas.")
    if id and ui.materialAdviceText then
        panel.text:SetText("|cffffd26a"..itemName(id).."|r\n"..ui.materialAdviceText(db,id,context))
    end
    local top=panel.text:GetStringHeight()+18
    local entries=id and ui.materialRecipients(db,id) or {}
    if #entries==0 and id then
        if not ui.materialAdviceText then panel.text:SetText("|cffffd26a"..itemName(id).."|r\n\nSin destinatarios registrados.") end
        top=panel.text:GetStringHeight()+18
    end
    for i,e in ipairs(entries) do
        local row=panel.recipients[i]
        if not row then
            row=CreateFrame("Frame",nil,panel.detail)
            row:SetWidth(505)
            row.star=ui.button(row) row.star:SetSize(28,28) row.star:SetPoint("TOPLEFT",0,0)
            row.star.mark=row.star:CreateTexture(nil,"OVERLAY")
            row.star.mark:SetTexture("Interface\\COMMON\\ReputationStar")
            row.star.mark:SetSize(18,18) row.star.mark:SetPoint("CENTER")
            row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            row.text:SetPoint("TOPLEFT",38,-2) row.text:SetWidth(465) row.text:SetJustifyH("LEFT")
            panel.recipients[i]=row
        end
        local names={}
        for _,p in ipairs(professions(db,id)) do
            if e.professions[p] then names[#names+1]=tint(p,label(p),db) end
        end
        local prefix=e.favorite and "Favorito: " or (i==1 and e.known>0 and "Sugerido: " or "")
        row.text:SetText(prefix..ui.short(e.who).." · "..table.concat(names,", ")..
            "\n"..e.known.." aprendidas · "..e.future.." por aprender"..
            (#e.examples>0 and ("\n"..table.concat(e.examples,", ")) or ""))
        local height=math.max(30,row.text:GetStringHeight()+6)
        row:SetHeight(height) row:ClearAllPoints() row:SetPoint("TOPLEFT",4,-top)
        row.star.mark:SetDesaturated(not e.favorite)
        row.star.mark:SetVertexColor(1,e.favorite and .82 or 1,e.favorite and .2 or 1,e.favorite and 1 or .35)
        row.star:SetBackdropBorderColor(e.favorite and 1 or .4,e.favorite and .82 or .4,.2,1)
        local who,material=e.who,id
        row.star:SetScript("OnClick",function()
            ui.setMaterialFavorite(db,material,who,not e.favorite)
            refresh()
        end)
        row.star:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(e.favorite and "Quitar favorito para este material" or "Priorizar para este material")
            GameTooltip:Show()
        end)
        row.star:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:Show() top=top+height+12
    end
    for i=#entries+1,#panel.recipients do panel.recipients[i]:Hide() end
    panel.legendTitle:ClearAllPoints() panel.legendTitle:SetPoint("TOPLEFT",4,-top)
    panel.legendTitle:SetText("Profesiones · Colores")
    top=top+26
    for i,p in ipairs(professionOrder) do
        local row=panel.legend[i]
        if not row then
            row=ui.button(panel.detail) row:SetSize(244,36)
            row.icon=CreateFrame("Frame",nil,row) row.icon:SetSize(28,28) row.icon:SetPoint("LEFT",5,0)
            row.icon.art=row.icon:CreateTexture(nil,"ARTWORK") row.icon.art:SetAllPoints()
            row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            row.name:SetPoint("LEFT",row.icon,"RIGHT",8,0) row.name:SetWidth(192) row.name:SetJustifyH("LEFT")
            panel.legend[i]=row
        end
        row:ClearAllPoints() row:SetPoint("TOPLEFT",4+((i-1)%2)*252,-top-math.floor((i-1)/2)*42)
        row.icon.art:SetTexture("Interface\\Icons\\"..professionIcons[p])
        row.name:SetText(tint(p,label(p),db))
        ui.professionSampleBorder(row.icon,p,db)
        local professionID=p
        row:SetScript("OnClick",function() editColor(db,professionID,refresh) end)
        row:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT") GameTooltip:SetText("Cambiar color de "..label(professionID)) GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:Show()
    end
    top=top+math.ceil(#professionOrder/2)*42
    panel.reset:ClearAllPoints() panel.reset:SetPoint("TOPLEFT",4,-top)
    panel.reset:SetScript("OnClick",function() db.materialColors=nil dirty=true refresh() end)
    panel.auctionToggle:ClearAllPoints() panel.auctionToggle:SetPoint("TOPLEFT",256,-top)
    panel.auctionToggle:SetText(db.materialAuctionAlerts==false and "Aviso subasta: no" or "Aviso subasta: sí")
    panel.auctionToggle:SetScript("OnClick",function() db.materialAuctionAlerts=db.materialAuctionAlerts==false dirty=true refresh() end)
    top=top+38
    local function cycle(key,values)
        local current=tonumber(db[key]) or (key=="materialAuctionMinimum" and 10000 or 5)
        local value=values[1]
        for i,v in ipairs(values) do if v==current then value=values[i%#values+1] break end end
        db[key]=value dirty=true refresh()
    end
    panel.auctionMinimum:ClearAllPoints() panel.auctionMinimum:SetPoint("TOPLEFT",4,-top)
    panel.auctionMinimum:SetText("Mínimo/u: "..(ui.materialMoney and ui.materialMoney(db.materialAuctionMinimum or 10000) or "1 oro"))
    panel.auctionMinimum:SetScript("OnClick",function() cycle("materialAuctionMinimum",{1000,5000,10000,50000}) end)
    panel.auctionMultiple:ClearAllPoints() panel.auctionMultiple:SetPoint("TOPLEFT",256,-top)
    panel.auctionMultiple:SetText("Sobre vendedor: ×"..(db.materialAuctionMultiple or 5))
    panel.auctionMultiple:SetScript("OnClick",function() cycle("materialAuctionMultiple",{2,5,10,20}) end)
    panel.detail:SetHeight(top+38)
end
function ui.hideMaterials() if panel then panel:Hide() end end
function ui.materials(parent,db,refresh)
    if not panel then
        panel=CreateFrame("Frame",nil,parent)
        panel:SetPoint("TOPLEFT",24,-112) panel:SetSize(885,425)
        local function scroll(x,width)
            local s=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
            s:SetPoint("TOPLEFT",x,0) s:SetSize(width,390)
            local child=CreateFrame("Frame",nil,s) child:SetSize(width,1) s:SetScrollChild(child)
            return s,child
        end
        panel.left,panel.items=scroll(0,295)
        panel.right,panel.detail=scroll(335,520)
        panel.text=panel.detail:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        panel.text:SetPoint("TOPLEFT",4,-4) panel.text:SetWidth(505) panel.text:SetJustifyH("LEFT")
        panel.buttons={} panel.recipients={} panel.legend={}
        panel.legendTitle=panel.detail:CreateFontString(nil,"OVERLAY","GameFontNormal")
        panel.reset=ui.button(panel.detail) panel.reset:SetSize(190,26) panel.reset:SetText("Restablecer colores")
        panel.auctionToggle=ui.button(panel.detail) panel.auctionToggle:SetSize(244,26)
        panel.auctionMinimum=ui.button(panel.detail) panel.auctionMinimum:SetSize(244,26)
        panel.auctionMultiple=ui.button(panel.detail) panel.auctionMultiple:SetSize(244,26)
    end
    refreshPanel=refresh
    panel:Show()
    local items=stock() local list={}
    for _,item in pairs(items) do list[#list+1]=item end
    table.sort(list,function(a,b) return itemName(a.id)<itemName(b.id) end)
    if not items[chosen] then chosen=list[1] and list[1].id end
    for i,item in ipairs(list) do
        local b=panel.buttons[i]
        if not b then
            b=ui.button(panel.items) b:SetSize(292,30) b:SetPoint("TOPLEFT",0,-(i-1)*33)
            panel.buttons[i]=b
            b:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT") GameTooltip:SetHyperlink("item:"..self.itemID)
                if ui.addMaterialTooltip then ui.addMaterialTooltip(GameTooltip,self.itemID,self.context) end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        local id=item.id
        b.itemID=id
        b.context=item.context
        b:SetText("|T"..(item.icon or 134400)..":20|t "..itemName(id).." ×"..item.count)
        b:SetBackdropBorderColor(chosen==id and 1 or .4,.65,.25,1)
        b:SetScript("OnClick",function() chosen=id panel.right:SetVerticalScroll(0) refresh() end)
        b:Show()
    end
    for i=#list+1,#panel.buttons do panel.buttons[i]:Hide() end
    panel.items:SetHeight(math.max(1,#list*33))
    renderRecipients(db,chosen,refresh,chosen and items[chosen] and items[chosen].context)
end

-- Capas propias: no modifican las texturas de calidad ni la marca de misión.
local decorated=setmetatable({},{__mode="k"})
local function drawNeon(button,list,db)
    local textures=decorated[button]
    if #list==0 then
        for _,t in ipairs(textures or {}) do t:Hide() end
        return
    end
    if not textures then textures={} decorated[button]=textures end
    local n=0
    for i,p in ipairs(list) do
        local c=color(p,db)
        for side=1,4 do
            n=n+1
            local t=textures[n]
            if not t then t=button:CreateTexture(nil,"OVERLAY",nil,6) textures[n]=t end
            t:ClearAllPoints() t:SetColorTexture(c[1],c[2],c[3],.95)
            local width,height=button:GetWidth(),button:GetHeight()
            if side==1 or side==2 then
                t:SetSize(width/#list,2)
                t:SetPoint(side==1 and "TOPLEFT" or "BOTTOMLEFT",button,side==1 and "TOPLEFT" or "BOTTOMLEFT",(i-1)*width/#list,0)
            else
                t:SetSize(2,height/#list)
                t:SetPoint(side==3 and "TOPLEFT" or "TOPRIGHT",button,side==3 and "TOPLEFT" or "TOPRIGHT",0,-(i-1)*height/#list)
            end
            t:SetBlendMode("ADD") t:Show()
        end
    end
    for i=n+1,#textures do textures[i]:Hide() end
end
function ui.materialBorder(button,id,quest,context)
    local db=ui.guildState()
    local primary=db.materialBorders~=false and not quest and id and ui.materialPrimaryProfession(db,id)
    local list=primary and {primary} or {}
    drawNeon(button,list,db)
    if ui.materialAuctionGlow then ui.materialAuctionGlow(button,id,db,quest,context) end
end
function ui.professionSampleBorder(button,id,db)
    drawNeon(button,{id},db)
end
local hooked=setmetatable({},{__mode="k"})
local function updateBags()
    if InCombatLockdown() or not C_Container then return end
    local containers,seen={},{}
    local function add(c)
        if c and not seen[c] then containers[#containers+1]=c seen[c]=true end
    end
    add(ContainerFrameCombinedBags)
    for _,c in pairs(ContainerFrameContainer and ContainerFrameContainer.ContainerFrames or {}) do add(c) end
    for i=1,math.max(NUM_CONTAINER_FRAMES or 0,NUM_TOTAL_BAG_FRAMES or 0,14) do add(_G["ContainerFrame"..i]) end
    for _,container in ipairs(containers) do
        if not hooked[container] then
            hooked[container]=true
            container:HookScript("OnShow",function() C_Timer.After(.05,function() dirty=true end) end)
            if container.UpdateItems and hooksecurefunc then hooksecurefunc(container,"UpdateItems",function() dirty=true end) end
        end
        if container:IsShown() then
            local buttons,seenButtons={},{}
            local function addButton(b)
                if type(b)=="table" and b.CreateTexture and not seenButtons[b] then buttons[#buttons+1]=b seenButtons[b]=true end
            end
            for _,b in pairs(container.Items or {}) do addButton(b) end
            if container.EnumerateValidItems then
                for a,b in container:EnumerateValidItems() do addButton(type(a)=="table" and a or b) end
            end
            local name=container.GetName and container:GetName()
            for i=1,(container.size or 36) do addButton(container["Item"..i] or (name and _G[name.."Item"..i])) end
            for _,b in ipairs(buttons) do
                local bag=b.GetBagID and b:GetBagID()
                local slot=b.GetID and b:GetID()
                if b.GetBagAndSlot then bag,slot=b:GetBagAndSlot() end
                if bag==nil then bag=container:GetID() end
                local info=type(bag)=="number" and type(slot)=="number" and slot>0 and C_Container.GetContainerItemInfo(bag,slot)
                local quest=info and C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag,slot)
                ui.materialBorder(b,info and info.itemID,quest and (quest.isQuestItem or (quest.questID and quest.questID>0)),
                    info and ui.materialSaleContext and ui.materialSaleContext(bag,slot))
            end
        end
    end
end
local f=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED"}) do f:RegisterEvent(e) end
f:SetScript("OnEvent",function(_,event)
    dirty=true
    if event=="GET_ITEM_INFO_RECEIVED" then cache=nil end
    if panel and panel:IsShown() and refreshPanel then refreshPanel() end
    if event=="PLAYER_LOGIN" and hooksecurefunc then
        if GameTooltip and GameTooltip.SetBagItem then
            hooksecurefunc(GameTooltip,"SetBagItem",function(tooltip,bag,slot)
                if InCombatLockdown() then return end
                local info=C_Container and C_Container.GetContainerItemInfo(bag,slot)
                if not info or not info.itemID then return end
                if ui.addMaterialTooltip then
                    ui.addMaterialTooltip(tooltip,info.itemID,ui.materialSaleContext(bag,slot))
                    return
                end
                local recipients=ui.materialRecipients(ui.guildState(),info.itemID)
                if #recipients==0 then return end
                tooltip:AddLine("TisteltiGuild · Destino de materiales",1,.82,.3)
                for i=1,math.min(3,#recipients) do
                    local e=recipients[i]
                    tooltip:AddLine((e.favorite and "|cffffd133Favorito|r · " or "")..ui.short(e.who).." · "..e.known.." aprendidas · "..e.future.." por aprender",.65,1,.8)
                end
                tooltip:AddLine("Ver detalles: Profesiones → Repartir materiales",.7,.7,.7)
                tooltip:Show()
            end)
        end
        for _,name in ipairs({"ContainerFrame_Update","ContainerFrame_GenerateFrame","ToggleAllBags","OpenAllBags","ToggleBag"}) do
            if type(_G[name])=="function" then hooksecurefunc(name,function() dirty=true end) end
        end
    end
end)
-- Sólo actualiza cuando cambia el inventario, las recetas o la vista de bolsas.
local elapsed=0
f:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<.2 then return end
    elapsed=0
    if dirty and not InCombatLockdown() then
        dirty=false updateBags()
        if ui.refreshMaterialBanks then ui.refreshMaterialBanks() end
    end
end)
