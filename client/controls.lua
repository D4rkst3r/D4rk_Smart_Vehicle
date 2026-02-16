-- D4rk Smart Vehicle - Advanced Controls
local activeControl = false
local remoteActive = false

-- ============================================
-- START CONTROL
-- ============================================
function StartControl(vehicle, vehicleName, mode)
    if activeControl then
        StopControl()
    end
    
    if not CanUseControls(vehicle) then
        return
    end
    
    currentVehicle = vehicle
    currentVehicleName = vehicleName
    currentConfig = GetVehicleConfig(vehicleName)
    controlMode = mode
    activeControl = true
    
    -- Initialize state
    InitializeVehicleState(vehicle, vehicleName)
    
    -- Notify server
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('D4rk_Smart:StartControl', netId)
    
    -- Show HUD
    ShowCompactHud()
    
    -- Start control thread
    CreateThread(ControlThread)
    
    ShowNotification(GetTranslation('control_active'), 'success')
end

function StopControl()
    if not activeControl then return end
    
    activeControl = false
    
    -- Notify server
    if currentVehicle then
        local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
        TriggerServerEvent('D4rk_Smart:StopControl', netId)
    end
    
    -- Hide HUD
    HideCompactHud()
    
    -- Stop animations
    if controlMode == 'standing' or controlMode == 'remote' then
        ClearPedTasks(PlayerPedId())
    end
    
    ShowNotification(GetTranslation('control_stopped'), 'info')
    
    currentVehicle = nil
    currentVehicleName = nil
    currentConfig = nil
    controlMode = nil
end

-- ============================================
-- CONTROL THREAD
-- ============================================
function ControlThread()
    local playerPed = PlayerPedId()
    
    while activeControl and DoesEntityExist(currentVehicle) do
        Wait(0)
        
        -- Distance check
        if controlMode ~= 'inside' and controlMode ~= 'cage' then
            local distance = GetDistanceToVehicle(currentVehicle)
            local maxDistance = controlMode == 'remote' and Config.MaxRemoteDistance or Config.MaxStandingDistance
            
            if distance > maxDistance then
                StopControl()
                ShowNotification(GetTranslation('too_far'), 'warning')
                break
            end
        end
        
        -- Play animation
        if controlMode == 'standing' then
            if not IsEntityPlayingAnim(playerPed, Config.Animations.standing_control.dict, Config.Animations.standing_control.anim, 3) then
                RequestAnimDict(Config.Animations.standing_control.dict)
                while not HasAnimDictLoaded(Config.Animations.standing_control.dict) do
                    Wait(10)
                end
                TaskPlayAnim(playerPed, Config.Animations.standing_control.dict, Config.Animations.standing_control.anim, 8.0, -8.0, -1, Config.Animations.standing_control.flag, 0, false, false, false)
            end
        elseif controlMode == 'remote' then
            if not IsEntityPlayingAnim(playerPed, Config.Animations.remote.dict, Config.Animations.remote.anim, 3) then
                RequestAnimDict(Config.Animations.remote.dict)
                while not HasAnimDictLoaded(Config.Animations.remote.dict) do
                    Wait(10)
                end
                TaskPlayAnim(playerPed, Config.Animations.remote.dict, Config.Animations.remote.anim, 8.0, -8.0, -1, Config.Animations.remote.flag, 0, false, false, false)
            end
            
            -- Disable movement in remote mode
            DisableControlAction(0, 30, true) -- A/D
            DisableControlAction(0, 31, true) -- W/S
        end
        
        -- Handle controls
        HandleControls()
        
        -- Exit control
        if controlMode ~= 'inside' then
            if IsControlJustPressed(0, Config.Keys.OpenMenu) then
                StopControl()
            end
        end
    end
    
    if activeControl then
        StopControl()
    end
end

-- ============================================
-- HANDLE CONTROLS
-- ============================================
function HandleControls()
    if not currentConfig or not currentConfig.bones then return end
    
    -- Iterate through bones and check for input
    for i, bone in ipairs(currentConfig.bones) do
        local delta = 0.0
        
        -- Check control group specific inputs
        if bone.controlGroup == 'turret' or i == 1 then
            if IsControlPressed(0, Config.Keys.RotateLeft) then
                delta = -1.0
            elseif IsControlPressed(0, Config.Keys.RotateRight) then
                delta = 1.0
            end
        end
        
        if bone.controlGroup == 'ladder' or bone.controlGroup == 'crane' or i == 2 then
            if IsControlPressed(0, Config.Keys.IncreaseControl) then
                delta = 1.0
            elseif IsControlPressed(0, Config.Keys.DecreaseControl) then
                delta = -1.0
            end
        end
        
        -- Additional controls for more bones
        if i == 3 then
            if IsControlPressed(0, 85) then -- Q
                delta = 1.0
            elseif IsControlPressed(0, 48) then -- Z
                delta = -1.0
            end
        end
        
        if i == 4 then
            if IsControlPressed(0, 21) and IsControlPressed(0, 85) then -- Shift + Q
                delta = 1.0
            elseif IsControlPressed(0, 21) and IsControlPressed(0, 48) then -- Shift + Z
                delta = -1.0
            end
        end
        
        -- Apply control
        if delta ~= 0.0 then
            UpdateControl(currentVehicle, i, delta)
        end
    end
    
    -- Stabilizers toggle
    if IsControlJustPressed(0, Config.Keys.StabilizersToggle) then
        if currentConfig.stabilizers and currentConfig.stabilizers.enabled then
            ToggleStabilizers(currentVehicle)
        end
    end
end

-- ============================================
-- REMOTE CONTROL
-- ============================================
function ActivateRemote(vehicle, vehicleName)
    if remoteActive then
        DeactivateRemote()
        return
    end
    
    remoteActive = true
    
    -- Öffne Panel (ohne StartControl - das kommt später)
    OpenControlPanel(vehicle, vehicleName)
    controlMode = 'remote'
    
    ShowNotification(GetTranslation('remote_activated'), 'success')
end

function DeactivateRemote()
    if not remoteActive then return end
    
    remoteActive = false
    StopControl()
    
    ShowNotification(GetTranslation('remote_deactivated'), 'info')
end

-- ============================================
-- PROXIMITY DETECTION
-- ============================================
CreateThread(function()
    while true do
        Wait(0)
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local inVehicle = IsPedInAnyVehicle(playerPed, false)
        
        local nearbyVehicle = nil
        local nearbyVehicleName = nil
        local mode = nil
        
        -- Check if in configured vehicle
        if inVehicle and Config.UseInVehicleControl then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            local vehicleName = IsVehicleConfigured(vehicle)
            
            if vehicleName and GetPedInVehicleSeat(vehicle, -1) == playerPed then
                nearbyVehicle = vehicle
                nearbyVehicleName = vehicleName
                mode = 'inside'
            end
        end
        
        -- Check if standing near vehicle
        if not inVehicle and Config.UseStandingControl and not activeControl then
            local vehicles = GetGamePool('CVehicle')
            
            for _, vehicle in ipairs(vehicles) do
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(playerCoords - vehicleCoords)
                
                if distance < Config.MaxStandingDistance then
                    local vehicleName = IsVehicleConfigured(vehicle)
                    if vehicleName then
                        nearbyVehicle = vehicle
                        nearbyVehicleName = vehicleName
                        mode = 'standing'
                        break
                    end
                end
            end
        end
        
        -- Show prompt
        if nearbyVehicle and not activeControl and not menuOpen then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(GetTranslation('open_menu'))
            EndTextCommandDisplayHelp(0, false, true, -1)
            
            if IsControlJustPressed(0, Config.Keys.OpenMenu) then
                if not menuOpen then  -- Doppelte Prüfung!
                    OpenControlPanel(nearbyVehicle, nearbyVehicleName)
                end
            end
        end
        
        -- Remote control
        if not inVehicle and Config.UseRemoteControl and not activeControl and not remoteActive then
            local vehicles = GetGamePool('CVehicle')
            local closestVehicle = nil
            local closestDistance = Config.MaxRemoteDistance
            local closestName = nil
            
            for _, vehicle in ipairs(vehicles) do
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(playerCoords - vehicleCoords)
                
                if distance < closestDistance then
                    local vehicleName = IsVehicleConfigured(vehicle)
                    if vehicleName then
                        closestVehicle = vehicle
                        closestDistance = distance
                        closestName = vehicleName
                    end
                end
            end
            
            if closestVehicle then
                if IsControlJustPressed(0, Config.Keys.OpenRemote) then
                    ActivateRemote(closestVehicle, closestName)
                end
            end
        end
        
        if not nearbyVehicle then
            Wait(500)
        end
    end
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('IsControlActive', function()
    return activeControl
end)

exports('GetCurrentVehicle', function()
    return currentVehicle
end)

exports('GetControlMode', function()
    return controlMode
end)
