-- D4rk Smart Vehicle - Spotlight System
-- Working spotlights that can be attached to props or vehicle

local spotlightsActive = {}
local spotlightThreads = {}

-- ============================================
-- SPOTLIGHT ACTIVATION
-- ============================================
function ToggleSpotlights(vehicle)
    local vehicleName = IsVehicleConfigured(vehicle)
    if not vehicleName then return end

    local config = GetVehicleConfig(vehicleName)
    if not config.spotlight or not config.spotlight.enabled then
        ShowNotification('Dieses Fahrzeug hat keine Scheinwerfer', 'warning')
        return
    end

    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    if spotlightsActive[netId] then
        DeactivateSpotlights(vehicle)
    else
        ActivateSpotlights(vehicle, config.spotlight)
    end
end

function ActivateSpotlights(vehicle, spotlightConfig)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    if spotlightsActive[netId] then return end

    spotlightsActive[netId] = true

    -- Start spotlight thread for each location
    if not spotlightThreads[netId] then
        spotlightThreads[netId] = {}
    end

    for locationId, spotlights in pairs(spotlightConfig.locations) do
        local thread = CreateThread(function()
            SpotlightThread(vehicle, locationId, spotlights)
        end)
        table.insert(spotlightThreads[netId], thread)
    end

    ShowNotification('Scheinwerfer aktiviert', 'success')

    -- Sync to server
    TriggerServerEvent('D4rk_Smart:SyncSpotlights', netId, true)

    if Config.Debug then
        print(string.format('^2[Spotlight] Activated spotlights for vehicle %d^7', netId))
    end
end

function DeactivateSpotlights(vehicle)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    if not spotlightsActive[netId] then return end

    spotlightsActive[netId] = false
    spotlightThreads[netId] = nil

    ShowNotification('Scheinwerfer deaktiviert', 'info')

    -- Sync to server
    TriggerServerEvent('D4rk_Smart:SyncSpotlights', netId, false)

    if Config.Debug then
        print(string.format('^3[Spotlight] Deactivated spotlights for vehicle %d^7', netId))
    end
end

-- ============================================
-- SPOTLIGHT THREAD
-- ============================================
function SpotlightThread(vehicle, locationId, spotlights)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    while spotlightsActive[netId] and DoesEntityExist(vehicle) do
        Wait(0)

        -- Get attach entity (prop or vehicle)
        local attachEntity = vehicle
        local attachCoords = GetEntityCoords(vehicle)

        if locationId ~= "vehicle" then
            -- Try to find prop
            local propData = GetPropByID(vehicle, locationId)
            if propData and DoesEntityExist(propData.entity) then
                attachEntity = propData.entity
                attachCoords = GetEntityCoords(propData.entity)
            end
        end

        -- Draw each spotlight
        for _, spotlight in ipairs(spotlights) do
            DrawSpotlight(attachEntity, attachCoords, spotlight)
        end
    end
end

function DrawSpotlight(entity, coords, spotlight)
    -- Da GetEntityRightVector und GetEntityUpVector in FiveM nicht existieren,
    -- nutzen wir Offsets, um die Richtung im 3D-Raum zu bestimmen.

    local dirOffset = spotlight.directionOffSet or vector3(0.0, 10.0, 0.0)

    -- Wir berechnen einen Zielpunkt relativ zum Fahrzeug/Prop.
    -- x = rechts/links, y = vorne/hinten, z = oben/unten
    local targetCoords = GetOffsetFromEntityInWorldCoords(
        entity,
        dirOffset.x,
        dirOffset.y,
        dirOffset.z
    )

    -- Der Richtungsvektor ist: Zielposition minus Startposition
    local direction = targetCoords - coords

    -- Normalisierung des Vektors (damit er die Länge 1 hat)
    local length = #(direction)
    if length > 0 then
        direction = direction / length
    end

    -- DrawSpotLight Native aufrufen
    -- Hinweis: coords sind bereits die Welt-Koordinaten des Bones/Props
    DrawSpotLight(
        coords.x, coords.y, coords.z,
        direction.x, direction.y, direction.z,
        spotlight.color[1] or 255,
        spotlight.color[2] or 255,
        spotlight.color[3] or 255,
        spotlight.distance or 50.0,
        spotlight.brightness or 50.0,
        spotlight.hardness or 2.0,
        spotlight.radius or 20.0,
        spotlight.falloff or 10.0
    )
end

-- ============================================
-- CONTROL HANDLER
-- ============================================
CreateThread(function()
    while true do
        if currentVehicle and controlActive then
            Wait(0)

            local config = GetVehicleConfig(currentVehicleName)

            if config and config.spotlight and config.spotlight.enabled then
                local control = config.spotlight.control

                if control and IsControlJustPressed(control[1], control[2]) then
                    ToggleSpotlights(currentVehicle)
                end
            end
        else
            Wait(500) -- Weniger CPU wenn nicht aktiv
        end
    end
end)

-- ============================================
-- SYNC EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncSpotlightsClient')
AddEventHandler('D4rk_Smart:SyncSpotlightsClient', function(netId, active)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    -- Don't sync to self
    if vehicle == currentVehicle then return end

    local vehicleName = IsVehicleConfigured(vehicle)
    if not vehicleName then return end

    local config = GetVehicleConfig(vehicleName)
    if not config.spotlight then return end

    if active then
        ActivateSpotlights(vehicle, config.spotlight)
    else
        DeactivateSpotlights(vehicle)
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    spotlightsActive = {}
    spotlightThreads = {}
end)

-- ============================================
-- EXPORTS
-- ============================================
exports('AreSpotlightsActive', function(vehicle)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    return spotlightsActive[netId] or false
end)

exports('ToggleSpotlights', function(vehicle)
    ToggleSpotlights(vehicle)
end)
