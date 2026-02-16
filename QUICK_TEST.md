# ⚡ QUICK TEST - Ist das Panel kaputt?

## 🎯 Schnelltest (10 Sekunden)

### 1. Fahrzeug spawnen
```
/car firetruk
```

### 2. Einsteigen
Setze dich auf den **Fahrersitz**

### 3. Test-Command
```
/testpanel
```

### 4. Was passiert?

#### ✅ FUNKTIONIERT:
```
Console:
=== OPENING CONTROL PANEL ===
Vehicle: firetruk
✅ NUI Message sent

NUI:
=== OPENING PANEL ===
Vehicle: Feuerwehr Drehleiter
✅ Panel display: block
✅ Has hidden class: false
```
→ **Panel sollte sichtbar sein!**

#### ❌ FUNKTIONIERT NICHT:
```
Console:
❌ Fahrzeug nicht in Config gefunden!
Model: FIRETRUK
```
→ **Fahrzeug ist nicht in config.lua!**

ODER:
```
Console:
=== OPENING CONTROL PANEL ===
Vehicle: firetruk
✅ NUI Message sent

NUI:
❌ Panel element NOT found!
```
→ **HTML ist kaputt!**

ODER:
```
Console:
=== OPENING CONTROL PANEL ===
Vehicle: firetruk
✅ NUI Message sent

NUI:
... nichts ...
```
→ **NUI lädt nicht! (fxmanifest.lua prüfen)**

---

## 🔍 Debugging Schritte

### Problem 1: "Fahrzeug nicht in Config"
**Lösung:**
1. Öffne `config.lua`
2. Suche nach dem Fahrzeug-Namen
3. Oder füge es hinzu

### Problem 2: "Panel element NOT found"
**Lösung:**
```
1. Prüfe nui/html/index.html
2. Suche nach: <div id="controlPanel"
3. Muss vorhanden sein!
```

### Problem 3: NUI lädt gar nicht
**Lösung:**
```
1. Öffne fxmanifest.lua
2. Prüfe:
   ui_page 'nui/html/index.html'
   files {
       'nui/html/index.html',
       'nui/css/style.css',
       'nui/js/script.js'
   }
```

### Problem 4: Panel display: block aber nicht sichtbar
**Lösung:**
Das ist wahrscheinlich der **schwarze Hintergrund** der alles verdeckt!

**Fix:**
1. Drücke F8
2. Tippe: `nui_focus off`
3. Jetzt kannst du wieder bewegen
4. Öffne nui/css/style.css
5. Prüfe ob body KEIN background hat

---

## 📊 Console Log Levels

Mit dieser DEBUG Version siehst du nur noch:

**Wichtig:**
```
=== OPENING PANEL ===
✅ Panel display: block
❌ Panel element NOT found!
```

**NICHT mehr gespammt:**
```
[D4rk_Smart NUI] Received message: showCagePrompt (x1000)
[D4rk_Smart NUI] Received message: updateControl (x1000)
```

---

## 🚀 Wenn /testpanel funktioniert aber E nicht

Das bedeutet:
- ✅ NUI funktioniert
- ✅ Panel kann sich öffnen
- ❌ Proximity Detection ist kaputt

**Fix:**
1. Prüfe ob du im Fahrersitz sitzt
2. Prüfe ob `menuOpen = false` richtig gesetzt wird
3. Schau in client/controls.lua Zeile ~256

---

## 💡 Schnell-Fixes

### Fix 1: NUI Reset
```
In FiveM Console (F8):
nui_focus off
restart d4rk_smart_vehicle
```

### Fix 2: Force Panel Open (Test)
```
F8 Console:
resmon
```
Dann ins Script klicken und NUI DevTools öffnen.

Im DevTools Console:
```javascript
document.getElementById('controlPanel').style.display = 'block';
```

Siehst du jetzt das Panel?
→ Ja: CSS/HTML funktioniert, Problem ist in Lua
→ Nein: Panel ist kaputt oder versteckt

---

**Mit /testpanel findest du sofort wo das Problem ist! ⚡**
