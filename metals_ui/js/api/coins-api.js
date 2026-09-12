import { apiRequest } from "./client.js";

// Coins are a slice of the mint-products catalog, not a separate resource:
// /api/coins is read-only and returns only the legal-tender pieces. Writes go to
// /api/mint-products, which is where bars, rounds and goldbacks live too.
const query = (filters = {}) => {
  const search = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value === undefined || value === null || value === "") return;
    // Repeated keys are how the API takes "either of these": ?metal=GOLD&metal=SILVER
    (Array.isArray(value) ? value : [value]).forEach((entry) => search.append(key, entry));
  });
  const text = search.toString();
  return text ? `?${text}` : "";
};

export const getCoins = (filters) => apiRequest(`/coins${query(filters)}`);
export const getCoin = (mintProductId) => apiRequest(`/coins/${mintProductId}`);

// Everything made from one alloy - matching its predominant alloy OR any layer,
// so cupronickel turns up the clad quarter whose core is plain copper.
export const getMintProductsByAlloy = (alloyId) => apiRequest(`/mint-products${query({ alloy_id: alloyId })}`);

export const getMintProducts = (filters) => apiRequest(`/mint-products${query(filters)}`);
export const getMintProduct = (mintProductId) => apiRequest(`/mint-products/${mintProductId}`);

export const createMintProduct = (product) =>
  apiRequest("/mint-products", { method: "POST", body: JSON.stringify(product) });
export const updateMintProduct = (mintProductId, product) =>
  apiRequest(`/mint-products/${mintProductId}`, { method: "PUT", body: JSON.stringify(product) });
export const deleteMintProduct = (mintProductId) =>
  apiRequest(`/mint-products/${mintProductId}`, { method: "DELETE" });
