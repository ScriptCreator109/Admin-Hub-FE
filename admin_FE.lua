local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local PREFIX = ";"
local flySpeed = 50
local flying, noclipOn, infJumpOn, flingOn, espOn, godOn, fbOn, fogOn, miniOn = false,false,false,false,false,false,false,false,false
local viewTarget = nil
local flyConn, jumpConn, noclipConn, flingThread, godConn, fbConn, viewConn
local espConns, espObjs = {}, {}
local savedFog = {fend=nil, fstart=nil, atms={}}
local savedCamSubject = nil

local function randStr()
    local len = math.random(10,20)
    local arr = {}
    for i=1,len do arr[i] = string.char(math.random(32,126)) end
    return table.concat(arr)
end

local function stopFly()
    flying = false
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if jumpConn then jumpConn:Disconnect() jumpConn = nil end
    local c = LP.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        local r = c:FindFirstChild("HumanoidRootPart")
        if h then h.PlatformStand = false end
        if r then r.AssemblyLinearVelocity = Vector3.zero end
    end
end

local function startFly()
    local c = LP.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    flying = true
    h.PlatformStand = true
    flyConn = RunService.RenderStepped:Connect(function()
        if not flying then return end
        local cc = LP.Character
        if not cc then return end
        local hh = cc:FindFirstChildOfClass("Humanoid")
        local rr = cc:FindFirstChild("HumanoidRootPart")
        local cam = workspace.CurrentCamera
        if not hh or not rr or not cam then return end
        local md = hh.MoveDirection
        if md.Magnitude > 0.05 then
            local dir = (cam.CFrame.LookVector * md:Dot(cam.CFrame.LookVector)) + (cam.CFrame.RightVector * md:Dot(cam.CFrame.RightVector))
            if dir.Magnitude > 0 then rr.AssemblyLinearVelocity = dir.Unit * flySpeed end
        else
            rr.AssemblyLinearVelocity = Vector3.zero
        end
        hh.PlatformStand = true
    end)
    jumpConn = UIS.JumpRequest:Connect(function()
        if not flying then return end
        local cc = LP.Character
        if not cc then return end
        local rr = cc:FindFirstChild("HumanoidRootPart")
        if rr then rr.AssemblyLinearVelocity = Vector3.new(rr.AssemblyLinearVelocity.X, flySpeed, rr.AssemblyLinearVelocity.Z) end
    end)
end

local function stopNoclip()
    noclipOn = false
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    local c = LP.Character
    if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
end

local function startNoclip()
    noclipOn = true
    noclipConn = RunService.Stepped:Connect(function()
        if not noclipOn then return end
        local c = LP.Character
        if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
    end)
end

local function startInfJump()
    infJumpOn = true
    if jumpConn then jumpConn:Disconnect() end
    jumpConn = UIS.JumpRequest:Connect(function()
        if flying then return end
        if infJumpOn then
            local c = LP.Character
            if c then local h = c:FindFirstChildOfClass("Humanoid") if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
        end
    end)
end

local function stopInfJump()
    infJumpOn = false
    if jumpConn and not flying then jumpConn:Disconnect() jumpConn = nil end
end

local function unfling()
    flingOn = false
    task.wait(0.1)
    local c = LP.Character
    if not c then return end
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
            v.Massless = false
            v.Velocity = Vector3.zero
        elseif v:IsA("BodyAngularVelocity") then
            v:Destroy()
        end
    end
end

local function startFling()
    if flingOn then return end
    flingOn = false
    local c = LP.Character
    if not c then return end
    for _, child in ipairs(c:GetDescendants()) do
        if child:IsA("BasePart") then
            child.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)
        end
    end
    if not noclipOn then startNoclip() end
    task.wait(0.1)
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bambam = Instance.new("BodyAngularVelocity")
    bambam.Name = randStr()
    bambam.Parent = hrp
    bambam.AngularVelocity = Vector3.new(0, 99999, 0)
    bambam.MaxTorque = Vector3.new(0, math.huge, 0)
    bambam.P = math.huge
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("BasePart") then
            v.Massless = true
            v.Velocity = Vector3.zero
        end
    end
    flingOn = true
    flingThread = task.spawn(function()
        while flingOn do
            if bambam and bambam.Parent then bambam.AngularVelocity = Vector3.new(0, 99999, 0) end
            task.wait(0.1)
            if bambam and bambam.Parent then bambam.AngularVelocity = Vector3.new(0, 0, 0) end
            task.wait(0.1)
        end
        if bambam then bambam:Destroy() end
    end)
end

local function clearESP()
    for _,cn in ipairs(espConns) do if cn then cn:Disconnect() end end
    espConns = {}
    for _,o in ipairs(espObjs) do if o and o.Parent then o:Destroy() end end
    espObjs = {}
end

local function createESP(p)
    if p == LP then return end
    local c = p.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255,0,0)
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.5
    hl.Parent = c
    table.insert(espObjs, hl)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0,200,0,40)
    bb.Adornee = hrp
    bb.AlwaysOnTop = true
    bb.Parent = c
    table.insert(espObjs, bb)
    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1,0,1,0)
    nl.BackgroundTransparency = 1
    nl.Text = p.Name
    nl.TextColor3 = Color3.fromRGB(255,255,255)
    nl.TextSize = 16
    nl.Font = Enum.Font.GothamBold
    nl.TextStrokeTransparency = 0.5
    nl.Parent = bb
    table.insert(espObjs, nl)
end

local function startESP()
    espOn = true
    for _,p in ipairs(Players:GetPlayers()) do createESP(p) end
    table.insert(espConns, Players.PlayerAdded:Connect(function(p)
        if espOn then p.CharacterAdded:Connect(function() task.wait(1) if espOn then createESP(p) end end) end
    end))
end

local function stopESP() espOn = false clearESP() end

local function startGod()
    godOn = true
    godConn = RunService.Heartbeat:Connect(function()
        if not godOn then return end
        local c = LP.Character
        if c then local h = c:FindFirstChildOfClass("Humanoid") if h then h.MaxHealth = math.huge h.Health = math.huge end end
    end)
end

local function stopGod()
    godOn = false
    if godConn then godConn:Disconnect() godConn = nil end
    local c = LP.Character
    if c then local h = c:FindFirstChildOfClass("Humanoid") if h then h.MaxHealth = 100 h.Health = 100 end end
end
local function startFB()
    fbOn = true
    fbConn = RunService.RenderStepped:Connect(function()
        if not fbOn then return end
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(178,178,178)
    end)
end

local function stopFB()
    fbOn = false
    if fbConn then fbConn:Disconnect() fbConn = nil end
    Lighting.Brightness = 1
    Lighting.ClockTime = 14
    Lighting.FogEnd = 1000
end

local function startNoFog()
    if not fogOn then
        savedFog.fend = Lighting.FogEnd
        savedFog.fstart = Lighting.FogStart
        for _,v in ipairs(Lighting:GetChildren()) do if v:IsA("Atmosphere") then savedFog.atms[v] = v.Density end end
    end
    fogOn = true
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    for _,v in ipairs(Lighting:GetChildren()) do if v:IsA("Atmosphere") then v.Density = 0 end end
end

local function stopNoFog()
    fogOn = false
    if savedFog.fend then Lighting.FogEnd = savedFog.fend end
    if savedFog.fstart then Lighting.FogStart = savedFog.fstart end
    for a,d in pairs(savedFog.atms) do if a and a.Parent then a.Density = d end end
    savedFog = {fend=nil, fstart=nil, atms={}}
end

local origSizes = {}

local function setMini(m)
    local c = LP.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return end
    if m then
        origSizes = {}
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                origSizes[part] = part.Size
                part.Size = part.Size * 0.2
            end
        end
    else
        for part, size in pairs(origSizes) do
            if part and part.Parent then part.Size = size end
        end
        origSizes = {}
    end
end

local function stopView()
    viewTarget = nil
    if viewConn then viewConn:Disconnect() viewConn = nil end
    local cam = workspace.CurrentCamera
    if cam then
        if savedCamSubject then
            cam.CameraSubject = savedCamSubject
            savedCamSubject = nil
        elseif LP.Character then
            local h = LP.Character:FindFirstChildOfClass("Humanoid")
            if h then cam.CameraSubject = h end
        end
        cam.CameraType = Enum.CameraType.Custom
    end
end

local function startView(p)
    if not p then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    stopView()
    viewTarget = p
    savedCamSubject = cam.CameraSubject
    local char = p.Character
    if not char then
        p.CharacterAdded:Wait()
        char = p.Character
    end
    local targetHum = char:WaitForChild("Humanoid", 5)
    if not targetHum then return end
    cam.CameraSubject = targetHum
    cam.CameraType = Enum.CameraType.Custom
    viewConn = p.CharacterAdded:Connect(function(newChar)
        local newHum = newChar:WaitForChild("Humanoid", 5)
        if newHum and viewTarget == p then cam.CameraSubject = newHum end
    end)
end

local invisActive = false

local function setInvisibleState(inv)
    local c = LP.Character
    if not c then return end
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then
            v.LocalTransparencyModifier = inv and 1 or 0
            v.Transparency = inv and 1 or 0
        elseif v:IsA("Decal") then
            v.Transparency = inv and 1 or 0
        elseif v:IsA("Accessory") then
            local h = v:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then
                h.LocalTransparencyModifier = inv and 1 or 0
                h.Transparency = inv and 1 or 0
            end
        end
    end
    local head = c:FindFirstChild("Head")
    if head then
        local ng = head:FindFirstChildOfClass("BillboardGui")
        if ng then ng.Enabled = not inv end
    end
end

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if invisActive then setInvisibleState(true) end
end)

local function findPlayers(name, includeSelf)
    if not name then return {} end
    name = name:lower()
    local list = {}
    local all = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if includeSelf or p ~= LP then
            table.insert(all, p)
            if name == "all" or p.Name:lower():find(name, 1, true) or p.DisplayName:lower():find(name, 1, true) then
                table.insert(list, p)
            end
        end
    end
    if name == "random" then
        if #all > 0 then return { all[math.random(1, #all)] } end
    end
    return list
end

local C = {}
C["invisible"] = {a="", d="Fica invisivel", f=function()
    invisActive = true
    setInvisibleState(true)
end}
C["visible"] = {a="", d="Volta a ser visivel", f=function()
    invisActive = false
    setInvisibleState(false)
end}
C["fly"] = {a="", d="Liga voo", f=function() if not flying then startFly() end end}
C["unfly"] = {a="", d="Desliga voo", f=function() if flying then stopFly() end end}
C["flyspeed"] = {a="<n>", d="Velocidade do voo", f=function(g) local n=tonumber(g[1]) if n and n>0 then flySpeed=n end end}
C["speed"] = {a="<n>", d="Velocidade ao andar", f=function(g) local n=tonumber(g[1]) if n and LP.Character then local h=LP.Character:FindFirstChildOfClass("Humanoid") if h then h.WalkSpeed=n end end end}
C["jumppower"] = {a="<n>", d="Forca do pulo", f=function(g) local n=tonumber(g[1]) if n and LP.Character then local h=LP.Character:FindFirstChildOfClass("Humanoid") if h then h.JumpPower=n end end end}
C["noclip"] = {a="", d="Atravessa paredes", f=function() if not noclipOn then startNoclip() end end}
C["unnoclip"] = {a="", d="Desativa noclip", f=function() if noclipOn then stopNoclip() end end}
C["infjump"] = {a="", d="Pulo infinito", f=function() if not infJumpOn then startInfJump() else stopInfJump() end end}
C["uninfjump"] = {a="", d="Desativa pulo infinito", f=function() if infJumpOn then stopInfJump() end end}
C["fling"] = {a="", d="Gira e arremessa quem encostar", f=function() if not flingOn then startFling() else unfling() end end}
C["unfling"] = {a="", d="Desativa o fling", f=function() if flingOn then unfling() end end}
C["esp"] = {a="", d="Ver jogadores", f=function() if not espOn then startESP() else stopESP() end end}
C["unesp"] = {a="", d="Desativa o ESP", f=function() if espOn then stopESP() end end}
C["godmode"] = {a="", d="Vida infinita", f=function() if not godOn then startGod() else stopGod() end end}
C["ungodmode"] = {a="", d="Desativa vida infinita", f=function() if godOn then stopGod() end end}
C["goto"] = {a="<nome|random|all>", d="Teleporta ate jogador(es)", f=function(g)
    local players = findPlayers(g[1])
    if #players == 0 then return end
    local mc = LP.Character
    if not mc then return end
    local mr = mc:FindFirstChild("HumanoidRootPart")
    if not mr then return end
    local p = players[1]
    local tc = p.Character
    if tc then
        local tr = tc:FindFirstChild("HumanoidRootPart")
        if tr then mr.CFrame = tr.CFrame + Vector3.new(0,3,0) end
    end
end}
C["view"] = {a="<nome|random>", d="Ve a visao de um jogador", f=function(g)
    local players = findPlayers(g[1])
    if #players == 0 then return end
    startView(players[1])
end}
C["unview"] = {a="", d="Volta pra sua camera", f=function() stopView() end}
C["fb"] = {a="", d="Fullbright", f=function() if not fbOn then startFB() else stopFB() end end}
C["fullbright"] = {a="", d="Clareia o mapa", f=function() if not fbOn then startFB() else stopFB() end end}
C["unfb"] = {a="", d="Desativa fullbright", f=function() if fbOn then stopFB() end end}
C["nofog"] = {a="", d="Remove nevoa", f=function() if not fogOn then startNoFog() else stopNoFog() end end}
C["unfog"] = {a="", d="Volta a nevoa", f=function() if fogOn then stopNoFog() end end}
C["loadstring"] = {a="<link>", d="Executa script de link", f=function(g)
    if not g[1] then return end
    local ok,err = pcall(function() loadstring(game:HttpGet(g[1]))() end)
    if not ok then warn("[Admin] "..tostring(err)) end
end}
C["reset"] = {a="", d="Reseta personagem", f=function()
    local c = LP.Character
    if c then local h = c:FindFirstChildOfClass("Humanoid") if h then h.Health = 0 end end
end}
C["mini"] = {a="", d="Personagem pequeno", f=function() miniOn = not miniOn setMini(miniOn) end}
C["unmini"] = {a="", d="Desativa o mini", f=function() if miniOn then miniOn = false setMini(false) end end}
C["rejoin"] = {a="", d="Reconecta", f=function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end}
C["rj"] = {a="", d="Reconecta", f=function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end}
C["serverhop"] = {a="", d="Troca servidor", f=function()
    local sv = {}
    pcall(function()
        local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local r = HttpService:JSONDecode(game:HttpGet(url))
        for _,s in ipairs(r.data) do if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(sv, s.id) end end
    end)
    if #sv > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, sv[math.random(1,#sv)], LP) end
end}
C["shop"] = C["serverhop"]
-- TP TOOL
C["tptool"] = {a="", d="Recebe uma tool de teleporte", f=function()
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return end
    local tool = Instance.new("Tool")
    tool.Name = "TP Tool"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 1)
    handle.Color = Color3.fromRGB(0, 170, 255)
    handle.Material = Enum.Material.Neon
    handle.Parent = tool
    tool.Activated:Connect(function()
        local mouse = LP:GetMouse()
        local target = mouse.Hit.Position
        local c = LP.Character
        if c then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = CFrame.new(target + Vector3.new(0, 3, 0)) end
        end
    end)
    tool.Parent = bp
end}

-- FLING TOOL (SFBasePart do NeverX)
C["flingtool"] = {a="", d="Tool de fling (clique em alguem)", f=function()
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return end
    local tool = Instance.new("Tool")
    tool.Name = "Fling Tool"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 1)
    handle.Color = Color3.fromRGB(255, 60, 60)
    handle.Material = Enum.Material.Neon
    handle.Parent = tool

    tool.Activated:Connect(function()
        local mouse = LP:GetMouse()
        local target = mouse.Target
        if not target then return end
        local targetChar = target:FindFirstAncestorOfClass("Model")
        if not targetChar then return end
        local targetPlr = Players:GetPlayerFromCharacter(targetChar)
        if not targetPlr or targetPlr == LP then return end

        local Character = LP.Character
        if not Character then return end
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Humanoid and Humanoid.RootPart
        if not RootPart then return end
        local OldPos = RootPart.CFrame

        local TCharacter = targetPlr.Character
        if not TCharacter then return end
        local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
        local TRootPart = THumanoid and THumanoid.RootPart
        local THead = TCharacter:FindFirstChild("Head")
        if not TRootPart and not THead then return end

        local savedFPDH = workspace.FallenPartsDestroyHeight
        workspace.FallenPartsDestroyHeight = 0/0

        local function FPos(BasePart, Pos, Ang)
            RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
            Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
            RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        local startTime = tick()
        local angle = 0
        local moveDir = THumanoid and THumanoid.MoveDirection or Vector3.zero
        local speed = THumanoid and THumanoid.WalkSpeed or 16

        repeat
            if not RootPart or not TRootPart or not TRootPart.Parent then break end
            local velMag = TRootPart.Velocity.Magnitude
            local posOffset = CFrame.new(0, 1.5, 0) + moveDir * (velMag / 1.25)
            local negOffset = CFrame.new(0, -1.5, 0) + moveDir * (velMag / 1.25)

            if velMag < 50 then
                angle = angle + 100
                local ang = CFrame.Angles(math.rad(angle), 0, 0)
                FPos(TRootPart, posOffset, ang); task.wait()
                FPos(TRootPart, negOffset, ang); task.wait()
                FPos(TRootPart, posOffset, ang); task.wait()
                FPos(TRootPart, negOffset, ang); task.wait()
                FPos(TRootPart, CFrame.new(0, 1.5, 0) + moveDir, ang); task.wait()
                FPos(TRootPart, CFrame.new(0, -1.5, 0) + moveDir, ang); task.wait()
            else
                local high = CFrame.Angles(math.rad(90), 0, 0)
                local zero = CFrame.new()
                FPos(TRootPart, CFrame.new(0, 1.5, speed), high); task.wait()
                FPos(TRootPart, CFrame.new(0, -1.5, -speed), zero); task.wait()
                FPos(TRootPart, CFrame.new(0, 1.5, speed), high); task.wait()
                FPos(TRootPart, CFrame.new(0, -1.5, 0), high); task.wait()
                FPos(TRootPart, CFrame.new(0, -1.5, 0), zero); task.wait()
                FPos(TRootPart, CFrame.new(0, -1.5, 0), high); task.wait()
                FPos(TRootPart, CFrame.new(0, -1.5, 0), zero); task.wait()
            end
        until tick() - startTime >= 2

        repeat
            RootPart.CFrame = OldPos * CFrame.new(0, .5, 0)
            Character:SetPrimaryPartCFrame(OldPos * CFrame.new(0, .5, 0))
            Humanoid:ChangeState("GettingUp")
            for _, part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new()
                end
            end
            task.wait()
        until (RootPart.Position - OldPos.p).Magnitude < 25

        workspace.FallenPartsDestroyHeight = savedFPDH
    end)

    tool.Parent = bp
end}

-- SPIN
local spinConn = nil
local spinning = false
C["spin"] = {a="", d="Gira o personagem (toggle)", f=function()
    if spinning then
        spinning = false
        if spinConn then spinConn:Disconnect() spinConn = nil end
        local c = LP.Character
        if c then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.AssemblyAngularVelocity = Vector3.zero
                local bav = hrp:FindFirstChildOfClass("BodyAngularVelocity")
                if bav then bav:Destroy() end
            end
        end
        return
    end
    spinning = true
    local c = LP.Character
    if not c then spinning = false return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then spinning = false return end
    local bav = Instance.new("BodyAngularVelocity")
    bav.AngularVelocity = Vector3.new(0, 99999, 0)
    bav.MaxTorque = Vector3.new(0, math.huge, 0)
    bav.P = math.huge
    bav.Parent = hrp
    spinConn = RunService.Heartbeat:Connect(function()
        if not spinning then return end
        local cc = LP.Character
        if cc then
            local rr = cc:FindFirstChild("HumanoidRootPart")
            if rr then rr.AssemblyAngularVelocity = Vector3.new(0, 99999, 0) end
        end
    end)
end}

-- HIPHEIGHT
C["hipheight"] = {a="<n>", d="Altura do personagem", f=function(g)
    local n = tonumber(g[1])
    if n and LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.HipHeight = n end
    end
end}

-- SIT
C["sit"] = {a="", d="Senta o personagem", f=function()
    local c = LP.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.Sit = true end
    end
end}
C["unsit"] = {a="", d="Levanta o personagem", f=function()
    local c = LP.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.Sit = false end
    end
end}

-- THRU
C["thru"] = {a="<n>", d="Teleporta X studs pra frente", f=function(g)
    local n = tonumber(g[1]) or 10
    local c = LP.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = hrp.CFrame + (hrp.CFrame.LookVector * n)
        end
    end
end}

-- FOV
C["fov"] = {a="<n>", d="Campo de visao (padrao 70)", f=function(g)
    local n = tonumber(g[1])
    if n then
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = n end
    end
end}

-- BIGHEAD
local bigHeadActive = false
local bigHeadOrigSize = nil
C["bighead"] = {a="", d="Cabeca gigante (toggle)", f=function()
    local c = LP.Character
    if not c then return end
    local head = c:FindFirstChild("Head")
    if not head then return end
    if bigHeadActive then
        bigHeadActive = false
        if bigHeadOrigSize then
            head.Size = bigHeadOrigSize
            pcall(function()
                local mesh = head:FindFirstChildOfClass("SpecialMesh")
                if mesh then mesh.Scale = Vector3.new(1,1,1) end
            end)
        end
    else
        bigHeadActive = true
        bigHeadOrigSize = head.Size
        head.Size = head.Size * 2
        pcall(function()
            local mesh = head:FindFirstChildOfClass("SpecialMesh")
            if mesh then mesh.Scale = Vector3.new(2,2,2) end
        end)
    end
end}

-- PREFIX
C["prefix"] = {a="<novo>", d="Troca o prefixo dos comandos", f=function(g)
    if not g[1] or #g[1] == 0 then return end
    PREFIX = g[1]
    _G.AdminHub.PREFIX = PREFIX
    print("[Admin] Prefixo mudado para: " .. PREFIX)
end}

-- GRAVITY
C["gravity"] = {a="<n>", d="Muda a gravidade (padrao 196.2)", f=function(g)
    local n = tonumber(g[1])
    if n then workspace.Gravity = n end
end}

-- CLONE
C["clone"] = {a="", d="Cria um clone visivel pra todos", f=function()
    local c = LP.Character
    if not c then return end
    if not c:FindFirstChildOfClass("Humanoid") then return end
    local clone = c:Clone()
    clone.Name = LP.Name .. "_Clone"
    local hrp = clone:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = hrp.CFrame + Vector3.new(3, 0, 0)
    end
    local h = clone:FindFirstChildOfClass("Humanoid")
    if h then
        h.DisplayName = LP.DisplayName .. " (Clone)"
    end
    clone.Parent = workspace
    task.delay(15, function()
        if clone and clone.Parent then clone:Destroy() end
    end)
end}
-- ============ JERK ============
C["jerk"] = {a="", d="Recebe a tool 'Jerk Off' (equipe pra usar)", f=function()
    local c = LP.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    local backpack = LP:FindFirstChildOfClass("Backpack")
    if not hum or not backpack then return end

    local oldTool = backpack:FindFirstChild("Jerk Off")
    if oldTool then oldTool:Destroy() end
    local oldTool2 = c:FindFirstChild("Jerk Off")
    if oldTool2 then oldTool2:Destroy() end

    local tool = Instance.new("Tool")
    tool.Name = "Jerk Off"
    tool.ToolTip = "in the stripped club. straight up 'jorking it'."
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.Parent = backpack

    local jorkin = false
    local track = nil

    local function isR15Local()
        return LP.Character and LP.Character:FindFirstChild("UpperTorso") ~= nil
    end

    local function stopTomfoolery()
        jorkin = false
        if track then track:Stop() track = nil end
    end

    tool.Equipped:Connect(function() jorkin = true end)
    tool.Unequipped:Connect(stopTomfoolery)

    if hum then
        hum.Died:Connect(stopTomfoolery)
    end

    task.spawn(function()
        while tool and tool.Parent do
            if jorkin then
                local cc = LP.Character
                if not cc then break end
                local hh = cc:FindFirstChildOfClass("Humanoid")
                if not hh then break end

                local r15 = isR15Local()

                if not track then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = r15 and "rbxassetid://698251653" or "rbxassetid://72042024"
                    track = hh:LoadAnimation(anim)
                end

                track:Play()
                track:AdjustSpeed(r15 and 0.7 or 0.65)
                track.TimePosition = 0.6
                task.wait(0.1)

                local maxPos = r15 and 0.7 or 0.65
                while track and track.TimePosition < maxPos do
                    task.wait(0.1)
                end

                if track then
                    track:Stop()
                    track = nil
                end
            end
            task.wait()
        end
    end)
end}

-- ============ FUNÇÕES AUXILIARES DO BANG ============
local function isR15Player(plr)
    local char = plr.Character
    if not char then return false end
    return char:FindFirstChild("UpperTorso") ~= nil
end

-- ============ BANG ============
local bangConn = nil
local bangAnimTrack = nil
local bangAnim = nil

local function stopBang()
    if bangConn then bangConn:Disconnect() bangConn = nil end
    if bangAnimTrack then bangAnimTrack:Stop() bangAnimTrack = nil end
    if bangAnim then bangAnim:Destroy() bangAnim = nil end
end

C["bang"] = {a="<nome|random|all>", d="Bang em alguem (troll)", f=function(g)
    stopBang()
    local c = LP.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    bangAnim = Instance.new("Animation")
    bangAnim.AnimationId = isR15Player(LP) and "rbxassetid://5918726674" or "rbxassetid://148840371"
    bangAnimTrack = hum:LoadAnimation(bangAnim)
    bangAnimTrack:Play(0.1, 1, 1)
    bangAnimTrack:AdjustSpeed(tonumber(g[2]) or 3)

    local targets = findPlayers(g[1] or "all")
    if #targets == 0 then return end

    local currentIndex = 1

    bangConn = RunService.Stepped:Connect(function()
        local cc = LP.Character
        if not cc then stopBang() return end
        local root = cc:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local target = targets[currentIndex]
        if not target or not target.Character then
            currentIndex = currentIndex + 1
            if currentIndex > #targets then currentIndex = 1 end
            return
        end

        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local behindPos = targetRoot.CFrame * CFrame.new(0, 0, 1.3)
            root.CFrame = CFrame.new(behindPos.Position, targetRoot.Position)
        end
    end)
end}

C["unbang"] = {a="", d="Para o bang", f=function() stopBang() end}

-- ============ INVISIBLE / VISIBLE (LocalTransparencyModifier) ============
local invisActive = false

local function setInvisibleState(inv)
    local c = LP.Character
    if not c then return end
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then
            v.LocalTransparencyModifier = inv and 1 or 0
            v.Transparency = inv and 1 or 0
        elseif v:IsA("Decal") then
            v.Transparency = inv and 1 or 0
        elseif v:IsA("Accessory") then
            local h = v:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then
                h.LocalTransparencyModifier = inv and 1 or 0
                h.Transparency = inv and 1 or 0
            end
        end
    end
    local head = c:FindFirstChild("Head")
    if head then
        local ng = head:FindFirstChildOfClass("BillboardGui")
        if ng then ng.Enabled = not inv end
    end
end

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if invisActive then setInvisibleState(true) end
end)

C["invisible"] = {a="", d="Fica invisivel", f=function()
    invisActive = true
    setInvisibleState(true)
end}
C["visible"] = {a="", d="Volta a ser visivel", f=function()
    invisActive = false
    setInvisibleState(false)
end}

-- ============ BTOOLS (F3X) ============
C["btools"] = {a="", d="Recebe as Building Tools (F3X)", f=function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/refs/heads/main/f3x.lua"))()
    end)
    if not ok then warn("[Admin] Erro no btools: " .. tostring(err)) end
end}

-- ============ PLATFORM (auto-chão) ============
local platformConn = nil
local platformOn = false
local lastPlatPos = nil
local platforms = {}

C["platform"] = {a="", d="Cria plataformas automaticas por onde andar (toggle)", f=function()
    if platformOn then
        platformOn = false
        if platformConn then platformConn:Disconnect() platformConn = nil end
        for _, p in ipairs(platforms) do
            if p and p.Parent then p:Destroy() end
        end
        platforms = {}
        lastPlatPos = nil
        return
    end

    platformOn = true
    platformConn = RunService.Heartbeat:Connect(function()
        if not platformOn then return end

        local c = LP.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local rayOrigin = hrp.Position
        local rayDir = Vector3.new(0, -1, 0)

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {c}

        local result = workspace:Raycast(rayOrigin, rayDir * 10, params)

        if not result then
            local currentPos = hrp.Position
            if lastPlatPos then
                local dist = (currentPos - lastPlatPos).Magnitude
                if dist < 4 then
                    return
                end
            end

            local plat = Instance.new("Part")
            plat.Name = "AutoPlatform"
            plat.Size = Vector3.new(8, 0.5, 8)
            plat.Position = Vector3.new(currentPos.X, currentPos.Y - 3, currentPos.Z)
            plat.Anchored = true
            plat.CanCollide = true
            plat.Transparency = 0.7
            plat.Color = Color3.fromRGB(0, 170, 255)
            plat.Material = Enum.Material.Neon
            plat.Parent = workspace

            table.insert(platforms, plat)
            lastPlatPos = currentPos

            task.delay(10, function()
                if plat and plat.Parent then
                    plat:Destroy()
                end
            end)
        end
    end)
end}

-- ============ CAMERANOCLIP ============
local camNoclipConn = nil
local camNoclipOn = false
C["cameranoclip"] = {a="", d="Camera atravessa paredes (toggle)", f=function()
    if camNoclipOn then
        camNoclipOn = false
        if camNoclipConn then camNoclipConn:Disconnect() camNoclipConn = nil end
        return
    end
    camNoclipOn = true
    camNoclipConn = RunService.RenderStepped:Connect(function()
        if not camNoclipOn then return end
        local cam = workspace.CurrentCamera
        if cam then
            cam.CanCollide = false
        end
    end)
end}

-- ============ ANTIFLING (consertado) ============
local antiflingConn = nil
local antiflingOn = false

local function setAntiflingOff()
    antiflingOn = false
    if antiflingConn then antiflingConn:Disconnect() antiflingConn = nil end
    local c = LP.Character
    if c then
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = true
            end
        end
    end
end

C["antifling"] = {a="", d="Nao toma fling (toggle)", f=function()
    if antiflingOn then
        setAntiflingOff()
        return
    end

    antiflingOn = true
    antiflingConn = RunService.Stepped:Connect(function()
        if not antiflingOn then return end
        local c = LP.Character
        if not c then return end

        -- Desativa colisão com partes dos OUTROS players
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                for _, v in ipairs(p.Character:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end

        -- Mantém colisão do SEU personagem com paredes
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = true
            end
        end
    end)
end}

C["unantifling"] = {a="", d="Desativa o antifling", f=function()
    if antiflingOn then setAntiflingOff() end
end}

-- ============ ANTIAFK ============
local antiafkConn = nil
local antiafkOn = false

C["antiafk"] = {a="", d="Nao toma kick por AFK (toggle)", f=function()
    if antiafkOn then
        antiafkOn = false
        if antiafkConn then antiafkConn:Disconnect() antiafkConn = nil end
        return
    end

    antiafkOn = true
    antiafkConn = RunService.Heartbeat:Connect(function()
        if not antiafkOn then return end
        local c = LP.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.1)
            h:ChangeState(Enum.HumanoidStateType.Landed)
        end
    end)
end}

C["unantiafk"] = {a="", d="Desativa o antiafk", f=function()
    if antiafkOn then
        antiafkOn = false
        if antiafkConn then antiafkConn:Disconnect() antiafkConn = nil end
    end
end}

-- ============ CONSOLE ============
C["console"] = {a="", d="Abre o Dev Console", f=function()
    pcall(function()
        game:GetService("StarterGui"):SetCore("DevConsoleVisible", true)
    end)
end}

-- ============ LALOL HUB (Backdoor Scanner) ============
C["lalolhub"] = {a="", d="LALOL Hub Backdoor Scanner | Creditos: Its_LALOL | Server sider (backdoor) - so funciona em jogos com seguranca fraca ou com backdoor", f=function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Its-LALOL/LALOL-Hub/main/Backdoor-Scanner/script"))()
    end)
    if not ok then
        warn("[Admin] Erro no lalolhub: " .. tostring(err))
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "LALOL Hub",
                Text = "Erro ao carregar. Verifique o link ou tente em outro jogo.",
                Duration = 5
            })
        end)
    end
end}

-- ============ INFINITE YIELD ============
C["infiniteyield"] = {a="", d="Executa o Infinite Yield", f=function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
    end)
    if not ok then warn("[Admin] Erro no infiniteyield: " .. tostring(err)) end
end}

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if miniOn then miniOn = false origSizes = {} end
    if flingOn then flingOn = false if flingThread then task.cancel(flingThread) end end
    if spinning then spinning = false if spinConn then spinConn:Disconnect() spinConn = nil end end
    stopView()
    stopBang()
end)

_G.AdminHub = { PREFIX = PREFIX, Commands = C, LP = LP, Players = Players }
print("[Admin] Partes 1, 2, 3A e 3B OK. Cole a Parte 4 abaixo.")
local hub = _G.AdminHub
if not hub then warn("[Admin] Rode as Partes 1, 2 e 3 primeiro!") return end

local PREFIX = hub.PREFIX
local C = hub.Commands
local LP = hub.LP

local function getPrefix()
    return _G.AdminHub and _G.AdminHub.PREFIX or PREFIX
end

local SG = Instance.new("ScreenGui")
SG.Name = "AdminUI"
SG.Parent = LP:WaitForChild("PlayerGui")
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.DisplayOrder = 999

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0,50,0,50)
Btn.Position = UDim2.new(0,20,0,100)
Btn.BackgroundColor3 = Color3.fromRGB(20,20,20)
Btn.Text = ">_"
Btn.TextColor3 = Color3.fromRGB(255,255,255)
Btn.Font = Enum.Font.Code
Btn.TextSize = 18
Btn.Active = true
Btn.Draggable = false
Btn.Parent = SG

local BtnC = Instance.new("UICorner")
BtnC.CornerRadius = UDim.new(0,10)
BtnC.Parent = Btn

local BtnS = Instance.new("UIStroke")
BtnS.Color = Color3.fromRGB(80,80,80)
BtnS.Thickness = 2
BtnS.Parent = Btn

local Box = Instance.new("Frame")
Box.Size = UDim2.new(0,400,0,249)
Box.Position = UDim2.new(0.5,0,1,-20)
Box.AnchorPoint = Vector2.new(0.5,1)
Box.BackgroundTransparency = 1
Box.Visible = false
Box.Parent = SG

local Sug = Instance.new("ScrollingFrame")
Sug.Size = UDim2.new(1,0,0,200)
Sug.BackgroundColor3 = Color3.fromRGB(20,20,20)
Sug.BackgroundTransparency = 0.05
Sug.BorderSizePixel = 0
Sug.ScrollBarThickness = 8
Sug.ScrollBarImageColor3 = Color3.fromRGB(100,100,100)
Sug.ScrollingDirection = Enum.ScrollingDirection.Y
Sug.CanvasSize = UDim2.new(0,0,0,0)
Sug.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sug.Parent = Box

local SugC = Instance.new("UICorner")
SugC.CornerRadius = UDim.new(0,6)
SugC.Parent = Sug

local SugS = Instance.new("UIStroke")
SugS.Color = Color3.fromRGB(80,80,80)
SugS.Thickness = 1
SugS.Parent = Sug

local SugP = Instance.new("UIPadding")
SugP.PaddingTop = UDim.new(0,4)
SugP.PaddingBottom = UDim.new(0,4)
SugP.PaddingLeft = UDim.new(0,4)
SugP.PaddingRight = UDim.new(0,8)
SugP.Parent = Sug

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0,3)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Sug

local Bar = Instance.new("Frame")
Bar.Size = UDim2.new(1,0,0,44)
Bar.Position = UDim2.new(0,0,0,205)
Bar.BackgroundColor3 = Color3.fromRGB(20,20,20)
Bar.BackgroundTransparency = 0.05
Bar.BorderSizePixel = 0
Bar.Parent = Box

local BarC = Instance.new("UICorner")
BarC.CornerRadius = UDim.new(0,6)
BarC.Parent = Bar

local BarS = Instance.new("UIStroke")
BarS.Color = Color3.fromRGB(80,80,80)
BarS.Thickness = 1
BarS.Parent = Bar

local Pref = Instance.new("TextLabel")
Pref.Size = UDim2.new(0,20,1,0)
Pref.Position = UDim2.new(0,10,0,0)
Pref.BackgroundTransparency = 1
Pref.Text = ">"
Pref.TextColor3 = Color3.fromRGB(180,180,180)
Pref.Font = Enum.Font.Code
Pref.TextSize = 18
Pref.TextXAlignment = Enum.TextXAlignment.Left
Pref.Parent = Bar

local Input = Instance.new("TextBox")
Input.Size = UDim2.new(1,-40,1,0)
Input.Position = UDim2.new(0,30,0,0)
Input.BackgroundTransparency = 1
Input.Text = ""
Input.PlaceholderText = "Digite um comando..."
Input.TextColor3 = Color3.fromRGB(255,255,255)
Input.PlaceholderColor3 = Color3.fromRGB(100,100,100)
Input.Font = Enum.Font.Code
Input.TextSize = 16
Input.TextXAlignment = Enum.TextXAlignment.Left
Input.ClearTextOnFocus = false
Input.Parent = Bar

local isOpen = false

local function clearSug()
    for _,c in ipairs(Sug:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
end

local function getFiltered(t)
    t = t:lower()
    local l = {}
    for n,d in pairs(C) do
        if t == "" or n:lower():find(t,1,true) then table.insert(l, {name=n, data=d}) end
    end
    table.sort(l, function(a,b) return a.name < b.name end)
    return l
end

local function createBtn(cmd)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,34)
    b.BackgroundColor3 = Color3.fromRGB(35,35,35)
    b.BorderSizePixel = 0
    b.Text = "  "..getPrefix()..cmd.name.." "..cmd.data.a.."  —  "..cmd.data.d
    b.TextColor3 = Color3.fromRGB(220,220,220)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Font = Enum.Font.Code
    b.TextSize = 13
    b.Parent = Sug
    local cor = Instance.new("UICorner")
    cor.CornerRadius = UDim.new(0,4)
    cor.Parent = b
    b.MouseButton1Click:Connect(function()
        Input.Text = cmd.name.." "
        task.defer(function() Input:CaptureFocus() Input.CursorPosition = #Input.Text+1 end)
    end)
end

local function updateSug(t)
    clearSug()
    for _,cmd in ipairs(getFiltered(t)) do createBtn(cmd) end
end

local function openBar()
    if isOpen then return end
    isOpen = true
    Box.Visible = true
    Btn.Text = "X"
    Input.Text = ""
    updateSug("")
    task.defer(function() Input:CaptureFocus() end)
end

local function closeBar()
    if not isOpen then return end
    isOpen = false
    Box.Visible = false
    Input.Text = ""
    Btn.Text = ">_"
    pcall(function() if Input:IsFocused() then Input:ReleaseFocus() end end)
end

local function toggleBar() if isOpen then closeBar() else openBar() end end

local function exec(input)
    local p = getPrefix()
    local raw = input
    if raw:sub(1,#p) == p then raw = raw:sub(#p+1) end
    local args = {}
    for w in raw:gmatch("%S+") do table.insert(args, w) end
    local name = table.remove(args, 1)
    if not name then return end
    local cmd = C[name:lower()]
    if cmd then
        local ok,err = pcall(cmd.f, args)
        if not ok then warn("[Admin] Erro em "..name..": "..tostring(err)) end
    end
end

Btn.Activated:Connect(toggleBar)

Input:GetPropertyChangedSignal("Text"):Connect(function()
    if not isOpen then return end
    local t = Input.Text
    local p = getPrefix()
    if t:sub(1,#p) == p then t = t:sub(#p+1) end
    updateSug(t)
end)

Input.FocusLost:Connect(function(enter)
    if not isOpen then return end
    if enter then exec(Input.Text) closeBar() end
end)

print("[Admin] UI carregada! Toque no '>_' pra abrir.")
