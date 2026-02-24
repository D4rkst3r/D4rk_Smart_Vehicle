-- ============================================
-- D4rk Smart Vehicle - Engine RPM Sound System
-- Motor dreht hoch wenn Bones bewegt werden
-- Realistisch: Echte Drehleitern nutzen Nebenabtrieb (PTO)
-- ============================================

local bonesMovingThisFrame = {} -- [boneKey] = { vehicle }
local bonesMovingLastFrame = {}
local isAnyBoneMoving = false
local targetRpm = 0.0
local currentRpm = 0.0
local rpmVehicle = nil

-- ============================================
-- CONFIG
-- ============================================
local RPM_CONFIG = {
    idle       = 0.22,  -- Leerlauf-RPM wenn Steuerung aktiv (Motor läuft leise)
    singleBone = 0.45,  -- RPM bei 1 Bone-Bewegung
    multiBone  = 0.65,  -- RPM bei 2+ Bone-Bewegungen gleichzeitig
    maxRpm     = 0.80,  -- Maximum RPM
    rampUp     = 0.03,  -- Wie schnell RPM hochgeht pro Frame (smooth)
    rampDown   = 0.015, -- Wie schnell RPM runtergeht pro Frame (langsamer = realistischer)
}

-- ============================================
-- MARK BONE MOVING (aufgerufen von UpdateControl in main.lua)
-- Interface bleibt gleich wie vorher!
-- ============================================
function MarkBoneMoving(vehicle, boneIndex, soundType, direction)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    local boneKey = netId .. '_' .. boneIndex
    bonesMovingThisFrame[boneKey] = {
        vehicle = vehicle,
    }
    rpmVehicle = vehicle
end

-- ============================================
-- STOP ALL (aufgerufen von StopControl, DeactivateRemote, etc.)
-- ============================================
function StopAllBoneSounds()
    bonesMovingThisFrame = {}
    bonesMovingLastFrame = {}
    isAnyBoneMoving = false
    targetRpm = 0.0
    currentRpm = 0.0 -- Sofort auf 0, kein rampDown (Steuerung wird beendet)
end

-- ============================================
-- RPM MANAGEMENT THREAD
-- ============================================
Citizen.CreateThread(function()
    while true do
        Wait(0)

        -- Zähle wie viele Bones sich diesen Frame bewegen
        local movingCount = 0
        local vehicle = nil
        for _, data in pairs(bonesMovingThisFrame) do
            movingCount = movingCount + 1
            vehicle = data.vehicle
        end

        -- Target RPM basierend auf Anzahl bewegter Bones
        if movingCount == 0 then
            targetRpm = 0.0 -- Kein Bone bewegt = kein extra RPM
            isAnyBoneMoving = false
        elseif movingCount == 1 then
            targetRpm = RPM_CONFIG.singleBone
            isAnyBoneMoving = true
        elseif movingCount == 2 then
            targetRpm = RPM_CONFIG.multiBone
            isAnyBoneMoving = true
        else
            targetRpm = RPM_CONFIG.maxRpm
            isAnyBoneMoving = true
        end

        -- Smooth RPM Übergang
        if currentRpm < targetRpm then
            currentRpm = math.min(currentRpm + RPM_CONFIG.rampUp, targetRpm)
        elseif currentRpm > targetRpm then
            currentRpm = math.max(currentRpm - RPM_CONFIG.rampDown, targetRpm)
        end

        -- RPM am Fahrzeug setzen
        local v = vehicle or rpmVehicle
        if v and DoesEntityExist(v) and currentRpm > 0.01 then
            -- Motor NUR einschalten wenn Bones sich AKTIV bewegen
            -- Nicht während rampDown — sonst Konflikt mit Stützen-Motor-Aus
            if isAnyBoneMoving and not GetIsVehicleEngineRunning(v) then
                SetVehicleEngineOn(v, true, true, false)
            end

            -- RPM setzen nur wenn Motor läuft
            if GetIsVehicleEngineRunning(v) then
                SetVehicleCurrentRpm(v, currentRpm)
            end
        end

        -- Frame-Reset: ThisFrame → LastFrame
        bonesMovingLastFrame = bonesMovingThisFrame
        bonesMovingThisFrame = {}
    end
end)

-- ============================================
-- TEST COMMAND
-- ============================================
RegisterCommand('testrpm', function(_, args)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        local coords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 20.0, 0, 70)
    end

    if not DoesEntityExist(vehicle) then
        print('^1[RPM] Kein Fahrzeug gefunden!^7')
        return
    end

    local arg = args[1] or 'ramp'

    -- Test 1: RPM Rampe hoch und runter
    if arg == 'ramp' then
        print('^5[RPM] Rampe hoch → runter Test...^7')

        -- Motor an
        SetVehicleEngineOn(vehicle, true, true, false)
        Wait(200)

        -- Hochdrehen
        for rpm = 20, 70, 5 do
            SetVehicleCurrentRpm(vehicle, rpm / 100.0)
            print('  RPM: ' .. (rpm / 100.0))
            Wait(200)
        end

        -- Halten
        print('  RPM 0.7 halten...')
        for i = 1, 15 do
            SetVehicleCurrentRpm(vehicle, 0.7)
            Wait(100)
        end

        -- Runterdrehen
        for rpm = 70, 20, -5 do
            SetVehicleCurrentRpm(vehicle, rpm / 100.0)
            print('  RPM: ' .. (rpm / 100.0))
            Wait(200)
        end

        print('^2[RPM] Test fertig!^7')
    end

    -- Test 2: Sofort auf bestimmten Wert
    if tonumber(arg) then
        local rpm = tonumber(arg)
        if rpm > 1.0 then rpm = rpm / 100.0 end
        print('^5[RPM] Setze auf ' .. rpm .. '^7')
        SetVehicleEngineOn(vehicle, true, true, false)

        for i = 1, 50 do
            SetVehicleCurrentRpm(vehicle, rpm)
            Wait(0)
        end
        print('^2[RPM] Fertig^7')
    end
end, false)

print('^2[D4rk_Smart] Engine RPM Sound System geladen^7')
print('^2  /testrpm       - Rampe hoch/runter Test^7')
print('^2  /testrpm 50    - RPM auf 0.5 setzen^7')
