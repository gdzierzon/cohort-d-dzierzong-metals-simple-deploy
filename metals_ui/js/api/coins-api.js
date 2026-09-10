import { apiRequest } from "./client.js";

export const getCoins = () => apiRequest("/coins");
export const getCoinsByAlloy = (alloyId) => apiRequest(`/coins?alloy_id=${encodeURIComponent(alloyId)}`);
export const getCoin = (coinId) => apiRequest(`/coins/${coinId}`);
export const createCoin = (coin) => apiRequest("/coins", { method: "POST", body: JSON.stringify(coin) });
export const updateCoin = (coinId, coin) => apiRequest(`/coins/${coinId}`, { method: "PUT", body: JSON.stringify(coin) });
export const deleteCoin = (coinId) => apiRequest(`/coins/${coinId}`, { method: "DELETE" });
