-- D4rk Smart Vehicle - Collision Objects (PROP-BASED)
-- Begehbare Objekte die an der Prop-Kette hängen
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
                local prop = CreateObject(modelHash, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 15.0, true, true,
                    false)

                if DoesEntityExist(prop) then
                    -- WICHTIG: Collision AN für begehbare Objekte!
                    SetEntityCollision(prop, true, true)
                    SetEntityInvincible(prop, true)

                    -- Sichtbarkeit
                    if obj.invisible then
                        SetEntityAlpha(prop, 0, false)
                        SetEntityVisible(prop, false, false)
                    end

                    -- Attach target bestimmen
                    local targetEntity, targetBoneIdx = GetCollisionAttachTarget(vehicle, netId, obj)

                    local offset = obj.offset or vector3(0.0, 0.0, 0.0)
                    local rotation = obj.rotation or vector3(0.0, 0.0, 0.0)

                    AttachEntityToEntity(
                        prop, targetEntity, targetBoneIdx,
                        offset.x, offset.y, offset.z,
                        rotation.x, rotation.y, rotation.z,
                        false, true, true, -- collision = true!
                        false, 2, true
                    )

                    collisionProps[netId][i] = {
                        entity = prop,
                        config = obj
                    }

                    if Config.Debug then
                        print(string.format('[D4rk_Smart] Collision obj #%d spawned: %s (collision=%s)',
                            i, obj.model, tostring(not obj.invisible)))
                    end
                end

                SetModelAsNoLongerNeeded(modelHash)
            end
        end
    end
end

function GetCollisionAttachTarget(vehicle, netId, objConfig)
    local attachTo = objConfig.attachTo or 'vehicle'

    if attachTo == 'vehicle' then
        local boneIdx = 0
        if objConfig.attachBone and objConfig.attachBone ~= '' then
            local idx = GetEntityBoneIndexByName(vehicle, objConfig.attachBone)
            if idx ~= -1 then boneIdx = idx end
        end
        return vehicle, boneIdx
    else
        -- An Bone-Prop hängen
        local parentIndex = tonumber(attachTo)
        if parentIndex and spawnedBoneProps[netId] and spawnedBoneProps[netId][parentIndex] then
            local parentProp = spawnedBoneProps[netId][parentIndex]
            if parentProp and parentProp.entity and DoesEntityExist(parentProp.entity) then
                return parentProp.entity, 0
            end
        end
        return vehicle, 0
    end
end

function DeleteCollisionObjects(netId)
    if not collisionProps[netId] then return end
    for i, propData in pairs(collisionProps[netId]) do
        if propData and propData.entity and DoesEntityExist(propData.entity) then
            DetachEntity(propData.entity, false, false)
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
