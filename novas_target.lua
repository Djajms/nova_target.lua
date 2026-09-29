-- language: Luau, file: nova_mobile.lua
-- NOVA Mobile — target aim + esp + trigger + sounds + sky
-- executor: Delta

-- ═══════════════════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local SoundService     = game:GetService("SoundService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local HAS_DRAWING = (typeof(Drawing) ~= "nil" and typeof(Drawing.new) == "function")

-- ═══════════════════════════════════════════════════════════════════════
-- PALETTE
-- ═══════════════════════════════════════════════════════════════════════
local C = {
    bg=Color3.fromRGB(255,244,248), bgDeep=Color3.fromRGB(250,226,234),
    bgSoft=Color3.fromRGB(255,236,242), glass=Color3.fromRGB(255,250,252),
    stroke=Color3.fromRGB(240,190,210), strokeDeep=Color3.fromRGB(220,140,172),
    accent=Color3.fromRGB(228,130,168), accentDeep=Color3.fromRGB(178,88,128),
    accentSoft=Color3.fromRGB(248,180,202), rose=Color3.fromRGB(232,112,152),
    peach=Color3.fromRGB(255,196,170), cream=Color3.fromRGB(255,240,224),
    lavender=Color3.fromRGB(214,180,220), text=Color3.fromRGB(82,52,66),
    textMuted=Color3.fromRGB(160,130,146), textLight=Color3.fromRGB(255,250,252),
    off=Color3.fromRGB(230,214,222), sun=Color3.fromRGB(255,232,190),
}

-- ═══════════════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════════════
local CFG = {
    ESP = {
        Enabled=true, Box=true, Name=true, Distance=true, Health=true,
        Snapline=false, HeadDot=false, MaxDist=1000,
        ColEnemy=C.rose, ColTeam=C.lavender,
        ColHead=C.rose, ColBody=C.peach, ColLegs=C.lavender,
        BoxHead=true, BoxBody=true, BoxLegs=true,
    },
    AIM = {
        Enabled=false,
        Wallbang=true, IgnoreTeam=true,
        FOV=35, MaxDist=1000, Bone="Head",
        ShowCircle=true, SnapSpeed=0.5,
    },
    TRIG = {
        Enabled=false, AutoFire=true, Wallbang=true,
        DelayMs=60, FOV=20, Bone="UpperTorso",
    },
    SND = {
        Hit={on=true, vol=1.0, ids={"rbxassetid://9114132802","rbxassetid://9120386436"}},
        Kill={on=true, vol=1.0, ids={"rbxassetid://9125402232"}},
        HS={on=true, vol=1.2, ids={"rbxassetid://5810753582"}},
    },
    SKY = {Current="default"},
}

-- ═══════════════════════════════════════════════════════════════════════
-- SKY
-- ═══════════════════════════════════════════════════════════════════════
local SKY = {
    default={ct=14,br=2,amb=0.5,fog=500,fc=Color3.fromRGB(200,180,210),oa=Color3.fromRGB(128,128,128)},
    dawn={ct=6,br=2.5,amb=0.75,fog=900,fc=Color3.fromRGB(255,186,148),oa=Color3.fromRGB(206,158,136)},
    sunset={ct=17.6,br=2.5,amb=0.8,fog=1200,fc=Color3.fromRGB(255,164,124),oa=Color3.fromRGB(240,152,116)},
    pink={ct=5.6,br=2.3,amb=0.85,fog=1500,fc=Color3.fromRGB(255,196,218),oa=Color3.fromRGB(250,196,214)},
    purple={ct=19,br=1.9,amb=0.65,fog=1000,fc=Color3.fromRGB(196,158,220),oa=Color3.fromRGB(168,132,196)},
    night={ct=0,br=0.8,amb=0.2,fog=350,fc=Color3.fromRGB(36,32,68),oa=Color3.fromRGB(56,50,88)},
}
local function applySky(n)
    local s=SKY[n]; if not s then return end
    Lighting.ClockTime=s.ct; Lighting.Brightness=s.br
    Lighting.Ambient=Color3.new(s.amb,s.amb,s.amb)
    Lighting.OutdoorAmbient=s.oa
    Lighting.FogEnd=s.fog; Lighting.FogColor=s.fc
    CFG.SKY.Current=n
end

-- ═══════════════════════════════════════════════════════════════════════
-- SOUNDS
-- ═══════════════════════════════════════════════════════════════════════
local function playSnd(ids,vol)
    if not ids or #ids==0 then return end
    local s=Instance.new("Sound")
    s.SoundId=ids[math.random(#ids)]; s.Volume=vol or 1
    s.Parent=SoundService; s:Play()
    game:GetService("Debris"):AddItem(s,3)
end

local lastHP,watched={},{}
local function hookHum(plr,hum)
    if not hum then return end
    lastHP[plr]=hum.Health
    hum.HealthChanged:Connect(function(n)
        local o=lastHP[plr] or n
        if o>n and o>0 and plr~=LP then
            local dmg=o-n
            if n<=0 then
                if CFG.SND.Kill.on then playSnd(CFG.SND.Kill.ids,CFG.SND.Kill.vol) end
            elseif CFG.SND.Hit.on then
                if dmg>80 and CFG.SND.HS.on then playSnd(CFG.SND.HS.ids,CFG.SND.HS.vol)
                else playSnd(CFG.SND.Hit.ids,CFG.SND.Hit.vol) end
            end
        end
        lastHP[plr]=n
    end)
end
local function attach(plr)
    if plr==LP or watched[plr] then return end
    watched[plr]=true
    if plr.Character then
        local h=plr.Character:FindFirstChildOfClass("Humanoid")
        if h then hookHum(plr,h) end
    end
    plr.CharacterAdded:Connect(function(ch)
        local h=ch:WaitForChild("Humanoid",5); if h then hookHum(plr,h) end
    end)
end
for _,p in ipairs(Players:GetPlayers()) do attach(p) end
Players.PlayerAdded:Connect(attach)
Players.PlayerRemoving:Connect(function(p) watched[p]=nil; lastHP[p]=nil end)

-- ═══════════════════════════════════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════════════════════════════════
local espO={}
local function w2s(p)
    local cam=Workspace.CurrentCamera; if not cam then return nil end
    local sp,on=cam:WorldToViewportPoint(p)
    if not on or sp.Z<=0 then return nil end
    return Vector2.new(sp.X,sp.Y)
end
local function createESP(plr)
    if not HAS_DRAWING then return end
    if plr==LP or espO[plr] then return end
    espO[plr]={
        box=Drawing.new("Square"), headBox=Drawing.new("Square"),
        bodyBox=Drawing.new("Square"), legsBox=Drawing.new("Square"),
        headDot=Drawing.new("Circle"), name=Drawing.new("Text"),
        dist=Drawing.new("Text"), snap=Drawing.new("Line"),
        hpBg=Drawing.new("Line"), hpFg=Drawing.new("Line"),
    }
    local o=espO[plr]
    for _,k in ipairs({"box","headBox","bodyBox","legsBox"}) do
        o[k].Filled=false; o[k].Thickness=1.5; o[k].Transparency=1; o[k].Visible=false
    end
    o.headDot.Filled=true; o.headDot.NumSides=20; o.headDot.Radius=3
    o.headDot.Transparency=0.2; o.headDot.Visible=false
    o.name.Size=13; o.name.Center=true; o.name.Outline=true; o.name.Visible=false
    o.dist.Size=12; o.dist.Center=true; o.dist.Outline=true; o.dist.Visible=false
    o.snap.Thickness=1; o.snap.Visible=false
    o.hpBg.Thickness=4; o.hpBg.Visible=false
    o.hpFg.Thickness=4; o.hpFg.Visible=false
end
local function removeESP(plr)
    if espO[plr] then
        for _,o in pairs(espO[plr]) do pcall(function() o:Remove() end) end
        espO[plr]=nil
    end
end
local function hideOne(o)
    o.box.Visible=false; o.headBox.Visible=false
    o.bodyBox.Visible=false; o.legsBox.Visible=false
    o.headDot.Visible=false; o.name.Visible=false
    o.dist.Visible=false; o.snap.Visible=false
    o.hpBg.Visible=false; o.hpFg.Visible=false
end
local function updateESP()
    if not HAS_DRAWING then return end
    if not CFG.ESP.Enabled then
        for _,o in pairs(espO) do hideOne(o) end
        return
    end
    local lpCh=LP.Character
    local lpHRP=lpCh and lpCh:FindFirstChild("HumanoidRootPart")
    if not lpHRP then return end
    local lTeam=LP.Team

    for plr,o in pairs(espO) do
        local ch=plr.Character
        local hum=ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then hideOne(o); continue end

        local hrp=ch:FindFirstChild("HumanoidRootPart")
        local head=ch:FindFirstChild("Head")
        local lower=ch:FindFirstChild("LowerTorso") or ch:FindFirstChild("Torso")
        if not hrp or not head then hideOne(o); continue end

        local d=(hrp.Position-lpHRP.Position).Magnitude
        if d>CFG.ESP.MaxDist then hideOne(o); continue end

        local hpH=w2s(head.Position+Vector3.new(0,0.8,0))
        local hR=w2s(head.Position-Vector3.new(0,0.4,0))
        local loR=w2s(lower and lower.Position or hrp.Position)
        local fR=w2s(hrp.Position-Vector3.new(0,3,0))
        if not hpH or not fR then hideOne(o); continue end

        local isEnemy=(not lTeam) or (plr.Team~=lTeam)
        local baseCol=isEnemy and CFG.ESP.ColEnemy or CFG.ESP.ColTeam

        if CFG.ESP.Box then
            local hh=math.abs(hpH.Y-fR.Y); local ww=hh/1.8
            o.box.Size=Vector2.new(ww,hh)
            o.box.Position=Vector2.new(hpH.X-ww/2,hpH.Y)
            o.box.Color=baseCol; o.box.Visible=true
        else o.box.Visible=false end

        if CFG.ESP.BoxHead and hpH and hR then
            local hh=math.abs(hpH.Y-hR.Y); local ww=hh*1.6
            o.headBox.Size=Vector2.new(ww,hh)
            o.headBox.Position=Vector2.new(hpH.X-ww/2,hpH.Y)
            o.headBox.Color=CFG.ESP.ColHead; o.headBox.Visible=true
        else o.headBox.Visible=false end

        if CFG.ESP.BoxBody and hR and loR then
            local hh=math.abs(hR.Y-loR.Y); local ww=hh*0.8
            o.bodyBox.Size=Vector2.new(ww,hh)
            o.bodyBox.Position=Vector2.new(hR.X-ww/2,hR.Y)
            o.bodyBox.Color=CFG.ESP.ColBody; o.bodyBox.Visible=true
        else o.bodyBox.Visible=false end

        if CFG.ESP.BoxLegs and loR and fR then
            local hh=math.abs(loR.Y-fR.Y); local ww=hh*0.9
            o.legsBox.Size=Vector2.new(ww,hh)
            o.legsBox.Position=Vector2.new(loR.X-ww/2,loR.Y)
            o.legsBox.Color=CFG.ESP.ColLegs; o.legsBox.Visible=true
        else o.legsBox.Visible=false end

        if CFG.ESP.HeadDot then
            o.headDot.Position=Vector2.new(hpH.X,hpH.Y)
            o.headDot.Radius=4
            o.headDot.Color=CFG.ESP.ColHead
            o.headDot.Visible=true
        else o.headDot.Visible=false end

        if CFG.ESP.Name then
            o.name.Text=plr.Name
            o.name.Position=Vector2.new(hpH.X,hpH.Y-18)
            o.name.Color=baseCol; o.name.Visible=true
        else o.name.Visible=false end

        if CFG.ESP.Distance then
            o.dist.Text=string.format("[%.0fm]",d)
            o.dist.Position=Vector2.new(hpH.X,fR.Y+2)
            o.dist.Color=baseCol; o.dist.Visible=true
        else o.dist.Visible=false end

        if CFG.ESP.Snapline then
            local vp=Workspace.CurrentCamera.ViewportSize
            o.snap.From=Vector2.new(vp.X/2,vp.Y)
            o.snap.To=Vector2.new(fR.X,fR.Y)
            o.snap.Color=baseCol; o.snap.Visible=true
        else o.snap.Visible=false end

        if CFG.ESP.Health and hum then
            local pct=hum.Health/hum.MaxHealth
            local hh=math.abs(hpH.Y-fR.Y); local ww=hh/1.8
            local bx=hpH.X-ww/2-6
            o.hpBg.From=Vector2.new(bx,hpH.Y)
            o.hpBg.To=Vector2.new(bx,fR.Y)
            o.hpBg.Color=Color3.new(0,0,0); o.hpBg.Visible=true
            local c2=pct>0.6 and C.peach or pct>0.3 and C.sun or C.rose
            o.hpFg.From=Vector2.new(bx,fR.Y-(fR.Y-hpH.Y)*pct)
            o.hpFg.To=Vector2.new(bx,fR.Y)
            o.hpFg.Color=c2; o.hpFg.Visible=true
        else o.hpBg.Visible=false; o.hpFg.Visible=false end
    end
end
for _,p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(0.3); createESP(p) end)
end)
Players.PlayerRemoving:Connect(removeESP)
RunService.RenderStepped:Connect(function() pcall(updateESP) end)

-- ═══════════════════════════════════════════════════════════════════════
-- TARGET AIM + FOV CIRCLE
-- ═══════════════════════════════════════════════════════════════════════
local currentTarget = nil
local aimWasScriptable = false

local fovCircle
if HAS_DRAWING then
    fovCircle = Drawing.new("Circle")
    fovCircle.Filled = false
    fovCircle.Thickness = 2
    fovCircle.NumSides = 80
    fovCircle.Color = C.accent
    fovCircle.Transparency = 0.55
    fovCircle.Visible = false
end

local function findTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local myCh = LP.Character
    if not myCh then return nil end
    local myHRP = myCh:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local fovPixels = (CFG.AIM.FOV / 100) * cam.ViewportSize.Y
    local best, bestD = nil, fovPixels

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local ch = plr.Character
        if not ch then continue end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if CFG.AIM.IgnoreTeam and LP.Team and plr.Team == LP.Team then continue end

        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        if (hrp.Position - myHRP.Position).Magnitude > CFG.AIM.MaxDist then continue end

        local tgt = ch:FindFirstChild(CFG.AIM.Bone) or hrp
        local pos = tgt.Position

        local sp, on = cam:WorldToViewportPoint(pos)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d > bestD then continue end

        if not CFG.AIM.Wallbang then
            local p = RaycastParams.new()
            p.FilterType = Enum.RaycastFilterType.Exclude
            p.FilterDescendantsInstances = {myCh, cam}
            local r = Workspace:Raycast(cam.CFrame.Position, pos - cam.CFrame.Position, p)
            if r and not r.Instance:IsDescendantOf(ch) then continue end
        end

        best, bestD = {ch=ch, pos=pos, plr=plr}, d
    end
    return best
end

-- AIM тик
RunService:BindToRenderStep("NOVA_AIM", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end

    if not CFG.AIM.Enabled then
        if aimWasScriptable then
            cam.CameraType = Enum.CameraType.Custom
            aimWasScriptable = false
        end
        currentTarget = nil
        return
    end

    currentTarget = findTarget()

    if not currentTarget then
        if aimWasScriptable then
            cam.CameraType = Enum.CameraType.Custom
            aimWasScriptable = false
        end
        return
    end

    if cam.CameraType ~= Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Scriptable
        aimWasScriptable = true
    end

    local from = cam.CFrame.Position
    local dir = (currentTarget.pos - from).Unit
    local tcf = CFrame.lookAt(from, from + dir)
    cam.CFrame = cam.CFrame:Lerp(tcf, math.clamp(CFG.AIM.SnapSpeed, 0.1, 1))
end)

-- поворот персонажа
RunService.Stepped:Connect(function()
    if not CFG.AIM.Enabled then return end
    if not currentTarget then return end

    local myCh = LP.Character
    if not myCh then return end
    local hrp = myCh:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local flat = Vector3.new(currentTarget.pos.X, hrp.Position.Y, currentTarget.pos.Z)
    hrp.CFrame = CFrame.lookAt(hrp.Position, flat)
end)

-- кружок
RunService.RenderStepped:Connect(function()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if fovCircle and CFG.AIM.Enabled and CFG.AIM.ShowCircle then
        local vp = cam.ViewportSize
        local radius = (CFG.AIM.FOV / 100) * vp.Y
        fovCircle.Position = Vector2.new(vp.X/2, vp.Y/2)
        fovCircle.Radius = radius
        if currentTarget then
            fovCircle.Color = C.rose
            fovCircle.Thickness = 3
            fovCircle.Transparency = 0.85
        else
            fovCircle.Color = C.accent
            fovCircle.Thickness = 2
            fovCircle.Transparency = 0.5
        end
        fovCircle.Visible = true
    elseif fovCircle then
        fovCircle.Visible = false
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- TRIGGER — стреляет при захвате
-- ═══════════════════════════════════════════════════════════════════════
local function trigFindTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local myCh = LP.Character
    if not myCh then return nil end
    local myHRP = myCh:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local fovPixels = (CFG.TRIG.FOV / 100) * cam.ViewportSize.Y
    local best, bestD = nil, fovPixels

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local ch = plr.Character
        if not ch then continue end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if CFG.AIM.IgnoreTeam and LP.Team and plr.Team == LP.Team then continue end

        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        if (hrp.Position - myHRP.Position).Magnitude > CFG.AIM.MaxDist then continue end

        local tgt = ch:FindFirstChild(CFG.TRIG.Bone) or hrp
        local pos = tgt.Position

        local sp, on = cam:WorldToViewportPoint(pos)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d > bestD then continue end

        if not CFG.TRIG.Wallbang then
            local p = RaycastParams.new()
            p.FilterType = Enum.RaycastFilterType.Exclude
            p.FilterDescendantsInstances = {myCh, cam}
            local r = Workspace:Raycast(cam.CFrame.Position, pos - cam.CFrame.Position, p)
            if r and not r.Instance:IsDescendantOf(ch) then continue end
        end

        best, bestD = true, d
    end
    return best
end

local lastFire = 0
RunService.Heartbeat:Connect(function()
    if not CFG.TRIG.Enabled then return end
    if not trigFindTarget() then return end
    local now = tick() * 1000
    if now - lastFire < CFG.TRIG.DelayMs then return end
    lastFire = now
    if CFG.TRIG.AutoFire then
        pcall(function()
            local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════
pcall(function()
    local old=CoreGui:FindFirstChild("NOVA_Sakura")
    if old then old:Destroy() end
end)

local gui=Instance.new("ScreenGui")
gui.Name="NOVA_Sakura"
gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset=true
pcall(function() gui.Parent=CoreGui end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end

local win=Instance.new("Frame")
win.Size=UDim2.new(0,340,0,520)
win.Position=UDim2.new(0,20,0,80)
win.BackgroundColor3=C.bg
win.BackgroundTransparency=0.05
win.BorderSizePixel=0
win.Active=true
win.Draggable=true
win.Parent=gui
local wc=Instance.new("UICorner"); wc.CornerRadius=UDim.new(0,14); wc.Parent=win
local ws=Instance.new("UIStroke"); ws.Color=C.stroke; ws.Thickness=1.5; ws.Transparency=0.2; ws.Parent=win
local wg=Instance.new("UIGradient")
wg.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,C.bg),
    ColorSequenceKeypoint.new(0.5,C.bgSoft),
    ColorSequenceKeypoint.new(1,C.bgDeep)})
wg.Rotation=135; wg.Parent=win

local header=Instance.new("Frame")
header.Size=UDim2.new(1,0,0,48)
header.BackgroundColor3=C.accent
header.BackgroundTransparency=0.15
header.BorderSizePixel=0
header.Parent=win
local hc=Instance.new("UICorner"); hc.CornerRadius=UDim.new(0,14); hc.Parent=header
local hFix=Instance.new("Frame")
hFix.Size=UDim2.new(1,0,0,14); hFix.Position=UDim2.new(0,0,1,-14)
hFix.BackgroundColor3=C.accent; hFix.BackgroundTransparency=0.15
hFix.BorderSizePixel=0; hFix.Parent=header
local hg=Instance.new("UIGradient")
hg.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,C.accentSoft),
    ColorSequenceKeypoint.new(1,C.accentDeep)})
hg.Parent=header

local title=Instance.new("TextLabel")
title.Text="❀  NOVA Mobile"
title.Size=UDim2.new(1,-50,0,24)
title.Position=UDim2.new(0,16,0,8)
title.BackgroundTransparency=1
title.Font=Enum.Font.GothamBold
title.TextSize=18
title.TextColor3=C.textLight
title.TextXAlignment=Enum.TextXAlignment.Left
title.Parent=header

local subtitle=Instance.new("TextLabel")
subtitle.Text="target edition  ·  by eumov"
subtitle.Size=UDim2.new(1,-50,0,14)
subtitle.Position=UDim2.new(0,16,0,28)
subtitle.BackgroundTransparency=1
subtitle.Font=Enum.Font.Gotham
subtitle.TextSize=11
subtitle.TextColor3=C.textLight
subtitle.TextTransparency=0.15
subtitle.TextXAlignment=Enum.TextXAlignment.Left
subtitle.Parent=header

local closeBtn=Instance.new("TextButton")
closeBtn.Text="✕"
closeBtn.Size=UDim2.new(0,30,0,26)
closeBtn.Position=UDim2.new(1,-40,0,11)
closeBtn.BackgroundColor3=C.accentDeep
closeBtn.BackgroundTransparency=0.4
closeBtn.BorderSizePixel=0
closeBtn.Font=Enum.Font.GothamBold
closeBtn.TextSize=14
closeBtn.TextColor3=C.textLight
closeBtn.Parent=header
local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=closeBtn

local tabNames={"ESP","Aim","Trig","Sound","Sky","Misc"}
local tabHolder=Instance.new("ScrollingFrame")
tabHolder.Size=UDim2.new(1,-16,0,38)
tabHolder.Position=UDim2.new(0,8,0,54)
tabHolder.BackgroundColor3=C.bgDeep
tabHolder.BackgroundTransparency=0.4
tabHolder.BorderSizePixel=0
tabHolder.ScrollBarThickness=0
tabHolder.ScrollingDirection=Enum.ScrollingDirection.X
tabHolder.CanvasSize=UDim2.new(0,6*72,0,0)
tabHolder.Parent=win
local thc=Instance.new("UICorner"); thc.CornerRadius=UDim.new(0,8); thc.Parent=tabHolder

local tabLayout=Instance.new("UIListLayout")
tabLayout.FillDirection=Enum.FillDirection.Horizontal
tabLayout.Padding=UDim.new(0,2)
tabLayout.VerticalAlignment=Enum.VerticalAlignment.Center
tabLayout.Parent=tabHolder
local tabPad=Instance.new("UIPadding")
tabPad.PaddingLeft=UDim.new(0,4); tabPad.PaddingRight=UDim.new(0,4)
tabPad.Parent=tabHolder

local tabButtons={}
local currentTab=1

local content=Instance.new("ScrollingFrame")
content.Size=UDim2.new(1,-16,1,-110)
content.Position=UDim2.new(0,8,0,94)
content.BackgroundColor3=C.glass
content.BackgroundTransparency=0.7
content.BorderSizePixel=0
content.ScrollBarThickness=4
content.ScrollBarImageColor3=C.accent
content.CanvasSize=UDim2.new(0,0,0,0)
content.AutomaticCanvasSize=Enum.AutomaticSize.Y
content.Parent=win
local cnc=Instance.new("UICorner"); cnc.CornerRadius=UDim.new(0,8); cnc.Parent=content
local cp=Instance.new("UIPadding")
cp.PaddingTop=UDim.new(0,6); cp.PaddingBottom=UDim.new(0,6)
cp.PaddingLeft=UDim.new(0,6); cp.PaddingRight=UDim.new(0,6)
cp.Parent=content
local cl=Instance.new("UIListLayout")
cl.Padding=UDim.new(0,4); cl.SortOrder=Enum.SortOrder.LayoutOrder
cl.Parent=content

for i,name in ipairs(tabNames) do
    local tb=Instance.new("TextButton")
    tb.Text=name
    tb.Size=UDim2.new(0,66,0,30)
    tb.BackgroundColor3=C.bgSoft
    tb.BackgroundTransparency=0.5
    tb.BorderSizePixel=0
    tb.Font=Enum.Font.GothamSemibold
    tb.TextSize=13
    tb.TextColor3=C.text
    tb.Parent=tabHolder
    local tbc=Instance.new("UICorner"); tbc.CornerRadius=UDim.new(0,6); tbc.Parent=tb

    tb.MouseButton1Click:Connect(function()
        currentTab=i
        for j,b in ipairs(tabButtons) do
            if j==i then
                b.BackgroundColor3=C.accent
                b.BackgroundTransparency=0.15
                b.TextColor3=C.textLight
            else
                b.BackgroundColor3=C.bgSoft
                b.BackgroundTransparency=0.5
                b.TextColor3=C.text
            end
        end
        for _,ch in ipairs(content:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end
        if buildTab then buildTab(i) end
    end)
    table.insert(tabButtons,tb)
end

local function mkRow(parent,label,h)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,-12,0,h or 32)
    row.BackgroundColor3=C.bgSoft
    row.BackgroundTransparency=0.55
    row.BorderSizePixel=0
    row.Parent=parent
    local rc=Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,6); rc.Parent=row
    local lbl=Instance.new("TextLabel")
    lbl.Text=label or ""
    lbl.Size=UDim2.new(1,-80,1,0)
    lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1
    lbl.Font=Enum.Font.Gotham
    lbl.TextSize=13
    lbl.TextColor3=C.text
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Parent=row
    return row,lbl
end

local function mkToggle(parent,label,getter,setter)
    local row=mkRow(parent,label,32)
    local tgl=Instance.new("TextButton")
    tgl.Text=""
    tgl.Size=UDim2.new(0,42,0,22)
    tgl.Position=UDim2.new(1,-52,0.5,-11)
    tgl.BorderSizePixel=0
    tgl.Parent=row
    local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(1,0); tc.Parent=tgl
    local knob=Instance.new("Frame")
    knob.Size=UDim2.new(0,18,0,18)
    knob.Position=UDim2.new(0,2,0.5,-9)
    knob.BackgroundColor3=C.textLight
    knob.BorderSizePixel=0
    knob.Parent=tgl
    local kc=Instance.new("UICorner"); kc.CornerRadius=UDim.new(1,0); kc.Parent=knob
    local function refresh()
        local v=getter()
        tgl.BackgroundColor3=v and C.accent or C.off
        TweenService:Create(knob,TweenInfo.new(0.15),{
            Position=v and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9),
            BackgroundColor3=v and C.textLight or C.textMuted,
        }):Play()
    end
    refresh()
    tgl.MouseButton1Click:Connect(function() setter(not getter()); refresh() end)
    return row
end

local function mkButton(parent,label,action)
    local row=mkRow(parent,label,32)
    local btn=Instance.new("TextButton")
    btn.Text="▶"
    btn.Size=UDim2.new(0,34,0,22)
    btn.Position=UDim2.new(1,-44,0.5,-11)
    btn.BackgroundColor3=C.accentSoft
    btn.BackgroundTransparency=0.3
    btn.BorderSizePixel=0
    btn.Font=Enum.Font.GothamBold
    btn.TextSize=12
    btn.TextColor3=C.text
    btn.Parent=row
    local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,5); bc.Parent=btn
    btn.MouseButton1Click:Connect(function()
        pcall(action)
        btn.BackgroundColor3=C.accent
        task.wait(0.12)
        btn.BackgroundColor3=C.accentSoft
    end)
    return row
end

local function mkSlider(parent,label,min,max,getter,setter,isInt)
    local row=mkRow(parent,label,44)

    local valLbl=Instance.new("TextLabel")
    valLbl.Text=isInt and tostring(math.floor(getter())) or string.format("%.2f",getter())
    valLbl.Size=UDim2.new(0,60,0,16)
    valLbl.Position=UDim2.new(1,-70,0,4)
    valLbl.BackgroundTransparency=1
    valLbl.Font=Enum.Font.GothamBold
    valLbl.TextSize=12
    valLbl.TextColor3=C.accentDeep
    valLbl.TextXAlignment=Enum.TextXAlignment.Right
    valLbl.Parent=row

    local bar=Instance.new("Frame")
    bar.Size=UDim2.new(1,-20,0,14)
    bar.Position=UDim2.new(0,10,1,-22)
    bar.BackgroundColor3=C.off
    bar.BorderSizePixel=0
    bar.Parent=row
    local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(1,0); bc.Parent=bar

    local fill=Instance.new("Frame")
    local p0=(getter()-min)/(max-min)
    fill.Size=UDim2.new(p0,0,1,0)
    fill.BackgroundColor3=C.accent
    fill.BorderSizePixel=0
    fill.Parent=bar
    local fc=Instance.new("UICorner"); fc.CornerRadius=UDim.new(1,0); fc.Parent=fill

    local dragging=false
    local function applyFromX(x)
        local abs=bar.AbsolutePosition.X
        local sz=bar.AbsoluteSize.X
        if sz<=0 then return end
        local t=math.clamp((x-abs)/sz,0,1)
        local v=min+(max-min)*t
        if isInt then v=math.floor(v) end
        fill.Size=UDim2.new(t,0,1,0)
        valLbl.Text=isInt and tostring(v) or string.format("%.2f",v)
        setter(v)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch
           or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true
            applyFromX(input.Position.X)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch
           or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.Touch
                         or input.UserInputType==Enum.UserInputType.MouseMovement) then
            applyFromX(input.Position.X)
        end
    end)
    return row
end

local BONES={"Head","UpperTorso","LowerTorso","HumanoidRootPart"}
local function mkBonePicker(parent,label,getter,setter)
    local row=mkRow(parent,label,56)
    local holder=Instance.new("Frame")
    holder.Size=UDim2.new(1,-20,0,26)
    holder.Position=UDim2.new(0,10,1,-30)
    holder.BackgroundTransparency=1
    holder.Parent=row
    local hl=Instance.new("UIListLayout")
    hl.FillDirection=Enum.FillDirection.Horizontal
    hl.Padding=UDim.new(0,4)
    hl.Parent=holder

    local btns={}
    local function refresh()
        local cur=getter()
        for _,b in ipairs(btns) do
            if b.Name==cur then
                b.BackgroundColor3=C.accent
                b.TextColor3=C.textLight
            else
                b.BackgroundColor3=C.bgSoft
                b.TextColor3=C.text
            end
        end
    end

    for _,bn in ipairs(BONES) do
        local b=Instance.new("TextButton")
        b.Name=bn
        b.Text=bn:sub(1,3)
        b.Size=UDim2.new(0,50,0,24)
        b.BackgroundColor3=C.bgSoft
        b.BorderSizePixel=0
        b.Font=Enum.Font.GothamSemibold
        b.TextSize=11
        b.TextColor3=C.text
        b.Parent=holder
        local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=b
        b.MouseButton1Click:Connect(function() setter(bn); refresh() end)
        table.insert(btns,b)
    end
    refresh()
    return row
end

function buildTab(idx)
    local order=0
    local function add(fr) fr.LayoutOrder=order; order=order+1 end
    local name=tabNames[idx]

    if name=="ESP" then
        add(mkToggle(content,"Enable ESP",function() return CFG.ESP.Enabled end,function(v) CFG.ESP.Enabled=v end))
        add(mkToggle(content,"Общий бокс",function() return CFG.ESP.Box end,function(v) CFG.ESP.Box=v end))
        add(mkToggle(content,"Бокс головы",function() return CFG.ESP.BoxHead end,function(v) CFG.ESP.BoxHead=v end))
        add(mkToggle(content,"Бокс тела",function() return CFG.ESP.BoxBody end,function(v) CFG.ESP.BoxBody=v end))
        add(mkToggle(content,"Бокс ног",function() return CFG.ESP.BoxLegs end,function(v) CFG.ESP.BoxLegs=v end))
        add(mkToggle(content,"Точка на голове",function() return CFG.ESP.HeadDot end,function(v) CFG.ESP.HeadDot=v end))
        add(mkToggle(content,"Имя",function() return CFG.ESP.Name end,function(v) CFG.ESP.Name=v end))
        add(mkToggle(content,"Дистанция",function() return CFG.ESP.Distance end,function(v) CFG.ESP.Distance=v end))
        add(mkToggle(content,"Полоса HP",function() return CFG.ESP.Health end,function(v) CFG.ESP.Health=v end))
        add(mkToggle(content,"Линия к цели",function() return CFG.ESP.Snapline end,function(v) CFG.ESP.Snapline=v end))
        add(mkSlider(content,"Max dist",100,3000,function() return CFG.ESP.MaxDist end,function(v) CFG.ESP.MaxDist=v end,true))
    elseif name=="Aim" then
        add(mkToggle(content,"Enable aim",function() return CFG.AIM.Enabled end,function(v) CFG.AIM.Enabled=v end))
        add(mkToggle(content,"Wallbang (сквозь стены)",function() return CFG.AIM.Wallbang end,function(v) CFG.AIM.Wallbang=v end))
        add(mkToggle(content,"Ignore team",function() return CFG.AIM.IgnoreTeam end,function(v) CFG.AIM.IgnoreTeam=v end))
        add(mkToggle(content,"FOV кружок",function() return CFG.AIM.ShowCircle end,function(v) CFG.AIM.ShowCircle=v end))
        add(mkBonePicker(content,"Куда целиться",function() return CFG.AIM.Bone end,function(v) CFG.AIM.Bone=v end))
        add(mkSlider(content,"Радиус %",5,100,function() return CFG.AIM.FOV end,function(v) CFG.AIM.FOV=v end,true))
        add(mkSlider(content,"Скорость наводки",0.1,1,function() return CFG.AIM.SnapSpeed end,function(v) CFG.AIM.SnapSpeed=v end))
        add(mkSlider(content,"Дистанция",100,3000,function() return CFG.AIM.MaxDist end,function(v) CFG.AIM.MaxDist=v end,true))
    elseif name=="Trig" then
        add(mkToggle(content,"Enable trigger",function() return CFG.TRIG.Enabled end,function(v) CFG.TRIG.Enabled=v end))
        add(mkToggle(content,"Auto fire",function() return CFG.TRIG.AutoFire end,function(v) CFG.TRIG.AutoFire=v end))
        add(mkToggle(content,"Сквозь стены",function() return CFG.TRIG.Wallbang end,function(v) CFG.TRIG.Wallbang=v end))
        add(mkBonePicker(content,"Кость",function() return CFG.TRIG.Bone end,function(v) CFG.TRIG.Bone=v end))
        add(mkSlider(content,"Радиус %",5,80,function() return CFG.TRIG.FOV end,function(v) CFG.TRIG.FOV=v end,true))
        add(mkSlider(content,"Задержка ms",0,500,function() return CFG.TRIG.DelayMs end,function(v) CFG.TRIG.DelayMs=v end,true))
    elseif name=="Sound" then
        add(mkToggle(content,"Hit sounds",function() return CFG.SND.Hit.on end,function(v) CFG.SND.Hit.on=v end))
        add(mkToggle(content,"Kill sounds",function() return CFG.SND.Kill.on end,function(v) CFG.SND.Kill.on=v end))
        add(mkToggle(content,"Headshot snd",function() return CFG.SND.HS.on end,function(v) CFG.SND.HS.on=v end))
        add(mkButton(content,"Test hit",function() playSnd(CFG.SND.Hit.ids,CFG.SND.Hit.vol) end))
        add(mkButton(content,"Test kill",function() playSnd(CFG.SND.Kill.ids,CFG.SND.Kill.vol) end))
    elseif name=="Sky" then
        for _,pr in ipairs({"default","dawn","sunset","pink","purple","night"}) do
            add(mkButton(content,"Sky: "..pr,function() applySky(pr) end))
        end
    elseif name=="Misc" then
        add(mkSlider(content,"WalkSpeed",16,200,function()
            local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            return h and h.WalkSpeed or 16
        end,function(v)
            local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed=v end
        end,true))
        add(mkSlider(content,"JumpPower",50,300,function()
            local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            return h and h.JumpPower or 50
        end,function(v)
            local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then h.JumpPower=v end
        end,true))
    end
end

tabButtons[1].BackgroundColor3=C.accent
tabButtons[1].BackgroundTransparency=0.15
tabButtons[1].TextColor3=C.textLight
buildTab(1)

closeBtn.MouseButton1Click:Connect(function() gui.Enabled=false end)
UserInputService.InputBegan:Connect(function(input,gp)
    if input.KeyCode==Enum.KeyCode.RightShift then gui.Enabled=not gui.Enabled end
end)

print("[NOVA] Mobile target aim loaded. RightShift — toggle.")
