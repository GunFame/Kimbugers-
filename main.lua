--[[
    Kimbugers ♡ v1.2
    Bloxburg-focused modular hub foundation

    GitHub repository: Kimbugers

    This base intentionally keeps Bloxburg-specific Auto Build / Auto Work logic
    behind adapters so those systems can be added later without rewriting the UI.
    It does not spoof payouts, bypass paid entitlements, or include anti-cheat evasion.
]]

if _G.KimbugersLoaded then
    if _G.KimbugersToggle then pcall(_G.KimbugersToggle) end
    return
end
_G.KimbugersLoaded = true

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local BUILD = "v1.2"
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
    ["Build & Plot"]="building, blueprints, and plot tools",
    Jobs="shift tracking and work-planning tools",
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

local stat=card(ov,"Live Status","See what is actually available instead of dead buttons pretending to work.")
local bs=infoLine(stat,"Build adapter",Adapters.Build and "Connected ✓" or "Not connected",Adapters.Build~=nil)
local js=infoLine(stat,"Jobs adapter",Adapters.Jobs and "Connected ✓" or "Not connected",Adapters.Jobs~=nil)
local vs=infoLine(stat,"Vehicle","Not seated",false)
local themeStatus=infoLine(stat,"Current theme",State.theme,true)
RunService.Heartbeat:Connect(function()
    if not stat.Parent then return end
    bs.Text=Adapters.Build and "Connected ✓" or "Not connected"
    js.Text=Adapters.Jobs and "Connected ✓" or "Not connected"
    local h=getHumanoid(); local seat=h and h.SeatPart
    vs.Text=(seat and seat:IsA("VehicleSeat")) and "Driving ♡" or "Not seated"
    themeStatus.Text=State.theme
end)

local quick=card(ov,"Quick Actions","Jump straight to the pages you will use most.")
button(quick,"♡  BUILD & PLOT PLANNER",function() show("Build & Plot") end)
button(quick,"♡  SHIFT TRACKER",function() show("Jobs") end)
button(quick,"♡  VEHICLE DASHBOARD",function() show("Vehicle") end)
button(quick,"♡  ENVIRONMENT & LIGHTING",function() show("Environment") end)

local ready=card(ov,"What Works Right Now","These do not depend on hidden Bloxburg server calls.")
txt(ready,"♥ Player movement + FOV controls",13,true,false)
txt(ready,"♥ Local shift timer and manual stats",13,true,false)
txt(ready,"♥ Vehicle speed HUD + driving camera FOV",13,true,false)
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
button(lib,"CAPTURE CURRENT PLOT (ADAPTER)",function()
    if not Adapters.Build or type(Adapters.Build.ScanCurrentPlot)~="function" then notify("Plot capture needs a compatible Build adapter.") return end
    local data=Adapters.Build:ScanCurrentPlot(); if type(data)~="table" then notify("Plot capture failed.") return end
    data.meta=data.meta or {}; data.meta.owner=LP.Name; data.meta.createdAt=os.time(); data.meta.format="KimbugersBlueprintV1"
    State.build.selected=data
    local name=tostring(data.meta.name or ("Plot_"..os.time())):gsub("[^%w%-%_ ]","")
    selected.Text="Selected Blueprint: "..name
    if FILES.rw then ensureFolders(); writefile(PLOTS.."/"..name..".json",HttpService:JSONEncode(data)); notify("Blueprint saved ♡") else notify("Blueprint captured in memory.") end
end)

local comp=card(bp,"Build Checklist","A quick checklist so this page still helps even with no automation adapter.")
txt(comp,"♡ Set your budget before entering Build Mode",13,true,false)
txt(comp,"♡ Pick a snap preference and structure-first option",13,true,false)
txt(comp,"♡ Use a wider FOV from Player for large builds",13,true,false)
txt(comp,"♡ Use Environment presets for brighter interiors",13,true,false)
txt(comp,"♡ Save your Kimbugers config when the setup feels right",13,true,false)

-- Jobs
local jp=pages.Jobs
local work=card(jp,"Shift Tracker ♡","A working local timer and manual shift tracker. It does not pretend Auto Work is connected when it is not.")
cycle(work,"Pace",{"Chill","Normal","Focused"},State.jobs.mode,function(v) State.jobs.mode=v end)
button(work,"START SHIFT TRACKER",function()
    if not State.jobs.tracking then
        State.jobs.tracking=true; State.jobs.paused=false; State.jobs.lastTick=os.clock(); State.jobs.status="Tracking"
        notify("Shift tracker started ♡")
    elseif State.jobs.paused then
        State.jobs.paused=false; State.jobs.lastTick=os.clock(); State.jobs.status="Tracking"
    end
end)
button(work,"PAUSE / RESUME TRACKER",function()
    if not State.jobs.tracking then notify("Start the shift tracker first.") return end
    State.jobs.paused=not State.jobs.paused
    State.jobs.lastTick=os.clock()
    State.jobs.status=State.jobs.paused and "Paused" or "Tracking"
end)
button(work,"RESET SHIFT",function()
    State.jobs.tracking=false; State.jobs.paused=false; State.jobs.elapsed=0; State.jobs.lastTick=nil
    State.jobs.tasks=0; State.jobs.earned=0; State.jobs.status="Idle"
    notify("Shift stats reset ♡")
end)

local manual=card(jp,"Manual Stats","Tap these while you work if you want the dashboard to track your session.")
button(manual,"+ 1 TASK",function() State.jobs.tasks=State.jobs.tasks+1 end)
button(manual,"+ $100 EARNED",function() State.jobs.earned=State.jobs.earned+100 end)
button(manual,"+ $500 EARNED",function() State.jobs.earned=State.jobs.earned+500 end)
slider(manual,"Goal Minutes",0,180,State.jobs.stopMinutes,5,function(v) State.jobs.stopMinutes=v end)
slider(manual,"Goal Earnings",0,500000,State.jobs.stopEarnings,5000,function(v) State.jobs.stopEarnings=v end)

local st=card(jp,"Shift Dashboard ♡","")
local s1=infoLine(st,"Status","Idle",true)
local s2=infoLine(st,"Time","0m 0s",true)
local s3=infoLine(st,"Tasks","0",true)
local s4=infoLine(st,"Tracked Earnings","$0",true)
local s5=infoLine(st,"Goal","No goal",false)
RunService.Heartbeat:Connect(function()
    if not s1.Parent then return end
    if State.jobs.tracking and not State.jobs.paused then
        local now=os.clock(); local last=State.jobs.lastTick or now
        State.jobs.elapsed=State.jobs.elapsed+math.max(0,now-last); State.jobs.lastTick=now
    elseif State.jobs.tracking then
        State.jobs.lastTick=os.clock()
    end
    s1.Text=State.jobs.status
    s2.Text=string.format("%dm %ds",math.floor(State.jobs.elapsed/60),math.floor(State.jobs.elapsed%60))
    s3.Text=tostring(State.jobs.tasks)
    s4.Text="$"..math.floor(State.jobs.earned)
    if State.jobs.stopEarnings>0 then s5.Text="$"..State.jobs.stopEarnings
    elseif State.jobs.stopMinutes>0 then s5.Text=State.jobs.stopMinutes.." min"
    else s5.Text="No goal" end
end)

local adapterWork=card(jp,"Auto Work Adapter","Auto Work requires job-specific integration with the live game. This build keeps that separate instead of faking a working button.")
infoLine(adapterWork,"Jobs adapter",Adapters.Jobs and "Connected ✓" or "Not connected",Adapters.Jobs~=nil)
button(adapterWork,"CHECK JOBS ADAPTER",function()
    notify(Adapters.Jobs and "Jobs adapter is connected ♡" or "No compatible Jobs adapter is connected.")
end)

-- Vehicle
local veh=pages.Vehicle
local function getVehicleSeat()
    local h=getHumanoid(); local seat=h and h.SeatPart
    if seat and seat:IsA("VehicleSeat") then return seat end
    return nil
end
local function convertSpeed(studs)
    if State.vehicle.unit=="KPH" then return studs*1.008, "km/h" end
    return studs*.626, "mph"
end
local drive=card(veh,"Vehicle Dashboard ♡","Live local driving information while you are sitting in a VehicleSeat.")
local vehicleState=infoLine(drive,"Vehicle","Not seated",true)
local vehicleSpeed=infoLine(drive,"Speed","0 mph",true)
local vehicleThrottle=infoLine(drive,"Throttle","0",false)
local vehicleSteer=infoLine(drive,"Steering","0",false)
cycle(drive,"Speed Unit",{"MPH","KPH"},State.vehicle.unit,function(v) State.vehicle.unit=v end)
toggle(drive,"Floating Speed HUD",State.vehicle.hud,function(v) State.vehicle.hud=v end)

local vcam=card(veh,"Driving Camera ♡","A wider local camera can make driving and parking easier.")
toggle(vcam,"Vehicle Camera FOV",State.vehicle.cameraBoost,function(v)
    State.vehicle.cameraBoost=v
    if Camera then Camera.FieldOfView=v and State.vehicle.cameraFov or State.player.fov end
end)
slider(vcam,"Driving FOV",50,120,State.vehicle.cameraFov,1,function(v)
    State.vehicle.cameraFov=v
    if State.vehicle.cameraBoost and getVehicleSeat() and Camera then Camera.FieldOfView=v end
end)
button(vcam,"RESET DRIVING CAMERA",function()
    State.vehicle.cameraBoost=false; State.vehicle.cameraFov=82
    if Camera then Camera.FieldOfView=State.player.fov end
    notify("Driving camera reset ♡")
end)

local vnote=card(veh,"Vehicle Notes","The HUD reads your current vehicle speed locally. This version does not alter Bloxburg vehicle physics or server-side speed values.")
txt(vnote,"♡ Great for testing routes and comparing cars",13,true,false)
txt(vnote,"♡ HUD automatically hides when you leave the seat",13,true,false)
txt(vnote,"♡ Switch between mph and km/h anytime",13,true,false)

local vehicleHud=N("Frame",{Parent=gui,Name="VehicleHUD",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-34),Size=UDim2.fromOffset(220,74),BorderSizePixel=0,Visible=false})
track(vehicleHud,"panel"); roundFrame(vehicleHud,18); line(vehicleHud,true,1.5,.18)
local hudHeart=txt(vehicleHud,"♥",22,true,false); hudHeart.Position=UDim2.fromOffset(12,10); hudHeart.Size=UDim2.fromOffset(28,28); hudHeart.TextXAlignment=Enum.TextXAlignment.Center; track(hudHeart,"accentText")
local hudSpeed=txt(vehicleHud,"0 mph",27,true,false); hudSpeed.Position=UDim2.fromOffset(46,7); hudSpeed.Size=UDim2.new(1,-58,0,34); hudSpeed.TextXAlignment=Enum.TextXAlignment.Center; track(hudSpeed,"accentText")
local hudSub=txt(vehicleHud,"vehicle speed ♡",10,true,true); hudSub.Position=UDim2.fromOffset(46,40); hudSub.Size=UDim2.new(1,-58,0,20); hudSub.TextXAlignment=Enum.TextXAlignment.Center
RunService.Heartbeat:Connect(function()
    local seat=getVehicleSeat()
    if seat then
        local spd,unit=convertSpeed(seat.AssemblyLinearVelocity.Magnitude)
        vehicleState.Text=seat.Parent and seat.Parent.Name or "VehicleSeat"
        vehicleSpeed.Text=string.format("%.0f %s",spd,unit)
        vehicleThrottle.Text=string.format("%.2f",seat.ThrottleFloat)
        vehicleSteer.Text=string.format("%.2f",seat.SteerFloat)
        vehicleHud.Visible=State.vehicle.hud
        hudSpeed.Text=string.format("%.0f %s",spd,unit)
        if State.vehicle.cameraBoost and Camera then Camera.FieldOfView=State.vehicle.cameraFov end
    else
        vehicleState.Text="Not seated"; vehicleSpeed.Text=State.vehicle.unit=="KPH" and "0 km/h" or "0 mph"
        vehicleThrottle.Text="0"; vehicleSteer.Text="0"; vehicleHud.Visible=false
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
txt(about,"Build/Jobs automation stays isolated behind adapters instead of using fake or unsafe server-side hooks.",12,true,true)

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
