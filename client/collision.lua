-- D4rk Smart Vehicle - Collision Objects (PROP-BASED)
-- VERSION 2.3 - POSITION-FOLLOW statt Attach
-- Props folgen per SetEntityCoords → keine Physik-Übertragung auf Fahrzeug!
local collisionProps = {} -- per vehicle netId

-- ============================================
-- SPAWN COLLISION OBJECTS
-- ============================================
function SpawnCollisionObjects(vehicle, vehicleName)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    if collisionProps[netId] then return end

    local config = GetVehicleConfig(vehicleName)
    if not config or not config.collision or not config.collision.enabled then return end

    collisionProps[netId] = {}
    local vehicleCoords = GetEntityCoords(vehicle)

    for i, obj in ipairs(config.collision.objects) do
        if obj.model and obj.model ~= '' then
            local modelHash = GetHashKey(obj.model)

            if RequestModelSync(modelHash) then
                local prop = CreateObject(modelHash,
                    vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 15.0,
                    false, -- networkObject (lokal, kein Netzwerk nötig)
                    true,  -- netMissionEntity
                    false  -- doorFlag
                )

                if DoesEntityExist(prop) then
                    -- Collision AN für begehbare Objekte
                    SetEntityCollision(prop, true, true)
                    SetEntityInvincible(prop, true)
                    FreezeEntityPosition(prop, true)

                    -- Sichtbarkeit
                    if obj.invisible then
                        SetEntityAlpha(prop, 0, false)
                        SetEntityVisible(prop, false, false)
                    end

                    -- NICHT attachen! Nur speichern
                    collisionProps[netId][i] = {
                        entity = prop,
                        config = obj,
                        vehicle = vehicle
                    }

                    if Config.Debug then
                        print(string.format('[D4rk_Smart] Collision obj #%d spawned (unattached): %s (invisible=%s)',
                            i, obj.model, tostring(obj.invisible or false)))
                    end
                end

                SetModelAsNoLongerNeeded(modelHash)
            end
        end
    end

    -- Position-Thread starten: Props folgen dem Parent OHNE Attach
    StartCollisionFollowThread(netId, vehicle)
end

-- ============================================
-- FOLLOW THREAD: Props folgen per SetEntityCoords
-- Keine Physik-Übertragung auf das Fahrzeug!
-- ============================================
function StartCollisionFollowThread(netId, vehicle)
    Citizen.CreateThread(function()
        while collisionProps[netId] and DoesEntityExist(vehicle) do
            Wait(0) -- Jeden Frame updaten für smooth

            if not collisionProps[netId] then return end

            for i, propData in pairs(collisionProps[netId]) do
                if propData and propData.entity and DoesEntityExist(propData.entity) then
                    local obj = propData.config

                    -- Parent bestimmen (Fahrzeug oder Bone-Prop)
                    local parentEntity = vehicle
                    local attachTo = obj.attachTo or 'vehicle'

                    if attachTo ~= 'vehicle' then
                        local parentIndex = tonumber(attachTo)
                        if parentIndex and spawnedBoneProps[netId] and spawnedBoneProps[netId][parentIndex] then
                            local parentProp = spawnedBoneProps[netId][parentIndex]
                            if parentProp and parentProp.entity and DoesEntityExist(parentProp.entity) then
                                parentEntity = parentProp.entity
                            end
                        end
                    end

                    -- Offset relativ zum Parent in Weltkoordinaten umrechnen
                    local offset = obj.offset or vector3(0.0, 0.0, 0.0)
                    local rotation = obj.rotation or vector3(0.0, 0.0, 0.0)

                    local worldPos = GetOffsetFromEntityInWorldCoords(parentEntity, offset.x, offset.y, offset.z)
                    local parentRot = GetEntityRotation(parentEntity, 2)

                    -- Prop positionieren (KEIN Attach → keine Physik!)
                    SetEntityCoordsNoOffset(propData.entity,
                        worldPos.x, worldPos.y, worldPos.z,
                        false, false, false)

                    SetEntityRotation(propData.entity,
                        parentRot.x + rotation.x,
                        parentRot.y + rotation.y,
                        parentRot.z + rotation.z,
                        2, true)

                    FreezeEntityPosition(propData.entity, true)
                end
            end
        end

        -- Thread beendet (Fahrzeug gelöscht) → Cleanup
        if collisionProps[netId] then
            DeleteCollisionObjects(netId)
        end
    end)
end

-- ============================================
-- DELETE
-- ============================================
function DeleteCollisionObjects(netId)
    if not collisionProps[netId] then return end
    for i, propData in pairs(collisionProps[netId]) do
        if propData and propData.entity and DoesEntityExist(propData.entity) then
            FreezeEntityPosition(propData.entity, false)
            DeleteEntity(propData.entity)
        end
    end
    collisionProps[netId] = nil
end

-- ============================================
-- CLEANUP THREAD
-- ============================================
Citizen.CreateThread(function()
    while true do
        Wait(5000)
        local toRemove = {}
        for netId, _ in pairs(collisionProps) do
            if not SafeGetEntity(netId) then
                table.insert(toRemove, netId)
            end
        end
        for _, netId in ipairs(toRemove) do
            DeleteCollisionObjects(netId)
        end
    end
end)

-- ============================================
-- CLEANUP ON STOP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for netId, _ in pairs(collisionProps) do
        DeleteCollisionObjects(netId)
    end
end)
