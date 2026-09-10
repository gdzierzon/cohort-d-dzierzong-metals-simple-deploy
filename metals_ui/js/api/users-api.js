import { apiRequest } from "./client.js";

export function getUsers() {
  return apiRequest("/users");
}

export function setUserAdminPermission(userId, isAdmin) {
  return apiRequest(`/users/${userId}/admin`, {
    method: "PUT",
    body: JSON.stringify({ is_admin: isAdmin }),
  });
}
