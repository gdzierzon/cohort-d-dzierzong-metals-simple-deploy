import { apiRequest } from "./client.js";

export const getAlloyElements = (alloyId) => apiRequest(`/alloy-elements?alloy_id=${encodeURIComponent(alloyId)}`);

// The same table read from the other side: every alloy a given element appears in.
export const getAlloyElementsByElement = (atomicNumber) =>
  apiRequest(`/alloy-elements?atomic_number=${encodeURIComponent(atomicNumber)}`);
