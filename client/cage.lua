-- D4rk Smart Vehicle - Cage/Basket System
local inCage = false
local currentCage = nil
local currentCageVehicle = nil
local cageAttachOffset = nil

-- ============================================
-- CAGE ENTER/EXIT
-- ============================================
function EnterCage(vehicle, cageConfig)
    if inCage then
        ShowNotification('Du bist bereits in einem Korb', 'warning')
        return
    end
    
    local state = GetVehicleState(vehicle)
    if not state then return end
    
    -- Check if cage is full
    local occupants = #state.cageOccupants
    if occupants >= cageConfig.maxOccupants then
        ShowNotification(GetTranslation('cage_full'), 'warning')
        return
    end
    
    local playerPed = PlayerPedId()
    local playerServerId = GetPlayerServerId(PlayerId())
    
    -- Get cage bone position
    local boneIndex = GetBoneIndex(vehicle, cageConfig.bone)
    if boneIndex == -1 then
        ShowNotification('Korb-Bone nicht gefunden', 'error')
        return
    end
    
    local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    
    -- Check distance
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - boneCoords)
    
    if distance > cageConfig.enterDistance then
        ShowNotification(GetTranslation('cage_too_far'), 'warning')
        return
    end
    
    -- Attach player to cage
    local offset = cageConfig.offset or vector3(0.0, 0.0, 0.5)
    local rotation = cageConfig.rotation or vector3(0.0, 0.0, 0.0)
    
    AttachEntityToEntity(
        playerPed,
        vehicle,
        boneIndex,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, false, false, false, 2, true
    )
    
    -- Set state
    inCage = true
    currentCage = cageConfig
    currentCageVehicle = vehicle
    cageAttachOffset = offset
    
    -- Add to occupants
    table.insert(state.cageOccupants, playerServerId)
    
    -- Sync to server
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('D4rk_Smart:EnterCage', netId)
    
    -- Update NUI
    SendNUIMessage({
        action = 'updateCage',
        inCage = true,
        occupants = #state.cageOccupants,
        maxOccupants = cageConfig.maxOccupants
    })
    
    SendNUIMessage({
        action = 'updateMode',
        mode = 'cage'
    })
    
    ShowNotification(GetTranslation('cage_entered'), 'success')
    
    -- Start cage thread
    CreateThread(CageThread)
end

function ExitCage()
    if not inCage then return end
    
    local playerPed = PlayerPedId()
    
    -- Detach player
    DetachEntity(playerPed, true, true)
    
    -- Place player on ground
    local coords = GetEntityCoords(playerPed)
    local groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    
    if groundZ and groundZ > 0 then
        SetEntityCoords(playerPed, coords.x, coords.y, groundZ + 1.0, false, false, false, false)
    end
    
    -- Remove from occupants
    if currentCageVehicle then
        local state = GetVehicleState(currentCageVehicle)
        if state then
            local playerServerId = GetPlayerServerId(PlayerId())
            for i, occupant in ipairs(state.cageOccupants) do
                if occupant == playerServerId then
                    table.remove(state.cageOccupants, i)
                    break
                end
            end
            
            -- Sync to server
            local netId = NetworkGetNetworkIdFromEntity(currentCageVehicle)
            TriggerServerEvent('D4rk_Smart:ExitCage', netId)
            
            -- Update NUI
            SendNUIMessage({
                action = 'updateCage',
                inCage = false,
                occupants = #state.cageOccupants,
                maxOccupants = currentCage.maxOccupants
            })
        end
    end
    
    -- Reset state
    inCage = false
    currentCage = nil
    currentCageVehicle = nil
    cageAttachOffset = nil
    
    SendNUIMessage({
        action = 'updateMode',
        mode = controlMode or 'standing'
    })
    
    ShowNotification(GetTranslation('cage_exited'), 'info')
end

-- ============================================
-- CAGE THREAD
-- ============================================
function CageThread()
    while inCage and currentCageVehicle do
        Wait(0)
        
        -- Check if vehicle still exists
        if not DoesEntityExist(currentCageVehicle) then
            ExitCage()
            break
        end
        
        -- Check if player pressed exit key
        if IsControlJustPressed(0, Config.Keys.ExitCage) then
            ExitCage()
            break
        end
        
        -- Allow control from cage
        if currentCage.canControl then
            -- Player can still control vehicle systems from cage
            -- Handle controls here if needed
        end
        
        -- Disable certain controls
        DisableControlAction(0, 23, true) -- F (Enter Vehicle)
        DisableControlAction(0, 75, true) -- F (Exit Vehicle)
        
        -- Show exit hint
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(GetTranslation('cage_exit'))
        EndTextCommandDisplayHelp(0, false, true, -1)
    end
end

-- ============================================
-- CAGE DETECTION
-- ============================================
function CheckCageProximity()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Don't check if already in cage
    if inCage then return end
    
    -- Check nearby vehicles
    local vehicles = GetGamePool('CVehicle')
    
    for _, vehicle in ipairs(vehicles) do
        local vehicleName = IsVehicleConfigured(vehicle)
        if vehicleName then
            local config = GetVehicleConfig(vehicleName)
            
            if config.cage and config.cage.enabled then
                local boneIndex = GetBoneIndex(vehicle, config.cage.bone)
                if boneIndex ~= -1 then
                    local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
                    local distance = #(playerCoords - boneCoords)
                    
                    if distance < config.cage.enterDistance then
                        -- Show prompt
                        SendNUIMessage({
                            action = 'showCagePrompt',
                            show = true
                        })
                        
                        -- Check for input
                        if IsControlJustPressed(0, Config.Keys.EnterCage) then
                            EnterCage(vehicle, config.cage)
                        end
                        
                        return
                    end
                end
            end
        end
    end
    
    -- Hide prompt if nothing nearby
    SendNUIMessage({
        action = 'showCagePrompt',
        show = false
    })
end

-- ============================================
-- EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:ToggleCage')
AddEventHandler('D4rk_Smart:ToggleCage', function(vehicle)
    if inCage then
        ExitCage()
    else
        local vehicleName = IsVehicleConfigured(vehicle)
        if vehicleName then
            local config = GetVehicleConfig(vehicleName)
            if config.cage and config.cage.enabled then
                EnterCage(vehicle, config.cage)
            end
        end
    end
end)

RegisterNetEvent('D4rk_Smart:SyncCageClient')
AddEventHandler('D4rk_Smart:SyncCageClient', function(netId, occupants)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end
    
    local state = GetVehicleState(vehicle)
    if state then
        -- Update occupants list (simplified)
        if vehicle == currentCageVehicle then
            SendNUIMessage({
                action = 'updateCage',
                inCage = inCage,
                occupants = occupants,
                maxOccupants = currentCage and currentCage.maxOccupants or 2
            })
        end
    end
end)

-- ============================================
-- CAGE PROXIMITY THREAD
-- ============================================
CreateThread(function()
    while true do
        Wait(500)
        
        if not IsPedInAnyVehicle(PlayerPedId(), false) and not inCage then
            CheckCageProximity()
        else
            SendNUIMessage({
                action = 'showCagePrompt',
                show = false
            })
        end
    end
end)

-- ============================================
-- COMMANDS
-- ============================================
RegisterCommand('entercage', function()
    if inCage then
        ShowNotification('Du bist bereits in einem Korb', 'warning')
        return
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Find closest vehicle with cage
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = nil
    local closestDistance = 999999
    local closestConfig = nil
    
    for _, vehicle in ipairs(vehicles) do
        local vehicleName = IsVehicleConfigured(vehicle)
        if vehicleName then
            local config = GetVehicleConfig(vehicleName)
            
            if config.cage and config.cage.enabled then
                local boneIndex = GetBoneIndex(vehicle, config.cage.bone)
                if boneIndex ~= -1 then
                    local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
                    local distance = #(playerCoords - boneCoords)
                    
                    if distance < config.cage.enterDistance and distance < closestDistance then
                        closestVehicle = vehicle
                        closestDistance = distance
                        closestConfig = config.cage
                    end
                end
            end
        end
    end
    
    if closestVehicle then
        local vehicleName = IsVehicleConfigured(closestVehicle)
        EnterCage(closestVehicle, closestConfig)
        
        if Config.Debug then
            print(string.format('^2[Cage] Entered cage via command: %s^7', vehicleName))
        end
    else
        ShowNotification('Kein Korb in der Nähe', 'warning')
    end
end, false)

RegisterCommand('exitcage', function()
    if inCage then
        ExitCage()
        
        if Config.Debug then
            print('^3[Cage] Exited cage via command^7')
        end
    else
        ShowNotification('Du bist nicht in einem Korb', 'warning')
    end
end, false)

-- ============================================
-- EXPORTS
-- ============================================
exports('IsInCage', function()
    return inCage
end)

exports('GetCurrentCageVehicle', function()
    return currentCageVehicle
end)
