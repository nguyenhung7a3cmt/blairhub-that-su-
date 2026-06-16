-- BlairHub split chunk
local S = (...) or {}

-- bootstrap moved to main.lua

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Lighting     = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("ReplicatedStorage")
local lp           = Players.LocalPlayer

local C = {
    BG=Color3.fromRGB(8,8,14),       BG2=Color3.fromRGB(14,9,24),
    Card=Color3.fromRGB(16,12,26),   CardAlt=Color3.fromRGB(12,9,20),
    Stroke=Color3.fromRGB(70,35,130),StrokeDim=Color3.fromRGB(48,24,90),
    Accent=Color3.fromRGB(130,60,220),AccentDim=Color3.fromRGB(60,30,110),
    Text=Color3.fromRGB(220,210,235),TextDim=Color3.fromRGB(130,120,155),
    TextMuted=Color3.fromRGB(75,70,100),Green=Color3.fromRGB(55,220,100),
    Red=Color3.fromRGB(220,50,50),   Purple=Color3.fromRGB(195,145,255),
    HeaderText=Color3.fromRGB(90,55,150),SectionLine=Color3.fromRGB(38,20,72),
    HuntRed=Color3.fromRGB(215,48,30),HuntDark=Color3.fromRGB(120,18,18),
    FarmGreen=Color3.fromRGB(25,110,25),FarmRed=Color3.fromRGB(130,25,25),
    GhostHunt=Color3.fromRGB(255,30,30),GhostNormal=Color3.fromRGB(200,80,255),
    ItemGreen=Color3.fromRGB(60,220,100),ColdBlue=Color3.fromRGB(100,210,255),
    FlyBlue=Color3.fromRGB(80,200,255),FlyPurple=Color3.fromRGB(180,100,255),
    Yellow=Color3.fromRGB(255,220,60),Orange=Color3.fromRGB(255,200,80),
    ColdLight=Color3.fromRGB(160,200,240),
}

local EV_MAP = {
    ["EMF Level 5"]="EMF5",["Freezing Temperatures"]="FREEZE",
    ["Ghost Orb"]="ORB",["Ghost Writing"]="WRITING",
    ["Spirit Box"]="SBOX",["SLS Anomaly"]="SLS",["Ultraviolet"]="UV",
}
local EVIDENCE_INFO = {
    {key="EMF5",    label="EMF Level 5",          icon="E"},
    {key="FREEZE",  label="Freezing Temperatures", icon="F"},
    {key="ORB",     label="Ghost Orb",             icon="O"},
    {key="WRITING", label="Ghost Writing",         icon="W"},
    {key="SBOX",    label="Spirit Box",            icon="S"},
    {key="SLS",     label="SLS Anomaly",           icon="L"},
    {key="UV",      label="Ultraviolet",           icon="U"},
}
local GHOST_DB = {}
local GHOST_DB_SET = {} -- [OPT-3] Set lookup cache

local Config = {
    FullBright=false,GhostESP=false,ItemESP=false,HuntAlert=false,
    SpeedHack=false,SpeedValue=24,
    AutoHide=false,AutoFarm=false,FlyMode=false,GhostMode=false,
}
local KEYBINDS = {
    Fly = Enum.KeyCode.F,
    Ghost = Enum.KeyCode.Y,
    Trait = Enum.KeyCode.T,
}

-- Auto save/load config
local CONFIG_FILE = "BlairHub_config.json"
local function saveConfig()
    if not writefile then return end
    local data = {}
    for k,v in pairs(Config) do data[k]=v end
    data["__kb_Fly"]   = KEYBINDS.Fly.Name
    data["__kb_Ghost"] = KEYBINDS.Ghost.Name
    data["__kb_Trait"] = KEYBINDS.Trait.Name
    pcall(function() writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode(data)) end)
end
local function loadConfig()
    if not readfile or not isfile then return end
    if not isfile(CONFIG_FILE) then return end
    pcall(function()
        local data = game:GetService("HttpService"):JSONDecode(readfile(CONFIG_FILE))
        local skip = {FlyMode=true,GhostMode=true,AutoFarm=true}
        for k,v in pairs(data) do
            if k:sub(1,5)=="__kb_" then
                local bind = k:sub(6)
                local ok,kc = pcall(function() return Enum.KeyCode[v] end)
                if ok and kc then KEYBINDS[bind]=kc end
            elseif Config[k]~=nil and not skip[k] then
                Config[k]=v
            end
        end
    end)
end
loadConfig()
local detectedEvidence  = {}
local evidenceRefs      = {}
local ghostCells        = {}
S.ghostCountLbl = nil
S.ghostRoomLbl = nil
S.farmStatusLbl = nil
S.farmBtn = nil
local detectionConns    = {}
local AUTO_FARM         = {running=false}
S.evidenceMissCount = {}
local MISS_SKIP         = 3
S.sboxToken = {}

S.evidenceConfirmedAbsent = {}
local objectiveDoneTextCache = {}
local function normObjectiveText(s)
    s = tostring(s or "")
    s = s:gsub("^%s*%d+%.%s*", "")
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end
local function markObjectiveDoneText(txt)
    local k = normObjectiveText(txt)
    if k ~= "" then objectiveDoneTextCache[k] = true end
end
local function isObjectiveDoneText(txt)
    local k = normObjectiveText(txt)
    return k ~= "" and objectiveDoneTextCache[k] == true
end
pcall(function()
    local rem = RS:FindFirstChild("Remotes")
    local objDone = rem and rem:FindFirstChild("ObjectiveCompleteClient")
    if objDone and objDone:IsA("RemoteEvent") then
        objDone.OnClientEvent:Connect(function(...)
            local args = {...}
            local txt = args[1]
            if type(txt) == "string" then
                markObjectiveDoneText(txt)
                print("[ObjHook] done:", txt)
            end
        end)
    end
end)
local function recordMiss(k) S.evidenceMissCount[k]=(S.evidenceMissCount[k] or 0)+1 end
local function resetMissCounts() S.evidenceMissCount={}; S.evidenceConfirmedAbsent={} end
local function markAbsent(k) S.evidenceConfirmedAbsent[k]=true end
local function shouldSkip(k)
    if detectedEvidence[k] then return true end
    if (S.evidenceMissCount[k] or 0) >= MISS_SKIP then return true end
    local possible = {}
    for name, evSet in pairs(GHOST_DB_SET) do
        local eliminated = false
        for ev, det in pairs(detectedEvidence) do
            if det and not evSet[ev] then eliminated = true; break end
        end
        if not eliminated then table.insert(possible, name) end
    end
    if #possible <= 1 then return false end
    local hasIt, notHasIt = false, false
    for _, gname in ipairs(possible) do
        if GHOST_DB_SET[gname] and GHOST_DB_SET[gname][k] then
            hasIt = true
        else
            notHasIt = true
        end
        if hasIt and notHasIt then return false end
    end
    return true
end

local function getMap()   return workspace:FindFirstChild("Map") end
local function getItems() local m=getMap(); return m and m:FindFirstChild("Items") end
local function getZones() local m=getMap(); return m and m:FindFirstChild("Zones") end
local function getChar()  return lp.Character end
local function getBP()    return lp:FindFirstChild("Backpack") end

local function getAllESPItemRoots()
    local roots = {}
    local map = getMap()

    if map then
        local items = map:FindFirstChild("Items")
        if items then
            table.insert(roots, {
                root = items,
                deep = false,
            })
        end

        local cursedSpawns = map:FindFirstChild("CursedSpawns")
        if cursedSpawns then
            table.insert(roots, {
                root = cursedSpawns,
                deep = false,
            })
        end
    end

    -- Scan workspace top-level cho cursed objects (BooBooDoll, Spirit Board, v.v.)
    table.insert(roots, {
        root = workspace,
        deep = false,
        workspaceOnly = true, -- chá»‰ láº¥y direct children
    })

    return roots
end

local function getRemote(path)
    local node=RS:FindFirstChild("Remotes")
    if not node then return nil end
    for part in path:gmatch("[^%.]+") do
        node=node:FindFirstChild(part)
        if not node then return nil end
    end
    return node
end

local function loadGhostDB()
    if next(GHOST_DB) then
        -- Äáº£m báº£o GHOST_DB_SET luÃ´n Ä‘Æ°á»£c build náº¿u chÆ°a cÃ³
        if not next(GHOST_DB_SET) then
            for gname, evList in pairs(GHOST_DB) do
                local s = {}
                for _, ev in ipairs(evList) do s[ev] = true end
                GHOST_DB_SET[gname] = s
            end
        end
        return true
    end
    local done,result=false,nil
    task.spawn(function()
        local ok,res=pcall(function()
            return RS.Remotes.GetGhostInformation.GetGhostEvidences:InvokeServer()
        end)
        result=ok and res or nil; done=true
    end)
    local t=0
    while not done and t<6 do task.wait(0.1); t=t+0.1 end
    if type(result)~="table" or not next(result) then return false end
    local count=0
    for ghostName,evList in pairs(result) do
        GHOST_DB[ghostName]={}
        for _,evName in ipairs(evList) do
            local key=EV_MAP[evName]
            if key then table.insert(GHOST_DB[ghostName],key) end
        end
        count=count+1
    end
    print("[Blair v7.8] Ghost DB:",count,"ghosts")
    -- [OPT-3] Build Set lookup cho getPossibleGhosts/shouldSkip/updateGhostFilter
    GHOST_DB_SET = {}
    for gname, evList in pairs(GHOST_DB) do
        local s = {}
        for _, ev in ipairs(evList) do s[ev] = true end
        GHOST_DB_SET[gname] = s
    end
    return count>0
end

S.playerNamesCache = {}
local function refreshPlayerNames()
    S.playerNamesCache = {}
    for _, p in ipairs(Players:GetPlayers()) do
        S.playerNamesCache[p.Name] = true
    end
end
Players.PlayerAdded:Connect(function(p)
    S.playerNamesCache[p.Name] = true
end)
Players.PlayerRemoving:Connect(function(p)
    S.playerNamesCache[p.Name] = nil
end)

-- [OPT-1] findGhost cache + dirty flag
local _ghostCache = nil
local _ghostCacheDirty = true
workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") then _ghostCacheDirty = true end
end)
workspace.ChildRemoved:Connect(function(child)
    if child == _ghostCache then
        _ghostCache = nil
        _ghostCacheDirty = true
    end
end)

local function findGhost()
    if not _ghostCacheDirty and _ghostCache and _ghostCache.Parent == workspace then
        return _ghostCache
    end
    _ghostCacheDirty = false
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") and not S.playerNamesCache[v.Name]
        and v.Name ~= "CloneGhost" and v.Name ~= "IntroVan"
        and v:FindFirstChild("Hunting") then
            _ghostCache = v
            return v
        end
    end
    _ghostCache = nil
    return nil
end

-- [OPT-2] isHunting event-driven, O(1)
local _huntingValue = nil
local _isHuntingNow = false

local function _hookHuntingValue()
    local g = findGhost()
    if not g then _isHuntingNow = false; return end
    local hv = g:FindFirstChild("Hunting")
    if not hv then _isHuntingNow = false; return end
    if _huntingValue == hv then return end
    _huntingValue = hv
    _isHuntingNow = hv.Value == true
    hv:GetPropertyChangedSignal("Value"):Connect(function()
        _isHuntingNow = hv.Value == true
    end)
end

local function isHunting()
    local g = findGhost()
    local hv = g and g:FindFirstChild("Hunting")
    if hv ~= _huntingValue then _hookHuntingValue() end
    return _isHuntingNow
end

local tweenToPos -- forward declaration
local lastTPTime = 0
local function gaussian(mean, stddev)
    local u = math.max(math.random(), 1e-10)
    local v = math.random()
    return mean + stddev * math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v)
end

local function moveToPos(dest,label)
    if not dest then return false end
    return tweenToPos(dest, label, 50)
end

local function tweenTo(pos,yOff)
    if not pos then return end
    moveToPos(Vector3.new(pos.X,pos.Y+(yOff or 0),pos.Z),"tweenTo")
end

local function getOutsidePos()
    local Map=getMap()
    local van=Map and Map:FindFirstChild("Van")
    local vanMdl=van and van:FindFirstChild("Van")
    if vanMdl then
        local p=vanMdl:FindFirstChildWhichIsA("BasePart")
        if p then return p.Position+Vector3.new(0,0,14) end
    end
    return Vector3.new(0,5,0)
end

-- ============================================================================
-- [v7.9 FIX] Van Door â€” dÃ¹ng OpenVan BindableEvent (confirmed tá»« scan)
-- Bindables: OpenVan, VanOpened, VanClosed
S.vanDoorOpened = false
local function openVanDoor()
    if S.vanDoorOpened then return true end

    -- Method 1: Fire OpenVan BindableEvent (direct, no position needed, khÃ´ng cáº§n vanMdl)
    local openedViaBindable=false
    pcall(function()
        local bind=RS:FindFirstChild("Bindables")
        local openVan=bind and bind:FindFirstChild("OpenVan")
        if openVan then
            openVan:Fire()
            task.wait(0.8)
            openedViaBindable=true
            print("[VanDoor] Opened via OpenVan bindable")
        end
    end)

    if openedViaBindable then
        S.vanDoorOpened=true
        return true
    end

    -- Method 2: Fallback ProximityPrompt scan (cáº§n vanMdl)
    local Map=getMap()
    local van=Map and Map:FindFirstChild("Van")
    local vanMdl=van and van:FindFirstChild("Van")
    if not vanMdl then
        print("[VanDoor] OpenVan bindable failed + vanMdl not found")
        return false
    end

    local bestPrompt=nil
    local bestPart=nil
    for _,desc in ipairs(vanMdl:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local action=(desc.ActionText or ""):lower()
            local pname=(desc.Parent and desc.Parent.Name or ""):lower()
            if action:find("door") or action:find("open") or pname:find("door") or pname:find("van") then
                bestPrompt=desc; bestPart=desc.Parent; break
            end
        end
    end
    if not bestPrompt then
        for _,desc in ipairs(vanMdl:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                bestPrompt=desc; bestPart=desc.Parent; break
            end
        end
    end
    if not bestPrompt then
        print("[VanDoor] No prompt found â€” continuing anyway")
        S.vanDoorOpened=true
        return true
    end
    if bestPart and bestPart:IsA("BasePart") then
        moveToPos(bestPart.Position+Vector3.new(0,0,2),"van door")
        task.wait(0.4)
    end
    pcall(function()
        bestPrompt.MaxActivationDistance=32
        if fireproximityprompt then fireproximityprompt(bestPrompt) end
    end)
    task.wait(1.2)
    S.vanDoorOpened=true
    print("[VanDoor] Opened via prompt")
    return true
end

-- [OPT-6] getSortedRooms cache centers, chá»‰ rebuild khi Zones Ä‘á»•i
local _roomsCache = nil
local _roomsDirty = true

local function getSortedRooms()
    local Zones = getZones()
    if not Zones then return {} end

    if _roomsDirty or not _roomsCache then
        local rooms = {}
        for _, zone in ipairs(Zones:GetChildren()) do
            local tv = zone:FindFirstChild("_____Temperature")
            local excl = zone:FindFirstChild("Exclude")
            if tv and tv:IsA("NumberValue") and not (excl and excl.Value) then
                local sumPos = Vector3.zero
                local count = 0
                local minY = math.huge
                local maxY = -math.huge
                for _, v in ipairs(zone:GetDescendants()) do
                    if v:IsA("BasePart") then
                        local sz = v.Size
                        -- Chi tinh floor parts: nam gan day zone, face up
                        local isFloor = sz.X > 1 and sz.Z > 1 and sz.Y < 2
                        if isFloor then
                            sumPos = sumPos + v.Position
                            count = count + 1
                            if v.Position.Y < minY then minY = v.Position.Y end
                            if v.Position.Y > maxY then maxY = v.Position.Y end
                        end
                    end
                end
                -- Fallback: neu khong co floor part thi dung tat ca
                if count == 0 then
                    for _, v in ipairs(zone:GetDescendants()) do
                        if v:IsA("BasePart") then
                            sumPos = sumPos + v.Position
                            count = count + 1
                        end
                    end
                end
                if count > 0 then
                    local center = sumPos / count
                    local floorY = minY < math.huge and minY or center.Y
                    local safe = Vector3.new(center.X, floorY + 2.5, center.Z)
                    table.insert(rooms, {
                        name = zone.Name,
                        temp = tv.Value,
                        pos = safe,
                        center = center,
                        tempRef = tv,
                    })
                end
            end
        end
        _roomsCache = rooms
        _roomsDirty = false
    end

    -- Sort theo nhiá»‡t Ä‘á»™ hiá»‡n táº¡i
    table.sort(_roomsCache, function(a, b)
        local ta = a.tempRef and a.tempRef.Value or a.temp
        local tb = b.tempRef and b.tempRef.Value or b.temp
        return ta < tb
    end)
    for _, r in ipairs(_roomsCache) do
        if r.tempRef then r.temp = r.tempRef.Value end
    end

    return _roomsCache
end

tweenToPos = function(dest, label, speed)
    if not dest then return false end
    local char = getChar()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end
    local dist = (hrp.Position - dest).Magnitude
    if dist < 3 then return true end
    -- Anticheat: them delay nho truoc khi TP
    local now = tick()
    local minDelay = gaussian(0.3, 0.08)
    if now - lastTPTime < minDelay then
        task.wait(minDelay - (now - lastTPTime))
    end

    -- [v8.3] TP 1 phat + raycast tim san. Ignore character + Van model.
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local _excludeList = {char}
    pcall(function()
        local _map = getMap()
        local _van = _map and _map:FindFirstChild("Van")
        if _van then table.insert(_excludeList, _van) end
    end)
    rp.FilterDescendantsInstances = _excludeList
    rp.IgnoreWater = true

    print(string.format("[Move] %s (%.0fu) -> teleport", label or "pos", dist))

    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyPosition") or v:IsA("BodyGyro") then
            v:Destroy()
        end
    end

    -- TP vÃ o khoáº£ng khÃ´ng giá»¯a phÃ²ng (dest + 3 studs cao), khÃ´ng raycast
    -- Character tá»± rÆ¡i xuá»‘ng sÃ n â†’ server khÃ´ng reject
    local landing = dest + Vector3.new(0, 3, 0)
    hrp.CFrame = CFrame.new(landing)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    -- Chá» character rÆ¡i xuá»‘ng sÃ n tá»± nhiÃªn (tá»‘i Ä‘a 1.5s)
    hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Freefall)
    end
    task.wait(0.8)

    local charF = getChar()
    local hrpF = charF and charF:FindFirstChild("HumanoidRootPart")
    return hrpF and (hrpF.Position - dest).Magnitude < 25 or false
end

-- ============================================================================
-- [smartTP] Adaptive TP vá»›i raycast grid sampling + anticheat gaussian
-- ============================================================================
local function smartTP(dest, label)
    if not dest then return false end

    local fallbackMove = function(reason)
        print("[smartTP] " .. reason .. ", fallback")
        if tweenToPos then
            return tweenToPos(dest, label, 50)
        end
        local humFallback = getChar() and getChar():FindFirstChildOfClass("Humanoid")
        if humFallback then
            humFallback:MoveTo(dest)
            local t = 0
            repeat task.wait(0.25); t = t + 0.25
            until t >= 3 or (getChar() and getChar():FindFirstChild("HumanoidRootPart") and (getChar().HumanoidRootPart.Position - dest).Magnitude < 8)
            return true
        end
        return false
    end

    local now = tick()
    local cooldown = gaussian(4, 0.8)
    if now - lastTPTime < cooldown then
        local remaining = cooldown - (now - lastTPTime)
        print(string.format("[smartTP] Cooldown %.1fs - walking instead", remaining))
        local hum2 = getChar() and getChar():FindFirstChildOfClass("Humanoid")
        if hum2 then
            hum2:MoveTo(dest)
            local t = 0
            repeat task.wait(0.5); t = t + 0.5
            until t >= remaining or (getChar() and getChar():FindFirstChild("HumanoidRootPart") and (getChar().HumanoidRootPart.Position - dest).Magnitude < 8)
        end
        return true
    end

    local char = getChar()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {char}
    rp.IgnoreWater = true

    local dirs = {
        Vector3.new(1,0,0), Vector3.new(-1,0,0),
        Vector3.new(0,0,1), Vector3.new(0,0,-1),
    }
    local minWall = math.huge
    for _, d in ipairs(dirs) do
        local hit = workspace:Raycast(dest, d * 20, rp)
        local dist = hit and hit.Distance or 20
        if dist < minWall then minWall = dist end
    end
    local safe_radius = math.max(minWall - 1, 1)

    local hitUp = workspace:Raycast(dest, Vector3.new(0, 1, 0) * 20, rp)
    local room_height = hitUp and hitUp.Distance or 10
    local landingOffsetY = math.clamp(room_height - 2, 1.5, 3)

    local grid_step
    if safe_radius < 3 then grid_step = 0.5
    elseif safe_radius <= 6 then grid_step = 1.0
    else grid_step = 2.0 end

    local bestPoint = nil
    local bestScore = -math.huge
    local x = -safe_radius
    while x <= safe_radius do
        local z = -safe_radius
        while z <= safe_radius do
            local candidate = dest + Vector3.new(x, landingOffsetY + 5, z)
            local hitDown = workspace:Raycast(candidate, Vector3.new(0, -10, 0), rp)
            if hitDown then
                local normal = hitDown.Normal
                if normal.Y > 0.85 then
                    local landPos = hitDown.Position + Vector3.new(0, landingOffsetY, 0)
                    local distToTarget = (landPos - dest).Magnitude
                    local distToWall = math.min(safe_radius, minWall - math.sqrt(x*x + z*z))
                    local score = -distToTarget * 2 + distToWall
                    if score > bestScore then
                        bestScore = score
                        bestPoint = landPos
                    end
                end
            end
            z = z + grid_step
        end
        x = x + grid_step
    end

    if not bestPoint then
        return fallbackMove("No safe point")
    end

    local blocked = false
    local offsets = {Vector3.new(0,0,0), Vector3.new(0.5,0,0), Vector3.new(-0.5,0,0)}
    for _, off in ipairs(offsets) do
        local from = hrp.Position + off
        local dir = (bestPoint - from)
        local verify = workspace:Raycast(from, dir, rp)
        if verify and verify.Distance < dir.Magnitude - 1 then
            blocked = true
            break
        end
    end
    if blocked then
        return fallbackMove("Path blocked")
    end

    local jx = gaussian(0, 0.8)
    local jz = gaussian(0, 0.8)
    bestPoint = bestPoint + Vector3.new(jx, 0, jz)
    print(string.format("[smartTP] %s -> score=%.1f dist=%.0fu", label or "pos", bestScore, (hrp.Position - bestPoint).Magnitude))
    hrp.CFrame = CFrame.new(bestPoint)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    if hum then hum:ChangeState(Enum.HumanoidStateType.Freefall) end

    task.wait(math.max(0.05, gaussian(0.15, 0.03)))
    lastTPTime = tick()

    local hrpF = getChar() and getChar():FindFirstChild("HumanoidRootPart")
    return hrpF ~= nil
end

local function goToGhostRoom()
    -- [v8.3] Luon tele den diem an toan giua phong (khong cham tuong/do vat -> tranh anti-cheat keo ve Van)
    local rooms = getSortedRooms()
    if #rooms == 0 then
        print("[GoGhostRoom] Khong tim duoc phong nao!")
        return false, nil
    end

    -- Neu tim duoc ghost, uu tien phong chua ghost (theo khoang cach toi center)
    local ghost = findGhost()
    local target = rooms[1]
    if ghost then
        local a = ghost:FindFirstChild("HumanoidRootPart") or ghost:FindFirstChildWhichIsA("BasePart")
        if a then
            local best, bestDist = nil, math.huge
            for _, r in ipairs(rooms) do
                local c = r.center or r.pos
                local d = (c - a.Position).Magnitude
                if d < bestDist then bestDist = d; best = r end
            end
            if best then target = best end
        end
    end

    print(string.format("[GoGhostRoom] -> %s (%.1f C)", target.name, target.temp))
    smartTP(target.pos, target.name)
    return true, target.pos
end

-- ============================================================================
-- [v7.8] Inventory â€” 3 slot máº·c Ä‘á»‹nh, dÃ¹ng Slot1-5 ObjectValue Ä‘á»ƒ track
-- ============================================================================
local invRemote=nil
local function getInvRemote()
    if invRemote and invRemote.Parent then return invRemote end
    invRemote=getRemote("InventoryRemotes.Action")
    return invRemote
end

-- Äáº¿m sá»‘ tool Ä‘ang cÃ³ (BP + char)
local function getBPToolCount()
    local bp=getBP()
    if not bp then return 0 end
    local c=0
    for _,v in ipairs(bp:GetChildren()) do if v:IsA("Tool") then c=c+1 end end
    return c
end

local function getCharToolCount()
    local char=getChar()
    if not char then return 0 end
    local c=0
    for _,v in ipairs(char:GetChildren()) do if v:IsA("Tool") then c=c+1 end end
    return c
end

local function getTotalToolCount()
    return getBPToolCount() + getCharToolCount()
end

local function dropCurrentTool()
    local char=getChar()
    local hasEquipped=false
    if char then
        for _,v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") then hasEquipped=true; break end
        end
    end
    if not hasEquipped then
        local r0=getInvRemote()
        if r0 then pcall(function() r0:FireServer("Slot",1) end) end
        task.wait(0.4)
    end
    local r=getInvRemote()
    if r then pcall(function() r:FireServer("Drop") end) end
    task.wait(0.35)
end

-- Drop equipped tool (tool trong char)
local function dropEquipped()
    local char=getChar()
    if not char then return end
    for _,v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then
            dropCurrentTool()
            task.wait(0.2)
            return
        end
    end
end

local function getSlotIndex(name)
    local bp=getBP()
    if not bp then return nil end
    local nameLow=name:lower()
    local children=bp:GetChildren()
    for i,v in ipairs(children) do
        if v:IsA("Tool") and v.Name:lower():find(nameLow,1,true) then
            return i,v
        end
    end
    return nil,nil
end

local function findInInventory(name)
    local nameLow=name:lower()
    local char,bp=getChar(),getBP()
    for _,parent in ipairs({char,bp}) do
        if parent then
            for _,v in ipairs(parent:GetChildren()) do
                if v:IsA("Tool") and v.Name:lower():find(nameLow,1,true) then
                    return v,parent
                end
            end
        end
    end
    return nil,nil
end

local function hasInInventory(name) return findInInventory(name)~=nil end

local function getEquipped(name)
    local char=getChar()
    if not char then return nil end
    local nameLow=name:lower()
    for _,v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") and v.Name:lower():find(nameLow,1,true) then return v end
    end
    return nil
end

local function equipTool(name)
    if getEquipped(name) then return true end
    local r=getInvRemote()
    for attempt=1,4 do
        local idx,tool=getSlotIndex(name)
        if idx then
            if r then pcall(function() r:FireServer("Slot",idx) end) end
            task.wait(0.4)
            if getEquipped(name) then return true end
        else
            task.wait(0.3)
        end
    end
    return getEquipped(name)~=nil
end

local function pickupFromFloor(toolObj)
    if not toolObj or not toolObj.Parent then return false end
    local prompt = nil
    local handle = toolObj:FindFirstChild("Handle")
    if handle then prompt = handle:FindFirstChild("NewPickupPrompt") end
    if not prompt then
        for _, d in ipairs(toolObj:GetDescendants()) do
            if d:IsA("ProximityPrompt") then prompt = d; break end
        end
    end
    if not prompt then return false end
    local anchor = handle or toolObj:FindFirstChildWhichIsA("BasePart")
    if anchor then
        -- TP truc tiep den ngang Handle, KHONG raycast (tranh dap len noc Van)
        local char = getChar()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dst = anchor.Position + Vector3.new(0, 3, 1)
            hrp.CFrame = CFrame.new(dst) * (hrp.CFrame - hrp.CFrame.Position)
            hrp.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.15)
        end
    end
    local confirmed = false
    local listenConn = nil
    local toolCreated = getRemote("ToolCreated")
    if toolCreated then
        listenConn = toolCreated.OnClientEvent:Connect(function(n)
            if tostring(n) == toolObj.Name then confirmed = true end
        end)
    end
    pcall(function()
        pcall(function() prompt.MaxActivationDistance = 32 end)
        if fireproximityprompt then fireproximityprompt(prompt) end
    end)
    local deadline = tick() + 2.5
    while tick() < deadline and not confirmed do task.wait(0.05) end
    if listenConn then pcall(function() listenConn:Disconnect() end) end
    return confirmed or hasInInventory(toolObj.Name)
end

-- [v7.8 FIX] bringTool â€” kiá»ƒm tra slot trÆ°á»›c khi pick
-- 3 slot máº·c Ä‘á»‹nh: náº¿u Ä‘Ã£ Ä‘á»§ 3, drop 1 trÆ°á»›c khi pick
local function bringTool(name)
    if hasInInventory(name) then return true end

    -- Kiá»ƒm tra slot cÃ²n trá»‘ng khÃ´ng (max 3)
    local total=getTotalToolCount()
    if total>=3 then
        -- Drop tool Ä‘ang cáº§m (equipped) trÆ°á»›c
        dropEquipped()
        task.wait(0.3)
        -- Náº¿u váº«n cÃ²n 3, drop tool trong BP
        if getTotalToolCount()>=3 then
            dropCurrentTool()
            task.wait(0.3)
        end
    end

    local Items=getItems()
    if not Items then return false end
    local nameLow=name:lower()
    local toolObj=nil
    for _,v in ipairs(Items:GetChildren()) do
        if v.Name:lower():find(nameLow,1,true) then toolObj=v; break end
    end
    if not toolObj then return false end

    local confirmed=false
    local listenConn=nil
    local toolCreated=getRemote("ToolCreated")
    if toolCreated then
        listenConn=toolCreated.OnClientEvent:Connect(function(n)
            if tostring(n):lower():find(nameLow,1,true) then confirmed=true end
        end)
    end
    local ok=pickupFromFloor(toolObj)
    if not confirmed then
        local t=0
        while not confirmed and t<3 do task.wait(0.1); t=t+0.1 end
    end
    if listenConn then pcall(function() listenConn:Disconnect() end) end
    local result=confirmed or ok or hasInInventory(name)
    if result then print("[Inv] Picked up:",name) end
    return result
end

local function returnTool(name)
    local eq=getEquipped(name)
    if not eq then return end
    local bp=getBP()
    if bp then
        pcall(function() eq.Parent=bp end)
        task.wait(0.2)
        if getEquipped(name) then dropCurrentTool() end
    else
        dropCurrentTool()
    end
end

local function setFarmStatus(text,col)
    if S.farmStatusLbl then
        S.farmStatusLbl.Text=text
        S.farmStatusLbl.TextColor3=col or C.FlyBlue
    end
    print("[Farm]",text)
end

local function waitHuntOver(returnPos, returnLabel)
    if not isHunting() then return end
    setFarmStatus("HUNT! Fleeing outside...", C.HuntRed)
    moveToPos(getOutsidePos(), "outside")
    local huntDeadline = tick() + 120
    -- [OPT-7] dÃ¹ng _isHuntingNow (updated bá»Ÿi Changed event OPT-2), poll 0.2s
    while _isHuntingNow and _G.BlairHub and Config.AutoFarm and tick() < huntDeadline do
        task.wait(0.2)
    end
    task.wait(1)
    setFarmStatus("Hunt over â€” returning...", C.Green)
    if returnPos then moveToPos(returnPos, returnLabel or "room") end
end

local function safewait(t)
    local dead=tick()+t
    while tick()<dead and _G.BlairHub and Config.AutoFarm do task.wait(0.1) end
end

local function updateGhostFilter()
    local possible, total = 0, 0
    for name, evSet in pairs(GHOST_DB_SET) do
        total = total + 1
        local eliminated = false
        for ev, det in pairs(detectedEvidence) do
            if det and not evSet[ev] then eliminated = true; break end
        end
        if not eliminated then
            for ev, absent in pairs(S.evidenceConfirmedAbsent) do
                if absent and evSet[ev] then eliminated = true; break end
            end
        end
        local cell = ghostCells[name]
        if cell then
            local on = not eliminated
            TweenService:Create(cell.frame, TweenInfo.new(0.2), {
                BackgroundColor3 = on and Color3.fromRGB(28,14,50) or Color3.fromRGB(12,11,18)
            }):Play()
            cell.label.TextColor3 = on and C.Purple or Color3.fromRGB(42,38,55)
            if on then possible = possible + 1 end
        end
    end
    if S.ghostCountLbl then
        S.ghostCountLbl.Text = possible.." / "..tostring(total).." ghosts possible"
        S.ghostCountLbl.TextColor3 = possible <= 3 and C.Yellow or Color3.fromRGB(130,110,170)
    end
    return possible
end

local function setEvidence(key,detected)
    if detectedEvidence[key]==detected then return end
    detectedEvidence[key]=detected
    local refs=evidenceRefs[key]
    if refs then
        TweenService:Create(refs.dot,TweenInfo.new(0.3),{
            BackgroundColor3=detected and C.Green or Color3.fromRGB(45,42,65)
        }):Play()
        refs.status.Text=detected and "DETECTED" or "waiting..."
        refs.status.TextColor3=detected and C.Green or Color3.fromRGB(75,72,100)
    end
    updateGhostFilter()
end

local function resetEvidence()
    for _,ev in ipairs(EVIDENCE_INFO) do setEvidence(ev.key,false) end
    if S.ghostRoomLbl then
        S.ghostRoomLbl.Text="detecting..."
        S.ghostRoomLbl.TextColor3=Color3.fromRGB(85,82,115)
    end
end

local function getPossibleGhosts()
    local possible = {}
    for name, evSet in pairs(GHOST_DB_SET) do
        local eliminated = false
        for ev, det in pairs(detectedEvidence) do
            if det and not evSet[ev] then eliminated = true; break end
        end
        if not eliminated then
            for ev, absent in pairs(S.evidenceConfirmedAbsent) do
                if absent and evSet[ev] then eliminated = true; break end
            end
        end
        if not eliminated then table.insert(possible, name) end
    end
    table.sort(possible)
    return possible
end

local function getBestGuess()
    local best,bestScore=nil,-1
    local detList={}
    for ev,det in pairs(detectedEvidence) do if det then table.insert(detList,ev) end end
    if #detList==0 then return nil,0 end
    local possible=getPossibleGhosts()
    for _,name in ipairs(possible) do
        local evidences=GHOST_DB[name]
        local score=0
        for _,de in ipairs(detList) do
            for _,ge in ipairs(evidences) do if ge==de then score=score+1; break end end
        end
        if score>bestScore then bestScore=score; best=name end
    end
    return best,bestScore
end

local function clearDetectionConns()
    for _,c in ipairs(detectionConns) do pcall(function() c:Disconnect() end) end
    detectionConns={}
end
local function conn(c) table.insert(detectionConns,c) end

local function submitGuess(ghostName)
    setFarmStatus("Submitting: "..ghostName,C.Green)
    local r1=getRemote("SelectGhost1")
    if r1 then pcall(function() r1:FireServer(ghostName) end) end
    task.wait(0.3)
    local r2=getRemote("GhostTypeChosen")
    if r2 then pcall(function() r2:FireServer(ghostName) end) end
end

-- ============================================================================
-- [v7.8 FIX] leaveMatch â€” chá»‰ tween Ä‘áº¿n van, KHÃ”NG auto fire leave
-- Player tá»± báº¥m leave button
-- ============================================================================
local function goToVan()
    setFarmStatus("Done! Go to van to leave...",C.Green)
    local Map=getMap()
    local van=Map and Map:FindFirstChild("Van")
    local vanMdl=van and van:FindFirstChild("Van")
    if vanMdl then
        local leaveBtn=vanMdl:FindFirstChild("LeaveButton")
        local sw=leaveBtn and leaveBtn:FindFirstChild("LightSwitch")
        if sw and sw:IsA("BasePart") then
            moveToPos(sw.Position+Vector3.new(0,0,2),"van leave button")
            return
        end
        -- fallback: tween Ä‘áº¿n van position
        local p=vanMdl:FindFirstChildWhichIsA("BasePart")
        if p then moveToPos(p.Position+Vector3.new(0,0,3),"van") end
    end
end

-- ============================================================================
-- PASSIVE DETECTION
-- ============================================================================
local function startPassiveDetection(Map)
    local Zones=Map:FindFirstChild("Zones")
    local Items=Map:FindFirstChild("Items")

    local function watchPrints()
        local Prints=Map:FindFirstChild("Prints")
        if Prints then
            if #Prints:GetChildren()>0 then setEvidence("UV",true) end
            conn(Prints.ChildAdded:Connect(function() setEvidence("UV",true) end))
        end
        conn(Map.ChildAdded:Connect(function(c)
            if c.Name=="Prints" then
                if #c:GetChildren()>0 then setEvidence("UV",true) end
                conn(c.ChildAdded:Connect(function() setEvidence("UV",true) end))
            end
        end))
    end

    -- [OPT-10] watchOrbs hook cáº£ trÆ°á»ng há»£p folder Orbs táº¡o muá»™n
    local function watchOrbs()
        local function hookOrbs(orbs)
            if #orbs:GetChildren() > 0 then setEvidence("ORB", true) end
            conn(orbs.ChildAdded:Connect(function() setEvidence("ORB", true) end))
        end
        local Orbs = Map:FindFirstChild("Orbs")
        if Orbs then hookOrbs(Orbs) end
        conn(Map.ChildAdded:Connect(function(c)
            if c.Name == "Orbs" then hookOrbs(c) end
        end))
    end

    -- [OPT-4] watchFreeze event-driven, khÃ´ng poll 0.3s
    local function watchFreeze()
        if not Zones then return end
        local stableCount = 0
        local function checkTemp(val)
            val = tonumber(val)
            if not val then return end
            if val <= 0 then
                stableCount = stableCount + 1
                if stableCount >= 2 then setEvidence("FREEZE", true) end
            else
                stableCount = 0
            end
        end
        local function hookZone(zone)
            local tv = zone:FindFirstChild("_____Temperature")
            if not tv then return end
            checkTemp(tv.Value)
            conn(tv:GetPropertyChangedSignal("Value"):Connect(function()
                checkTemp(tv.Value)
            end))
        end
        for _, zone in ipairs(Zones:GetChildren()) do hookZone(zone) end
        conn(Zones.ChildAdded:Connect(hookZone))
    end

    local function watchEMF(parent)
        if not parent then return end
        pcall(function()
            local tool=parent:FindFirstChild("EMF Reader")
            if tool then
                local rlf=tool:FindFirstChild("RecentlyLevelFive")
                if rlf then
                    if rlf.Value then setEvidence("EMF5",true) end
                    conn(rlf.Changed:Connect(function(v) if v then setEvidence("EMF5",true) end end))
                end
            end
            conn(parent.ChildAdded:Connect(function(child)
                if child.Name=="EMF Reader" then
                    task.wait(0.2)
                    local rlf=child:FindFirstChild("RecentlyLevelFive")
                    if rlf then
                        conn(rlf.Changed:Connect(function(v) if v then setEvidence("EMF5",true) end end))
                    end
                end
            end))
        end)
    end

    local function watchWriting(parent)
        if not parent then return end
        pcall(function()
            local function probeBook(tool)
                if not tool or tool.Name ~= "Ghost Writing Book" then return end
                local w = tool:FindFirstChild("Written")
                if w and w.Value then setEvidence("WRITING",true) return end
                for _, d in ipairs(tool:GetDescendants()) do
                    if d:IsA("BoolValue") and (d.Name:lower():find("writ") or d.Name:lower():find("sign")) and d.Value then
                        setEvidence("WRITING",true) return
                    elseif d:IsA("StringValue") and (d.Name:lower():find("text") or d.Name:lower():find("page")) and tostring(d.Value) ~= "" then
                        setEvidence("WRITING",true) return
                    elseif (d:IsA("Decal") or d:IsA("Texture")) and tostring(d.Texture or "") ~= "" then
                        setEvidence("WRITING",true) return
                    end
                end
            end
            local tool=parent:FindFirstChild("Ghost Writing Book")
            if tool then
                probeBook(tool)
                local w=tool:FindFirstChild("Written")
                if w then conn(w.Changed:Connect(function(v) if v then setEvidence("WRITING",true) end end)) end
                conn(tool.DescendantAdded:Connect(function() probeBook(tool) end))
            end
            conn(parent.ChildAdded:Connect(function(child)
                if child.Name == "Ghost Writing Book" then
                    task.wait(0.2)
                    probeBook(child)
                    local w=child:FindFirstChild("Written")
                    if w then conn(w.Changed:Connect(function(v) if v then setEvidence("WRITING",true) end end)) end
                    conn(child.DescendantAdded:Connect(function() probeBook(child) end))
                end
            end))
        end)
    end

    local sboxHooked={}
    local function hookSpiritBoxPassive(sb)
        if not sb or sboxHooked[sb] then return end
        sboxHooked[sb]=true
        pcall(function()
            local folder=sb:FindFirstChild("GhostTalk")
            if folder then
                local function hookSound(sound)
                    if not sound:IsA("Sound") then return end
                    conn(sound:GetPropertyChangedSignal("Playing"):Connect(function()
                        if sound.Playing then
                            setEvidence("SBOX",true)
                            print("[Passive SBox] GhostTalk:",sound.Name)
                        end
                    end))
                end
                for _,s in ipairs(folder:GetChildren()) do hookSound(s) end
                conn(folder.ChildAdded:Connect(hookSound))
            end
        end)
    end

    local function watchSBoxPassive()
        local function scan(parent)
            if not parent then return end
            pcall(function()
                local sb=parent:FindFirstChild("Spirit Box")
                if sb then hookSpiritBoxPassive(sb) end
                conn(parent.ChildAdded:Connect(function(c)
                    if c.Name=="Spirit Box" then
                        task.wait(0.1); hookSpiritBoxPassive(c)
                    end
                end))
            end)
        end
        -- Chá»‰ hook SBox khi player Ä‘ang cáº§m/mang, KHÃ”NG hook khi á»Ÿ Items (trÃªn sÃ n)
        scan(getChar()); scan(getBP())
        conn(lp.CharacterAdded:Connect(function(char)
            task.wait(0.5); scan(char); scan(getBP())
        end))
    end

    local function watchSLSPassive()
        task.spawn(function()
            while _G.BlairHub and Map.Parent do
                pcall(function()
                    local char=getChar()
                    if not char then return end
                    local ghost=findGhost()
                    if ghost then
                        local hl=ghost:FindFirstChild("Highlight")
                        if hl and hl.Enabled then
                            local slsCam=char:FindFirstChild("SLS Camera")
                            if slsCam then setEvidence("SLS",true) end
                        end
                    end
                end)
                task.wait(0.4)
            end
        end)
    end

    -- [OPT-5] watchRoomDisplay event-driven, khÃ´ng poll 0.5s
    local function watchRoomDisplay()
        if not Zones or not S.ghostRoomLbl then return end
        local function refresh()
            if not S.ghostRoomLbl then return end
            local coldName, coldTemp = "?", 100
            for _, zone in ipairs(Zones:GetChildren()) do
                local tv = zone:FindFirstChild("_____Temperature")
                local excl = zone:FindFirstChild("Exclude")
                if tv and tv.Value < coldTemp and not (excl and excl.Value) then
                    coldTemp = tv.Value
                    coldName = zone.Name
                end
            end
            if coldTemp < 18 then
                S.ghostRoomLbl.Text = coldName.."  ("..math.floor(coldTemp*10)/10 .." C)"
                S.ghostRoomLbl.TextColor3 = coldTemp < 3 and C.ColdBlue or C.ColdLight
            else
                S.ghostRoomLbl.Text = "detecting..."
                S.ghostRoomLbl.TextColor3 = Color3.fromRGB(85, 82, 115)
            end
        end
        local function hookZone(zone)
            local tv = zone:FindFirstChild("_____Temperature")
            if tv then
                conn(tv:GetPropertyChangedSignal("Value"):Connect(refresh))
            end
        end
        for _, zone in ipairs(Zones:GetChildren()) do hookZone(zone) end
        conn(Zones.ChildAdded:Connect(hookZone))
        refresh()
    end

    watchPrints(); watchOrbs(); watchFreeze()
    watchEMF(Items); watchEMF(getBP()); watchEMF(getChar())
    watchWriting(Items); watchWriting(getBP()); watchWriting(getChar())
    watchSBoxPassive(); watchSLSPassive(); watchRoomDisplay()
    conn(lp.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        watchEMF(char); watchEMF(getBP())
        watchWriting(char); watchWriting(getBP())
    end))
end

task.spawn(function()
    loadGhostDB()
    local Map=getMap()
    if Map then task.wait(1.5); startPassiveDetection(Map) end
    workspace.ChildAdded:Connect(function(child)
        if child.Name~="Map" or not _G.BlairHub then return end
        S.vanDoorOpened=false -- reset khi vÃ o map má»›i
        _ghostCache = nil; _ghostCacheDirty = true  -- [OPT-1] reset ghost cache
        _roomsCache = nil; _roomsDirty = true       -- [OPT-6] reset rooms cache
        task.wait(1.5)
        clearDetectionConns(); resetEvidence()
        refreshPlayerNames()
        startPassiveDetection(child)
    end)
    workspace.ChildRemoved:Connect(function(child)
        if child.Name~="Map" then return end
        clearDetectionConns(); resetEvidence()
        S.vanDoorOpened=false
        _ghostCache = nil; _ghostCacheDirty = true
        _roomsCache = nil; _roomsDirty = true
    end)
end)

-- ============================================================================
-- [v7.8 FIX] checkEMF â€” wait equip + wait remote replicate Ä‘Ãºng cÃ¡ch
-- EMF á»Ÿ BP, cáº§n equipTool trÆ°á»›c, chá» char nháº­n, chá» EMFRemote replicate
-- ============================================================================

S.Players = Players
S.RunService = RunService
S.Lighting = Lighting
S.TweenService = TweenService
S.UIS = UIS
S.RS = RS
S.lp = lp
S.C = C
S.EV_MAP = EV_MAP
S.EVIDENCE_INFO = EVIDENCE_INFO
S.GHOST_DB = GHOST_DB
S.GHOST_DB_SET = GHOST_DB_SET
S.saveConfig = saveConfig
S.loadConfig = loadConfig
S.Config = Config
S.KEYBINDS = KEYBINDS
S.detectedEvidence = detectedEvidence
S.evidenceRefs = evidenceRefs
S.ghostCells = ghostCells
S.detectionConns = detectionConns
S.AUTO_FARM = AUTO_FARM
S.MISS_SKIP = MISS_SKIP
S.recordMiss = recordMiss
S.resetMissCounts = resetMissCounts
S.markAbsent = markAbsent
S.shouldSkip = shouldSkip
S.getMap = getMap
S.getItems = getItems
S.getZones = getZones
S.getChar = getChar
S.getBP = getBP
S.getAllESPItemRoots = getAllESPItemRoots
S.getRemote = getRemote
S.loadGhostDB = loadGhostDB
S.refreshPlayerNames = refreshPlayerNames
S.findGhost = findGhost
S.isHunting = isHunting
S.tweenToPos = tweenToPos
S.moveToPos = moveToPos
S.tweenTo = tweenTo
S.getOutsidePos = getOutsidePos
S.openVanDoor = openVanDoor
S.getSortedRooms = getSortedRooms
S.lastTPTime = lastTPTime
S.gaussian = gaussian
S.smartTP = smartTP
S.goToGhostRoom = goToGhostRoom
S.invRemote = invRemote
S.getInvRemote = getInvRemote
S.getBPToolCount = getBPToolCount
S.getCharToolCount = getCharToolCount
S.getTotalToolCount = getTotalToolCount
S.dropCurrentTool = dropCurrentTool
S.dropEquipped = dropEquipped
S.getSlotIndex = getSlotIndex
S.findInInventory = findInInventory
S.hasInInventory = hasInInventory
S.getEquipped = getEquipped
S.equipTool = equipTool
S.pickupFromFloor = pickupFromFloor
S.bringTool = bringTool
S.returnTool = returnTool
S.setFarmStatus = setFarmStatus
S.waitHuntOver = waitHuntOver
S.safewait = safewait
S.updateGhostFilter = updateGhostFilter
S.setEvidence = setEvidence
S.resetEvidence = resetEvidence
S.getPossibleGhosts = getPossibleGhosts
S.getBestGuess = getBestGuess
S.clearDetectionConns = clearDetectionConns
S.conn = conn
S.submitGuess = submitGuess
S.goToVan = goToVan
S.startPassiveDetection = startPassiveDetection
return S

S.markObjectiveDoneText = markObjectiveDoneText
S.isObjectiveDoneText = isObjectiveDoneText
