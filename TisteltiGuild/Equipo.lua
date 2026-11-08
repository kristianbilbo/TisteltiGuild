local _,ui=...
local cards={}
local portraits={}
local portraitStorage=CreateFrame("Frame")
portraitStorage:Hide()
-- Las caras generadas no son archivos: conservar la textura, no GetTexture().
function ui.captureGearPortrait(db,who,token)
    if not who or not UnitExists(token) then return end
    local _,race=UnitRace(token)
    local sex=UnitSex(token)
    if issecretvalue and (issecretvalue(race) or issecretvalue(sex)) then return end
    if race and (sex==2 or sex==3) then
        db.gearFaces=db.gearFaces or {}
        db.gearFaces[who]={race=race,sex=sex}
    end
    if not SetPortraitTexture or (UnitIsVisible and not UnitIsVisible(token)) then return end
    local entry=portraits[who]
    if not entry then
        local texture=portraitStorage:CreateTexture(nil,"ARTWORK")
        local mask=portraitStorage:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        mask:SetAllPoints(texture)
        texture:AddMaskTexture(mask)
        entry={texture=texture,mask=mask}
        portraits[who]=entry
    end
    SetPortraitTexture(entry.texture,token)
end
local function paintPortrait(card,db,who)
    if card.face then card.face:Hide() card.face=nil end
    card.portrait:SetTexCoord(0,1,0,1)
    card.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    card.portrait:Show()
    local entry=portraits[who]
    if entry then
        entry.texture:SetParent(card.header)
        entry.mask:SetParent(card.header)
        entry.texture:ClearAllPoints()
        entry.texture:SetAllPoints(card.portrait)
        entry.texture:Show()
        card.portrait:Hide()
        card.face=entry.texture
    else
        local face=(db.gearFaces or {})[who]
        if face and C_Texture and C_Texture.GetAtlasInfo then
            local suffix=face.race:lower().."-"..(face.sex==3 and "female" or "male")
            for _,prefix in ipairs({"raceicon128-","raceicon-"}) do
                local atlas=prefix..suffix
                if C_Texture.GetAtlasInfo(atlas) then card.portrait:SetAtlas(atlas) break end
            end
        end
    end
end
local SLOT_NAMES={"Cabeza","Cuello","Hombros","Camisa","Pecho","Cintura","Piernas","Pies","Muñecas","Manos","Anillo","Anillo","Abalorio","Abalorio","Espalda","Mano principal","Mano secundaria","A distancia","Tabardo"}
local function panel(frame)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(.025,.045,.08,.96)
    frame:SetBackdropBorderColor(.66,.49,.22,1)
end
local function label(parent,font,x,y,width)
    local text=parent:CreateFontString(nil,"OVERLAY",font)
    text:SetPoint("TOPLEFT",x,y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    return text
end
local function createCard(parent)
    local card=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    panel(card)
    card.header=CreateFrame("Frame",nil,card,"BackdropTemplate")
    card.header:SetPoint("TOPLEFT",8,-8)
    card.header:SetPoint("TOPRIGHT",-8,-8)
    card.header:SetHeight(64)
    panel(card.header)
    card.portrait=card.header:CreateTexture(nil,"ARTWORK")
    card.portrait:SetSize(52,52)
    card.portrait:SetPoint("LEFT",6,0)
    local mask=card.header:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(card.portrait)
    card.portrait:AddMaskTexture(mask)
    card.ring=card.header:CreateTexture(nil,"BORDER")
    card.ring:SetTexture("Interface\\AddOns\\TisteltiGuild\\Media\\Circle")
    card.ring:SetVertexColor(.86,.66,.29)
    card.ring:SetSize(58,58)
    card.ring:SetPoint("CENTER",card.portrait,"CENTER")
    card.name=label(card.header,"GameFontNormal",66,-12,1)
    card.name:SetPoint("TOPRIGHT",-8,-12)
    card.name:SetWidth(0)
    card.name:SetJustifyH("CENTER")
    card.name:SetWordWrap(true)
    card.name:SetHeight(30)
    card.detail=label(card.header,"GameFontHighlightSmall",66,-44,1)
    card.detail:SetPoint("TOPRIGHT",-8,-44)
    card.detail:SetWidth(0)
    card.detail:SetJustifyH("CENTER")
    card.items={}
    return card
end
local function itemRow(card,index,width)
    local row=card.items[index]
    if not row then
        row=CreateFrame("Button",nil,card)
        row:SetHeight(36)
        row:SetPoint("TOPLEFT",10,-82-(index-1)*38)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetSize(30,30)
        row.icon:SetPoint("LEFT")
        row.slot=label(row,"GameFontNormalSmall",38,-1,1)
        row.name=label(row,"GameFontHighlightSmall",38,-16,1)
        row.name:SetWordWrap(false)
        row:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:"..self.itemID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("OnClick",function(self)
            local _,link=C_Item.GetItemInfo(self.itemID)
            if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
        end)
        card.items[index]=row
    end
    row:SetWidth(width-20)
    row.slot:SetWidth(width-64)
    row.name:SetWidth(width-64)
    return row
end
function ui.hideGear()
    for _,card in ipairs(cards) do
        if card.face then card.face:Hide() card.face=nil end
        card:Hide()
    end
end
function ui.gear(parent,db,key)
    ui.hideGear()
    local people={}
    local function unit(token)
        if not UnitExists(token) then return end
        local name,realm=UnitFullName(token)
        if not name or (issecretvalue and (issecretvalue(name) or issecretvalue(realm))) then return end
        local who=key(name.."-"..((realm and realm~="") and realm or GetNormalizedRealmName()))
        ui.captureGearPortrait(db,who,token)
    end
    unit("player")
    unit("target")
    unit("focus")
    local raid=IsInRaid()
    for i=1,(raid and GetNumGroupMembers() or GetNumSubgroupMembers()) do unit((raid and "raid" or "party")..i) end
    for who,gear in pairs(db.gear or {}) do people[#people+1]={who=who,gear=gear} end
    table.sort(people,function(a,b) return a.who<b.who end)
    local width=(parent:GetWidth()-16)/2
    local top=0
    for i,person in ipairs(people) do
        local card=cards[i]
        if not card then card=createCard(parent) cards[i]=card end
        local entries={}
        for slot,id in person.gear:gmatch("(%d+)=(%d+)") do entries[#entries+1]={slot=tonumber(slot),id=tonumber(id)} end
        table.sort(entries,function(a,b) return a.slot<b.slot end)
        card:SetWidth(width)
        card:SetHeight(92+math.max(1,#entries)*38)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT",((i-1)%2)*(width+16),-top)
        -- El guion separa el apellido en Forever; conservarlo en la placa.
        local first,last=person.who:match("^([^-]+)%-(.+)$")
        card.name:SetText(first and (last==GetNormalizedRealmName() and first or first.." "..last) or person.who)
        paintPortrait(card,db,key(person.who))
        card.detail:SetText(#entries.." piezas registradas")
        for j,entry in ipairs(entries) do
            local row=itemRow(card,j,width)
            row.itemID=entry.id
            row.icon:SetTexture(C_Item.GetItemIconByID(entry.id) or 134400)
            row.slot:SetText(SLOT_NAMES[entry.slot] or ("Casilla "..entry.slot))
            local name,link=C_Item.GetItemInfo(entry.id)
            row.name:SetText(link or name or ("Objeto #"..entry.id))
            row:Show()
        end
        for j=#entries+1,#card.items do card.items[j]:Hide() end
        card:Show()
        if i%2==0 or i==#people then
            local left=cards[i%2==0 and i-1 or i]
            top=top+math.max(left:GetHeight(),card:GetHeight())+16
        end
    end
    for i=#people+1,#cards do cards[i]:Hide() end
    parent:SetHeight(math.max(1,top))
    return #people>0
end
