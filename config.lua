Config = {}

-- ============================================
-- GENERAL SETTINGS
-- ============================================
Config.Locale = 'de'
Config.Debug = true         -- Wichtige Events (Spawn, Delete, Errors)
Config.DebugVerbose = false -- Frame-by-Frame Logs (NUR für Entwicklung!)

-- Control Modes
Config.UseRemoteControl = true
Config.UseStandingControl = true
Config.UseInVehicleControl = true

-- Distances
Config.MaxRemoteDistance = 50.0
Config.MaxStandingDistance = 5.0

-- Performance
Config.UpdateRate = 50
Config.MaxBonesPerVehicle = 20

-- ============================================
-- KEYBINDS
-- ============================================
Config.Keys = {
    OpenMenu          = 38,  -- E
    OpenRemote        = 168, -- F7
    EnterCage         = 38,  -- E
    ExitCage          = 73,  -- X
    ToggleWater       = 47,  -- G
    StabilizersToggle = 47,  -- G
}

-- ============================================
-- CONTROL GROUPS
-- Zentrale Tasten-Zuordnung + NUI Labels
-- Neue Gruppe = 1 Zeile hier, fertig!
--
-- increase = Taste für +/rechts/hoch
-- decrease = Taste für -/links/runter
-- label    = Anzeige im NUI Panel
-- shift    = true → braucht zusätzlich Shift gedrückt
-- ============================================
Config.ControlGroups = {
    turret    = { increase = 109, decrease = 108, label = 'Turm' },             -- Numpad 6 / 4
    base      = { increase = 109, decrease = 108, label = 'Basis' },            -- Numpad 6 / 4
    ladder    = { increase = 172, decrease = 173, label = 'Leiter' },           -- Pfeil Hoch / Runter
    crane     = { increase = 172, decrease = 173, label = 'Kran' },             -- Pfeil Hoch / Runter
    arm       = { increase = 172, decrease = 173, label = 'Ausleger' },         -- Pfeil Hoch / Runter
    lift      = { increase = 172, decrease = 173, label = 'Hebebühne' },        -- Pfeil Hoch / Runter
    platform  = { increase = 172, decrease = 173, label = 'Plattform' },        -- Pfeil Hoch / Runter
    extend    = { increase = 85, decrease = 48, label = 'Ausfahren' },          -- Q / Z
    winch     = { increase = 85, decrease = 48, label = 'Winde' },              -- Q / Z
    hydraulic = { increase = 85, decrease = 48, label = 'Hydraulik' },          -- Q / Z
    basket    = { increase = 85, decrease = 48, label = 'Korb', shift = true }, -- Shift+Q / Shift+Z
    hook      = { increase = 85, decrease = 48, label = 'Haken', shift = true },
    water     = { increase = 174, decrease = 175, label = 'Wasserwerfer' },     -- Pfeil Links / Rechts
    light     = { increase = 174, decrease = 175, label = 'Beleuchtung' },      -- Pfeil Links / Rechts
}

-- ============================================
-- SOUND / RPM SYSTEM
-- Motor dreht hoch wenn Bones bewegt werden (PTO/Nebenabtrieb)
-- Bones mit soundEffect = true lösen RPM-Erhöhung aus
-- Konfiguration in sounds.lua (RPM_CONFIG)
-- ============================================

-- ============================================
-- VEHICLES CONFIGURATION
-- ============================================
Config.Vehicles = {

    -- ==========================================
    -- FIRE DEPARTMENT - LADDER TRUCK
    -- ==========================================
    ['ladder'] = {
        type = 'ladder',
        label = 'Feuerwehr Drehleiter',
        description = 'Drehleiter mit Rettungskorb und Wasserwerfer',

        standingControl = {
            requireBoneProp = 1,
            maxDistance     = 3.0,
        },

        -- ======================
        -- BONES (Prop-basiert!)
        -- ======================
        -- Hierarchie:
        --   Fahrzeug (bodyshell)
        --     └─ #1 Turm (dreht Z)          → crane_rotate   🔊 Drehkranz-Motor
        --         └─ #2 Leiter (hebt X)      → crane_elevate  🔊 Kran Heben
        --             └─ #3 Ausfahren (Y)     → crane_extend   🔊 Kran Teleskop
        --                 └─ #4 Korb (kippt X) → hydraulic      🔊 Hydraulik ↑↓
        --                 └─ Cage-Prop
        --                 └─ Water-Prop
        bones = {
            -- #1: Turm Rotation → Numpad 4/6
            {
                name            = 'turm',
                label           = 'Turm Rotation',
                type            = 'rotation',
                axis            = 'z',
                min             = -270.0,
                max             = 270.0,
                default         = 0.0,
                speed           = 0.09,
                controlGroup    = 'turret',
                soundEffect     = true,
                propModel       = 'ladder_base',
                attachTo        = 'vehicle',
                attachBone      = 'bodyshell',
                defaultOffset   = vector3(-0.02, -4.82, 1.64),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #2: Leiter Anheben → Pfeil Hoch/Runter
            {
                name            = 'leiter_heben',
                label           = 'Leiter Anheben',
                type            = 'rotation',
                axis            = 'x',
                min             = 0.0,
                max             = 75.0,
                default         = 0.0,
                speed           = 0.05,
                controlGroup    = 'ladder',
                soundEffect     = true,
                propModel       = 'ladder_main_0',
                attachTo        = '1',
                defaultOffset   = vector3(0.0, 0.5, 0.35),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #3: Leiter Ausfahren → Q/Z
            {
                name            = 'leiter_ausfahren',
                label           = 'Leiter Ausfahren',
                type            = 'position',
                axis            = 'y',
                min             = 0.0,
                max             = 4.7,
                default         = 0.0,
                speed           = 0.02,
                controlGroup    = 'extend',
                soundEffect     = true,
                propModel       = 'ladder_main_1',
                attachTo        = '2',
                defaultOffset   = vector3(0.0, 0.0, 0.0),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #4: Korb neigen → Shift+Q/Z
            {
                name            = 'korb',
                label           = 'Korb Rotation',
                type            = 'rotation',
                axis            = 'x',
                min             = -45.0,
                max             = 55.0,
                default         = 0.0,
                speed           = 0.3,
                controlGroup    = 'basket',
                soundEffect     = true,
                propModel       = 'ladder_bucket',
                attachTo        = '3',
                defaultOffset   = vector3(0.0, 7.9, -0.2),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
        },


        -- ======================
        -- STABILIZERS (Prop-basiert)
        -- ======================
        stabilizers = {
            enabled      = true,
            required     = false,
            propModel    = 'outr_down_l1',
            maxExtension = 1.5,
            animDuration = 2000,
            liftHeight   = 0.4,
            bones        = {
                { side = 'front_left',  offset = vector3(-1.5, 2.0, -0.3),  attachBone = 'bodyshell' },
                { side = 'front_right', offset = vector3(1.5, 2.0, -0.3),   attachBone = 'bodyshell' },
                { side = 'rear_left',   offset = vector3(-1.5, -2.0, -0.3), attachBone = 'bodyshell' },
                { side = 'rear_right',  offset = vector3(1.5, -2.0, -0.3),  attachBone = 'bodyshell' },
            },
        },

        -- ======================
        -- CAGE (Prop-basiert, an Leiter-Spitze #3)
        -- ======================
        cage = {
            enabled       = true,
            useBoneProp   = 4,
            playerOffset  = vector3(0.0, 0.6, 1.0),
            enterDistance = 3.0,
            canControl    = true,
            maxOccupants  = 2,
        },

        -- ======================
        -- WATER MONITOR (Prop-basiert, an Leiter-Spitze #3)
        -- ======================
        waterMonitor = {
            enabled        = true,
            propModel      = '',
            attachTo       = '4',
            offset         = vector3(0.0, 1.0, 0.3),
            rotation       = vector3(0.0, 0.0, 0.0),
            particleEffect = 'core',
            particleName   = 'water_cannon_jet',
            range          = 30.0,
            pressure       = 1.5,
        },

        -- ======================
        -- SPOTLIGHTS
        -- ======================
        spotlight = {
            enabled = true,
            control = { 0, 101 },
            locations = {
                ['vehicle'] = {
                    { directionOffSet = vector3(0.0, 10.0, 0.0), color = { 255, 255, 255 }, distance = 50.0, brightness = 60.0, hardness = 2.0, radius = 20.0, falloff = 20.0 },
                },
            }
        },


        -- ======================
        -- COLLISION (begehbare Leiter, an Prop #2)
        -- ======================
        collision = {
            enabled = true,
            objects = {
                {
                    model     = 'ladder_base',
                    attachTo  = '1',
                    offset    = vector3(0.0, 0.0, 0.0),
                    rotation  = vector3(0.0, 0.0, 0.0),
                    invisible = true,
                },
                {
                    model     = 'ladder_main_0',
                    attachTo  = '2',
                    offset    = vector3(0.0, 0.0, 0.0),
                    rotation  = vector3(0.0, 0.0, 0.0),
                    invisible = true,
                },
                {
                    model     = 'ladder_main_1',
                    attachTo  = '3',
                    offset    = vector3(0.0, 0.0, 0.0),
                    rotation  = vector3(0.0, 0.0, 0.0),
                    invisible = true,
                },
                {
                    model     = 'ladder_bucket',
                    attachTo  = '4',
                    offset    = vector3(0.0, 0.0, 0.0),
                    rotation  = vector3(0.0, 0.0, 0.0),
                    invisible = true,
                },
            }
        },

        -- ======================
        -- UI
        -- ======================
        ui = {
            showSpeed     = true,
            showAngle     = true,
            showStability = true,
            theme         = 'fire',
        }
    },

    -- ==========================================
    -- CRANE TRUCK
    -- ==========================================
    ['flatbed'] = {
        type         = 'crane',
        label        = 'Schwerer Abschleppkran',
        description  = 'Abschlepp-LKW mit drehbarem Kran',

        -- Hierarchie:
        --   Fahrzeug (bodyshell)
        --     └─ #1 Kran (dreht Z)           → crane_rotate   🔊 Drehkranz
        --         └─ #2 Ausleger (kippt X)    → crane_elevate  🔊 Kran Heben
        --             └─ #3 Ausfahren (Y)      → crane_extend   🔊 Kran Teleskop
        --                 └─ #4 Seil (Z runter) → winch          🔊 Seilwinde ↑↓
        bones        = {
            -- #1: Kran Rotation → Numpad 4/6
            {
                name            = 'kran_rotation',
                label           = 'Kran Rotation',
                type            = 'rotation',
                axis            = 'z',
                min             = -180.0,
                max             = 180.0,
                default         = 0.0,
                speed           = 0.5,
                controlGroup    = 'crane',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = 'vehicle',
                attachBone      = 'bodyshell',
                defaultOffset   = vector3(0.0, -2.0, 1.5),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #2: Ausleger Neigung → Pfeil Hoch/Runter
            {
                name            = 'ausleger_neigung',
                label           = 'Ausleger Neigung',
                type            = 'rotation',
                axis            = 'x',
                min             = -60.0,
                max             = 60.0,
                default         = 0.0,
                speed           = 0.3,
                controlGroup    = 'arm',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = '1',
                defaultOffset   = vector3(0.0, 0.0, 0.5),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #3: Ausleger Ausfahren → Q/Z
            {
                name            = 'ausleger_ausfahren',
                label           = 'Ausleger Ausfahren',
                type            = 'position',
                axis            = 'y',
                min             = 0.0,
                max             = 8.0,
                default         = 0.0,
                speed           = 0.12,
                controlGroup    = 'extend',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = '2',
                defaultOffset   = vector3(0.0, 0.5, 0.0),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #4: Seil Länge → Shift+Q/Z
            {
                name            = 'seil',
                label           = 'Seil Länge',
                type            = 'position',
                axis            = 'z',
                min             = 0.0,
                max             = 12.0,
                default         = 0.0,
                speed           = 0.25,
                controlGroup    = 'winch',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = '3',
                defaultOffset   = vector3(0.0, 0.0, -0.5),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
        },

        stabilizers  = {
            enabled      = true,
            required     = false,
            propModel    = 'prop_roadcone02a',
            maxExtension = 1.5,
            animDuration = 2000,
            liftHeight   = 0.4,
            bones        = {
                { side = 'front_left',  offset = vector3(-1.5, 2.0, -0.3),  attachBone = 'bodyshell' },
                { side = 'front_right', offset = vector3(1.5, 2.0, -0.3),   attachBone = 'bodyshell' },
                { side = 'rear_left',   offset = vector3(-1.5, -2.0, -0.3), attachBone = 'bodyshell' },
                { side = 'rear_right',  offset = vector3(1.5, -2.0, -0.3),  attachBone = 'bodyshell' },
            },
        },

        cage         = { enabled = false },
        waterMonitor = { enabled = false },
        collision    = { enabled = false },

        ui           = {
            showSpeed = true,
            showAngle = true,
            theme     = 'utility',
        }
    },

    -- ==========================================
    -- TOWER / PLATFORM TRUCK
    -- ==========================================
    ['tower_truck'] = {
        type         = 'platform',
        label        = 'Hubrettungsfahrzeug',
        description  = 'Gelenkarm-Hubarbeitsbühne',

        -- Hierarchie:
        --   Fahrzeug (bodyshell)
        --     └─ #1 Plattform (dreht Z)      → crane_rotate  🔊 Drehkranz
        --         └─ #2 Unterer Arm (X)       → hydraulic     🔊 Hydraulik ↑↓
        --             └─ #3 Oberer Arm (X)     → hydraulic     🔊 Hydraulik ↑↓
        --                 └─ #4 Korb Pos (Z)   → elevator      🔊 Aufzug ↑↓
        --                     └─ Cage-Prop
        bones        = {
            -- #1: Plattform Rotation → Numpad 4/6
            {
                name            = 'plattform_rotation',
                label           = 'Plattform Rotation',
                type            = 'rotation',
                axis            = 'z',
                min             = -360.0,
                max             = 360.0,
                default         = 0.0,
                speed           = 0.35,
                controlGroup    = 'turret',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = 'vehicle',
                attachBone      = 'bodyshell',
                defaultOffset   = vector3(0.0, -1.5, 1.8),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #2: Unterer Arm → Pfeil Hoch/Runter
            {
                name            = 'unterer_arm',
                label           = 'Unterer Arm',
                type            = 'rotation',
                axis            = 'x',
                min             = -10.0,
                max             = 75.0,
                default         = 0.0,
                speed           = 0.2,
                controlGroup    = 'arm',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = '1',
                defaultOffset   = vector3(0.0, 0.0, 0.5),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #3: Oberer Arm → Q/Z
            {
                name            = 'oberer_arm',
                label           = 'Oberer Arm',
                type            = 'rotation',
                axis            = 'x',
                min             = -75.0,
                max             = 75.0,
                default         = 0.0,
                speed           = 0.2,
                controlGroup    = 'extend',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = '2',
                defaultOffset   = vector3(0.0, 0.0, 0.5),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #4: Korb Position → Shift+Q/Z
            {
                name            = 'korb_position',
                label           = 'Korb Position',
                type            = 'position',
                axis            = 'z',
                min             = 0.0,
                max             = 5.0,
                default         = 0.0,
                speed           = 0.15,
                controlGroup    = 'basket',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = '3',
                defaultOffset   = vector3(0.0, 0.0, 0.0),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
        },

        stabilizers  = {
            enabled      = true,
            required     = true,
            propModel    = 'prop_roadcone02a',
            maxExtension = 2.0,
            animDuration = 2500,
            liftHeight   = 0.4,
            bones        = {
                { side = 'front_left',  offset = vector3(-1.8, 2.5, -0.3),  attachBone = 'bodyshell' },
                { side = 'front_right', offset = vector3(1.8, 2.5, -0.3),   attachBone = 'bodyshell' },
                { side = 'rear_left',   offset = vector3(-1.8, -2.5, -0.3), attachBone = 'bodyshell' },
                { side = 'rear_right',  offset = vector3(1.8, -2.5, -0.3),  attachBone = 'bodyshell' },
            },
        },

        cage         = {
            enabled         = true,
            propModel       = 'prop_roadcone02a',
            attachTo        = '4',
            offset          = vector3(0.0, 0.0, 0.5),
            rotation        = vector3(0.0, 0.0, 0.0),
            playerOffset    = vector3(0.0, 0.0, 0.3),
            enterDistance   = 3.5,
            canControl      = true,
            maxOccupants    = 2,
            enableCollision = true,
        },

        waterMonitor = { enabled = false },
        collision    = { enabled = false },

        ui           = {
            showSpeed  = true,
            showAngle  = true,
            showHeight = true,
            theme      = 'fire',
        }
    },

    -- ==========================================
    -- UTILITY BUCKET TRUCK
    -- ==========================================
    ['utillitruck'] = {
        type         = 'utility',
        label        = 'Service Hubarbeitsbühne',
        description  = 'Wartungsfahrzeug mit Arbeitskorb',

        -- Hierarchie:
        --   Fahrzeug (bodyshell)
        --     └─ #1 Bühne (kippt X)          → hydraulic     🔊 Hydraulik ↑↓
        --         └─ #2 Ausfahren (Y)          → crane_extend  🔊 Kran Teleskop
        --             └─ #3 Korb (dreht Z)     → (kein Sound)
        --                 └─ Cage-Prop
        bones        = {
            -- #1: Bühne Anheben → Pfeil Hoch/Runter
            {
                name            = 'buehne_heben',
                label           = 'Bühne Anheben',
                type            = 'rotation',
                axis            = 'x',
                min             = 0.0,
                max             = 75.0,
                default         = 0.0,
                speed           = 0.28,
                controlGroup    = 'lift',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = 'vehicle',
                attachBone      = 'bodyshell',
                defaultOffset   = vector3(0.0, -1.5, 1.5),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #2: Bühne Ausfahren → Q/Z
            {
                name            = 'buehne_ausfahren',
                label           = 'Bühne Ausfahren',
                type            = 'position',
                axis            = 'y',
                min             = 0.0,
                max             = 4.0,
                default         = 0.0,
                speed           = 0.12,
                controlGroup    = 'extend',
                soundEffect     = true,
                propModel       = 'prop_roadcone02a',
                attachTo        = '1',
                defaultOffset   = vector3(0.0, 0.5, 0.0),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
            -- #3: Korb Rotation → Shift+Q/Z
            {
                name            = 'korb_rotation',
                label           = 'Korb Rotation',
                type            = 'rotation',
                axis            = 'z',
                min             = -90.0,
                max             = 90.0,
                default         = 0.0,
                speed           = 0.25,
                controlGroup    = 'basket',
                -- kein soundEffect (kleine Korb-Drehung)
                propModel       = 'prop_roadcone02a',
                attachTo        = '2',
                defaultOffset   = vector3(0.0, 0.0, 0.0),
                defaultRotation = vector3(0.0, 0.0, 0.0),
            },
        },

        stabilizers  = {
            enabled      = true,
            required     = false,
            propModel    = 'prop_roadcone02a',
            maxExtension = 1.5,
            animDuration = 2000,
            liftHeight   = 0.4,
            bones        = {
                { side = 'front_left',  offset = vector3(-1.5, 2.0, -0.3),  attachBone = 'bodyshell' },
                { side = 'front_right', offset = vector3(1.5, 2.0, -0.3),   attachBone = 'bodyshell' },
                { side = 'rear_left',   offset = vector3(-1.5, -2.0, -0.3), attachBone = 'bodyshell' },
                { side = 'rear_right',  offset = vector3(1.5, -2.0, -0.3),  attachBone = 'bodyshell' },
            },
        },

        cage         = {
            enabled         = true,
            propModel       = 'prop_roadcone02a',
            attachTo        = '3',
            offset          = vector3(0.0, 0.0, 0.5),
            rotation        = vector3(0.0, 0.0, 0.0),
            playerOffset    = vector3(0.0, 0.0, 0.3),
            enterDistance   = 2.5,
            canControl      = true,
            maxOccupants    = 1,
            enableCollision = true,
        },

        waterMonitor = { enabled = false },
        collision    = { enabled = false },

        ui           = {
            theme = 'utility',
        }
    },
}

-- ============================================
-- TRANSLATIONS
-- ============================================
Config.Translations = {
    ['de'] = {
        -- Menu
        ['open_menu']              = 'Drücke ~INPUT_CONTEXT~ für Steuerung',
        ['open_remote']            = 'Drücke ~INPUT_SELECT_CHARACTER_TREVOR~ für Fernbedienung',
        ['menu_title']             = 'Fahrzeugsteuerung',

        -- Controls
        ['control_active']         = 'Steuerung aktiv',
        ['control_stopped']        = 'Steuerung beendet',
        ['too_far']                = 'Zu weit entfernt vom Fahrzeug',
        ['already_controlled']     = 'Fahrzeug wird bereits gesteuert',

        -- Stabilizers
        ['stabilizers_deployed']   = 'Stützen ausgefahren',
        ['stabilizers_retracted']  = 'Stützen eingefahren',
        ['stabilizers_required']   = 'Stützen müssen ausgefahren sein',
        ['stabilizers_deploying']  = 'Stützen werden ausgefahren...',
        ['stabilizers_retracting'] = 'Stützen werden eingefahren...',

        -- Cage
        ['exit_cage']              = 'Drücke ~INPUT_VEH_DUCK~ um Korb zu verlassen',
        ['enter_cage']             = 'Drücke ~INPUT_CONTEXT~ um in Korb zu steigen',
        ['cage_entered']           = 'Im Rettungskorb',
        ['cage_exited']            = 'Rettungskorb verlassen',
        ['cage_full']              = 'Korb ist voll',
        ['cage_too_far']           = 'Korb ist zu weit entfernt',

        -- Water
        ['water_activated']        = 'Wasserwerfer aktiviert',
        ['water_deactivated']      = 'Wasserwerfer deaktiviert',
        ['water_toggle']           = 'Drücke ~INPUT_DETONATE~ um Wasserwerfer zu schalten',

        -- Remote
        ['remote_activated']       = 'Fernbedienung aktiv',
        ['remote_deactivated']     = 'Fernbedienung deaktiviert',

        -- Status
        ['speed']                  = 'Geschwindigkeit',
        ['angle']                  = 'Winkel',
        ['extension']              = 'Ausfahrung',
        ['height']                 = 'Höhe',
        ['rotation']               = 'Rotation',
    }
}

-- ============================================
-- ANIMATIONS
-- ============================================
Config.Animations = {
    remote = {
        dict = 'amb@world_human_stand_mobile@male@text@base',
        anim = 'base',
        flag = 49,
    },
    standing_control = {
        dict = 'amb@prop_human_parking_meter@female@idle_a',
        anim = 'idle_a',
        flag = 1,
    },
    cage_enter = {
        dict = 'move_m@_idles@standing@',
        anim = 'idle_a',
        flag = 1,
    },
}
