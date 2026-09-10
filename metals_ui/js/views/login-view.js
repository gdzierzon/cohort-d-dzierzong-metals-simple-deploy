import { login } from "../api/auth-api.js";
import { storeSession } from "../auth/session.js";

export function loginView() {
  return `
    <main id="app-content" class="page auth-page">
      <section class="auth-panel" aria-labelledby="login-title">
        <div class="auth-panel__intro">
          <p class="auth-panel__eyebrow">Metals Atlas</p>
          <h1 id="login-title">Welcome back.</h1>
          <p>Log in to explore the catalog of elements, alloys, and coins.</p>
        </div>
        <form id="login-form" class="auth-form" novalidate>
          <div id="login-message" class="auth-form__message" role="alert" aria-live="polite" hidden></div>
          <div class="field">
            <label for="username">Username</label>
            <input id="username" name="username" type="text" autocomplete="username" minlength="3" maxlength="100" required autofocus />
          </div>
          <div class="field">
            <label for="password">Password</label>
            <input id="password" name="password" type="password" autocomplete="current-password" required />
          </div>
          <button class="button button--primary auth-form__submit" type="submit">
            <span>Log in</span><span aria-hidden="true">›</span>
          </button>
          <p class="auth-form__alternate">New to Metals Atlas? <a href="#/register">Create an account</a></p>
        </form>
      </section>
    </main>
  `;
}

export function bindLoginForm() {
  const form = document.querySelector("#login-form");
  if (!form) {
    return;
  }

  const message = form.querySelector("#login-message");
  const submitButton = form.querySelector('button[type="submit"]');

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    message.hidden = true;
    message.textContent = "";

    if (!form.checkValidity()) {
      form.reportValidity();
      return;
    }

    submitButton.disabled = true;
    submitButton.querySelector("span").textContent = "Logging in…";

    try {
      const session = await login({
        username: form.elements.username.value.trim(),
        password: form.elements.password.value,
      });
      storeSession(session);
      window.location.hash = "/";
    } catch (error) {
      message.textContent = error.message || "We could not log you in. Please try again.";
      message.hidden = false;
      submitButton.disabled = false;
      submitButton.querySelector("span").textContent = "Log in";
    }
  });
}
