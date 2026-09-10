import { apiRequest } from "./client.js";

export function login(credentials) {
  return apiRequest("/auth/login", {
    method: "POST",
    body: JSON.stringify(credentials),
  });
}

export function register(account) {
  return apiRequest("/auth/register", {
    method: "POST",
    body: JSON.stringify(account),
  });
}

export function getCurrentUser() {
  return apiRequest("/auth/me");
}
