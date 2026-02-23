-- ============================================
-- D4rk Smart Vehicle - 3D Bone Sound System
-- Verschiedene Sounds pro Bone-Typ (Kran, Hydraulik, Stabilizer)
-- 3D Audio vom Fahrzeug, Auto-Loop, Smart Stop
-- ============================================

local activeSounds = {}         -- [boneKey] = { soundId, startTime, config, loopInterval, isFrontend, vehicle }
local bonesMovingThisFrame = {} -- [boneKey] = { soundType, direction, vehicle }
local bonesMovingLastFrame = {} -- [boneKey] = { soundType, direction, vehicle }

-- ============================================
-- SOUND KONFIGURATION
-- Verschiedene Sounds für verschiedene Bewegungstypen
-- ============================================
--[[
    Jeder Bone in Config.Vehicles kann jetzt ein 'soundEffect' haben das auf
    einen Key in Config.SoundEffects zeigt. Das System unterstützt:

    - Richtungsabhängige Sounds (up/down, extend/retract)
    - Loop-Intervalle pro Sound-Typ
    - Optionale Stop-Sounds beim Loslassen
    - 3D-Audio vom Fahrzeug mit Frontend-Fallback

    Beispiel Bone-Config:
    {
        type = 'rotation',
        axis = 'z',
        soundEffect = 'crane_rotate',  -- Key in Config.SoundEffects
    }
]]

-- Default Sound-Konfiguration (wird von Config.SoundEffects überschrieben)
local DefaultSoundEffects = {
    -- Kran: Basis-Drehung (Rotation der Leiter)
    crane_rotate = {
        name         = 'Move_Base',
        reference    = 'CRANE_SOUNDS',
        loopInterval = 2000,
        stopSound    = { name = 'Strain', reference = 'CRANE_SOUNDS' },
    },

    -- Kran: Hoch/Runter (Leiter neigen)
    crane_elevate = {
        name         = 'Move_U_D',
        reference    = 'CRANE_SOUNDS',
        loopInterval = 2000,
        stopSound    = { name = 'Strain', reference = 'CRANE_SOUNDS' },
    },

    -- Kran: Links/Rechts oder Ausfahren
    crane_extend = {
        name         = 'Move_L_R',
        reference    = 'CRANE_SOUNDS',
        loopInterval = 2000,
        stopSound    = { name = 'Strain', reference = 'CRANE_SOUNDS' },
    },

    -- Hydraulik (Stützen, allgemeine Hydraulik)
    hydraulic = {
        -- Richtungsabhängig: up-Sound und down-Sound
        directional  = true,
        upSound      = { name = 'Hydraulics_Up', reference = 'Lowrider_Super_Mod_Garage_Sounds' },
        downSound    = { name = 'Hydraulics_Down', reference = 'Lowrider_Super_Mod_Garage_Sounds' },
        loopInterval = 2200,
        stopSound    = { name = 'Strain', reference = 'CRANE_SOUNDS' },
    },

    -- Stabilisatoren / Schwere Motoren
    stabilizer = {
        name         = 'hangar_doors_loop',
        reference    = 'dlc_xm_facility_entry_exit_sounds',
        loopInterval = 2500,
        stopSound    = { name = 'hangar_doors_limit', reference = 'dlc_xm_facility_entry_exit_sounds' },
    },

    -- Aufzug-Loop (Alternative für langsame Bewegungen)
    elevator = {
        directional  = true,
        upSound      = { name = 'Elevator_Ascending_Loop', reference = 'DLC_IE_Garage_Elevator_Sounds' },
        downSound    = { name = 'Elevator_Descending_Loop', reference = 'DLC_IE_Garage_Elevator_Sounds' },
        loopInterval = 3000,
        stopSound    = { name = 'Elevator_Stop', reference = 'DLC_IE_Garage_Elevator_Sounds' },
    },

    -- Frachtaufzug (schwer, industriell)
    freight = {
        name         = 'Motor_01',
        reference    = 'FREIGHT_ELEVATOR_SOUNDS',
        loopInterval = 2500,
    },

    -- Klammer/Verriegelung
    clamp = {
        name         = 'Clamp',
        reference    = 'CRANE_SOUNDS',
        loopInterval = 0, -- Einmal abspielen, kein Loop
    },
}

-- ============================================
-- HELPER: Sound-Config auflösen
-- ============================================
local function GetSoundConfig(soundType)
    -- Erst in Config.SoundEffects schauen (User-Config)
    if Config.SoundEffects and Config.SoundEffects[soundType] then
        return Config.SoundEffects[soundType]
    end
    -- Dann Defaults
    return DefaultSoundEffects[soundType]
end

-- ============================================
-- HELPER: Sound-Name + Reference für Richtung auflösen
-- ============================================
local function ResolveSoundNameRef(config, direction)
    if config.directional and direction then
        if direction > 0 and config.upSound then
            return config.upSound.name, config.upSound.reference
        elseif direction < 0 and config.downSound then
            return config.downSound.name, config.downSound.reference
        end
    end
    return config.name, config.reference
end

-- ============================================
-- MARK BONE AS MOVING (aufgerufen von main.lua)
-- ============================================
function MarkBoneMoving(vehicle, boneIndex, soundType, direction)
    if not soundType then return end
    local netId = SafeGetNetId(vehicle)
    if not netId then return end

    local boneKey = netId .. '_' .. boneIndex
    bonesMovingThisFrame[boneKey] = {
        soundType = soundType,
        direction = direction or 0,
        vehicle   = vehicle,
    }
end

-- ============================================
-- START SOUND FÜR BONE
-- ============================================
local function StartBoneSound(vehicle, boneKey, soundType, direction)
    local config = GetSoundConfig(soundType)
    if not config then
        if Config.Debug then
            print('^1[D4rk_Sound] Unknown sound type: ' .. tostring(soundType) .. '^7')
        end
        return
    end

    local soundName, soundRef = ResolveSoundNameRef(config, direction)
    if not soundName or not soundRef then return end

    local soundId = GetSoundId()
    local isFrontend = false

    -- 3D Sound vom Fahrzeug
    if DoesEntityExist(vehicle) then
        PlaySoundFromEntity(soundId, soundName, vehicle, soundRef, false, 0)

        -- Fallback-Check: Wenn Sound nach 100ms nicht spielt
        Citizen.SetTimeout(100, function()
            if activeSounds[boneKey] and activeSounds[boneKey].soundId == soundId then
                if HasSoundFinished(soundId) then
                    -- 3D hat nicht funktioniert, Fallback zu Frontend
                    StopSound(soundId)
                    ReleaseSoundId(soundId)

                    local newId = GetSoundId()
                    PlaySoundFrontend(newId, soundName, soundRef, true)
                    activeSounds[boneKey].soundId = newId
                    activeSounds[boneKey].isFrontend = true

                    if Config.Debug then
                        print('^3[D4rk_Sound] Fallback to frontend: ' .. soundName .. '/' .. soundRef .. '^7')
                    end
                end
            end
        end)
    else
        -- Kein Entity, direkt Frontend
        PlaySoundFrontend(soundId, soundName, soundRef, true)
        isFrontend = true
    end

    activeSounds[boneKey] = {
        soundId      = soundId,
        startTime    = GetGameTimer(),
        config       = config,
        soundType    = soundType,
        direction    = direction,
        loopInterval = config.loopInterval or 2000,
        isFrontend   = isFrontend,
        vehicle      = vehicle,
    }

    if Config.Debug then
        print('^2[D4rk_Sound] Start: ' .. soundName .. '/' .. soundRef
            .. ' (bone: ' .. boneKey .. ', dir: ' .. tostring(direction) .. ')^7')
    end
end

-- ============================================
-- STOP SOUND FÜR BONE
-- ============================================
local function StopBoneSound(boneKey)
    local active = activeSounds[boneKey]
    if not active then return end

    -- Aktuellen Sound stoppen
    if active.soundId then
        StopSound(active.soundId)
        ReleaseSoundId(active.soundId)
    end

    -- Optionaler Stop-Sound (mechanisches Klack/Ächzen)
    if active.config and active.config.stopSound then
        local stopName = active.config.stopSound.name
        local stopRef  = active.config.stopSound.reference
        if stopName and stopRef then
            local stopId = GetSoundId()
            if active.vehicle and DoesEntityExist(active.vehicle) then
                PlaySoundFromEntity(stopId, stopName, active.vehicle, stopRef, false, 0)
            else
                PlaySoundFrontend(stopId, stopName, stopRef, true)
            end
            -- Stop-Sound nach kurzer Zeit freigeben
            Citizen.SetTimeout(2000, function()
                if not HasSoundFinished(stopId) then
                    StopSound(stopId)
                end
                ReleaseSoundId(stopId)
            end)
        end
    end

    activeSounds[boneKey] = nil

    if Config.Debug then
        print('^3[D4rk_Sound] Stop: bone ' .. boneKey .. '^7')
    end
end

-- ============================================
-- STOP ALL SOUNDS (Cleanup)
-- ============================================
function StopAllBoneSounds()
    for boneKey, _ in pairs(activeSounds) do
        local active = activeSounds[boneKey]
        if active and active.soundId then
            StopSound(active.soundId)
            ReleaseSoundId(active.soundId)
        end
    end
    activeSounds = {}
    bonesMovingThisFrame = {}
    bonesMovingLastFrame = {}

    if Config.Debug then
        print('^3[D4rk_Sound] All sounds stopped^7')
    end
end

-- ============================================
-- SOUND MANAGEMENT THREAD
-- Läuft jeden Frame, vergleicht moving vs. nicht-moving
-- ============================================
Citizen.CreateThread(function()
    while true do
        Wait(0)

        local now = GetGameTimer()

        -- 1. Neue Bewegungen starten
        for boneKey, data in pairs(bonesMovingThisFrame) do
            if not bonesMovingLastFrame[boneKey] then
                -- Bone hat gerade angefangen sich zu bewegen
                StartBoneSound(data.vehicle, boneKey, data.soundType, data.direction)
            end
        end

        -- 2. Gestoppte Bewegungen beenden
        for boneKey, _ in pairs(bonesMovingLastFrame) do
            if not bonesMovingThisFrame[boneKey] then
                -- Bone hat aufgehört sich zu bewegen
                StopBoneSound(boneKey)
            end
        end

        -- 3. Laufende Sounds: Loop-Management + Richtungswechsel
        for boneKey, active in pairs(activeSounds) do
            if bonesMovingThisFrame[boneKey] and active.loopInterval > 0 then
                local elapsed = now - active.startTime
                local currentData = bonesMovingThisFrame[boneKey]

                -- Richtungswechsel erkennen (bei directional sounds)
                local dirChanged = active.config.directional
                    and currentData.direction ~= 0
                    and active.direction ~= 0
                    and ((currentData.direction > 0) ~= (active.direction > 0))

                if dirChanged or elapsed >= active.loopInterval then
                    -- Alten Sound stoppen (ohne Stop-Sound)
                    if active.soundId then
                        StopSound(active.soundId)
                        ReleaseSoundId(active.soundId)
                    end
                    activeSounds[boneKey] = nil

                    -- Neuen Sound mit aktueller Richtung starten
                    StartBoneSound(
                        currentData.vehicle,
                        boneKey,
                        currentData.soundType,
                        currentData.direction
                    )
                end
            end
        end

        -- 4. Frame-Tracking rotieren
        bonesMovingLastFrame = bonesMovingThisFrame
        bonesMovingThisFrame = {}
    end
end)

-- ============================================
-- TEST COMMAND: /testsound
-- ============================================
RegisterCommand('testsound', function(_, args)
    local ped = PlayerPedId()
    local vehicle = nil

    -- Nächstes Fahrzeug finden für 3D-Test
    local coords = GetEntityCoords(ped)
    local nearVeh = GetClosestVehicle(coords.x, coords.y, coords.z, 15.0, 0, 70)
    if DoesEntityExist(nearVeh) then
        vehicle = nearVeh
    end

    local testSounds = {
        { name = 'Move_Base',                ref = 'CRANE_SOUNDS',                      desc = 'Kran Basis-Dreh' },
        { name = 'Move_U_D',                 ref = 'CRANE_SOUNDS',                      desc = 'Kran Hoch/Runter' },
        { name = 'Move_L_R',                 ref = 'CRANE_SOUNDS',                      desc = 'Kran Links/Rechts' },
        { name = 'Strain',                   ref = 'CRANE_SOUNDS',                      desc = 'Kran Ächzen' },
        { name = 'Clamp',                    ref = 'CRANE_SOUNDS',                      desc = 'Kran Klammer' },
        { name = 'Hydraulics_Up',            ref = 'Lowrider_Super_Mod_Garage_Sounds',  desc = 'Hydraulik Hoch' },
        { name = 'Hydraulics_Down',          ref = 'Lowrider_Super_Mod_Garage_Sounds',  desc = 'Hydraulik Runter' },
        { name = 'Elevator_Ascending_Loop',  ref = 'DLC_IE_Garage_Elevator_Sounds',     desc = 'Aufzug Hoch (Loop)' },
        { name = 'Elevator_Descending_Loop', ref = 'DLC_IE_Garage_Elevator_Sounds',     desc = 'Aufzug Runter (Loop)' },
        { name = 'Elevator_Stop',            ref = 'DLC_IE_Garage_Elevator_Sounds',     desc = 'Aufzug Stop' },
        { name = 'hangar_doors_loop',        ref = 'dlc_xm_facility_entry_exit_sounds', desc = 'Hangar Motor (Loop)' },
        { name = 'hangar_doors_limit',       ref = 'dlc_xm_facility_entry_exit_sounds', desc = 'Hangar Anschlag' },
        { name = 'Motor_01',                 ref = 'FREIGHT_ELEVATOR_SOUNDS',           desc = 'Fracht-Motor' },
        { name = 'Elevator_Start',           ref = 'DLC_IE_Garage_Elevator_Sounds',     desc = 'Aufzug Start' },
        { name = 'Container_Attach',         ref = 'CRANE_SOUNDS',                      desc = 'Kran Anhängen' },
        { name = 'Detach_Container',         ref = 'CRANE_SOUNDS',                      desc = 'Kran Lösen' },
    }

    local arg = args[1]

    -- Hilfe
    if not arg then
        print('^5=== D4rk Sound Test ===^7')
        print('^5/testsound all^7   - Alle nacheinander')
        print('^5/testsound 1-' .. #testSounds .. '^7  - Einzelner Sound')
        print('^5/testsound 3d^7   - 3D-Test am Fahrzeug')
        print('')
        for i, s in ipairs(testSounds) do
            print(string.format('^7  %2d. %-30s %s', i, s.desc, s.ref .. '/' .. s.name))
        end
        return
    end

    -- Alle abspielen
    if arg == 'all' then
        print('^5[D4rk_Sound] Spiele alle ' .. #testSounds .. ' Sounds...^7')
        for i, s in ipairs(testSounds) do
            Citizen.SetTimeout((i - 1) * 1800, function()
                local id = GetSoundId()
                if vehicle then
                    PlaySoundFromEntity(id, s.name, vehicle, s.ref, false, 0)
                else
                    PlaySoundFrontend(id, s.name, s.ref, true)
                end
                print(string.format('🔊 [%2d/%d] %-25s %s/%s ID:%d',
                    i, #testSounds, s.desc, s.ref, s.name, id))

                -- Check nach 1.2s
                Citizen.SetTimeout(1200, function()
                    if not HasSoundFinished(id) then
                        print('   ↳ ✅ Sound #' .. i .. ' spielt noch nach 1.2s')
                        Citizen.SetTimeout(1500, function()
                            StopSound(id)
                            ReleaseSoundId(id)
                        end)
                    else
                        print('   ↳ ⏱ Sound #' .. i .. ' bereits beendet (kurzer Sound)')
                        ReleaseSoundId(id)
                    end
                end)
            end)
        end
        return
    end

    -- 3D Test: Spielt Kran-Sounds direkt am Fahrzeug
    if arg == '3d' then
        if not vehicle then
            print('^1[D4rk_Sound] Kein Fahrzeug in der Nähe für 3D-Test!^7')
            return
        end
        print('^5[D4rk_Sound] 3D-Test am Fahrzeug...^7')
        local sounds3d = { 1, 2, 3, 6, 7, 11 } -- Beste Kandidaten
        for idx, i in ipairs(sounds3d) do
            local s = testSounds[i]
            Citizen.SetTimeout((idx - 1) * 2500, function()
                local id = GetSoundId()
                PlaySoundFromEntity(id, s.name, vehicle, s.ref, false, 0)
                print(string.format('🔊 3D [%d] %s - Geh ums Fahrzeug!', i, s.desc))
                Citizen.SetTimeout(2200, function()
                    StopSound(id)
                    ReleaseSoundId(id)
                end)
            end)
        end
        return
    end

    -- Einzelner Sound
    local num = tonumber(arg)
    if num and testSounds[num] then
        local s = testSounds[num]
        local id = GetSoundId()
        if vehicle then
            PlaySoundFromEntity(id, s.name, vehicle, s.ref, false, 0)
            print(string.format('🔊 3D: %s (%s/%s)', s.desc, s.ref, s.name))
        else
            PlaySoundFrontend(id, s.name, s.ref, true)
            print(string.format('🔊 2D: %s (%s/%s)', s.desc, s.ref, s.name))
        end

        Citizen.SetTimeout(1200, function()
            if not HasSoundFinished(id) then
                print('   ↳ ✅ Spielt noch nach 1.2s (langer Sound!)')
                Citizen.SetTimeout(3000, function()
                    StopSound(id)
                    ReleaseSoundId(id)
                end)
            else
                print('   ↳ ⏱ Bereits beendet (kurzer Sound)')
                ReleaseSoundId(id)
            end
        end)
    else
        print('^1[D4rk_Sound] Ungültige Nummer. /testsound für Liste.^7')
    end
end, false)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        StopAllBoneSounds()
    end
end)
