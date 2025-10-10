-- WindUI + Utils Farm + Egg Placement (Pet/Fish) — Debug/Diagnostics Build (No-TP)

-- 1) Load WindUI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- 2) ===== Core services / players ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local LocalPlayerUserId = LocalPlayer and LocalPlayer.UserId or 0

-- Debug flag
local DEBUG = false
local function dprint(...)
    if DEBUG then print("[UtilsFarm]", ...) end
end

-- 3) ===== Island / tile utilities ==========================================
local function BRVS_GetMyIsland()
    local art = workspace:FindFirstChild("Art")
    if not art then return nil end
    for i = 1, 12 do
        local island = art:FindFirstChild("Island_" .. i)
        if island and island:GetAttribute("OccupyingPlayerId") == LocalPlayerUserId then
            return island, i
        end
    end
    return nil
end

local function BRVS_GetRootCF(root)
    if not root then return CFrame.new() end
    if root:IsA("Model") then
        local ok, cf = pcall(function() return root:GetPivot() end)
        return ok and cf or CFrame.new()
    elseif root:IsA("BasePart") then
        return root.CFrame
    else
        local p = root:FindFirstChildWhichIsA("BasePart", true)
        return p and p.CFrame or CFrame.new()
    end
end

local function BRVS_GetInstCF(inst)
    if not inst then return nil end
    if inst:IsA("Model") then
        local ok, cf = pcall(function() return inst:GetPivot() end)
        return ok and cf or nil
    elseif inst:IsA("BasePart") then
        return inst.CFrame
    else
        local p = inst:FindFirstChildWhichIsA("BasePart", true)
        return p and p.CFrame or nil
    end
end

local function BRVS_CollectSortedTilesForMe(pattern)
    local root = BRVS_GetMyIsland()
    if not root then
        warn("[BRVS] You don't have a claimed island right now.")
        return {}
    end
    local rootCF = BRVS_GetRootCF(root)
    local ROW_TOL = 0.25
    local tiles = {}
    for _, ch in ipairs(root:GetChildren()) do
        if ch.Name:match(pattern) then
            local cf = BRVS_GetInstCF(ch)
            if cf then
                local lp = rootCF:PointToObjectSpace(cf.Position)
                tiles[#tiles+1] = { inst = ch, wp = cf.Position, lp = lp }
            end
        end
    end
    table.sort(tiles, function(a,b)
        if math.abs(a.lp.Z - b.lp.Z) > ROW_TOL then return a.lp.Z < b.lp.Z end
        if a.lp.X ~= b.lp.X then return a.lp.X < b.lp.X end
        if a.lp.Y ~= b.lp.Y then return a.lp.Y < b.lp.Y end
        return a.inst.Name < b.inst.Name
    end)
    return tiles
end

local function BRVS_GetFarmTilesForMe()
    return BRVS_CollectSortedTilesForMe("^Farm_split_(%d+)_(%d+)_(%d+)$")
end
local function BRVS_GetWaterFarmTilesForMe()
    return BRVS_CollectSortedTilesForMe("^WaterFarm_split_(%d+)_(%d+)_(%d+)$")
end

-- 4) ===== State / helpers ====================================================
local GRID = "Farm"
local FARM_TILES, WATERFARM_TILES = {}, {}
local currentIndex = 0
local running = false
local stepDelay = 0.25

local function refreshTiles()
    FARM_TILES = BRVS_GetFarmTilesForMe()
    WATERFARM_TILES = BRVS_GetWaterFarmTilesForMe()
    dprint("Tiles refreshed. Farm:", #FARM_TILES, "WaterFarm:", #WATERFARM_TILES)
end

local function getActiveTiles()
    return (GRID == "Farm") and FARM_TILES or WATERFARM_TILES
end

local function getIslandIndex()
    local _, idx = BRVS_GetMyIsland()
    return idx
end

-- manual farming helper (not used by auto-place)
local function tpTo(pos, yOffset)
    yOffset = yOffset or 4
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOffset, 0))
    end
end

local function interactWith(tile)
    local prompt = tile.inst:FindFirstChildOfClass("ProximityPrompt") or tile.inst:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and fireproximityprompt then
        local old = prompt.HoldDuration
        prompt.HoldDuration = 0
        pcall(fireproximityprompt, prompt)
        prompt.HoldDuration = old
        return
    end
    if tile.wp then tpTo(tile.wp) end
end

-- 5) ===== WindUI window & base panels =======================================
WindUI:SetTheme("Dark")
WindUI.TransparencyValue = 0.15

local Window = WindUI:CreateWindow({
    Title = "Utils Farm",
    Icon = "sprout",
    Author = "Your Island Helper",
    Folder = "UtilsFarm_WindUI",
    Size = UDim2.fromOffset(560, 350),
    Theme = "Dark",
    HidePanelBackground = false,
    NewElements = false,
})

Window:CreateTopbarButton("theme", "moon", function()
    WindUI:SetTheme(WindUI:GetCurrentTheme() == "Dark" and "Light" or "Dark")
    WindUI:Notify({ Title = "Theme", Content = "Current: " .. WindUI:GetCurrentTheme(), Duration = 2 })
end, 999)
local GiftSection = Window:Section({ Title = "Gifting", Opened = true })
local Sections = {
    Main = Window:Section({ Title = "Farming", Opened = true }),
    Eggs = Window:Section({ Title = "Eggs", Opened = true }),
    Diag = Window:Section({ Title = "Diagnostics", Opened = true }),
    Settings = Window:Section({ Title = "Settings", Opened = true }),
}

local Tabs = {
    Farm = Sections.Main:Tab({ Title = "Controls", Icon = "tractor" }),
    Info = Sections.Main:Tab({ Title = "Info", Icon = "info" }),
    Pet  = Sections.Eggs:Tab({ Title = "Pet Egg Placement", Icon = "egg" }),
    Fish = Sections.Eggs:Tab({ Title = "Fish Egg Placement", Icon = "fish" }),
    Diag = Sections.Diag:Tab({ Title = "Tools", Icon = "wrench" }),
    App  = Sections.Settings:Tab({ Title = "Appearance", Icon = "brush" }),
}

-- Info paragraphs
local islandPara = Tabs.Info:Paragraph({ Title = "Island", Desc = "Detecting...", Image = "map", ImageSize = 18, Color = "White" })
local countPara  = Tabs.Info:Paragraph({ Title = "Tile Counts", Desc = "Farm: 0 | WaterFarm: 0", Image = "boxes", ImageSize = 18, Color = "White" })
local statusPara = Tabs.Info:Paragraph({ Title = "Status", Desc = "Idle", Image = "activity", ImageSize = 18, Color = "White" })

local function setStatus(text)
    if statusPara.SetDesc then statusPara:SetDesc(text) elseif statusPara.Set then statusPara:Set(text) end
    dprint("STATUS:", text)
end

local function redrawInfo()
    local idx = getIslandIndex()
    local islandText = idx and ("You are on Island_" .. tostring(idx)) or "No island claimed."
    if islandPara.SetDesc then islandPara:SetDesc(islandText) elseif islandPara.Set then islandPara:Set(islandText) end
    local countsText = ("Farm: %d | WaterFarm: %d"):format(#FARM_TILES, #WATERFARM_TILES)
    if countPara.SetDesc then countPara:SetDesc(countsText) elseif countPara.Set then countPara:Set(countsText) end
end

-- Manual farming controls
Tabs.Farm:Dropdown({
    Title = "Grid",
    Values = { "Farm", "WaterFarm" },
    Value = GRID,
    Callback = function(v)
        GRID = v
        currentIndex = 0
        WindUI:Notify({ Title = "Grid", Content = "Active: " .. GRID, Duration = 2 })
    end
})

Tabs.Farm:Slider({
    Title = "Step Delay (s)",
    Value = { Min = 0, Max = 2, Default = stepDelay },
    Step = 0.05,
    Callback = function(v) stepDelay = tonumber(v) or 0.25 end
})

Tabs.Farm:Button({
    Title = "Refresh Tiles",
    Icon = "refresh-cw",
    Variant = "Primary",
    Callback = function()
        refreshTiles()
        redrawInfo()
        WindUI:Notify({ Title = "Refreshed", Content = "Tiles rescanned.", Duration = 2 })
    end
})

local autoToggle = Tabs.Farm:Toggle({
    Title = "Auto Farm (manual interaction)",
    Value = false,
    Callback = function(on)
        running = on
        if running then
            setStatus("Running…")
            task.spawn(function()
                while running do
                    local tiles = getActiveTiles()
                    if #tiles == 0 then
                        setStatus("No tiles found (" .. GRID .. ").")
                        task.wait(1)
                    else
                        currentIndex = (currentIndex % #tiles) + 1
                        local tile = tiles[currentIndex]
                        if tile and tile.wp then
                            tpTo(tile.wp)
                            interactWith(tile)
                            setStatus(("Working %s [%d/%d]"):format(tile.inst.Name, currentIndex, #tiles))
                        end
                        task.wait(stepDelay)
                    end
                end
                setStatus("Idle")
            end)
        else
            setStatus("Idle")
        end
    end
})

-- Appearance
local themes = {}
if WindUI.GetThemes then
    for themeName,_ in pairs(WindUI:GetThemes()) do table.insert(themes, themeName) end
else
    themes = { "Dark", "Light" }
end
table.sort(themes)
Tabs.App:Dropdown({
    Title = "Theme",
    Values = themes,
    Value = WindUI.GetCurrentTheme and WindUI:GetCurrentTheme() or themes[1],
    Callback = function(theme) if WindUI.SetTheme then WindUI:SetTheme(theme) end end
})
Tabs.App:Slider({
    Title = "Window Transparency",
    Value = { Min = 0, Max = 1, Default = WindUI.TransparencyValue or 0 },
    Step = 0.05,
    Callback = function(v)
        WindUI.TransparencyValue = tonumber(v) or 0
        if Window.ToggleTransparency then Window:ToggleTransparency((tonumber(v) or 0) > 0) end
    end
})

-- 6) ===== Auto-place helpers ================================================
-- Remote + helpers
local CharacterRE -- cached reference after validation
local function CharacterRE_Fire(...)
    if not CharacterRE then
        CharacterRE = ReplicatedStorage:FindFirstChild("Remote")
            and ReplicatedStorage.Remote:FindFirstChild("CharacterRE")
        if not CharacterRE then
            warn("[UtilsFarm] CharacterRE not found under ReplicatedStorage.Remote")
            return
        end
    end
    CharacterRE:FireServer(...)
end

-- Eggs scanning
local function ScanEggOptions()
    local namesSet, mutsSet = {}, {}
    local eggsFolder = LocalPlayer:FindFirstChild("PlayerGui")
        and LocalPlayer.PlayerGui:FindFirstChild("Data")
        and LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    if eggsFolder then
        for _, egg in ipairs(eggsFolder:GetChildren()) do
            local T = egg:GetAttribute("T")
            local M = egg:GetAttribute("M")
            if T then namesSet[T] = true end
            if M then mutsSet[tostring(M)] = true end
        end
    end
    local names, muts = {}, { "None" }
    for k in pairs(namesSet) do table.insert(names, k) end
    for k in pairs(mutsSet) do table.insert(muts, k) end
    table.sort(names)
    table.sort(muts, function(a,b) if a=="None" then return true elseif b=="None" then return false else return a < b end end)
    return names, muts
end

local function FindEggUID(eggName, eggMutation)
    local eggsFolder = LocalPlayer:FindFirstChild("PlayerGui")
        and LocalPlayer.PlayerGui:FindFirstChild("Data")
        and LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    if not eggsFolder then dprint("Eggs folder missing"); return nil end
    local withM, noM = {}, {}
    for _, egg in ipairs(eggsFolder:GetChildren()) do
        if not egg:GetAttribute("D") and not egg:GetAttribute("BPV") then
            local T = egg:GetAttribute("T")
            if (not eggName or eggName == "" or eggName == "Any" or T == eggName) then
                local M = egg:GetAttribute("M")
                if M then
                    if eggMutation and eggMutation ~= "None" and tostring(M) == tostring(eggMutation) then
                        table.insert(withM, egg)
                    elseif not eggMutation or eggMutation == "Any" then
                        table.insert(withM, egg)
                    end
                else
                    table.insert(noM, egg)
                end
            end
        end
    end
    local chosen
    if eggMutation and eggMutation ~= "None" then
        chosen = withM[1] or noM[1]
    else
        chosen = noM[1] or withM[1]
    end
    if chosen then dprint("Chosen egg UID:", chosen.Name) end
    return chosen and chosen.Name or nil
end

-- Focus / Place / Unfocus
local function FocusEgg(uid) dprint("Focus", uid) CharacterRE_Fire("Focus", uid) end

-- DST format setting for servers that don’t like vector.create
local DST_FORMAT = "Vector3.new" -- "vector.create" | "Vector3.new" | "TableXYZ"
local function BuildDSTVector(pos)
    if DST_FORMAT == "Vector3.new" then
        return Vector3.new(pos.X, pos.Y+4, pos.Z)
    elseif DST_FORMAT == "TableXYZ" then
        return { X = pos.X, Y = pos.Y+4, Z = pos.Z }
    else
        -- default vector.create (if available, else fallback to Vector3)
        if vector and vector.create then return vector.create(pos.X, pos.Y+4, pos.Z) end
        return Vector3.new(pos.X, pos.Y+4, pos.Z)
    end
end

local function PlaceEgg(uid, worldPos)
    local dst = BuildDSTVector(worldPos)
    dprint("Place", uid, worldPos, "DST format:", DST_FORMAT)
    CharacterRE_Fire("Place", { DST = dst, ID = uid })
end

local function Unfocus() dprint("Unfocus") CharacterRE_Fire("Focus") end

-- Next placement position
local function NextPlacementPosition(gridName)
    local tiles = (gridName == "WaterFarm") and WATERFARM_TILES or FARM_TILES
    if #tiles == 0 then return nil end
    local key = gridName .. "_egg_idx"
    _G[key] = ((_G[key] or 0) % #tiles) + 1
    local t = tiles[_G[key]]
    return t and t.wp or nil, _G[key], #tiles
end

-- Auto loop
local runningEggFarm = { Farm = false, WaterFarm = false }
local eggDelay = 0.35

local function AutoPlaceEggs(gridName, getEggNameFn, getMutationFn)
    if runningEggFarm[gridName] then return end
    runningEggFarm[gridName] = true
    dprint("AutoPlaceEggs started for", gridName)

    task.spawn(function()
        local cycle = 0
        while runningEggFarm[gridName] do
            cycle = cycle + 1
            if cycle % 20 == 0 then refreshTiles() end -- rescan tiles periodically

            local pos, idx, total = NextPlacementPosition(gridName)
            if not pos then
                setStatus("No tiles found for " .. gridName)
                task.wait(1)
                continue()
            end

            local nameWanted = getEggNameFn()
            local mutationWanted = getMutationFn()
            dprint("Looking for egg:", nameWanted, "mutation:", mutationWanted)
            local uid = FindEggUID(nameWanted, mutationWanted)

            if not uid then
                WindUI:Notify({
                    Title = "No Egg",
                    Content = ("No eligible egg found (Name=%s, M=%s)"):format(tostring(nameWanted), tostring(mutationWanted)),
                    Duration = 2, Icon = "x"
                })
                task.wait(1)
                continue()
            end

            -- Focus -> Place -> Unfocus (no teleport)
            pcall(FocusEgg, uid)
            pcall(PlaceEgg, uid, pos)
            pcall(Unfocus)

            setStatus(("Placed egg %s at %s [%d/%d]"):format(uid, gridName, idx or 0, total or 0))
            task.wait(eggDelay)
        end
        setStatus("Idle")
        dprint("AutoPlaceEggs stopped for", gridName)
    end)
end

-- 7) ===== Pet/Fish UI =======================================================
local function _getOptions()
    local eggNames, eggMutations = ScanEggOptions()
    if #eggNames == 0 then eggNames = { "Any" } end
    if #eggMutations == 0 then eggMutations = { "None" } end
    return eggNames, eggMutations
end

-- PET
do
    local names, muts = _getOptions()
    local petEggName, petEggMutation = names[1], muts[1]

    local petNameDD = Tabs.Pet:Dropdown({
        Title = "eggName (T)",
        Values = names,
        Value  = names[1],
        Callback = function(v) petEggName = v; dprint("petEggName:", v) end
    })
    local petMutDD = Tabs.Pet:Dropdown({
        Title = "eggMutation (M)",
        Values = muts,
        Value  = muts[1],
        Callback = function(v) petEggMutation = v; dprint("petEggMutation:", v) end
    })

    Tabs.Pet:Button({
        Title = "Refresh Egg Options",
        Icon = "refresh-cw",
        Callback = function()
            local n, m = _getOptions()
            if petNameDD.Refresh then petNameDD:Refresh(n) end
            if petMutDD.Refresh then petMutDD:Refresh(m) end
            petEggName, petEggMutation = n[1], m[1]
            if petNameDD.Select then petNameDD:Select(n[1]) end
            if petMutDD.Select then petMutDD:Select(m[1]) end
            WindUI:Notify({ Title = "Pet Eggs", Content = "Options refreshed.", Duration = 2 })
        end
    })

    local petDelay = 0.35
    Tabs.Pet:Slider({
        Title = "Place Delay (s)",
        Value = { Min = 0, Max = 2, Default = petDelay },
        Step = 0.05,
        Callback = function(v) petDelay = tonumber(v) or 0.35 end
    })

    local petToggle = Tabs.Pet:Toggle({
        Title = "Auto Place Pet Eggs (Farm)",
        Value = false,
        Callback = function(on)
            if on then
                refreshTiles()
                local oldDelay = eggDelay ; eggDelay = petDelay
                -- DO NOT set runningEggFarm.Farm here – let AutoPlaceEggs do it
                AutoPlaceEggs("Farm",
                    function() return petEggName end,
                    function() return petEggMutation end
                )
                task.spawn(function()
                    while runningEggFarm.Farm do task.wait(0.1) end
                    eggDelay = oldDelay
                end)
            else
                -- turn off the loop
                runningEggFarm.Farm = false
            end
        end
    })

    Tabs.Pet:Button({
        Title = "One-shot Place (Pet/Farm)",
        Icon = "mouse-pointer",
        Callback = function()
            refreshTiles()
            local pos = NextPlacementPosition("Farm")
            if not pos then WindUI:Notify({ Title="No Tiles", Content="No Farm tiles.", Duration=2, Icon="x" }); return end
            local uid = FindEggUID(petEggName, petEggMutation)
            if not uid then WindUI:Notify({ Title="No Egg", Content="No eligible pet egg.", Duration=2, Icon="x" }); return end
            FocusEgg(uid); PlaceEgg(uid, pos); Unfocus()
            WindUI:Notify({ Title="Placed", Content=("Pet egg %s placed."):format(uid), Duration=2 })
        end
    })

    Tabs.Pet:Button({
        Title = "Stop Pet Placement",
        Icon = "square",
        Variant = "Tertiary",
        Callback = function()
            if petToggle.Set then petToggle:Set(false) else runningEggFarm.Farm = false end
        end
    })
end

-- FISH
do
    local names, muts = _getOptions()
    local fishEggName, fishEggMutation = names[1], muts[1]

    local fishNameDD = Tabs.Fish:Dropdown({
        Title = "eggName (T)",
        Values = names,
        Value  = names[1],
        Callback = function(v) fishEggName = v; dprint("fishEggName:", v) end
    })
    local fishMutDD = Tabs.Fish:Dropdown({
        Title = "eggMutation (M)",
        Values = muts,
        Value  = muts[1],
        Callback = function(v) fishEggMutation = v; dprint("fishEggMutation:", v) end
    })

    Tabs.Fish:Button({
        Title = "Refresh Egg Options",
        Icon = "refresh-cw",
        Callback = function()
            local n, m = _getOptions()
            if fishNameDD.Refresh then fishNameDD:Refresh(n) end
            if fishMutDD.Refresh then fishMutDD:Refresh(m) end
            fishEggName, fishEggMutation = n[1], m[1]
            if fishNameDD.Select then fishNameDD:Select(n[1]) end
            if fishMutDD.Select then fishMutDD:Select(m[1]) end
            WindUI:Notify({ Title = "Fish Eggs", Content = "Options refreshed.", Duration = 2 })
        end
    })

    local fishDelay = 0.35
    Tabs.Fish:Slider({
        Title = "Place Delay (s)",
        Value = { Min = 0, Max = 2, Default = fishDelay },
        Step = 0.05,
        Callback = function(v) fishDelay = tonumber(v) or 0.35 end
    })

    local fishToggle = Tabs.Fish:Toggle({
        Title = "Auto Place Fish Eggs (WaterFarm)",
        Value = false,
        Callback = function(on)
            if on then
                refreshTiles()
                local oldDelay = eggDelay ; eggDelay = fishDelay
                -- DO NOT set runningEggFarm.WaterFarm here – let AutoPlaceEggs do it
                AutoPlaceEggs("WaterFarm",
                    function() return fishEggName end,
                    function() return fishEggMutation end
                )
                task.spawn(function()
                    while runningEggFarm.WaterFarm do task.wait(0.1) end
                    eggDelay = oldDelay
                end)
            else
                -- turn off the loop
                runningEggFarm.WaterFarm = false
            end
        end
    })

    Tabs.Fish:Button({
        Title = "One-shot Place (Fish/WaterFarm)",
        Icon = "mouse-pointer",
        Callback = function()
            refreshTiles()
            local pos = NextPlacementPosition("WaterFarm")
            if not pos then WindUI:Notify({ Title="No Tiles", Content="No WaterFarm tiles.", Duration=2, Icon="x" }); return end
            local uid = FindEggUID(fishEggName, fishEggMutation)
            if not uid then WindUI:Notify({ Title="No Egg", Content="No eligible fish egg.", Duration=2, Icon="x" }); return end
            FocusEgg(uid); PlaceEgg(uid, pos); Unfocus()
            WindUI:Notify({ Title="Placed", Content=("Fish egg %s placed."):format(uid), Duration=2 })
        end
    })

    Tabs.Fish:Button({
        Title = "Stop Fish Placement",
        Icon = "square",
        Variant = "Tertiary",
        Callback = function()
            if fishToggle.Set then fishToggle:Set(false) else runningEggFarm.WaterFarm = false end
        end
    })
end

-- 8) ===== Diagnostics ========================================================
local DSTDD = Tabs.Diag:Dropdown({
    Title = "DST Format",
    Values = { "vector.create", "Vector3.new", "TableXYZ" },
    Value  = "vector.create",
    Callback = function(v) DST_FORMAT = v; WindUI:Notify({ Title="DST", Content="Now using "..v, Duration=2 }) end
})

Tabs.Diag:Toggle({
    Title = "Debug Logs",
    Value = false,
    Callback = function(on)
        DEBUG = on
        WindUI:Notify({ Title = "Debug", Content = on and "ON" or "OFF", Duration = 2 })
    end
})

Tabs.Diag:Button({
    Title = "Validate Remote (CharacterRE)",
    Icon = "search",
    Callback = function()
        local r = ReplicatedStorage:FindFirstChild("Remote")
        if not r then warn("[Diag] ReplicatedStorage.Remote missing"); return end
        local kids = r:GetChildren()
        print("[Diag] Remote children:", #kids)
        for _,k in ipairs(kids) do print(" -", k.Name) end
        CharacterRE = r:FindFirstChild("CharacterRE")
        if CharacterRE then
            WindUI:Notify({ Title="Remote", Content="CharacterRE found.", Duration=2 })
        else
            warn("[Diag] CharacterRE not found under ReplicatedStorage.Remote")
            WindUI:Notify({ Title="Remote", Content="CharacterRE NOT found.", Duration=3, Icon="x" })
        end
    end
})

Tabs.Diag:Button({
    Title = "Print Eggs Summary",
    Icon = "list",
    Callback = function()
        local eggsFolder = LocalPlayer:FindFirstChild("PlayerGui")
            and LocalPlayer.PlayerGui:FindFirstChild("Data")
            and LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
        if not eggsFolder then print("[Diag] No PlayerGui.Data.Egg folder"); return end
        print("[Diag] Eggs:")
        for _, egg in ipairs(eggsFolder:GetChildren()) do
            local attrs = egg:GetAttributes()
            local ok = (not egg:GetAttribute("D")) and (not egg:GetAttribute("BPV"))
            print(" -", egg.Name, attrs, "eligible:", ok)
        end
    end
})

Tabs.Diag:Button({
    Title = "Print First Tiles (Farm/WaterFarm)",
    Icon = "grid",
    Callback = function()
        refreshTiles()
        local function pfx(label, tiles)
            print(("[Diag] %s tiles: %d"):format(label, #tiles))
            for i=1, math.min(5, #tiles) do
                local t = tiles[i]
                print(("  [%d] %s  wp=(%.2f, %.2f, %.2f)"):format(i, t.inst.Name, t.wp.X, t.wp.Y, t.wp.Z))
            end
        end
        pfx("Farm", FARM_TILES)
        pfx("WaterFarm", WATERFARM_TILES)
    end
})

-- =========================
-- 10) ===== Auto Gift =========================================
-- UI + gifting workflow for Pet/Egg/Food items (+ mutation + teleport)
-- =============================================================

-- Shortcuts already defined in your file:
-- local Players, ReplicatedStorage, LocalPlayer = ...
-- CharacterRE_Fire() helper exists (caches Remote/CharacterRE)
-- Unfocus() helper exists

-- Cache GiftRE
local GiftRE do
    local r = ReplicatedStorage:FindFirstChild("Remote")
    GiftRE = r and r:FindFirstChild("GiftRE") or nil
end

-- ---------- Small utils ----------
local function _getAttrInt(inst, keys)
    for _,k in ipairs(keys) do
        local v = inst:GetAttribute(k)
        if typeof(v) == "number" then return v end
    end
    return nil
end

local function _ensureTarget(name)
    if not name then return nil end
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

local function _getHRPFromChar(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function _teleportBehind(targetPlayer, distance)
    distance = 3
    local myHRP = _getHRPFromChar(LocalPlayer.Character)
    local tgtHRP = targetPlayer and _getHRPFromChar(targetPlayer.Character)
    if not (myHRP and tgtHRP) then return false, "No HRP" end
    -- Behind = target's CFrame * +Z
    local destCF = tgtHRP.CFrame * CFrame.new(0, 3, distance)
    local ok, err = pcall(function()
        myHRP.AssemblyLinearVelocity = Vector3.zero
        myHRP.CFrame = CFrame.new(destCF.Position, (tgtHRP.CFrame * CFrame.new(0,0,-5)).Position)
    end)
    if not ok then return false, err end
    task.wait(0.05)
    return true
end

-- ---------- Player scanner ----------
local function ScanPlayers()
    local opts, map = {}, {}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(opts, plr.Name)
            map[plr.Name] = plr
        end
    end
    table.sort(opts)
    return opts, map
end

-- ---------- Focus / Gift helpers ----------
local function FocusUID(uid)
    if not uid then return false, "No UID" end
    pcall(function() CharacterRE_Fire("Focus", uid) end)
    return true
end

local function SendGiftTo(targetPlayer)
    if not GiftRE then
        local r = ReplicatedStorage:FindFirstChild("Remote")
        GiftRE = r and r:FindFirstChild("GiftRE") or nil
    end
    if not GiftRE then return false, "GiftRE missing" end
    local ok, err = pcall(function()
        GiftRE:FireServer(targetPlayer)
    end)
    return ok, err
end

local function _giftOnce_UID(uid, targetPlr)
    -- Focus -> Gift -> Unfocus (your example)
    FocusUID(uid)
    task.wait(0.25)
    local ok, err = SendGiftTo(targetPlr)
    task.wait(0.25)
    Unfocus()
    return ok, err
end

-- ---------- Inventory scanners ----------
-- NOTE: Your original "pets" are stored under PlayerGui.Data.Egg (UID children).
-- We’ll keep that as "Pet", and add an "Egg" category that reads the same folder too
-- (some games label them separately; keeping them separate gives you UI flexibility).
local function _scanGiftableFromFolder(folder)
    local tbl = {}
    if not folder then return tbl end

    local byType = {}
    for _, inst in ipairs(folder:GetChildren()) do
        -- Exclude anything with D or BPV
        if not inst:GetAttribute("D") and not inst:GetAttribute("BPV") then
            local T = tostring(inst:GetAttribute("T") or "Unknown")
            local M = inst:GetAttribute("M")
            local display = M and (T .. " (M:" .. tostring(M) .. ")") or T
            if not byType[T] then byType[T] = { list = {}, count = 0, label = T, mutations = {} } end
            table.insert(byType[T].list, { uid = inst.Name, T = T, M = M, display = display })
            byType[T].count = byType[T].count + 1
            if M ~= nil then
                byType[T].mutations[M] = (byType[T].mutations[M] or 0) + 1
            end
        end
    end

    for t,pack in pairs(byType) do
        table.sort(pack.list, function(a,b) return a.uid < b.uid end)
        table.insert(tbl, {
            label = ("%s  x%d"):format(pack.label, pack.count),
            key = t,
            uids = pack.list,
            count = pack.count,
            mutations = pack.mutations
        })
    end
    table.sort(tbl, function(a,b) return a.key < b.key end)
    return tbl
end

-- PETS (your setup uses the Egg folder to hold giftable pet UIDs)
local function ScanGiftablePets()
    local eggsFolder = LocalPlayer:FindFirstChild("PlayerGui")
        and LocalPlayer.PlayerGui:FindFirstChild("Data")
        and LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
    return _scanGiftableFromFolder(eggsFolder)
end

-- EGGS (separate listing; same folder/source, but shown as its own category)
local function ScanGiftableEggs()
    local eggsFolder = LocalPlayer:FindFirstChild("PlayerGui")
        and LocalPlayer.PlayerGui:FindFirstChild("Data")
        and LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    return _scanGiftableFromFolder(eggsFolder)
end

-- FOODS: from PlayerGui.Data.Asset
local function ScanGiftableFoods()
    local tbl = {}
    local assetFolder = LocalPlayer:FindFirstChild("PlayerGui")
        and LocalPlayer.PlayerGui:FindFirstChild("Data")
        and LocalPlayer.PlayerGui.Data:FindFirstChild("Asset")

    if not assetFolder then return tbl end

    for _, it in ipairs(assetFolder:GetChildren()) do
        local qty = _getAttrInt(it, { "Count", "Cnt", "Qty", "A", "Amount", "Q" }) or 0
        if qty > 0 then
            table.insert(tbl, { key = it.Name, label = ("%s  x%d"):format(it.Name, qty), count = qty })
        end
    end
    table.sort(tbl, function(a,b) return a.key < b.key end)
    return tbl
end

-- Get next UID for selected type with optional mutation filter (removes from list)
local function PopNextUID(packs, key, wantedMutation) -- wantedMutation: nil = any
    for _,pack in ipairs(packs) do
        if pack.key == key and pack.count > 0 and #pack.uids > 0 then
            -- find first UID that matches mutation (if specified)
            for i,ud in ipairs(pack.uids) do
                if wantedMutation == nil or ud.M == wantedMutation then
                    table.remove(pack.uids, i)
                    pack.count = pack.count - 1
                    return ud.uid
                end
            end
            return nil -- none match mutation
        end
    end
    return nil
end

-- For foods, fetch remaining qty live
local function _remainingForFoodKey(key)
    local assetFolder = LocalPlayer:FindFirstChild("PlayerGui")
        and LocalPlayer.PlayerGui:FindFirstChild("Data")
        and LocalPlayer.PlayerGui.Data:FindFirstChild("Asset")
    if not assetFolder then return 0 end
    local inst = assetFolder:FindFirstChild(key)
    if not inst then return 0 end
    return _getAttrInt(inst, { "Count", "Cnt", "Qty", "A", "Amount", "Q" }) or 0
end

-- Some games accept item key as focus; we try to resolve a UID-like instance first
local function _resolveFoodUIDForKey(key)
    local assetFolder = LocalPlayer:FindFirstChild("PlayerGui")
        and LocalPlayer.PlayerGui:FindFirstChild("Data")
        and LocalPlayer.PlayerGui.Data:FindFirstChild("Asset")
    if not assetFolder then return nil end
    local inst = assetFolder:FindFirstChild(key)
    return inst and inst.Name or nil
end

-- ---------- WindUI: Gift UI ----------

local GiftTab = GiftSection:Tab({ Title = "Auto Gift", Icon = "gift" })

-- Reactive state
local playerOpts, playerMap = ScanPlayers()
local petOptions = ScanGiftablePets()   -- array of {key,label,count,uids={...}, mutations={M:count}}
local eggOptions = ScanGiftableEggs()   -- same structure (separate category)
local foodOptions = ScanGiftableFoods() -- array of {key,label,count}
local selectedPlayer = playerOpts[1]

local itemMode = "Pet"  -- "Pet" | "Egg" | "Food"
local selectedPetKey  = petOptions[1] and petOptions[1].key or nil
local selectedEggKey  = eggOptions[1] and eggOptions[1].key or nil
local selectedFoodKey = foodOptions[1] and foodOptions[1].key or nil

local selectedMutation = "Any" -- "Any" or numeric/string M
local qtyToSend = 1
local sending = false

-- Teleport settings
local tpDistance = 3

--// Clear Hand Button (using FindFirstChild)
local xPlayers = game:GetService("Players")
local xplayer = xPlayers.LocalPlayer

local xgui = xplayer:FindFirstChild("PlayerGui")
local xdata = xgui and xgui:FindFirstChild("Data")
local xdeploy = xdata and xdata:FindFirstChild("Deploy")

local rs = game:GetService("ReplicatedStorage")
local remote = rs:FindFirstChild("Remote")
local deployRE = remote and remote:FindFirstChild("DeployRE")

local asuw = GiftTab:Button({
    Title = "Clear Hand",
    Callback = function()
        if not (xdeploy and deployRE) then
            warn("[GiftUI] Deploy or DeployRE not found — cannot clear hand.")
            return
        end

        local fired = 0
        for i = 3, 8 do
            local attrName = "S" .. i
            local val = xdeploy:GetAttribute(attrName)

            if typeof(val) == "string" and #val > 0 then
                local parts = string.split(val, "_")
                local uid = parts[2] -- use index[1] as UID

                if uid and #uid > 0 then
                    local args = {{
                        event = "deploy",
                        uid = uid
                    }}
                    deployRE:FireServer(unpack(args))
                    fired = fired + 1
                end
            end
        end

        print(("[GiftUI] Clear Hand: fired deploy for %d slot(s) (S3–S8)."):format(fired))
    end
})



-- UI controls
local playerDD = GiftTab:Dropdown({
    Title = "Player",
    Values = (#playerOpts > 0) and playerOpts or { "No players…" },
    Value = selectedPlayer,
    Callback = function(v) selectedPlayer = v end
})

local modeDD = GiftTab:Dropdown({
    Title = "Item Type",
    Values = { "Pet", "Egg", "Food" },
    Value = itemMode,
    Callback = function(v)
        itemMode = v
        -- Reset mutation on switch
        selectedMutation = "Any"
    end
})

-- Show mutation dropdown only for Pet/Egg
local mutationDD = GiftTab:Dropdown({
    Title = "Mutation",
    Values = { "Any" }, -- will refresh per key selection
    Value = "Any",
    Callback = function(v) selectedMutation = v end
})

local function _setMutationVisible()
    if itemMode == "Pet" or itemMode == "Egg" then
        if mutationDD.SetVisible then mutationDD:SetVisible(true) end
    else
        if mutationDD.SetVisible then mutationDD:SetVisible(false) end
    end
end
_setMutationVisible()

local petDD = GiftTab:Dropdown({
    Title = "Pet (by Type)",
    Values = (function()
        local arr = {}
        for _,p in ipairs(petOptions) do table.insert(arr, p.key .. "  (x" .. p.count .. ")") end
        return (#arr > 0) and arr or { "No pets…" }
    end)(),
    Value = (selectedPetKey and (selectedPetKey .. "  (x" .. (petOptions[1] and petOptions[1].count or 0) .. ")")) or nil,
    Callback = function(v)
        local k = v and v:match("^(.-)%s+%(") or v
        selectedPetKey = k
        -- Rebuild mutation list for this type
        for _,pack in ipairs(petOptions) do
            if pack.key == selectedPetKey then
                local list = { "Any" }
                for m,_ in pairs(pack.mutations or {}) do table.insert(list, tostring(m)) end
                table.sort(list, function(a,b)
                    if a == "Any" then return true elseif b == "Any" then return false end
                    return a < b
                end)
                if mutationDD.Refresh then mutationDD:Refresh(list) end
                if mutationDD.Select then mutationDD:Select(list[1]) end
                selectedMutation = "Any"
                break
            end
        end
    end
})

local eggDD = GiftTab:Dropdown({
    Title = "Egg (by Type)",
    Values = (function()
        local arr = {}
        for _,e in ipairs(eggOptions) do table.insert(arr, e.key .. "  (x" .. e.count .. ")") end
        return (#arr > 0) and arr or { "No eggs…" }
    end)(),
    Value = (selectedEggKey and (selectedEggKey .. "  (x" .. (eggOptions[1] and eggOptions[1].count or 0) .. ")")) or nil,
    Callback = function(v)
        local k = v and v:match("^(.-)%s+%(") or v
        selectedEggKey = k
        -- Rebuild mutation list for this egg type
        for _,pack in ipairs(eggOptions) do
            if pack.key == selectedEggKey then
                local list = { "Any" }
                for m,_ in pairs(pack.mutations or {}) do table.insert(list, tostring(m)) end
                table.sort(list, function(a,b)
                    if a == "Any" then return true elseif b == "Any" then return false end
                    return a < b
                end)
                if mutationDD.Refresh then mutationDD:Refresh(list) end
                if mutationDD.Select then mutationDD:Select(list[1]) end
                selectedMutation = "Any"
                break
            end
        end
    end
})

local foodDD = GiftTab:Dropdown({
    Title = "Food",
    Values = (function()
        local arr = {}
        for _,f in ipairs(foodOptions) do table.insert(arr, f.key .. "  (x" .. f.count .. ")") end
        return (#arr > 0) and arr or { "No foods…" }
    end)(),
    Value = (selectedFoodKey and (selectedFoodKey .. "  (x" .. (foodOptions[1] and foodOptions[1].count or 0) .. ")")) or nil,
    Callback = function(v)
        local k = v and v:match("^(.-)%s+%(") or v
        selectedFoodKey = k
    end
})

local qtyBox = GiftTab:Input({
    Title = "Qty",
    Placeholder = "1",
    Numeric = true,
    Callback = function(txt)
        local n = tonumber(txt)
        if not n or n < 1 then n = 1 end
        qtyToSend = math.floor(n)
    end
})

-- Teleport behind
local tpBox = GiftTab:Input({
    Title = "Teleport Distance (behind target)",
    Placeholder = tostring(tpDistance),
    Numeric = true,
    Callback = function(txt)
        local n = tonumber(txt) or tpDistance
        if n < 2 then n = 2 end
        if n > 30 then n = 30 end
        tpDistance = math.floor(n)
    end
})

GiftTab:Button({
    Title = "Teleport Behind Target",
    Icon = "navigation",
    Callback = function()
        local tgt = _ensureTarget(selectedPlayer)
        if not tgt then
            WindUI:Notify({ Title="Gift", Content="Target player not found.", Duration=3, Icon="x" })
            return
        end
        local ok, err = _teleportBehind(tgt, tpDistance)
        if ok then
            WindUI:Notify({ Title="Gift", Content="Teleported behind target.", Duration=2 })
        else
            WindUI:Notify({ Title="Gift", Content="Teleport failed: "..tostring(err), Duration=3, Icon="x" })
        end
    end
})

GiftTab:Button({
    Title = "Refresh Lists",
    Icon = "refresh-cw",
    Callback = function()
        playerOpts, playerMap = ScanPlayers()
        if playerDD.Refresh then playerDD:Refresh((#playerOpts>0) and playerOpts or { "No players…" }) end
        if playerDD.Select and playerOpts[1] then playerDD:Select(playerOpts[1]) selectedPlayer = playerOpts[1] end

        petOptions = ScanGiftablePets()
        do
            local arr = {}
            for _,p in ipairs(petOptions) do table.insert(arr, p.key .. "  (x" .. p.count .. ")") end
            if petDD.Refresh then petDD:Refresh((#arr>0) and arr or { "No pets…" }) end
            if petDD.Select and petOptions[1] then
                petDD:Select(petOptions[1].key .. "  (x" .. petOptions[1].count .. ")")
                selectedPetKey = petOptions[1].key
            end
        end

        eggOptions = ScanGiftableEggs()
        do
            local arr = {}
            for _,e in ipairs(eggOptions) do table.insert(arr, e.key .. "  (x" .. e.count .. ")") end
            if eggDD.Refresh then eggDD:Refresh((#arr>0) and arr or { "No eggs…" }) end
            if eggDD.Select and eggOptions[1] then
                eggDD:Select(eggOptions[1].key .. "  (x" .. eggOptions[1].count .. ")")
                selectedEggKey = eggOptions[1].key
            end
        end

        foodOptions = ScanGiftableFoods()
        do
            local arr = {}
            for _,f in ipairs(foodOptions) do table.insert(arr, f.key .. "  (x" .. f.count .. ")") end
            if foodDD.Refresh then foodDD:Refresh((#arr>0) and arr or { "No foods…" }) end
            if foodDD.Select and foodOptions[1] then
                foodDD:Select(foodOptions[1].key .. "  (x" .. foodOptions[1].count .. ")")
                selectedFoodKey = foodOptions[1].key
            end
        end

        -- Reset mutation for currently highlighted type
        if itemMode == "Pet" and selectedPetKey then
            for _,pack in ipairs(petOptions) do
                if pack.key == selectedPetKey then
                    local list = { "Any" , "None" }
                    for m,_ in pairs(pack.mutations or {}) do table.insert(list, tostring(m)) end
                    table.sort(list, function(a,b) if a=="Any" then return true elseif b=="Any" then return false end return a<b end)
                    if mutationDD.Refresh then mutationDD:Refresh(list) end
                    if mutationDD.Select then mutationDD:Select(list[1]) end
                    selectedMutation = "Any"
                    break
                end
            end
        elseif itemMode == "Egg" and selectedEggKey then
            for _,pack in ipairs(eggOptions) do
                if pack.key == selectedEggKey then
                    local list = { "Any" , "None" }
                    for m,_ in pairs(pack.mutations or {}) do table.insert(list, tostring(m)) end
                    table.sort(list, function(a,b) if a=="Any" then return true elseif b=="Any" then return false end return a<b end)
                    if mutationDD.Refresh then mutationDD:Refresh(list) end
                    if mutationDD.Select then mutationDD:Select(list[1]) end
                    selectedMutation = "Any"
                    break
                end
            end
        end

        _setMutationVisible()
        WindUI:Notify({ Title="Gift", Content="Lists refreshed.", Duration=2 })
    end
})

-- ---------- Runner ----------
GiftTab:Toggle({
    Title = "Start Auto Gift",
    Value = false,
    Callback = function(on)
        if sending then
            WindUI:Notify({ Title="Gift", Content="Already running.", Duration=2 })
            return
        end
        sending = on
        if not on then return end

        task.spawn(function()
            local target = _ensureTarget(selectedPlayer)
            if not target then
                WindUI:Notify({ Title="Gift", Content="Target player not found.", Duration=3, Icon="x" })
                sending = false
                return
            end
            if not GiftRE then
                WindUI:Notify({ Title="Gift", Content="GiftRE not found in ReplicatedStorage.Remote.", Duration=3, Icon="x" })
                sending = false
                return
            end

            local toSend = qtyToSend
            local sent = 0

            if itemMode == "Food" then
                while sending and toSend > 0 do
                    target = _ensureTarget(selectedPlayer)
                    if not target then
                        WindUI:Notify({ Title="Gift", Content="Target left the game.", Duration=3, Icon="x" })
                        break
                    end
                    local remaining = _remainingForFoodKey(selectedFoodKey)
                    if remaining <= 0 then
                        WindUI:Notify({ Title="Gift", Content="No more of selected food.", Duration=3, Icon="x" })
                        break
                    end

                    local uid = _resolveFoodUIDForKey(selectedFoodKey) or selectedFoodKey
                    local ok, err = _giftOnce_UID(uid, target)
                    if ok then
                        sent = sent + 1
                        toSend = toSend - 1
                        setStatus(("Gifted FOOD %s to %s (%d/%d)"):format(selectedFoodKey, target.Name, sent, qtyToSend))
                    else
                        WindUI:Notify({ Title="Gift", Content="Gift failed: "..tostring(err), Duration=3, Icon="x" })
                        break
                    end
                    task.wait(0.2)
                end

            elseif itemMode == "Pet" then
                -- Pet or Egg: pop UID by type (respect mutation if set)
                local packs = (itemMode == "Pet") and ScanGiftablePets()
                local key = (itemMode == "Pet") and selectedPetKey
                local wantedM = (selectedMutation ~= "Any") and tonumber(selectedMutation) or (selectedMutation ~= "Any" and selectedMutation or nil)

                while sending and toSend > 0 do
                    target = _ensureTarget(selectedPlayer)
                    if not target then
                        WindUI:Notify({ Title="Gift", Content="Target left the game.", Duration=3, Icon="x" })
                        break
                    end

                    -- pop a matching UID
                    local uid = PopNextUID(packs, key, wantedM)
                    if not uid then
                        WindUI:Notify({ Title="Gift", Content="No more items of that type (or matching mutation).", Duration=3, Icon="x" })
                        break
                    end

                    local ok, err = _giftOnce_UID(uid, target)
                    if ok then
                        sent = sent + 1
                        toSend = toSend - 1
                        setStatus(("Gifted %s %s to %s (%d/%d)"):format(itemMode:upper(), key, target.Name, sent, qtyToSend))
                    else
                        WindUI:Notify({ Title="Gift", Content="Gift failed: "..tostring(err), Duration=3, Icon="x" })
                        break
                    end
                    task.wait(0.25)
                end
            else
                -- Pet or Egg: pop UID by type (respect mutation if set)
                local packs = (itemMode == "Egg") and ScanGiftableEggs()
                local key = (itemMode == "Egg") and selectedEggKey
                local wantedM = (selectedMutation ~= "Any") and tonumber(selectedMutation) or (selectedMutation ~= "Any" and selectedMutation or nil)

                while sending and toSend > 0 do
                    target = _ensureTarget(selectedPlayer)
                    if not target then
                        WindUI:Notify({ Title="Gift", Content="Target left the game.", Duration=3, Icon="x" })
                        break
                    end

                    -- pop a matching UID
                    local uid = PopNextUID(packs, key, wantedM)
                    if not uid then
                        WindUI:Notify({ Title="Gift", Content="No more items of that type (or matching mutation).", Duration=3, Icon="x" })
                        break
                    end

                    local ok, err = _giftOnce_UID(uid, target)
                    if ok then
                        sent = sent + 1
                        toSend = toSend - 1
                        setStatus(("Gifted %s %s to %s (%d/%d)"):format(itemMode:upper(), key, target.Name, sent, qtyToSend))
                    else
                        WindUI:Notify({ Title="Gift", Content="Gift failed: "..tostring(err), Duration=3, Icon="x" })
                        break
                    end
                    task.wait(0.25)
                end
            end

            WindUI:Notify({
                Title="Gift",
                Content=("Done. Sent %d / %d."):format(sent, qtyToSend),
                Duration=3
            })
            sending = false
        end)
    end
})

GiftTab:Button({
    Title = "Stop",
    Icon = "square",
    Variant = "Tertiary",
    Callback = function()
        sending = false
        setStatus("Idle")
    end
})
-- ========================= end Auto Gift ====================================



-- 9) ===== Boot & cleanup =====================================================
refreshTiles()
redrawInfo()
WindUI:Notify({ Title = "Utils Farm", Content = "UI loaded. Use Diagnostics if auto-place fails.", Duration = 4 })



print("[UtilsFarm] Press RightShift to hide/show UI. Top-center button appears when hidden.")


Window:OnClose(function()
    running = false
    runningEggFarm.Farm = false
    runningEggFarm.WaterFarm = false
end)
