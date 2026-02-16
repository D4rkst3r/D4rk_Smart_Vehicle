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

    -- Reset window if expired (1 second)
    if (currentTime - data.windowStart) >= 1000 then
        data.count = 0
        data.windowStart = currentTime
    end

    data.count = data.count + 1

    -- Max 50 syncs per second
    if data.count > 50 then
        if Config.Debug then
            print(string.format('^1[D4rk_Smart] Player %d exceeded rate limit^7', source))
        end
        return false
    end

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
-- ANTI-CHEAT MONITORING
-- ============================================
local suspiciousActivity = {}

function MonitorSuspiciousActivity(source, reason)
    if not suspiciousActivity[source] then
        suspiciousActivity[source] = {
            count = 0,
            lastWarning = 0,
            reasons = {}
        }
    end

    local data = suspiciousActivity[source]
    data.count = data.count + 1

    if not data.reasons[reason] then
        data.reasons[reason] = 0
    end
    data.reasons[reason] = data.reasons[reason] + 1

    local currentTime = GetGameTimer()

    -- Warn every 30 seconds
    if (currentTime - data.lastWarning) >= 30000 then
        print(string.format('^3[D4rk_Smart] Suspicious activity from player %d: %s (Total: %d)^7', source, reason,
            data.count))
        data.lastWarning = currentTime

        -- Could trigger additional anti-cheat measures here
        -- Example: Kick player after X violations
        if data.count > 100 then
            print(string.format('^1[D4rk_Smart] Player %d exceeded suspicious activity threshold^7', source))
            -- DropPlayer(source, 'Suspicious vehicle control activity detected')
        end
    end
end

-- Monitor unauthorized control attempts
RegisterNetEvent('D4rk_Smart:SyncControl')
AddEventHandler('D4rk_Smart:SyncControl', function(netId, boneIndex, value)
    local source = source

    if not CheckRateLimit(source) then
        MonitorSuspiciousActivity(source, 'Rate limit exceeded')
        return
    end

    if GetVehicleController(netId) ~= source then
        MonitorSuspiciousActivity(source, 'Unauthorized control attempt')
        return
    end

    -- Update state (übernommen aus main.lua)
    local state = InitializeVehicleState(netId)
    state.controls[boneIndex] = value

    -- Sync to all clients
    TriggerClientEvent('D4rk_Smart:SyncControlClient', -1, netId, boneIndex, value)
end)

-- ============================================
-- STATISTICS
-- ============================================
local statistics = {
    totalControls = 0,
    totalSyncs = 0,
    vehiclesControlled = {},
    playersActive = {}
}

function UpdateStatistics(event, data)
    if event == 'control_start' then
        statistics.totalControls = statistics.totalControls + 1
        statistics.vehiclesControlled[data.netId] = (statistics.vehiclesControlled[data.netId] or 0) + 1
        statistics.playersActive[data.source] = (statistics.playersActive[data.source] or 0) + 1
    elseif event == 'sync' then
        statistics.totalSyncs = statistics.totalSyncs + 1
    end
end

RegisterNetEvent('D4rk_Smart:StartControl')
AddEventHandler('D4rk_Smart:StartControl', function(netId)
    UpdateStatistics('control_start', { netId = netId, source = source })
end)

-- Stats command
if Config.Debug then
    RegisterCommand('smartvehicle:stats', function(source, args)
        print('^2[D4rk_Smart] Statistics:^7')
        print(json.encode(statistics, { indent = true }))
    end, true)
end

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
exports('GetStatistics', function()
    return statistics
end)

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
