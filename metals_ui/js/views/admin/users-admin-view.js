import { getUsers, setUserAdminPermission } from "../../api/users-api.js";
import { state } from "../../state.js";

export function usersAdminView() {
  return `
    <main id="app-content" class="page admin-page">
      <header class="admin-header">
        <p class="catalog-intro__eyebrow">Access control</p>
        <h1>Users</h1>
        <p>Review customer accounts and grant or remove administrator permission.</p>
      </header>
      <section class="admin-list-section" aria-labelledby="users-heading">
        <div class="admin-section-heading">
          <div><p class="catalog-intro__eyebrow">Accounts</p><h2 id="users-heading">All users</h2></div>
          <a class="admin-button" href="#/admin">Back to administration</a>
        </div>
        <p id="users-message" class="admin-form__message" role="status" aria-live="polite">Loading users…</p>
        <div id="users-list" class="admin-list"></div>
      </section>
    </main>`;
}

export async function bindUsersAdminView() {
  const list = document.querySelector("#users-list");
  const message = document.querySelector("#users-message");
  if (!list || !message) return;

  try {
    const users = await getUsers();
    if (!document.body.contains(list)) return;
    renderUsers(list, users, message);
    message.textContent = users.length ? `${users.length} user${users.length === 1 ? "" : "s"}` : "No users found.";
  } catch (error) {
    message.textContent = error.message;
    message.classList.add("admin-form__message--error");
  }
}

function renderUsers(list, users, message) {
  list.replaceChildren(...users.map((user) => createUserRow(user, message)));
}

function createUserRow(user, message) {
  const row = document.createElement("article");
  row.className = "admin-row admin-user-row";

  const content = document.createElement("div");
  content.className = "admin-row__content";
  const name = document.createElement("h3");
  name.textContent = user.username;
  const details = document.createElement("p");
  details.textContent = `User ID ${user.user_id} · ${user.roles.join(", ") || "No roles"}`;
  content.append(name, details);

  const label = document.createElement("label");
  label.className = "admin-checkbox admin-user-row__permission";
  const checkbox = document.createElement("input");
  checkbox.type = "checkbox";
  checkbox.checked = user.roles.includes("Admin");
  checkbox.disabled = user.user_id === state.currentUser?.user_id;
  checkbox.setAttribute("aria-label", `Administrator permission for ${user.username}`);
  const labelText = document.createElement("span");
  labelText.textContent = checkbox.disabled ? "Administrator (current account)" : "Administrator";
  label.append(checkbox, labelText);

  checkbox.addEventListener("change", async () => {
    const requestedValue = checkbox.checked;
    checkbox.disabled = true;
    message.classList.remove("admin-form__message--error");
    message.textContent = `Updating ${user.username}…`;
    try {
      const updatedUser = await setUserAdminPermission(user.user_id, requestedValue);
      user.roles = updatedUser.roles;
      details.textContent = `User ID ${user.user_id} · ${user.roles.join(", ") || "No roles"}`;
      checkbox.checked = user.roles.includes("Admin");
      message.textContent = `${user.username}'s permissions were updated.`;
    } catch (error) {
      checkbox.checked = !requestedValue;
      message.textContent = error.message;
      message.classList.add("admin-form__message--error");
    } finally {
      checkbox.disabled = false;
    }
  });

  row.append(content, label);
  return row;
}
