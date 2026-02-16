-- D4rk Smart Vehicle - Advanced Controls
-- FIX #1: Keine lokalen Variablen mehr - nutze globale aus main.lua
-- controlActive, remoteActive, menuOpen sind global in main.lua definiert

-- ============================================
-- START CONTROL (FIX #3: wird jetzt von Proximity genutzt)
-- ============================================
function StartControl(vehicle, vehicleName, mode)
    if controlActive then
        StopControl()
    end

    if not CanUseControls(vehicle) then
        return
    end

    currentVehicle = vehicle
    currentVehicleName = vehicleName
    currentConfig = GetVehicleConfig(vehicleName)
    controlMode = mode
    controlActive = true

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
    if not controlActive then return end

    controlActive = false

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

    while controlActive and currentVehicle and DoesEntityExist(currentVehicle) do
        Wait(0)

        -- Automatisch ALLE verwendeten Tasten für GTA blockieren
        for _, mapping in pairs(Config.ControlGroups) do
            DisableControlAction(0, mapping.increase, true)
            DisableControlAction(0, mapping.decrease, true)
        end
        DisableControlAction(0, 21, true) -- Shift (für Shift-Combos)

        if menuOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 106, true)
            DisableControlAction(0, 200, true)
        end

        -- Distance check
        if controlMode ~= 'inside' and controlMode ~= 'cage' then
            local distance = GetDistanceToVehicle(currentVehicle)
            local maxDistance = controlMode == 'remote' and Config.MaxRemoteDistance or Config.MaxStandingDistance

            if distance > maxDistance then
                if menuOpen then CloseControlPanel() end
                StopControl()
                ShowNotification(GetTranslation('too_far'), 'warning')
                break
            end
        end

        -- Animationen nur spielen, wenn das Panel NICHT offen ist
        if not menuOpen then
            if controlMode == 'standing' then
                -- Animation Code
            elseif controlMode == 'remote' then
                -- Animation Code
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
            end
        end

        -- Die Steuerung der Bones/Wasser/Stützen läuft weiter
        HandleControls()

        -- Beenden nur erlauben, wenn Panel zu ist
        if controlMode ~= 'inside' and not menuOpen then
            if IsControlJustPressed(0, Config.Keys.OpenMenu) then
                StopControl()
            end
        end
    end

    -- Sicherheits-Cleanup: Nur stoppen wenn noch aktiv
    -- (Verhindert doppeltes StopControl)
    if controlActive then
        StopControl()
    end
end

-- ============================================
-- HANDLE CONTROLS
-- ============================================
function HandleControls()
    if not currentConfig then return end

    -- Handle BONE controls (automatisch aus Config!)
    if currentConfig.bones then
        for i, bone in ipairs(currentConfig.bones) do
            local group = bone.controlGroup
            if not group then goto continue end

            local mapping = Config.ControlGroups[group]
            if not mapping then goto continue end

            local delta = 0.0

            if mapping.shift then
                -- Shift + Taste
                if IsDisabledControlPressed(0, 21) and IsDisabledControlPressed(0, mapping.increase) then
                    delta = 1.0
                elseif IsDisabledControlPressed(0, 21) and IsDisabledControlPressed(0, mapping.decrease) then
                    delta = -1.0
                end
            else
                -- Normale Taste
                if IsDisabledControlPressed(0, mapping.increase) then
                    delta = 1.0
                elseif IsDisabledControlPressed(0, mapping.decrease) then
                    delta = -1.0
                end
            end

            if delta ~= 0.0 then
                UpdateControl(currentVehicle, i, delta)
            end

            ::continue::
        end
    end

    -- Handle PROP controls (unverändert)
    if currentConfig.props then
        for _, propConfig in ipairs(currentConfig.props) do
            if propConfig.controls then
                for _, control in ipairs(propConfig.controls) do
                    if IsDisabledControlPressed(0, control.control) then
                        if control.movementType == "move" or control.movementType == "rotate" then
                            UpdatePropControl(currentVehicle, propConfig.id, control.movementType, control.axis,
                                control.movementAmount)
                        end
                    end
                    if IsDisabledControlJustPressed(0, control.control) then
                        if control.movementType == "toggle" then
                            ToggleProp(currentVehicle, propConfig.id)
                        elseif control.movementType == "spin" then
                            ToggleSpin(currentVehicle, propConfig.id, control)
                        end
                    end
                end
            end
        end
    end

    -- Stabilizers toggle
    if IsDisabledControlJustPressed(0, Config.Keys.StabilizersToggle) then
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

    print('🔵 Aktiviere Fernsteuerung')

    remoteActive = true
    currentVehicle = vehicle
    currentVehicleName = vehicleName
    currentConfig = GetVehicleConfig(vehicleName)
    controlMode = 'remote'
    controlActive = true -- FIX: controlActive auch setzen!

    -- Initialize state
    InitializeVehicleState(vehicle, vehicleName)

    -- Notify server
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('D4rk_Smart:StartControl', netId)

    -- Zeige NUR das Compact HUD (nicht das große Panel!)
    ShowCompactHud()

    -- Start control thread für Tasteneingaben
    CreateThread(ControlThread)

    ShowNotification(GetTranslation('remote_activated'), 'success')
end

function DeactivateRemote()
    if not remoteActive then return end

    print('🔵 Deaktiviere Fernsteuerung')

    remoteActive = false
    controlActive = false -- FIX: controlActive auch zurücksetzen!

    -- Notify server
    if currentVehicle then
        local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
        TriggerServerEvent('D4rk_Smart:StopControl', netId)
    end

    -- Schließe Compact HUD
    HideCompactHud()

    -- Stop animations
    ClearPedTasks(PlayerPedId())

    currentVehicle = nil
    currentVehicleName = nil
    currentConfig = nil
    controlMode = nil

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
        if not inVehicle and Config.UseStandingControl and not controlActive then
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
        if nearbyVehicle and not controlActive and not menuOpen then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(GetTranslation('open_menu'))
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustPressed(0, Config.Keys.OpenMenu) then
                if not menuOpen then
                    OpenControlPanel(nearbyVehicle, nearbyVehicleName)
                end
            end
        end

        -- Remote control (FIX: elseif verhindert Aktivieren+Deaktivieren im selben Frame)
        if remoteActive then
            -- Bereits aktiv → F7 zum Deaktivieren
            if IsControlJustPressed(0, Config.Keys.OpenRemote) then
                DeactivateRemote()
            end
        elseif not inVehicle and Config.UseRemoteControl and not controlActive and not menuOpen then
            -- Noch nicht aktiv → F7 zum Aktivieren
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

        if not nearbyVehicle and not remoteActive then
            Wait(500)
        end
    end
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('IsControlActive', function()
    return controlActive
end)

exports('GetCurrentVehicle', function()
    return currentVehicle
end)

exports('GetControlMode', function()
    return controlMode
end)
