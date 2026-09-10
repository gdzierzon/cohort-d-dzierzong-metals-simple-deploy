import { getCurrentUser } from "../api/auth-api.js";
import { setCurrentUser } from "../state.js";

const TOKEN_KEY = "metals.accessToken";

export function getAccessToken() {
  return sessionStorage.getItem(TOKEN_KEY);
}

export function storeSession({ access_token: token, user }) {
  sessionStorage.setItem(TOKEN_KEY, token);
  setCurrentUser(user);
}

export function clearSession() {
  sessionStorage.removeItem(TOKEN_KEY);
  setCurrentUser(null);
}

export async function restoreSession() {
  if (!getAccessToken()) {
    return;
  }

  try {
    setCurrentUser(await getCurrentUser());
  } catch {
    clearSession();
  }
}
