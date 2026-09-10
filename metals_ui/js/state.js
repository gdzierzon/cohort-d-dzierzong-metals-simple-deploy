export const state = {
  currentUser: null,
};

export function setCurrentUser(user) {
  state.currentUser = user;
}

export function isAuthenticated() {
  return state.currentUser !== null;
}

export function isAdmin() {
  return state.currentUser?.roles?.includes("Admin") ?? false;
}
