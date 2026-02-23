-- D4rk Smart Vehicle - NUI Controls Bridge
-- VERSION 1.0 - Verbindet alle 3 Panels mit dem Steuersystem
-- Panel (ladderControl), Remote (remoteControl), Dashboard (dashboardControl)
-- Alle senden die gleichen Actions → gleicher Handler

-- ============================================
-- ACTION → BONE MAPPING
-- NUI Action → controlGroup + Richtung
-- ============================================
local ACTION_MAP = {
    -- Joystick: Turm + Leiter
    elevate_up   = { group = 'ladder', delta = 1.0 },
    elevate_down = { group = 'ladder', delta = -1.0 },
    rotate_left  = { group = 'turret', delta = -1.0 },
    rotate_right = { group = 'turret', delta = 1.0 },

    -- Ausfahren
    extend_out   = { group = 'extend', delta = 1.0 },
    extend_in    = { group = 'extend', delta = -1.0 },

    -- Korb
    basket_left  = { group = 'basket', delta = -1.0 },
    basket_right = { group = 'basket', delta = 1.0 },
}

-- Aktive NUI-Aktionen (hold-to-move)
local activeNuiActions = {}

-- Welches Panel ist gerade aktiv
local activePanel = nil -- 'ladder', 'remote', 'dashboard'

-- ============================================
-- ZENTRALER ACTION HANDLER
-- Alle 3 Panels nutzen denselben
-- ============================================
function HandleNuiAction(data, cb)
    local action = data.action
    local state = data.state

    if not action then
        cb('ok')
        return
    end

    -- Hold-to-Move Actions (Bones steuern)
    if ACTION_MAP[action] then
        if state == 'start' then
            activeNuiActions[action] = ACTION_MAP[action]
            if Config.Debug then
                print(string.format('[D4rk_Smart NUI] Action START: %s (group=%s, delta=%.1f)',
                    action, ACTION_MAP[action].group, ACTION_MAP[action].delta))
            end
        elseif state == 'stop' then
            activeNuiActions[action] = nil
            if Config.Debug then
                print(string.format('[D4rk_Smart NUI] Action STOP: %s', action))
            end
        end
        cb('ok')
        return
    end

    -- System Actions (einmalig)
    if action == 'stabilizers_toggle' or action == 'stabilizers_deploy' or action == 'stabilizers_retract' then
        if currentVehicle then
            ToggleStabilizers(currentVehicle)
        end
    elseif action == 'emergency_stop' then
        -- Alle aktiven Aktionen sofort stoppen
        activeNuiActions = {}
        if currentVehicle then
            ResetAllControls(currentVehicle)
        end
        ShowNotification('NOT-STOPP ausgelöst!', 'warning')
    elseif action == 'reset_all' then
        activeNuiActions = {}
        if currentVehicle then
            ResetAllControls(currentVehicle)
        end
    elseif action == 'toggle_power' then
        if state == 'on' then
            -- Panel aktivieren (wird von Proximity Detection gehandelt)
        elseif state == 'off' then
            CloseNuiPanel()
        end
    elseif action == 'close_panel' then
        CloseNuiPanel()
    elseif action == 'preset_1' or action == 'preset_2' or action == 'preset_3' then
        -- Preset-System (für später vorbereitet)
        local presetNum = tonumber(action:sub(-1))
        if Config.Debug then
            print('[D4rk_Smart NUI] Preset ' .. presetNum .. ' angefordert (noch nicht implementiert)')
        end
        ShowNotification('Preset ' .. presetNum .. ' (bald verfügbar)', 'info')
    end

    cb('ok')
end

-- ============================================
-- NUI CALLBACKS — Alle 3 Panels
-- ============================================
RegisterNUICallback('ladderControl', function(data, cb)
    activePanel = 'ladder'
    HandleNuiAction(data, cb)
end)

RegisterNUICallback('remoteControl', function(data, cb)
    activePanel = 'remote'
    HandleNuiAction(data, cb)
end)

RegisterNUICallback('dashboardControl', function(data, cb)
    activePanel = 'dashboard'
    HandleNuiAction(data, cb)
end)

-- ============================================
-- HOLD-TO-MOVE THREAD
-- Verarbeitet aktive NUI Actions → UpdateControl
-- ============================================
Citizen.CreateThread(function()
    while true do
        Wait(0)

        if not currentVehicle or not currentConfig then
            -- Nichts zu tun, alle Actions clearen
            if next(activeNuiActions) then
                activeNuiActions = {}
            end
            goto continue
        end

        -- Jede aktive Action → passendes Bone finden → UpdateControl
        for action, mapping in pairs(activeNuiActions) do
            local group = mapping.group
            local delta = mapping.delta

            -- Finde den Bone mit diesem controlGroup
            for i, bone in ipairs(currentConfig.bones) do
                if bone.controlGroup == group then
                    UpdateControl(currentVehicle, i, delta)
                    break -- Nur ersten Bone dieser Gruppe steuern
                end
            end
        end

        ::continue::
    end
end)

-- ============================================
-- LIVE VALUE UPDATE THREAD
-- Sendet aktuelle Werte an das aktive NUI Panel
-- ============================================
Citizen.CreateThread(function()
    while true do
        Wait(100) -- 10x pro Sekunde

        if not currentVehicle or not currentConfig then
            goto continue
        end

        local state = GetVehicleState(currentVehicle)
        if not state then goto continue end

        -- Werte aus controlValues lesen
        local rotation = 0
        local elevation = 0
        local extend = 0
        local basket = 0

        for i, bone in ipairs(currentConfig.bones) do
            local val = state.controlValues[i] or 0
            if bone.controlGroup == 'turret' or bone.controlGroup == 'base' then
                rotation = val
            elseif bone.controlGroup == 'ladder' or bone.controlGroup == 'crane' or bone.controlGroup == 'arm' or bone.controlGroup == 'lift' then
                elevation = val
            elseif bone.controlGroup == 'extend' or bone.controlGroup == 'winch' then
                extend = val
            elseif bone.controlGroup == 'basket' or bone.controlGroup == 'hook' then
                basket = val
            end
        end

        -- An alle Panels senden (nur das aktive zeigt es an)
        SendNUIMessage({
            action = 'updateValues',
            rotation = rotation,
            elevation = elevation,
            extend = extend,
            basket = basket,
            maxElevation = GetMaxForGroup('ladder'),
            maxExtend = GetMaxForGroup('extend'),
        })

        ::continue::
    end
end)

-- ============================================
-- HELPER: Max-Wert für eine ControlGroup finden
-- ============================================
function GetMaxForGroup(group)
    if not currentConfig or not currentConfig.bones then return 100 end
    for _, bone in ipairs(currentConfig.bones) do
        if bone.controlGroup == group then
            return bone.max or 100
        end
    end
    return 100
end

-- ============================================
-- PANEL ÖFFNEN / SCHLIEẞEN
-- ============================================
function OpenNuiPanel(panelType, vehicle, vehicleName)
    activePanel = panelType
    activeNuiActions = {} -- Sicherstellen dass keine alten Actions laufen

    local config = GetVehicleConfig(vehicleName)
    if not config then return end

    local state = GetVehicleState(vehicle)

    -- Panel-spezifische Show-Message
    if panelType == 'ladder' then
        SendNUIMessage({
            action = 'showLadderPanel',
            vehicleName = config.label or vehicleName,
        })
    elseif panelType == 'remote' then
        SendNUIMessage({
            action = 'showRemote',
            vehicleName = config.label or vehicleName,
        })
    elseif panelType == 'dashboard' then
        SendNUIMessage({
            action = 'showDashboard',
            vehicleName = config.label or vehicleName,
        })
    end

    -- Stabilizer-Status senden
    if state then
        SendNUIMessage({
            action = 'updateStabilizers',
            deployed = state.stabilizersDeployed or false,
        })
    end

    if Config.Debug then
        print(string.format('[D4rk_Smart NUI] Panel geöffnet: %s für %s', panelType, vehicleName))
    end
end

function CloseNuiPanel()
    -- Alle aktiven Aktionen stoppen
    activeNuiActions = {}

    -- Alle Panels schließen (nur das aktive reagiert)
    SendNUIMessage({ action = 'hideLadderPanel' })
    SendNUIMessage({ action = 'hideRemote' })
    SendNUIMessage({ action = 'hideDashboard' })

    activePanel = nil

    if Config.Debug then
        print('[D4rk_Smart NUI] Panel geschlossen')
    end
end

-- ============================================
-- STABILIZER SYNC → NUI
-- Wird aufgerufen wenn sich Stützen-Status ändert
-- ============================================
function SyncStabilizersToNui(deployed)
    SendNUIMessage({
        action = 'updateStabilizers',
        deployed = deployed,
    })
end

-- ============================================
-- INTEGRATION HOOKS
-- Rufe diese Funktionen aus controls.lua / main.lua auf
-- ============================================

-- In OpenControlPanel() (main.lua) hinzufügen:
--   OpenNuiPanel('dashboard', vehicle, vehicleName)  -- Im Fahrzeug
--   OpenNuiPanel('ladder', vehicle, vehicleName)      -- Standing auf ladder_base

-- In ActivateRemote() (controls.lua) hinzufügen:
--   OpenNuiPanel('remote', vehicle, vehicleName)

-- In CloseControlPanel() / DeactivateRemote() hinzufügen:
--   CloseNuiPanel()

-- In ToggleStabilizers() nach dem Toggle hinzufügen:
--   SyncStabilizersToNui(deployed)

-- ============================================
-- CLEANUP
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    activeNuiActions = {}
    CloseNuiPanel()
end)
