-- D4rk Smart Vehicle - Server Main
-- VERSION 2.2 - MULTIPLAYER FIXES
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
-- FIX #4: Spielername mitschicken wenn bereits gesteuert
RegisterNetEvent('D4rk_Smart:StartControl')
AddEventHandler('D4rk_Smart:StartControl', function(netId)
    local source = source

    if vehicleControllers[netId] and vehicleControllers[netId] ~= source then
        local controllerName = GetPlayerName(vehicleControllers[netId]) or 'Unbekannt'
        TriggerClientEvent('D4rk_Smart:Notify', source,
            'Fahrzeug wird von ' .. controllerName .. ' gesteuert', 'warning')
        return
    end

    SetVehicleController(netId, source)

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Player %d (%s) started controlling vehicle %d^7',
            source, GetPlayerName(source) or '?', netId))
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

-- ============================================
-- SYNC EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncStabilizers')
AddEventHandler('D4rk_Smart:SyncStabilizers', function(netId, deployed)
    local source = source

    local state = InitializeVehicleState(netId)
    state.stabilizersDeployed = deployed

    TriggerClientEvent('D4rk_Smart:SyncStabilizersClient', -1, netId, deployed)

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Stabilizers %s for vehicle %d^7',
            deployed and 'deployed' or 'retracted', netId))
    end
end)

RegisterNetEvent('D4rk_Smart:SyncWater')
AddEventHandler('D4rk_Smart:SyncWater', function(netId, active)
    local source = source

    local state = InitializeVehicleState(netId)
    state.waterActive = active

    TriggerClientEvent('D4rk_Smart:SyncWaterClient', -1, netId, active)

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Water monitor %s for vehicle %d^7',
            active and 'activated' or 'deactivated', netId))
    end
end)

-- ============================================
-- CAGE EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:EnterCage')
AddEventHandler('D4rk_Smart:EnterCage', function(netId)
    local source = source

    local state = InitializeVehicleState(netId)

    if not TableContains(state.cageOccupants, source) then
        table.insert(state.cageOccupants, source)
    end

    TriggerClientEvent('D4rk_Smart:SyncCageClient', -1, netId, #state.cageOccupants)

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Player %d entered cage on vehicle %d^7', source, netId))
    end
end)

RegisterNetEvent('D4rk_Smart:ExitCage')
AddEventHandler('D4rk_Smart:ExitCage', function(netId)
    local source = source

    local state = InitializeVehicleState(netId)

    for i, playerId in ipairs(state.cageOccupants) do
        if playerId == source then
            table.remove(state.cageOccupants, i)
            break
        end
    end

    TriggerClientEvent('D4rk_Smart:SyncCageClient', -1, netId, #state.cageOccupants)

    if Config.Debug then
        print(string.format('^3[D4rk_Smart] Player %d exited cage on vehicle %d^7', source, netId))
    end
end)

-- ============================================
-- RESET EVENT
-- ============================================
RegisterNetEvent('D4rk_Smart:ResetAll')
AddEventHandler('D4rk_Smart:ResetAll', function(netId)
    local source = source

    local state = InitializeVehicleState(netId)
    state.controls = {}

    -- Sync to other clients (nicht an Sender!)
    local players = GetPlayers()
    for _, player in ipairs(players) do
        if tonumber(player) ~= source then
            TriggerClientEvent('D4rk_Smart:ResetAllClient', tonumber(player), netId)
        end
    end

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Vehicle %d controls reset by player %d^7', netId, source))
    end
end)

-- ============================================
-- FIX #3: STATE REQUEST (für Spieler die dazukommen)
-- ============================================
RegisterNetEvent('D4rk_Smart:RequestState')
AddEventHandler('D4rk_Smart:RequestState', function(netId)
    local source = source
    local state = vehicleStates[netId]

    if not state then return end

    -- Alle Bone-Werte an den anfragenden Spieler schicken
    if state.controls then
        for boneIndex, value in pairs(state.controls) do
            TriggerClientEvent('D4rk_Smart:SyncControlClient', source, netId, boneIndex, value)
        end
    end

    -- Stabilizer-Status
    if state.stabilizersDeployed then
        TriggerClientEvent('D4rk_Smart:SyncStabilizersClient', source, netId, true)
    end

    -- Wasser-Status
    if state.waterActive then
        TriggerClientEvent('D4rk_Smart:SyncWaterClient', source, netId, true)
    end

    if Config.Debug then
        print(string.format('^2[D4rk_Smart] Sent state for vehicle %d to player %d^7', netId, source))
    end
end)

-- ============================================
-- FIX #5: PLAYER DROPPED — Fahrzeuge freigeben
-- ============================================
AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Alle Fahrzeuge freigeben die dieser Spieler kontrolliert hat
    local released = {}
    for netId, controller in pairs(vehicleControllers) do
        if controller == source then
            table.insert(released, netId)
        end
    end

    for _, netId in ipairs(released) do
        vehicleControllers[netId] = nil

        -- Alle anderen Clients informieren
        TriggerClientEvent('D4rk_Smart:ForceRelease', -1, netId)
    end

    -- Spieler aus Cage-Occupants entfernen
    for netId, state in pairs(vehicleStates) do
        if state.cageOccupants then
            for i = #state.cageOccupants, 1, -1 do
                if state.cageOccupants[i] == source then
                    table.remove(state.cageOccupants, i)
                end
            end
        end
    end

    if #released > 0 and Config.Debug then
        print(string.format('^3[D4rk_Smart] Player %d disconnected, released %d vehicle(s)^7',
            source, #released))
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
            local name = GetPlayerName(controller) or '?'
            print(string.format('Vehicle %d controlled by %s (ID: %d)', netId, name, controller))
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
