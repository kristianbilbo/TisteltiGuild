-- Posiciones efímeras de los personajes conectados de la hermandad.
local prefix = "TisteltiMap1"
local members, pins, classes = {}, {}, {}
local guild, last, sent, lastClassTime
local received,drawn=0,0
local registration,sendResult
-- Forever puede usar «Nombre Apellido-Reino» en las unidades y
-- «Nombre-Apellido» en el canal de hermandad (igual que en Gestion.lua).
local function characterKey(who)
    if not who then return end
    local realm = GetNormalizedRealmName()
    local name, suffix = who:match("^([^-]+)%-(.+)$")
    if not name then name, suffix = who, realm end
    if suffix == realm then
        local first, last = name:match("^(%S+)%s+([^%s-]+)$")
        if first then return first.."-"..last end
    end
    return name.."-"..suffix
end

local function unitKey(unit)
    local name, realm = UnitFullName(unit)
    if not name or (issecretvalue and (issecretvalue(name) or issecretvalue(realm))) then return end
    return characterKey(name.."-"..((realm and realm ~= "") and realm or GetNormalizedRealmName()))
end

local function nativeMarkers()
    local hidden = {}
    local function add(unit)
        local key = unitKey(unit)
        if key then hidden[key] = true end
    end
    add("player")
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do add("raid"..i) end
    else
        for i = 1, GetNumSubgroupMembers() do add("party"..i) end
    end
    return hidden
end

local function context()
    local current = GetGuildInfo("player")
    if current ~= guild then
        guild, last, sent = current, nil, nil
        wipe(members) wipe(classes)
        for _, pin in ipairs(pins) do pin:Hide() end
    end
    return guild
end

local function position(map, p)
    local api=OpenMapAPI
    if api and api.IsStitched() then
        local u,v=api.WorldFromMap(p.map,p.x,p.y)
        if u then return api.MapFromWorld(map,u,v) end
        return
    end
    if map == p.map then return p.x, p.y end
    if not C_Map.GetMapRectOnMap then return end
    local info = C_Map.GetMapInfo(p.map)
    while info and info.parentMapID and info.parentMapID > 0 do
        if info.parentMapID == map then
            local left,right,top,bottom = C_Map.GetMapRectOnMap(p.map,map)
            if bottom and left ~= right and top ~= bottom then
                return left+p.x*(right-left), top+p.y*(bottom-top)
            end
            return
        end
        info = C_Map.GetMapInfo(info.parentMapID)
    end
end

local function redraw()
    local frame = WorldMapFrame
    if not frame or not frame:IsShown() or not frame.GetCanvas then return end
    local canvas, map = frame:GetCanvas(), frame:GetMapID()
    if not canvas or not map then return end
    local count = 0
    local hidden = nativeMarkers()
    for name,p in pairs(members) do
        if GetTime()-p.time > 45 then
            members[name] = nil
        elseif not hidden[characterKey(name)] then
            local x,y = position(map,p)
            if x and y and ((OpenMapAPI and OpenMapAPI.IsStitched()) or (x>=0 and x<=1 and y>=0 and y<=1)) then
                count = count+1
                local pin = pins[count]
                if not pin then
                    pin = CreateFrame("Frame",nil,canvas)
                    pins[count] = pin
                    pin:SetSize(10,10)
                    pin:EnableMouse(true)
                    local icon = pin:CreateTexture(nil,"OVERLAY")
                    icon:SetAllPoints()
                    icon:SetTexture("Interface\\AddOns\\TisteltiGuild\\Media\\Circle")
                    pin.icon = icon
                    pin:SetScript("OnEnter",function(self)
                        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                        GameTooltip:SetText(self.member)
                        GameTooltip:Show()
                    end)
                    pin:SetScript("OnLeave",function() GameTooltip:Hide() end)
                end
                local color = RAID_CLASS_COLORS[classes[name] or ""]
                if color then pin.icon:SetVertexColor(color.r,color.g,color.b) else pin.icon:SetVertexColor(.7,.7,.7) end
                pin.member = name
                local art=OpenMapAPI and OpenMapAPI.ArtTopLevel and OpenMapAPI.ArtTopLevel() or 0
                pin:SetFrameLevel(math.max(canvas:GetFrameLevel()+30,art or 0)+5)
                local scale=frame.GetCanvasScale and frame:GetCanvasScale() or 1
                pin:SetScale(1/math.max(.01,scale))
                pin:ClearAllPoints()
                pin:SetPoint("CENTER",canvas,"TOPLEFT",x*canvas:GetWidth(),-y*canvas:GetHeight())
                pin:Show()
            end
        end
    end
    drawn=count
    for i=count+1,#pins do pins[i]:Hide() end
end

local function broadcast()
    if not context() or InCombatLockdown() then return end
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map,"player")
    local msg = "-"
    if pos then
        local x,y = pos:GetXY()
        if not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) and x and y and (x~=0 or y~=0) then
            msg = string.format("%d:%d:%d",map,math.floor(x*10000),math.floor(y*10000))
        end
    end
    if msg~=last or not sent or GetTime()-sent>=20 then
        if not sent or GetTime() - (lastClassTime or 0) >= 20 then
            local _, class = UnitClass("player")
            if class then C_ChatInfo.SendAddonMessage(prefix,"C:"..class,"GUILD") end
            lastClassTime = GetTime()
        end
        sendResult=C_ChatInfo.SendAddonMessage(prefix,msg,"GUILD")
        local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
        if sendResult==nil or sendResult==true or sendResult==success then last,sent = msg,GetTime() end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent",function(_,event,key,msg,channel,sender)
    if event=="PLAYER_LOGIN" then
        if C_ChatInfo and C_Map then
            registration=C_ChatInfo.RegisterAddonMessagePrefix(prefix)
            C_Timer.NewTicker(4,broadcast)
            C_Timer.NewTicker(1,function() context() redraw() end)
        end
    elseif event=="GROUP_ROSTER_UPDATE" then
        context()
        redraw()
    elseif key==prefix and channel=="GUILD" and context() then
        received=received+1
        sender = characterKey(sender)
        if not sender or sender==unitKey("player") then return end
        local class = msg:match("^C:([A-Z]+)$")
        if class and RAID_CLASS_COLORS[class] then classes[sender]=class return end
        if msg=="-" then members[sender]=nil return end
        local map,x,y = msg:match("^(%d+):(%d+):(%d+)$")
        map,x,y = tonumber(map),tonumber(x),tonumber(y)
        if map and map>0 and x<=10000 and y<=10000 and C_Map.GetMapInfo(map) then
            members[sender]={map=map,x=x/10000,y=y/10000,time=GetTime()}
        end
    end
end)



SLASH_TISTELTIMAP1="/tisteltimapa"
SlashCmdList.TISTELTIMAP=function()
    broadcast()
    redraw()
    local peers=0
    for who,p in pairs(members) do
        if GetTime()-p.time<=45 then
            peers=peers+1
            print("TisteltiGuild · "..who.." · mapa "..p.map.." · recibido hace "..math.floor(GetTime()-p.time).." s")
        end
    end
    print("TisteltiGuild mapa 0.9.1 · Hermandad: "..tostring(guild)..
        " · mensajes: "..received.." · posiciones recientes: "..peers.." · marcadores: "..drawn)
    print("Registro: "..tostring(registration).." · resultado de envío: "..tostring(sendResult)..
        " · última posición enviada: "..tostring(last).." · OpenMap: "..tostring(OpenMapAPI and OpenMapAPI.IsStitched() or false))
end
