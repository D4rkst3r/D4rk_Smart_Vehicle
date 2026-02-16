# 🚀 Quick Install Guide - D4rk Smart Vehicle v2.0

## ⚡ 3-Schritte Installation

### Schritt 1: Installation (2 Minuten)
```bash
1. Entpacke "D4rk_Smart_Vehicle.zip"
2. Kopiere den Ordner in deinen Server "resources" Ordner
3. Öffne server.cfg
4. Füge hinzu: ensure D4rk_Smart_Vehicle
5. Server neustarten
```

### Schritt 2: Teste mit Standard-Fahrzeugen (1 Minute)
```bash
1. Spawne ein "firetruk" oder "flatbed"
2. Steige ein (Fahrersitz)
3. Drücke E
4. UI sollte sich öffnen ✓
```

### Schritt 3: Eigenes Fahrzeug konfigurieren (5-15 Minuten)
```lua
1. Öffne config.lua
2. Finde die Bone-Namen deines Fahrzeugs (siehe unten)
3. Füge dein Fahrzeug unter Config.Vehicles hinzu
4. Server restart
```

---

## 🔍 Bone-Namen finden

### Methode 1: CodeWalker (empfohlen)
```
1. Öffne dein Fahrzeug (.yft) in CodeWalker
2. Gehe zu "Drawable Dictionary"
3. Dort siehst du alle Bones mit Namen
4. Notiere: crane_base, ladder_arm, etc.
```

### Methode 2: In-Game Debug
```lua
-- Füge in client/main.lua ein (temporär):
RegisterCommand('showbones', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle ~= 0 then
        for i = 0, 200 do
            local boneName = GetEntityBoneNameByIndex(vehicle, i)
            if boneName ~= '' then
                print('Bone ' .. i .. ': ' .. boneName)
            end
        end
    end
end)
```

---

## 📝 Minimale Fahrzeug-Config

```lua
['mein_fahrzeug'] = {
    type = 'crane',  -- crane, ladder, platform, utility
    label = 'Mein Kran',
    
    bones = {
        {
            name = 'crane_base',      -- ← Dein Bone-Name hier!
            label = 'Rotation',
            type = 'rotation',        -- rotation oder position
            axis = 'z',               -- x, y, oder z
            min = -180.0,
            max = 180.0,
            default = 0.0,
            speed = 0.5
        }
    },
    
    stabilizers = {
        enabled = true,
        required = false,
        bones = {
            {name = 'stab1', side = 'left', offset = vector3(-1.0, 0.0, -0.5)},
            {name = 'stab2', side = 'right', offset = vector3(1.0, 0.0, -0.5)}
        }
    }
}
```

---

## 🎯 Bone Types Erklärt

### Type: rotation
```lua
-- Dreht ein Bone um eine Achse
type = 'rotation',
axis = 'z',        -- z = horizontal drehen (wie Kompass)
min = -180.0,      -- Wie weit nach links
max = 180.0,       -- Wie weit nach rechts
```

**Wann verwenden:**
- Turm/Kran drehen
- Leiter schwenken
- Korb rotieren

### Type: position
```lua
-- Verschiebt ein Bone entlang einer Achse
type = 'position',
axis = 'y',        -- y = vor/zurück (z.B. ausfahren)
min = 0.0,         -- Eingefahren
max = 10.0,        -- Maximal ausgefahren (Meter)
```

**Wann verwenden:**
- Teleskop ausfahren
- Haken hoch/runter
- Ausleger verlängern

---

## ⚙️ Achsen-System

```
X-Achse: Links/Rechts
Y-Achse: Vor/Zurück (auch für Heben/Senken bei Auslegern)
Z-Achse: Hoch/Runter (und Rotation um vertikale Achse)
```

**Beispiele:**
- Turm drehen: `axis = 'z'` + `type = 'rotation'`
- Leiter anheben: `axis = 'x'` + `type = 'rotation'`
- Ausfahren: `axis = 'y'` + `type = 'position'`
- Haken hoch/runter: `axis = 'z'` + `type = 'position'`

---

## 🔧 Optional: Erweiterte Features

### Rettungskorb (Cage)
```lua
cage = {
    enabled = true,
    bone = 'basket_bone',
    enterDistance = 3.0,
    offset = vector3(0.0, 0.0, 0.5),
    canControl = true,
    maxOccupants = 2
}
```

### Wasserwerfer
```lua
waterMonitor = {
    enabled = true,
    bone = 'water_cannon_bone',
    offset = vector3(0.0, 1.0, 0.3),
    particleEffect = 'core',
    particleName = 'water_cannon_jet',
    range = 30.0,
    pressure = 1.5
}
```

### Begehbare Leiter
```lua
collision = {
    enabled = true,
    objects = {
        {
            model = 'prop_ladder_01',
            bone = 'ladder_bone',
            offset = vector3(0.0, 0.0, 0.0),
            dynamic = true
        }
    }
}
```

---

## ✅ Checkliste

- [ ] Script in resources/ kopiert
- [ ] server.cfg angepasst
- [ ] Server neugestartet
- [ ] firetruk getestet (E drücken) ✓
- [ ] Bone-Namen gefunden (CodeWalker)
- [ ] Eigenes Fahrzeug in config.lua eingetragen
- [ ] Server erneut neugestartet
- [ ] Eigenes Fahrzeug gespawnt
- [ ] E gedrückt - Menü öffnet sich ✓
- [ ] Steuerung funktioniert ✓

---

## 🆘 Häufige Fehler

### ❌ "Menü öffnet sich nicht"
**Lösung:**
1. Sitzt du im Fahrersitz?
2. Ist das Fahrzeug in config.lua eingetragen?
3. F8 Console prüfen

### ❌ "Fahrzeug bewegt sich nicht"
**Lösung:**
1. Bone-Namen korrekt? (CodeWalker!)
2. Config.Debug = true setzen
3. F8 Console → Fehler?

### ❌ "Stützen fehlen"
**Lösung:**
1. stabilizers.enabled = true?
2. Bone-Namen korrekt?
3. Stützen-Bones im Modell vorhanden?

### ❌ "NUI zeigt nichts"
**Lösung:**
1. F8 Console → JavaScript Fehler?
2. Internet-Verbindung (jQuery CDN)?
3. nui/html/index.html vorhanden?

---

## 🎮 Standard-Steuerung

```
E         - Menü öffnen/schließen
F7        - Fernbedienung
↑ ↓       - Heben/Senken
← →       - Drehen
Q / Z     - Zusatzsteuerung
G         - Stützen
X         - Korb verlassen
ESC       - Schließen
```

---

## 📚 Beispiel-Fahrzeuge

In der config.lua sind bereits vorkonfiguriert:
- `firetruk` - Feuerwehr Drehleiter
- `flatbed` - Abschleppwagen
- `tower_truck` - Hubrettungsfahrzeug
- `utillitruck` - Service Truck

**Tipp:** Schaue dir diese Beispiele an bevor du dein eigenes konfigurierst!

---

## 💡 Tipps

1. **Klein anfangen** - Teste zuerst mit 1-2 Bones
2. **Debug nutzen** - `Config.Debug = true` zeigt hilfreiche Logs
3. **Beispiele anschauen** - Die vorkonfigurierten Fahrzeuge in config.lua
4. **CodeWalker** - Unverzichtbar für Bone-Namen
5. **Bone-Hierarchie** - Beachte Parent/Child Beziehungen

---

## 🔗 Wichtige Dateien

```
D4rk_Smart_Vehicle/
├── config.lua          ← HIER deine Fahrzeuge eintragen!
├── README.md           ← Vollständige Dokumentation
├── fxmanifest.lua      ← Resource Manifest
├── client/             ← Client Scripts
│   ├── main.lua       
│   ├── controls.lua   
│   ├── cage.lua       
│   ├── water.lua      
│   └── collision.lua  
├── server/             ← Server Scripts
└── nui/                ← UI Interface
    ├── html/
    ├── css/
    └── js/
```

---

## ⏱️ Geschätzte Zeiten

- **Installation:** 2 Minuten
- **Test mit Standard-Fahrzeug:** 1 Minute
- **Bone-Namen finden:** 5-10 Minuten
- **Eigenes Fahrzeug konfigurieren:** 5-15 Minuten
- **Feintuning:** 10-30 Minuten

**Gesamt:** 20-60 Minuten für dein erstes Fahrzeug

---

## 📞 Noch Fragen?

1. Lies die README.md für Details
2. Schau dir die Beispiele in config.lua an
3. Aktiviere Debug-Modus
4. Prüfe F8 Console

---

**Los geht's! 🚀**
