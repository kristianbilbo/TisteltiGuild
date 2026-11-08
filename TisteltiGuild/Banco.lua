local _,ui=...
local panel,selected
function ui.hideBank()
    if panel then panel:Hide() end
end
function ui.bank(parent,personal,guild,refresh)
    if not panel then
        panel=CreateFrame("Frame",nil,parent)
        panel:SetPoint("TOPLEFT",24,-110)
        panel:SetSize(890,420)
        panel.tabs,panel.cells={},{}
        panel.scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
        panel.scroll:SetPoint("TOPLEFT",195,0)
        panel.scroll:SetSize(665,385)
        panel.canvas=CreateFrame("Frame",nil,panel.scroll)
        panel.canvas:SetSize(665,1)
        panel.scroll:SetScrollChild(panel.canvas)
        panel.note=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        panel.note:SetPoint("BOTTOMLEFT",195,0)
        panel.note:SetWidth(665)
        panel.note:SetJustifyH("LEFT")
    end
    panel:Show()
    local pages={}
    local function collect(t,prefix)
        local ids={}
        for id in pairs(t or {}) do ids[#ids+1]=id end
        table.sort(ids)
        for _,id in ipairs(ids) do
            pages[#pages+1]={key=prefix..id,label=prefix.." · "..t[id].name,data=t[id]}
        end
    end
    collect(personal and personal.tabs,"Personal")
    collect(guild,"Hermandad")
    local chosen
    for _,p in ipairs(pages) do if p.key==selected then chosen=p end end
    chosen=chosen or pages[1]
    selected=chosen and chosen.key
    for i,p in ipairs(pages) do
        local b=panel.tabs[i]
        if not b then
            b=ui.button(panel)
            b:SetSize(180,28)
            b:SetPoint("TOPLEFT",0,-(i-1)*32)
            panel.tabs[i]=b
        end
        local key=p.key
        b:SetText(p.label)
        b:SetScript("OnClick",function() selected=key panel.scroll:SetVerticalScroll(0) refresh() end)
        b:SetBackdropBorderColor(p.key==selected and 1 or .4,.65,.25)
        b:Show()
    end
    for i=#pages+1,#panel.tabs do panel.tabs[i]:Hide() end
    local data=chosen and chosen.data
    local count=data and data.slots and data.size or 0
    for i=1,count do
        local b=panel.cells[i]
        if not b then
            b=CreateFrame("Button",nil,panel.canvas,"BackdropTemplate")
            b:SetSize(42,42)
            b:SetPoint("TOPLEFT",((i-1)%14)*46,-math.floor((i-1)/14)*46)
            b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
            b:SetBackdropColor(.025,.045,.08,1)
            b:SetBackdropBorderColor(.52,.43,.25,1)
            b.icon=b:CreateTexture(nil,"ARTWORK")
            b.icon:SetPoint("TOPLEFT",3,-3)
            b.icon:SetPoint("BOTTOMRIGHT",-3,3)
            b.count=b:CreateFontString(nil,"OVERLAY","NumberFontNormal")
            b.count:SetPoint("BOTTOMRIGHT",-3,3)
            b:SetScript("OnEnter",function(self)
                if not self.item then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.item.link or ("item:"..self.item.id))
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end)
            panel.cells[i]=b
        end
        local item=data.slots[i]
        b.item=item
        b.icon:SetTexture(item and (item.icon or C_Item.GetItemIconByID(item.id) or 134400))
        b.count:SetText(item and item.count>1 and item.count or "")
        if ui.materialBorder then ui.materialBorder(b,item and item.id) end
        b:Show()
    end
    for i=count+1,#panel.cells do panel.cells[i]:Hide() end
    panel.canvas:SetHeight(math.max(1,math.ceil(count/14)*46))
    panel.note:SetText(count>0 and ("Última lectura · "..date("%d/%m %H:%M",data.t).." · "..count.." casillas") or "Abre el banco para registrar la posición de los objetos y los huecos libres.")
end
