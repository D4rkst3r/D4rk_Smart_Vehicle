-- D4rk Smart Vehicle - Spinning Props System
-- Continuously spinning props for warning signs, beacons, etc.

local spinningProps = {}

-- ============================================
-- SPIN CONTROL
-- ============================================
function ToggleSpin(vehicle, propId, spinConfig)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    if not spinningProps[netId] then
        spinningProps[netId] = {}
    end
    
    if spinningProps[netId][propId] then
        StopSpin(vehicle, propId)
    else
        StartSpin(vehicle, propId, spinConfig)
    end
end

function StartSpin(vehicle, propId, spinConfig)
    local propData = GetPropByID(vehicle, propId)
    if not propData then
        if Config.Debug then
            print('^3[Spin] Prop not found: ' .. propId .. '^7')
        end
        return
    end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    if not spinningProps[netId] then
        spinningProps[netId] = {}
    end
    
    -- Store spin state
    spinningProps[netId][propId] = {
        active = true,
        config = spinConfig
    }
    
    -- Start spin thread
    CreateThread(function()
        SpinThread(vehicle, propId, spinConfig)
    end)
    
    ShowNotification(string.format('Rotation aktiviert: %s', propId), 'success')
    
    -- Sync to server
    TriggerServerEvent('D4rk_Smart:SyncSpin', netId, propId, true, spinConfig)
    
    if Config.Debug then
        print(string.format('^2[Spin] Started spinning %s on vehicle %d^7', propId, netId))
    end
end

function StopSpin(vehicle, propId)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    if spinningProps[netId] and spinningProps[netId][propId] then
        spinningProps[netId][propId].active = false
        spinningProps[netId][propId] = nil
        
        ShowNotification(string.format('Rotation gestoppt: %s', propId), 'info')
        
        -- Sync to server
        TriggerServerEvent('D4rk_Smart:SyncSpin', netId, propId, false, nil)
        
        if Config.Debug then
            print(string.format('^3[Spin] Stopped spinning %s on vehicle %d^7', propId, netId))
        end
    end
end

-- ============================================
-- SPIN THREAD
-- ============================================
function SpinThread(vehicle, propId, spinConfig)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    while DoesEntityExist(vehicle) and spinningProps[netId] and spinningProps[netId][propId] do
        local spinState = spinningProps[netId][propId]
        if not spinState or not spinState.active then break end
        
        -- Get current state
        local state = GetPropState(vehicle, propId)
        if not state then break end
        
        -- Calculate new rotation
        local axis = spinConfig.axis or 3
        local amount = spinConfig.movementAmount or 0.5
        
        local newRotation = vector3(state.rotation.x, state.rotation.y, state.rotation.z)
        
        if axis == 1 then
            newRotation = vector3(state.rotation.x + amount, state.rotation.y, state.rotation.z)
        elseif axis == 2 then
            newRotation = vector3(state.rotation.x, state.rotation.y + amount, state.rotation.z)
        elseif axis == 3 then
            newRotation = vector3(state.rotation.x, state.rotation.y, state.rotation.z + amount)
        end
        
        -- Wrap rotation (0-360)
        newRotation = vector3(
            newRotation.x % 360,
            newRotation.y % 360,
            newRotation.z % 360
        )
        
        state.rotation = newRotation
        
        -- Apply rotation
        local propData = GetPropByID(vehicle, propId)
        if propData and DoesEntityExist(propData.entity) then
            AttachEntityToEntity(
                propData.entity,
                vehicle,
                propData.attachBone,
                state.offset.x, state.offset.y, state.offset.z,
                newRotation.x, newRotation.y, newRotation.z,
                false, false, true, false, 2, true
            )
            
            SetPropState(vehicle, propId, state)
        else
            break
        end
        
        -- Remove smoke if configured (Smart Fires integration)
        if spinConfig.removeSmoke then
            local propEntity = propData.entity
            local coords = GetEntityCoords(propEntity)
            
            -- Stop fires in range
            StopFireInRange(coords.x, coords.y, coords.z, 10.0)
        end
        
        Wait(spinConfig.movementSpeed or 100)
    end
    
    -- Cleanup
    if spinningProps[netId] then
        spinningProps[netId][propId] = nil
    end
end

-- ============================================
-- SYNC EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncSpinClient')
AddEventHandler('D4rk_Smart:SyncSpinClient', function(netId, propId, active, spinConfig)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end
    
    -- Don't sync to self
    if vehicle == currentVehicle then return end
    
    if active then
        StartSpin(vehicle, propId, spinConfig)
    else
        StopSpin(vehicle, propId)
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Stop all spinning
    for netId, props in pairs(spinningProps) do
        for propId, _ in pairs(props) do
            props[propId] = nil
        end
    end
    
    spinningProps = {}
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('IsSpinning', function(vehicle, propId)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return spinningProps[netId] and spinningProps[netId][propId] ~= nil
end)

exports('ToggleSpin', function(vehicle, propId, spinConfig)
    ToggleSpin(vehicle, propId, spinConfig)
end)

exports('StopAllSpins', function(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    if spinningProps[netId] then
        for propId, _ in pairs(spinningProps[netId]) do
            StopSpin(vehicle, propId)
        end
    end
end)
