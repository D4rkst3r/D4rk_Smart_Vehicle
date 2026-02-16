-- D4rk Smart Vehicle - Stabilizers (PROP-BASED)
local stabProps = {} -- Spawned stabilizer props per vehicle netId
stabAnimating = {}   -- Animation lock per vehicle

-- ============================================
-- SPAWN STABILIZER PROPS
-- ============================================
function SpawnStabilizerProps(vehicle, vehicleName)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if stabProps[netId] then return end

    local config = GetVehicleConfig(vehicleName)
    if not config or not config.stabilizers or not config.stabilizers.enabled then return end

    local stabConfig = config.stabilizers
    if not stabConfig.propModel or stabConfig.propModel == '' then
        if Config.Debug then
            print('[D4rk_Smart] Stabilizers have no propModel - skipped')
        end
        return
    end

    stabProps[netId] = {}
    local vehicleCoords = GetEntityCoords(vehicle)
    local modelHash = GetHashKey(stabConfig.propModel)

    if not RequestModelSync(modelHash) then return end

    for i, stab in ipairs(stabConfig.bones) do
        local prop = CreateObject(modelHash, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 15.0, true, true, false)

        if DoesEntityExist(prop) then
            SetEntityCollision(prop, true, true)
            SetEntityInvincible(prop, true)

            -- Initial: eingefahren (offset 0)
            local baseOffset = stab.offset or vector3(0.0, 0.0, 0.0)

            -- Attach bone am Fahrzeug
            local boneIdx = 0
            if stab.attachBone and stab.attachBone ~= '' then
                local idx = GetEntityBoneIndexByName(vehicle, stab.attachBone)
                if idx ~= -1 then boneIdx = idx end
            end

            local rotation = stab.rotation or vector3(0.0, 0.0, 0.0)

            AttachEntityToEntity(
                prop, vehicle, boneIdx,
                baseOffset.x, baseOffset.y, 0.0, -- Z=0 = eingefahren
                rotation.x, rotation.y, rotation.z,
                false, true, true,
                false, 2, true
            )

            stabProps[netId][i] = {
                entity = prop,
                config = stab,
                deployed = false,
                currentZ = 0.0
            }

            if Config.Debug then
                print(string.format('[D4rk_Smart] Stabilizer #%d (%s) spawned', i, stab.side or '?'))
            end
        end
    end

    SetModelAsNoLongerNeeded(modelHash)
end

function DeleteStabilizerProps(netId)
    if not stabProps[netId] then return end
    for i, propData in pairs(stabProps[netId]) do
        if propData and propData.entity and DoesEntityExist(propData.entity) then
            DetachEntity(propData.entity, false, false)
            DeleteEntity(propData.entity)
        end
    end
    stabProps[netId] = nil
end

-- ============================================
-- ANIMATE STABILIZERS (smooth aus-/einfahren)
-- ============================================
function AnimateStabilizersProps(vehicle, vehicleName, deploy)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not stabProps[netId] then
        SpawnStabilizerProps(vehicle, vehicleName)
    end
    if not stabProps[netId] then return end
    if stabAnimating[netId] then return end

    local config = GetVehicleConfig(vehicleName)
    if not config or not config.stabilizers then return end

    local stabConfig = config.stabilizers
    local maxExtension = stabConfig.maxExtension or 1.5
    local duration = stabConfig.animDuration or 2000
    local liftHeight = stabConfig.liftHeight or 0.4 -- NEU: Wie hoch anheben (Meter)

    -- Startposition merken
    local startCoords = GetEntityCoords(vehicle)
    local startHeading = GetEntityHeading(vehicle)

    stabAnimating[netId] = true

    Citizen.CreateThread(function()
        local startTime = GetGameTimer()

        while GetGameTimer() - startTime < duration do
            Wait(16)

            local progress = (GetGameTimer() - startTime) / duration
            -- Ease in/out
            progress = progress * progress * (3.0 - 2.0 * progress)

            -- ===== Stützen-Props bewegen =====
            for i, propData in pairs(stabProps[netId]) do
                if propData and propData.entity and DoesEntityExist(propData.entity) then
                    local stab = propData.config
                    local baseOffset = stab.offset or vector3(0.0, 0.0, 0.0)
                    local rotation = stab.rotation or vector3(0.0, 0.0, 0.0)

                    local targetZ
                    if deploy then
                        targetZ = baseOffset.z - (maxExtension * progress)
                    else
                        targetZ = (baseOffset.z - maxExtension) + (maxExtension * progress)
                    end

                    local boneIdx = 0
                    if stab.attachBone and stab.attachBone ~= '' then
                        local idx = GetEntityBoneIndexByName(vehicle, stab.attachBone)
                        if idx ~= -1 then boneIdx = idx end
                    end

                    DetachEntity(propData.entity, false, false)
                    AttachEntityToEntity(
                        propData.entity, vehicle, boneIdx,
                        baseOffset.x, baseOffset.y, targetZ,
                        rotation.x, rotation.y, rotation.z,
                        false, true, true,
                        false, 2, true
                    )

                    propData.currentZ = targetZ
                    propData.deployed = deploy
                end
            end

            -- ===== NEU: Fahrzeug anheben/absenken =====
            local currentLift
            if deploy then
                currentLift = liftHeight * progress
            else
                currentLift = liftHeight * (1.0 - progress)
            end

            SetEntityCoords(
                vehicle,
                startCoords.x,
                startCoords.y,
                startCoords.z + currentLift,
                false, false, false, false
            )
            SetEntityHeading(vehicle, startHeading)
        end

        -- ===== Finale Position sicherstellen =====
        for i, propData in pairs(stabProps[netId]) do
            if propData and propData.entity and DoesEntityExist(propData.entity) then
                local stab = propData.config
                local baseOffset = stab.offset or vector3(0.0, 0.0, 0.0)
                local rotation = stab.rotation or vector3(0.0, 0.0, 0.0)
                local finalZ = deploy and (baseOffset.z - maxExtension) or baseOffset.z

                local boneIdx = 0
                if stab.attachBone and stab.attachBone ~= '' then
                    local idx = GetEntityBoneIndexByName(vehicle, stab.attachBone)
                    if idx ~= -1 then boneIdx = idx end
                end

                DetachEntity(propData.entity, false, false)
                AttachEntityToEntity(
                    propData.entity, vehicle, boneIdx,
                    baseOffset.x, baseOffset.y, finalZ,
                    rotation.x, rotation.y, rotation.z,
                    false, true, true,
                    false, 2, true
                )

                propData.currentZ = finalZ
                propData.deployed = deploy
            end
        end

        -- Finale Fahrzeug-Position
        local finalLift = deploy and liftHeight or 0.0
        SetEntityCoords(
            vehicle,
            startCoords.x,
            startCoords.y,
            startCoords.z + finalLift,
            false, false, false, false
        )
        SetEntityHeading(vehicle, startHeading)

        -- JETZT erst einfrieren (nach dem Anheben!)
        FreezeEntityPosition(vehicle, deploy)

        if stabConfig.soundEffect then
            PlaySoundEffect(stabConfig.soundEffect)
        end

        stabAnimating[netId] = false
    end)
end

-- ============================================
-- CLEANUP
-- ============================================
Citizen.CreateThread(function()
    while true do
        Wait(5000)
        local toRemove = {}
        for netId, _ in pairs(stabProps) do
            local veh = NetworkGetEntityFromNetworkId(netId)
            if not DoesEntityExist(veh) then
                table.insert(toRemove, netId)
            end
        end
        for _, netId in ipairs(toRemove) do
            DeleteStabilizerProps(netId)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for netId, _ in pairs(stabProps) do
        DeleteStabilizerProps(netId)
    end
end)
