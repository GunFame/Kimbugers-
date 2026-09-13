--[[
    Kimbugers ♡ v2.1 MAPPED AUTOMATION
    Bloxburg-focused modular hub foundation

    GitHub repository: Kimbugers

    Built from the last Potassium-confirmed working v1.4 base.
    v2.1 adds task-aware Auto Work helpers from the user's live capture report,
    plus real local plot blueprint capture / preview / normal-input placement assist.
    It does not spoof payouts, bypass purchases, enumerate hidden remotes,
    or include anti-cheat evasion.
]]

-- v2.1 intentionally replaces older Kimbugers sessions instead of returning early.
_G.KimbugersLoaded = true
_G.KimbugersVersion = "v2.1-mapped-automation"

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local BUILD = "v2.1-mapped-automation"

-- Remove an older Kimbugers GUI if this is executed again in the same session.
do
    local roots={CoreGui,LP:FindFirstChildOfClass("PlayerGui")}
    if type(gethui)=="function" then
        local ok,h=pcall(gethui)
        if ok and h then roots[#roots+1]=h end
    end
    for _,root in ipairs(roots) do
        if root then
            local old=root:FindFirstChild("Kimbugers")
            if old then pcall(function() old:Destroy() end) end
        end
    end
end
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
        status="Ready", selected=nil,
        noGamepass=true, autoAdapt=true, structureOnly=false,
        estimate=true, skipFailed=true, budget=150000, snap="15°",
        autoPlacing=false, placeIndex=1, placeDelay=0.85,
    },
    jobs = {
        status="Idle", mode="Chill", autoNext=true,
        normalMovement=true, autoReturn=true,
        stopMinutes=0, stopEarnings=0, tasks=0, earned=0,
        tracking=false, paused=false, elapsed=0, lastTick=nil,
        selectedJob="Ben's Ice Cream", autoWork=false, loopDelay=0.85,
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
}

-- =========================================================
-- Modular adapters
-- =========================================================
local Adapters = {Build=nil, Jobs=nil, Teleports=nil}
local API = {}
function API:RegisterBuildAdapter(a) Adapters.Build=a; notify("Build adapter connected ♡") end
function API:RegisterJobsAdapter(a) Adapters.Jobs=a; notify("Jobs adapter connected ♡") end
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
pcall(function() gui.Parent=(type(gethui)=="function" and gethui()) or CoreGui end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end

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
    Overview="your cute bloxburg control center ♡",
    Player="movement and camera controls",
    ["Build & Plot"]="save plots, preview blueprints, and placement assist",
    Jobs="mapped task-aware auto work",
    Vehicle="speed HUD and driving camera tools",
    Environment="lighting, atmosphere, and time",
    Teleports="quick location shortcuts",
    ["Visuals & Camera"]="cinematic local visuals",
    Settings="themes, configs, and gui controls",
}
local function page(name)
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
    local ht=txt(head,name:lower(),22,true,false); ht.Position=UDim2.fromOffset(49,7); ht.Size=UDim2.new(1,-65,0,28); track(ht,"accentText")
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
        b.Text=(active and "♥  " or "♡  ")..n
        local st=b:FindFirstChildOfClass("UIStroke")
        if st then track(st,active and "hotStroke" or "stroke") end
    end
    applyTheme()
end
local function side(name,order)
    local b=N("TextButton",{
        Parent=nav,LayoutOrder=order,Size=UDim2.new(1,0,0,37),BorderSizePixel=0,AutoButtonColor=false,
        Text="♡  "..name,Font=Enum.Font.FredokaOne,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,
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

local sections={"Overview","Player","Build & Plot","Jobs","Vehicle","Environment","Teleports","Visuals & Camera","Settings"}
for i,n in ipairs(sections) do page(n); side(n,i) end

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

RunService.Heartbeat:Connect(function()
    if not stat.Parent then return end
    bs.Text=runtimeBuildMode() and "Active ♡" or "Not active"
    local working,pct=runtimeJobEfficiency()
    js.Text=working and ("Working  "..tostring(pct or "")) or "Not detected"
    local vm=runtimeVehicle()
    vs.Text=vm and ("Driving  "..vm.Name) or "Not seated"
    themeStatus.Text=State.theme
end)

local quick=card(ov,"Quick Actions","Jump straight to the pages you will use most.")
button(quick,"♡  AUTO BUILD / BLUEPRINTS",function() show("Build & Plot") end)
button(quick,"♡  AUTO WORK",function() show("Jobs") end)
button(quick,"♡  VEHICLE DASHBOARD",function() show("Vehicle") end)
button(quick,"♡  ENVIRONMENT & LIGHTING",function() show("Environment") end)

local ready=card(ov,"v2.1 Mapped Systems","Built from your live capture + the last Potassium-confirmed working base.")
txt(ready,"♥ Player movement + FOV controls",13,true,false)
txt(ready,"♥ Captured Auto Work task readers + visible-input loops",13,true,false)
txt(ready,"♥ Plot blueprint save / preview / supported-object placement",13,true,false)\ntxt(ready,"♥ Vehicle speed HUD + driving camera FOV",13,true,false)
txt(ready,"♥ Lighting, time, fog, bloom, DOF, blur",13,true,false)
txt(ready,"♥ Themes, configs, profile header, Right Shift toggle",13,true,false)

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


-- =========================================================
-- v2.1 mapped runtime helpers
-- Uses only client-visible objects + normal local input.
-- =========================================================
local Runtime = {
    input=nil,
    worldCache={},
    jobContext={},
    jobAreas={
        ["Ben's Ice Cream"]="JobArea_BensIceCreamSeller",
        ["Blox Burgers"]="JobArea_BloxBurgersEmployee",
        ["Fisherman"]="JobArea_HutFisherman",
        ["Pizza Planet Baker"]="JobArea_PizzaPlanetBaker",
        ["Pizza Planet Delivery"]="JobArea_PizzaPlanetDelivery",
        ["School Janitor"]="JobArea_SchoolJanitor",
        ["Stylez Hairdresser"]="JobArea_StylezHairdresser",
        ["Supermarket Cashier"]="JobArea_SupermarketCashier",
        ["Supermarket Stocker"]="JobArea_SupermarketStocker",
        ["Taxi Driver"]="JobArea_TaxiDriver",
    },
}

function Runtime:getInput()
    if self.input~=nil then return self.input end
    local ok,v=pcall(function() return game:GetService("VirtualInputManager") end)
    self.input=ok and v or false
    return self.input or nil
end

function Runtime:root()
    local c=LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Runtime:myPlot()
    local plots=workspace:FindFirstChild("Plots")
    return plots and plots:FindFirstChild("Plot_"..LP.Name)
end

function Runtime:plotGround(plot)
    if not plot then return CFrame.new() end
    local gv=plot:FindFirstChild("_groundCFrame")
    if gv and gv:IsA("CFrameValue") then return gv.Value end
    local gp=plot:GetAttribute("GroundPosition")
    if typeof(gp)=="CFrame" then return gp end
    if typeof(gp)=="Vector3" then return CFrame.new(gp) end
    local house=plot:FindFirstChild("House")
    if house and house:IsA("Model") then
        local ok,cf=pcall(function() return house:GetPivot() end)
        if ok then return cf end
    end
    return CFrame.new()
end

function Runtime:nearestPlot()
    local plots=workspace:FindFirstChild("Plots")
    local root=self:root()
    if not plots or not root then return nil end
    local best,bestD=nil,math.huge
    for _,plot in ipairs(plots:GetChildren()) do
        if not plot:GetAttribute("_eventPlot") then
            local p=self:plotGround(plot).Position
            local d=(root.Position-p).Magnitude
            if d<bestD then best,bestD=plot,d end
        end
    end
    return best,bestD
end

function Runtime:getJobArea(job)
    local g=workspace:FindFirstChild("_game")
    local name=self.jobAreas[job]
    if not g or not name then return nil end
    local areas=g:FindFirstChild("JobAreas")
    return (areas and areas:FindFirstChild(name)) or g:FindFirstChild(name)
end

function Runtime:teleportCF(cf)
    local root=self:root()
    if not root or typeof(cf)~="CFrame" then return false end
    root.CFrame=cf
    return true
end

function Runtime:moveNear(inst,offset)
    if not inst then return false end
    local cf
    if inst:IsA("BasePart") then
        cf=inst.CFrame
    elseif inst:IsA("Model") then
        local ok,v=pcall(function() return inst:GetPivot() end)
        if ok then cf=v end
    end
    if not cf then
        local p=inst:FindFirstChildWhichIsA("BasePart",true)
        if p then cf=p.CFrame end
    end
    if not cf then return false end
    offset=offset or Vector3.new(0,2.5,3)
    return self:teleportCF(CFrame.new(cf.Position+offset,cf.Position))
end

function Runtime:teleportJob(job)
    local area=self:getJobArea(job)
    if not area then return false,"job area not found" end
    local ok=self:moveNear(area,Vector3.new(0,3,0))
    return ok,ok and "at "..job or "teleport failed"
end

function Runtime:clickGui(obj)
    if not obj or not obj.Parent then return false end
    if obj:IsA("GuiButton") then
        local ok=pcall(function() obj:Activate() end)
        if ok then return true end
    end
    local vim=self:getInput()
    if vim and obj:IsA("GuiObject") then
        local p=obj.AbsolutePosition
        local s=obj.AbsoluteSize
        local x=p.X+s.X/2
        local y=p.Y+s.Y/2
        local ok=pcall(function()
            vim:SendMouseMoveEvent(x,y,game)
            task.wait(.03)
            vim:SendMouseButtonEvent(x,y,0,true,game,0)
            task.wait(.03)
            vim:SendMouseButtonEvent(x,y,0,false,game,0)
        end)
        if ok then return true end
    end
    return false
end

function Runtime:key(code)
    local vim=self:getInput()
    if not vim then return false end
    return pcall(function()
        vim:SendKeyEvent(true,code,false,game)
        task.wait(.035)
        vim:SendKeyEvent(false,code,false,game)
    end)
end

function Runtime:visible(o)
    if not o or not o.Parent then return false end
    if o:IsA("GuiObject") and not o.Visible then return false end
    local p=o.Parent
    while p do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("LayerCollector") and not p.Enabled then return false end
        p=p.Parent
    end
    return true
end

function Runtime:startVisibleJob()
    local pg=LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return false end
    local phrases={"start task","start work","start working","start shift","clock in"}
    for _,b in ipairs(pg:GetDescendants()) do
        if b:IsA("GuiButton") and self:visible(b) then
            local hay=string.lower(b.Name)
            for _,x in ipairs(b:GetDescendants()) do
                if x:IsA("TextLabel") and self:visible(x) then hay=hay.." "..string.lower(x.Text) end
            end
            for _,q in ipairs(phrases) do
                if string.find(hay,q,1,true) then
                    return self:clickGui(b)
                end
            end
        end
    end
    local tx=self:visibleInteractText()
    if tx then
        local lo=string.lower(tx)
        if string.find(lo,"start",1,true) or string.find(lo,"work",1,true) then
            return self:interact("")
        end
    end
    return false
end

function Runtime:visibleInteractText()
    local pg=LP:FindFirstChildOfClass("PlayerGui")
    local ui=pg and pg:FindFirstChild("_interactUI")
    if not ui then return nil end
    for _,d in ipairs(ui:GetDescendants()) do
        if d:IsA("TextLabel") and self:visible(d) and tostring(d.Text)~="" then
            return d.Text,d
        end
    end
    return nil
end

function Runtime:interact(expected)
    local pg=LP:FindFirstChildOfClass("PlayerGui")
    local ui=pg and pg:FindFirstChild("_interactUI")
    local expectedLow=string.lower(tostring(expected or ""))
    if ui then
        for _,d in ipairs(ui:GetDescendants()) do
            if d:IsA("GuiButton") and self:visible(d) then
                local good=(expectedLow=="")
                if not good then
                    for _,x in ipairs(d:GetDescendants()) do
                        if x:IsA("TextLabel") and string.find(string.lower(x.Text),expectedLow,1,true) then
                            good=true break
                        end
                    end
                end
                if good and self:clickGui(d) then return true end
            end
        end
    end
    return self:key(Enum.KeyCode.E)
end

function Runtime:instancePos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok,cf=pcall(function() return inst:GetPivot() end)
        if ok then return cf.Position end
    end
    local p=inst:FindFirstChildWhichIsA("BasePart",true)
    return p and p.Position or nil
end

function Runtime:findWorldTarget(job,phrases)
    local area=self:getJobArea(job)
    local center=area and area.Position
    if not center then
        local root=self:root()
        center=root and root.Position
    end
    if not center then return nil end

    local best,bestScore=nil,-math.huge
    local roots={}
    local g=workspace:FindFirstChild("_game")
    if g then roots[#roots+1]=g end
    roots[#roots+1]=workspace

    local seen={}
    for _,root in ipairs(roots) do
        for _,d in ipairs(root:GetDescendants()) do
            if not seen[d] and (d:IsA("BasePart") or d:IsA("Model")) then
                seen[d]=true
                if not (LP.Character and d:IsDescendantOf(LP.Character)) then
                    local n=string.lower(d.Name)
                    local phraseIndex=nil
                    local exact=false
                    for i,phrase in ipairs(phrases) do
                        local q=string.lower(tostring(phrase or ""))
                        if q~="" and string.find(n,q,1,true) then
                            phraseIndex=i
                            exact=(n==q)
                            break
                        end
                    end
                    if phraseIndex then
                        local pos=self:instancePos(d)
                        if pos then
                            local dist=(pos-center).Magnitude
                            if dist<=115 then
                                local score=200-(phraseIndex*8)-dist*.08
                                if exact then score=score+80 end
                                if score>bestScore then
                                    best,bestScore=d,score
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

function Runtime:spawned()
    local g=workspace:FindFirstChild("_game")
    return g and (g:FindFirstChild("SpawnedCharacters") or workspace:FindFirstChild("SpawnedCharacters"))
end

function Runtime:findCustomer(name,needs)
    local f=self:spawned()
    if not f then return nil end
    local area=self:getJobArea(State.jobs.selectedJob)
    local center=area and area.Position
    local best,bestD=nil,math.huge
    for _,m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and m.Name==name then
            local ok=true
            if needs and not m:FindFirstChild(needs) then ok=false end
            if ok then
                local p=self:instancePos(m)
                local d=(p and center) and (p-center).Magnitude or 0
                local bubble=m:FindFirstChild("ChatBubble",true)
                if bubble and bubble:IsA("BillboardGui") and bubble.Enabled then d=d-40 end
                if d<bestD then best,bestD=m,d end
            end
        end
    end
    return best
end

function Runtime:jobTitle()
    local pg=LP:FindFirstChildOfClass("PlayerGui")
    local tg=pg and pg:FindFirstChild("TopbarGui")
    local header=tg and tg:FindFirstChild("JobHeader",true)
    local label=header and header:FindFirstChild("JobTitleLabel",true)
    return label and label:IsA("TextLabel") and label.Text or "—"
end

function Runtime:cframePack(cf)
    return {cf:GetComponents()}
end

function Runtime:cframeUnpack(t)
    if type(t)~="table" or #t<12 then return CFrame.new() end
    return CFrame.new(table.unpack(t))
end

function Runtime:sizePack(v)
    return {v.X,v.Y,v.Z}
end

function Runtime:buttonByText(root,text)
    if not root then return nil end
    local q=string.lower(tostring(text or ""))
    for _,b in ipairs(root:GetDescendants()) do
        if b:IsA("GuiButton") and self:visible(b) then
            if string.find(string.lower(b.Name),q,1,true) then return b end
            for _,x in ipairs(b:GetDescendants()) do
                if x:IsA("TextLabel") and self:visible(x) and string.find(string.lower(x.Text),q,1,true) then
                    return b
                end
            end
        end
    end
    return nil
end

function Runtime:buttonByImage(root,image)
    if not root or not image or image=="" then return nil end
    for _,b in ipairs(root:GetDescendants()) do
        if b:IsA("GuiButton") and self:visible(b) then
            if b:IsA("ImageButton") and b.Image==image then return b end
            for _,x in ipairs(b:GetDescendants()) do
                if x:IsA("ImageLabel") and self:visible(x) and x.Image==image then
                    return b
                end
            end
        end
    end
    return nil
end

function Runtime:mouseWorldClick(cf)
    if not Camera or typeof(cf)~="CFrame" then return false end
    local vim=self:getInput()
    if not vim then return false end
    local oldType=Camera.CameraType
    local oldCF=Camera.CFrame
    local target=cf.Position
    local ok=pcall(function()
        Camera.CameraType=Enum.CameraType.Scriptable
        Camera.CFrame=CFrame.new(target+Vector3.new(0,75,0),target)
        task.wait(.12)
        local v,on=Camera:WorldToViewportPoint(target)
        if not on then error("target not on screen") end
        vim:SendMouseMoveEvent(v.X,v.Y,game)
        task.wait(.05)
        vim:SendMouseButtonEvent(v.X,v.Y,0,true,game,0)
        task.wait(.05)
        vim:SendMouseButtonEvent(v.X,v.Y,0,false,game,0)
        task.wait(.12)
    end)
    pcall(function()
        Camera.CFrame=oldCF
        Camera.CameraType=oldType
    end)
    return ok
end


-- Build & Plot
do
    local bp=pages["Build & Plot"]
    local blueprint=nil
    local previewFolder=nil
    local buildToken=0

    local function cleanName(s)
        return tostring(s or "Blueprint"):gsub("[^%w%-%_ ]",""):sub(1,72)
    end

    local function primitiveAttr(v)
        local tv=typeof(v)
        if tv=="string" or tv=="number" or tv=="boolean" then return v end
        if tv=="Vector3" then return {__type="Vector3",v={v.X,v.Y,v.Z}} end
        if tv=="Color3" then return {__type="Color3",v={v.R,v.G,v.B}} end
        if tv=="CFrame" then return {__type="CFrame",v=Runtime:cframePack(v)} end
        return nil
    end

    local function poseOf(obj)
        if obj:IsA("BasePart") then return obj.CFrame,obj.Size end
        if obj:IsA("Model") then
            local ok,cf,size=pcall(function()
                local c,s=obj:GetBoundingBox()
                return c,s
            end)
            if ok then return cf,size end
        end
        local p=obj:FindFirstChildWhichIsA("BasePart",true)
        if p then return p.CFrame,p.Size end
        return nil,nil
    end

    local function captureItem(obj,category,ground)
        local cf,size=poseOf(obj)
        if not cf then return nil end
        local item={
            name=obj.Name,
            category=category,
            class=obj.ClassName,
            relCFrame=Runtime:cframePack(ground:ToObjectSpace(cf)),
            size=Runtime:sizePack(size),
            attrs={},
            points={},
            colors={},
        }

        for k,v in pairs(obj:GetAttributes()) do
            local pv=primitiveAttr(v)
            if pv~=nil then item.attrs[k]=pv end
        end

        local pointCount=0
        local colorCount=0
        for _,d in ipairs(obj:GetDescendants()) do
            if pointCount<48 and d:IsA("Vector3Value") and
                (string.find(d.Name,"Point_",1,true) or d.Name=="PoleValue") then
                pointCount=pointCount+1
                local vv=d.Value
                item.points[#item.points+1]={name=d.Name,v={vv.X,vv.Y,vv.Z}}
            elseif colorCount<18 and d:IsA("BasePart") and d.Transparency<.98 then
                colorCount=colorCount+1
                item.colors[#item.colors+1]={
                    name=d.Name,
                    color={d.Color.R,d.Color.G,d.Color.B},
                    material=d.Material.Name,
                }
            end
        end
        return item
    end

    local function capturePlot(plot)
        if not plot then return nil,"plot not found" end
        local house=plot:FindFirstChild("House")
        if not house then return nil,"House folder not found" end
        local ground=Runtime:plotGround(plot)
        local data={
            meta={
                format="KimbugersBlueprintV2",
                sourcePlot=plot.Name,
                createdAt=os.time(),
                placeId=game.PlaceId,
            },
            items={},
        }

        local specs={
            {"Objects",house:FindFirstChild("Objects")},
            {"Counters",house:FindFirstChild("Counters")},
            {"Walls",house:FindFirstChild("Walls")},
            {"Floor",house:FindFirstChild("Floor")},
            {"Roof",house:FindFirstChild("Roof")},
            {"Fences",house:FindFirstChild("Fences")},
            {"Paths",house:FindFirstChild("Paths")},
            {"Pools",house:FindFirstChild("Pools")},
            {"Basements",house:FindFirstChild("Basements")},
        }
        local front=house:FindFirstChild("FrontObjects")
        if front then
            specs[#specs+1]={"FrontObjects",front:FindFirstChild("ItemHolder") or front}
        end

        for _,spec in ipairs(specs) do
            local category,container=spec[1],spec[2]
            if container then
                for _,obj in ipairs(container:GetChildren()) do
                    if obj.Name~="Poles" and obj.Name~="DevHidden" then
                        local item=captureItem(obj,category,ground)
                        if item then data.items[#data.items+1]=item end
                    end
                end
            end
        end
        return data
    end

    local function saveBlueprint(data,label)
        blueprint=data
        State.build.placeIndex=1
        if not data then return end
        State.build.selected=label
        if FILES.rw then
            ensureFolders()
            local file=PLOTS.."/"..cleanName(label).."_"..tostring(os.time())..".json"
            local ok,raw=pcall(function() return HttpService:JSONEncode(data) end)
            if ok then
                local wrote=pcall(writefile,file,raw)
                if wrote then notify("Blueprint saved ♡  "..#data.items.." pieces") end
            end
        else
            notify("Blueprint captured in memory ♡  "..#data.items.." pieces")
        end
    end

    local function loadNewestBlueprint()
        if not FILES.list or not FILES.rw then
            notify("This executor does not expose local blueprint files.")
            return nil
        end
        ensureFolders()
        local files=listfiles(PLOTS)
        table.sort(files)
        for i=#files,1,-1 do
            local f=files[i]
            if string.sub(string.lower(f),-5)==".json" then
                local ok,raw=pcall(readfile,f)
                if ok and raw then
                    local ok2,data=pcall(function() return HttpService:JSONDecode(raw) end)
                    if ok2 and type(data)=="table" and type(data.items)=="table" then
                        blueprint=data
                        State.build.selected=f
                        State.build.placeIndex=1
                        notify("Loaded blueprint ♡  "..#data.items.." pieces")
                        return data
                    end
                end
            end
        end
        notify("No saved blueprint files found.")
        return nil
    end

    local function clearPreview()
        if previewFolder then pcall(function() previewFolder:Destroy() end) end
        local old=workspace:FindFirstChild("__KimbugersBlueprintPreview")
        if old then pcall(function() old:Destroy() end) end
        previewFolder=nil
    end

    local function previewOnMyPlot()
        if not blueprint then notify("Capture or load a blueprint first.") return end
        local plot=Runtime:myPlot()
        if not plot then notify("Your plot is not loaded.") return end
        clearPreview()
        previewFolder=Instance.new("Folder")
        previewFolder.Name="__KimbugersBlueprintPreview"
        previewFolder.Parent=workspace
        local ground=Runtime:plotGround(plot)
        local shown=0
        for _,item in ipairs(blueprint.items) do
            if shown>=1200 then break end
            if type(item.relCFrame)=="table" then
                local cf=ground*Runtime:cframeUnpack(item.relCFrame)
                local sz=item.size
                local p=Instance.new("Part")
                p.Name=item.category.." • "..item.name
                p.Anchored=true
                p.CanCollide=false
                p.CanTouch=false
                p.CanQuery=false
                p.Material=Enum.Material.ForceField
                p.Transparency=.68
                p.Color=T().accent
                if type(sz)=="table" and #sz>=3 then
                    p.Size=Vector3.new(math.max(.35,sz[1]),math.max(.35,sz[2]),math.max(.35,sz[3]))
                else
                    p.Size=Vector3.new(2,2,2)
                end
                p.CFrame=cf
                p.Parent=previewFolder
                shown=shown+1
            end
        end
        notify("Blueprint preview: "..shown.." piece(s) ♡")
    end

    local function buildMenu()
        local mg=runtimeMainGui()
        return mg and mg:FindFirstChild("BuildMenu")
    end

    local function selectCatalogItem(itemName)
        local bm=buildMenu()
        if not bm or not bm.Visible then return false,"enter Build Mode first" end
        local search=bm:FindFirstChild("SearchBox",true)
        if search and search:IsA("TextBox") then
            search.Text=itemName
            pcall(function() search:CaptureFocus(); search:ReleaseFocus(false) end)
            task.wait(.35)
        end

        local exact=nil
        for _,b in ipairs(bm:GetDescendants()) do
            if b:IsA("GuiButton") and Runtime:visible(b) then
                local nameLabel=b:FindFirstChild("NameLabel",true)
                if nameLabel and nameLabel:IsA("TextLabel") and
                    string.lower(nameLabel.Text)==string.lower(itemName) then
                    exact=b break
                end
            end
        end
        if not exact then
            exact=Runtime:buttonByText(bm,itemName)
        end
        if not exact then return false,"catalog item not visible: "..itemName end
        Runtime:clickGui(exact)
        task.wait(.18)

        local placement=bm:FindFirstChild("Placement",true)
        if placement and placement:IsA("GuiButton") and Runtime:visible(placement) then
            Runtime:clickGui(placement)
            task.wait(.12)
        end
        return true
    end

    local function placeItem(item)
        if not item or type(item.relCFrame)~="table" then return false,"missing transform" end
        if item.category~="Objects" and item.category~="Counters" and item.category~="FrontObjects" then
            return false,"structure piece needs point placement"
        end
        local plot=Runtime:myPlot()
        if not plot then return false,"your plot not loaded" end
        local ok,msg=selectCatalogItem(item.name)
        if not ok then return false,msg end

        local target=Runtime:plotGround(plot)*Runtime:cframeUnpack(item.relCFrame)
        local _,ry,_=target:ToOrientation()
        local snap=tonumber(tostring(State.build.snap or "15"):match("%d+")) or 15
        snap=math.max(1,math.min(90,snap))
        local turns=math.floor(((math.deg(ry)%360)/snap)+.5)%math.max(1,math.floor(360/snap))
        for _=1,turns do Runtime:key(Enum.KeyCode.R); task.wait(.045) end
        local clicked=Runtime:mouseWorldClick(target)
        if not clicked then return false,"mouse placement input unavailable" end
        task.wait(State.build.placeDelay or .85)
        return true,"placed "..item.name
    end

    local statusCard=card(bp,"Auto Build ♡","Save the plot you are standing on, preview it on your own plot, then replay ordinary catalog placements. Walls/floors/roofs are saved + previewed but point-drawing is not silently faked.")
    local bpName=infoLine(statusCard,"Blueprint","None",true)
    local bpCount=infoLine(statusCard,"Pieces","0",true)
    local bpIndex=infoLine(statusCard,"Placement","0 / 0",true)
    local bpState=infoLine(statusCard,"Status","Ready",true)

    button(statusCard,"SAVE NEAREST PLOT AS BLUEPRINT",function()
        local plot,dist=Runtime:nearestPlot()
        if not plot then notify("No plot detected.") return end
        local data,err=capturePlot(plot)
        if not data then notify(err) return end
        saveBlueprint(data,plot.Name)
        bpName.Text=plot.Name
        bpCount.Text=tostring(#data.items)
        bpIndex.Text="1 / "..#data.items
        bpState.Text="Captured ♡"
        notify("Captured nearest plot ("..math.floor(dist or 0).." studs away) ♡")
    end)

    button(statusCard,"SAVE MY PLOT AS BLUEPRINT",function()
        local plot=Runtime:myPlot()
        local data,err=capturePlot(plot)
        if not data then notify(err) return end
        saveBlueprint(data,plot.Name)
        bpName.Text=plot.Name
        bpCount.Text=tostring(#data.items)
        bpIndex.Text="1 / "..#data.items
        bpState.Text="Captured ♡"
    end)

    button(statusCard,"LOAD NEWEST SAVED BLUEPRINT",function()
        local data=loadNewestBlueprint()
        if data then
            bpName.Text=tostring((data.meta and data.meta.sourcePlot) or "Saved Blueprint")
            bpCount.Text=tostring(#data.items)
            bpIndex.Text=tostring(State.build.placeIndex).." / "..#data.items
            bpState.Text="Loaded ♡"
        end
    end)

    local preview=card(bp,"Blueprint Preview ♡","Shows the saved layout on your current plot before anything is clicked or purchased.")
    button(preview,"PREVIEW BLUEPRINT ON MY PLOT",previewOnMyPlot)
    button(preview,"CLEAR PREVIEW",function() clearPreview(); notify("Preview cleared ♡") end)

    local placement=card(bp,"Placement Assistant ♡","Uses the normal Build Mode catalog and mouse placement flow. It never calls hidden placement remotes.")
    slider(placement,"Placement Delay",0.35,2.5,State.build.placeDelay,.05,function(v) State.build.placeDelay=v end)
    toggle(placement,"Skip Unsupported / Failed Pieces",State.build.skipFailed,function(v) State.build.skipFailed=v end)

    button(placement,"PLACE NEXT SUPPORTED OBJECT",function()
        if not blueprint then notify("Capture or load a blueprint first.") return end
        local total=#blueprint.items
        local i=math.max(1,State.build.placeIndex or 1)
        while i<=total do
            local item=blueprint.items[i]
            bpState.Text="Trying "..item.name
            local ok,msg=placeItem(item)
            i=i+1
            State.build.placeIndex=i
            bpIndex.Text=math.min(i,total).." / "..total
            if ok then bpState.Text=msg; return end
            if not State.build.skipFailed then bpState.Text=msg; notify(msg); return end
        end
        bpState.Text="Blueprint finished / no supported pieces left ♡"
    end)

    button(placement,"AUTO PLACE SUPPORTED OBJECTS",function()
        if State.build.autoPlacing then notify("Auto Build is already running.") return end
        if not blueprint then notify("Capture or load a blueprint first.") return end
        if not runtimeBuildMode() then notify("Enter Build Mode first.") return end
        State.build.autoPlacing=true
        buildToken=buildToken+1
        local myToken=buildToken
        task.spawn(function()
            local total=#blueprint.items
            local i=math.max(1,State.build.placeIndex or 1)
            while State.build.autoPlacing and myToken==buildToken and i<=total do
                local item=blueprint.items[i]
                bpState.Text="Auto: "..item.name
                local ok,msg=placeItem(item)
                i=i+1
                State.build.placeIndex=i
                bpIndex.Text=math.min(i,total).." / "..total
                if ok then
                    bpState.Text=msg
                elseif not State.build.skipFailed then
                    bpState.Text=msg
                    break
                end
                task.wait(.08)
            end
            State.build.autoPlacing=false
            if i>total then bpState.Text="Auto Build pass complete ♡" end
        end)
    end)

    button(placement,"STOP AUTO BUILD",function()
        State.build.autoPlacing=false
        buildToken=buildToken+1
        bpState.Text="Stopped"
    end)

    local buildLive=card(bp,"Live Build Mode ♡","Reads the confirmed BuildMenu and plot builder state from Bloxburg.")
    local buildLiveState=infoLine(buildLive,"Build Mode","Not active",true)
    local activeBuilders=infoLine(buildLive,"Active builders","—",false)
    RunService.Heartbeat:Connect(function()
        if not buildLiveState.Parent then return end
        buildLiveState.Text=runtimeBuildMode() and "Active ♡" or "Not active"
        local plot=Runtime:myPlot()
        local ab=plot and plot:FindFirstChild("PlotData") and plot.PlotData:FindFirstChild("ActiveBuilders")
        activeBuilders.Text=ab and tostring(ab.Value) or "—"
        if blueprint then
            bpCount.Text=tostring(#blueprint.items)
            bpIndex.Text=tostring(math.min(State.build.placeIndex or 1,#blueprint.items)).." / "..#blueprint.items
        end
    end)
end


-- Jobs
do
    local jp=pages.Jobs
    local jobs={
        "Ben's Ice Cream",
        "Blox Burgers",
        "Pizza Planet Baker",
        "Pizza Planet Delivery",
        "Stylez Hairdresser",
        "Supermarket Cashier",
        "Supermarket Stocker",
        "Taxi Driver",
        "Fisherman",
        "School Janitor",
    }
    local ctx={}
    local workToken=0

    local function orderSummary(job)
        if job=="Ben's Ice Cream" then
            local c=Runtime:findCustomer("BensIceCreamCustomer","Order")
            local o=c and c:FindFirstChild("Order")
            if o then
                local f1=o:FindFirstChild("Flavor1")
                local f2=o:FindFirstChild("Flavor2")
                local top=o:FindFirstChild("Topping")
                if f1 or f2 or top then
                    return table.concat({
                        f1 and tostring(f1.Value) or "?",
                        f2 and tostring(f2.Value) or "?",
                        top and tostring(top.Value) or "No topping",
                    }," + ")
                end
            end
            return "Waiting for customer"
        elseif job=="Pizza Planet Baker" then
            local c=Runtime:findCustomer("PizzaPlanetCustomer","Order")
            local o=c and c:FindFirstChild("Order")
            local p=o and o:FindFirstChild("Pizza")
            return p and ("Pizza: "..tostring(p.Value)) or "Waiting for pizza order"
        elseif job=="Stylez Hairdresser" then
            local c=Runtime:findCustomer("StylezHairStudioCustomer","Order")
            local o=c and c:FindFirstChild("Order")
            local st=o and o:FindFirstChild("Style")
            local co=o and o:FindFirstChild("Color")
            if st or co then return tostring(st and st.Value or "?").." / "..tostring(co and co.Value or "?") end
            return "Waiting for customer"
        elseif job=="Supermarket Cashier" then
            local c=Runtime:findCustomer("SupermarketCustomer","Status")
            local s=c and c:FindFirstChild("Status")
            local placed=s and s:FindFirstChild("PlacedObjects")
            local scanned=s and s:FindFirstChild("ScannedObjects")
            if placed or scanned then
                return "Placed "..tostring(placed and placed.Value or 0).." • Scanned "..tostring(scanned and scanned.Value or 0)
            end
            return "Waiting for customer"
        elseif job=="Pizza Planet Delivery" then
            return Runtime:findCustomer("PizzaPlanetDeliveryCustomer") and "Delivery customer detected" or "Waiting for delivery target"
        elseif job=="Taxi Driver" then
            local c=Runtime:findCustomer("TaxiCustomer")
            if c then
                local p=c:GetAttribute("_customerPosition")
                return p and ("Customer "..tostring(p)) or "Taxi customer detected"
            end
            return "Waiting for customer"
        end
        local txt=Runtime:visibleInteractText()
        return txt or "Watching task state"
    end

    local function benStep()
        local c=Runtime:findCustomer("BensIceCreamCustomer","Order")
        local o=c and c:FindFirstChild("Order")
        if not o then return "Waiting for Ben's customer" end
        local f1=o:FindFirstChild("Flavor1")
        local f2=o:FindFirstChild("Flavor2")
        local top=o:FindFirstChild("Topping")
        if not f1 and not f2 then return "Waiting for order" end

        local sig=tostring(c)..":"..tostring(f1 and f1.Value)..":"..tostring(f2 and f2.Value)..":"..tostring(top and top.Value)
        if ctx.sig~=sig then ctx.sig=sig; ctx.stage=1 end
        ctx.stage=ctx.stage or 1

        local stages={
            {"Cup",{"paper cup dispenser","cup dispenser","cup"},"take"},
            {"Scoop 1",{tostring(f1 and f1.Value or ""), "ice cream"},"take"},
            {"Scoop 2",{tostring(f2 and f2.Value or ""), "ice cream"},"take"},
            {"Topping",{tostring(top and top.Value or "")},"take"},
        }

        if ctx.stage<=#stages then
            local s=stages[ctx.stage]
            if s[2][1]=="" then ctx.stage=ctx.stage+1 return "Skipping empty "..s[1] end
            local target=Runtime:findWorldTarget("Ben's Ice Cream",s[2])
            if not target then return s[1].." station not found yet" end
            Runtime:moveNear(target)
            task.wait(.16)
            Runtime:interact(s[3])
            ctx.stage=ctx.stage+1
            return s[1].." ✓"
        end

        if c then
            Runtime:moveNear(c,Vector3.new(0,2,2.5))
            task.wait(.16)
            Runtime:interact("")
            ctx.stage=ctx.stage+1
            return "Serving customer…"
        end
        return "Waiting"
    end

    local function burgerStep()
        local mg=runtimeMainGui()
        local cashier=mg and mg:FindFirstChild("CashierFrame")
        if not cashier or not cashier.Visible then
            local target=Runtime:findWorldTarget("Blox Burgers",{"cash register","register","cashier"})
            if target then Runtime:moveNear(target); task.wait(.12); Runtime:interact("") end
            return "Opening cashier…"
        end

        local c=Runtime:findCustomer("BloxBurgersCustomer")
        local iconFrame=c and c:FindFirstChild("IconFrame",true)
        if not iconFrame then return "Waiting for burger order" end

        local clicked=0
        local used={}
        for _,img in ipairs(iconFrame:GetDescendants()) do
            if img:IsA("ImageLabel") and Runtime:visible(img) and img.Image~="" and not used[img.Image] then
                used[img.Image]=true
                local b=Runtime:buttonByImage(cashier,img.Image)
                if b then Runtime:clickGui(b); clicked=clicked+1; task.wait(.08) end
            end
        end

        for _,tl in ipairs(iconFrame:GetDescendants()) do
            if tl:IsA("TextLabel") and Runtime:visible(tl) then
                local tx=string.upper(tl.Text)
                if tx=="S" or tx=="M" or tx=="L" then
                    local names={S="Small",M="Medium",L="Large"}
                    local b=Runtime:buttonByText(cashier,names[tx])
                    if b then Runtime:clickGui(b); clicked=clicked+1; task.wait(.06) end
                end
            end
        end

        local confirm=cashier:FindFirstChild("Confirm",true)
        if confirm and confirm:IsA("GuiButton") and Runtime:visible(confirm) then
            Runtime:clickGui(confirm)
            clicked=clicked+1
        end
        return clicked>0 and ("Cashier input "..clicked.." click(s)") or "Order visible; waiting for matching buttons"
    end

    local function bakerStep()
        local c=Runtime:findCustomer("PizzaPlanetCustomer","Order")
        local o=c and c:FindFirstChild("Order")
        local p=o and o:FindFirstChild("Pizza")
        local kind=p and tostring(p.Value) or "Cheese"
        local sig=tostring(c)..":"..kind
        if ctx.sig~=sig then ctx.sig=sig; ctx.stage=1 end
        ctx.stage=ctx.stage or 1
        local seq={
            {"Dough",{"dough"},"add dough"},
            {"Sauce",{"sauce"},""},
            {"Cheese",{"cheese"},""},
        }
        if kind~="Cheese" then seq[#seq+1]={kind,{string.lower(kind)},""} end
        seq[#seq+1]={"Oven",{"oven","conveyor"},""}

        local s=seq[ctx.stage]
        if s then
            local target=Runtime:findWorldTarget("Pizza Planet Baker",s[2])
            if target then
                Runtime:moveNear(target)
                task.wait(.15)
                Runtime:interact(s[3])
                ctx.stage=ctx.stage+1
                return s[1].." ✓"
            end
            local visible=Runtime:visibleInteractText()
            if visible then Runtime:interact(""); ctx.stage=ctx.stage+1; return visible.." ✓" end
            return "Looking for "..s[1]
        end
        ctx.stage=1
        return "Pizza cycle complete; checking next order"
    end

    local function deliveryStep()
        local customer=Runtime:findCustomer("PizzaPlanetDeliveryCustomer")
        local char=LP.Character
        local backpack=LP:FindFirstChildOfClass("Backpack")
        local box=(char and char:FindFirstChild("Pizza Box",true)) or (backpack and backpack:FindFirstChild("Pizza Box",true))
        if not box then
            local target=Runtime:findWorldTarget("Pizza Planet Delivery",{"pizza box","delivery pizza","pizza"})
            if target then
                Runtime:moveNear(target)
                task.wait(.15)
                Runtime:interact("take")
                return "Getting pizza box…"
            end
            return "Waiting for pizza box"
        end
        if customer then
            Runtime:moveNear(customer,Vector3.new(0,2,2.5))
            task.wait(.15)
            Runtime:interact("")
            return "Delivering pizza…"
        end
        return "Waiting for delivery customer"
    end

    local function hairStep()
        local c=Runtime:findCustomer("StylezHairStudioCustomer","Order")
        local o=c and c:FindFirstChild("Order")
        if not c or not o then return "Waiting for hair customer" end
        local st=o:FindFirstChild("Style")
        local co=o:FindFirstChild("Color")
        local style=tostring(st and st.Value or "")
        local color=tostring(co and co.Value or "")
        Runtime:moveNear(c,Vector3.new(0,2,3))
        task.wait(.12)

        local pg=LP:FindFirstChildOfClass("PlayerGui")
        local clicked=false
        if pg then
            local b=Runtime:buttonByText(pg,style)
            if b then Runtime:clickGui(b); clicked=true; task.wait(.08) end
            local b2=Runtime:buttonByText(pg,color)
            if b2 then Runtime:clickGui(b2); clicked=true; task.wait(.08) end
        end
        if not clicked then Runtime:interact("") end
        return "Order: "..style.." / "..color..(clicked and " ✓" or " • matching visible controls")
    end

    local function cashierStep()
        local c=Runtime:findCustomer("SupermarketCustomer","Status")
        local s=c and c:FindFirstChild("Status")
        if not c or not s then return "Waiting for supermarket customer" end
        local placed=s:FindFirstChild("PlacedObjects")
        local scanned=s:FindFirstChild("ScannedObjects")
        if placed and scanned and scanned.Value>=placed.Value and placed.Value>0 then
            Runtime:moveNear(c,Vector3.new(0,2,3))
            Runtime:interact("")
            return "Checkout complete; advancing customer"
        end
        local target=Runtime:findWorldTarget("Supermarket Cashier",{"grocery","item","bag","scanner","checkout"})
        if target then
            Runtime:moveNear(target)
            task.wait(.1)
            Runtime:interact("")
            return "Scanning items… "..tostring(scanned and scanned.Value or 0).."/"..tostring(placed and placed.Value or "?")
        end
        Runtime:interact("")
        return "Cashier "..tostring(scanned and scanned.Value or 0).."/"..tostring(placed and placed.Value or "?")
    end

    local function stockerStep()
        local tx=Runtime:visibleInteractText()
        if tx and string.find(string.lower(tx),"restock",1,true) then
            Runtime:interact("restock")
            return "Restocking shelf…"
        end
        local target=Runtime:findWorldTarget("Supermarket Stocker",{"crate","stock","shelf","box"})
        if target then
            Runtime:moveNear(target)
            task.wait(.1)
            Runtime:interact("")
            return "Moving to stock target…"
        end
        return "Looking for restock target"
    end

    local function taxiStep()
        local c=Runtime:findCustomer("TaxiCustomer")
        if not c then return "Waiting for taxi customer" end
        local hrp=c:FindFirstChild("HumanoidRootPart")
        local attached=hrp and hrp:FindFirstChild("AttachWeld")
        if not attached then
            Runtime:moveNear(c,Vector3.new(0,2,3))
            task.wait(.12)
            Runtime:interact("")
            return "Picking up taxi customer…"
        end
        return "Customer onboard • destination is not exposed in this capture"
    end

    local function genericStep(job)
        local tx=Runtime:visibleInteractText()
        if tx then Runtime:interact(""); return "Interaction: "..tx end
        local ok,msg=Runtime:teleportJob(job)
        return ok and "At job • waiting for task prompt" or msg
    end

    local handlers={
        ["Ben's Ice Cream"]=benStep,
        ["Blox Burgers"]=burgerStep,
        ["Pizza Planet Baker"]=bakerStep,
        ["Pizza Planet Delivery"]=deliveryStep,
        ["Stylez Hairdresser"]=hairStep,
        ["Supermarket Cashier"]=cashierStep,
        ["Supermarket Stocker"]=stockerStep,
        ["Taxi Driver"]=taxiStep,
        ["Fisherman"]=function() return genericStep("Fisherman") end,
        ["School Janitor"]=function() return genericStep("School Janitor") end,
    }

    local ctl=card(jp,"Auto Work ♡","Pick a captured job. Kimbugers reads the live task/customer objects and automates visible movement + interactions without hidden job remotes.")
    local selectedLine=infoLine(ctl,"Selected",State.jobs.selectedJob,true)
    local currentLine=infoLine(ctl,"Current job",Runtime:jobTitle(),true)
    local orderLine=infoLine(ctl,"Task / order",orderSummary(State.jobs.selectedJob),false)
    local autoLine=infoLine(ctl,"Auto Work","OFF",true)
    local stepLine=infoLine(ctl,"Last step","Idle",false)

    cycle(ctl,"Job",jobs,State.jobs.selectedJob,function(v)
        State.jobs.selectedJob=v
        selectedLine.Text=v
        ctx={}
        orderLine.Text=orderSummary(v)
    end)

    slider(ctl,"Loop Delay",0.35,2.0,State.jobs.loopDelay,.05,function(v) State.jobs.loopDelay=v end)

    button(ctl,"TELEPORT TO SELECTED JOB",function()
        local ok,msg=Runtime:teleportJob(State.jobs.selectedJob)
        notify(ok and ("Teleported to "..State.jobs.selectedJob.." ♡") or msg)
    end)

    button(ctl,"RUN ONE AUTO-WORK STEP",function()
        local fn=handlers[State.jobs.selectedJob]
        if not fn then notify("No mapped handler for this job.") return end
        local ok,msg=pcall(fn)
        stepLine.Text=ok and tostring(msg) or ("Error: "..tostring(msg))
    end)

    button(ctl,"START AUTO WORK",function()
        if State.jobs.autoWork then notify("Auto Work is already running.") return end
        State.jobs.autoWork=true
        State.jobs.status="Auto Work"
        workToken=workToken+1
        local myToken=workToken
        autoLine.Text="ON ♡"
        ctx={}
        local area=Runtime:getJobArea(State.jobs.selectedJob)
        local root=Runtime:root()
        if area and root and (root.Position-area.Position).Magnitude>45 then
            Runtime:teleportJob(State.jobs.selectedJob)
            task.wait(.35)
        end
        Runtime:startVisibleJob()
        task.wait(.2)
        task.spawn(function()
            while State.jobs.autoWork and myToken==workToken do
                local fn=handlers[State.jobs.selectedJob]
                if fn then
                    local ok,msg=pcall(fn)
                    stepLine.Text=ok and tostring(msg) or ("Error: "..tostring(msg))
                    if ok and tostring(msg):find("✓",1,true) then State.jobs.tasks=State.jobs.tasks+1 end
                else
                    stepLine.Text="No mapped handler"
                end
                orderLine.Text=orderSummary(State.jobs.selectedJob)
                task.wait(State.jobs.loopDelay or .85)
            end
            autoLine.Text="OFF"
        end)
    end)

    button(ctl,"STOP AUTO WORK",function()
        State.jobs.autoWork=false
        State.jobs.status="Idle"
        workToken=workToken+1
        autoLine.Text="OFF"
        stepLine.Text="Stopped"
    end)

    local mapped=card(jp,"Mapped Job Data ♡","These are the task signals found in your capture. Jobs with thinner captures use the generic visible-interaction fallback.")
    txt(mapped,"♥ Ben's: Order.Flavor1 / Flavor2 / Topping",12,true,false)
    txt(mapped,"♥ Blox Burgers: CashierFrame + customer order icons",12,true,false)
    txt(mapped,"♥ Pizza Baker: PizzaPlanetCustomer.Order.Pizza",12,true,false)
    txt(mapped,"♥ Delivery: PizzaPlanetDeliveryCustomer + Pizza Box",12,true,false)
    txt(mapped,"♥ Hairdresser: Order.Style + Order.Color",12,true,false)
    txt(mapped,"♥ Cashier: Status.PlacedObjects + ScannedObjects",12,true,false)
    txt(mapped,"♥ Stocker: live Restock interaction",12,true,false)
    txt(mapped,"♡ Taxi/Fisherman/Janitor have partial task captures",12,true,true)

    local dash=card(jp,"Live Work Dashboard ♡","")
    local s1=infoLine(dash,"Job title",Runtime:jobTitle(),true)
    local s2=infoLine(dash,"Efficiency","—",true)
    local s3=infoLine(dash,"Tasks / steps",tostring(State.jobs.tasks),true)
    local s4=infoLine(dash,"Visible interaction","—",false)

    RunService.Heartbeat:Connect(function()
        if not s1.Parent then return end
        local working,pct=runtimeJobEfficiency()
        s1.Text=Runtime:jobTitle()
        s2.Text=working and tostring(pct or "working") or "—"
        s3.Text=tostring(State.jobs.tasks)
        s4.Text=Runtime:visibleInteractText() or "—"
        currentLine.Text=Runtime:jobTitle()
        selectedLine.Text=State.jobs.selectedJob
        orderLine.Text=orderSummary(State.jobs.selectedJob)
        autoLine.Text=State.jobs.autoWork and "ON ♡" or "OFF"
    end)
end


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

-- Teleports
local tp=pages.Teleports
local loc=card(tp,"Location Shortcuts ♡","These shortcuts only activate when a compatible teleport/location adapter has been connected.")
infoLine(loc,"Teleport adapter",Adapters.Teleports and "Connected ✓" or "Not connected",Adapters.Teleports~=nil)
button(loc,"MY PLOT",function() if Adapters.Teleports and Adapters.Teleports.GoPlot then Adapters.Teleports:GoPlot() else notify("Teleport adapter is not connected.") end end)
button(loc,"CURRENT JOB",function() if Adapters.Teleports and Adapters.Teleports.GoJob then Adapters.Teleports:GoJob() else notify("Teleport adapter is not connected.") end end)
button(loc,"TOWN CENTER",function() if Adapters.Teleports and Adapters.Teleports.GoTown then Adapters.Teleports:GoTown() else notify("Teleport adapter is not connected.") end end)
local locHelp=card(tp,"Navigation Helpers","Useful even when the teleport adapter is unavailable.")
button(locHelp,"CENTER CAMERA ON CHARACTER",function() local h=getHumanoid(); if h and Camera then Camera.CameraSubject=h end end)
button(locHelp,"OPEN VEHICLE DASHBOARD",function() show("Vehicle") end)
button(locHelp,"OPEN BUILD PLANNER",function() show("Build & Plot") end)

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
txt(about,"Cute Bloxburg helper interface with local visual, planner, tracking, and dashboard tools.",12,true,true)
txt(about,"v2.1 uses client-visible task state + normal input helpers. Hidden payout/build remotes are not called.",12,true,true)

_G.KimbugersToggle=function() State.open=not State.open; main.Visible=State.open end
UIS.InputBegan:Connect(function(i)
    if UIS:GetFocusedTextBox() then return end
    if i.KeyCode==Enum.KeyCode.RightShift then _G.KimbugersToggle() end
end)

show(State.page)
applyTheme()
applyEnv()
applyVis()
mainScale.Scale=clamp(State.uiScale or 1,.85,1.15)
pcall(function() if Camera then Camera.FieldOfView=State.player.fov end end)
notify("Kimbugers ♡ "..BUILD.." loaded")
print("[Kimbugers ♡] "..BUILD.." loaded • repo: Kimbugers")
