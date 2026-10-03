local function getSafeGui()
    if typeof(gethui) == "function" then return gethui() end
    local ok, cg = pcall(function() return cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return game:GetService("CoreGui")
end
local CoreGui = getSafeGui()

local UIS    = game:GetService("UserInputService")
local TweenS = game:GetService("TweenService")
local RunS   = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- ── Announcement system: version label upvalues ───────────────────────────
-- These are set during UI construction and updated when the announcement
-- JSON is fetched (via the announcement system block at the bottom of this file).
local _headerVersionLbl  -- main header subtitle  (e.g. "v5.2.0 · Piano / Drum / Guitar")
local _helpVersionLbl    -- help panel line        (e.g. "v5.2.0 - Piano/Drum/Guitar Edition")
-- ─────────────────────────────────────────────────────────────────────────

local VIM
do
    local ok, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    VIM = ok and vim or nil
end

local T = {
    bg          = Color3.fromRGB(10,6,24),
    panel       = Color3.fromRGB(20,12,44),
    card        = Color3.fromRGB(30,18,58),
    border      = Color3.fromRGB(90,55,170),
    neon        = Color3.fromRGB(155,80,255),
    neonB       = Color3.fromRGB(190,110,255),
    purpleDeep  = Color3.fromRGB(45,15,100),
    purpleMid   = Color3.fromRGB(85,35,175),
    purpleLight = Color3.fromRGB(170,95,255),
    accent      = Color3.fromRGB(215,170,255),
    neonG   = Color3.fromRGB(80,220,150),   -- green  (playing)
    neonY   = Color3.fromRGB(255,195,60),   -- amber  (paused / BPM)
    neonR   = Color3.fromRGB(240,70,110),   -- red    (stop / rec)
    txt     = Color3.fromRGB(230,215,255),
    txtDim  = Color3.fromRGB(130,105,180),
    white   = Color3.new(1,1,1),
    btnPlay      = Color3.fromRGB(28,80,58),    -- dark teal-green base
    btnPlayAccent= Color3.fromRGB(60,210,140),  -- teal glow / text
    btnStop      = Color3.fromRGB(75,18,38),    -- dark rose base
    btnStopAccent= Color3.fromRGB(230,75,110),  -- rose glow / text
    btnLoop      = Color3.fromRGB(72,48,10),    -- dark amber base
    btnLoopAccent= Color3.fromRGB(240,175,45),  -- amber glow / text
    btnHelp      = Color3.fromRGB(18,42,80),    -- dark blue base
    btnHelpAccent= Color3.fromRGB(85,165,255),  -- sky blue glow / text
    btnLag       = Color3.fromRGB(18,68,60),    -- dark seafoam base
    btnLagAccent = Color3.fromRGB(60,210,175),  -- seafoam glow / text
    btnReload    = Color3.fromRGB(38,22,80),    -- dark purple base
    btnReloadAccent= Color3.fromRGB(160,105,255), -- purple glow / text
}

local Scale = {}
function Scale.init()
    Scale.vp = workspace.CurrentCamera.ViewportSize
    local s  = math.min(Scale.vp.X, Scale.vp.Y)
    Scale.f  = math.max(0.62, math.min(s/480, 1.1))
end
function Scale.px(n) return math.round(n*Scale.f) end
function Scale.fs(n) return math.max(10, math.round(n*Scale.f)) end
Scale.init()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Scale.init)

local function tw(obj,t,props,style)
    TweenS:Create(obj,TweenInfo.new(t,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props):Play()
end
local function twBack(obj,t,props) tw(obj,t,props,Enum.EasingStyle.Back) end

local UI = {}
function UI.frame(parent,props)
    local f=Instance.new("Frame",parent); f.BorderSizePixel=0
    for k,v in pairs(props or {}) do f[k]=v end; return f
end
function UI.corner(parent,r)
    local c=Instance.new("UICorner",parent); c.CornerRadius=UDim.new(0,r or Scale.px(10)); return c
end
function UI.stroke(parent,col,thick)
    local s=Instance.new("UIStroke",parent)
    s.Color=col or T.border; s.Thickness=thick or 1
    s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    return s
end
function UI.label(parent,props)
    local l=Instance.new("TextLabel",parent); l.BackgroundTransparency=1
    l.Font=Enum.Font.BuilderSans; l.TextColor3=T.txt; l.BorderSizePixel=0
    for k,v in pairs(props or {}) do l[k]=v end; return l
end
function UI.btn(parent,props)
    local b=Instance.new("TextButton",parent); b.BorderSizePixel=0
    b.Font=Enum.Font.BuilderSans; b.TextColor3=T.txt; b.AutoButtonColor=false
    for k,v in pairs(props or {}) do b[k]=v end; return b
end
function UI.input(parent,props)
    local i=Instance.new("TextBox",parent); i.BorderSizePixel=0
    i.Font=Enum.Font.BuilderSans; i.TextColor3=T.txt
    for k,v in pairs(props or {}) do i[k]=v end; return i
end
function UI.scroll(parent,props)
    local s=Instance.new("ScrollingFrame",parent); s.BorderSizePixel=0
    s.ScrollBarThickness=Scale.px(4); s.ScrollBarImageColor3=T.neon
    s.CanvasSize=UDim2.new(0,0,0,0)
    for k,v in pairs(props or {}) do s[k]=v end; return s
end
function UI.listLayout(parent,pad)
    local l=Instance.new("UIListLayout",parent)
    l.Padding=UDim.new(0,pad or Scale.px(6))
    l.SortOrder=Enum.SortOrder.LayoutOrder
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if parent:IsA("ScrollingFrame") then
            parent.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+Scale.px(8))
        end
    end)
    return l
end
function UI.gradient(parent,cols,rot)
    local g=Instance.new("UIGradient",parent)
    g.Color=ColorSequence.new(cols); g.Rotation=rot or 0; return g
end
function UI.ripple(btn,col)
    btn.ClipsDescendants=true
    btn.MouseButton1Down:Connect(function(x,y)
        local rp=UI.frame(btn,{
            Size=UDim2.new(0,0,0,0),
            Position=UDim2.new(0,x-btn.AbsolutePosition.X,0,y-btn.AbsolutePosition.Y),
            BackgroundColor3=col or T.white, BackgroundTransparency=0.7, ZIndex=btn.ZIndex+5,
        }); UI.corner(rp,999)
        tw(rp,0.4,{Size=UDim2.new(3,0,3,0),BackgroundTransparency=1})
        task.delay(0.45,function() if rp.Parent then rp:Destroy() end end)
    end)
end
function UI.hover(btn,base,hover)
    btn.MouseEnter:Connect(function() tw(btn,0.12,{BackgroundColor3=hover}) end)
    btn.MouseLeave:Connect(function() tw(btn,0.12,{BackgroundColor3=base}) end)
    UI.ripple(btn,hover)
end
function UI.makeDraggable(handle,target)
    local dragging,dStart,dPos=false,nil,nil
    local dragInput=nil
    local dragIsMouse=false
    handle.Active=true
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            if dragging then return end
            dragging=true
            dragInput=inp
            dragIsMouse=(inp.UserInputType==Enum.UserInputType.MouseButton1)
            if State then State.isFrameDragging=true end
            dStart=inp.Position; dPos=target.Position
            inp.Changed:Connect(function()
                if inp.UserInputState==Enum.UserInputState.End then
                    if inp==dragInput then
                        dragging=false; dragInput=nil; dragIsMouse=false
                        if State then State.isFrameDragging=false end
                    end
                end
            end)
        end
    end)
    local function onMove(inp)
        if not dragging then return end
        local valid = (inp==dragInput) or
                      (dragIsMouse and inp.UserInputType==Enum.UserInputType.MouseMovement)
        if valid then
            local d=inp.Position-dStart
            local vp=workspace.CurrentCamera.ViewportSize
            local absW=target.AbsoluteSize.X
            local absH=target.AbsoluteSize.Y
            local rawX=dPos.X.Scale*vp.X+dPos.X.Offset+d.X
            local rawY=dPos.Y.Scale*vp.Y+dPos.Y.Offset+d.Y
            local clampedX=math.clamp(rawX,0,math.max(0,vp.X-absW))
            local clampedY=math.clamp(rawY,0,math.max(0,vp.Y-absH))
            target.Position=UDim2.new(0,clampedX,0,clampedY)
        end
    end
    handle.InputChanged:Connect(onMove)
    UIS.InputChanged:Connect(onMove)
    UIS.InputEnded:Connect(function(inp)
        if inp==dragInput or (dragIsMouse and inp.UserInputType==Enum.UserInputType.MouseButton1) then
            dragging=false; dragInput=nil; dragIsMouse=false
            if State then State.isFrameDragging=false end
        end
    end)
end

local Toast = {}
Toast._container = nil
Toast.muted = false  -- set to true while record mode is active to suppress all toasts

local TOAST_TYPES = {
    info    = { icon = "i",  color = Color3.fromRGB(155,80,255),   bg = Color3.fromRGB(28,16,60)  },
    success = { icon = "+",  color = Color3.fromRGB(80,220,150),   bg = Color3.fromRGB(16,48,32)  },
    warning = { icon = "!",  color = Color3.fromRGB(255,195,60),   bg = Color3.fromRGB(50,36,10)  },
    error   = { icon = "X",  color = Color3.fromRGB(240,70,110),   bg = Color3.fromRGB(50,14,24)  },
    fav     = { icon = "*",  color = Color3.fromRGB(255,200,60),   bg = Color3.fromRGB(50,35,8)   },
    loop    = { icon = ">>", color = Color3.fromRGB(240,175,45),   bg = Color3.fromRGB(72,48,10)  },
    rec     = { icon = "o",  color = Color3.fromRGB(240,70,110),   bg = Color3.fromRGB(50,14,24)  },
}

function Toast.init(parentGui)
    Toast._container = Instance.new("Frame", parentGui)
    Toast._container.Name = "ToastContainer"
    Toast._container.Size = UDim2.new(0, Scale.px(240), 1, 0)
    Toast._container.Position = UDim2.new(1, -Scale.px(248), 0, 0)
    Toast._container.BackgroundTransparency = 1
    Toast._container.BorderSizePixel = 0
    Toast._container.ZIndex = 100
    local layout = Instance.new("UIListLayout", Toast._container)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, Scale.px(6))
    local pad = Instance.new("UIPadding", Toast._container)
    pad.PaddingBottom = UDim.new(0, Scale.px(12))
    pad.PaddingRight = UDim.new(0, Scale.px(6))
end

function Toast.show(message, toastType, duration)
    if Toast.muted then return end  -- silenced while record mode is active
    toastType = toastType or "info"
    duration  = duration  or 2.5
    local style = TOAST_TYPES[toastType] or TOAST_TYPES.info
    task.spawn(function()
        local c = Toast._container
        if not c then return end
        local card = Instance.new("Frame", c)
        card.Name = "Toast"
        card.Size = UDim2.new(1, 0, 0, Scale.px(44))
        card.BackgroundColor3 = style.bg
        card.BorderSizePixel = 0
        card.BackgroundTransparency = 1
        card.ZIndex = 101
        card.LayoutOrder = -math.floor(tick() * 1000)
        local corner = Instance.new("UICorner", card)
        corner.CornerRadius = UDim.new(0, Scale.px(10))
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = style.color; stroke.Thickness = 1; stroke.Transparency = 0.4
        local accent = Instance.new("Frame", card)
        accent.Size = UDim2.new(0, Scale.px(3), 1, -Scale.px(10))
        accent.Position = UDim2.new(0, Scale.px(6), 0, Scale.px(5))
        accent.BackgroundColor3 = style.color
        accent.BorderSizePixel = 0; accent.ZIndex = 102
        local ac = Instance.new("UICorner", accent); ac.CornerRadius = UDim.new(0, Scale.px(2))
        local icon = Instance.new("TextLabel", card)
        icon.Size = UDim2.new(0, Scale.px(20), 1, 0)
        icon.Position = UDim2.new(0, Scale.px(14), 0, 0)
        icon.BackgroundTransparency = 1
        icon.Text = style.icon
        icon.TextColor3 = style.color
        icon.Font = Enum.Font.BuilderSansBold
        icon.TextSize = Scale.fs(15)
        icon.ZIndex = 102
        local lbl = Instance.new("TextLabel", card)
        lbl.Size = UDim2.new(1, -Scale.px(42), 1, 0)
        lbl.Position = UDim2.new(0, Scale.px(38), 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = message
        lbl.TextColor3 = Color3.fromRGB(230,215,255)
        lbl.Font = Enum.Font.BuilderSans
        lbl.TextSize = Scale.fs(12)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.ZIndex = 102
        local progBg = Instance.new("Frame", card)
        progBg.Size = UDim2.new(1, -Scale.px(12), 0, Scale.px(2))
        progBg.Position = UDim2.new(0, Scale.px(6), 1, -Scale.px(4))
        progBg.BackgroundColor3 = style.color
        progBg.BackgroundTransparency = 0.7
        progBg.BorderSizePixel = 0; progBg.ZIndex = 102
        local pc2 = Instance.new("UICorner", progBg); pc2.CornerRadius = UDim.new(0, Scale.px(1))
        local progFill2 = Instance.new("Frame", progBg)
        progFill2.Size = UDim2.new(1, 0, 1, 0)
        progFill2.BackgroundColor3 = style.color
        progFill2.BorderSizePixel = 0; progFill2.ZIndex = 103
        local pc3 = Instance.new("UICorner", progFill2); pc3.CornerRadius = UDim.new(0, Scale.px(1))
        TweenS:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0 }):Play()
        TweenS:Create(progFill2, TweenInfo.new(duration, Enum.EasingStyle.Linear),
            { Size = UDim2.new(0, 0, 1, 0) }):Play()
        task.wait(duration)
        TweenS:Create(card,  TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
        TweenS:Create(lbl,   TweenInfo.new(0.3, Enum.EasingStyle.Quad), { TextTransparency = 1 }):Play()
        TweenS:Create(icon,  TweenInfo.new(0.3, Enum.EasingStyle.Quad), { TextTransparency = 1 }):Play()
        task.wait(0.32)
        card:Destroy()
    end)
end

-- ── Silent local decal cache (only IMG leaks to outer scope) ─────────────────
local IMG do
    local D = "RoMidiDecals"
    local ASSETS = {
        { file = "play.png",     url = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/Decals/play.png"     },
        { file = "pause.png",    url = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/Decals/pause.png"    },
        { file = "stop.png",     url = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/Decals/stop.png"     },
        { file = "loop.png",     url = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/Decals/loop.png"     },
        { file = "settings.png", url = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/Decals/settings.png" },
        { file = "folder.png",   url = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/Decals/folder.png"   },
    }
    if not isfolder(D) then pcall(makefolder, D) end
    for _, a in ipairs(ASSETS) do
        local p = D .. "/" .. a.file
        if not isfile(p) then
            local ok, data = pcall(game.HttpGet, game, a.url)
            if ok and data and #data > 0 then pcall(writefile, p, data) end
        end
    end
    local function res(f)
        local path = D .. "/" .. f
        if not isfile(path) then return "" end
        local ok, r = pcall(getcustomasset, path)
        return (ok and r and r ~= "") and r or ""
    end
    IMG = {
        play     = res("play.png"),
        pause    = res("pause.png"),
        stop     = res("stop.png"),
        loopOff  = res("loop.png"),
        loopOn   = res("loop.png"),
        settings = res("settings.png"),
        folder   = res("folder.png"),
    }
end
local LABEL = {
    play="PLAY", pause="PAUSE", stop="STOP", loopOff="LOOP", loopOn="LOOP ON",
}

local BtnStore = {}

function UI.imgBtn(parent, props, imgId, fallbackText, imgSize)
    imgSize = imgSize or 0.60
    local b = UI.btn(parent, props)
    b.Text = ""; b.ClipsDescendants = true

    local img = Instance.new("ImageLabel", b)
    img.BackgroundTransparency = 1
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Position = UDim2.new(0.5, 0, 0.5, 0)
    img.Size = UDim2.new(imgSize, 0, imgSize, 0)
    img.SizeConstraint = Enum.SizeConstraint.RelativeYY
    img.Image = imgId or ""
    img.ImageColor3 = props.TextColor3 or T.white
    img.ZIndex = (props.ZIndex or 1) + 1
    img.ScaleType = Enum.ScaleType.Fit

    local lbl = Instance.new("TextLabel", b)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Text = fallbackText or ""
    lbl.TextColor3 = props.TextColor3 or T.white
    lbl.Font = Enum.Font.BuilderSansBold
    lbl.TextSize = props.TextSize or Scale.fs(13)
    lbl.TextScaled = false
    lbl.ZIndex = (props.ZIndex or 1) + 1

    local function showImage()
        img.Visible = img.Image ~= ""
        lbl.Visible = img.Image == ""
    end
    task.spawn(function()
        for _, t in ipairs({0, 0.05, 0.2, 0.5, 1.0, 2.0}) do
            task.wait(t)
            if img.IsLoaded then showImage(); return end
        end
        showImage()  -- force after 2s regardless
    end)
    img:GetPropertyChangedSignal("IsLoaded"):Connect(showImage)

    BtnStore[b] = {img=img, lbl=lbl}
    return b
end

local function refreshBtnVis(b)
    local s = BtnStore[b]; if not s then return end
    s.img.Visible = s.img.Image ~= ""
    s.lbl.Visible = s.img.Image == ""
end
local function setBtnImage(b, imgId)
    local s = BtnStore[b]; if not s then return end
    if not imgId or imgId == "" then          -- nil / empty → show text label
        s.img.Image = ""; s.img.Visible = false; s.lbl.Visible = true; return
    end
    if s.img.Image == imgId then return end
    s.img.Image = imgId
    if imgId == "" then
        s.img.Visible = false; s.lbl.Visible = true; return
    end
    s.img.Visible = true; s.lbl.Visible = false
    task.spawn(function()
        local id = imgId
        for _, t in ipairs({0, 0.05, 0.2, 0.5, 1.0, 2.0}) do
            task.wait(t)
            if s.img.Image ~= id then return end
            if s.img.IsLoaded then
                s.img.Visible = true; s.lbl.Visible = false; return
            end
        end
        if s.img.Image == id then s.img.Visible=true; s.lbl.Visible=false end
    end)
end
local function setBtnLabel(b, text, col)
    local s = BtnStore[b]; if not s then return end
    s.lbl.Text = text
    if col then s.lbl.TextColor3 = col end
    refreshBtnVis(b)
end
local function setBtnImgColor(b, col)
    local s = BtnStore[b]; if s then s.img.ImageColor3 = col end
end

local AsciiKeys = {
    ['a'] = Enum.KeyCode.A, ['b'] = Enum.KeyCode.B, ['c'] = Enum.KeyCode.C,
    ['d'] = Enum.KeyCode.D, ['e'] = Enum.KeyCode.E, ['f'] = Enum.KeyCode.F,
    ['g'] = Enum.KeyCode.G, ['h'] = Enum.KeyCode.H, ['i'] = Enum.KeyCode.I,
    ['j'] = Enum.KeyCode.J, ['k'] = Enum.KeyCode.K, ['l'] = Enum.KeyCode.L,
    ['m'] = Enum.KeyCode.M, ['n'] = Enum.KeyCode.N, ['o'] = Enum.KeyCode.O,
    ['p'] = Enum.KeyCode.P, ['q'] = Enum.KeyCode.Q, ['r'] = Enum.KeyCode.R,
    ['s'] = Enum.KeyCode.S, ['t'] = Enum.KeyCode.T, ['u'] = Enum.KeyCode.U,
    ['v'] = Enum.KeyCode.V, ['w'] = Enum.KeyCode.W, ['x'] = Enum.KeyCode.X,
    ['y'] = Enum.KeyCode.Y, ['z'] = Enum.KeyCode.Z,

    ['0'] = Enum.KeyCode.Zero, ['1'] = Enum.KeyCode.One, ['2'] = Enum.KeyCode.Two,
    ['3'] = Enum.KeyCode.Three, ['4'] = Enum.KeyCode.Four, ['5'] = Enum.KeyCode.Five,
    ['6'] = Enum.KeyCode.Six, ['7'] = Enum.KeyCode.Seven, ['8'] = Enum.KeyCode.Eight,
    ['9'] = Enum.KeyCode.Nine,
}

local SymbolKeyCodes = {
    ["!"] = Enum.KeyCode.One, ["@"] = Enum.KeyCode.Two, ["#"] = Enum.KeyCode.Three,
    ["$"] = Enum.KeyCode.Four, ["%"] = Enum.KeyCode.Five, ["^"] = Enum.KeyCode.Six,
    ["&"] = Enum.KeyCode.Seven, ["*"] = Enum.KeyCode.Eight, ["("] = Enum.KeyCode.Nine,
    [")"] = Enum.KeyCode.Zero,
}

local shiftKey = Enum.KeyCode.LeftShift
local ctrlKey  = Enum.KeyCode.LeftControl

-- MIDI → {KeyCode, needsShift} for guitar mode.
-- One key per note, chromatic from E2 (40) to E5 (76).
local GUITAR_KEY_MAP = {
    [40]={Enum.KeyCode.Z,            false}, -- E2
    [41]={Enum.KeyCode.X,            false}, -- F2
    [42]={Enum.KeyCode.C,            false}, -- F#2
    [43]={Enum.KeyCode.V,            false}, -- G2
    [44]={Enum.KeyCode.B,            false}, -- G#2
    [45]={Enum.KeyCode.A,            false}, -- A2
    [46]={Enum.KeyCode.S,            false}, -- A#2
    [47]={Enum.KeyCode.D,            false}, -- B2
    [48]={Enum.KeyCode.F,            false}, -- C3
    [49]={Enum.KeyCode.G,            false}, -- C#3
    [50]={Enum.KeyCode.H,            false}, -- D3
    [51]={Enum.KeyCode.J,            false}, -- D#3
    [52]={Enum.KeyCode.K,            false}, -- E3
    [53]={Enum.KeyCode.L,            false}, -- F3
    [54]={Enum.KeyCode.Semicolon,    false}, -- F#3
    [55]={Enum.KeyCode.Quote,        false}, -- G3
    [56]={Enum.KeyCode.U,            false}, -- G#3
    [57]={Enum.KeyCode.I,            false}, -- A3
    [58]={Enum.KeyCode.O,            false}, -- A#3
    [59]={Enum.KeyCode.P,            false}, -- B3
    [60]={Enum.KeyCode.LeftBracket,  false}, -- C4
    [61]={Enum.KeyCode.RightBracket, false}, -- C#4
    [62]={Enum.KeyCode.BackSlash,    false}, -- D4
    [63]={Enum.KeyCode.Eight,        false}, -- D#4
    [64]={Enum.KeyCode.Nine,         false}, -- E4
    [65]={Enum.KeyCode.Zero,         false}, -- F4
    [66]={Enum.KeyCode.Minus,        false}, -- F#4
    [67]={Enum.KeyCode.Equals,       false}, -- G4
    [68]={Enum.KeyCode.P,            true }, -- G#4  Shift+P
    [69]={Enum.KeyCode.LeftBracket,  true }, -- A4   Shift+[
    [70]={Enum.KeyCode.RightBracket, true }, -- A#4  Shift+]
    [71]={Enum.KeyCode.BackSlash,    true }, -- B4   Shift+\
    [72]={Enum.KeyCode.Eight,        true }, -- C5   Shift+8
    [73]={Enum.KeyCode.Nine,         true }, -- C#5  Shift+9
    [74]={Enum.KeyCode.Zero,         true }, -- D5   Shift+0
    [75]={Enum.KeyCode.Minus,        true }, -- D#5  Shift+-
    [76]={Enum.KeyCode.Equals,       true }, -- E5   Shift+=
}

local Keys88Mode = false

local MIDI_88_EXT = {}
do
    local lowerKeys = {"1","2","3","4","5","6","7","8","9","0","q","w","e","r","t"}
    for i, n in ipairs(lowerKeys) do MIDI_88_EXT[20 + i] = "ctrl+" .. n end
    local upperKeys = {"y","u","i","o","p","a","s","d","f","g","h","j"}
    for i, n in ipairs(upperKeys) do MIDI_88_EXT[96 + i] = "ctrl+" .. n end
end

local MidiProcessor = {}
MidiProcessor.__index = MidiProcessor

function MidiProcessor.new()
    local self = setmetatable({}, MidiProcessor)
    self.virtualPianoScale = {
        "1","!","2","@","3","4","$","5","%","6","^","7","8","*","9","(","0",
        "q","Q","w","W","e","E","r","t","T","y","Y","u","i","I","o","O","p","P",
        "a","s","S","d","D","f","g","G","h","H","j","J","k","l","L",
        "z","Z","x","c","C","v","V","b","B","n","m"
    }
    self.VPS_BASE     = 36   -- MIDI note number for virtualPianoScale[1]
    self.notes        = {}
    self.keyPressCount = 0
    self.tempo        = 120  -- BPM of the last tempo event seen
    self.division     = 480
    return self
end

function MidiProcessor:_midiToChar(key)
    if Keys88Mode then
        local ext = MIDI_88_EXT[key]
        if ext then return ext end
        if key >= self.VPS_BASE and key < self.VPS_BASE + #self.virtualPianoScale then
            return self.virtualPianoScale[key - self.VPS_BASE + 1]
        end
    end
    local m = key - self.VPS_BASE
    while m >= #self.virtualPianoScale do m = m - 12 end
    while m < 0                        do m = m + 12 end
    return self.virtualPianoScale[m + 1]
end

function MidiProcessor:_parseMidi(bytes)
    local pos = 1

    local function eof()    return pos > #bytes end
    local function rb()     local b = bytes[pos]; pos = pos + 1; return b end
    local function readInt(n)
        local v = 0
        for _ = 1, n do
            if pos > #bytes then return v end
            v = bit32.bor(bit32.lshift(v, 8), rb())
        end
        return v
    end
    local function readVLQ()
        local v = 0
        repeat
            if eof() then return v end
            local b = rb()
            v = bit32.bor(bit32.lshift(v, 7), bit32.band(b, 0x7F))
            if bit32.band(b, 0x80) == 0 then break end
        until false
        return v
    end
    local function peek4(a, b, c, d)
        if pos + 3 > #bytes then return false end
        return bytes[pos] == a and bytes[pos+1] == b
            and bytes[pos+2] == c and bytes[pos+3] == d
    end

    if #bytes < 14 then return nil, "too short" end

    if not peek4(0x4D, 0x54, 0x68, 0x64) then return nil, "no MThd" end
    pos = pos + 4

    local hlen    = readInt(4)
    local _format = readInt(2)
    local ntracks = readInt(2)
    local divraw  = readInt(2)
    pos = pos + (hlen - 6)   -- skip any extra header bytes

    if bit32.band(divraw, 0x8000) ~= 0 then
        return nil, "SMPTE division not supported"
    end
    local division = divraw

    local allEvents    = {}
    local initialTempo = 500000   -- default 120 BPM
    local midiMinKey   = 127
    local midiMaxKey   = 0

    for _ = 1, ntracks do
        while not eof() do
            if peek4(0x4D, 0x54, 0x72, 0x6B) then break end
            pos = pos + 1
        end
        if eof() then break end
        pos = pos + 4   -- skip "MTrk"

        local chunkLen = readInt(4)
        local chunkEnd = pos + chunkLen
        local absT     = 0
        local running  = -1

        while pos < chunkEnd and not eof() do
            absT = absT + readVLQ()
            if eof() or pos > chunkEnd then break end

            local sb = bytes[pos]

            if sb == 0xFF then
                pos = pos + 1
                if eof() then break end
                local mtype = rb()
                local mlen  = readVLQ()
                if mtype == 0x51 and mlen == 3 then
                    local t = bit32.bor(
                        bit32.bor(bit32.lshift(rb(), 16), bit32.lshift(rb(), 8)), rb())
                    initialTempo = t
                    local bpm = math.floor(60000000 / t + 0.5)
                    table.insert(allEvents, {tick = absT, type = "tempo", bpm = bpm, tempo_us = t})
                else
                    pos = pos + mlen
                    if mtype == 0x2F then break end   -- End of Track
                end

            elseif sb == 0xF0 or sb == 0xF7 then
                pos     = pos + 1
                local slen = readVLQ()
                pos     = pos + slen
                running = -1

            else
                local status
                if sb >= 0x80 then
                    status  = rb(); running = status
                else
                    status  = running   -- running status
                end
                if status >= 0 then
                    local hi = bit32.band(bit32.rshift(status, 4), 0xF)
                    if hi == 0x8 or hi == 0x9 or hi == 0xA or hi == 0xB or hi == 0xE then
                        local d1 = rb(); local d2 = rb()
                        if hi == 0x9 and d2 > 0 then
                            if d1 < midiMinKey then midiMinKey = d1 end
                            if d1 > midiMaxKey then midiMaxKey = d1 end
                            table.insert(allEvents, {tick = absT, type = "on",  key = d1})
                        elseif hi == 0x8 or (hi == 0x9 and d2 == 0) then
                            table.insert(allEvents, {tick = absT, type = "off", key = d1})
                        end
                    elseif hi == 0xC or hi == 0xD then
                        rb()   -- Program Change / Channel Pressure (1 data byte)
                    else
                        if pos < chunkEnd then rb() end
                    end
                else
                    if pos < chunkEnd then pos = pos + 1 end
                end
            end
        end

        pos = chunkEnd   -- always land exactly at chunk end
    end

    local _typeOrder = {tempo=0, off=1, on=2}
    table.sort(allEvents, function(a, b)
        if a.tick ~= b.tick then return a.tick < b.tick end
        return (_typeOrder[a.type] or 3) < (_typeOrder[b.type] or 3)
    end)

    return allEvents, division, initialTempo, midiMinKey, midiMaxKey
end

function MidiProcessor:_buildNotes(allEvents, division, initialTempo)
    self.notes         = {}
    self.keyPressCount = 0
    self.division      = division
    self.tempo         = math.floor(60000000 / initialTempo + 0.5)

    local currentTempo_us = initialTempo   -- microseconds per beat
    local lastTick        = 0
    local currentMs       = 0.0           -- accumulated milliseconds

    for _, ev in ipairs(allEvents) do
        local deltaTicks = ev.tick - lastTick
        currentMs  = currentMs + (deltaTicks / division) * (currentTempo_us / 1000.0)
        lastTick   = ev.tick

        local ms       = math.floor(currentMs + 0.5)   -- rounded integer ms
        local beatTime = ev.tick / division             -- beat position

        if ev.type == "tempo" then
            currentTempo_us = ev.tempo_us or math.floor(60000000 / ev.bpm + 0.5)
            table.insert(self.notes, {
                time      = ms,
                tempo     = "tempo=" .. ev.bpm,
                notestate = "",
                _beat     = beatTime,
            })

        elseif ev.type == "on" then
            local ch = self:_midiToChar(ev.key)
            table.insert(self.notes, {
                time      = ms,
                key       = ch,
                notestate = "down",
                _beat     = beatTime,
                _midi     = ev.key,  -- raw MIDI note number; used by hand-split filter
            })
            self.keyPressCount = self.keyPressCount + 1

        elseif ev.type == "off" then
            local ch = self:_midiToChar(ev.key)
            table.insert(self.notes, {
                time      = ms,
                key       = ch,
                notestate = "up",
                _beat     = beatTime,
                _midi     = ev.key,  -- raw MIDI note number; used by hand-split filter
            })
        end
    end

end

function MidiProcessor:processMidiBytes(bytes)
    local allEvents, division, initialTempo = self:_parseMidi(bytes)
    if not allEvents then
        self.notes = {}; self.keyPressCount = 0
        return {notes = self.notes, keyPressCount = 0}
    end
    self:_buildNotes(allEvents, division, initialTempo)
    return {notes = self.notes, keyPressCount = self.keyPressCount}
end

function MidiProcessor:processMidiBytesWithChords(bytes, chordWindow, detectChords)
    detectChords = detectChords or false
    chordWindow  = chordWindow  or 0.05
    local allEvents, division, initialTempo = self:_parseMidi(bytes)
    if not allEvents then
        self.notes = {}; self.keyPressCount = 0
        return {notes = self.notes, keyPressCount = 0}
    end
    self:_buildNotes(allEvents, division, initialTempo)
    if detectChords then self:detectChords(chordWindow) end
    return {notes = self.notes, keyPressCount = self.keyPressCount}
end

function MidiProcessor:fixSustain()
    table.sort(self.notes, function(a, b) return a._beat < b._beat end)
    local activeNotes    = {}
    local validatedNotes = {}
    for _, note in ipairs(self.notes) do
        if note.tempo and note.tempo ~= "" then
            table.insert(validatedNotes, note)
        elseif note.notestate == "up" then
            local nk = note.key
            if activeNotes[nk] and activeNotes[nk] > 0 then
                activeNotes[nk] = activeNotes[nk] - 1
                if activeNotes[nk] == 0 then activeNotes[nk] = nil end
                table.insert(validatedNotes, note)
            end
        elseif note.notestate == "down" then
            local nk = note.key
            activeNotes[nk] = (activeNotes[nk] or 0) + 1
            table.insert(validatedNotes, note)
        else
            local noteData = note.keys or note[2] or ""
            if noteData:find("tempo") then
                table.insert(validatedNotes, note)
            elseif noteData:sub(1,1) == "~" then
                local noteKey = noteData:sub(2)
                if activeNotes[noteKey] and activeNotes[noteKey] > 0 then
                    activeNotes[noteKey] = activeNotes[noteKey] - 1
                    if activeNotes[noteKey] == 0 then activeNotes[noteKey] = nil end
                    table.insert(validatedNotes, note)
                end
            else
                for i = 1, #noteData do
                    local nk = noteData:sub(i, i)
                    activeNotes[nk] = (activeNotes[nk] or 0) + 1
                end
                table.insert(validatedNotes, note)
            end
        end
    end
    self.notes = validatedNotes
end

function MidiProcessor:detectChords(chordWindow)
    chordWindow = chordWindow or 0.05
    local groupedNotes  = {}
    local currentGroup  = {}
    local groupStartBeat = nil
    for _, note in ipairs(self.notes) do
        local beat     = note._beat or 0
        local isTempo  = (note.tempo and note.tempo ~= "")
        local isNoteOn = (note.notestate == "down")
        if isNoteOn then
            if #currentGroup == 0 then
                groupStartBeat = beat
                table.insert(currentGroup, note)
            elseif beat - groupStartBeat <= chordWindow then
                table.insert(currentGroup, note)
            else
                if #currentGroup == 1 then
                    table.insert(groupedNotes, currentGroup[1])
                else
                    local chordKeys = ""
                    for _, cn in ipairs(currentGroup) do chordKeys = chordKeys .. (cn.key or "") end
                    table.insert(groupedNotes, {
                        time      = currentGroup[1].time,
                        key       = self:removeDuplicateChars(chordKeys),
                        notestate = "down",
                        _beat     = groupStartBeat,
                    })
                end
                currentGroup   = {note}
                groupStartBeat = beat
            end
        else
            if #currentGroup > 0 then
                if #currentGroup == 1 then
                    table.insert(groupedNotes, currentGroup[1])
                else
                    local chordKeys = ""
                    for _, cn in ipairs(currentGroup) do chordKeys = chordKeys .. (cn.key or "") end
                    table.insert(groupedNotes, {
                        time      = currentGroup[1].time,
                        key       = self:removeDuplicateChars(chordKeys),
                        notestate = "down",
                        _beat     = groupStartBeat,
                    })
                end
                currentGroup = {}
            end
            table.insert(groupedNotes, note)
        end
    end
    if #currentGroup > 0 then
        if #currentGroup == 1 then
            table.insert(groupedNotes, currentGroup[1])
        else
            local chordKeys = ""
            for _, cn in ipairs(currentGroup) do chordKeys = chordKeys .. (cn.key or "") end
            table.insert(groupedNotes, {
                time      = currentGroup[1].time,
                key       = self:removeDuplicateChars(chordKeys),
                notestate = "down",
                _beat     = groupStartBeat,
            })
        end
    end
    self.notes = groupedNotes
end

function MidiProcessor:removeDuplicateChars(str)
    local seen, result = {}, ""
    for i = 1, #str do
        local c = string.sub(str, i, i)
        if not seen[c] then seen[c] = true; result = result .. c end
    end
    return result
end

function MidiProcessor:getRawNoteRange(bytes)
    local allEvents, _, _, minKey, maxKey = self:_parseMidi(bytes)
    if not allEvents or minKey > maxKey then return nil, nil end
    return minKey, maxKey
end

-- ── GuitarMidiProcessor ────────────────────────────────────────────────────
-- Dedicated MIDI processor for guitar mode.  Shares the raw MIDI parser from
-- MidiProcessor via __index inheritance but owns its own note-building logic:
-- every MIDI note is transposed into the GUITAR_KEY_MAP range (40–76) and
-- encoded as a "__gkNN" token that pressGuitarKey / releaseGuitarKey decode.
local GuitarMidiProcessor = setmetatable({}, {__index = MidiProcessor})
GuitarMidiProcessor.__index = GuitarMidiProcessor

function GuitarMidiProcessor.new()
    local self = setmetatable({}, GuitarMidiProcessor)
    self.notes         = {}
    self.keyPressCount = 0
    self.tempo         = 120
    self.division      = 480
    return self
end

-- Transpose midi into the fretboard range and return the "__gkNN" token.
function GuitarMidiProcessor:_midiToGuitarKey(midi)
    while midi < 40 do midi = midi + 12 end
    while midi > 76 do midi = midi - 12 end
    return "__gk" .. midi
end

-- Guitar-specific note builder (overrides MidiProcessor:_buildNotes).
function GuitarMidiProcessor:_buildNotes(allEvents, division, initialTempo)
    self.notes         = {}
    self.keyPressCount = 0
    self.division      = division
    self.tempo         = math.floor(60000000 / initialTempo + 0.5)

    local currentTempo_us = initialTempo
    local lastTick        = 0
    local currentMs       = 0.0

    for _, ev in ipairs(allEvents) do
        local deltaTicks = ev.tick - lastTick
        currentMs  = currentMs + (deltaTicks / division) * (currentTempo_us / 1000.0)
        lastTick   = ev.tick

        local ms       = math.floor(currentMs + 0.5)
        local beatTime = ev.tick / division

        if ev.type == "tempo" then
            currentTempo_us = ev.tempo_us or math.floor(60000000 / ev.bpm + 0.5)
            table.insert(self.notes, {
                time      = ms,
                tempo     = "tempo=" .. ev.bpm,
                notestate = "",
                _beat     = beatTime,
            })
        elseif ev.type == "on" then
            local ch = self:_midiToGuitarKey(ev.key)
            table.insert(self.notes, {
                time      = ms,
                key       = ch,
                notestate = "down",
                _beat     = beatTime,
            })
            self.keyPressCount = self.keyPressCount + 1
        elseif ev.type == "off" then
            local ch = self:_midiToGuitarKey(ev.key)
            table.insert(self.notes, {
                time      = ms,
                key       = ch,
                notestate = "up",
                _beat     = beatTime,
            })
        end
    end
end

function GuitarMidiProcessor:processMidiBytes(bytes)
    local allEvents, division, initialTempo = self:_parseMidi(bytes)
    if not allEvents then
        self.notes = {}; self.keyPressCount = 0
        return {notes = self.notes, keyPressCount = 0}
    end
    self:_buildNotes(allEvents, division, initialTempo)
    return {notes = self.notes, keyPressCount = self.keyPressCount}
end
-- ── end GuitarMidiProcessor ────────────────────────────────────────────────

local Config = {
    PRESET_URL = "https://github.com/wownskdo/TestForApi/raw/refs/heads/main/Main/Presets/",
    RETURN_URL = "https://github.com/wownskdo/TestForApi/raw/refs/heads/main/Main/returntables/",
    UPLOADED_RETURN_URL = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/UploadedMidi/uploadreturn/",
    UPLOADED_PRESET_URL = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/UploadedMidi/",
    UPLOADED_CATEGORIES = {
        {name="Anime",     file="Animereturn.lua"},
        {name="Classical", file="Classicalreturn.lua"},
        {name="Emotional", file="Emotionalreturn.lua"},
        {name="Game OST",  file="GameOSTreturn.lua",  folder="GameOST"},  -- GitHub folder has no space
        {name="Modern",    file="Modernreturn.lua"},
        {name="Movie",     file="Moviereturn.lua"},
        {name="Others",    file="Othersreturn.lua"},
    },
    CATEGORIES = {
        {name="Classical",  file="classicalreturn.lua"},
        {name="Modern",     file="modernreturn.lua"},
        {name="Anime",      file="animereturn.lua"},
        {name="Movie",      file="moviereturn.lua"},
        {name="Emotional",  file="emotionalreturn.lua"},
        {name="Game OST",   file="gameostreturn.lua",  folder="Game OST"},  -- GitHub folder has a space (Game%20OST)
        {name="Others",     file="othersreturn.lua"},
    },
    DRUM_PRESET_URL = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/DrumPresets/",
    DRUM_RETURN_URL = "https://github.com/VBfHKC86WxpXyIgr/RoMidi/raw/refs/heads/main/DrumPresets/returnfiles/",
    DRUM_CATEGORIES = {
        {name="Anime",  file="Animereturn.lua"},
        {name="Modern", file="Modernreturn.lua"},
        {name="Movie",  file="Moviereturn.lua"},
        {name="Others", file="Othersreturn.lua"},
        {name="Rock",   file="Rockreturn.lua"},
    },
    DRUM_UPLOADED_BASE_URL   = "https://raw.githubusercontent.com/VBfHKC86WxpXyIgr/RoMidi/main/Uploaded%20Drums/",
    DRUM_UPLOADED_RETURN_URL = "https://raw.githubusercontent.com/VBfHKC86WxpXyIgr/RoMidi/main/Uploaded%20Drums/returnfiles/",
    -- ── Guitar ──────────────────────────────────────────────────
    GUITAR_PRESET_URL    = "https://raw.githubusercontent.com/VBfHKC86WxpXyIgr/RoMidi/main/GuitarPresets/",
    GUITAR_RETURN_URL    = "https://raw.githubusercontent.com/VBfHKC86WxpXyIgr/RoMidi/main/GuitarPresets/returnfiles/",
    GUITAR_CATEGORIES    = {
        {name="Acoustic",    file="Acousticreturn.lua"},
        {name="Alternative", file="Alternativereturn.lua"},
        {name="Anime",       file="Animereturn.lua"},
        {name="Bluegrass",   file="Bluegrassreturn.lua"},
        {name="Blues",       file="Bluesreturn.lua"},
        {name="Classic Rock",file="ClassicRockreturn.lua"},
        {name="Classical",   file="Classicalreturn.lua"},
        {name="Country",     file="Countryreturn.lua"},
        {name="Fingerstyle", file="Fingerstylereturn.lua"},
        {name="Flamenco",    file="Flamencoreturn.lua"},
        {name="Folk",        file="Folkreturn.lua"},
        {name="Funk",        file="Funkreturn.lua"},
        {name="Indie",       file="Indiereturn.lua"},
        {name="Jazz",        file="Jazzreturn.lua"},
        {name="Latin",       file="Latinreturn.lua"},
        {name="Memes",       file="Memesreturn.lua"},
        {name="Metal",       file="Metalreturn.lua"},
        {name="Nu-Metal",    file="Nu-Metalreturn.lua"},
        {name="OST",         file="OSTreturn.lua"},
        {name="Pop",         file="Popreturn.lua"},
        {name="Progressive", file="Progressivereturn.lua"},
        {name="Punk",        file="Punkreturn.lua"},
        {name="Reggae",      file="Reggaereturn.lua"},
        {name="Rock",        file="Rockreturn.lua"},
        {name="Ska",         file="Skareturn.lua"},
        {name="Soul",        file="Soulreturn.lua"},
    },
    GUITAR_UPLOADED_BASE_URL   = "https://raw.githubusercontent.com/VBfHKC86WxpXyIgr/RoMidi/main/Uploaded%20Guitars/",
    GUITAR_UPLOADED_RETURN_URL = "https://raw.githubusercontent.com/VBfHKC86WxpXyIgr/RoMidi/main/Uploaded%20Guitars/returnfiles/",
}

local function catFolder(catName, catList)
    for _, c in ipairs(catList) do
        if c.name == catName then return c.folder or catName end
    end
    return catName
end

local State = {
    loopMode=false, floatMode=false, usetempo=true,
    manualBpm=120, currentBpm=120, lastManualBpm=120, originalBpm=120,
    songTime=0, songDuration=0, beatPos=0, noteIndex=1,
    notes={}, tempoMarkers={}, heldKeys={}, seekReq=false,
    isDragging=false, isFrameDragging=false, songChanged=false,
    seekLocked=false,  -- true = progress bar drag is locked (lock button)
    progressConn=nil, rightVisible=false,
    recordMode=false, recCounting=false, recHidden=false,
    recDelay=5,           -- seconds to wait before playback starts in record mode
    recCountdownVisible=true, -- show countdown overlay during the delay
    recAutoRestore=true,  -- restore UI automatically when song ends in record mode
    loading=false,  -- true while a song's MIDI bytes are being fetched; blocks play
    drumMode=false, -- true when drum instrument is selected
    guitarMode=false, -- true when guitar instrument is selected
    drumBaseDuration=0, -- raw drum duration at 120 BPM; scaled by manualBpm at runtime
    currentRawBytes=nil, -- raw MIDI bytes of the currently loaded song (for 88-key reprocess)
}

local function jsonEncode(t)
    local ok, s = pcall(HttpService.JSONEncode, HttpService, t); return ok and s or nil
end
local function jsonDecode(s)
    local ok, t = pcall(HttpService.JSONDecode, HttpService, s); return ok and t or nil
end

local Humanize = {}
Humanize.piano = {
    all            = false,
    simulateHands  = false,
    chordRoll      = false,
    varyTiming     = { on=false, val=0.010 },  -- seconds max offset
    varyArticulation={ on=false, val=0.95 },   -- 0–1 articulation factor
    handDrift      = { on=false, val=0.25 },   -- 0–1 drift intensity
    mistakes       = { on=false, val=0.005 },  -- 0–1 mistake probability
    tempoSway      = { on=false, val=0.015 },  -- seconds sway amount
    invertSway     = false,
    handSplit      = "off",  -- "off" | "left" (bass <60) | "right" (treble >=60)  piano only
}
Humanize.drum = {
    all            = false,
    varyTiming     = { on=false, val=0.010 },
    mistakes       = { on=false, val=0.005 },
    tempoSway      = { on=false, val=0.015 },
    invertSway     = false,
}
Humanize.guitar = {
    all            = false,
    strumSpread    = { on=false, val=0.018 }, -- cascade delay per string in a chord cluster (s)
    fretLag        = { on=false, val=0.008 }, -- fretting-hand lag: always-positive timing push (s)
    mutChance      = { on=false, val=0.004 }, -- string buzz/mute: note fires then cuts immediately
    pickArticul    = { on=false, val=0.90  }, -- pick articulation: shorten hold duration (0–1 factor)
    varyTiming     = { on=false, val=0.010 }, -- pick timing jitter ±(s)
    mistakes       = { on=false, val=0.005 }, -- probability of completely missed pick
    tempoSway      = { on=false, val=0.015 }, -- groove/BPM sway (s)
    invertSway     = false,
}
function Humanize.get()
    if State.drumMode   then return Humanize.drum   end
    if State.guitarMode then return Humanize.guitar end
    return Humanize.piano
end

function Humanize.timingOffset()
    local h = Humanize.get()
    if h.varyTiming.on then
        local v = h.varyTiming.val
        return (math.random()*2-1)*v  -- ±v seconds
    end
    return 0
end

function Humanize.isMistake()
    local h = Humanize.get()
    if h.mistakes.on then return math.random() < h.mistakes.val end
    return false
end

local _swayPhase = 0
function Humanize.swayOffset(dt)
    local h = Humanize.get()
    if h.tempoSway.on then
        _swayPhase = _swayPhase + dt * 0.5
        local s = math.sin(_swayPhase) * h.tempoSway.val
        return h.invertSway and -s or s
    end
    return 0
end

local SETTINGS_FILE = "RoMidi/settings.json"

local HUM_DEFAULTS = {
    piano = {
        all=false, simulateHands=false, chordRoll=false, handSplit="off",
        varyTiming={on=false,val=0.010}, varyArticulation={on=false,val=0.95},
        handDrift={on=false,val=0.25}, mistakes={on=false,val=0.005},
        tempoSway={on=false,val=0.015}, invertSway=false,
    },
    drum = {
        all=false,
        varyTiming={on=false,val=0.010}, mistakes={on=false,val=0.005},
        tempoSway={on=false,val=0.015}, invertSway=false,
    },
    guitar = {
        all=false,
        strumSpread={on=false,val=0.018}, fretLag={on=false,val=0.008},
        mutChance={on=false,val=0.004},   pickArticul={on=false,val=0.90},
        varyTiming={on=false,val=0.010},  mistakes={on=false,val=0.005},
        tempoSway={on=false,val=0.015},   invertSway=false,
    },
}

function Humanize.save()
    pcall(makefolder,"RoMidi")
    local data = {
        piano = {
            all=Humanize.piano.all, simulateHands=Humanize.piano.simulateHands,
            chordRoll=Humanize.piano.chordRoll, invertSway=Humanize.piano.invertSway,
            handSplit=Humanize.piano.handSplit,
            varyTiming={on=Humanize.piano.varyTiming.on,val=Humanize.piano.varyTiming.val},
            varyArticulation={on=Humanize.piano.varyArticulation.on,val=Humanize.piano.varyArticulation.val},
            handDrift={on=Humanize.piano.handDrift.on,val=Humanize.piano.handDrift.val},
            mistakes={on=Humanize.piano.mistakes.on,val=Humanize.piano.mistakes.val},
            tempoSway={on=Humanize.piano.tempoSway.on,val=Humanize.piano.tempoSway.val},
        },
        drum = {
            all=Humanize.drum.all, invertSway=Humanize.drum.invertSway,
            varyTiming={on=Humanize.drum.varyTiming.on,val=Humanize.drum.varyTiming.val},
            mistakes={on=Humanize.drum.mistakes.on,val=Humanize.drum.mistakes.val},
            tempoSway={on=Humanize.drum.tempoSway.on,val=Humanize.drum.tempoSway.val},
        },
        guitar = {
            all=Humanize.guitar.all, invertSway=Humanize.guitar.invertSway,
            strumSpread={on=Humanize.guitar.strumSpread.on,val=Humanize.guitar.strumSpread.val},
            fretLag={on=Humanize.guitar.fretLag.on,val=Humanize.guitar.fretLag.val},
            mutChance={on=Humanize.guitar.mutChance.on,val=Humanize.guitar.mutChance.val},
            pickArticul={on=Humanize.guitar.pickArticul.on,val=Humanize.guitar.pickArticul.val},
            varyTiming={on=Humanize.guitar.varyTiming.on,val=Humanize.guitar.varyTiming.val},
            mistakes={on=Humanize.guitar.mistakes.on,val=Humanize.guitar.mistakes.val},
            tempoSway={on=Humanize.guitar.tempoSway.on,val=Humanize.guitar.tempoSway.val},
        },
    }
    local s = jsonEncode(data)
    if s then pcall(writefile, SETTINGS_FILE, s) end
end

function Humanize.load()
    local ok,raw = pcall(readfile, SETTINGS_FILE)
    if not ok or not raw or raw=="" then return end
    local t = jsonDecode(raw)
    if type(t)~="table" then return end
    local p = t.piano
    if type(p)=="table" then
        if type(p.all)=="boolean" then Humanize.piano.all=p.all end
        if type(p.simulateHands)=="boolean" then Humanize.piano.simulateHands=p.simulateHands end
        if type(p.chordRoll)=="boolean" then Humanize.piano.chordRoll=p.chordRoll end
        if type(p.handSplit)=="string"  then Humanize.piano.handSplit=p.handSplit  end
        if type(p.invertSway)=="boolean" then Humanize.piano.invertSway=p.invertSway end
        if type(p.varyTiming)=="table" then
            if type(p.varyTiming.on)=="boolean" then Humanize.piano.varyTiming.on=p.varyTiming.on end
            if type(p.varyTiming.val)=="number"  then Humanize.piano.varyTiming.val=p.varyTiming.val end
        end
        if type(p.varyArticulation)=="table" then
            if type(p.varyArticulation.on)=="boolean" then Humanize.piano.varyArticulation.on=p.varyArticulation.on end
            if type(p.varyArticulation.val)=="number"  then Humanize.piano.varyArticulation.val=p.varyArticulation.val end
        end
        if type(p.handDrift)=="table" then
            if type(p.handDrift.on)=="boolean" then Humanize.piano.handDrift.on=p.handDrift.on end
            if type(p.handDrift.val)=="number"  then Humanize.piano.handDrift.val=p.handDrift.val end
        end
        if type(p.mistakes)=="table" then
            if type(p.mistakes.on)=="boolean" then Humanize.piano.mistakes.on=p.mistakes.on end
            if type(p.mistakes.val)=="number"  then Humanize.piano.mistakes.val=p.mistakes.val end
        end
        if type(p.tempoSway)=="table" then
            if type(p.tempoSway.on)=="boolean" then Humanize.piano.tempoSway.on=p.tempoSway.on end
            if type(p.tempoSway.val)=="number"  then Humanize.piano.tempoSway.val=p.tempoSway.val end
        end
    end
    local d = t.drum
    if type(d)=="table" then
        if type(d.all)=="boolean" then Humanize.drum.all=d.all end
        if type(d.invertSway)=="boolean" then Humanize.drum.invertSway=d.invertSway end
        if type(d.varyTiming)=="table" then
            if type(d.varyTiming.on)=="boolean" then Humanize.drum.varyTiming.on=d.varyTiming.on end
            if type(d.varyTiming.val)=="number"  then Humanize.drum.varyTiming.val=d.varyTiming.val end
        end
        if type(d.mistakes)=="table" then
            if type(d.mistakes.on)=="boolean" then Humanize.drum.mistakes.on=d.mistakes.on end
            if type(d.mistakes.val)=="number"  then Humanize.drum.mistakes.val=d.mistakes.val end
        end
        if type(d.tempoSway)=="table" then
            if type(d.tempoSway.on)=="boolean" then Humanize.drum.tempoSway.on=d.tempoSway.on end
            if type(d.tempoSway.val)=="number"  then Humanize.drum.tempoSway.val=d.tempoSway.val end
        end
    end
    local g = t.guitar
    if type(g)=="table" then
        if type(g.all)=="boolean"        then Humanize.guitar.all=g.all end
        if type(g.invertSway)=="boolean" then Humanize.guitar.invertSway=g.invertSway end
        if type(g.strumSpread)=="table" then
            if type(g.strumSpread.on)=="boolean" then Humanize.guitar.strumSpread.on=g.strumSpread.on end
            if type(g.strumSpread.val)=="number"  then Humanize.guitar.strumSpread.val=g.strumSpread.val end
        end
        if type(g.fretLag)=="table" then
            if type(g.fretLag.on)=="boolean" then Humanize.guitar.fretLag.on=g.fretLag.on end
            if type(g.fretLag.val)=="number"  then Humanize.guitar.fretLag.val=g.fretLag.val end
        end
        if type(g.mutChance)=="table" then
            if type(g.mutChance.on)=="boolean" then Humanize.guitar.mutChance.on=g.mutChance.on end
            if type(g.mutChance.val)=="number"  then Humanize.guitar.mutChance.val=g.mutChance.val end
        end
        if type(g.pickArticul)=="table" then
            if type(g.pickArticul.on)=="boolean" then Humanize.guitar.pickArticul.on=g.pickArticul.on end
            if type(g.pickArticul.val)=="number"  then Humanize.guitar.pickArticul.val=g.pickArticul.val end
        end
        if type(g.varyTiming)=="table" then
            if type(g.varyTiming.on)=="boolean" then Humanize.guitar.varyTiming.on=g.varyTiming.on end
            if type(g.varyTiming.val)=="number"  then Humanize.guitar.varyTiming.val=g.varyTiming.val end
        end
        if type(g.mistakes)=="table" then
            if type(g.mistakes.on)=="boolean" then Humanize.guitar.mistakes.on=g.mistakes.on end
            if type(g.mistakes.val)=="number"  then Humanize.guitar.mistakes.val=g.mistakes.val end
        end
        if type(g.tempoSway)=="table" then
            if type(g.tempoSway.on)=="boolean" then Humanize.guitar.tempoSway.on=g.tempoSway.on end
            if type(g.tempoSway.val)=="number"  then Humanize.guitar.tempoSway.val=g.tempoSway.val end
        end
    end
end
Humanize.load()

-- ── GuitarHum ──────────────────────────────────────────────────────────────
-- Guitar-specific humanization helpers.  Strum cluster state lives here as
-- upvalues so playGuitarNotes stays under Lua's 200-local-register hard limit.
local GuitarHum = {}
do
    local _strumPrevMs = -999   -- evMs of the last note-down in the current strum cluster
    local _strumCount  = 0      -- how many notes have fired in this cluster

    -- Returns extra ms delay for this note based on its position in a chord
    -- cluster (low strings strum first, higher strings cascade behind them).
    function GuitarHum.strumDelay(evMs)
        local h = Humanize.guitar
        if not (h.strumSpread and h.strumSpread.on) then return 0 end
        if evMs - _strumPrevMs > 30 then _strumCount = 0 end  -- new chord: reset cluster
        _strumPrevMs = evMs
        _strumCount  = _strumCount + 1
        return h.strumSpread.val * (_strumCount - 1) * 1000   -- ms per subsequent string
    end

    -- Returns a random positive-only ms delay (fretting hand arrives slightly late).
    function GuitarHum.fretLag()
        local h = Humanize.guitar
        if not (h.fretLag and h.fretLag.on) then return 0 end
        return math.random() * h.fretLag.val * 1000
    end

    -- Returns true if this pick should be a string buzz (note fires, cuts immediately).
    function GuitarHum.isMute()
        local h = Humanize.guitar
        if not (h.mutChance and h.mutChance.on) then return false end
        return math.random() < h.mutChance.val
    end

    -- Returns seconds until early release for pick articulation, or nil if disabled.
    function GuitarHum.pickArticulDelay(evMs, upMs)
        local h = Humanize.guitar
        if not (h.pickArticul and h.pickArticul.on) then return nil end
        local factor    = math.max(0.05, math.min(0.99, h.pickArticul.val))
        local naturalMs = math.max(10, upMs - evMs)
        return math.max(0.015, naturalMs * factor / 1000)
    end

    -- Call on loop start / seek to reset strum cluster state.
    function GuitarHum.reset()
        _strumPrevMs = -999
        _strumCount  = 0
    end
end
-- ── end GuitarHum ──────────────────────────────────────────────────────────

local parseDrumMidi
do
    local DRUM_MAP = {
        [35]={key="B",label="Kick"},         [36]={key="N",label="Kick #2"},
        [38]={key="C",label="Snare"},         [39]={key="C",label="Snare"},
        [40]={key="V",label="Snare #2"},      [37]={key="S",label="Snare Side"},
        [42]={key="X",label="HH Closed"},     [44]={key="M",label="HH Closed #2"},
        [46]={key="Z",label="HH Open"},       [26]={key=",",label="HH Open #2"},
        [48]={key="D",label="Tom 1"},         [50]={key="F",label="Tom 1 #2"},
        [47]={key="H",label="Tom 2 #2"},      [45]={key="G",label="Tom 2"},
        [43]={key="K",label="Tom 3 #2"},      [41]={key="J",label="Tom 3"},
        [49]={key="E",label="L. Crash"},      [57]={key="R",label="R. Crash"},
        [51]={key="U",label="Ride"},          [59]={key="U",label="Ride"},
        [53]={key="I",label="Ride Bell"},     [52]={key="O",label="China"},
        [55]={key="W",label="Splash"},        [58]={key="W",label="Splash"},
        [56]={key="A",label="Cowbell"},       [54]={key="A",label="Cowbell"},
    }
    parseDrumMidi = function(data)
    if #data < 14 then return nil, "too short" end
    if data:sub(1,4) ~= "MThd" then return nil, "no MThd" end

    local function ru32(d,p) local a,b,c,e=d:byte(p,p+3); return a*16777216+b*65536+c*256+e end
    local function ru16(d,p) local a,b=d:byte(p,p+1); return a*256+b end
    local function rvl(d,p)
        local v=0; local byte
        repeat
            if p>#d then break end
            byte=d:byte(p); p=p+1
            v=bit32.bor(bit32.lshift(v,7),bit32.band(byte,0x7F))
        until bit32.band(byte,0x80)==0
        return v,p
    end

    local numTracks=ru16(data,11); local division=ru16(data,13)
    local headerLen=ru32(data,5)
    if bit32.band(division,0x8000)~=0 then return nil,"SMPTE not supported" end

    local rawEvents={}
    local pos=9+headerLen

    for _=1,numTracks do
        local sl=math.min(pos+16,#data-4)
        while pos<=sl and data:sub(pos,pos+3)~="MTrk" do pos=pos+1 end
        if pos>#data-8 then break end
        local trackLen=ru32(data,pos+4)
        local trackStart=pos+8; local trackEnd=math.min(trackStart+trackLen,#data)
        pos=trackStart
        local absTick=0; local runStatus=0
        while pos<trackEnd do
            local delta; delta,pos=rvl(data,pos); absTick=absTick+delta
            if pos>trackEnd then break end
            local sb=data:byte(pos)
            if sb==0xFF then
                pos=pos+1; if pos>trackEnd then break end
                local mt=data:byte(pos); pos=pos+1
                local ml; ml,pos=rvl(data,pos)
                if mt==0x51 and ml>=3 then
                    local a,b,c=data:byte(pos,pos+2)
                    table.insert(rawEvents,{tick=absTick,etype="tempo",tempo=a*65536+b*256+c})
                end
                pos=pos+ml
            elseif sb==0xF0 or sb==0xF7 then
                pos=pos+1; local sl2; sl2,pos=rvl(data,pos); pos=pos+sl2
            else
                local newSt=sb>=0x80
                if newSt then runStatus=sb; pos=pos+1 end
                local msgType=bit32.rshift(bit32.band(runStatus,0xF0),4)
                if msgType==0x9 or msgType==0x8 then
                    if pos+1>trackEnd then break end
                    local note=data:byte(pos); local vel=data:byte(pos+1); pos=pos+2
                    if msgType==0x9 and vel>0 then
                        table.insert(rawEvents,{tick=absTick,etype="note",note=note})
                    end
                elseif msgType==0xA or msgType==0xB or msgType==0xE then pos=pos+2
                elseif msgType==0xC or msgType==0xD then pos=pos+1
                else break end
            end
        end
        pos=trackEnd
    end

    table.sort(rawEvents,function(a,b) return a.tick<b.tick end)

    local timeEvents={}
    local curTempo=500000; local lastTick=0; local lastTimeSec=0.0
    for _,ev in ipairs(rawEvents) do
        local dt=ev.tick-lastTick
        local sec=lastTimeSec+dt*curTempo/division/1e6
        if ev.etype=="tempo" then
            lastTimeSec=sec; lastTick=ev.tick; curTempo=ev.tempo
        elseif ev.etype=="note" then
            local info=DRUM_MAP[ev.note]
            if info then
                table.insert(timeEvents,{time=math.floor(sec*1000+0.5),key=info.key,notestate="drum_hit",label=info.label})
            end
        end
    end

    local totalSec=0
    if #rawEvents>0 then
        local lastEv=rawEvents[#rawEvents]
        local dt2=lastEv.tick-lastTick
        totalSec=lastTimeSec+dt2*curTempo/division/1e6
    end

    return timeEvents, totalSec
end
end -- close do block: DRUM_MAP + parseDrumMidi

local Cache = {songs={}, github={}, category={}, allPreloaded=false, preloading=false, loaded=0,
               allUploadedPreloaded=false, uploadedPreloading=false, uploadedLoaded=0, imagesReady=false,
               drumUploadedPreloading=false}

local MAX_RECENT = 20

-- Separate piano/drum tables — no shared file, no cross-mode leakage
local Favorites      = {piano={}, drum={}, guitar={}}
local RecentlyPlayed = {piano={}, drum={}, guitar={}}

-- Returns the active mode's table (no new locals at call sites)
function Favorites.get()
    if State.drumMode   then return Favorites.drum   end
    if State.guitarMode then return Favorites.guitar end
    return Favorites.piano
end
function RecentlyPlayed.get()
    if State.drumMode   then return RecentlyPlayed.drum   end
    if State.guitarMode then return RecentlyPlayed.guitar end
    return RecentlyPlayed.piano
end

-- ── Safe one-time migration from old unified files ────────────────────────────
-- New users who never had the old files are safe: every readfile is pcall'd.
-- Existing users get their piano songs → piano files, drum songs → drum files,
-- then the old files are deleted so this block never runs again.
do
    local function isDrumUrl(u) return u=="drum_preset" or u=="drum_uploaded" end
    local function isGuitarUrl(u) return u=="guitar_preset" or u=="guitar_uploaded" end
    -- Migrate favorites
    local fOk, fRaw = pcall(readfile, "RoMidi_favorites.json")
    if fOk and fRaw and fRaw ~= "" then
        local fT = jsonDecode(fRaw)
        if type(fT) == "table" then
            local fp, fd, fg = {}, {}, {}
            for n, m in pairs(fT) do
                if isDrumUrl(m.url) then fd[n]=m
                elseif isGuitarUrl(m.url) then fg[n]=m
                else fp[n]=m end
            end
            pcall(makefolder, "RoMidi")
            local sp = jsonEncode(fp); if sp then pcall(writefile,"RoMidi/favorites_piano.json",sp) end
            local sd = jsonEncode(fd); if sd then pcall(writefile,"RoMidi/favorites_drum.json",sd) end
            local sg = jsonEncode(fg); if sg then pcall(writefile,"RoMidi/favorites_guitar.json",sg) end
            pcall(delfile, "RoMidi_favorites.json")
        end
    end
    -- Migrate recently played
    local rOk, rRaw = pcall(readfile, "RoMidi_recent.json")
    if rOk and rRaw and rRaw ~= "" then
        local rT = jsonDecode(rRaw)
        if type(rT) == "table" then
            local rp, rd, rg = {}, {}, {}
            for _, e in ipairs(rT) do
                if isDrumUrl(e.url) then table.insert(rd,e)
                elseif isGuitarUrl(e.url) then table.insert(rg,e)
                else table.insert(rp,e) end
            end
            pcall(makefolder, "RoMidi")
            local srp = jsonEncode(rp); if srp then pcall(writefile,"RoMidi/recent_piano.json",srp) end
            local srd = jsonEncode(rd); if srd then pcall(writefile,"RoMidi/recent_drum.json",srd) end
            local srg = jsonEncode(rg); if srg then pcall(writefile,"RoMidi/recent_guitar.json",srg) end
            pcall(delfile, "RoMidi_recent.json")
        end
    end
end -- migration block

function Favorites.load()
    pcall(makefolder, "RoMidi")
    local ok1,r1 = pcall(readfile,"RoMidi/favorites_piano.json")
    if ok1 and r1 and r1~="" then local t=jsonDecode(r1); if type(t)=="table" then Favorites.piano=t end end
    local ok2,r2 = pcall(readfile,"RoMidi/favorites_drum.json")
    if ok2 and r2 and r2~="" then local t=jsonDecode(r2); if type(t)=="table" then Favorites.drum=t end end
    local ok3,r3 = pcall(readfile,"RoMidi/favorites_guitar.json")
    if ok3 and r3 and r3~="" then local t=jsonDecode(r3); if type(t)=="table" then Favorites.guitar=t end end
end
function Favorites.save()
    pcall(makefolder, "RoMidi")
    local file = State.drumMode and "RoMidi/favorites_drum.json"
               or State.guitarMode and "RoMidi/favorites_guitar.json"
               or "RoMidi/favorites_piano.json"
    local s = jsonEncode(Favorites.get()); if s then pcall(writefile, file, s) end
end
function Favorites.isFav(name) return Favorites.get()[name] ~= nil end
function Favorites.toggle(name, sData)
    local d = Favorites.get()
    if d[name] then d[name]=nil
    else d[name]={url=sData.url, category=sData.category or "",
                  originalName=sData.originalName or name, bpm=sData.bpm or 120, path=sData.path}
    end
    Favorites.save()
end

function RecentlyPlayed.load()
    pcall(makefolder, "RoMidi")
    local ok1,r1 = pcall(readfile,"RoMidi/recent_piano.json")
    if ok1 and r1 and r1~="" then local t=jsonDecode(r1); if type(t)=="table" then RecentlyPlayed.piano=t end end
    local ok2,r2 = pcall(readfile,"RoMidi/recent_drum.json")
    if ok2 and r2 and r2~="" then local t=jsonDecode(r2); if type(t)=="table" then RecentlyPlayed.drum=t end end
    local ok3,r3 = pcall(readfile,"RoMidi/recent_guitar.json")
    if ok3 and r3 and r3~="" then local t=jsonDecode(r3); if type(t)=="table" then RecentlyPlayed.guitar=t end end
end
function RecentlyPlayed.save()
    pcall(makefolder, "RoMidi")
    local file = State.drumMode and "RoMidi/recent_drum.json"
               or State.guitarMode and "RoMidi/recent_guitar.json"
               or "RoMidi/recent_piano.json"
    local s = jsonEncode(RecentlyPlayed.get()); if s then pcall(writefile, file, s) end
end
function RecentlyPlayed.add(name, sData)
    local list = RecentlyPlayed.get()
    for i = #list, 1, -1 do
        if list[i].name == name then table.remove(list, i) end
    end
    table.insert(list, 1, {
        name=name, url=sData.url, category=sData.category or "",
        originalName=sData.originalName or name, bpm=sData.bpm or 120, path=sData.path,
    })
    while #list > MAX_RECENT do table.remove(list) end
    RecentlyPlayed.save()
end

Favorites.load()
RecentlyPlayed.load()

local function safeKey(down,kc)
    if not kc then return end
    if VIM then
        local ok = pcall(VIM.SendKeyEvent, VIM, down, kc, false, game)
        if ok then return end
    end
    if down then
        if syn and syn.key_press then pcall(syn.key_press, kc.Value); return end
        if keypress then pcall(keypress, kc.Value); return end
        if Input and Input.SendKeyEvent then pcall(Input.SendKeyEvent, Input, true, kc, false, game); return end
    else
        if syn and syn.key_release then pcall(syn.key_release, kc.Value); return end
        if keyrelease then pcall(keyrelease, kc.Value); return end
        if Input and Input.SendKeyEvent then pcall(Input.SendKeyEvent, Input, false, kc, false, game); return end
    end
end

local _kcRefs = {}  -- [Enum.KeyCode] → integer hold count (piano notes only)

local function _kcPress(kc)
    _kcRefs[kc] = (_kcRefs[kc] or 0) + 1
    safeKey(true, kc)
end

local function _kcRelease(kc)
    local n = (_kcRefs[kc] or 1) - 1
    if n <= 0 then
        _kcRefs[kc] = nil
        safeKey(false, kc)
        return true   -- physical key was released
    else
        _kcRefs[kc] = n
        return false  -- still held by another note
    end
end

local function pressKey(char)
    if char:sub(1, 5) == "ctrl+" then
        local base = char:sub(6)
        local kc   = AsciiKeys[base]
        if kc then
            safeKey(true, ctrlKey)   -- Ctrl held while key fires (modifier only)
            _kcPress(kc)
            safeKey(false, ctrlKey)  -- release Ctrl immediately after key-down
            State.heldKeys[char] = kc
        end
        return
    end
    local sym = SymbolKeyCodes[char]
    local asc = AsciiKeys[char:lower()]
    if sym then
        safeKey(true, shiftKey)
        _kcPress(sym)
        safeKey(false, shiftKey)
        State.heldKeys[char] = sym
    elseif asc then
        if char ~= char:lower() then safeKey(true, shiftKey) end
        _kcPress(asc)
        if char ~= char:lower() then safeKey(false, shiftKey) end
        State.heldKeys[char] = asc
    end
end

local function releaseKey(char)
    local kc = State.heldKeys[char]
    if not kc then return end
    local released = _kcRelease(kc)  -- decrements; physically releases only when count=0
    if released then
        State.heldKeys[char] = nil   -- last holder released → clear the slot
    end
end

-- Guitar press/release: decodes "__gkNN" tokens using GUITAR_KEY_MAP.
-- Before pressing, releases any token already holding the same physical key
-- so repeated notes (Q then Q again) never get stuck.
local function pressGuitarKey(char)
    if char:sub(1, 4) ~= "__gk" then return end
    local midi = tonumber(char:sub(5))
    local km   = midi and GUITAR_KEY_MAP[midi]
    if not km then return end
    local kc = km[1]

    -- Release this token if it is already held (same note retrigger)
    if State.heldKeys[char] then
        safeKey(false, State.heldKeys[char])
        State.heldKeys[char] = nil
    end

    -- Release any OTHER guitar token holding the same physical key
    for token, heldKc in pairs(State.heldKeys) do
        if token:sub(1, 4) == "__gk" and heldKc == kc then
            safeKey(false, heldKc)
            State.heldKeys[token] = nil
        end
    end

    if km[2] then safeKey(true, shiftKey) end
    safeKey(true, kc)
    if km[2] then safeKey(false, shiftKey) end
    State.heldKeys[char] = kc
end

local function releaseGuitarKey(char)
    if char:sub(1, 4) ~= "__gk" then return end
    local kc = State.heldKeys[char]
    if not kc then return end
    local midi = tonumber(char:sub(5))
    local km   = midi and GUITAR_KEY_MAP[midi]
    local needsShift = km and km[2]
    -- For shift+key notes: hold shift while releasing the base key,
    -- then release shift — prevents the base key from getting stuck.
    if needsShift then safeKey(true, shiftKey) end
    safeKey(false, kc)
    if needsShift then safeKey(false, shiftKey) end
    State.heldKeys[char] = nil
end

local function pressDrumKey(char)
    local sym = SymbolKeyCodes[char]
    local asc = AsciiKeys[char:lower()]
    if sym then
        safeKey(true, shiftKey); safeKey(true, sym); safeKey(false, shiftKey)
        return sym
    elseif asc then
        if char ~= char:lower() then safeKey(true, shiftKey) end
        safeKey(true, asc)
        if char ~= char:lower() then safeKey(false, shiftKey) end
        return asc
    end
    return nil
end

local function releaseAll()
    for _, kc in pairs(State.heldKeys) do safeKey(false, kc) end
    State.heldKeys = {}
    _kcRefs        = {}             -- hard-reset all refcounts on a full release
    safeKey(false, shiftKey)
    safeKey(false, ctrlKey)  -- ensure Ctrl is never left stranded
end
local function fmtTime(s)
    return string.format("%d:%02d",math.floor(s/60),math.floor(s%60))
end
local function urlEncode(str)
    return str:gsub("([^%w%-_%.~])",function(c) return string.format("%%%02X",c:byte()) end)
end
local function getHttp()
    return (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)
        or (http and http.Request)
        or (SENTINEL and SENTINEL.http_request)
        or (Axios and Axios.request)
        or nil
end
local function safeHttpGet(url)
    -- Cache-bust: nocache timestamp busts GitHub CDN; true arg bypasses Roblox engine HTTP cache
    -- This ensures return files always reflect the latest indexed songs on GitHub
    local bustUrl = url .. (url:find("?") and "&" or "?") .. "nocache=" .. tostring(os.time())
    local ok, res = pcall(function() return game:HttpGet(bustUrl, true) end)
    if ok and res then return res end
    local httpReq = getHttp()
    if httpReq then
        local ok2, resp = pcall(httpReq, {Url=bustUrl, Method="GET"})
        if ok2 and resp and (resp.StatusCode == 200 or resp.status == 200) then
            return resp.Body or resp.body or nil
        end
    end
    return nil
end

local function safeLoadstring(code)
    if not code or code == "" then return nil end
    local fn, compileErr = loadstring(code)
    if not fn then return nil end  -- compile error — caller gets nil
    local ok, result = pcall(fn)
    if ok then return result end
    return nil  -- runtime error inside loaded chunk — caller gets nil
end

local function parseList(res)
    if not res or res == "" then return nil end
    local lower100 = res:sub(1, 200):lower()
    if lower100:find("<!doctype") or lower100:find("<html") or lower100:find("data%-view%-component") or lower100:find("<div") or lower100:find("<span") then return nil end
    local v = safeLoadstring(res)
    if type(v) == "table" then return v end
    local t = {}
    local src = type(v) == "string" and v or res
    for line in src:gmatch("[^\n\r]+") do
        local s = line:match("^%s*(.-)%s*$")
        s = s:match("^\"(.-)\"") or s:match("^'(.-)'") or s
        s = s:match("^(.-)%s*,$") or s
        if s ~= "" and s ~= "return {" and s ~= "{" and s ~= "}" then
            t[#t+1] = s
        end
    end
    return #t > 0 and t or nil
end
local function readMidiFile(path)
    local ok,res=pcall(readfile,path)
    if not ok then return nil end
    local b=table.create(#res)
    for i=1,#res do b[i]=res:byte(i) end
    return b
end
local function scanWorkspace()
    local categoryMap = {}  -- { catName -> { fname -> path } }

    local function isMidi(path)
        local low = path:lower()
        return low:sub(-4) == ".mid" or low:sub(-4) == ".smf"
    end

    local function fname(path)
        path = path:gsub("\\", "/")
        return path:match("([^/]+)$") or path
    end

    local function stripExt(name)
        return name:match("^(.+)%.[^%.]+$") or name
    end

    local ok, rootEntries = pcall(listfiles, "")
    if not ok or type(rootEntries) ~= "table" then
        return categoryMap
    end

    for _, rootPath in ipairs(rootEntries) do
        rootPath = rootPath:gsub("\\", "/")
        local rootName = fname(rootPath)
        if not rootName:find("%.") then
            local ok2, subEntries = pcall(listfiles, rootPath)
            if ok2 and type(subEntries) == "table" then
                for _, subPath in ipairs(subEntries) do
                    subPath = subPath:gsub("\\", "/")
                    local subName = fname(subPath)
                    if not subName:find("%.") then
                        local catName = subName
                        if not categoryMap[catName] then
                            categoryMap[catName] = {}
                        end
                        local ok3, fileEntries = pcall(listfiles, subPath)
                        if ok3 and type(fileEntries) == "table" then
                            for _, filePath in ipairs(fileEntries) do
                                filePath = filePath:gsub("\\", "/")
                                if isMidi(filePath) then
                                    local fn = stripExt(fname(filePath))
                                    if not categoryMap[catName][fn] then
                                        categoryMap[catName][fn] = filePath
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return categoryMap
end

local function getFolderCategories()
    local map = scanWorkspace()
    local cats = {}
    for catName, files in pairs(map) do
        local count = 0
        for _ in pairs(files) do count = count + 1 end
        if count > 0 then table.insert(cats, catName) end
    end
    table.sort(cats, function(a, b) return a:lower() < b:lower() end)
    return cats
end

local function getMidiFilesForCategory(category)
    local map = scanWorkspace()
    local result = {}  -- list of { fname, path }
    if category == "All Songs" then
        local seen = {}
        for _, files in pairs(map) do
            for fn, path in pairs(files) do
                if not seen[fn] then
                    seen[fn] = true
                    table.insert(result, { fname=fn, path=path })
                end
            end
        end
    else
        local files = map[category] or {}
        for fn, path in pairs(files) do
            table.insert(result, { fname=fn, path=path })
        end
    end
    table.sort(result, function(a, b) return a.fname:lower() < b.fname:lower() end)
    return result
end

local function getMidiFiles(folder)
    local files={}
    local ok,lst=pcall(listfiles,folder)
    if ok then
        for _,f in ipairs(lst) do
            local ext=f:lower():sub(-4)
            if ext==".mid" or ext==".smf" then table.insert(files,f) end
        end
    end
    return files
end

local function scanWorkspaceDrum()
    local categoryMap={}

    local function isRtx(path) return path:lower():sub(-4)==".drm" end
    local function fname(path) path=path:gsub("\\","/"); return path:match("([^/]+)$") or path end
    local function stripExt(name) return name:match("^(.+)%.[^%.]+$") or name end

    local ok,rootEntries=pcall(listfiles,"")
    if not ok or type(rootEntries)~="table" then return categoryMap end

    for _,rootPath in ipairs(rootEntries) do
        rootPath=rootPath:gsub("\\","/")
        local rootName=fname(rootPath)
        if not rootName:find("%.") then
            local ok2,subEntries=pcall(listfiles,rootPath)
            if ok2 and type(subEntries)=="table" then
                for _,subPath in ipairs(subEntries) do
                    subPath=subPath:gsub("\\","/")
                    local subName=fname(subPath)
                    if not subName:find("%.") then
                        local catName=subName
                        if not categoryMap[catName] then categoryMap[catName]={} end
                        local ok3,fileEntries=pcall(listfiles,subPath)
                        if ok3 and type(fileEntries)=="table" then
                            for _,filePath in ipairs(fileEntries) do
                                filePath=filePath:gsub("\\","/")
                                if isRtx(filePath) then
                                    local fn=stripExt(fname(filePath))
                                    if not categoryMap[catName][fn] then
                                        categoryMap[catName][fn]=filePath
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return categoryMap
end

local function getFolderCategoriesDrum()
    local map=scanWorkspaceDrum()
    local cats={}
    for catName,files in pairs(map) do
        local count=0; for _ in pairs(files) do count=count+1 end
        if count>0 then table.insert(cats,catName) end
    end
    table.sort(cats,function(a,b) return a:lower()<b:lower() end)
    return cats
end

local function getRtxFilesForCategory(category)
    local map=scanWorkspaceDrum()
    local result={}
    if category=="All Songs" then
        local seen={}
        for _,files in pairs(map) do
            for fn,path in pairs(files) do
                if not seen[fn] then seen[fn]=true; table.insert(result,{fname=fn,path=path}) end
            end
        end
    else
        local files=map[category] or {}
        for fn,path in pairs(files) do table.insert(result,{fname=fn,path=path}) end
    end
    table.sort(result,function(a,b) return a.fname:lower()<b.fname:lower() end)
    return result
end

-- ── Guitar local file scanner (.gtr extension) ───────────────────────────────
local function scanWorkspaceGuitar()
    local categoryMap={}
    local function isGtr(path) return path:lower():sub(-4)==".gtr" end
    local function fname(path) path=path:gsub("\\","/"); return path:match("([^/]+)$") or path end
    local function stripExt(name) return name:match("^(.+)%.[^%.]+$") or name end
    local ok,rootEntries=pcall(listfiles,"")
    if not ok or type(rootEntries)~="table" then return categoryMap end
    for _,rootPath in ipairs(rootEntries) do
        rootPath=rootPath:gsub("\\","/")
        local rootName=fname(rootPath)
        if not rootName:find("%.") then
            local ok2,subEntries=pcall(listfiles,rootPath)
            if ok2 and type(subEntries)=="table" then
                for _,subPath in ipairs(subEntries) do
                    subPath=subPath:gsub("\\","/")
                    local subName=fname(subPath)
                    if not subName:find("%.") then
                        local catName=subName
                        if not categoryMap[catName] then categoryMap[catName]={} end
                        local ok3,fileEntries=pcall(listfiles,subPath)
                        if ok3 and type(fileEntries)=="table" then
                            for _,filePath in ipairs(fileEntries) do
                                filePath=filePath:gsub("\\","/")
                                if isGtr(filePath) then
                                    local fn=stripExt(fname(filePath))
                                    if not categoryMap[catName][fn] then
                                        categoryMap[catName][fn]=filePath
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return categoryMap
end

local function getFolderCategoriesGuitar()
    local map=scanWorkspaceGuitar()
    local cats={}
    for catName,files in pairs(map) do
        local count=0; for _ in pairs(files) do count=count+1 end
        if count>0 then table.insert(cats,catName) end
    end
    table.sort(cats,function(a,b) return a:lower()<b:lower() end)
    return cats
end

local function getGtrFilesForCategory(category)
    local map=scanWorkspaceGuitar()
    local result={}
    if category=="All Songs" then
        local seen={}
        for _,files in pairs(map) do
            for fn,path in pairs(files) do
                if not seen[fn] then seen[fn]=true; table.insert(result,{fname=fn,path=path}) end
            end
        end
    else
        local files=map[category] or {}
        for fn,path in pairs(files) do table.insert(result,{fname=fn,path=path}) end
    end
    table.sort(result,function(a,b) return a.fname:lower()<b.fname:lower() end)
    return result
end

-- Removes leading empty silence from a notes array so songs begin immediately.
-- Finds the first real note-on event, and if it starts >= 500 ms into the
-- track, shifts ALL events (notes + tempo markers) back by that offset so
-- playback begins at t=0.  Both `time` (wall-clock ms) and `_beat` are shifted
-- so the fix works in both Auto-tempo and Manual-BPM modes.
local function trimLeadingSilence(notesArr)
    if not notesArr or #notesArr == 0 then return notesArr end

    -- Find the first actual note-on event.
    -- Piano/Guitar use notestate="down"; Drums use notestate="drum_hit".
    local firstMs, firstBeat
    for _, n in ipairs(notesArr) do
        if n.notestate == "down" or n.notestate == "drum_hit" then
            firstMs   = n.time  or 0
            firstBeat = n._beat -- nil for drums (time-only), that's fine
            break
        end
    end

    -- Only trim if there is a meaningful leading gap (>= 500 ms / ~0.5 s)
    if not firstMs or firstMs < 500 then return notesArr end

    -- Shift every event backwards by the gap so the first note lands at t=0.
    -- `_beat` is only present on piano/guitar events; drums only have `time`.
    for _, n in ipairs(notesArr) do
        if n.time  ~= nil then n.time  = math.max(0, n.time  - firstMs)             end
        if n._beat ~= nil and firstBeat then
            n._beat = math.max(0, n._beat - firstBeat)
        end
    end

    return notesArr
end

local function extractTempos(notesArr)
    local m={}
    for _,n in ipairs(notesArr) do
        local tempoStr = n.tempo
        if not tempoStr or tempoStr == "" then
            local k = n.keys or n[2] or ""
            if k:match("^tempo=%d+$") then tempoStr = k end
        end
        if tempoStr then
            local b = tempoStr:match("^tempo=(%d+)$")
            if b then
                local beatT = n._beat or (type(n[1])=="number" and n[1] or 0)
                table.insert(m,{time=beatT, bpm=tonumber(b)})
            end
        end
    end
    table.sort(m,function(a,b) return a.time<b.time end)
    return m
end
local function beatToReal(beat,markers,initBpm,use)
    if not use or #markers==0 then return beat*(60/initBpm) end
    local total,lastB,curB=0,0,initBpm
    for _,mk in ipairs(markers) do
        if mk.time<=beat then total=total+(mk.time-lastB)*(60/curB); lastB=mk.time; curB=mk.bpm
        else break end
    end
    return total+(beat-lastB)*(60/curB)
end
local function realToBeat(real,markers,initBpm,use)
    if not use or #markers==0 then return real/(60/initBpm) end
    local totalB,lastB,curB,rem=0,0,initBpm,real
    for _,mk in ipairs(markers) do
        local segB=mk.time-lastB; local segR=segB*(60/curB)
        if rem<=segR then return totalB+(rem*(curB/60)) end
        rem=rem-segR; totalB=totalB+segB; lastB=mk.time; curB=mk.bpm
    end
    return totalB+rem*(curB/60)
end
local function calcDuration(notesArr,initBpm,useT)
    if #notesArr==0 then return 0 end
    local markers=useT and extractTempos(notesArr) or {}
    local lastT=0
    for _,n in ipairs(notesArr) do
        local tempoStr = n.tempo
        if not tempoStr or tempoStr == "" then
            local k = n.keys or n[2] or ""
            if k:match("^tempo=%d+$") then tempoStr = k end
        end
        if not (tempoStr and tempoStr ~= "") then
            local t = n._beat or (type(n[1])=="number" and n[1] or 0)
            if t > lastT then lastT = t end
        end
    end
    return beatToReal(lastT,markers,initBpm,useT)
end
local function bpmAtBeat(beat)
    -- Manual mode: always use the user-chosen BPM
    if not State.usetempo then return State.manualBpm end
    -- Auto mode with no markers: fall back to the MIDI's native initial BPM
    if #State.tempoMarkers == 0 then return State.originalBpm end
    -- Auto mode: walk markers and return the BPM active at 'beat'
    local bpm = State.originalBpm
    for _,mk in ipairs(State.tempoMarkers) do
        if beat >= mk.time then bpm = mk.bpm else break end
    end
    return bpm
end

-- Shared event-timing helper used by both seekTo and the playback loop.
-- Auto mode:   ev.time is already native wall-clock ms → use directly (no scaling).
-- Manual mode: derive ms from beat position at the user-chosen BPM.
local function calcEvMs(ev)
    if State.usetempo then
        if ev.time ~= nil then
            return ev.time          -- native MIDI absolute ms, no scaling needed
        else
            local initB = #State.tempoMarkers > 0
                          and State.tempoMarkers[1].bpm or State.originalBpm
            return beatToReal(ev._beat or ev[1] or 0, State.tempoMarkers, initB, true) * 1000
        end
    else
        if ev._beat ~= nil then
            return ev._beat * (60 / State.manualBpm) * 1000
        elseif ev.time ~= nil then
            -- fallback: scale native ms by BPM ratio
            local nativeBpm = State.originalBpm > 0 and State.originalBpm or 120
            return ev.time * (nativeBpm / State.manualBpm)
        else
            return beatToReal(ev._beat or ev[1] or 0, State.tempoMarkers,
                              State.currentBpm, false) * 1000
        end
    end
end
local gui = Instance.new("ScreenGui", CoreGui)
gui.Name="RoMidi"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
Toast.init(gui)

-- ── REC Modal + Countdown — only 4 upvalues leak to outer scope ──────────────
-- Everything else lives inside the do-block to stay within Lua's 200-local limit.
local runRecCountdown, cancelRecCountdown, openRecModal
local _recModalConfirmCallback = nil
do
    -- ── Countdown overlay (compact pill — auto-sizes to content) ────────────
    local cdOverlay = UI.frame(gui, {
        Size=UDim2.new(0,0,0,0),
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
        BackgroundColor3=Color3.fromRGB(18,6,40), BackgroundTransparency=1,
        AutomaticSize=Enum.AutomaticSize.XY,
        ZIndex=300, Visible=false,
    })
    UI.corner(cdOverlay, Scale.px(22))
    UI.gradient(cdOverlay, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30,10,60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10,4,28)),
    }, 135)
    do
        local pad = Instance.new("UIPadding", cdOverlay)
        pad.PaddingTop    = UDim.new(0, Scale.px(14))
        pad.PaddingBottom = UDim.new(0, Scale.px(14))
        pad.PaddingLeft   = UDim.new(0, Scale.px(20))
        pad.PaddingRight  = UDim.new(0, Scale.px(20))
        local ll = Instance.new("UIListLayout", cdOverlay)
        ll.FillDirection = Enum.FillDirection.Vertical
        ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
        ll.VerticalAlignment = Enum.VerticalAlignment.Center
        ll.Padding = UDim.new(0, Scale.px(4))
        ll.SortOrder = Enum.SortOrder.LayoutOrder
    end
    local cdNumLbl = UI.label(cdOverlay, {
        Size=UDim2.new(0,Scale.px(80),0,Scale.px(80)),
        TextColor3=T.white, Font=Enum.Font.BuilderSansBold,
        TextSize=Scale.fs(72), Text="5", ZIndex=301,
        TextXAlignment=Enum.TextXAlignment.Center,
        LayoutOrder=1,
    })
    local cdHintLbl = UI.label(cdOverlay, {
        Size=UDim2.new(0,Scale.px(140),0,Scale.px(22)),
        TextColor3=T.neonR, Font=Enum.Font.BuilderSansBold,
        TextSize=Scale.fs(11), Text="● REC — Get ready...", ZIndex=301,
        TextXAlignment=Enum.TextXAlignment.Center,
        LayoutOrder=2,
    })

    -- ── Setup modal ──────────────────────────────────────────────────────────
    local scrim = UI.frame(gui, {
        Size=UDim2.new(1,0,1,0), Position=UDim2.new(0,0,0,0),
        BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=0.55,
        ZIndex=309, Visible=false,
    })
    local modal = UI.frame(gui, {
        Size=UDim2.new(0,Scale.px(310),0,Scale.px(306)),
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
        BackgroundColor3=T.panel, ZIndex=310, Visible=false,
    })
    UI.corner(modal, Scale.px(14)); UI.stroke(modal, T.neonR, 2)
    UI.gradient(modal, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(36,10,62)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20,6,38)),
    }, 135)
    -- static labels / divider
    UI.label(modal, {
        Size=UDim2.new(1,-Scale.px(20),0,Scale.px(28)), Position=UDim2.new(0,Scale.px(10),0,Scale.px(12)),
        TextColor3=T.neonR, Font=Enum.Font.BuilderSansBold, TextSize=Scale.fs(14),
        TextXAlignment=Enum.TextXAlignment.Center, Text="● REC MODE SETUP", ZIndex=311,
    })
    UI.label(modal, {
        Size=UDim2.new(1,-Scale.px(20),0,Scale.px(20)), Position=UDim2.new(0,Scale.px(10),0,Scale.px(40)),
        TextColor3=T.txtDim, Font=Enum.Font.BuilderSans, TextSize=Scale.fs(11),
        TextXAlignment=Enum.TextXAlignment.Center, Text="How many seconds before playback starts?", ZIndex=311,
    })
    UI.frame(modal, {
        Size=UDim2.new(1,-Scale.px(24),0,1), Position=UDim2.new(0,Scale.px(12),0,Scale.px(62)),
        BackgroundColor3=T.border, ZIndex=311,
    })
    UI.label(modal, {
        Size=UDim2.new(1,-Scale.px(20),0,Scale.px(18)), Position=UDim2.new(0,Scale.px(14),0,Scale.px(70)),
        TextColor3=T.accent, Font=Enum.Font.BuilderSansBold, TextSize=Scale.fs(11),
        TextXAlignment=Enum.TextXAlignment.Left, Text="Delay (seconds) — max 60:", ZIndex=311,
    })
    -- delay input
    local inputBg = UI.frame(modal, {
        Size=UDim2.new(1,-Scale.px(24),0,Scale.px(36)), Position=UDim2.new(0,Scale.px(12),0,Scale.px(90)),
        BackgroundColor3=T.card, ZIndex=311,
    })
    UI.corner(inputBg, Scale.px(8)); UI.stroke(inputBg, T.border, 1)
    local delayInput = UI.input(inputBg, {
        Size=UDim2.new(1,-Scale.px(12),1,0), Position=UDim2.new(0,Scale.px(6),0,0),
        BackgroundTransparency=1, TextColor3=T.white, Font=Enum.Font.BuilderSansBold,
        TextSize=Scale.fs(18), TextXAlignment=Enum.TextXAlignment.Center,
        PlaceholderText="5", Text="5", ClearTextOnFocus=false, ZIndex=312,
    })
    local hintLbl = UI.label(modal, {
        Size=UDim2.new(1,-Scale.px(20),0,Scale.px(16)), Position=UDim2.new(0,Scale.px(14),0,Scale.px(130)),
        TextColor3=T.neonY, Font=Enum.Font.BuilderSans, TextSize=Scale.fs(10),
        TextXAlignment=Enum.TextXAlignment.Center, Text="", ZIndex=311,
    })
    -- countdown visibility checkbox
    UI.label(modal, {
        Size=UDim2.new(1,-Scale.px(20),0,Scale.px(16)), Position=UDim2.new(0,Scale.px(14),0,Scale.px(150)),
        TextColor3=T.accent, Font=Enum.Font.BuilderSansBold, TextSize=Scale.fs(11),
        TextXAlignment=Enum.TextXAlignment.Left, Text="Countdown visibility:", ZIndex=311,
    })
    local chkRow = UI.frame(modal, {
        Size=UDim2.new(1,-Scale.px(24),0,Scale.px(26)), Position=UDim2.new(0,Scale.px(12),0,Scale.px(168)),
        BackgroundTransparency=1, ZIndex=311,
    })
    local chkBox = UI.frame(chkRow, {
        Size=UDim2.new(0,Scale.px(20),0,Scale.px(20)), Position=UDim2.new(0,0,0.5,-Scale.px(10)),
        BackgroundColor3=T.neonR, ZIndex=312,
    })
    UI.corner(chkBox, Scale.px(5)); UI.stroke(chkBox, T.neonR, 1)
    local chkMark = UI.label(chkBox, {
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, TextColor3=T.white,
        Font=Enum.Font.BuilderSansBold, TextSize=Scale.fs(13), Text="✓", ZIndex=313,
    })
    local chkLbl = UI.label(chkRow, {
        Size=UDim2.new(1,-Scale.px(28),1,0), Position=UDim2.new(0,Scale.px(28),0,0),
        BackgroundTransparency=1, TextColor3=T.txt, Font=Enum.Font.BuilderSans,
        TextSize=Scale.fs(12), TextXAlignment=Enum.TextXAlignment.Left,
        Text="Visible Countdown", ZIndex=312,
    })
    local chkBtn = UI.btn(chkRow, { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="", ZIndex=314 })
    local chkState = true
    local function syncChk()
        if chkState then
            chkBox.BackgroundColor3=T.neonR; chkMark.Text="✓"; chkLbl.Text="Visible Countdown"
        else
            chkBox.BackgroundColor3=T.card; chkMark.Text=""; chkLbl.Text="Invisible Countdown (silent)"
        end
    end
    chkBtn.MouseButton1Click:Connect(function() chkState=not chkState; syncChk() end)
    syncChk()
    -- after-song restore checkbox
    UI.frame(modal, {
        Size=UDim2.new(1,-Scale.px(24),0,1), Position=UDim2.new(0,Scale.px(12),0,Scale.px(198)),
        BackgroundColor3=T.border, ZIndex=311,
    })
    UI.label(modal, {
        Size=UDim2.new(1,-Scale.px(20),0,Scale.px(16)), Position=UDim2.new(0,Scale.px(14),0,Scale.px(204)),
        TextColor3=T.accent, Font=Enum.Font.BuilderSansBold, TextSize=Scale.fs(11),
        TextXAlignment=Enum.TextXAlignment.Left, Text="After song ends:", ZIndex=311,
    })
    local chk2Row = UI.frame(modal, {
        Size=UDim2.new(1,-Scale.px(24),0,Scale.px(26)), Position=UDim2.new(0,Scale.px(12),0,Scale.px(222)),
        BackgroundTransparency=1, ZIndex=311,
    })
    local chk2Box = UI.frame(chk2Row, {
        Size=UDim2.new(0,Scale.px(20),0,Scale.px(20)), Position=UDim2.new(0,0,0.5,-Scale.px(10)),
        BackgroundColor3=T.neonR, ZIndex=312,
    })
    UI.corner(chk2Box, Scale.px(5)); UI.stroke(chk2Box, T.neonR, 1)
    local chk2Mark = UI.label(chk2Box, {
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, TextColor3=T.white,
        Font=Enum.Font.BuilderSansBold, TextSize=Scale.fs(13), Text="✓", ZIndex=313,
    })
    local chk2Lbl = UI.label(chk2Row, {
        Size=UDim2.new(1,-Scale.px(28),1,0), Position=UDim2.new(0,Scale.px(28),0,0),
        BackgroundTransparency=1, TextColor3=T.txt, Font=Enum.Font.BuilderSans,
        TextSize=Scale.fs(12), TextXAlignment=Enum.TextXAlignment.Left,
        Text="Bring back UI after song ends", ZIndex=312,
    })
    local chk2Btn = UI.btn(chk2Row, { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="", ZIndex=314 })
    local chk2State = true
    local function syncChk2()
        if chk2State then
            chk2Box.BackgroundColor3=T.neonR; chk2Mark.Text="✓"; chk2Lbl.Text="Bring back UI after song ends"
        else
            chk2Box.BackgroundColor3=T.card; chk2Mark.Text=""; chk2Lbl.Text="Keep UI hidden (use 3-tap)"
        end
    end
    chk2Btn.MouseButton1Click:Connect(function() chk2State=not chk2State; syncChk2() end)
    syncChk2()
    -- confirm / cancel buttons
    local btnRow = UI.frame(modal, {
        Size=UDim2.new(1,-Scale.px(24),0,Scale.px(36)), Position=UDim2.new(0,Scale.px(12),0,Scale.px(254)),
        BackgroundTransparency=1, ZIndex=311,
    })
    local confirmBtn = UI.btn(btnRow, {
        Size=UDim2.new(0.56,-Scale.px(4),1,0), Position=UDim2.new(0.44,Scale.px(4),0,0),
        BackgroundColor3=Color3.fromRGB(72,14,30), TextColor3=T.btnStopAccent,
        Font=Enum.Font.BuilderSansBold, TextSize=Scale.fs(12), Text="● Start Recording", ZIndex=312,
    })
    UI.corner(confirmBtn, Scale.px(8)); UI.hover(confirmBtn, Color3.fromRGB(72,14,30), Color3.fromRGB(100,20,42))
    local cancelBtn = UI.btn(btnRow, {
        Size=UDim2.new(0.44,-Scale.px(4),1,0), Position=UDim2.new(0,0,0,0),
        BackgroundColor3=T.card, TextColor3=T.txtDim, Font=Enum.Font.BuilderSans,
        TextSize=Scale.fs(12), Text="Cancel", ZIndex=312,
    })
    UI.corner(cancelBtn, Scale.px(8)); UI.hover(cancelBtn, T.card, T.border)

    -- ── Internal helpers ─────────────────────────────────────────────────────
    local function closeModal()
        tw(modal, 0.15, {BackgroundTransparency=1})
        task.delay(0.17, function() modal.Visible=false; scrim.Visible=false end)
    end
    local function parseDelay()
        local raw = delayInput.Text:match("^%s*(%d+)%s*$")
        if not raw then return nil, "Enter a whole number (0–60)" end
        local n = tonumber(raw)
        if not n or n < 0 then return nil, "Minimum is 0 seconds" end
        if n > 60 then return nil, "Maximum is 60 seconds" end
        return n, nil
    end
    cancelBtn.MouseButton1Click:Connect(closeModal)
    confirmBtn.MouseButton1Click:Connect(function()
        local n, err = parseDelay()
        if err then
            hintLbl.Text = "⚠ " .. err
            tw(inputBg, 0.1, {BackgroundColor3=Color3.fromRGB(60,18,18)})
            task.delay(0.12, function() tw(inputBg, 0.1, {BackgroundColor3=T.card}) end)
            return
        end
        hintLbl.Text = ""; State.recDelay=n; State.recCountdownVisible=chkState
        State.recAutoRestore=chk2State
        closeModal()
        if _recModalConfirmCallback then _recModalConfirmCallback() end
    end)

    -- ── Exposed upvalues ─────────────────────────────────────────────────────
    openRecModal = function()
        delayInput.Text = tostring(State.recDelay)
        chkState = State.recCountdownVisible; hintLbl.Text = ""
        chk2State = State.recAutoRestore
        syncChk(); syncChk2(); scrim.Visible=true; modal.Visible=true
        modal.BackgroundTransparency=1; tw(modal, 0.2, {BackgroundTransparency=0})
    end

    local cdActive = false
    runRecCountdown = function(seconds, onDone)
        if seconds <= 0 then onDone(); return end
        if State.recCountdownVisible then
            cdOverlay.Visible=true; cdOverlay.BackgroundTransparency=1
            tw(cdOverlay, 0.25, {BackgroundTransparency=0.6})
        end
        cdActive = true
        task.spawn(function()
            for i = seconds, 1, -1 do
                if not cdActive then return end
                if State.recCountdownVisible then
                    cdNumLbl.Text=tostring(i); cdNumLbl.TextTransparency=0
                    cdNumLbl.TextSize=Scale.fs(140); tw(cdNumLbl, 0.3, {TextSize=Scale.fs(120)})
                    if i <= 3 then
                        cdHintLbl.Text="● REC — "..i.." second"..(i==1 and "" or "s").."..."
                        cdHintLbl.TextColor3 = (i==1) and T.neonR or T.neonY
                    else
                        cdHintLbl.Text="● REC — Get ready..."; cdHintLbl.TextColor3=T.txtDim
                    end
                end
                task.wait(1)
            end
            cdActive = false
            if State.recCountdownVisible then
                tw(cdOverlay, 0.2, {BackgroundTransparency=1})
                task.delay(0.22, function() cdOverlay.Visible=false end)
            end
            onDone()
        end)
    end

    cancelRecCountdown = function()
        cdActive = false; cdOverlay.Visible = false; State.recCounting = false
    end
end -- ── end REC Modal + Countdown do-block ───────────────────────────────────

local mainFrame, floatFrame, songInfoLbl
local loadLocalCategory  -- forward-declared; assigned after main frame is built

local function getMainSize()
    local vp=workspace.CurrentCamera.ViewportSize
    local s=math.min(vp.X,vp.Y)
    local w=math.min(math.round(s*0.78),520)
    local h=Scale.px(296)
    return w, h
end
local function getBrowserSize()
    local vp=workspace.CurrentCamera.ViewportSize
    local s=math.min(vp.X,vp.Y)
    return math.min(math.round(s*0.76),500), Scale.px(296)
end
local function getFloatSize()
    local s=math.min(workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y)
    return math.min(math.round(s*0.58),340), Scale.px(170)
end

local MFW,MFH=getMainSize()
local P8=Scale.px(8); local P12=Scale.px(12)

mainFrame=UI.frame(gui,{
    Size=UDim2.new(0,MFW,0,MFH),
    Position=UDim2.new(0,Scale.px(20),0,Scale.px(20)),
    BackgroundColor3=T.bg, Visible=true, BackgroundTransparency=1, ClipsDescendants=true,
})
twBack(mainFrame,0.4,{BackgroundTransparency=0})
UI.corner(mainFrame,P12); UI.stroke(mainFrame,T.neon,2)
UI.gradient(mainFrame,{
    ColorSequenceKeypoint.new(0,T.bg),
    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(18,10,40)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(30,12,55)),
},120)

local browseBtn, settingsBtn, floatBtn, minimizeBtn
local instrBadge   -- instrument badge label; updated by updateInstrumentBtns
local _minimized = false
do
    -- Full-frame drag: entire panel is draggable, clamped to viewport
    UI.makeDraggable(mainFrame,mainFrame)

    local HEADER_H = Scale.px(40)
    local header = UI.frame(mainFrame, {
        Size=UDim2.new(1,0,0,HEADER_H),
        BackgroundColor3=T.purpleDeep, ClipsDescendants=true, ZIndex=2,
    })
    UI.corner(header, P8)
    UI.gradient(header, {
        ColorSequenceKeypoint.new(0, T.purpleDeep),
        ColorSequenceKeypoint.new(1, T.purpleMid),
    }, 0)

    -- ── LEFT: Instrument badge pill ──────────────────────────────────────────
    instrBadge = UI.label(header, {
        Size=UDim2.new(0,Scale.px(106),0,Scale.px(22)),
        Position=UDim2.new(0,P8,0.5,-Scale.px(11)),
        Text="🎹 Piano", TextColor3=T.neonB, TextSize=Scale.fs(10),
        Font=Enum.Font.BuilderSansBold,
        BackgroundColor3=Color3.fromRGB(20,12,50), BackgroundTransparency=0,
        ZIndex=3,
    })
    UI.corner(instrBadge, Scale.px(6))
    UI.stroke(instrBadge, T.border, 1)

    -- ── CENTER: Title + subtitle ─────────────────────────────────────────────
    UI.label(header, {
        Size=UDim2.new(0,Scale.px(240),0,Scale.px(20)),
        Position=UDim2.new(0.5,-Scale.px(120),0.5,-Scale.px(13)),
        Text="♪ RoMidi", TextColor3=T.accent, TextSize=Scale.fs(14),
        Font=Enum.Font.BuilderSansBold, ZIndex=3,
        TextXAlignment=Enum.TextXAlignment.Center,
    })
    -- NOTE: _headerVersionLbl is updated dynamically by the announcement system
    _headerVersionLbl = UI.label(header, {
        Size=UDim2.new(0,Scale.px(240),0,Scale.px(13)),
        Position=UDim2.new(0.5,-Scale.px(120),0.5,Scale.px(1)),
        Text="v5.1.0 · Piano / Drum / Guitar", TextColor3=T.txtDim, TextSize=Scale.fs(8),
        Font=Enum.Font.BuilderSans, ZIndex=3,
        TextXAlignment=Enum.TextXAlignment.Center,
    })

    -- ── RIGHT: MINI  ▼  only (settings & LIST moved to ctrl row icons) ───────
    -- ▼ minimize
    minimizeBtn = UI.btn(header, {
        Size=UDim2.new(0,Scale.px(28),0,Scale.px(26)),
        Position=UDim2.new(1,-Scale.px(36),0.5,-Scale.px(13)),
        BackgroundColor3=T.card, Text="▼", TextSize=Scale.fs(12),
        Font=Enum.Font.BuilderSansBold, TextColor3=T.accent, ZIndex=3,
    })
    UI.corner(minimizeBtn, Scale.px(6))
    UI.stroke(minimizeBtn, T.border, 1)
    UI.hover(minimizeBtn, T.card, Color3.fromRGB(55,30,100))

    -- MINI float
    floatBtn = UI.btn(header, {
        Size=UDim2.new(0,Scale.px(44),0,Scale.px(26)),
        Position=UDim2.new(1,-Scale.px(86),0.5,-Scale.px(13)),
        BackgroundColor3=T.card, Text="MINI", TextSize=Scale.fs(9),
        Font=Enum.Font.BuilderSans, TextColor3=T.neon, ZIndex=3,
    })
    UI.corner(floatBtn, Scale.px(6))
    UI.stroke(floatBtn, T.border, 1)
    UI.hover(floatBtn, T.card, Color3.fromRGB(42,20,88))

    -- Hidden proxy buttons — not visible in the header but still receive
    -- click connections wired elsewhere in the script (settings panel toggle,
    -- browser open/close). The ctrl-row icon buttons call :Activate() on these.
    settingsBtn = UI.btn(mainFrame, {
        Size=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,0),
        Visible=false, Text="", ZIndex=0,
    })
    browseBtn = UI.btn(mainFrame, {
        Size=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,0),
        Visible=false, Text="", ZIndex=0,
    })
end

local songTitleBg=UI.frame(mainFrame,{
    Size=UDim2.new(1,-P8*2,0,Scale.px(36)),
    Position=UDim2.new(0,P8,0,Scale.px(46)),
    BackgroundColor3=T.card,
})
UI.corner(songTitleBg,P8); UI.stroke(songTitleBg,T.border,1)
local songTitleLbl=UI.label(songTitleBg,{
    Size=UDim2.new(1,-P8*2,1,0), Position=UDim2.new(0,P8,0,0),
    Text="No song loaded", TextColor3=T.txtDim, TextSize=Scale.fs(12),
    Font=Enum.Font.BuilderSans, TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd,
})

local progContainer=UI.frame(mainFrame,{
    Size=UDim2.new(0.80,-P8*2,0,Scale.px(16)),
    Position=UDim2.new(0.10,P8,0,Scale.px(94)),
    BackgroundColor3=Color3.fromRGB(0,0,0),
    BackgroundTransparency=0.999,
    Active=true, ZIndex=4,
})
local progTrack=UI.frame(progContainer,{
    Size=UDim2.new(1,0,0,Scale.px(5)),
    Position=UDim2.new(0,0,0.5,-Scale.px(2)),
    BackgroundColor3=T.card,
})
UI.corner(progTrack,Scale.px(3))
local progFill=UI.frame(progTrack,{Size=UDim2.new(0,0,1,0),BackgroundColor3=T.neon})
UI.corner(progFill,Scale.px(3))
UI.gradient(progFill,{ColorSequenceKeypoint.new(0,T.neon),ColorSequenceKeypoint.new(1,T.neonB)},0)
local progHandle=UI.frame(progContainer,{
    Size=UDim2.new(0,Scale.px(16),0,Scale.px(16)),
    Position=UDim2.new(0,-Scale.px(8),0.5,-Scale.px(8)),
    BackgroundColor3=T.white, ZIndex=3,
})
UI.corner(progHandle,999)
UI.stroke(progHandle, T.neon, 2)

do
    local lb=UI.btn(mainFrame,{
        Size=UDim2.new(0,Scale.px(22),0,Scale.px(22)),
        Position=UDim2.new(0.90,P8+Scale.px(4),0,Scale.px(94)-Scale.px(3)),
        BackgroundColor3=T.card, Text="🔓", TextSize=Scale.fs(12),
        Font=Enum.Font.BuilderSans, ZIndex=6,
    })
    UI.corner(lb,Scale.px(6))
    UI.stroke(lb,T.border,1)
    lb.MouseButton1Click:Connect(function()
        State.seekLocked = not State.seekLocked
        if State.seekLocked then
            lb.Text="🔒"; tw(lb,0.15,{BackgroundColor3=T.purpleMid})
            for _,s in ipairs(lb:GetChildren()) do
                if s:IsA("UIStroke") then s.Color=T.neon end
            end
            Toast.show("🔒 Seek locked","warning",1.5)
        else
            lb.Text="🔓"; tw(lb,0.15,{BackgroundColor3=T.card})
            for _,s in ipairs(lb:GetChildren()) do
                if s:IsA("UIStroke") then s.Color=T.border end
            end
            Toast.show("🔓 Seek unlocked","info",1.5)
        end
    end)
end

local timeLbl=UI.label(mainFrame,{
    Size=UDim2.new(1,-P8*2,0,Scale.px(17)),
    Position=UDim2.new(0,P8,0,Scale.px(116)),
    Text="0:00 / 0:00", TextColor3=T.txtDim, TextSize=Scale.fs(11),
    Font=Enum.Font.BuilderSans, TextXAlignment=Enum.TextXAlignment.Center,
})

local playBtn, stopBtn, loopBtn
do
    local ctrlFrame=UI.frame(mainFrame,{
        Size=UDim2.new(1,-P8*2,0,Scale.px(60)),
        Position=UDim2.new(0,P8,0,Scale.px(138)),
        BackgroundTransparency=1, ClipsDescendants=false,
    })

    -- Center sub-frame holds the 3 main buttons via UIListLayout
    local centerCtrl=UI.frame(ctrlFrame,{
        Size=UDim2.new(0,Scale.px(174),1,0),
        Position=UDim2.new(0.5,-Scale.px(87),0,0),
        BackgroundTransparency=1,
    })
    do
        local cl=Instance.new("UIListLayout",centerCtrl)
        cl.FillDirection=Enum.FillDirection.Horizontal
        cl.HorizontalAlignment=Enum.HorizontalAlignment.Center
        cl.VerticalAlignment=Enum.VerticalAlignment.Center
        cl.Padding=UDim.new(0,Scale.px(12))
    end
    local CTRL_SZ = 50  -- all buttons same size
    local function mkCtrl(imgId, fallback, basCol, accentCol)
        local b = UI.imgBtn(centerCtrl, {
            Size=UDim2.new(0,Scale.px(CTRL_SZ),0,Scale.px(CTRL_SZ)),
            BackgroundColor3=basCol, TextColor3=accentCol,
            TextSize=Scale.fs(13), ClipsDescendants=true,
        }, imgId, fallback, 0.58)
        UI.corner(b, Scale.px(14))
        local _cs = UI.stroke(b, Color3.new(accentCol.R*0.55, accentCol.G*0.55, accentCol.B*0.55), 1.5)
        local hov = Color3.new(
            math.min(basCol.R + accentCol.R*0.22, 1),
            math.min(basCol.G + accentCol.G*0.22, 1),
            math.min(basCol.B + accentCol.B*0.22, 1)
        )
        UI.hover(b, basCol, hov)
        UI.ripple(b, accentCol)
        if BtnStore[b] then BtnStore[b].img.ImageColor3 = accentCol end
        return b
    end
    playBtn = mkCtrl(IMG.play,    LABEL.play,    T.btnPlay, T.btnPlayAccent)
    stopBtn = mkCtrl(IMG.stop,    LABEL.stop,    T.btnStop, T.btnStopAccent)
    loopBtn = mkCtrl(IMG.loopOff, LABEL.loopOff, T.btnLoop, T.btnLoopAccent)

    -- ── Side icon buttons: ⚙ left of play, 📁 right of loop ─────────────────
    local SIDE_SZ    = 36
    local sideBase   = Color3.fromRGB(28, 14, 60)     -- deep purple base
    local sideAccent = T.purpleLight                   -- Color3.fromRGB(170,95,255)
    local sideHov    = Color3.fromRGB(52, 26, 108)
    local function mkSide(imgId, fallback, xOffset)
        local b = UI.imgBtn(ctrlFrame, {
            Size=UDim2.new(0,Scale.px(SIDE_SZ),0,Scale.px(SIDE_SZ)),
            Position=UDim2.new(0.5,Scale.px(xOffset),0.5,-Scale.px(SIDE_SZ/2)),
            BackgroundColor3=sideBase, TextColor3=sideAccent,
            TextSize=Scale.fs(11), ClipsDescendants=true, ZIndex=2,
        }, imgId, fallback, 0.62)
        UI.corner(b, Scale.px(14))
        local _ss = UI.stroke(b, Color3.new(sideAccent.R*0.55, sideAccent.G*0.55, sideAccent.B*0.55), 1.5)
        UI.hover(b, sideBase, sideHov)
        UI.ripple(b, sideAccent)
        if BtnStore[b] then BtnStore[b].img.ImageColor3 = sideAccent end
        return b
    end
    -- Settings icon: left gap (center-offset = -(87 + 12 + 44) = -143)
    local ctrlSettingsIcon = mkSide(IMG.settings, "⚙",  -(87 + 24 + SIDE_SZ))
    ctrlSettingsIcon.MouseButton1Click:Connect(function()
        if State._settingsToggle then State._settingsToggle() end
    end)
    -- Folder/List icon: right gap (center-offset = +(87 + 24) = +111)
    local ctrlFolderIcon   = mkSide(IMG.folder,   "LIST", 87 + 24)
    ctrlFolderIcon.MouseButton1Click:Connect(function()
        if State._browseToggle then State._browseToggle() end
    end)
end

local bpmRow=UI.frame(mainFrame,{
    Size=UDim2.new(1,-P8*2,0,Scale.px(38)),
    Position=UDim2.new(0,P8,0,Scale.px(202)),
    BackgroundColor3=T.card,
})
UI.corner(bpmRow,P8); UI.stroke(bpmRow,T.border,1)
UI.label(bpmRow,{
    Size=UDim2.new(0,Scale.px(44),1,0), Position=UDim2.new(0,P8,0,0),
    Text="BPM", TextColor3=T.neonY, TextSize=Scale.fs(13),
    Font=Enum.Font.BuilderSans, TextXAlignment=Enum.TextXAlignment.Left,
})
local bpmInput=UI.input(bpmRow,{
    Size=UDim2.new(0,Scale.px(56),0,Scale.px(26)),
    Position=UDim2.new(0,Scale.px(72),0.5,-Scale.px(13)),
    BackgroundColor3=T.panel, Text="120", TextSize=Scale.fs(13),
    Font=Enum.Font.BuilderSans, TextColor3=T.txtDim, TextXAlignment=Enum.TextXAlignment.Center,
    TextEditable=false,
})
UI.corner(bpmInput,Scale.px(6)); UI.stroke(bpmInput,T.border,1)

do
    local function bpmStep(delta)
        if State.usetempo then
            Toast.show("⚠ BPM ±1 only works in Manual mode","warning",2)
            return
        end
        local v = math.max(1, math.min(999, State.manualBpm + delta))
        -- updateBPM and bpmDisplayLbl are local to a later scope — nil here.
        -- Set every reachable field immediately; the 100ms status loop will
        -- flush bpmDisplayLbl and call updateProgressUI() within one tick.
        State.manualBpm=v; State.lastManualBpm=v; State.currentBpm=v
        bpmInput.Text=tostring(v)
        if State.drumMode then
            State.songDuration = State.drumBaseDuration * (120 / v)
        else
            State.songDuration = calcDuration(State.notes, v, false)
        end
        Toast.show("BPM → "..v,"info",0.8)
    end
    local mb=UI.btn(bpmRow,{
        Size=UDim2.new(0,Scale.px(22),0,Scale.px(26)),
        Position=UDim2.new(0,Scale.px(48),0.5,-Scale.px(13)),
        BackgroundColor3=T.card, Text="-", TextSize=Scale.fs(15),
        Font=Enum.Font.BuilderSansBold, TextColor3=T.neonY, ZIndex=5,
    })
    UI.corner(mb,Scale.px(6)); UI.stroke(mb,T.border,1)
    UI.hover(mb,T.card,Color3.fromRGB(50,35,10))
    mb.MouseButton1Click:Connect(function() bpmStep(-1) end)
    local pb=UI.btn(bpmRow,{
        Size=UDim2.new(0,Scale.px(22),0,Scale.px(26)),
        Position=UDim2.new(0,Scale.px(130),0.5,-Scale.px(13)),
        BackgroundColor3=T.card, Text="+", TextSize=Scale.fs(15),
        Font=Enum.Font.BuilderSansBold, TextColor3=T.neonY, ZIndex=5,
    })
    UI.corner(pb,Scale.px(6)); UI.stroke(pb,T.border,1)
    UI.hover(pb,T.card,Color3.fromRGB(50,35,10))
    pb.MouseButton1Click:Connect(function() bpmStep(1) end)
end

local bpmBlocker=UI.btn(bpmRow,{
    Size=UDim2.new(0,Scale.px(56),0,Scale.px(26)),
    Position=UDim2.new(0,Scale.px(72),0.5,-Scale.px(13)),
    BackgroundTransparency=1, Text="", ZIndex=10,
    AutoButtonColor=false, Visible=true,  -- visible by default since Auto is ON at startup
})

local autoBtn=UI.btn(bpmRow,{
    Size=UDim2.new(0,Scale.px(82),0,Scale.px(26)),
    Position=UDim2.new(1,-Scale.px(90),0.5,-Scale.px(13)),
    BackgroundColor3=Color3.fromRGB(20,60,35), Text="Auto: ON", TextSize=Scale.fs(11),
    Font=Enum.Font.BuilderSans, TextColor3=T.neonG,
})
UI.corner(autoBtn,Scale.px(6)); UI.hover(autoBtn,Color3.fromRGB(20,60,35),Color3.fromRGB(28,80,48))

local recBtn, antilagBtn, helpBtn, reloadBtn
do
    local utilRow=UI.frame(mainFrame,{
        Size=UDim2.new(1,-P8*2,0,Scale.px(38)),
        Position=UDim2.new(0,P8,0,Scale.px(248)),
        BackgroundTransparency=1, ClipsDescendants=true,
    })
    do
        local ul=Instance.new("UIListLayout",utilRow)
        ul.FillDirection=Enum.FillDirection.Horizontal
        ul.HorizontalAlignment=Enum.HorizontalAlignment.Center
        ul.VerticalAlignment=Enum.VerticalAlignment.Center
        ul.Padding=UDim.new(0,Scale.px(4))
    end
    local function mkUtil(text, basCol, accentCol)
        local bW=math.floor((MFW-P8*2-Scale.px(4)*3)/4)
        local hoverBg = Color3.new(
            math.min(basCol.R + accentCol.R*0.22, 1),
            math.min(basCol.G + accentCol.G*0.22, 1),
            math.min(basCol.B + accentCol.B*0.22, 1)
        )
        local b=UI.btn(utilRow,{
            Size=UDim2.new(0,bW,0,Scale.px(34)),  -- bW already in pixels
            BackgroundColor3=basCol, Text=text, TextSize=Scale.fs(11),
            Font=Enum.Font.BuilderSansBold, TextColor3=accentCol, ClipsDescendants=true,
        })
        UI.corner(b,Scale.px(8))
        UI.stroke(b, Color3.new(accentCol.R*0.6, accentCol.G*0.6, accentCol.B*0.6), 1)
        UI.hover(b, basCol, hoverBg); UI.ripple(b, accentCol)
        return b
    end
    recBtn     = mkUtil("REC",    T.btnStop,   T.btnStopAccent)
    recBtn.TextSize  = Scale.fs(10)  -- slightly smaller so "REC:\nOn" fits on two lines
    antilagBtn = mkUtil("LAG",    T.btnLag,    T.btnLagAccent)
    helpBtn    = mkUtil("HELP",   T.btnHelp,   T.btnHelpAccent)
    reloadBtn  = mkUtil("RELOAD", T.btnReload, T.btnReloadAccent)
end

-- Centred in the gap between the "+" button (bpmRow x=152) and autoBtn (bpmRow right-90).
-- bpmRow starts at P8 from mainFrame left, so:
--   left edge  = P8 + Scale.px(152)
--   right edge = mainFrame.Width - P8 - Scale.px(90)
local bpmStatusLbl=UI.label(mainFrame,{
    Size=UDim2.new(1,-(P8+Scale.px(152))-(P8+Scale.px(90)),0,Scale.px(38)),
    Position=UDim2.new(0,P8+Scale.px(152),0,Scale.px(202)),
    Text="Ready", TextColor3=T.txtDim, TextSize=Scale.fs(12),
    Font=Enum.Font.BuilderSansBold, TextXAlignment=Enum.TextXAlignment.Center,
    BackgroundTransparency=1, ZIndex=5,
})

local bpmDisplayLbl=UI.label(mainFrame,{
    Size=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,0),
    Text="BPM: 120", Visible=false,
})
local statusLbl=UI.label(mainFrame,{
    Size=UDim2.new(0,0,0,0), Position=UDim2.new(0,0,0,0),
    Text="Ready", Visible=false,
})

local browserPanel  -- forward-declared; BPW/BPH scoped below to save local slots
do
    local BPW,BPH=getBrowserSize()
    browserPanel=UI.frame(gui,{
        Size=UDim2.new(0,BPW,0,BPH),
        Position=UDim2.new(0,Scale.px(20),0,Scale.px(20)),
        BackgroundColor3=T.bg, Visible=false, ZIndex=5, ClipsDescendants=true,
    })
end
UI.corner(browserPanel,P12); UI.stroke(browserPanel,T.neonB,2)
UI.gradient(browserPanel,{
    ColorSequenceKeypoint.new(0,T.bg),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(20,10,45)),
},120)

local bpCloseBtn  -- forward-declared; assigned inside do below
do
    local bpHeader=UI.frame(browserPanel,{Size=UDim2.new(1,0,0,Scale.px(38)),BackgroundColor3=T.panel,ZIndex=6,ClipsDescendants=true})
    UI.corner(bpHeader,P8)
    UI.gradient(bpHeader,{ColorSequenceKeypoint.new(0,T.purpleDeep),ColorSequenceKeypoint.new(1,T.purpleMid)},0)
    UI.label(bpHeader,{
        Size=UDim2.new(0.6,0,1,0), Position=UDim2.new(0,P8,0,0),
        Text="Song Library", TextColor3=T.accent, TextSize=Scale.fs(16),
        Font=Enum.Font.BuilderSansBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=6,
    })
    bpCloseBtn=UI.btn(bpHeader,{
        Size=UDim2.new(0,Scale.px(52),0,Scale.px(26)),
        Position=UDim2.new(1,-Scale.px(58),0.5,-Scale.px(13)),
        BackgroundColor3=T.neonR, Text="CLOSE", TextSize=Scale.fs(10),
        Font=Enum.Font.BuilderSans, ZIndex=6,
    })
    UI.corner(bpCloseBtn,Scale.px(7))
    UI.stroke(bpCloseBtn, Color3.fromRGB(130, 40, 60), 1)
    UI.hover(bpCloseBtn,T.neonR,Color3.fromRGB(255,100,130))
end

local presetDropBg=UI.frame(browserPanel,{
    Size=UDim2.new(0.32,-P8,0,Scale.px(30)),
    Position=UDim2.new(0,P8,0,Scale.px(46)),
    BackgroundColor3=T.card, ZIndex=22,
})
UI.corner(presetDropBg,P8)
do local s=Instance.new("UIStroke",presetDropBg); s.Color=T.neon; s.Thickness=2 end
local presetDropBtn=UI.btn(presetDropBg,{
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="★ Preset ▾", TextSize=Scale.fs(11),
    Font=Enum.Font.BuilderSansBold, TextColor3=T.accent, ZIndex=22,
})

local uploadedDropBg=UI.frame(browserPanel,{
    Size=UDim2.new(0.33,-Scale.px(4),0,Scale.px(30)),
    Position=UDim2.new(0.33,Scale.px(2),0,Scale.px(46)),
    BackgroundColor3=T.card, ZIndex=22,
})
UI.corner(uploadedDropBg,P8)
do local s=Instance.new("UIStroke",uploadedDropBg); s.Color=T.neonG; s.Thickness=2 end
local uploadedDropBtn=UI.btn(uploadedDropBg,{
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="⬆ Uploaded ▾", TextSize=Scale.fs(10),
    Font=Enum.Font.BuilderSansBold, TextColor3=T.neonG, ZIndex=22,
})

local DrumBrowserUI = {}
do
    DrumBrowserUI.dropBg=UI.frame(browserPanel,{
        Size=UDim2.new(0.32,-P8,0,Scale.px(30)),
        Position=UDim2.new(0,P8,0,Scale.px(46)),
        BackgroundColor3=T.card, ZIndex=23, Visible=false,
    })
    UI.corner(DrumBrowserUI.dropBg,P8)
    do local s=Instance.new("UIStroke",DrumBrowserUI.dropBg); s.Color=Color3.fromRGB(255,140,20); s.Thickness=2 end
    DrumBrowserUI.dropBtn=UI.btn(DrumBrowserUI.dropBg,{
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Text="🥁 Presets ▾", TextSize=Scale.fs(11),
        Font=Enum.Font.BuilderSansBold, TextColor3=Color3.fromRGB(255,165,40), ZIndex=23,
    })
    DrumBrowserUI.menu=UI.scroll(browserPanel,{
        Size=UDim2.new(1,-P8*2,0,0),
        Position=UDim2.new(0,P8,0,Scale.px(78)),
        BackgroundColor3=T.panel, Visible=false, ZIndex=26, ClipsDescendants=true,
    })
    UI.corner(DrumBrowserUI.menu,P8); UI.stroke(DrumBrowserUI.menu,Color3.fromRGB(255,140,20),1)
end

-- Drum Uploaded tab (mirrors Piano's Uploaded tab; shown only in drum mode)
DrumBrowserUI.uploadedDropBg=UI.frame(browserPanel,{
    Size=UDim2.new(0.33,-Scale.px(4),0,Scale.px(30)),
    Position=UDim2.new(0.33,Scale.px(2),0,Scale.px(46)),
    BackgroundColor3=T.card, ZIndex=23, Visible=false,
})
UI.corner(DrumBrowserUI.uploadedDropBg,P8)
do local s=Instance.new("UIStroke",DrumBrowserUI.uploadedDropBg); s.Color=T.neonG; s.Thickness=2 end
DrumBrowserUI.uploadedDropBtn=UI.btn(DrumBrowserUI.uploadedDropBg,{
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="⬆ Drum Uploads ▾", TextSize=Scale.fs(10),
    Font=Enum.Font.BuilderSansBold, TextColor3=T.neonG, ZIndex=23,
})
DrumBrowserUI.uploadedMenu=UI.scroll(browserPanel,{
    Size=UDim2.new(1,-P8*2,0,0),
    Position=UDim2.new(0,P8,0,Scale.px(78)),
    BackgroundColor3=T.panel, Visible=false, ZIndex=26, ClipsDescendants=true,
})
UI.corner(DrumBrowserUI.uploadedMenu,P8); UI.stroke(DrumBrowserUI.uploadedMenu,T.neonG,1)
DrumBrowserUI.uploadedMenuOpen=false

-- Guitar browser UI (preset + uploaded dropdowns; hidden until guitar mode active)
local GuitarBrowserUI = {}
do
    local gtrGold = Color3.fromRGB(220,165,40)
    GuitarBrowserUI.dropBg=UI.frame(browserPanel,{
        Size=UDim2.new(0.32,-P8,0,Scale.px(30)),
        Position=UDim2.new(0,P8,0,Scale.px(46)),
        BackgroundColor3=T.card, ZIndex=23, Visible=false,
    })
    UI.corner(GuitarBrowserUI.dropBg,P8)
    do local s=Instance.new("UIStroke",GuitarBrowserUI.dropBg); s.Color=gtrGold; s.Thickness=2 end
    GuitarBrowserUI.dropBtn=UI.btn(GuitarBrowserUI.dropBg,{
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Text="🎸 Presets ▾", TextSize=Scale.fs(11),
        Font=Enum.Font.BuilderSansBold, TextColor3=gtrGold, ZIndex=23,
    })
    GuitarBrowserUI.menu=UI.scroll(browserPanel,{
        Size=UDim2.new(1,-P8*2,0,0),
        Position=UDim2.new(0,P8,0,Scale.px(78)),
        BackgroundColor3=T.panel, Visible=false, ZIndex=26, ClipsDescendants=true,
    })
    UI.corner(GuitarBrowserUI.menu,P8); UI.stroke(GuitarBrowserUI.menu,gtrGold,1)
    GuitarBrowserUI.menuOpen=false

    GuitarBrowserUI.uploadedDropBg=UI.frame(browserPanel,{
        Size=UDim2.new(0.33,-Scale.px(4),0,Scale.px(30)),
        Position=UDim2.new(0.33,Scale.px(2),0,Scale.px(46)),
        BackgroundColor3=T.card, ZIndex=23, Visible=false,
    })
    UI.corner(GuitarBrowserUI.uploadedDropBg,P8)
    do local s=Instance.new("UIStroke",GuitarBrowserUI.uploadedDropBg); s.Color=T.neonG; s.Thickness=2 end
    GuitarBrowserUI.uploadedDropBtn=UI.btn(GuitarBrowserUI.uploadedDropBg,{
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Text="⬆ Guitar Uploads ▾", TextSize=Scale.fs(10),
        Font=Enum.Font.BuilderSansBold, TextColor3=T.neonG, ZIndex=23,
    })
    GuitarBrowserUI.uploadedMenu=UI.scroll(browserPanel,{
        Size=UDim2.new(1,-P8*2,0,0),
        Position=UDim2.new(0,P8,0,Scale.px(78)),
        BackgroundColor3=T.panel, Visible=false, ZIndex=26, ClipsDescendants=true,
    })
    UI.corner(GuitarBrowserUI.uploadedMenu,P8); UI.stroke(GuitarBrowserUI.uploadedMenu,T.neonG,1)
    GuitarBrowserUI.uploadedMenuOpen=false
end

local localDropBg=UI.frame(browserPanel,{
    Size=UDim2.new(0.33,-P8,0,Scale.px(30)),
    Position=UDim2.new(0.67,Scale.px(2),0,Scale.px(46)),
    BackgroundColor3=T.card, ZIndex=22,
})
UI.corner(localDropBg,P8)
do local s=Instance.new("UIStroke",localDropBg); s.Color=T.btnHelpAccent; s.Thickness=2 end
local localDropBtn=UI.btn(localDropBg,{
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="▶ Local ▾", TextSize=Scale.fs(11),
    Font=Enum.Font.BuilderSansBold, TextColor3=T.btnHelpAccent, ZIndex=22,
})

local presetMenu=UI.scroll(browserPanel,{
    Size=UDim2.new(1,-P8*2,0,0),
    Position=UDim2.new(0,P8,0,Scale.px(78)),
    BackgroundColor3=T.panel, Visible=false, ZIndex=25, ClipsDescendants=true,
})
UI.corner(presetMenu,P8); UI.stroke(presetMenu,T.neon,1)

local catMenu=UI.scroll(browserPanel,{
    Size=UDim2.new(1,-P8*2,0,0),
    Position=UDim2.new(0,P8,0,Scale.px(78)),
    BackgroundColor3=T.panel, Visible=false, ZIndex=25, ClipsDescendants=true,
})
UI.corner(catMenu,P8); UI.stroke(catMenu,T.btnHelpAccent,1)

local uploadedMenu=UI.scroll(browserPanel,{
    Size=UDim2.new(1,-P8*2,0,0),
    Position=UDim2.new(0,P8,0,Scale.px(78)),
    BackgroundColor3=T.panel, Visible=false, ZIndex=25, ClipsDescendants=true,
})
UI.corner(uploadedMenu,P8); UI.stroke(uploadedMenu,T.neonG,1)

local searchBg=UI.frame(browserPanel,{
    Size=UDim2.new(1,-P8*2,0,Scale.px(30)),
    Position=UDim2.new(0,P8,0,Scale.px(84)),
    BackgroundColor3=T.card, ZIndex=5,
})
UI.corner(searchBg,P8); UI.stroke(searchBg,T.border,1)
UI.label(searchBg,{
    Size=UDim2.new(0,Scale.px(26),1,0),Position=UDim2.new(0,P8,0,0),
    Text="🔍",TextSize=Scale.fs(13),ZIndex=5, TextColor3=T.txtDim,
})
local searchBox=UI.input(searchBg,{
    Size=UDim2.new(1,-Scale.px(34),1,0), Position=UDim2.new(0,Scale.px(30),0,0),
    BackgroundTransparency=1, Text="", PlaceholderText="Search songs...",
    PlaceholderColor3=T.txtDim, TextColor3=T.txt,
    TextSize=Scale.fs(12), Font=Enum.Font.BuilderSans, ZIndex=5, ClearTextOnFocus=false,
})

songInfoLbl=UI.label(browserPanel,{
    Size=UDim2.new(1,-P8*2,0,Scale.px(18)),
    Position=UDim2.new(0,P8,0,Scale.px(120)),
    Text="Select a category", TextColor3=T.txtDim, TextSize=Scale.fs(11),
    Font=Enum.Font.BuilderSans, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
})

local songList=UI.scroll(browserPanel,{
    Size=UDim2.new(1,-P8*2,1,-Scale.px(142)),
    Position=UDim2.new(0,P8,0,Scale.px(142)),
    BackgroundColor3=T.panel, ZIndex=5,
})
UI.corner(songList,P8)
UI.listLayout(songList,Scale.px(5))
do local p=Instance.new("UIPadding",songList); p.PaddingTop=UDim.new(0,Scale.px(5)) end

local FLW,FLH=getFloatSize()
floatFrame=UI.frame(gui,{
    Size=UDim2.new(0,FLW,0,FLH),
    Position=UDim2.new(0.5,-FLW/2,0,Scale.px(20)),
    BackgroundColor3=T.bg, Visible=false, ZIndex=10, ClipsDescendants=true,
})
UI.corner(floatFrame,P12); UI.stroke(floatFrame,T.neon,2)
UI.gradient(floatFrame,{
    ColorSequenceKeypoint.new(0,T.purpleDeep),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(18,10,42)),
},135)

local ftHomeBtn
do
    local ftHeader=UI.frame(floatFrame,{
        Size=UDim2.new(1,0,0,Scale.px(32)),
        BackgroundColor3=T.panel, ZIndex=10, ClipsDescendants=true,
    })
    UI.corner(ftHeader,P8)
    UI.gradient(ftHeader,{ColorSequenceKeypoint.new(0,T.purpleDeep),ColorSequenceKeypoint.new(1,T.purpleMid)},0)
    -- Full-frame drag: entire mini panel is draggable, clamped to viewport
    UI.makeDraggable(floatFrame,floatFrame)

    UI.label(ftHeader,{
        Size=UDim2.new(0.55,0,1,0), Position=UDim2.new(0,P8,0,0),
        Text="RoMini", TextColor3=T.accent, TextSize=Scale.fs(14),
        Font=Enum.Font.BuilderSansBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=10,
    })
    ftHomeBtn=UI.btn(ftHeader,{
        Size=UDim2.new(0,Scale.px(50),0,Scale.px(22)),
        Position=UDim2.new(1,-Scale.px(56),0.5,-Scale.px(11)),
        BackgroundColor3=T.neonB, Text="HOME", TextSize=Scale.fs(10),
        Font=Enum.Font.BuilderSans, ZIndex=10,
    })
    UI.corner(ftHomeBtn,Scale.px(6)); UI.hover(ftHomeBtn,T.neonB,T.neon)
end

local ftSongLbl=UI.label(floatFrame,{
    Size=UDim2.new(1,-P8*2,0,Scale.px(22)),
    Position=UDim2.new(0,P8,0,Scale.px(36)),
    Text="No song loaded", TextColor3=T.txtDim, TextSize=Scale.fs(12),
    Font=Enum.Font.BuilderSans, TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=10,
})

local ftProgContainer=UI.frame(floatFrame,{
    Size=UDim2.new(0.80,-P8*2,0,Scale.px(16)),
    Position=UDim2.new(0.10,P8,0,Scale.px(64)),
    BackgroundColor3=Color3.fromRGB(0,0,0),
    BackgroundTransparency=0.999,
    Active=true, ZIndex=10,
})
local ftProgTrack=UI.frame(ftProgContainer,{
    Size=UDim2.new(1,0,0,Scale.px(5)),
    Position=UDim2.new(0,0,0.5,-Scale.px(2)),
    BackgroundColor3=T.card, ZIndex=10,
})
UI.corner(ftProgTrack,Scale.px(3))
local ftProgFill=UI.frame(ftProgTrack,{Size=UDim2.new(0,0,1,0),BackgroundColor3=T.neon,ZIndex=10})
UI.corner(ftProgFill,Scale.px(3))
UI.gradient(ftProgFill,{ColorSequenceKeypoint.new(0,T.neon),ColorSequenceKeypoint.new(1,T.neonB)},0)
local ftProgHandle=UI.frame(ftProgContainer,{
    Size=UDim2.new(0,Scale.px(16),0,Scale.px(16)),
    Position=UDim2.new(0,-Scale.px(8),0.5,-Scale.px(8)),
    BackgroundColor3=T.white, ZIndex=12,
})
UI.corner(ftProgHandle,999)
UI.stroke(ftProgHandle, T.neon, 2)

local ftTimeLbl=UI.label(floatFrame,{
    Size=UDim2.new(1,-P8*2,0,Scale.px(15)),
    Position=UDim2.new(0,P8,0,Scale.px(88)),
    Text="0:00 / 0:00", TextColor3=T.txtDim, TextSize=Scale.fs(10),
    Font=Enum.Font.BuilderSans, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=10,
})

local ftStatusLbl=UI.label(floatFrame,{
    Size=UDim2.new(1,-P8*2,0,Scale.px(15)),
    Position=UDim2.new(0,P8,0,Scale.px(104)),
    Text="Ready", TextColor3=T.txtDim, TextSize=Scale.fs(10),
    Font=Enum.Font.BuilderSansBold, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=10,
})

local ftPlayBtn, ftStopBtn, ftLoopBtn, ftRecBtn, ftHelpBtn
do
    local ftCtrlRow=UI.frame(floatFrame,{
        Size=UDim2.new(1,-P8*2,0,Scale.px(44)),
        Position=UDim2.new(0,P8,0,Scale.px(122)),
        BackgroundTransparency=1, ZIndex=10,
    })
    do
        local cl=Instance.new("UIListLayout",ftCtrlRow)
        cl.FillDirection=Enum.FillDirection.Horizontal
        cl.HorizontalAlignment=Enum.HorizontalAlignment.Center
        cl.VerticalAlignment=Enum.VerticalAlignment.Center
        cl.Padding=UDim.new(0,Scale.px(5))
    end
    local ftBtnW = math.floor((FLW - P8*2 - Scale.px(5)*4) / 5)
    local function mkFtBtn(imgId, fallback, basCol, accentCol, w)
        local b = UI.imgBtn(ftCtrlRow, {
            Size=UDim2.new(0,w,0,Scale.px(40)),  -- w is already in pixels, no Scale.px()
            BackgroundColor3=basCol, TextColor3=accentCol,
            TextSize=Scale.fs(11), ZIndex=10,
        }, imgId, fallback, 0.55)
        UI.corner(b, Scale.px(9))
        local _fs = UI.stroke(b, Color3.new(accentCol.R*0.55, accentCol.G*0.55, accentCol.B*0.55), 1.5)
        local hov = Color3.new(
            math.min(basCol.R + accentCol.R*0.22, 1),
            math.min(basCol.G + accentCol.G*0.22, 1),
            math.min(basCol.B + accentCol.B*0.22, 1)
        )
        UI.hover(b, basCol, hov)
        if BtnStore[b] then BtnStore[b].img.ImageColor3 = accentCol end
        return b
    end
    ftPlayBtn = mkFtBtn(IMG.play,    LABEL.play,    T.btnPlay,   T.btnPlayAccent,  ftBtnW)
    ftStopBtn = mkFtBtn(IMG.stop,    LABEL.stop,    T.btnStop,   T.btnStopAccent,  ftBtnW)
    ftLoopBtn = mkFtBtn(IMG.loopOff, LABEL.loopOff, T.btnLoop,   T.btnLoopAccent,  ftBtnW)
    ftRecBtn  = mkFtBtn(nil,         "REC",         T.btnStop,   T.btnStopAccent,  ftBtnW)
    ftHelpBtn = mkFtBtn(nil,         "HELP",        T.btnHelp,   T.btnHelpAccent,  ftBtnW)
end

local helpPanel
local helpCloseBtn  -- referenced at the bottom of the script
do
    helpPanel = UI.frame(gui, {
        Size     = UDim2.new(0.62, 0, 0.82, 0),
        Position = UDim2.new(0.19, 0, 0.09, 0),
        BackgroundColor3 = T.panel, Visible = false, ZIndex = 30, ClipsDescendants = true,
    })
    UI.corner(helpPanel, P12)
    UI.stroke(helpPanel, T.neon, 2)
    -- Full-frame drag: entire help panel is draggable, clamped to viewport
    UI.makeDraggable(helpPanel, helpPanel)

    local hHdr = UI.frame(helpPanel, {
        Size = UDim2.new(1,0,0,Scale.px(54)),
        BackgroundColor3 = T.purpleDeep, ZIndex = 31,
    })
    UI.corner(hHdr, P12)
    UI.gradient(hHdr, {ColorSequenceKeypoint.new(0,T.purpleDeep), ColorSequenceKeypoint.new(1,T.purpleMid)}, 0)

    local iCircle = UI.frame(hHdr, {
        Size = UDim2.new(0,Scale.px(36),0,Scale.px(36)),
        Position = UDim2.new(0,Scale.px(10),0.5,-Scale.px(18)),
        BackgroundColor3 = T.purpleMid, ZIndex = 32,
    })
    UI.corner(iCircle, Scale.px(10))
    UI.stroke(iCircle, T.neon, 1.5)
    UI.label(iCircle, {
        Size = UDim2.new(1,0,1,0), Text = "♪",
        TextColor3 = T.white, TextSize = Scale.fs(18),
        Font = Enum.Font.BuilderSansBold, ZIndex = 33,
    })

    UI.label(hHdr, {
        Size = UDim2.new(1,-Scale.px(130),0,Scale.px(22)),
        Position = UDim2.new(0,Scale.px(54),0,Scale.px(7)),
        Text = "RoMidi Help", TextColor3 = T.accent, TextSize = Scale.fs(14),
        Font = Enum.Font.BuilderSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32,
    })
    -- NOTE: _helpVersionLbl is updated dynamically by the announcement system
    _helpVersionLbl = UI.label(hHdr, {
        Size = UDim2.new(1,-Scale.px(130),0,Scale.px(16)),
        Position = UDim2.new(0,Scale.px(54),0,Scale.px(30)),
        Text = "v5.1.0 - Piano/Drum/Guitar Edition", TextColor3 = T.txtDim, TextSize = Scale.fs(10),
        Font = Enum.Font.BuilderSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32,
    })

    helpCloseBtn = UI.btn(hHdr, {
        Size = UDim2.new(0,Scale.px(72),0,Scale.px(28)),
        Position = UDim2.new(1,-Scale.px(80),0.5,-Scale.px(14)),
        BackgroundColor3 = T.btnStop, Text = "✕  CLOSE", TextSize = Scale.fs(10),
        Font = Enum.Font.BuilderSansBold, TextColor3 = T.white, ZIndex = 32,
    })
    UI.corner(helpCloseBtn, Scale.px(7))
    UI.hover(helpCloseBtn, T.btnStop, Color3.fromRGB(255,120,150))

    local HDR_H = Scale.px(54)
    local aScroll = UI.scroll(helpPanel, {
        Size = UDim2.new(1,0,1,-HDR_H),
        Position = UDim2.new(0,0,0,HDR_H),
        BackgroundTransparency = 1, ZIndex = 31,
        ScrollBarThickness = Scale.px(3), ScrollBarImageColor3 = T.neon,
    })
    do
        local al = Instance.new("UIListLayout", aScroll)
        al.Padding = UDim.new(0,Scale.px(5)); al.SortOrder = Enum.SortOrder.LayoutOrder
        al:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            aScroll.CanvasSize = UDim2.new(0,0,0, al.AbsoluteContentSize.Y + Scale.px(14))
        end)
        local ap = Instance.new("UIPadding", aScroll)
        ap.PaddingLeft = UDim.new(0,Scale.px(8)); ap.PaddingRight = UDim.new(0,Scale.px(8))
        ap.PaddingTop = UDim.new(0,Scale.px(8)); ap.PaddingBottom = UDim.new(0,Scale.px(8))
    end

    local UPLOADER_URL      = "https://pandahub-romidi.vercel.app/upload.html"
    local DRUM_UPLOADER_URL = "https://pandahub-romidi.vercel.app/upload.html"
    local GTR_UPLOADER_URL  = "https://pandahub-romidi.vercel.app/upload.html"
    local ROW_H  = Scale.px(26)
    local BTN_H  = Scale.px(30)
    local HDR_RH = Scale.px(40)

    local SEC = {
        { title="GETTING STARTED",  col=T.neon,          items={
            "Run the script → the main panel appears top-left",
            "Drag anywhere on the panel to reposition it",
            "Press LIST to open the Song Browser sidebar",
            "Tap any song card to instantly load it",
            "Adjust BPM manually or enable Auto BPM",
            "Press ▶ PLAY — keys fire automatically!",
            "Press MINI to collapse to the compact player",
            "Switch modes: Piano 🎹 · Drum 🥁 · Guitar 🎸 via ⚙ Settings",
            "Tip: enable REC mode for clean video recordings",
        }},
        { title="DRAGGING & UI LAYOUT", col=T.neonB,      items={
            "All panels are fully draggable — grab anywhere",
            "Drag the main panel from any empty area",
            "Drag the MINI player from any part of it",
            "Drag the Help panel (this one!) to move it",
            "Drag the ⚙ Settings panel from any area",
            "Panels are clamped — they can't leave the screen",
            "Browser sidebar follows main panel position",
        }},
        { title="SONG BROWSER",     col=T.purpleLight,   items={
            "★ Preset — built-in songs, ready to play",
            "⬆ Uploaded — community MIDIs by category",
            "▶ Local — your own files from executor workspace",
            "♥ Favorites — starred songs, saved across reloads",
            "🕐 Recent — last 20 songs you played",
            "Each mode (Piano / Drum / Guitar) has its own browser tabs",
            "Search bar filters any active list in real time",
            "Tap a card to load · tap ♥ to favourite a song",
            "Drum browser shows .drm files · Guitar shows .gtr files",
        }},
        { title="UPLOADING SONGS",  col=T.neonG,         items={
            "Submit your own MIDI, Drum, or Guitar files to the library:",
            {btn=true, label="🎹  Copy MIDI Uploader",   url=UPLOADER_URL},
            {btn=true, label="🥁  Copy Drum Uploader",   url=DRUM_UPLOADER_URL},
            {btn=true, label="🎸  Copy Guitar Uploader", url=GTR_UPLOADER_URL},
            "Piano uploads: .mid / .midi format",
            "Drum uploads: .drm format only",
            "Guitar uploads: .gtr format only",
            "Choose the correct category before uploading",
            "Goes live for all users within 1–10 minutes",
        }},
        { title="PLAYBACK CONTROLS",col=T.btnPlayAccent, items={
            "▶ PLAY — start from current position",
            "⏸ PAUSE — freeze; press PLAY again to resume",
            "⏹ STOP — stop and reset to the beginning",
            "🔁 LOOP — auto-restart when the song ends",
            "Progress bar — drag to seek anywhere in the song",
            "MINI — collapse to the compact floating mini-player",
            "HOME (in MINI) — return to the full main panel",
            "LIST — open or close the Song Browser sidebar",
            "Minimize ▼ — shrink main panel to just the header",
        }},
        { title="BPM & TIMING",     col=T.neonY,         items={
            "Auto BPM ON — follows tempo events embedded in the file",
            "Auto BPM OFF — your manual BPM field controls speed",
            "Tap the BPM number to type a custom value",
            "Lower BPM = slower playback · Higher = faster",
            "Complex songs with tempo changes need Auto BPM",
            "BPM Sway (in Settings) gently varies tempo over time",
        }},
        { title="SETTINGS PANEL",   col=T.accent,        items={
            "Open with the ⚙ gear icon in the main panel header",
            "Drag anywhere on the Settings panel to move it",
            "── INSTRUMENT MODES ──",
            "Piano 🎹 — presses Virtual Piano keys (default mode)",
            "Drum 🥁 — triggers Roblox drum pad buttons",
            "Guitar 🎸 — plays the 6-string fretboard key layout",
            "61 Keys — 5-octave wrap mode, C2–C7 (piano only)",
            "88 Keys — full MIDI range 21–108, Ctrl+key combos (piano only)",
            "── PIANO HUMANIZATION ──",
            "Hand Sim — staggers simultaneous notes slightly",
            "Natural Chord — human-like stagger: keys press/release slightly apart",
            "Hand Split — play only Left ✋ (bass <C4) or Right 🤚 (treble ≥C4) hand",
            "Timing Jitter — adds a small random delay per note",
            "Note Length — varies how long each note is held",
            "Hand Drift — shifts timing gradually left or right",
            "Miss Chance — randomly skips notes (human feel)",
            "BPM Sway — gently varies tempo over time",
            "Flip Sway — reverses the sway direction",
            "── DRUM HUMANIZATION ──",
            "Timing Jitter — randomises hit timing slightly",
            "Miss Chance — occasionally drops a drum hit",
            "BPM Sway — adds subtle tempo groove",
            "── GUITAR HUMANIZATION ──",
            "Strum Spread — cascades chord notes like a real strum",
            "Fret Lag — fretting hand arrives slightly late (always +)",
            "Mute Chance — randomly buzzes/mutes a string",
            "Pick Articul. — shortens note ring time (pick release)",
            "Timing Jitter — pick timing imprecision ±ms",
            "Miss Chance — randomly skips a pick strike",
            "BPM Sway — adds natural groove fluctuation",
            "── GENERAL ──",
            "↩ Reset — restores all humanization defaults",
            "💾 Save — writes your settings to settings.json",
        }},
        { title="DRUM MODE 🥁",     col=Color3.fromRGB(255,165,40), items={
            "Switch to Drum mode via ⚙ Settings → 🥁 Drum",
            "The browser switches to show .drm drum files",
            "Preset tab — built-in drum patterns ready to play",
            "Uploaded tab — community drum songs",
            "Local .drm files load from your executor workspace",
            "Drum mode uses its own Favorites and Recent lists",
            "Auto BPM works with drum files just like piano",
            "88 Keys toggle is disabled in Drum mode",
            "Switch back to Piano at any time — song position resets",
        }},
        { title="GUITAR MODE 🎸",   col=Color3.fromRGB(220,165,40), items={
            "Switch to Guitar mode via ⚙ Settings → 🎸 Guitar",
            "The browser switches to show .gtr guitar files",
            "Preset tab — built-in guitar songs ready to play",
            "Uploaded tab — community guitar songs",
            "Local .gtr files load from your executor workspace",
            "Guitar mode uses its own Favorites and Recent lists",
            "Guitar keys use the 6-string × 13-fret fretboard layout",
            "88 Keys toggle is disabled in Guitar mode",
            "Humanization is guitar-specific (strum, fret lag, mute)",
            "Switch back to Piano at any time — song position resets",
        }},
        { title="RECORD MODE",      col=T.neonR,         items={
            "Press REC → a setup panel opens to configure options",
            "Delay — seconds to count down before playback starts (0–60)",
            "Visible Countdown — show or hide the on-screen overlay",
            "Bring back UI after song ends — auto-restore the panel",
            "  ✓ checked → UI returns automatically when the song ends",
            "  ✕ unchecked → UI stays hidden; use triple-tap to restore",
            "Press PLAY → UI hides, countdown runs, then song plays",
            "Use the countdown to frame your camera angle",
            "Triple-tap the screen to restore the UI at any time",
            "Triple-tap works during the countdown AND during playback",
            "STOP always restores the UI automatically regardless of settings",
            "All toast notifications are suppressed during REC",
            "Works in Piano, Drum, and Guitar modes",
            "Perfect for clean video captures with no HUD clutter",
        }},
        { title="LOCAL FILES",      col=T.btnHelpAccent, items={
            "Piano: put .mid / .smf files in your executor workspace",
            "Drum: put .drm files in a separate workspace folder",
            "Guitar: put .gtr files in a separate workspace folder",
            "Subfolders become category labels in the browser",
            "Example: workspace/Songs/Anime/track.mid → 'Anime'",
            "Press RELOAD after adding or removing files",
            "Browse local files in the ▶ Local browser tab",
            "Files stay on your device — never uploaded anywhere",
        }},
        { title="FAVORITES & RECENT",col=Color3.fromRGB(240,120,160), items={
            "Tap ♥ on any song card to add it to Favorites",
            "Tap ♥ again to remove it from Favorites",
            "Favorites are saved — they survive script reloads",
            "Recent automatically saves your last 20 played songs",
            "Piano, Drum, and Guitar each have separate lists",
            "Both lists appear inside the Song Browser",
            "Favorites sorted A–Z · Recent sorted by last play time",
        }},
        { title="TIPS & UTILITIES",  col=Color3.fromRGB(60,210,175), items={
            "LAG — runs an anti-lag routine to improve performance",
            "RELOAD — rescans your local MIDI / Drum / Guitar folder",
            "Progress bar works in both Main and MINI mode",
            "Triple-tap screen to restore UI hidden by REC (countdown too)",
            "Uploaded songs preload silently in the background",
            "BPM, humanization settings and favorites all persist",
            "Minimize ▼ collapses main panel to a slim header bar",
            "Panels snap back in-bounds if the viewport is resized",
            "Guitar strum cluster resets automatically on loop restart",
        }},
    }

    for si = 1, #SEC do
        local sec = SEC[si]
        local open = false

        local contentH = Scale.px(6) -- top padding
        for _, item in ipairs(sec.items) do
            contentH = contentH + (type(item)=="table" and item.btn and BTN_H or ROW_H) + Scale.px(4)
        end
        contentH = contentH + Scale.px(6) -- bottom padding

        local wrapper = UI.frame(aScroll, {
            Size = UDim2.new(1,0,0,HDR_RH),
            BackgroundColor3 = T.card, LayoutOrder = si, ClipsDescendants = true,
        })
        UI.corner(wrapper, Scale.px(8))

        local secBtn = UI.btn(wrapper, {
            Size = UDim2.new(1,0,0,HDR_RH),
            BackgroundColor3 = T.card, BackgroundTransparency = 1,
            Text = "", ZIndex = 32, AutoButtonColor = false,
        })

        local dot = UI.frame(secBtn, {
            Size = UDim2.new(0,Scale.px(9),0,Scale.px(9)),
            Position = UDim2.new(0,Scale.px(12),0.5,-Scale.px(4)),
            BackgroundColor3 = sec.col, ZIndex = 33,
        })
        UI.corner(dot, Scale.px(5))

        UI.label(secBtn, {
            Size = UDim2.new(1,-Scale.px(50),1,0),
            Position = UDim2.new(0,Scale.px(28),0,0),
            Text = sec.title, TextColor3 = T.accent, TextSize = Scale.fs(11),
            Font = Enum.Font.BuilderSansBold,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33,
        })

        local arrow = UI.label(secBtn, {
            Size = UDim2.new(0,Scale.px(20),1,0),
            Position = UDim2.new(1,-Scale.px(26),0,0),
            Text = "▶", TextColor3 = T.txtDim, TextSize = Scale.fs(10),
            Font = Enum.Font.BuilderSansBold, ZIndex = 33,
        })

        local content = UI.frame(wrapper, {
            Size = UDim2.new(1,-Scale.px(10),0,contentH),
            Position = UDim2.new(0,Scale.px(5),0,HDR_RH),
            BackgroundTransparency = 1, Visible = false, ZIndex = 32, ClipsDescendants = true,
        })
        do
            local cl = Instance.new("UIListLayout", content)
            cl.Padding = UDim.new(0,Scale.px(4)); cl.SortOrder = Enum.SortOrder.LayoutOrder
            local cp = Instance.new("UIPadding", content)
            cp.PaddingTop = UDim.new(0,Scale.px(6)); cp.PaddingBottom = UDim.new(0,Scale.px(6))
        end

        for ii, item in ipairs(sec.items) do
            if type(item) == "table" and item.btn then
                local brow = UI.btn(content, {
                    Size = UDim2.new(1,0,0,BTN_H), LayoutOrder = ii,
                    BackgroundColor3 = Color3.fromRGB(16,48,32),
                    Text = "", AutoButtonColor = false, ClipsDescendants = true, ZIndex = 33,
                })
                UI.corner(brow, Scale.px(5))
                UI.stroke(brow, T.neonG, 1)
                UI.hover(brow, Color3.fromRGB(16,48,32), Color3.fromRGB(24,68,44))
                local acbar = UI.frame(brow, {
                    Size = UDim2.new(0,Scale.px(3),1,-Scale.px(8)),
                    Position = UDim2.new(0,Scale.px(4),0,Scale.px(4)),
                    BackgroundColor3 = T.neonG,
                })
                UI.corner(acbar, Scale.px(2))
                local bLbl = UI.label(brow, {
                    Size = UDim2.new(1,-Scale.px(12),1,0),
                    Position = UDim2.new(0,Scale.px(10),0,0),
                    Text = item.label, TextColor3 = T.neonG, TextSize = Scale.fs(10),
                    Font = Enum.Font.BuilderSansBold,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34,
                })
                local turl = item.url
                brow.MouseButton1Click:Connect(function()
                    local ok2 = false
                    if setclipboard then pcall(setclipboard,turl); ok2=true
                    elseif toclipboard then pcall(toclipboard,turl); ok2=true
                    elseif syn and syn.write_clipboard then pcall(syn.write_clipboard,turl); ok2=true
                    end
                    if ok2 then
                        bLbl.Text = "✓  Copied!"
                        task.delay(2, function() bLbl.Text = item.label end)
                        Toast.show("URL copied!", "success", 2)
                    else
                        Toast.show(turl, "info", 6)
                        bLbl.Text = "!  See toast"
                        task.delay(2.5, function() bLbl.Text = item.label end)
                    end
                end)
            else
                local row = UI.frame(content, {
                    Size = UDim2.new(1,0,0,ROW_H), LayoutOrder = ii,
                    BackgroundColor3 = Color3.fromRGB(24,14,52),
                })
                UI.corner(row, Scale.px(5))
                local bar = UI.frame(row, {
                    Size = UDim2.new(0,Scale.px(3),1,-Scale.px(8)),
                    Position = UDim2.new(0,Scale.px(4),0,Scale.px(4)),
                    BackgroundColor3 = sec.col,
                })
                UI.corner(bar, Scale.px(2))
                UI.label(row, {
                    Size = UDim2.new(1,-Scale.px(12),1,0),
                    Position = UDim2.new(0,Scale.px(10),0,0),
                    Text = item, TextColor3 = T.txt, TextSize = Scale.fs(10),
                    Font = Enum.Font.BuilderSans,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 32,
                })
            end
        end

        secBtn.MouseButton1Click:Connect(function()
            open = not open
            content.Visible = open
            tw(wrapper, 0.15, {Size = UDim2.new(1,0,0, open and HDR_RH+contentH or HDR_RH)})
            tw(arrow, 0.15, {Rotation = open and 90 or 0})
            arrow.TextColor3 = open and sec.col or T.txtDim
            tw(wrapper, 0.12, {BackgroundColor3 = open and T.purpleDeep or T.card})
        end)
        UI.hover(secBtn, Color3.new(0,0,0), Color3.new(0,0,0)) -- ripple only
        UI.ripple(secBtn, sec.col)
    end
end -- help panel

local settingsPanel, spCloseBtn, spPianoBtn, spDrumBtn, spGuitarBtn
local SpUI = {}

local function _buildSettingsPanel()
    local function _spSize()
        local vpH = workspace.CurrentCamera.ViewportSize.Y
        local vpW = workspace.CurrentCamera.ViewportSize.X
        local h   = math.min(Scale.px(550), math.floor(vpH * 0.88))
        local w   = math.min(Scale.px(350), math.floor(vpW * 0.92))
        return w, h
    end
    local _spW, _spH = _spSize()
    settingsPanel = UI.frame(gui, {
        Size     = UDim2.new(0, _spW, 0, _spH),
        Position = UDim2.new(0.5, -math.floor(_spW/2), 0.5, -math.floor(_spH/2)),
        BackgroundColor3 = T.bg, Visible = false, ZIndex = 40,
    })
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if not settingsPanel or not settingsPanel.Parent then return end
        local nw, nh = _spSize()
        settingsPanel.Size     = UDim2.new(0, nw, 0, nh)
        settingsPanel.Position = UDim2.new(0.5, -math.floor(nw/2), 0.5, -math.floor(nh/2))
    end)
    UI.corner(settingsPanel, Scale.px(14))
    UI.stroke(settingsPanel, T.neon, 2)
    UI.gradient(settingsPanel, {
        ColorSequenceKeypoint.new(0, T.bg),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 10, 48)),
    }, 120)

    local spHdr = UI.frame(settingsPanel, {
        Size = UDim2.new(1, 0, 0, Scale.px(48)),
        BackgroundColor3 = T.purpleDeep, ZIndex = 41,
    })
    UI.corner(spHdr, Scale.px(10))
    UI.gradient(spHdr, {
        ColorSequenceKeypoint.new(0, T.purpleDeep),
        ColorSequenceKeypoint.new(1, T.purpleMid),
    }, 0)
    UI.makeDraggable(settingsPanel, settingsPanel)   -- ← full-panel drag

    UI.label(spHdr, {
        Size = UDim2.new(1, -Scale.px(64), 1, 0),
        Position = UDim2.new(0, Scale.px(14), 0, 0),
        Text = "⚙  Settings", TextColor3 = T.accent, TextSize = Scale.fs(15),
        Font = Enum.Font.BuilderSansBold,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41,
    })
    UI.label(spHdr, {
        Size = UDim2.new(0, Scale.px(80), 0, Scale.px(14)),
        Position = UDim2.new(0, Scale.px(14), 1, -Scale.px(15)),
        Text = "drag anywhere to move", TextColor3 = T.txtDim, TextSize = Scale.fs(8),
        Font = Enum.Font.BuilderSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 41,
    })
    spCloseBtn = UI.btn(spHdr, {
        Size = UDim2.new(0, Scale.px(44), 0, Scale.px(32)),
        Position = UDim2.new(1, -Scale.px(50), 0.5, -Scale.px(16)),
        BackgroundColor3 = T.btnStop, Text = "✕",
        TextSize = Scale.fs(16), Font = Enum.Font.BuilderSansBold,
        TextColor3 = T.white, ZIndex = 41,
    })
    UI.corner(spCloseBtn, Scale.px(9))
    UI.stroke(spCloseBtn, Color3.fromRGB(130, 40, 60), 1)
    UI.hover(spCloseBtn, T.btnStop, Color3.fromRGB(255, 120, 150))

    local spScroll = UI.scroll(settingsPanel, {
        Size     = UDim2.new(1, 0, 1, -Scale.px(48)),
        Position = UDim2.new(0, 0, 0, Scale.px(48)),
        BackgroundTransparency = 1, ZIndex = 41,
        ScrollBarThickness = Scale.px(4), ScrollBarImageColor3 = T.neon,
    })
    do
        local ll = Instance.new("UIListLayout", spScroll)
        ll.Padding = UDim.new(0, Scale.px(7))
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            spScroll.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + Scale.px(14))
        end)
        local pp = Instance.new("UIPadding", spScroll)
        pp.PaddingLeft   = UDim.new(0, Scale.px(9))
        pp.PaddingRight  = UDim.new(0, Scale.px(9))
        pp.PaddingTop    = UDim.new(0, Scale.px(9))
        pp.PaddingBottom = UDim.new(0, Scale.px(9))
    end

    local LO = 0
    local function nLO() LO = LO + 1; return LO end

    local function secLbl(txt)
        UI.label(spScroll, {
            Size = UDim2.new(1, 0, 0, Scale.px(20)),
            Text = txt, TextColor3 = T.accent, TextSize = Scale.fs(9),
            Font = Enum.Font.BuilderSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = nLO(), ZIndex = 41,
        })
    end

    local function spDiv()
        UI.frame(spScroll, {
            Size = UDim2.new(1, 0, 0, Scale.px(1)),
            BackgroundColor3 = T.border, LayoutOrder = nLO(),
        })
    end

    local function twoBtn(labelA, labelB)
        local row = UI.frame(spScroll, {
            Size = UDim2.new(1, 0, 0, Scale.px(46)),
            BackgroundTransparency = 1, LayoutOrder = nLO(),
        })
        do
            local rl = Instance.new("UIListLayout", row)
            rl.FillDirection = Enum.FillDirection.Horizontal
            rl.Padding = UDim.new(0, Scale.px(8))
            rl.VerticalAlignment = Enum.VerticalAlignment.Center
        end
        local bA = UI.btn(row, {
            Size = UDim2.new(0.5, -Scale.px(4), 1, 0),
            BackgroundColor3 = T.purpleMid, Text = labelA,
            TextSize = Scale.fs(13), Font = Enum.Font.BuilderSansBold,
            TextColor3 = T.white, ZIndex = 41,
        })
        UI.corner(bA, Scale.px(11)); UI.ripple(bA, T.neon)
        UI.stroke(bA, Color3.fromRGB(80, 40, 140), 1)
        local bB = UI.btn(row, {
            Size = UDim2.new(0.5, -Scale.px(4), 1, 0),
            BackgroundColor3 = T.card, Text = labelB,
            TextSize = Scale.fs(13), Font = Enum.Font.BuilderSansBold,
            TextColor3 = T.txtDim, ZIndex = 41,
        })
        UI.corner(bB, Scale.px(11)); UI.ripple(bB, T.neon)
        UI.stroke(bB, Color3.fromRGB(80, 40, 140), 1)
        return row, bA, bB
    end

    secLbl("INSTRUMENT")
    local instrRow = UI.frame(spScroll, {
        Size = UDim2.new(1, 0, 0, Scale.px(46)),
        BackgroundTransparency = 1, LayoutOrder = nLO(),
    })
    do
        local rl = Instance.new("UIListLayout", instrRow)
        rl.FillDirection = Enum.FillDirection.Horizontal
        rl.Padding = UDim.new(0, Scale.px(6))
        rl.VerticalAlignment = Enum.VerticalAlignment.Center
    end
    local function mkInstrBtn(label)
        local bW = math.floor(((_spW or Scale.px(350)) - Scale.px(9)*2 - Scale.px(6)*2) / 3)
        local b = UI.btn(instrRow, {
            Size = UDim2.new(0, bW, 1, 0),
            BackgroundColor3 = T.card, Text = label,
            TextSize = Scale.fs(12), Font = Enum.Font.BuilderSansBold,
            TextColor3 = T.txtDim, ZIndex = 41,
        })
        UI.corner(b, Scale.px(11)); UI.ripple(b, T.neon)
        UI.stroke(b, Color3.fromRGB(80, 40, 140), 1)
        return b
    end
    local pianoB  = mkInstrBtn("🎹 Piano")
    local drumB   = mkInstrBtn("🥁 Drum")
    local guitarB = mkInstrBtn("🎸 Guitar")
    spPianoBtn = pianoB; spDrumBtn = drumB; spGuitarBtn = guitarB

    spDiv()

    secLbl("KEY RANGE")
    UI.label(spScroll, {
        Size = UDim2.new(1, 0, 0, Scale.px(15)),
        Text = "61: C2–C7   •   88: MIDI 21–108",
        TextColor3 = T.txtDim, TextSize = Scale.fs(9),
        Font = Enum.Font.BuilderSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = nLO(), ZIndex = 41,
    })
    local _, k61B, k88B = twoBtn("🎹 61 Keys", "🎹 88 Keys")
    local sp61Btn = k61B; local sp88Btn = k88B

    local function syncKeyBtns()
        if Keys88Mode then
            tw(sp88Btn, 0.15, {BackgroundColor3 = T.purpleMid})
            sp88Btn.TextColor3 = T.white
            tw(sp61Btn, 0.15, {BackgroundColor3 = T.card})
            sp61Btn.TextColor3 = T.txtDim
        else
            tw(sp61Btn, 0.15, {BackgroundColor3 = T.purpleMid})
            sp61Btn.TextColor3 = T.white
            tw(sp88Btn, 0.15, {BackgroundColor3 = T.card})
            sp88Btn.TextColor3 = T.txtDim
        end
    end
    syncKeyBtns()
    SpUI.syncKeyBtns = syncKeyBtns

    local function applyKeyMode()
        -- 88-key / 61-key toggle only applies to piano mode
        if State.guitarMode or State.drumMode then
            Toast.show("Key mode only applies to Piano", "info", 2); return
        end
        if State.currentRawBytes then
            local mp   = MidiProcessor.new()
            local proc = mp:processMidiBytes(State.currentRawBytes)
            State.notes        = trimLeadingSilence(proc.notes)
            State.tempoMarkers = extractTempos(State.notes)
            State.songDuration = calcDuration(State.notes, State.currentBpm, State.usetempo)
            State.noteIndex = 1; State.beatPos = 0; State.songTime = 0
            releaseAll()
            Toast.show(Keys88Mode and "🎹 88-Key Mode ON" or "🎹 61-Key Mode", "info", 2)
        else
            Toast.show(
                Keys88Mode and "🎹 88-Key Mode — load a song to apply"
                            or "🎹 61-Key Mode — load a song to apply",
                "info", 2.5)
        end
    end

    sp61Btn.MouseButton1Click:Connect(function()
        if Keys88Mode then Keys88Mode = false; syncKeyBtns(); applyKeyMode() end
    end)
    sp88Btn.MouseButton1Click:Connect(function()
        if not Keys88Mode then Keys88Mode = true; syncKeyBtns(); applyKeyMode() end
    end)

    spDiv()

    secLbl("HUMANIZATION")

    local modeDropBg = UI.frame(spScroll, {
        Size = UDim2.new(1, 0, 0, Scale.px(40)),
        BackgroundColor3 = T.card, ZIndex = 42, LayoutOrder = nLO(),
    })
    UI.corner(modeDropBg, Scale.px(9))
    UI.stroke(modeDropBg, T.neon, 1.5)
    UI.label(modeDropBg, {
        Size = UDim2.new(0, Scale.px(90), 1, 0),
        Position = UDim2.new(0, Scale.px(10), 0, 0),
        Text = "Settings for:", TextColor3 = T.txtDim, TextSize = Scale.fs(10),
        Font = Enum.Font.BuilderSans,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42,
    })
    SpUI.modeBtn = UI.btn(modeDropBg, {
        Size = UDim2.new(1, -Scale.px(96), 1, 0),
        Position = UDim2.new(0, Scale.px(90), 0, 0),
        BackgroundTransparency = 1,
        Text = "🎹 Piano ▾", TextSize = Scale.fs(12),
        Font = Enum.Font.BuilderSansBold,
        TextColor3 = T.neon, ZIndex = 43,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    SpUI.modeMenu = UI.frame(spScroll, {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = T.panel, Visible = false,
        ZIndex = 50, ClipsDescendants = true,
        LayoutOrder = nLO(),
    })
    UI.corner(SpUI.modeMenu, Scale.px(9))
    UI.stroke(SpUI.modeMenu, T.neon, 1)
    do
        local ml = Instance.new("UIListLayout", SpUI.modeMenu)
        ml.Padding = UDim.new(0, Scale.px(2))
        ml.SortOrder = Enum.SortOrder.LayoutOrder
        local function mkMO(txt, col, order)
            local b = UI.btn(SpUI.modeMenu, {
                Size = UDim2.new(1, 0, 0, Scale.px(38)),
                BackgroundColor3 = T.card, Text = txt,
                TextSize = Scale.fs(13), Font = Enum.Font.BuilderSansBold,
                TextColor3 = col, LayoutOrder = order, ZIndex = 51,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            UI.corner(b, Scale.px(7))
            Instance.new("UIPadding", b).PaddingLeft = UDim.new(0, Scale.px(10))
            UI.hover(b, T.card, T.panel)
            return b
        end
        SpUI.optPiano = mkMO("🎹 Piano", T.neon, 1)
        SpUI.optDrum  = mkMO("🥁 Drum",  Color3.fromRGB(255,165,40), 2)
        SpUI.optGuitar = mkMO("🎸 Guitar", Color3.fromRGB(220,165,40), 3)
    end

    SpUI.humScroll = UI.frame(spScroll, {
        Size = UDim2.new(1, 0, 0, Scale.px(50)),
        BackgroundTransparency = 1, ZIndex = 41,
        LayoutOrder = nLO(),
    })
    do
        local sl = Instance.new("UIListLayout", SpUI.humScroll)
        sl.Padding = UDim.new(0, Scale.px(4))
        sl.SortOrder = Enum.SortOrder.LayoutOrder
        sl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            SpUI.humScroll.Size = UDim2.new(1, 0, 0, sl.AbsoluteContentSize.Y + Scale.px(8))
        end)
        local p2 = Instance.new("UIPadding", SpUI.humScroll)
        p2.PaddingLeft   = UDim.new(0, Scale.px(2))
        p2.PaddingRight  = UDim.new(0, Scale.px(2))
        p2.PaddingTop    = UDim.new(0, Scale.px(4))
    end

    local function makeCheckRow(parent, labelText, order, initVal, initEnabled, onToggle)
        if initEnabled == nil then initEnabled = true end
        local row = UI.frame(parent, {
            Size = UDim2.new(1, 0, 0, Scale.px(34)),
            BackgroundColor3 = T.card, LayoutOrder = order, ZIndex = 42,
        })
        UI.corner(row, Scale.px(8))
        local boxOuter = UI.frame(row, {
            Size = UDim2.new(0, Scale.px(22), 0, Scale.px(22)),
            Position = UDim2.new(0, Scale.px(7), 0.5, -Scale.px(11)),
            BackgroundColor3 = Color3.fromRGB(18,10,42), ZIndex = 43,
        })
        UI.corner(boxOuter, Scale.px(5))
        UI.stroke(boxOuter, T.neon, 1.5)
        local boxFill = UI.frame(boxOuter, {
            Size = UDim2.new(0.72, 0, 0.72, 0),
            Position = UDim2.new(0.14, 0, 0.14, 0),
            BackgroundColor3 = T.neon, Visible = initVal, ZIndex = 44,
        })
        UI.corner(boxFill, Scale.px(3))
        local boxBtn = UI.btn(boxOuter, {
            Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", ZIndex = 46,
        })
        local lbl = UI.label(row, {
            Size = UDim2.new(1, -Scale.px(36), 1, 0),
            Position = UDim2.new(0, Scale.px(34), 0, 0),
            Text = labelText, TextColor3 = initEnabled and T.txt or T.txtDim,
            TextSize = Scale.fs(11), Font = Enum.Font.BuilderSans,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
        })
        local isOn = initVal; local isEnabled = initEnabled
        local function setVal(v)   isOn = v; boxFill.Visible = v end
        local function setEnabled(v)
            isEnabled = v
            boxOuter.BackgroundColor3 = v and Color3.fromRGB(18,10,42) or Color3.fromRGB(12,8,28)
            local st = boxOuter:FindFirstChildOfClass("UIStroke")
            if st then st.Color = v and T.neon or T.border end
            boxFill.BackgroundColor3 = v and T.neon or T.txtDim
            lbl.TextColor3 = v and T.txt or T.txtDim
            row.BackgroundTransparency = v and 0 or 0.45
        end
        boxBtn.MouseButton1Click:Connect(function()
            if not isEnabled then return end
            isOn = not isOn; boxFill.Visible = isOn
            if onToggle then onToggle(isOn) end
        end)
        return row, setVal, setEnabled
    end

    local _activeDrag = nil

    local function makeSliderRow(parent, labelText, order, cfg, fmt, parseInput, minV, maxV, onToggle, onValChange)
        local RH    = Scale.px(34)
        local CHK   = Scale.px(22)
        local PAD   = Scale.px(6)
        local LBL_W = Scale.px(72)
        local VAL_W = Scale.px(56)
        local KNB_R = Scale.px(12)
        local row = UI.frame(parent, {
            Size = UDim2.new(1, 0, 0, RH),
            BackgroundColor3 = T.card, LayoutOrder = order, ZIndex = 42,
        })
        UI.corner(row, Scale.px(8))
        local boxOuter = UI.frame(row, {
            Size = UDim2.new(0, CHK, 0, CHK),
            Position = UDim2.new(0, PAD, 0.5, -CHK/2),
            BackgroundColor3 = Color3.fromRGB(18,10,42), ZIndex = 43,
        })
        UI.corner(boxOuter, Scale.px(5)); UI.stroke(boxOuter, T.neon, 1.5)
        local boxFill = UI.frame(boxOuter, {
            Size = UDim2.new(0.72,0,0.72,0), Position = UDim2.new(0.14,0,0.14,0),
            BackgroundColor3 = T.neon, Visible = cfg.on, ZIndex = 44,
        })
        UI.corner(boxFill, Scale.px(3))
        local boxBtn = UI.btn(boxOuter, {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="", ZIndex=46,
        })
        local lblX = PAD + CHK + PAD
        UI.label(row, {
            Size = UDim2.new(0, LBL_W, 1, 0),
            Position = UDim2.new(0, lblX, 0, 0),
            Text = labelText, TextColor3 = T.txt, TextSize = Scale.fs(10),
            Font = Enum.Font.BuilderSans,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
        })
        local valBox = Instance.new("TextBox")
        valBox.Size = UDim2.new(0, VAL_W, 0, Scale.px(22))
        valBox.Position = UDim2.new(1, -VAL_W-PAD, 0.5, -Scale.px(11))
        valBox.BackgroundColor3 = Color3.fromRGB(12,6,28)
        valBox.Text = fmt(cfg.val); valBox.TextColor3 = T.neonB
        valBox.TextSize = Scale.fs(10); valBox.Font = Enum.Font.BuilderSansBold
        valBox.TextXAlignment = Enum.TextXAlignment.Center
        valBox.ClearTextOnFocus = false; valBox.ZIndex = 45; valBox.Parent = row
        UI.corner(valBox, Scale.px(4))
        local trackX   = lblX + LBL_W + PAD
        local trackEndX = VAL_W + PAD*2
        local track = UI.frame(row, {
            Size = UDim2.new(1, -(trackX+trackEndX), 0, Scale.px(6)),
            Position = UDim2.new(0, trackX, 0.5, -Scale.px(3)),
            BackgroundColor3 = Color3.fromRGB(18,10,42), ZIndex = 43,
        })
        UI.corner(track, Scale.px(3))
        UI.stroke(track, T.border, 1)
        local pct  = math.max(0, math.min(1, (cfg.val-minV)/(maxV-minV)))
        local fill = UI.frame(track, {
            Size = UDim2.new(pct, 0, 1, 0),
            BackgroundColor3 = cfg.on and T.neon or T.border, ZIndex = 44,
        })
        UI.corner(fill, Scale.px(3))
        UI.gradient(fill, {ColorSequenceKeypoint.new(0,T.neon), ColorSequenceKeypoint.new(1,T.neonB)}, 0)
        local knob = UI.frame(track, {
            Size = UDim2.new(0, KNB_R, 0, KNB_R),
            Position = UDim2.new(pct, -KNB_R/2, 0.5, -KNB_R/2),
            BackgroundColor3 = T.white, ZIndex = 46,
        })
        UI.corner(knob, 999); UI.stroke(knob, T.neon, 2)

        local dragInput = nil
        local function applyDrag(inp)
            local tp = track.AbsolutePosition; local ts = track.AbsoluteSize
            local p2 = math.max(0, math.min(1, (inp.Position.X-tp.X)/ts.X))
            local v  = minV + (maxV-minV)*p2
            cfg.val = v; fill.Size = UDim2.new(p2,0,1,0)
            knob.Position = UDim2.new(p2,-KNB_R/2,0.5,-KNB_R/2)
            valBox.Text = fmt(v)
            if onValChange then onValChange(v) end
        end
        local function beginDrag(inp)
            if _activeDrag then return end
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                _activeDrag = inp
                dragInput   = inp
                spScroll.ScrollingEnabled = false
                applyDrag(inp)
            end
        end
        track.InputBegan:Connect(beginDrag); knob.InputBegan:Connect(beginDrag)
        UIS.InputChanged:Connect(function(inp)
            if inp ~= dragInput then return end
            if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then applyDrag(inp) end
        end)
        UIS.InputEnded:Connect(function(inp)
            if inp == dragInput then
                dragInput = nil
                if _activeDrag == inp then
                    _activeDrag = nil
                    spScroll.ScrollingEnabled = true  -- restore scroll
                end
            end
        end)

        valBox.FocusLost:Connect(function()
            local raw = valBox.Text
            local n = parseInput and parseInput(raw)
                    or tonumber(raw:match("[%d%.]+"))
            if n then
                n = math.max(minV, math.min(maxV, n))
                cfg.val = n
                local p2 = math.max(0, math.min(1, (n-minV)/(maxV-minV)))
                fill.Size = UDim2.new(p2,0,1,0)
                knob.Position = UDim2.new(p2,-KNB_R/2,0.5,-KNB_R/2)
                if onValChange then onValChange(n) end
            end
            valBox.Text = fmt(cfg.val)
        end)

        local isOn = cfg.on
        boxBtn.MouseButton1Click:Connect(function()
            isOn = not isOn; cfg.on = isOn
            boxFill.Visible = isOn
            fill.BackgroundColor3 = isOn and T.neon or T.border
            if onToggle then onToggle(isOn) end
        end)
        local function setEnabled(v)
            row.BackgroundTransparency = v and 0 or 0.4
            local st = boxOuter:FindFirstChildOfClass("UIStroke")
            if st then st.Color = v and T.neon or T.border end
            boxOuter.BackgroundColor3 = v and Color3.fromRGB(18,10,42) or Color3.fromRGB(12,8,28)
        end
        local function setVal(v)
            cfg.val = v
            local p2 = math.max(0, math.min(1, (v-minV)/(maxV-minV)))
            fill.Size = UDim2.new(p2,0,1,0)
            knob.Position = UDim2.new(p2,-KNB_R/2,0.5,-KNB_R/2)
            valBox.Text = fmt(v)
            cfg.on = isOn; boxFill.Visible = isOn
        end
        return row, setEnabled, setVal
    end

    SpUI.buildHumRows = function(hBlock, isPiano, defaults, isGuitar)
        for _, c in ipairs(SpUI.humScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end
        local order = 0
        local invertSetVal, invertSetEnabled

        if isPiano then
            order = order + 1
            makeCheckRow(SpUI.humScroll, "Hand Simulation", order, hBlock.simulateHands, true,
                function(v) hBlock.simulateHands = v end)
            order = order + 1
            makeCheckRow(SpUI.humScroll, "Natural Chord", order, hBlock.chordRoll, true,
                function(v) hBlock.chordRoll = v end)
            -- ── Hand Split 3-way segmented toggle ────────────────────────────
            order = order + 1
            do
                local hsr = UI.frame(SpUI.humScroll, {
                    Size = UDim2.new(1,0,0,Scale.px(38)),
                    BackgroundColor3 = T.card, LayoutOrder = order, ZIndex = 42,
                })
                UI.corner(hsr, Scale.px(8))
                UI.label(hsr, {
                    Size = UDim2.new(0,Scale.px(80),1,0),
                    Position = UDim2.new(0,Scale.px(8),0,0),
                    Text = "Hand Split", TextSize = Scale.fs(11),
                    Font = Enum.Font.BuilderSans,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
                })
                local BW = Scale.px(54); local GAP = Scale.px(4)
                local function _hsb(txt, xr)
                    local b = UI.btn(hsr, {
                        Size = UDim2.new(0,BW,0,Scale.px(26)),
                        Position = UDim2.new(1,xr,0.5,-Scale.px(13)),
                        BackgroundColor3=T.card, Text=txt,
                        TextSize=Scale.fs(10), Font=Enum.Font.BuilderSansBold, ZIndex=43,
                    })
                    UI.corner(b,Scale.px(6)); UI.stroke(b,T.border,1); return b
                end
                local hsBtnR = _hsb("Right 🤚", -(BW+8))
                local hsBtnL = _hsb("Left ✋",  -(BW*2+GAP+8))
                local hsBtnO = _hsb("All",      -(BW*3+GAP*2+8))
                local function _syncHs()
                    local v = hBlock.handSplit
                    tw(hsBtnO,0.12,{BackgroundColor3=(v=="off")   and T.purpleMid or T.card})
                    tw(hsBtnL,0.12,{BackgroundColor3=(v=="left")  and T.purpleMid or T.card})
                    tw(hsBtnR,0.12,{BackgroundColor3=(v=="right") and T.purpleMid or T.card})
                    hsBtnO.TextColor3=(v=="off")   and T.white or T.txtDim
                    hsBtnL.TextColor3=(v=="left")  and T.white or T.txtDim
                    hsBtnR.TextColor3=(v=="right") and T.white or T.txtDim
                end
                _syncHs()
                hsBtnO.MouseButton1Click:Connect(function() hBlock.handSplit="off";   _syncHs() end)
                hsBtnL.MouseButton1Click:Connect(function() hBlock.handSplit="left";  _syncHs() end)
                hsBtnR.MouseButton1Click:Connect(function() hBlock.handSplit="right"; _syncHs() end)
            end -- Hand Split
        end

        order = order + 1
        UI.frame(SpUI.humScroll, {
            Size = UDim2.new(1, 0, 0, Scale.px(1)),
            BackgroundColor3 = T.border, LayoutOrder = order,
        })

        order = order + 1
        makeSliderRow(SpUI.humScroll, "Timing Jitter", order, hBlock.varyTiming,
            function(v) return string.format("%.0f ms", v*1000) end,
            function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/1000 end,
            0, 0.1, nil, nil)

        if isPiano then
            order = order + 1
            makeSliderRow(SpUI.humScroll, "Note Length", order, hBlock.varyArticulation,
                function(v) return string.format("%.1f%%", v*100) end,
                function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/100 end,
                0, 1, nil, nil)
            order = order + 1
            makeSliderRow(SpUI.humScroll, "Hand Drift", order, hBlock.handDrift,
                function(v) return string.format("%.1f%%", v*100) end,
                function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/100 end,
                0, 1, nil, nil)
        end

        if isGuitar then
            order = order + 1
            makeSliderRow(SpUI.humScroll, "Strum Spread", order, hBlock.strumSpread,
                function(v) return string.format("%.0f ms", v*1000) end,
                function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/1000 end,
                0, 0.05, nil, nil)
            order = order + 1
            makeSliderRow(SpUI.humScroll, "Fret Lag", order, hBlock.fretLag,
                function(v) return string.format("%.0f ms", v*1000) end,
                function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/1000 end,
                0, 0.03, nil, nil)
            order = order + 1
            makeSliderRow(SpUI.humScroll, "Mute Chance", order, hBlock.mutChance,
                function(v) return string.format("%.2f%%", v*100) end,
                function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/100 end,
                0, 0.1, nil, nil)
            order = order + 1
            makeSliderRow(SpUI.humScroll, "Pick Articul.", order, hBlock.pickArticul,
                function(v) return string.format("%.1f%%", v*100) end,
                function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/100 end,
                0, 1, nil, nil)
        end

        order = order + 1
        makeSliderRow(SpUI.humScroll, "Miss Chance", order, hBlock.mistakes,
            function(v) return string.format("%.2f%%", v*100) end,
            function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/100 end,
            0, 0.1, nil, nil)

        order = order + 1
        makeSliderRow(SpUI.humScroll, "BPM Sway", order, hBlock.tempoSway,
            function(v) return string.format("%.0f ms", v*1000) end,
            function(s) local n=tonumber(s:match("[%d%.]+")) return n and n/1000 end,
            0, 0.1,
            function(swayOn)
                if invertSetEnabled then invertSetEnabled(swayOn) end
                if not swayOn then
                    hBlock.invertSway = false
                    if invertSetVal then invertSetVal(false) end
                end
            end, nil)

        order = order + 1
        _, invertSetVal, invertSetEnabled = makeCheckRow(
            SpUI.humScroll, "Flip Sway", order, hBlock.invertSway,
            hBlock.tempoSway.on,
            function(v) hBlock.invertSway = v end)

        order = order + 1
        UI.frame(SpUI.humScroll, {
            Size = UDim2.new(1, 0, 0, Scale.px(1)),
            BackgroundColor3 = T.border, LayoutOrder = order,
        })

        order = order + 1
        local btnRow = UI.frame(SpUI.humScroll, {
            Size = UDim2.new(1, 0, 0, Scale.px(44)),
            BackgroundTransparency = 1, LayoutOrder = order,
        })
        do
            local bl = Instance.new("UIListLayout", btnRow)
            bl.FillDirection = Enum.FillDirection.Horizontal
            bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
            bl.VerticalAlignment   = Enum.VerticalAlignment.Center
            bl.Padding = UDim.new(0, Scale.px(10))
        end

        local resetBtn = UI.btn(btnRow, {
            Size = UDim2.new(0, Scale.px(110), 0, Scale.px(36)),
            BackgroundColor3 = Color3.fromRGB(60,18,18),
            Text = "↩  Reset", TextSize = Scale.fs(12),
            Font = Enum.Font.BuilderSansBold,
            TextColor3 = Color3.fromRGB(240,90,90), ZIndex = 43,
        })
        UI.corner(resetBtn, Scale.px(9))
        UI.hover(resetBtn, Color3.fromRGB(60,18,18), Color3.fromRGB(90,20,20))
        resetBtn.MouseButton1Click:Connect(function()
            local def = isGuitar and HUM_DEFAULTS.guitar or (isPiano and HUM_DEFAULTS.piano or HUM_DEFAULTS.drum)
            hBlock.all = def.all; hBlock.invertSway = def.invertSway
            if isPiano then
                hBlock.simulateHands = def.simulateHands
                hBlock.chordRoll = def.chordRoll
                hBlock.handSplit = def.handSplit
                hBlock.varyArticulation.on = def.varyArticulation.on
                hBlock.varyArticulation.val = def.varyArticulation.val
                hBlock.handDrift.on  = def.handDrift.on
                hBlock.handDrift.val = def.handDrift.val
            end
            if isGuitar then
                hBlock.strumSpread.on=def.strumSpread.on;  hBlock.strumSpread.val=def.strumSpread.val
                hBlock.fretLag.on=def.fretLag.on;          hBlock.fretLag.val=def.fretLag.val
                hBlock.mutChance.on=def.mutChance.on;       hBlock.mutChance.val=def.mutChance.val
                hBlock.pickArticul.on=def.pickArticul.on;   hBlock.pickArticul.val=def.pickArticul.val
            end
            hBlock.varyTiming.on  = def.varyTiming.on;  hBlock.varyTiming.val  = def.varyTiming.val
            hBlock.mistakes.on    = def.mistakes.on;     hBlock.mistakes.val    = def.mistakes.val
            hBlock.tempoSway.on   = def.tempoSway.on;   hBlock.tempoSway.val   = def.tempoSway.val
            SpUI.buildHumRows(hBlock, isPiano, def, isGuitar)
            Toast.show("Humanization reset to defaults", "info", 2)
        end)

        local saveBtn = UI.btn(btnRow, {
            Size = UDim2.new(0, Scale.px(110), 0, Scale.px(36)),
            BackgroundColor3 = Color3.fromRGB(16,48,26),
            Text = "💾  Save", TextSize = Scale.fs(12),
            Font = Enum.Font.BuilderSansBold,
            TextColor3 = T.neonG, ZIndex = 43,
        })
        UI.corner(saveBtn, Scale.px(9))
        UI.hover(saveBtn, Color3.fromRGB(16,48,26), Color3.fromRGB(20,68,34))
        saveBtn.MouseButton1Click:Connect(function()
            Humanize.save()
            Toast.show("💾 Settings saved to RoMidi/settings.json", "success", 2.5)
        end)
    end

    SpUI.currentHumMode = "piano"
    SpUI.buildHumRows(Humanize.piano, true, HUM_DEFAULTS.piano)

    SpUI.modeMenuOpen = false
    SpUI.modeBtn.MouseButton1Click:Connect(function()
        SpUI.modeMenuOpen = not SpUI.modeMenuOpen
        SpUI.modeMenu.Visible = SpUI.modeMenuOpen
        SpUI.modeMenu.Size = UDim2.new(1, 0, 0, SpUI.modeMenuOpen and Scale.px(126) or 0)
    end)
    local function selectHumMode(mode)  -- "piano","drum","guitar"
        SpUI.modeMenuOpen = false; SpUI.modeMenu.Visible = false
        SpUI.modeMenu.Size = UDim2.new(1, 0, 0, 0)
        SpUI.currentHumMode = mode
        if mode == "piano" then
            SpUI.modeBtn.Text = "🎹 Piano ▾"; SpUI.modeBtn.TextColor3 = T.neon
            SpUI.buildHumRows(Humanize.piano, true, HUM_DEFAULTS.piano)
        elseif mode == "drum" then
            SpUI.modeBtn.Text = "🥁 Drum ▾"; SpUI.modeBtn.TextColor3 = Color3.fromRGB(255,165,40)
            SpUI.buildHumRows(Humanize.drum, false, HUM_DEFAULTS.drum)
        else
            SpUI.modeBtn.Text = "🎸 Guitar ▾"; SpUI.modeBtn.TextColor3 = Color3.fromRGB(220,165,40)
            SpUI.buildHumRows(Humanize.guitar, false, HUM_DEFAULTS.guitar, true)
        end
    end
    SpUI.optPiano.MouseButton1Click:Connect(function()  selectHumMode("piano")  end)
    SpUI.optDrum.MouseButton1Click:Connect(function()   selectHumMode("drum")   end)
    SpUI.optGuitar.MouseButton1Click:Connect(function() selectHumMode("guitar") end)
    SpUI.syncModeDropdown = function()
        local mode = State.drumMode and "drum" or State.guitarMode and "guitar" or "piano"
        if SpUI.currentHumMode ~= mode then selectHumMode(mode) end
    end
end -- _buildSettingsPanel
_buildSettingsPanel()
local function updateProgressUI()
    if State.songDuration<=0 then
        timeLbl.Text="0:00 / 0:00"; ftTimeLbl.Text="0:00 / 0:00"; return
    end
    -- Clamp displayTime so the timer never shows a value beyond the song length
    local displayTime = math.min(State.songTime, State.songDuration)
    local pct = displayTime / State.songDuration
    local tStr = fmtTime(displayTime) .. " / " .. fmtTime(State.songDuration)
    timeLbl.Text=tStr; ftTimeLbl.Text=tStr
    if not State.isDragging then
        progFill.Size=UDim2.new(pct,0,1,0)
        progHandle.Position=UDim2.new(pct,-Scale.px(8),0.5,-Scale.px(8))
        ftProgFill.Size=UDim2.new(pct,0,1,0)
        ftProgHandle.Position=UDim2.new(pct,-Scale.px(8),0.5,-Scale.px(8))
    end
end

local function startProg()
    if State.progressConn then State.progressConn:Disconnect() end
    State.progressConn=RunS.Heartbeat:Connect(function()
        if State.playing and not State.paused then updateProgressUI() end
    end)
end
local function stopProg()
    if State.progressConn then State.progressConn:Disconnect(); State.progressConn=nil end
end

local syncPlayBtn
local syncRecBtn

local function seekTo(t)
    if not State.notes then return end  -- No song loaded yet
    t = math.max(0, math.min(t, State.songDuration))
    State.songTime = t
    local initB = (State.usetempo and #State.tempoMarkers>0) and State.tempoMarkers[1].bpm or State.currentBpm
    State.beatPos = realToBeat(t, State.tempoMarkers, initB, State.usetempo)

    local seekMs = t * 1000

    State.noteIndex = 1
    for i = 1, #State.notes do
        local ev = State.notes[i]
        local evMs = calcEvMs(ev)
        if evMs <= seekMs then
            State.noteIndex = i + 1
        else
            break
        end
    end
    State.noteIndex = math.min(State.noteIndex, #State.notes + 1)

    releaseAll()

    State.seekReq = true
    updateProgressUI()
end

do
    local activeContainer = nil
    local activeInput     = nil   -- the exact InputObject (finger/mouse) that owns this drag
    local pendingPct      = nil
    local lastCommit      = 0

    local function getPct(container, pos)
        local cp = container.AbsolutePosition
        local cs = container.AbsoluteSize
        return math.max(0, math.min(1, (pos.X - cp.X) / cs.X))
    end

    local function inBounds(container, pos)
        local cp = container.AbsolutePosition
        local cs = container.AbsoluteSize
        local padX = Scale.px(8)
        local padY = Scale.px(10)
        return pos.X >= cp.X - padX and pos.X <= cp.X + cs.X + padX
           and pos.Y >= cp.Y - padY and pos.Y <= cp.Y + cs.Y + padY
    end

    local function updateBars(pct)
        progFill.Size       = UDim2.new(pct,0,1,0)
        progHandle.Position = UDim2.new(pct,-Scale.px(8),0.5,-Scale.px(8))
        ftProgFill.Size     = UDim2.new(pct,0,1,0)
        ftProgHandle.Position = UDim2.new(pct,-Scale.px(8),0.5,-Scale.px(8))
    end

    local function endDrag()
        if pendingPct and activeContainer then
            seekTo(pendingPct * State.songDuration)
        end
        State.isDragging = false
        activeContainer  = nil
        activeInput      = nil
        pendingPct       = nil
    end

    local function startDrag(container, inp)
        if State.isFrameDragging then return end
        if container == progContainer and _minimized then return end
        if State.seekLocked then
            Toast.show("🔒 Seek is locked", "warning", 1.2)
            return
        end
        activeContainer = container
        activeInput     = inp          -- lock onto this specific finger/button
        State.isDragging = true
        pendingPct      = getPct(container, inp.Position)
        lastCommit      = tick()
        updateBars(pendingPct)
        seekTo(pendingPct * State.songDuration)
    end

    local function moveDrag(inp)
        if inp ~= activeInput then return end
        if not activeContainer then return end
        if _minimized and activeContainer == progContainer then endDrag(); return end
        pendingPct = getPct(activeContainer, inp.Position)
        updateBars(pendingPct)
        local now = tick()
        if now - lastCommit >= 0.08 then
            lastCommit = now
            seekTo(pendingPct * State.songDuration)
        end
    end

    progContainer.InputBegan:Connect(function(inp)
        if not mainFrame.Visible or _minimized then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            startDrag(progContainer, inp)
        end
    end)
    ftProgContainer.InputBegan:Connect(function(inp)
        if not floatFrame.Visible then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            startDrag(ftProgContainer, inp)
        end
    end)

    for _, child in ipairs({progTrack, progFill, progHandle}) do
        child.InputBegan:Connect(function(inp)
            if not mainFrame.Visible or _minimized then return end
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                startDrag(progContainer, inp)
            end
        end)
    end
    for _, child in ipairs({ftProgTrack, ftProgFill, ftProgHandle}) do
        child.InputBegan:Connect(function(inp)
            if not floatFrame.Visible then return end
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                startDrag(ftProgContainer, inp)
            end
        end)
    end

    UIS.InputBegan:Connect(function(inp, gpe)
        if inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if State.isDragging or State.isFrameDragging then return end
        if mainFrame.Visible and not _minimized and inBounds(progContainer, inp.Position) then
            startDrag(progContainer, inp)
        elseif floatFrame.Visible and inBounds(ftProgContainer, inp.Position) then
            startDrag(ftProgContainer, inp)
        end
    end)

    UIS.InputChanged:Connect(function(inp)
        if not State.isDragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            moveDrag(inp)
        end
    end)

    UIS.InputEnded:Connect(function(inp)
        if inp ~= activeInput then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
end

local function updateBPM(bpm, recalc)
    State.currentBpm = bpm
    bpmInput.Text = tostring(bpm)
    bpmDisplayLbl.Text = "BPM: " .. bpm
    if recalc then
        if State.drumMode then
            -- Drum timing is always ms-based from 120 BPM reference
            State.songDuration = State.drumBaseDuration * (120 / (State.usetempo and 120 or State.manualBpm))
        else
            -- Auto: duration is fixed by native MIDI tempos → use originalBpm as initBpm
            -- Manual: duration scales with the user's chosen BPM
            local durInitBpm = State.usetempo and State.originalBpm or State.manualBpm
            State.songDuration = calcDuration(State.notes, durInitBpm, State.usetempo)
        end
        updateProgressUI()
    end
end

local restoreFromRecord  -- forward-declared; defined after mainFrame is built

-- ── Guitar-mode dedicated playback loop ───────────────────────────────────
-- Mirrors playNotes but uses only pressGuitarKey / releaseGuitarKey and
-- contains no piano/drum branches.
local function playGuitarNotes()
    State.tempoMarkers = extractTempos(State.notes)

    if State.usetempo then
        State.currentBpm = bpmAtBeat(State.beatPos or 0)
    else
        State.currentBpm = State.manualBpm
    end

    State.playing = true
    if State.songTime == 0 then
        State.beatPos  = 0
        State.noteIndex = 1
    end
    State.songDuration = calcDuration(State.notes, State.currentBpm, State.usetempo)

    startProg(); updateBPM(State.currentBpm, false); updateProgressUI()

    local lastT      = tick()
    local wasPaused  = false

    local _noteJitter    = {}
    local _earlyReleased = {}
    GuitarHum.reset()   -- clear strum-cluster state at song start

    while State.playing and State.noteIndex <= #State.notes do
        if State.stopReq then break end

        if State.paused then
            if not wasPaused then
                releaseAll()
                wasPaused = true
            end
            task.wait(0.05)
        else
            if wasPaused then lastT = tick(); wasPaused = false end
            if State.seekReq then lastT = tick(); State.seekReq = false end

            local now = tick()
            local dt  = now - lastT
            lastT = now

            local swayDt = Humanize.swayOffset(dt)
            State.songTime = State.songTime + dt + swayDt
            local initB = (State.usetempo and #State.tempoMarkers > 0)
                          and State.tempoMarkers[1].bpm or State.currentBpm
            State.beatPos = realToBeat(State.songTime, State.tempoMarkers, initB, State.usetempo)

            if State.usetempo then
                local exp = bpmAtBeat(State.beatPos)
                if exp ~= State.currentBpm then State.currentBpm = exp; updateBPM(exp, false) end
            else
                if State.currentBpm ~= State.manualBpm then
                    State.currentBpm = State.manualBpm
                    State.songDuration = calcDuration(State.notes, State.currentBpm, false)
                    updateBPM(State.currentBpm, false); updateProgressUI()
                end
            end

            local nowMs = State.songTime * 1000
            while State.noteIndex <= #State.notes do
                local ev  = State.notes[State.noteIndex]
                local evMs = calcEvMs(ev)
                if nowMs < evMs then break end

                local jitter = _noteJitter[State.noteIndex]
                if jitter == nil then
                    local gh = Humanize.guitar
                    -- pick timing jitter ±val (bidirectional, simulates pick imprecision)
                    local j = gh.varyTiming.on and (math.random()*2-1)*gh.varyTiming.val*1000 or 0
                    if ev.notestate == "down" then
                        -- strum cascade: each note in a chord cluster fires a bit later
                        j = j + GuitarHum.strumDelay(evMs)
                        -- fret lag: fretting hand always arrives slightly late (positive only)
                        j = j + GuitarHum.fretLag()
                    end
                    _noteJitter[State.noteIndex] = j
                    jitter = j
                end
                if nowMs < evMs + jitter then break end

                local ns = ev.notestate
                if ns == "" then
                    if State.usetempo then
                        local nb = tonumber((ev.tempo or ""):match("tempo=(%d+)"))
                        if nb and nb ~= State.currentBpm then
                            State.currentBpm = nb; updateBPM(nb, false)
                        end
                    end
                elseif ns == "up" then
                    if _earlyReleased[State.noteIndex] then
                        _earlyReleased[State.noteIndex] = nil
                    else
                        releaseGuitarKey(ev.key)
                    end
                elseif ns == "down" then
                    if not Humanize.isMistake() then
                        pressGuitarKey(ev.key)
                        local evKey = ev.key
                        if GuitarHum.isMute() then
                            -- string buzz: note fires but dies almost immediately
                            local captKey = evKey
                            task.delay(0.015 + math.random()*0.015, function()
                                if State.playing and not State.stopReq then
                                    releaseGuitarKey(captKey)
                                end
                            end)
                        else
                            -- pick articulation: shorten note to a fraction of its natural duration
                            for si = State.noteIndex + 1, math.min(#State.notes, State.noteIndex + 500) do
                                local sev = State.notes[si]
                                if sev and sev.notestate == "up" and sev.key == evKey then
                                    local earlyS = GuitarHum.pickArticulDelay(evMs, calcEvMs(sev))
                                    if earlyS then
                                        local captIdx = si
                                        task.delay(earlyS, function()
                                            if State.playing and not State.stopReq then
                                                _earlyReleased[captIdx] = true
                                                releaseGuitarKey(evKey)
                                            end
                                        end)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                State.noteIndex = State.noteIndex + 1
            end

            task.wait(0.001)
        end

        if State.noteIndex > #State.notes then
            if State.loopMode then
                State.noteIndex = 1; State.beatPos = 0; State.songTime = 0
                lastT = tick(); wasPaused = false
                State.currentBpm = State.usetempo and bpmAtBeat(0) or State.manualBpm
                releaseAll(); GuitarHum.reset()
                State.songDuration = calcDuration(State.notes, State.currentBpm, State.usetempo)
                updateBPM(State.currentBpm, false); updateProgressUI()
                task.wait(1); lastT = tick()
            else
                break
            end
        end
    end

    releaseAll()
    State.playing  = false
    State.stopReq  = false
    State.paused   = false
    stopProg()

    -- Reset position BEFORE touching the UI so updateProgressUI sees songTime=0
    State.songTime  = 0
    State.beatPos   = 0
    State.noteIndex = 1

    progFill.Size         = UDim2.new(0,0,1,0)
    progHandle.Position   = UDim2.new(0,-Scale.px(8),0.5,-Scale.px(8))
    ftProgFill.Size       = UDim2.new(0,0,1,0)
    ftProgHandle.Position = UDim2.new(0,-Scale.px(8),0.5,-Scale.px(8))
    timeLbl.Text   = "0:00 / "..fmtTime(State.songDuration)
    ftTimeLbl.Text = "0:00 / "..fmtTime(State.songDuration)

    if not State.songChanged then syncPlayBtn() end
    State.songChanged = false
    if State.recordMode and State.recAutoRestore then restoreFromRecord() end
end
-- ── end playGuitarNotes ────────────────────────────────────────────────────

local function playNotes()
    State.tempoMarkers = extractTempos(State.notes)

    if State.usetempo then
        State.currentBpm = bpmAtBeat(State.beatPos or 0)
    else
        State.currentBpm = State.manualBpm
    end

    State.playing = true
    if State.songTime == 0 then
        State.beatPos  = 0
        State.noteIndex = 1
    end
    if not State.drumMode then
        State.songDuration = calcDuration(State.notes, State.currentBpm, State.usetempo)
    end

    startProg(); updateBPM(State.currentBpm, false); updateProgressUI()

    local lastT    = tick()
    local wasPaused = false
    local pausedAt  = 0

    local _noteJitter    = {}
    local _earlyReleased = {}
    local _driftMs  = 0
    local _driftDir = 1
    -- Natural Chord stagger state: tracks same-timestamp note groups (MIDI chords)
    local _chordLastEvMs = nil   -- evMs of the last "down" note processed
    local _chordAcc      = 0    -- accumulated delay (seconds) for this chord group
    local _staggerDelay  = {}   -- [noteIndex] → stagger delay applied to that "down" event
    local function _nextDrift()
        local h = Humanize.get()
        if not (h.handDrift and h.handDrift.on) then return 0 end
        local maxMs  = h.handDrift.val * 80   -- ±80 ms at full intensity
        local stepMs = h.handDrift.val * 2.5  -- ms shift per note event
        _driftMs = _driftMs + _driftDir * stepMs
        if math.abs(_driftMs) >= maxMs then _driftDir = -_driftDir end
        return _driftMs
    end
    local function _evMsOf(sev)
        return calcEvMs(sev)
    end

    while State.playing and State.noteIndex <= #State.notes do
        if State.stopReq then break end

        if State.paused then
            if not wasPaused then
                releaseAll()
                wasPaused = true
                pausedAt  = tick()
            end
            task.wait(0.05)
        else
            if wasPaused then
                lastT    = tick()
                wasPaused = false
            end
            if State.seekReq then
                lastT = tick()
                State.seekReq = false
            end

            local now = tick()
            local dt  = now - lastT
            lastT = now

            local swayDt = Humanize.swayOffset(dt)
            State.songTime = State.songTime + dt + swayDt
            local initB = (State.usetempo and #State.tempoMarkers > 0)
                          and State.tempoMarkers[1].bpm or State.currentBpm
            State.beatPos = realToBeat(State.songTime, State.tempoMarkers, initB, State.usetempo)

            if State.usetempo then
                local exp = bpmAtBeat(State.beatPos)
                if exp ~= State.currentBpm then State.currentBpm = exp; updateBPM(exp, false) end
            else
                if State.currentBpm ~= State.manualBpm then
                    State.currentBpm = State.manualBpm
                    if State.drumMode then
                        State.songDuration = State.drumBaseDuration * (120 / State.manualBpm)
                    else
                        State.songDuration = calcDuration(State.notes, State.currentBpm, false)
                    end
                    updateBPM(State.currentBpm, false)
                    updateProgressUI()
                end
            end

            local nowMs = State.songTime * 1000
            while State.noteIndex <= #State.notes do
                local ev = State.notes[State.noteIndex]
                local evMs = calcEvMs(ev)
                if nowMs < evMs then break end

                local jitter = _noteJitter[State.noteIndex]
                if jitter == nil then
                    local h = Humanize.get()
                    jitter = h.varyTiming.on and (math.random()*2-1)*h.varyTiming.val*1000 or 0
                    jitter = jitter + _nextDrift()
                    _noteJitter[State.noteIndex] = jitter
                end
                if nowMs < evMs + jitter then break end

                local ns = ev.notestate
                if ns == "" then
                    if State.usetempo then
                        local tempoStr = ev.tempo or (ev.keys or ev[2] or "")
                        local nb = tonumber(tempoStr:match("tempo=(%d+)"))
                        if nb and nb ~= State.currentBpm then
                            State.currentBpm = nb; updateBPM(nb, false)
                        end
                    end
                elseif ns == "drum_hit" then
                    if not Humanize.isMistake() then
                        local dk  = ev.key
                        local dkc = pressDrumKey(dk)
                        if dkc then
                            task.delay(0.045, function() safeKey(false, dkc) end)
                        end
                    end
                elseif ns == "up" then
                    if _earlyReleased[State.noteIndex] then
                        _earlyReleased[State.noteIndex] = nil
                    else
                        local sd = _staggerDelay[State.noteIndex]
                        if sd and sd > 0 then
                            _staggerDelay[State.noteIndex] = nil
                            local captKey = ev.key
                            task.delay(sd, function()
                                if State.playing and not State.stopReq then
                                    releaseKey(captKey)
                                end
                            end)
                        else
                            releaseKey(ev.key)
                        end
                    end
                elseif ns == "down" then
                    -- Hand Split filter: skip notes outside the chosen hand.
                    local _hsSkip = Humanize.piano.handSplit ~= "off"
                                    and not State.drumMode and not State.guitarMode
                                    and ev._midi ~= nil
                                    and ((Humanize.piano.handSplit == "left"  and ev._midi >= 60)
                                      or (Humanize.piano.handSplit == "right" and ev._midi <  60))
                    if not _hsSkip and not Humanize.isMistake() then
                        local h = Humanize.get()
                        -- Natural Chord stagger for MIDI: notes sharing the same evMs
                        -- timestamp are part of a chord.  Each one beyond the first gets
                        -- an accumulated random delay so fingers land visibly apart.
                        if h.chordRoll then
                            if evMs ~= _chordLastEvMs then
                                -- New timestamp → start of a fresh chord (or solo note)
                                _chordLastEvMs = evMs
                                _chordAcc      = 0
                            end
                            local staggerDelay = _chordAcc
                            -- Accumulate for the NEXT note: 8–15 ms base +
                            -- a ~40 % chance of an extra 0–20 ms "lurch" so gaps
                            -- are visibly uneven, just like a real hand.
                            local base  = 0.008 + math.random() * 0.007
                            local lurch = (math.random() < 0.40) and (math.random() * 0.020) or 0
                            _chordAcc = _chordAcc + base + lurch

                            local captKey  = ev.key
                            local captIdx  = State.noteIndex
                            local captEvMs = evMs

                            -- Record the stagger delay onto the matching "up" event index
                            -- so the ns=="up" handler delays release by the same amount.
                            if staggerDelay > 0 then
                                for si = captIdx + 1, math.min(#State.notes, captIdx + 500) do
                                    local sev = State.notes[si]
                                    if sev and sev.notestate == "up" and sev.key == captKey then
                                        _staggerDelay[si] = staggerDelay
                                        break
                                    end
                                end
                            end

                            local function doPress()
                                if not (State.playing and not State.stopReq) then return end
                                pressKey(captKey)
                                if h.varyArticulation and h.varyArticulation.on and captKey then
                                    local artFactor = math.max(0.05, math.min(0.99, h.varyArticulation.val))
                                    for si = captIdx + 1, math.min(#State.notes, captIdx + 500) do
                                        local sev = State.notes[si]
                                        if sev and sev.notestate == "up" and sev.key == captKey then
                                            local upMs      = _evMsOf(sev)
                                            local naturalMs = math.max(10, upMs - captEvMs)
                                            local earlyS    = math.max(0.015, naturalMs * artFactor / 1000)
                                            local ci        = si
                                            task.delay(earlyS, function()
                                                if State.playing and not State.stopReq then
                                                    _earlyReleased[ci] = true
                                                    releaseKey(captKey)
                                                end
                                            end)
                                            break
                                        end
                                    end
                                end
                            end
                            if staggerDelay <= 0 then
                                doPress()          -- first note fires immediately
                            else
                                task.delay(staggerDelay, doPress)
                            end
                        else
                            -- chordRoll off: original behaviour
                            pressKey(ev.key)
                            if h.varyArticulation and h.varyArticulation.on and ev.key then
                                local artFactor = math.max(0.05, math.min(0.99, h.varyArticulation.val))
                                local evKey = ev.key
                                for si = State.noteIndex + 1, math.min(#State.notes, State.noteIndex + 500) do
                                    local sev = State.notes[si]
                                    if sev and sev.notestate == "up" and sev.key == evKey then
                                        local upMs      = _evMsOf(sev)
                                        local naturalMs = math.max(10, upMs - evMs)
                                        local earlyS    = math.max(0.015, naturalMs * artFactor / 1000)
                                        local captIdx   = si
                                        task.delay(earlyS, function()
                                            if State.playing and not State.stopReq then
                                                _earlyReleased[captIdx] = true
                                                releaseKey(evKey)
                                            end
                                        end)
                                        break
                                    end
                                end
                            end
                        end
                    end
                else
                    local ks = ev.keys or ev[2] or ""
                    if ks:match("^tempo=%d+$") then
                        if State.usetempo then
                            local nb = tonumber(ks:match("tempo=(%d+)"))
                            if nb and nb ~= State.currentBpm then
                                State.currentBpm = nb; updateBPM(nb, false)
                            end
                        end
                    elseif ks:sub(1,1) == "~" then
                        -- chord release
                        local h = Humanize.get()
                        local releaseStr = ks:sub(2)
                        if h.chordRoll and #releaseStr > 1 then
                            -- stagger releases: each key gets a small random extra delay,
                            -- accumulating so keys drift apart naturally like a real hand lifting
                            local acc = 0
                            for i = 1, #releaseStr do
                                local k = releaseStr:sub(i, i)
                                if acc <= 0 then
                                    releaseKey(k)
                                else
                                    local d = acc
                                    task.delay(d, function()
                                        if State.playing and not State.stopReq then
                                            releaseKey(k)
                                        end
                                    end)
                                end
                                acc = acc + 0.007 + math.random() * 0.016  -- 7-23 ms per key
                            end
                        else
                            for i = 2, #ks do releaseKey(ks:sub(i, i)) end
                        end
                    else
                        -- chord press
                        local h = Humanize.get()
                        if h.chordRoll and #ks > 1 then
                            -- stagger presses: first key fires immediately, each next key
                            -- gets an accumulated random delay mimicking fingers landing
                            -- on a chord. Small enough that sustained notes still overlap.
                            local acc = 0
                            for i = 1, #ks do
                                local k = ks:sub(i, i)
                                if acc <= 0 then
                                    pressKey(k)
                                else
                                    local d = acc
                                    task.delay(d, function()
                                        if State.playing and not State.stopReq then
                                            pressKey(k)
                                        end
                                    end)
                                end
                                acc = acc + 0.007 + math.random() * 0.016  -- 7-23 ms per key
                            end
                        else
                            for i = 1, #ks do pressKey(ks:sub(i, i)) end
                        end
                    end
                end
                State.noteIndex = State.noteIndex + 1
            end

            task.wait(0.001)
        end

        if State.noteIndex > #State.notes then
            if State.loopMode then
                State.noteIndex = 1
                State.beatPos   = 0
                State.songTime  = 0
                lastT = tick(); wasPaused = false
                State.currentBpm = State.usetempo and bpmAtBeat(0) or State.manualBpm
                releaseAll()
                State.songDuration = calcDuration(State.notes, State.currentBpm, State.usetempo)
                updateBPM(State.currentBpm, false); updateProgressUI()
                task.wait(1); lastT = tick()
            else
                break
            end
        end
    end

    releaseAll()
    State.playing  = false
    State.stopReq  = false
    State.paused   = false
    stopProg()

    progFill.Size      = UDim2.new(0,0,1,0)
    progHandle.Position= UDim2.new(0,-Scale.px(8),0.5,-Scale.px(8))
    ftProgFill.Size    = UDim2.new(0,0,1,0)
    ftProgHandle.Position= UDim2.new(0,-Scale.px(8),0.5,-Scale.px(8))
    timeLbl.Text   = "0:00 / "..fmtTime(State.songDuration)
    ftTimeLbl.Text = "0:00 / "..fmtTime(State.songDuration)

    State.tempoMarkers = {}
    State.songTime  = 0
    State.noteIndex = 1

    if not State.songChanged then syncPlayBtn() end
    State.songChanged = false
    if State.recordMode and State.recAutoRestore then restoreFromRecord() end
end

local function loadPresetSong(songName,category)
    if Cache.github[category] and Cache.github[category][songName] then
        local d=Cache.github[category][songName]; return d.notes,d.bpm,d.rawBytes
    end
    local url=Config.PRESET_URL..urlEncode(catFolder(category,Config.CATEGORIES)).."/"..urlEncode(songName)
    local res=safeHttpGet(url)
    if res then
        local bytes=table.create(#res)
        for i=1,#res do bytes[i]=res:byte(i) end
        local mp=MidiProcessor.new(); local proc=mp:processMidiBytes(bytes)
        return proc.notes, mp.tempo or 120, bytes
    end
    return nil,nil
end

local currentSongsTable={}
local loadUploadedSong  -- forward declaration; defined after preloadAllPresets

-- Track the last-loaded category per tab so RELOAD can refresh the right view
local _activePresetCat        = "All Songs"
local _activeUploadedCat      = "All Songs"
local _activeDrumPresetCat    = "All Songs"
local _activeGuitarPresetCat  = "All Songs"
local _activeGuitarUploadedCat= "All Songs"

local function selectSong(sName,sData)
    State.playing=false; State.stopReq=true; State.paused=false; State.songChanged=true
    releaseAll(); State.songTime=0; State.beatPos=0; State.noteIndex=1

    State.notes = {}
    State.loading = true

    if BtnStore[playBtn] then
        setBtnLabel(playBtn,   "...", T.txtDim)
        setBtnImage(playBtn,   "")
        setBtnImgColor(playBtn, T.txtDim)
        tw(playBtn,0.12,{BackgroundColor3=Color3.fromRGB(18,14,36)})
    end
    if BtnStore[ftPlayBtn] then
        setBtnLabel(ftPlayBtn, "...", T.txtDim)
        setBtnImage(ftPlayBtn, "")
        setBtnImgColor(ftPlayBtn, T.txtDim)
        tw(ftPlayBtn,0.12,{BackgroundColor3=Color3.fromRGB(18,14,36)})
    end

    if (sData.url=="preset" or sData.url=="uploaded" or sData.url=="local") and not sData.notes then
        songTitleLbl.Text = "● Loading song content..."
        ftSongLbl.Text    = "● Loading song content..."
    end
    if sData.url=="preset" then
        if State.drumMode then
            Toast.show("No preset piano songs in drum mode", "warning", 2.5)
            State.loading = false
            if syncPlayBtn then syncPlayBtn() end
            return
        end
        local n,bpm,rb=loadPresetSong(sData.originalName,sData.category)
        if n then sData.notes=n; sData.bpm=bpm; sData.rawBytes=rb
        else
            warn("Failed to load: "..sName)
            State.loading = false
            if syncPlayBtn then syncPlayBtn() end
            return
        end
    elseif sData.url=="uploaded" then
        if State.drumMode then
            Toast.show("No uploaded drum songs yet", "warning", 2.5)
            State.loading = false
            if syncPlayBtn then syncPlayBtn() end
            return
        end
        local n,bpm,rb=loadUploadedSong(sData.originalName,sData.category)
        if n then sData.notes=n; sData.bpm=bpm; sData.rawBytes=rb
        else
            warn("Failed to load: "..sName)
            State.loading = false
            if syncPlayBtn then syncPlayBtn() end
            return
        end
    elseif sData.url=="drum_preset" then
        local n, dur = State._loadDrumPresetSong(sData.originalName, sData.category)
        if n then
            sData.notes        = n
            sData.bpm          = 120
            sData.drumDuration = dur or 0
            sData.isDrum       = true
        else
            warn("Failed to load drum preset: "..sName)
            Toast.show("Could not load drum preset – check HTTP access", "error", 3)
            State.loading = false
            if syncPlayBtn then syncPlayBtn() end
            return
        end
    elseif sData.url=="drum_uploaded" then
        local n, dur = State._loadDrumUploadedSong(sData.originalName, sData.category)
        if n then
            sData.notes=n; sData.bpm=120; sData.drumDuration=dur or 0; sData.isDrum=true
        else
            warn("Failed to load drum upload: "..sName)
            Toast.show("Could not load drum upload – check HTTP", "error", 3)
            State.loading=false
            if syncPlayBtn then syncPlayBtn() end
            return
        end
    elseif sData.url=="guitar_preset" then
        local n, bpm, rb = State._loadGuitarPresetSong(sData.originalName, sData.category)
        if n then sData.notes=n; sData.bpm=bpm; sData.rawBytes=rb
        else
            warn("Failed to load guitar preset: "..sName)
            Toast.show("Could not load guitar preset – check HTTP", "error", 3)
            State.loading=false
            if syncPlayBtn then syncPlayBtn() end
            return
        end
    elseif sData.url=="guitar_uploaded" then
        local n, bpm, rb = State._loadGuitarUploadedSong(sData.originalName, sData.category)
        if n then sData.notes=n; sData.bpm=bpm; sData.rawBytes=rb
        else
            warn("Failed to load guitar upload: "..sName)
            Toast.show("Could not load guitar upload – check HTTP", "error", 3)
            State.loading=false
            if syncPlayBtn then syncPlayBtn() end
            return
        end
    elseif sData.url=="local" then
        if not sData.notes then
            if State.drumMode then
                local ok, raw = pcall(readfile, sData.path)
                if ok and raw and raw ~= "" then
                    local evts, totalSec = parseDrumMidi(raw)
                    if evts then
                        sData.notes        = evts
                        sData.bpm          = 120   -- drums use time-stamped ms, BPM irrelevant
                        sData.rawBytes     = nil
                        sData.drumDuration = totalSec or 0
                        if Cache.category[sData.category] and Cache.category[sData.category][sName] then
                            Cache.category[sData.category][sName] = sData
                        end
                    else
                        warn("Drum parse failed: "..(sData.path or sName))
                        State.loading = false
                        if syncPlayBtn then syncPlayBtn() end
                        return
                    end
                else
                    warn("Failed to read drum file: "..(sData.path or sName))
                    State.loading = false
                    if syncPlayBtn then syncPlayBtn() end
                    return
                end
            elseif State.guitarMode then
                -- Guitar local: .gtr files are standard MIDI files
                local bytes = readMidiFile(sData.path)
                if bytes then
                    local mp = GuitarMidiProcessor.new()
                    local proc = mp:processMidiBytes(bytes)
                    sData.notes    = proc.notes
                    sData.bpm      = mp.tempo or 120
                    sData.rawBytes = bytes
                    if Cache.category[sData.category] and Cache.category[sData.category][sName] then
                        Cache.category[sData.category][sName] = sData
                    end
                else
                    warn("Failed to read guitar file: "..(sData.path or sName))
                    State.loading = false
                    if syncPlayBtn then syncPlayBtn() end
                    return
                end
            else
                local bytes = readMidiFile(sData.path)
                if bytes then
                    local mp = MidiProcessor.new()
                    local proc = mp:processMidiBytes(bytes)
                    sData.notes    = proc.notes
                    sData.bpm      = mp.tempo or 120
                    sData.rawBytes = bytes
                    if Cache.category[sData.category] and Cache.category[sData.category][sName] then
                        Cache.category[sData.category][sName] = sData
                    end
                else
                    warn("Failed to read local file: "..(sData.path or sName))
                    State.loading = false
                    if syncPlayBtn then syncPlayBtn() end
                    return
                end
            end
        end
    end
    if not sData.notes then
        warn("No note data: "..sName)
        State.loading = false
        if syncPlayBtn then syncPlayBtn() end
        return
    end

    State.loading = false
    State.notes=trimLeadingSilence(sData.notes); State.songName=sName
    State.currentRawBytes = sData.rawBytes or nil
    Toast.show("♪ " .. sName, "success", 2.5)
    local rawBytesForTranspose = sData.rawBytes
    task.spawn(function()
        task.wait(0.4)
        if State.drumMode then return end
        if rawBytesForTranspose then
            local mp2 = MidiProcessor.new()
            local minP, maxP = mp2:getRawNoteRange(rawBytesForTranspose)
            if minP then
                local VP_MIN, VP_MAX = 36, 96
                local alreadyFits = minP >= VP_MIN and maxP <= VP_MAX
                if not alreadyFits then
                    local bestShift, bestClip = 0, math.huge
                    for oct = -5, 5 do
                        local shift = oct * 12
                        local newMin = minP + shift
                        local newMax = maxP + shift
                        local clip = math.max(0, VP_MIN - newMin) + math.max(0, newMax - VP_MAX)
                        if clip < bestClip then bestClip = clip; bestShift = oct end
                    end
                    if bestShift ~= 0 then
                        local dir = bestShift > 0 and "+" or ""
                        Toast.show("Transpose " .. dir .. bestShift .. " oct recommended", "warning", 4)
                    end
                end
            end
        end
    end)
    RecentlyPlayed.add(sName, sData)
    -- originalBpm = the MIDI file's native BPM (never changed after this point)
    State.originalBpm   = sData.bpm or 120
    -- manualBpm   = user-chosen speed; reset to native BPM on a new song load
    State.manualBpm     = State.originalBpm
    State.lastManualBpm = State.originalBpm
    if State.drumMode then
        State.tempoMarkers     = {}
        State.drumBaseDuration = sData.drumDuration or 0
        State.songDuration     = State.drumBaseDuration  -- drums: no BPM scaling
    else
        State.tempoMarkers = extractTempos(State.notes)
        local durInitBpm   = State.usetempo and State.originalBpm or State.manualBpm
        State.songDuration = calcDuration(State.notes, durInitBpm, State.usetempo)
    end
    -- In Auto mode show the first tempo marker's BPM (the accurate initial MIDI tempo).
    -- In Manual mode show the native BPM as the starting manual value.
    if State.usetempo and #State.tempoMarkers > 0 then
        State.currentBpm = State.tempoMarkers[1].bpm
    else
        State.currentBpm = State.manualBpm
    end
    songTitleLbl.Text="> "..sName; ftSongLbl.Text="> "..sName
    bpmInput.Text=tostring(State.currentBpm); bpmDisplayLbl.Text="BPM: "..State.currentBpm
    progFill.Size=UDim2.new(0,0,1,0); ftProgFill.Size=UDim2.new(0,0,1,0)
    timeLbl.Text="0:00 / "..fmtTime(State.songDuration)
    ftTimeLbl.Text="0:00 / "..fmtTime(State.songDuration)
    updateProgressUI()
    if syncPlayBtn then syncPlayBtn() end  -- reset play button to PLAY after song change
end

local function makeSongBtn(parent,sName,sData,order)
    local isPreset = sData.url=="preset" or sData.url=="uploaded" or sData.url=="drum_preset" or sData.url=="drum_uploaded" or sData.url=="guitar_preset" or sData.url=="guitar_uploaded"
    local isFav    = Favorites.isFav(sName)

    local durText = ""
    if sData.notes and #sData.notes > 0 then
        local dur = calcDuration(sData.notes, sData.bpm or 120, false)
        durText = fmtTime(dur)
    elseif isPreset then
        durText = "?"
    end

    local baseBg = isFav and Color3.fromRGB(42,18,48) or T.card
    local btn=UI.btn(parent,{
        Size=UDim2.new(1,-Scale.px(8),0,Scale.px(50)),
        BackgroundColor3=baseBg, Text="", LayoutOrder=order, ZIndex=5, ClipsDescendants=true,
    })
    UI.corner(btn,Scale.px(8))
    if isFav then UI.stroke(btn, Color3.fromRGB(140, 30, 55), 1.5) else UI.stroke(btn, Color3.fromRGB(50, 25, 90), 1) end
    UI.hover(btn,baseBg,T.panel); UI.ripple(btn,T.neonB)

    UI.label(btn,{
        Size=UDim2.new(1,-Scale.px(90),isPreset and 0.54 or 1,0),
        Position=UDim2.new(0,P8,isPreset and 0.04 or 0,0),
        Text=sName, TextColor3=T.txt, TextSize=Scale.fs(12), Font=Enum.Font.BuilderSans,
        TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=5,
    })

    if isPreset then
        local tagIcon  = sData.url=="uploaded" and "⬆ " or sData.url=="drum_preset" and "🥁 " or sData.url=="drum_uploaded" and "⬆🥁" or sData.url=="guitar_preset" and "🎸 " or sData.url=="guitar_uploaded" and "⬆🎸" or "★ "
        local tagColor = sData.url=="uploaded" and T.neonG or sData.url=="drum_preset" and Color3.fromRGB(255,165,40) or sData.url=="drum_uploaded" and T.neonG or sData.url=="guitar_preset" and Color3.fromRGB(220,165,40) or sData.url=="guitar_uploaded" and T.neonG or T.neonY
        UI.label(btn,{
            Size=UDim2.new(0.55,-Scale.px(16),0.38,0), Position=UDim2.new(0,P8,0.58,0),
            Text=tagIcon..sData.category, TextColor3=tagColor, TextSize=Scale.fs(10),
            Font=Enum.Font.BuilderSans, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
        })
    end

    local starBtn=UI.btn(btn,{
        Size=UDim2.new(0,Scale.px(30),1,0),
        Position=UDim2.new(1,-Scale.px(32),0,0),
        BackgroundTransparency=1,
        Text=isFav and "♥" or "♥",
        TextColor3=isFav and T.neonR or T.txtDim,
        TextSize=Scale.fs(18), Font=Enum.Font.BuilderSans,
        ZIndex=7, AutoButtonColor=false,
    })

    if durText ~= "" then
        UI.label(btn,{
            Size=UDim2.new(0,Scale.px(44), isPreset and 0.38 or 0.5, 0),
            Position=UDim2.new(1,-Scale.px(78), isPreset and 0.58 or 0.25, 0),
            Text=durText, TextColor3=T.txtDim, TextSize=Scale.fs(10),
            Font=Enum.Font.BuilderSans, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=5,
        })
    end
    starBtn.MouseButton1Click:Connect(function()
        Favorites.toggle(sName,sData)
        local nowFav=Favorites.isFav(sName)
        starBtn.Text = nowFav and "♥" or "♥"
        starBtn.TextColor3 = nowFav and T.neonR or T.txtDim
        tw(btn,0.15,{BackgroundColor3 = nowFav and Color3.fromRGB(42,18,48) or T.card})
        if not nowFav and UI.stroke then
            for _,ch in ipairs(btn:GetChildren()) do
                if ch:IsA("UIStroke") then tw(ch,0.15,{Thickness=0}) end
            end
        end
        Toast.show(nowFav and "★ Added to Favorites" or "Removed from Favorites", "fav", 2)
    end)

    btn.MouseButton1Click:Connect(function()
        tw(btn,0.1,{BackgroundColor3=T.neon})
        local finalBg = Favorites.isFav(sName) and Color3.fromRGB(42,18,48) or T.card
        task.delay(0.16,function() tw(btn,0.14,{BackgroundColor3=finalBg}) end)
        selectSong(sName,sData)
    end)
    return btn
end

local function populateSongList(songs,filter)
    for _,c in ipairs(songList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local sorted={}
    for name in pairs(songs) do
        if not filter or name:lower():find(filter:lower(),1,true) then table.insert(sorted,name) end
    end
    table.sort(sorted,function(a,b) return a:lower()<b:lower() end)
    for i,name in ipairs(sorted) do makeSongBtn(songList,name,songs[name],i) end
    return sorted
end

loadLocalCategory = function(category)
    if Cache.category[category] then
        currentSongsTable=Cache.category[category]; populateSongList(currentSongsTable)
        local n=0; for _ in pairs(currentSongsTable) do n+=1 end
        songInfoLbl.Text="["..category.."] "..n.." songs"; return
    end
    local fileList = getMidiFilesForCategory(category)
    songInfoLbl.Text="Scanning... "..#fileList.." file(s)"
    local songs={}
    for _, entry in ipairs(fileList) do
        songs[entry.fname]={url="local", originalName=entry.fname, category=category, path=entry.path}
    end
    Cache.category[category]=songs; currentSongsTable=songs
    populateSongList(songs)
    local n=0; for _ in pairs(songs) do n+=1 end
    songInfoLbl.Text="["..category.."] "..n.." songs"
end

local function loadLocalDrumCategory(category)
    local drumKey="Drum:"..category
    if Cache.category[drumKey] then
        currentSongsTable=Cache.category[drumKey]; populateSongList(currentSongsTable)
        local n=0; for _ in pairs(currentSongsTable) do n+=1 end
        songInfoLbl.Text="[Drum/"..category.."] "..n.." songs"; return
    end
    local fileList=getRtxFilesForCategory(category)
    songInfoLbl.Text="Scanning drums... "..#fileList.." file(s)"
    local songs={}
    for _,entry in ipairs(fileList) do
        songs[entry.fname]={url="local", originalName=entry.fname, category=category, path=entry.path, isDrum=true}
    end
    Cache.category[drumKey]=songs; currentSongsTable=songs
    populateSongList(songs)
    local n=0; for _ in pairs(songs) do n+=1 end
    songInfoLbl.Text="[Drum/"..category.."] "..n.." songs"
end

local function loadPresetCategory(categoryName)
    _activePresetCat = categoryName
    local cacheKey="Preset:"..categoryName
    if Cache.category[cacheKey] then
        currentSongsTable=Cache.category[cacheKey]; populateSongList(currentSongsTable)
        local n=0; for _ in pairs(currentSongsTable) do n+=1 end
        songInfoLbl.Text="[Preset/"..categoryName.."] "..n.." songs"; return
    end
    songInfoLbl.Text="Loading presets..."
    local songs={}
    if categoryName=="All Songs" then
        for _,cat in ipairs(Config.CATEGORIES) do
            local subKey="Preset:"..cat.name
            if Cache.category[subKey] then
                for sn,sd in pairs(Cache.category[subKey]) do
                    if not songs[sn] then songs[sn]=sd end
                end
            elseif cat.file then
                local res=safeHttpGet(Config.RETURN_URL..cat.file)
                if res then
                    local list=parseList(res)
                    if list then
                        if not Cache.category[subKey] then Cache.category[subKey]={} end
                        for _,sn in ipairs(list) do
                            local sd={url="preset",category=cat.name,originalName=sn}
                            Cache.category[subKey][sn]=sd
                            if not songs[sn] then songs[sn]=sd end
                        end
                    end
                end
            end
        end
    else
        for _,cat in ipairs(Config.CATEGORIES) do
            if cat.name==categoryName and cat.file then
                local res=safeHttpGet(Config.RETURN_URL..cat.file)
                if res then
                    local list=parseList(res)
                    if list then
                        for _,sn in ipairs(list) do songs[sn]={url="preset",category=categoryName,originalName=sn} end
                    end
                end; break
            end
        end
    end
    Cache.category[cacheKey]=songs; currentSongsTable=songs
    populateSongList(songs)
    local n=0; for _ in pairs(songs) do n+=1 end
    songInfoLbl.Text="[Preset/"..categoryName.."] "..n.." songs"
end

loadUploadedSong = function(songName, category)
    local cKey="Uploaded:"..category
    if Cache.github[cKey] and Cache.github[cKey][songName] then
        local d=Cache.github[cKey][songName]; return d.notes,d.bpm,d.rawBytes
    end
    local baseUrl=Config.UPLOADED_PRESET_URL..urlEncode(catFolder(category,Config.UPLOADED_CATEGORIES)).."/"
    -- Try without extension first, then with .mid (some files are stored with .mid on GitHub)
    local res = safeHttpGet(baseUrl..urlEncode(songName))
    if not res then
        res = safeHttpGet(baseUrl..urlEncode(songName..".mid"))
    end
    if res then
        local bytes=table.create(#res)
        for i=1,#res do bytes[i]=res:byte(i) end
        local mp=MidiProcessor.new(); local proc=mp:processMidiBytes(bytes)
        local notes = proc.notes
        if not Cache.github[cKey] then Cache.github[cKey]={} end
        Cache.github[cKey][songName]={notes=notes,bpm=mp.tempo or 120,rawBytes=bytes}
        return notes, mp.tempo or 120, bytes
    end
    return nil,nil
end

local function loadUploadedCategory(categoryName)
    _activeUploadedCat = categoryName
    local cacheKey="Uploaded:"..categoryName
    if Cache.category[cacheKey] then
        currentSongsTable=Cache.category[cacheKey]; populateSongList(currentSongsTable)
        local n=0; for _ in pairs(currentSongsTable) do n+=1 end
        songInfoLbl.Text="[Uploaded/"..categoryName.."] "..n.." songs"; return
    end
    songInfoLbl.Text="Loading uploaded songs..."
    local songs={}

    if categoryName=="All Songs" then
        for _,cat in ipairs(Config.UPLOADED_CATEGORIES) do
            local subKey="Uploaded:"..cat.name
            if Cache.category[subKey] then
                for sn,sd in pairs(Cache.category[subKey]) do
                    if not songs[sn] then songs[sn]=sd end
                end
            elseif cat.file then
                local res=safeHttpGet(Config.UPLOADED_RETURN_URL..cat.file)
                if res then
                    local list=parseList(res)
                    if list then
                        if not Cache.category[subKey] then Cache.category[subKey]={} end
                        for _,sn in ipairs(list) do
                            local sd={url="uploaded",category=cat.name,originalName=sn}
                            Cache.category[subKey][sn]=sd
                            if not songs[sn] then songs[sn]=sd end
                        end
                    end
                end
            end
        end
    else
        for _,cat in ipairs(Config.UPLOADED_CATEGORIES) do
            if cat.name==categoryName and cat.file then
                local res=safeHttpGet(Config.UPLOADED_RETURN_URL..cat.file)
                if res then
                    local list=parseList(res)
                    if list then
                        for _,sn in ipairs(list) do
                            songs[sn]={url="uploaded",category=categoryName,originalName=sn}
                        end
                    end
                end; break
            end
        end
    end

    Cache.category[cacheKey]=songs; currentSongsTable=songs
    populateSongList(songs)
    local n=0; for _ in pairs(songs) do n+=1 end
    songInfoLbl.Text="[Uploaded/"..categoryName.."] "..n.." songs"
end

local function preloadAllPresets()
    if Cache.preloading then return end; Cache.preloading=true
    task.spawn(function()
        for _,cat in ipairs(Config.CATEGORIES) do
            if cat.file then
                task.spawn(function()
                    local function bump()
                        Cache.loaded+=1; if Cache.loaded>=7 then Cache.allPreloaded=true end
                    end
                    local res=safeHttpGet(Config.RETURN_URL..cat.file)
                    if not res then bump(); return end
                    local list=parseList(res)
                    if not list then bump(); return end
                    local cKey="Preset:"..cat.name
                    if not Cache.category[cKey] then Cache.category[cKey]={} end
                    for _,sn in ipairs(list) do
                        if not Cache.category[cKey][sn] then
                            Cache.category[cKey][sn]={url="preset",category=cat.name,originalName=sn}
                        end
                    end
                    bump()
                end)
            end
        end
    end)
end

local function preloadAllUploaded()
    if Cache.uploadedPreloading then return end; Cache.uploadedPreloading=true
    local total=#Config.UPLOADED_CATEGORIES
    task.spawn(function()
        for _,cat in ipairs(Config.UPLOADED_CATEGORIES) do
            if cat.file then
                task.spawn(function()
                    local bump=function()
                        Cache.uploadedLoaded+=1
                        if Cache.uploadedLoaded>=total then Cache.allUploadedPreloaded=true end
                    end
                    local res=safeHttpGet(Config.UPLOADED_RETURN_URL..cat.file)
                    if not res then bump(); return end
                    local list=parseList(res)
                    if not list then bump(); return end
                    local cKey="Uploaded:"..cat.name
                    if not Cache.category[cKey] then Cache.category[cKey]={} end
                    for _,sn in ipairs(list) do
                        if not Cache.category[cKey][sn] then
                            Cache.category[cKey][sn]={url="uploaded",category=cat.name,originalName=sn}
                        end
                    end
                    bump()
                end)
            end
        end
    end)
end

local loadDrumPresetCategory
local preloadAllDrumPresets
do
    local function drumDisplayToFilename(name)
        return name
    end

    local function loadDrumPresetSong(songName, category)
        local cKey = "DrumPreset:" .. category
        if Cache.github[cKey] and Cache.github[cKey][songName] then
            local d = Cache.github[cKey][songName]
            return d.notes, d.drumDuration
        end
        local fname = drumDisplayToFilename(songName) .. ".drm"
        local url = Config.DRUM_PRESET_URL .. urlEncode(category) .. "/" .. urlEncode(fname)
        local res = safeHttpGet(url)
        if res then
            local evts, totalSec = parseDrumMidi(res)
            if evts then
                if not Cache.github[cKey] then Cache.github[cKey] = {} end
                Cache.github[cKey][songName] = {notes=evts, drumDuration=totalSec or 0}
                return evts, totalSec or 0
            end
        end
        return nil, nil
    end

    loadDrumPresetCategory = function(categoryName)
        _activeDrumPresetCat = categoryName
        local cacheKey = "DrumPreset:" .. categoryName
        if Cache.category[cacheKey] then
            currentSongsTable = Cache.category[cacheKey]; populateSongList(currentSongsTable)
            local n=0; for _ in pairs(currentSongsTable) do n+=1 end
            songInfoLbl.Text = "[DrumPreset/"..categoryName.."] "..n.." songs"; return
        end
        songInfoLbl.Text = "Loading drum presets..."
        local songs = {}
        if categoryName == "All Songs" then
            for _,cat in ipairs(Config.DRUM_CATEGORIES) do
                local subKey = "DrumPreset:"..cat.name
                if Cache.category[subKey] then
                    for sn,sd in pairs(Cache.category[subKey]) do
                        if not songs[sn] then songs[sn]=sd end
                    end
                elseif cat.file then
                    local res = safeHttpGet(Config.DRUM_RETURN_URL..cat.file)
                    if res then
                        local list = parseList(res)
                        if list then
                            if not Cache.category[subKey] then Cache.category[subKey]={} end
                            for _,sn in ipairs(list) do
                                local dn = sn:gsub("%.drm$","")
                                local sd = {url="drum_preset", category=cat.name, originalName=dn, isDrum=true}
                                Cache.category[subKey][dn] = sd
                                if not songs[dn] then songs[dn]=sd end
                            end
                        end
                    end
                end
            end
        else
            for _,cat in ipairs(Config.DRUM_CATEGORIES) do
                if cat.name == categoryName and cat.file then
                    local res = safeHttpGet(Config.DRUM_RETURN_URL..cat.file)
                    if res then
                        local list = parseList(res)
                        if list then
                            for _,sn in ipairs(list) do
                                local dn = sn:gsub("%.drm$","")
                                songs[dn] = {url="drum_preset", category=categoryName, originalName=dn, isDrum=true}
                            end
                        end
                    end; break
                end
            end
        end
        Cache.category[cacheKey]=songs; currentSongsTable=songs
        populateSongList(songs)
        local n=0; for _ in pairs(songs) do n+=1 end
        songInfoLbl.Text = "[DrumPreset/"..categoryName.."] "..n.." songs"
    end

    preloadAllDrumPresets = function()
        if Cache.drumPreloading then return end; Cache.drumPreloading = true
        task.spawn(function()
            for _,cat in ipairs(Config.DRUM_CATEGORIES) do
                if cat.file then
                    task.spawn(function()
                        local res = safeHttpGet(Config.DRUM_RETURN_URL..cat.file)
                        if not res then return end
                        local list = parseList(res)
                        if not list then return end
                        local cKey = "DrumPreset:"..cat.name
                        if not Cache.category[cKey] then Cache.category[cKey]={} end
                        for _,sn in ipairs(list) do
                            local dn = sn:gsub("%.drm$","")
                            if not Cache.category[cKey][dn] then
                                Cache.category[cKey][dn] = {url="drum_preset", category=cat.name, originalName=dn, isDrum=true}
                            end
                        end
                    end)
                end
            end
        end)
    end

    State._loadDrumPresetSong = loadDrumPresetSong
end

-- ── Guitar Preset loading ────────────────────────────────────────────────────
local loadGuitarPresetCategory
local preloadAllGuitarPresets
do
    local function loadGuitarPresetSong(songName, category)
        local cKey = "GuitarPreset:"..category
        if Cache.github[cKey] and Cache.github[cKey][songName] then
            local d=Cache.github[cKey][songName]; return d.notes, d.bpm, d.rawBytes
        end
        local url = Config.GUITAR_PRESET_URL..urlEncode(category).."/"..urlEncode(songName..".gtr")
        local res = safeHttpGet(url)
        if res then
            local bytes=table.create(#res)
            for i=1,#res do bytes[i]=res:byte(i) end
            local mp=GuitarMidiProcessor.new(); local proc=mp:processMidiBytes(bytes)
            if not Cache.github[cKey] then Cache.github[cKey]={} end
            Cache.github[cKey][songName]={notes=proc.notes,bpm=mp.tempo or 120,rawBytes=bytes}
            return proc.notes, mp.tempo or 120, bytes
        end
        return nil,nil
    end

    loadGuitarPresetCategory = function(categoryName)
        _activeGuitarPresetCat = categoryName
        local cacheKey="GuitarPreset:"..categoryName
        if Cache.category[cacheKey] then
            currentSongsTable=Cache.category[cacheKey]; populateSongList(currentSongsTable)
            local n=0; for _ in pairs(currentSongsTable) do n+=1 end
            songInfoLbl.Text="[GuitarPreset/"..categoryName.."] "..n.." songs"; return
        end
        songInfoLbl.Text="Loading guitar presets..."
        local songs={}
        if categoryName=="All Songs" then
            for _,cat in ipairs(Config.GUITAR_CATEGORIES) do
                local subKey="GuitarPreset:"..cat.name
                if Cache.category[subKey] then
                    for sn,sd in pairs(Cache.category[subKey]) do
                        if not songs[sn] then songs[sn]=sd end
                    end
                elseif cat.file then
                    local res=safeHttpGet(Config.GUITAR_RETURN_URL..cat.file)
                    if res then
                        local list=parseList(res)
                        if list then
                            if not Cache.category[subKey] then Cache.category[subKey]={} end
                            for _,sn in ipairs(list) do
                                local sd={url="guitar_preset",category=cat.name,originalName=sn}
                                Cache.category[subKey][sn]=sd
                                if not songs[sn] then songs[sn]=sd end
                            end
                        end
                    end
                end
            end
        else
            for _,cat in ipairs(Config.GUITAR_CATEGORIES) do
                if cat.name==categoryName and cat.file then
                    local res=safeHttpGet(Config.GUITAR_RETURN_URL..cat.file)
                    if res then
                        local list=parseList(res)
                        if list then
                            for _,sn in ipairs(list) do
                                songs[sn]={url="guitar_preset",category=categoryName,originalName=sn}
                            end
                        end
                    end; break
                end
            end
        end
        Cache.category[cacheKey]=songs; currentSongsTable=songs
        populateSongList(songs)
        local n=0; for _ in pairs(songs) do n+=1 end
        songInfoLbl.Text="[GuitarPreset/"..categoryName.."] "..n.." songs"
    end

    preloadAllGuitarPresets = function()
        if Cache.guitarPreloading then return end; Cache.guitarPreloading=true
        task.spawn(function()
            for _,cat in ipairs(Config.GUITAR_CATEGORIES) do
                if cat.file then
                    task.spawn(function()
                        local res=safeHttpGet(Config.GUITAR_RETURN_URL..cat.file)
                        if not res then return end
                        local list=parseList(res)
                        if not list then return end
                        local cKey="GuitarPreset:"..cat.name
                        if not Cache.category[cKey] then Cache.category[cKey]={} end
                        for _,sn in ipairs(list) do
                            if not Cache.category[cKey][sn] then
                                Cache.category[cKey][sn]={url="guitar_preset",category=cat.name,originalName=sn}
                            end
                        end
                    end)
                end
            end
        end)
    end

    State._loadGuitarPresetSong = loadGuitarPresetSong
end

-- Returns "#N" if the category is already cached, else ""
local function cntStr(key)
    local t=Cache.category[key]; if not t then return "" end
    local n=0; for _ in pairs(t) do n=n+1 end; return tostring(n)
end
-- Attaches a right-side count badge to a category button
local function addCountBadge(btn,txt)
    if not txt or txt=="" then return end
    local lbl=UI.label(btn,{
        Size=UDim2.new(0,Scale.px(52),1,0),
        Position=UDim2.new(1,-Scale.px(58),0,0),
        Text=txt, TextColor3=T.txtDim,
        TextSize=Scale.fs(10), Font=Enum.Font.BuilderSansBold,
        TextXAlignment=Enum.TextXAlignment.Right, ZIndex=27,
    })
    lbl.BorderSizePixel=0
end

-- ── Guitar Uploaded loading ──────────────────────────────────────────────────
local preloadAllGuitarUploaded
local loadGuitarUploadedCategory
do
    local GU = {}

    GU.fetchCats = function()
        if Cache.guitarUploadedCats and #Cache.guitarUploadedCats > 0 then return Cache.guitarUploadedCats end
        local res=safeHttpGet(Config.GUITAR_UPLOADED_RETURN_URL.."categories.lua")
        local cats=(res and parseList(res)) or {}
        if #cats > 0 then Cache.guitarUploadedCats=cats end
        return cats
    end

    GU.loadSong = function(songName, category)
        local cKey="GuitarUploaded:"..category
        if Cache.github[cKey] and Cache.github[cKey][songName] then
            local d=Cache.github[cKey][songName]; return d.notes, d.bpm, d.rawBytes
        end
        local url=Config.GUITAR_UPLOADED_BASE_URL..urlEncode(category).."/"..urlEncode(songName..".gtr")
        local res=safeHttpGet(url)
        if res then
            local bytes=table.create(#res)
            for i=1,#res do bytes[i]=res:byte(i) end
            local mp=GuitarMidiProcessor.new(); local proc=mp:processMidiBytes(bytes)
            if not Cache.github[cKey] then Cache.github[cKey]={} end
            Cache.github[cKey][songName]={notes=proc.notes,bpm=mp.tempo or 120,rawBytes=bytes}
            return proc.notes, mp.tempo or 120, bytes
        end
        return nil,nil
    end

    GU.loadCategory = function(categoryName)
        _activeGuitarUploadedCat = categoryName
        local cacheKey="GuitarUploaded:"..categoryName
        if Cache.category[cacheKey] then
            currentSongsTable=Cache.category[cacheKey]; populateSongList(currentSongsTable)
            local n=0; for _ in pairs(currentSongsTable) do n+=1 end
            songInfoLbl.Text="[GuitarUploaded/"..categoryName.."] "..n.." songs"; return
        end
        songInfoLbl.Text="Loading guitar uploads..."
        local songs={}
        if categoryName=="All Songs" then
            for _,catName in ipairs(GU.fetchCats()) do
                local subKey="GuitarUploaded:"..catName
                if Cache.category[subKey] then
                    for sn,sd in pairs(Cache.category[subKey]) do
                        if not songs[sn] then songs[sn]=sd end
                    end
                else
                    local res=safeHttpGet(Config.GUITAR_UPLOADED_RETURN_URL.."songfiles/"..urlEncode(catName)..".lua")
                    if res then
                        local list=parseList(res)
                        if list then
                            if not Cache.category[subKey] then Cache.category[subKey]={} end
                            for _,sn in ipairs(list) do
                                local sd={url="guitar_uploaded",category=catName,originalName=sn}
                                Cache.category[subKey][sn]=sd
                                if not songs[sn] then songs[sn]=sd end
                            end
                        end
                    end
                end
            end
        else
            local res=safeHttpGet(Config.GUITAR_UPLOADED_RETURN_URL.."songfiles/"..urlEncode(categoryName)..".lua")
            if res then
                local list=parseList(res)
                if list then
                    for _,sn in ipairs(list) do
                        songs[sn]={url="guitar_uploaded",category=categoryName,originalName=sn}
                    end
                end
            end
        end
        Cache.category[cacheKey]=songs; currentSongsTable=songs
        populateSongList(songs)
        local n=0; for _ in pairs(songs) do n+=1 end
        songInfoLbl.Text="[GuitarUploaded/"..categoryName.."] "..n.." songs"
    end

    GU.buildMenu = function()
        local gMenu=GuitarBrowserUI.uploadedMenu
        for _,c in ipairs(gMenu:GetChildren()) do c:Destroy() end
        local gLayout=Instance.new("UIListLayout",gMenu)
        gLayout.Padding=UDim.new(0,Scale.px(3)); gLayout.SortOrder=Enum.SortOrder.LayoutOrder
        gLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            gMenu.CanvasSize=UDim2.new(0,0,0,gLayout.AbsoluteContentSize.Y+Scale.px(6))
        end)
        local cats=GU.fetchCats()
        local gOpts={}
        local _gfc=0; for _ in pairs(Favorites.get()) do _gfc=_gfc+1 end
        table.insert(gOpts,{label="♥  Guitar Favorites", col=T.neonR, action=State.loadFavoritesCategory, ctxt=(_gfc>0 and tostring(_gfc) or "")})
        table.insert(gOpts,{label="🕐 Guitar Recent",     col=T.neonY, action=State.loadRecentCategory,    ctxt=(#RecentlyPlayed.get()>0 and tostring(#RecentlyPlayed.get()) or "")})
        table.insert(gOpts,{label="── Guitar Uploads ──", col=T.neonG, action=nil})
        table.insert(gOpts,{label="All Guitar Uploads", col=T.neonG,
            action=function() GU.loadCategory("All Songs") end, ctxt=cntStr("GuitarUploaded:All Songs")})
        for _,catName in ipairs(cats) do
            local cn=catName
            local cnt=cntStr("GuitarUploaded:"..cn)
            if cnt ~= "0" then
                table.insert(gOpts,{label=cn, col=T.neonG,
                    action=function() GU.loadCategory(cn) end, ctxt=cnt})
            end
        end
        for i,opt in ipairs(gOpts) do
            if opt.action==nil then
                UI.label(gMenu,{
                    Size=UDim2.new(1,0,0,Scale.px(22)), BackgroundTransparency=1,
                    Text=opt.label, TextColor3=opt.col or T.txtDim, TextSize=Scale.fs(10),
                    Font=Enum.Font.BuilderSansBold, LayoutOrder=i, ZIndex=27,
                    TextXAlignment=Enum.TextXAlignment.Center,
                })
            else
                local gbtn=UI.btn(gMenu,{
                    Size=UDim2.new(1,0,0,Scale.px(30)),BackgroundColor3=T.card,
                    Text=opt.label,TextSize=Scale.fs(12),Font=Enum.Font.BuilderSans,
                    TextColor3=opt.col or T.neonG,TextXAlignment=Enum.TextXAlignment.Left,
                    LayoutOrder=i,ZIndex=27,
                })
                UI.corner(gbtn,Scale.px(6)); UI.hover(gbtn,T.card,T.panel)
                addCountBadge(gbtn,opt.ctxt)
                local gp=Instance.new("UIPadding",gbtn); gp.PaddingLeft=UDim.new(0,Scale.px(8))
                local captOpt=opt
                gbtn.MouseButton1Click:Connect(function()
                    captOpt.action()
                    gMenu.Visible=false; GuitarBrowserUI.uploadedMenuOpen=false
                    gMenu.Size=UDim2.new(1,-P8*2,0,0)
                    GuitarBrowserUI.uploadedDropBtn.Text="⬆ "..captOpt.label.." ▾"
                end)
            end
        end
        return #cats
    end

    preloadAllGuitarUploaded = function()
        if Cache.guitarUploadedPreloading then return end; Cache.guitarUploadedPreloading=true
        task.spawn(function()
            for _,catName in ipairs(GU.fetchCats()) do
                task.spawn(function()
                    local res=safeHttpGet(Config.GUITAR_UPLOADED_RETURN_URL.."songfiles/"..urlEncode(catName)..".lua")
                    if not res then return end
                    local list=parseList(res)
                    if not list then return end
                    local cKey="GuitarUploaded:"..catName
                    if not Cache.category[cKey] then Cache.category[cKey]={} end
                    for _,sn in ipairs(list) do
                        if not Cache.category[cKey][sn] then
                            Cache.category[cKey][sn]={url="guitar_uploaded",category=catName,originalName=sn}
                        end
                    end
                end)
            end
        end)
    end

    loadGuitarUploadedCategory = GU.loadCategory
    State._loadGuitarUploadedSong = GU.loadSong
    GuitarBrowserUI._buildUploadedMenu = GU.buildMenu
end

-- ── Guitar local category loader ─────────────────────────────────────────────
local function loadLocalGuitarCategory(category)
    local gKey="Guitar:"..category
    if Cache.category[gKey] then
        currentSongsTable=Cache.category[gKey]; populateSongList(currentSongsTable)
        local n=0; for _ in pairs(currentSongsTable) do n+=1 end
        songInfoLbl.Text="[Guitar/"..category.."] "..n.." songs"; return
    end
    local fileList=getGtrFilesForCategory(category)
    songInfoLbl.Text="Scanning guitars... "..#fileList.." file(s)"
    local songs={}
    for _,entry in ipairs(fileList) do
        songs[entry.fname]={url="local",originalName=entry.fname,category=category,path=entry.path,isGuitar=true}
    end
    Cache.category[gKey]=songs; currentSongsTable=songs
    populateSongList(songs)
    local n=0; for _ in pairs(songs) do n+=1 end
    songInfoLbl.Text="[Guitar/"..category.."] "..n.." songs"
end
-- Forward declarations: assigned after the DU block so closures inside DU.buildMenu
-- can capture the variable and call through it once the real function is defined.
-- loadFavoritesCategory / loadRecentCategory moved to State table to stay under Luau's 200 local-register limit

-- ============================================================
--  DRUM UPLOADED — data & logic (UI wiring is below closeAllDropdowns)
-- ============================================================
-- preloadAllDrumUploaded stored in State table to avoid exceeding Luau's 200-local-register limit
;(function() -- preloadAllDrumUploaded block: isolated in true function scope to avoid 200 local-register limit
    -- Namespace table: keeps all helpers off the local variable stack
    local DU = {}

    DU.fetchCats = function()
        if Cache.drumUploadedCats then return Cache.drumUploadedCats end
        local res = safeHttpGet(Config.DRUM_UPLOADED_RETURN_URL.."categories.lua")
        local cats = (res and parseList(res)) or {}
        Cache.drumUploadedCats = cats
        return cats
    end

    DU.loadSong = function(songName, category)
        local cKey = "DrumUploaded:"..category
        if Cache.github[cKey] and Cache.github[cKey][songName] then
            local d = Cache.github[cKey][songName]
            return d.notes, d.drumDuration
        end
        local url = Config.DRUM_UPLOADED_BASE_URL
                    .."Categories/"..urlEncode(category).."/"..urlEncode(songName..".drm")
        local res = safeHttpGet(url)
        if res then
            local evts, totalSec = parseDrumMidi(res)
            if evts then
                if not Cache.github[cKey] then Cache.github[cKey]={} end
                Cache.github[cKey][songName]={notes=evts, drumDuration=totalSec or 0}
                return evts, totalSec or 0
            end
        end
        return nil, nil
    end

    DU.loadCategory = function(categoryName)
        local cacheKey = "DrumUploaded:"..categoryName
        if Cache.category[cacheKey] then
            currentSongsTable=Cache.category[cacheKey]; populateSongList(currentSongsTable)
            local n=0; for _ in pairs(currentSongsTable) do n+=1 end
            songInfoLbl.Text="[DrumUploaded/"..categoryName.."] "..n.." songs"; return
        end
        songInfoLbl.Text="Loading drum uploads..."
        local songs={}
        if categoryName=="All Songs" then
            for _,catName in ipairs(DU.fetchCats()) do
                local subKey="DrumUploaded:"..catName
                if Cache.category[subKey] then
                    for sn,sd in pairs(Cache.category[subKey]) do
                        if not songs[sn] then songs[sn]=sd end
                    end
                else
                    local res=safeHttpGet(Config.DRUM_UPLOADED_RETURN_URL
                                          .."songfiles/"..urlEncode(catName)..".lua")
                    if res then
                        local list=parseList(res)
                        if list then
                            if not Cache.category[subKey] then Cache.category[subKey]={} end
                            for _,sn in ipairs(list) do
                                local sd={url="drum_uploaded",category=catName,originalName=sn,isDrum=true}
                                Cache.category[subKey][sn]=sd
                                if not songs[sn] then songs[sn]=sd end
                            end
                        end
                    end
                end
            end
        else
            local res=safeHttpGet(Config.DRUM_UPLOADED_RETURN_URL
                                   .."songfiles/"..urlEncode(categoryName)..".lua")
            if res then
                local list=parseList(res)
                if list then
                    for _,sn in ipairs(list) do
                        songs[sn]={url="drum_uploaded",category=categoryName,originalName=sn,isDrum=true}
                    end
                end
            end
        end
        Cache.category[cacheKey]=songs; currentSongsTable=songs
        populateSongList(songs)
        local n=0; for _ in pairs(songs) do n+=1 end
        songInfoLbl.Text="[DrumUploaded/"..categoryName.."] "..n.." songs"
    end

    -- Builds the dropdown menu and returns the number of dynamic categories fetched
    DU.buildMenu = function()
        local dMenu=DrumBrowserUI.uploadedMenu
        for _,c in ipairs(dMenu:GetChildren()) do c:Destroy() end
        local dLayout=Instance.new("UIListLayout",dMenu)
        dLayout.Padding=UDim.new(0,Scale.px(3)); dLayout.SortOrder=Enum.SortOrder.LayoutOrder
        dLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            dMenu.CanvasSize=UDim2.new(0,0,0,dLayout.AbsoluteContentSize.Y+Scale.px(6))
        end)
        local cats=DU.fetchCats()
        local dOpts={}
        local _dfc=0; for _ in pairs(Favorites.get()) do _dfc=_dfc+1 end
        table.insert(dOpts,{label="♥  Drum Favorites",   col=T.neonR, action=State.loadFavoritesCategory, ctxt=(_dfc>0 and tostring(_dfc) or "")})
        table.insert(dOpts,{label="🕐 Drum Recent",       col=T.neonY, action=State.loadRecentCategory,    ctxt=(#RecentlyPlayed.get()>0 and tostring(#RecentlyPlayed.get()) or "")})
        table.insert(dOpts,{label="── Drum Uploads ──", col=T.neonG, action=nil})
        table.insert(dOpts,{label="All Drum Uploads", col=T.neonG,
            action=function() DU.loadCategory("All Songs") end, ctxt=cntStr("DrumUploaded:All Songs")})
        for _,catName in ipairs(cats) do
            local cn=catName
            local cnt=cntStr("DrumUploaded:"..cn)
            if cnt ~= "0" then
                table.insert(dOpts,{label=cn, col=T.neonG,
                    action=function() DU.loadCategory(cn) end, ctxt=cnt})
            end
        end
        for i,opt in ipairs(dOpts) do
            if opt.action==nil then
                UI.label(dMenu,{
                    Size=UDim2.new(1,0,0,Scale.px(22)), BackgroundTransparency=1,
                    Text=opt.label, TextColor3=opt.col or T.txtDim, TextSize=Scale.fs(10),
                    Font=Enum.Font.BuilderSansBold, LayoutOrder=i, ZIndex=27,
                    TextXAlignment=Enum.TextXAlignment.Center,
                })
            else
                local dbtn=UI.btn(dMenu,{
                    Size=UDim2.new(1,0,0,Scale.px(30)), BackgroundColor3=T.card,
                    Text=opt.label, TextSize=Scale.fs(12), Font=Enum.Font.BuilderSans,
                    TextColor3=opt.col or T.neonG, TextXAlignment=Enum.TextXAlignment.Left,
                    LayoutOrder=i, ZIndex=27,
                })
                UI.corner(dbtn,Scale.px(6)); UI.hover(dbtn,T.card,T.panel)
                addCountBadge(dbtn,opt.ctxt)
                local dp=Instance.new("UIPadding",dbtn); dp.PaddingLeft=UDim.new(0,Scale.px(8))
                local captOpt=opt
                dbtn.MouseButton1Click:Connect(function()
                    captOpt.action()
                    dMenu.Visible=false; DrumBrowserUI.uploadedMenuOpen=false
                    dMenu.Size=UDim2.new(1,-P8*2,0,0)
                    DrumBrowserUI.uploadedDropBtn.Text="⬆ "..captOpt.label.." ▾"
                end)
            end
        end
        return #cats
    end

    State.preloadAllDrumUploaded = function()
        if Cache.drumUploadedPreloading then return end; Cache.drumUploadedPreloading=true
        task.spawn(function()
            for _,catName in ipairs(DU.fetchCats()) do
                task.spawn(function()
                    local res=safeHttpGet(Config.DRUM_UPLOADED_RETURN_URL
                                          .."songfiles/"..urlEncode(catName)..".lua")
                    if not res then return end
                    local list=parseList(res)
                    if not list then return end
                    local cKey="DrumUploaded:"..catName
                    if not Cache.category[cKey] then Cache.category[cKey]={} end
                    for _,sn in ipairs(list) do
                        if not Cache.category[cKey][sn] then
                            Cache.category[cKey][sn]={url="drum_uploaded",category=catName,
                                                       originalName=sn,isDrum=true}
                        end
                    end
                end)
            end
        end)
    end

    State._loadDrumUploadedSong = DU.loadSong
    -- Store buildMenu on DrumBrowserUI so the click handler (wired below) can reach it
    DrumBrowserUI._buildUploadedMenu = DU.buildMenu
end)() -- end preloadAllDrumUploaded IIFE

State.loadFavoritesCategory = function()
    local songs={}
    for name,meta in pairs(Favorites.get()) do
        local s={url=meta.url, category=meta.category or "", originalName=meta.originalName or name,
                 bpm=meta.bpm or 120, path=meta.path}
        if meta.url=="preset" then
            local gc=Cache.github[meta.category]
            if gc and gc[meta.originalName] then
                s.notes=gc[meta.originalName].notes; s.bpm=gc[meta.originalName].bpm
            end
        else
            local cc=Cache.category[meta.category]
            if cc and cc[name] then
                s.notes=cc[name].notes
            elseif meta.path then
                local bytes=readMidiFile(meta.path)
                if bytes then
                    local mp = State.guitarMode and GuitarMidiProcessor.new() or MidiProcessor.new()
                    local proc=mp:processMidiBytes(bytes)
                    s.notes=proc.notes; s.bpm=mp.tempo or 120
                end
            end
        end
        songs[name]=s
    end
    currentSongsTable=songs
    populateSongList(songs)
    local n=0; for _ in pairs(Favorites.get()) do n+=1 end
    local modeTag = State.drumMode and "🥁 Drum " or State.guitarMode and "🎸 Guitar " or "🎹 Piano "
    songInfoLbl.Text= modeTag.."♥ Favorites — "..n.." song".. (n==1 and "" or "s")
end

State.loadRecentCategory = function()
    for _,c in ipairs(songList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local songs={}
    for i,entry in ipairs(RecentlyPlayed.get()) do
        local s={url=entry.url, category=entry.category or "", originalName=entry.originalName or entry.name,
                 bpm=entry.bpm or 120, path=entry.path}
        if entry.url=="preset" then
            local gc=Cache.github[entry.category]
            if gc and gc[entry.originalName] then s.notes=gc[entry.originalName].notes end
        else
            local cc=Cache.category[entry.category]
            if cc and cc[entry.name] then s.notes=cc[entry.name].notes end
        end
        songs[entry.name]=s
        makeSongBtn(songList, entry.name, s, i)  -- preserve recency order, skip sort
    end
    currentSongsTable=songs
    local n=#RecentlyPlayed.get()
    local modeTag2 = State.drumMode and "🥁 Drum " or State.guitarMode and "🎸 Guitar " or "🎹 Piano "
    songInfoLbl.Text=modeTag2.."🕐 Recently Played — "..n.." song"..(n==1 and "" or "s")
end

-- State.presetMenuOpen/State.catMenuOpen/State.uploadedMenuOpen moved into State to stay under Luau's 200 local-register limit
State.presetMenuOpen=false
State.catMenuOpen=false
State.uploadedMenuOpen=false

;(function() -- _buildMenusAndDropdowns: isolated to avoid 200 local-register limit
local function buildPresetMenu()
    for _,c in ipairs(presetMenu:GetChildren()) do c:Destroy() end
    local layout=Instance.new("UIListLayout",presetMenu)
    layout.Padding=UDim.new(0,Scale.px(3)); layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        presetMenu.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+Scale.px(6))
    end)
    local options={}
    local _fc=0; for _ in pairs(Favorites.get()) do _fc=_fc+1 end
    table.insert(options,{label="♥  Favorites",      col=T.neonR,  action=State.loadFavoritesCategory, ctxt=(_fc>0 and tostring(_fc) or "")})
    table.insert(options,{label="🕐 Recently Played", col=T.neonY,  action=State.loadRecentCategory,    ctxt=(#RecentlyPlayed.get()>0 and tostring(#RecentlyPlayed.get()) or "")})
    table.insert(options,{label="── Preset ──",      col=T.txtDim, action=nil})  -- separator
    table.insert(options,{label="All Preset Songs",action=function() loadPresetCategory("All Songs") end, ctxt=cntStr("Preset:All Songs")})
    for _,cat in ipairs(Config.CATEGORIES) do
        if cat.file then
            local cn=cat.name
            table.insert(options,{label=cn,action=function() loadPresetCategory(cn) end, ctxt=cntStr("Preset:"..cn)})
        end
    end
    for i,opt in ipairs(options) do
        if opt.action == nil then
            local lbl=UI.label(presetMenu,{
                Size=UDim2.new(1,0,0,Scale.px(22)), BackgroundTransparency=1,
                Text=opt.label, TextColor3=opt.col or T.txtDim, TextSize=Scale.fs(10),
                Font=Enum.Font.BuilderSansBold, LayoutOrder=i, ZIndex=26,
                TextXAlignment=Enum.TextXAlignment.Center,
            })
        else
            local btn=UI.btn(presetMenu,{
                Size=UDim2.new(1,0,0,Scale.px(30)),BackgroundColor3=T.card,
                Text=opt.label,TextSize=Scale.fs(12),Font=Enum.Font.BuilderSans,
                TextColor3=opt.col or T.txt,TextXAlignment=Enum.TextXAlignment.Left,
                LayoutOrder=i,ZIndex=26,
            })
            UI.corner(btn,Scale.px(6)); UI.stroke(btn,Color3.fromRGB(50,25,90),1); UI.hover(btn,T.card,T.panel)
            addCountBadge(btn,opt.ctxt)
            local p=Instance.new("UIPadding",btn); p.PaddingLeft=UDim.new(0,Scale.px(8))
            btn.MouseButton1Click:Connect(function()
                opt.action(); presetMenu.Visible=false; State.presetMenuOpen=false
                presetMenu.Size=UDim2.new(1,-P8*2,0,0)
                presetDropBtn.Text="★ "..opt.label.." v"
            end)
        end
    end
end

local function buildLocalMenu()
    for _,c in ipairs(catMenu:GetChildren()) do c:Destroy() end
    local layout=Instance.new("UIListLayout",catMenu)
    layout.Padding=UDim.new(0,Scale.px(3)); layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        catMenu.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+Scale.px(6))
    end)
    local options={}
    local _fc=0; for _ in pairs(Favorites.get()) do _fc=_fc+1 end
    if State.drumMode then
        table.insert(options,{label="♥  Drum Favorites",   col=T.neonR,  action=State.loadFavoritesCategory, ctxt=(_fc>0 and tostring(_fc) or "")})
        table.insert(options,{label="🕐 Drum Recent",       col=T.neonY,  action=State.loadRecentCategory,    ctxt=(#RecentlyPlayed.get()>0 and tostring(#RecentlyPlayed.get()) or "")})
        table.insert(options,{label="── Drum Local ──", col=T.txtDim, action=nil})
        local _drumCats=getFolderCategoriesDrum()
        table.insert(options,{label="All Drum Songs", action=function() loadLocalDrumCategory("All Songs") end, ctxt=cntStr("Drum:All Songs")})
        for _,cat in ipairs(_drumCats) do
            local cn=cat
            table.insert(options,{label=cn, action=function() loadLocalDrumCategory(cn) end, ctxt=cntStr("Drum:"..cn)})
        end
    elseif State.guitarMode then
        table.insert(options,{label="♥  Guitar Favorites",  col=T.neonR,  action=State.loadFavoritesCategory, ctxt=(_fc>0 and tostring(_fc) or "")})
        table.insert(options,{label="🕐 Guitar Recent",      col=T.neonY,  action=State.loadRecentCategory,    ctxt=(#RecentlyPlayed.get()>0 and tostring(#RecentlyPlayed.get()) or "")})
        table.insert(options,{label="── Guitar Local ──", col=T.txtDim, action=nil})
        local _gtrCats=getFolderCategoriesGuitar()
        table.insert(options,{label="All Guitar Songs", action=function() loadLocalGuitarCategory("All Songs") end, ctxt=cntStr("Guitar:All Songs")})
        for _,cat in ipairs(_gtrCats) do
            local cn=cat
            table.insert(options,{label=cn, action=function() loadLocalGuitarCategory(cn) end, ctxt=cntStr("Guitar:"..cn)})
        end
    else
        table.insert(options,{label="♥  Favorites",       col=T.neonR,  action=State.loadFavoritesCategory, ctxt=(_fc>0 and tostring(_fc) or "")})
        table.insert(options,{label="🕐 Recently Played",  col=T.neonY,  action=State.loadRecentCategory,    ctxt=(#RecentlyPlayed.get()>0 and tostring(#RecentlyPlayed.get()) or "")})
        table.insert(options,{label="── Local ──",         col=T.txtDim, action=nil})
        local _localCats=getFolderCategories()
        table.insert(options,{label="All Local Songs",action=function() loadLocalCategory("All Songs") end, ctxt=cntStr("All Songs")})
        for _,cat in ipairs(_localCats) do
            local cn=cat
            table.insert(options,{label=cn,action=function() loadLocalCategory(cn) end, ctxt=cntStr(cn)})
        end
    end
    for i,opt in ipairs(options) do
        if opt.action == nil then
            local lbl=UI.label(catMenu,{
                Size=UDim2.new(1,0,0,Scale.px(22)), BackgroundTransparency=1,
                Text=opt.label, TextColor3=opt.col or T.txtDim, TextSize=Scale.fs(10),
                Font=Enum.Font.BuilderSansBold, LayoutOrder=i, ZIndex=26,
                TextXAlignment=Enum.TextXAlignment.Center,
            })
        else
            local btn=UI.btn(catMenu,{
                Size=UDim2.new(1,0,0,Scale.px(30)),BackgroundColor3=T.card,
                Text=opt.label,TextSize=Scale.fs(12),Font=Enum.Font.BuilderSans,
                TextColor3=opt.col or T.txt,TextXAlignment=Enum.TextXAlignment.Left,
                LayoutOrder=i,ZIndex=26,
            })
            UI.corner(btn,Scale.px(6)); UI.stroke(btn,Color3.fromRGB(50,25,90),1); UI.hover(btn,T.card,T.panel)
            addCountBadge(btn,opt.ctxt)
            local p=Instance.new("UIPadding",btn); p.PaddingLeft=UDim.new(0,Scale.px(8))
            btn.MouseButton1Click:Connect(function()
                opt.action(); catMenu.Visible=false; State.catMenuOpen=false
                catMenu.Size=UDim2.new(1,-P8*2,0,0)
                localDropBtn.Text="▶ "..opt.label.." v"
            end)
        end
    end
end

local function buildUploadedMenu()
    for _,c in ipairs(uploadedMenu:GetChildren()) do c:Destroy() end
    local layout=Instance.new("UIListLayout",uploadedMenu)
    layout.Padding=UDim.new(0,Scale.px(3)); layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        uploadedMenu.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+Scale.px(6))
    end)
    local options={}
    table.insert(options,{label="── Uploaded ──", col=T.neonG, action=nil})
    table.insert(options,{label="All Uploaded Songs", col=T.neonG, action=function() loadUploadedCategory("All Songs") end, ctxt=cntStr("Uploaded:All Songs")})
    for _,cat in ipairs(Config.UPLOADED_CATEGORIES) do
        local cn=cat.name
        table.insert(options,{label=cn, col=T.neonG, action=function() loadUploadedCategory(cn) end, ctxt=cntStr("Uploaded:"..cn)})
    end
    for i,opt in ipairs(options) do
        if opt.action==nil then
            UI.label(uploadedMenu,{
                Size=UDim2.new(1,0,0,Scale.px(22)), BackgroundTransparency=1,
                Text=opt.label, TextColor3=opt.col or T.txtDim, TextSize=Scale.fs(10),
                Font=Enum.Font.BuilderSansBold, LayoutOrder=i, ZIndex=26,
                TextXAlignment=Enum.TextXAlignment.Center,
            })
        else
            local btn=UI.btn(uploadedMenu,{
                Size=UDim2.new(1,0,0,Scale.px(30)),BackgroundColor3=T.card,
                Text=opt.label,TextSize=Scale.fs(12),Font=Enum.Font.BuilderSans,
                TextColor3=opt.col or T.neonG,TextXAlignment=Enum.TextXAlignment.Left,
                LayoutOrder=i,ZIndex=26,
            })
            UI.corner(btn,Scale.px(6)); UI.stroke(btn,Color3.fromRGB(50,25,90),1); UI.hover(btn,T.card,T.panel)
            addCountBadge(btn,opt.ctxt)
            local p=Instance.new("UIPadding",btn); p.PaddingLeft=UDim.new(0,Scale.px(8))
            btn.MouseButton1Click:Connect(function()
                opt.action(); uploadedMenu.Visible=false; State.uploadedMenuOpen=false
                uploadedMenu.Size=UDim2.new(1,-P8*2,0,0)
                uploadedDropBtn.Text="⬆ "..opt.label.." v"
            end)
        end
    end
end

local function closeAllDropdowns()
    if State.presetMenuOpen then
        State.presetMenuOpen=false; tw(presetMenu,0.15,{Size=UDim2.new(1,-P8*2,0,0)})
        task.delay(0.18,function() presetMenu.Visible=false end)
    end
    if State.catMenuOpen then
        State.catMenuOpen=false; tw(catMenu,0.15,{Size=UDim2.new(1,-P8*2,0,0)})
        task.delay(0.18,function() catMenu.Visible=false end)
    end
    if State.uploadedMenuOpen then
        State.uploadedMenuOpen=false; tw(uploadedMenu,0.15,{Size=UDim2.new(1,-P8*2,0,0)})
        task.delay(0.18,function() uploadedMenu.Visible=false end)
    end
    if State.drumPresetMenuOpen then
        State.drumPresetMenuOpen=false; tw(DrumBrowserUI.menu,0.15,{Size=UDim2.new(1,-P8*2,0,0)})
        task.delay(0.18,function() DrumBrowserUI.menu.Visible=false end)
    end
    if DrumBrowserUI.uploadedMenuOpen then
        DrumBrowserUI.uploadedMenuOpen=false
        tw(DrumBrowserUI.uploadedMenu,0.15,{Size=UDim2.new(1,-P8*2,0,0)})
        task.delay(0.18,function() DrumBrowserUI.uploadedMenu.Visible=false end)
    end
    if GuitarBrowserUI.menuOpen then
        GuitarBrowserUI.menuOpen=false; tw(GuitarBrowserUI.menu,0.15,{Size=UDim2.new(1,-P8*2,0,0)})
        task.delay(0.18,function() GuitarBrowserUI.menu.Visible=false end)
    end
    if GuitarBrowserUI.uploadedMenuOpen then
        GuitarBrowserUI.uploadedMenuOpen=false
        tw(GuitarBrowserUI.uploadedMenu,0.15,{Size=UDim2.new(1,-P8*2,0,0)})
        task.delay(0.18,function() GuitarBrowserUI.uploadedMenu.Visible=false end)
    end
end

presetDropBtn.MouseButton1Click:Connect(function()
    local wasOpen=State.presetMenuOpen
    closeAllDropdowns()
    if not wasOpen then
        State.presetMenuOpen=true
        buildPresetMenu(); presetMenu.Visible=true; presetMenu.Size=UDim2.new(1,-P8*2,0,0)
        local totalH=math.min(Scale.px(220),(#Config.CATEGORIES+4)*Scale.px(30)+Scale.px(20))
        twBack(presetMenu,0.25,{Size=UDim2.new(1,-P8*2,0,totalH)})
    end
end)

uploadedDropBtn.MouseButton1Click:Connect(function()
    local wasOpen=State.uploadedMenuOpen
    closeAllDropdowns()
    if not wasOpen then
        State.uploadedMenuOpen=true
        buildUploadedMenu(); uploadedMenu.Visible=true; uploadedMenu.Size=UDim2.new(1,-P8*2,0,0)
        local totalH=math.min(Scale.px(220),(#Config.UPLOADED_CATEGORIES+2)*Scale.px(30)+Scale.px(30))
        twBack(uploadedMenu,0.25,{Size=UDim2.new(1,-P8*2,0,totalH)})
    end
end)

DrumBrowserUI.dropBtn.MouseButton1Click:Connect(function()
    local wasOpen=State.drumPresetMenuOpen
    closeAllDropdowns()
    if not wasOpen then
        State.drumPresetMenuOpen=true
        local dMenu = DrumBrowserUI.menu
        for _,c in ipairs(dMenu:GetChildren()) do c:Destroy() end
        local dLayout=Instance.new("UIListLayout",dMenu)
        dLayout.Padding=UDim.new(0,Scale.px(3)); dLayout.SortOrder=Enum.SortOrder.LayoutOrder
        dLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            dMenu.CanvasSize=UDim2.new(0,0,0,dLayout.AbsoluteContentSize.Y+Scale.px(6))
        end)
        local drumOrange=Color3.fromRGB(255,165,40)
        local dOpts={}
        local _dpfc=0; for _ in pairs(Favorites.get()) do _dpfc=_dpfc+1 end
        table.insert(dOpts,{label="♥  Drum Favorites",   col=T.neonR, action=State.loadFavoritesCategory, ctxt=(_dpfc>0 and tostring(_dpfc) or "")})
        table.insert(dOpts,{label="🕐 Drum Recent",       col=T.neonY, action=State.loadRecentCategory,    ctxt=(#RecentlyPlayed.get()>0 and tostring(#RecentlyPlayed.get()) or "")})
        table.insert(dOpts,{label="── Drum Presets ──", col=drumOrange, action=nil})
        table.insert(dOpts,{label="All Drum Presets", col=drumOrange, action=function() loadDrumPresetCategory("All Songs") end, ctxt=cntStr("DrumPreset:All Songs")})
        for _,cat in ipairs(Config.DRUM_CATEGORIES) do
            if cat.file then
                local cn=cat.name
                local cnt=cntStr("DrumPreset:"..cn)
                if cnt ~= "0" then
                    table.insert(dOpts,{label=cn, col=drumOrange, action=function() loadDrumPresetCategory(cn) end, ctxt=cnt})
                end
            end
        end
        for i,opt in ipairs(dOpts) do
            if opt.action==nil then
                UI.label(dMenu,{
                    Size=UDim2.new(1,0,0,Scale.px(22)), BackgroundTransparency=1,
                    Text=opt.label, TextColor3=opt.col or T.txtDim, TextSize=Scale.fs(10),
                    Font=Enum.Font.BuilderSansBold, LayoutOrder=i, ZIndex=27,
                    TextXAlignment=Enum.TextXAlignment.Center,
                })
            else
                local dbtn=UI.btn(dMenu,{
                    Size=UDim2.new(1,0,0,Scale.px(30)),BackgroundColor3=T.card,
                    Text=opt.label,TextSize=Scale.fs(12),Font=Enum.Font.BuilderSans,
                    TextColor3=opt.col or drumOrange,TextXAlignment=Enum.TextXAlignment.Left,
                    LayoutOrder=i,ZIndex=27,
                })
                UI.corner(dbtn,Scale.px(6)); UI.hover(dbtn,T.card,T.panel)
                addCountBadge(dbtn,opt.ctxt)
                local dp=Instance.new("UIPadding",dbtn); dp.PaddingLeft=UDim.new(0,Scale.px(8))
                dbtn.MouseButton1Click:Connect(function()
                    opt.action(); dMenu.Visible=false; State.drumPresetMenuOpen=false
                    dMenu.Size=UDim2.new(1,-P8*2,0,0)
                    DrumBrowserUI.dropBtn.Text="🥁 "..opt.label.." v"
                end)
            end
        end
        dMenu.Visible=true; dMenu.Size=UDim2.new(1,-P8*2,0,0)
        local totalH=math.min(Scale.px(220),(#Config.DRUM_CATEGORIES+2)*Scale.px(30)+Scale.px(20))
        twBack(dMenu,0.25,{Size=UDim2.new(1,-P8*2,0,totalH)})
    end
end)

localDropBtn.MouseButton1Click:Connect(function()
    local wasOpen=State.catMenuOpen
    closeAllDropdowns()
    if not wasOpen then
        State.catMenuOpen=true
        buildLocalMenu(); catMenu.Visible=true; catMenu.Size=UDim2.new(1,-P8*2,0,0)
        local cats = State.drumMode and getFolderCategoriesDrum() or getFolderCategories()
        local totalH=math.min(Scale.px(220),(#cats+4)*Scale.px(30)+Scale.px(20))
        twBack(catMenu,0.25,{Size=UDim2.new(1,-P8*2,0,totalH)})
    end
end)

DrumBrowserUI.uploadedDropBtn.MouseButton1Click:Connect(function()
    local wasOpen=DrumBrowserUI.uploadedMenuOpen
    closeAllDropdowns()
    if not wasOpen then
        DrumBrowserUI.uploadedMenuOpen=true
        local nCats=DrumBrowserUI._buildUploadedMenu()
        local dMenu=DrumBrowserUI.uploadedMenu
        dMenu.Visible=true; dMenu.Size=UDim2.new(1,-P8*2,0,0)
        local totalH=math.min(Scale.px(220),(nCats+2)*Scale.px(30)+Scale.px(20))
        twBack(dMenu,0.25,{Size=UDim2.new(1,-P8*2,0,totalH)})
    end
end)

-- ── Guitar preset dropdown ────────────────────────────────────────────────────
GuitarBrowserUI.dropBtn.MouseButton1Click:Connect(function()
    local wasOpen=GuitarBrowserUI.menuOpen
    closeAllDropdowns()
    if not wasOpen then
        GuitarBrowserUI.menuOpen=true
        local gMenu=GuitarBrowserUI.menu
        for _,c in ipairs(gMenu:GetChildren()) do c:Destroy() end
        local gLayout=Instance.new("UIListLayout",gMenu)
        gLayout.Padding=UDim.new(0,Scale.px(3)); gLayout.SortOrder=Enum.SortOrder.LayoutOrder
        gLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            gMenu.CanvasSize=UDim2.new(0,0,0,gLayout.AbsoluteContentSize.Y+Scale.px(6))
        end)
        local gtrGold=Color3.fromRGB(220,165,40)
        local gOpts={}
        local _gpfc=0; for _ in pairs(Favorites.get()) do _gpfc=_gpfc+1 end
        table.insert(gOpts,{label="♥  Guitar Favorites",  col=T.neonR, action=State.loadFavoritesCategory, ctxt=(_gpfc>0 and tostring(_gpfc) or "")})
        table.insert(gOpts,{label="🕐 Guitar Recent",      col=T.neonY, action=State.loadRecentCategory,    ctxt=(#RecentlyPlayed.get()>0 and tostring(#RecentlyPlayed.get()) or "")})
        table.insert(gOpts,{label="── Guitar Presets ──", col=gtrGold, action=nil})
        table.insert(gOpts,{label="All Guitar Presets", col=gtrGold,
            action=function() loadGuitarPresetCategory("All Songs") end, ctxt=cntStr("GuitarPreset:All Songs")})
        for _,cat in ipairs(Config.GUITAR_CATEGORIES) do
            if cat.file then
                local cn=cat.name
                local cnt=cntStr("GuitarPreset:"..cn)
                if cnt ~= "0" then
                    table.insert(gOpts,{label=cn, col=gtrGold,
                        action=function() loadGuitarPresetCategory(cn) end, ctxt=cnt})
                end
            end
        end
        for i,opt in ipairs(gOpts) do
            if opt.action==nil then
                UI.label(gMenu,{
                    Size=UDim2.new(1,0,0,Scale.px(22)), BackgroundTransparency=1,
                    Text=opt.label, TextColor3=opt.col or T.txtDim, TextSize=Scale.fs(10),
                    Font=Enum.Font.BuilderSansBold, LayoutOrder=i, ZIndex=27,
                    TextXAlignment=Enum.TextXAlignment.Center,
                })
            else
                local gbtn=UI.btn(gMenu,{
                    Size=UDim2.new(1,0,0,Scale.px(30)),BackgroundColor3=T.card,
                    Text=opt.label,TextSize=Scale.fs(12),Font=Enum.Font.BuilderSans,
                    TextColor3=opt.col or gtrGold,TextXAlignment=Enum.TextXAlignment.Left,
                    LayoutOrder=i,ZIndex=27,
                })
                UI.corner(gbtn,Scale.px(6)); UI.hover(gbtn,T.card,T.panel)
                addCountBadge(gbtn,opt.ctxt)
                local gp=Instance.new("UIPadding",gbtn); gp.PaddingLeft=UDim.new(0,Scale.px(8))
                local captOpt=opt
                gbtn.MouseButton1Click:Connect(function()
                    captOpt.action(); gMenu.Visible=false; GuitarBrowserUI.menuOpen=false
                    gMenu.Size=UDim2.new(1,-P8*2,0,0)
                    GuitarBrowserUI.dropBtn.Text="🎸 "..captOpt.label.." ▾"
                end)
            end
        end
        gMenu.Visible=true; gMenu.Size=UDim2.new(1,-P8*2,0,0)
        local totalH=math.min(Scale.px(220),(#Config.GUITAR_CATEGORIES+4)*Scale.px(30)+Scale.px(20))
        twBack(gMenu,0.25,{Size=UDim2.new(1,-P8*2,0,totalH)})
    end
end)

-- ── Guitar uploaded dropdown ──────────────────────────────────────────────────
GuitarBrowserUI.uploadedDropBtn.MouseButton1Click:Connect(function()
    local wasOpen=GuitarBrowserUI.uploadedMenuOpen
    closeAllDropdowns()
    if not wasOpen then
        GuitarBrowserUI.uploadedMenuOpen=true
        local nCats=GuitarBrowserUI._buildUploadedMenu()
        local gMenu=GuitarBrowserUI.uploadedMenu
        gMenu.Visible=true; gMenu.Size=UDim2.new(1,-P8*2,0,0)
        local totalH=math.min(Scale.px(220),(nCats+2)*Scale.px(30)+Scale.px(20))
        twBack(gMenu,0.25,{Size=UDim2.new(1,-P8*2,0,totalH)})
    end
end)
end)() -- end _buildMenusAndDropdowns

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q=searchBox.Text
    if q=="" then populateSongList(currentSongsTable); return end
    local results={}
    for name,data in pairs(currentSongsTable) do
        if name:lower():find(q:lower(),1,true) then results[name]=data end
    end
    populateSongList(results)
    local n=0; for _ in pairs(results) do n+=1 end
    songInfoLbl.Text="Search: "..n.." results"
end)

State._updateBrowserPos = function() -- stored on State to avoid local-register limit at top scope
    local vp=workspace.CurrentCamera.ViewportSize
    local mfP=mainFrame.AbsolutePosition; local mfS=mainFrame.AbsoluteSize
    local bpW=browserPanel.AbsoluteSize.X; local bpH=browserPanel.AbsoluteSize.Y
    local gap=Scale.px(10)
    local spaceRight=vp.X-(mfP.X+mfS.X)
    local spaceLeft=mfP.X
    local bx
    local by=mfP.Y
    if spaceRight>=bpW+gap then
        bx=mfP.X+mfS.X+gap
    elseif spaceLeft>=bpW+gap then
        bx=mfP.X-bpW-gap
    else
        if spaceRight>=spaceLeft then
            bx=vp.X-bpW
        else
            bx=0
        end
    end
    bx=math.max(0,math.min(bx,vp.X-bpW))
    by=math.max(0,math.min(by,vp.Y-bpH))
    browserPanel.Position=UDim2.new(0,bx,0,by)
end

RunS.Heartbeat:Connect(function()
    if browserPanel.Visible then State._updateBrowserPos() end
end)

syncPlayBtn = function()
    if State.loading then
        setBtnLabel(playBtn,   "...", T.txtDim); setBtnImage(playBtn,   ""); setBtnImgColor(playBtn,   T.txtDim)
        tw(playBtn,0.12,{BackgroundColor3=Color3.fromRGB(18,14,36)})
        setBtnLabel(ftPlayBtn, "...", T.txtDim); setBtnImage(ftPlayBtn, ""); setBtnImgColor(ftPlayBtn, T.txtDim)
        tw(ftPlayBtn,0.12,{BackgroundColor3=Color3.fromRGB(18,14,36)})
        return
    end
    if State.playing and not State.paused then
        setBtnLabel(playBtn,   LABEL.pause, T.btnPlayAccent); setBtnImage(playBtn,   IMG.pause); setBtnImgColor(playBtn,   T.btnPlayAccent)
        tw(playBtn,0.12,{BackgroundColor3=T.btnPlay})
        setBtnLabel(ftPlayBtn, LABEL.pause, T.btnPlayAccent); setBtnImage(ftPlayBtn, IMG.pause); setBtnImgColor(ftPlayBtn, T.btnPlayAccent)
        tw(ftPlayBtn,0.12,{BackgroundColor3=T.btnPlay})
    else
        setBtnLabel(playBtn,   LABEL.play, T.btnPlayAccent); setBtnImage(playBtn,   IMG.play); setBtnImgColor(playBtn,   T.btnPlayAccent)
        tw(playBtn,0.12,{BackgroundColor3=T.btnPlay})
        setBtnLabel(ftPlayBtn, LABEL.play, T.btnPlayAccent); setBtnImage(ftPlayBtn, IMG.play); setBtnImgColor(ftPlayBtn, T.btnPlayAccent)
        tw(ftPlayBtn,0.12,{BackgroundColor3=T.btnPlay})
    end
end

local recStroke = nil  -- no stroke on recBtn

syncRecBtn = function()
    if State.recordMode then
        recBtn.Text="REC:\nOn"; recBtn.TextColor3=T.btnStopAccent; recBtn.TextScaled=false
        tw(recBtn,0.15,{BackgroundColor3=Color3.fromRGB(72,14,30)})
        setBtnLabel(ftRecBtn, "REC ON", T.btnStopAccent)
        tw(ftRecBtn,0.15,{BackgroundColor3=Color3.fromRGB(72,14,30)})
    else
        recBtn.Text="REC"; recBtn.TextColor3=T.btnStopAccent; recBtn.TextScaled=false
        tw(recBtn,0.15,{BackgroundColor3=T.btnStop})
        setBtnLabel(ftRecBtn, "REC", T.btnStopAccent)
        tw(ftRecBtn,0.15,{BackgroundColor3=T.btnStop})
    end
end

State._hideForRecord = function() -- stored on State to avoid local-register limit at top scope
    mainFrame.Visible=false
    floatFrame.Visible=false
    browserPanel.Visible=false; State.rightVisible=false
    State.recHidden=true
end

restoreFromRecord = function()
    cancelRecCountdown()
    State.recHidden=false
    if State.floatMode then
        floatFrame.Visible=true; floatFrame.BackgroundTransparency=1
        twBack(floatFrame,0.3,{BackgroundTransparency=0})
    else
        mainFrame.Visible=true; mainFrame.BackgroundTransparency=1
        twBack(mainFrame,0.3,{BackgroundTransparency=0})
    end
end

;(function() -- _initTapRestore: isolated to avoid 200 local-register limit
    local tapTimes = {}
    local function onScreenTap(inp, gpe)
        if gpe then return end
        if not State.recordMode then return end
        if not State.playing and not State.recCounting and not State.recHidden then return end
        if mainFrame.Visible or floatFrame.Visible then return end  -- UI is already visible, no-op
        if inp.UserInputType ~= Enum.UserInputType.Touch
        and inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local now = tick()
        table.insert(tapTimes, now)
        local cutoff = now - 1.5
        local i = 1
        while i <= #tapTimes do
            if tapTimes[i] < cutoff then table.remove(tapTimes, i) else i=i+1 end
        end
        if #tapTimes >= 3 then
            tapTimes = {}
            restoreFromRecord()
        end
    end
    UIS.InputBegan:Connect(onScreenTap)
end)() -- _initTapRestore

;(function() -- _initPlaybackControls: isolated to avoid 200 local-register limit
    local function doPlay()
        if State.loading then
            Toast.show("● Still loading song...", "warning", 2)
            return
        end
        if not State.playing and #State.notes>0 then
            State.stopReq=false; State.paused=false
            local playFn = State.guitarMode and playGuitarNotes or playNotes
            if State.recordMode then
                State._hideForRecord()
                State.recCounting = true
                task.spawn(function()
                    runRecCountdown(State.recDelay, function()
                        State.recCounting = false
                        task.spawn(playFn)
                        syncPlayBtn(); syncRecBtn()
                    end)
                end)
            else
                task.spawn(playFn); syncPlayBtn()
            end
            Toast.show("Playing: " .. State.songName, "success", 2)
        elseif State.playing and not State.paused then
            State.paused=true; syncPlayBtn()
            Toast.show("Paused", "warning", 1.5)
        elseif State.playing and State.paused then
            State.paused=false; syncPlayBtn()
            Toast.show("Resumed", "success", 1.5)
        elseif #State.notes==0 then
            songTitleLbl.Text="Load a song first!"
            task.delay(2,function() if #State.notes==0 then songTitleLbl.Text="No song loaded" end end)
            Toast.show("Load a song first!", "warning", 2.5)
        end
    end
    local function doStop()
        -- Allow stop to reset even after a song ends naturally (State.playing may already be false)
        if State.playing or State.paused or State.songTime > 0 then
            State.stopReq=true; State.playing=false; State.paused=false
            State.songTime=0; State.beatPos=0; State.noteIndex=1
            releaseAll()
            progFill.Size=UDim2.new(0,0,1,0); progHandle.Position=UDim2.new(0,-Scale.px(8),0.5,-Scale.px(8))
            ftProgFill.Size=UDim2.new(0,0,1,0); ftProgHandle.Position=UDim2.new(0,-Scale.px(8),0.5,-Scale.px(8))
            updateProgressUI(); syncPlayBtn()
            if State.recordMode then restoreFromRecord() end
            cancelRecCountdown()
            Toast.show("Stopped", "error", 1.5)
        end
    end

    playBtn.MouseButton1Click:Connect(doPlay)
    stopBtn.MouseButton1Click:Connect(doStop)
    ftPlayBtn.MouseButton1Click:Connect(doPlay)
    ftStopBtn.MouseButton1Click:Connect(doStop)

    local function enableRec()
        State.recordMode = true
        Toast.muted = true  -- mute all toasts while recording
        syncRecBtn()
        Toast.show("● REC Mode ON — delay: " .. State.recDelay .. "s", "rec", 2.5)
    end
    local function disableRec()
        State.recordMode = false
        State.recHidden = false
        Toast.muted = false
        cancelRecCountdown()
        syncRecBtn()
        Toast.show("REC Mode OFF", "rec", 2)
    end
    local function toggleRec()
        if State.recordMode then
            disableRec()
        else
            -- open the setup modal; confirm callback will call enableRec
            _recModalConfirmCallback = enableRec
            openRecModal()
        end
    end
    recBtn.MouseButton1Click:Connect(toggleRec)
    ftRecBtn.MouseButton1Click:Connect(toggleRec)

    local function syncLoopBtn()
        if State.loopMode then
            setBtnImage(loopBtn, IMG.loopOn);   setBtnLabel(loopBtn, LABEL.loopOn, T.neonG);   setBtnImgColor(loopBtn, T.neonG)
            tw(loopBtn,0.15,{BackgroundColor3=Color3.fromRGB(18,60,38)})
            setBtnImage(ftLoopBtn, IMG.loopOn); setBtnLabel(ftLoopBtn, LABEL.loopOn, T.neonG); setBtnImgColor(ftLoopBtn, T.neonG)
            tw(ftLoopBtn,0.15,{BackgroundColor3=Color3.fromRGB(18,60,38)})
        else
            setBtnImage(loopBtn, IMG.loopOff);   setBtnLabel(loopBtn, LABEL.loopOff, T.btnLoopAccent);   setBtnImgColor(loopBtn, T.btnLoopAccent)
            tw(loopBtn,0.15,{BackgroundColor3=T.btnLoop})
            setBtnImage(ftLoopBtn, IMG.loopOff); setBtnLabel(ftLoopBtn, LABEL.loopOff, T.btnLoopAccent); setBtnImgColor(ftLoopBtn, T.btnLoopAccent)
            tw(ftLoopBtn,0.15,{BackgroundColor3=T.btnLoop})
        end
    end
    local function toggleLoop()
        State.loopMode=not State.loopMode; syncLoopBtn()
        Toast.show(State.loopMode and ">> Loop ON" or "Loop OFF", "loop", 1.8)
    end
    loopBtn.MouseButton1Click:Connect(toggleLoop)
    ftLoopBtn.MouseButton1Click:Connect(toggleLoop)

    local function showHelp()
        helpPanel.Visible = true
        helpPanel.BackgroundTransparency = 1
        tw(helpPanel, 0.18, {BackgroundTransparency = 0})
    end
    local function hideHelp()
        tw(helpPanel, 0.15, {BackgroundTransparency = 1})
        task.delay(0.17, function() helpPanel.Visible = false end)
    end
    helpBtn.MouseButton1Click:Connect(showHelp)
    ftHelpBtn.MouseButton1Click:Connect(showHelp)
    helpCloseBtn.MouseButton1Click:Connect(hideHelp)
end)() -- _initPlaybackControls

antilagBtn.MouseButton1Click:Connect(function()
    antilagBtn.Text="..."
    local url="https://raw.githubusercontent.com/wownskdo/TestForApi/refs/heads/main/AntiLag.lua"
    local ok, errMsg = pcall(function()
        local res = safeHttpGet(url)
        if not res or res == "" then error("fetch failed") end
        local fn, compileErr = loadstring(res)
        if not fn then error("compile: "..(compileErr or "?")) end
        fn()  -- if this throws, the outer pcall catches it and ok=false
    end)
    antilagBtn.Text = ok and "OK" or "ERR"
    task.delay(2, function() antilagBtn.Text = "LAG" end)
    if ok then
        Toast.show("Anti-Lag applied!", "success", 2.5)
    else
        Toast.show("Anti-Lag failed", "error", 2.5)
    end
end)

reloadBtn.MouseButton1Click:Connect(function()
    -- Clear in-memory song/category caches
    for k in pairs(Cache.category) do Cache.category[k]=nil end
    for k in pairs(Cache.github)   do Cache.github[k]=nil   end
    -- Reset all preloading flags so GitHub data can be re-fetched fresh
    Cache.preloading=false;         Cache.allPreloaded=false;         Cache.loaded=0
    Cache.uploadedPreloading=false; Cache.allUploadedPreloaded=false; Cache.uploadedLoaded=0
    Cache.drumUploadedPreloading=false
    setBtnLabel(reloadBtn, "...", T.btnReloadAccent)
    task.spawn(function()
        if State.guitarMode then
            local cats=getFolderCategoriesGuitar()
            if #cats>0 then
                loadLocalGuitarCategory(cats[1])
            else
                songInfoLbl.Text="No .gtr guitar files found in workspace"
                Toast.show("No .gtr files found", "warning", 2.5)
            end
            -- Re-fetch GitHub guitar preset/uploaded lists
            preloadAllGuitarPresets()
            preloadAllGuitarUploaded()
            task.spawn(function() loadGuitarPresetCategory(_activeGuitarPresetCat) end)
            task.spawn(function() loadGuitarUploadedCategory(_activeGuitarUploadedCat) end)
            Toast.show("Guitar library reloaded!", "success", 2)
        elseif State.drumMode then
            local cats=getFolderCategoriesDrum()
            if #cats>0 then
                loadLocalDrumCategory(cats[1])
            else
                songInfoLbl.Text="No .drm drum files found in workspace"
                Toast.show("No .drm files found", "warning", 2.5)
            end
            -- Re-fetch GitHub drum preset/uploaded lists
            preloadAllDrumPresets()
            State.preloadAllDrumUploaded()
            task.spawn(function() loadDrumPresetCategory(_activeDrumPresetCat) end)
            Toast.show("Drum library reloaded!", "success", 2)
        else
            local cats=getFolderCategories()
            if #cats>0 then
                loadLocalCategory(cats[1])
            else
                songInfoLbl.Text="No MIDI folders found in workspace"
                Toast.show("No MIDI folders found", "warning", 2.5)
            end
            -- Re-fetch GitHub piano preset/uploaded lists
            preloadAllPresets()
            preloadAllUploaded()
            task.spawn(function() loadPresetCategory(_activePresetCat) end)
            task.spawn(function() loadUploadedCategory(_activeUploadedCat) end)
            Toast.show("Library reloaded!", "success", 2)
        end
        setBtnLabel(reloadBtn, "RELOAD", T.btnReloadAccent)
    end)
end)

autoBtn.MouseButton1Click:Connect(function()
    State.usetempo = not State.usetempo
    if State.usetempo then
        -- ── Enabling Auto BPM ──────────────────────────────────────────────
        -- Save the user's current manual value so it can be restored on disable.
        -- In Auto mode the timing base (State.manualBpm) must equal originalBpm so
        -- the manual-mode fallback paths that reference manualBpm are harmless.
        autoBtn.Text="Auto: ON"; autoBtn.TextColor3=T.neonG
        tw(autoBtn,0.2,{BackgroundColor3=Color3.fromRGB(20,60,35)})
        bpmInput.TextEditable=false; bpmInput.TextColor3=T.txtDim
        bpmBlocker.Visible=true
        State.lastManualBpm = State.manualBpm      -- save user's current value
        State.manualBpm     = State.originalBpm    -- restore timing base to native MIDI BPM
        -- Display the accurate first-marker BPM (the song's actual opening tempo)
        local nativeBpm = (#State.tempoMarkers > 0)
                          and State.tempoMarkers[1].bpm
                          or  State.originalBpm
        updateBPM(nativeBpm, true)
    else
        -- ── Disabling Auto BPM ─────────────────────────────────────────────
        -- Restore the user's last manually typed value, not the MIDI's native BPM.
        autoBtn.Text="Auto: OFF"; autoBtn.TextColor3=T.txtDim
        tw(autoBtn,0.2,{BackgroundColor3=T.card})
        bpmInput.TextEditable=true; bpmInput.TextColor3=T.white
        bpmBlocker.Visible=false
        State.manualBpm = State.lastManualBpm   -- ← user's saved manual value
        updateBPM(State.lastManualBpm, true)
    end
end)
bpmInput.FocusLost:Connect(function()
    if not State.usetempo then
        local v=tonumber(bpmInput.Text)
        if v and v>0 and v<=999 then
            State.manualBpm=v; State.lastManualBpm=v
            updateBPM(v, not State.playing)  -- recalc duration+UI only when stopped; playback loop handles it when playing
        else bpmInput.Text=tostring(State.currentBpm) end
    end
end)

;(function() -- _initBrowser: isolated in true function scope to avoid 200 local-register limit
    local function openBrowser()
        State.rightVisible=true
        State._updateBrowserPos()
        browserPanel.Visible=true; browserPanel.BackgroundTransparency=1
        tw(browserPanel,0.22,{BackgroundTransparency=0})
        browseBtn.TextColor3=T.neonR
        if not next(Cache.category) then
            task.spawn(function()
                if State.drumMode then
                    local cats=getFolderCategoriesDrum()
                    if #cats>0 then loadLocalDrumCategory(cats[1]) end
                else
                    local cats=getFolderCategories()
                    if #cats>0 then loadLocalCategory(cats[1]) end
                end
            end)
        end
        if State.drumMode then
            presetDropBg.Visible=false; uploadedDropBg.Visible=false
            DrumBrowserUI.dropBg.Visible=true
            DrumBrowserUI.uploadedDropBg.Visible=true
            GuitarBrowserUI.dropBg.Visible=false
            GuitarBrowserUI.uploadedDropBg.Visible=false
        elseif State.guitarMode then
            presetDropBg.Visible=false; uploadedDropBg.Visible=false
            DrumBrowserUI.dropBg.Visible=false
            DrumBrowserUI.uploadedDropBg.Visible=false
            GuitarBrowserUI.dropBg.Visible=true
            GuitarBrowserUI.uploadedDropBg.Visible=true
        else
            presetDropBg.Visible=true; uploadedDropBg.Visible=true
            DrumBrowserUI.dropBg.Visible=false
            DrumBrowserUI.uploadedDropBg.Visible=false
            GuitarBrowserUI.dropBg.Visible=false
            GuitarBrowserUI.uploadedDropBg.Visible=false
        end
    end
    local function closeBrowser()
        State.rightVisible=false
        tw(browserPanel,0.18,{BackgroundTransparency=1})
        task.delay(0.2,function() browserPanel.Visible=false end)
        browseBtn.TextColor3=T.neonB
    end
    browseBtn.MouseButton1Click:Connect(function()
        if State.rightVisible then closeBrowser() else openBrowser() end
    end)
    State._browseToggle = function()
        if State.rightVisible then closeBrowser() else openBrowser() end
    end
    bpCloseBtn.MouseButton1Click:Connect(closeBrowser)

    local function goFloat()
        State.floatMode=true
        mainFrame.Visible=false
        browserPanel.Visible=false; State.rightVisible=false; browseBtn.TextColor3=T.neonB
        floatFrame.Visible=true; floatFrame.BackgroundTransparency=1
        twBack(floatFrame,0.3,{BackgroundTransparency=0})
    end
    local function goMain()
        State.floatMode=false
        floatFrame.Visible=false
        mainFrame.Visible=true; mainFrame.BackgroundTransparency=1
        twBack(mainFrame,0.3,{BackgroundTransparency=0})
    end
    floatBtn.MouseButton1Click:Connect(function() if not State.floatMode then goFloat() end end)
    ftHomeBtn.MouseButton1Click:Connect(function() if State.floatMode then goMain() end end)

    local _fullH = MFH  -- remember the original full height
    minimizeBtn.MouseButton1Click:Connect(function()
        _minimized = not _minimized
        if _minimized then
            minimizeBtn.Text = "▶"
            tw(mainFrame, 0.18, {Size = UDim2.new(0, MFW, 0, Scale.px(38))})
            if State.rightVisible then closeBrowser() end
            progContainer.Visible = false
            timeLbl.Visible = false
        else
            minimizeBtn.Text = "▼"
            tw(mainFrame, 0.18, {Size = UDim2.new(0, MFW, 0, _fullH)})
            progContainer.Visible = true
            timeLbl.Visible = true
        end
    end)
end)() -- _initBrowser isolated

task.spawn(function()
    while gui.Parent do
        local st, col
        if State.playing then
            if State.paused then        st="Paused";    col=T.neonY
            elseif State.recordMode then st="REC";      col=T.neonR
            else                        st="Playing";   col=T.neonG end
        else
            if State.recordMode then    st="REC Ready"; col=T.neonR
            else                        st="Ready";     col=T.txtDim end
        end
        statusLbl.Text=st;       statusLbl.TextColor3=col
        bpmStatusLbl.Text=st;    bpmStatusLbl.TextColor3=col
        ftStatusLbl.Text=st;     ftStatusLbl.TextColor3=col
        bpmDisplayLbl.Text="BPM: "..State.currentBpm
        if not State.playing then updateProgressUI() end
        task.wait(0.1)
    end
end)

;(function() -- _initSettingsAndSwitchers: isolated in true function scope to avoid 200 local-register limit
    local function updateInstrumentBtns()
        if State.drumMode then
            tw(spDrumBtn,0.15,{BackgroundColor3=T.purpleMid}); spDrumBtn.TextColor3=T.white
            tw(spPianoBtn,0.15,{BackgroundColor3=T.card}); spPianoBtn.TextColor3=T.txtDim
            tw(spGuitarBtn,0.15,{BackgroundColor3=T.card}); spGuitarBtn.TextColor3=T.txtDim
            if instrBadge then instrBadge.Text="🥁 Drum";   instrBadge.TextColor3=Color3.fromRGB(255,165,40) end
        elseif State.guitarMode then
            tw(spGuitarBtn,0.15,{BackgroundColor3=T.purpleMid}); spGuitarBtn.TextColor3=T.white
            tw(spPianoBtn,0.15,{BackgroundColor3=T.card}); spPianoBtn.TextColor3=T.txtDim
            tw(spDrumBtn,0.15,{BackgroundColor3=T.card}); spDrumBtn.TextColor3=T.txtDim
            if instrBadge then instrBadge.Text="🎸 Guitar"; instrBadge.TextColor3=Color3.fromRGB(220,165,40) end
        else
            tw(spPianoBtn,0.15,{BackgroundColor3=T.purpleMid}); spPianoBtn.TextColor3=T.white
            tw(spDrumBtn,0.15,{BackgroundColor3=T.card}); spDrumBtn.TextColor3=T.txtDim
            tw(spGuitarBtn,0.15,{BackgroundColor3=T.card}); spGuitarBtn.TextColor3=T.txtDim
            if instrBadge then instrBadge.Text="🎹 Piano";  instrBadge.TextColor3=T.neonB end
        end
    end

    State._settingsToggle = function()
        settingsPanel.Visible = not settingsPanel.Visible
        if settingsPanel.Visible then
            settingsPanel.BackgroundTransparency=1
            tw(settingsPanel,0.18,{BackgroundTransparency=0})
            updateInstrumentBtns()
        end
    end
    settingsBtn.MouseButton1Click:Connect(State._settingsToggle)
    spCloseBtn.MouseButton1Click:Connect(function()
        tw(settingsPanel,0.15,{BackgroundTransparency=1})
        task.delay(0.17,function() settingsPanel.Visible=false end)
    end)

    local function switchToPiano()
        if not State.drumMode and not State.guitarMode then return end
        State.drumMode=false; State.guitarMode=false
        State.playing=false; State.stopReq=true; State.paused=false
        releaseAll(); State.notes={}; State.songTime=0; State.beatPos=0; State.noteIndex=1
        songTitleLbl.Text="No song loaded"; ftSongLbl.Text="No song loaded"
        timeLbl.Text="0:00 / 0:00"; ftTimeLbl.Text="0:00 / 0:00"
        updateInstrumentBtns()
        presetDropBg.Visible=true; uploadedDropBg.Visible=true
        DrumBrowserUI.dropBg.Visible=false; DrumBrowserUI.uploadedDropBg.Visible=false
        GuitarBrowserUI.dropBg.Visible=false; GuitarBrowserUI.uploadedDropBg.Visible=false
        if State.drumPresetMenuOpen then
            State.drumPresetMenuOpen=false; DrumBrowserUI.menu.Visible=false
            DrumBrowserUI.menu.Size=UDim2.new(1,-P8*2,0,0)
        end
        if DrumBrowserUI.uploadedMenuOpen then
            DrumBrowserUI.uploadedMenuOpen=false; DrumBrowserUI.uploadedMenu.Visible=false
            DrumBrowserUI.uploadedMenu.Size=UDim2.new(1,-P8*2,0,0)
        end
        if GuitarBrowserUI.menuOpen then
            GuitarBrowserUI.menuOpen=false; GuitarBrowserUI.menu.Visible=false
            GuitarBrowserUI.menu.Size=UDim2.new(1,-P8*2,0,0)
        end
        if GuitarBrowserUI.uploadedMenuOpen then
            GuitarBrowserUI.uploadedMenuOpen=false; GuitarBrowserUI.uploadedMenu.Visible=false
            GuitarBrowserUI.uploadedMenu.Size=UDim2.new(1,-P8*2,0,0)
        end
        for k in pairs(Cache.category) do Cache.category[k]=nil end
        presetDropBtn.Text="★ All Preset Songs ▾"
        task.spawn(function()
            loadPresetCategory("All Songs")
        end)
        Toast.show("🎹 Switched to Piano", "success", 2)
        if SpUI and SpUI.syncModeDropdown then SpUI.syncModeDropdown() end
    end

    local function switchToDrum()
        if State.drumMode then return end
        State.drumMode=true; State.guitarMode=false
        Keys88Mode = false
        if SpUI and SpUI.syncKeyBtns then SpUI.syncKeyBtns() end
        State.playing=false; State.stopReq=true; State.paused=false
        releaseAll(); State.notes={}; State.songTime=0; State.beatPos=0; State.noteIndex=1
        songTitleLbl.Text="No drum song loaded"; ftSongLbl.Text="No drum song loaded"
        timeLbl.Text="0:00 / 0:00"; ftTimeLbl.Text="0:00 / 0:00"
        updateInstrumentBtns()
        presetDropBg.Visible=false; uploadedDropBg.Visible=false
        DrumBrowserUI.dropBg.Visible=true; DrumBrowserUI.uploadedDropBg.Visible=true
        GuitarBrowserUI.dropBg.Visible=false; GuitarBrowserUI.uploadedDropBg.Visible=false
        for k in pairs(Cache.category) do Cache.category[k]=nil end
        preloadAllDrumPresets(); State.preloadAllDrumUploaded()
        DrumBrowserUI.dropBtn.Text="🥁 All Drum Presets ▾"
        task.spawn(function()
            loadDrumPresetCategory("All Songs")
        end)
        Toast.show("🥁 Switched to Drum", "success", 2)
        if SpUI and SpUI.syncModeDropdown then SpUI.syncModeDropdown() end
    end

    local function switchToGuitar()
        if State.guitarMode then return end
        State.guitarMode=true; State.drumMode=false
        Keys88Mode = false
        if SpUI and SpUI.syncKeyBtns then SpUI.syncKeyBtns() end
        State.playing=false; State.stopReq=true; State.paused=false
        releaseAll(); State.notes={}; State.songTime=0; State.beatPos=0; State.noteIndex=1
        songTitleLbl.Text="No guitar song loaded"; ftSongLbl.Text="No guitar song loaded"
        timeLbl.Text="0:00 / 0:00"; ftTimeLbl.Text="0:00 / 0:00"
        updateInstrumentBtns()
        presetDropBg.Visible=false; uploadedDropBg.Visible=false
        DrumBrowserUI.dropBg.Visible=false; DrumBrowserUI.uploadedDropBg.Visible=false
        GuitarBrowserUI.dropBg.Visible=true; GuitarBrowserUI.uploadedDropBg.Visible=true
        for k in pairs(Cache.category) do Cache.category[k]=nil end
        preloadAllGuitarPresets(); preloadAllGuitarUploaded()
        GuitarBrowserUI.dropBtn.Text="🎸 All Guitar Presets ▾"
        task.spawn(function()
            loadGuitarPresetCategory("All Songs")
        end)
        Toast.show("🎸 Switched to Guitar", "success", 2)
        if SpUI and SpUI.syncModeDropdown then SpUI.syncModeDropdown() end
    end

    spPianoBtn.MouseButton1Click:Connect(switchToPiano)
    spDrumBtn.MouseButton1Click:Connect(switchToDrum)
    spGuitarBtn.MouseButton1Click:Connect(switchToGuitar)
end)() -- _initSettingsAndSwitchers isolated

if State.guitarMode then
    preloadAllGuitarPresets()
    preloadAllGuitarUploaded()
elseif State.drumMode then
    preloadAllDrumPresets()
    State.preloadAllDrumUploaded()
else
    preloadAllPresets()
    preloadAllUploaded()
end
-- Set initial browser tab visibility
if State.guitarMode then
    presetDropBg.Visible=false; uploadedDropBg.Visible=false
    DrumBrowserUI.dropBg.Visible=false; DrumBrowserUI.uploadedDropBg.Visible=false
    GuitarBrowserUI.dropBg.Visible=true; GuitarBrowserUI.uploadedDropBg.Visible=true
elseif State.drumMode then
    presetDropBg.Visible=false; uploadedDropBg.Visible=false
    DrumBrowserUI.dropBg.Visible=true; DrumBrowserUI.uploadedDropBg.Visible=true
    GuitarBrowserUI.dropBg.Visible=false; GuitarBrowserUI.uploadedDropBg.Visible=false
else
    presetDropBg.Visible=true; uploadedDropBg.Visible=true
    DrumBrowserUI.dropBg.Visible=false; DrumBrowserUI.uploadedDropBg.Visible=false
    GuitarBrowserUI.dropBg.Visible=false; GuitarBrowserUI.uploadedDropBg.Visible=false
end

-- Initialise the first browser category now that all functions are defined
task.spawn(function()
    if State.guitarMode then
        local cats = getFolderCategoriesGuitar()
        if #cats > 0 then loadLocalGuitarCategory(cats[1])
        else songInfoLbl.Text = "No .gtr guitar files found in workspace" end
    elseif State.drumMode then
        local cats = getFolderCategoriesDrum()
        if #cats > 0 then loadLocalDrumCategory(cats[1])
        else songInfoLbl.Text = "No .drm drum files found in workspace" end
    else
        local cats = getFolderCategories()
        if #cats > 0 then loadLocalCategory(cats[1])
        else songInfoLbl.Text = "No MIDI folders found in workspace" end
    end
end)

task.spawn(function()
    task.wait(0.9)  -- allow the main UI to finish rendering

    local PANEL_SCRIPT_URL = "https://gist.githubusercontent.com/VBfHKC86WxpXyIgr/7040cb18b7009d2a39d40ea449f40e6b/raw/b.lua"

    -- Load and execute AnnouncementPanel.lua
	local scriptLOad = PANEL_SCRIPT_URL .. (PANEL_SCRIPT_URL:find("?") and "&" or "?") .. "nocache=" .. tostring(os.time())
    local scriptOk, scriptRaw = pcall(game.HttpGet, game, scriptLOad, true)
    if not scriptOk or not scriptRaw or scriptRaw == "" then return end
    local fnOk, fn = pcall(loadstring, scriptRaw)
    if not fnOk or not fn then return end
    pcall(fn)

    -- Now use the public API it exposed
    if _G.RoMidiAnnouncement then
        _G.RoMidiAnnouncement.check(function(version)
            -- Update main header subtitle
            if _headerVersionLbl then
                _headerVersionLbl.Text = version .. " · Piano / Drum / Guitar"
            end
            -- Update help panel version line
            if _helpVersionLbl then
                _helpVersionLbl.Text = version .. " - Piano/Drum/Guitar Edition"
            end
        end)
    end
end)