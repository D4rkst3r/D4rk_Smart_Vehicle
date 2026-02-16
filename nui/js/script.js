// D4rk Smart Vehicle - NUI Script
let currentVehicle = null;
let controlStates = {};
let stabilizersDeployed = false;
let waterActive = false;
let inCage = false;
let escHandlerEnabled = false;
let escPressCount = 0;
let groupLabels = {}; // Labels aus Config.ControlGroups

if (typeof $ === "undefined") {
  console.error("[D4rk_Smart NUI] jQuery is NOT loaded!");
} else {
  console.log("[D4rk_Smart NUI] jQuery loaded successfully");
}

// ============================================
// MESSAGE HANDLERS
// ============================================
window.addEventListener("message", function (event) {
  const data = event.data;

  if (data.action !== "showCagePrompt" && data.action !== "updateControl") {
    console.log("[D4rk_Smart NUI] Received message:", data.action);
  }

  switch (data.action) {
    case "openPanel":
      console.log("[D4rk_Smart NUI] Opening panel with vehicle:", data.vehicle);
      // ← GEÄNDERT: Labels aus Config übernehmen
      if (data.groupLabels) {
        groupLabels = data.groupLabels;
      }
      openPanel(data.vehicle);
      break;
    case "closePanel":
      closePanel();
      break;
    case "updateControl":
      updateControl(data.index, data.value);
      break;
    case "updateStabilizers":
      updateStabilizers(data.deployed);
      break;
    case "updateWater":
      updateWater(data.active);
      break;
    case "updateCage":
      updateCage(data.inCage, data.occupants, data.maxOccupants);
      break;
    case "showHud":
      showHud(data.vehicle);
      break;
    case "hideHud":
      hideHud();
      break;
    case "showCagePrompt":
      showCagePrompt(data.show);
      break;
    case "notify":
      showNotification(data.message, data.type);
      break;
    case "updateMode":
      updateMode(data.mode);
      break;
  }
});

// ============================================
// PANEL FUNCTIONS
// ============================================
function openPanel(vehicle) {
  console.log("=== OPENING PANEL ===");
  console.log("Vehicle:", vehicle.label);

  currentVehicle = vehicle;
  escHandlerEnabled = false;

  const panel = document.getElementById("controlPanel");
  if (!panel) {
    console.error("❌ Panel element NOT found!");
    return;
  }

  try {
    $("#vehicleLabel").text(vehicle.label);
    $("#vehicleDescription").text(vehicle.description || "");

    $("#controlPanel").removeClass("theme-fire theme-police theme-utility");
    if (vehicle.ui && vehicle.ui.theme) {
      $("#controlPanel").addClass("theme-" + vehicle.ui.theme);
    }

    buildControlGroups(vehicle.bones);
    setupQuickActions(vehicle);

    $("#controlPanel").removeClass("hidden").css("display", "block");
    panel.classList.remove("hidden");
    panel.style.display = "block";

    console.log("✅ Panel display:", panel.style.display);
    console.log("✅ Has hidden class:", panel.classList.contains("hidden"));

    $.post("https://D4rk_Smart_Vehicle/panelReady", JSON.stringify({}));

    setTimeout(() => {
      escHandlerEnabled = true;
      console.log("✅ ESC Handler aktiviert");
    }, 1000);
  } catch (error) {
    console.error("❌ Error in openPanel:", error);
    panel.classList.remove("hidden");
    panel.style.display = "block";
    panel.style.visibility = "visible";
    panel.style.opacity = "1";
  }
}

function closePanel() {
  console.log("=== CLOSING PANEL ===");
  escHandlerEnabled = false;
  $("#controlPanel").addClass("hidden").css("display", "none");
  $.post("https://D4rk_Smart_Vehicle/closePanel", JSON.stringify({}));
}

function buildControlGroups(bones) {
  const groups = {};

  bones.forEach((bone, index) => {
    const group = bone.controlGroup || "main";
    if (!groups[group]) {
      groups[group] = [];
    }
    groups[group].push({ ...bone, index: index });
  });

  let html = "";
  for (const [groupName, groupBones] of Object.entries(groups)) {
    html += `
            <div class="control-group">
                <div class="control-group-title">${getGroupLabel(groupName)}</div>
                ${groupBones
                  .map(
                    (bone) => `
                    <div class="control-item">
                        <div class="control-label">
                            <span class="control-name">${bone.label}</span>
                            <span class="control-value" id="control-value-${bone.index}">0.0</span>
                        </div>
                        <div class="control-slider">
                            <div class="control-slider-fill" id="control-fill-${bone.index}"></div>
                        </div>
                    </div>
                `,
                  )
                  .join("")}
            </div>
        `;
  }

  $("#controlGroups").html(html);
}

// ← GEÄNDERT: Dynamische Labels aus Config.ControlGroups
function getGroupLabel(group) {
  // 1. Aus Config.ControlGroups (dynamisch via Lua mitgeschickt)
  if (groupLabels[group] && groupLabels[group].label) {
    return groupLabels[group].label;
  }

  // 2. Fallback: Erster Buchstabe gross
  return group.charAt(0).toUpperCase() + group.slice(1);
}

function setupQuickActions(vehicle) {
  if (vehicle.stabilizers && vehicle.stabilizers.enabled) {
    $("#stabilizersBtn").removeClass("hidden");
  } else {
    $("#stabilizersBtn").addClass("hidden");
  }

  if (vehicle.waterMonitor && vehicle.waterMonitor.enabled) {
    $("#waterBtn").removeClass("hidden");
  } else {
    $("#waterBtn").addClass("hidden");
  }

  if (vehicle.cage && vehicle.cage.enabled) {
    $("#cageBtn").removeClass("hidden");
    $("#cageStatus").show();
  } else {
    $("#cageBtn").addClass("hidden");
    $("#cageStatus").hide();
  }
}
function enterCage() {
  $.post("https://D4rk_Smart_Vehicle/enterCage", JSON.stringify({}));
}

function exitCage() {
  $.post("https://D4rk_Smart_Vehicle/exitCage", JSON.stringify({}));
}

// ============================================
// UPDATE FUNCTIONS
// ============================================
function updateControl(index, value) {
  var jsIndex = index - 1;

  if (!currentVehicle || !currentVehicle.bones[jsIndex]) return;

  const bone = currentVehicle.bones[jsIndex];
  const range = bone.max - bone.min;
  const percentage = (value - bone.min) / range;

  $(`#control-value-${jsIndex}`).text(value.toFixed(1));
  $(`#control-fill-${jsIndex}`).css("transform", `scaleX(${percentage})`);

  updateHudControl(jsIndex, value);
  controlStates[jsIndex] = value;
}

function updateStabilizers(deployed) {
  stabilizersDeployed = deployed;

  if (deployed) {
    $("#stabilizersStatus").text("Ausgefahren").addClass("active");
    $("#stabilizersBtn").addClass("active");
  } else {
    $("#stabilizersStatus").text("Eingefahren").removeClass("active");
    $("#stabilizersBtn").removeClass("active");
  }
}

function updateWater(active) {
  waterActive = active;

  if (active) {
    $("#waterBtn").addClass("active");
  } else {
    $("#waterBtn").removeClass("active");
  }
}

function updateCage(inCageStatus, occupants, maxOccupants) {
  inCage = inCageStatus;

  if (occupants !== undefined) {
    $("#cageOccupants").text(`${occupants}/${maxOccupants}`);
  }

  if (inCageStatus) {
    $("#cageBtn").addClass("active");
  } else {
    $("#cageBtn").removeClass("active");
  }
}

function updateMode(mode) {
  const modeLabels = {
    inside: "Im Fahrzeug",
    standing: "Am Fahrzeug",
    remote: "Fernbedienung",
    cage: "Im Korb",
  };

  $("#controlMode").text(modeLabels[mode] || mode);
  $("#hudControlMode").text(mode.toUpperCase());
}

// ============================================
// HUD FUNCTIONS
// ============================================
function showHud(vehicle) {
  currentVehicle = vehicle;

  $("#hudVehicleName").text(vehicle.label);
  buildHudControls(vehicle.bones);

  $("#compactHud").removeClass("hidden").css("display", "block");
}

function hideHud() {
  $("#compactHud").addClass("hidden").css("display", "none");
}

function buildHudControls(bones) {
  let html = "";

  bones.slice(0, 4).forEach((bone, index) => {
    html += `
            <div class="hud-control-item">
                <span>${bone.label}</span>
                <span class="hud-control-value" id="hud-value-${index}">0.0</span>
            </div>
        `;
  });

  $("#hudControls").html(html);
}

function updateHudControl(index, value) {
  $(`#hud-value-${index}`).text(value.toFixed(1));
}

// ============================================
// PROMPT FUNCTIONS
// ============================================
function showCagePrompt(show) {
  if (show) {
    $("#cagePrompt").removeClass("hidden").css("display", "block");
  } else {
    $("#cagePrompt").addClass("hidden").css("display", "none");
  }
}

// ============================================
// NOTIFICATION SYSTEM
// ============================================
function showNotification(message, type = "info") {
  const notification = $(`
        <div class="notification ${type}">
            ${message}
        </div>
    `);

  $("#notifications").append(notification);

  setTimeout(() => {
    notification.fadeOut(300, function () {
      $(this).remove();
    });
  }, 3000);
}

// ============================================
// ACTION HANDLERS
// ============================================
function toggleStabilizers() {
  $.post("https://D4rk_Smart_Vehicle/toggleStabilizers", JSON.stringify({}));
}

function toggleWater() {
  $.post("https://D4rk_Smart_Vehicle/toggleWater", JSON.stringify({}));
}

function toggleCage() {
  $.post("https://D4rk_Smart_Vehicle/toggleCage", JSON.stringify({}));
}

function resetAll() {
  $.post("https://D4rk_Smart_Vehicle/resetAll", JSON.stringify({}));
}

// ============================================
// KEYBOARD HANDLERS
// ============================================
document.addEventListener("keydown", function (e) {
  if (e.key === "Escape" || e.keyCode === 27) {
    const panel = document.getElementById("controlPanel");

    if (escHandlerEnabled && panel && panel.style.display === "block") {
      console.log("ESC pressed in NUI - closing panel");
      e.preventDefault();
      e.stopPropagation();
      closePanel();
    }
  }
});

document.addEventListener("contextmenu", (event) => event.preventDefault());
