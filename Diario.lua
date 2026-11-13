local _, ui = ...
local frame = CreateFrame("Frame")
local db, panel, page
local function finish(t)
    local run = db.active
    if not run then return end
    run.stop = math.max(t, run.start)
    table.insert(db.history, 1, run)
    if #db.history > 250 then table.remove(db.history) end
    db.active = nil
end
local function sample()
    if not db then return end
    local inside, kind = IsInInstance()
    local now = time()
    if not inside or (kind ~= "party" and kind ~= "raid") then
        finish(db.active and db.active.last or now)
        if C_Map then
            local map = C_Map.GetBestMapForUnit("player")
            local pos = map and C_Map.GetPlayerMapPosition(map, "player")
            if pos then db.outside = {map=map,x=pos.x,y=pos.y,t=now} end
        end
        return
    end
    local name, _, difficulty, _, _, _, _, id = GetInstanceInfo()
    if not name or name == "" then return end
    local key = tostring(id or name)..":"..tostring(difficulty)
    if db.active and (db.active.key ~= key or now-db.active.last > 900) then finish(db.active.last) end
    if not db.active then
        local near = db.outside and now-db.outside.t <= 90 and db.outside or nil
        db.active = {key=key,name=name,start=now,last=now,people={},bosses={},near=near}
    end
    local run = db.active
    run.last = now
    local function member(unit)
        local n, realm = UnitName(unit)
        if n and not (issecretvalue and issecretvalue(n)) and not (issecretvalue and issecretvalue(realm)) then
            run.people[n..(realm and realm ~= "" and "-"..realm or "")] = true
        end
    end
    member("player")
    local raid = IsInRaid()
    for i=1,GetNumGroupMembers() do member((raid and "raid" or "party")..i) end
end
local function keys(t)
    local a = {}
    local seen={}
    for k in pairs(t or {}) do
        local label=ui.short(k)
        if not seen[label] then a[#a+1]=label seen[label]=true end
    end
    table.sort(a)
    return table.concat(a,", ")
end
local function selected()
    if db.active and page == 1 then return db.active end
    return db.history[page-(db.active and 1 or 0)]
end
local function render()
    if not panel or not panel:IsShown() then return end
    local count=#db.history+(db.active and 1 or 0)
    page=math.max(1,math.min(page or 1,count))
    local r=selected()
    if not r then panel.box:SetText("El diario empezará al entrar en una mazmorra o banda.") return end
    local visits,seconds=0,0
    for _,h in ipairs(db.history) do
        if h.key==r.key then visits=visits+1 seconds=seconds+h.stop-h.start end
    end
    panel.box:SetText(string.format("%s · %s\n%s · %d min\nGrupo: %s\nJefes registrados: %s\nVisitas cerradas: %d · Media: %.0f min\n%s",r.name,date("%d/%m/%Y",r.start),r.stop and "Salida cerrada" or "En curso",math.floor(((r.stop or r.last)-r.start)/60),keys(r.people),keys(r.bosses),visits,seconds/math.max(1,visits)/60,r.note or ""))
end
local function button(label,x,callback)
    local b=ui.button(panel)
    b:SetSize(95,24) b:SetPoint("BOTTOMLEFT",x,12) b:SetText(label) b:SetScript("OnClick",callback)
end
SLASH_DIARIOGUILD1="/diarioguild"
SlashCmdList.DIARIOGUILD=function(msg)
    if not db then return end
    if not panel then
        panel=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        panel:SetSize(475,245) panel:SetPoint("CENTER") panel:SetFrameStrata("DIALOG")
        ui.panel(panel)
        local box=CreateFrame("EditBox",nil,panel)
        box:SetMultiLine(true) box:SetAutoFocus(false) box:SetFontObject(GameFontHighlight)
        box:SetPoint("TOPLEFT",15,-16) box:SetPoint("BOTTOMRIGHT",-15,48)
        box:SetScript("OnEscapePressed",function(self) self:ClearFocus() panel:Hide() end)
        panel.box=box
        button("Reciente",12,function() page=page-1 render() end)
        button("Anterior",113,function() page=page+1 render() end)
        button("Mapa",214,function()
            local r=selected()
            if r and r.near and UiMapPoint and C_Map.SetUserWaypoint and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(r.near.map) then
                C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(r.near.map,r.near.x,r.near.y))
                print("Diario: marcado el último punto observado antes de entrar.")
            else print("Diario: sin posición exterior disponible.") end
        end)
        button("Cerrar",315,function() panel:Hide() end)
    end
    page=page or 1
    local note=msg:match("^nota%s+(.+)")
    if note and selected() then selected().note=note:sub(1,240) end
    panel:Show() render()
end
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
pcall(frame.RegisterEvent,frame,"ENCOUNTER_END")
frame:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if ... ~= "TisteltiGuild" then return end
        TisteltiJourneyDB=TisteltiJourneyDB or {history={}}
        db=TisteltiJourneyDB
        C_Timer.NewTicker(30,function() if not InCombatLockdown() then sample() end end)
    elseif event=="ENCOUNTER_END" then
        local _,name,_,_,success=...
        if db and db.active and not (issecretvalue and (issecretvalue(name) or issecretvalue(success))) and name and success==1 then db.active.bosses[name]=true end
    elseif db and not InCombatLockdown() then sample() end
end)


