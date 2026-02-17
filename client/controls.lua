-- D4rk Smart Vehicle - Advanced Controls
-- VERSION 2.2 - MULTIPLAYER FIXES
-- controlActive, remoteActive, menuOpen sind global in main.lua definiert

-- ============================================
-- START CONTROL
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
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
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
        local netId = SafeGetNetId(currentVehicle)
        if netId then
            TriggerServerEvent('D4rk_Smart:StopControl', netId)
        end
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
                -- Normale Taste (NUR wenn Shift NICHT gedrückt, sonst Conflict mit Shift-Combos)
                if not IsDisabledControlPressed(0, 21) then
                    if IsDisabledControlPressed(0, mapping.increase) then
                        delta = 1.0
                    elseif IsDisabledControlPressed(0, mapping.decrease) then
                        delta = -1.0
                    end
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

    remoteActive = true
    currentVehicle = vehicle
    currentVehicleName = vehicleName
    currentConfig = GetVehicleConfig(vehicleName)
    controlMode = 'remote'
    controlActive = true

    -- Initialize state
    InitializeVehicleState(vehicle, vehicleName)

    -- Notify server
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    TriggerServerEvent('D4rk_Smart:StartControl', netId)

    -- Zeige NUR das Compact HUD (nicht das große Panel!)
    ShowCompactHud()

    -- Start control thread für Tasteneingaben
    CreateThread(ControlThread)

    ShowNotification(GetTranslation('remote_activated'), 'success')
end

function DeactivateRemote()
    if not remoteActive then return end

    remoteActive = false
    controlActive = false

    -- Notify server
    if currentVehicle then
        local netId = SafeGetNetId(currentVehicle)
        if netId then
            TriggerServerEvent('D4rk_Smart:StopControl', netId)
        end
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
-- PROXIMITY DETECTION (MULTIPLAYER-FIX)
-- ============================================
CreateThread(function()
    while true do
        local sleep = 500
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

        -- FIX: Standing near vehicle → Nur wenn auf dem richtigen Prop!
        if not inVehicle and Config.UseStandingControl and not controlActive then
            local vehicles = GetGamePool('CVehicle')
            local closestDist = Config.MaxStandingDistance

            for _, vehicle in ipairs(vehicles) do
                if DoesEntityExist(vehicle) then
                    local vehicleName = IsVehicleConfigured(vehicle)
                    if vehicleName then
                        local config = GetVehicleConfig(vehicleName)
                        local netId = SafeGetNetId(vehicle)

                        -- Prüfe ob standingControl konfiguriert ist
                        if config and config.standingControl and config.standingControl.requireBoneProp and netId then
                            -- Distanz zum spezifischen Bone-Prop checken
                            local boneIndex = config.standingControl.requireBoneProp
                            local maxDist = config.standingControl.maxDistance or 2.0

                            if spawnedBoneProps[netId] and spawnedBoneProps[netId][boneIndex] then
                                local boneProp = spawnedBoneProps[netId][boneIndex]
                                if boneProp and boneProp.entity and DoesEntityExist(boneProp.entity) then
                                    local propCoords = GetEntityCoords(boneProp.entity)
                                    local dist = #(playerCoords - propCoords)

                                    if dist < maxDist and dist < closestDist then
                                        nearbyVehicle = vehicle
                                        nearbyVehicleName = vehicleName
                                        closestDist = dist
                                        mode = 'standing'
                                    end
                                end
                            end
                        else
                            -- Fallback: Altes Verhalten (Distanz zum Fahrzeug)
                            local dist = #(playerCoords - GetEntityCoords(vehicle))
                            if dist < closestDist then
                                nearbyVehicle = vehicle
                                nearbyVehicleName = vehicleName
                                closestDist = dist
                                mode = 'standing'
                            end
                        end
                    end
                end
            end
        end

        -- FIX #2: Props für ALLE nahen konfigurierten Fahrzeuge spawnen
        -- Damit andere Spieler die Props sehen können
        if not inVehicle then
            local vehicles = GetGamePool('CVehicle')
            for _, vehicle in ipairs(vehicles) do
                if DoesEntityExist(vehicle) then
                    local dist = #(playerCoords - GetEntityCoords(vehicle))
                    -- Props spawnen wenn in Sichtweite (Remote-Distance als Maximum)
                    if dist < Config.MaxRemoteDistance then
                        local vehicleName = IsVehicleConfigured(vehicle)
                        if vehicleName then
                            local netId = SafeGetNetId(vehicle)
                            if netId and not spawnedBoneProps[netId] then
                                Citizen.CreateThread(function()
                                    SpawnBoneProps(vehicle, vehicleName)
                                    SpawnStabilizerProps(vehicle, vehicleName)
                                    SpawnCollisionObjects(vehicle, vehicleName)
                                    SpawnCageProp(vehicle, vehicleName)
                                    SpawnWaterProp(vehicle, vehicleName)

                                    -- FIX #3: Aktuellen State vom Server holen
                                    Wait(500)
                                    local nId = SafeGetNetId(vehicle)
                                    if nId then
                                        TriggerServerEvent('D4rk_Smart:RequestState', nId)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end

        -- ===== E-Prompt für Panel =====
        if nearbyVehicle and not controlActive and not menuOpen then
            sleep = 0
            AddTextEntry('D4RK_PROMPT', GetTranslation('open_menu'))
            DisplayHelpTextThisFrame('D4RK_PROMPT', false)

            if IsControlJustPressed(0, Config.Keys.OpenMenu) then
                if not menuOpen then
                    OpenControlPanel(nearbyVehicle, nearbyVehicleName)
                end
            end
        end

        -- ===== F7 Remote Control =====
        if remoteActive then
            sleep = 0
            if IsControlJustPressed(0, Config.Keys.OpenRemote) then
                DeactivateRemote()
            end
        elseif not inVehicle and Config.UseRemoteControl and not controlActive and not menuOpen then
            local vehicles = GetGamePool('CVehicle')
            local closestVehicle = nil
            local closestDistance = Config.MaxRemoteDistance
            local closestName = nil

            for _, vehicle in ipairs(vehicles) do
                if DoesEntityExist(vehicle) then
                    local dist = #(playerCoords - GetEntityCoords(vehicle))
                    if dist < closestDistance then
                        local vehicleName = IsVehicleConfigured(vehicle)
                        if vehicleName then
                            closestVehicle = vehicle
                            closestDistance = dist
                            closestName = vehicleName
                        end
                    end
                end
            end

            if closestVehicle then
                sleep = 0
                AddTextEntry('D4RK_REMOTE', GetTranslation('open_remote'))
                DisplayHelpTextThisFrame('D4RK_REMOTE', false)

                if IsControlJustPressed(0, Config.Keys.OpenRemote) then
                    ActivateRemote(closestVehicle, closestName)
                end
            end
        end

        Wait(sleep)
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
