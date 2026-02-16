Config = {}

-- ============================================
-- GENERAL SETTINGS
-- ============================================
Config.Locale = 'de'
Config.Debug = false

-- Control Modes
Config.UseRemoteControl = true
Config.UseStandingControl = true
Config.UseInVehicleControl = true

-- Distances
Config.MaxRemoteDistance = 50.0
Config.MaxStandingDistance = 5.0

-- Performance
Config.UpdateRate = 50 -- ms between updates (lower = smoother but more intensive)
Config.MaxBonesPerVehicle = 20

-- ============================================
-- KEYBINDS
-- ============================================
Config.Keys = {
    OpenMenu = 38,          -- E
    OpenRemote = 168,       -- F7
    EnterCage = 38,         -- E (when near cage)
    ExitCage = 73,          -- X
    ToggleWater = 47,       -- G
    MenuUp = 172,           -- Arrow Up
    MenuDown = 173,         -- Arrow Down
    MenuLeft = 174,         -- Arrow Left
    MenuRight = 175,        -- Arrow Right
    MenuSelect = 191,       -- Enter
    MenuBack = 177,         -- Backspace
    IncreaseControl = 172,  -- Arrow Up
    DecreaseControl = 173,  -- Arrow Down
    RotateLeft = 174,       -- Arrow Left
    RotateRight = 175,      -- Arrow Right
    StabilizersToggle = 47, -- G
}

-- ============================================
-- VEHICLES CONFIGURATION
-- ============================================
Config.Vehicles = {

    -- ==========================================
    -- FIRE DEPARTMENT - LADDER TRUCK (Advanced)
    -- ==========================================
    ['firetruk'] = {
        type = 'ladder',
        label = 'Feuerwehr Drehleiter',
        description = 'Drehleiter mit Rettungskorb und Wasserwerfer',

        -- Bone Configuration
        bones = {
            {
                name = 'misc_a',
                label = 'Turm Rotation',
                type = 'rotation',
                axis = 'z',
                min = -270.0,
                max = 270.0,
                default = 0.0,
                speed = 0.4,
                controlGroup = 'turret'
            },
            {
                name = 'misc_b',
                label = 'Leiter Anheben',
                type = 'rotation',
                axis = 'x',
                min = 0.0,
                max = 75.0,
                default = 0.0,
                speed = 0.3,
                controlGroup = 'ladder',
                soundEffect = 'hydraulic'
            },
            {
                name = 'misc_c',
                label = 'Leiter Ausfahren',
                type = 'position',
                axis = 'y',
                min = 0.0,
                max = 10.0,
                default = 0.0,
                speed = 0.15,
                controlGroup = 'ladder',
                soundEffect = 'hydraulic'
            },
            {
                name = 'misc_d',
                label = 'Korb Neigung',
                type = 'rotation',
                axis = 'x',
                min = -45.0,
                max = 45.0,
                default = 0.0,
                speed = 0.25,
                controlGroup = 'basket'
            }
        },

        -- Stabilizers (Stützen)
        stabilizers = {
            enabled = true,
            required = false, -- Empfohlen aber nicht Pflicht
            bones = {
                { name = 'misc_e', side = 'front_left',  offset = vector3(-1.5, 2.0, -0.8) },
                { name = 'misc_f', side = 'front_right', offset = vector3(1.5, 2.0, -0.8) },
                { name = 'misc_g', side = 'rear_left',   offset = vector3(-1.5, -2.0, -0.8) },
                { name = 'misc_h', side = 'rear_right',  offset = vector3(1.5, -2.0, -0.8) }
            },
            speed = 0.2,
            maxExtension = 1.5,
            soundEffect = 'stabilizer'
        },

        -- Cage/Basket System
        cage = {
            enabled = true,
            bone = 'misc_d', -- Attach bone
            enterDistance = 3.0,
            offset = vector3(0.0, 0.0, 0.5),
            rotation = vector3(0.0, 0.0, 0.0),
            canControl = true, -- Kann aus Korb steuern
            maxOccupants = 2
        },

        -- Water Monitor (Wasserwerfer)
        waterMonitor = {
            enabled = true,
            bone = 'weapon_1a',
            offset = vector3(0.0, 1.0, 0.3),
            rotation = vector3(0.0, 0.0, 0.0),
            particleEffect = 'core',
            particleName = 'water_cannon_jet',
            range = 30.0,
            pressure = 1.5,
            canRotate = true,
            rotationSpeed = 0.3,
            soundEffect = 'water_cannon'
        },

        -- Collision Objects (Begehbare Leiter)
        collision = {
            enabled = true,
            objects = {
                {
                    model = 'prop_ladder_01',
                    bone = 'misc_c',
                    offset = vector3(0.0, 0.0, 0.0),
                    rotation = vector3(0.0, 0.0, 0.0),
                    dynamic = true -- Bewegt sich mit Bone
                }
            }
        },

        -- UI Settings
        ui = {
            showSpeed = true,
            showAngle = true,
            showStability = true,
            theme = 'fire' -- fire, police, utility
        }
    },

    -- ==========================================
    -- CRANE TRUCK (Advanced)
    -- ==========================================
    ['flatbed'] = {
        type = 'crane',
        label = 'Schwerer Abschleppkran',
        description = 'Abschlepp-LKW mit drehbarem Kran',

        bones = {
            {
                name = 'misc_a',
                label = 'Kran Rotation',
                type = 'rotation',
                axis = 'z',
                min = -180.0,
                max = 180.0,
                default = 0.0,
                speed = 0.5,
                controlGroup = 'crane'
            },
            {
                name = 'misc_b',
                label = 'Ausleger Neigung',
                type = 'rotation',
                axis = 'x',
                min = -60.0,
                max = 60.0,
                default = 0.0,
                speed = 0.3,
                controlGroup = 'crane',
                soundEffect = 'hydraulic'
            },
            {
                name = 'misc_c',
                label = 'Ausleger Ausfahren',
                type = 'position',
                axis = 'y',
                min = 0.0,
                max = 8.0,
                default = 0.0,
                speed = 0.12,
                controlGroup = 'crane',
                soundEffect = 'hydraulic'
            },
            {
                name = 'misc_d',
                label = 'Seil Länge',
                type = 'position',
                axis = 'z',
                min = 0.0,
                max = 12.0,
                default = 0.0,
                speed = 0.25,
                controlGroup = 'winch',
                soundEffect = 'winch'
            }
        },

        stabilizers = {
            enabled = true,
            required = false,
            bones = {
                { name = 'misc_e', side = 'left',  offset = vector3(-1.2, 0.0, -0.6) },
                { name = 'misc_f', side = 'right', offset = vector3(1.2, 0.0, -0.6) }
            },
            speed = 0.2,
            maxExtension = 1.2
        },

        cage = {
            enabled = false
        },

        waterMonitor = {
            enabled = false
        },

        collision = {
            enabled = false
        },

        ui = {
            showSpeed = true,
            showAngle = true,
            theme = 'utility'
        }
    },

    -- ==========================================
    -- TOWER/PLATFORM TRUCK
    -- ==========================================
    ['tower_truck'] = {
        type = 'platform',
        label = 'Hubrettungsfahrzeug',
        description = 'Gelenkarm-Hubarbeitsbühne',

        bones = {
            {
                name = 'platform_base',
                label = 'Plattform Rotation',
                type = 'rotation',
                axis = 'z',
                min = -360.0,
                max = 360.0,
                default = 0.0,
                speed = 0.35,
                controlGroup = 'base'
            },
            {
                name = 'platform_arm_1',
                label = 'Unterer Arm',
                type = 'rotation',
                axis = 'x',
                min = -10.0,
                max = 75.0,
                default = 0.0,
                speed = 0.2,
                controlGroup = 'arm',
                soundEffect = 'hydraulic'
            },
            {
                name = 'platform_arm_2',
                label = 'Oberer Arm',
                type = 'rotation',
                axis = 'x',
                min = -75.0,
                max = 75.0,
                default = 0.0,
                speed = 0.2,
                controlGroup = 'arm',
                soundEffect = 'hydraulic'
            },
            {
                name = 'platform_basket',
                label = 'Korb Position',
                type = 'position',
                axis = 'z',
                min = 0.0,
                max = 5.0,
                default = 0.0,
                speed = 0.15,
                controlGroup = 'basket'
            },
            {
                name = 'platform_basket_rotate',
                label = 'Korb Rotation',
                type = 'rotation',
                axis = 'z',
                min = -180.0,
                max = 180.0,
                default = 0.0,
                speed = 0.3,
                controlGroup = 'basket'
            }
        },

        stabilizers = {
            enabled = true,
            required = true,
            bones = {
                { name = 'stabilizer_fl', side = 'front_left',  offset = vector3(-1.8, 2.5, -0.9) },
                { name = 'stabilizer_fr', side = 'front_right', offset = vector3(1.8, 2.5, -0.9) },
                { name = 'stabilizer_rl', side = 'rear_left',   offset = vector3(-1.8, -2.5, -0.9) },
                { name = 'stabilizer_rr', side = 'rear_right',  offset = vector3(1.8, -2.5, -0.9) }
            },
            speed = 0.18,
            maxExtension = 2.0
        },

        cage = {
            enabled = true,
            bone = 'platform_basket',
            enterDistance = 3.5,
            offset = vector3(0.0, 0.0, 1.0),
            rotation = vector3(0.0, 0.0, 0.0),
            canControl = true,
            maxOccupants = 2
        },

        waterMonitor = {
            enabled = false
        },

        collision = {
            enabled = false
        },

        ui = {
            showSpeed = true,
            showAngle = true,
            showHeight = true,
            theme = 'fire'
        }
    },

    -- ==========================================
    -- UTILITY BUCKET TRUCK
    -- ==========================================
    ['utillitruck'] = {
        type = 'utility',
        label = 'Service Hubarbeitsbühne',
        description = 'Wartungsfahrzeug mit Arbeitskorb',

        bones = {
            {
                name = 'misc_a',
                label = 'Bühne Anheben',
                type = 'rotation',
                axis = 'x',
                min = 0.0,
                max = 75.0,
                default = 0.0,
                speed = 0.28,
                controlGroup = 'lift',
                soundEffect = 'hydraulic'
            },
            {
                name = 'misc_b',
                label = 'Bühne Ausfahren',
                type = 'position',
                axis = 'y',
                min = 0.0,
                max = 4.0,
                default = 0.0,
                speed = 0.12,
                controlGroup = 'lift'
            },
            {
                name = 'misc_c',
                label = 'Korb Rotation',
                type = 'rotation',
                axis = 'z',
                min = -90.0,
                max = 90.0,
                default = 0.0,
                speed = 0.25,
                controlGroup = 'basket'
            }
        },

        stabilizers = {
            enabled = true,
            required = false,
            bones = {
                { name = 'misc_d', side = 'left',  offset = vector3(-1.0, 0.0, -0.5) },
                { name = 'misc_e', side = 'right', offset = vector3(1.0, 0.0, -0.5) }
            },
            speed = 0.2,
            maxExtension = 1.0
        },

        cage = {
            enabled = true,
            bone = 'misc_c',
            enterDistance = 2.5,
            offset = vector3(0.0, 0.0, 0.5),
            rotation = vector3(0.0, 0.0, 0.0),
            canControl = true,
            maxOccupants = 1
        },

        ui = {
            theme = 'utility'
        }
    }
}

-- ============================================
-- SOUND EFFECTS
-- ============================================
Config.SoundEffects = {
    hydraulic = {
        name = 'Hydraulic',
        volume = 0.3,
        reference = 'DLC_APT_YACHT_DOOR_SOUNDS'
    },
    winch = {
        name = 'Winch',
        volume = 0.4,
        reference = 'DLC_EXEC_WAREHOUSE_LIFT'
    },
    stabilizer = {
        name = 'Stabilizer',
        volume = 0.25,
        reference = 'DLC_APT_YACHT_DOOR_SOUNDS'
    },
    water_cannon = {
        name = 'WATERING_CAN_SPRINKLE',
        volume = 0.5,
        reference = 'FAMILY_5_SOUNDS'
    }
}

-- ============================================
-- TRANSLATIONS
-- ============================================
Config.Translations = {
    ['de'] = {
        -- Menu
        ['open_menu'] = 'Drücke ~INPUT_CONTEXT~ für Steuerung',
        ['open_remote'] = 'Drücke ~INPUT_SELECT_CHARACTER_TREVOR~ für Fernbedienung',
        ['menu_title'] = 'Fahrzeugsteuerung',

        -- Controls
        ['control_active'] = 'Steuerung aktiv',
        ['control_stopped'] = 'Steuerung beendet',
        ['too_far'] = 'Zu weit entfernt vom Fahrzeug',
        ['already_controlled'] = 'Fahrzeug wird bereits gesteuert',

        -- Stabilizers
        ['stabilizers_deployed'] = 'Stützen ausgefahren',
        ['stabilizers_retracted'] = 'Stützen eingefahren',
        ['stabilizers_required'] = 'Stützen müssen ausgefahren sein',
        ['stabilizers_deploying'] = 'Stützen werden ausgefahren...',
        ['stabilizers_retracting'] = 'Stützen werden eingefahren...',

        -- Cage
        ['cage_enter'] = 'Drücke ~INPUT_CONTEXT~ um in Korb zu steigen',
        ['cage_exit'] = 'Drücke ~INPUT_VEH_EXIT~ um Korb zu verlassen',
        ['cage_entered'] = 'Im Rettungskorb',
        ['cage_exited'] = 'Rettungskorb verlassen',
        ['cage_full'] = 'Korb ist voll',
        ['cage_too_far'] = 'Korb ist zu weit entfernt',

        -- Water
        ['water_activated'] = 'Wasserwerfer aktiviert',
        ['water_deactivated'] = 'Wasserwerfer deaktiviert',
        ['water_toggle'] = 'Drücke ~INPUT_DETONATE~ um Wasserwerfer zu schalten',

        -- Remote
        ['remote_activated'] = 'Fernbedienung aktiv',
        ['remote_deactivated'] = 'Fernbedienung deaktiviert',

        -- Status
        ['speed'] = 'Geschwindigkeit',
        ['angle'] = 'Winkel',
        ['extension'] = 'Ausfahrung',
        ['height'] = 'Höhe',
        ['rotation'] = 'Rotation',
    }
}

-- ============================================
-- ANIMATIONS
-- ============================================
Config.Animations = {
    remote = {
        dict = 'amb@world_human_stand_mobile@male@text@base',
        anim = 'base',
        flag = 49
    },
    standing_control = {
        dict = 'amb@prop_human_parking_meter@female@idle_a',
        anim = 'idle_a',
        flag = 1
    },
    cage_enter = {
        dict = 'move_m@_idles@standing@',
        anim = 'idle_a',
        flag = 1
    }
}
