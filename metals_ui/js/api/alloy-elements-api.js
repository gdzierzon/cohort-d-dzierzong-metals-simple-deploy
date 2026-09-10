import { apiRequest } from "./client.js";

export const getAlloyElements = (alloyId) => apiRequest(`/alloy-elements?alloy_id=${encodeURIComponent(alloyId)}`);
