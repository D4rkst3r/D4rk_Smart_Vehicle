-- D4rk Smart Vehicle - Door Control System
-- Control vehicle doors with configurable keybinds

local doorStates = {}

-- ============================================
-- DOOR CONTROL
-- ============================================
function ToggleDoor(vehicle, doorIndex)
    if not DoesEntityExist(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if not doorStates[netId] then
        doorStates[netId] = {}
    end

    -- Get current door state
    local currentState = doorStates[netId][doorIndex]

    if currentState == nil then
        -- Unknown state, check actual door angle
        local angle = GetVehicleDoorAngleRatio(vehicle, doorIndex)
        currentState = angle > 0.1 -- Open if angle > 0.1
    end

    if currentState then
        -- Close door
        SetVehicleDoorShut(vehicle, doorIndex, false)
        doorStates[netId][doorIndex] = false

        ShowNotification(string.format('Tür %d geschlossen', doorIndex + 1), 'info')
    else
        -- Open door
        SetVehicleDoorOpen(vehicle, doorIndex, false, false)
        doorStates[netId][doorIndex] = true

        ShowNotification(string.format('Tür %d geöffnet', doorIndex + 1), 'success')
    end

    -- Sync to server
    TriggerServerEvent('D4rk_Smart:SyncDoor', netId, doorIndex, doorStates[netId][doorIndex])

    if Config.Debug then
        print(string.format('^2[Doors] Toggled door %d on vehicle %d to %s^7',
            doorIndex, netId, doorStates[netId][doorIndex] and 'open' or 'closed'))
    end
end

function SetDoorState(vehicle, doorIndex, open)
    if not DoesEntityExist(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if not doorStates[netId] then
        doorStates[netId] = {}
    end

    if open then
        SetVehicleDoorOpen(vehicle, doorIndex, false, false)
    else
        SetVehicleDoorShut(vehicle, doorIndex, false)
    end

    doorStates[netId][doorIndex] = open
end

-- ============================================
-- CONTROL HANDLER
-- ============================================
CreateThread(function()
    while true do
        if currentVehicle and controlActive then
            Wait(0)

            local config = GetVehicleConfig(currentVehicleName)

            if config and config.doors and config.doors.enabled then
                local controls = config.doors.controls

                if controls then
                    for control, doorIndex in pairs(controls) do
                        if IsControlJustPressed(0, control) then
                            ToggleDoor(currentVehicle, doorIndex)
                        end
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- ============================================
-- SYNC EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncDoorClient')
AddEventHandler('D4rk_Smart:SyncDoorClient', function(netId, doorIndex, open)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    -- Don't sync to self
    if vehicle == currentVehicle then return end

    SetDoorState(vehicle, doorIndex, open)
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Close all doors
    for netId, doors in pairs(doorStates) do
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(vehicle) then
            for doorIndex, _ in pairs(doors) do
                SetVehicleDoorShut(vehicle, doorIndex, false)
            end
        end
    end

    doorStates = {}
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('ToggleDoor', function(vehicle, doorIndex)
    ToggleDoor(vehicle, doorIndex)
end)

exports('GetDoorState', function(vehicle, doorIndex)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if doorStates[netId] then
        return doorStates[netId][doorIndex]
    end
    return nil
end)

exports('SetDoorState', function(vehicle, doorIndex, open)
    SetDoorState(vehicle, doorIndex, open)
end)
