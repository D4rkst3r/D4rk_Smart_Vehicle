-- D4rk Smart Vehicle - Server Prop Sync
-- Syncs props, spotlights, spinning and doors between clients

local propStates = {}
local spotlightStates = {}
local spinStates = {}
local doorStates = {}

-- ============================================
-- PROP SYNC
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncProp')
AddEventHandler('D4rk_Smart:SyncProp', function(netId, propId, state)
    local source = source
    
    -- Update state
    if not propStates[netId] then
        propStates[netId] = {}
    end
    
    propStates[netId][propId] = state
    
    -- Sync to all clients except sender
    TriggerClientEvent('D4rk_Smart:SyncPropClient', -1, netId, propId, state)
    
    if Config.Debug then
        print(string.format('^2[Prop Sync] Synced prop %s on vehicle %d^7', propId, netId))
    end
end)

-- ============================================
-- SPOTLIGHT SYNC
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncSpotlights')
AddEventHandler('D4rk_Smart:SyncSpotlights', function(netId, active)
    local source = source
    
    spotlightStates[netId] = active
    
    -- Sync to all clients except sender
    TriggerClientEvent('D4rk_Smart:SyncSpotlightsClient', -1, netId, active)
    
    if Config.Debug then
        print(string.format('^2[Spotlight Sync] Vehicle %d spotlights: %s^7', netId, active and 'ON' or 'OFF'))
    end
end)

-- ============================================
-- SPIN SYNC
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncSpin')
AddEventHandler('D4rk_Smart:SyncSpin', function(netId, propId, active, spinConfig)
    local source = source
    
    if not spinStates[netId] then
        spinStates[netId] = {}
    end
    
    if active then
        spinStates[netId][propId] = spinConfig
    else
        spinStates[netId][propId] = nil
    end
    
    -- Sync to all clients except sender
    TriggerClientEvent('D4rk_Smart:SyncSpinClient', -1, netId, propId, active, spinConfig)
    
    if Config.Debug then
        print(string.format('^2[Spin Sync] Prop %s on vehicle %d: %s^7', propId, netId, active and 'SPINNING' or 'STOPPED'))
    end
end)

-- ============================================
-- DOOR SYNC
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncDoor')
AddEventHandler('D4rk_Smart:SyncDoor', function(netId, doorIndex, open)
    local source = source
    
    if not doorStates[netId] then
        doorStates[netId] = {}
    end
    
    doorStates[netId][doorIndex] = open
    
    -- Sync to all clients except sender
    TriggerClientEvent('D4rk_Smart:SyncDoorClient', -1, netId, doorIndex, open)
    
    if Config.Debug then
        print(string.format('^2[Door Sync] Vehicle %d door %d: %s^7', netId, doorIndex, open and 'OPEN' or 'CLOSED'))
    end
end)

-- ============================================
-- STATE REQUEST
-- ============================================
RegisterNetEvent('D4rk_Smart:RequestHybridState')
AddEventHandler('D4rk_Smart:RequestHybridState', function(netId)
    local source = source
    
    -- Send all states for this vehicle
    if propStates[netId] then
        for propId, state in pairs(propStates[netId]) do
            TriggerClientEvent('D4rk_Smart:SyncPropClient', source, netId, propId, state)
        end
    end
    
    if spotlightStates[netId] then
        TriggerClientEvent('D4rk_Smart:SyncSpotlightsClient', source, netId, spotlightStates[netId])
    end
    
    if spinStates[netId] then
        for propId, spinConfig in pairs(spinStates[netId]) do
            TriggerClientEvent('D4rk_Smart:SyncSpinClient', source, netId, propId, true, spinConfig)
        end
    end
    
    if doorStates[netId] then
        for doorIndex, open in pairs(doorStates[netId]) do
            TriggerClientEvent('D4rk_Smart:SyncDoorClient', source, netId, doorIndex, open)
        end
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('playerDropped', function()
    -- Cleanup is handled by entity deletion
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('GetPropState', function(netId, propId)
    if propStates[netId] then
        return propStates[netId][propId]
    end
    return nil
end)

exports('GetSpotlightState', function(netId)
    return spotlightStates[netId]
end)

exports('GetSpinState', function(netId, propId)
    if spinStates[netId] then
        return spinStates[netId][propId]
    end
    return nil
end)

exports('GetDoorState', function(netId, doorIndex)
    if doorStates[netId] then
        return doorStates[netId][doorIndex]
    end
    return nil
end)

exports('GetAllStates', function(netId)
    return {
        props = propStates[netId],
        spotlights = spotlightStates[netId],
        spins = spinStates[netId],
        doors = doorStates[netId]
    }
end)
