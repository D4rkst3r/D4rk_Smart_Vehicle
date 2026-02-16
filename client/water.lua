-- D4rk Smart Vehicle - Water Monitor System
local waterActive = false
local currentWaterVehicle = nil
local currentWaterConfig = nil
local waterParticle = nil

-- ============================================
-- WATER MONITOR ACTIVATION
-- ============================================
function ActivateWaterMonitor(vehicle, waterConfig)
    if waterActive then
        DeactivateWaterMonitor()
        return
    end
    
    local state = GetVehicleState(vehicle)
    if not state then return end
    
    -- Check if stabilizers required and deployed
    if state.config.stabilizers and state.config.stabilizers.required then
        if not state.stabilizersDeployed then
            ShowNotification('Stützen müssen ausgefahren sein', 'warning')
            return
        end
    end
    
    -- Get bone position
    local boneIndex = GetBoneIndex(vehicle, waterConfig.bone)
    if boneIndex == -1 then
        ShowNotification('Water Monitor Bone nicht gefunden', 'error')
        return
    end
    
    -- Request particle effect
    local particleDict = waterConfig.particleEffect or 'core'
    RequestNamedPtfxAsset(particleDict)
    
    local timeout = 0
    while not HasNamedPtfxAssetLoaded(particleDict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not HasNamedPtfxAssetLoaded(particleDict) then
        ShowNotification('Particle Effect konnte nicht geladen werden', 'error')
        return
    end
    
    -- Start particle effect
    UseParticleFxAsset(particleDict)
    
    local offset = waterConfig.offset or vector3(0.0, 1.0, 0.3)
    local rotation = waterConfig.rotation or vector3(0.0, 0.0, 0.0)
    local scale = waterConfig.pressure or 1.5
    
    waterParticle = StartParticleFxLoopedOnEntityBone(
        waterConfig.particleName or 'water_cannon_jet',
        vehicle,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        boneIndex,
        scale,
        false, false, false
    )
    
    -- Set state
    waterActive = true
    currentWaterVehicle = vehicle
    currentWaterConfig = waterConfig
    state.waterActive = true
    
    -- Sync to server
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('D4rk_Smart:SyncWater', netId, true)
    
    -- Update NUI
    SendNUIMessage({
        action = 'updateWater',
        active = true
    })
    
    ShowNotification(GetTranslation('water_activated'), 'success')
    
    -- Play sound
    if waterConfig.soundEffect then
        PlaySoundEffect(waterConfig.soundEffect)
    end
    
    -- Start water control thread
    CreateThread(WaterControlThread)
end

function DeactivateWaterMonitor()
    if not waterActive then return end
    
    -- Stop particle effect
    if waterParticle then
        StopParticleFxLooped(waterParticle, false)
        waterParticle = nil
    end
    
    -- Update state
    if currentWaterVehicle then
        local state = GetVehicleState(currentWaterVehicle)
        if state then
            state.waterActive = false
            
            -- Sync to server
            local netId = NetworkGetNetworkIdFromEntity(currentWaterVehicle)
            TriggerServerEvent('D4rk_Smart:SyncWater', netId, false)
        end
    end
    
    -- Reset
    waterActive = false
    currentWaterVehicle = nil
    currentWaterConfig = nil
    
    -- Update NUI
    SendNUIMessage({
        action = 'updateWater',
        active = false
    })
    
    ShowNotification(GetTranslation('water_deactivated'), 'info')
end

-- ============================================
-- WATER CONTROL THREAD
-- ============================================
function WaterControlThread()
    while waterActive and currentWaterVehicle do
        Wait(0)
        
        -- Check if vehicle still exists
        if not DoesEntityExist(currentWaterVehicle) then
            DeactivateWaterMonitor()
            break
        end
        
        -- Toggle with key
        if IsControlJustPressed(0, Config.Keys.ToggleWater) then
            DeactivateWaterMonitor()
            break
        end
        
        -- Optional: Rotate water monitor
        if currentWaterConfig.canRotate then
            -- Allow player to rotate the water stream
            -- Could be implemented with additional controls
        end
        
        -- Show hint
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(GetTranslation('water_toggle'))
        EndTextCommandDisplayHelp(0, false, true, -1)
    end
end

-- ============================================
-- WATER DAMAGE/EFFECTS
-- ============================================
function ApplyWaterEffects()
    if not waterActive or not currentWaterVehicle then return end
    
    -- Get water direction
    local boneIndex = GetBoneIndex(currentWaterVehicle, currentWaterConfig.bone)
    if boneIndex == -1 then return end
    
    local boneCoords = GetWorldPositionOfEntityBone(currentWaterVehicle, boneIndex)
    local boneMatrix = GetWorldRotationOfEntityBone(currentWaterVehicle, boneIndex)
    
    -- Calculate forward vector
    local forwardX = boneMatrix.x
    local forwardY = boneMatrix.y
    local forwardZ = boneMatrix.z
    
    local range = currentWaterConfig.range or 30.0
    local endCoords = vector3(
        boneCoords.x + (forwardX * range),
        boneCoords.y + (forwardY * range),
        boneCoords.z + (forwardZ * range)
    )
    
    -- Raycast
    local rayHandle = StartShapeTestRay(
        boneCoords.x, boneCoords.y, boneCoords.z,
        endCoords.x, endCoords.y, endCoords.z,
        -1,
        currentWaterVehicle,
        7
    )
    
    local _, hit, hitCoords, _, entityHit = GetShapeTestResult(rayHandle)
    
    if hit and entityHit then
        -- Check if fire
        if IsEntityOnFire(entityHit) then
            -- Extinguish fire
            StopFireInRange(hitCoords.x, hitCoords.y, hitCoords.z, 5.0)
        end
        
        -- Push entities (optional)
        if IsEntityAPed(entityHit) or IsEntityAVehicle(entityHit) then
            local force = currentWaterConfig.pressure or 1.5
            ApplyForceToEntity(
                entityHit,
                3,
                forwardX * force, forwardY * force, forwardZ * force,
                0.0, 0.0, 0.0,
                0, false, true, true, false, true
            )
        end
    end
end

-- ============================================
-- WATER EFFECTS THREAD
-- ============================================
CreateThread(function()
    while true do
        Wait(100)
        
        if waterActive then
            ApplyWaterEffects()
        end
    end
end)

-- ============================================
-- EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:ToggleWater')
AddEventHandler('D4rk_Smart:ToggleWater', function(vehicle)
    local vehicleName = IsVehicleConfigured(vehicle)
    if not vehicleName then return end
    
    local config = GetVehicleConfig(vehicleName)
    if not config.waterMonitor or not config.waterMonitor.enabled then
        ShowNotification('Dieses Fahrzeug hat keinen Wasserwerfer', 'warning')
        return
    end
    
    if waterActive and currentWaterVehicle == vehicle then
        DeactivateWaterMonitor()
    else
        ActivateWaterMonitor(vehicle, config.waterMonitor)
    end
end)

RegisterNetEvent('D4rk_Smart:SyncWaterClient')
AddEventHandler('D4rk_Smart:SyncWaterClient', function(netId, active)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end
    
    -- Don't sync to self (we're already handling it)
    if vehicle == currentWaterVehicle then return end
    
    local state = GetVehicleState(vehicle)
    if state then
        state.waterActive = active
        
        -- Could activate particle effect for other players too
        -- But typically only the controller sees it
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if waterActive then
        DeactivateWaterMonitor()
    end
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('IsWaterActive', function()
    return waterActive
end)

exports('GetWaterVehicle', function()
    return currentWaterVehicle
end)
