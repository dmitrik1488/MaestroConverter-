local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local objFileName        = ""
local objOutputName      = ""
local objScale           = 1
local objThickness       = 0.2
local objSolidScale      = 1
local objStripSize       = 0.5
local randomColorEnabled = false
local gradientEnabled    = false
local gradientColor1     = Color3.fromRGB(255, 255, 255)
local gradientColor2     = Color3.fromRGB(255, 255, 255)
local gradientDirection  = "Vertical"
local customColorEnabled = false
local customColor        = Color3.fromRGB(255, 255, 255)
local selectedBlock      = "PlasticBlock"

local blockList = {
    "BallonBlock",
    "BrickBlock",
    "CoalBlock",
    "ConcreteBlock",
    "FabricBlock",
    "GlassBlock",
    "GoldBlock",
    "GrassBlock",
    "IceBlock",
    "MarbleBlock",
    "MetalBlock",
    "ObsidianBlock",
    "PlasticBlock",
    "RustedBlock",
    "StoneBlock",
    "TitaniumBlock",
    "WoodBlock",
}

local isMobile = false
local function checkIfMobile()
    local ok, uis = pcall(function() return game:GetService("UserInputService") end)
    if ok and uis and uis.TouchEnabled and not uis.MouseEnabled then
        return true
    end

    local ok2, vx = pcall(function()
        return workspace.CurrentCamera.ViewportSize.X
    end)
    if ok2 and vx then
        return vx < 600
    end

    return false
end

isMobile = checkIfMobile()

local function parseOBJ(content, scale)
    local vertices = {}
    local edges = {}
    local faces = {}
    local edgeSet = {}
    local edgeCount = {}

    for line in content:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line:sub(1, 2) == "v " then
            local x, y, z = line:match("v%s+(%-?%d+%.?%d*e?[+-]?%d*)%s+(%-?%d+%.?%d*e?[+-]?%d*)%s+(%-?%d+%.?%d*e?[+-]?%d*)")
            if x and y and z then
                table.insert(vertices, Vector3.new(tonumber(x) * scale, tonumber(y) * scale, tonumber(z) * scale))
            end
        elseif line:sub(1, 2) == "f " then
            local indices = {}
            for part in line:sub(3):gmatch("%S+") do
                local idx = tonumber(part:match("^(%d+)"))
                if idx and idx >= 1 and idx <= #vertices then
                    table.insert(indices, idx)
                end
            end
            if #indices >= 3 then
                table.insert(faces, indices)
            end
            for i = 1, #indices do
                local a = indices[i]
                local b = indices[(i % #indices) + 1]
                if a and b and a ~= b then
                    local key = math.min(a, b) .. "_" .. math.max(a, b)
                    edgeCount[key] = (edgeCount[key] or 0) + 1
                    if not edgeSet[key] then
                        edgeSet[key] = true
                        table.insert(edges, {a, b})
                    end
                end
            end
        end
    end
    return vertices, edges, faces, edgeCount
end

local function centerVertices(vertices)
    if #vertices == 0 then return vertices end
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for _, v in ipairs(vertices) do
        if v.X < minX then minX = v.X end
        if v.Y < minY then minY = v.Y end
        if v.Z < minZ then minZ = v.Z end
        if v.X > maxX then maxX = v.X end
        if v.Y > maxY then maxY = v.Y end
        if v.Z > maxZ then maxZ = v.Z end
    end
    local cx = (minX + maxX) / 2
    local cy = minY
    local cz = (minZ + maxZ) / 2
    local out = {}
    for _, v in ipairs(vertices) do
        table.insert(out, Vector3.new(v.X - cx, v.Y - cy, v.Z - cz))
    end
    return out
end

local function randomColor3()
    return Color3.fromHSV(math.random(), 0.75, 0.92)
end

local function getGradientColor(pos, minPos, maxPos, dir)
    local t = 0
    if dir == "Vertical" then
        t = (pos.Y - minPos.Y) / math.max(0.0001, maxPos.Y - minPos.Y)
    elseif dir == "Horizontal" then
        t = (pos.X - minPos.X) / math.max(0.0001, maxPos.X - minPos.X)
    else
        t = (pos.Z - minPos.Z) / math.max(0.0001, maxPos.Z - minPos.Z)
    end
    t = math.clamp(t, 0, 1)
    return Color3.new(
        gradientColor1.R + (gradientColor2.R - gradientColor1.R) * t,
        gradientColor1.G + (gradientColor2.G - gradientColor1.G) * t,
        gradientColor1.B + (gradientColor2.B - gradientColor1.B) * t
    )
end

local function getBounds(vertices)
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for _, v in ipairs(vertices) do
        if v.X < minX then minX = v.X end
        if v.Y < minY then minY = v.Y end
        if v.Z < minZ then minZ = v.Z end
        if v.X > maxX then maxX = v.X end
        if v.Y > maxY then maxY = v.Y end
        if v.Z > maxZ then maxZ = v.Z end
    end
    return Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)
end

local function roundTo(v, step)
    local inv = 1 / step
    return math.floor(v * inv + 0.5) / inv
end

local function stableCFrameForEdge(v1, v2)
    local diff = v2 - v1
    local length = diff.Magnitude
    if length < 0.0001 then
        return CFrame.new(v1), 0
    end
    local dir = diff.Unit
    local absX = math.abs(dir.X)
    local absY = math.abs(dir.Y)
    local absZ = math.abs(dir.Z)
    local worldUp
    if absY <= absX and absY <= absZ then
        worldUp = Vector3.new(0, 1, 0)
    elseif absX <= absY and absX <= absZ then
        worldUp = Vector3.new(1, 0, 0)
    else
        worldUp = Vector3.new(0, 0, 1)
    end
    local right = dir:Cross(worldUp)
    if right.Magnitude < 0.0001 then
        worldUp = Vector3.new(0, 0, 1)
        right = dir:Cross(worldUp)
    end
    right = right.Unit
    local up = right:Cross(dir).Unit
    local mid = (v1 + v2) / 2
    local cf = CFrame.fromMatrix(mid, right, up, -dir)
    return cf, length
end

local function fmt(n)
    return string.format("%.5f", n)
end

local function makeEdgeBlock(v1, v2, thickness, color)
    local diff = v2 - v1
    local length = diff.Magnitude
    if length < 0.01 then return nil end
    local cf, len = stableCFrameForEdge(v1, v2)
    local rx, ry, rz = cf:ToEulerAnglesXYZ()
    local mid = (v1 + v2) / 2
    local entry = {
        Position = fmt(mid.X) .. "," .. fmt(mid.Y) .. "," .. fmt(mid.Z),
        Rotation = fmt(math.deg(rx)) .. "," .. fmt(math.deg(ry)) .. "," .. fmt(math.deg(rz)),
        Size = fmt(thickness) .. "," .. fmt(thickness) .. "," .. fmt(length),
        CanCollide = true,
        Anchored = true,
        ShowShadow = false,
    }
    if color then
        entry.Color = string.format("%.3f,%.3f,%.3f", color.R, color.G, color.B)
    end
    return entry
end

local function makeEdgeBlockNormal(v1, v2, thickness, color, normal, oppositeVertex)
    local diff = v2 - v1
    local length = diff.Magnitude
    if length < 0.01 then return nil end
    local mid = (v1 + v2) / 2
    local blockDir = diff.Unit
    local upVec = normal - blockDir * blockDir:Dot(normal)
    local rx, ry, rz
    local blockPos = mid
    if upVec.Magnitude < 0.0001 then
        local cf = stableCFrameForEdge(v1, v2)
        rx, ry, rz = cf:ToEulerAnglesXYZ()
    else
        upVec = upVec.Unit
        local rightVec = blockDir:Cross(upVec)
        if rightVec.Magnitude < 0.0001 then
            local cf = stableCFrameForEdge(v1, v2)
            rx, ry, rz = cf:ToEulerAnglesXYZ()
        else
            rightVec = rightVec.Unit
            local sign = 1
            if oppositeVertex then
                local towardInterior = (oppositeVertex - mid):Dot(rightVec)
                if towardInterior < 0 then
                    sign = -1
                end
            end
            blockPos = mid - upVec * (thickness / 2) + rightVec * sign * (thickness / 2)
            local cf = CFrame.fromMatrix(blockPos, rightVec, upVec, -blockDir)
            rx, ry, rz = cf:ToEulerAnglesXYZ()
        end
    end
    local entry = {
        Position = fmt(blockPos.X) .. "," .. fmt(blockPos.Y) .. "," .. fmt(blockPos.Z),
        Rotation = fmt(math.deg(rx)) .. "," .. fmt(math.deg(ry)) .. "," .. fmt(math.deg(rz)),
        Size = fmt(thickness) .. "," .. fmt(thickness) .. "," .. fmt(length),
        CanCollide = true,
        Anchored = true,
        ShowShadow = false,
    }
    if color then
        entry.Color = string.format("%.3f,%.3f,%.3f", color.R, color.G, color.B)
    end
    return entry
end

local function fillTriangle(va, vb, vc, thickness, color)
    local blocks = {}
    local edge1 = vb - va
    local edge2 = vc - va
    local normal = edge1:Cross(edge2)
    if normal.Magnitude < 0.0001 then return blocks end
    normal = normal.Unit
    local d12 = (vb - va).Magnitude
    local d23 = (vc - vb).Magnitude
    local d13 = (vc - va).Magnitude
    local stripDir
    if d12 >= d23 and d12 >= d13 then
        stripDir = (vb - va).Unit
    elseif d23 >= d12 and d23 >= d13 then
        stripDir = (vc - vb).Unit
    else
        stripDir = (vc - va).Unit
    end
    stripDir = stripDir - normal * stripDir:Dot(normal)
    if stripDir.Magnitude < 0.0001 then return blocks end
    stripDir = stripDir.Unit
    local sweepDir = stripDir:Cross(normal)
    if sweepDir.Magnitude < 0.0001 then return blocks end
    sweepDir = sweepDir.Unit
    local p1 = va:Dot(sweepDir)
    local p2 = vb:Dot(sweepDir)
    local p3 = vc:Dot(sweepDir)
    local minP = math.min(p1, p2, p3)
    local maxP = math.max(p1, p2, p3)
    local totalDist = maxP - minP
    if totalDist < 0.0001 then return blocks end
    local steps = math.max(1, math.ceil(totalDist / thickness))
    local stripSpacing = totalDist / steps
    local triEdges = {
        {va, vb, p1, p2},
        {vb, vc, p2, p3},
        {vc, va, p3, p1}
    }

    local vaS = va:Dot(stripDir)
    local vaSweep = va:Dot(sweepDir)

    local function computeHitInterval(sweepPos)
        local hits = {}
        for _, edge in ipairs(triEdges) do
            local eA, eB = edge[1], edge[2]
            local pA, pB = edge[3], edge[4]
            local lo = math.min(pA, pB)
            local hi = math.max(pA, pB)
            if sweepPos >= lo - 0.00001 and sweepPos <= hi + 0.00001 then
                local range = pB - pA
                local t
                if math.abs(range) > 0.00001 then
                    t = math.clamp((sweepPos - pA) / range, 0, 1)
                else
                    t = 0.5
                end
                local hit = eA + (eB - eA) * t
                local isDup = false
                for _, h in ipairs(hits) do
                    if (h - hit).Magnitude < 0.00001 then
                        isDup = true
                        break
                    end
                end
                if not isDup then
                    table.insert(hits, hit)
                end
            end
        end
        if #hits < 2 then return nil end
        local bestA, bestB = hits[1], hits[2]
        local bestDist = (bestB - bestA).Magnitude
        for a = 1, #hits do
            for b = a + 1, #hits do
                local d = (hits[b] - hits[a]).Magnitude
                if d > bestDist then
                    bestA = hits[a]
                    bestB = hits[b]
                    bestDist = d
                end
            end
        end
        if bestDist <= 0.0001 then return nil end
        local sA = bestA:Dot(stripDir)
        local sB = bestB:Dot(stripDir)
        return math.min(sA, sB), math.max(sA, sB)
    end

    for i = 0, steps - 1 do
        local sweepLeft = minP + i * stripSpacing
        local sweepRight = minP + (i + 1) * stripSpacing

        local lMin, lMax = computeHitInterval(sweepLeft)
        local rMin, rMax = computeHitInterval(sweepRight)

        if lMin and rMin then
            local safeMin = math.max(lMin, rMin)
            local safeMax = math.min(lMax, rMax)
            if safeMax - safeMin > 0.0001 then
                local sweepPos = (sweepLeft + sweepRight) / 2
                local sMid = (safeMin + safeMax) / 2
                local bestDist = safeMax - safeMin
                local mid = va + (sMid - vaS) * stripDir + (sweepPos - vaSweep) * sweepDir

                local blockDir = stripDir
                local upVec = normal - blockDir * blockDir:Dot(normal)
                if upVec.Magnitude < 0.0001 then
                    upVec = Vector3.new(0, 1, 0)
                end
                upVec = upVec.Unit
                local rightVec = blockDir:Cross(upVec).Unit
                local blockPos = mid - upVec * (thickness / 2)
                local cf = CFrame.fromMatrix(blockPos, rightVec, upVec, -blockDir)
                local rx, ry, rz = cf:ToEulerAnglesXYZ()
                local entry = {
                    Position = fmt(blockPos.X) .. "," .. fmt(blockPos.Y) .. "," .. fmt(blockPos.Z),
                    Rotation = fmt(math.deg(rx)) .. "," .. fmt(math.deg(ry)) .. "," .. fmt(math.deg(rz)),
                    Size = fmt(stripSpacing) .. "," .. fmt(thickness) .. "," .. fmt(bestDist),
                    CanCollide = true,
                    Anchored = true,
                    ShowShadow = false,
                }
                if color then
                    entry.Color = string.format("%.3f,%.3f,%.3f", color.R, color.G, color.B)
                end
                table.insert(blocks, entry)
            end
        end
    end
    return blocks
end

local function splitAndSaveChunks(blocks, outputBase)
    local result = {[selectedBlock] = blocks}
    local jok, js = pcall(function()
        return HttpService:JSONEncode(result)
    end)
    if not jok then
        return nil, "JSON encode failed: " .. tostring(js)
    end
    local fname = outputBase .. ".Build"
    local wok, werr = pcall(function()
        writefile(fname, js)
    end)
    if not wok then
        return nil, "Write failed: " .. tostring(werr)
    end
    return {fname}, nil
end

local BG      = Color3.fromRGB(255, 255, 255)
local BG2     = Color3.fromRGB(240, 242, 248)
local ACCENT  = Color3.fromRGB(37, 99, 235)
local BORDER  = Color3.fromRGB(210, 218, 235)
local TEXT    = Color3.fromRGB(30, 40, 60)
local TEXTSUB = Color3.fromRGB(140, 155, 185)

local viewportSize = {X = 800, Y = 600}
pcall(function()
    local cam = workspace.CurrentCamera
    if cam and cam.ViewportSize then
        viewportSize = cam.ViewportSize
    end
end)

local PANEL_W, HEADER_H, TAB_W, BODY_H, CONTENT_W, PAD, PADW, SLD_H, LBL_H, INP_H, BTN_H, STAT_H, ITEM_H, DROP_MAX

if isMobile then
    PANEL_W   = math.min(330, math.max(240, math.floor(viewportSize.X - 24)))
    HEADER_H  = 36
    TAB_W     = math.floor(PANEL_W * 0.24)
    BODY_H    = math.min(230, math.max(180, math.floor(viewportSize.Y - 140)))
    CONTENT_W = PANEL_W
else
    PANEL_W   = 460
    HEADER_H  = 40
    TAB_W     = 110
    BODY_H    = 320
    CONTENT_W = PANEL_W
end

TOTAL_H   = HEADER_H + BODY_H
PAD       = isMobile and 7 or 10
PADW      = CONTENT_W - PAD * 2
SLD_H     = isMobile and 15 or 18
LBL_H     = isMobile and 11 or 13
INP_H     = isMobile and 26 or 30
BTN_H     = isMobile and 26 or 30
STAT_H    = isMobile and 11 or 13
ITEM_H    = isMobile and 18 or 22
DROP_MAX  = 5

local function buildGUI()
    local old = game:GetService("CoreGui"):FindFirstChild("OBJConverter")
    if old then
        old:Destroy()
    end

    local format = "Solid"
    local extendedWireframe = false
    local colorMode = "Static"

    local SG = Instance.new("ScreenGui")
    SG.Name = "OBJConverter"
    SG.ResetOnSpawn = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.Enabled = false
    SG.Parent = game:GetService("CoreGui")

    local MainBorder = Instance.new("Frame")
    MainBorder.Name = "MainBorder"
    MainBorder.Size = UDim2.new(0, PANEL_W, 0, TOTAL_H)
    MainBorder.Position = UDim2.new(0.5, -PANEL_W / 2, 0.5, -TOTAL_H / 2)
    MainBorder.BackgroundColor3 = BORDER
    MainBorder.BorderSizePixel = 0
    MainBorder.Parent = SG

    local BorderCorner = Instance.new("UICorner", MainBorder)
    BorderCorner.CornerRadius = UDim.new(0, 8)

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(1, -4, 1, -4)
    Main.Position = UDim2.new(0, 2, 0, 2)
    Main.BackgroundColor3 = BG
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true
    Main.Parent = MainBorder

    local MainCorner = Instance.new("UICorner", Main)
    MainCorner.CornerRadius = UDim.new(0, 6)

    local Header = Instance.new("Frame", Main)
    Header.Size = UDim2.new(1, 0, 0, HEADER_H)
    Header.Position = UDim2.new(0, 0, 0, 0)
    Header.BackgroundColor3 = BG2
    Header.BorderSizePixel = 0

    local HeaderCorner = Instance.new("UICorner", Header)
    HeaderCorner.CornerRadius = UDim.new(0, 6)

    local HeaderBottomCover = Instance.new("Frame", Header)
    HeaderBottomCover.Size = UDim2.new(1, 0, 0, 6)
    HeaderBottomCover.Position = UDim2.new(0, 0, 1, -6)
    HeaderBottomCover.BackgroundColor3 = BG2
    HeaderBottomCover.BorderSizePixel = 0

    local HDivider = Instance.new("Frame", Main)
    HDivider.Size = UDim2.new(1, 0, 0, 1)
    HDivider.Position = UDim2.new(0, 0, 0, HEADER_H)
    HDivider.BackgroundColor3 = BORDER
    HDivider.BorderSizePixel = 0
    HDivider.ZIndex = 2

    local dragging, dragStart, startPos = false, nil, nil

    Header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = MainBorder.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            MainBorder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local function makeCircleBtn(xOff, baseColor, hoverSymbol, symbolColor)
        local b = Instance.new("TextButton", Header)
        b.Size = UDim2.new(0, 13, 0, 13)
        b.Position = UDim2.new(1, xOff, 0.5, -6)
        b.BackgroundColor3 = baseColor
        b.BorderSizePixel = 0
        b.Text = ""
        b.AutoButtonColor = false
        b.ZIndex = 3

        local corner = Instance.new("UICorner", b)
        corner.CornerRadius = UDim.new(1, 0)

        local sym = Instance.new("TextLabel", b)
        sym.Size = UDim2.new(1, 0, 1, 0)
        sym.BackgroundTransparency = 1
        sym.Text = ""
        sym.TextColor3 = symbolColor or Color3.fromRGB(80, 40, 0)
        sym.TextSize = 8
        sym.Font = Enum.Font.GothamBold
        sym.ZIndex = 4

        b.MouseEnter:Connect(function() sym.Text = hoverSymbol end)
        b.MouseLeave:Connect(function() sym.Text = "" end)

        return b
    end

    local CollapseBtn = makeCircleBtn(-42, Color3.fromRGB(40, 200, 64),  "−", Color3.fromRGB(10, 90, 20))
    local CloseBtn    = makeCircleBtn(-24, Color3.fromRGB(255, 95, 87),  "×", Color3.fromRGB(130, 20, 10))

    CloseBtn.MouseButton1Click:Connect(function()
        SG:Destroy()
    end)

    local DISCORD_BTN_W = isMobile and 62 or 74
    local DISCORD_BTN_H = isMobile and 18 or 22
    local DISCORD_RIGHT_GAP = 66
    local DISCORD_LEFT_DIST = DISCORD_RIGHT_GAP + DISCORD_BTN_W
    local TITLE_GAP = 6
    local TITLE_RIGHT_MARGIN = 33 + DISCORD_LEFT_DIST + TITLE_GAP

    local DiscordBtn = Instance.new("TextButton", Header)
    DiscordBtn.Size = UDim2.new(0, DISCORD_BTN_W, 0, DISCORD_BTN_H)
    DiscordBtn.Position = UDim2.new(1, -DISCORD_LEFT_DIST, 0.5, -DISCORD_BTN_H / 2)
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    DiscordBtn.BorderSizePixel = 0
    DiscordBtn.Text = "Discord"
    DiscordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DiscordBtn.TextSize = isMobile and 9 or 10
    DiscordBtn.Font = Enum.Font.GothamBold
    DiscordBtn.AutoButtonColor = false
    DiscordBtn.ZIndex = 2

    local discordBtnCorner = Instance.new("UICorner", DiscordBtn)
    discordBtnCorner.CornerRadius = UDim.new(1, 0)

    local discordClicked = false
    DiscordBtn.MouseEnter:Connect(function()
        if not discordClicked then
            DiscordBtn.BackgroundColor3 = Color3.fromRGB(71, 82, 200)
        end
    end)
    DiscordBtn.MouseLeave:Connect(function()
        if not discordClicked then
            DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        end
    end)
    DiscordBtn.MouseButton1Click:Connect(function()
        if discordClicked then return end
        pcall(function() setclipboard("https://discord.gg/FesTMUPsgx") end)
        discordClicked = true
        DiscordBtn.Text = "Link Copied!"
        DiscordBtn.BackgroundColor3 = Color3.fromRGB(34, 170, 90)
        task.delay(2, function()
            if DiscordBtn and DiscordBtn.Parent then
                discordClicked = false
                DiscordBtn.Text = "Discord"
                DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
            end
        end)
    end)

    local TitleIcon = Instance.new("ImageLabel", Header)
    TitleIcon.Size = UDim2.new(0, 18, 0, 18)
    TitleIcon.Position = UDim2.new(0, 10, 0.5, -9)
    TitleIcon.BackgroundTransparency = 1
    TitleIcon.Image = "rbxassetid://106071465059482"
    TitleIcon.ScaleType = Enum.ScaleType.Fit
    TitleIcon.ZIndex = 2
    local TitleIconCorner = Instance.new("UICorner", TitleIcon)
    TitleIconCorner.CornerRadius = UDim.new(0, 4)

    local TitleLbl = Instance.new("TextLabel", Header)
    TitleLbl.Size = UDim2.new(1, -TITLE_RIGHT_MARGIN, 1, 0)
    TitleLbl.Position = UDim2.new(0, 33, 0, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text = "Maestro Converter ++"
    TitleLbl.TextColor3 = TEXT
    TitleLbl.TextSize = isMobile and 11 or 13
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLbl.ZIndex = 2

    local STEP_BAR_H = isMobile and 46 or 56
    local StepBar = Instance.new("Frame", Main)
    StepBar.Size = UDim2.new(1, 0, 0, STEP_BAR_H)
    StepBar.Position = UDim2.new(0, 0, 0, HEADER_H + 1)
    StepBar.BackgroundColor3 = BG2
    StepBar.BorderSizePixel = 0

    local StepBarDiv = Instance.new("Frame", Main)
    StepBarDiv.Size = UDim2.new(1, 0, 0, 1)
    StepBarDiv.Position = UDim2.new(0, 0, 0, HEADER_H + 1 + STEP_BAR_H)
    StepBarDiv.BackgroundColor3 = BORDER
    StepBarDiv.BorderSizePixel = 0
    StepBarDiv.ZIndex = 2

    local ContentPanel = Instance.new("Frame", Main)
    ContentPanel.Size = UDim2.new(1, 0, 0, BODY_H - STEP_BAR_H)
    ContentPanel.Position = UDim2.new(0, 0, 0, HEADER_H + 1 + STEP_BAR_H + 1)
    ContentPanel.BackgroundColor3 = BG
    ContentPanel.BorderSizePixel = 0
    ContentPanel.ClipsDescendants = true

    local stepNames = {"Model", "Format", "Scale", "Color", "Material"}
    local stepDots = {}
    local stepLabels = {}
    local stepLines = {}
    local stepScrolls = {}
    local stepUnlocked = {true, false, false, false, false}
    local currentStep = 1
    local refreshScaleStepFn = function() end
    local refreshColorStepFn = function() end

    local stepRow = Instance.new("Frame", StepBar)
    stepRow.Size = UDim2.new(1, -20, 1, 0)
    stepRow.Position = UDim2.new(0, 10, 0, 0)
    stepRow.BackgroundTransparency = 1

    local DOT_SIZE = isMobile and 18 or 22
    local nSteps = #stepNames

    for i, name in ipairs(stepNames) do
        local slotW = 1 / nSteps
        local xCenter = (i - 0.5) * slotW

        if i < nSteps then
            local line = Instance.new("Frame", stepRow)
            line.Size = UDim2.new(slotW, 0, 0, 2)
            line.Position = UDim2.new(xCenter, 0, 0, DOT_SIZE / 2 - 1 + (isMobile and 2 or 4))
            line.BackgroundColor3 = Color3.fromRGB(220, 225, 240)
            line.BorderSizePixel = 0
            line.ZIndex = 1
            stepLines[i] = line
        end

        local dot = Instance.new("TextButton", stepRow)
        dot.Size = UDim2.new(0, DOT_SIZE, 0, DOT_SIZE)
        dot.Position = UDim2.new(xCenter, -DOT_SIZE / 2, 0, isMobile and 2 or 4)
        dot.BackgroundColor3 = Color3.fromRGB(220, 225, 240)
        dot.BorderSizePixel = 0
        dot.Text = tostring(i)
        dot.TextColor3 = Color3.fromRGB(140, 155, 185)
        dot.TextSize = isMobile and 10 or 12
        dot.Font = Enum.Font.GothamBold
        dot.AutoButtonColor = false
        dot.ZIndex = 2

        local dotCorner = Instance.new("UICorner", dot)
        dotCorner.CornerRadius = UDim.new(1, 0)

        local lbl = Instance.new("TextLabel", stepRow)
        lbl.Size = UDim2.new(slotW, 0, 0, 12)
        lbl.Position = UDim2.new(xCenter - slotW / 2, 0, 0, DOT_SIZE + (isMobile and 4 or 8))
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = Color3.fromRGB(140, 155, 185)
        lbl.TextSize = isMobile and 8 or 9
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.ZIndex = 2

        stepDots[i] = dot
        stepLabels[i] = lbl

        local scroll = Instance.new("ScrollingFrame", ContentPanel)
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = Color3.fromRGB(180, 195, 225)
        scroll.Visible = false
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

        local layout = Instance.new("UIListLayout", scroll)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, isMobile and 5 or 7)
        local pad = Instance.new("UIPadding", scroll)
        pad.PaddingTop = UDim.new(0, isMobile and 8 or 12)
        pad.PaddingBottom = UDim.new(0, isMobile and 8 or 12)
        pad.PaddingLeft = UDim.new(0, PAD)
        pad.PaddingRight = UDim.new(0, PAD)

        stepScrolls[i] = scroll
    end

    local function refreshStepBar()
        for i, dot in ipairs(stepDots) do
            local lbl = stepLabels[i]
            if i == currentStep then
                dot.BackgroundColor3 = ACCENT
                dot.TextColor3 = Color3.fromRGB(255, 255, 255)
                lbl.TextColor3 = ACCENT
            elseif stepUnlocked[i] then
                dot.BackgroundColor3 = Color3.fromRGB(190, 225, 170)
                dot.TextColor3 = Color3.fromRGB(40, 130, 60)
                lbl.TextColor3 = Color3.fromRGB(40, 130, 60)
            else
                dot.BackgroundColor3 = Color3.fromRGB(220, 225, 240)
                dot.TextColor3 = Color3.fromRGB(140, 155, 185)
                lbl.TextColor3 = Color3.fromRGB(140, 155, 185)
            end
        end
        for i, line in ipairs(stepLines) do
            line.BackgroundColor3 = stepUnlocked[i + 1] and Color3.fromRGB(120, 190, 110) or Color3.fromRGB(220, 225, 240)
        end
    end

    local function goToStep(n)
        if n < 1 or n > nSteps then return end
        if n > currentStep and not stepUnlocked[n] then return end
        for _, s in ipairs(stepScrolls) do
            s.Visible = false
        end
        stepScrolls[n].Visible = true
        currentStep = n
        refreshStepBar()
        if n == 3 then
            refreshScaleStepFn()
        elseif n == 4 then
            refreshColorStepFn()
        end
    end

    for i, dot in ipairs(stepDots) do
        dot.MouseButton1Click:Connect(function()
            goToStep(i)
        end)
    end

    local function unlockNext(n)
        if n + 1 <= nSteps then
            stepUnlocked[n + 1] = true
        end
        refreshStepBar()
    end

    local function mkLabel(parent, text, order)
        local L = Instance.new("TextLabel", parent)
        L.Size = UDim2.new(1, 0, 0, LBL_H)
        L.BackgroundTransparency = 1
        L.Text = text
        L.TextColor3 = TEXTSUB
        L.TextSize = isMobile and 9 or 10
        L.Font = Enum.Font.GothamBold
        L.TextXAlignment = Enum.TextXAlignment.Left
        L.LayoutOrder = order
        return L
    end

    local function mkSpacer(parent, h, order)
        local f = Instance.new("Frame", parent)
        f.Size = UDim2.new(1, 0, 0, h)
        f.BackgroundTransparency = 1
        f.LayoutOrder = order
    end

    local function mkInput(parent, ph, order, default, cb, widthFraction)
        local f = Instance.new("Frame", parent)
        f.Size = UDim2.new(widthFraction or 1, 0, 0, INP_H)
        f.BackgroundColor3 = Color3.fromRGB(248, 249, 255)
        f.BorderSizePixel = 0
        f.LayoutOrder = order

        local corner = Instance.new("UICorner", f)
        corner.CornerRadius = UDim.new(0, 5)

        local s = Instance.new("UIStroke", f)
        s.Color = BORDER
        s.Thickness = 1

        local b = Instance.new("TextBox", f)
        b.Size = UDim2.new(1, -16, 1, 0)
        b.Position = UDim2.new(0, 8, 0, 0)
        b.BackgroundTransparency = 1
        b.PlaceholderText = ph
        b.PlaceholderColor3 = TEXTSUB
        b.Text = default or ""
        b.TextColor3 = TEXT
        b.TextSize = 11
        b.Font = Enum.Font.Gotham
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.ClearTextOnFocus = false
        b:GetPropertyChangedSignal("Text"):Connect(function()
            if cb then
                cb(b.Text)
            end
        end)
        b.Focused:Connect(function()
            s.Color = ACCENT
        end)
        b.FocusLost:Connect(function()
            s.Color = BORDER
        end)
        return b
    end

    local function roundTo2(v, step)
        local inv = 1 / step
        return math.floor(v * inv + 0.5) / inv
    end

    local function mkSlider(parent, sMin, sMax, def, step, order, cb)
        local cont = Instance.new("Frame", parent)
        cont.Size = UDim2.new(1, 0, 0, SLD_H)
        cont.BackgroundTransparency = 1
        cont.LayoutOrder = order

        local FW = PADW - 48
        local IW = 42

        local track = Instance.new("Frame", cont)
        track.Size = UDim2.new(0, FW, 0, SLD_H)
        track.BackgroundColor3 = Color3.fromRGB(225, 230, 245)
        track.BorderSizePixel = 0

        local trackCorner = Instance.new("UICorner", track)
        trackCorner.CornerRadius = UDim.new(0, 4)

        local ts = Instance.new("UIStroke", track)
        ts.Color = BORDER
        ts.Thickness = 1

        local pct0 = math.clamp((def - sMin) / (sMax - sMin), 0, 1)
        local fill = Instance.new("Frame", track)
        fill.Size = UDim2.new(pct0, 0, 1, 0)
        fill.BackgroundColor3 = ACCENT
        fill.BorderSizePixel = 0

        local fillCorner = Instance.new("UICorner", fill)
        fillCorner.CornerRadius = UDim.new(0, 4)

        local ca = Instance.new("TextButton", track)
        ca.Size = UDim2.new(1, 0, 1, 0)
        ca.BackgroundTransparency = 1
        ca.Text = ""
        ca.AutoButtonColor = false

        local numF = Instance.new("Frame", cont)
        numF.Size = UDim2.new(0, IW, 0, SLD_H)
        numF.Position = UDim2.new(0, FW + 6, 0, 0)
        numF.BackgroundColor3 = Color3.fromRGB(225, 230, 245)
        numF.BorderSizePixel = 0

        local numCorner = Instance.new("UICorner", numF)
        numCorner.CornerRadius = UDim.new(0, 4)

        local ns = Instance.new("UIStroke", numF)
        ns.Color = BORDER
        ns.Thickness = 1

        local vl = Instance.new("TextBox", numF)
        vl.Size = UDim2.new(1, 0, 1, 0)
        vl.BackgroundTransparency = 1
        vl.Text = tostring(def)
        vl.TextColor3 = TEXT
        vl.TextSize = 10
        vl.Font = Enum.Font.Gotham
        vl.ClearTextOnFocus = false

        local cur = def
        local isFocused = false

        if cb then cb(cur) end

        local function setFill(v)
            fill.Size = UDim2.new(math.clamp((v - sMin) / (sMax - sMin), 0, 1), 0, 1, 0)
        end

        local function updateValue(v)
            v = math.clamp(v, sMin, sMax)
            cur = v
            setFill(v)
            if not isFocused then
                vl.Text = string.format("%.2f", v)
            end
            if cb then cb(v) end
        end

        local function fromX(x)
            local rel = math.clamp(x - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
            local v = sMin + (sMax - sMin) * (rel / track.AbsoluteSize.X)
            v = roundTo2(v, step)
            v = math.clamp(v, sMin, sMax)
            updateValue(v)
        end

        local drag = false
        ca.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = true
                fromX(i.Position.X)
            end
        end)
        ca.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = false
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                fromX(i.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = false
            end
        end)

        vl.Focused:Connect(function()
            isFocused = true
            ns.Color = ACCENT
            vl.Text = string.format("%.2f", cur)
        end)

        vl.FocusLost:Connect(function()
            isFocused = false
            ns.Color = BORDER
            local num = tonumber(vl.Text)
            if num then
                num = math.clamp(num, 0, 999)
                cur = num
                setFill(math.clamp(num, sMin, sMax))
                vl.Text = string.format("%.2f", num)
                if cb then cb(num) end
            else
                vl.Text = string.format("%.2f", cur)
            end
        end)

        setFill(def)
        vl.Text = string.format("%.2f", def)

        return cont
    end

    local function mkButton(parent, txt, order, cb, accent)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(1, 0, 0, BTN_H)
        btn.BackgroundColor3 = accent and ACCENT or Color3.fromRGB(235, 238, 250)
        btn.BorderSizePixel = 0
        btn.Text = txt
        btn.TextColor3 = accent and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(60, 80, 140)
        btn.TextSize = isMobile and 10 or 11
        btn.Font = accent and Enum.Font.GothamBold or Enum.Font.Gotham
        btn.AutoButtonColor = false
        btn.LayoutOrder = order

        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 5)

        local baseColor = accent and ACCENT or Color3.fromRGB(235, 238, 250)
        local hoverColor = accent and Color3.fromRGB(28, 80, 200) or Color3.fromRGB(220, 225, 245)

        if not accent then
            local s = Instance.new("UIStroke", btn)
            s.Color = BORDER
            s.Thickness = 1
        end

        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = hoverColor
            if not accent then btn.TextColor3 = Color3.fromRGB(20, 40, 120) end
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = baseColor
            if not accent then btn.TextColor3 = Color3.fromRGB(60, 80, 140) end
        end)
        btn.MouseButton1Down:Connect(function()
            btn.BackgroundColor3 = accent and Color3.fromRGB(20, 60, 160) or Color3.fromRGB(200, 210, 240)
        end)
        btn.MouseButton1Up:Connect(function()
            btn.BackgroundColor3 = hoverColor
        end)
        if cb then
            btn.MouseButton1Click:Connect(cb)
        end
        return btn
    end

    local function mkStat(parent, order)
        local L = Instance.new("TextLabel", parent)
        L.Size = UDim2.new(1, 0, 0, STAT_H)
        L.BackgroundTransparency = 1
        L.Text = ""
        L.TextColor3 = Color3.fromRGB(30, 130, 80)
        L.TextSize = isMobile and 9 or 10
        L.Font = Enum.Font.Gotham
        L.TextXAlignment = Enum.TextXAlignment.Left
        L.TextWrapped = true
        L.LayoutOrder = order
        return L
    end

    local function mkRadioRow(parent, label, order, checked, cb)
        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, BTN_H)
        row.BackgroundColor3 = checked and Color3.fromRGB(232, 240, 255) or Color3.fromRGB(248, 249, 255)
        row.BorderSizePixel = 0
        row.LayoutOrder = order

        local rCorner = Instance.new("UICorner", row)
        rCorner.CornerRadius = UDim.new(0, 5)

        local rStroke = Instance.new("UIStroke", row)
        rStroke.Color = checked and ACCENT or BORDER
        rStroke.Thickness = checked and 1.5 or 1

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -40, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = TEXT
        lbl.TextSize = isMobile and 10 or 11
        lbl.Font = checked and Enum.Font.GothamBold or Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local box = Instance.new("Frame", row)
        box.Size = UDim2.new(0, 18, 0, 18)
        box.Position = UDim2.new(1, -28, 0.5, -9)
        box.BackgroundColor3 = checked and ACCENT or Color3.fromRGB(225, 230, 245)
        box.BorderSizePixel = 0

        local boxCorner = Instance.new("UICorner", box)
        boxCorner.CornerRadius = UDim.new(1, 0)

        local boxStroke = Instance.new("UIStroke", box)
        boxStroke.Color = BORDER
        boxStroke.Thickness = 1

        local check = Instance.new("TextLabel", box)
        check.Size = UDim2.new(1, 0, 1, 0)
        check.BackgroundTransparency = 1
        check.Text = checked and "✓" or ""
        check.TextColor3 = Color3.fromRGB(255, 255, 255)
        check.TextSize = 12
        check.Font = Enum.Font.GothamBold

        local clickBtn = Instance.new("TextButton", row)
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.AutoButtonColor = false

        local function setChecked(state)
            row.BackgroundColor3 = state and Color3.fromRGB(232, 240, 255) or Color3.fromRGB(248, 249, 255)
            rStroke.Color = state and ACCENT or BORDER
            rStroke.Thickness = state and 1.5 or 1
            lbl.Font = state and Enum.Font.GothamBold or Enum.Font.Gotham
            box.BackgroundColor3 = state and ACCENT or Color3.fromRGB(225, 230, 245)
            check.Text = state and "✓" or ""
        end

        clickBtn.MouseButton1Click:Connect(function()
            if cb then cb() end
        end)

        return row, setChecked
    end

    local function mkToggleRow(parent, label, order, default, cb)
        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, BTN_H)
        row.BackgroundColor3 = Color3.fromRGB(248, 249, 255)
        row.BorderSizePixel = 0
        row.LayoutOrder = order

        local rCorner = Instance.new("UICorner", row)
        rCorner.CornerRadius = UDim.new(0, 5)

        local rStroke = Instance.new("UIStroke", row)
        rStroke.Color = BORDER
        rStroke.Thickness = 1

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -40, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = TEXT
        lbl.TextSize = isMobile and 10 or 11
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local box = Instance.new("Frame", row)
        box.Size = UDim2.new(0, 18, 0, 18)
        box.Position = UDim2.new(1, -28, 0.5, -9)
        box.BackgroundColor3 = default and ACCENT or Color3.fromRGB(225, 230, 245)
        box.BorderSizePixel = 0

        local boxCorner = Instance.new("UICorner", box)
        boxCorner.CornerRadius = UDim.new(0, 4)

        local boxStroke = Instance.new("UIStroke", box)
        boxStroke.Color = BORDER
        boxStroke.Thickness = 1

        local check = Instance.new("TextLabel", box)
        check.Size = UDim2.new(1, 0, 1, 0)
        check.BackgroundTransparency = 1
        check.Text = default and "✓" or ""
        check.TextColor3 = Color3.fromRGB(255, 255, 255)
        check.TextSize = 12
        check.Font = Enum.Font.GothamBold

        local clickBtn = Instance.new("TextButton", row)
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.AutoButtonColor = false

        local state = default
        clickBtn.MouseButton1Click:Connect(function()
            state = not state
            box.BackgroundColor3 = state and ACCENT or Color3.fromRGB(225, 230, 245)
            check.Text = state and "✓" or ""
            if cb then cb(state) end
        end)

        return row
    end

    local function mkDropdown(parent, lbl, opts, def, order, cb)
        local sec = Instance.new("Frame", parent)
        sec.Size = UDim2.new(1, 0, 0, 0)
        sec.BackgroundTransparency = 1
        sec.AutomaticSize = Enum.AutomaticSize.Y
        sec.LayoutOrder = order

        local sl = Instance.new("UIListLayout", sec)
        sl.SortOrder = Enum.SortOrder.LayoutOrder
        sl.Padding = UDim.new(0, 4)

        mkLabel(sec, lbl, 1)

        local dd = Instance.new("TextButton", sec)
        dd.Size = UDim2.new(1, 0, 0, INP_H)
        dd.BackgroundColor3 = Color3.fromRGB(248, 249, 255)
        dd.BorderSizePixel = 0
        dd.Text = ""
        dd.AutoButtonColor = false
        dd.LayoutOrder = 2

        local ddCorner = Instance.new("UICorner", dd)
        ddCorner.CornerRadius = UDim.new(0, 5)

        local ds = Instance.new("UIStroke", dd)
        ds.Color = BORDER
        ds.Thickness = 1

        local ddL = Instance.new("TextLabel", dd)
        ddL.Size = UDim2.new(1, -22, 1, 0)
        ddL.Position = UDim2.new(0, 8, 0, 0)
        ddL.BackgroundTransparency = 1
        ddL.Text = def
        ddL.TextColor3 = TEXT
        ddL.TextSize = 11
        ddL.Font = Enum.Font.Gotham
        ddL.TextXAlignment = Enum.TextXAlignment.Left

        local arr = Instance.new("TextLabel", dd)
        arr.Size = UDim2.new(0, 16, 1, 0)
        arr.Position = UDim2.new(1, -18, 0, 0)
        arr.BackgroundTransparency = 1
        arr.Text = "▼"
        arr.TextColor3 = TEXTSUB
        arr.TextSize = 9

        local list = Instance.new("Frame", SG)
        list.BackgroundColor3 = Color3.fromRGB(245, 247, 255)
        list.BorderSizePixel = 0
        list.ClipsDescendants = true
        list.Visible = false
        list.ZIndex = 100

        local listCorner = Instance.new("UICorner", list)
        listCorner.CornerRadius = UDim.new(0, 6)

        local ls = Instance.new("UIStroke", list)
        ls.Color = BORDER

        local listScroll = Instance.new("ScrollingFrame", list)
        listScroll.Size = UDim2.new(1, 0, 1, 0)
        listScroll.BackgroundTransparency = 1
        listScroll.BorderSizePixel = 0
        listScroll.ScrollBarThickness = 3
        listScroll.ScrollBarImageColor3 = Color3.fromRGB(180, 195, 225)
        listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        listScroll.ZIndex = 101

        local ll2 = Instance.new("UIListLayout", listScroll)
        ll2.SortOrder = Enum.SortOrder.LayoutOrder
        local lp = Instance.new("UIPadding", listScroll)
        lp.PaddingTop = UDim.new(0, 3)
        lp.PaddingBottom = UDim.new(0, 3)

        local dropOpen = false

        local function selectOpt(opt)
            ddL.Text = opt
            list.Visible = false
            dropOpen = false
            ds.Color = BORDER
            if cb then cb(opt) end
        end

        for i, opt in ipairs(opts) do
            local ob = Instance.new("TextButton", listScroll)
            ob.Size = UDim2.new(1, 0, 0, 24)
            ob.BackgroundTransparency = 1
            ob.BackgroundColor3 = Color3.fromRGB(225, 230, 245)
            ob.BorderSizePixel = 0
            ob.Text = ""
            ob.AutoButtonColor = false
            ob.LayoutOrder = i
            ob.ZIndex = 101
            local ol = Instance.new("TextLabel", ob)
            ol.Size = UDim2.new(1, -8, 1, 0)
            ol.Position = UDim2.new(0, 8, 0, 0)
            ol.BackgroundTransparency = 1
            ol.Text = opt
            ol.TextColor3 = TEXT
            ol.TextSize = 10
            ol.Font = Enum.Font.Gotham
            ol.TextXAlignment = Enum.TextXAlignment.Left
            ol.ZIndex = 102
            ob.MouseEnter:Connect(function()
                ob.BackgroundTransparency = 0
            end)
            ob.MouseLeave:Connect(function()
                ob.BackgroundTransparency = 1
            end)
            ob.MouseButton1Click:Connect(function()
                selectOpt(opt)
            end)
        end

        dd.MouseButton1Click:Connect(function()
            dropOpen = not dropOpen
            list.Visible = dropOpen
            if dropOpen then
                local ap = dd.AbsolutePosition
                local as = dd.AbsoluteSize
                local winPos = MainBorder.AbsolutePosition
                local winSize = MainBorder.AbsoluteSize
                local winBottom = winPos.Y + winSize.Y
                local winTop = winPos.Y

                local desiredH = math.min(#opts, 6) * 24 + 6
                local spaceBelow = winBottom - (ap.Y + as.Y + 3) - 6
                local spaceAbove = (ap.Y - 3) - winTop - 6

                local finalH = math.min(desiredH, math.max(spaceBelow, 24))
                local openDown = true

                if spaceBelow < 60 and spaceAbove > spaceBelow then
                    openDown = false
                    finalH = math.min(desiredH, math.max(spaceAbove, 24))
                end

                if openDown then
                    list.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 3)
                else
                    list.Position = UDim2.new(0, ap.X, 0, ap.Y - 3 - finalH)
                end

                list.Size = UDim2.new(0, as.X, 0, finalH)
                ds.Color = ACCENT
            else
                ds.Color = BORDER
            end
        end)

        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and dropOpen then
                task.wait()
                if not dropOpen then return end
                local mpos = UserInputService:GetMouseLocation()
                local lp2 = list.AbsolutePosition
                local ls2 = list.AbsoluteSize
                local dp = dd.AbsolutePosition
                local dsz = dd.AbsoluteSize
                local inList = mpos.X >= lp2.X and mpos.X <= lp2.X + ls2.X and mpos.Y >= lp2.Y and mpos.Y <= lp2.Y + ls2.Y
                local inDD   = mpos.X >= dp.X and mpos.X <= dp.X + dsz.X and mpos.Y >= dp.Y and mpos.Y <= dp.Y + dsz.Y
                if not inList and not inDD then
                    dropOpen = false
                    list.Visible = false
                    ds.Color = BORDER
                end
            end
        end)

        return sec, ddL, selectOpt
    end

    local function mkFileBrowser(parent, order, widthFraction, onSelectFile)
        local secWidth = widthFraction or (1 / 3)
        local GAP = 8

        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, INP_H)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order

        local sec = Instance.new("Frame", row)
        sec.Size = UDim2.new(secWidth, -GAP / 2, 1, 0)
        sec.Position = UDim2.new(0, 0, 0, 0)
        sec.BackgroundColor3 = Color3.fromRGB(248, 249, 255)
        sec.BorderSizePixel = 0
        sec.ZIndex = 5

        local sCorner = Instance.new("UICorner", sec)
        sCorner.CornerRadius = UDim.new(0, 5)

        local sStroke = Instance.new("UIStroke", sec)
        sStroke.Color = BORDER
        sStroke.Thickness = 1

        local btn = Instance.new("TextButton", sec)
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 7

        local lbl = Instance.new("TextLabel", sec)
        lbl.Size = UDim2.new(1, -10, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Select file"
        lbl.TextColor3 = TEXTSUB
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.ZIndex = 6

        local reloadBtn = Instance.new("TextButton", row)
        local RELOAD_W = isMobile and 56 or 64
        reloadBtn.Size = UDim2.new(0, RELOAD_W, 1, 0)
        reloadBtn.Position = UDim2.new(secWidth, GAP / 2, 0, 0)
        reloadBtn.BackgroundColor3 = Color3.fromRGB(235, 238, 250)
        reloadBtn.BorderSizePixel = 0
        reloadBtn.Text = "Reload"
        reloadBtn.TextColor3 = Color3.fromRGB(60, 80, 140)
        reloadBtn.TextSize = isMobile and 10 or 11
        reloadBtn.Font = Enum.Font.Gotham
        reloadBtn.AutoButtonColor = false
        reloadBtn.ZIndex = 5

        local reloadCorner = Instance.new("UICorner", reloadBtn)
        reloadCorner.CornerRadius = UDim.new(0, 5)

        local reloadStroke = Instance.new("UIStroke", reloadBtn)
        reloadStroke.Color = BORDER
        reloadStroke.Thickness = 1

        reloadBtn.MouseEnter:Connect(function()
            reloadBtn.BackgroundColor3 = Color3.fromRGB(220, 225, 245)
            reloadBtn.TextColor3 = Color3.fromRGB(20, 40, 120)
        end)
        reloadBtn.MouseLeave:Connect(function()
            reloadBtn.BackgroundColor3 = Color3.fromRGB(235, 238, 250)
            reloadBtn.TextColor3 = Color3.fromRGB(60, 80, 140)
        end)
        reloadBtn.MouseButton1Down:Connect(function()
            reloadBtn.BackgroundColor3 = Color3.fromRGB(200, 210, 240)
        end)
        reloadBtn.MouseButton1Up:Connect(function()
            reloadBtn.BackgroundColor3 = Color3.fromRGB(220, 225, 245)
        end)

        local list = Instance.new("Frame", SG)
        list.BackgroundColor3 = Color3.fromRGB(245, 247, 255)
        list.BorderSizePixel = 0
        list.ClipsDescendants = true
        list.Visible = false
        list.ZIndex = 20

        local lCorner = Instance.new("UICorner", list)
        lCorner.CornerRadius = UDim.new(0, 5)

        local lStroke = Instance.new("UIStroke", list)
        lStroke.Color = BORDER
        lStroke.Thickness = 1

        local scroll = Instance.new("ScrollingFrame", list)
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = Color3.fromRGB(180, 195, 225)
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.ZIndex = 21
        local sLayout = Instance.new("UIListLayout", scroll)
        sLayout.SortOrder = Enum.SortOrder.LayoutOrder
        Instance.new("UIPadding", scroll).PaddingTop = UDim.new(0, 2)

        local open = false
        local files = {}
        local rows = {}

        local function updatePos()
            local ap = sec.AbsolutePosition
            local as = sec.AbsoluteSize
            list.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 2)
        end

        local function refreshFiles()
            files = {}
            local ok, list2 = pcall(function() return listfiles("") end)
            if ok and list2 then
                for _, path in ipairs(list2) do
                    local name = path:gsub("\\", "/"):match("([^/]+)$") or path
                    local ok2, res = pcall(function() return isfile(path) end)
                    if ok2 and res and name:lower():find("%.obj$") then
                        table.insert(files, {name = name, path = path})
                    end
                end
            end
        end

        local function closeList()
            list.Visible = false
            open = false
            sStroke.Color = BORDER
        end

        local function populate()
            for _, r in ipairs(rows) do r:Destroy() end
            rows = {}
            if #files == 0 then
                local e = Instance.new("TextLabel", scroll)
                e.Size = UDim2.new(1, 0, 0, ITEM_H)
                e.BackgroundTransparency = 1
                e.Text = "  No .obj files found"
                e.TextColor3 = Color3.fromRGB(140, 155, 185)
                e.TextSize = 11
                e.Font = Enum.Font.Gotham
                e.TextXAlignment = Enum.TextXAlignment.Left
                e.ZIndex = 22
                table.insert(rows, e)
                return
            end
            for idx, f in ipairs(files) do
                local rowBtn = Instance.new("TextButton", scroll)
                rowBtn.Size = UDim2.new(1, 0, 0, ITEM_H)
                rowBtn.BackgroundColor3 = Color3.fromRGB(235, 238, 250)
                rowBtn.BackgroundTransparency = 1
                rowBtn.BorderSizePixel = 0
                rowBtn.Text = ""
                rowBtn.AutoButtonColor = false
                rowBtn.LayoutOrder = idx
                rowBtn.ZIndex = 22
                local nl = Instance.new("TextLabel", rowBtn)
                nl.Size = UDim2.new(1, -8, 1, 0)
                nl.Position = UDim2.new(0, 8, 0, 0)
                nl.BackgroundTransparency = 1
                nl.Text = f.name
                nl.TextColor3 = TEXT
                nl.TextSize = 11
                nl.Font = Enum.Font.Gotham
                nl.TextXAlignment = Enum.TextXAlignment.Left
                nl.TextTruncate = Enum.TextTruncate.AtEnd
                nl.ZIndex = 23
                local dv = Instance.new("Frame", rowBtn)
                dv.Size = UDim2.new(1, -8, 0, 1)
                dv.Position = UDim2.new(0, 4, 1, -1)
                dv.BackgroundColor3 = BORDER
                dv.BorderSizePixel = 0
                dv.ZIndex = 23
                rowBtn.MouseEnter:Connect(function()
                    rowBtn.BackgroundTransparency = 0
                    rowBtn.BackgroundColor3 = Color3.fromRGB(220, 225, 245)
                    nl.TextColor3 = Color3.fromRGB(20, 40, 120)
                end)
                rowBtn.MouseLeave:Connect(function()
                    rowBtn.BackgroundTransparency = 1
                    nl.TextColor3 = TEXT
                end)
                rowBtn.MouseButton1Down:Connect(function()
                    lbl.Text = f.name
                    lbl.TextColor3 = TEXT
                    closeList()
                    if onSelectFile then onSelectFile(f.path, f.name) end
                end)
                table.insert(rows, rowBtn)
            end
        end

        local function refreshListSize()
            local visCount = math.min(#files == 0 and 1 or #files, DROP_MAX)
            local h = visCount * ITEM_H + 4
            list.Size = UDim2.new(0, sec.AbsoluteSize.X, 0, h)
        end

        local function openList()
            populate()
            refreshListSize()
            updatePos()
            list.Visible = true
            open = true
            sStroke.Color = ACCENT
        end

        btn.MouseButton1Click:Connect(function()
            if open then
                closeList()
            else
                openList()
            end
        end)

        reloadBtn.MouseButton1Click:Connect(function()
            refreshFiles()
            if open then
                populate()
                refreshListSize()
            end
        end)

        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and open then
                task.wait()
                if not open then return end
                local mpos = UserInputService:GetMouseLocation()
                local dp = list.AbsolutePosition
                local ds2 = list.AbsoluteSize
                local hp = sec.AbsolutePosition
                local hs = sec.AbsoluteSize
                local inD = mpos.X >= dp.X and mpos.X <= dp.X + ds2.X and mpos.Y >= dp.Y and mpos.Y <= dp.Y + ds2.Y
                local inH = mpos.X >= hp.X and mpos.X <= hp.X + hs.X and mpos.Y >= hp.Y and mpos.Y <= hp.Y + hs.Y
                if not inD and not inH then
                    closeList()
                end
            end
        end)

        game:GetService("RunService").RenderStepped:Connect(function()
            if open then updatePos() end
        end)

        refreshFiles()

        return row
    end

    local step1 = stepScrolls[1]
    mkLabel(step1, "SELECT MODEL", 1)
    mkSpacer(step1, 3, 2)
    mkFileBrowser(step1, 3, 1 / 3, function(path, name)
        objFileName = path
    end)
    mkLabel(step1, "OUTPUT FILE NAME", 4)
    mkSpacer(step1, 3, 5)
    mkInput(step1, "output", 6, "", function(v)
        objOutputName = v
    end, 1 / 3)
    mkSpacer(step1, 8, 7)
    mkButton(step1, "Assign", 8, function()
        if objFileName == "" then return end
        unlockNext(1)
        goToStep(2)
    end, true)

    local step2 = stepScrolls[2]
    mkLabel(step2, "CONVERSION FORMAT", 1)
    mkSpacer(step2, 3, 2)

    local fmtWireSetChecked, fmtSolidSetChecked

    local wireExtRow

    local function setFormat(f)
        format = f
        if fmtWireSetChecked then fmtWireSetChecked(f == "Wireframe") end
        if fmtSolidSetChecked then fmtSolidSetChecked(f == "Solid") end
        if wireExtRow then
            wireExtRow.Visible = (f == "Wireframe")
        end
    end

    local _, wireSet = mkRadioRow(step2, "Wireframe", 3, false, function() setFormat("Wireframe") end)
    fmtWireSetChecked = wireSet

    wireExtRow = Instance.new("Frame", step2)
    wireExtRow.Size = UDim2.new(1, 0, 0, 0)
    wireExtRow.AutomaticSize = Enum.AutomaticSize.Y
    wireExtRow.BackgroundTransparency = 1
    wireExtRow.LayoutOrder = 4
    wireExtRow.Visible = false
    local wireExtLayout = Instance.new("UIListLayout", wireExtRow)
    wireExtLayout.SortOrder = Enum.SortOrder.LayoutOrder
    wireExtLayout.Padding = UDim.new(0, 6)
    mkToggleRow(wireExtRow, "Extended Wireframe", 1, false, function(state)
        extendedWireframe = state
    end)

    local _, solidSet = mkRadioRow(step2, "Solid", 5, true, function() setFormat("Solid") end)
    fmtSolidSetChecked = solidSet

    setFormat("Solid")

    mkSpacer(step2, 8, 6)
    mkButton(step2, "Save", 7, function()
        unlockNext(2)
        goToStep(3)
    end, true)

    local step3 = stepScrolls[3]
    local step3Wire = Instance.new("Frame", step3)
    step3Wire.Size = UDim2.new(1, 0, 0, 0)
    step3Wire.AutomaticSize = Enum.AutomaticSize.Y
    step3Wire.BackgroundTransparency = 1
    step3Wire.LayoutOrder = 1
    local step3WireLayout = Instance.new("UIListLayout", step3Wire)
    step3WireLayout.SortOrder = Enum.SortOrder.LayoutOrder
    step3WireLayout.Padding = UDim.new(0, isMobile and 5 or 7)

    mkLabel(step3Wire, "SCALE", 1)
    mkSpacer(step3Wire, 3, 2)
    mkSlider(step3Wire, 0.1, 100, 1.0, 0.1, 3, function(v)
        objScale = v
    end)
    mkLabel(step3Wire, "STRIP SIZE", 4)
    mkSpacer(step3Wire, 3, 5)
    mkSlider(step3Wire, 0.01, 2.0, 0.2, 0.01, 6, function(v)
        objThickness = v
    end)

    local step3Solid = Instance.new("Frame", step3)
    step3Solid.Size = UDim2.new(1, 0, 0, 0)
    step3Solid.AutomaticSize = Enum.AutomaticSize.Y
    step3Solid.BackgroundTransparency = 1
    step3Solid.LayoutOrder = 1
    local step3SolidLayout = Instance.new("UIListLayout", step3Solid)
    step3SolidLayout.SortOrder = Enum.SortOrder.LayoutOrder
    step3SolidLayout.Padding = UDim.new(0, isMobile and 5 or 7)

    mkLabel(step3Solid, "SCALE", 1)
    mkSpacer(step3Solid, 3, 2)
    mkSlider(step3Solid, 0.1, 100, 1.0, 0.1, 3, function(v)
        objSolidScale = v
    end)
    mkLabel(step3Solid, "STRIP SIZE", 4)
    mkSpacer(step3Solid, 3, 5)
    mkSlider(step3Solid, 0.01, 5.0, 0.5, 0.01, 6, function(v)
        objStripSize = v
    end)

    local function refreshScaleStep()
        step3Wire.Visible = (format == "Wireframe")
        step3Solid.Visible = (format == "Solid")
    end
    refreshScaleStepFn = refreshScaleStep

    mkSpacer(step3, 8, 2)
    mkButton(step3, "Save", 3, function()
        unlockNext(3)
        goToStep(4)
    end, true)

    local step4 = stepScrolls[4]
    mkLabel(step4, "COLOR MODE", 1)
    mkSpacer(step4, 3, 2)

    local staticRadioSet, gradientRadioSet, randomRadioSet

    local function setColorMode(mode)
        colorMode = mode
        gradientEnabled = (mode == "Gradient")
        customColorEnabled = (mode == "Static")
        randomColorEnabled = (mode == "Random")
        if staticRadioSet then staticRadioSet(mode == "Static") end
        if gradientRadioSet then gradientRadioSet(mode == "Gradient") end
        if randomRadioSet then randomRadioSet(mode == "Random") end
        refreshColorStepFn()
    end

    local _, staticSet = mkRadioRow(step4, "Static", 3, true, function() setColorMode("Static") end)
    staticRadioSet = staticSet
    local _, gradientSet = mkRadioRow(step4, "Gradient", 4, false, function() setColorMode("Gradient") end)
    gradientRadioSet = gradientSet
    local _, randomSet = mkRadioRow(step4, "Random", 5, false, function() setColorMode("Random") end)
    randomRadioSet = randomSet

    local function mkRGBSliderRow(parentFrame, label, initVal, setFunc, rowOrder)
        local ROW_H = SLD_H
        local row = Instance.new("Frame", parentFrame)
        row.Size = UDim2.new(1, 0, 0, ROW_H)
        row.BackgroundTransparency = 1
        row.LayoutOrder = rowOrder

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0, 20, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = TEXT
        lbl.TextSize = isMobile and 9 or 10
        lbl.Font = Enum.Font.GothamBold

        local track = Instance.new("Frame", row)
        track.Size = UDim2.new(1, -70, 1, 0)
        track.Position = UDim2.new(0, 24, 0, 0)
        track.BackgroundColor3 = Color3.fromRGB(225, 230, 245)
        track.BorderSizePixel = 0

        local tCorner = Instance.new("UICorner", track)
        tCorner.CornerRadius = UDim.new(0, 3)

        local tStroke = Instance.new("UIStroke", track)
        tStroke.Color = BORDER
        tStroke.Thickness = 1

        local fill = Instance.new("Frame", track)
        fill.Size = UDim2.new(initVal, 0, 1, 0)
        fill.BackgroundColor3 = ACCENT
        fill.BorderSizePixel = 0

        local fCorner = Instance.new("UICorner", fill)
        fCorner.CornerRadius = UDim.new(0, 3)

        local slider = Instance.new("TextButton", track)
        slider.Size = UDim2.new(1, 0, 1, 0)
        slider.BackgroundTransparency = 1
        slider.Text = ""
        slider.AutoButtonColor = false

        local numBox = Instance.new("TextLabel", row)
        numBox.Size = UDim2.new(0, 40, 1, 0)
        numBox.Position = UDim2.new(1, -40, 0, 0)
        numBox.BackgroundColor3 = Color3.fromRGB(225, 230, 245)
        numBox.BorderSizePixel = 0
        numBox.Text = tostring(math.floor(initVal * 255))
        numBox.TextColor3 = TEXT
        numBox.TextSize = 9
        numBox.Font = Enum.Font.Gotham

        local nCorner = Instance.new("UICorner", numBox)
        nCorner.CornerRadius = UDim.new(0, 3)

        local nStroke = Instance.new("UIStroke", numBox)
        nStroke.Color = BORDER

        local isDragging = false
        local function updateSlider(pct, skipCb)
            pct = math.clamp(pct, 0, 1)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            numBox.Text = tostring(math.floor(pct * 255))
            if not skipCb then
                setFunc(pct)
            end
        end
        local function fromX(x)
            local rel = math.clamp(x - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
            updateSlider(rel / track.AbsoluteSize.X)
        end
        slider.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
                fromX(i.Position.X)
            end
        end)
        slider.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                isDragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if isDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                fromX(i.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                isDragging = false
            end
        end)

        local function setValue(pct, skipCb)
            updateSlider(pct, skipCb)
        end

        return setValue
    end

    local function mkColorSwatchHeader(parent, label, initColor, order)
        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, isMobile and 22 or 26)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order

        local swatch = Instance.new("Frame", row)
        swatch.Size = UDim2.new(0, isMobile and 18 or 22, 0, isMobile and 18 or 22)
        swatch.Position = UDim2.new(0, 0, 0.5, -(isMobile and 9 or 11))
        swatch.BackgroundColor3 = initColor
        swatch.BorderSizePixel = 0

        local swCorner = Instance.new("UICorner", swatch)
        swCorner.CornerRadius = UDim.new(0, 5)

        local swStroke = Instance.new("UIStroke", swatch)
        swStroke.Color = BORDER
        swStroke.Thickness = 1

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -34, 1, 0)
        lbl.Position = UDim2.new(0, (isMobile and 18 or 22) + 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = TEXTSUB
        lbl.TextSize = isMobile and 9 or 10
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local function setColor(c)
            swatch.BackgroundColor3 = c
        end

        return setColor
    end

    local colorPresets = {
        {name = "Inferno",    c1 = Color3.fromRGB(15, 15, 18),   c2 = Color3.fromRGB(220, 60, 35)},
        {name = "Sunset",     c1 = Color3.fromRGB(20, 18, 25),   c2 = Color3.fromRGB(245, 140, 40)},
        {name = "Citrus",     c1 = Color3.fromRGB(245, 140, 40), c2 = Color3.fromRGB(70, 190, 220)},
        {name = "Bubblegum",  c1 = Color3.fromRGB(250, 130, 180),c2 = Color3.fromRGB(70, 90, 220)},
        {name = "Ocean",      c1 = Color3.fromRGB(10, 40, 80),   c2 = Color3.fromRGB(80, 210, 220)},
        {name = "Berry",      c1 = Color3.fromRGB(140, 30, 90),  c2 = Color3.fromRGB(255, 200, 60)},
        {name = "Mint",       c1 = Color3.fromRGB(20, 25, 30),   c2 = Color3.fromRGB(60, 230, 170)},
        {name = "Royal",      c1 = Color3.fromRGB(25, 15, 60),   c2 = Color3.fromRGB(160, 100, 255)},
        {name = "Gold",       c1 = Color3.fromRGB(30, 20, 10),   c2 = Color3.fromRGB(255, 200, 80)},
        {name = "Lava",       c1 = Color3.fromRGB(255, 80, 30),  c2 = Color3.fromRGB(255, 220, 60)},
    }

    local staticColorBlock = Instance.new("Frame", step4)
    staticColorBlock.Size = UDim2.new(1, 0, 0, 0)
    staticColorBlock.AutomaticSize = Enum.AutomaticSize.Y
    staticColorBlock.BackgroundTransparency = 1
    staticColorBlock.LayoutOrder = 6
    local staticLayout = Instance.new("UIListLayout", staticColorBlock)
    staticLayout.SortOrder = Enum.SortOrder.LayoutOrder
    staticLayout.Padding = UDim.new(0, isMobile and 5 or 7)

    local staticSwatchSet = mkColorSwatchHeader(staticColorBlock, "STATIC COLOR", customColor, 1)
    local curR, curG, curB = customColor.R, customColor.G, customColor.B
    local setRStatic, setGStatic, setBStatic
    local function applyCustomColor()
        local c = Color3.new(curR, curG, curB)
        customColor = c
        staticSwatchSet(c)
    end
    setRStatic = mkRGBSliderRow(staticColorBlock, "R", curR, function(v) curR = v; applyCustomColor() end, 2)
    setGStatic = mkRGBSliderRow(staticColorBlock, "G", curG, function(v) curG = v; applyCustomColor() end, 3)
    setBStatic = mkRGBSliderRow(staticColorBlock, "B", curB, function(v) curB = v; applyCustomColor() end, 4)

    local function mkPresetSwatch(parent, preset, size, onClick)
        local btn = Instance.new("Frame", parent)
        btn.Size = UDim2.new(0, size, 0, size)
        btn.BackgroundColor3 = Color3.new(1, 1, 1)
        btn.BorderSizePixel = 0
        btn.ClipsDescendants = true

        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 7)

        local grad = Instance.new("UIGradient", btn)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, preset.c1),
            ColorSequenceKeypoint.new(0.499, preset.c1),
            ColorSequenceKeypoint.new(0.501, preset.c2),
            ColorSequenceKeypoint.new(1, preset.c2),
        })

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = BORDER
        stroke.Thickness = 1
        stroke.Transparency = 0.3
        stroke.ZIndex = 3

        local clickBtn = Instance.new("TextButton", btn)
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.AutoButtonColor = false
        clickBtn.ZIndex = 4

        clickBtn.MouseEnter:Connect(function()
            stroke.Color = ACCENT
            stroke.Thickness = 1.5
        end)
        clickBtn.MouseLeave:Connect(function()
            stroke.Color = BORDER
            stroke.Thickness = 1
        end)

        clickBtn.MouseButton1Click:Connect(function()
            if onClick then onClick(preset) end
        end)

        return btn
    end

    local function mkPresetGrid(parent, order, onPick)
        local wrap = Instance.new("Frame", parent)
        wrap.Size = UDim2.new(1, 0, 0, 0)
        wrap.AutomaticSize = Enum.AutomaticSize.Y
        wrap.BackgroundTransparency = 1
        wrap.LayoutOrder = order

        local wLayout = Instance.new("UIListLayout", wrap)
        wLayout.SortOrder = Enum.SortOrder.LayoutOrder
        wLayout.Padding = UDim.new(0, 4)

        mkLabel(wrap, "PRESETS", 1)

        local swatchSize = isMobile and 30 or 34
        local cellPad = isMobile and 6 or 8
        local cols = math.max(1, math.floor((PADW + cellPad) / (swatchSize + cellPad)))
        local rows = math.ceil(#colorPresets / cols)
        local gridH = rows * swatchSize + (rows - 1) * cellPad

        local grid = Instance.new("Frame", wrap)
        grid.Size = UDim2.new(1, 0, 0, gridH)
        grid.BackgroundTransparency = 1
        grid.LayoutOrder = 2

        local gridLayout = Instance.new("UIGridLayout", grid)
        gridLayout.CellSize = UDim2.new(0, swatchSize, 0, swatchSize)
        gridLayout.CellPadding = UDim2.new(0, cellPad, 0, cellPad)
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.StartCorner = Enum.StartCorner.TopLeft
        gridLayout.FillDirection = Enum.FillDirection.Horizontal

        for i, preset in ipairs(colorPresets) do
            local sw = mkPresetSwatch(grid, preset, swatchSize, onPick)
            sw.LayoutOrder = i
        end

        return wrap
    end

    local gradientColorBlock = Instance.new("Frame", step4)
    gradientColorBlock.Size = UDim2.new(1, 0, 0, 0)
    gradientColorBlock.AutomaticSize = Enum.AutomaticSize.Y
    gradientColorBlock.BackgroundTransparency = 1
    gradientColorBlock.LayoutOrder = 6
    gradientColorBlock.Visible = false
    local gradLayout = Instance.new("UIListLayout", gradientColorBlock)
    gradLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gradLayout.Padding = UDim.new(0, isMobile and 5 or 7)

    local grad1SwatchSet = mkColorSwatchHeader(gradientColorBlock, "COLOR 1", gradientColor1, 1)
    local c1R, c1G, c1B = gradientColor1.R, gradientColor1.G, gradientColor1.B
    local setR1, setG1, setB1
    local function applyColor1()
        local c = Color3.new(c1R, c1G, c1B)
        gradientColor1 = c
        grad1SwatchSet(c)
    end
    setR1 = mkRGBSliderRow(gradientColorBlock, "R", c1R, function(v) c1R = v; applyColor1() end, 2)
    setG1 = mkRGBSliderRow(gradientColorBlock, "G", c1G, function(v) c1G = v; applyColor1() end, 3)
    setB1 = mkRGBSliderRow(gradientColorBlock, "B", c1B, function(v) c1B = v; applyColor1() end, 4)

    local grad2SwatchSet = mkColorSwatchHeader(gradientColorBlock, "COLOR 2", gradientColor2, 5)
    local c2R, c2G, c2B = gradientColor2.R, gradientColor2.G, gradientColor2.B
    local setR2, setG2, setB2
    local function applyColor2()
        local c = Color3.new(c2R, c2G, c2B)
        gradientColor2 = c
        grad2SwatchSet(c)
    end
    setR2 = mkRGBSliderRow(gradientColorBlock, "R", c2R, function(v) c2R = v; applyColor2() end, 6)
    setG2 = mkRGBSliderRow(gradientColorBlock, "G", c2G, function(v) c2G = v; applyColor2() end, 7)
    setB2 = mkRGBSliderRow(gradientColorBlock, "B", c2B, function(v) c2B = v; applyColor2() end, 8)

    mkDropdown(gradientColorBlock, "Gradient Direction", {"Vertical", "Horizontal", "Depth"}, "Vertical", 9, function(v)
        gradientDirection = v
    end)

    mkPresetGrid(gradientColorBlock, 10, function(preset)
        c1R, c1G, c1B = preset.c1.R, preset.c1.G, preset.c1.B
        c2R, c2G, c2B = preset.c2.R, preset.c2.G, preset.c2.B
        applyColor1()
        applyColor2()
        setR1(c1R, true)
        setG1(c1G, true)
        setB1(c1B, true)
        setR2(c2R, true)
        setG2(c2G, true)
        setB2(c2B, true)
    end)

    local function refreshColorStep()
        staticColorBlock.Visible = (colorMode == "Static")
        gradientColorBlock.Visible = (colorMode == "Gradient")
    end
    refreshColorStepFn = refreshColorStep

    mkSpacer(step4, 8, 7)
    mkButton(step4, "Save", 8, function()
        unlockNext(4)
        goToStep(5)
    end, true)

    local step5 = stepScrolls[5]
    mkDropdown(step5, "Select Block", blockList, selectedBlock, 1, function(v)
        selectedBlock = v
    end)

    mkSpacer(step5, 8, 2)
    local exportStat = mkStat(step5, 4)

    mkButton(step5, "Export", 3, function()
        exportStat.Text = "Converting..."
        exportStat.TextColor3 = Color3.fromRGB(160, 130, 20)
        task.spawn(function()
            if objFileName == "" then
                exportStat.Text = "Error: No file!"
                exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                return
            end

            local ok, content = pcall(readfile, objFileName)
            if not ok then
                exportStat.Text = "Error: Can't read!"
                exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                return
            end

            local outputBase = (objOutputName ~= "" and objOutputName or "output"):gsub("%.Build$", "")

            local function getColor(pos, minPos, maxPos)
                if randomColorEnabled then
                    return randomColor3()
                elseif gradientEnabled then
                    return getGradientColor(pos, minPos, maxPos, gradientDirection)
                elseif customColorEnabled then
                    return customColor
                end
                return nil
            end

            if format == "Wireframe" then
                local scaleUsed = objScale
                local vertices, edges, faces = parseOBJ(content, scaleUsed)
                if #vertices == 0 then
                    exportStat.Text = "Error: No vertices!"
                    exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                    return
                end
                vertices = centerVertices(vertices)
                local minPos, maxPos = getBounds(vertices)
                local allBlocks = {}

                if not extendedWireframe then
                    if #edges == 0 then
                        exportStat.Text = "Error: No edges!"
                        exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                        return
                    end
                    exportStat.Text = "Building " .. #edges .. " edges..."
                    task.wait()
                    for _, edge in ipairs(edges) do
                        local v1 = vertices[edge[1]]
                        local v2 = vertices[edge[2]]
                        if v1 and v2 then
                            local col = getColor((v1 + v2) / 2, minPos, maxPos)
                            local b = makeEdgeBlock(v1, v2, objThickness, col)
                            if b then table.insert(allBlocks, b) end
                        end
                    end
                else
                    if #faces == 0 then
                        exportStat.Text = "No faces, building edges..."
                        task.wait()
                        for _, edge in ipairs(edges) do
                            local v1 = vertices[edge[1]]
                            local v2 = vertices[edge[2]]
                            if v1 and v2 then
                                local col = getColor((v1 + v2) / 2, minPos, maxPos)
                                local b = makeEdgeBlock(v1, v2, objThickness, col)
                                if b then table.insert(allBlocks, b) end
                            end
                        end
                    else
                        local triangles = {}
                        for _, face in ipairs(faces) do
                            if #face >= 3 then
                                for i = 2, #face - 1 do
                                    table.insert(triangles, {face[1], face[i], face[i + 1]})
                                end
                            end
                        end
                        exportStat.Text = "Processing " .. #triangles .. " triangles..."
                        task.wait()
                        for tIdx, tri in ipairs(triangles) do
                            local v1 = vertices[tri[1]]
                            local v2 = vertices[tri[2]]
                            local v3 = vertices[tri[3]]
                            if v1 and v2 and v3 then
                                local e1 = v2 - v1
                                local e2 = v3 - v1
                                local normal = e1:Cross(e2)
                                normal = normal.Magnitude >= 0.0001 and normal.Unit or Vector3.new(0, 1, 0)
                                local col = getColor((v1 + v2 + v3) / 3, minPos, maxPos)
                                for _, ep in ipairs({{v1, v2, v3}, {v2, v3, v1}, {v3, v1, v2}}) do
                                    local ea, eb, opp = ep[1], ep[2], ep[3]
                                    local b = makeEdgeBlockNormal(ea, eb, objThickness, col, normal, opp)
                                    if b then table.insert(allBlocks, b) end
                                end
                            end
                            if tIdx % 300 == 0 then
                                exportStat.Text = "Processing... " .. tIdx .. "/" .. #triangles
                                task.wait()
                            end
                        end
                    end
                end

                if #allBlocks == 0 then
                    exportStat.Text = "Error: No blocks!"
                    exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                    return
                end
                exportStat.Text = "Saving " .. #allBlocks .. " blocks..."
                task.wait()
                local sf, err = splitAndSaveChunks(allBlocks, outputBase)
                if not sf then
                    exportStat.Text = "Error: " .. tostring(err)
                    exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                    return
                end
                exportStat.Text = "Done! " .. #allBlocks .. " -> " .. sf[1]
                exportStat.TextColor3 = Color3.fromRGB(30, 130, 80)
            else
                local vertices, edges, faces = parseOBJ(content, objSolidScale)
                if #vertices == 0 then
                    exportStat.Text = "Error: No vertices!"
                    exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                    return
                end
                if #faces == 0 then
                    exportStat.Text = "Error: No faces!"
                    exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                    return
                end
                vertices = centerVertices(vertices)
                local minPos, maxPos = getBounds(vertices)
                local triangles = {}
                for _, face in ipairs(faces) do
                    if #face >= 3 then
                        for i = 2, #face - 1 do
                            table.insert(triangles, {face[1], face[i], face[i + 1]})
                        end
                    end
                end
                local allBlocks = {}
                local triColors = {}
                exportStat.Text = "Filling " .. #triangles .. " triangles..."
                task.wait()
                for tIdx, tri in ipairs(triangles) do
                    local v1 = vertices[tri[1]]
                    local v2 = vertices[tri[2]]
                    local v3 = vertices[tri[3]]
                    if v1 and v2 and v3 then
                        local col = getColor((v1 + v2 + v3) / 3, minPos, maxPos)
                        triColors[tIdx] = col
                        local blocks = fillTriangle(v1, v2, v3, objStripSize, col)
                        for _, b in ipairs(blocks) do
                            table.insert(allBlocks, b)
                        end
                    end
                    if tIdx % 100 == 0 then
                        exportStat.Text = "Filling..." .. tIdx .. "/" .. #triangles
                        task.wait()
                    end
                end
                exportStat.Text = "Adding wireframe..."
                task.wait()
                for tIdx, tri in ipairs(triangles) do
                    local v1 = vertices[tri[1]]
                    local v2 = vertices[tri[2]]
                    local v3 = vertices[tri[3]]
                    if v1 and v2 and v3 then
                        local e1 = v2 - v1
                        local e2 = v3 - v1
                        local normal = e1:Cross(e2)
                        normal = normal.Magnitude < 0.0001 and Vector3.new(0, 1, 0) or normal.Unit
                        local col = triColors[tIdx]
                        for _, ep in ipairs({{v1, v2, v3}, {v2, v3, v1}, {v3, v1, v2}}) do
                            local ea, eb, opp = ep[1], ep[2], ep[3]
                            local b = makeEdgeBlockNormal(ea, eb, objStripSize, col, normal, opp)
                            if b then table.insert(allBlocks, b) end
                        end
                    end
                end
                if #allBlocks == 0 then
                    exportStat.Text = "Error: No blocks!"
                    exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                    return
                end
                exportStat.Text = "Saving " .. #allBlocks .. " blocks..."
                task.wait()
                local sf, err = splitAndSaveChunks(allBlocks, outputBase)
                if not sf then
                    exportStat.Text = "Error: " .. tostring(err)
                    exportStat.TextColor3 = Color3.fromRGB(200, 60, 60)
                    return
                end
                exportStat.Text = "Done! " .. #allBlocks .. " -> " .. sf[1]
                exportStat.TextColor3 = Color3.fromRGB(30, 130, 80)
            end
        end)
    end, true)

    local ISLAND_H = isMobile and 40 or 46
    local DIAMOND_S = ISLAND_H / math.sqrt(2)
    local BODY_W = isMobile and math.min(170, math.max(120, math.floor(viewportSize.X - 24 - ISLAND_H))) or 200
    local ISLAND_W = BODY_W + ISLAND_H
    local ISLAND_TOP_MARGIN = 14
    local BANNER_COLOR = Color3.fromRGB(248, 249, 251)

    local Island = Instance.new("Frame", SG)
    Island.Size = UDim2.new(0, ISLAND_W, 0, ISLAND_H)
    Island.Position = UDim2.new(0.5, -ISLAND_W / 2, 0, ISLAND_TOP_MARGIN)
    Island.BackgroundTransparency = 1
    Island.Visible = false
    Island.ZIndex = 10

    local islandScale = Instance.new("UIScale", Island)
    islandScale.Scale = 0.7

    local mainBody = Instance.new("Frame", Island)
    mainBody.Size = UDim2.new(0, BODY_W, 1, 0)
    mainBody.Position = UDim2.new(0, ISLAND_H / 2, 0, 0)
    mainBody.BackgroundColor3 = BANNER_COLOR
    mainBody.BorderSizePixel = 0
    mainBody.ZIndex = 10

    local leftDiamond = Instance.new("Frame", Island)
    leftDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
    leftDiamond.Size = UDim2.new(0, DIAMOND_S, 0, DIAMOND_S)
    leftDiamond.Position = UDim2.new(0, ISLAND_H / 2, 0.5, 0)
    leftDiamond.Rotation = 45
    leftDiamond.BackgroundColor3 = BANNER_COLOR
    leftDiamond.BorderSizePixel = 0
    leftDiamond.ZIndex = 9

    local rightDiamond = Instance.new("Frame", Island)
    rightDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
    rightDiamond.Size = UDim2.new(0, DIAMOND_S, 0, DIAMOND_S)
    rightDiamond.Position = UDim2.new(0, ISLAND_H / 2 + BODY_W, 0.5, 0)
    rightDiamond.Rotation = 45
    rightDiamond.BackgroundColor3 = BANNER_COLOR
    rightDiamond.BorderSizePixel = 0
    rightDiamond.ZIndex = 9

    local islandBtn = Instance.new("TextButton", Island)
    islandBtn.Size = UDim2.new(1, 0, 1, 0)
    islandBtn.BackgroundTransparency = 1
    islandBtn.Text = ""
    islandBtn.AutoButtonColor = false
    islandBtn.ZIndex = 11

    local islandTitle = Instance.new("TextLabel", mainBody)
    islandTitle.Size = UDim2.new(1, -8, 0, isMobile and 15 or 17)
    islandTitle.Position = UDim2.new(0, 4, 0, isMobile and 4 or 5)
    islandTitle.BackgroundTransparency = 1
    islandTitle.Text = "MAESTRO | Converter++"
    islandTitle.TextColor3 = Color3.fromRGB(15, 15, 20)
    islandTitle.TextSize = isMobile and 10 or 11
    islandTitle.Font = Enum.Font.GothamBold
    islandTitle.TextXAlignment = Enum.TextXAlignment.Center
    islandTitle.TextTruncate = Enum.TextTruncate.AtEnd
    islandTitle.ZIndex = 12

    local islandStats = Instance.new("TextLabel", mainBody)
    islandStats.Size = UDim2.new(1, -8, 0, isMobile and 13 or 15)
    islandStats.Position = UDim2.new(0, 4, 1, -(isMobile and 17 or 19))
    islandStats.BackgroundTransparency = 1
    islandStats.Text = "FPS: --  |  Ping: --ms"
    islandStats.TextColor3 = Color3.fromRGB(40, 40, 45)
    islandStats.TextSize = isMobile and 9 or 10
    islandStats.Font = Enum.Font.Gotham
    islandStats.TextXAlignment = Enum.TextXAlignment.Center
    islandStats.ZIndex = 12

    local currentFps = 0
    local fpsLastTime = os.clock()
    game:GetService("RunService").RenderStepped:Connect(function()
        local now = os.clock()
        local dt = now - fpsLastTime
        fpsLastTime = now
        if dt > 0 then
            currentFps = math.floor((1 / dt) + 0.5)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(0.5)
            if Island.Visible then
                local ping = 0
                pcall(function()
                    ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
                islandStats.Text = "FPS: " .. currentFps .. "  |  Ping: " .. ping .. "ms"
            end
        end
    end)

    local collapsed = false

    local function showIsland()
        Island.Visible = true
        islandScale.Scale = 0.01
        task.wait()
        task.wait()
        islandScale.Scale = 0.7
        TweenService:Create(islandScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end

    local function hideIsland(onDone)
        local tw = TweenService:Create(islandScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.7})
        tw:Play()
        task.delay(0.2, function()
            Island.Visible = false
            if onDone then onDone() end
        end)
    end

    CollapseBtn.MouseButton1Click:Connect(function()
        collapsed = true
        MainBorder.Visible = false
        showIsland()
    end)

    islandBtn.MouseButton1Click:Connect(function()
        if not collapsed then return end
        collapsed = false
        hideIsland(function()
            MainBorder.Visible = true
        end)
    end)

    refreshScaleStep()
    refreshColorStep()
    goToStep(1)

    Island.Visible = true
    task.wait()
    task.wait()
    Island.Visible = false

    task.wait()
    SG.Enabled = true
end

pcall(buildGUI)
