-- ==============================
-- Fetching WindUI Modded
-- ==============================
local WindUI = loadstring(game:HttpGet("https://article-hub-studio.github.io/WindUI-Skibidi/loader.lua"))()

local Players       = game:GetService("Players")
local workspace     = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local RS            = game:GetService("ReplicatedStorage")
local HttpService   = game:GetService("HttpService")
local VirtualUser   = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local char   = player.Character or player.CharacterAdded:Wait()
local root   = char:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(c)
    char = c
    root = c:WaitForChild("HumanoidRootPart")
end)

-- Fetching the game's native Huge math module for Cash/Tokens formatting
local HugeModule
pcall(function()
    HugeModule = require(RS:WaitForChild("Modules", 5):WaitForChild("Huge", 5))
end)

-- Default Config Variables
local AUTO_BUY_DELAY       = 1
local AUTO_UPGRADE_DELAY   = 1
local AUTO_UPGRADE_AMOUNT  = 25   -- how many levels to buy per Upgrade call
local PHONE_OFFER_RESPONSE = "Accept"
local POWER_NAMES = { "UpgradeStack", "BuyNext", "Manage", "WalkSpeed", "ClickFruitValue" }

local INCOME_STREAMS = {
    "LemonDash", "LemonDepot", "LemonLabs",
    "LemonTrading", "LemonRepublic", "LemonRobotics",
    "LemonStand", "LemonX",
}

-- Evolution names ordered by index
local EVOLUTION_NAMES = {
    "Lemon", "Orange", "Lime", "Grapefruit",
    "Tangerine", "Pomelo", "Abyssalime", "Nullfruit",
    "Voidlemon", "Purity",
}

local ENABLED = {
    AutoBuyBuilding   = false,
    AutoUpgrade       = false,
    AutoClick         = false,
    AutoCashVine      = false,
    AutoPhoneOffer    = false,
    AutoRebirth       = false,
    AutoAscend        = false,
    AutoEvolve        = false,
    AutoPowerUpgrade  = false,
    AutoOfflineCash   = false,
    AutoTimeCash      = false,
    AutoEarnerBoost   = false,
    AutoMinigameRace  = false,
    AutoMinigameTrade = false,
    AntiAFK           = false,
    BoostFPS          = false,
    -- Orchard
    AutoCollectFruit  = false,
    AutoEatFruit      = false,
    AutoSellFruit     = false,
}

local STATS = {
    upgradesBought  = 0,
    clicks          = 0,
    phoneOffers     = 0,
    standsUpgraded  = 0,
    rebirths        = 0,
    ascends         = 0,
    evolves         = 0,
    powerUpgrades   = 0,
    racesWon        = 0,
    tradesWon       = 0,
    vineCollected   = 0,
    -- Orchard
    fruitsCollected = 0,
    fruitsEaten     = 0,
    fruitsSold      = 0,
}

-- ==============================
-- ORCHARD FRUIT SELECTION STATE
-- Each holds the selected label string from the inventory dropdown.
-- nil / "All" = act on every fruit in inventory.
-- Any other string = act only on the specific fruit that label maps to.
-- ==============================
local EAT_FRUIT_SELECTED  = "All"   -- label chosen in the Eat dropdown
local SELL_FRUIT_SELECTED = "All"   -- label chosen in the Sell dropdown

-- inventory map: label string → { evoIndex (0-based), mutationsTable, count }
-- rebuilt whenever the player opens the Orchard tab or clicks Refresh
local fruitInventoryLabels = { "All" }   -- shown in dropdowns
local fruitInventoryMap    = {}           -- label → entry

-- ==============================
-- CONFIG SAVE/LOAD SYSTEM
-- ==============================
local ConfigName = "AzureHUB_SellLemons.json"

local function SaveConfig()
    local data = {
        ENABLED              = ENABLED,
        AUTO_BUY_DELAY       = AUTO_BUY_DELAY,
        AUTO_UPGRADE_DELAY   = AUTO_UPGRADE_DELAY,
        AUTO_UPGRADE_AMOUNT  = AUTO_UPGRADE_AMOUNT,
        PHONE_OFFER_RESPONSE = PHONE_OFFER_RESPONSE,
        EAT_FRUIT_SELECTED   = EAT_FRUIT_SELECTED,
        SELL_FRUIT_SELECTED  = SELL_FRUIT_SELECTED,
    }
    pcall(function()
        writefile(ConfigName, HttpService:JSONEncode(data))
    end)
end

local function LoadConfig()
    pcall(function()
        if isfile(ConfigName) then
            local decoded = HttpService:JSONDecode(readfile(ConfigName))
            if decoded then
                if decoded.ENABLED then
                    for k, v in pairs(decoded.ENABLED) do
                        ENABLED[k] = v
                    end
                end
                if decoded.AUTO_BUY_DELAY      then AUTO_BUY_DELAY       = decoded.AUTO_BUY_DELAY      end
                if decoded.AUTO_UPGRADE_DELAY  then AUTO_UPGRADE_DELAY   = decoded.AUTO_UPGRADE_DELAY  end
                if decoded.AUTO_UPGRADE_AMOUNT then AUTO_UPGRADE_AMOUNT  = decoded.AUTO_UPGRADE_AMOUNT end
                if decoded.PHONE_OFFER_RESPONSE then PHONE_OFFER_RESPONSE = decoded.PHONE_OFFER_RESPONSE end
                if decoded.EAT_FRUIT_SELECTED  then EAT_FRUIT_SELECTED   = decoded.EAT_FRUIT_SELECTED  end
                if decoded.SELL_FRUIT_SELECTED then SELL_FRUIT_SELECTED  = decoded.SELL_FRUIT_SELECTED end
            end
        end
    end)
end

LoadConfig()

-- ==============================
-- UTILITY FUNCTIONS
-- ==============================
local function getMyTycoon()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:match("^Tycoon%d+$") then
            local owner = obj:FindFirstChild("Owner", true)
            if owner and owner:IsA("ObjectValue") and owner.Value == player then
                return obj
            end
        end
    end
    return nil
end

local myTycoon = nil
task.spawn(function()
    for _ = 1, 20 do
        myTycoon = getMyTycoon()
        if myTycoon then break end
        task.wait(0.5)
    end
end)

local function tycoon()
    if not myTycoon then myTycoon = getMyTycoon() end
    return myTycoon
end

local function rem(name)
    local t = tycoon()
    if not t then return nil end
    local remotes = t:FindFirstChild("Remotes")
    if not remotes then return nil end
    return remotes:FindFirstChild(name)
end

local function getTycoonValue(valueName)
    local t = tycoon()
    if not t then return "0" end
    local valuesFolder = t:FindFirstChild("Values")
    if valuesFolder then
        local valObj = valuesFolder:FindFirstChild(valueName)
        if valObj then
            if valObj:IsA("NumberValue") or valObj:IsA("IntValue") then
                if HugeModule and HugeModule.formatAbbreviated then
                    local success, formatted = pcall(function()
                        return HugeModule.formatAbbreviated(valObj.Value)
                    end)
                    if success then return formatted end
                end
                return tostring(valObj.Value)
            elseif valObj:IsA("StringValue") then
                return valObj.Value
            end
        end
    end
    return "0"
end

local function getInvestors()
    local success, result = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.Rebirth.InvestorsMenu.Body.Amount.Quantity.Text
    end)
    if success and result and result ~= "" then
        return result
    end
    return "0"
end

-- ==============================
-- FARMING LOGIC
-- ==============================
local buyLock = {}

local function runAutoUpgrades()
    while not myTycoon do task.wait(0.5) end
    RunService.Heartbeat:Connect(function()
        if not ENABLED.AutoBuyBuilding then return end
        local t = tycoon()
        if not t then return end
        local purchases = t:FindFirstChild("Purchases")
        if not purchases then return end
        for _, obj in ipairs(purchases:GetDescendants()) do
            if not ENABLED.AutoBuyBuilding then break end
            if not (obj:IsA("RemoteFunction") and obj.Name == "Purchase") then continue end
            local btn = obj.Parent
            if not btn then continue end
            if buyLock[obj] then continue end
            if btn:GetAttribute("Purchased") == true  then continue end
            if btn:GetAttribute("Enabled")   == false then continue end
            if btn:GetAttribute("Shown")     == false then continue end
            buyLock[obj] = true
            task.spawn(function()
                pcall(function() obj:InvokeServer(false) end)
                STATS.upgradesBought += 1
                task.wait(AUTO_BUY_DELAY)
                buyLock[obj] = nil
            end)
        end
    end)
end

local STAND_NAMES = {
    "LemonDash", "Lemon Depot", "Lemon Labs",
    "Lemon Stand", "Lemon Trading", "Lemon Republic",
    "Lemon Robotics", "LemonX",
}

local cachedStandRFs = {}

local function buildStandRFCache()
    cachedStandRFs = {}
    local t = tycoon()
    if not t then return end
    local purchases = t:FindFirstChild("Purchases")
    if not purchases then return end
    for _, standName in ipairs(STAND_NAMES) do
        -- Cobalt confirms path: Purchases[name][name][name].Upgrade
        local l1 = purchases:FindFirstChild(standName)
        if not l1 then continue end
        local l2 = l1:FindFirstChild(standName)
        if not l2 then continue end
        local l3 = l2:FindFirstChild(standName)
        -- Try l3 first (three levels), fall back to l2 descendants
        local upgradeRF = l3 and l3:FindFirstChild("Upgrade")
        if not upgradeRF then
            for _, obj in ipairs(l2:GetDescendants()) do
                if obj:IsA("RemoteFunction") and obj.Name == "Upgrade" then
                    upgradeRF = obj
                    break
                end
            end
        end
        if upgradeRF then
            cachedStandRFs[standName] = upgradeRF
        end
    end
end

local function runAutoUpgradeStands()
    while not myTycoon do task.wait(0.5) end
    buildStandRFCache()
    while true do
        if ENABLED.AutoUpgrade then
            if not next(cachedStandRFs) then
                buildStandRFCache()
            else
                for _, upgradeRF in pairs(cachedStandRFs) do
                    task.spawn(function()
                        -- Cobalt confirms: InvokeServer(amount) where amount = levels to buy
                        local ok = pcall(function() upgradeRF:InvokeServer(AUTO_UPGRADE_AMOUNT) end)
                        if ok then STATS.standsUpgraded += 1 end
                    end)
                end
            end
        end
        task.wait(AUTO_UPGRADE_DELAY)
    end
end

local cachedWakeRF = nil

local function buildWakeRFCache()
    cachedWakeRF = nil
    local r = rem("WakeIncomeStream")
    if r and r:IsA("RemoteFunction") then cachedWakeRF = r end
end

local function runAutoClick()
    while not myTycoon do task.wait(0.5) end
    buildWakeRFCache()
    RunService.Heartbeat:Connect(function()
        if not ENABLED.AutoClick then return end
        if not cachedWakeRF then buildWakeRFCache() return end
        for _, streamName in ipairs(INCOME_STREAMS) do
            local s = streamName
            task.spawn(function()
                pcall(function() cachedWakeRF:InvokeServer(s) end)
                STATS.clicks += 1
            end)
        end
    end)
end

local phoneEvent   = nil
local phoneConn    = nil
local activeOffer  = false
local offerHandled = false

local function respondToOffer()
    if not phoneEvent then return end
    offerHandled = true
    pcall(function() phoneEvent:FireServer(PHONE_OFFER_RESPONSE) end)
    STATS.phoneOffers += 1
end

local function setupPhoneOffer()
    local t = tycoon()
    if not t then return end
    local remotes = t:FindFirstChild("Remotes")
    if not remotes then return end
    local ev = remotes:FindFirstChild("PhoneOffer")
    if not ev then return end
    phoneEvent = ev
    if phoneConn then phoneConn:Disconnect() end
    phoneConn = phoneEvent.OnClientEvent:Connect(function(val)
        if type(val) == "number" then
            activeOffer  = true
            offerHandled = false
            if ENABLED.AutoPhoneOffer then respondToOffer() end
        else
            activeOffer  = false
            offerHandled = false
        end
    end)
end

task.spawn(function()
    while not myTycoon do task.wait(1) end
    setupPhoneOffer()
    while true do
        task.wait(0.5)
        if ENABLED.AutoPhoneOffer and activeOffer and not offerHandled then
            respondToOffer()
        end
    end
end)

local rebirthCooldown = false

local function runAutoRebirth()
    while not myTycoon do task.wait(0.5) end
    RunService.Heartbeat:Connect(function()
        if not ENABLED.AutoRebirth then return end
        if rebirthCooldown then return end
        local r = rem("Rebirth")
        if not r then return end
        task.spawn(function()
            rebirthCooldown = true
            local ok = pcall(function() r:InvokeServer() end)
            if ok then
                STATS.rebirths += 1
                task.wait(5)
                myTycoon = nil
                buyLock  = {}
                for _ = 1, 20 do
                    myTycoon = getMyTycoon()
                    if myTycoon then break end
                    task.wait(0.5)
                end
                buildStandRFCache()
                buildWakeRFCache()
                setupPhoneOffer()
            end
            rebirthCooldown = false
        end)
    end)
end

local function runAutoAscend()
    while true do
        task.wait(8)
        if not ENABLED.AutoAscend then continue end
        local r = rem("Ascend")
        if not r then continue end
        local ok = pcall(function() r:InvokeServer() end)
        if ok then STATS.ascends += 1 end
    end
end

local function runAutoEvolve()
    while true do
        task.wait(8)
        if not ENABLED.AutoEvolve then continue end
        local r = rem("Evolve")
        if not r then continue end
        local ok = pcall(function() r:InvokeServer() end)
        if ok then STATS.evolves += 1 end
    end
end

local function runAutoPowerUpgrade()
    while true do
        task.wait(0.5)
        if not ENABLED.AutoPowerUpgrade then continue end
        local r = rem("UpgradePowerLevel")
        if not r then continue end
        for _, powerName in ipairs(POWER_NAMES) do
            task.spawn(function()
                local ok = pcall(function() r:InvokeServer(powerName) end)
                if ok then STATS.powerUpgrades += 1 end
            end)
        end
    end
end

local function runAutoOfflineCash()
    while true do
        task.wait(20)
        if not ENABLED.AutoOfflineCash then continue end
        local r = rem("DoubleOfflineCash")
        if not r then continue end
        pcall(function() r:InvokeServer() end)
    end
end

local function runAutoTimeCash()
    while true do
        task.wait(10)
        if not ENABLED.AutoTimeCash then continue end
        local r = rem("UseTimeCash")
        if not r then continue end
        pcall(function() r:InvokeServer() end)
    end
end

local function runAutoEarnerBoost()
    while true do
        task.wait(10)
        if not ENABLED.AutoEarnerBoost then continue end
        local r = rem("UseEarnerBoost")
        if not r then continue end
        pcall(function() r:InvokeServer() end)
    end
end

local raceCD = false

local function runAutoMinigameRace()
    while true do
        task.wait(5)
        if not ENABLED.AutoMinigameRace then continue end
        if raceCD then continue end
        local core    = RS:FindFirstChild("Core")
        if not core then continue end
        local request = core:FindFirstChild("RemoteRequest")
        if not request then continue end
        local startRF = request:FindFirstChild("MinigameRaceService.Start")
        local endRF   = request:FindFirstChild("MinigameRaceService.End")
        if not startRF or not endRF then continue end
        raceCD = true
        task.spawn(function()
            local ok, res = pcall(function() return startRF:InvokeServer() end)
            if ok and res then
                task.wait(0.25)
                pcall(function() endRF:InvokeServer(1) end)
                STATS.racesWon += 1
            end
            task.wait(3)
            raceCD = false
        end)
    end
end

local tradeCD = false

local function runAutoMinigameTrade()
    while true do
        task.wait(5)
        if not ENABLED.AutoMinigameTrade then continue end
        if tradeCD then continue end
        local core    = RS:FindFirstChild("Core")
        if not core then continue end
        local request = core:FindFirstChild("RemoteRequest")
        if not request then continue end
        local startRF = request:FindFirstChild("MinigameTradeService.Start")
        local endRF   = request:FindFirstChild("MinigameTradeService.End")
        if not startRF or not endRF then continue end
        tradeCD = true
        task.spawn(function()
            local ok, res = pcall(function() return startRF:InvokeServer() end)
            if ok and res then
                task.wait(0.25)
                pcall(function() endRF:InvokeServer(1) end)
                STATS.tradesWon += 1
            end
            task.wait(3)
            tradeCD = false
        end)
    end
end

local function runAutoCashVine()
    while true do
        task.wait(30)
        if not ENABLED.AutoCashVine then continue end
        local map = workspace:FindFirstChild("Map")
        if not map then continue end
        local sewer = map:FindFirstChild("Sewer")
        if not sewer then continue end
        local cvFolder = sewer:FindFirstChild("CashVine")
        if not cvFolder then continue end
        local cvModel = cvFolder:FindFirstChild("CashVine")
        if not cvModel then continue end
        local useRF = cvModel:FindFirstChild("Use")
        if not useRF or not useRF:IsA("RemoteFunction") then continue end
        local targetPart = cvModel:FindFirstChildOfClass("BasePart") or cvFolder:FindFirstChildOfClass("BasePart")
        local saved = root.CFrame
        if targetPart then
            pcall(function() root.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0)) end)
            task.wait(0.2)
        end
        local ok = pcall(function() useRF:InvokeServer() end)
        if ok then STATS.vineCollected += 1 end
        task.wait(0.2)
        pcall(function() root.CFrame = saved end)
    end
end

-- ==============================
-- ORCHARD LOGIC
-- ==============================

local PLOT_STATE_EMPTY       = 0
local PLOT_STATE_FRUIT_READY = 3

local function getOrchardPlots()
    local plots = {}
    local t = tycoon()
    if not t then return plots end
    -- Cobalt confirms path: tycoon.Orchard.Plots.PlotN
    local orchardFolder = t:FindFirstChild("Orchard")
    local plotsFolder   = orchardFolder and orchardFolder:FindFirstChild("Plots")
    if not plotsFolder then return plots end
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        table.insert(plots, plot)
    end
    return plots
end

-- -------------------------------------------------------
-- Read OrchardFruits inventory via the game's OrchardFruits
-- component, which stores one entry per unique fruit type.
-- Returns: list of { evoIndex (number), mutations (table), count (number) }
-- Falls back to scanning the Values folder as a secondary path.
-- -------------------------------------------------------
local function getOrchardFruitEntries()
    local entries = {}

    -- Primary path: read via the OrchardFruits component on the Orchard entity.
    -- The component exposes GetAll() → { Fruit, Count } pairs, where each Fruit
    -- has :GetEvolution() (0-based) and :GetMutations() (table or nil).
    local ok = pcall(function()
        local RS2 = game:GetService("ReplicatedStorage")
        local LocalTycoon  = require(RS2.Modules.Tycoon.LocalTycoon)
        local Orchard      = require(RS2.Modules.Tycoon.Orchard.Orchard)
        local OrchardFruits = require(RS2.Modules.Tycoon.Orchard.OrchardFruits)
        local orchard = Orchard.getFromTycoon(LocalTycoon.get())
        local fruitsComp = orchard:GetComponent(OrchardFruits)
        for _, data in fruitsComp:GetAll() do
            local fruit = data.Fruit
            local count = data.Count or 1
            -- GetEvolution() is 0-based; store as-is, add 1 only when looking up EVOLUTION_NAMES
            local evo = fruit:GetEvolution()
            local mut = {}
            pcall(function()
                local raw = fruit:GetMutations()
                if type(raw) == "table" then mut = raw end
            end)
            if count > 0 then
                table.insert(entries, { evo, mut, count, fruit })
            end
        end
    end)

    -- Secondary fallback: the Values.OrchardFruits folder (some server versions
    -- replicate fruit data here as JSON StringValues).
    if not ok or #entries == 0 then
        local t = tycoon()
        if t then
            local valuesFolder  = t:FindFirstChild("Values")
            local fruitsFolder  = valuesFolder and valuesFolder:FindFirstChild("OrchardFruits")
            if fruitsFolder then
                for _, child in ipairs(fruitsFolder:GetChildren()) do
                    local raw = nil
                    pcall(function()
                        local val = child:IsA("StringValue") and child.Value or tostring(child.Value)
                        raw = HttpService:JSONDecode(val)
                    end)
                    -- Server packs as { "_C_", "OrchardFruit", evoIndex(0-based), mutations }
                    if raw and type(raw) == "table" and raw[3] then
                        local evo = (type(raw[3]) == "number") and raw[3] or 0
                        local mut = (type(raw[4]) == "table") and raw[4] or {}
                        local count = tonumber(child:GetAttribute("Count")) or 1
                        table.insert(entries, { evo, mut, count, nil })
                    end
                end
            end
        end
    end

    return entries
end

-- -------------------------------------------------------
-- Build a human-readable label for a fruit entry.
-- Format examples:
--   "Lemon"
--   "Orange [Juicy x2, Sweet x1]"
-- -------------------------------------------------------
local function buildFruitLabel(entry, index)
    -- entry format: { evoIndex (1-based), mutations, count, fruitObj }
    local evoIndex  = entry[1]
    local mutations = entry[2]
    -- evoIndex is 0-based; EVOLUTION_NAMES is 1-based, so add 1 for lookup
    local evoName   = (type(evoIndex) == "number" and EVOLUTION_NAMES[evoIndex + 1]) or ("Evo#" .. tostring(evoIndex))

    local mutParts = {}
    if type(mutations) == "table" then
        for mutName, count in pairs(mutations) do
            if type(count) == "number" and count > 0 then
                table.insert(mutParts, mutName .. " x" .. count)
            end
        end
        table.sort(mutParts)
    end

    local label
    if #mutParts > 0 then
        label = evoName .. " [" .. table.concat(mutParts, ", ") .. "]"
    else
        label = evoName
    end

    -- Guarantee uniqueness by appending slot number if a duplicate already exists
    local base = label
    local n = 2
    local seen = {}
    for _, existing in ipairs(fruitInventoryLabels) do
        seen[existing] = true
    end
    while seen[label] do
        label = base .. " (" .. n .. ")"
        n += 1
    end

    return label
end

-- -------------------------------------------------------
-- Rebuild fruitInventoryLabels and fruitInventoryMap
-- from the current live inventory. Called on Refresh and
-- at UI-build time.
-- -------------------------------------------------------
local eatDropdownRef  = nil  -- set after UI is created
local sellDropdownRef = nil

local function rebuildInventoryDropdown()
    fruitInventoryLabels = { "All" }
    fruitInventoryMap    = {}

    local entries = getOrchardFruitEntries()
    for i, entry in ipairs(entries) do
        -- entry[1] = evoIndex (0-based), entry[2] = mutations, entry[3] = count
        if type(entry[1]) ~= "number" then continue end
        local label = buildFruitLabel(entry, i)
        table.insert(fruitInventoryLabels, label)
        -- store evo index (1-based), mutations, and count for eat/sell use
        fruitInventoryMap[label] = { entry[1], entry[2] or {}, entry[3] or 1 }  -- entry[1] is 0-based evo
    end

    -- Update the live dropdowns if they already exist
    if eatDropdownRef and eatDropdownRef.SetValues then
        pcall(function()
            eatDropdownRef:SetValues(fruitInventoryLabels)
            -- reset to "All" if the previously-selected label no longer exists
            if EAT_FRUIT_SELECTED ~= "All" and not fruitInventoryMap[EAT_FRUIT_SELECTED] then
                EAT_FRUIT_SELECTED = "All"
                eatDropdownRef:SetValue("All")
            end
        end)
    end

    if sellDropdownRef and sellDropdownRef.SetValues then
        pcall(function()
            sellDropdownRef:SetValues(fruitInventoryLabels)
            if SELL_FRUIT_SELECTED ~= "All" and not fruitInventoryMap[SELL_FRUIT_SELECTED] then
                SELL_FRUIT_SELECTED = "All"
                sellDropdownRef:SetValue("All")
            end
        end)
    end
end

-- -------------------------------------------------------
-- AUTO COLLECT FRUIT
-- -------------------------------------------------------
local collectLock = {}

local function runAutoCollectFruit()
    while not myTycoon do task.wait(1) end
    while true do
        task.wait(2)
        if not ENABLED.AutoCollectFruit then continue end

        -- Cobalt confirms: RS.Core.RemoteRequest["OrchardPlot.Harvest"]
        local remoteRequest = RS:FindFirstChild("Core") and RS.Core:FindFirstChild("RemoteRequest")
        if not remoteRequest then continue end
        local harvestRF = remoteRequest:FindFirstChild("OrchardPlot.Harvest")
        if not harvestRF then continue end

        local plots = getOrchardPlots()
        for _, plot in ipairs(plots) do
            if not ENABLED.AutoCollectFruit then break end
            local state = plot:GetAttribute("State") or PLOT_STATE_EMPTY
            if state ~= PLOT_STATE_FRUIT_READY then continue end
            if collectLock[plot] then continue end

            collectLock[plot] = true
            task.spawn(function()
                -- Cobalt confirms: Event:InvokeServer(plotInstance)
                local ok = pcall(function() harvestRF:InvokeServer(plot) end)
                if ok then STATS.fruitsCollected += 1 end
                task.wait(1)
                collectLock[plot] = nil
            end)
        end
    end
end

-- -------------------------------------------------------
-- AUTO EAT FRUIT
-- EAT_FRUIT_SELECTED = "All"  → eat any fruit (first in inventory)
-- EAT_FRUIT_SELECTED = label  → eat only the fruit matching that inventory label
-- -------------------------------------------------------
local eatLock = false

local function runAutoEatFruit()
    while not myTycoon do task.wait(1) end
    while true do
        task.wait(1)
        if not ENABLED.AutoEatFruit then continue end
        if eatLock then continue end

        local t = tycoon()
        if not t then continue end
        local remotes = t:FindFirstChild("Remotes")
        if not remotes then continue end
        local eatRF = remotes:FindFirstChild("EatFruit")
        if not eatRF then continue end

        local evolutionIndex, mutations

        if EAT_FRUIT_SELECTED == "All" then
            -- eat first available fruit
            local entries = getOrchardFruitEntries()
            if #entries == 0 then continue end
            local entry = entries[1]
            -- entry[1] = evoIndex (1-based, shift back to 0-based for the remote)
            if type(entry[1]) ~= "number" then continue end
            evolutionIndex = entry[1]   -- already 0-based
            mutations      = entry[2] or {}
        else
            -- eat the specific fruit from the inventory map
            local mapped = fruitInventoryMap[EAT_FRUIT_SELECTED]
            if not mapped then
                -- label no longer in inventory; wait for user to refresh
                continue
            end
            evolutionIndex = mapped[1]  -- already 0-based
            mutations      = mapped[2]
        end

        eatLock = true
        task.spawn(function()
            local ok = pcall(function()
                -- Cobalt confirms: Event:InvokeServer({ evoIndex, mutations }) — plain 2-element array, 0-based evo
                eatRF:InvokeServer({ evolutionIndex, mutations })
            end)
            if ok then STATS.fruitsEaten += 1 end
            task.wait(2)
            eatLock = false
        end)
    end
end

-- -------------------------------------------------------
-- AUTO SELL FRUIT
-- SELL_FRUIT_SELECTED = "All"  → sell all fruits (batch up to 16)
-- SELL_FRUIT_SELECTED = label  → sell only the specific fruit matching that label
-- -------------------------------------------------------
local sellLock = false

local function runAutoSellFruit()
    while not myTycoon do task.wait(1) end
    while true do
        task.wait(1.5)
        if not ENABLED.AutoSellFruit then continue end
        if sellLock then continue end

        local t = tycoon()
        if not t then continue end
        local remotes = t:FindFirstChild("Remotes")
        if not remotes then continue end

        -- Try known remote names for selling fruit
        local sellRF = remotes:FindFirstChild("SellFruit")
                    or remotes:FindFirstChild("OrchardFruit.Sell")
                    or remotes:FindFirstChild("SellFruits")
        if not sellRF then continue end

        local fruitsToSend = {}
        local countsToSend = {}

        if SELL_FRUIT_SELECTED == "All" then
            -- batch all fruits, up to 16 unique types (sell full stack each)
            local entries = getOrchardFruitEntries()
            local sent = 0
            for _, entry in ipairs(entries) do
                if sent >= 16 then break end
                -- entry[1] = evoIndex (1-based); remote expects 0-based
                local evo = entry[1]
                local mut = entry[2] or {}
                local cnt = entry[3] or 1
                if type(evo) ~= "number" then continue end
                table.insert(fruitsToSend, { "_C_", "OrchardFruit", evo, mut })  -- evo already 0-based
                table.insert(countsToSend, cnt)
                sent += 1
            end
        else
            -- sell only the specifically selected inventory fruit
            local mapped = fruitInventoryMap[SELL_FRUIT_SELECTED]
            if not mapped then continue end
            -- mapped[1] = evoIndex (1-based), mapped[2] = mutations, mapped[3] = count
            table.insert(fruitsToSend, { "_C_", "OrchardFruit", mapped[1], mapped[2] })  -- mapped[1] already 0-based
            table.insert(countsToSend, mapped[3] or 1)
        end

        if #fruitsToSend == 0 then continue end

        sellLock = true
        task.spawn(function()
            local ok = pcall(function()
                sellRF:InvokeServer({
                    Fruits = fruitsToSend,
                    Counts = countsToSend,
                })
            end)
            if ok then STATS.fruitsSold += #fruitsToSend end
            task.wait(1)
            sellLock = false
        end)
    end
end

player.Idled:Connect(function()
    if not ENABLED.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

task.spawn(function()
    while true do
        task.wait(900)
        if not ENABLED.AntiAFK then continue end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

local removedObjects = {}
local fpsBoostActive = false

local function enableFPSBoost()
    if fpsBoostActive then return end
    fpsBoostActive = true
    local removeClasses = {
        "Texture", "Decal", "ParticleEmitter", "Trail",
        "Smoke", "Fire", "Sparkles", "SpecialMesh",
        "SelectionBox", "SurfaceAppearance",
    }
    for _, obj in ipairs(workspace:GetDescendants()) do
        for _, cls in ipairs(removeClasses) do
            if obj:IsA(cls) then
                table.insert(removedObjects, { obj = obj, parent = obj.Parent })
                obj.Parent = nil
                break
            end
        end
    end
    local lighting = game:GetService("Lighting")
    for _, obj in ipairs(lighting:GetChildren()) do
        if obj:IsA("Sky") or obj:IsA("Atmosphere") or obj:IsA("BloomEffect")
        or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect")
        or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
            table.insert(removedObjects, { obj = obj, parent = obj.Parent })
            obj.Parent = nil
        end
    end
    lighting.GlobalShadows = false
    lighting.FogEnd        = 100000
    lighting.Brightness    = 2
end

local function disableFPSBoost()
    if not fpsBoostActive then return end
    fpsBoostActive = false
    for _, entry in ipairs(removedObjects) do
        pcall(function() entry.obj.Parent = entry.parent end)
    end
    removedObjects = {}
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = true
    lighting.FogEnd        = 100000
    lighting.Brightness    = 1
end

player.CharacterAdded:Connect(function()
    task.wait(2)
    buildStandRFCache()
    buildWakeRFCache()
    setupPhoneOffer()
    buyLock     = {}
    collectLock = {}
    eatLock     = false
    sellLock    = false
end)

-- ==============================
-- WindUI Modded: Azure HUB Setup
-- ==============================

local Window = WindUI:CreateWindow({
    Title      = "Azure HUB",
    Icon       = "cloud",
    Author     = "Azure",
    Folder     = "AzureHUB",
    TypeWindow = "modern",
})

local MainTab    = Window:Tab({ Title = "Main",     Icon = "home"        })
local UpgradeTab = Window:Tab({ Title = "Upgrade",  Icon = "trending-up" })
local MiscTab    = Window:Tab({ Title = "Misc",     Icon = "box"         })
local OrchardTab = Window:Tab({ Title = "Orchard",  Icon = "leaf"        })
local StatsTab   = Window:Tab({ Title = "Stats",    Icon = "bar-chart"   })
local SettTab    = Window:Tab({ Title = "Settings", Icon = "settings"    })

-- ==============================
-- Main Tab
-- ==============================
MainTab:Toggle({
    Title    = "Auto Buy Building",
    Default  = ENABLED.AutoBuyBuilding,
    Callback = function(v)
        ENABLED.AutoBuyBuilding = v
        SaveConfig()
    end,
})

MainTab:Slider({
    Title    = "Auto Buy Speed (Buys/s)",
    Step     = 1,
    Value    = { Min = 1, Max = 50, Default = math.floor(1 / AUTO_BUY_DELAY) },
    Callback = function(v)
        AUTO_BUY_DELAY = 1 / v
        SaveConfig()
    end,
})

MainTab:Toggle({
    Title    = "Auto Upgrade",
    Default  = ENABLED.AutoUpgrade,
    Callback = function(v)
        ENABLED.AutoUpgrade = v
        SaveConfig()
    end,
})

MainTab:Slider({
    Title    = "Auto Upgrade Delay (s)",
    Step     = 0.1,
    Value    = { Min = 0.1, Max = 5, Default = AUTO_UPGRADE_DELAY },
    Callback = function(v)
        AUTO_UPGRADE_DELAY = v
        SaveConfig()
    end,
})

MainTab:Input({
    Title       = "Auto Upgrade Amount (levels per call)",
    Default     = tostring(AUTO_UPGRADE_AMOUNT),
    Placeholder = "e.g. 25 or 100",
    Numeric     = true,
    Callback    = function(v)
        local n = tonumber(v)
        if n and n >= 1 then
            AUTO_UPGRADE_AMOUNT = math.floor(n)
            SaveConfig()
        end
    end,
})

MainTab:Toggle({
    Title    = "Auto Click Income",
    Default  = ENABLED.AutoClick,
    Callback = function(v)
        ENABLED.AutoClick = v
        SaveConfig()
    end,
})

MainTab:Toggle({
    Title    = "Auto Cash Vine",
    Default  = ENABLED.AutoCashVine,
    Callback = function(v)
        ENABLED.AutoCashVine = v
        SaveConfig()
    end,
})

MainTab:Toggle({
    Title    = "Auto Phone Offer",
    Default  = ENABLED.AutoPhoneOffer,
    Callback = function(v)
        ENABLED.AutoPhoneOffer = v
        SaveConfig()
        if v and activeOffer then offerHandled = false respondToOffer() end
    end,
})

-- ==============================
-- Upgrade Tab
-- ==============================
UpgradeTab:Toggle({
    Title    = "Auto Rebirth",
    Default  = ENABLED.AutoRebirth,
    Callback = function(v)
        ENABLED.AutoRebirth = v
        SaveConfig()
    end,
})

UpgradeTab:Toggle({
    Title    = "Auto Ascend",
    Default  = ENABLED.AutoAscend,
    Callback = function(v)
        ENABLED.AutoAscend = v
        SaveConfig()
    end,
})

UpgradeTab:Toggle({
    Title    = "Auto Evolve",
    Default  = ENABLED.AutoEvolve,
    Callback = function(v)
        ENABLED.AutoEvolve = v
        SaveConfig()
    end,
})

UpgradeTab:Toggle({
    Title    = "Auto Power Upgrade",
    Default  = ENABLED.AutoPowerUpgrade,
    Callback = function(v)
        ENABLED.AutoPowerUpgrade = v
        SaveConfig()
    end,
})

-- ==============================
-- Misc Tab
-- ==============================
MiscTab:Toggle({
    Title    = "Auto Double Offline Cash",
    Default  = ENABLED.AutoOfflineCash,
    Callback = function(v)
        ENABLED.AutoOfflineCash = v
        SaveConfig()
    end,
})

MiscTab:Toggle({
    Title    = "Auto Use Time Cash",
    Default  = ENABLED.AutoTimeCash,
    Callback = function(v)
        ENABLED.AutoTimeCash = v
        SaveConfig()
    end,
})

MiscTab:Toggle({
    Title    = "Auto Use Earner Boost",
    Default  = ENABLED.AutoEarnerBoost,
    Callback = function(v)
        ENABLED.AutoEarnerBoost = v
        SaveConfig()
    end,
})

MiscTab:Toggle({
    Title    = "Auto Minigame Race",
    Default  = ENABLED.AutoMinigameRace,
    Callback = function(v)
        ENABLED.AutoMinigameRace = v
        SaveConfig()
    end,
})

MiscTab:Toggle({
    Title    = "Auto Minigame Trade",
    Default  = ENABLED.AutoMinigameTrade,
    Callback = function(v)
        ENABLED.AutoMinigameTrade = v
        SaveConfig()
    end,
})

-- ==============================
-- Orchard Tab
-- ==============================
OrchardTab:Paragraph({
    Title = "Orchard Automation",
    Desc  = "Requires the Orchard to be unlocked. Auto Collect picks up ready fruit. Auto Eat consumes fruit for buffs. Auto Sell sells fruit for cash.",
})

-- Auto Collect Fruit
OrchardTab:Toggle({
    Title    = "Auto Collect Fruit",
    Default  = ENABLED.AutoCollectFruit,
    Callback = function(v)
        ENABLED.AutoCollectFruit = v
        SaveConfig()
    end,
})

-- -------------------------------------------------------
-- Build the initial inventory list before creating UI
-- -------------------------------------------------------
rebuildInventoryDropdown()

-- Refresh button — rescans the live inventory and repopulates both dropdowns
OrchardTab:Button({
    Title    = "Refresh Fruit Inventory",
    Callback = function()
        rebuildInventoryDropdown()
        WindUI:Notify({
            Title    = "Inventory Refreshed",
            Content  = (#fruitInventoryLabels - 1) .. " fruit(s) found in inventory.",
            Duration = 3,
        })
    end,
})

-- Auto Eat Fruit
OrchardTab:Toggle({
    Title    = "Auto Eat Fruit",
    Default  = ENABLED.AutoEatFruit,
    Callback = function(v)
        ENABLED.AutoEatFruit = v
        SaveConfig()
    end,
})

-- Validate saved eat selection against current inventory labels
local eatDefault = "All"
for _, lbl in ipairs(fruitInventoryLabels) do
    if lbl == EAT_FRUIT_SELECTED then eatDefault = lbl break end
end
EAT_FRUIT_SELECTED = eatDefault

eatDropdownRef = OrchardTab:Dropdown({
    Title    = "Eat: Select Fruit from Inventory",
    Values   = fruitInventoryLabels,
    Value    = eatDefault,
    Callback = function(v)
        EAT_FRUIT_SELECTED = v
        SaveConfig()
    end,
})

-- Auto Sell Fruit
OrchardTab:Toggle({
    Title    = "Auto Sell Fruit",
    Default  = ENABLED.AutoSellFruit,
    Callback = function(v)
        ENABLED.AutoSellFruit = v
        SaveConfig()
    end,
})

-- Validate saved sell selection against current inventory labels
local sellDefault = "All"
for _, lbl in ipairs(fruitInventoryLabels) do
    if lbl == SELL_FRUIT_SELECTED then sellDefault = lbl break end
end
SELL_FRUIT_SELECTED = sellDefault

sellDropdownRef = OrchardTab:Dropdown({
    Title    = "Sell: Select Fruit from Inventory",
    Values   = fruitInventoryLabels,
    Value    = sellDefault,
    Callback = function(v)
        SELL_FRUIT_SELECTED = v
        SaveConfig()
    end,
})

-- ==============================
-- Stats Tab
-- ==============================
local sCash      = StatsTab:Paragraph({ Title = "Cash",             Desc = "0" })
local sInvestors = StatsTab:Paragraph({ Title = "Investors",        Desc = "0" })
local sTokens    = StatsTab:Paragraph({ Title = "Tokens",           Desc = "0" })
local sUpg       = StatsTab:Paragraph({ Title = "Buildings Bought", Desc = "0" })
local sClick     = StatsTab:Paragraph({ Title = "Income Clicks",    Desc = "0" })
local sStands    = StatsTab:Paragraph({ Title = "Stands Upgraded",  Desc = "0" })
local sPhone     = StatsTab:Paragraph({ Title = "Phone Offers",     Desc = "0" })
local sVine      = StatsTab:Paragraph({ Title = "Vine Collected",   Desc = "0" })
local sRebirths  = StatsTab:Paragraph({ Title = "Rebirths",         Desc = "0" })
local sAscends   = StatsTab:Paragraph({ Title = "Ascends",          Desc = "0" })
local sEvolves   = StatsTab:Paragraph({ Title = "Evolves",          Desc = "0" })
local sPower     = StatsTab:Paragraph({ Title = "Power Upgrades",   Desc = "0" })
local sRaces     = StatsTab:Paragraph({ Title = "Races Won",        Desc = "0" })
local sTrades    = StatsTab:Paragraph({ Title = "Trades Won",       Desc = "0" })
local sFruitsCol  = StatsTab:Paragraph({ Title = "Fruits Collected", Desc = "0" })
local sFruitsEat  = StatsTab:Paragraph({ Title = "Fruits Eaten",     Desc = "0" })
local sFruitsSold = StatsTab:Paragraph({ Title = "Fruits Sold",      Desc = "0" })

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function() sCash:SetDesc(getTycoonValue("Cash"))               end)
        pcall(function() sInvestors:SetDesc(getInvestors())                  end)
        pcall(function() sTokens:SetDesc(getTycoonValue("Tokens"))           end)
        pcall(function() sUpg:SetDesc(tostring(STATS.upgradesBought))        end)
        pcall(function() sClick:SetDesc(tostring(STATS.clicks))              end)
        pcall(function() sStands:SetDesc(tostring(STATS.standsUpgraded))     end)
        pcall(function() sPhone:SetDesc(tostring(STATS.phoneOffers))         end)
        pcall(function() sVine:SetDesc(tostring(STATS.vineCollected))        end)
        pcall(function() sRebirths:SetDesc(tostring(STATS.rebirths))         end)
        pcall(function() sAscends:SetDesc(tostring(STATS.ascends))           end)
        pcall(function() sEvolves:SetDesc(tostring(STATS.evolves))           end)
        pcall(function() sPower:SetDesc(tostring(STATS.powerUpgrades))       end)
        pcall(function() sRaces:SetDesc(tostring(STATS.racesWon))            end)
        pcall(function() sTrades:SetDesc(tostring(STATS.tradesWon))          end)
        pcall(function() sFruitsCol:SetDesc(tostring(STATS.fruitsCollected)) end)
        pcall(function() sFruitsEat:SetDesc(tostring(STATS.fruitsEaten))     end)
        pcall(function() sFruitsSold:SetDesc(tostring(STATS.fruitsSold))     end)
    end
end)

-- ==============================
-- Settings Tab
-- ==============================
SettTab:Dropdown({
    Title    = "Phone Offer Response",
    Values   = { "Accept", "Raise", "Reject" },
    Value    = PHONE_OFFER_RESPONSE,
    Callback = function(v)
        PHONE_OFFER_RESPONSE = v
        SaveConfig()
    end,
})

SettTab:Toggle({
    Title    = "Anti-AFK",
    Default  = ENABLED.AntiAFK,
    Callback = function(v)
        ENABLED.AntiAFK = v
        SaveConfig()
    end,
})

SettTab:Toggle({
    Title    = "Boost FPS",
    Default  = ENABLED.BoostFPS,
    Callback = function(v)
        ENABLED.BoostFPS = v
        SaveConfig()
        if v then enableFPSBoost() else disableFPSBoost() end
    end,
})

-- ==============================
-- Boot notification
-- ==============================
WindUI:Notify({
    Title    = "Azure HUB",
    Content  = "Loaded config & preferences!",
    Duration = 5,
})

-- ==============================
-- Initialize active loops
-- ==============================
task.spawn(runAutoUpgrades)
task.spawn(runAutoUpgradeStands)
task.spawn(runAutoClick)
task.spawn(runAutoRebirth)
task.spawn(runAutoAscend)
task.spawn(runAutoEvolve)
task.spawn(runAutoPowerUpgrade)
task.spawn(runAutoOfflineCash)
task.spawn(runAutoTimeCash)
task.spawn(runAutoEarnerBoost)
task.spawn(runAutoMinigameRace)
task.spawn(runAutoMinigameTrade)
task.spawn(runAutoCashVine)
-- Orchard loops
task.spawn(runAutoCollectFruit)
task.spawn(runAutoEatFruit)
task.spawn(runAutoSellFruit)

print("Azure HUB (WindUI Modded) loaded successfully.")
