local _, ui = ...
-- Interfaz de hermandad para Forever 16001.
local events = CreateFrame("Frame")
local window, listing, input, hint, title, actions
local tab, offset, rows = 1, 0, {}
local prefix = "DiarioGuild2"
local names = {"Grupo", "Profesiones", "Encargos", "Equipo", "Aventuras", "Retos", "Banco"}
-- Forever guarda el apellido en UnitFullName, pero el canal lo separa con un guion.
local function artisanKey(who)
    if not who then return end
    local realm=GetNormalizedRealmName()
    local full,suffix=who:match("^([^-]+)%-(.+)$")
    if not full then full,suffix=who,realm end
    if suffix==realm then
        local first,last=full:match("^(%S+)%s+([^%s-]+)$")
        if first then return first.."-"..last end
    end
    return full.."-"..suffix
end

local function migrateArtisans(db)
    if db.artisanKeysVersion==1 then return end
    local recipes={}
    for key,r in pairs(db.recipes) do
        local id=key:match("^[^:]+:(.+)$")
        if id then
            r.who=artisanKey(r.who)
            local k=r.who..":"..id
            if not recipes[k] or #(r.mats or "")>#(recipes[k].mats or "") then recipes[k]=r end
        else recipes[key]=r end
    end
    db.recipes=recipes
    local members={}
    for who,m in pairs(db.members or {}) do
        local k=artisanKey(who)
        if not members[k] or (m.t or 0)>(members[k].t or 0) then members[k]=m end
    end
    db.members=members
    db.artisanKeysVersion=1
end
local function realmName(unit)
    if not UnitExists(unit) then return end
    local name, realm = UnitFullName(unit)
    if not name or (issecretvalue and (issecretvalue(name) or issecretvalue(realm))) then return end
    return name.."-"..((realm and realm ~= "") and realm or GetNormalizedRealmName())
end
local function ownerKey(bucket,who)
    if bucket=="orders" or bucket=="wishes" then return artisanKey(who) end
    return who
end

local function migrateGearAndOrders(db)
    if db.gearOrderKeysVersion==1 then return end
    local gear={}
    for who,equipment in pairs(db.gear or {}) do
        local key=artisanKey(who)
        if gear[key]==nil or who==key then gear[key]=equipment end
    end
    db.gear=gear
    for _,bucket in ipairs({"orders","wishes"}) do
        local entries={}
        for _,entry in pairs(db[bucket] or {}) do
            entry.who=artisanKey(entry.who)
            local key=entry.who..":"..entry.id
            if not entries[key] or entry.done then entries[key]=entry end
        end
        db[bucket]=entries
    end
    db.gearOrderKeysVersion=1
end
local function state()
    local guild,_,_,realm = GetGuildInfo("player")
    local key = table.concat({GetNormalizedRealmName(),UnitFactionGroup("player") or "",guild or realmName("player") or "solo"},"/")
    TisteltiGuildDB = TisteltiGuildDB or {}
    TisteltiGuildDB[key] = TisteltiGuildDB[key] or {recipes={},orders={},goals={},wishes={}}
    if TisteltiGuildDB[key].share==nil then TisteltiGuildDB[key].share=true end
    migrateArtisans(TisteltiGuildDB[key])
    migrateGearAndOrders(TisteltiGuildDB[key])
    return TisteltiGuildDB[key]
end
local function available() return not InCombatLockdown() end
local function value() return strtrim(input:GetText() or "") end
local function line(s) rows[#rows+1]=s end
local function button(parent,label,width,x,y,fn)
    local b=ui.button(parent)
    b:SetSize(width,24) b:SetPoint("TOPLEFT",x,y) b:SetText(label) b:SetScript("OnClick",fn)
    return b
end
-- Cada cliente publica únicamente su propio libro en la hermandad actual.
local recipePrefix="TisteltiRec1"
local pendingRecipes, sentRecipes, partial = {}, {}, {}
local guildState, lastReplay, activeRecipe
local function scheduleRecipe(id,r)
    local payload=r.name.."\t"..r.prof.."\t"..r.mats
    if sentRecipes[id]~=payload and (not pendingRecipes[id] or pendingRecipes[id].data~=payload) then
        pendingRecipes[id]={data=payload,part=1}
    end
end
local function replay(db)
    local who=realmName("player")
    wipe(sentRecipes)
    for key,r in pairs(db.recipes) do
        local id=key:match(":(%d+)$")
        if id and who and r.who==artisanKey(who) then scheduleRecipe(id,r) end
    end
end
local function recipeTick()
    if not C_ChatInfo or not available() then return end
    local db=state()
    if db~=guildState then
        guildState=db
        wipe(pendingRecipes) wipe(sentRecipes) wipe(partial)
        lastReplay=nil
        if IsInGuild() and GetGuildInfo("player") then
            replay(db)
            C_ChatInfo.SendAddonMessage(recipePrefix,"?","GUILD")
        end
    end
    if not IsInGuild() then return end
    local id=activeRecipe and pendingRecipes[activeRecipe] and activeRecipe or next(pendingRecipes)
    activeRecipe=id
    if not id then return end
    local job=pendingRecipes[id]
    local n=math.ceil(#job.data/200)
    local i=job.part
    C_ChatInfo.SendAddonMessage(recipePrefix,id.." "..i.." "..n.." "..job.data:sub((i-1)*200+1,i*200),"GUILD")
    if i==n then sentRecipes[id]=job.data pendingRecipes[id]=nil else job.part=i+1 end
end
local function receiveRecipe(msg,ch,who)
    if ch~="GUILD" or type(who)~="string" then return end
    if not who:find("-",1,true) then who=who.."-"..GetNormalizedRealmName() end
    who=artisanKey(who)
    if who==artisanKey(realmName("player")) then return end
    if msg=="?" then
        if not lastReplay then
            lastReplay=true
            local db=state()
            C_Timer.After(2,function() lastReplay=nil if state()==db then replay(db) end end)
        end
        return
    end
    local id,i,n,chunk=msg:match("^(%d+) (%d+) (%d+) (.+)$")
    i,n=tonumber(i),tonumber(n)
    if not i or i<1 or i>n or n>128 then return end
    local key=who..":"..id
    if i==1 then partial[who]={key=key,n=n} end
    local parts=partial[who]
    if not parts or parts.key~=key or parts.n~=n or #parts+1~=i then return end
    parts[i]=chunk
    if i~=n then return end
    partial[who]=nil
    local name,prof,mats=table.concat(parts):match("^([^\t]+)\t([^\t]+)\t(.*)$")
    if name then state().recipes[key]={who=who,name=name,prof=prof,mats=mats} return true end
end
local function scan()
    if not available() then return end
    local api=C_TradeSkillUI
    if not api or not api.GetFilteredRecipeIDs or not api.GetBaseProfessionInfo then return end
    if (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) or (api.IsNPCCrafting and api.IsNPCCrafting()) or (api.IsTradeSkillGuild and api.IsTradeSkillGuild()) then return end
    local p=api.GetBaseProfessionInfo()
    if not p or not p.professionID or not p.skillLevel or p.skillLevel<1 then return end
    local ids=(api.GetAllRecipeIDs or api.GetFilteredRecipeIDs)()
    if not ids or not realmName("player") then return end
    local db=state() local data=db.recipes
    local who=artisanKey(realmName("player"))
    for _,id in ipairs(ids) do
        local r=api.GetRecipeInfo(id)
        if r and r.learned and r.name then
            local spec=api.GetRecipeSchematic(id,false)
            if spec then
                local mats={}
                for _,slot in ipairs(spec.reagentSlotSchematics or {}) do
                    if slot.required then
                        local choices={}
                        for _,item in ipairs(slot.reagents or {}) do
                            if item.itemID then choices[#choices+1]=C_Item.GetItemNameByID(item.itemID) or ("#"..item.itemID) end
                        end
                        mats[#mats+1]=(slot.quantityRequired or "?").." × "..(#choices>0 and table.concat(choices,"/") or "?")
                    end
                end
                data[who..":"..id]={who=who,name=r.name,prof=p.professionName or p.profession or tostring(p.professionID),mats=table.concat(mats,", ")}
                if who then scheduleRecipe(tostring(id),data[who..":"..id]) end
            end
        end
    end
end
local queue={}
local function send(kind,id,body)
    if not state().share or not IsInGuild() or not C_ChatInfo or #queue>=120 then return end
    local msg=kind.."\t"..id.."\t"..body
    if #msg<=245 then queue[#queue+1]=msg end
end
local bankOpen,personalOpen=false,false
local refresh
local function readPersonalBank()
    local kind=Enum and Enum.BankType and Enum.BankType.Character
    if not personalOpen or not kind or not C_Bank or not C_Bank.FetchPurchasedBankTabIDs
        or not C_Container or not C_Bank.CanUseBank(kind) then return end
    local bags=C_Bank.FetchPurchasedBankTabIDs(kind)
    if not bags or #bags==0 then return end
    local items,tabs={},{}
    for page,bag in ipairs(bags) do
        local size=C_Container.GetContainerNumSlots(bag)
        if not size or size<1 then return end
        local cells={}
        tabs[bag]={name="Pestaña "..page,size=size,slots=cells,t=time()}
        for slot=1,size do
            local id=C_Container.GetContainerItemID(bag,slot)
            local info=C_Container.GetContainerItemInfo(bag,slot)
            if id or info then
                if not id or not info or info.itemID~=id or not info.stackCount or info.stackCount<1 then return end
                items[id]=(items[id] or 0)+info.stackCount
                cells[slot]={id=id,count=info.stackCount,icon=info.iconFileID,link=info.hyperlink}
            end
        end
    end
    local db=state()
    db.personalBank=db.personalBank or {}
    db.personalBank[artisanKey(realmName("player"))]={items=items,tabs=tabs,t=time()}
    return true
end
local function readBank()
    if not bankOpen or not available() or not GetCurrentGuildBankTab or not GetGuildBankItemLink or not GetGuildBankItemInfo then return end
    local index=GetCurrentGuildBankTab()
    if not index or not GetGuildBankTabInfo then return end
    local name,_,visible=GetGuildBankTabInfo(index)
    if not visible then return end
    local items,cells={},{}
    for slot=1,98 do
        local texture,n=GetGuildBankItemInfo(index,slot)
        local link=GetGuildBankItemLink(index,slot)
        if texture and not link then return end
        if link then items[link]=(items[link] or 0)+(n or 1) cells[slot]={link=link,icon=texture,count=n or 1} end
    end
    local db=state()
    db.bank=db.bank or {}
    local who=realmName("player")
    db.bank[who]=db.bank[who] or {}
    db.bank[who][index]={name=name or tostring(index),t=time(),items=items,size=98,slots=cells}
    return true
end
local bankGeneration=0
local function queueBankRead()
    bankGeneration=bankGeneration+1
    local ticket=bankGeneration
    local function attempt(remaining)
        if ticket~=bankGeneration or not (personalOpen or bankOpen) then return end
        local ready
        if personalOpen then ready=readPersonalBank() else ready=readBank() end
        if ready then refresh()
        elseif remaining>0 then C_Timer.After(.5,function() attempt(remaining-1) end) end
    end
    C_Timer.After(.25,function() attempt(8) end)
end
local onGearLoot
local function captureLoot(text)
    if type(text)~="string" or (issecretvalue and issecretvalue(text)) then return end
    local link=text:match("(|c%x+|Hitem:[^|]+|h.-|h|r)")
    if not link then return end
    local function save()
        local _,_,quality=C_Item.GetItemInfo(link)
        if onGearLoot then onGearLoot(link) end
        if quality~=4 then return end
        local db=state()
        db.epics=db.epics or {}
        table.insert(db.epics,1,{t=time(),link=link,text=text})
        if #db.epics>150 then table.remove(db.epics) end
    end
    if Item and Item.CreateFromItemLink then Item:CreateFromItemLink(link):ContinueOnItemLoad(save) else save() end
end
local catalog={{"Minas de la Muerte",17,24,{166,167,168,214}},{"Las Mazmorras",24,30,{377,387,388,391}}}
local function snapshot()
    if not available() then return end
    local db=state()
    local qs,gear,ids={},{},{}
    for _,d in ipairs(catalog) do for _,id in ipairs(d[4]) do
        if C_QuestLog.IsOnQuest(id) then qs[#qs+1]=id end
    end end
    for slot=1,19 do
        local link=GetInventoryItemLink("player",slot)
        local itemID=link and link:match("item:(%d+)")
        if itemID then ids[#ids+1]=slot.."="..itemID end
        if link and C_Item.GetDetailedItemLevelInfo then
            local level=C_Item.GetDetailedItemLevelInfo(link)
            if level then gear[#gear+1]=slot.."="..level end
        end
    end
    local body=table.concat({UnitLevel("player"),UnitGroupRolesAssigned("player") or "NONE",table.concat(qs,","),table.concat(gear,",")},";")
    db.members=db.members or {}
    db.members[artisanKey(realmName("player"))]={body=body,t=time()}
    db.gear=db.gear or {}
    local equipment=table.concat(ids,",")
    db.gear[artisanKey(realmName("player"))]=equipment
    if equipment~="" then send("E","1",equipment) end
    send("P","1",body)
    local h=(TisteltiJourneyDB and TisteltiJourneyDB.history) or {}
    local kills=0
    for _,r in ipairs(h) do for _ in pairs(r.bosses or {}) do kills=kills+1 end end
    send("S","1",table.concat({#h,kills,#(db.epics or {})},","))
end
local function partyStory()
    if not available() then return end
    local db=state()
    local people={}
    for i=1,GetNumGroupMembers() do
        local u=(IsInRaid() and "raid" or "party")..i
        if UnitExists(u) and not UnitIsUnit(u,"player") then
            local n=realmName(u)
            if n then people[#people+1]=ui.short(n) end
        end
    end
    table.sort(people)
    local names=table.concat(people,", ")
    local me=realmName("player")
    if not me then return end
    db.partyStory=db.partyStory or {}
    local story=db.partyStory[me] or {}
    db.partyStory[me]=story
    if story.last==names then return end
    local hadParty=story.last and story.last~=""
    story.last=names
    if names=="" and not hadParty then return end
    local zone=GetRealZoneText() or ""
    table.insert(story,1,{t=time(),text=names~="" and ("Formamos grupo con "..names.." en "..zone..".") or "Nos despedimos del grupo."})
    if #story>40 then table.remove(story) end
end
local function plans(db)
    for _,d in ipairs(catalog) do
        local suitable=true
        for i=0,GetNumGroupMembers() do
            local u=i==0 and "player" or ((IsInRaid() and "raid" or "party")..i)
            if UnitExists(u) then local l=UnitLevel(u) if l<d[2] or l>d[3] then suitable=false end end
        end
        if suitable then line("Sugerencia por nivel · "..d[1].." ("..d[2].."–"..d[3]..")") end
    end
    for who,m in pairs(db.members or {}) do
        local lv,role,qs=m.body:match("^(%d+);([^;]*);([^;]*);")
        if lv then
            local list={}
            for id in qs:gmatch("%d+") do list[#list+1]=C_QuestLog.GetTitleForQuestID(tonumber(id)) or id end
            line(ui.short(who).." · "..role.." · misiones de las dos mazmorras: "..(#list>0 and table.concat(list,", ") or "ninguna").." · "..date("%d/%m %H:%M",m.t))
        end
    end
end
local slots={INVTYPE_HEAD=1,INVTYPE_NECK=2,INVTYPE_SHOULDER=3,INVTYPE_CHEST=5,INVTYPE_ROBE=5,INVTYPE_WAIST=6,INVTYPE_LEGS=7,INVTYPE_FEET=8,INVTYPE_WRIST=9,INVTYPE_HAND=10,INVTYPE_CLOAK=15,INVTYPE_RANGED=18}
local responses,requests={},{}
local function evaluate(id)
    local _,link=C_Item.GetItemInfo(id)
    if not link then return "Objeto pendiente de cargar" end
    local usable=C_Item.IsUsableItem or IsUsableItem
    if usable and not usable(link) then return "Sin uso disponible para este personaje" end
    if PawnGetItemData and PawnIsItemAnUpgrade then
        local item=PawnGetItemData(link)
        if item then
            local upgrades=PawnIsItemAnUpgrade(item,true)
            local best
            for _,u in pairs(type(upgrades)=="table" and upgrades or {}) do
                if u.PercentUpgrade and (not best or u.PercentUpgrade>best.PercentUpgrade) then best=u end
            end
            if best and best.PercentUpgrade>=(PawnBigUpgradeThreshold or 100) then return "Mejora según Pawn · sin base porcentual comparable" end
            if best then return ("Mejora según Pawn · +%.1f%% · "):format(best.PercentUpgrade*100)..(best.LocalizedScaleName or best.ScaleName or "") end
            return "Pawn no indica mejora con las escalas visibles"
        end
    end
    local _,_,_,loc=C_Item.GetItemInfoInstant(id)
    local slot=slots[loc]
    if usable and usable(link) and slot then
        local old=GetInventoryItemLink("player",slot)
        local level=C_Item.GetDetailedItemLevelInfo(link)
        local worn=old and C_Item.GetDetailedItemLevelInfo(old) or 0
        if level and worn and level>worn then return "Posible mejora por nivel de objeto" end
    end
    return "Sin puntuación disponible"
end
local function score(id)
    local ok,msg=pcall(evaluate,tonumber(id))
    return ok and msg or "Sin información suficiente"
end
local recentLoot={}
onGearLoot=function(link)
    local id=link:match("item:(%d+)")
    local equippable=C_Item.IsEquippableItem or IsEquippableItem
    if not id or not equippable or not equippable(link) then return end
    for k,t in pairs(recentLoot) do if GetTime()-t>60 then recentLoot[k]=nil end end
    if recentLoot[id] then return end
    recentLoot[id]=GetTime()
    local db=state()
    local name=C_Item.GetItemInfo(link)
    for _,wish in pairs(db.wishes) do
        if not wish.done and (wish.text==id or wish.text:match("item:(%d+)")==id or (name and wish.text:lower()==name:lower())) then
            print("TisteltiGuild · "..ui.short(wish.who).." busca "..link)
        end
    end
    local answers={[artisanKey(realmName("player"))]=score(id)}
    responses[id]=answers
    send("Q",id,"?")
    C_Timer.After(8,function()
        if responses[id]~=answers then return end
        local best,names=0,{}
        for who,answer in pairs(answers) do
            local pct=tonumber(answer:match("Pawn · %+(%d+%.?%d*)%%"))
            if pct and pct>0 then
                if pct>best then best,names=pct,{} end
                if pct==best then names[#names+1]=ui.short(who) end
            end
        end
        if #names>0 then
            table.sort(names)
            print(("TisteltiGuild · %s · Mayor mejora estimada entre las respuestas: %s (+%.1f%% según Pawn)."):format(link,table.concat(names,", "),best))
        end
    end)
end
local function record(bucket,kind)
    local s=value()
    if s=="" or #s>150 then hint:SetText("Escribe entre 1 y 150 bytes.") return end
    local db=state()
    db.seq=(db.seq or 0)+1
    local id=tostring(time()).."-"..db.seq
    local who=ownerKey(bucket,realmName("player"))
    db[bucket][who..":"..id]={who=who,text=s,id=id,expires=bucket=="goals" and time()+604800 or nil}
    send(kind,id,s) input:SetText("") refresh()
end
local months={"primer","segundo","tercer","cuarto","quinto","sexto","séptimo","octavo","noveno","décimo","undécimo","duodécimo"}
local function chronicle(t)
    local stamp=date("*t",t)
    local db=state()
    db.firstYear=math.min(db.firstYear or stamp.year,stamp.year)
    return ("Día %d del %s mes · Año %d de nuestra crónica"):format(stamp.day,months[stamp.month],stamp.year-db.firstYear+1)
end
local function draw()
    listing:SetText(#rows>0 and table.concat(rows,"\n\n") or "Todavía no hay datos.")
    window.page:SetHeight(math.max(1,listing:GetStringHeight()+16))
end
local orderFilter
local function assignedTo(r,db)
    if r.target then return r.target end
    local recipe,label=r.text:match("^(.-) → (.+)$")
    if not label then return end
    local found
    for _,known in pairs(db.recipes) do
        local who=artisanKey(known.who)
        if known.name==recipe and (ui.short(who)==label or ui.short(who)==ui.short(artisanKey(label))) then
            if found and found~=who then return end
            found=who
        end
    end
    if found then r.target=found r.recipe=recipe end
    return found
end
local function displayOrders(db)
    local choices,seen,orders={},{},{}
    local me=artisanKey(realmName("player"))
    for _,r in pairs(db.orders) do
        local target=assignedTo(r,db)
        if target and not seen[target] then
            choices[#choices+1]=target
            seen[target]=true
        end
    end
    table.sort(choices)
    if not seen[orderFilter] then orderFilter=nil end
    for _,r in pairs(db.orders) do
        if not orderFilter or r.target==orderFilter then orders[#orders+1]=r end
    end
    table.sort(orders,function(a,b)
        if (not a.done)~=(not b.done) then return not a.done end
        if a.id==b.id then return a.who<b.who end
        return a.id>b.id
    end)
    if not window.orderFilter then
        window.orderFilter=button(window,"",240,24,-104,function() end)
    end
    local filter=window.orderFilter
    filter:SetText("Encargado: "..(orderFilter and ui.short(orderFilter) or "Todos").."  ›")
    filter:SetScript("OnClick",function()
        local index=1
        for i,who in ipairs(choices) do if who==orderFilter then index=i+1 break end end
        orderFilter=choices[index]
        window.scroll:SetVerticalScroll(0)
        refresh()
    end)
    filter:Show()
    window.orderRows=window.orderRows or {}
    for i,r in ipairs(orders) do
        local row=window.orderRows[i]
        if not row then
            row=CreateFrame("Frame",nil,window.page)
            window.orderRows[i]=row
            row:SetSize(840,46)
            row:SetPoint("TOPLEFT",0,-(i-1)*48)
            row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            row.label:SetPoint("LEFT")
            row.label:SetWidth(650)
            row.label:SetJustifyH("LEFT")
            row.close=button(row,"Marcar como hecho",156,676,-9,function() end)
        end
        local order=r
        row.label:SetText((r.done and "|cff88cc88Hecho|r · " or "")..(r.recipe or r.text).."\nPedido por "..ui.short(r.who).." · "..(r.target and ("Encargado: "..ui.short(r.target)) or "Sin encargado confirmado"))
        row.close:SetShown(r.target==me and not r.done)
        row.close:SetScript("OnClick",function()
            if state()~=db or order.target~=artisanKey(realmName("player")) or order.done then return end
            order.done=true
            C_ChatInfo.SendAddonMessage("TisteltiOrder","DONE\t"..order.who.."\t"..order.id,"GUILD")
            refresh()
        end)
        row:Show()
    end
    listing:SetShown(#orders==0)
    listing:SetText("Todavía no hay encargos.")
    window.page:SetHeight(math.max(48,#orders*48))
end
refresh=function()
    if not window or not window:IsShown() or not available() then return end
    ui.hideCraft() ui.hideBank()
    local journal=tab==1 or tab==5
    input:SetShown(tab==6)
    if window.orderFilter then window.orderFilter:Hide() end
    for _,row in ipairs(window.orderRows or {}) do row:Hide() end
    listing:Show()
    window.scroll:SetShown(tab~=2 and tab~=7)
    window.scroll:ClearAllPoints()
    window.scroll:SetPoint("TOPLEFT",window,"TOPLEFT",38,journal and -120 or -150)
    window.scroll:SetPoint("BOTTOMRIGHT",window,"BOTTOMRIGHT",-52,68)
    if window.lastTab~=tab then window.scroll:SetVerticalScroll(0) window.lastTab=tab end
    rows={} title:SetText("TisteltiGuild · "..names[tab])
    for _,b in ipairs(actions) do b:Hide() end
    local function action(i,label,fn)
        local b=actions[i] b:SetText(label) b:SetScript("OnClick",fn) b:Show()
    end
    local db=state()
    window.paper:SetShown(tab==1 or tab==5)
    listing:SetTextColor(1,1,1)
    if tab==1 or tab==5 then listing:SetTextColor(.19,.11,.055) end
    if tab==1 then
        for i,r in ipairs((db.partyStory or {})[realmName("player")] or {}) do
            if i>4 then break end
            line(chronicle(r.t).."   "..r.text)
        end
        local history=(TisteltiJourneyDB and TisteltiJourneyDB.history) or {}
        for i=1,math.min(#history,4) do
            local r=history[i]
            local people={}
            for who in pairs(r.people or {}) do people[#people+1]=ui.short(who) end
            table.sort(people)
            line(chronicle(r.start).."   Entramos en "..r.name.." con "..table.concat(people,", ")..".")
        end
        line(chronicle(time()).."\nLos compañeros que hoy caminan a nuestro lado")
        hint:SetText("Crónica del grupo. Compartir equipo permite a la hermandad consultar tus piezas y comparar el botín.")
        local function unit(u)
            local n=realmName(u)
            if n then line(ui.short(n).." · "..UnitLevel(u).." · "..(UnitClass(u) or "?").." · "..(UnitGroupRolesAssigned(u) or "?")) end
        end
        unit("player")
        for i=1,GetNumGroupMembers() do local u=(IsInRaid() and "raid" or "party")..i if not UnitIsUnit(u,"player") then unit(u) end end
        local map=C_Map.GetBestMapForUnit("player")
        if map and C_QuestLog.GetQuestsOnMap then
            for _,q in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do if q.questID and C_QuestLog.IsOnQuest(q.questID) then line("Misión · "..(C_QuestLog.GetTitleForQuestID(q.questID) or q.questID)) end end
        end
        plans(db)
        action(1,db.share and "Compartir equipo: sí" or "Compartir equipo: no",function() db.share=not db.share wipe(queue) snapshot() refresh() end)
    elseif tab==2 then
        hint:SetText("Elige un oficio y una receta para consultar los materiales y sus artesanos.")
        ui.craft(window,db,artisanKey(realmName("player")),"",refresh,function(recipe,target)
            if not IsInGuild() then hint:SetText("Necesitas una hermandad para enviar el encargo.") return end
            db.seq=(db.seq or 0)+1
            local id=tostring(time()).."-"..db.seq
            local who=artisanKey(realmName("player"))
            local text=recipe.." → "..ui.short(target)
            local msg=id.."\t"..target.."\t"..recipe
            if #msg>245 then hint:SetText("El nombre del encargo supera el límite de envío.") return end
            db.orders[who..":"..id]={who=who,id=id,text=text,recipe=recipe,target=artisanKey(target)}
            orderFilter=artisanKey(target)
            C_ChatInfo.SendAddonMessage("TisteltiOrder",msg,"GUILD")
            tab=3 offset=0 input:SetText("") refresh()
        end)
        action(1,"Materiales del banco",function() tab=7 input:SetText("") refresh() end)
    elseif tab==7 then
        hint:SetText("Contenido de la última visita. Abre el banco para actualizar sus casillas.")
        ui.bank(window,(db.personalBank or {})[artisanKey(realmName("player"))],(db.bank or {})[realmName("player")] or {},refresh)
        return
    elseif tab==5 then
        hint:SetText("Registro automático por personaje. Abre el diario para consultar el mapa o copiar una visita.")
        for _,r in ipairs((TisteltiJourneyDB and TisteltiJourneyDB.history) or {}) do line("|TInterface\\Icons\\INV_Misc_Map_01:18|t "..chronicle(r.start).." · "..r.name.." · "..math.floor((r.stop-r.start)/60).." min") end
        local bosses,minutes=0,0
        for _,r in ipairs(TisteltiJourneyDB.history or {}) do
            for _ in pairs(r.bosses or {}) do bosses=bosses+1 end
            minutes=minutes+(r.stop-r.start)/60
        end
        table.insert(rows,1,string.format("|TInterface\\Icons\\INV_Misc_Book_09:24|t  %d expediciones     |TInterface\\Icons\\INV_Misc_Bone_02:24|t  %d jefes     ·     %.0f min",#TisteltiJourneyDB.history,bosses,minutes))
        for who,stat in pairs(db.stats or {}) do
            local v,k,e=stat.body:match("^(%d+),(%d+),(%d+)$")
            if v then line(who.." · "..v.." visitas · "..k.." jefes · "..e.." botines épicos observados") end
        end
        for _,e in ipairs(db.epics or {}) do line(date("%d/%m",e.t).." · "..e.text) end
        action(1,"Diario y mapa",function() window:Hide() SlashCmdList.DIARIOGUILD("") end)
    elseif tab==3 then
        hint:SetText("Los encargos se crean desde Profesiones. Cada artesano puede marcar los suyos como hechos.")
        displayOrders(db)
        return
    elseif tab==4 then
        hint:SetText("Equipo registrado por personaje. Las mejoras de botín se consultan automáticamente.")
        for who,gear in pairs(db.gear or {}) do
            line("Equipo · "..ui.short(who))
            for slot,id in gear:gmatch("(%d+)=(%d+)") do
                local item=select(2,C_Item.GetItemInfo(tonumber(id)))
                local tex=C_Item.GetItemIconByID(tonumber(id)) or 134400
                local slotNames={"Cabeza","Cuello","Hombros","Camisa","Pecho","Cintura","Piernas","Pies","Muñecas","Manos","Anillo","Anillo","Abalorio","Abalorio","Espalda","Mano principal","Mano secundaria","A distancia","Tabardo"}
                line("|T"..tex..":22|t  "..(slotNames[tonumber(slot)] or slot).."   "..(item or ("|Hitem:"..id.."|h[Objeto #"..id.."]|h")))
            end
        end
    elseif tab==6 then
        hint:SetText("Escribe un reto para la hermandad. Caduca a los siete días.")
        for _,r in pairs(db.goals) do
            if not r.done and (not r.expires or time()<r.expires) then line(r.text.." · "..ui.short(r.who)) end
        end
        table.sort(rows)
        action(1,"Crear reto de 7 días",function() record("goals","G") end)
    end
    draw()
end
function GestionGuildAbrir()
    if not available() then return end
    if not window then
        window=CreateFrame("Frame","GestionGuildPanel",UIParent,"BackdropTemplate")
        window:SetSize(940,600) window:SetScale(math.min(1,UIParent:GetWidth()/1080,UIParent:GetHeight()/675)) window:SetPoint("CENTER") window:SetFrameStrata("DIALOG")
        ui.panel(window)
        window:EnableMouse(true) window:SetMovable(true) window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart",window.StartMoving) window:SetScript("OnDragStop",window.StopMovingOrSizing)
        table.insert(UISpecialFrames,"GestionGuildPanel")
        local function font(x,y,width,style)
            local f=window:CreateFontString(nil,"OVERLAY",style) f:SetPoint("TOPLEFT",x,y) f:SetWidth(width) f:SetJustifyH("LEFT") return f
        end
        title=font(16,-16,600,"GameFontNormalLarge")
        for i,ix in ipairs({1,2,3,4,5,6,7}) do local target=ix
            button(window,names[ix],126,15+(i-1)*130,-48,function() tab=target offset=0 input:SetText("") refresh() end)
        end
        hint=font(18,-82,700,"GameFontHighlightSmall")
        input=CreateFrame("EditBox",nil,window,"InputBoxTemplate")
        input:SetSize(888,24) input:SetPoint("TOPLEFT",22,-110) input:SetAutoFocus(false) input:SetMaxLetters(150)
        input:SetScript("OnEnterPressed",function(self) self:ClearFocus() refresh() end)
        window.paper=window:CreateTexture(nil,"ARTWORK")
        window.paper:SetTexture("Interface\\QuestFrame\\QuestBG")
        window.paper:SetTexCoord(.02,.57,.02,.62)
        window.paper:SetPoint("TOPLEFT",14,-100)
        window.paper:SetPoint("BOTTOMRIGHT",-14,50)
        window.scroll=CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate")
        window.page=CreateFrame("Frame",nil,window.scroll)
        window.page:SetSize(845,1)
        window.scroll:SetScrollChild(window.page)
        listing=window.page:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        listing:SetPoint("TOPLEFT")
        listing:SetWidth(842)
        listing:SetJustifyH("LEFT")
        listing:SetSpacing(2)
        if window.page.SetHyperlinksEnabled then window.page:SetHyperlinksEnabled(true)
        window.page:SetScript("OnHyperlinkEnter",function(self,link)
            GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end)
        window.page:SetScript("OnHyperlinkLeave",function() GameTooltip:Hide() end) end
        actions={}
        for i=1,3 do actions[i]=button(window,"",140,16+(i-1)*146,-560,function() end) end
        button(window,"Cerrar",90,832,-560,function() window:Hide() end)
    end
    window:Show() refresh()
end
SLASH_GESTIONGUILD1="/guildpanel"
SLASH_GESTIONGUILD2="/tisteltiguild"
SlashCmdList.GESTIONGUILD=GestionGuildAbrir
local buckets={O="orders",G="goals",W="wishes",T="trips"}
local function receive(p,msg,ch,sender)
    if p~=prefix or ch~="GUILD" or not available() or not state().share or #msg>245 then return end
    if not sender:find("-",1,true) then sender=sender.."-"..GetNormalizedRealmName() end
    if artisanKey(sender)==artisanKey(realmName("player")) then return end
    local kind,id,body=msg:match("^([PROGWDTJQASE])\t([^\t]+)\t(.+)$")
    if not kind then return end
    local db=state()
    db.trips=db.trips or {}
    if kind=="S" and body:match("^%d+,%d+,%d+$") then
        db.stats=db.stats or {} db.stats[sender]={body=body,t=time()}
    elseif kind=="Q" and id:match("^%d+$") and #id<=9 and (not requests[sender] or requests[sender].id~=id or time()-requests[sender].t>=5) then
        requests[sender]={id=id,t=time()} send("A",id,score(id))
    elseif kind=="A" and responses[id] then
        sender=artisanKey(sender)
        if recentLoot[id] and GetTime()-recentLoot[id]<60 and not responses[id][sender] and (body:find("Mejora según Pawn",1,true)==1 or body=="Posible mejora por nivel de objeto") then
            print("TisteltiGuild · "..ui.short(sender)..": "..body.." · "..(select(2,C_Item.GetItemInfo(tonumber(id))) or id))
        end
        responses[id][sender]=body
    elseif kind=="J" then
        local trip=db.trips[body..":"..id]
        if trip then trip.people=trip.people or {} trip.people[sender]=true end
    elseif kind=="E" and body:match("^[%d,=]+$") then db.gear=db.gear or {} db.gear[artisanKey(sender)]=body
    elseif kind=="P" then
        if body:match("^%d+;[%u]*;[%d,]*;[%d,=]*$") then db.members=db.members or {} db.members[artisanKey(sender)]={body=body,t=time()} end
    elseif kind=="R" then
        local prof,mats=body:match("^([^\t]+)\t(.*)$")
        if prof then sender=artisanKey(sender) db.recipes[sender..":"..id]={who=sender,name=id,prof=prof,mats=mats} end
    elseif id:match("^%d+%-%d+$") then
        local bucket=buckets[kind] or (kind=="D" and buckets[body])
        if bucket then
            sender=ownerKey(bucket,sender)
            local key=sender..":"..id
            if kind=="D" then if bucket~="orders" and db[bucket][key] then db[bucket][key].done=true end
            elseif not db[bucket][key] then db[bucket][key]={who=sender,id=id,text=body,expires=kind=="G" and time()+604800 or nil} end
        end
    end
    refresh()
end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
for _,event in ipairs({"BANKFRAME_OPENED","BANKFRAME_CLOSED","BAG_UPDATE_DELAYED","PLAYERBANKSLOTS_CHANGED","BANK_TABS_CHANGED","GUILDBANK_UPDATE_TABS","GUILDBANKFRAME_OPENED","GUILDBANKFRAME_CLOSED","GUILDBANKBAGSLOTS_CHANGED","CHAT_MSG_LOOT"}) do pcall(events.RegisterEvent,events,event) end
local pending
events:SetScript("OnEvent",function(_,event,...)
    if event=="PLAYER_LOGIN" then
        if C_ChatInfo then C_ChatInfo.RegisterAddonMessagePrefix("TisteltiOrder") C_ChatInfo.RegisterAddonMessagePrefix(prefix) C_ChatInfo.RegisterAddonMessagePrefix(recipePrefix) C_Timer.NewTicker(.45,recipeTick) end
        local function attach()
            if CharacterFrame and not CharacterFrame.tisteltiSnapshot then
                CharacterFrame:HookScript("OnShow",snapshot)
                CharacterFrame.tisteltiSnapshot=true
            end
        end
        attach()
        if ToggleCharacter and hooksecurefunc then hooksecurefunc("ToggleCharacter",function() attach() end) end
        C_Timer.After(4,partyStory)
        C_Timer.After(4,snapshot)
        C_Timer.NewTicker(120,snapshot)
        C_Timer.NewTicker(.7,function()
            if #queue>0 and available() and state().share and IsInGuild() then C_ChatInfo.SendAddonMessage(prefix,table.remove(queue,1),"GUILD") end
        end)
    elseif event=="GROUP_ROSTER_UPDATE" then partyStory() refresh()
    elseif event=="PLAYER_EQUIPMENT_CHANGED" then if available() then snapshot() end
    elseif event=="BANKFRAME_OPENED" then personalOpen=true queueBankRead()
    elseif event=="BANKFRAME_CLOSED" then personalOpen=false
    elseif event=="BAG_UPDATE_DELAYED" or event=="PLAYERBANKSLOTS_CHANGED" or event=="BANK_TABS_CHANGED" then
        if personalOpen then queueBankRead() end
    elseif event=="GUILDBANKFRAME_OPENED" then
        bankOpen=true
        local index=GetCurrentGuildBankTab and GetCurrentGuildBankTab()
        if index and index>0 and QueryGuildBankTab then QueryGuildBankTab(index) end
        queueBankRead()
    elseif event=="GUILDBANKFRAME_CLOSED" then bankOpen=false
    elseif event=="GUILDBANKBAGSLOTS_CHANGED" or event=="GUILDBANK_UPDATE_TABS" then if bankOpen then queueBankRead() end
    elseif event=="CHAT_MSG_LOOT" then captureLoot(...)
    elseif event=="CHAT_MSG_ADDON" then local p,msg,ch,who=... if p=="TisteltiOrder" and ch=="GUILD" then
        local owner,closedID=msg:match("^DONE\t([^\t]+)\t(%d+%-%d+)$")
        if owner then
            local db=state()
            local order=db.orders[artisanKey(owner)..":"..closedID]
            if order and assignedTo(order,db)==artisanKey(who) then order.done=true refresh() end
            return
        end
        local id,target,recipe=msg:match("^(%d+%-%d+)\t([^\t]+)\t([^\t]+)$")
        if id then
            if not who:find("-",1,true) then who=who.."-"..GetNormalizedRealmName() end
            local db=state()
            who=artisanKey(who)
            local key=who..":"..id
            if not db.orders[key] then
                db.orders[key]={id=id,who=who,text=recipe.." → "..ui.short(target),recipe=recipe,target=artisanKey(target)}
                if artisanKey(target)==artisanKey(realmName("player")) then
                    print("|cffffd26aTisteltiGuild|r · "..ui.short(who).." te encarga "..recipe)
                    if UIErrorsFrame then UIErrorsFrame:AddMessage("Nuevo encargo: "..recipe,1,.8,.3) end
                end
                refresh()
            end
        end
        elseif p==recipePrefix then if receiveRecipe(msg,ch,who) then refresh() end else receive(...) end
    elseif not pending then
        pending=true C_Timer.After(.6,function() pending=false scan() refresh() end)
    end
end)














