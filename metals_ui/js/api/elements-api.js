import { apiRequest } from "./client.js";

export const getElements = () => apiRequest("/elements");
export const getElement = (atomicNumber) => apiRequest(`/elements/${atomicNumber}`);
export const createElement = (element) => apiRequest("/elements", { method: "POST", body: JSON.stringify(element) });
export const updateElement = (atomicNumber, element) => apiRequest(`/elements/${atomicNumber}`, { method: "PUT", body: JSON.stringify(element) });
export const deleteElement = (atomicNumber) => apiRequest(`/elements/${atomicNumber}`, { method: "DELETE" });
