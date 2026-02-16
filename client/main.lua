-- D4rk Smart Vehicle - Client Main (Advanced)
currentVehicle = nil
currentVehicleName = nil
currentConfig = nil
vehicleStates = {}
controlActive = false
controlMode = nil
menuOpen = false     -- GLOBAL: Sichtbar in allen Dateien
remoteActive = false -- GLOBAL: Sichtbar in allen Dateien

-- Helpers
function GetTranslation(key)
    return Config.Translations[Config.Locale][key] or key
end

function ShowNotification(msg, type)
    SendNUIMessage({
        action = 'notify',
        message = msg,
        type = type or 'info'
    })
end

function IsVehicleConfigured(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model):lower()

    for vehicleName, _ in pairs(Config.Vehicles) do
        if modelName == vehicleName:lower() or GetHashKey(vehicleName) == model then
            return vehicleName
        end
    end
    return nil
end

function GetVehicleConfig(vehicleName)
    return Config.Vehicles[vehicleName]
end

function GetDistanceToVehicle(vehicle)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicleCoords = GetEntityCoords(vehicle)
    return #(playerCoords - vehicleCoords)
end

-- ============================================
-- BONE MANIPULATION (Real Natives)
-- ============================================
function GetBoneIndex(vehicle, boneName)
    return GetEntityBoneIndexByName(vehicle, boneName)
end

function SetBonePosition(vehicle, boneIndex, x, y, z)
    if boneIndex == -1 then return end

    -- ECHTER Native!
    Citizen.InvokeNative(0xBD8D32550E5CEBFE, vehicle, boneIndex, x, y, z)

    if Config.Debug then
        print(string.format('[Bone] Set position: %d = (%.3f, %.3f, %.3f)', boneIndex, x, y, z))
    end
end

function GetBonePosition(vehicle, boneIndex)
    if boneIndex == -1 then return vector3(0, 0, 0) end

    return Citizen.InvokeNative(0xCE6294A232D03786, vehicle, boneIndex, Citizen.ReturnResultAnyway(),
        Citizen.ReturnResultAnyway(), Citizen.ReturnResultAnyway())
end

function GetBoneRotation(vehicle, boneIndex)
    if boneIndex == -1 then return vector3(0, 0, 0) end

    return Citizen.InvokeNative(0x46F8696933A63C9B, vehicle, boneIndex, Citizen.ReturnResultAnyway(),
        Citizen.ReturnResultAnyway(), Citizen.ReturnResultAnyway())
end

function SetBoneRotation(vehicle, boneIndex, x, y, z)
    if boneIndex == -1 then return end

    -- TRICK: "Rotation" ist oft Position auf anderer Achse!
    -- Z-Rotation = Z-Position, X-Rotation = X-Position, etc.
    SetBonePosition(vehicle, boneIndex, x, y, z)

    if Config.Debug then
        print(string.format('[Bone] Set "rotation" via position: %d = (%.3f, %.3f, %.3f)', boneIndex, x, y, z))
    end
end

function ApplyBoneControl(vehicle, bone, value)
    local boneIndex = GetBoneIndex(vehicle, bone.name)
    if boneIndex == -1 then
        if Config.Debug then
            print('^3[D4rk_Smart] Warning: Bone not found: ' .. bone.name .. '^7')
        end
        return
    end

    if bone.type == 'rotation' then
        local x, y, z = 0.0, 0.0, 0.0

        if bone.axis == 'x' then
            x = value
        elseif bone.axis == 'y' then
            y = value
        elseif bone.axis == 'z' then
            z = value
        end

        SetBoneRotation(vehicle, boneIndex, x, y, z)
    elseif bone.type == 'position' then
        local x, y, z = 0.0, 0.0, 0.0

        if bone.axis == 'x' then
            x = value
        elseif bone.axis == 'y' then
            y = value
        elseif bone.axis == 'z' then
            z = value
        end

        SetBonePosition(vehicle, boneIndex, x, y, z)
    end

    -- Play sound effect
    if bone.soundEffect and Config.SoundEffects[bone.soundEffect] then
        PlaySoundEffect(bone.soundEffect)
    end
end

-- ============================================
-- STATE MANAGEMENT
-- ============================================
function InitializeVehicleState(vehicle, vehicleName)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if not vehicleStates[netId] then
        local config = GetVehicleConfig(vehicleName)

        vehicleStates[netId] = {
            vehicle = vehicle,
            vehicleName = vehicleName,
            config = config,
            controlValues = {},
            stabilizersDeployed = false,
            waterActive = false,
            cageOccupants = {}
        }

        -- Initialize control values
        for i, bone in ipairs(config.bones) do
            vehicleStates[netId].controlValues[i] = bone.default or bone.min or 0.0
        end
    end

    return vehicleStates[netId]
end

function GetVehicleState(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return vehicleStates[netId]
end

-- ============================================
-- CONTROL UPDATE
-- ============================================
function UpdateControl(vehicle, boneIndex, delta)
    local state = GetVehicleState(vehicle)
    if not state then return end

    local bone = state.config.bones[boneIndex]
    if not bone then return end

    -- Calculate new value
    local currentValue = state.controlValues[boneIndex]
    local newValue = currentValue + (delta * bone.speed)

    -- Clamp
    newValue = math.max(bone.min, math.min(bone.max, newValue))

    if newValue ~= currentValue then
        state.controlValues[boneIndex] = newValue

        -- Apply locally
        ApplyBoneControl(vehicle, bone, newValue)

        -- Sync to server
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        TriggerServerEvent('D4rk_Smart:SyncControl', netId, boneIndex, newValue)

        -- Update NUI
        SendNUIMessage({
            action = 'updateControl',
            index = boneIndex,
            value = newValue
        })
    end
end

-- ============================================
-- STABILIZERS
-- ============================================
function ToggleStabilizers(vehicle)
    local state = GetVehicleState(vehicle)
    if not state then return end

    local config = state.config
    if not config.stabilizers or not config.stabilizers.enabled then
        ShowNotification('Dieses Fahrzeug hat keine Stützen', 'warning')
        return
    end

    state.stabilizersDeployed = not state.stabilizersDeployed

    -- Animate stabilizers
    AnimateStabilizers(vehicle, config.stabilizers, state.stabilizersDeployed)

    -- Sync to server
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('D4rk_Smart:SyncStabilizers', netId, state.stabilizersDeployed)

    -- Update NUI
    SendNUIMessage({
        action = 'updateStabilizers',
        deployed = state.stabilizersDeployed
    })

    -- Notification
    if state.stabilizersDeployed then
        ShowNotification(GetTranslation('stabilizers_deployed'), 'success')
    else
        ShowNotification(GetTranslation('stabilizers_retracted'), 'info')
    end
end

function AnimateStabilizers(vehicle, stabConfig, deploy)
    if not stabConfig.bones then return end

    CreateThread(function()
        local startTime = GetGameTimer()
        local duration = 2000 -- 2 seconds animation

        for _, stab in ipairs(stabConfig.bones) do
            local boneIndex = GetBoneIndex(vehicle, stab.name)
            if boneIndex ~= -1 then
                -- Animate extension
                local targetExtension = deploy and stabConfig.maxExtension or 0.0

                -- Simple animation loop
                while GetGameTimer() - startTime < duration do
                    Wait(16) -- ~60fps

                    local progress = (GetGameTimer() - startTime) / duration
                    local currentExtension = targetExtension * progress

                    -- Apply position based on offset
                    if stab.offset then
                        SetBonePosition(vehicle, boneIndex,
                            stab.offset.x * currentExtension,
                            stab.offset.y * currentExtension,
                            stab.offset.z * currentExtension
                        )
                    end
                end
            end
        end

        -- Play sound
        if stabConfig.soundEffect then
            PlaySoundEffect(stabConfig.soundEffect)
        end
    end)
end

function CanUseControls(vehicle)
    local state = GetVehicleState(vehicle)
    if not state then return false end

    local config = state.config

    -- Check if stabilizers required
    if config.stabilizers and config.stabilizers.required then
        if not state.stabilizersDeployed then
            ShowNotification(GetTranslation('stabilizers_required'), 'warning')
            return false
        end
    end

    return true
end

-- ============================================
-- MENU SYSTEM
-- ============================================
function OpenControlPanel(vehicle, vehicleName)
    if not vehicle or not vehicleName then
        print('❌ [D4rk_Smart] OpenControlPanel: vehicle or vehicleName is nil')
        return
    end

    print('=== OPENING CONTROL PANEL ===')
    print('Vehicle: ' .. vehicleName)

    currentVehicle = vehicle
    currentVehicleName = vehicleName
    currentConfig = GetVehicleConfig(vehicleName)

    local state = InitializeVehicleState(vehicle, vehicleName)

    -- Set menu open flag
    menuOpen = true

    -- Starte Control Logic
    local playerPed = PlayerPedId()
    local inVehicle = IsPedInAnyVehicle(playerPed, false)
    local mode = inVehicle and 'inside' or 'standing'

    -- Setze Control Variablen ohne StartControl zu rufen (das würde HUD öffnen)
    currentVehicle = vehicle
    currentVehicleName = vehicleName
    currentConfig = GetVehicleConfig(vehicleName)
    controlMode = mode
    controlActive = true

    -- Notify server
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('D4rk_Smart:StartControl', netId)

    -- Starte Control Thread
    CreateThread(ControlThread)

    -- Open NUI - NUR Maus Focus, Keyboard geht an FiveM!
    SetNuiFocus(true, true)    -- false = Keyboard funktioniert in FiveM!
    SetNuiFocusKeepInput(true) -- Erlaubt Input trotz NUI

    CreateThread(function()
        while menuOpen do
            Wait(0)
            ShowCursorThisFrame() -- Force Maus sichtbar
        end
    end)

    SendNUIMessage({
        action = 'openPanel',
        vehicle = currentConfig
    })
    print('✅ NUI Message sent')

    -- Update current values
    for i, bone in ipairs(currentConfig.bones) do
        SendNUIMessage({
            action = 'updateControl',
            index = i,
            value = state.controlValues[i]
        })
    end

    -- Update stabilizers status
    SendNUIMessage({
        action = 'updateStabilizers',
        deployed = state.stabilizersDeployed
    })

    -- Update mode
    SendNUIMessage({
        action = 'updateMode',
        mode = mode
    })
end

function CloseControlPanel()
    if not menuOpen then
        -- Schon geschlossen, nicht nochmal schließen!
        return
    end

    print('❌ CLOSING PANEL')

    menuOpen = false
    controlActive = false -- Stoppe Control Thread

    -- Notify server
    if currentVehicle then
        local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
        TriggerServerEvent('D4rk_Smart:StopControl', netId)
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'closePanel'
    })
end

function ShowCompactHud()
    if not currentConfig then return end

    SendNUIMessage({
        action = 'showHud',
        vehicle = currentConfig
    })
end

function HideCompactHud()
    SendNUIMessage({
        action = 'hideHud'
    })
end

-- ============================================
-- SOUND SYSTEM
-- ============================================
function PlaySoundEffect(soundName)
    if not Config.SoundEffects[soundName] then return end

    local sound = Config.SoundEffects[soundName]
    PlaySoundFrontend(-1, sound.name, sound.reference, true)
end

-- ============================================
-- RESET
-- ============================================
function ResetAllControls(vehicle)
    local state = GetVehicleState(vehicle)
    if not state then return end

    for i, bone in ipairs(state.config.bones) do
        local defaultValue = bone.default or bone.min or 0.0
        state.controlValues[i] = defaultValue

        ApplyBoneControl(vehicle, bone, defaultValue)

        SendNUIMessage({
            action = 'updateControl',
            index = i,
            value = defaultValue
        })
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('D4rk_Smart:ResetAll', netId)

    ShowNotification('Alle Kontrollen zurückgesetzt', 'info')
end

-- ============================================
-- NUI CALLBACKS
-- ============================================
RegisterNUICallback('closePanel', function(data, cb)
    CloseControlPanel()
    cb('ok')
end)

RegisterNUICallback('toggleStabilizers', function(data, cb)
    if currentVehicle then
        ToggleStabilizers(currentVehicle)
    end
    cb('ok')
end)

RegisterNUICallback('toggleWater', function(data, cb)
    if currentVehicle then
        TriggerEvent('D4rk_Smart:ToggleWater', currentVehicle)
    end
    cb('ok')
end)

RegisterNUICallback('toggleCage', function(data, cb)
    if currentVehicle then
        TriggerEvent('D4rk_Smart:ToggleCage', currentVehicle)
    end
    cb('ok')
end)

RegisterNUICallback('resetAll', function(data, cb)
    if currentVehicle then
        ResetAllControls(currentVehicle)
    end
    cb('ok')
end)

RegisterNUICallback('panelReady', function(data, cb)
    -- Panel is ready
    cb('ok')
end)

-- ============================================
-- SERVER SYNC EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncControlClient')
AddEventHandler('D4rk_Smart:SyncControlClient', function(netId, boneIndex, value)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    local state = GetVehicleState(vehicle)
    if not state then return end

    local bone = state.config.bones[boneIndex]
    if not bone then return end

    state.controlValues[boneIndex] = value
    ApplyBoneControl(vehicle, bone, value)

    -- Update NUI if this is our vehicle
    if vehicle == currentVehicle then
        SendNUIMessage({
            action = 'updateControl',
            index = boneIndex,
            value = value
        })
    end
end)

RegisterNetEvent('D4rk_Smart:SyncStabilizersClient')
AddEventHandler('D4rk_Smart:SyncStabilizersClient', function(netId, deployed)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    local state = GetVehicleState(vehicle)
    if not state then return end

    state.stabilizersDeployed = deployed

    -- Animate if not already done
    AnimateStabilizers(vehicle, state.config.stabilizers, deployed)

    -- Update NUI if this is our vehicle
    if vehicle == currentVehicle then
        SendNUIMessage({
            action = 'updateStabilizers',
            deployed = deployed
        })
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    CloseControlPanel()
    HideCompactHud()
    vehicleStates = {}
    menuOpen = false
    currentVehicle = nil
    currentVehicleName = nil
    currentConfig = nil
    controlActive = false
    controlMode = nil
end)

-- ============================================
-- EMERGENCY MENU CLOSE (Notfall wenn stuck)
-- ============================================
CreateThread(function()
    while true do
        Wait(100) -- Nicht jeden Frame prüfen

        -- WICHTIG: IsControlJustPressed funktioniert nicht richtig mit NUI Focus!
        -- Deaktiviert, da es false positives verursacht
        -- ESC wird stattdessen vom Close Button (X) in der UI gehandled

        --[[
        if menuOpen and IsControlJustPressed(0, 322) then
            print('🔴 ESC gedrückt - schließe Panel')
            CloseControlPanel()
        end
        ]] --
    end
end)

-- ============================================
-- TEST COMMAND
-- ============================================
RegisterCommand('testpanel', function()
    -- Prüfe ob Panel schon offen ist
    if menuOpen then
        print('⚠️ Panel ist bereits offen!')
        return
    end

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then
        print('❌ Du musst in einem Fahrzeug sitzen!')
        return
    end

    local vehicleName = IsVehicleConfigured(vehicle)
    if not vehicleName then
        print('❌ Fahrzeug nicht in Config gefunden!')
        print('Model: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
        return
    end

    print('✅ Fahrzeug gefunden: ' .. vehicleName)
    OpenControlPanel(vehicle, vehicleName)
end, false)

-- ============================================
-- RESET COMMAND (für debugging)
-- ============================================
RegisterCommand('resetmenu', function()
    print('🔄 Reset Menu State')
    menuOpen = false
    remoteActive = false
    CloseControlPanel()
    HideCompactHud()
    print('✅ Menu zurückgesetzt')
end, false)
