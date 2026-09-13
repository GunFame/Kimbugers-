--[[
    Kimbugers ♡ v2.0 FULL HUB
    Bloxburg-focused modular hub foundation

    GitHub repository: Kimbugers

    This base intentionally keeps Bloxburg-specific Auto Build / Auto Work logic
    behind adapters so those systems can be added later without rewriting the UI.
    It does not spoof payouts, bypass paid entitlements, or include anti-cheat evasion.
]]

-- executor-safe bootstrap: always replace older Kimbugers builds instead of returning early
local ENV = (type(getgenv)=="function" and getgenv()) or _G
print("[Kimbugers ♡] bootstrap v2.0.1")

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- remove any older Kimbugers UI from the same Roblox session
pcall(function()
    if type(ENV.KimbugersCleanup)=="function" then ENV.KimbugersCleanup() end
end)
pcall(function()
    ENV.KimbugersToggle = nil
    ENV.KimbugersLoaded = nil
    _G.KimbugersToggle = nil
    _G.KimbugersLoaded = nil
end)
local function destroyOldGui(parent)
    if not parent then return end
    for _,name in ipairs({"Kimbugers","KimbugersRuntimeDetector","UniversalBlueprintScanner"}) do
        local oldGui=parent:FindFirstChild(name)
        if oldGui then pcall(function() oldGui:Destroy() end) end
    end
end
pcall(function() if type(gethui)=="function" then destroyOldGui(gethui()) end end)
pcall(function() destroyOldGui(CoreGui) end)
pcall(function() destroyOldGui(LP:FindFirstChildOfClass("PlayerGui")) end)

local BUILD = "v2.0.1-executor-safe"
local ROOT = "Kimbugers"
local PLOTS = ROOT .. "/Plots"
local CONFIG = ROOT .. "/config.json"

local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Kimbugers ♡",
            Text = tostring(msg),
            Duration = 3,
        })
    end)
end

local function clamp(n,a,b)
    n = tonumber(n) or a
    return math.max(a, math.min(b,n))
end

local function getHumanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local FILES = {
    rw = type(writefile)=="function" and type(readfile)=="function",
    folders = type(makefolder)=="function" and type(isfolder)=="function",
    list = type(listfiles)=="function",
    exists = type(isfile)=="function",
}
local function ensureFolders()
    if not FILES.folders then return end
    pcall(function()
        if not isfolder(ROOT) then makefolder(ROOT) end
        if not isfolder(PLOTS) then makefolder(PLOTS) end
    end)
end
ensureFolders()

local State = {
    page = "Overview",
    open = true,
    theme = "Blue",
    uiScale = 1,
    player = {speedOn=false, speed=16, jumpOn=false, jump=50, fov=70},
    build = {
        status="Planner Ready", selected=nil,
        noGamepass=true, autoAdapt=true, structureOnly=false,
        estimate=true, skipFailed=true, budget=150000, snap="15°",
    },
    jobs = {
        status="Idle", mode="Chill", autoNext=true,
        normalMovement=true, autoReturn=true,
        stopMinutes=0, stopEarnings=0, tasks=0, earned=0,
        tracking=false, paused=false, elapsed=0, lastTick=nil,
    },
    vehicle = {
        hud=true, unit="MPH", cameraBoost=false, cameraFov=82,
        speedModifier=1.2, keepModifier=true,
    },
    env = {
        shadows=false, darkness=70, softness=28,
        lights=false, brightness=160, glow=30,
        timeOn=false, clockTime=14, fogOn=false, fogEnd=650,
        saturation=0, contrast=0, brightnessFX=0,
    },
    visuals = {cinematic=false, dof=25, bloom=15, blur=0},
    anim = {selected="Wave", loop=false, speed=1},
    navigation = {selectedJob="Blox Burgers Employee"},
}

-- =========================================================
-- Modular adapters
-- =========================================================
local Adapters = {Build=nil, Jobs=nil, Teleports=nil}
local JobModules = {}
local API = {}
function API:RegisterBuildAdapter(a) Adapters.Build=a; notify("Build adapter connected ♡") end
function API:RegisterJobsAdapter(a) Adapters.Jobs=a; notify("Jobs adapter connected ♡") end
function API:RegisterJobModule(jobId,module) JobModules[jobId]=module; notify("Job module connected: "..tostring(jobId).." ♡") end
function API:GetJobModules() return JobModules end
function API:RegisterTeleportAdapter(a) Adapters.Teleports=a; notify("Teleport adapter connected ♡") end
function API:GetState() return State end
function API:GetBuild() return BUILD end
_G.KimbugersAPI = API

-- =========================================================
-- Config
-- =========================================================
local function merge(dst,src)
    if type(dst)~="table" or type(src)~="table" then return end
    for k,v in pairs(src) do
        if type(v)=="table" and type(dst[k])=="table" then merge(dst[k],v)
        elseif dst[k]~=nil then dst[k]=v end
    end
end

local function saveConfig()
    if not FILES.rw then notify("Local file saving isn't available.") return end
    ensureFolders()
    local ok,data = pcall(HttpService.JSONEncode,HttpService,State)
    if ok and pcall(writefile,CONFIG,data) then notify("Config saved ♡") else notify("Config save failed.") end
end

local function loadConfig()
    if not FILES.rw then return end
    if FILES.exists and not isfile(CONFIG) then return end
    local ok,raw = pcall(readfile,CONFIG)
    if not ok or not raw or raw=="" then return end
    local ok2,data = pcall(HttpService.JSONDecode,HttpService,raw)
    if ok2 then merge(State,data) end
end
loadConfig()

-- =========================================================
-- Theme / Kimqetras-style appearance
-- =========================================================
local TweenService = game:GetService("TweenService")

local Themes = {
    Pink={
        bg=Color3.fromRGB(255,239,247), bg2=Color3.fromRGB(255,247,251),
        panel=Color3.fromRGB(255,255,255), soft=Color3.fromRGB(255,244,249),
        accent=Color3.fromRGB(243,135,187), accent2=Color3.fromRGB(255,210,234),
        text=Color3.fromRGB(91,61,76), muted=Color3.fromRGB(151,111,132),
        stroke=Color3.fromRGB(247,199,223), white=Color3.fromRGB(255,255,255),
    },
    Lilac={
        bg=Color3.fromRGB(244,241,255), bg2=Color3.fromRGB(250,248,255),
        panel=Color3.fromRGB(255,255,255), soft=Color3.fromRGB(250,247,255),
        accent=Color3.fromRGB(150,139,235), accent2=Color3.fromRGB(221,218,255),
        text=Color3.fromRGB(91,91,137), muted=Color3.fromRGB(131,131,174),
        stroke=Color3.fromRGB(214,210,245), white=Color3.fromRGB(255,255,255),
    },
    Blue={
        bg=Color3.fromRGB(238,248,255), bg2=Color3.fromRGB(247,252,255),
        panel=Color3.fromRGB(255,255,255), soft=Color3.fromRGB(248,253,255),
        accent=Color3.fromRGB(91,169,239), accent2=Color3.fromRGB(207,232,255),
        text=Color3.fromRGB(65,104,137), muted=Color3.fromRGB(109,145,174),
        stroke=Color3.fromRGB(193,222,247), white=Color3.fromRGB(255,255,255),
    },
    Red={
        bg=Color3.fromRGB(255,241,243), bg2=Color3.fromRGB(255,249,250),
        panel=Color3.fromRGB(255,255,255), soft=Color3.fromRGB(255,246,247),
        accent=Color3.fromRGB(235,92,111), accent2=Color3.fromRGB(255,207,214),
        text=Color3.fromRGB(119,62,72), muted=Color3.fromRGB(164,112,121),
        stroke=Color3.fromRGB(246,190,199), white=Color3.fromRGB(255,255,255),
    },
}
local themed = {}
local gradients = {}
local function T() return Themes[State.theme] or Themes.Blue end
local function track(o,role) themed[o]=role return o end
local function trackGradient(g) gradients[g]=true return g end
local function applyTheme()
    local t=T()
    for o,r in pairs(themed) do
        if not o or not o.Parent then themed[o]=nil else
            pcall(function()
                if r=="bg" then o.BackgroundColor3=t.bg
                elseif r=="bg2" then o.BackgroundColor3=t.bg2
                elseif r=="panel" then o.BackgroundColor3=t.panel
                elseif r=="soft" then o.BackgroundColor3=t.soft
                elseif r=="accent" then o.BackgroundColor3=t.accent
                elseif r=="action" then o.BackgroundColor3=t.accent; if o:IsA("TextButton") then o.TextColor3=t.white end
                elseif r=="accent2" then o.BackgroundColor3=t.accent2
                elseif r=="text" then o.TextColor3=t.text
                elseif r=="muted" then o.TextColor3=t.muted
                elseif r=="accentText" then o.TextColor3=t.accent
                elseif r=="whiteText" then o.TextColor3=t.white
                elseif r=="stroke" then o.Color=t.stroke
                elseif r=="hotStroke" then o.Color=t.accent
                elseif r=="nav" then o.BackgroundColor3=t.panel; o.TextColor3=t.text
                elseif r=="navActive" then o.BackgroundColor3=t.accent; o.TextColor3=t.white
                elseif r=="toggleOn" then o.BackgroundColor3=t.accent; o.TextColor3=t.white
                elseif r=="toggleOff" then o.BackgroundColor3=t.soft; o.TextColor3=t.text
                end
            end)
        end
    end
    for o in pairs(themed) do
        if o and o.Parent and o:IsA("ScrollingFrame") then pcall(function() o.ScrollBarImageColor3=t.accent end) end
    end
    for g in pairs(gradients) do
        if not g or not g.Parent then gradients[g]=nil else
            pcall(function()
                g.Color=ColorSequence.new({
                    ColorSequenceKeypoint.new(0,t.accent2),
                    ColorSequenceKeypoint.new(.52,t.accent),
                    ColorSequenceKeypoint.new(1,t.accent:Lerp(Color3.new(1,1,1),.18)),
                })
            end)
        end
    end
end

-- =========================================================
-- UI helpers
-- =========================================================
local function N(class,p)
    local o=Instance.new(class)
    for k,v in pairs(p or {}) do o[k]=v end
    return o
end
local function roundFrame(p,r) N("UICorner",{Parent=p,CornerRadius=UDim.new(0,r or 10)}) end
local function line(p,hot,thickness,transparency)
    local s=N("UIStroke",{Parent=p,Thickness=thickness or 1,Transparency=transparency==nil and .22 or transparency})
    track(s,hot and "hotStroke" or "stroke")
    return s
end
local function txt(p,text,size,bold,muted)
    local font=(bold and (size or 13)>=14) and Enum.Font.FredokaOne or (bold and Enum.Font.GothamSemibold or Enum.Font.Gotham)
    local l=N("TextLabel",{
        Parent=p,BackgroundTransparency=1,Text=text,Font=font,TextSize=size or 13,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
        TextWrapped=true,Size=UDim2.new(1,0,0,(size or 13)+10)
    })
    track(l,muted and "muted" or "text")
    return l
end
local function tinyHeart(parent,pos,size,transparency)
    local h=N("TextLabel",{
        Parent=parent,BackgroundTransparency=1,Position=pos,Size=UDim2.fromOffset(size,size),
        Text="♥",Font=Enum.Font.FredokaOne,TextSize=math.floor(size*.72),
        TextTransparency=transparency or 0,TextXAlignment=Enum.TextXAlignment.Center,
        TextYAlignment=Enum.TextYAlignment.Center,ZIndex=(parent.ZIndex or 1)+2,
    })
    track(h,"accentText")
    return h
end
local function stitchLine(parent,pos,size,text)
    local l=N("TextLabel",{
        Parent=parent,BackgroundTransparency=1,Position=pos,Size=size,
        Text=text or "·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·",
        Font=Enum.Font.GothamBold,TextSize=10,TextWrapped=false,
        TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,
        ZIndex=(parent.ZIndex or 1)+1,
    })
    track(l,"muted")
    return l
end

local gui=N("ScreenGui",{Name="Kimbugers",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local parented=false
if type(gethui)=="function" then
    local ok=pcall(function() gui.Parent=gethui() end)
    parented=ok and gui.Parent~=nil
end
if not parented then
    local ok=pcall(function() gui.Parent=CoreGui end)
    parented=ok and gui.Parent~=nil
end
if not parented then
    gui.Parent=LP:WaitForChild("PlayerGui")
end
print("[Kimbugers ♡] GUI parent: "..tostring(gui.Parent))

local main=N("Frame",{
    Parent=gui,Name="Main",Size=UDim2.fromOffset(900,590),Position=UDim2.new(.5,-450,.5,-295),
    BorderSizePixel=0,ClipsDescendants=true
})
track(main,"bg"); roundFrame(main,26); line(main,true,2.1,.16)
local mainScale=N("UIScale",{Parent=main,Scale=clamp(State.uiScale or 1,.85,1.15)})

-- soft inner shell
local shell=N("Frame",{Parent=main,Position=UDim2.fromOffset(9,9),Size=UDim2.new(1,-18,1,-18),BorderSizePixel=0,ClipsDescendants=true})
track(shell,"bg2"); roundFrame(shell,21); line(shell,false,1,.35)
stitchLine(shell,UDim2.fromOffset(18,1),UDim2.new(1,-36,0,16))
stitchLine(shell,UDim2.new(0,18,1,-17),UDim2.new(1,-36,0,16))
tinyHeart(shell,UDim2.new(1,-43,0,9),28,.08)

local top=N("Frame",{Parent=shell,Size=UDim2.new(1,0,0,84),BackgroundTransparency=1})
local title=txt(top,"Kimbugers ♡",29,true,false); title.Position=UDim2.fromOffset(20,8); title.Size=UDim2.new(0,390,0,38); track(title,"accentText")
local sub=txt(top,"bloxburg hub  •  "..BUILD.."  ♡",12,true,true); sub.Position=UDim2.fromOffset(23,43); sub.Size=UDim2.new(0,360,0,21)

local topProfile=N("Frame",{Parent=top,Position=UDim2.new(1,-242,0,13),Size=UDim2.fromOffset(220,54),BorderSizePixel=0})
track(topProfile,"panel"); roundFrame(topProfile,15); line(topProfile,false,1,.34)
local avatar=N("ImageLabel",{Parent=topProfile,Position=UDim2.fromOffset(7,6),Size=UDim2.fromOffset(40,40),BackgroundTransparency=0,BorderSizePixel=0})
track(avatar,"soft"); roundFrame(avatar,999); line(avatar,false,1,.28)
local profileName=txt(topProfile,LP.DisplayName,13,true,false); profileName.Position=UDim2.fromOffset(54,7); profileName.Size=UDim2.new(1,-60,0,18)
local profileUser=txt(topProfile,"@"..LP.Name,10,false,true); profileUser.Position=UDim2.fromOffset(54,27); profileUser.Size=UDim2.new(1,-60,0,16)
task.spawn(function()
    local ok,img=pcall(function() return Players:GetUserThumbnailAsync(LP.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size180x180) end)
    if ok and avatar and avatar.Parent then avatar.Image=img end
end)

local sidebar=N("Frame",{Parent=shell,Position=UDim2.fromOffset(12,84),Size=UDim2.new(0,198,1,-96),BorderSizePixel=0})
track(sidebar,"bg"); roundFrame(sidebar,18); line(sidebar,false,1,.30)
local featureTitle=txt(sidebar,"♡  FEATURES  ♡",16,true,false); featureTitle.Position=UDim2.fromOffset(10,8); featureTitle.Size=UDim2.new(1,-20,0,26); featureTitle.TextXAlignment=Enum.TextXAlignment.Center; track(featureTitle,"accentText")
local nav=N("ScrollingFrame",{Parent=sidebar,Position=UDim2.fromOffset(8,40),Size=UDim2.new(1,-16,1,-48),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
N("UIPadding",{Parent=nav,PaddingBottom=UDim.new(0,8)})
N("UIListLayout",{Parent=nav,Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})

local content=N("Frame",{Parent=shell,Position=UDim2.fromOffset(222,84),Size=UDim2.new(1,-234,1,-96),BackgroundTransparency=1})
local pages,buttons={},{}
local PAGE_DESCRIPTIONS={
    Overview="live dashboard and quick actions ♡",
    Player="movement and camera controls",
    ["Build & Plot"]="auto-build dashboard, blueprints, and plot tools",
    Jobs="job selector, live work detection, and task modules",
    Vehicle="working speed multiplier and driving tools",
    Environment="lighting, atmosphere, and time",
    Teleports="job navigation and location shortcuts",
    Animations="detected character animations and emotes",
    ["Visuals & Camera"]="cinematic local visuals",
    ["Plot Tools"]="plot information, inventory, and build status",
    Utilities="session info and useful helpers",
    Settings="themes, configs, and gui controls",
}
local sectionLabels={
    Overview="Overview", Player="Player", ["Build & Plot"]="Auto Build", Jobs="Auto Jobs",
    Vehicle="Vehicle Speed", Environment="Environment", Teleports="Teleports",
    Animations="Animations", ["Visuals & Camera"]="Visuals", ["Plot Tools"]="Plot Tools",
    Utilities="Utilities", Settings="Settings",
}
local function page(name,displayName)
    local p=N("ScrollingFrame",{
        Parent=content,Name=name,Visible=false,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        BorderSizePixel=0,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0),
    })
    track(p,"bg2")
    N("UIPadding",{Parent=p,PaddingTop=UDim.new(0,2),PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,2)})
    N("UIListLayout",{Parent=p,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
    local head=N("Frame",{Parent=p,LayoutOrder=-100,Size=UDim2.new(1,0,0,60),BorderSizePixel=0})
    track(head,"panel"); roundFrame(head,15); line(head,false,1,.34)
    tinyHeart(head,UDim2.fromOffset(13,13),31,0)
    local ht=txt(head,(displayName or sectionLabels[name] or name):lower(),22,true,false); ht.Position=UDim2.fromOffset(49,7); ht.Size=UDim2.new(1,-65,0,28); track(ht,"accentText")
    local hd=txt(head,PAGE_DESCRIPTIONS[name] or "kimbugers ♡",11,true,true); hd.Position=UDim2.fromOffset(50,33); hd.Size=UDim2.new(1,-66,0,18)
    pages[name]=p
    return p
end
local function show(name)
    State.page=name
    for n,p in pairs(pages) do p.Visible=(n==name) end
    for n,b in pairs(buttons) do
        local active=(n==name)
        track(b,active and "navActive" or "nav")
        b.Text=(active and "♥  " or "♡  ")..(sectionLabels[n] or n)
        local st=b:FindFirstChildOfClass("UIStroke")
        if st then track(st,active and "hotStroke" or "stroke") end
    end
    applyTheme()
end
local function side(name,label,order)
    local b=N("TextButton",{
        Parent=nav,LayoutOrder=order,Size=UDim2.new(1,0,0,37),BorderSizePixel=0,AutoButtonColor=false,
        Text="♡  "..(label or name),Font=Enum.Font.FredokaOne,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,
    })
    N("UIPadding",{Parent=b,PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,8)})
    track(b,"nav"); roundFrame(b,11); line(b,false,1,.42)
    b.MouseButton1Click:Connect(function() show(name) end)
    b.MouseEnter:Connect(function()
        if State.page~=name then pcall(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundTransparency=.08}):Play() end) end
    end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency=0 end)
    buttons[name]=b
end
local function card(p,titleText,desc)
    local c=N("Frame",{Parent=p,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BorderSizePixel=0})
    track(c,"panel"); roundFrame(c,13); line(c,false,1,.38)
    N("UIPadding",{Parent=c,PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
    N("UIListLayout",{Parent=c,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
    local ct=txt(c,"♥  "..titleText,16,true,false); track(ct,"accentText")
    if desc and desc~="" then local d=txt(c,desc,12,true,true); d.AutomaticSize=Enum.AutomaticSize.Y; d.Size=UDim2.new(1,0,0,0) end
    return c
end
local function button(p,text,cb)
    local b=N("TextButton",{
        Parent=p,Size=UDim2.new(1,0,0,36),BorderSizePixel=0,AutoButtonColor=false,Text=text,
        Font=Enum.Font.FredokaOne,TextSize=13,
    })
    track(b,"action"); roundFrame(b,10); line(b,true,1,.18); track(b,"action")
    -- white text is applied directly after each theme refresh below
    b.TextColor3=T().white
    b.MouseEnter:Connect(function() pcall(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundTransparency=.08}):Play() end) end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency=0 end)
    b.MouseButton1Click:Connect(function() local ok,e=pcall(cb); if not ok then notify(e) end end)
    return b
end
local function infoLine(p,left,right,accent)
    local r=N("Frame",{Parent=p,Size=UDim2.new(1,0,0,28),BackgroundTransparency=1})
    local a=txt(r,left,12,true,false); a.Size=UDim2.new(.62,0,1,0)
    local b=txt(r,right,12,true,not accent); b.Position=UDim2.new(.62,0,0,0); b.Size=UDim2.new(.38,0,1,0); b.TextXAlignment=Enum.TextXAlignment.Right
    if accent then track(b,"accentText") end
    return b
end
local function divider(p,label)
    local d=N("Frame",{Parent=p,Size=UDim2.new(1,0,0,24),BackgroundTransparency=1})
    local l=txt(d,"♡  "..label.."  ♡",11,true,true); l.Size=UDim2.fromScale(1,1); l.TextXAlignment=Enum.TextXAlignment.Center
    return d
end
local function toggle(p,text,initial,cb)
    local r=N("Frame",{Parent=p,Size=UDim2.new(1,0,0,36),BackgroundTransparency=1})
    local l=txt(r,text,13,true,false); l.Size=UDim2.new(1,-76,1,0)
    local b=N("TextButton",{Parent=r,Position=UDim2.new(1,-66,.5,-14),Size=UDim2.fromOffset(66,28),BorderSizePixel=0,AutoButtonColor=false,Font=Enum.Font.FredokaOne,TextSize=11})
    roundFrame(b,14); line(b,false,1,.38)
    local v=not not initial
    local function render()
        b.Text=v and "♥  ON" or "♡  OFF"
        track(b,v and "toggleOn" or "toggleOff")
        applyTheme()
    end
    b.MouseButton1Click:Connect(function() v=not v; render(); cb(v) end)
    render()
end
local function slider(p,text,a,b,initial,step,cb)
    local w=N("Frame",{Parent=p,Size=UDim2.new(1,0,0,58),BackgroundTransparency=1})
    local l=txt(w,"",13,true,false)
    local bar=N("Frame",{Parent=w,Position=UDim2.fromOffset(0,35),Size=UDim2.new(1,0,0,9),BorderSizePixel=0}); track(bar,"soft"); roundFrame(bar,5); line(bar,false,1,.45)
    local fill=N("Frame",{Parent=bar,Size=UDim2.fromScale(0,1),BorderSizePixel=0}); track(fill,"accent"); roundFrame(fill,5)
    local knob=N("Frame",{Parent=fill,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(1,0,.5,0),Size=UDim2.fromOffset(15,15),BorderSizePixel=0}); track(knob,"accent"); roundFrame(knob,999); line(knob,true,1,.15)
    local v=clamp(initial,a,b); local drag=false
    local function render() fill.Size=UDim2.fromScale((v-a)/(b-a),1); l.Text=text.."  •  "..tostring(v) end
    local function setx(x) local pct=clamp((x-bar.AbsolutePosition.X)/math.max(1,bar.AbsoluteSize.X),0,1); v=math.floor(((a+(b-a)*pct)/(step or 1))+.5)*(step or 1); v=clamp(v,a,b); render(); cb(v) end
    bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true; setx(i.Position.X) end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then setx(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    render()
end
local function cycle(p,text,values,current,cb)
    local idx=table.find(values,current) or 1
    local b
    local function render() b.Text="♡  "..text.."  •  "..values[idx] end
    b=button(p,"",function() idx=idx%#values+1; render(); cb(values[idx]); applyTheme() end); render()
end

-- drag window
local dragging,dragStart,startPos=false,nil,nil
top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; dragStart=i.Position; startPos=main.Position end end)
UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-dragStart; main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)

local sections={
    {"Overview","Overview"},
    {"Jobs","Auto Jobs"},
    {"Build & Plot","Auto Build"},
    {"Vehicle","Vehicle Speed"},
    {"Teleports","Teleports"},
    {"Player","Player"},
    {"Environment","Environment"},
    {"Animations","Animations"},
    {"Visuals & Camera","Visuals"},
    {"Plot Tools","Plot Tools"},
    {"Utilities","Utilities"},
    {"Settings","Settings"},
}
for i,item in ipairs(sections) do page(item[1],item[2]); side(item[1],item[2],i) end

-- Overview
local ov=pages.Overview
local hero=N("Frame",{Parent=ov,LayoutOrder=-90,Size=UDim2.new(1,0,0,150),BorderSizePixel=0,ClipsDescendants=true})
track(hero,"accent"); roundFrame(hero,18); line(hero,true,1,.18)
local heroGrad=N("UIGradient",{Parent=hero,Rotation=8}); trackGradient(heroGrad)
local bubble1=N("Frame",{Parent=hero,Position=UDim2.new(-.03,0,.50,0),Size=UDim2.fromOffset(122,122),BorderSizePixel=0,BackgroundTransparency=.86}); track(bubble1,"panel"); roundFrame(bubble1,999)
local bubble2=N("Frame",{Parent=hero,Position=UDim2.new(.87,0,.40,0),Size=UDim2.fromOffset(118,118),BorderSizePixel=0,BackgroundTransparency=.86}); track(bubble2,"panel"); roundFrame(bubble2,999)
local heroTitle=txt(hero,"Kimbugers ♡",38,true,false); heroTitle.Position=UDim2.new(0,20,.5,-50); heroTitle.Size=UDim2.new(1,-40,0,48); heroTitle.TextXAlignment=Enum.TextXAlignment.Center; track(heroTitle,"whiteText")
local heroSub=txt(hero,"your cute bloxburg control center",13,true,false); heroSub.Position=UDim2.new(0,20,.5,1); heroSub.Size=UDim2.new(1,-40,0,24); heroSub.TextXAlignment=Enum.TextXAlignment.Center; track(heroSub,"whiteText")
local heroMini=txt(hero,"local tools  •  planners  •  visuals  •  vehicle HUD",11,true,false); heroMini.Position=UDim2.new(0,20,.5,28); heroMini.Size=UDim2.new(1,-40,0,20); heroMini.TextXAlignment=Enum.TextXAlignment.Center; track(heroMini,"whiteText")
tinyHeart(hero,UDim2.fromOffset(18,12),33,.18); tinyHeart(hero,UDim2.new(1,-54,0,88),30,.18)

local welcome=card(ov,"Welcome back ♡","A fuller Kimqetras-style layout with the useful local tools grouped clearly.")
infoLine(welcome,"Player",LP.DisplayName.."  @"..LP.Name,true)
infoLine(welcome,"Theme",State.theme,true)
infoLine(welcome,"Toggle key","Right Shift",true)

local stat=card(ov,"Live Status","Reads the Bloxburg client state directly where we have confirmed signals.")
local bs=infoLine(stat,"Build Mode","Not detected",false)
local js=infoLine(stat,"Work Status","Not detected",false)
local vs=infoLine(stat,"Vehicle","Not detected",false)
local nearStatus=infoLine(stat,"Nearest job","Scanning…",false)
local themeStatus=infoLine(stat,"Current theme",State.theme,true)

local function runtimeMainGui()
    local pg=LP:FindFirstChildOfClass("PlayerGui")
    return pg and pg:FindFirstChild("MainGUI")
end

local function runtimeBuildMode()
    local mg=runtimeMainGui()
    local bm=mg and mg:FindFirstChild("BuildMenu")
    return bm and bm.Visible or false
end

local function runtimeJobEfficiency()
    local mg=runtimeMainGui()
    local jf=mg and mg:FindFirstChild("MobileJobEfficiencyFrame")
    local pct=jf and jf:FindFirstChild("Percentage",true)
    if jf and jf.Visible then
        return true,(pct and pct:IsA("TextLabel")) and pct.Text or "working"
    end
    return false,nil
end

local function runtimeVehicle()
    local c=LP.Character
    if not c then return nil,nil,nil end
    for _,obj in ipairs(c:GetChildren()) do
        if obj:IsA("Model") then
            local mod=obj:FindFirstChild("VehicleSpeedModifier",true)
            if mod and mod:IsA("NumberValue") then
                local root=obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)
                return obj,mod,root
            end
        end
    end
    return nil,nil,nil
end


local JobInfo={
    {id="BensIceCreamSeller",name="Ben's Ice Cream Seller",desc="Make NPC ice cream orders with the requested flavors and toppings."},
    {id="BloxBurgersEmployee",name="Blox Burgers Employee",desc="Handle fast-food tasks such as orders, cooking, and food preparation."},
    {id="CaveMiner",name="Cave Miner",desc="Mine rocks and ores inside the cave."},
    {id="HighSchoolTeacher",name="High School Teacher",desc="Complete classroom tasks with NPC students."},
    {id="HutFisherman",name="Fisherman",desc="Catch fish at the fishing hut."},
    {id="LumberWoodcutter",name="Lumber Woodcutter",desc="Chop trees and logs at the lumber area."},
    {id="MikesMechanic",name="Mike's Mechanic",desc="Repair NPC vehicles and complete requested mechanic tasks."},
    {id="PizzaPlanetBaker",name="Pizza Planet Baker",desc="Prepare pizzas using the ingredients requested by each order."},
    {id="PizzaPlanetDelivery",name="Pizza Planet Delivery",desc="Collect pizzas and deliver them to NPC customers."},
    {id="SchoolJanitor",name="School Janitor",desc="Clean messes and graffiti around the school."},
    {id="StylezHairdresser",name="Stylez Hairdresser",desc="Match an NPC's requested hairstyle and hair color."},
    {id="SupermarketCashier",name="Supermarket Cashier",desc="Scan and process NPC customers' groceries."},
    {id="SupermarketStocker",name="Supermarket Stocker",desc="Restock supermarket shelves with products."},
}
local JobByName,JobNames={},{}
for _,j in ipairs(JobInfo) do JobByName[j.name]=j; JobNames[#JobNames+1]=j.name end
if not State.jobs.selectedJob or not JobByName[State.jobs.selectedJob] then State.jobs.selectedJob="Blox Burgers Employee" end

local function getJobArea(job)
    local g=workspace:FindFirstChild("_game")
    local f=g and g:FindFirstChild("JobAreas")
    return f and job and f:FindFirstChild("JobArea_"..job.id) or nil
end
local function characterRoot()
    local c=LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function distanceTo(part)
    local r=characterRoot()
    if not r or not part or not part:IsA("BasePart") then return nil end
    return (r.Position-part.Position).Magnitude
end
local function nearestJob()
    local best,bestDist=nil,math.huge
    for _,j in ipairs(JobInfo) do
        local a=getJobArea(j)
        local d=distanceTo(a)
        if d and d<bestDist then best,bestDist=j,d end
    end
    return best,bestDist
end
local function findOwnPlot()
    local plots=workspace:FindFirstChild("Plots")
    if not plots then return nil end
    return plots:FindFirstChild("Plot_"..LP.Name)
end
local function countPlot(plot)
    local out={models=0,parts=0,lights=0,values=0,total=0}
    if not plot then return out end
    for _,o in ipairs(plot:GetDescendants()) do
        out.total+=1
        if o:IsA("Model") then out.models+=1
        elseif o:IsA("BasePart") then out.parts+=1
        elseif o:IsA("Light") then out.lights+=1
        elseif o:IsA("ValueBase") then out.values+=1 end
    end
    return out
end
local jobMarker=nil
local function clearJobMarker()
    if jobMarker then pcall(function() jobMarker:Destroy() end); jobMarker=nil end
end
local function markJob(job)
    clearJobMarker()
    local area=getJobArea(job)
    if not area then notify("That job area is not loaded right now.") return end
    local box=Instance.new("SelectionBox")
    box.Name="KimbugersJobMarker"; box.Adornee=area; box.LineThickness=.08; box.SurfaceTransparency=.88; box.Parent=area
    jobMarker=box
    notify("Marked "..job.name.." ♡")
end

RunService.Heartbeat:Connect(function()
    if not stat.Parent then return end
    bs.Text=runtimeBuildMode() and "Active ♡" or "Not active"
    local working,pct=runtimeJobEfficiency()
    js.Text=working and ("Working  "..tostring(pct or "")) or "Not detected"
    local vm=runtimeVehicle()
    vs.Text=vm and ("Driving  "..vm.Name) or "Not seated"
    local nj,nd=nearestJob(); nearStatus.Text=nj and (nj.name.."  "..math.floor(nd).." studs") or "—"
    themeStatus.Text=State.theme
end)

local quick=card(ov,"Quick Actions","Jump straight to the pages you will use most.")
button(quick,"♡  AUTO JOBS",function() show("Jobs") end)
button(quick,"♡  AUTO BUILD",function() show("Build & Plot") end)
button(quick,"♡  VEHICLE SPEED",function() show("Vehicle") end)
button(quick,"♡  TELEPORTS / NAVIGATION",function() show("Teleports") end)

local ready=card(ov,"What Works Right Now","These do not depend on hidden Bloxburg server calls.")
txt(ready,"♥ Player movement + FOV controls",13,true,false)
txt(ready,"♥ 13 scanned Bloxburg job areas + live work status",13,true,false)
txt(ready,"♥ Working VehicleSpeedModifier controls + speed HUD",13,true,false)
txt(ready,"♥ Live Build Mode + plot inventory/snapshot tools",13,true,false)
txt(ready,"♥ Environment, animations, visuals, player, utilities",13,true,false)

-- Player
local pp=pages.Player
local move=card(pp,"Movement ♡","Simple local character controls with clean defaults.")
toggle(move,"Walk Speed Override",State.player.speedOn,function(v) State.player.speedOn=v end)
slider(move,"Walk Speed",8,80,State.player.speed,1,function(v) State.player.speed=v end)
toggle(move,"Jump Override",State.player.jumpOn,function(v) State.player.jumpOn=v end)
slider(move,"Jump Power",20,120,State.player.jump,1,function(v) State.player.jump=v end)
local cam=card(pp,"Camera ♡","Useful for building, screenshots, and house tours.")
slider(cam,"Field of View",40,120,State.player.fov,1,function(v) State.player.fov=v; if Camera and not State.vehicle.cameraBoost then Camera.FieldOfView=v end end)
button(cam,"RESET CAMERA FOV",function() State.player.fov=70; if Camera then Camera.FieldOfView=70 end; notify("Camera FOV reset ♡") end)
local char=card(pp,"Character Utilities","Small quality-of-life actions in one place.")
button(char,"RESET CHARACTER",function() local h=getHumanoid(); if h then h.Health=0 end end)
button(char,"CENTER CAMERA ON CHARACTER",function()
    local h=getHumanoid(); if h and Camera then Camera.CameraSubject=h; notify("Camera centered ♡") end
end)
RunService.Heartbeat:Connect(function()
    local h=getHumanoid(); if not h then return end
    if State.player.speedOn then h.WalkSpeed=State.player.speed end
    if State.player.jumpOn then
        if h.UseJumpPower~=false then h.JumpPower=State.player.jump else h.JumpHeight=math.max(2,State.player.jump/7) end
    end
end)

-- Build & Plot
local bp=pages["Build & Plot"]
local auto=card(bp,"Build Planner ♡","Plan a session here. Actual Bloxburg placement only becomes available if a legitimate Build adapter is connected.")
local selected=txt(auto,"Selected Blueprint: None",12,true,true)
infoLine(auto,"Adapter",Adapters.Build and "Connected ✓" or "Not connected",Adapters.Build~=nil)
slider(auto,"Build Budget",0,1000000,State.build.budget,10000,function(v) State.build.budget=v end)
cycle(auto,"Snap Preference",{"5°","15°","45°","90°"},State.build.snap,function(v) State.build.snap=v end)
button(auto,"CHECK BUILD ADAPTER",function()
    notify(Adapters.Build and "Build adapter is connected ♡" or "No Build adapter is connected. Planner tools still work.")
end)
button(auto,"START AUTO BUILD",function()
    if not Adapters.Build or type(Adapters.Build.Start)~="function" then notify("No verified Auto Build module is connected yet ♡") return end
    local ok,err=pcall(function() Adapters.Build:Start(State.build.selected,State.build) end)
    notify(ok and "Auto Build module started ♡" or tostring(err))
end)
button(auto,"STOP AUTO BUILD",function()
    if Adapters.Build and type(Adapters.Build.Stop)=="function" then pcall(function() Adapters.Build:Stop() end); notify("Auto Build module stopped ♡") else notify("No running verified Auto Build module.") end
end)

local bo=card(bp,"Planner Options","Saved with your Kimbugers config for future build sessions.")
toggle(bo,"Structure First",State.build.structureOnly,function(v) State.build.structureOnly=v end)
toggle(bo,"Estimate Before Building",State.build.estimate,function(v) State.build.estimate=v end)
toggle(bo,"Auto Adapt Unsupported Pieces",State.build.autoAdapt,function(v) State.build.autoAdapt=v end)
toggle(bo,"Skip Failed Objects",State.build.skipFailed,function(v) State.build.skipFailed=v end)
toggle(bo,"No Gamepass Planning Mode",State.build.noGamepass,function(v) State.build.noGamepass=v end)

local lib=card(bp,"Blueprint Library ♡","Local blueprint files can be listed here when your environment supports file APIs.")
button(lib,"REFRESH SAVED BLUEPRINTS",function()
    if not FILES.list then notify("This environment does not provide listfiles().") return end
    ensureFolders(); local files=listfiles(PLOTS); notify("Found "..#files.." blueprint file(s) ♡")
end)
button(lib,"SAVE CURRENT PLOT INVENTORY",function()
    local plot=findOwnPlot(); if not plot then notify("Your plot is not loaded.") return end
    local data={meta={owner=LP.Name,createdAt=os.time(),format="KimbugersPlotInventoryV1",plot=plot.Name},objects={}}
    for _,o in ipairs(plot:GetDescendants()) do
        if o:IsA("Model") or o:IsA("BasePart") or o:IsA("Light") then
            data.objects[#data.objects+1]={class=o.ClassName,name=o.Name,path=o:GetFullName()}
        end
    end
    State.build.selected=data; selected.Text="Selected Blueprint: "..plot.Name.." inventory"
    if FILES.rw then ensureFolders(); local name="PlotInventory_"..LP.Name.."_"..os.time()..".json"; pcall(writefile,PLOTS.."/"..name,HttpService:JSONEncode(data)); notify("Plot inventory saved ♡") else notify("Plot inventory captured in memory ♡") end
end)
button(lib,"CAPTURE PLACEMENT BLUEPRINT (ADAPTER)",function()
    if not Adapters.Build or type(Adapters.Build.ScanCurrentPlot)~="function" then notify("Exact placement capture needs a verified Build adapter.") return end
    local data=Adapters.Build:ScanCurrentPlot(); if type(data)~="table" then notify("Plot capture failed.") return end
    data.meta=data.meta or {}; data.meta.owner=LP.Name; data.meta.createdAt=os.time(); data.meta.format="KimbugersBlueprintV1"
    State.build.selected=data
    local name=tostring(data.meta.name or ("Plot_"..os.time())):gsub("[^%w%-%_ ]","")
    selected.Text="Selected Blueprint: "..name
    if FILES.rw then ensureFolders(); writefile(PLOTS.."/"..name..".json",HttpService:JSONEncode(data)); notify("Blueprint saved ♡") else notify("Blueprint captured in memory.") end
end)

local buildLive=card(bp,"Live Build Mode ♡","Confirmed from your recorder: MainGUI.BuildMenu.Visible becomes true while Build Mode is active.")
local buildLiveState=infoLine(buildLive,"Build Mode","Not active",true)
local activeBuilders=infoLine(buildLive,"Your plot builder state","Checking…",false)
RunService.Heartbeat:Connect(function()
    if not buildLiveState.Parent then return end
    buildLiveState.Text=runtimeBuildMode() and "Active ♡" or "Not active"
    local plot=workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild("Plot_"..LP.Name)
    local ab=plot and plot:FindFirstChild("PlotData") and plot.PlotData:FindFirstChild("ActiveBuilders")
    activeBuilders.Text=ab and tostring(ab.Value) or "—"
end)

local comp=card(bp,"Build Checklist","A quick checklist so this page still helps even with no automation adapter.")
txt(comp,"♡ Set your budget before entering Build Mode",13,true,false)
txt(comp,"♡ Pick a snap preference and structure-first option",13,true,false)
txt(comp,"♡ Use a wider FOV from Player for large builds",13,true,false)
txt(comp,"♡ Use Environment presets for brighter interiors",13,true,false)
txt(comp,"♡ Save your Kimbugers config when the setup feels right",13,true,false)

-- Jobs / Auto Jobs
local jp=pages.Jobs
local jobSelect=card(jp,"Auto Jobs ♡","Choose one of the 13 jobs discovered by the scanner. Kimbugers can detect/mark each job immediately; task automation only starts when that job has a verified module attached.")
local selectedJobLine=infoLine(jobSelect,"Selected job",State.jobs.selectedJob,true)
local selectedDesc=txt(jobSelect,JobByName[State.jobs.selectedJob].desc,12,true,true); selectedDesc.AutomaticSize=Enum.AutomaticSize.Y; selectedDesc.Size=UDim2.new(1,0,0,0)
local selectedDistance=infoLine(jobSelect,"Distance","—",false)
local moduleState=infoLine(jobSelect,"Task module","Not captured yet",false)
cycle(jobSelect,"Job",JobNames,State.jobs.selectedJob,function(v)
    State.jobs.selectedJob=v
    selectedJobLine.Text=v
    selectedDesc.Text=JobByName[v].desc
end)
button(jobSelect,"MARK SELECTED JOB AREA",function() markJob(JobByName[State.jobs.selectedJob]) end)
button(jobSelect,"CLEAR JOB MARKER",clearJobMarker)
button(jobSelect,"START AUTO JOB",function()
    local j=JobByName[State.jobs.selectedJob]
    local m=j and JobModules[j.id]
    if not m or type(m.Start)~="function" then
        notify("No verified task module for "..State.jobs.selectedJob.." yet ♡")
        return
    end
    local ok,err=pcall(function() m:Start() end)
    notify(ok and ("Started "..State.jobs.selectedJob.." module ♡") or tostring(err))
end)
button(jobSelect,"STOP AUTO JOB",function()
    local j=JobByName[State.jobs.selectedJob]
    local m=j and JobModules[j.id]
    if m and type(m.Stop)=="function" then pcall(function() m:Stop() end); notify("Stopped job module ♡") else notify("No running verified module.") end
end)

local liveJob=card(jp,"Live Work Detection ♡","Reads the confirmed MobileJobEfficiencyFrame and compares your position to the scanned job areas.")
local workState=infoLine(liveJob,"Work state","Not detected",true)
local effState=infoLine(liveJob,"Efficiency","—",true)
local nearestState=infoLine(liveJob,"Nearest job","—",false)
local nearDistance=infoLine(liveJob,"Distance","—",false)
RunService.Heartbeat:Connect(function()
    if not workState.Parent then return end
    local working,pct=runtimeJobEfficiency()
    workState.Text=working and "Working ♡" or "Not detected"
    effState.Text=pct or "—"
    local n,d=nearestJob()
    nearestState.Text=n and n.name or "—"
    nearDistance.Text=d and (math.floor(d).." studs") or "—"
    local sj=JobByName[State.jobs.selectedJob]
    local area=getJobArea(sj); local sd=distanceTo(area)
    selectedDistance.Text=sd and (math.floor(sd).." studs") or "—"
    moduleState.Text=(sj and JobModules[sj.id]) and "Connected ✓" or "Not captured yet"
end)

local catalog=card(jp,"Job Catalog ♡","All job areas found in this Bloxburg client scan.")
for _,j in ipairs(JobInfo) do
    txt(catalog,"♡  "..j.name.."  —  "..j.desc,11,true,true).AutomaticSize=Enum.AutomaticSize.Y
end

local work=card(jp,"Shift Tracker ♡","Optional local timer for a manual work session.")
button(work,"START SHIFT TRACKER",function()
    if not State.jobs.tracking then State.jobs.tracking=true; State.jobs.paused=false; State.jobs.lastTick=os.clock(); State.jobs.status="Tracking"; notify("Shift tracker started ♡")
    elseif State.jobs.paused then State.jobs.paused=false; State.jobs.lastTick=os.clock(); State.jobs.status="Tracking" end
end)
button(work,"PAUSE / RESUME",function()
    if not State.jobs.tracking then notify("Start the shift tracker first.") return end
    State.jobs.paused=not State.jobs.paused; State.jobs.lastTick=os.clock(); State.jobs.status=State.jobs.paused and "Paused" or "Tracking"
end)
button(work,"RESET SHIFT",function() State.jobs.tracking=false; State.jobs.paused=false; State.jobs.elapsed=0; State.jobs.lastTick=nil; State.jobs.tasks=0; State.jobs.earned=0; State.jobs.status="Idle" end)
local s1=infoLine(work,"Status","Idle",true)
local s2=infoLine(work,"Time","0m 0s",true)
RunService.Heartbeat:Connect(function()
    if State.jobs.tracking and not State.jobs.paused then local now=os.clock(); local last=State.jobs.lastTick or now; State.jobs.elapsed = State.jobs.elapsed + math.max(0,now-last); State.jobs.lastTick=now
    elseif State.jobs.tracking then State.jobs.lastTick=os.clock() end
    s1.Text=State.jobs.status; s2.Text=string.format("%dm %ds",math.floor(State.jobs.elapsed/60),math.floor(State.jobs.elapsed%60))
end)

-- Vehicle
local veh=pages.Vehicle

local function getRuntimeVehicle()
    return runtimeVehicle()
end

local function getVehicleVelocityRoot(model,root)
    if root and root:IsA("BasePart") then return root end
    if model then
        return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
    end
end

local function convertSpeed(studs)
    if State.vehicle.unit=="KPH" then return studs*1.008, "km/h" end
    return studs*.626, "mph"
end

local drive=card(veh,"Vehicle Dashboard ♡","Uses the actual Bloxburg vehicle model that appears under your character while driving.")
local vehicleState=infoLine(drive,"Vehicle","Not seated",true)
local vehicleSpeed=infoLine(drive,"Speed","0 mph",true)
local vehicleModifier=infoLine(drive,"Speed modifier","—",true)
cycle(drive,"Speed Unit",{"MPH","KPH"},State.vehicle.unit,function(v) State.vehicle.unit=v end)
toggle(drive,"Floating Speed HUD",State.vehicle.hud,function(v) State.vehicle.hud=v end)

local speedCard=card(veh,"Vehicle Speed ♡","Your recording exposed a NumberValue named VehicleSpeedModifier. Kimbugers now controls that value directly while you are in the car.")
slider(speedCard,"Speed Multiplier",5,50,math.floor(State.vehicle.speedModifier*10),1,function(v)
    State.vehicle.speedModifier=v/10
    local model,mod=getRuntimeVehicle()
    if mod then
        mod.Value=State.vehicle.speedModifier
        notify("Vehicle speed multiplier: "..string.format("%.1fx",State.vehicle.speedModifier))
    end
end)
toggle(speedCard,"Keep Speed Multiplier Applied",State.vehicle.keepModifier,function(v)
    State.vehicle.keepModifier=v
end)
button(speedCard,"APPLY SPEED NOW",function()
    local model,mod=getRuntimeVehicle()
    if not mod then notify("Get in your vehicle first ♡") return end
    mod.Value=State.vehicle.speedModifier
    vehicleModifier.Text=string.format("%.1fx",mod.Value)
    notify("Applied "..string.format("%.1fx",mod.Value).." ♡")
end)
button(speedCard,"RESET VEHICLE SPEED",function()
    State.vehicle.speedModifier=1.2
    local model,mod=getRuntimeVehicle()
    if mod then mod.Value=1.2 end
    notify("Vehicle speed reset to 1.2x ♡")
end)

local vcam=card(veh,"Driving Camera ♡","A wider local camera can make driving and parking easier.")
toggle(vcam,"Vehicle Camera FOV",State.vehicle.cameraBoost,function(v)
    State.vehicle.cameraBoost=v
    if Camera then Camera.FieldOfView=v and State.vehicle.cameraFov or State.player.fov end
end)
slider(vcam,"Driving FOV",50,120,State.vehicle.cameraFov,1,function(v)
    State.vehicle.cameraFov=v
    local model=getRuntimeVehicle()
    if State.vehicle.cameraBoost and model and Camera then Camera.FieldOfView=v end
end)
button(vcam,"RESET DRIVING CAMERA",function()
    State.vehicle.cameraBoost=false; State.vehicle.cameraFov=82
    if Camera then Camera.FieldOfView=State.player.fov end
    notify("Driving camera reset ♡")
end)

local vnote=card(veh,"Detected Bloxburg Vehicle Hook","The live recorder caught VehicleSpeedModifier=1.2 when you entered the Old Roat 500. This page now uses that confirmed client object instead of VehicleSeat.")
txt(vnote,"♡ Detects the vehicle model under your character",13,true,false)
txt(vnote,"♡ Reads the vehicle's AssemblyLinearVelocity",13,true,false)
txt(vnote,"♡ Reapplies your multiplier while driving if enabled",13,true,false)

local vehicleHud=N("Frame",{Parent=gui,Name="VehicleHUD",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-34),Size=UDim2.fromOffset(220,74),BorderSizePixel=0,Visible=false})
track(vehicleHud,"panel"); roundFrame(vehicleHud,18); line(vehicleHud,true,1.5,.18)
local hudHeart=txt(vehicleHud,"♥",22,true,false); hudHeart.Position=UDim2.fromOffset(12,10); hudHeart.Size=UDim2.fromOffset(28,28); hudHeart.TextXAlignment=Enum.TextXAlignment.Center; track(hudHeart,"accentText")
local hudSpeed=txt(vehicleHud,"0 mph",27,true,false); hudSpeed.Position=UDim2.fromOffset(46,7); hudSpeed.Size=UDim2.new(1,-58,0,34); hudSpeed.TextXAlignment=Enum.TextXAlignment.Center; track(hudSpeed,"accentText")
local hudSub=txt(vehicleHud,"vehicle speed ♡",10,true,true); hudSub.Position=UDim2.fromOffset(46,40); hudSub.Size=UDim2.new(1,-58,0,20); hudSub.TextXAlignment=Enum.TextXAlignment.Center

local applyAccumulator=0
RunService.Heartbeat:Connect(function(dt)
    local model,mod,root=getRuntimeVehicle()
    if model and mod then
        root=getVehicleVelocityRoot(model,root)
        local studs=(root and root.AssemblyLinearVelocity.Magnitude) or 0
        local spd,unit=convertSpeed(studs)

        vehicleState.Text=model.Name
        vehicleSpeed.Text=string.format("%.0f %s",spd,unit)
        vehicleModifier.Text=string.format("%.1fx",mod.Value)
        vehicleHud.Visible=State.vehicle.hud
        hudSpeed.Text=string.format("%.0f %s",spd,unit)

        applyAccumulator=applyAccumulator+(dt or 0)
        if State.vehicle.keepModifier and applyAccumulator>=0.2 then
            applyAccumulator=0
            if math.abs(mod.Value-State.vehicle.speedModifier)>.001 then
                mod.Value=State.vehicle.speedModifier
            end
        end

        if State.vehicle.cameraBoost and Camera then
            Camera.FieldOfView=State.vehicle.cameraFov
        end
    else
        applyAccumulator=0
        vehicleState.Text="Not seated"
        vehicleSpeed.Text=State.vehicle.unit=="KPH" and "0 km/h" or "0 mph"
        vehicleModifier.Text="—"
        vehicleHud.Visible=false
        if State.vehicle.cameraBoost and Camera then Camera.FieldOfView=State.player.fov end
    end
end)

-- Environment
local ep=pages.Environment
local baseLight={
    Technology=Lighting.Technology,Diffuse=Lighting.EnvironmentDiffuseScale,Soft=Lighting.ShadowSoftness,
    ClockTime=Lighting.ClockTime,FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,
}
local originals=setmetatable({}, {__mode="k"})
local cc=Lighting:FindFirstChild("KimbugersColor") or N("ColorCorrectionEffect",{Parent=Lighting,Name="KimbugersColor",Enabled=true})
local function applyEnv()
    pcall(function()
        if State.env.shadows then
            Lighting.Technology=Enum.Technology.Future; Lighting.GlobalShadows=true
            local d=clamp(State.env.darkness,0,150)
            Lighting.EnvironmentDiffuseScale=d<=100 and (1-(d/100)*.82) or math.max(.02,.18-((d-100)/50)*.16)
            Lighting.ShadowSoftness=clamp(State.env.softness/100,0,1)
        else
            Lighting.Technology=baseLight.Technology; Lighting.EnvironmentDiffuseScale=baseLight.Diffuse; Lighting.ShadowSoftness=baseLight.Soft
        end
        Lighting.ClockTime=State.env.timeOn and State.env.clockTime or baseLight.ClockTime
        if State.env.fogOn then Lighting.FogStart=0; Lighting.FogEnd=State.env.fogEnd else Lighting.FogStart=baseLight.FogStart; Lighting.FogEnd=baseLight.FogEnd end
        cc.Saturation=clamp(State.env.saturation/100,-1,1)
        cc.Contrast=clamp(State.env.contrast/100,-1,1)
        cc.Brightness=clamp(State.env.brightnessFX/100,-1,1)
    end)
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("PointLight") or o:IsA("SpotLight") or o:IsA("SurfaceLight") then
            originals[o]=originals[o] or {Brightness=o.Brightness,Range=o.Range,Shadows=o.Shadows}
            local x=originals[o]
            if State.env.lights then o.Brightness=x.Brightness*(State.env.brightness/100); o.Range=x.Range*(1+(State.env.glow/100)*.35); o.Shadows=true
            else o.Brightness=x.Brightness; o.Range=x.Range; o.Shadows=x.Shadows end
        end
    end
end
local presets=card(ep,"Lighting Presets ♡","Fast local presets for building, screenshots, or night roleplay.")
button(presets,"BRIGHT DAY",function() State.env.timeOn=true; State.env.clockTime=13; State.env.saturation=5; State.env.contrast=3; State.env.brightnessFX=4; applyEnv() end)
button(presets,"GOLDEN HOUR",function() State.env.timeOn=true; State.env.clockTime=17.5; State.env.saturation=12; State.env.contrast=5; State.env.brightnessFX=2; applyEnv() end)
button(presets,"DEEP NIGHT",function() State.env.timeOn=true; State.env.clockTime=0.5; State.env.saturation=-5; State.env.contrast=10; State.env.brightnessFX=-4; applyEnv() end)
button(presets,"RESET ENVIRONMENT",function()
    State.env.timeOn=false; State.env.fogOn=false; State.env.shadows=false; State.env.lights=false
    State.env.saturation=0; State.env.contrast=0; State.env.brightnessFX=0; applyEnv(); notify("Environment reset ♡")
end)

local timeCard=card(ep,"Time & Fog ♡","Local atmosphere controls with clear on/off toggles.")
toggle(timeCard,"Time Override",State.env.timeOn,function(v) State.env.timeOn=v; applyEnv() end)
slider(timeCard,"Clock Time",0,24,State.env.clockTime,.5,function(v) State.env.clockTime=v; applyEnv() end)
toggle(timeCard,"Fog Override",State.env.fogOn,function(v) State.env.fogOn=v; applyEnv() end)
slider(timeCard,"Fog Distance",100,5000,State.env.fogEnd,50,function(v) State.env.fogEnd=v; applyEnv() end)

local sh=card(ep,"Shadows & Lights ♡","Make interiors feel deeper without just making the whole screen dark.")
toggle(sh,"Corner / Contact Shadows",State.env.shadows,function(v) State.env.shadows=v; applyEnv() end)
slider(sh,"Corner Darkness",0,150,State.env.darkness,1,function(v) State.env.darkness=v; applyEnv() end)
slider(sh,"Shadow Edge Softness",0,100,State.env.softness,1,function(v) State.env.softness=v; applyEnv() end)
toggle(sh,"Enhanced World Lights",State.env.lights,function(v) State.env.lights=v; applyEnv() end)
slider(sh,"Light Brightness %",50,400,State.env.brightness,5,function(v) State.env.brightness=v; applyEnv() end)
slider(sh,"Light Glow %",0,100,State.env.glow,1,function(v) State.env.glow=v; applyEnv() end)

local color=card(ep,"Color Grading ♡","Fine-tune the look without changing your theme UI.")
slider(color,"Saturation",-100,100,State.env.saturation,5,function(v) State.env.saturation=v; applyEnv() end)
slider(color,"Contrast",-100,100,State.env.contrast,5,function(v) State.env.contrast=v; applyEnv() end)
slider(color,"Scene Brightness",-100,100,State.env.brightnessFX,5,function(v) State.env.brightnessFX=v; applyEnv() end)

-- Teleports / Navigation
local tp=pages.Teleports
local navCard=card(tp,"Job Navigation ♡","The scan provides exact job-area objects. Kimbugers can mark/focus them now; actual teleport movement is only used when a compatible location adapter is connected.")
local navSelected=infoLine(navCard,"Selected",State.navigation.selectedJob,true)
local navDist=infoLine(navCard,"Distance","—",false)
cycle(navCard,"Destination",JobNames,State.navigation.selectedJob,function(v) State.navigation.selectedJob=v; navSelected.Text=v end)
button(navCard,"MARK DESTINATION",function() markJob(JobByName[State.navigation.selectedJob]) end)
button(navCard,"FOCUS CAMERA ON DESTINATION",function()
    local j=JobByName[State.navigation.selectedJob]; local a=getJobArea(j); local r=characterRoot()
    if not a or not Camera then notify("Destination is not loaded.") return end
    local from=(r and r.Position or a.Position)+Vector3.new(0,28,55)
    Camera.CameraType=Enum.CameraType.Scriptable; Camera.CFrame=CFrame.lookAt(from,a.Position); notify("Camera focused on "..j.name.." ♡")
end)
button(navCard,"RESTORE CHARACTER CAMERA",function() local h=getHumanoid(); if Camera and h then Camera.CameraType=Enum.CameraType.Custom; Camera.CameraSubject=h end end)
button(navCard,"TELEPORT VIA CONNECTED ADAPTER",function()
    local j=JobByName[State.navigation.selectedJob]
    if Adapters.Teleports and type(Adapters.Teleports.GoJob)=="function" then Adapters.Teleports:GoJob(j.id,j.name) else notify("No compatible teleport adapter is connected.") end
end)
RunService.Heartbeat:Connect(function()
    local j=JobByName[State.navigation.selectedJob]; local d=distanceTo(getJobArea(j)); navDist.Text=d and (math.floor(d).." studs") or "—"
end)
local navList=card(tp,"Detected Locations ♡","Exact job-area names found in Workspace._game.JobAreas.")
for _,j in ipairs(JobInfo) do
    local a=getJobArea(j)
    local pos=a and a.Position
    txt(navList,"♡ "..j.name..(pos and string.format("  (%.0f, %.0f, %.0f)",pos.X,pos.Y,pos.Z) or "  [not streamed]"),11,true,true)
end
local locHelp=card(tp,"Navigation Helpers","Local camera and marker helpers.")
button(locHelp,"CENTER CAMERA ON CHARACTER",function() local h=getHumanoid(); if h and Camera then Camera.CameraType=Enum.CameraType.Custom; Camera.CameraSubject=h end end)
button(locHelp,"CLEAR JOB MARKER",clearJobMarker)
button(locHelp,"OPEN VEHICLE SPEED",function() show("Vehicle") end)
button(locHelp,"OPEN AUTO JOBS",function() show("Jobs") end)

-- Animations
local ap=pages.Animations
local AnimationLibrary={
    Wave="rbxassetid://507770239", Cheer="rbxassetid://507770677", Laugh="rbxassetid://507770818",
    Point="rbxassetid://507770453", Sit="rbxassetid://2506281703", Pose="rbxassetid://10921056055",
    Dance="rbxassetid://507771019", Dance2="rbxassetid://507776043", Dance3="rbxassetid://507777268",
    Climb="rbxassetid://10921257536", Swim="rbxassetid://10921264784", Jump="rbxassetid://10921279832",
}
local AnimationNames={"Wave","Cheer","Laugh","Point","Sit","Pose","Dance","Dance2","Dance3","Climb","Swim","Jump"}
local customTrack=nil
local animCard=card(ap,"Detected Animations ♡","Animation IDs found in your character Animate hierarchy by the game blueprint scanner.")
local animState=infoLine(animCard,"Selected",State.anim.selected,true)
cycle(animCard,"Animation",AnimationNames,State.anim.selected,function(v) State.anim.selected=v; animState.Text=v end)
toggle(animCard,"Loop Animation",State.anim.loop,function(v) State.anim.loop=v; if customTrack then customTrack.Looped=v end end)
slider(animCard,"Animation Speed x10",5,30,math.floor(State.anim.speed*10),1,function(v) State.anim.speed=v/10; if customTrack then pcall(function() customTrack:AdjustSpeed(State.anim.speed) end) end end)
button(animCard,"PLAY ANIMATION",function()
    local h=getHumanoid(); if not h then return end
    local animator=h:FindFirstChildOfClass("Animator") or Instance.new("Animator",h)
    if customTrack then pcall(function() customTrack:Stop(.15) end) end
    local a=Instance.new("Animation"); a.AnimationId=AnimationLibrary[State.anim.selected]
    local ok,tr=pcall(function() return animator:LoadAnimation(a) end); a:Destroy()
    if ok and tr then customTrack=tr; tr.Looped=State.anim.loop; tr:Play(.15); tr:AdjustSpeed(State.anim.speed) else notify("Animation could not be loaded.") end
end)
button(animCard,"STOP CUSTOM ANIMATION",function() if customTrack then pcall(function() customTrack:Stop(.15) end); customTrack=nil end end)
local animList=card(ap,"Animation IDs","Useful detected IDs from this session.")
for _,n in ipairs(AnimationNames) do txt(animList,"♡ "..n.."  •  "..AnimationLibrary[n],11,true,true) end

-- Plot Tools
local plotPage=pages["Plot Tools"]
local plotLive=card(plotPage,"Your Plot ♡","Reads your currently streamed plot and summarizes its client-visible structure.")
local plotName=infoLine(plotLive,"Plot","Checking…",true)
local plotParts=infoLine(plotLive,"Parts","0",false)
local plotModels=infoLine(plotLive,"Models","0",false)
local plotLights=infoLine(plotLive,"Lights","0",false)
local plotBuilders=infoLine(plotLive,"Active Builders","—",false)
local plotBuildMode=infoLine(plotLive,"Build Mode","No",true)
local plotTick=0
RunService.Heartbeat:Connect(function(dt)
    plotTick = plotTick + (dt or 0); if plotTick<1 then return end; plotTick=0
    local p=findOwnPlot(); plotName.Text=p and p.Name or "Not loaded"; plotBuildMode.Text=runtimeBuildMode() and "Yes ♡" or "No"
    local c=countPlot(p); plotParts.Text=tostring(c.parts); plotModels.Text=tostring(c.models); plotLights.Text=tostring(c.lights)
    local pd=p and p:FindFirstChild("PlotData"); local ab=pd and pd:FindFirstChild("ActiveBuilders"); plotBuilders.Text=ab and tostring(ab.Value) or "—"
end)
local plotActions=card(plotPage,"Plot Inventory ♡","Create a local inventory of the plot objects currently visible to your client.")
button(plotActions,"SAVE PLOT INVENTORY JSON",function()
    local p=findOwnPlot(); if not p then notify("Your plot is not loaded.") return end
    local payload={owner=LP.Name,plot=p.Name,createdAt=os.time(),items={}}
    for _,o in ipairs(p:GetDescendants()) do
        if o:IsA("Model") then payload.items[#payload.items+1]={class="Model",name=o.Name,path=o:GetFullName()}
        elseif o:IsA("BasePart") then payload.items[#payload.items+1]={class=o.ClassName,name=o.Name,path=o:GetFullName(),position={o.Position.X,o.Position.Y,o.Position.Z},size={o.Size.X,o.Size.Y,o.Size.Z}} end
    end
    if FILES.rw then ensureFolders(); local fn=PLOTS.."/PlotInventory_"..LP.Name.."_"..os.time()..".json"; pcall(writefile,fn,HttpService:JSONEncode(payload)); notify("Plot inventory saved ♡") else notify("File saving is unavailable.") end
end)
button(plotActions,"OPEN AUTO BUILD",function() show("Build & Plot") end)

-- Utilities
local up=pages.Utilities
local session=card(up,"Session ♡","Useful client/session information in one place.")
infoLine(session,"Place ID",tostring(game.PlaceId),true)
infoLine(session,"Game ID",tostring(game.GameId),true)
local uptime=infoLine(session,"Session time","0m",false)
local coords=infoLine(session,"Position","—",false)
RunService.Heartbeat:Connect(function()
    uptime.Text=string.format("%dm %ds",math.floor(workspace.DistributedGameTime/60),math.floor(workspace.DistributedGameTime%60))
    local r=characterRoot(); coords.Text=r and string.format("%.0f, %.0f, %.0f",r.Position.X,r.Position.Y,r.Position.Z) or "—"
end)
local copy=card(up,"Copy Helpers ♡","Uses your executor clipboard when available.")
local function copyText(v)
    if type(setclipboard)=="function" then local ok=pcall(setclipboard,tostring(v)); notify(ok and "Copied ♡" or "Copy failed")
    elseif type(toclipboard)=="function" then local ok=pcall(toclipboard,tostring(v)); notify(ok and "Copied ♡" or "Copy failed") else notify("Clipboard API is unavailable.") end
end
button(copy,"COPY PLACE ID",function() copyText(game.PlaceId) end)
button(copy,"COPY JOB ID",function() copyText(game.JobId) end)
button(copy,"COPY CURRENT POSITION",function() local r=characterRoot(); if r then copyText(string.format("Vector3.new(%.3f, %.3f, %.3f)",r.Position.X,r.Position.Y,r.Position.Z)) end end)
local money=card(up,"Bloxburg HUD Readout ♡","Reads visible currency labels if the current UI exposes them.")
local moneyLine=infoLine(money,"Money","—",true)
local buxLine=infoLine(money,"Blockbux","—",true)
RunService.Heartbeat:Connect(function()
    local pg=LP:FindFirstChildOfClass("PlayerGui"); local tg=pg and pg:FindFirstChild("TopbarGui")
    local tc=tg and tg:FindFirstChild("TopRightContainer",true); local cur=tc and tc:FindFirstChild("Currencies",true)
    local m=cur and cur:FindFirstChild("Money"); local b=cur and cur:FindFirstChild("Blockbux")
    local ml=m and m:FindFirstChild("ValueLabel"); local bl=b and b:FindFirstChild("ValueLabel")
    moneyLine.Text=(ml and ml:IsA("TextLabel")) and ml.Text or "—"; buxLine.Text=(bl and bl:IsA("TextLabel")) and bl.Text or "—"
end)

-- Visuals & Camera
local vp=pages["Visuals & Camera"]
local dof=Lighting:FindFirstChild("KimbugersDOF") or N("DepthOfFieldEffect",{Parent=Lighting,Name="KimbugersDOF",Enabled=false,FarIntensity=.15,NearIntensity=.1,FocusDistance=18,InFocusRadius=28})
local bloom=Lighting:FindFirstChild("KimbugersBloom") or N("BloomEffect",{Parent=Lighting,Name="KimbugersBloom",Enabled=false,Intensity=.15,Size=24,Threshold=1.2})
local blur=Lighting:FindFirstChild("KimbugersBlur") or N("BlurEffect",{Parent=Lighting,Name="KimbugersBlur",Enabled=false,Size=0})
local function applyVis()
    dof.Enabled=State.visuals.cinematic; bloom.Enabled=State.visuals.cinematic
    dof.FarIntensity=clamp(State.visuals.dof/100,0,1)
    bloom.Intensity=clamp(State.visuals.bloom/100,0,1.5)
    blur.Size=clamp(State.visuals.blur,0,32); blur.Enabled=blur.Size>0
end
local cine=card(vp,"Cinematic Mode ♡","Local screenshot and house-tour effects.")
toggle(cine,"Cinematic Effects",State.visuals.cinematic,function(v) State.visuals.cinematic=v; applyVis() end)
slider(cine,"Depth of Field",0,100,State.visuals.dof,1,function(v) State.visuals.dof=v; applyVis() end)
slider(cine,"Bloom",0,100,State.visuals.bloom,1,function(v) State.visuals.bloom=v; applyVis() end)
slider(cine,"Blur",0,32,State.visuals.blur,1,function(v) State.visuals.blur=v; applyVis() end)

local shot=card(vp,"Screenshot Tools ♡","Quick buttons for cleaner screenshots.")
button(shot,"HIDE KIMBUGERS FOR SCREENSHOT",function() main.Visible=false; notify("Kimbugers hidden — press Right Shift to bring it back ♡") end)
button(shot,"CLEAN VISUAL RESET",function()
    State.visuals.cinematic=false; State.visuals.dof=25; State.visuals.bloom=15; State.visuals.blur=0; applyVis(); notify("Visual effects reset ♡")
end)
button(shot,"CAMERA FOV 70",function() State.player.fov=70; if Camera then Camera.FieldOfView=70 end end)
button(shot,"CAMERA FOV 90",function() State.player.fov=90; if Camera then Camera.FieldOfView=90 end end)

-- Settings
local sp=pages.Settings
local app=card(sp,"Appearance ♡","Everything recolors together so the GUI stays cohesive.")
cycle(app,"Theme",{"Blue","Pink","Lilac","Red"},State.theme,function(v) State.theme=v; applyTheme() end)
cycle(app,"UI Scale",{"90%","100%","110%"},math.floor((State.uiScale or 1)*100).."%",function(v)
    local n=tonumber(v:match("%d+")) or 100; State.uiScale=n/100; mainScale.Scale=State.uiScale
end)
button(app,"RE-APPLY THEME",function() applyTheme(); notify("Theme refreshed ♡") end)

local cfg=card(sp,"Config ♡","Save your theme, planner values, visual settings, and tracker preferences.")
button(cfg,"SAVE CONFIG",saveConfig)
button(cfg,"RELOAD SAVED CONFIG",function()
    loadConfig(); mainScale.Scale=clamp(State.uiScale or 1,.85,1.15); applyTheme(); applyEnv(); applyVis()
    notify("Config values loaded. Re-execute to redraw controls that were already created.")
end)
button(cfg,"RESET LOCAL VISUALS",function()
    State.env.timeOn=false; State.env.fogOn=false; State.env.shadows=false; State.env.lights=false
    State.env.saturation=0; State.env.contrast=0; State.env.brightnessFX=0
    State.visuals.cinematic=false; State.visuals.blur=0; State.vehicle.cameraBoost=false
    applyEnv(); applyVis(); if Camera then Camera.FieldOfView=State.player.fov end
    notify("Local visuals reset ♡")
end)

local controls=card(sp,"Controls","Simple and consistent, just like Kimqetras HC.")
infoLine(controls,"Toggle GUI","Right Shift",true)
infoLine(controls,"Drag window","Top header",true)
infoLine(controls,"Default theme","Blue",true)
infoLine(controls,"Version",BUILD,true)

local about=card(sp,"About ♡","")
txt(about,"Kimbugers ♡  "..BUILD,15,true,false)
txt(about,"Full Bloxburg hub with live detection, job catalog, plot tools, vehicle speed, navigation, animations, visuals, and utilities.",12,true,true)
txt(about,"Auto Jobs and exact Auto Build placement use verified modules/adapters so unsupported buttons never pretend to work.",12,true,true)

ENV.KimbugersCleanup=function()
    pcall(function() if gui then gui:Destroy() end end)
    ENV.KimbugersToggle=nil
    ENV.KimbugersLoaded=nil
    _G.KimbugersToggle=nil
    _G.KimbugersLoaded=nil
end
ENV.KimbugersLoaded=true
_G.KimbugersLoaded=true
ENV.KimbugersToggle=function() State.open=not State.open; main.Visible=State.open end
_G.KimbugersToggle=ENV.KimbugersToggle
UIS.InputBegan:Connect(function(i)
    if UIS:GetFocusedTextBox() then return end
    if i.KeyCode==Enum.KeyCode.RightShift and type(ENV.KimbugersToggle)=="function" then ENV.KimbugersToggle() end
end)

show(State.page)
applyTheme()
applyEnv()
applyVis()
mainScale.Scale=clamp(State.uiScale or 1,.85,1.15)
pcall(function() if Camera then Camera.FieldOfView=State.player.fov end end)
print("[Kimbugers ♡] UI construction complete")
notify("Kimbugers ♡ "..BUILD.." loaded")
print("[Kimbugers ♡] "..BUILD.." loaded • repo: Kimbugers")
