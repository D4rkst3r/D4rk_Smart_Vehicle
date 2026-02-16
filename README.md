

 # D4rk Smart Vehicle System v2.0

**Professional vehicle control system for FiveM inspired by London Studios' Smart Vehicle**

Ein fortschrittliches, vollständig synchronisiertes Fahrzeugsteuerungssystem mit modernem NUI Interface, Rettungskorb-System, Wasserwerfer und begehbaren Objekten.

---

## 🚀 Features

### ⭐ Kern-Features
- **Moderne NUI Steuerung** - HTML/CSS/JS Interface statt Text-Menü
- **3 Steuerungsmodi** - Im Fahrzeug, stehend am Fahrzeug, Fernbedienung (bis 50m)
- **Echte Bone Manipulation** - Verwendung von nativen GTA5/FiveM Funktionen
- **Vollständig synchronisiert** - State-Management mit Anti-Spam Protection
- **Standalone** - Keine Dependencies, funktioniert mit jedem Framework

### 🔥 Erweiterte Features
- **Cage/Basket System** - Spieler können in Rettungskörbe steigen (wie in echten Drehleitern)
- **Water Monitor** - Wasserwerfer mit Particle Effects zum Löschen von Bränden
- **Collision Objects** - Begehbare Leitern und andere Objekte
- **Sound Effects** - Hydraulik-Sounds, Winden-Geräusche, etc.
- **Stabilizer System** - Stützen müssen ausgefahren werden (optional/pflicht)
- **Rate Limiting** - Anti-Cheat Protection gegen Manipulation

### 🎨 UI Features
- Kompaktes HUD während der Steuerung
- Echtzeit-Anzeige aller Kontrollwerte
- Visuelle Slider für alle Bewegungen
- Verschiedene Themes (Fire, Police, Utility)
- Notifications System
- Responsive Design

---

## 📦 Installation

### 1. Download & Entpacken
```bash
1. Lade das Script herunter
2. Entpacke den Ordner "D4rk_Smart_Vehicle"
3. Kopiere ihn in deinen "resources" Ordner
```

### 2. Server.cfg
```cfg
ensure D4rk_Smart_Vehicle
```

### 3. Fahrzeug konfigurieren
```lua
-- In config.lua unter Config.Vehicles:
['dein_fahrzeug'] = {
    type = 'ladder',  -- oder 'crane', 'platform', 'utility'
    label = 'Dein Fahrzeug Name',
    bones = {
        {
            name = 'bone_name',     -- Bone Name aus deinem Modell
            label = 'Anzeigename',
            type = 'rotation',      -- 'rotation' oder 'position'
            axis = 'z',             -- 'x', 'y', oder 'z'
            min = -180.0,
            max = 180.0,
            default = 0.0,
            speed = 0.5
        }
    }
}
```

---

## 🎮 Steuerung

### Standard Tasten
```
E         - Steuerungsmenü öffnen
F7        - Fernbedienung aktivieren/deaktivieren
↑ ↓       - Haupt-Kontrolle (z.B. Leiter anheben/senken)
← →       - Rotation (z.B. Turm drehen)
Q / Z     - Zusatzsteuerung
Shift+Q/Z - Erweiterte Steuerung
G         - Stützen aus/einfahren
X         - Korb verlassen
ESC       - Menü schließen
```

**Alle Tasten sind in `config.lua` anpassbar!**

---

## 🏗️ Fahrzeug-Konfiguration

### Bone-Namen finden

**Mit CodeWalker:**
1. Öffne deine .yft Datei in CodeWalker
2. Navigiere zu "Drawable Dictionary"
3. Notiere alle Bone-Namen (z.B. `ladder_base`, `crane_arm_1`, etc.)

**In-Game (optional):**
```lua
-- Temporär in client/main.lua einfügen:
RegisterCommand('showbones', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    for i = 0, 200 do
        local boneName = GetEntityBoneNameByIndex(vehicle, i)
        if boneName ~= '' then
            print('Bone ' .. i .. ': ' .. boneName)
        end
    end
end)
```

### Beispiel: Feuerwehr Drehleiter

```lua
['firetruk'] = {
    type = 'ladder',
    label = 'Feuerwehr Drehleiter',
    description = 'Drehleiter mit Rettungskorb und Wasserwerfer',
    
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
        }
        -- Weitere Bones...
    ],
    
    stabilizers = {
        enabled = true,
        required = true,
        bones = {
            {name = 'misc_e', side = 'front_left', offset = vector3(-1.5, 2.0, -0.8)},
            {name = 'misc_f', side = 'front_right', offset = vector3(1.5, 2.0, -0.8)}
            -- etc...
        },
        speed = 0.2,
        maxExtension = 1.5
    },
    
    cage = {
        enabled = true,
        bone = 'misc_d',
        enterDistance = 3.0,
        offset = vector3(0.0, 0.0, 0.5),
        canControl = true,
        maxOccupants = 2
    },
    
    waterMonitor = {
        enabled = true,
        bone = 'misc_d',
        offset = vector3(0.0, 1.0, 0.3),
        particleEffect = 'core',
        particleName = 'water_cannon_jet',
        range = 30.0,
        pressure = 1.5
    }
}
```

---

## 💧 Water Monitor (Wasserwerfer)

### Setup
```lua
waterMonitor = {
    enabled = true,
    bone = 'water_cannon_bone',        -- Bone wo Wasserwerfer befestigt ist
    offset = vector3(0.0, 1.0, 0.3),   -- Offset zum Bone
    particleEffect = 'core',            -- Particle Dictionary
    particleName = 'water_cannon_jet',  -- Particle Name
    range = 30.0,                       -- Reichweite in Metern
    pressure = 1.5,                     -- Druck/Stärke
    soundEffect = 'water_cannon'        -- Sound aus Config.SoundEffects
}
```

### Features
- ✅ Löscht Brände automatisch
- ✅ Drückt Objekte weg (optional)
- ✅ Particle Effects (Wasserstrahl)
- ✅ Sound Effects
- ✅ Toggle mit G-Taste

---

## 🧍 Cage/Basket System

### Setup
```lua
cage = {
    enabled = true,
    bone = 'basket_bone',              -- Bone des Korbs
    enterDistance = 3.0,               -- Max. Distanz zum Einsteigen
    offset = vector3(0.0, 0.0, 0.5),  -- Offset wo Spieler attachiert wird
    rotation = vector3(0.0, 0.0, 0.0), -- Rotation
    canControl = true,                 -- Kann aus Korb steuern
    maxOccupants = 2                   -- Max. Anzahl Spieler
}
```

### Features
- ✅ Spieler wird an Fahrzeug attachiert
- ✅ Bewegt sich mit dem Korb
- ✅ Kann aus Korb steuern (optional)
- ✅ Mehrere Spieler gleichzeitig
- ✅ E zum Einsteigen, X zum Aussteigen

---

## 🪜 Collision Objects (Begehbare Leitern)

### Setup
```lua
collision = {
    enabled = true,
    objects = {
        {
            model = 'prop_ladder_01',      -- Prop Model
            bone = 'ladder_bone',          -- Bone wo es attachiert wird
            offset = vector3(0.0, 0.0, 0.0),
            rotation = vector3(0.0, 0.0, 0.0),
            dynamic = true                 -- Bewegt sich mit Bone
        }
    }
}
```

### Features
- ✅ Spawnt echte Objekte mit Kollision
- ✅ Spieler können drauf laufen
- ✅ Bewegt sich dynamisch mit Fahrzeug
- ✅ Automatisches Cleanup

---

## 🔧 Erweiterte Konfiguration

### Control Groups
Organisiere Kontrollen in Gruppen für bessere Übersicht:
```lua
controlGroup = 'turret'  -- Kategorisiert die Kontrolle
```

Verfügbare Gruppen:
- `main` - Hauptsteuerung
- `turret` - Turm/Basis
- `crane` - Kran
- `ladder` - Leiter
- `basket` - Korb
- `arm` - Ausleger
- `winch` - Winde
- `lift` - Hebebühne

### Sound Effects
Definiere eigene Sounds in `Config.SoundEffects`:
```lua
Config.SoundEffects = {
    hydraulic = {
        name = 'Hydraulic',
        volume = 0.3,
        reference = 'DLC_APT_YACHT_DOOR_SOUNDS'
    }
}
```

### UI Themes
Wähle ein Theme für dein Fahrzeug:
```lua
ui = {
    theme = 'fire'  -- 'fire', 'police', oder 'utility'
}
```

---

## 📊 Performance

### Optimierungen
- **Rate Limiting** - Max 50 Updates/Sekunde pro Spieler
- **Batch Processing** - Updates werden gebündelt
- **Update Rate** - Konfigurierbar (default 50ms)
- **State Management** - Server-seitig
- **Culling** - Optional für weit entfernte Spieler

### Konfiguration
```lua
Config.UpdateRate = 50  -- ms zwischen Updates (niedriger = smoother aber intensiver)
```

---

## 🛡️ Anti-Cheat

### Eingebaute Schutzmechanismen
- ✅ Rate Limiting (max 50 Syncs/Sekunde)
- ✅ Authorization Checks
- ✅ Suspicious Activity Monitoring
- ✅ Server-seitige State Validierung

### Monitoring
```bash
# In Server Console (wenn Config.Debug = true)
smartvehicle:stats          # Zeigt Statistiken
smartvehicle:state [netId]  # Zeigt Fahrzeugzustand
smartvehicle:controllers    # Zeigt aktive Controller
```

---

## 🔍 Debugging

### Debug-Modus aktivieren
```lua
Config.Debug = true  -- in config.lua
```

### Verfügbare Commands
```bash
smartvehicle:state [netId]   # Server: Zeigt Fahrzeugzustand
smartvehicle:controllers     # Server: Zeigt alle Controller
smartvehicle:stats          # Server: Zeigt Statistiken
showbones                    # Client: Zeigt alle Bones (wenn implementiert)
```

---

## 📚 Exports

### Client Exports
```lua
-- Prüfen ob Steuerung aktiv
local active = exports['D4rk_Smart_Vehicle']:IsControlActive()

-- Aktuelles Fahrzeug abrufen
local vehicle = exports['D4rk_Smart_Vehicle']:GetCurrentVehicle()

-- Steuerungsmodus abrufen
local mode = exports['D4rk_Smart_Vehicle']:GetControlMode()

-- Prüfen ob im Korb
local inCage = exports['D4rk_Smart_Vehicle']:IsInCage()

-- Prüfen ob Wasserwerfer aktiv
local water = exports['D4rk_Smart_Vehicle']:IsWaterActive()
```

### Server Exports
```lua
-- Fahrzeugzustand abrufen
local state = exports['D4rk_Smart_Vehicle']:GetVehicleState(netId)

-- Prüfen ob kontrolliert
local controlled = exports['D4rk_Smart_Vehicle']:IsVehicleControlled(netId)

-- Controller abrufen
local controller = exports['D4rk_Smart_Vehicle']:GetVehicleController(netId)

-- Fahrzeug zwangsweise freigeben
exports['D4rk_Smart_Vehicle']:ForceReleaseVehicle(netId)

-- Statistiken abrufen
local stats = exports['D4rk_Smart_Vehicle']:GetStatistics()
```

---

## 🆘 Troubleshooting

### Fahrzeug bewegt sich nicht
1. **Bone-Namen prüfen** - Mit CodeWalker verifizieren
2. **Debug aktivieren** - `Config.Debug = true`
3. **F8 Console prüfen** - Auf Fehler achten
4. **Bone Index** - Könnte -1 sein (nicht gefunden)

### NUI öffnet sich nicht
1. **F8 Console** - JavaScript Fehler?
2. **jQuery geladen** - Internet-Verbindung nötig (CDN)
3. **Pfade prüfen** - `nui/html/index.html` vorhanden?

### Stützen fehlen
1. **Config prüfen** - `stabilizers.enabled = true`?
2. **Bone-Namen** - `stabilizer_bones` korrekt?
3. **Modell** - Hat das Fahrzeug Stützen?

### Wasserwerfer funktioniert nicht
1. **Particle Asset** - Wird geladen?
2. **Bone-Name** - Korrekt konfiguriert?
3. **F8 Console** - Fehler bei Particle Loading?

### Kollisionsobjekte spawnen nicht
1. **Model Hash** - Korrekt?
2. **Streaming** - Model geladen?
3. **Bone** - Existiert der Bone?

---

## 🔄 Updates & Migration

### Von v1.0 zu v2.0
Das neue System ist **nicht rückwärtskompatibel** mit v1.0!

**Hauptänderungen:**
- NUI statt Text-Menü
- Neue Config-Struktur (`bones` statt `controls`)
- Neue Features (Cage, Water, Collision)
- Andere Event-Namen

**Migration:**
1. Sichere alte Config
2. Erstelle neue Config nach v2.0 Format
3. Teste alle Fahrzeuge
4. Passe Custom-Scripte an (falls vorhanden)

---

## 📄 Lizenz

**MIT License** - Frei verwendbar und anpassbar

---

## 🙏 Credits

**Inspiriert von:**
- London Studios' Smart Vehicle System
- GTA5 Vehicle Natives Documentation
- FiveM Community

**Erstellt von:** D4rk  
**Version:** 2.0.0  
**Datum:** 2026  

---

## 💬 Support

Bei Fragen oder Problemen:
1. README durchlesen
2. Debug-Modus aktivieren
3. Console-Logs prüfen
4. Config vergleichen mit Beispielen

---

**Viel Erfolg mit deinem Smart Vehicle System! 🚒🏗️🚧**
