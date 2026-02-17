-- D4rk Smart Vehicle - Stabilizers (PROP-BASED)
-- VERSION 2.2 - MULTIPLAYER FIXES + SafeGetNetId + Gravity-Fix
local stabProps = {} -- Spawned stabilizer props per vehicle netId
stabAnimating = {}   -- Animation lock per vehicle (global für main.lua)

-- ============================================
-- SPAWN STABILIZER PROPS
-- ============================================
function SpawnStabilizerProps(vehicle, vehicleName)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
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
            SetEntityCollision(prop, false, false)
            SetEntityNoCollisionEntity(prop, vehicle, false)
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
    stabAnimating[netId] = nil
end

-- ============================================
-- ANIMATE STABILIZERS (smooth aus-/einfahren)
-- ============================================
function AnimateStabilizersProps(vehicle, vehicleName, deploy)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

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
    local liftHeight = stabConfig.liftHeight or 0.4

    stabAnimating[netId] = true

    if deploy then
        -- ===== AUSFAHREN =====
        -- 1. Handbremse + Motor aus
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleHandbrake(vehicle, true)

        -- 2. Original-Position speichern BEVOR wir irgendwas bewegen
        local origCoords = GetEntityCoords(vehicle)
        local origHeading = GetEntityHeading(vehicle)

        -- 3. Stützen-Animation (nur Props, Fahrzeug bleibt still)
        local startTime = GetGameTimer()

        Citizen.CreateThread(function()
            while GetGameTimer() - startTime < duration do
                Wait(16)

                if not stabProps[netId] then
                    stabAnimating[netId] = false
                    return
                end

                local progress = (GetGameTimer() - startTime) / duration
                progress = progress * progress * (3.0 - 2.0 * progress) -- Easing

                for i, propData in pairs(stabProps[netId]) do
                    if propData and propData.entity and DoesEntityExist(propData.entity) then
                        local stab = propData.config
                        local baseOffset = stab.offset or vector3(0.0, 0.0, 0.0)
                        local rotation = stab.rotation or vector3(0.0, 0.0, 0.0)
                        local targetZ = baseOffset.z - (maxExtension * progress)

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
                            false, true, true, false, 2, true
                        )
                    end
                end
            end

            -- 4. Stützen finale Position
            if stabProps[netId] then
                for i, propData in pairs(stabProps[netId]) do
                    if propData and propData.entity and DoesEntityExist(propData.entity) then
                        local stab = propData.config
                        local baseOffset = stab.offset or vector3(0.0, 0.0, 0.0)
                        local rotation = stab.rotation or vector3(0.0, 0.0, 0.0)
                        local finalZ = baseOffset.z - maxExtension

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
                            false, true, true, false, 2, true
                        )

                        propData.currentZ = finalZ
                        propData.deployed = true
                    end
                end
            end

            -- 5. Fahrzeug anheben (GRAVITY-FIX)
            if DoesEntityExist(vehicle) then
                SetEntityHasGravity(vehicle, false)
                SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
                FreezeEntityPosition(vehicle, false)
                Wait(0)
                SetEntityCoordsNoOffset(vehicle,
                    origCoords.x, origCoords.y, origCoords.z + liftHeight,
                    false, false, false)
                SetEntityHeading(vehicle, origHeading)
                Wait(0)
                FreezeEntityPosition(vehicle, true)
                SetEntityHasGravity(vehicle, true)
            end

            if stabConfig.soundEffect then
                PlaySoundEffect(stabConfig.soundEffect)
            end

            stabAnimating[netId] = false
        end)
    else
        -- ===== EINFAHREN =====
        Citizen.CreateThread(function()
            -- 1. Fahrzeug absenken (GRAVITY-FIX)
            if DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(vehicle)
                local heading = GetEntityHeading(vehicle)

                SetEntityHasGravity(vehicle, false)
                SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
                FreezeEntityPosition(vehicle, false)
                Wait(0)
                SetEntityCoordsNoOffset(vehicle,
                    coords.x, coords.y, coords.z - liftHeight,
                    false, false, false)
                SetEntityHeading(vehicle, heading)
                Wait(0)
                -- NICHT einfrieren — Fahrzeug soll sich danach frei bewegen
                SetEntityHasGravity(vehicle, true)
            end

            -- 2. Stützen-Animation zurückfahren
            local startTime = GetGameTimer()

            while GetGameTimer() - startTime < duration do
                Wait(16)

                if not stabProps[netId] then
                    stabAnimating[netId] = false
                    return
                end

                local progress = (GetGameTimer() - startTime) / duration
                progress = progress * progress * (3.0 - 2.0 * progress)

                for i, propData in pairs(stabProps[netId]) do
                    if propData and propData.entity and DoesEntityExist(propData.entity) then
                        local stab = propData.config
                        local baseOffset = stab.offset or vector3(0.0, 0.0, 0.0)
                        local rotation = stab.rotation or vector3(0.0, 0.0, 0.0)
                        local targetZ = (baseOffset.z - maxExtension) + (maxExtension * progress)

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
                            false, true, true, false, 2, true
                        )
                    end
                end
            end

            -- 3. Stützen finale Position (eingezogen)
            if stabProps[netId] then
                for i, propData in pairs(stabProps[netId]) do
                    if propData and propData.entity and DoesEntityExist(propData.entity) then
                        local stab = propData.config
                        local baseOffset = stab.offset or vector3(0.0, 0.0, 0.0)
                        local rotation = stab.rotation or vector3(0.0, 0.0, 0.0)

                        local boneIdx = 0
                        if stab.attachBone and stab.attachBone ~= '' then
                            local idx = GetEntityBoneIndexByName(vehicle, stab.attachBone)
                            if idx ~= -1 then boneIdx = idx end
                        end

                        DetachEntity(propData.entity, false, false)
                        AttachEntityToEntity(
                            propData.entity, vehicle, boneIdx,
                            baseOffset.x, baseOffset.y, baseOffset.z,
                            rotation.x, rotation.y, rotation.z,
                            false, true, true, false, 2, true
                        )

                        propData.currentZ = baseOffset.z
                        propData.deployed = false
                    end
                end
            end

            -- 4. Handbremse lösen, fahrbereit
            SetVehicleHandbrake(vehicle, false)

            if stabConfig.soundEffect then
                PlaySoundEffect(stabConfig.soundEffect)
            end

            stabAnimating[netId] = false
        end)
    end
end

-- ============================================
-- CLEANUP (FIX: SafeGetEntity statt NetworkGetEntityFromNetworkId)
-- ============================================
Citizen.CreateThread(function()
    while true do
        Wait(5000)
        local toRemove = {}
        for netId, _ in pairs(stabProps) do
            if not SafeGetEntity(netId) then
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
