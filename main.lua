--[[
    Kimbugers ♡ v1.1
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
local BUILD = "v1.1"
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
    player = {speedOn=false, speed=16, jumpOn=false, jump=50, fov=70},
    build = {
        status="Idle", selected=nil,
        noGamepass=true, autoAdapt=true, structureOnly=false,
        estimate=true, skipFailed=true,
    },
    jobs = {
        status="Idle", mode="Fast", autoNext=true,
        normalMovement=true, autoReturn=true,
        stopMinutes=0, stopEarnings=0, tasks=0, earned=0, startedAt=nil,
    },
    env = {
        shadows=false, darkness=70, softness=28,
        lights=false, brightness=160, glow=30,
    },
    visuals = {cinematic=false, dof=25, bloom=15},
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
    Parent=gui,Name="Main",Size=UDim2.fromOffset(820,540),Position=UDim2.new(.5,-410,.5,-270),
    BorderSizePixel=0,ClipsDescendants=true
})
track(main,"bg"); roundFrame(main,26); line(main,true,2.1,.16)

-- soft inner shell
local shell=N("Frame",{Parent=main,Position=UDim2.fromOffset(9,9),Size=UDim2.new(1,-18,1,-18),BorderSizePixel=0,ClipsDescendants=true})
track(shell,"bg2"); roundFrame(shell,21); line(shell,false,1,.35)
stitchLine(shell,UDim2.fromOffset(18,1),UDim2.new(1,-36,0,16))
stitchLine(shell,UDim2.new(0,18,1,-17),UDim2.new(1,-36,0,16))
tinyHeart(shell,UDim2.new(1,-43,0,9),28,.08)

local top=N("Frame",{Parent=shell,Size=UDim2.new(1,0,0,76),BackgroundTransparency=1})
local title=txt(top,"Kimbugers ♡",29,true,false); title.Position=UDim2.fromOffset(20,8); title.Size=UDim2.new(0,390,0,38); track(title,"accentText")
local sub=txt(top,"bloxburg hub  •  "..BUILD.."  ♡",12,true,true); sub.Position=UDim2.fromOffset(23,43); sub.Size=UDim2.new(0,360,0,21)

local topProfile=N("Frame",{Parent=top,Position=UDim2.new(1,-222,0,11),Size=UDim2.fromOffset(202,52),BorderSizePixel=0})
track(topProfile,"panel"); roundFrame(topProfile,15); line(topProfile,false,1,.34)
local avatar=N("ImageLabel",{Parent=topProfile,Position=UDim2.fromOffset(7,6),Size=UDim2.fromOffset(40,40),BackgroundTransparency=0,BorderSizePixel=0})
track(avatar,"soft"); roundFrame(avatar,999); line(avatar,false,1,.28)
local profileName=txt(topProfile,LP.DisplayName,13,true,false); profileName.Position=UDim2.fromOffset(54,7); profileName.Size=UDim2.new(1,-60,0,18)
local profileUser=txt(topProfile,"@"..LP.Name,10,false,true); profileUser.Position=UDim2.fromOffset(54,27); profileUser.Size=UDim2.new(1,-60,0,16)
task.spawn(function()
    local ok,img=pcall(function() return Players:GetUserThumbnailAsync(LP.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size180x180) end)
    if ok and avatar and avatar.Parent then avatar.Image=img end
end)

local sidebar=N("Frame",{Parent=shell,Position=UDim2.fromOffset(12,76),Size=UDim2.new(0,184,1,-88),BorderSizePixel=0})
track(sidebar,"bg"); roundFrame(sidebar,18); line(sidebar,false,1,.30)
local featureTitle=txt(sidebar,"♡  FEATURES  ♡",16,true,false); featureTitle.Position=UDim2.fromOffset(10,8); featureTitle.Size=UDim2.new(1,-20,0,26); featureTitle.TextXAlignment=Enum.TextXAlignment.Center; track(featureTitle,"accentText")
local nav=N("ScrollingFrame",{Parent=sidebar,Position=UDim2.fromOffset(8,40),Size=UDim2.new(1,-16,1,-48),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
N("UIPadding",{Parent=nav,PaddingBottom=UDim.new(0,8)})
N("UIListLayout",{Parent=nav,Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})

local content=N("Frame",{Parent=shell,Position=UDim2.fromOffset(208,76),Size=UDim2.new(1,-220,1,-88),BackgroundTransparency=1})
local pages,buttons={},{}
local PAGE_DESCRIPTIONS={
    Overview="your cute bloxburg control center ♡",
    Player="movement and camera controls",
    ["Build & Plot"]="building, blueprints, and plot tools",
    Jobs="work controls and shift tracking",
    Environment="lighting and atmosphere",
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

local sections={"Overview","Player","Build & Plot","Jobs","Environment","Teleports","Visuals & Camera","Settings"}
for i,n in ipairs(sections) do page(n); side(n,i) end

-- Overview
local ov=pages.Overview
local hero=N("Frame",{Parent=ov,LayoutOrder=-90,Size=UDim2.new(1,0,0,128),BorderSizePixel=0,ClipsDescendants=true})
track(hero,"accent"); roundFrame(hero,15); line(hero,true,1,.18)
local heroGrad=N("UIGradient",{Parent=hero,Rotation=8}); trackGradient(heroGrad)
local bubble1=N("Frame",{Parent=hero,Position=UDim2.new(-.03,0,.52,0),Size=UDim2.fromOffset(105,105),BorderSizePixel=0,BackgroundTransparency=.86}); track(bubble1,"panel"); roundFrame(bubble1,999)
local bubble2=N("Frame",{Parent=hero,Position=UDim2.new(.88,0,.44,0),Size=UDim2.fromOffset(100,100),BorderSizePixel=0,BackgroundTransparency=.86}); track(bubble2,"panel"); roundFrame(bubble2,999)
local heroTitle=txt(hero,"Kimbugers ♡",35,true,false); heroTitle.Position=UDim2.new(0,20,.5,-39); heroTitle.Size=UDim2.new(1,-40,0,46); heroTitle.TextXAlignment=Enum.TextXAlignment.Center; track(heroTitle,"whiteText")
local heroSub=txt(hero,"cute bloxburg tools made to match your style ♡",12,true,false); heroSub.Position=UDim2.new(0,20,.5,10); heroSub.Size=UDim2.new(1,-40,0,24); heroSub.TextXAlignment=Enum.TextXAlignment.Center; track(heroSub,"whiteText")
tinyHeart(hero,UDim2.fromOffset(18,12),31,.22); tinyHeart(hero,UDim2.new(1,-51,0,70),27,.22)
local welcome=card(ov,"Welcome to Kimbugers ♡","Cute, organized, modular Bloxburg tools.")
txt(welcome,LP.DisplayName.."  @"..LP.Name,14,true,false)
local stat=card(ov,"Status","")
local bs=txt(stat,"♡ Auto Build: Idle",13,false,false)
local js=txt(stat,"♡ Auto Work: Idle",13,false,false)
local ads=txt(stat,"♡ Adapters: Build …   Jobs …",12,false,true)
RunService.Heartbeat:Connect(function()
    if bs.Parent then
        bs.Text="♡ Auto Build: "..State.build.status
        js.Text="♡ Auto Work: "..State.jobs.status
        ads.Text="♡ Adapters: "..(Adapters.Build and "Build ✓" or "Build …").."   "..(Adapters.Jobs and "Jobs ✓" or "Jobs …")
    end
end)
local quick=card(ov,"Quick Actions","")
button(quick,"Build & Plot",function() show("Build & Plot") end)
button(quick,"Jobs",function() show("Jobs") end)
button(quick,"Environment",function() show("Environment") end)

-- Player
local pp=pages.Player
local move=card(pp,"Movement","Optional local controls. Off by default.")
toggle(move,"Walk Speed Override",State.player.speedOn,function(v) State.player.speedOn=v end)
slider(move,"Walk Speed",8,80,State.player.speed,1,function(v) State.player.speed=v end)
toggle(move,"Jump Override",State.player.jumpOn,function(v) State.player.jumpOn=v end)
slider(move,"Jump Power",20,120,State.player.jump,1,function(v) State.player.jump=v end)
local cam=card(pp,"Camera","")
slider(cam,"Field of View",40,120,State.player.fov,1,function(v) State.player.fov=v; if Camera then Camera.FieldOfView=v end end)
button(cam,"Reset Character",function() local h=getHumanoid(); if h then h.Health=0 end end)
RunService.Heartbeat:Connect(function()
    local h=getHumanoid(); if not h then return end
    if State.player.speedOn then h.WalkSpeed=State.player.speed end
    if State.player.jumpOn then
        if h.UseJumpPower~=false then h.JumpPower=State.player.jump else h.JumpHeight=math.max(2,State.player.jump/7) end
    end
end)

-- Build & Plot
local bp=pages["Build & Plot"]
local auto=card(bp,"Auto Build ♡","Blueprint builder shell. Bloxburg-specific placement is added through the Build adapter.")
local selected=txt(auto,"Selected Blueprint: None",12,false,true)
button(auto,"START BUILD",function()
    if not Adapters.Build or type(Adapters.Build.Start)~="function" then notify("Build adapter isn't connected yet.") return end
    State.build.status="Building"; Adapters.Build:Start(State.build.selected,State.build)
end)
button(auto,"PAUSE / RESUME",function() if Adapters.Build and Adapters.Build.TogglePause then Adapters.Build:TogglePause() else notify("Build adapter isn't connected yet.") end end)
button(auto,"STOP",function() State.build.status="Idle"; if Adapters.Build and Adapters.Build.Stop then Adapters.Build:Stop() end end)
local bo=card(bp,"Build Options","")
toggle(bo,"No Gamepass Mode ♡",State.build.noGamepass,function(v) State.build.noGamepass=v end)
toggle(bo,"Auto Adapt Unsupported Pieces",State.build.autoAdapt,function(v) State.build.autoAdapt=v end)
toggle(bo,"Structure Only",State.build.structureOnly,function(v) State.build.structureOnly=v end)
toggle(bo,"Estimate Before Building",State.build.estimate,function(v) State.build.estimate=v end)
toggle(bo,"Skip Failed Objects",State.build.skipFailed,function(v) State.build.skipFailed=v end)
local lib=card(bp,"Plot Library ♡","Blueprints are saved separately from the main script when file APIs are available.")
button(lib,"Save Current Plot Blueprint",function()
    if not Adapters.Build or type(Adapters.Build.ScanCurrentPlot)~="function" then notify("Plot scanning needs the Bloxburg Build adapter first.") return end
    local data=Adapters.Build:ScanCurrentPlot(); if type(data)~="table" then notify("Plot scan failed.") return end
    data.meta=data.meta or {}; data.meta.owner=LP.Name; data.meta.createdAt=os.time(); data.meta.format="KimbugersBlueprintV1"
    State.build.selected=data
    local name=tostring(data.meta.name or ("Plot_"..os.time())):gsub("[^%w%-%_ ]","")
    selected.Text="Selected Blueprint: "..name
    if FILES.rw then ensureFolders(); writefile(PLOTS.."/"..name..".json",HttpService:JSONEncode(data)); notify("Blueprint saved ♡") else notify("Blueprint captured in memory.") end
end)
button(lib,"Refresh Saved Blueprints",function()
    if not FILES.list then notify("listfiles() isn't available.") return end
    ensureFolders(); local files=listfiles(PLOTS); notify("Found "..#files.." blueprint file(s).")
end)
local comp=card(bp,"Blueprint Compatibility","Before Auto Build starts, the Build adapter will be able to report cost, object count, floors, missing items, and required build privileges.")
txt(comp,"♡ Cost Guard",13,true,false); txt(comp,"♡ No-gamepass adaptation",13,true,false); txt(comp,"♡ Structure-first build order",13,true,false); txt(comp,"♡ Failed-object retry/skip",13,true,false)

-- Jobs
local jp=pages.Jobs
local work=card(jp,"Auto Work ♡","Job automation shell. Job-specific normal actions plug into the Jobs adapter.")
cycle(work,"Work Mode",{"Chill","Fast","MAX WORK"},State.jobs.mode,function(v) State.jobs.mode=v end)
button(work,"START SHIFT",function()
    if not Adapters.Jobs or type(Adapters.Jobs.Start)~="function" then notify("Jobs adapter isn't connected yet.") return end
    State.jobs.status="Working"; State.jobs.startedAt=os.clock(); Adapters.Jobs:Start(State.jobs)
end)
button(work,"PAUSE / RESUME",function() if Adapters.Jobs and Adapters.Jobs.TogglePause then Adapters.Jobs:TogglePause() else notify("Jobs adapter isn't connected yet.") end end)
button(work,"STOP SHIFT",function() State.jobs.status="Idle"; if Adapters.Jobs and Adapters.Jobs.Stop then Adapters.Jobs:Stop() end end)
local wo=card(jp,"Work Options","")
toggle(wo,"Auto Next Task",State.jobs.autoNext,function(v) State.jobs.autoNext=v end)
toggle(wo,"Normal Movement Mode",State.jobs.normalMovement,function(v) State.jobs.normalMovement=v end)
toggle(wo,"Auto Return to Work Area",State.jobs.autoReturn,function(v) State.jobs.autoReturn=v end)
slider(wo,"Auto Stop Minutes (0 = off)",0,180,State.jobs.stopMinutes,5,function(v) State.jobs.stopMinutes=v end)
slider(wo,"Auto Stop Earnings (0 = off)",0,500000,State.jobs.stopEarnings,5000,function(v) State.jobs.stopEarnings=v end)
local st=card(jp,"Shift Stats","")
local s1=txt(st,"Status: Idle",13,false,false); local s2=txt(st,"Time: 0m 0s",13,false,false); local s3=txt(st,"Tasks: 0",13,false,false); local s4=txt(st,"Tracked Earnings: $0",13,false,false)
RunService.Heartbeat:Connect(function()
    if not s1.Parent then return end
    s1.Text="Status: "..State.jobs.status; s3.Text="Tasks: "..State.jobs.tasks; s4.Text="Tracked Earnings: $"..math.floor(State.jobs.earned)
    local e=State.jobs.startedAt and math.max(0,os.clock()-State.jobs.startedAt) or 0; s2.Text=string.format("Time: %dm %ds",math.floor(e/60),math.floor(e%60))
end)

-- Environment
local ep=pages.Environment
local baseLight={Technology=Lighting.Technology,Diffuse=Lighting.EnvironmentDiffuseScale,Soft=Lighting.ShadowSoftness}
local originals=setmetatable({}, {__mode="k"})
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
local sh=card(ep,"Corner Shadows ♡","Darker corners/creases without simply darkening the sky.")
toggle(sh,"Corner / Contact Shadows",State.env.shadows,function(v) State.env.shadows=v; applyEnv() end)
slider(sh,"Corner Darkness",0,150,State.env.darkness,1,function(v) State.env.darkness=v; applyEnv() end)
slider(sh,"Shadow Edge Softness",0,100,State.env.softness,1,function(v) State.env.softness=v; applyEnv() end)
local li=card(ep,"World Lights ♡","Boost actual map light objects locally.")
toggle(li,"Enhanced Lights",State.env.lights,function(v) State.env.lights=v; applyEnv() end)
slider(li,"Light Brightness %",50,400,State.env.brightness,5,function(v) State.env.brightness=v; applyEnv() end)
slider(li,"Light Glow %",0,100,State.env.glow,1,function(v) State.env.glow=v; applyEnv() end)

-- Teleports
local tp=pages.Teleports
local loc=card(tp,"Locations ♡","Locations use an adapter so we don't hard-code coordinates that may change.")
button(loc,"My Plot",function() if Adapters.Teleports and Adapters.Teleports.GoPlot then Adapters.Teleports:GoPlot() else notify("Teleport adapter isn't connected yet.") end end)
button(loc,"Current Job",function() if Adapters.Teleports and Adapters.Teleports.GoJob then Adapters.Teleports:GoJob() else notify("Teleport adapter isn't connected yet.") end end)
button(loc,"Town Center",function() if Adapters.Teleports and Adapters.Teleports.GoTown then Adapters.Teleports:GoTown() else notify("Teleport adapter isn't connected yet.") end end)

-- Visuals & Camera
local vp=pages["Visuals & Camera"]
local dof=Lighting:FindFirstChild("KimbugersDOF") or N("DepthOfFieldEffect",{Parent=Lighting,Name="KimbugersDOF",Enabled=false,FarIntensity=.15,NearIntensity=.1,FocusDistance=18,InFocusRadius=28})
local bloom=Lighting:FindFirstChild("KimbugersBloom") or N("BloomEffect",{Parent=Lighting,Name="KimbugersBloom",Enabled=false,Intensity=.15,Size=24,Threshold=1.2})
local function applyVis() dof.Enabled=State.visuals.cinematic; bloom.Enabled=State.visuals.cinematic; dof.FarIntensity=clamp(State.visuals.dof/100,0,1); bloom.Intensity=clamp(State.visuals.bloom/100,0,1.5) end
local cine=card(vp,"Cinematic Mode ♡","Local camera effects for screenshots, house tours, and roleplay.")
toggle(cine,"Cinematic Effects",State.visuals.cinematic,function(v) State.visuals.cinematic=v; applyVis() end)
slider(cine,"Depth of Field",0,100,State.visuals.dof,1,function(v) State.visuals.dof=v; applyVis() end)
slider(cine,"Bloom",0,100,State.visuals.bloom,1,function(v) State.visuals.bloom=v; applyVis() end)

-- Settings
local sp=pages.Settings
local app=card(sp,"Appearance","")
cycle(app,"Theme",{"Pink","Lilac","Blue"},State.theme,function(v) State.theme=v; applyTheme() end)
local cfg=card(sp,"Config","")
button(cfg,"Save Config",saveConfig)
button(cfg,"Reload Saved Config",function() loadConfig(); applyTheme(); notify("Config values loaded. Re-execute to redraw every saved control.") end)
txt(cfg,"Right Shift toggles Kimbugers ♡",12,false,true)
local about=card(sp,"About","")
txt(about,"Kimbugers ♡  "..BUILD,13,true,false)
txt(about,"GitHub repository: Kimbugers",12,false,true)
txt(about,"Auto Build and Auto Work are isolated adapters so we can upgrade those systems without disrupting the rest of the hub.",12,false,true)

_G.KimbugersToggle=function() State.open=not State.open; main.Visible=State.open end
UIS.InputBegan:Connect(function(i)
    if UIS:GetFocusedTextBox() then return end
    if i.KeyCode==Enum.KeyCode.RightShift then _G.KimbugersToggle() end
end)

show(State.page)
applyTheme()
pcall(function() if Camera then Camera.FieldOfView=State.player.fov end end)
notify("Kimbugers ♡ "..BUILD.." loaded")
print("[Kimbugers ♡] "..BUILD.." loaded • repo: Kimbugers")
