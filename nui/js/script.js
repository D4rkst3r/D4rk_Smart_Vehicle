// D4rk Smart Vehicle - NUI Script (Aufgeräumt)
// Alte Panel/HUD/Cage-Anzeigen entfernt
// Neue Panels werden über panels.js gesteuert

let currentVehicle = null;
let controlStates = {};
let stabilizersDeployed = false;
let waterActive = false;

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

  switch (data.action) {
    case "updateControl":
      updateControl(data.index, data.value);
      break;
    case "updateStabilizers":
      updateStabilizers(data.deployed);
      break;
    case "updateWater":
      updateWater(data.active);
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
// UPDATE FUNCTIONS
// ============================================
function updateControl(index, value) {
  controlStates[index] = value;
}

function updateStabilizers(deployed) {
  stabilizersDeployed = deployed;
}

function updateWater(active) {
  waterActive = active;
}

function updateMode(mode) {
  // Kann von panels.js genutzt werden
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
// ACTION HANDLERS (für NUI Callbacks)
// ============================================
function toggleStabilizers() {
  $.post("https://D4rk_Smart_Vehicle/toggleStabilizers", JSON.stringify({}));
}

function toggleWater() {
  $.post("https://D4rk_Smart_Vehicle/toggleWater", JSON.stringify({}));
}

function resetAll() {
  $.post("https://D4rk_Smart_Vehicle/resetAll", JSON.stringify({}));
}

// Rechtsklick deaktivieren
document.addEventListener("contextmenu", (event) => event.preventDefault());
