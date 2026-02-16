-- D4rk Smart Vehicle - Collision Objects System
-- Allows players to walk on ladders and other vehicle parts

local spawnedObjects = {}

-- ============================================
-- SPAWN COLLISION OBJECTS
-- ============================================
function SpawnCollisionObjects(vehicle, collisionConfig)
    if not collisionConfig or not collisionConfig.enabled then return end
    if not collisionConfig.objects then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if not spawnedObjects[netId] then
        spawnedObjects[netId] = {}
    end

    for i, objConfig in ipairs(collisionConfig.objects) do
        -- Request model
        local modelHash = GetHashKey(objConfig.model)
        RequestModel(modelHash)

        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        if not HasModelLoaded(modelHash) then
            if Config.Debug then
                print('^3[Collision] Failed to load model: ' .. objConfig.model .. '^7')
            end
            goto continue
        end

        -- Get bone position
        local boneIndex = GetBoneIndex(vehicle, objConfig.bone)
        if boneIndex == -1 then
            if Config.Debug then
                print('^3[Collision] Bone not found: ' .. objConfig.bone .. '^7')
            end
            goto continue
        end

        local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
        local offset = objConfig.offset or vector3(0.0, 0.0, 0.0)

        -- Spawn object
        local object = CreateObject(
            modelHash,
            boneCoords.x + offset.x,
            boneCoords.y + offset.y,
            boneCoords.z + offset.z,
            false, -- networkObject
            true,  -- netMissionEntity
            true   -- doorFlag
        )

        if not DoesEntityExist(object) then
            if Config.Debug then
                print('^3[Collision] Failed to create object^7')
            end
            goto continue
        end

        -- Set properties
        SetEntityCollision(object, true, true)
        FreezeEntityPosition(object, true)
        SetEntityVisible(object, true, false)
        SetEntityAlpha(object, 255, false)

        -- Attach to vehicle if dynamic
        if objConfig.dynamic then
            local rotation = objConfig.rotation or vector3(0.0, 0.0, 0.0)

            AttachEntityToEntity(
                object,
                vehicle,
                boneIndex,
                offset.x, offset.y, offset.z,
                rotation.x, rotation.y, rotation.z,
                false, false, true, false, 2, true
            )
        end

        -- Store reference
        table.insert(spawnedObjects[netId], {
            object = object,
            model = modelHash,
            config = objConfig
        })

        SetModelAsNoLongerNeeded(modelHash)

        ::continue::
    end

    if Config.Debug then
        print('^2[Collision] Spawned ' .. #spawnedObjects[netId] .. ' collision objects for vehicle ' .. netId .. '^7')
    end
end

-- ============================================
-- REMOVE COLLISION OBJECTS
-- ============================================
function RemoveCollisionObjects(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if spawnedObjects[netId] then
        for _, objData in ipairs(spawnedObjects[netId]) do
            if DoesEntityExist(objData.object) then
                DeleteEntity(objData.object)
            end
        end

        spawnedObjects[netId] = nil

        if Config.Debug then
            print('^3[Collision] Removed collision objects for vehicle ' .. netId .. '^7')
        end
    end
end

-- ============================================
-- UPDATE COLLISION OBJECTS
-- ============================================
function UpdateCollisionObjects(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if not spawnedObjects[netId] then return end

    for _, objData in ipairs(spawnedObjects[netId]) do
        if DoesEntityExist(objData.object) and not objData.config.dynamic then
            -- Update position for non-dynamic objects if needed
            local boneIndex = GetBoneIndex(vehicle, objData.config.bone)
            if boneIndex ~= -1 then
                local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
                local offset = objData.config.offset or vector3(0.0, 0.0, 0.0)

                SetEntityCoords(
                    objData.object,
                    boneCoords.x + offset.x,
                    boneCoords.y + offset.y,
                    boneCoords.z + offset.z,
                    false, false, false, false
                )
            end
        end
    end
end

-- ============================================
-- VEHICLE DETECTION THREAD
-- ============================================
CreateThread(function()
    while true do
        Wait(1000) -- Check every second

        local vehicles = GetGamePool('CVehicle')

        for _, vehicle in ipairs(vehicles) do
            local vehicleName = IsVehicleConfigured(vehicle)

            if vehicleName then
                local config = GetVehicleConfig(vehicleName)
                local netId = NetworkGetNetworkIdFromEntity(vehicle)

                -- Spawn collision objects if configured and not already spawned
                if config.collision and config.collision.enabled then
                    if not spawnedObjects[netId] then
                        SpawnCollisionObjects(vehicle, config.collision)
                    end
                end
            end
        end

        -- Cleanup deleted vehicles - direkt mit netId arbeiten
        local toRemove = {}
        for netId, objList in pairs(spawnedObjects) do
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if not DoesEntityExist(vehicle) then
                table.insert(toRemove, netId)
            end
        end

        for _, netId in ipairs(toRemove) do
            if spawnedObjects[netId] then
                for _, objData in ipairs(spawnedObjects[netId]) do
                    if DoesEntityExist(objData.object) then
                        DeleteEntity(objData.object)
                    end
                end
                spawnedObjects[netId] = nil

                if Config.Debug then
                    print('^3[Collision] Cleaned up objects for deleted vehicle ' .. netId .. '^7')
                end
            end
        end
    end
end)

-- ============================================
-- UPDATE THREAD
-- ============================================
CreateThread(function()
    while true do
        Wait(100) -- Update every 100ms

        for netId, _ in pairs(spawnedObjects) do
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(vehicle) then
                UpdateCollisionObjects(vehicle)
            end
        end
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Remove all spawned objects
    for netId, objList in pairs(spawnedObjects) do
        for _, objData in ipairs(objList) do
            if DoesEntityExist(objData.object) then
                DeleteEntity(objData.object)
            end
        end
    end

    spawnedObjects = {}
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('GetCollisionObjects', function(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return spawnedObjects[netId] or {}
end)

exports('ForceSpawnCollision', function(vehicle)
    local vehicleName = IsVehicleConfigured(vehicle)
    if vehicleName then
        local config = GetVehicleConfig(vehicleName)
        if config.collision then
            SpawnCollisionObjects(vehicle, config.collision)
        end
    end
end)

exports('ForceRemoveCollision', function(vehicle)
    RemoveCollisionObjects(vehicle)
end)
