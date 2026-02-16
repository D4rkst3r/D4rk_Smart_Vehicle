-- D4rk Smart Vehicle - Stabilizers (PROP-BASED)
local stabProps = {} -- Spawned stabilizer props per vehicle netId
stabAnimating = {}   -- Animation lock per vehicle

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
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleHandbrake(vehicle, true)

        -- Original-Position JETZT speichern (vor dem Anheben!)
        local origCoords = GetEntityCoords(vehicle)
        local origHeading = GetEntityHeading(vehicle)

        -- Stützen-Animation
        local startTime = GetGameTimer()

        Citizen.CreateThread(function()
            while GetGameTimer() - startTime < duration do
                Wait(16)

                local progress = (GetGameTimer() - startTime) / duration
                progress = progress * progress * (3.0 - 2.0 * progress)

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

            -- Finale Stützen-Position
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
                        baseOffset.x, baseOffset.y, baseOffset.z - maxExtension,
                        rotation.x, rotation.y, rotation.z,
                        false, true, true, false, 2, true
                    )

                    propData.currentZ = baseOffset.z - maxExtension
                    propData.deployed = true
                end
            end

            -- Anheben: Gravity aus → Position setzen → Freeze
            SetEntityHasGravity(vehicle, false)
            SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
            FreezeEntityPosition(vehicle, false)
            Wait(0)
            SetEntityCoordsNoOffset(vehicle, origCoords.x, origCoords.y, origCoords.z + liftHeight, false, false, false)
            SetEntityHeading(vehicle, origHeading)
            Wait(0)
            FreezeEntityPosition(vehicle, true)
            SetEntityHasGravity(vehicle, true)

            -- Original-Coords speichern für sauberes Absenken
            if not stabProps[netId] then stabProps[netId] = {} end
            stabProps[netId].origCoords = origCoords
            stabProps[netId].origHeading = origHeading

            if stabConfig.soundEffect then
                PlaySoundEffect(stabConfig.soundEffect)
            end

            stabAnimating[netId] = false
        end)
    else
        -- ===== EINFAHREN =====
        Citizen.CreateThread(function()
            -- Gespeicherte Original-Position nutzen (NICHT relativ rechnen!)
            local origCoords = stabProps[netId] and stabProps[netId].origCoords
            local origHeading = stabProps[netId] and stabProps[netId].origHeading

            -- Absenken: Zurück auf Original-Position
            if origCoords then
                SetEntityHasGravity(vehicle, false)
                SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
                FreezeEntityPosition(vehicle, false)
                Wait(0)
                SetEntityCoordsNoOffset(vehicle, origCoords.x, origCoords.y, origCoords.z, false, false, false)
                if origHeading then SetEntityHeading(vehicle, origHeading) end
                Wait(0)
            else
                FreezeEntityPosition(vehicle, false)
                Wait(0)
            end

            -- Gravity wieder an, Physik laufen lassen
            SetEntityHasGravity(vehicle, true)

            -- Stützen-Animation zurückfahren
            local startTime = GetGameTimer()

            while GetGameTimer() - startTime < duration do
                Wait(16)

                local progress = (GetGameTimer() - startTime) / duration
                progress = progress * progress * (3.0 - 2.0 * progress)

                for i, propData in pairs(stabProps[netId]) do
                    if type(i) ~= 'number' then goto skipRetract end -- origCoords überspringen!
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
                    ::skipRetract::
                end
            end

            -- Finale Position (eingezogen)
            for i, propData in pairs(stabProps[netId]) do
                if type(i) ~= 'number' then goto skipFinal end
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
                ::skipFinal::
            end

            -- Handbremse lösen
            SetVehicleHandbrake(vehicle, false)

            -- Gespeicherte Coords löschen
            if stabProps[netId] then
                stabProps[netId].origCoords = nil
                stabProps[netId].origHeading = nil
            end

            if stabConfig.soundEffect then
                PlaySoundEffect(stabConfig.soundEffect)
            end

            stabAnimating[netId] = false
        end)
    end
end

-- ============================================
-- CLEANUP
-- ============================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for netId, _ in pairs(stabProps) do
        DeleteStabilizerProps(netId)
    end
end)
