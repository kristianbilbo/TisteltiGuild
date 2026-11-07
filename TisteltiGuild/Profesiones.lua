local _, ui = ...
local base = {"Alquimia","Desuello","Encantamiento","Herrería","Herboristería","Ingeniería","Minería","Peletería","Sastrería","Cocina","Pesca","Primeros auxilios"}
local books={["Alquimia"]=2259,["Encantamiento"]=7411,["Herrería"]=2018,["Ingeniería"]=4036,["Minería"]=2656,["Peletería"]=2108,["Sastrería"]=3908,["Cocina"]=2550,["Primeros auxilios"]=3273}
local panel, selected, chosen, profession, query

local function icon(id) return "|T"..(id or 134400)..":18:18|t " end
local function sorted(set)
    local list={}
    for k in pairs(set) do list[#list+1]=k end
    table.sort(list)
    return list
end

local function list(parent,x,width)
    local sc=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
    sc:SetPoint("TOPLEFT",x,-33)
    sc:SetSize(width,320)
    local child=CreateFrame("Frame",nil,sc)
    child:SetSize(width,1)
    sc:SetScrollChild(child)
    return {child=child,scroll=sc,width=width,buttons={}}
end
local function entry(column,i,text,enabled,checked,click)
    local b=column.buttons[i]
    if not b then
        b=ui.button(column.child)
        column.buttons[i]=b
        b:SetSize(column.width,24)
        b:SetPoint("TOPLEFT",0,-(i-1)*26)
    end
    b:SetText(text)
    b:SetEnabled(enabled)
    b:SetDisabledFontObject(GameFontDisableSmall)
    b:SetAlpha(enabled and 1 or .52)
    b:SetBackdropBorderColor(checked and 1 or .43,checked and .82 or .39,checked and .28 or .3,1)
    b:SetScript("OnClick",click)
    b:Show()
end
local function finish(column,n)
    for i=n+1,#column.buttons do column.buttons[i]:Hide() end
    column.child:SetHeight(math.max(1,n*26))
end
function ui.hideCraft()
    if panel then panel:Hide() end
end
function ui.craft(parent,db,selfName,search,refresh,order)
    if not panel then
        panel=CreateFrame("Frame",nil,parent)
        panel:SetPoint("TOPLEFT",14,-106)
        panel:SetSize(906,385)
        panel.person=ui.button(panel)
        panel.person:SetSize(220,24)
        panel.person:SetPoint("TOPLEFT")
        panel.book=ui.button(panel)
        panel.book:SetSize(160,24)
        panel.book:SetPoint("TOPLEFT",230,0)
        panel.book:SetText("Abrir mi libro de oficio")
        panel.prof=list(panel,0,145)
        panel.rec=list(panel,178,295)
        panel.detail=list(panel,510,350)
        panel.text=panel.detail.child:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        panel.text:SetPoint("TOPLEFT",2,-3)
        panel.text:SetWidth(345)
        panel.text:SetJustifyH("LEFT")
    end
    panel:Show()
    local people,all,known,items={},{},{},{}
    people[selfName]=true
    for _,p in ipairs(base) do all[p]=true end
    for _,r in pairs(db.recipes) do people[r.who]=true all[r.prof]=true end
    for who in pairs(db.members or {}) do people[who]=true end
    if selected and not people[selected] then selected=nil end
    local chars=sorted(people)
    panel.person:SetText((selected and ui.short(selected) or "Toda la hermandad").."  >")
    panel.person:SetScript("OnClick",function()
        local nextIndex=1
        for i,n in ipairs(chars) do if selected==n then nextIndex=i+1 break end end
        selected=chars[nextIndex]
        profession,chosen=nil,nil
        refresh()
    end)
    for _,r in pairs(db.recipes) do
        if not selected or r.who==selected then known[r.prof]=true end
    end
    local isKnown=IsSpellKnown or IsPlayerSpell
    if isKnown and (not selected or selected==selfName) then
        for p,id in pairs(books) do if isKnown(id) then known[p]=true end end
    end
    local profs=sorted(all)
    if not profession or not known[profession] then profession=sorted(known)[1] end
    local spell=books[profession]
    local cast=CastSpellByID or (C_Spell and C_Spell.CastSpell)
    panel.book:SetShown(spell~=nil and isKnown and isKnown(spell) and cast~=nil or false)
    panel.book:SetScript("OnClick",function() if spell and cast and not InCombatLockdown() then cast(spell) end end)
    for i,p in ipairs(profs) do
        local name=p
        entry(panel.prof,i,p,known[p] or false,p==profession,function()
            profession,chosen=name,nil
            panel.rec.scroll:SetVerticalScroll(0)
            refresh()
        end)
    end
    finish(panel.prof,#profs)
    for key,r in pairs(db.recipes) do
        if r.prof==profession then
            local item=items[r.name] or {who={},mats=""}
            local id=tonumber(key:match(":(%d+)$"))
            if id and not item.icon then
                local ok,spec=pcall(C_TradeSkillUI.GetRecipeSchematic,id,false)
                local output=ok and spec and spec.outputItemID
                item.icon=(output and C_Item.GetItemIconByID(output)) or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id))
            end
            items[r.name]=item
            item.who[r.who]=true
            if #r.mats>#item.mats then item.mats=r.mats end
        end
    end
    local visible={}
    for name,item in pairs(items) do
        local haystack=name.." "..item.mats.." "..table.concat(sorted(item.who)," ")
        if (not selected or item.who[selected]) and haystack:lower():find(search,1,true) then visible[name]=true end
    end
    local recipes=sorted(visible)
    if not chosen or not visible[chosen] then chosen=recipes[1] end
    if query~=search then panel.rec.scroll:SetVerticalScroll(0) query=search end
    for i,n in ipairs(recipes) do
        local name=n
        entry(panel.rec,i,icon(items[n].icon)..n,true,n==chosen,function() chosen=name refresh() end)
    end
    finish(panel.rec,#recipes)
    local item=items[chosen]
    local makers=item and sorted(item.who) or {}
    local detail=item and (icon(item.icon).."|cffffd26a"..chosen.."|r\n\nMateriales\n"..(item.mats~="" and item.mats or "Sin componentes registrados").."\n\nEncargar a") or "Sin recetas registradas."
    if panel.text:GetText()~=detail then
        panel.text:SetText(detail)
        panel.detail.scroll:SetVerticalScroll(0)
    end
    local top=panel.text:GetStringHeight()+10
    local seen,count={},0
    for _,who in ipairs(makers) do
        local target=who
        local label=ui.short(who)
        if not seen[label] then
            seen[label]=true
            count=count+1
            entry(panel.detail,count,label,true,false,function() order(chosen,target) end)
            local b=panel.detail.buttons[count]
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",0,-top-(count-1)*26)
        end
    end
    finish(panel.detail,count)
    panel.detail.child:SetHeight(top+count*26)
end
