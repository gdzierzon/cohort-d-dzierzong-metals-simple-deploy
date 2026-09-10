import { API_BASE_URL } from "../config.js";
import { clearSession, getAccessToken } from "../auth/session.js";

export async function apiRequest(path, options = {}) {
  const headers = new Headers(options.headers);
  headers.set("Accept", "application/json");

  const token = getAccessToken();
  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }
  if (options.body) {
    headers.set("Content-Type", "application/json");
  }

  let response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      ...options,
      headers,
    });
  } catch {
    throw new Error("There was an error with your request. Please try again.");
  }

  if (response.status === 401) {
    clearSession();
  }

  const body = response.status === 204 ? null : await response.json();
  if (!response.ok) {
    throw new Error(body?.error ?? body?.errors?.join(" ") ?? "Request failed.");
  }

  return body;
}
