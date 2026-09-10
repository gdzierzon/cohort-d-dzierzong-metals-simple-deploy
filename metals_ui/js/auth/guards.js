import { isAdmin, isAuthenticated } from "../state.js";

export const requireLogin = () => isAuthenticated();
export const requireAdmin = () => isAuthenticated() && isAdmin();
