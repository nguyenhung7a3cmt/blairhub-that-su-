-- BlairHub split chunk
local S = (...) or {}
local RS = S.RS
local C = S.C
local EVIDENCE_INFO = S.EVIDENCE_INFO
local Config = S.Config
local detectedEvidence = S.detectedEvidence
local AUTO_FARM = S.AUTO_FARM
local MISS_SKIP = S.MISS_SKIP
local recordMiss = S.recordMiss
local resetMissCounts = S.resetMissCounts
local markAbsent = S.markAbsent
local shouldSkip = S.shouldSkip
local getMap = S.getMap
local getItems = S.getItems
local getZones = S.getZones
local getChar = S.getChar
local loadGhostDB = S.loadGhostDB
local refreshPlayerNames = S.refreshPlayerNames
local findGhost = S.findGhost
local isHunting = S.isHunting
local tweenToPos = S.tweenToPos
local moveToPos = S.moveToPos
local openVanDoor = S.openVanDoor
local getSortedRooms = S.getSortedRooms
local goToGhostRoom = S.goToGhostRoom
local getTotalToolCount = S.getTotalToolCount
local dropCurrentTool = S.dropCurrentTool
local hasInInventory = S.hasInInventory
local getEquipped = S.getEquipped
local equipTool = S.equipTool
local bringTool = S.bringTool
local returnTool = S.returnTool
local setFarmStatus = S.setFarmStatus
local waitHuntOver = S.waitHuntOver
local safewait = S.safewait
local setEvidence = S.setEvidence
local resetEvidence = S.resetEvidence
local getPossibleGhosts = S.getPossibleGhosts
local getBestGuess = S.getBestGuess
local submitGuess = S.submitGuess
local goToVan = S.goToVan

local function checkEMF(roomPos,roomName)
    if detectedEvidence["EMF5"] then return end
    setFarmStatus("EMF: equipping...",C.Yellow)

    -- Đảm bảo có tool trong inventory
    if not hasInInventory("EMF Reader") then
        setFarmStatus("EMF: not in inventory",C.TextMuted); return
    end

    -- Equip tool vào character
    if not equipTool("EMF Reader") then
        setFarmStatus("EMF: equip failed",C.Red); return
    end

    -- Chờ tool thực sự replicate vào character (quan trọng!)
    local eq=nil
    local waitT=tick()
    repeat
        task.wait(0.15)
        eq=getEquipped("EMF Reader")
    until eq or tick()-waitT>4

    if not eq then
        setFarmStatus("EMF: char replicate timeout",C.Red)
        return
    end
    print("[EMF] Tool in char OK:",eq.Name)

    -- Chờ EMFRemote replicate vào tool (quan trọng!)
    local emfRemote=nil
    local waitR=tick()
    repeat
        task.wait(0.15)
        emfRemote=eq:FindFirstChild("EMFRemote")
        if not emfRemote then
            eq=getEquipped("EMF Reader")
            if eq then emfRemote=eq:FindFirstChild("EMFRemote") end
        end
    until emfRemote or tick()-waitR>4

    if not emfRemote then
        setFarmStatus("EMF: remote timeout",C.Red)
        print("[EMF] Children after wait:",eq and eq:GetChildren() or "nil")
        return
    end

    -- Kích hoạt EMF
    pcall(function() emfRemote:FireServer(true) end)
    setFarmStatus("EMF: scanning...",C.Yellow)
    print("[EMF] Remote activated OK")

    local deadline=tick()+22
    while tick()<deadline and _G.BlairHub and Config.AutoFarm do
        if isHunting() then
            pcall(function() if emfRemote then emfRemote:FireServer(false) end end)
            waitHuntOver(roomPos,roomName)
            -- Re-equip sau hunt
            if not equipTool("EMF Reader") then return end
            local wt=tick()
            repeat task.wait(0.15); eq=getEquipped("EMF Reader") until eq or tick()-wt>3
            if not eq then return end
            local wr=tick()
            repeat task.wait(0.15); emfRemote=eq:FindFirstChild("EMFRemote") until emfRemote or tick()-wr>3
            if emfRemote then pcall(function() emfRemote:FireServer(true) end) end
            deadline=tick()+14
        end

        eq=getEquipped("EMF Reader")
        if eq then
            local rlf=eq:FindFirstChild("RecentlyLevelFive")
            if rlf and rlf.Value then
                setEvidence("EMF5",true)
                setFarmStatus("EMF5 DETECTED!",C.Yellow)
                pcall(function()
                    local r=eq:FindFirstChild("EMFRemote")
                    if r then r:FireServer(false) end
                end)
                returnTool("EMF Reader"); return
            end
        end
        task.wait(0.2)
    end

    pcall(function() if emfRemote then emfRemote:FireServer(false) end end)
    recordMiss("EMF5")
    markAbsent("EMF5")
    returnTool("EMF Reader")
    setFarmStatus("EMF: no level 5",C.TextMuted)
end

local function checkWriting(roomPos,roomName)
    if detectedEvidence["WRITING"] then return end
    setFarmStatus("Writing: checking...",C.Orange)
    if not hasInInventory("Ghost Writing Book") then return end
    if not equipTool("Ghost Writing Book") then return end

    -- Chờ replicate
    local eq=nil
    local wt=tick()
    repeat task.wait(0.15); eq=getEquipped("Ghost Writing Book") until eq or tick()-wt>3
    if not eq then return end

    -- Mobile flag
    pcall(function()
        local r=eq:FindFirstChild("Mobile")
        if r then r:FireServer("IsMobile",false) end
    end)

    local deadline=tick()+22
    while tick()<deadline and _G.BlairHub and Config.AutoFarm do
        if isHunting() then
            waitHuntOver(roomPos,roomName)
            if not equipTool("Ghost Writing Book") then return end
            deadline=tick()+12
        end
        eq=getEquipped("Ghost Writing Book")
        if eq then
            local w=eq:FindFirstChild("Written")
            if w and w.Value then
                setEvidence("WRITING",true)
                setFarmStatus("WRITING DETECTED!",C.Orange)
                returnTool("Ghost Writing Book"); return
            end
        end
        local Items2=getItems()
        if Items2 then
            local book=Items2:FindFirstChild("Ghost Writing Book")
            if book then
                local w=book:FindFirstChild("Written")
                if w and w.Value then
                    setEvidence("WRITING",true)
                    setFarmStatus("WRITING DETECTED (floor)!",C.Orange)
                    returnTool("Ghost Writing Book"); return
                end
            end
        end
        task.wait(0.2)
    end
    recordMiss("WRITING")
    markAbsent("WRITING")
    returnTool("Ghost Writing Book")
    setFarmStatus("Writing: no response",C.TextMuted)
end

local function checkSLS(roomPos,roomName)
    if detectedEvidence["SLS"] then return end
    setFarmStatus("SLS: equipping...",C.Orange)

    local function ensureSLS()
        if getEquipped("SLS Camera") then return true end
        if not hasInInventory("SLS Camera") then return false end
        return equipTool("SLS Camera")
    end

    if not ensureSLS() then
        setFarmStatus("SLS Camera not found",C.TextMuted)
        recordMiss("SLS")
        return
    end
    task.wait(0.8)

    local ghost=findGhost()
    if ghost then
        local anchor=ghost:FindFirstChildWhichIsA("BasePart")
        if anchor then
            local targetPos=anchor.Position+Vector3.new(math.random(-5,5),0,8)
            moveToPos(targetPos,"SLS position")
            task.wait(0.3)
        end
    end

    local function faceGhost()
        pcall(function()
            local g=findGhost()
            local anchor=g and g:FindFirstChildWhichIsA("BasePart")
            local hrp=getChar() and getChar():FindFirstChild("HumanoidRootPart")
            if anchor and hrp then
                workspace.CurrentCamera.CFrame=CFrame.lookAt(
                    hrp.Position+Vector3.new(0,1.5,0),anchor.Position)
            end
        end)
    end

    local function findOverlay()
        local char=getChar()
        if not char then return nil end
        local cam=char:FindFirstChild("SLS Camera")
        if not cam then return nil end
        local overlay=nil
        pcall(function() overlay=cam:FindFirstChild("AnomalyOverlay",true) end)
        if not overlay then
            pcall(function()
                local base=cam:FindFirstChild("Base")
                local screen=base and base:FindFirstChild("Screen")
                local sg2=screen and screen:FindFirstChild("SurfaceGui")
                local ui=sg2 and sg2:FindFirstChild("SLSCameraUi")
                if ui then overlay=ui:FindFirstChild("AnomalyOverlay",true) end
            end)
        end
        return overlay
    end

    local slsGhostDetected=false
    local slsGhostConn=workspace.ChildAdded:Connect(function(child)
        if child.Name=="SLS_GHOST" then slsGhostDetected=true end
    end)
    if workspace:FindFirstChild("SLS_GHOST") then slsGhostDetected=true end

    -- Hook DANGER sound trong SLS Camera
    pcall(function()
        local eq=getEquipped("SLS Camera")
        if not eq then return end
        local danger=eq:FindFirstChild("DANGER")
        if danger and danger:IsA("Sound") then
            danger:GetPropertyChangedSignal("Playing"):Connect(function()
                if danger.Playing then
                    slsGhostDetected=true
                    print("[SLS] DANGER sound played")
                end
            end)
            print("[SLS] DANGER sound hooked")
        end
    end)
    faceGhost()
    setFarmStatus("SLS: watching...",C.Orange)

    local deadline=tick()+20
    local faceTimer=tick()
    local reequipTimer=tick()

    while tick()<deadline and _G.BlairHub and Config.AutoFarm do
        if isHunting() then
            slsGhostConn:Disconnect()
            waitHuntOver(roomPos,roomName)
            if not ensureSLS() then return end
            slsGhostDetected=workspace:FindFirstChild("SLS_GHOST") and true or false
            slsGhostConn=workspace.ChildAdded:Connect(function(child)
                if child.Name=="SLS_GHOST" then slsGhostDetected=true end
            end)
            faceGhost(); deadline=tick()+12
            faceTimer=tick(); reequipTimer=tick()
        end
        if tick()-faceTimer>=0.8 then faceGhost(); faceTimer=tick() end
        if tick()-reequipTimer>=2 then
            if not getEquipped("SLS Camera") then
                setFarmStatus("SLS: re-equipping...",C.Orange)
                if not ensureSLS() then break end
                faceGhost()
            end
            reequipTimer=tick()
        end
        if slsGhostDetected then
            setEvidence("SLS",true)
            setFarmStatus("SLS DETECTED!",C.Orange)
            pcall(function() slsGhostConn:Disconnect() end)
            returnTool("SLS Camera"); return
        end
        local overlay=findOverlay()
        if overlay and overlay.Visible then
            setEvidence("SLS",true)
            setFarmStatus("SLS DETECTED! (overlay)",C.Orange)
            pcall(function() slsGhostConn:Disconnect() end)
            returnTool("SLS Camera"); return
        end
        task.wait(0.2)
    end
    pcall(function() slsGhostConn:Disconnect() end)
    recordMiss("SLS")
    markAbsent("SLS")
    returnTool("SLS Camera")
    setFarmStatus("SLS: no anomaly",C.TextMuted)
end

-- ============================================================================
-- checkSBox — SpiritBoxError detect
-- ============================================================================
local function checkSBox(roomPos,roomName)
    if detectedEvidence["SBOX"] then return end
    setFarmStatus("Spirit Box: equipping...",C.FlyBlue)

    local function ensureSBox()
        if getEquipped("Spirit Box") then return true end
        if not hasInInventory("Spirit Box") then return false end
        return equipTool("Spirit Box")
    end

    if not ensureSBox() then
        setFarmStatus("Spirit Box not found",C.TextMuted); return
    end
    task.wait(0.5)

    local ghost=findGhost()
    if ghost then
        local anchor=ghost:FindFirstChildWhichIsA("BasePart")
        if anchor then
            moveToPos(anchor.Position+Vector3.new(math.random(-4,4),0,math.random(-4,4)),"SBox near ghost")
            task.wait(0.3)
            if not ensureSBox() then return end
        end
    end

    local detected=false
    local soundConns={}
    local function hookSounds()
        local eq=getEquipped("Spirit Box")
        if not eq then return end
        local folder=eq:FindFirstChild("GhostTalk")
        if not folder then return end
        for _,sound in ipairs(folder:GetChildren()) do
            if sound:IsA("Sound") then
                table.insert(soundConns,sound:GetPropertyChangedSignal("Playing"):Connect(function()
                    if sound.Playing then detected=true; print("[SBox] GhostTalk:",sound.Name) end
                end))
            end
        end
        table.insert(soundConns,folder.ChildAdded:Connect(function(s)
            if s:IsA("Sound") then
                table.insert(soundConns,s:GetPropertyChangedSignal("Playing"):Connect(function()
                    if s.Playing then detected=true end
                end))
            end
        end))
        print("[SBox] Hooked",#folder:GetChildren(),"sounds")
    end
    -- Hook thêm ProximitySFX (Close/Near/NextToYou = ghost gần)
    pcall(function()
        local eq=getEquipped("Spirit Box")
        if not eq then return end
        local prox=eq:FindFirstChild("ProximitySFX")
        if not prox then return end
        for _,snd in ipairs(prox:GetChildren()) do
            if snd:IsA("Sound") then
                local n=snd.Name:lower()
                if n=="close" or n=="near" or n=="nexttoyou" or n=="rightbyyou" then
                    table.insert(soundConns,snd:GetPropertyChangedSignal("Playing"):Connect(function()
                        if snd.Playing then
                            detected=true
                            print("[SBox] ProximitySFX:",snd.Name)
                        end
                    end))
                end
            end
        end
        print("[SBox] Hooked ProximitySFX OK")
    end)
    hookSounds()

    local function cleanSoundConns()
        for _,c in ipairs(soundConns) do pcall(function() c:Disconnect() end) end
        soundConns={}
    end

    local function askAndCheck(btn)
        local eq=getEquipped("Spirit Box")
        local aq=eq and eq:FindFirstChild("AskQuestion")
        if not aq then return false end

        local g=findGhost()
        local hrp=getChar() and getChar():FindFirstChild("HumanoidRootPart")
        local anchor=g and g:FindFirstChildWhichIsA("BasePart")
        if hrp and anchor then
            local dist=(hrp.Position-anchor.Position).Magnitude
            if dist>14 then
                moveToPos(anchor.Position+Vector3.new(math.random(-4,4),0,math.random(-4,4)),"approach ghost")
                task.wait(0.3)
                if not ensureSBox() then return false end
                eq=getEquipped("Spirit Box")
                aq=eq and eq:FindFirstChild("AskQuestion")
                if not aq then return false end
            end
        end

        local gotError=false
        local errorConn=nil
        local sboxErr=eq:FindFirstChild("SpiritBoxError")
        if sboxErr and sboxErr:IsA("RemoteEvent") then
            errorConn=sboxErr.OnClientEvent:Connect(function() gotError=true end)
        else
            print("[SBox] Warning: SpiritBoxError not found, using sound only")
            pcall(function() aq:FireServer(btn) end)
            local ws=tick()
            while tick()-ws<2.2 and not detected do task.wait(0.08) end
            return detected
        end

        pcall(function() aq:FireServer(btn) end)
        print("[SBox] Asked:",btn)

        local waitStart=tick()
        while tick()-waitStart<2.2 and not gotError and not detected do
            task.wait(0.08)
        end
        if errorConn then pcall(function() errorConn:Disconnect() end) end

        if detected then return true end
        if not gotError then
            print("[SBox] No SpiritBoxError → ghost responded!")
            return true
        end
        print("[SBox] SpiritBoxError received → no response")
        return false
    end

    local myToken={}
    S.sboxToken=myToken
    setFarmStatus("Spirit Box: asking ghost...",C.FlyBlue)

    local deadline=tick()+32
    local reequipTimer=tick()
    local askCount=0

    while tick()<deadline and not detected and _G.BlairHub and Config.AutoFarm do
        if S.sboxToken~=myToken then break end

        if isHunting() then
            cleanSoundConns()
            waitHuntOver(roomPos,roomName)
            if not ensureSBox() then break end
            hookSounds()
            myToken={}; S.sboxToken=myToken
            deadline=tick()+22
            reequipTimer=tick()
        end

        if tick()-reequipTimer>=2.5 then
            if not getEquipped("Spirit Box") then
                setFarmStatus("SBox: re-equipping...",C.FlyBlue)
                if not ensureSBox() then break end
                cleanSoundConns(); hookSounds()
            end
            reequipTimer=tick()
        end

        askCount=askCount+1
        setFarmStatus(string.format("Spirit Box: ask #%d...",askCount),C.FlyBlue)
        local btn=(askCount%2==1) and "ButtonA" or "ButtonB"
        local responded=askAndCheck(btn)
        if responded then detected=true; break end
        safewait(1.5)
    end

    S.sboxToken={}
    cleanSoundConns()

    if detected then
        setEvidence("SBOX",true)
        setFarmStatus("SPIRIT BOX DETECTED!",C.FlyBlue)
    else
        recordMiss("SBOX")
        if askCount>0 then markAbsent("SBOX") end
        setFarmStatus("SBox: no response",C.TextMuted)
    end
    returnTool("Spirit Box")
end

-- ============================================================================
-- [v8.2] Do All Quests — handler riêng cho từng objective (phương án A)
-- Mỗi objective trên Whiteboard có 1 BoolValue HasCompleted để biết đã xong.
-- Tùy nội dung objective mà dispatch sang handler tương ứng.
-- ============================================================================
local function findObjectivesFolder()
    local Map = getMap()
    if not Map then return nil end
    local van = Map:FindFirstChild("Van")
    if not van then return nil end
    local vanMdl = van:FindFirstChild("Van")
    local screens = van:FindFirstChild("Screens") or (vanMdl and vanMdl:FindFirstChild("Screens"))
    local wb = screens and screens:FindFirstChild("Whiteboard")
    local sg2 = wb and wb:FindFirstChild("SurfaceGui")
    local fr = sg2 and sg2:FindFirstChild("Frame")
    return fr and fr:FindFirstChild("Objectives")
end

-- Quay camera nhìn vào part (để chụp ảnh đúng subject)
local function lookAtPart(targetPart)
    pcall(function()
        local hrp = getChar() and getChar():FindFirstChild("HumanoidRootPart")
        if hrp and targetPart then
            workspace.CurrentCamera.CFrame = CFrame.lookAt(
                hrp.Position + Vector3.new(0, 1.5, 0), targetPart.Position)
        end
    end)
end

-- Chụp ảnh: equip Photo Camera, tới gần subject, nhắm vào và fire TakePhoto
local function objPhoto(subjectPart, label)
    if not subjectPart then return false end
    if not (hasInInventory("Photo Camera") or getEquipped("Photo Camera")) then
        if not bringTool("Photo Camera") then return false end
    end
    if not equipTool("Photo Camera") then return false end
    moveToPos(subjectPart.Position + Vector3.new(0, 0, 8), label or "photo subject")
    task.wait(0.3)
    local takePhoto = nil
    pcall(function()
        local svc = RS:FindFirstChild("PhotoCameraService")
        local ev = svc and svc:FindFirstChild("Events")
        takePhoto = ev and ev:FindFirstChild("TakePhoto")
    end)
    for _ = 1, 5 do
        if not _G.BlairHub then break end
        lookAtPart(subjectPart)
        task.wait(0.15)
        pcall(function() if takePhoto then takePhoto:InvokeServer() end end)
        task.wait(0.4)
    end
    returnTool("Photo Camera")
    return true
end

-- Thermometer dưới ngưỡng nhiệt: equip Thermometer, tới phòng lạnh nhất, đợi IsFreezing
local function objThermometer(deadline)
    if not (hasInInventory("Thermometer") or getEquipped("Thermometer")) then
        if not bringTool("Thermometer") then return false end
    end
    if not equipTool("Thermometer") then return false end
    local rooms = getSortedRooms()
    if #rooms > 0 then moveToPos(rooms[1].pos, "coldest room") end
    task.wait(0.5)
    while tick() < deadline and _G.BlairHub do
        local eq = getEquipped("Thermometer")
        local frz = eq and eq:FindFirstChild("IsFreezing")
        if frz and frz.Value then return true end
        local items = getItems()
        local t2 = items and items:FindFirstChild("Thermometer")
        local frz2 = t2 and t2:FindFirstChild("IsFreezing")
        if frz2 and frz2.Value then return true end
        task.wait(0.3)
    end
    return false
end

-- Tim Boo-Boo Doll trong workspace (Workspace.BooBooDoll hoac trong Items/CursedSpawns)
local function findBooBoo()
    local boo = workspace:FindFirstChild("BooBooDoll")
    if boo then return boo end
    local items = getItems()
    if items then
        local p = items:FindFirstChild("The Panda") or items:FindFirstChild("BooBooDoll")
        if p then return p end
    end
    return nil
end

-- Lay part dai dien cua 1 object (BasePart hoac con BasePart)
local function partOf(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChildWhichIsA("BasePart")
end

-- Fire moi ProximityPrompt cua 1 object (dung cho free/pickup/use)
local function firePromptsOf(obj)
    if not obj then return false end
    local fired = false
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            pcall(function()
                d.MaxActivationDistance = 32
                d.HoldDuration = 0
                if fireproximityprompt then fireproximityprompt(d); fired = true end
            end)
        end
    end
    -- prompt co the o chinh obj
    if obj:IsA("BasePart") then
        for _, d in ipairs(obj:GetChildren()) do
            if d:IsA("ProximityPrompt") then
                pcall(function()
                    d.MaxActivationDistance = 32
                    d.HoldDuration = 0
                    if fireproximityprompt then fireproximityprompt(d); fired = true end
                end)
            end
        end
    end
    return fired
end

-- Giai phong Boo-Boo Doll: TP toi cho no roi fire prompt
local function objFreeBooBoo(deadline)
    local boo = findBooBoo()
    if not boo then return false end
    local part = partOf(boo)
    if part then tweenToPos(part.Position + Vector3.new(0, 0, 2), "Boo-Boo Doll", 50); task.wait(0.3) end
    for _ = 1, 5 do
        if not _G.BlairHub then break end
        firePromptsOf(boo)
        task.wait(0.4)
    end
    return true
end

-- Liet ke tat ca cursed object trong CursedSpawns + Boo-Boo
local function listCursedObjects()
    local out = {}
    local Map = getMap()
    local cs = Map and Map:FindFirstChild("CursedSpawns")
    if cs then
        for _, v in ipairs(cs:GetChildren()) do
            if partOf(v) then table.insert(out, v) end
        end
    end
    local boo = findBooBoo()
    if boo then table.insert(out, boo) end
    return out
end

-- Chup anh tat ca cursed object (gom ca Boo-Boo)
local function objPhotoCursed(deadline)
    local objs = listCursedObjects()
    if #objs == 0 then return false end
    if not (hasInInventory("Photo Camera") or getEquipped("Photo Camera")) then
        if not bringTool("Photo Camera") then return false end
    end
    if not equipTool("Photo Camera") then return false end
    local any = false
    for _, obj in ipairs(objs) do
        if not _G.BlairHub then break end
        local part = partOf(obj)
        if part then
            objPhoto(part, "cursed: " .. obj.Name)
            any = true
        end
    end
    return any
end

-- Dung cursed object: TP toi cursed object trong CursedSpawns, equip neu cam duoc, fire use/prompt
local function objCursed(deadline)
    -- Uu tien: dung cursed object dat san trong map (CursedSpawns)
    local Map = getMap()
    local cs = Map and Map:FindFirstChild("CursedSpawns")
    if cs then
        for _, v in ipairs(cs:GetChildren()) do
            local part = partOf(v)
            if part then
                tweenToPos(part.Position + Vector3.new(0, 0, 2), "cursed: " .. v.Name, 50)
                task.wait(0.3)
                for _ = 1, 4 do
                    if not _G.BlairHub then break end
                    firePromptsOf(v)
                    task.wait(0.3)
                end
                -- Tarot dung bindable rieng
                pcall(function()
                    if v.Name:lower():find("tarot", 1, true) then
                        local bind = RS:FindFirstChild("Bindables")
                        local t = bind and bind:FindFirstChild("TarotCardsMonstrosity")
                        if t then t:Fire() end
                    end
                end)
                return true
            end
        end
    end

    -- Fallback: cursed item co the cam tay
    local CURSED = {"Tarot Cards", "Music Box", "Voodoo Doll", "Summoning Circle", "Monkey Paw", "Haunted Mirror"}
    local picked = nil
    for _, nm in ipairs(CURSED) do
        if hasInInventory(nm) or getEquipped(nm) then picked = nm; break end
    end
    if not picked then
        for _, nm in ipairs(CURSED) do
            if getTotalToolCount() < 3 and bringTool(nm) then picked = nm; break end
        end
    end
    if not picked then return false end
    equipTool(picked)
    task.wait(0.4)
    pcall(function()
        local bind = RS:FindFirstChild("Bindables")
        if picked == "Tarot Cards" then
            local t = bind and bind:FindFirstChild("TarotCardsMonstrosity")
            if t then t:Fire() end
        end
    end)
    local eq = getEquipped(picked)
    if eq then firePromptsOf(eq) end
    return true
end

-- Incense Burner: equip, tới ghost room, fire Incense bindable
local function objIncense(deadline)
    if not (hasInInventory("Incense Burner") or getEquipped("Incense Burner")) then
        if not bringTool("Incense Burner") then return false end
    end
    if not equipTool("Incense Burner") then return false end
    local ghost = findGhost()
    if ghost then
        local a = ghost:FindFirstChildWhichIsA("BasePart")
        if a then moveToPos(a.Position + Vector3.new(2, 0, 2), "ghost room incense") end
    else
        local rooms = getSortedRooms()
        if #rooms > 0 then moveToPos(rooms[1].pos, "coldest room incense") end
    end
    task.wait(0.4)
    pcall(function()
        local bind = RS:FindFirstChild("Bindables")
        local inc = bind and bind:FindFirstChild("Incense")
        if inc then inc:Fire() end
    end)
    local eq = getEquipped("Incense Burner")
    if eq then
        for _, d in ipairs(eq:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                pcall(function() d.MaxActivationDistance = 32; if fireproximityprompt then fireproximityprompt(d) end end)
            end
        end
    end
    return true
end

-- Đặt Trail Camera trong ghost room (ghost tự trigger -> passive hoàn thành)
local function objTrailCamera(deadline)
    if not (hasInInventory("Trail Camera") or getEquipped("Trail Camera")) then
        if not bringTool("Trail Camera") then return false end
    end
    if not equipTool("Trail Camera") then return false end
    local ghost = findGhost()
    local rooms = getSortedRooms()
    local dest = (ghost and ghost:FindFirstChildWhichIsA("BasePart") and ghost:FindFirstChildWhichIsA("BasePart").Position)
        or (rooms[1] and rooms[1].pos)
    if dest then moveToPos(dest, "ghost room trailcam") end
    task.wait(0.4)
    local eq = getEquipped("Trail Camera")
    if eq then
        for _, d in ipairs(eq:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                pcall(function() d.MaxActivationDistance = 32; if fireproximityprompt then fireproximityprompt(d) end end)
            end
        end
    end
    return true -- đã đặt, phần trigger là passive
end

-- Dispatch theo nội dung objective
local function runObjectiveHandler(objName)
    local n = objName:lower()
        local deadline = tick() + 60

    -- "free / release the boo-boo doll" -> fire prompt giai phong
    if (n:find("free") or n:find("release") or n:find("save")) and (n:find("boo") or n:find("doll")) then
        return objFreeBooBoo(deadline)

    -- chup anh: phan biet cursed/boo-boo vs ghost vs subject thuong
    elseif n:find("photo") or n:find("picture") or n:find("capture") then
        if n:find("cursed") then
            return objPhotoCursed(deadline)
        elseif n:find("boo") or n:find("panda") or n:find("doll") then
            local boo = findBooBoo()
            local part = partOf(boo)
            return objPhoto(part, "Boo-Boo Doll")
        else
            local ghost = findGhost()
            local part = ghost and ghost:FindFirstChildWhichIsA("BasePart")
            return objPhoto(part, "Ghost photo")
        end

    elseif n:find("thermomet") or n:find("freezing") or (n:find("under") and n:find("c")) then
        return objThermometer(deadline)

    -- "use a cursed object" -> dung cursed; neu doi hoi chup thi da bat o nhanh photo tren
    elseif n:find("cursed") then
        return objCursed(deadline)

    elseif n:find("incense") or n:find("cleanse") or n:find("smudge") or n:find("stun") then
        return objIncense(deadline)

    elseif n:find("trail") then
        return objTrailCamera(deadline)
    end
    return nil -- khong co handler -> skip
end

local function doAllQuests()
    setFarmStatus("Auto quests: scanning...", C.FlyBlue)
    if not getMap() then setFarmStatus("Map not found!", C.Red); return 0 end
    local objs = findObjectivesFolder()
    if not objs then setFarmStatus("Objectives not found!", C.Red); return 0 end
    -- Debug: in tên tất cả objectives
    for _, obj in ipairs(objs:GetChildren()) do
        local hc = obj:FindFirstChild("HasCompleted")
        print(string.format("[Quest] '%s' | done=%s", obj.Name, tostring(hc and hc.Value)))
    end

    local done, skipped = 0, 0
    for _, obj in ipairs(objs:GetChildren()) do
        if not _G.BlairHub then break end
        local hc = obj:FindFirstChild("HasCompleted")
        if hc and not hc.Value then
            setFarmStatus("Obj: " .. obj.Name:sub(1, 32), C.FlyPurple)
            local handled = false
            local ok, res = pcall(runObjectiveHandler, obj.Name)
            if ok and res ~= nil then handled = true end
            if handled then
                -- chờ HasCompleted lật sang true (tối đa 6s)
                local wd = tick() + 8
                while tick() < wd and not hc.Value and _G.BlairHub do task.wait(0.1) end
                if hc.Value then done = done + 1 else skipped = skipped + 1 end
            else
                skipped = skipped + 1
            end
        end
    end
    -- Bonus: chụp thêm ghost, boo-boo, all cursed object sau khi xong quest
    setFarmStatus("Bonus: chụp ghost + cursed + boo-boo...", C.FlyPurple)
    pcall(function()
        local deadline2 = tick() + 60
        -- Chụp ghost
        local ghost = findGhost()
        local ghostPart = ghost and ghost:FindFirstChildWhichIsA("BasePart")
        if ghostPart then objPhoto(ghostPart, "Ghost bonus photo") end
        -- Chụp tất cả cursed objects
        objPhotoCursed(deadline2)
        -- Chụp Boo-Boo Doll
        local boo = findBooBoo()
        local booPart = partOf(boo)
        if booPart then objPhoto(booPart, "Boo-Boo bonus photo") end
    end)
    setFarmStatus(string.format("Quests: %d done, %d skipped + bonus photos", done, skipped),
        done > 0 and C.Green or C.Orange)
    return done
end

-- ============================================================================
-- AUTO FARM v7.8
-- Flow: Open van door → Pickup 3 tools (EMF+Writing+SLS) → Go ghost room
--       → Test all 3 → Drop all → Pickup Spirit Box → Test SBox
--       → Submit → Tween to van (player bấm leave thủ công)
-- ============================================================================
local function trySubmitAndGoVan(possible)
    if #possible==1 then
        setFarmStatus("IDENTIFIED: "..possible[1].."!",C.Green)
        submitGuess(possible[1])
        task.wait(1.5)
        goToVan()
        return true
    end
    return false
end

local function runAutoFarm()
    if AUTO_FARM.running then return end
    AUTO_FARM.running=true
    local ok,err=pcall(function()
        setFarmStatus("Starting v7.8...",C.TextDim)
        resetEvidence(); resetMissCounts(); refreshPlayerNames()
        S.vanDoorOpened=false

        if not loadGhostDB() then setFarmStatus("Ghost DB load failed!",C.Red); return end

        local waited=0
        while not getMap() and waited<20 and _G.BlairHub and Config.AutoFarm do
            task.wait(1); waited=waited+1
        end
        if not getMap() then setFarmStatus("Map not found!",C.Red); return end

        -- STEP 0: Mở van door trước tiên
        setFarmStatus("Opening van door...",C.Yellow)
        openVanDoor()
        task.wait(0.5)
        if not _G.BlairHub or not Config.AutoFarm then return end

        -- STEP 0.5: Auto hoàn thành quest
        doAllQuests()
        task.wait(0.5)
        if not _G.BlairHub or not Config.AutoFarm then return end

        -- STEP 1: Passive scan nhanh
        setFarmStatus("Passive scan...",C.TextDim)
        local Map=getMap()
        pcall(function()
            local Prints=Map:FindFirstChild("Prints")
            if Prints and #Prints:GetChildren()>0 then setEvidence("UV",true) end
            local Orbs=Map:FindFirstChild("Orbs")
            if Orbs and #Orbs:GetChildren()>0 then setEvidence("ORB",true) end
            local Zones=getZones()
            if Zones then
                for _,zone in ipairs(Zones:GetChildren()) do
                    local tv=zone:FindFirstChild("_____Temperature")
                    if tv and tv.Value<0 then setEvidence("FREEZE",true); break end
                end
            end
            if workspace:FindFirstChild("SLS_GHOST") then setEvidence("SLS",true) end
        end)
        safewait(0.5)
        if not _G.BlairHub or not Config.AutoFarm then return end
        if trySubmitAndGoVan(getPossibleGhosts()) then return end

        -- STEP 2: Pickup 3 tools (EMF + Writing + SLS)
        -- 3 slot mặc định → pick từng cái, không drop tool kia
        setFarmStatus("Pickup: EMF + Writing + SLS...",C.Yellow)
        for _,toolName in ipairs({"EMF Reader","Ghost Writing Book","SLS Camera"}) do
            if not _G.BlairHub or not Config.AutoFarm then break end
            if not hasInInventory(toolName) then
                setFarmStatus("Pickup: "..toolName,C.Yellow)
                for attempt=1,3 do
                    if bringTool(toolName) then break end
                    task.wait(0.6)
                end
            end
        end
        print("[Farm] Inventory after pickup 3 tools:",getTotalToolCount())

        -- STEP 3: Tìm ghost room và scan
        setFarmStatus("Finding ghost room...",C.FlyPurple)
        local _,ghostRoomPos=goToGhostRoom()
        safewait(0.5)

        local rooms = getSortedRooms()
        local coldRooms = {}
        -- Lấy top 3 phòng lạnh nhất, bỏ qua Outside
        for _, r in ipairs(rooms) do
            if r.name ~= "Outside" then
                table.insert(coldRooms, r)
                if #coldRooms >= 3 then break end
            end
        end
        if #coldRooms == 0 then
            coldRooms = rooms
        end
        print(string.format("[Farm] Scan %d phòng: %s",
            #coldRooms,
            table.concat((function()
                local t = {}
                for _, r in ipairs(coldRooms) do
                    table.insert(t, r.name.."("..math.floor(r.temp).."°)")
                end
                return t
            end)(), ", ")
        ))

        local roomsToScan={}
        if ghostRoomPos then
            table.insert(roomsToScan,{pos=ghostRoomPos,name="GhostRoom",temp=-99})
        end
        for _,r in ipairs(coldRooms) do
            if not ghostRoomPos or (r.pos-ghostRoomPos).Magnitude>5 then
                table.insert(roomsToScan,r)
            end
        end

        -- Scan từng room với 3 tool
        for i,room in ipairs(roomsToScan) do
            if not _G.BlairHub or not Config.AutoFarm then break end
            -- Early exit nếu chỉ còn 1 ghost possible
            if #getPossibleGhosts() == 1 then
                if trySubmitAndGoVan(getPossibleGhosts()) then return end
            end
            if i>1 then
                setFarmStatus(string.format("Room %d/%d: %s",i,#roomsToScan,room.name),C.FlyPurple)
                if isHunting() then waitHuntOver(room.pos,room.name) end
                tweenToPos(room.pos, room.name, 55); safewait(0.2)
            end

            if not shouldSkip("EMF5") and hasInInventory("EMF Reader") then
                checkEMF(room.pos,room.name)
                if not _G.BlairHub or not Config.AutoFarm then break end
                if trySubmitAndGoVan(getPossibleGhosts()) then return end
            end

            if not shouldSkip("WRITING") and hasInInventory("Ghost Writing Book") then
                checkWriting(room.pos,room.name)
                if not _G.BlairHub or not Config.AutoFarm then break end
                if trySubmitAndGoVan(getPossibleGhosts()) then return end
            end

            if not shouldSkip("SLS") and hasInInventory("SLS Camera") then
                checkSLS(room.pos,room.name)
                if not _G.BlairHub or not Config.AutoFarm then break end
                if trySubmitAndGoVan(getPossibleGhosts()) then return end
            end

            if detectedEvidence["EMF5"] and detectedEvidence["WRITING"] and detectedEvidence["SLS"] then break end
        end

        if not _G.BlairHub or not Config.AutoFarm then return end
        if trySubmitAndGoVan(getPossibleGhosts()) then return end

        -- STEP 4: Drop 3 tools cũ, pickup Spirit Box
        setFarmStatus("Dropping old tools, pickup Spirit Box...",C.FlyBlue)

        -- Drop EMF, Writing, SLS nếu đang cầm
        for _,toolName in ipairs({"EMF Reader","Ghost Writing Book","SLS Camera"}) do
            if getEquipped(toolName) then
                returnTool(toolName); task.wait(0.3)
            end
        end
        -- Drop hết BP nếu vẫn còn slot
        local dropAttempts=0
        while getTotalToolCount()>=3 and dropAttempts<5 do
            dropCurrentTool(); task.wait(0.3)
            dropAttempts=dropAttempts+1
        end

        -- Pickup Spirit Box
        for attempt=1,3 do
            if bringTool("Spirit Box") then break end
            task.wait(0.6)
        end

        if not hasInInventory("Spirit Box") then
            setFarmStatus("Spirit Box not available",C.TextMuted)
        else
        -- Return to ghost room for SBox
        if ghostRoomPos then tweenToPos(ghostRoomPos, "GhostRoom", 50) end
            safewait(0.3)

            if not shouldSkip("SBOX") then
                for i,room in ipairs(roomsToScan) do
                    if not _G.BlairHub or not Config.AutoFarm then break end
                    if detectedEvidence["SBOX"] then break end
                    if i>1 then
                        if isHunting() then waitHuntOver(room.pos,room.name) end
                        moveToPos(room.pos,room.name); safewait(0.3)
                        if not getEquipped("Spirit Box") then equipTool("Spirit Box") end
                    end
                    checkSBox(room.pos,room.name)
                    if trySubmitAndGoVan(getPossibleGhosts()) then return end
                end
            end
        end

        if not _G.BlairHub or not Config.AutoFarm then return end

        -- STEP 5: Recheck nếu còn tool chưa detect đủ
        local recheckList={}
        for _,ev in ipairs(EVIDENCE_INFO) do
            if not detectedEvidence[ev.key]
            and (S.evidenceMissCount[ev.key] or 0)>0
            and (S.evidenceMissCount[ev.key] or 0)<MISS_SKIP then
                table.insert(recheckList,ev.key)
            end
        end
        if #recheckList>0 then
            setFarmStatus("Recheck: "..table.concat(recheckList,", "),C.FlyPurple)
            resetMissCounts()
            if ghostRoomPos then tweenToPos(ghostRoomPos, "GhostRoom", 50) end
            safewait(0.3)
            for _,key in ipairs(recheckList) do
                if not _G.BlairHub or not Config.AutoFarm then break end
                if key=="EMF5" and hasInInventory("EMF Reader") then
                    equipTool("EMF Reader"); checkEMF(ghostRoomPos,"GhostRoom")
                elseif key=="WRITING" and hasInInventory("Ghost Writing Book") then
                    equipTool("Ghost Writing Book"); checkWriting(ghostRoomPos,"GhostRoom")
                elseif key=="SLS" and hasInInventory("SLS Camera") then
                    equipTool("SLS Camera"); checkSLS(ghostRoomPos,"GhostRoom")
                elseif key=="SBOX" and hasInInventory("Spirit Box") then
                    equipTool("Spirit Box"); checkSBox(ghostRoomPos,"GhostRoom")
                end
                if trySubmitAndGoVan(getPossibleGhosts()) then return end
            end
        end

        -- STEP 6: Endgame
        local possible=getPossibleGhosts()
        local detCount=0
        for _,v in pairs(detectedEvidence) do if v then detCount=detCount+1 end end

        if trySubmitAndGoVan(possible) then return
        elseif #possible<=3 and detCount>=2 then
            local best,score=getBestGuess()
            if best and score>=2 then
                setFarmStatus("Best guess: "..best.." ("..score..")",C.Yellow)
                task.wait(1)
                submitGuess(best)
                task.wait(1)
                goToVan()
            else
                setFarmStatus("Ambiguous: "..table.concat(possible,", "),C.Orange)
                goToVan()
            end
        elseif #possible==0 then
            setFarmStatus("No match — resetting",C.Red); resetEvidence()
        else
            setFarmStatus(#possible.." possible — "..detCount.." detected",C.Orange)
            goToVan()
        end
    end)

    AUTO_FARM.running=false
    if not ok then
        print("[Blair v7.8] Farm error:",err)
        setFarmStatus("Farm error: "..tostring(err):sub(1,60),C.Red)
        if S.farmBtn and S.farmBtn.Parent then
            S.farmBtn.Text="START AUTO FARM"
            S.farmBtn.BackgroundColor3=C.FarmGreen
        end
        Config.AutoFarm=false
    end
end

-- ============================================================================

S.checkEMF = checkEMF
S.checkWriting = checkWriting
S.checkSLS = checkSLS
S.checkSBox = checkSBox
S.findObjectivesFolder = findObjectivesFolder
S.lookAtPart = lookAtPart
S.objPhoto = objPhoto
S.objThermometer = objThermometer
S.findBooBoo = findBooBoo
S.partOf = partOf
S.firePromptsOf = firePromptsOf
S.objFreeBooBoo = objFreeBooBoo
S.listCursedObjects = listCursedObjects
S.objPhotoCursed = objPhotoCursed
S.objCursed = objCursed
S.objIncense = objIncense
S.objTrailCamera = objTrailCamera
S.runObjectiveHandler = runObjectiveHandler
S.doAllQuests = doAllQuests
S.trySubmitAndGoVan = trySubmitAndGoVan
S.runAutoFarm = runAutoFarm
return S