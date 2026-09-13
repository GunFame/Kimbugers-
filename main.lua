--[[
    Kimbugers ♡ v1.3 Runtime Detector / Vehicle Test
    Run this while:
      1) clocked into the Bloxburg job that Kimbugers should detect
      2) seated in the vehicle whose speed you want to change

    This does NOT claim job automation is wired yet. It captures the live
    Bloxburg paths needed to wire it correctly instead of guessing.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
local GUI_NAME = "KimbugersRuntimeDetector"
local ROOT = "Kimbugers"
local REPORT_PATH = ROOT .. "/runtime_dump.txt"

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Kimbugers ♡ detector",
            Text = tostring(text),
            Duration = 5,
        })
    end)
end

local function safeDestroyOld()
    local roots = {CoreGui, LP and LP:FindFirstChildOfClass("PlayerGui")}
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then table.insert(roots, 1, hui) end
    end
    for _, root in ipairs(roots) do
        if root then
            local old = root:FindFirstChild(GUI_NAME)
            if old then pcall(function() old:Destroy() end) end
        end
    end
end
safeDestroyOld()

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local KEYWORDS = {
    "job","work","shift","task","employ","occupation",
    "pizza","burger","cashier","delivery","deliver","clean",
    "stock","mechanic","fish","mine","wood","hair","icecream",
    "earn","paycheck","efficiency","customer","order",
    "build","plot","place","placement","furniture","object","blueprint"
}

local KNOWN_JOB_WORDS = {
    "pizza","delivery","cashier","burger","bloxy","janitor","cleaner",
    "stocker","supermarket","mechanic","fisherman","fishing","miner",
    "woodcutter","wood","hairdresser","ice cream","icecream","baker"
}

local function relevant(s)
    s = tostring(s or ""):lower()
    for _, k in ipairs(KEYWORDS) do
        if s:find(k, 1, true) then return true end
    end
    return false
end

local function safeFullName(obj)
    local ok, name = pcall(function() return obj:GetFullName() end)
    return ok and name or tostring(obj)
end

local function getHumanoid()
    local c = LP and LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getSeat()
    local h = getHumanoid()
    local seat = h and h.SeatPart
    if seat and seat:IsA("BasePart") then return seat end
    return nil
end

local function getVehicleModel(seat)
    if not seat then return nil end
    local best = nil
    local p = seat.Parent
    local depth = 0
    while p and p ~= workspace and depth < 8 do
        if p:IsA("Model") then
            best = p
            local n = p.Name:lower()
            if n:find("vehicle") or n:find("car") or n:find("bike") or n:find("motor") or n:find("scooter") then
                return p
            end
        end
        p = p.Parent
        depth += 1
    end
    return best
end

local function getRoot(seat, vehicle)
    if not seat then return nil end
    local root = seat.AssemblyRootPart
    if root then return root end
    if vehicle then
        if vehicle.PrimaryPart then return vehicle.PrimaryPart end
        for _, d in ipairs(vehicle:GetDescendants()) do
            if d:IsA("BasePart") and not d.Anchored then return d end
        end
    end
    return seat
end

local function modelPartCount(model)
    if not model then return 0 end
    local n = 0
    for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
    return n
end

local function detectJobFromAttributes()
    local roots = {LP, LP and LP.Character}
    for _, root in ipairs(roots) do
        if root then
            local ok, attrs = pcall(function() return root:GetAttributes() end)
            if ok then
                for name, value in pairs(attrs) do
                    if relevant(name) or relevant(value) then
                        local sv = trim(value)
                        if sv ~= "" and sv ~= "false" and sv ~= "0" then
                            return tostring(value), "attribute: " .. safeFullName(root) .. "." .. tostring(name)
                        end
                    end
                end
            end
        end
    end
end

local function detectJobFromValues()
    local roots = {LP, LP and LP.Character}
    for _, root in ipairs(roots) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("StringValue") or d:IsA("ObjectValue") or d:IsA("IntValue") or d:IsA("NumberValue") or d:IsA("BoolValue") then
                    if relevant(d.Name) then
                        local ok, value = pcall(function() return d.Value end)
                        if ok and value ~= nil then
                            local text = typeof(value) == "Instance" and value.Name or tostring(value)
                            if trim(text) ~= "" and text ~= "false" and text ~= "0" then
                                return text, "value: " .. safeFullName(d)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function detectJobFromGui()
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end

    local bestText, bestPath, bestScore = nil, nil, 0
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local ok, text = pcall(function() return trim(d.Text) end)
            if ok and text ~= "" and #text <= 120 then
                local low = text:lower()
                local score = 0
                for _, word in ipairs(KNOWN_JOB_WORDS) do
                    if low:find(word, 1, true) then score += 5 end
                end
                if relevant(d.Name) then score += 3 end
                if low:find("job", 1, true) or low:find("work", 1, true) or low:find("shift", 1, true) then score += 2 end
                if score > bestScore then
                    bestScore, bestText, bestPath = score, text, safeFullName(d)
                end
            end
        end
    end
    if bestScore > 0 then return bestText, "gui: " .. tostring(bestPath) end
end

local function detectJob()
    local a,b = detectJobFromAttributes(); if a then return a,b end
    a,b = detectJobFromValues(); if a then return a,b end
    a,b = detectJobFromGui(); if a then return a,b end
    return "Not detected", "No obvious job value/text found"
end

local function collectReport()
    local lines = {}
    local function add(s) lines[#lines+1] = tostring(s) end
    add("Kimbugers ♡ v1.3 runtime report")
    add("PlaceId: " .. tostring(game.PlaceId))
    add("JobId: " .. tostring(game.JobId))
    add("Player: " .. tostring(LP and LP.Name))
    add("")

    local seat = getSeat()
    local vehicle = getVehicleModel(seat)
    local root = getRoot(seat, vehicle)
    add("[SEAT / VEHICLE]")
    add("Seat: " .. (seat and (seat.ClassName .. " | " .. safeFullName(seat)) or "NONE"))
    add("Vehicle model: " .. (vehicle and safeFullName(vehicle) or "NONE"))
    add("Vehicle part count: " .. tostring(modelPartCount(vehicle)))
    add("Assembly root: " .. (root and safeFullName(root) or "NONE"))
    if seat and seat:IsA("VehicleSeat") then
        add("VehicleSeat.MaxSpeed: " .. tostring(seat.MaxSpeed))
        add("VehicleSeat.Torque: " .. tostring(seat.Torque))
        add("VehicleSeat.TurnSpeed: " .. tostring(seat.TurnSpeed))
    end
    if root then add("Assembly speed: " .. tostring(root.AssemblyLinearVelocity.Magnitude)) end
    add("")

    local job, source = detectJob()
    add("[JOB DETECTION]")
    add("Detected job: " .. tostring(job))
    add("Source: " .. tostring(source))
    add("")

    add("[PLAYER ATTRIBUTES / VALUES RELATED TO JOBS]")
    for _, obj in ipairs({LP, LP and LP.Character}) do
        if obj then
            local ok, attrs = pcall(function() return obj:GetAttributes() end)
            if ok then
                for name, value in pairs(attrs) do
                    if relevant(name) or relevant(value) then
                        add("ATTR " .. safeFullName(obj) .. "." .. tostring(name) .. " = " .. tostring(value))
                    end
                end
            end
            for _, d in ipairs(obj:GetDescendants()) do
                if (d:IsA("ValueBase") or d:IsA("ObjectValue")) and relevant(d.Name) then
                    local ok2, value = pcall(function() return d.Value end)
                    if ok2 then add("VALUE " .. safeFullName(d) .. " = " .. tostring(value)) end
                end
            end
        end
    end
    add("")

    add("[PLAYERGUI JOB/WORK TEXT]")
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local guiCount = 0
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if guiCount >= 120 then break end
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local ok, text = pcall(function() return trim(d.Text) end)
                if ok and text ~= "" and (relevant(d.Name) or relevant(text)) then
                    guiCount += 1
                    add(safeFullName(d) .. " | " .. text:gsub("\n", " "))
                end
            elseif relevant(d.Name) and (d:IsA("Frame") or d:IsA("ScreenGui")) then
                guiCount += 1
                add(safeFullName(d) .. " | <" .. d.ClassName .. ">")
            end
        end
    end
    if guiCount == 0 then add("NONE FOUND") end
    add("")

    add("[JOB-LIKE REMOTES / MODULES IN REPLICATEDSTORAGE]")
    local remoteCount = 0
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if remoteCount >= 160 then break end
        local path = safeFullName(d)
        if relevant(d.Name) or relevant(path) then
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") or d:IsA("ModuleScript") then
                remoteCount += 1
                add(d.ClassName .. " | " .. path)
            end
        end
    end
    if remoteCount == 0 then add("NONE FOUND") end
    add("")

    add("[VEHICLE MODEL SPEED-LIKE VALUES / ATTRIBUTES]")
    if vehicle then
        local vcount = 0
        for _, d in ipairs(vehicle:GetDescendants()) do
            if vcount >= 120 then break end
            local low = d.Name:lower()
            if low:find("speed",1,true) or low:find("torque",1,true) or low:find("motor",1,true) or low:find("drive",1,true) or low:find("velocity",1,true) then
                if d:IsA("ValueBase") or d:IsA("ObjectValue") then
                    local ok, value = pcall(function() return d.Value end)
                    if ok then
                        vcount += 1
                        add(d.ClassName .. " | " .. safeFullName(d) .. " = " .. tostring(value))
                    end
                elseif d:IsA("BasePart") or d:IsA("Constraint") then
                    vcount += 1
                    add(d.ClassName .. " | " .. safeFullName(d))
                end
            end
            local ok, attrs = pcall(function() return d:GetAttributes() end)
            if ok then
                for name,value in pairs(attrs) do
                    local n = tostring(name):lower()
                    if n:find("speed",1,true) or n:find("torque",1,true) or n:find("drive",1,true) then
                        vcount += 1
                        add("ATTR " .. safeFullName(d) .. "." .. tostring(name) .. " = " .. tostring(value))
                        if vcount >= 120 then break end
                    end
                end
            end
        end
        if vcount == 0 then add("NONE FOUND") end
    else
        add("NO VEHICLE MODEL DETECTED")
    end

    return table.concat(lines, "\n")
end

local function ensureFolder()
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then return false end
    pcall(function() if not isfolder(ROOT) then makefolder(ROOT) end end)
    local ok, exists = pcall(isfolder, ROOT)
    return ok and exists
end

local lastReport = ""
local function refreshReport()
    lastReport = collectReport()
    print("\n" .. lastReport .. "\n")
    if type(writefile) == "function" and ensureFolder() then
        pcall(writefile, REPORT_PATH, lastReport)
    end
    return lastReport
end

-- =========================================================
-- Vehicle speed test
-- =========================================================
local SpeedTest = {
    enabled = false,
    targetMph = 80,
    keyW = false,
    keyS = false,
    lastSeat = nil,
    originalMaxSpeed = nil,
    originalTorque = nil,
    serverOverride = false,
    appliedAt = 0,
}

local function studsForMph(mph)
    return math.max(0, tonumber(mph) or 0) / 0.626
end

local function getDriveDirection(seat)
    local throttle = 0
    if seat and seat:IsA("VehicleSeat") then throttle = seat.ThrottleFloat end
    if math.abs(throttle) < .05 then
        if SpeedTest.keyW then throttle = 1 elseif SpeedTest.keyS then throttle = -1 end
    end
    if math.abs(throttle) < .05 then return nil end
    local sign = throttle >= 0 and 1 or -1
    return seat.CFrame.LookVector * sign
end

local function restoreVehicleSeat()
    local seat = SpeedTest.lastSeat
    if seat and seat.Parent and seat:IsA("VehicleSeat") then
        if SpeedTest.originalMaxSpeed then pcall(function() seat.MaxSpeed = SpeedTest.originalMaxSpeed end) end
        if SpeedTest.originalTorque then pcall(function() seat.Torque = SpeedTest.originalTorque end) end
    end
    SpeedTest.lastSeat = nil
    SpeedTest.originalMaxSpeed = nil
    SpeedTest.originalTorque = nil
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.W then SpeedTest.keyW = true end
    if input.KeyCode == Enum.KeyCode.S then SpeedTest.keyS = true end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then SpeedTest.keyW = false end
    if input.KeyCode == Enum.KeyCode.S then SpeedTest.keyS = false end
end)

RunService.Heartbeat:Connect(function()
    if not SpeedTest.enabled then return end
    local seat = getSeat()
    if not seat then return end
    if SpeedTest.lastSeat ~= seat then
        restoreVehicleSeat()
        SpeedTest.lastSeat = seat
        if seat:IsA("VehicleSeat") then
            SpeedTest.originalMaxSpeed = seat.MaxSpeed
            SpeedTest.originalTorque = seat.Torque
        end
    end

    local target = studsForMph(SpeedTest.targetMph)
    if seat:IsA("VehicleSeat") then
        pcall(function()
            seat.MaxSpeed = math.max(seat.MaxSpeed, target)
            seat.Torque = math.max(seat.Torque, 5000)
        end)
    end

    local vehicle = getVehicleModel(seat)
    local root = getRoot(seat, vehicle)
    local dir = getDriveDirection(seat)
    if root and dir and not root.Anchored then
        local v = root.AssemblyLinearVelocity
        local horizontal = Vector3.new(v.X, 0, v.Z)
        local desired = target
        -- Accelerate toward target instead of multiplying every frame.
        local current = horizontal.Magnitude
        if current < desired then
            local nextSpeed = math.min(desired, current + math.max(2, desired * 0.035))
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(dir.X * nextSpeed, v.Y, dir.Z * nextSpeed)
            end)
        end
        if SpeedTest.appliedAt == 0 then SpeedTest.appliedAt = os.clock() end
    end
end)

-- =========================================================
-- Cute diagnostic GUI
-- =========================================================
local function N(class, props)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k] = v end
    return o
end
local function round(o, r) N("UICorner", {Parent=o, CornerRadius=UDim.new(0,r or 12)}) end
local function stroke(o, color, trans)
    return N("UIStroke", {Parent=o, Color=color or Color3.fromRGB(182,218,247), Thickness=1.2, Transparency=trans or .2})
end
local BLUE = Color3.fromRGB(91,169,239)
local BLUE2 = Color3.fromRGB(211,235,255)
local BG = Color3.fromRGB(239,248,255)
local PANEL = Color3.fromRGB(255,255,255)
local TEXT = Color3.fromRGB(63,102,135)
local MUTED = Color3.fromRGB(111,145,173)

local gui = N("ScreenGui", {Name=GUI_NAME, ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
pcall(function() gui.Parent = (type(gethui)=="function" and gethui()) or CoreGui end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = N("Frame", {Parent=gui, AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), Size=UDim2.fromOffset(650,500), BackgroundColor3=BG, BorderSizePixel=0})
round(main,24); stroke(main,BLUE,.08)
local top = N("Frame", {Parent=main, Size=UDim2.new(1,0,0,76), BackgroundColor3=BLUE, BorderSizePixel=0})
round(top,24)
local topMask = N("Frame", {Parent=top, Position=UDim2.new(0,0,1,-24), Size=UDim2.new(1,0,0,24), BackgroundColor3=BLUE, BorderSizePixel=0})
local title = N("TextLabel", {Parent=top, BackgroundTransparency=1, Position=UDim2.fromOffset(20,10), Size=UDim2.new(1,-40,0,34), Text="Kimbugers ♡ runtime detector", Font=Enum.Font.FredokaOne, TextSize=25, TextColor3=Color3.new(1,1,1), TextXAlignment=Enum.TextXAlignment.Left})
local subtitle = N("TextLabel", {Parent=top, BackgroundTransparency=1, Position=UDim2.fromOffset(21,42), Size=UDim2.new(1,-40,0,20), Text="sit in your car + clock into your job (or enter build mode), then refresh ♡", Font=Enum.Font.GothamSemibold, TextSize=11, TextColor3=Color3.fromRGB(238,248,255), TextXAlignment=Enum.TextXAlignment.Left})

local body = N("Frame", {Parent=main, Position=UDim2.fromOffset(14,90), Size=UDim2.new(1,-28,1,-104), BackgroundTransparency=1})
local layout = N("UIListLayout", {Parent=body, Padding=UDim.new(0,9), SortOrder=Enum.SortOrder.LayoutOrder})

local function card(height)
    local f=N("Frame",{Parent=body,Size=UDim2.new(1,0,0,height),BackgroundColor3=PANEL,BorderSizePixel=0})
    round(f,16); stroke(f,BLUE2,.12); return f
end
local function label(parent,text,pos,size,fontSize,bold,color)
    return N("TextLabel",{Parent=parent,BackgroundTransparency=1,Position=pos,Size=size,Text=text,Font=bold and Enum.Font.FredokaOne or Enum.Font.GothamSemibold,TextSize=fontSize or 12,TextColor3=color or TEXT,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
end
local function button(parent,text,pos,size,cb)
    local b=N("TextButton",{Parent=parent,Position=pos,Size=size,BackgroundColor3=BLUE,BorderSizePixel=0,Text=text,Font=Enum.Font.FredokaOne,TextSize=12,TextColor3=Color3.new(1,1,1),AutoButtonColor=false})
    round(b,12); b.MouseButton1Click:Connect(cb); return b
end

local status = card(116)
label(status,"♡ LIVE DETECTION",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,24),15,true,BLUE)
local seatLine=label(status,"Seat: checking...",UDim2.fromOffset(16,37),UDim2.new(1,-32,0,20),12,false,TEXT)
local carLine=label(status,"Vehicle: checking...",UDim2.fromOffset(16,58),UDim2.new(1,-32,0,20),12,false,TEXT)
local jobLine=label(status,"Job: checking...",UDim2.fromOffset(16,79),UDim2.new(1,-32,0,25),12,false,TEXT)

local speedCard = card(130)
label(speedCard,"♡ VEHICLE SPEED TEST",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,24),15,true,BLUE)
local speedLine=label(speedCard,"Current: 0 mph   •   Target: 80 mph",UDim2.fromOffset(16,36),UDim2.new(1,-32,0,20),12,false,TEXT)
local minus=button(speedCard,"− 10",UDim2.fromOffset(16,68),UDim2.fromOffset(80,34),function() SpeedTest.targetMph=math.max(20,SpeedTest.targetMph-10) end)
local plus=button(speedCard,"+ 10",UDim2.fromOffset(104,68),UDim2.fromOffset(80,34),function() SpeedTest.targetMph=math.min(250,SpeedTest.targetMph+10) end)
local toggle=button(speedCard,"START SPEED TEST",UDim2.fromOffset(194,68),UDim2.new(1,-210,0,34),function()
    SpeedTest.enabled = not SpeedTest.enabled
    SpeedTest.appliedAt = 0
    if not SpeedTest.enabled then restoreVehicleSeat() end
    notify(SpeedTest.enabled and "Vehicle speed test ON ♡" or "Vehicle speed test OFF")
end)
label(speedCard,"Hold W/S while seated. If the server owns the car, Bloxburg may overwrite client velocity.",UDim2.fromOffset(16,103),UDim2.new(1,-32,0,18),10,false,MUTED)

local reportCard = card(126)
label(reportCard,"♡ RUNTIME REPORT",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,24),15,true,BLUE)
label(reportCard,"This captures the exact job/vehicle paths Kimbugers needs instead of guessing.",UDim2.fromOffset(16,35),UDim2.new(1,-32,0,22),11,false,MUTED)
button(reportCard,"REFRESH + SAVE REPORT",UDim2.fromOffset(16,67),UDim2.fromOffset(195,36),function()
    refreshReport(); notify("Runtime report refreshed ♡")
end)
button(reportCard,"COPY REPORT",UDim2.fromOffset(219,67),UDim2.fromOffset(130,36),function()
    if lastReport=="" then refreshReport() end
    if type(setclipboard)=="function" then
        pcall(setclipboard,lastReport); notify("Report copied ♡")
    else
        notify("setclipboard() isn't available; use the saved file/console output.")
    end
end)
button(reportCard,"PRINT REPORT",UDim2.fromOffset(357,67),UDim2.new(1,-373,0,36),function()
    print("\n"..refreshReport().."\n"); notify("Report printed to console ♡")
end)
label(reportCard,"Saved as Kimbugers/runtime_dump.txt when writefile() is supported.",UDim2.fromOffset(16,105),UDim2.new(1,-32,0,18),10,false,MUTED)

local help=card(52)
label(help,"♥ Right Shift hides/shows this detector  •  this is the diagnostic build, not another fake Auto Work button",UDim2.fromOffset(15,10),UDim2.new(1,-30,0,32),11,false,TEXT)

local open=true
UIS.InputBegan:Connect(function(i,gp)
    if gp or UIS:GetFocusedTextBox() then return end
    if i.KeyCode==Enum.KeyCode.RightShift then open=not open; main.Visible=open end
end)

-- Dragging
local dragging=false; local dragStart; local startPos
top.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; dragStart=i.Position; startPos=main.Position end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)

local lastJobScan=0
RunService.Heartbeat:Connect(function()
    if not main.Parent then return end
    local seat=getSeat()
    local vehicle=getVehicleModel(seat)
    local root=getRoot(seat,vehicle)
    seatLine.Text="Seat: "..(seat and (seat.ClassName.."  •  "..seat.Name) or "NONE")
    carLine.Text="Vehicle: "..(vehicle and vehicle.Name or "NONE")
    local mph=root and (root.AssemblyLinearVelocity.Magnitude*.626) or 0
    speedLine.Text=string.format("Current: %.0f mph   •   Target: %d mph",mph,SpeedTest.targetMph)
    toggle.Text=SpeedTest.enabled and "STOP SPEED TEST" or "START SPEED TEST"
    toggle.BackgroundColor3=SpeedTest.enabled and Color3.fromRGB(238,121,171) or BLUE

    if os.clock()-lastJobScan > 1 then
        lastJobScan=os.clock()
        local job,source=detectJob()
        jobLine.Text="Job: "..tostring(job).."   •   "..tostring(source)
    end
end)

refreshReport()
notify("Detector loaded — car/job/build mode ready; press REFRESH ♡")
print("[Kimbugers] v1.3 runtime detector loaded")
