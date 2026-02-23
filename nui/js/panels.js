// ============================================
// D4RK SMART VEHICLE - NEW CONTROL PANELS JS
// Ladder Panel | Remote Control | Dashboard MDT
// ============================================

(function () {
  "use strict";

  // Resource name for NUI callbacks
  var RESOURCE = "D4rk_Smart_Vehicle";

  // Active panel type: 'ladder', 'remote', 'dashboard', or null
  var activePanel = null;

  // Pressed buttons tracking
  var pressedButtons = {};

  // Knob elements per panel
  var knobs = {
    ladder: "lpKnob",
    remote: "rcKnob",
    dashboard: "mdtKnob",
  };

  // Knob CSS class prefixes
  var knobClasses = {
    ladder: "lp-knob",
    remote: "rc-knob",
    dashboard: "mdt-joy-center",
  };

  // ============================================
  // SHOW / HIDE PANELS
  // ============================================
  function showPanel(type, data) {
    activePanel = type;

    var overlayId = {
      ladder: "ladderPanelOverlay",
      remote: "remotePanelOverlay",
      dashboard: "dashboardPanelOverlay",
    }[type];

    if (!overlayId) return;

    var overlay = document.getElementById(overlayId);
    if (overlay) overlay.classList.add("active");

    // Panel-specific init
    if (type === "ladder") {
      document.getElementById("lpLedPower").classList.add("on-green");
      document.getElementById("lpPower").classList.add("active");
    } else if (type === "remote") {
      document.getElementById("rcSignal").classList.add("active");
      var connEl = document.getElementById("rcConnStatus");
      if (connEl) {
        connEl.textContent = "CONNECTED";
        connEl.classList.add("connected");
      }
    } else if (type === "dashboard") {
      document.getElementById("mdtLedPwr").classList.add("on");
      if (data && data.vehicleName) {
        var nameEl = document.getElementById("mdtVehicleName");
        if (nameEl) nameEl.textContent = data.vehicleName;
      }
      // Show NO STAB warning by default
      var warnEl = document.getElementById("mdtWarnNoStab");
      if (warnEl) warnEl.classList.add("active");
    }

    console.log("[D4rk Panels] Opened: " + type);
  }

  function hidePanel(type) {
    var overlayId = {
      ladder: "ladderPanelOverlay",
      remote: "remotePanelOverlay",
      dashboard: "dashboardPanelOverlay",
    }[type];

    if (overlayId) {
      var overlay = document.getElementById(overlayId);
      if (overlay) overlay.classList.remove("active");
    }

    // Reset panel-specific state
    if (type === "ladder") {
      document.getElementById("lpLedPower").classList.remove("on-green");
      document.getElementById("lpPower").classList.remove("active");
    } else if (type === "remote") {
      document.getElementById("rcSignal").classList.remove("active");
      var connEl = document.getElementById("rcConnStatus");
      if (connEl) {
        connEl.textContent = "DISCONNECTED";
        connEl.classList.remove("connected");
      }
    } else if (type === "dashboard") {
      document.getElementById("mdtLedPwr").classList.remove("on");
    }

    stopAllActions();

    if (activePanel === type) activePanel = null;
    console.log("[D4rk Panels] Closed: " + type);
  }

  function hideAllPanels() {
    hidePanel("ladder");
    hidePanel("remote");
    hidePanel("dashboard");
  }

  // ============================================
  // NUI COMMUNICATION
  // ============================================
  function sendToLua(callbackName, data) {
    $.post(
      "https://" + RESOURCE + "/" + callbackName,
      JSON.stringify(data || {}),
    );
  }

  function sendAction(action, state) {
    if (!activePanel) return;

    // Route to the correct Lua callback based on active panel
    var callback =
      {
        ladder: "ladderControl",
        remote: "remoteControl",
        dashboard: "dashboardControl",
      }[activePanel] || "ladderControl";

    sendToLua(callback, { action: action, state: state });
  }

  // ============================================
  // HOLD-TO-MOVE LOGIC
  // ============================================
  function startAction(action, btnEl) {
    if (!activePanel) return;
    if (pressedButtons[action]) return;

    pressedButtons[action] = btnEl;
    btnEl.classList.add("pressed");
    sendAction(action, "start");

    // Tilt knob
    var knobId = knobs[activePanel];
    var knobClass = knobClasses[activePanel];
    var knobEl = document.getElementById(knobId);
    if (knobEl) {
      if (action === "elevate_up") knobEl.className = knobClass + " tilt-up";
      if (action === "elevate_down")
        knobEl.className = knobClass + " tilt-down";
      if (action === "rotate_left") knobEl.className = knobClass + " tilt-left";
      if (action === "rotate_right")
        knobEl.className = knobClass + " tilt-right";
    }
  }

  function stopAction(action) {
    var btnEl = pressedButtons[action];
    if (!btnEl) return;

    btnEl.classList.remove("pressed");
    delete pressedButtons[action];
    sendAction(action, "stop");

    // Reset knob if no actions active
    if (Object.keys(pressedButtons).length === 0 && activePanel) {
      var knobId = knobs[activePanel];
      var knobClass = knobClasses[activePanel];
      var knobEl = document.getElementById(knobId);
      if (knobEl) knobEl.className = knobClass;
    }
  }

  function stopAllActions() {
    for (var action in pressedButtons) {
      if (pressedButtons[action]) {
        pressedButtons[action].classList.remove("pressed");
        sendAction(action, "stop");
      }
    }
    pressedButtons = {};

    // Reset all knobs
    ["lpKnob", "rcKnob", "mdtKnob"].forEach(function (id) {
      var el = document.getElementById(id);
      if (!el) return;
      // Strip tilt classes
      el.className = el.className.replace(/\s*tilt-\w+/g, "");
    });
  }

  // ============================================
  // UPDATE VALUES — from Lua
  // ============================================
  function updateValues(data) {
    var rot =
      data.rotation !== undefined ? Math.round(data.rotation) + "°" : null;
    var elev =
      data.elevation !== undefined ? Math.round(data.elevation) + "°" : null;
    var ext = data.extend !== undefined ? data.extend.toFixed(1) + "m" : null;
    var bsk = data.basket !== undefined ? Math.round(data.basket) + "°" : null;

    // Ladder Panel
    if (rot !== null) setTextSafe("lpValRot", rot);
    if (elev !== null) setTextSafe("lpValElev", elev);
    if (ext !== null) setTextSafe("lpValExt", ext);
    if (bsk !== null) setTextSafe("lpValBsk", bsk);

    // Remote
    if (rot !== null) setTextSafe("rcValRot", rot);
    if (elev !== null) setTextSafe("rcValElev", elev);
    if (ext !== null) setTextSafe("rcValExt", ext);
    if (bsk !== null) setTextSafe("rcValBsk", bsk);

    // Dashboard
    if (rot !== null) setTextSafe("mdtValRot", rot);
    if (elev !== null) setTextSafe("mdtValElev", elev);
    if (ext !== null) setTextSafe("mdtValExt", ext);
    if (bsk !== null) setTextSafe("mdtValBsk", bsk);

    // Dashboard bars
    if (data.elevation !== undefined && data.maxElevation) {
      var elevPct = (Math.abs(data.elevation) / data.maxElevation) * 100;
      var barElev = document.getElementById("mdtBarElev");
      if (barElev) {
        barElev.style.width = elevPct + "%";
        barElev.className =
          "mdt-bar-fill" +
          (elevPct > 85 ? " danger" : elevPct > 65 ? " warn" : "");
      }
    }
    if (data.extend !== undefined && data.maxExtend) {
      var extPct = (data.extend / data.maxExtend) * 100;
      var barExt = document.getElementById("mdtBarExt");
      if (barExt) {
        barExt.style.width = extPct + "%";
        barExt.className =
          "mdt-bar-fill" +
          (extPct > 85 ? " danger" : extPct > 65 ? " warn" : "");
      }
    }
  }

  function updateStabilizers(deployed) {
    // Ladder panel
    var lpDeploy = document.getElementById("lpStabDeploy");
    if (lpDeploy) {
      if (deployed) lpDeploy.classList.add("deployed");
      else lpDeploy.classList.remove("deployed");
    }

    // Remote
    var rcStab = document.getElementById("rcStab");
    var rcLabel = document.getElementById("rcStabLabel");
    if (rcStab) {
      if (deployed) rcStab.classList.add("deployed");
      else rcStab.classList.remove("deployed");
    }
    if (rcLabel) rcLabel.textContent = deployed ? "ON" : "OFF";

    // Remote stab dots
    ["rcSDot1", "rcSDot2", "rcSDot3", "rcSDot4"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) {
        if (deployed) el.classList.add("active");
        else el.classList.remove("active");
      }
    });

    // Dashboard
    var mdtStab = document.getElementById("mdtStab");
    var mdtStabText = document.getElementById("mdtStabText");
    if (mdtStab) {
      if (deployed) mdtStab.classList.add("deployed");
      else mdtStab.classList.remove("deployed");
    }
    if (mdtStabText) mdtStabText.textContent = deployed ? "RETRACT" : "DEPLOY";

    // Dashboard LEDs
    var ledStab = document.getElementById("mdtLedStab");
    if (ledStab) {
      if (deployed) ledStab.classList.add("on");
      else ledStab.classList.remove("on");
    }

    // Dashboard stab dots
    ["mdtSFL", "mdtSFR", "mdtSRL", "mdtSRR"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) {
        if (deployed) el.classList.add("active");
        else el.classList.remove("active");
      }
    });

    // Dashboard NO STAB warning
    var warnNoStab = document.getElementById("mdtWarnNoStab");
    if (warnNoStab) {
      if (deployed) warnNoStab.classList.remove("active");
      else warnNoStab.classList.add("active");
    }
  }

  // ============================================
  // HELPER
  // ============================================
  function setTextSafe(id, text) {
    var el = document.getElementById(id);
    if (el) el.textContent = text;
  }

  // ============================================
  // EVENT BINDING — All [data-action] buttons
  // ============================================
  function bindButtons() {
    // Hold-to-move buttons (data-action)
    var actionBtns = document.querySelectorAll("[data-action]");
    actionBtns.forEach(function (btn) {
      var action = btn.getAttribute("data-action");

      btn.addEventListener("mousedown", function (e) {
        e.preventDefault();
        startAction(action, btn);
      });
      btn.addEventListener("touchstart", function (e) {
        e.preventDefault();
        startAction(action, btn);
      });
    });

    // System buttons (data-system) — single click
    var systemBtns = document.querySelectorAll("[data-system]");
    systemBtns.forEach(function (btn) {
      var systemAction = btn.getAttribute("data-system");

      btn.addEventListener("click", function (e) {
        e.preventDefault();
        if (!activePanel) return;

        if (systemAction === "emergency_stop") {
          stopAllActions();

          // Flash warning LED on ladder panel
          var warnLed = document.getElementById("lpLedWarn");
          if (warnLed) {
            warnLed.classList.add("on-yellow");
            setTimeout(function () {
              warnLed.classList.remove("on-yellow");
            }, 3000);
          }

          // Flash dashboard warn LED
          var mdtWarn = document.getElementById("mdtLedWarn");
          if (mdtWarn) {
            mdtWarn.classList.add("warn");
            setTimeout(function () {
              mdtWarn.classList.remove("warn");
            }, 3000);
          }
        }

        if (systemAction === "reset_all") {
          var info = document.getElementById("mdtInfo");
          if (info) info.textContent = "RESETTING...";
        }

        if (systemAction === "close_panel") {
          sendAction("close_panel", "triggered");
          return;
        }

        if (systemAction.indexOf("preset_") === 0) {
          var num = systemAction.split("_")[1];
          var info2 = document.getElementById("mdtInfo");
          if (info2) info2.textContent = "PRESET " + num + " LADEN...";
        }

        sendAction(systemAction, "triggered");
      });
    });

    // Global mouse/touch up → stop all held actions
    document.addEventListener("mouseup", function () {
      for (var action in pressedButtons) {
        stopAction(action);
      }
    });
    document.addEventListener("touchend", function () {
      for (var action in pressedButtons) {
        stopAction(action);
      }
    });
    document.addEventListener("mouseleave", stopAllActions);

    // Prevent context menu on panels
    document.addEventListener("contextmenu", function (e) {
      if (activePanel) e.preventDefault();
    });
  }

  // ============================================
  // NUI MESSAGE HANDLER — From Lua
  // ============================================
  window.addEventListener("message", function (event) {
    var data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
      // Show panels
      case "showLadderPanel":
        showPanel("ladder", data);
        break;
      case "showRemote":
        showPanel("remote", data);
        break;
      case "showDashboard":
        showPanel("dashboard", data);
        break;

      // Hide panels
      case "hideLadderPanel":
        hidePanel("ladder");
        break;
      case "hideRemote":
        hidePanel("remote");
        break;
      case "hideDashboard":
        hidePanel("dashboard");
        break;

      // Value updates (sent to all panels, only active one visible)
      case "updateValues":
        updateValues(data);
        break;

      // Stabilizer sync
      case "updateStabilizers":
        updateStabilizers(data.deployed);
        break;

      // Info text (dashboard)
      case "setInfo":
        setTextSafe("mdtInfo", data.text || "");
        break;
    }
  });

  // ============================================
  // INIT
  // ============================================
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bindButtons);
  } else {
    bindButtons();
  }

  console.log("[D4rk Panels] Initialized — Ladder, Remote, Dashboard ready");
})();
