-- BlairHub split chunk
local Lighting = game:GetService("Lighting")
local S = (...) or {}
local Players = S.Players
local RunService = S.RunService
local TweenService = S.TweenService
local UIS = S.UIS
local RS = S.RS
local lp = S.lp
local C = S.C
local EVIDENCE_INFO = S.EVIDENCE_INFO
local GHOST_DB = S.GHOST_DB
local Config = S.Config
local KEYBINDS = S.KEYBINDS
local evidenceRefs = S.evidenceRefs
local ghostCells = S.ghostCells
local AUTO_FARM = S.AUTO_FARM
local getMap = S.getMap
local getItems = S.getItems
local getZones = S.getZones
local getChar = S.getChar
local getBP = S.getBP
local getAllESPItemRoots = S.getAllESPItemRoots
local getRemote = S.getRemote
local findGhost = S.findGhost
local isHunting = S.isHunting
local tweenToPos = S.tweenToPos
local moveToPos = S.moveToPos
local getOutsidePos = S.getOutsidePos
local openVanDoor = S.openVanDoor
local goToGhostRoom = S.goToGhostRoom
local getTotalToolCount = S.getTotalToolCount
local hasInInventory = S.hasInInventory
local bringTool = S.bringTool
local setFarmStatus = S.setFarmStatus
local updateGhostFilter = S.updateGhostFilter
local getPossibleGhosts = S.getPossibleGhosts
local clearDetectionConns = S.clearDetectionConns
local conn = S.conn
local goToVan = S.goToVan
local runAutoFarm = S.runAutoFarm
local doAllQuests = S.doAllQuests

-- ESP
-- ============================================================================
local espCache={}
local IMPORTANT_ITEM_NAMES = {
    ["SLS Camera"] = true,
    ["EMF Reader"] = true,
    ["Spirit Box"] = true,
    ["Ghost Writing Book"] = true,
    ["Crucifix"] = true,
    ["Photo Camera"] = true,
    ["Salt"] = true,
    ["The Panda"] = true,
}
local CURSED_ITEM_NAMES = {
    ["Tarot Cards"] = true,
    ["PulledTarotCard"] = true,

    ["Music Box"] = true,
    ["MusicBox"] = true,

    ["Spirit Board"] = true,
    ["SpiritBoard"] = true,
    ["Ouija Board"] = true,
    ["OuijaBoard"] = true,

    ["Summoning Circle"] = true,
    ["SummoningCircle"] = true,

    ["Mirror"] = true,
    ["Haunted Mirror"] = true,
    ["HauntedMirror"] = true,

    ["Monkey Paw"] = true,
    ["MonkeyPaw"] = true,

    ["Voodoo Doll"] = true,
    ["VoodooDoll"] = true,
}

-- BooBooDoll riêng — màu tím
local BOOBOO_NAMES = {
    ["BooBooDoll"] = true,
    ["Boo-Boo Doll"] = true,
    ["BooBoo"] = true,
}

-- Tools quan trọng — màu xanh lá
local IMPORTANT_TOOL_NAMES = {
    ["SLS Camera"] = true,
    ["EMF Reader"] = true,
    ["Spirit Box"] = true,
    ["Ghost Writing Book"] = true,
    ["Thermometer"] = true,
    ["Crucifix"] = true,
    ["Photo Camera"] = true,
    ["Salt"] = true,
    ["UV Light"] = true,
}
local CURSED_KEYWORDS = {
    "tarot",
    "musicbox",
    "music box",
    "spiritboard",
    "spirit board",
    "ouija",
    "summoningcircle",
    "summoning circle",
    "hauntedmirror",
    "haunted mirror",
    "monkeypaw",
    "monkey paw",
    "voodoo",
    "cursed",
}
local function normalizeItemName(name)
    name = tostring(name or ""):lower()
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end
local function isBooBoo(item)
    if not item then return false end
    local n = normalizeItemName(item.Name)
    for name in pairs(BOOBOO_NAMES) do
        if n == normalizeItemName(name) then return true end
    end
    return false
end

local function isImportantTool(item)
    if not item then return false end
    local n = normalizeItemName(item.Name)
    for name in pairs(IMPORTANT_TOOL_NAMES) do
        if n == normalizeItemName(name) then return true end
    end
    return false
end

local function isImportantItem(item)
    return isImportantTool(item) or isBooBoo(item)
end

local function isCursedItem(item)
    if not item then
        return false
    end

    local n = normalizeItemName(item.Name)

    for itemName in pairs(CURSED_ITEM_NAMES) do
        if n == normalizeItemName(itemName) then
            return true
        end
    end

    for _,keyword in ipairs(CURSED_KEYWORDS) do
        if n:find(keyword, 1, true) then
            return true
        end
    end

    -- Chỉ check parent trực tiếp là CursedSpawns, không walk chain
    local directParent = item.Parent
    if directParent and normalizeItemName(directParent.Name) == "cursedspawns" then
        return true
    end

    return false
end
local function shouldESPItem(item)
    return isImportantItem(item) or isCursedItem(item)
end
local function getItemESPColor(item)
    if isBooBoo(item) then
        return C.FlyPurple  -- màu tím
    end
    if isCursedItem(item) then
        return C.Red        -- màu đỏ
    end
    if isImportantTool(item) then
        return C.ItemGreen  -- màu xanh lá
    end
    return C.ItemGreen
end

local function getItemESPLabel(item)
    if isBooBoo(item) then
        return "[BOO-BOO] " .. item.Name
    end
    if isCursedItem(item) then
        local n = tostring(item.Name or "")

        if n == "SpiritBoard" then n = "Spirit Board" end
        if n == "SummoningCircle" then n = "Summoning Circle" end
        if n == "MusicBox" then n = "Music Box" end
        if n == "HauntedMirror" then n = "Haunted Mirror" end
        if n == "MonkeyPaw" then n = "Monkey Paw" end
        if n == "VoodooDoll" then n = "Voodoo Doll" end
        if n == "" then n = "Cursed Object" end

        return "[CURSED] " .. n
    end
    return item.Name
end
local function addESP(model,color,label)
    if espCache[model] or not model or not model.Parent then return end
    local visuals={}
    pcall(function()
        local anchor=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Handle") or model:FindFirstChildWhichIsA("BasePart")
        if anchor then
            local sb=Instance.new("SelectionBox")
            sb.Color3=color; sb.LineThickness=0.05
            sb.SurfaceTransparency=0.85; sb.SurfaceColor3=color
            sb.Adornee=anchor; sb.Parent=lp:WaitForChild("PlayerGui")
            table.insert(visuals,sb)

            local bb=Instance.new("BillboardGui")
            bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,180,0,32)
            bb.StudsOffset=Vector3.new(0,3,0); bb.Adornee=anchor; bb.Parent=lp:WaitForChild("PlayerGui")
            local lbl=Instance.new("TextLabel",bb)
            lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
            lbl.Text=label; lbl.TextColor3=color; lbl.TextSize=13
            lbl.Font=Enum.Font.GothamBold; lbl.TextStrokeTransparency=0
            table.insert(visuals,bb)
        end
    end)
    espCache[model]=visuals
end
local function removeESP(model)
    if not espCache[model] then return end
    for _,v in ipairs(espCache[model]) do pcall(function() v:Destroy() end) end
    espCache[model]=nil
end
local function clearAllESP()
    for model in pairs(espCache) do removeESP(model) end
end

local ghostESP = { model=nil, highlight=nil, bb=nil, label=nil }
local function clearGhostESP()
    if ghostESP.highlight then pcall(function() ghostESP.highlight:Destroy() end) end
    if ghostESP.bb then pcall(function() ghostESP.bb:Destroy() end) end
    ghostESP.model=nil; ghostESP.highlight=nil; ghostESP.bb=nil; ghostESP.label=nil
end
local function updateGhostESP(ghost)
    if not Config.GhostESP or not ghost then
        if ghostESP.model then clearGhostESP() end
        return
    end
    if ghostESP.model ~= ghost or not ghostESP.highlight then
        clearGhostESP()
        ghostESP.model = ghost
        pcall(function()
            local hl = Instance.new("Highlight")
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.6
            hl.OutlineTransparency = 0
            hl.Adornee = ghost
            hl.Parent = lp:WaitForChild("PlayerGui")
            ghostESP.highlight = hl
            local anchor = ghost:FindFirstChild("HumanoidRootPart") or ghost:FindFirstChildWhichIsA("BasePart")
            if anchor then
                local bb = Instance.new("BillboardGui")
                bb.AlwaysOnTop = true; bb.Size = UDim2.new(0,200,0,30)
                bb.StudsOffset = Vector3.new(0,4,0); bb.Adornee = anchor
                bb.Parent = lp:WaitForChild("PlayerGui")
                local lbl = Instance.new("TextLabel", bb)
                lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
                lbl.TextSize = 14; lbl.Font = Enum.Font.GothamBold
                lbl.TextStrokeTransparency = 0
                ghostESP.bb = bb; ghostESP.label = lbl
            end
        end)
    end
    pcall(function()
        local hv = ghost:FindFirstChild("Hunting")
        local hunting = hv and hv.Value == true
        local col = hunting and C.GhostHunt or C.GhostNormal
        if ghostESP.highlight then
            ghostESP.highlight.FillColor = col
            ghostESP.highlight.OutlineColor = col
        end
        if ghostESP.label then
            local anchor = ghost:FindFirstChild("HumanoidRootPart") or ghost:FindFirstChildWhichIsA("BasePart")
            local dist = 0
            local cam = workspace.CurrentCamera
            if anchor and cam then dist = (cam.CFrame.Position - anchor.Position).Magnitude end
            ghostESP.label.Text = hunting
                and string.format("GHOST [%dm] - HUNTING", math.floor(dist))
                or  string.format("GHOST [%dm]", math.floor(dist))
            ghostESP.label.TextColor3 = col
        end
    end)
end

local function cleanESPCache()
    for model in pairs(espCache) do
        if not model or not model.Parent then
            removeESP(model)
        elseif model ~= findGhost() then
            if not shouldESPItem(model) and model.Parent ~= getItems() then
                removeESP(model)
            end
        end
    end
end

local origLight = {}
pcall(function()
    if Lighting then
        origLight = {
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
        }
    end
end)
local function applyFullBright()
    Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
    Lighting.Brightness=3; Lighting.ClockTime=14; Lighting.FogEnd=999999
    for _,e in ipairs(Lighting:GetChildren()) do
        if e:IsA("Atmosphere") or e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") then
            pcall(function() e.Enabled=false end)
        end
    end
end
local function restoreLight()
    for k,v in pairs(origLight) do pcall(function() Lighting[k]=v end) end
    for _,e in ipairs(Lighting:GetChildren()) do pcall(function() e.Enabled=true end) end
end


-- ============================================================================
-- [v8.3] Fly — BodyVelocity theo huong camera + HRP hook chong PlayerController keo ve
-- ============================================================================
local fly = { conn = nil, bv = nil, bg = nil, speed = 40 }
local _flyHookActive = false
local _hrpHooked = false
local disableGhostMode -- forward
local disableFly -- forward

local function hookHRP()
    if _hrpHooked then return end
    if not (getrawmetatable and setreadonly and newcclosure) then
        _hrpHooked = true
        return
    end
    local char = getChar()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        local mt = getrawmetatable(hrp)
        local old_ni = mt.__newindex
        setreadonly(mt, false)
        mt.__newindex = newcclosure(function(self, key, value)
            if (key == "CFrame" or key == "Position") and _flyHookActive then
                local src = debug.info(2, "s") or ""
                if src:find("PlayerController") or src:find("DoorCollisions") then
                    return
                end
            end
            if old_ni then
                return old_ni(self, key, value)
            else
                rawset(self, key, value)
            end
        end)
        setreadonly(mt, true)
        _hrpHooked = true
        print("[Hook] HRP __newindex hooked")
    end)
end

local function ensureHRPHook()
    local char = getChar()
    if not char then return end
    if not char:FindFirstChild("HumanoidRootPart") then return end
    hookHRP()
end
ensureHRPHook()
lp.CharacterAdded:Connect(function()
    _hrpHooked = false
    task.wait(0.5)
    ensureHRPHook()
end)

local function enableFly()
    if fly.conn then return end
    pcall(function()
        if Config.GhostMode then Config.GhostMode = false; pcall(disableGhostMode) end
        local char = getChar(); if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        ensureHRPHook()
        hum.PlatformStand = true
        hum.AutoRotate = false
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        _flyHookActive = true
        local oldBV = hrp:FindFirstChildOfClass("BodyVelocity")
        local oldBG = hrp:FindFirstChildOfClass("BodyGyro")
        if oldBV then oldBV:Destroy() end
        if oldBG then oldBG:Destroy() end
        local bv = Instance.new("BodyVelocity")
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.P = 5e3
        bv.Parent = hrp
        fly.bv = bv
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.P = 1e4
        bg.D = 100
        bg.CFrame = hrp.CFrame
        bg.Parent = hrp
        fly.bg = bg
        fly.conn = RunService.Heartbeat:Connect(function()
            if not Config.FlyMode or not _G.BlairHub then disableFly(); return end
            pcall(function()
                local charNow = getChar(); if not charNow then return end
                local hrpNow = charNow:FindFirstChild("HumanoidRootPart")
                local bvNow = hrpNow and hrpNow:FindFirstChildOfClass("BodyVelocity")
                local bgNow = hrpNow and hrpNow:FindFirstChildOfClass("BodyGyro")
                local cam = workspace.CurrentCamera
                if not hrpNow or not bvNow or not cam then return end
                local move = Vector3.zero
                local spd = fly.speed
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then spd = spd * 2 end
                local camCF = cam.CFrame
                if UIS:IsKeyDown(Enum.KeyCode.W) then move += camCF.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then move -= camCF.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then move -= camCF.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then move += camCF.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
                if move.Magnitude > 0 then bvNow.Velocity = move.Unit * spd else bvNow.Velocity = Vector3.zero end
                if bgNow then bgNow.CFrame = hrpNow.CFrame end
            end)
        end)
    end)
end

disableFly = function()
    pcall(function()
        _flyHookActive = false
        if fly.conn then fly.conn:Disconnect(); fly.conn=nil end
        if fly.bv then fly.bv:Destroy(); fly.bv=nil end
        if fly.bg then fly.bg:Destroy(); fly.bg=nil end
        local char = getChar()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChildOfClass("BodyVelocity"); if bv then bv:Destroy() end
            local bg = hrp:FindFirstChildOfClass("BodyGyro"); if bg then bg:Destroy() end
        end
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            task.wait(0.05)
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

task.spawn(function()
    local wasHunting=false
    while _G.BlairHub do
        if Config.AutoHide then pcall(function()
            local hunting=isHunting()
            if hunting and not wasHunting then
                local Map=getMap()
                local hrp=getChar() and getChar():FindFirstChild("HumanoidRootPart")
                if Map and hrp then
                    local best,bestDist=nil,math.huge
                    local ClosetDoors=Map:FindFirstChild("ClosetDoors")
                    if ClosetDoors then
                        for _,closet in ipairs(ClosetDoors:GetChildren()) do
                            local main=closet:FindFirstChild("Main")
                            if main and main:IsA("BasePart") then
                                local d=(hrp.Position-main.Position).Magnitude
                                if d<bestDist then bestDist=d; best=main end
                            end
                        end
                    end
                    -- Tween ra ngoài nhà thay vì vào tủ
                    local outsidePos=getOutsidePos()
                    moveToPos(outsidePos,"outside-hide")
                end
            end
            wasHunting=hunting
        end) end
        task.wait(0.3)
    end
end)

-- ============================================================================
-- UI
-- ============================================================================
local sg=Instance.new("ScreenGui")
sg.Name="BlairHubUI"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent=lp:WaitForChild("PlayerGui")

local HuntBanner=Instance.new("Frame",sg)
HuntBanner.Size=UDim2.new(1,0,0,52); HuntBanner.BackgroundColor3=C.Red
HuntBanner.BorderSizePixel=0; HuntBanner.Visible=false; HuntBanner.ZIndex=100
_G.BlairHuntAlert=HuntBanner
local HuntL=Instance.new("TextLabel",HuntBanner)
HuntL.Size=UDim2.new(1,0,0,32); HuntL.BackgroundTransparency=1
HuntL.Text="!!  GHOST HUNTING  —  FLEE OUTSIDE  !!"
HuntL.TextColor3=Color3.new(1,1,1); HuntL.TextSize=20
HuntL.Font=Enum.Font.GothamBold; HuntL.ZIndex=101
local HuntCountdown=Instance.new("TextLabel",HuntBanner)
HuntCountdown.Name="HuntCountdown"
HuntCountdown.Size=UDim2.new(1,0,0,20)
HuntCountdown.Position=UDim2.new(0,0,1,-20)
HuntCountdown.BackgroundTransparency=1
HuntCountdown.Text="HUNTING"
HuntCountdown.TextColor3=Color3.new(1,1,1)
HuntCountdown.TextSize=13
HuntCountdown.Font=Enum.Font.Gotham
HuntCountdown.ZIndex=101

task.spawn(function()
    while _G.BlairHub do
        if HuntBanner.Visible then
            TweenService:Create(HuntBanner,TweenInfo.new(0.22),{BackgroundColor3=C.HuntRed}):Play()
            task.wait(0.22)
            TweenService:Create(HuntBanner,TweenInfo.new(0.22),{BackgroundColor3=C.HuntDark}):Play()
            task.wait(0.22)
        else task.wait(0.5) end
    end
end)

local WIN_W=318
local vpY=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 760
local WIN_H=math.min(700,vpY-40)
local Win=Instance.new("Frame",sg)
Win.Name="Main"; Win.Size=UDim2.new(0,WIN_W,0,WIN_H)
Win.Position=UDim2.new(1,-WIN_W-16,0.5,-WIN_H/2)
Win.BackgroundColor3=C.BG; Win.BorderSizePixel=0
Win.Active=true; Win.Draggable=true

-- Mobile: touch drag cho Win
local _mDrag=false; local _mOff=Vector2.new()
local UISvc=game:GetService("UserInputService")
if UISvc.TouchEnabled then
    TB.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.Touch then
            _mDrag=true
            local tp=inp.Position
            local wp=Win.AbsolutePosition
            _mOff=Vector2.new(tp.X-wp.X,tp.Y-wp.Y)
        end
    end)
    UISvc.InputChanged:Connect(function(inp)
        if _mDrag and inp.UserInputType==Enum.UserInputType.Touch then
            local tp=inp.Position
            local vp=workspace.CurrentCamera.ViewportSize
            local nx=math.clamp(tp.X-_mOff.X,0,vp.X-WIN_W)
            local ny=math.clamp(tp.Y-_mOff.Y,0,vp.Y-WIN_H)
            Win.Position=UDim2.new(0,nx,0,ny)
        end
    end)
    UISvc.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.Touch then _mDrag=false end
    end)

    -- Nút Hide UI cho mobile (thay RShift)
    local MobileHideBtn=Instance.new("TextButton",sg)
    MobileHideBtn.Size=UDim2.new(0,52,0,28)
    MobileHideBtn.Position=UDim2.new(0,8,0,8)
    MobileHideBtn.BackgroundColor3=Color3.fromRGB(40,40,80)
    MobileHideBtn.TextColor3=Color3.new(1,1,1)
    MobileHideBtn.Text="HIDE"
    MobileHideBtn.TextSize=11
    MobileHideBtn.Font=Enum.Font.GothamBold
    MobileHideBtn.BorderSizePixel=0
    MobileHideBtn.ZIndex=200
    Instance.new("UICorner",MobileHideBtn).CornerRadius=UDim.new(0,6)
    MobileHideBtn.MouseButton1Click:Connect(function()
        if toggleUIVisible then toggleUIVisible() end
        MobileHideBtn.Text=_uiVisible and "HIDE" or "SHOW"
    end)
end
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,12)
local winStroke=Instance.new("UIStroke",Win)
winStroke.Color=C.Stroke; winStroke.Thickness=1.5

local TB=Instance.new("Frame",Win)
TB.Size=UDim2.new(1,0,0,46); TB.BackgroundColor3=C.BG2; TB.BorderSizePixel=0
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,12)
local tbFix=Instance.new("Frame",TB)
tbFix.Size=UDim2.new(1,0,0,12); tbFix.Position=UDim2.new(0,0,1,-12)
tbFix.BackgroundColor3=C.BG2; tbFix.BorderSizePixel=0

local TitleL=Instance.new("TextLabel",TB)
TitleL.Size=UDim2.new(1,-54,0,22); TitleL.Position=UDim2.new(0,14,0,6)
TitleL.BackgroundTransparency=1; TitleL.Text="BLAIR HUB  v7.8"
TitleL.TextColor3=C.Purple; TitleL.TextSize=14
TitleL.Font=Enum.Font.GothamBold; TitleL.TextXAlignment=Enum.TextXAlignment.Left

local SubL=Instance.new("TextLabel",TB)
SubL.Size=UDim2.new(1,-54,0,14); SubL.Position=UDim2.new(0,14,0,28)
SubL.BackgroundTransparency=1
SubL.Text="ESP fix · quest tracker · team sanity"
SubL.TextColor3=C.HeaderText; SubL.TextSize=9
SubL.Font=Enum.Font.Gotham; SubL.TextXAlignment=Enum.TextXAlignment.Left

local function makeUnload()
    _G.BlairHub=false; Config.AutoFarm=false; S.sboxToken={}
    clearDetectionConns(); restoreLight(); clearAllESP(); pcall(clearGhostESP)
    pcall(disableFly)
    Config.GhostMode=false; Config.FlyMode=false; pcall(disableGhostMode)
    pcall(function()
        local hum=getChar() and getChar():FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=16 end
    end)
    sg:Destroy()
end

local CloseBtn=Instance.new("TextButton",TB)
CloseBtn.Size=UDim2.new(0,26,0,26); CloseBtn.Position=UDim2.new(1,-36,0.5,-13)
CloseBtn.BackgroundColor3=Color3.fromRGB(170,35,35); CloseBtn.Text="x"
CloseBtn.TextColor3=Color3.new(1,1,1); CloseBtn.TextSize=12
CloseBtn.Font=Enum.Font.GothamBold; CloseBtn.BorderSizePixel=0
Instance.new("UICorner",CloseBtn).CornerRadius=UDim.new(0,6)
CloseBtn.MouseButton1Click:Connect(makeUnload)

-- Auto save config mỗi 10s
task.spawn(function()
    while _G.BlairHub do
        task.wait(10)
        if S.saveConfig then pcall(S.saveConfig) end
    end
end)

local gcam = {
    speed = 20,
    renderConn = nil,
    inputConn = nil,
    yaw = 0,
    pitch = 0,
    pos = Vector3.zero,
    active = false,
    cam = nil,
    -- saved camera/player state
    savedType = nil,
    savedSubject = nil,
    savedFOV = nil,
    savedCamMode = nil,
    savedPlayerMin = nil,
    savedPlayerMax = nil,
    -- saved character state for safe restore
    savedHRPCF = nil,
    savedAutoRotate = nil,
    -- disabled game camera scripts
    disabledScripts = {},
}

-- Disable game camera LocalScripts so they don't fight us each frame
local CAM_SCRIPT_NAMES = {
    ["Camera(Keep)"]      = true,
    ["Old_Camera(Keep)"]  = true,
    ["CameraLookVector"]  = true,
    ["CameraTransparency"]= true,
}
local function disableGameCameraScripts()
    gcam.disabledScripts = {}
    local function scan(container)
        if not container then return end
        for _, d in ipairs(container:GetDescendants()) do
            if d:IsA("LocalScript") and CAM_SCRIPT_NAMES[d.Name] and not d.Disabled then
                d.Disabled = true
                table.insert(gcam.disabledScripts, d)
            end
        end
    end
    pcall(function() scan(getChar()) end)
    pcall(function() scan(lp:FindFirstChild("PlayerScripts")) end)
    pcall(function() scan(lp:FindFirstChild("PlayerGui")) end)
end
local function restoreGameCameraScripts()
    for _, d in ipairs(gcam.disabledScripts) do
        pcall(function() if d and d.Parent then d.Disabled = false end end)
    end
    gcam.disabledScripts = {}
end

local function enableGhostMode()
    pcall(function()
        if Config.FlyMode then Config.FlyMode = false; pcall(disableFly) end
        local char = getChar()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Luu trang thai goc de khoi phuc
        gcam.savedHRPCF      = hrp.CFrame
        gcam.savedAutoRotate = hum and hum.AutoRotate

        -- Hard-lock nhan vat tai cho (khong move theo cam)
        if hum then
            hum.PlatformStand = true
            hum.AutoRotate    = false
        end
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.LocalTransparencyModifier = 1 end
            end
        end

        -- Tat script camera cua game
        disableGameCameraScripts()

        -- Quan trong: thoat khoi LockFirstPerson neu game ep
        gcam.savedCamMode = lp.CameraMode
        pcall(function() lp.CameraMode = Enum.CameraMode.Classic end)
        gcam.savedPlayerMin = lp.CameraMinZoomDistance
        gcam.savedPlayerMax = lp.CameraMaxZoomDistance
        pcall(function()
            lp.CameraMinZoomDistance = 0.5
            lp.CameraMaxZoomDistance = 1024
        end)

        local cam = workspace.CurrentCamera
        if not cam then return end
        gcam.cam          = cam
        gcam.savedType    = cam.CameraType
        gcam.savedSubject = cam.CameraSubject
        gcam.savedFOV     = cam.FieldOfView

        local camCF = cam.CFrame
        gcam.pos = camCF.Position
        local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
        if lookFlat.Magnitude < 1e-4 then lookFlat = Vector3.new(0,0,-1) end
        gcam.yaw   = math.atan2(-lookFlat.X, -lookFlat.Z)
        gcam.pitch = math.asin(math.clamp(camCF.LookVector.Y, -1, 1))

        cam.CameraType    = Enum.CameraType.Scriptable
        cam.CameraSubject = nil
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        gcam.active = true

        -- Mouse look: chi update goc, RenderStepped lo set CFrame
        gcam.inputConn = UIS.InputChanged:Connect(function(input)
            if not gcam.active then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local sens = 0.003
                gcam.yaw   = gcam.yaw   - input.Delta.X * sens
                gcam.pitch = math.clamp(gcam.pitch - input.Delta.Y * sens, -math.pi/2 + 0.05, math.pi/2 - 0.05)
            end
        end)

        -- Dung RenderStepped (chay SAU moi BindToRenderStep, ke ca cua game)
        if gcam.renderConn then gcam.renderConn:Disconnect() end
        gcam.renderConn = RunService.RenderStepped:Connect(function(dt)
            if not gcam.active then return end
            local c = workspace.CurrentCamera
            if not c then return end

            -- bam vao camera moi neu game switch
            if gcam.cam ~= c then
                gcam.cam = c
                pcall(function()
                    gcam.savedType    = c.CameraType
                    gcam.savedSubject = c.CameraSubject
                    gcam.savedFOV     = c.FieldOfView
                end)
            end

            -- ep moi frame phong khi game keo lai
            if c.CameraType ~= Enum.CameraType.Scriptable then c.CameraType = Enum.CameraType.Scriptable end
            if c.CameraSubject ~= nil then c.CameraSubject = nil end
            if lp.CameraMode ~= Enum.CameraMode.Classic then
                pcall(function() lp.CameraMode = Enum.CameraMode.Classic end)
            end

            -- giu nhan vat dung im
            local charNow = getChar()
            local hrpNow  = charNow and charNow:FindFirstChild("HumanoidRootPart")
            if hrpNow and gcam.savedHRPCF then
                if not hrpNow.Anchored then hrpNow.Anchored = true end
                hrpNow.AssemblyLinearVelocity  = Vector3.zero
                hrpNow.AssemblyAngularVelocity = Vector3.zero
                local p = hrpNow.Position
                local op = gcam.savedHRPCF.Position
                if (p - op).Magnitude > 0.5 then
                    hrpNow.CFrame = gcam.savedHRPCF
                end
            end

            -- WASD
            local move = Vector3.zero
            local spd  = gcam.speed * dt * 60
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then spd = spd * 3 end
            local rotCF = CFrame.new(gcam.pos) * CFrame.Angles(0, gcam.yaw, 0) * CFrame.Angles(gcam.pitch, 0, 0)
            if UIS:IsKeyDown(Enum.KeyCode.W)           then move = move + rotCF.LookVector  end
            if UIS:IsKeyDown(Enum.KeyCode.S)           then move = move - rotCF.LookVector  end
            if UIS:IsKeyDown(Enum.KeyCode.A)           then move = move - rotCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D)           then move = move + rotCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space)       then move = move + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
            if move.Magnitude > 0 then
                gcam.pos = gcam.pos + move.Unit * (spd * dt)
            end
            c.CFrame = CFrame.new(gcam.pos) * CFrame.Angles(0, gcam.yaw, 0) * CFrame.Angles(gcam.pitch, 0, 0)
        end)

        setFarmStatus("Ghost Mode ON - WASD + mouse - G de TP den day", C.FlyPurple)
    end)
end

disableGhostMode = function()
    pcall(function()
        gcam.active = false
        if gcam.renderConn then gcam.renderConn:Disconnect(); gcam.renderConn = nil end
        if gcam.inputConn  then gcam.inputConn:Disconnect();  gcam.inputConn  = nil end
        UIS.MouseBehavior = Enum.MouseBehavior.Default

        local char = getChar()
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        -- TP an toan: chi TP toi vi tri cam neu raycast tim duoc san hop le
        local landed = false
        if hrp then
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = {char}
            rp.IgnoreWater = true
            local hit = workspace:Raycast(gcam.pos + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), rp)
            if hit then
                hrp.Anchored = false
                hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero
                landed = true
            else
                -- khong co san -> tra ve vi tri ban dau
                hrp.Anchored = false
                if gcam.savedHRPCF then
                    hrp.CFrame = gcam.savedHRPCF
                end
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end

        if hum then
            hum.PlatformStand = false
            if gcam.savedAutoRotate ~= nil then hum.AutoRotate = gcam.savedAutoRotate end
        end
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.LocalTransparencyModifier = 0 end
            end
        end

        -- Khoi phuc camera + player
        local c = workspace.CurrentCamera
        if c then
            c.CameraType    = gcam.savedType    or Enum.CameraType.Custom
            c.CameraSubject = gcam.savedSubject or hum
            if gcam.savedFOV then c.FieldOfView = gcam.savedFOV end
        end
        pcall(function()
            if gcam.savedCamMode  then lp.CameraMode           = gcam.savedCamMode  end
            if gcam.savedPlayerMin then lp.CameraMinZoomDistance = gcam.savedPlayerMin end
            if gcam.savedPlayerMax then lp.CameraMaxZoomDistance = gcam.savedPlayerMax end
        end)
        gcam.cam = nil

        restoreGameCameraScripts()
        setFarmStatus(landed and "Ghost Mode OFF - TP den vi tri camera"
                              or  "Ghost Mode OFF - khong co san, giu vi tri cu", C.Green)
    end)
end

local _uiVisible = true
local function toggleUIVisible()
    _uiVisible = not _uiVisible
    Win.Visible = _uiVisible
    SanityCard.Visible = _uiVisible
    TraitCard.Visible = _uiVisible
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not _G.BlairHub then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        toggleUIVisible()
        return
    end
    if input.KeyCode == KEYBINDS.Fly then
        Config.FlyMode = not Config.FlyMode
        if Config.FlyMode then enableFly() else disableFly() end
    elseif input.KeyCode == KEYBINDS.Ghost then
        Config.GhostMode = not Config.GhostMode
        if Config.GhostMode then enableGhostMode() else disableGhostMode() end
    end
end)


local Scroll=Instance.new("ScrollingFrame",Win)
Scroll.Size=UDim2.new(1,-8,1,-52); Scroll.Position=UDim2.new(0,4,0,48)
Scroll.BackgroundTransparency=1; Scroll.BorderSizePixel=0
Scroll.ScrollBarThickness=3; Scroll.ScrollBarImageColor3=C.AccentDim
Scroll.CanvasSize=UDim2.new(0,0,0,0); Scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y

local Content=Instance.new("Frame",Scroll)
Content.Size=UDim2.new(1,0,0,0); Content.AutomaticSize=Enum.AutomaticSize.Y
Content.BackgroundTransparency=1
local CL=Instance.new("UIListLayout",Content)
CL.SortOrder=Enum.SortOrder.LayoutOrder; CL.Padding=UDim.new(0,4)
Instance.new("UIPadding",Content).PaddingBottom=UDim.new(0,10)

local function sectionLabel(text,order)
    local F=Instance.new("Frame",Content)
    F.Size=UDim2.new(1,0,0,20); F.BackgroundTransparency=1; F.LayoutOrder=order
    local L=Instance.new("TextLabel",F)
    L.Size=UDim2.new(1,-10,1,0); L.Position=UDim2.new(0,8,0,0)
    L.BackgroundTransparency=1; L.Text=text; L.TextColor3=C.HeaderText
    L.TextSize=9; L.Font=Enum.Font.GothamBold; L.TextXAlignment=Enum.TextXAlignment.Left
    local line=Instance.new("Frame",F)
    line.Size=UDim2.new(1,-10,0,1); line.Position=UDim2.new(0,5,1,-1)
    line.BackgroundColor3=C.SectionLine; line.BorderSizePixel=0
end

local function makeToggle(label,sub,configKey,order,cb,ac)
    ac=ac or C.Accent
    local Row=Instance.new("Frame",Content)
    Row.Size=UDim2.new(1,0,0,46); Row.BackgroundColor3=C.Card
    Row.BorderSizePixel=0; Row.LayoutOrder=order
    Instance.new("UICorner",Row).CornerRadius=UDim.new(0,8)
    local NL=Instance.new("TextLabel",Row)
    NL.Size=UDim2.new(1,-80,0,16); NL.Position=UDim2.new(0,12,0,7)
    NL.BackgroundTransparency=1; NL.Text=label; NL.TextColor3=C.Text
    NL.TextSize=12; NL.Font=Enum.Font.GothamBold; NL.TextXAlignment=Enum.TextXAlignment.Left
    local SL=Instance.new("TextLabel",Row)
    SL.Size=UDim2.new(1,-80,0,12); SL.Position=UDim2.new(0,12,0,27)
    SL.BackgroundTransparency=1; SL.Text=sub.."  |  off"
    SL.TextColor3=C.TextMuted; SL.TextSize=10
    SL.Font=Enum.Font.Gotham; SL.TextXAlignment=Enum.TextXAlignment.Left
    local TBg=Instance.new("Frame",Row)
    TBg.Size=UDim2.new(0,42,0,22); TBg.Position=UDim2.new(1,-50,0.5,-11)
    TBg.BackgroundColor3=C.AccentDim; TBg.BorderSizePixel=0
    Instance.new("UICorner",TBg).CornerRadius=UDim.new(1,0)
    local TK=Instance.new("Frame",TBg)
    TK.Size=UDim2.new(0,16,0,16); TK.Position=UDim2.new(0,3,0.5,-8)
    TK.BackgroundColor3=Color3.new(1,1,1); TK.BorderSizePixel=0
    Instance.new("UICorner",TK).CornerRadius=UDim.new(1,0)
    -- Sync visual với config hiện tại (đã load từ file)
    local _initOn = Config[configKey]
    if _initOn then
        TBg.BackgroundColor3 = ac
        TK.Position = UDim2.new(1,-19,0.5,-8)
        SL.Text = sub.."  |  on"
        SL.TextColor3 = ac
    end
    local Btn=Instance.new("TextButton",TBg)
    Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.Text=""
    Btn.MouseButton1Click:Connect(function()
        Config[configKey]=not Config[configKey]
        local on=Config[configKey]
        TweenService:Create(TBg,TweenInfo.new(0.15),{BackgroundColor3=on and ac or C.AccentDim}):Play()
        TweenService:Create(TK,TweenInfo.new(0.15),{
            Position=on and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
        }):Play()
        SL.Text=sub..(on and "  |  on" or "  |  off")
        SL.TextColor3=on and ac or C.TextMuted
        if cb then cb(on) end
    end)
end

local function makeButton(label,sub,order,color,cb)
    local Row=Instance.new("Frame",Content)
    Row.Size=UDim2.new(1,0,0,46); Row.BackgroundColor3=C.Card
    Row.BorderSizePixel=0; Row.LayoutOrder=order
    Instance.new("UICorner",Row).CornerRadius=UDim.new(0,8)
    local NL=Instance.new("TextLabel",Row)
    NL.Size=UDim2.new(1,-90,0,16); NL.Position=UDim2.new(0,12,0,7)
    NL.BackgroundTransparency=1; NL.Text=label; NL.TextColor3=C.Text
    NL.TextSize=12; NL.Font=Enum.Font.GothamBold; NL.TextXAlignment=Enum.TextXAlignment.Left
    local SL=Instance.new("TextLabel",Row)
    SL.Size=UDim2.new(1,-90,0,12); SL.Position=UDim2.new(0,12,0,27)
    SL.BackgroundTransparency=1; SL.Text=sub; SL.TextColor3=C.TextMuted
    SL.TextSize=10; SL.Font=Enum.Font.Gotham; SL.TextXAlignment=Enum.TextXAlignment.Left
    local Btn=Instance.new("TextButton",Row)
    Btn.Size=UDim2.new(0,70,0,26); Btn.Position=UDim2.new(1,-76,0.5,-13)
    Btn.BackgroundColor3=color or C.AccentDim; Btn.Text="USE"
    Btn.TextColor3=Color3.new(1,1,1); Btn.TextSize=10
    Btn.Font=Enum.Font.GothamBold; Btn.BorderSizePixel=0
    Instance.new("UICorner",Btn).CornerRadius=UDim.new(0,5)
    Btn.MouseButton1Click:Connect(function()
        TweenService:Create(Btn,TweenInfo.new(0.1),{BackgroundColor3=Color3.new(1,1,1)}):Play()
        task.delay(0.15,function()
            if Btn and Btn.Parent then
                TweenService:Create(Btn,TweenInfo.new(0.2),{BackgroundColor3=color or C.AccentDim}):Play()
            end
        end)
        if cb then cb() end
    end)
end

sectionLabel("  AUTO FARM",1)
local FarmCard=Instance.new("Frame",Content)
FarmCard.Size=UDim2.new(1,0,0,80); FarmCard.BackgroundColor3=Color3.fromRGB(10,22,10)
FarmCard.BorderSizePixel=0; FarmCard.LayoutOrder=2
Instance.new("UICorner",FarmCard).CornerRadius=UDim.new(0,10)
do local s=Instance.new("UIStroke",FarmCard); s.Color=Color3.fromRGB(25,80,25); s.Thickness=1.5 end
S.farmBtn=Instance.new("TextButton",FarmCard)
S.farmBtn.Size=UDim2.new(1,-16,0,34); S.farmBtn.Position=UDim2.new(0,8,0,8)
S.farmBtn.BackgroundColor3=C.FarmGreen; S.farmBtn.Text="START AUTO FARM"
S.farmBtn.TextColor3=Color3.new(1,1,1); S.farmBtn.TextSize=13
S.farmBtn.Font=Enum.Font.GothamBold; S.farmBtn.BorderSizePixel=0
Instance.new("UICorner",S.farmBtn).CornerRadius=UDim.new(0,8)
S.farmStatusLbl=Instance.new("TextLabel",FarmCard)
S.farmStatusLbl.Size=UDim2.new(1,-16,0,22); S.farmStatusLbl.Position=UDim2.new(0,8,0,50)
S.farmStatusLbl.BackgroundTransparency=1; S.farmStatusLbl.Text="idle"
S.farmStatusLbl.TextColor3=Color3.fromRGB(70,130,70); S.farmStatusLbl.TextSize=10
S.farmStatusLbl.Font=Enum.Font.GothamBold; S.farmStatusLbl.TextXAlignment=Enum.TextXAlignment.Left
S.farmBtn.MouseButton1Click:Connect(function()
    Config.AutoFarm=not Config.AutoFarm
    if Config.AutoFarm then
        S.farmBtn.Text="STOP AUTO FARM"; S.farmBtn.BackgroundColor3=C.FarmRed
        task.spawn(function()
            runAutoFarm()
            if S.farmBtn and S.farmBtn.Parent then
                S.farmBtn.Text="START AUTO FARM"
                S.farmBtn.BackgroundColor3=C.FarmGreen
            end
            Config.AutoFarm=false
        end)
    else
        S.farmBtn.Text="START AUTO FARM"; S.farmBtn.BackgroundColor3=C.FarmGreen
        S.sboxToken={}; AUTO_FARM.running=false
        setFarmStatus("stopped",Color3.fromRGB(150,150,150))
    end
end)

sectionLabel("  HACKS",5)
makeToggle("Auto Hide",       "TP outside on hunt",   "AutoHide",       11)
makeToggle("Fly Mode",        "WASD + Space/Ctrl, hotkey F", "FlyMode",        9,
    function(on) if on then enableFly() else disableFly() end end, C.FlyBlue)
makeToggle("Speed Hack",      "set walk speed",            "SpeedHack",      12,
    function(on)
        if not on then pcall(function()
            local hum=getChar() and getChar():FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed=16 end
        end) end
    end)
do
    local Row=Instance.new("Frame",Content)
    Row.Size=UDim2.new(1,0,0,48); Row.BackgroundColor3=C.Card
    Row.BorderSizePixel=0; Row.LayoutOrder=13
    Instance.new("UICorner",Row).CornerRadius=UDim.new(0,8)
    local TL=Instance.new("TextLabel",Row)
    TL.Size=UDim2.new(1,-16,0,18); TL.Position=UDim2.new(0,12,0,6)
    TL.BackgroundTransparency=1; TL.Text="walk speed: "..Config.SpeedValue
    TL.TextColor3=C.TextDim; TL.TextSize=11; TL.Font=Enum.Font.GothamBold
    TL.TextXAlignment=Enum.TextXAlignment.Left
    local SBg=Instance.new("Frame",Row)
    SBg.Size=UDim2.new(1,-22,0,5); SBg.Position=UDim2.new(0,11,0,32)
    SBg.BackgroundColor3=C.AccentDim; SBg.BorderSizePixel=0
    Instance.new("UICorner",SBg).CornerRadius=UDim.new(1,0)
    local SFill=Instance.new("Frame",SBg)
    SFill.Size=UDim2.new((Config.SpeedValue-16)/84,0,1,0)
    SFill.BackgroundColor3=C.Accent; SFill.BorderSizePixel=0
    Instance.new("UICorner",SFill).CornerRadius=UDim.new(1,0)
    local SHit=Instance.new("TextButton",Row)
    SHit.Size=UDim2.new(1,-22,0,26); SHit.Position=UDim2.new(0,11,0,20)
    SHit.BackgroundTransparency=1; SHit.Text=""
    local drag=false
    SHit.MouseButton1Down:Connect(function() drag=true end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local r=math.clamp((i.Position.X-SBg.AbsolutePosition.X)/SBg.AbsoluteSize.X,0,1)
            Config.SpeedValue=math.floor(r*84+16)
            SFill.Size=UDim2.new(r,0,1,0); TL.Text="walk speed: "..Config.SpeedValue
        end
    end)
end
do
    local Row=Instance.new("Frame",Content)
    Row.Size=UDim2.new(1,0,0,48); Row.BackgroundColor3=C.Card
    Row.BorderSizePixel=0; Row.LayoutOrder=14
    Instance.new("UICorner",Row).CornerRadius=UDim.new(0,8)
    local TL=Instance.new("TextLabel",Row)
    TL.Size=UDim2.new(1,-16,0,18); TL.Position=UDim2.new(0,12,0,6)
    TL.BackgroundTransparency=1; TL.Text="fly speed: "..fly.speed
    TL.TextColor3=C.TextDim; TL.TextSize=11; TL.Font=Enum.Font.GothamBold
    TL.TextXAlignment=Enum.TextXAlignment.Left
    local SBg=Instance.new("Frame",Row)
    SBg.Size=UDim2.new(1,-22,0,5); SBg.Position=UDim2.new(0,11,0,32)
    SBg.BackgroundColor3=C.AccentDim; SBg.BorderSizePixel=0
    Instance.new("UICorner",SBg).CornerRadius=UDim.new(1,0)
    local SFill=Instance.new("Frame",SBg)
    SFill.Size=UDim2.new((fly.speed-10)/190,0,1,0)
    SFill.BackgroundColor3=C.FlyBlue; SFill.BorderSizePixel=0
    Instance.new("UICorner",SFill).CornerRadius=UDim.new(1,0)
    local SHit=Instance.new("TextButton",Row)
    SHit.Size=UDim2.new(1,-22,0,26); SHit.Position=UDim2.new(0,11,0,20)
    SHit.BackgroundTransparency=1; SHit.Text=""
    local drag=false
    SHit.MouseButton1Down:Connect(function() drag=true end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local r=math.clamp((i.Position.X-SBg.AbsolutePosition.X)/SBg.AbsoluteSize.X,0,1)
            fly.speed=math.floor(r*190+10)
            SFill.Size=UDim2.new(r,0,1,0); TL.Text="fly speed: "..fly.speed
        end
    end)
end

sectionLabel("  TOOLS",20)
makeToggle("Full Bright","removes darkness & fog",       "FullBright",21,
    function(on) if on then applyFullBright() else restoreLight() end end)
makeToggle("Ghost ESP",  "highlight + nametag on ghost", "GhostESP",  22)
makeToggle("Item ESP",   "highlight all map items",       "ItemESP",   23)
makeToggle("Hunt Alert", "red banner when ghost hunts",  "HuntAlert", 24)

sectionLabel("  ACTIONS",30)

-- Keybind editor
local KeybindCard = Instance.new("Frame", Content)
KeybindCard.Size = UDim2.new(1,0,0,0)
KeybindCard.AutomaticSize = Enum.AutomaticSize.Y
KeybindCard.BackgroundColor3 = Color3.fromRGB(12,10,22)
KeybindCard.BorderSizePixel = 0
KeybindCard.LayoutOrder = 31
Instance.new("UICorner", KeybindCard).CornerRadius = UDim.new(0,8)
do local s=Instance.new("UIStroke",KeybindCard); s.Color=C.StrokeDim; s.Thickness=1 end
local KBLayout = Instance.new("UIListLayout", KeybindCard)
KBLayout.SortOrder = Enum.SortOrder.LayoutOrder
KBLayout.Padding = UDim.new(0,2)
Instance.new("UIPadding", KeybindCard).PaddingTop = UDim.new(0,6)

local function makeKeybindRow(label, bindKey, order)
    local Row = Instance.new("Frame", KeybindCard)
    Row.Size = UDim2.new(1,0,0,30)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = order

    local NameL = Instance.new("TextLabel", Row)
    NameL.Size = UDim2.new(0,100,1,0)
    NameL.Position = UDim2.new(0,8,0,0)
    NameL.BackgroundTransparency = 1
    NameL.Text = label
    NameL.TextColor3 = C.TextDim
    NameL.TextSize = 10
    NameL.Font = Enum.Font.GothamBold
    NameL.TextXAlignment = Enum.TextXAlignment.Left

    local Btn = Instance.new("TextButton", Row)
    Btn.Size = UDim2.new(0,80,0,22)
    Btn.Position = UDim2.new(1,-88,0.5,-11)
    Btn.BackgroundColor3 = C.AccentDim
    Btn.Text = KEYBINDS[bindKey].Name
    Btn.TextColor3 = Color3.new(1,1,1)
    Btn.TextSize = 10
    Btn.Font = Enum.Font.GothamBold
    Btn.BorderSizePixel = 0
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0,5)

    local listening = false
    Btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        Btn.Text = "press key..."
        Btn.BackgroundColor3 = C.HuntRed
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            local kc = input.KeyCode
            if kc == Enum.KeyCode.Unknown then return end
            KEYBINDS[bindKey] = kc
            Btn.Text = kc.Name
            Btn.BackgroundColor3 = C.AccentDim
            listening = false
            conn:Disconnect()
        end)
    end)
end

makeKeybindRow("Fly Mode", "Fly", 1)
makeKeybindRow("Ghost Mode", "Ghost", 2)
makeKeybindRow("Trait Toggle", "Trait", 3)
Instance.new("Frame", KeybindCard).Size = UDim2.new(1,0,0,6)
makeButton("Go Ghost Room", "TP to coldest zone",32,Color3.fromRGB(40,60,110),goToGhostRoom)
makeButton("Go To Van",     "TP to leave button",33,Color3.fromRGB(30,60,30), goToVan)
makeButton("Open Van Door", "fire van door prompt", 34,Color3.fromRGB(60,50,20), function()
    S.vanDoorOpened=false; openVanDoor()
end)
makeButton("TP to Cursed", "tele tới cursed item gần nhất", 36, Color3.fromRGB(80,20,20), function()
    task.spawn(function()
        local char = getChar()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then setFarmStatus("No character", C.Red); return end

        -- Quet tat ca nguon co the chua cursed item, chon cai gan nhat
        local best, bestPart, bestDist = nil, nil, math.huge
        local function consider(obj)
            if not obj or not isCursedItem(obj) then return end
            local bp = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if not bp then return end
            local d = (bp.Position - hrp.Position).Magnitude
            if d < bestDist then bestDist = d; best = obj; bestPart = bp end
        end

        local Map = getMap()
        if Map then
            local cs = Map:FindFirstChild("CursedSpawns")
            if cs then for _, v in ipairs(cs:GetChildren()) do consider(v) end end
            local items = Map:FindFirstChild("Items")
            if items then for _, v in ipairs(items:GetChildren()) do consider(v) end end
        end
        -- Boo-Boo Doll + cursed object o workspace top-level
        -- Chỉ lấy Model/Tool, không lấy BasePart lẻ để tránh match parent chain sai
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA("Model") or v:IsA("Tool") then
                consider(v)
            end
        end

        if not bestPart then setFarmStatus("No cursed item found", C.Orange); return end
        setFarmStatus("TP to cursed: " .. best.Name .. string.format(" (%.0fu)", bestDist), C.FlyPurple)
        tweenToPos(bestPart.Position + Vector3.new(0, 0, 2), "cursed", 50)
    end)
end)
makeButton("Auto Quest", "tự động làm tất cả objectives", 35, Color3.fromRGB(50,30,80), function()
    task.spawn(function()
        if doAllQuests then
            doAllQuests()
        else
            setFarmStatus("doAllQuests not found!", C.Red)
        end
    end)
end)
makeButton("Pull All Tools", "tele tới từng tool quan trọng và tự nhặt", 37, Color3.fromRGB(40,40,80), function()
    task.spawn(function()
        local PULL_TOOLS = {
            "EMF Reader", "Ghost Writing Book", "Spirit Box",
            "SLS Camera", "Photo Camera", "Salt", "Crucifix",
        }
        if not getMap() then setFarmStatus("Map not found!", C.Red); return end
        local Items = getItems()
        if not Items then setFarmStatus("Items folder not found!", C.Red); return end

        local picked, missing, full = 0, 0, false
        for _, toolName in ipairs(PULL_TOOLS) do
            if hasInInventory(toolName) then
                -- already in bag, skip
            else
                if getTotalToolCount() >= 3 then full = true; break end
                -- locate tool model in Items folder
                local nameLow = toolName:lower()
                local toolObj = nil
                for _, v in ipairs(Items:GetChildren()) do
                    if v:IsA("Tool") and v.Name:lower():find(nameLow, 1, true) then
                        toolObj = v; break
                    end
                end
                if not toolObj then
                    missing = missing + 1
                else
                    setFarmStatus("Pulling: "..toolName, C.FlyBlue)
                    if bringTool(toolName) then
                        picked = picked + 1
                    else
                        missing = missing + 1
                    end
                    task.wait(0.15)
                end
            end
        end
        local msg = string.format("Picked %d, missing %d", picked, missing)
        if full then msg = msg .. " (bag full)" end
        setFarmStatus(msg, picked > 0 and C.Green or C.Orange)
    end)
end)

sectionLabel("  OBJECTIVES",37)
local QuestCard=Instance.new("Frame",Content)
QuestCard.Size=UDim2.new(1,0,0,0); QuestCard.AutomaticSize=Enum.AutomaticSize.Y
QuestCard.BackgroundColor3=Color3.fromRGB(10,18,10); QuestCard.BorderSizePixel=0
QuestCard.LayoutOrder=38
Instance.new("UICorner",QuestCard).CornerRadius=UDim.new(0,8)
do local s=Instance.new("UIStroke",QuestCard); s.Color=Color3.fromRGB(25,70,25); s.Thickness=1 end
local QuestLayout=Instance.new("UIListLayout",QuestCard)
QuestLayout.SortOrder=Enum.SortOrder.LayoutOrder; QuestLayout.Padding=UDim.new(0,0)
Instance.new("UIPadding",QuestCard).PaddingTop=UDim.new(0,4)

local questLabels={}
local function updateQuests()
    -- Clear cũ
    for _,v in ipairs(questLabels) do pcall(function() v:Destroy() end) end
    questLabels={}
    pcall(function()
        local map=workspace:FindFirstChild("Map")
        local van=map and map:FindFirstChild("Van")
        local vanMdl=van and van:FindFirstChild("Van")
        local screens=(van and van:FindFirstChild("Screens")) or (vanMdl and vanMdl:FindFirstChild("Screens"))
        local wb2=screens and screens:FindFirstChild("Whiteboard")
        local frame=wb2 and wb2:FindFirstChild("SurfaceGui")
        local objFrame=frame and frame:FindFirstChild("Frame")
        local objs=objFrame and objFrame:FindFirstChild("Objectives")
        if not objs then
            local lbl=Instance.new("TextLabel",QuestCard)
            lbl.Size=UDim2.new(1,-16,0,24); lbl.BackgroundTransparency=1
            lbl.Text="No objectives found"; lbl.TextColor3=C.TextMuted
            lbl.TextSize=10; lbl.Font=Enum.Font.Gotham
            lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.LayoutOrder=1
            Instance.new("UIPadding",lbl).PaddingLeft=UDim.new(0,8)
            table.insert(questLabels,lbl); return
        end
        local idx=0
        for _,obj in ipairs(objs:GetChildren()) do
            local hc=obj:FindFirstChild("HasCompleted")
            if hc then
                idx=idx+1
                local done=hc.Value==true
                local Row=Instance.new("Frame",QuestCard)
                Row.Size=UDim2.new(1,0,0,28); Row.BackgroundTransparency=1
                Row.BorderSizePixel=0; Row.LayoutOrder=idx
                local Dot=Instance.new("Frame",Row)
                Dot.Size=UDim2.new(0,8,0,8); Dot.Position=UDim2.new(0,8,0.5,-4)
                Dot.BackgroundColor3=done and C.Green or C.TextMuted
                Dot.BorderSizePixel=0
                Instance.new("UICorner",Dot).CornerRadius=UDim.new(1,0)
                local Lbl=Instance.new("TextLabel",Row)
                Lbl.Size=UDim2.new(1,-24,1,0); Lbl.Position=UDim2.new(0,22,0,0)
                Lbl.BackgroundTransparency=1; Lbl.Text=obj.Name
                Lbl.TextColor3=done and C.Green or C.TextDim
                Lbl.TextSize=10; Lbl.Font=Enum.Font.Gotham
                Lbl.TextXAlignment=Enum.TextXAlignment.Left
                Lbl.TextTruncate=Enum.TextTruncate.AtEnd
                table.insert(questLabels,Row)
                -- Auto update khi complete
                hc:GetPropertyChangedSignal("Value"):Connect(function()
                    Dot.BackgroundColor3=hc.Value and C.Green or C.TextMuted
                    Lbl.TextColor3=hc.Value and C.Green or C.TextDim
                end)
            end
        end
        if idx==0 then
            local lbl=Instance.new("TextLabel",QuestCard)
            lbl.Size=UDim2.new(1,-16,0,24); lbl.BackgroundTransparency=1
            lbl.Text="Loading objectives..."; lbl.TextColor3=C.TextMuted
            lbl.TextSize=10; lbl.Font=Enum.Font.Gotham
            lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.LayoutOrder=1
            Instance.new("UIPadding",lbl).PaddingLeft=UDim.new(0,8)
            table.insert(questLabels,lbl)
        end
    end)
end

-- Update khi map load/reload
task.spawn(function()
    while _G.BlairHub do
        updateQuests()
        task.wait(3)
    end
end)
workspace.ChildAdded:Connect(function(child)
    if child.Name=="Map" then task.wait(2); updateQuests() end
end)
sectionLabel("  GHOST ROOM",40)
local GRCard=Instance.new("Frame",Content)
GRCard.Size=UDim2.new(1,0,0,40); GRCard.BackgroundColor3=Color3.fromRGB(10,14,26)
GRCard.BorderSizePixel=0; GRCard.LayoutOrder=41
Instance.new("UICorner",GRCard).CornerRadius=UDim.new(0,8)
do local s=Instance.new("UIStroke",GRCard); s.Color=Color3.fromRGB(30,50,100); s.Thickness=1 end
S.ghostRoomLbl=Instance.new("TextLabel",GRCard)
S.ghostRoomLbl.Size=UDim2.new(1,-16,1,0); S.ghostRoomLbl.Position=UDim2.new(0,12,0,0)
S.ghostRoomLbl.BackgroundTransparency=1; S.ghostRoomLbl.Text="detecting..."
S.ghostRoomLbl.TextColor3=C.TextMuted; S.ghostRoomLbl.TextSize=12
S.ghostRoomLbl.Font=Enum.Font.GothamBold; S.ghostRoomLbl.TextXAlignment=Enum.TextXAlignment.Left

do
local SanityCard=Instance.new("Frame",sg)
SanityCard.Name="SanityTracker"
SanityCard.Size=UDim2.new(0,220,0,0)
SanityCard.AutomaticSize=Enum.AutomaticSize.Y
SanityCard.Position=UDim2.new(1,-WIN_W-28,0,16)
-- Chỉ follow Win nếu user chưa tự kéo SanityCard đi
local _sanityPinned = false
local _sanityDragging = false

SanityCard.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        _sanityDragging = true
    end
end)
SanityCard.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        -- Dùng AbsolutePosition (pixel thực tế) thay vì Position.X.Offset
        task.wait(0.05) -- đợi Roblox update AbsolutePosition sau khi thả
        _sanityDragging = false
        if Win and SanityCard then
            local defaultAbsX = Win.AbsolutePosition.X - 228
            local curAbsX = SanityCard.AbsolutePosition.X
            if math.abs(curAbsX - defaultAbsX) > 10 then
                _sanityPinned = true
            end
        end
    end
end)

task.spawn(function()
    while sg and sg.Parent do
        task.wait(0.05)
        if Win and SanityCard and not _sanityPinned and not _sanityDragging then
            local wp = Win.Position
            SanityCard.Position = UDim2.new(
                wp.X.Scale, wp.X.Offset - 228,
                wp.Y.Scale, wp.Y.Offset
            )
        end
    end
end)
SanityCard.BackgroundColor3=Color3.fromRGB(10,10,22)
SanityCard.BorderSizePixel=0
SanityCard.ZIndex=50
SanityCard.Active=true
SanityCard.Draggable=true
Instance.new("UICorner",SanityCard).CornerRadius=UDim.new(0,8)
do
    local s=Instance.new("UIStroke",SanityCard)
    s.Color=C.StrokeDim
    s.Thickness=1
end

local SanityTitle=Instance.new("TextLabel",SanityCard)
SanityTitle.Size=UDim2.new(1,-12,0,22)
SanityTitle.Position=UDim2.new(0,6,0,4)
SanityTitle.BackgroundTransparency=1
SanityTitle.Text="TEAM SANITY"
SanityTitle.TextColor3=C.Purple
SanityTitle.TextSize=11
SanityTitle.Font=Enum.Font.GothamBold
SanityTitle.TextXAlignment=Enum.TextXAlignment.Left
SanityTitle.ZIndex=51

local SanityList=Instance.new("Frame",SanityCard)
SanityList.Size=UDim2.new(1,-8,0,0)
SanityList.Position=UDim2.new(0,4,0,28)
SanityList.AutomaticSize=Enum.AutomaticSize.Y
SanityList.BackgroundTransparency=1
SanityList.ZIndex=51

local SanLayout=Instance.new("UIListLayout",SanityList)
SanLayout.SortOrder=Enum.SortOrder.LayoutOrder
SanLayout.Padding=UDim.new(0,2)

local sanPad=Instance.new("UIPadding",SanityList)
sanPad.PaddingTop=UDim.new(0,4)
sanPad.PaddingBottom=UDim.new(0,4)
sanPad.PaddingLeft=UDim.new(0,4)
sanPad.PaddingRight=UDim.new(0,4)

local sanityRows={}
local function getSanityColor(v)
    if v>=70 then return C.Green
    elseif v>=40 then return C.Yellow
    elseif v>=20 then return C.Orange
    else return C.Red end
end

local function updateSanityTracker()
    -- Clear cũ
    for name,row in pairs(sanityRows) do
        if not Players:FindFirstChild(name) then
            pcall(function() row.frame:Destroy() end)
            sanityRows[name]=nil
        end
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if not sanityRows[p.Name] then
            local Row=Instance.new("Frame",SanityList)
            Row.Size=UDim2.new(1,0,0,32); Row.BackgroundTransparency=1
            Row.BorderSizePixel=0; Row.LayoutOrder=#Players:GetPlayers()

            local NameL=Instance.new("TextLabel",Row)
            NameL.Size=UDim2.new(0,80,0,14); NameL.Position=UDim2.new(0,8,0,2)
            NameL.BackgroundTransparency=1; NameL.Text=p.Name
            NameL.TextColor3=C.TextDim; NameL.TextSize=9
            NameL.Font=Enum.Font.GothamBold
            NameL.TextXAlignment=Enum.TextXAlignment.Left
            NameL.TextTruncate=Enum.TextTruncate.AtEnd

            local BarBg=Instance.new("Frame",Row)
            BarBg.Size=UDim2.new(1,-16,0,8); BarBg.Position=UDim2.new(0,8,0,18)
            BarBg.BackgroundColor3=Color3.fromRGB(30,30,50); BarBg.BorderSizePixel=0
            Instance.new("UICorner",BarBg).CornerRadius=UDim.new(1,0)

            local BarFill=Instance.new("Frame",BarBg)
            BarFill.Size=UDim2.new(1,0,1,0); BarFill.BackgroundColor3=C.Green
            BarFill.BorderSizePixel=0
            Instance.new("UICorner",BarFill).CornerRadius=UDim.new(1,0)

            local ValL=Instance.new("TextLabel",Row)
            ValL.Size=UDim2.new(0,35,0,14); ValL.Position=UDim2.new(1,-38,0,2)
            ValL.BackgroundTransparency=1; ValL.Text="100%"
            ValL.TextColor3=C.Green; ValL.TextSize=9
            ValL.Font=Enum.Font.GothamBold
            ValL.TextXAlignment=Enum.TextXAlignment.Right

            sanityRows[p.Name]={frame=Row,bar=BarFill,val=ValL,name=NameL}
        end

        -- Đọc sanity từ player instance
        local row=sanityRows[p.Name]
        pcall(function()
            local sanity=p:FindFirstChild("Sanity")
            local sv=sanity and math.clamp(math.floor(sanity.Value),0,100) or 100
            local ratio=sv/100
            TweenService:Create(row.bar,TweenInfo.new(0.3),{
                Size=UDim2.new(ratio,0,1,0),
                BackgroundColor3=getSanityColor(sv)
            }):Play()
            row.val.Text=sv.."%"
            row.val.TextColor3=getSanityColor(sv)
        end)
    end
end

-- Update loop
-- Update loop (lazy: 2s, event hook vẫn update tức thì)
task.spawn(function()
    while _G.BlairHub do
        updateSanityTracker()
        task.wait(2)
    end
end)

-- Hook SanityCellAdded để update ngay lập tức
pcall(function()
    RS.Remotes.SanityCellAdded.OnClientEvent:Connect(function()
        task.wait(0.1); updateSanityTracker()
    end)
end)
end -- close sanity do block
sectionLabel("  EVIDENCE",45)
local EvCard=Instance.new("Frame",Content)
EvCard.Size=UDim2.new(1,0,0,0); EvCard.AutomaticSize=Enum.AutomaticSize.Y
EvCard.BackgroundColor3=Color3.fromRGB(10,8,18); EvCard.BorderSizePixel=0; EvCard.LayoutOrder=46
Instance.new("UICorner",EvCard).CornerRadius=UDim.new(0,8)
do local s=Instance.new("UIStroke",EvCard); s.Color=C.StrokeDim; s.Thickness=1 end
local EvLayout=Instance.new("UIListLayout",EvCard)
EvLayout.SortOrder=Enum.SortOrder.LayoutOrder; EvLayout.Padding=UDim.new(0,0)
Instance.new("Frame",EvCard).Size=UDim2.new(1,0,0,4)
for i,ev in ipairs(EVIDENCE_INFO) do
    local Row=Instance.new("Frame",EvCard)
    Row.Size=UDim2.new(1,0,0,32)
    Row.BackgroundColor3=i%2==0 and C.CardAlt or Color3.fromRGB(14,10,22)
    Row.BorderSizePixel=0; Row.LayoutOrder=i
    local Dot=Instance.new("Frame",Row)
    Dot.Size=UDim2.new(0,9,0,9); Dot.Position=UDim2.new(0,12,0.5,-4)
    Dot.BackgroundColor3=Color3.fromRGB(45,42,65); Dot.BorderSizePixel=0
    Instance.new("UICorner",Dot).CornerRadius=UDim.new(1,0)
    local IconL=Instance.new("TextLabel",Row)
    IconL.Size=UDim2.new(0,20,1,0); IconL.Position=UDim2.new(0,26,0,0)
    IconL.BackgroundTransparency=1; IconL.Text=ev.icon
    IconL.TextSize=13; IconL.Font=Enum.Font.Gotham; IconL.TextColor3=C.TextDim
    local NameL=Instance.new("TextLabel",Row)
    NameL.Size=UDim2.new(0,110,1,0); NameL.Position=UDim2.new(0,48,0,0)
    NameL.BackgroundTransparency=1; NameL.Text=ev.label; NameL.TextColor3=C.TextDim
    NameL.TextSize=11; NameL.Font=Enum.Font.GothamBold; NameL.TextXAlignment=Enum.TextXAlignment.Left
    local StatusLbl=Instance.new("TextLabel",Row)
    StatusLbl.Size=UDim2.new(0,82,1,0); StatusLbl.Position=UDim2.new(1,-86,0,0)
    StatusLbl.BackgroundTransparency=1; StatusLbl.Text="waiting..."
    StatusLbl.TextColor3=C.TextMuted; StatusLbl.TextSize=10
    StatusLbl.Font=Enum.Font.Gotham; StatusLbl.TextXAlignment=Enum.TextXAlignment.Right
    evidenceRefs[ev.key]={dot=Dot,status=StatusLbl}
end

sectionLabel("  GHOST FILTER",55)
local FilterCard=Instance.new("Frame",Content)
FilterCard.Size=UDim2.new(1,0,0,0); FilterCard.AutomaticSize=Enum.AutomaticSize.Y
FilterCard.BackgroundColor3=Color3.fromRGB(10,8,18); FilterCard.BorderSizePixel=0
FilterCard.LayoutOrder=56
Instance.new("UICorner",FilterCard).CornerRadius=UDim.new(0,8)
do local s=Instance.new("UIStroke",FilterCard); s.Color=C.StrokeDim; s.Thickness=1 end
local FCLayout=Instance.new("UIListLayout",FilterCard)
FCLayout.SortOrder=Enum.SortOrder.LayoutOrder; FCLayout.Padding=UDim.new(0,4)
S.ghostCountLbl=Instance.new("TextLabel",FilterCard)
S.ghostCountLbl.Size=UDim2.new(1,-16,0,22); S.ghostCountLbl.BackgroundTransparency=1
S.ghostCountLbl.Text="loading ghost DB..."; S.ghostCountLbl.TextColor3=C.TextDim
S.ghostCountLbl.TextSize=10; S.ghostCountLbl.Font=Enum.Font.GothamBold
S.ghostCountLbl.TextXAlignment=Enum.TextXAlignment.Left; S.ghostCountLbl.LayoutOrder=0
local GGrid=Instance.new("Frame",FilterCard)
GGrid.Size=UDim2.new(1,-12,0,0); GGrid.AutomaticSize=Enum.AutomaticSize.Y
GGrid.BackgroundTransparency=1; GGrid.LayoutOrder=1
local GGL=Instance.new("UIGridLayout",GGrid)
GGL.CellSize=UDim2.new(0.5,-4,0,24); GGL.CellPadding=UDim2.new(0,6,0,4)
GGL.SortOrder=Enum.SortOrder.LayoutOrder
task.spawn(function()
    local waited=0
    while not next(GHOST_DB) and waited<15 do task.wait(0.5); waited=waited+0.5 end
    local sortedNames={}
    for n in pairs(GHOST_DB) do table.insert(sortedNames,n) end
    table.sort(sortedNames)
    for i,name in ipairs(sortedNames) do
        local Cell=Instance.new("Frame",GGrid)
        Cell.BackgroundColor3=Color3.fromRGB(28,14,50); Cell.BorderSizePixel=0; Cell.LayoutOrder=i
        Instance.new("UICorner",Cell).CornerRadius=UDim.new(0,5)
        local Lbl=Instance.new("TextLabel",Cell)
        Lbl.Size=UDim2.new(1,0,1,0); Lbl.BackgroundTransparency=1; Lbl.Text=name
        Lbl.TextColor3=C.Purple; Lbl.TextSize=10; Lbl.Font=Enum.Font.GothamBold
        Lbl.TextXAlignment=Enum.TextXAlignment.Center
        ghostCells[name]={frame=Cell,label=Lbl}
    end
    S.ghostCountLbl.Text=#sortedNames.." / "..#sortedNames.." ghosts possible"
    updateGhostFilter()
end)
Instance.new("Frame",FilterCard).Size=UDim2.new(1,0,0,6)

local StopBtn=Instance.new("TextButton",Content)
StopBtn.Size=UDim2.new(1,0,0,34); StopBtn.BackgroundColor3=Color3.fromRGB(140,28,28)
StopBtn.Text="STOP & UNLOAD"; StopBtn.TextColor3=Color3.new(1,1,1)
StopBtn.TextSize=12; StopBtn.Font=Enum.Font.GothamBold
StopBtn.BorderSizePixel=0; StopBtn.LayoutOrder=99
Instance.new("UICorner",StopBtn).CornerRadius=UDim.new(0,8)
StopBtn.MouseButton1Click:Connect(makeUnload)

updateGhostFilter()

local _espTimer = 0
local _lastHunting = false
RunService.Heartbeat:Connect(function(dt)
    if not _G.BlairHub then return end
    local ghost = findGhost()
    updateGhostESP(ghost)
    if Config.SpeedHack then
        pcall(function()
            local _sc = getChar()
            local hum = _sc and _sc:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed=Config.SpeedValue end
        end)
    end
        if Config.ItemESP then
            local seen = {}

            for _,info in ipairs(getAllESPItemRoots()) do
                local root = info.root
                local itemList = info.deep and root:GetDescendants() or root:GetChildren()

                for _,item in ipairs(itemList) do
                    -- Bỏ qua player, Map, Camera, v.v. khi scan workspace
                    if info.workspaceOnly then
                        local skip = S.playerNamesCache[item.Name]
                            or item.Name == "Map"
                            or item.Name == "Terrain"
                            or item.Name == "Camera"
                            or item.Name == "IntroVan"
                        if skip then continue end
                    end

                    if item:IsA("Model") or item:IsA("Tool") or item:IsA("BasePart") or item:IsA("MeshPart") then
                        if shouldESPItem(item) then
                            -- Distance check 500 studs
                            local _c = getChar()
                            local _hrp = _c and _c:FindFirstChild("HumanoidRootPart")
                            local _anchor = item:IsA("BasePart") and item
                                or item:FindFirstChild("Handle")
                                or item:FindFirstChildWhichIsA("BasePart")
                            local _dist = (_hrp and _anchor)
                                and (_hrp.Position - _anchor.Position).Magnitude or 0
                            if _dist > 500 then
                                if espCache[item] then removeESP(item) end
                                continue
                            end
                            seen[item] = true
                            local espColor = getItemESPColor(item)
                            local espLabel = getItemESPLabel(item)

                            if not espCache[item] then
                                addESP(item,espColor,espLabel)
                            end
                        elseif espCache[item] then
                            removeESP(item)
                        end
                    end
                end
            end

            for obj in pairs(espCache) do
                if obj ~= ghost and not seen[obj] then
                    if isImportantItem(obj) or isCursedItem(obj) then
                        removeESP(obj)
                    end
                end
            end
        else
            for obj in pairs(espCache) do
                if obj ~= ghost and (isImportantItem(obj) or isCursedItem(obj)) then
                    removeESP(obj)
                end
            end
        end
        if Config.HuntAlert then
            local hv = ghost and ghost:FindFirstChild("Hunting")
            local hunting = hv and hv.Value==true
            if hunting and not _lastHunting then
                if _G.BlairHuntAlert then _G.BlairHuntAlert.Visible=true end
                -- Bắt đầu countdown hunt ~50s (estimate Blair hunt duration)
                task.spawn(function()
                    local _huntDur = 50
                    local _t = _huntDur
                    while _G.BlairHub and _t > 0 do
                        task.wait(1)
                        _t = _t - 1
                        local hv2 = ghost and ghost:FindFirstChild("Hunting")
                        local stillHunting = hv2 and hv2.Value==true
                        if not stillHunting then break end
                        if _G.BlairHuntAlert then
                            local lbl = _G.BlairHuntAlert:FindFirstChild("HuntCountdown")
                            if lbl then lbl.Text = "HUNT — " .. _t .. "s" end
                        end
                    end
                    if _G.BlairHuntAlert then
                        local lbl = _G.BlairHuntAlert:FindFirstChild("HuntCountdown")
                        if lbl then lbl.Text = "HUNTING" end
                    end
                end)
            elseif not hunting and _lastHunting then
                if _G.BlairHuntAlert then _G.BlairHuntAlert.Visible=false end
            end
            _lastHunting = hunting or false
        else
            if _G.BlairHuntAlert then _G.BlairHuntAlert.Visible=false end
        end
    _espTimer = _espTimer + dt
    if _espTimer < 0.5 then return end
    _espTimer = 0
end)

-- ============================================================================
-- TRAIT DETECTOR
-- ============================================================================
local traitLog = {}
local traitCard = nil
local traitVisible = true
local traitListFrame = nil
local TRAIT_MAX = 8

local function addTraitLog(text, col)
    col = col or C.Purple
    -- Popup thông báo dù trait card đang ẩn
    task.spawn(function()
        local popup = Instance.new("Frame", sg)
        popup.Size = UDim2.new(0, 280, 0, 32)
        popup.Position = UDim2.new(0.5, -140, 0, 60)
        popup.BackgroundColor3 = Color3.fromRGB(18, 10, 30)
        popup.BorderSizePixel = 0
        popup.ZIndex = 200
        Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)
        do
            local s = Instance.new("UIStroke", popup)
            s.Color = col; s.Thickness = 1.5
        end
        local lbl = Instance.new("TextLabel", popup)
        lbl.Size = UDim2.new(1, -12, 1, 0)
        lbl.Position = UDim2.new(0, 6, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "🔍 " .. text
        lbl.TextColor3 = col
        lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 201
        TweenService:Create(popup, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -140, 0, 70)
        }):Play()
        task.wait(3)
        TweenService:Create(popup, TweenInfo.new(0.4), {
            BackgroundTransparency = 1
        }):Play()
        TweenService:Create(lbl, TweenInfo.new(0.4), {
            TextTransparency = 1
        }):Play()
        task.wait(0.4)
        pcall(function() popup:Destroy() end)
    end)

    -- Thêm vào log trong card
    table.insert(traitLog, 1, {text=text, col=col, time=os.date("%H:%M:%S")})
    if #traitLog > TRAIT_MAX then table.remove(traitLog) end

    -- Rebuild list
    if traitListFrame then
        for _, v in ipairs(traitListFrame:GetChildren()) do
            if not v:IsA("UIListLayout") then v:Destroy() end
        end
        for i, entry in ipairs(traitLog) do
            local row = Instance.new("Frame", traitListFrame)
            row.Size = UDim2.new(1, 0, 0, 28)
            row.BackgroundTransparency = 1
            row.LayoutOrder = i
            local dot = Instance.new("Frame", row)
            dot.Size = UDim2.new(0, 7, 0, 7)
            dot.Position = UDim2.new(0, 6, 0.5, -3)
            dot.BackgroundColor3 = entry.col
            dot.BorderSizePixel = 0
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
            local tl = Instance.new("TextLabel", row)
            tl.Size = UDim2.new(1, -50, 1, 0)
            tl.Position = UDim2.new(0, 18, 0, 0)
            tl.BackgroundTransparency = 1
            tl.Text = entry.text
            tl.TextColor3 = entry.col
            tl.TextSize = 10
            tl.Font = Enum.Font.GothamBold
            tl.TextXAlignment = Enum.TextXAlignment.Left
            tl.TextTruncate = Enum.TextTruncate.AtEnd
            local ttime = Instance.new("TextLabel", row)
            ttime.Size = UDim2.new(0, 40, 1, 0)
            ttime.Position = UDim2.new(1, -44, 0, 0)
            ttime.BackgroundTransparency = 1
            ttime.Text = entry.time
            ttime.TextColor3 = C.TextMuted
            ttime.TextSize = 9
            ttime.Font = Enum.Font.Gotham
            ttime.TextXAlignment = Enum.TextXAlignment.Right
        end
    end
end

-- Build Trait Card UI
local TraitCard = Instance.new("Frame", sg)
TraitCard.Name = "TraitDetector"
TraitCard.Size = UDim2.new(0, 240, 0, 0)
TraitCard.AutomaticSize = Enum.AutomaticSize.Y
TraitCard.Position = UDim2.new(1, -WIN_W-28, 0, 200)
TraitCard.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
TraitCard.BorderSizePixel = 0
TraitCard.ZIndex = 50
TraitCard.Active = true
TraitCard.Draggable = true
Instance.new("UICorner", TraitCard).CornerRadius = UDim.new(0, 8)
do
    local s = Instance.new("UIStroke", TraitCard)
    s.Color = C.StrokeDim; s.Thickness = 1
end

-- Header
local traitHeader = Instance.new("Frame", TraitCard)
traitHeader.Size = UDim2.new(1, 0, 0, 28)
traitHeader.BackgroundColor3 = Color3.fromRGB(16, 10, 30)
traitHeader.BorderSizePixel = 0
Instance.new("UICorner", traitHeader).CornerRadius = UDim.new(0, 8)
local traitHeaderFix = Instance.new("Frame", traitHeader)
traitHeaderFix.Size = UDim2.new(1, 0, 0, 8)
traitHeaderFix.Position = UDim2.new(0, 0, 1, -8)
traitHeaderFix.BackgroundColor3 = Color3.fromRGB(16, 10, 30)
traitHeaderFix.BorderSizePixel = 0
local traitTitle = Instance.new("TextLabel", traitHeader)
traitTitle.Size = UDim2.new(1, -60, 1, 0)
traitTitle.Position = UDim2.new(0, 8, 0, 0)
traitTitle.BackgroundTransparency = 1
traitTitle.Text = "TRAIT DETECTOR  [T]"
traitTitle.TextColor3 = C.Purple
traitTitle.TextSize = 10
traitTitle.Font = Enum.Font.GothamBold
traitTitle.TextXAlignment = Enum.TextXAlignment.Left
local traitToggleBtn = Instance.new("TextButton", traitHeader)
traitToggleBtn.Size = UDim2.new(0, 36, 0, 18)
traitToggleBtn.Position = UDim2.new(1, -40, 0.5, -9)
traitToggleBtn.BackgroundColor3 = C.AccentDim
traitToggleBtn.Text = "hide"
traitToggleBtn.TextColor3 = Color3.new(1,1,1)
traitToggleBtn.TextSize = 9
traitToggleBtn.Font = Enum.Font.GothamBold
traitToggleBtn.BorderSizePixel = 0
Instance.new("UICorner", traitToggleBtn).CornerRadius = UDim.new(0, 4)

-- Body
local traitBody = Instance.new("Frame", TraitCard)
traitBody.Size = UDim2.new(1, 0, 0, 0)
traitBody.AutomaticSize = Enum.AutomaticSize.Y
traitBody.Position = UDim2.new(0, 0, 0, 28)
traitBody.BackgroundTransparency = 1
traitBody.BorderSizePixel = 0

traitListFrame = Instance.new("Frame", traitBody)
traitListFrame.Size = UDim2.new(1, -8, 0, 0)
traitListFrame.AutomaticSize = Enum.AutomaticSize.Y
traitListFrame.Position = UDim2.new(0, 4, 0, 4)
traitListFrame.BackgroundTransparency = 1
local traitLL = Instance.new("UIListLayout", traitListFrame)
traitLL.SortOrder = Enum.SortOrder.LayoutOrder
traitLL.Padding = UDim.new(0, 2)

local traitEmptyLbl = Instance.new("TextLabel", traitListFrame)
traitEmptyLbl.Size = UDim2.new(1, 0, 0, 28)
traitEmptyLbl.BackgroundTransparency = 1
traitEmptyLbl.Text = "No traits detected yet..."
traitEmptyLbl.TextColor3 = C.TextMuted
traitEmptyLbl.TextSize = 10
traitEmptyLbl.Font = Enum.Font.Gotham
traitEmptyLbl.LayoutOrder = 99

local traitPad = Instance.new("Frame", traitBody)
traitPad.Size = UDim2.new(1, 0, 0, 6)
traitPad.BackgroundTransparency = 1

-- Toggle logic
local function setTraitVisible(v)
    traitVisible = v
    traitBody.Visible = v
    traitToggleBtn.Text = v and "hide" or "show"
end

traitToggleBtn.MouseButton1Click:Connect(function()
    setTraitVisible(not traitVisible)
end)

traitCard = TraitCard

-- Hotkey Trait
UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not _G.BlairHub then return end
    if input.KeyCode == KEYBINDS.Trait then
        setTraitVisible(not traitVisible)
    end
end)

-- ============================================================================
-- TRAIT DETECTION LOGIC (v7.9 — based on Blair Wiki data)
local TS = {
    traitDetected   = {},
    huntCount       = 0,
    huntTimes       = {},
    huntDurations   = {},
    saltStepCount   = 0,
    lightOffCount   = 0,
    lightOnCount    = 0,
    itemThrowCount  = 0,
    itemThrowWindow = 0,
    ghostSpeedLog   = {},
    lastHuntStart   = 0,
    lastHuntEnd     = 0,
    parabolicScream = false,
    nookItemMissing = false,
    vuultLightCount = 0,
    vuultWindow     = 0,
    mareConsecOff   = 0,
    lastLightState  = nil,
    lastLightChange = 0,
    lightHooked     = false,
    saltHooked      = false,
}

local TRAIT_GHOST_MAP = {
    wraith_salt="Wraith", mare_light="Mare", phantom_los="Phantom",
    demon_hunt="Demon", shade_nohunt="Shade", poltergeist_polt="Poltergeist",
    revenant_speed="Revenant", banshee_target="Banshee", vuult_breaker="Vuult",
    krasue_range="Krasue", jiangshi_stay="Jiangshi", yama_growl="Yama",
    lament_hide="Lament", oni_active="Oni", spirit_smudge="Spirit",
    yurei_teleport="Yurei",
}

local function initTraitDetection()

local function markTrait(key, text, col)
    if TS.traitDetected and TS.traitDetected[key] then return end
    local ghostName = TRAIT_GHOST_MAP[key]
    if ghostName then
        local possible = getPossibleGhosts()
        if #possible>0 then
            local found=false
            for _,g in ipairs(possible) do if g==ghostName then found=true; break end end
            if not found then return end
        end
    end
    if not TS.traitDetected then TS.traitDetected = {} end
    TS.traitDetected[key] = true
    if traitEmptyLbl and traitEmptyLbl.Parent then
        traitEmptyLbl:Destroy()
        traitEmptyLbl = nil
    end
    addTraitLog(text, col)
    print("[Trait]", text)
end

-- Hook đèn ghost room một lần
local function hookGhostRoomLight()
        if TS.lightHooked then return end
    pcall(function()
        local Zones = getZones()
        if not Zones then return end
        local coldZone, coldTemp = nil, 100
        for _, zone in ipairs(Zones:GetChildren()) do
            local tv   = zone:FindFirstChild("_____Temperature")
            local excl = zone:FindFirstChild("Exclude")
            if tv and tv.Value < coldTemp and not (excl and excl.Value) then
                coldTemp = tv.Value; coldZone = zone
            end
        end
        if not coldZone then return end
        local zl = coldZone:FindFirstChild("ZoneLight")
        local ls = zl and zl.Value
        local sw = ls and ls:FindFirstChild("SwitchState")
        if not sw then return end
        TS.lightHooked = true
        TS.lastLightState = sw.Value

        sw:GetPropertyChangedSignal("Value"):Connect(function()
            local now    = tick()
            local isOn   = sw.Value
            local wasOff = (TS.lastLightState == false)

            if not isHunting() then
                if not isOn then
                    -- Đèn tắt
                    TS.lightOffCount = TS.lightOffCount + 1
                    TS.mareConsecOff = TS.mareConsecOff + 1

                    -- Vuult: bật/tắt nhanh (< 4s giữa các lần)
                    if now - TS.lastLightChange < 4 then
                        TS.vuultLightCount = TS.vuultLightCount + 1
                        if TS.vuultLightCount >= 4 then
                            markTrait("vuult_breaker",
                                string.format("VUULT: đèn bật/tắt liên tục %dx trong thời gian ngắn!", TS.vuultLightCount),
                                C.Yellow)
                        end
                    else
                        TS.vuultLightCount = 1
                    end
                else
                    -- Đèn bật lại
                    local offDuration = now - TS.lastLightChange
                    -- Mare trick: tắt rồi bật ngay lại (< 2s) để bẫy player
                    if wasOff and offDuration < 2 then
                        TS.lightOnCount = TS.lightOnCount + 1
                        if TS.lightOnCount >= 2 then
                            markTrait("mare_trick",
                                "MARE: tắt đèn rồi bật ngay lại để bẫy! (Mare light trick)",
                                C.ColdBlue)
                        end
                    end
                    -- Reset Mare consecutive off count
                    TS.mareConsecOff = 0
                    TS.vuultLightCount = 0
                end

                -- Mare: tắt đèn >= 3 lần liên tiếp không bật lại
                if TS.mareConsecOff >= 3 then
                    markTrait("mare_light",
                        string.format("MARE: tắt đèn ghost room %dx liên tiếp (không bật lại)!", TS.mareConsecOff),
                        C.ColdBlue)
                end
            end

            TS.lastLightState  = isOn
            TS.lastLightChange = now
        end)
        print("[Trait] Ghost room light hooked:", coldZone.Name)
    end)
end

-- Hook salt
local function hookSalt()
        if TS.saltHooked then return end
    pcall(function()
        local items = getItems()
        if not items then return end
        local salt = items:FindFirstChild("Salt")
        if not salt then return end
                TS.saltHooked = true
        -- Wraith: ghost KHÔNG tạo Prints sau khi dẫm muối
        -- Detect qua SaltPlaced event → chờ 3s → check Prints
        local remote = salt:FindFirstChild("Remote")
        local placed = remote and remote:FindFirstChild("SaltPlaced")
        if placed then
            placed.Event:Connect(function()
                TS.saltStepCount = TS.saltStepCount + 1
                task.wait(3)
                local prints = getMap() and getMap():FindFirstChild("Prints")
                local hasPrint = prints and #prints:GetChildren() > 0
                if not hasPrint then
                    markTrait("wraith_salt",
                        "WRAITH: dẫm muối nhưng không để lại dấu chân UV!",
                        C.Purple)
                end
            end)
        end
    end)
end

-- ── HUNT TRACKER ─────────────────────────────────────────────────────────────
task.spawn(function()
    local wasHunting = false
    local huntStartTime = 0
    while _G.BlairHub do
        task.wait(0.25)
        pcall(function()
            local hunting = isHunting()
            if hunting and not wasHunting then
                -- Hunt bắt đầu
                TS.huntCount     = TS.huntCount + 1
                huntStartTime = tick()
                TS.lastHuntStart = huntStartTime
                table.insert(TS.huntTimes, huntStartTime)
                TS.ghostSpeedLog = {}

                -- Krasue: hunt bắt đầu từ rất xa (> 40 studs)
                local ghost    = findGhost()
                local ghostHrp = ghost and ghost:FindFirstChild("HumanoidRootPart")
                local myHrp    = getChar() and getChar():FindFirstChild("HumanoidRootPart")
                if ghostHrp and myHrp then
                    local dist = (ghostHrp.Position - myHrp.Position).Magnitude
                    if dist > 40 then
                        markTrait("krasue_range",
                            string.format("KRASUE: hunt bắt đầu từ xa %.0f studs!", dist),
                            C.HuntRed)
                    end
                end

                -- Demon: hunt lại quá nhanh (< 25s kể từ hunt trước kết thúc)
                if TS.lastHuntEnd > 0 then
                    local gap = huntStartTime - TS.lastHuntEnd
                    if gap < 25 then
                        markTrait("demon_hunt",
                            string.format("DEMON: hunt lại chỉ sau %.0fs! (cooldown cực ngắn)", gap),
                            C.Red)
                    end
                end

            elseif not hunting and wasHunting then
                -- Hunt kết thúc
                local duration = tick() - huntStartTime
                table.insert(TS.huntDurations, duration)
                TS.lastHuntEnd = tick()

                -- Lament: fake end → check lights/footsteps vẫn còn
                -- Phát hiện bằng cách kiểm tra ghost vẫn còn active sau "end"
                task.spawn(function()
                    task.wait(1)
                    if isHunting() then
                        markTrait("lament_fake",
                            "LAMENT: fake kết thúc hunt! Vẫn đang hunt sau khi đèn dừng nhấp nháy.",
                            C.TextDim)
                    end
                end)
            end

            -- Speed tracking khi hunting
            if hunting then
                local ghost    = findGhost()
                local ghostHrp = ghost and ghost:FindFirstChild("HumanoidRootPart")
                if ghostHrp then
                    local now = tick()
                    if #TS.ghostSpeedLog > 0 then
                        local last   = TS.ghostSpeedLog[#TS.ghostSpeedLog]
                        local spd    = (ghostHrp.Position - last.pos).Magnitude / (now - last.t)
                        local myHrp  = getChar() and getChar():FindFirstChild("HumanoidRootPart")
                        local hasLOS = myHrp and (ghostHrp.Position - myHrp.Position).Magnitude < 30

                        -- Revenant: chậm ngoài LOS, cực nhanh khi LOS
                        if hasLOS and spd > 10 then
                            markTrait("revenant_speed",
                                string.format("REVENANT: tốc độ %.0f studs/s khi nhìn thấy player (LOS)!", spd),
                                C.Orange)
                        end
                    end
                    table.insert(TS.ghostSpeedLog, {pos = ghostHrp.Position, t = tick()})
                    if #TS.ghostSpeedLog > 20 then table.remove(TS.ghostSpeedLog, 1) end
                end
            end

            wasHunting = hunting
        end)
    end
end)

-- ── PHANTOM: GhostinLOS remote ───────────────────────────────────────────────
pcall(function()
    RS.Remotes.GhostinLOS.OnClientEvent:Connect(function()
        markTrait("phantom_los",
            "PHANTOM: xuất hiện trong tầm nhìn player (LOS sanity drain)!",
            C.FlyPurple)
    end)
end)

-- ── POLTERGEIST: ném nhiều item cùng lúc (poltsplosion) ─────────────────────
-- Poltergeist có thể ném tới 10 items cùng lúc
pcall(function()
    local remote = RS.Remotes:FindFirstChild("Eventboard/ExecuteEvent")
    if not remote then return end
    remote.OnClientEvent:Connect(function()
        local now = tick()
        if now - TS.itemThrowWindow > 5 then
            TS.itemThrowCount  = 0
            TS.itemThrowWindow = now
        end
        TS.itemThrowCount = TS.itemThrowCount + 1
        if TS.itemThrowCount >= 4 then
            markTrait("poltergeist_polt",
                string.format("POLTERGEIST: %d items bị ném trong 5s (poltsplosion)!", TS.itemThrowCount),
                C.Orange)
        end
    end)
end)

-- ── BANSHEE: screech qua Parabolic Microphone ────────────────────────────────
-- Banshee screech là cách chắc chắn nhất để identify
pcall(function()
    local parabolic = getRemote("ParabolicMicrophoneScream")
    if not parabolic then return end
    parabolic.OnClientEvent:Connect(function()
        if not TS.parabolicScream then
            TS.parabolicScream = true
            markTrait("banshee_screech",
                "BANSHEE: nghe tiếng screech qua Parabolic Microphone!",
                C.Yellow)
        end
    end)
end)

-- ── SHADE: ít hoạt động, không hunt khi 2+ người ────────────────────────────
-- Shade sanity threshold 35% (thấp hơn bình thường 50%)
-- Không perform ghost event khi 2+ người trong nhà
task.spawn(function()
    local noEventTimer  = 0
    local gameStartTime = tick()
    while _G.BlairHub do
        task.wait(10)
        pcall(function()
            if tick() - gameStartTime < 120 then return end -- chờ 2 phút
            local pCount = #Players:GetPlayers()
            if pCount >= 2 and not isHunting() then
                noEventTimer = noEventTimer + 10
                if noEventTimer >= 200 then
                    markTrait("shade_nohunt",
                        string.format("SHADE: không hunt suốt %.0fs với %d người (sanity threshold thấp)!", noEventTimer, pCount),
                        C.TextDim)
                end
            else
                if isHunting() then noEventTimer = 0 end
            end
        end)
    end
end)

-- ── SPIRIT: smudge block hunt 180s (vs 120s thông thường) ────────────────────
task.spawn(function()
    local smudgeTime  = 0
    local smudgeActive = false
    while _G.BlairHub do
        task.wait(1)
        pcall(function()
            if isHunting() then smudgeActive = false; smudgeTime = 0; return end
            local items  = getItems()
            local smudge = items and items:FindFirstChild("Smudge Stick")
            local burn   = smudge and smudge:FindFirstChild("Burning")
            if burn and burn.Value and not smudgeActive then
                smudgeActive = true
                smudgeTime   = tick()
                print("[Trait] Smudge detected, timer started")
            end
            if smudgeActive and smudgeTime > 0 then
                local elapsed = tick() - smudgeTime
                if elapsed > 180 and not isHunting() then
                    markTrait("spirit_smudge",
                        string.format("SPIRIT: không hunt %.0fs sau smudge (Spirit = 180s, others = 120s)!", elapsed),
                        C.Green)
                    smudgeActive = false
                end
            end
        end)
    end
end)

-- ── HARROW: không roam, chỉ ở ghost room (DUY NHẤT không roam) ───────────────
-- Wiki: "All ghosts, with the exception of the Harrow, may roam"
-- Harrow: speed tăng khi gần ghost room, giảm khi đi xa
task.spawn(function()
    local origin     = nil
    local stayTick   = 0
    local stayCount  = 0
    task.wait(15)
    while _G.BlairHub do
        task.wait(5)
        pcall(function()
            if isHunting() then return end
            local ghost = findGhost()
            local hrp   = ghost and ghost:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            if not origin then origin = hrp.Position; return end
            local dist = (hrp.Position - origin).Magnitude
            if dist < 12 then
                stayCount = stayCount + 1
                if stayCount >= 8 then -- 40s không rời ghost room
                    markTrait("harrow_noroam",
                        "HARROW: ghost không rời ghost room (HARROW là ghost DUY NHẤT không roam!)",
                        C.ColdLight)
                end
            else
                -- Ghost đã roam → không phải Harrow
                stayCount = 0
                origin    = hrp.Position
            end
        end)
    end
end)

-- ── JIANGSHI: lặp lại interaction 3 lần liên tiếp ────────────────────────────
-- Jiangshi đặc trưng: trigger cùng 1 loại event 3 lần liên tiếp
pcall(function()
    local remote = RS.Remotes:FindFirstChild("Eventboard/ExecuteEvent")
    if not remote then return end
    local lastEventType = nil
    local consecCount   = 0
    remote.OnClientEvent:Connect(function(evType)
        if evType == lastEventType then
            consecCount = consecCount + 1
            if consecCount >= 3 then
                markTrait("jiangshi_repeat",
                    string.format("JIANGSHI: lặp lại event '%s' %dx liên tiếp!", tostring(evType), consecCount),
                    C.ColdLight)
            end
        else
            lastEventType = evType
            consecCount   = 1
        end
    end)
end)

-- ── YUREI: teleport đột ngột về ghost room ───────────────────────────────────
task.spawn(function()
    local ghostLastPos = nil
    while _G.BlairHub do
        task.wait(0.5)
        pcall(function()
            if isHunting() then ghostLastPos = nil; return end
            local ghost = findGhost()
            local hrp   = ghost and ghost:FindFirstChild("HumanoidRootPart")
            if not hrp then ghostLastPos = nil; return end
            if ghostLastPos then
                local moved = (hrp.Position - ghostLastPos).Magnitude
                if moved > 25 then
                    markTrait("yurei_teleport",
                        string.format("YUREI: ghost teleport đột ngột %.0f studs về ghost room!", moved),
                        C.ColdBlue)
                end
            end
            ghostLastPos = hrp.Position
        end)
    end
end)

-- ── YAMA: Spirit Box growl đặc trưng ────────────────────────────────────────
-- Yama growl ≠ Demon roar: Yama growl xảy ra khi KHÔNG hunt
task.spawn(function()
    while _G.BlairHub do
        task.wait(1)
        pcall(function()
            local char = getChar()
            local bp   = getBP()
            for _, parent in ipairs({char, bp}) do
                if parent then
                    local sb = parent:FindFirstChild("Spirit Box")
                    if sb then
                        local gt = sb:FindFirstChild("GhostTalk")
                        if gt then
                            for _, snd in ipairs(gt:GetChildren()) do
                                if snd:IsA("Sound") and not snd:GetAttribute("yama_hooked") then
                                    snd:SetAttribute("yama_hooked", true)
                                    local n = snd.Name:lower()
                                    if n:find("growl") or n:find("roar") or n:find("yama") then
                                        snd:GetPropertyChangedSignal("Playing"):Connect(function()
                                            if snd.Playing and not isHunting() then
                                                markTrait("yama_growl",
                                                    "YAMA: Spirit Box growl khi KHÔNG hunt (≠ Demon roar)!",
                                                    C.FlyPurple)
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- ── NOOK: steal/mất item trong Items folder ───────────────────────────────────
-- Nook steal items, Poltergeist throw items — khác nhau ở chỗ item biến mất
task.spawn(function()
    local knownItems = {}
    task.wait(5)
    pcall(function()
        local items = getItems()
        if not items then return end
        for _, v in ipairs(items:GetChildren()) do
            knownItems[v] = true
        end
        items.ChildRemoved:Connect(function(child)
            if knownItems[child] then
                knownItems[child] = nil
                if not isHunting() then
                    -- Chờ 1s xem item có xuất hiện lại trong backpack/char không
                    -- Nếu có = player nhặt, không phải Nook steal
                    task.wait(1)
                    local bp = getBP()
                    local char = getChar()
                    local inPlayer = (bp and bp:FindFirstChild(child.Name))
                        or (char and char:FindFirstChild(child.Name))
                    if not inPlayer then
                        markTrait("nook_steal",
                            "NOOK: item '"..child.Name.."' biến mất khỏi map (Nook steal)!",
                            C.Orange)
                    end
                end
            end
        end)
    end)
end)

-- ── VUULT: bật tắt đèn NHANH (< 3s liên tiếp), phân biệt với Mare ────────────
-- Vuult: đèn bật tắt liên tục rất nhanh (vuultage behavior)
-- Mare: đèn tắt lâu, thích darkness, không bật lại liên tục
-- → Đã xử lý trong hookGhostRoomLight() ở trên

-- ── DEMON: roar khi crucifix được dùng ──────────────────────────────────────
pcall(function()
    local crucifixRemote = getRemote("CrucifixRemote")
    if not crucifixRemote then return end
    crucifixRemote.OnClientEvent:Connect(function(evType)
        if tostring(evType):lower():find("roar") or tostring(evType):lower():find("demon") then
            markTrait("demon_roar",
                "DEMON: phát ra tiếng roar khi crucifix được kích hoạt!",
                C.Red)
        end
    end)
end)

-- ── INIT: Hook light và salt khi map load ────────────────────────────────────
task.spawn(function()
    task.wait(3)
    hookGhostRoomLight()
    hookSalt()
end)

workspace.ChildAdded:Connect(function(child)
    if child.Name == "Map" then
        -- Reset tất cả state
        TS.traitDetected = {}
        traitLog = {}
        TS.huntCount       = 0
        TS.huntTimes       = {}
        TS.huntDurations   = {}
        TS.saltStepCount   = 0
        TS.lightOffCount   = 0
        TS.lightOnCount    = 0
        TS.mareConsecOff   = 0
        TS.vuultLightCount = 0
        TS.itemThrowCount  = 0
        TS.itemThrowWindow = 0
        TS.ghostSpeedLog   = {}
        TS.lastHuntStart   = 0
        TS.lastHuntEnd     = 0
        TS.parabolicScream = false
        TS.nookItemMissing = false
        TS.lightHooked     = false
        TS.saltHooked      = false
        TS.lastLightState  = nil
        TS.lastLightChange = 0
        traitLog = {}

        if traitListFrame then
            for _, v in ipairs(traitListFrame:GetChildren()) do
                if not v:IsA("UIListLayout") then v:Destroy() end
            end
            if not traitEmptyLbl or not traitEmptyLbl.Parent then
                traitEmptyLbl = Instance.new("TextLabel", traitListFrame)
                traitEmptyLbl.Size = UDim2.new(1, 0, 0, 28)
                traitEmptyLbl.BackgroundTransparency = 1
                traitEmptyLbl.Text = "No traits detected yet..."
                traitEmptyLbl.TextColor3 = C.TextMuted
                traitEmptyLbl.TextSize = 10
                traitEmptyLbl.Font = Enum.Font.Gotham
                traitEmptyLbl.LayoutOrder = 99
            end
        end

        task.wait(3)
        hookGhostRoomLight()
        hookSalt()
        print("[Trait v2.0] Reset for new map")
    end
end)

end -- close initTraitDetection
initTraitDetection()

print("[Blair Hub v7.8] Loaded!")
print("  FIX: EMF — wait char replicate + wait remote replicate before fire")
print("  FIX: bringTool — drop equipped first nếu đủ 3 slot (không drop random)")
print("  FIX: Sanity — lp.Sanity NumberValue trực tiếp (confirmed scan)")
print("  FIX: Stamina — lp.DoubleStamina BoolValue (confirmed scan)")
print("  NEW: openVanDoor() tự động khi start farm")
print("  NEW: Leave = goToVan() tween đến van, player tự bấm")
print("  NEW: Button 'Go To Van' + 'Open Van Door' trong ACTIONS")

S.espCache = espCache
S.IMPORTANT_ITEM_NAMES = IMPORTANT_ITEM_NAMES
S.CURSED_ITEM_NAMES = CURSED_ITEM_NAMES
S.BOOBOO_NAMES = BOOBOO_NAMES
S.IMPORTANT_TOOL_NAMES = IMPORTANT_TOOL_NAMES
S.CURSED_KEYWORDS = CURSED_KEYWORDS
S.normalizeItemName = normalizeItemName
S.isBooBoo = isBooBoo
S.isImportantTool = isImportantTool
S.isImportantItem = isImportantItem
S.isCursedItem = isCursedItem
S.shouldESPItem = shouldESPItem
S.getItemESPColor = getItemESPColor
S.getItemESPLabel = getItemESPLabel
S.addESP = addESP
S.removeESP = removeESP
S.clearAllESP = clearAllESP
S.ghostESP = ghostESP
S.clearGhostESP = clearGhostESP
S.updateGhostESP = updateGhostESP
S.cleanESPCache = cleanESPCache
S.origLight = origLight
S.applyFullBright = applyFullBright
S.restoreLight = restoreLight
S.fly = fly
S._flyHookActive = _flyHookActive
S._hrpHooked = _hrpHooked
S.disableGhostMode = disableGhostMode
S.disableFly = disableFly
S.hookHRP = hookHRP
S.ensureHRPHook = ensureHRPHook
S.enableFly = enableFly
S.sg = sg
S.HuntBanner = HuntBanner
S.HuntL = HuntL
S.WIN_W = WIN_W
S.vpY = vpY
S.WIN_H = WIN_H
S.Win = Win
S.winStroke = winStroke
S.TB = TB
S.tbFix = tbFix
S.TitleL = TitleL
S.SubL = SubL
S.makeUnload = makeUnload
S.CloseBtn = CloseBtn
S.gcam = gcam
S.CAM_SCRIPT_NAMES = CAM_SCRIPT_NAMES
S.disableGameCameraScripts = disableGameCameraScripts
S.restoreGameCameraScripts = restoreGameCameraScripts
S.enableGhostMode = enableGhostMode
S.Scroll = Scroll
S.Content = Content
S.CL = CL
S.sectionLabel = sectionLabel
S.makeToggle = makeToggle
S.makeButton = makeButton
S.FarmCard = FarmCard
S.KeybindCard = KeybindCard
S.KBLayout = KBLayout
S.makeKeybindRow = makeKeybindRow
S.QuestCard = QuestCard
S.QuestLayout = QuestLayout
S.questLabels = questLabels
S.updateQuests = updateQuests
S.GRCard = GRCard
S.SanityCard = SanityCard
S.SanityTitle = SanityTitle
S.SanityList = SanityList
S.SanLayout = SanLayout
S.sanPad = sanPad
S.sanityRows = sanityRows
S.getSanityColor = getSanityColor
S.updateSanityTracker = updateSanityTracker
S.EvCard = EvCard
S.EvLayout = EvLayout
S.FilterCard = FilterCard
S.FCLayout = FCLayout
S.GGrid = GGrid
S.GGL = GGL
S.StopBtn = StopBtn
S._espTimer = _espTimer
S._lastHunting = _lastHunting
S.traitLog = traitLog
S.traitCard = traitCard
S.traitVisible = traitVisible
S.traitListFrame = traitListFrame
S.TRAIT_MAX = TRAIT_MAX
S.addTraitLog = addTraitLog
S.TraitCard = TraitCard
S.traitHeader = traitHeader
S.traitHeaderFix = traitHeaderFix
S.traitTitle = traitTitle
S.traitToggleBtn = traitToggleBtn
S.traitBody = traitBody
S.traitLL = traitLL
S.traitEmptyLbl = traitEmptyLbl
S.traitPad = traitPad
S.setTraitVisible = setTraitVisible
S.TS = TS
S.initTraitDetection = initTraitDetection
S.TRAIT_GHOST_MAP = TRAIT_GHOST_MAP
S.markTrait = markTrait
S.hookGhostRoomLight = hookGhostRoomLight
S.hookSalt = hookSalt
return S