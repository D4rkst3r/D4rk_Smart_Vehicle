-- D4rk Smart Vehicle - Water Monitor System (PROP-BASED)
local waterProps = {}
local waterActive = {}
local waterParticles = {}

-- ============================================
-- WATER PROP SPAWNING
-- ============================================
function SpawnWaterProp(vehicle, vehicleName)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if waterProps[netId] then return waterProps[netId] end

    local config = GetVehicleConfig(vehicleName)
    if not config or not config.waterMonitor or not config.waterMonitor.enabled then return nil end

    local water = config.waterMonitor
    if not water.propModel or water.propModel == '' then
        -- Kein Prop → unsichtbarer Wasserwerfer (Particle-only)
        -- Wir brauchen trotzdem einen Referenzpunkt
        waterProps[netId] = { entity = nil, config = water }
        return waterProps[netId]
    end

    local modelHash = GetHashKey(water.propModel)
    if not RequestModelSync(modelHash) then return nil end

    local vehicleCoords = GetEntityCoords(vehicle)
    local prop = CreateObject(modelHash, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 10.0, true, true, false)

    if not DoesEntityExist(prop) then return nil end

    SetEntityCollision(prop, false, false)
    SetEntityInvincible(prop, true)
    SetModelAsNoLongerNeeded(modelHash)

    -- Attach
    local targetEntity, targetBoneIdx = GetWaterAttachTarget(vehicle, netId, water)
    local offset = water.offset or vector3(0.0, 1.0, 0.3)
    local rotation = water.rotation or vector3(0.0, 0.0, 0.0)

    AttachEntityToEntity(
        prop, targetEntity, targetBoneIdx,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, true, false, false, 2, true
    )

    waterProps[netId] = {
        entity = prop,
        config = water
    }

    if Config.Debug then
        print('[D4rk_Smart] Water prop spawned: ' .. water.propModel)
    end

    return waterProps[netId]
end

function GetWaterAttachTarget(vehicle, netId, waterConfig)
    local attachTo = waterConfig.attachTo or 'vehicle'

    if attachTo == 'vehicle' then
        local boneIdx = 0
        if waterConfig.attachBone and waterConfig.attachBone ~= '' then
            local idx = GetEntityBoneIndexByName(vehicle, waterConfig.attachBone)
            if idx ~= -1 then boneIdx = idx end
        end
        return vehicle, boneIdx
    else
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

function DeleteWaterProp(netId)
    StopWater(netId)
    if not waterProps[netId] then return end
    if waterProps[netId].entity and DoesEntityExist(waterProps[netId].entity) then
        DetachEntity(waterProps[netId].entity, false, false)
        DeleteEntity(waterProps[netId].entity)
    end
    waterProps[netId] = nil
end

-- ============================================
-- WATER TOGGLE
-- ============================================
function ToggleWater(vehicle, vehicleName)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if waterActive[netId] then
        StopWater(netId)
        ShowNotification('Wasserwerfer AUS', 'info')
    else
        StartWater(vehicle, vehicleName, netId)
        ShowNotification('Wasserwerfer AN', 'success')
    end

    -- Sync
    TriggerServerEvent('D4rk_Smart:SyncWater', netId, waterActive[netId] or false)
end

function StartWater(vehicle, vehicleName, netId)
    -- Spawn prop if needed
    local waterData = waterProps[netId] or SpawnWaterProp(vehicle, vehicleName)
    if not waterData then return end

    waterActive[netId] = true

    local water = waterData.config

    -- Get the entity to emit particles from
    local emitterEntity = waterData.entity or vehicle

    -- Start particle effect
    local ptfxDict = water.particleEffect or 'core'
    local ptfxName = water.particleName or 'water_cannon_jet'

    RequestNamedPtfxAsset(ptfxDict)
    local startTime = GetGameTimer()
    while not HasNamedPtfxAssetLoaded(ptfxDict) do
        Wait(10)
        if GetGameTimer() - startTime > 3000 then
            print('^1[D4rk_Smart] PTFX load timeout^7')
            return
        end
    end

    UseParticleFxAssetNextCall(ptfxDict)

    local particle = StartParticleFxLoopedOnEntity(
        ptfxName,
        emitterEntity,
        0.0, 1.0, 0.0, -- Offset (vorne)
        0.0, 0.0, 0.0, -- Rotation
        water.pressure or 1.5,
        false, false, false
    )

    waterParticles[netId] = particle

    if Config.Debug then
        print('[D4rk_Smart] Water started, particle: ' .. tostring(particle))
    end

    -- Start water effects thread
    Citizen.CreateThread(function()
        while waterActive[netId] do
            Wait(100)

            if not DoesEntityExist(emitterEntity) then
                StopWater(netId)
                break
            end

            -- Raycast for fire extinguishing
            local emitterCoords = GetEntityCoords(emitterEntity)
            local forwardVector = GetEntityForwardVector(emitterEntity)
            local range = water.range or 30.0

            local endCoords = emitterCoords + (forwardVector * range)

            local rayHandle = StartShapeTestRay(
                emitterCoords.x, emitterCoords.y, emitterCoords.z,
                endCoords.x, endCoords.y, endCoords.z,
                -1, vehicle, 7
            )

            local _, hit, hitCoords, _, entityHit = GetShapeTestResult(rayHandle)

            if hit then
                -- Feuer löschen
                StopFireInRange(hitCoords.x, hitCoords.y, hitCoords.z, 5.0)

                -- Entities wegschieben
                if entityHit and DoesEntityExist(entityHit) then
                    if IsEntityAPed(entityHit) or IsEntityAVehicle(entityHit) then
                        local force = water.pressure or 1.5
                        ApplyForceToEntity(
                            entityHit, 3,
                            forwardVector.x * force,
                            forwardVector.y * force,
                            forwardVector.z * force,
                            0.0, 0.0, 0.0,
                            0, false, true, true, false, true
                        )
                    end
                end
            end
        end
    end)
end

function StopWater(netId)
    waterActive[netId] = false

    if waterParticles[netId] then
        StopParticleFxLooped(waterParticles[netId], false)
        waterParticles[netId] = nil
    end
end

-- ============================================
-- EVENT HANDLER
-- ============================================
RegisterNetEvent('D4rk_Smart:ToggleWater')
AddEventHandler('D4rk_Smart:ToggleWater', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local vehicleName = IsVehicleConfigured(vehicle)
    if vehicleName then
        ToggleWater(vehicle, vehicleName)
    end
end)

RegisterNetEvent('D4rk_Smart:SyncWaterClient')
AddEventHandler('D4rk_Smart:SyncWaterClient', function(netId, active)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    if active then
        local vehicleName = IsVehicleConfigured(vehicle)
        if vehicleName then
            StartWater(vehicle, vehicleName, netId)
        end
    else
        StopWater(netId)
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for netId, _ in pairs(waterProps) do
        DeleteWaterProp(netId)
    end
end)
