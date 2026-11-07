local _, ui = ...
local white = "Interface\\Buttons\\WHITE8X8"
local function border(frame, size)
    frame:SetBackdrop({bgFile=white, edgeFile=white, edgeSize=size})
    frame:SetBackdropBorderColor(.86,.66,.29,1)
end
function ui.panel(frame)
    border(frame,2)
    frame:SetBackdropColor(.035,.095,.18,.98)
    local function ornament(file,width,height,anchor,x,y)
        local tex=frame:CreateTexture(nil,"ARTWORK")
        tex:SetTexture("Interface\\AddOns\\TisteltiGuild\\Media\\"..file)
        tex:SetSize(width,height)
        tex:SetPoint("CENTER",frame,anchor,x,y)
        return tex
    end
    local left=ornament("Wings",185,200,"TOPLEFT",-60,8)
    left:SetTexCoord(0,.49,0,1)
    local right=ornament("Wings",185,200,"TOPRIGHT",60,8)
    right:SetTexCoord(.51,1,0,1)
    local trim=frame:CreateTexture(nil,"BORDER")
    trim:SetColorTexture(.61,.43,.17,.85)
    trim:SetPoint("TOPLEFT",12,-5)
    trim:SetPoint("TOPRIGHT",-12,-5)
    trim:SetHeight(1)
    ornament("Assassin",74,74,"TOP",0,16)
end
function ui.button(parent)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    border(b,1)
    b:SetBackdropColor(.035,.065,.11,1)
    -- Usa el relieve original del cliente y retira el pigmento rojo antes de teñirlo.
    local function skin(file,r,g,blue)
        local t=b:CreateTexture(nil,"ARTWORK")
        t:SetTexture("Interface\\Buttons\\UI-Panel-Button-"..file)
        t:SetTexCoord(0,.625,0,.6875)
        t:SetPoint("TOPLEFT",1,-1)
        t:SetPoint("BOTTOMRIGHT",-1,1)
        t:SetDesaturated(true)
        t:SetVertexColor(r,g,blue)
        return t
    end
    b:SetNormalTexture(skin("Up",.47,.76,1))
    b:SetPushedTexture(skin("Down",.39,.65,.95))
    b:SetDisabledTexture(skin("Disabled",.53,.58,.66))
    b:SetHighlightTexture(skin("Highlight",.35,.67,1),"ADD")
    b:SetPushedTextOffset(1,-1)
    b:SetNormalFontObject(GameFontNormalSmall)
    b:SetHighlightFontObject(GameFontHighlightSmall)
    b:SetDisabledFontObject(GameFontDisableSmall)
    return b
end


function ui.short(name) return (name or ""):match("^[^-]+") or name end

