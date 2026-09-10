import { apiRequest } from "./client.js";

export const getAlloys = () => apiRequest("/alloys");
export const getAlloy = (alloyId) => apiRequest(`/alloys/${alloyId}`);
export const createAlloy = (alloy) => apiRequest("/alloys", { method: "POST", body: JSON.stringify(alloy) });
export const updateAlloy = (alloyId, alloy) => apiRequest(`/alloys/${alloyId}`, { method: "PUT", body: JSON.stringify(alloy) });
export const deleteAlloy = (alloyId) => apiRequest(`/alloys/${alloyId}`, { method: "DELETE" });
