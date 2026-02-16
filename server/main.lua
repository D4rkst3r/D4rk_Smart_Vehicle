-- D4rk Smart Vehicle - Server Main
vehicleControllers = {}
vehicleStates = {}

-- ============================================
-- STATE MANAGEMENT
-- ============================================
function InitializeVehicleState(netId)
    if not vehicleStates[netId] then
        vehicleStates[netId] = {
            controls = {},
            stabilizersDeployed = false,
            waterActive = false,
            cageOccupants = {}
        }
    end
    return vehicleStates[netId]
end

function GetVehicleController(netId)
    return vehicleControllers[netId]
end

function SetVehicleController(netId, source)
    vehicleControllers[netId] = source
end

function RemoveVehicleController(netId)
    vehicleControllers[netId] = nil
end

-- ============================================
-- CONTROL EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:StartControl')
AddEventHandler('D4rk_Smart:StartControl', function(netId)
    local source = source

    if vehicleControllers[netId] and vehicleControllers[netId] ~= source then
        TriggerClientEvent('D4rk_Smart:Notify', source, GetTranslation('already_controlled'), 'warning')
        return
    end

    SetVehicleController(netId, source)

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Player %d started controlling vehicle %d^7', source, netId))
    end
end)

RegisterNetEvent('D4rk_Smart:StopControl')
AddEventHandler('D4rk_Smart:StopControl', function(netId)
    local source = source

    if GetVehicleController(netId) == source then
        RemoveVehicleController(netId)

        if Config.Debug then
            print(string.format('^3[D4rk_Smart] Player %d stopped controlling vehicle %d^7', source, netId))
        end
    end
end)


RegisterNetEvent('D4rk_Smart:SyncStabilizers')
AddEventHandler('D4rk_Smart:SyncStabilizers', function(netId, deployed)
    local source = source

    -- Update state
    local state = InitializeVehicleState(netId)
    state.stabilizersDeployed = deployed

    -- Sync to all clients
    TriggerClientEvent('D4rk_Smart:SyncStabilizersClient', -1, netId, deployed)

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Stabilizers %s for vehicle %d^7', deployed and 'deployed' or 'retracted',
            netId))
    end
end)

RegisterNetEvent('D4rk_Smart:SyncWater')
AddEventHandler('D4rk_Smart:SyncWater', function(netId, active)
    local source = source

    -- Update state
    local state = InitializeVehicleState(netId)
    state.waterActive = active

    -- Sync to all clients
    TriggerClientEvent('D4rk_Smart:SyncWaterClient', -1, netId, active)

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Water monitor %s for vehicle %d^7', active and 'activated' or 'deactivated',
            netId))
    end
end)

-- ============================================
-- CAGE EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:EnterCage')
AddEventHandler('D4rk_Smart:EnterCage', function(netId)
    local source = source

    -- Update state
    local state = InitializeVehicleState(netId)

    if not TableContains(state.cageOccupants, source) then
        table.insert(state.cageOccupants, source)
    end

    -- Sync to all clients
    TriggerClientEvent('D4rk_Smart:SyncCageClient', -1, netId, #state.cageOccupants)

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Player %d entered cage on vehicle %d^7', source, netId))
    end
end)

RegisterNetEvent('D4rk_Smart:ExitCage')
AddEventHandler('D4rk_Smart:ExitCage', function(netId)
    local source = source

    -- Update state
    local state = InitializeVehicleState(netId)

    for i, playerId in ipairs(state.cageOccupants) do
        if playerId == source then
            table.remove(state.cageOccupants, i)
            break
        end
    end

    -- Sync to all clients
    TriggerClientEvent('D4rk_Smart:SyncCageClient', -1, netId, #state.cageOccupants)

    if Config.Debug then
        print(string.format('^3[D4rk_Smart] Player %d exited cage on vehicle %d^7', source, netId))
    end
end)

-- ============================================
-- RESET
-- ============================================
RegisterNetEvent('D4rk_Smart:ResetAll')
AddEventHandler('D4rk_Smart:ResetAll', function(netId)
    local source = source

    -- Verify controller
    if GetVehicleController(netId) ~= source then
        return
    end

    -- Reset state
    local state = InitializeVehicleState(netId)
    state.controls = {}

    -- Notify all clients
    TriggerClientEvent('D4rk_Smart:ResetAllClient', -1, netId)

    if Config.Debug then
        print(string.format('^3[D4rk_Smart] Vehicle %d reset by player %d^7', netId, source))
    end
end)

-- ============================================
-- PLAYER DISCONNECT
-- ============================================
AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Remove from controllers
    for netId, controller in pairs(vehicleControllers) do
        if controller == source then
            RemoveVehicleController(netId)

            if Config.Debug then
                print(string.format('^3[D4rk_Smart] Player %d dropped, released vehicle %d^7', source, netId))
            end
        end
    end

    -- Remove from cage occupants
    for netId, state in pairs(vehicleStates) do
        for i, playerId in ipairs(state.cageOccupants) do
            if playerId == source then
                table.remove(state.cageOccupants, i)
                TriggerClientEvent('D4rk_Smart:SyncCageClient', -1, netId, #state.cageOccupants)
                break
            end
        end
    end
end)

-- ============================================
-- STATE REQUEST
-- ============================================
RegisterNetEvent('D4rk_Smart:RequestState')
AddEventHandler('D4rk_Smart:RequestState', function(netId)
    local source = source
    local state = vehicleStates[netId]

    if state then
        TriggerClientEvent('D4rk_Smart:ReceiveState', source, netId, state)
    end
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('GetVehicleState', function(netId)
    return vehicleStates[netId]
end)

exports('IsVehicleControlled', function(netId)
    return vehicleControllers[netId] ~= nil
end)

exports('GetVehicleController', function(netId)
    return vehicleControllers[netId]
end)

exports('ForceReleaseVehicle', function(netId)
    vehicleControllers[netId] = nil
    TriggerClientEvent('D4rk_Smart:ForceRelease', -1, netId)
end)

exports('GetAllControllers', function()
    return vehicleControllers
end)

exports('GetAllStates', function()
    return vehicleStates
end)

-- ============================================
-- COMMANDS (Debug)
-- ============================================
if Config.Debug then
    RegisterCommand('smartvehicle:state', function(source, args)
        local netId = tonumber(args[1])

        if netId then
            local state = vehicleStates[netId]
            if state then
                print(string.format('^2[D4rk_Smart] State for vehicle %d:^7', netId))
                print(json.encode(state, { indent = true }))
            else
                print(string.format('^1[D4rk_Smart] No state found for vehicle %d^7', netId))
            end
        else
            print('^2[D4rk_Smart] All vehicle states:^7')
            for id, state in pairs(vehicleStates) do
                print(string.format('Vehicle %d: %s', id, json.encode(state)))
            end
        end
    end, true)

    RegisterCommand('smartvehicle:controllers', function(source, args)
        print('^2[D4rk_Smart] Active controllers:^7')
        for netId, controller in pairs(vehicleControllers) do
            print(string.format('Vehicle %d controlled by player %d', netId, controller))
        end
    end, true)
end

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
function TableContains(tbl, element)
    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

function GetTranslation(key)
    return Config.Translations[Config.Locale][key] or key
end
