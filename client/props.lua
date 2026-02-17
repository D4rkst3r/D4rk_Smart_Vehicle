-- D4rk Smart Vehicle - Prop Management System (Hybrid)
-- VERSION 2.5 - Collision Fix: Default OFF für attached Props
-- Spawns and attaches props to vehicles

local spawnedProps = {}
local propStates = {}

-- ============================================
-- PROP SPAWNING
-- ============================================
function SpawnVehicleProps(vehicle, vehicleName)
    local config = GetVehicleConfig(vehicleName)
    if not config or not config.props then return end

    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    if not spawnedProps[netId] then
        spawnedProps[netId] = {}
    end

    if not propStates[netId] then
        propStates[netId] = {}
    end

    for i, propConfig in ipairs(config.props) do
        local propData = SpawnProp(vehicle, propConfig, vehicleName)

        if propData then
            table.insert(spawnedProps[netId], propData)

            -- Initialize state
            propStates[netId][propConfig.id] = {
                offset = propConfig.defaultOffset or propConfig.offset or vector3(0, 0, 0),
                rotation = propConfig.defaultRotation or propConfig.rotation or vector3(0, 0, 0),
                visible = not propConfig.toggleOffInitially,
                spinning = false
            }

            if Config.Debug then
                print(string.format('^2[Props] Spawned prop %s for vehicle %d^7', propConfig.id, netId))
            end
        end
    end

    if Config.Debug then
        print(string.format('^2[Props] Spawned %d props for vehicle %d^7', #spawnedProps[netId], netId))
    end
end

function SpawnProp(vehicle, propConfig, vehicleName)
    -- Request model
    local modelHash = GetHashKey(propConfig.model)
    RequestModel(modelHash)

    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        if Config.Debug then
            print('^3[Props] Failed to load model: ' .. propConfig.model .. '^7')
        end
        return nil
    end

    -- Determine attach point
    local attachEntity = vehicle
    local attachBone = 0

    if propConfig.attachTo and propConfig.attachTo ~= "vehicle" then
        -- Attach to bone
        attachBone = GetEntityBoneIndexByName(vehicle, propConfig.attachTo)
        if attachBone == -1 then
            if Config.Debug then
                print('^3[Props] Bone not found: ' .. propConfig.attachTo .. '^7')
            end
            -- Fall back to vehicle
            attachBone = 0
        end
    end

    -- Get spawn position
    local coords
    if attachBone ~= 0 then
        coords = GetWorldPositionOfEntityBone(vehicle, attachBone)
    else
        coords = GetEntityCoords(vehicle)
    end

    local offset = propConfig.defaultOffset or propConfig.offset or vector3(0, 0, 0)

    -- Spawn prop
    local prop = CreateObject(
        modelHash,
        coords.x + offset.x,
        coords.y + offset.y,
        coords.z + offset.z,
        false, -- networkObject
        true,  -- netMissionEntity
        true   -- doorFlag
    )

    if not DoesEntityExist(prop) then
        if Config.Debug then
            print('^3[Props] Failed to create prop^7')
        end
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end

    -- FIX: Collision default AUS für attached Props!
    -- Attached Props mit Collision lassen das Fahrzeug fliegen
    SetEntityCollision(prop, false, false)
    SetEntityNoCollisionEntity(prop, vehicle, false)

    if propConfig.toggleOffInitially then
        SetEntityVisible(prop, false, false)
    else
        SetEntityVisible(prop, true, false)
    end

    SetEntityAlpha(prop, 255, false)
    SetEntityInvincible(prop, true)

    -- Attach to vehicle/bone
    local rotation = propConfig.defaultRotation or propConfig.rotation or vector3(0, 0, 0)

    AttachEntityToEntity(
        prop,
        vehicle,
        attachBone,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, false, false, false, 2, true -- p11 (collision) = false!
    )

    SetModelAsNoLongerNeeded(modelHash)

    -- Return prop data
    return {
        entity = prop,
        config = propConfig,
        attachBone = attachBone,              -- Numerischer Index
        attachBoneName = propConfig.attachTo, -- String-Name für spinning.lua
        id = propConfig.id
    }
end

-- ============================================
-- PROP REMOVAL
-- ============================================
function RemoveVehicleProps(vehicle)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    if spawnedProps[netId] then
        for _, propData in ipairs(spawnedProps[netId]) do
            if DoesEntityExist(propData.entity) then
                DeleteEntity(propData.entity)
            end
        end

        spawnedProps[netId] = nil
        propStates[netId] = nil

        if Config.Debug then
            print('^3[Props] Removed props for vehicle ' .. netId .. '^7')
        end
    end
end

-- ============================================
-- PROP STATE MANAGEMENT
-- ============================================
function GetPropByID(vehicle, propId)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    if not spawnedProps[netId] then return nil end

    for _, propData in ipairs(spawnedProps[netId]) do
        if propData.id == propId then
            return propData
        end
    end

    return nil
end

function GetPropState(vehicle, propId)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    if not propStates[netId] then return nil end

    return propStates[netId][propId]
end

function SetPropState(vehicle, propId, state)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    if not propStates[netId] then
        propStates[netId] = {}
    end

    propStates[netId][propId] = state
end

-- ============================================
-- PROP CONTROL
-- ============================================
function UpdatePropControl(vehicle, propId, controlType, axis, amount)
    local propData = GetPropByID(vehicle, propId)
    if not propData then return end

    local state = GetPropState(vehicle, propId)
    if not state then return end

    local prop = propData.entity
    local config = propData.config

    if controlType == "move" then
        -- Update offset
        local newOffset = vector3(state.offset.x, state.offset.y, state.offset.z)

        if axis == 1 then
            newOffset = vector3(state.offset.x + amount, state.offset.y, state.offset.z)
        elseif axis == 2 then
            newOffset = vector3(state.offset.x, state.offset.y + amount, state.offset.z)
        elseif axis == 3 then
            newOffset = vector3(state.offset.x, state.offset.y, state.offset.z + amount)
        end

        -- Check limits
        if config.minimumOffSet then
            newOffset = vector3(
                math.max(config.minimumOffSet.x, newOffset.x),
                math.max(config.minimumOffSet.y, newOffset.y),
                math.max(config.minimumOffSet.z, newOffset.z)
            )
        end

        if config.maximumOffSet then
            newOffset = vector3(
                math.min(config.maximumOffSet.x, newOffset.x),
                math.min(config.maximumOffSet.y, newOffset.y),
                math.min(config.maximumOffSet.z, newOffset.z)
            )
        end

        state.offset = newOffset

        -- Apply
        AttachEntityToEntity(
            prop,
            vehicle,
            propData.attachBone,
            newOffset.x, newOffset.y, newOffset.z,
            state.rotation.x, state.rotation.y, state.rotation.z,
            false, false, false, false, 2, true -- collision = false!
        )
    elseif controlType == "rotate" then
        -- Update rotation
        local newRotation = vector3(state.rotation.x, state.rotation.y, state.rotation.z)

        if axis == 1 then
            newRotation = vector3(state.rotation.x + amount, state.rotation.y, state.rotation.z)
        elseif axis == 2 then
            newRotation = vector3(state.rotation.x, state.rotation.y + amount, state.rotation.z)
        elseif axis == 3 then
            newRotation = vector3(state.rotation.x, state.rotation.y, state.rotation.z + amount)
        end

        -- Check limits
        if config.minimumRotation then
            newRotation = vector3(
                math.max(config.minimumRotation.x, newRotation.x),
                math.max(config.minimumRotation.y, newRotation.y),
                math.max(config.minimumRotation.z, newRotation.z)
            )
        end

        if config.maximumRotation then
            newRotation = vector3(
                math.min(config.maximumRotation.x, newRotation.x),
                math.min(config.maximumRotation.y, newRotation.y),
                math.min(config.maximumRotation.z, newRotation.z)
            )
        end

        state.rotation = newRotation

        -- Apply
        AttachEntityToEntity(
            prop,
            vehicle,
            propData.attachBone,
            state.offset.x, state.offset.y, state.offset.z,
            newRotation.x, newRotation.y, newRotation.z,
            false, false, false, false, 2, true -- collision = false!
        )
    end

    SetPropState(vehicle, propId, state)

    -- Sync to server
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    TriggerServerEvent('D4rk_Smart:SyncProp', netId, propId, state)
end

function ToggleProp(vehicle, propId)
    local propData = GetPropByID(vehicle, propId)
    if not propData then return end

    local state = GetPropState(vehicle, propId)
    if not state then return end

    state.visible = not state.visible
    SetEntityVisible(propData.entity, state.visible, false)

    SetPropState(vehicle, propId, state)

    -- Sync to server
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    TriggerServerEvent('D4rk_Smart:SyncProp', netId, propId, state)

    if Config.Debug then
        print(string.format('^2[Props] Toggled prop %s to %s^7', propId, state.visible and 'visible' or 'hidden'))
    end
end

-- ============================================
-- PROP DETECTION THREAD
-- ============================================
CreateThread(function()
    while true do
        Wait(1000)

        local vehicles = GetGamePool('CVehicle')

        for _, vehicle in ipairs(vehicles) do
            if DoesEntityExist(vehicle) then
                local vehicleName = IsVehicleConfigured(vehicle)

                if vehicleName then
                    local netId = SafeGetNetId(vehicle)
                    if netId then
                        -- Spawn props if not already spawned
                        if not spawnedProps[netId] then
                            SpawnVehicleProps(vehicle, vehicleName)
                        end
                    end
                end
            end
        end

        -- Cleanup deleted vehicles
        local toClean = {}
        for netId, _ in pairs(spawnedProps) do
            if not SafeGetEntity(netId) then
                table.insert(toClean, netId)
            end
        end
        for _, netId in ipairs(toClean) do
            if spawnedProps[netId] then
                for _, propData in ipairs(spawnedProps[netId]) do
                    if propData.entity and DoesEntityExist(propData.entity) then
                        DeleteEntity(propData.entity)
                    end
                end
                spawnedProps[netId] = nil
                propStates[netId] = nil
            end
        end
    end
end)

-- ============================================
-- SYNC EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncPropClient')
AddEventHandler('D4rk_Smart:SyncPropClient', function(netId, propId, state)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    -- Don't sync to self
    if vehicle == currentVehicle then return end

    local propData = GetPropByID(vehicle, propId)
    if not propData then return end

    -- Apply state
    AttachEntityToEntity(
        propData.entity,
        vehicle,
        propData.attachBone,
        state.offset.x, state.offset.y, state.offset.z,
        state.rotation.x, state.rotation.y, state.rotation.z,
        false, false, false, false, 2, true -- collision = false!
    )

    SetEntityVisible(propData.entity, state.visible, false)

    SetPropState(vehicle, propId, state)
end)

-- ============================================
-- CLEANUP ON STOP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for netId, props in pairs(spawnedProps) do
        if props then
            for _, propData in ipairs(props) do
                if propData.entity and DoesEntityExist(propData.entity) then
                    DeleteEntity(propData.entity)
                end
            end
        end
    end
    spawnedProps = {}
    propStates = {}
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('GetVehicleProps', function(vehicle)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    return spawnedProps[netId] or {}
end)

exports('GetPropByID', function(vehicle, propId)
    return GetPropByID(vehicle, propId)
end)

exports('ToggleProp', function(vehicle, propId)
    ToggleProp(vehicle, propId)
end)

exports('SpawnVehicleProps', function(vehicle, vehicleName)
    SpawnVehicleProps(vehicle, vehicleName)
end)

exports('RemoveVehicleProps', function(vehicle)
    RemoveVehicleProps(vehicle)
end)
