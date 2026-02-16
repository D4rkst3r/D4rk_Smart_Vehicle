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
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    if spotlightsActive[netId] then
        DeactivateSpotlights(vehicle)
    else
        ActivateSpotlights(vehicle, config.spotlight)
    end
end

function ActivateSpotlights(vehicle, spotlightConfig)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
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
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
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
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
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
    -- Calculate spotlight direction
    local forward = GetEntityForwardVector(entity)
    local right = GetEntityRightVector(entity)
    local up = GetEntityUpVector(entity)
    
    local dirOffset = spotlight.directionOffSet or vector3(0, 10, 0)
    
    local direction = vector3(
        forward.x * dirOffset.y + right.x * dirOffset.x + up.x * dirOffset.z,
        forward.y * dirOffset.y + right.y * dirOffset.x + up.y * dirOffset.z,
        forward.z * dirOffset.y + right.z * dirOffset.x + up.z * dirOffset.z
    )
    
    -- Normalize direction
    local length = math.sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
    direction = vector3(direction.x / length, direction.y / length, direction.z / length)
    
    -- Calculate target coords
    local distance = spotlight.distance or 50.0
    local target = vector3(
        coords.x + direction.x * distance,
        coords.y + direction.y * distance,
        coords.z + direction.z * distance
    )
    
    -- Draw spotlight
    DrawSpotLight(
        coords.x, coords.y, coords.z,
        direction.x, direction.y, direction.z,
        spotlight.color[1] or 255, spotlight.color[2] or 255, spotlight.color[3] or 255,
        distance,
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
        Wait(0)
        
        if currentVehicle and controlActive then
            local config = GetVehicleConfig(currentVehicleName)
            
            if config and config.spotlight and config.spotlight.enabled then
                local control = config.spotlight.control
                
                if control and IsControlJustPressed(control[1], control[2]) then
                    ToggleSpotlights(currentVehicle)
                end
            end
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
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return spotlightsActive[netId] or false
end)

exports('ToggleSpotlights', function(vehicle)
    ToggleSpotlights(vehicle)
end)
