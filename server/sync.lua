-- D4rk Smart Vehicle - Advanced Sync System
local syncQueue = {}
local lastSyncTime = {}
local playerSyncCount = {}

-- ============================================
-- RATE LIMITING
-- ============================================
function CheckRateLimit(source)
    local currentTime = GetGameTimer()

    if not playerSyncCount[source] then
        playerSyncCount[source] = {
            count = 0,
            windowStart = currentTime
        }
    end

    local data = playerSyncCount[source]

    -- Reset window
    if (currentTime - data.windowStart) >= 1000 then
        data.count = 0
        data.windowStart = currentTime
    end

    data.count = data.count + 1

    -- ALT: 50 → viel zu niedrig
    -- NEU: 300 pro Sekunde (4 Bones × 60fps + Props + Stabilizers)
    if data.count > 300 then
        -- Nur EINMAL pro Fenster loggen, nicht jedes Mal!
        if not data.warned then
            data.warned = true
            if Config.Debug then
                print(string.format('^3[D4rk_Smart] Player %d rate limited (%d/s)^7', source, data.count))
            end
        end
        return false
    end

    data.warned = false
    return true
end

-- ============================================
-- BATCH PROCESSING
-- ============================================
function QueueSync(netId, syncType, data)
    if not syncQueue[netId] then
        syncQueue[netId] = {}
    end

    syncQueue[netId][syncType] = {
        data = data,
        timestamp = GetGameTimer()
    }
end

function ProcessSyncQueue()
    for netId, syncs in pairs(syncQueue) do
        for syncType, syncData in pairs(syncs) do
            local currentTime = GetGameTimer()

            -- Only send if at least 50ms have passed since last sync
            if not lastSyncTime[netId] or (currentTime - lastSyncTime[netId]) >= Config.UpdateRate then
                if syncType == 'control' then
                    TriggerClientEvent('D4rk_Smart:SyncControlClient', -1, netId, syncData.data.boneIndex,
                        syncData.data.value)
                elseif syncType == 'stabilizers' then
                    TriggerClientEvent('D4rk_Smart:SyncStabilizersClient', -1, netId, syncData.data.deployed)
                elseif syncType == 'water' then
                    TriggerClientEvent('D4rk_Smart:SyncWaterClient', -1, netId, syncData.data.active)
                elseif syncType == 'cage' then
                    TriggerClientEvent('D4rk_Smart:SyncCageClient', -1, netId, syncData.data.occupants)
                end

                lastSyncTime[netId] = currentTime
                syncQueue[netId][syncType] = nil
            end
        end
    end
end

-- ============================================
-- SYNC THREAD
-- ============================================
CreateThread(function()
    while true do
        Wait(Config.UpdateRate or 50)
        ProcessSyncQueue()
    end
end)

-- ============================================
-- STATE PERSISTENCE
-- ============================================
local saveInterval = 300000 -- 5 minutes

function SaveVehicleStates()
    if Config.Debug then
        print('^2[D4rk_Smart] Saving vehicle states...^7')

        local count = 0
        for _ in pairs(vehicleStates) do
            count = count + 1
        end

        print(string.format('^2[D4rk_Smart] Saved %d vehicle states^7', count))
    end

    -- TODO: Implement actual saving to database/file
    -- This is just a placeholder for the persistence system
end

function LoadVehicleStates()
    if Config.Debug then
        print('^2[D4rk_Smart] Loading vehicle states...^7')
    end

    -- TODO: Implement actual loading from database/file
end

-- Auto-save thread
CreateThread(function()
    while true do
        Wait(saveInterval)
        SaveVehicleStates()
    end
end)

-- Load on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    LoadVehicleStates()
end)

-- Save on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SaveVehicleStates()
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('playerDropped', function()
    local source = source
    playerSyncCount[source] = nil
end)


-- ============================================
-- NETWORK OPTIMIZATION
-- ============================================
-- Culling: Don't sync to players who are too far away
local function GetPlayersInRange(coords, range)
    local players = {}
    local allPlayers = GetPlayers()

    for _, player in ipairs(allPlayers) do
        local ped = GetPlayerPed(player)
        if ped and DoesEntityExist(ped) then
            local playerCoords = GetEntityCoords(ped)
            local distance = #(coords - playerCoords)

            if distance <= range then
                table.insert(players, player)
            end
        end
    end

    return players
end

-- Optimized sync for far-away players
-- (Could be implemented to reduce sync rate for distant players)

-- ============================================
-- EXPORTS
-- ============================================

exports('GetSyncQueue', function()
    return syncQueue
end)

exports('ClearSyncQueue', function(netId)
    if netId then
        syncQueue[netId] = nil
    else
        syncQueue = {}
    end
end)
