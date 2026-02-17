-- D4rk Smart Vehicle - Client Main (Advanced)
-- VERSION 2.1 - PROP-BASED SYSTEM (keine Bone-Natives mehr!)
currentVehicle = nil
currentVehicleName = nil
currentConfig = nil
vehicleStates = {}
controlActive = false
controlMode = nil
menuOpen = false     -- GLOBAL: Sichtbar in allen Dateien
remoteActive = false -- GLOBAL: Sichtbar in allen Dateien
local isResetting = false
local lastSoundTime = {}
local lastSyncTime = {}

-- ============================================
-- HELPERS
-- ============================================
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

local vehicleConfigCache = {}
local configCacheTime = 0

function IsVehicleConfigured(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local model = GetEntityModel(vehicle)

    -- Cache prüfen (5 Sekunden gültig)
    local now = GetGameTimer()
    if now - configCacheTime > 5000 then
        vehicleConfigCache = {}
        configCacheTime = now
    end

    if vehicleConfigCache[model] ~= nil then
        return vehicleConfigCache[model] or nil -- false = nicht konfiguriert
    end

    local modelName = GetDisplayNameFromVehicleModel(model):lower()

    for vehicleName, _ in pairs(Config.Vehicles) do
        if modelName == vehicleName:lower() or GetHashKey(vehicleName) == model then
            vehicleConfigCache[model] = vehicleName
            return vehicleName
        end
    end

    vehicleConfigCache[model] = false
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

function SafeGetNetId(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil
    end
    return NetworkGetNetworkIdFromEntity(entity)
end

function SafeGetEntity(netId)
    if not netId or netId == 0 then return nil end
    -- DIESE Prüfung VERHINDERT die Warning!
    if not NetworkDoesNetworkIdExist(netId) then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil
    end
    return entity
end

-- ============================================
-- BONE INDEX HELPER (für water.lua, cage.lua etc.)
-- ============================================
function GetBoneIndex(vehicle, boneName)
    return GetEntityBoneIndexByName(vehicle, boneName)
end

-- ============================================
-- PROP-BASED CONTROL SYSTEM
-- ============================================
-- GTA V hat KEINE Natives um Vehicle-Bones zur Laufzeit zu bewegen.
-- Stattdessen: Props spawnen und per AttachEntityToEntity bewegen.
-- So macht es auch London Studios Smart Vehicle.
-- ============================================

spawnedBoneProps = {}

-- Model laden mit Timeout
function RequestModelSync(modelHash, timeout)
    timeout = timeout or 5000
    RequestModel(modelHash)
    local startTime = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Wait(10)
        if GetGameTimer() - startTime > timeout then
            print('^1[D4rk_Smart] ERROR: Model load timeout^7')
            return false
        end
    end
    return true
end

-- Alle Props für ein Fahrzeug spawnen
function SpawnBoneProps(vehicle, vehicleName)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    if spawnedBoneProps[netId] then return true end

    local config = GetVehicleConfig(vehicleName)
    if not config or not config.bones then return false end

    spawnedBoneProps[netId] = {}
    local vehicleCoords = GetEntityCoords(vehicle)

    for i, bone in ipairs(config.bones) do
        if bone.propModel and bone.propModel ~= '' then
            local modelHash = GetHashKey(bone.propModel)

            if RequestModelSync(modelHash) then
                local prop = CreateObject(modelHash, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 10.0, true, true,
                    false)

                if DoesEntityExist(prop) then
                    SetEntityCollision(prop, bone.enableCollision or false, bone.enableCollision or false)
                    SetEntityAlpha(prop, bone.propAlpha or 255, false)
                    SetEntityInvincible(prop, true)

                    spawnedBoneProps[netId][i] = {
                        entity = prop,
                        boneConfig = bone,
                        currentOffset = vector3(
                            bone.defaultOffset and bone.defaultOffset.x or 0.0,
                            bone.defaultOffset and bone.defaultOffset.y or 0.0,
                            bone.defaultOffset and bone.defaultOffset.z or 0.0
                        ),
                        currentRotation = vector3(
                            bone.defaultRotation and bone.defaultRotation.x or 0.0,
                            bone.defaultRotation and bone.defaultRotation.y or 0.0,
                            bone.defaultRotation and bone.defaultRotation.z or 0.0
                        )
                    }

                    -- Initial attachment mit Default-Wert
                    local defaultValue = bone.default or bone.min or 0.0
                    AttachBoneProp(vehicle, netId, i, bone, defaultValue)

                    if Config.DebugVerbose then
                        print(string.format(
                            '[D4rk_Smart] Prop #%d: off=(%.2f,%.2f,%.2f) rot=(%.2f,%.2f,%.2f) val=%.2f',
                            boneIndex, offset.x, offset.y, offset.z,
                            rotation.x, rotation.y, rotation.z, value
                        ))
                    end
                else
                    print('^1[D4rk_Smart] ERROR: Could not create prop: ' .. bone.propModel .. '^7')
                end

                SetModelAsNoLongerNeeded(modelHash)
            else
                print('^1[D4rk_Smart] ERROR: Could not load model: ' .. bone.propModel .. '^7')
            end
        else
            -- Kein Prop-Modell → virtueller Bone (nur Wert, keine Anzeige)
            spawnedBoneProps[netId][i] = nil
            if Config.Debug then
                print(string.format('[D4rk_Smart] Bone #%d (%s) has no propModel - skipped', i, bone.label or '?'))
            end
        end
    end
    return true
end

-- Alle Props eines Fahrzeugs löschen
function DeleteBoneProps(netId)
    if not spawnedBoneProps[netId] then return end
    for i, propData in pairs(spawnedBoneProps[netId]) do
        if propData and propData.entity and DoesEntityExist(propData.entity) then
            DetachEntity(propData.entity, false, false)
            DeleteEntity(propData.entity)
            if Config.Debug then
                print(string.format('[D4rk_Smart] Deleted prop #%d', i))
            end
        end
    end
    spawnedBoneProps[netId] = nil
end

-- Wohin soll der Prop attached werden?
function GetAttachTarget(vehicle, netId, boneConfig)
    local attachTo = boneConfig.attachTo or 'vehicle'

    if attachTo == 'vehicle' then
        local boneIdx = 0
        if boneConfig.attachBone and boneConfig.attachBone ~= '' then
            local idx = GetEntityBoneIndexByName(vehicle, boneConfig.attachBone)
            if idx ~= -1 then
                boneIdx = idx
            elseif Config.Debug then
                print('^3[D4rk_Smart] Warning: attachBone not found: ' .. boneConfig.attachBone .. '^7')
            end
        end
        return vehicle, boneIdx
    else
        -- An anderen Prop attachen (per Index-Nummer, z.B. "1" = Prop #1)
        local parentIndex = tonumber(attachTo)
        if parentIndex and spawnedBoneProps[netId] and spawnedBoneProps[netId][parentIndex] then
            local parentProp = spawnedBoneProps[netId][parentIndex]
            if parentProp and parentProp.entity and DoesEntityExist(parentProp.entity) then
                return parentProp.entity, 0
            end
        end
        -- Fallback zum Fahrzeug
        if Config.Debug then
            print('^3[D4rk_Smart] Warning: Parent prop not found for attachTo=' .. tostring(attachTo) .. '^7')
        end
        return vehicle, 0
    end
end

RegisterNUICallback('enterCage', function(data, cb)
    if currentVehicle and currentVehicleName then
        EnterCage(currentVehicle, currentVehicleName)
        CloseControlPanel() -- Panel zu, Spieler ist jetzt im Korb
    end
    cb('ok')
end)

RegisterNUICallback('exitCage', function(data, cb)
    if currentVehicle then
        ExitCage(currentVehicle)
    end
    cb('ok')
end)
-- ============================================
-- KERN: Prop anhängen / neu-anhängen
-- ============================================
function AttachBoneProp(vehicle, netId, boneIndex, boneConfig, value)
    if not spawnedBoneProps[netId] or not spawnedBoneProps[netId][boneIndex] then return end

    local propData = spawnedBoneProps[netId][boneIndex]
    local prop = propData.entity
    if not DoesEntityExist(prop) then return end

    local targetEntity, targetBoneIdx = GetAttachTarget(vehicle, netId, boneConfig)

    -- Basis-Werte aus Config
    local baseOffset = boneConfig.defaultOffset or vector3(0.0, 0.0, 0.0)
    local baseRotation = boneConfig.defaultRotation or vector3(0.0, 0.0, 0.0)

    local offset = vector3(baseOffset.x, baseOffset.y, baseOffset.z)
    local rotation = vector3(baseRotation.x, baseRotation.y, baseRotation.z)

    -- Slider-Wert auf richtige Achse anwenden
    if boneConfig.type == 'rotation' then
        if boneConfig.axis == 'x' then
            rotation = vector3(baseRotation.x + value, baseRotation.y, baseRotation.z)
        elseif boneConfig.axis == 'y' then
            rotation = vector3(baseRotation.x, baseRotation.y + value, baseRotation.z)
        elseif boneConfig.axis == 'z' then
            rotation = vector3(baseRotation.x, baseRotation.y, baseRotation.z + value)
        end
    elseif boneConfig.type == 'position' then
        if boneConfig.axis == 'x' then
            offset = vector3(baseOffset.x + value, baseOffset.y, baseOffset.z)
        elseif boneConfig.axis == 'y' then
            offset = vector3(baseOffset.x, baseOffset.y + value, baseOffset.z)
        elseif boneConfig.axis == 'z' then
            offset = vector3(baseOffset.x, baseOffset.y, baseOffset.z + value)
        end
    end

    propData.currentOffset = offset
    propData.currentRotation = rotation

    -- Detach + Re-attach (sauber)
    DetachEntity(prop, false, false)

    AttachEntityToEntity(
        prop,          -- Das Prop
        targetEntity,  -- Fahrzeug oder Parent-Prop
        targetBoneIdx, -- Bone am Ziel-Entity
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, -- p9
        true,  -- useSoftPinning
        boneConfig.enableCollision or false,
        false, -- isPed
        2,     -- rotationOrder
        true   -- syncRot (relative Rotation!)
    )

    if Config.Debug then
        print(string.format(
            '[D4rk_Smart] Prop #%d: off=(%.2f,%.2f,%.2f) rot=(%.2f,%.2f,%.2f) val=%.2f',
            boneIndex, offset.x, offset.y, offset.z,
            rotation.x, rotation.y, rotation.z, value
        ))
    end
end

-- ============================================
-- ApplyBoneControl (PROP-VERSION)
-- ============================================
function ApplyBoneControl(vehicle, bone, value)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    local state = GetVehicleState(vehicle)
    if not state then return end

    local boneIndex = nil
    for i, b in ipairs(state.config.bones) do
        if b == bone or (b.name == bone.name and b.label == bone.label) then
            boneIndex = i
            break
        end
    end
    if not boneIndex then return end

    -- Prop neu-attachen
    if spawnedBoneProps[netId] and spawnedBoneProps[netId][boneIndex] then
        AttachBoneProp(vehicle, netId, boneIndex, bone, value)
    end

    -- Kinder-Props aktualisieren
    UpdateChildProps(vehicle, netId, boneIndex, state)

    -- Sound NUR wenn sich Wert ändert + Cooldown 500ms
    if bone.soundEffect and Config.SoundEffects and Config.SoundEffects[bone.soundEffect] then
        local key = netId .. '_' .. boneIndex
        local now = GetGameTimer()
        local lastVal = lastSoundTime[key]

        if not lastVal or (now - lastVal) > 500 then
            lastSoundTime[key] = now
            PlaySoundEffect(bone.soundEffect)
        end
    end
end

-- Kinder-Props rekursiv aktualisieren wenn Parent sich bewegt
function UpdateChildProps(vehicle, netId, parentIndex, state)
    if not spawnedBoneProps[netId] or not state then return end
    for i, bone in ipairs(state.config.bones) do
        if bone.attachTo and tonumber(bone.attachTo) == parentIndex then
            local value = state.controlValues[i]
            if value and spawnedBoneProps[netId][i] then
                AttachBoneProp(vehicle, netId, i, bone, value)
                UpdateChildProps(vehicle, netId, i, state) -- Rekursiv!
            end
        end
    end
end

-- Cleanup wenn Fahrzeug nicht mehr gesteuert wird
function CleanupVehicleProps(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    DeleteBoneProps(netId)
end

-- Periodischer Cleanup für gelöschte Fahrzeuge
Citizen.CreateThread(function()
    while true do
        Wait(5000)

        local toClean = {}
        -- Alle netIds aus allen Systemen sammeln
        for netId, _ in pairs(spawnedBoneProps) do
            if not SafeGetEntity(netId) then
                toClean[netId] = true
            end
        end

        -- Einmal aufräumen für alle Systeme
        for netId, _ in pairs(toClean) do
            DeleteBoneProps(netId)
            DeleteStabilizerProps(netId)
            DeleteCollisionObjects(netId)
            DeleteCageProp(netId)
            DeleteWaterProp(netId)
        end
    end
end)

-- ============================================
-- STATE MANAGEMENT
-- ============================================
function InitializeVehicleState(vehicle, vehicleName)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

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
        for i, bone in ipairs(config.bones) do
            vehicleStates[netId].controlValues[i] = bone.default or bone.min or 0.0
        end
    end

    -- Props in eigenem Thread spawnen (blockiert nicht das Menü!)
    Citizen.CreateThread(function()
        SpawnBoneProps(vehicle, vehicleName)
        SpawnStabilizerProps(vehicle, vehicleName)
        SpawnCollisionObjects(vehicle, vehicleName)
        SpawnCageProp(vehicle, vehicleName)
        SpawnWaterProp(vehicle, vehicleName)
    end)

    return vehicleStates[netId]
end

function GetVehicleState(vehicle)
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
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

    local currentValue = state.controlValues[boneIndex]
    local newValue = currentValue + (delta * bone.speed)
    newValue = math.max(bone.min, math.min(bone.max, newValue))

    if newValue ~= currentValue then
        state.controlValues[boneIndex] = newValue
        ApplyBoneControl(vehicle, bone, newValue)

        local now = GetGameTimer()
        local key = boneIndex

        -- Server UND NUI gemeinsam throttlen
        if not lastSyncTime[key] or (now - lastSyncTime[key]) >= 100 then
            lastSyncTime[key] = now

            local netId = SafeGetNetId(vehicle)
            if netId then
                TriggerServerEvent('D4rk_Smart:SyncControl', netId, boneIndex, newValue)
            end

            SendNUIMessage({
                action = 'updateControl',
                index = boneIndex,
                value = newValue
            })
        end
    end
end

-- ============================================
-- STABILIZERS
-- ============================================
function ToggleStabilizers(vehicle)
    local state = GetVehicleState(vehicle)
    if not state then return end

    local stabConfig = state.config.stabilizers
    if not stabConfig or not stabConfig.enabled then return end

    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    if stabAnimating and stabAnimating[netId] then
        ShowNotification('Stützen fahren gerade...', 'warning')
        return
    end

    local deploy = not state.stabilizersDeployed
    state.stabilizersDeployed = deploy

    -- Motor/Handbremse sofort
    if deploy then
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleHandbrake(vehicle, true)
    else
        SetVehicleHandbrake(vehicle, false)
    end

    -- KEIN FreezeEntityPosition hier!
    -- Freeze passiert IN AnimateStabilizersProps NACH der Animation!

    AnimateStabilizersProps(vehicle, state.vehicleName, deploy)

    TriggerServerEvent('D4rk_Smart:SyncStabilizers', netId, deploy)

    SendNUIMessage({
        action = 'updateStabilizers',
        deployed = deploy
    })

    local msg = deploy and 'Stützen ausgefahren - Fahrzeug angehoben' or 'Stützen eingefahren - Fahrzeug abgesenkt'
    ShowNotification(msg, 'info')
end

-- AnimateStabilizers wird jetzt von stabilizers.lua übernommen
-- Die alte Funktion aus main.lua kann gelöscht werden!
function AnimateStabilizers(vehicle, stabConfig, deploy)
    local vehicleName = IsVehicleConfigured(vehicle)
    if vehicleName then
        AnimateStabilizersProps(vehicle, vehicleName, deploy)
    end
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

    -- 1. Variablen setzen
    currentVehicle = vehicle
    currentVehicleName = vehicleName
    currentConfig = GetVehicleConfig(vehicleName)
    local state = InitializeVehicleState(vehicle, vehicleName)

    local playerPed = PlayerPedId()
    controlMode = IsPedInAnyVehicle(playerPed, false) and 'inside' or 'standing'

    -- 2. Status Flags
    menuOpen = true
    controlActive = true

    -- 3. Server & Logik starten
    local netId = SafeGetNetId(vehicle)
    if not netId then return end
    TriggerServerEvent('D4rk_Smart:StartControl', netId)
    CreateThread(ControlThread)

    -- 4. NUI Focus
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    -- 5. NUI Nachrichten
    SendNUIMessage({
        action = 'openPanel',
        vehicle = currentConfig,
        groupLabels = Config.ControlGroups -- NEU: Labels mitschicken
    })

    -- Daten-Sync an UI
    for i, bone in ipairs(currentConfig.bones) do
        SendNUIMessage({
            action = 'updateControl',
            index = i,
            value = state.controlValues[i]
        })
    end

    SendNUIMessage({ action = 'updateStabilizers', deployed = state.stabilizersDeployed })
    SendNUIMessage({ action = 'updateMode', mode = controlMode })
end

function CloseControlPanel()
    if not menuOpen then return end

    print('❌ CLOSING PANEL')

    menuOpen = false
    controlActive = false

    -- Notify server
    if currentVehicle then
        local netId = SafeGetNetId(currentVehicle)
        if netId then
            TriggerServerEvent('D4rk_Smart:StopControl', netId)
        end
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
    if not Config.SoundEffects or not Config.SoundEffects[soundName] then return end
    local sound = Config.SoundEffects[soundName]
    PlaySoundFrontend(-1, sound.name, sound.reference, true)
end

-- ============================================
-- RESET
-- ============================================
function ResetAllControls(vehicle)
    if isResetting then return end
    isResetting = true

    local state = GetVehicleState(vehicle)
    if not state then
        isResetting = false
        return
    end
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    for i, bone in ipairs(state.config.bones) do
        local defaultValue = bone.default or bone.min or 0.0
        state.controlValues[i] = defaultValue

        if spawnedBoneProps[netId] and spawnedBoneProps[netId][i] then
            AttachBoneProp(vehicle, netId, i, bone, defaultValue)
        end

        SendNUIMessage({
            action = 'updateControl',
            index = i,
            value = defaultValue
        })
    end

    TriggerServerEvent('D4rk_Smart:ResetAll', netId)
    ShowNotification('Alle Kontrollen zurückgesetzt', 'info')

    -- Flag nach kurzer Pause zurücksetzen
    Citizen.SetTimeout(500, function()
        isResetting = false
    end)
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
    cb('ok')
end)

-- ============================================
-- SERVER SYNC EVENTS
-- ============================================
RegisterNetEvent('D4rk_Smart:SyncControlClient')
AddEventHandler('D4rk_Smart:SyncControlClient', function(netId, boneIndex, value)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    -- NEU: Nicht auf eigenes Fahrzeug anwenden (haben wir schon lokal gemacht)
    if vehicle == currentVehicle then
        -- NUI trotzdem updaten (könnte von anderem Spieler kommen)
        -- Aber ApplyBoneControl überspringen
        SendNUIMessage({
            action = 'updateControl',
            index = boneIndex,
            value = value
        })
        return
    end

    local state = GetVehicleState(vehicle)
    if not state then return end

    local bone = state.config.bones[boneIndex]
    if not bone then return end

    state.controlValues[boneIndex] = value
    ApplyBoneControl(vehicle, bone, value)
end)

RegisterNetEvent('D4rk_Smart:SyncStabilizersClient')
AddEventHandler('D4rk_Smart:SyncStabilizersClient', function(netId, deployed)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    local state = GetVehicleState(vehicle)
    if not state then return end

    state.stabilizersDeployed = deployed

    -- Motor/Handbremse
    if deployed then
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleHandbrake(vehicle, true)
    else
        SetVehicleHandbrake(vehicle, false)
    end

    -- KEIN FreezeEntityPosition hier!
    -- Freeze passiert IN AnimateStabilizersProps NACH der Animation!

    AnimateStabilizers(vehicle, state.config.stabilizers, deployed)

    if vehicle == currentVehicle then
        SendNUIMessage({
            action = 'updateStabilizers',
            deployed = deployed
        })
    end
end)

-- ForceRelease Handler
RegisterNetEvent('D4rk_Smart:ForceRelease')
AddEventHandler('D4rk_Smart:ForceRelease', function(netId)
    -- Nur releasen wenn WIR dieses Fahrzeug steuern
    if not currentVehicle then return end

    local myNetId = SafeGetNetId(currentVehicle)
    if not myNetId then return end

    -- netId = nil (alter Aufruf ohne Parameter) → alles releasen
    -- netId vorhanden → nur gezielt releasen
    if netId and myNetId ~= netId then return end

    if menuOpen then
        CloseControlPanel()
    end
    if controlActive then
        controlActive = false
        HideCompactHud()
    end
    currentVehicle = nil
    currentVehicleName = nil
    currentConfig = nil
    controlMode = nil
    remoteActive = false
end)

-- Notify Handler
RegisterNetEvent('D4rk_Smart:Notify')
AddEventHandler('D4rk_Smart:Notify', function(msg, type)
    ShowNotification(msg, type)
end)

-- ResetAllClient Handler
RegisterNetEvent('D4rk_Smart:ResetAllClient')
AddEventHandler('D4rk_Smart:ResetAllClient', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        ResetAllControls(vehicle)
    end
end)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Delete ALL spawned bone props
    for netId, _ in pairs(spawnedBoneProps) do
        DeleteBoneProps(netId)
    end

    -- NEU: Unfreeze alle Fahrzeuge (falls Stützen aktiv waren)
    for netId, state in pairs(vehicleStates) do
        if state.stabilizersDeployed then
            local veh = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(veh) then
                FreezeEntityPosition(veh, false)
                SetVehicleHandbrake(veh, false)
            end
        end
    end

    CloseControlPanel()
    HideCompactHud()
    vehicleStates = {}
    spawnedBoneProps = {}
    menuOpen = false
    currentVehicle = nil
    currentVehicleName = nil
    currentConfig = nil
    controlActive = false
    controlMode = nil
end)

-- ============================================
-- ESC HANDLER
-- ============================================
CreateThread(function()
    while true do
        Wait(100)
        if menuOpen then
            DisableControlAction(0, 200, true) -- ESC
            if IsDisabledControlJustPressed(0, 200) then
                print('🔴 ESC pressed - closing panel')
                CloseControlPanel()
            end
        end
    end
end)

-- ============================================
-- TEST COMMANDS
-- ============================================
RegisterCommand('testpanel', function()
    if menuOpen then
        print('⚠️ Panel already open!')
        return
    end

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then
        print('❌ You must be in a vehicle!')
        return
    end

    local vehicleName = IsVehicleConfigured(vehicle)
    if not vehicleName then
        print('❌ Vehicle not in config!')
        print('Model: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
        return
    end

    print('✅ Vehicle found: ' .. vehicleName)
    OpenControlPanel(vehicle, vehicleName)
end, false)

RegisterCommand('resetmenu', function()
    print('🔄 Reset Menu State')
    menuOpen = false
    remoteActive = false
    controlActive = false
    CloseControlPanel()
    HideCompactHud()
    SetNuiFocus(false, false)
    print('✅ Menu reset')
end, false)
