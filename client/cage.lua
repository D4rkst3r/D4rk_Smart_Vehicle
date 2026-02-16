-- D4rk Smart Vehicle - Cage/Basket System (PROP-BASED)
local cageProps = {}
local cageOccupants = {}
local playerInCage = false

-- ============================================
-- CAGE PROP SPAWNING
-- ============================================
function SpawnCageProp(vehicle, vehicleName)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    if cageProps[netId] then return cageProps[netId] end

    local config = GetVehicleConfig(vehicleName)
    if not config or not config.cage or not config.cage.enabled then return nil end

    local cage = config.cage
    if not cage.propModel or cage.propModel == '' then
        if Config.Debug then
            print('[D4rk_Smart] Cage has no propModel - skipped')
        end
        return nil
    end

    local modelHash = GetHashKey(cage.propModel)
    if not RequestModelSync(modelHash) then return nil end

    local vehicleCoords = GetEntityCoords(vehicle)
    local prop = CreateObject(modelHash, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 10.0, true, true, false)

    if not DoesEntityExist(prop) then return nil end

    SetEntityCollision(prop, cage.enableCollision or false, cage.enableCollision or false)
    SetEntityInvincible(prop, true)
    SetModelAsNoLongerNeeded(modelHash)

    -- Attach to correct target
    local targetEntity, targetBoneIdx = GetCageAttachTarget(vehicle, netId, cage)

    local offset = cage.offset or vector3(0.0, 0.0, 0.5)
    local rotation = cage.rotation or vector3(0.0, 0.0, 0.0)

    AttachEntityToEntity(
        prop, targetEntity, targetBoneIdx,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, true, false, false, 2, true
    )

    cageProps[netId] = {
        entity = prop,
        config = cage
    }

    if Config.Debug then
        print('[D4rk_Smart] Cage prop spawned: ' .. cage.propModel)
    end

    return cageProps[netId]
end

function GetCageAttachTarget(vehicle, netId, cageConfig)
    local attachTo = cageConfig.attachTo or 'vehicle'

    if attachTo == 'vehicle' then
        local boneIdx = 0
        if cageConfig.attachBone and cageConfig.attachBone ~= '' then
            local idx = GetEntityBoneIndexByName(vehicle, cageConfig.attachBone)
            if idx ~= -1 then boneIdx = idx end
        end
        return vehicle, boneIdx
    else
        -- An Bone-Prop hängen (z.B. '3' = an Leiter-Ausfahren-Prop)
        local parentIndex = tonumber(attachTo)
        if parentIndex and spawnedBoneProps[netId] and spawnedBoneProps[netId][parentIndex] then
            local parentProp = spawnedBoneProps[netId][parentIndex]
            if parentProp and parentProp.entity and DoesEntityExist(parentProp.entity) then
                return parentProp.entity, 0
            end
        end
        return vehicle, 0
    end
end

function DeleteCageProp(netId)
    if not cageProps[netId] then return end
    if cageProps[netId].entity and DoesEntityExist(cageProps[netId].entity) then
        DetachEntity(cageProps[netId].entity, false, false)
        DeleteEntity(cageProps[netId].entity)
    end
    cageProps[netId] = nil
end

-- ============================================
-- CAGE ENTER/EXIT
-- ============================================
function EnterCage(vehicle, vehicleName)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    local config = GetVehicleConfig(vehicleName)
    if not config or not config.cage or not config.cage.enabled then return end

    -- Spawn cage prop if not exists
    local cageData = cageProps[netId] or SpawnCageProp(vehicle, vehicleName)
    if not cageData then
        ShowNotification('Kein Korb-Modell konfiguriert', 'error')
        return
    end

    -- Check max occupants
    local cage = config.cage
    if cageOccupants[netId] and #cageOccupants[netId] >= (cage.maxOccupants or 2) then
        ShowNotification(GetTranslation('cage_full'), 'warning')
        return
    end

    local playerPed = PlayerPedId()

    -- Attach player to cage prop
    local playerOffset = cage.playerOffset or vector3(0.0, 0.0, 0.3)

    AttachEntityToEntity(
        playerPed, cageData.entity, 0,
        playerOffset.x, playerOffset.y, playerOffset.z,
        0.0, 0.0, 0.0,
        false, true, false, true, 2, true
    )
    playerInCage = true -- NEU

    -- Track occupant
    if not cageOccupants[netId] then cageOccupants[netId] = {} end
    table.insert(cageOccupants[netId], PlayerId())

    -- Notify server
    TriggerServerEvent('D4rk_Smart:EnterCage', netId)

    -- Start cage control if allowed
    if cage.canControl then
        controlMode = 'cage'
    end

    ShowNotification(GetTranslation('cage_entered'), 'success')

    if Config.Debug then
        print('[D4rk_Smart] Player entered cage')
    end
end

function ExitCage(vehicle)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    local playerPed = PlayerPedId()

    -- Detach player
    DetachEntity(playerPed, true, false)
    playerInCage = false -- NEU

    -- Safe ground position
    local playerCoords = GetEntityCoords(playerPed)
    local found, groundZ = GetGroundZFor_3dCoord(playerCoords.x, playerCoords.y, playerCoords.z + 1.0, false)
    if found then
        SetEntityCoords(playerPed, playerCoords.x, playerCoords.y, groundZ + 1.0, false, false, false, false)
    end

    -- Remove from occupants
    if cageOccupants[netId] then
        for i, pid in ipairs(cageOccupants[netId]) do
            if pid == PlayerId() then
                table.remove(cageOccupants[netId], i)
                break
            end
        end
    end

    -- Notify server
    TriggerServerEvent('D4rk_Smart:ExitCage', netId)

    if controlMode == 'cage' then
        controlMode = nil
    end

    ShowNotification(GetTranslation('cage_exited'), 'info')
end

-- ============================================
-- CAGE PROXIMITY THREAD
-- Nur für Personen die NICHT am Fahrzeug sind
-- (z.B. auf einem Dach stehen und der Korb ist bei ihnen)
-- ============================================
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local playerPed = PlayerPedId()

        -- Einsteige-Check:
        -- ✅ NICHT im Korb
        -- ✅ NICHT im Fahrzeug
        -- ✅ Panel NICHT offen (Panel hat eigenen Button)
        -- ✅ Control NICHT aktiv
        if not playerInCage
            and not IsPedInAnyVehicle(playerPed, false)
            and not menuOpen
            and not controlActive
        then
            local playerCoords = GetEntityCoords(playerPed)
            local vehicles = GetGamePool('CVehicle')

            for _, vehicle in ipairs(vehicles) do
                local vehicleName = IsVehicleConfigured(vehicle)
                if vehicleName then
                    local config = GetVehicleConfig(vehicleName)
                    if config and config.cage and config.cage.enabled then
                        local netId = SafeGetNetId(vehicle)
                        if not netId then return end
                        local cageData = cageProps[netId]

                        if cageData and DoesEntityExist(cageData.entity) then
                            local cageCoords = GetEntityCoords(cageData.entity)
                            local vehicleCoords = GetEntityCoords(vehicle)

                            -- Distanz: Spieler zum KORB-PROP (nicht zum Fahrzeug!)
                            local distToCage = #(playerCoords - cageCoords)

                            -- Distanz: Spieler zum FAHRZEUG
                            local distToVehicle = #(playerCoords - vehicleCoords)

                            -- Nur anzeigen wenn:
                            -- Nah am Korb (<3m)
                            -- UND weit weg vom Fahrzeug (>5m) → verhindert E-Konflikt
                            if distToCage < (config.cage.enterDistance or 3.0)
                                and distToVehicle > 5.0
                            then
                                sleep = 0
                                AddTextEntry('D4RK_CAGE_ENTER', GetTranslation('enter_cage'))
                                DisplayHelpTextThisFrame('D4RK_CAGE_ENTER', false)

                                if IsControlJustPressed(0, Config.Keys.EnterCage) then
                                    -- currentVehicle setzen damit ExitCage funktioniert
                                    currentVehicle = vehicle
                                    currentVehicleName = vehicleName
                                    EnterCage(vehicle, vehicleName)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Aussteige-Check NUR wenn wirklich im Korb
        if playerInCage then
            sleep = 0
            AddTextEntry('D4RK_CAGE_EXIT', GetTranslation('exit_cage'))
            DisplayHelpTextThisFrame('D4RK_CAGE_EXIT', false)

            if IsControlJustPressed(0, Config.Keys.ExitCage) then
                if currentVehicle then
                    ExitCage(currentVehicle)
                end
            end
        end

        Wait(sleep)
    end
end)


