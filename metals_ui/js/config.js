// API configuration is intentionally independent of the UI's host and port.
// Deployments can replace the value in runtime-config.js without rebuilding
// or modifying the application modules.
const configuredApiBaseUrl = globalThis.METALS_ATLAS_CONFIG?.apiBaseUrl;

export const API_BASE_URL = (
  configuredApiBaseUrl || "http://localhost:5000/api"
).replace(/\/$/, "");
