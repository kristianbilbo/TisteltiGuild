local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not Minimap then return end
    local button = CreateFrame("Button", "TisteltiGuildMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    TisteltiJourneyDB = TisteltiJourneyDB or {history={}}
    local angle = tonumber(TisteltiJourneyDB.minimapAngle) or 225
    local dragging, suppressClick
    local function place()
        local radians = math.rad(angle)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(radians)*(Minimap:GetWidth()/2+4),
            math.sin(radians)*(Minimap:GetHeight()/2+4))
    end
    local function move()
        local x,y = GetCursorPosition()
        local cx,cy = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        if not cx or not cy or not scale or scale<=0 then return end
        local dx,dy = x/scale-cx,y/scale-cy
        if dx==0 and dy==0 then return end
        angle = math.deg(math.atan2(dy,dx)) % 360
        TisteltiJourneyDB.minimapAngle = angle
        place()
    end
    local function stop()
        dragging = false
        button:SetScript("OnUpdate",nil)
    end
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnMouseDown",function() suppressClick=false end)
    button:SetScript("OnDragStart",function()
        dragging,suppressClick = true,true
        GameTooltip:Hide()
        button:SetScript("OnUpdate",move)
        move()
    end)
    button:SetScript("OnDragStop",function() move() stop() end)
    button:SetScript("OnHide",stop)
    Minimap:HookScript("OnSizeChanged",place)
    place()
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\TisteltiGuild\\Media\\Assassin")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:SetScript("OnClick", function()
        if dragging or suppressClick then return end
        if GestionGuildPanel and GestionGuildPanel:IsShown() then
            GestionGuildPanel:Hide()
        else
            GestionGuildAbrir()
        end
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("TisteltiGuild")
        GameTooltip:AddLine("Clic para abrir o cerrar el panel de hermandad.", 1, 1, 1)
        GameTooltip:AddLine("Arrastra para mover el icono alrededor del minimapa.", .8, .8, .8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end)
