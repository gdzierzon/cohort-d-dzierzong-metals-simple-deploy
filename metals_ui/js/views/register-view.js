import { register } from "../api/auth-api.js";

export function registerView() {
  return `
    <main id="app-content" class="page auth-page">
      <section class="auth-panel" aria-labelledby="register-title">
        <div class="auth-panel__intro">
          <p class="auth-panel__eyebrow">Metals Atlas</p>
          <h1 id="register-title">Begin your collection.</h1>
          <p>Create a customer account to browse elements, alloys, and coins.</p>
        </div>
        <form id="register-form" class="auth-form" novalidate>
          <div id="register-message" class="auth-form__message" role="alert" aria-live="polite" hidden></div>
          <div class="field">
            <label for="register-username">Username</label>
            <input id="register-username" name="username" type="text" autocomplete="username" minlength="3" maxlength="100" pattern="[A-Za-z0-9_-]+" required autofocus />
            <p class="field__hint">Use 3–100 letters, numbers, hyphens, or underscores.</p>
          </div>
          <div class="field">
            <label for="register-password">Password</label>
            <input id="register-password" name="password" type="password" autocomplete="new-password" required />
          </div>
          <div class="field">
            <label for="confirm-password">Confirm password</label>
            <input id="confirm-password" name="confirmPassword" type="password" autocomplete="new-password" required />
          </div>
          <button class="button button--primary auth-form__submit" type="submit">
            <span>Create account</span><span aria-hidden="true">›</span>
          </button>
          <p class="auth-form__alternate">Already have an account? <a href="#/login">Log in</a></p>
        </form>
      </section>
    </main>
  `;
}

export function bindRegisterForm() {
  const form = document.querySelector("#register-form");
  if (!form) {
    return;
  }

  const message = form.querySelector("#register-message");
  const submitButton = form.querySelector('button[type="submit"]');
  const password = form.elements.password;
  const confirmation = form.elements.confirmPassword;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    message.hidden = true;
    message.textContent = "";
    confirmation.setCustomValidity("");

    if (password.value !== confirmation.value) {
      confirmation.setCustomValidity("Passwords do not match.");
    }

    if (!form.checkValidity()) {
      form.reportValidity();
      return;
    }

    submitButton.disabled = true;
    submitButton.querySelector("span").textContent = "Creating account…";

    try {
      await register({
        username: form.elements.username.value.trim(),
        password: password.value,
      });
      window.location.hash = "/login";
    } catch (error) {
      message.textContent = error.message || "We could not create your account. Please try again.";
      message.hidden = false;
      submitButton.disabled = false;
      submitButton.querySelector("span").textContent = "Create account";
    }
  });
}
