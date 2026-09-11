import { register } from "../api/auth-api.js";

// Mirrors PASSWORD_MINIMUM_LENGTH / PASSWORD_MAXIMUM_LENGTH in
// metals_api/dtos/auth_dto.py - change both together. The API is the authority;
// everything here is only for immediate feedback while typing.
const PASSWORD_MINIMUM_LENGTH = 15;

// Strength is judged on length alone, deliberately. Meeting the minimum is
// already a reasonable password, so the lowest band a valid password can reach
// is "medium" - there is no "weak" state for something that passes validation.
const STRENGTH_BANDS = [
  { minimum: 30, level: "excellent", label: "Excellent — a phrase this long is very hard to guess." },
  { minimum: 20, level: "strong", label: "Strong — comfortably past the minimum." },
  { minimum: PASSWORD_MINIMUM_LENGTH, level: "medium", label: "Medium — valid. A few more words would make it stronger." },
];

function describeStrength(password) {
  if (!password) {
    return { level: "empty", label: "", progress: 0 };
  }

  const band = STRENGTH_BANDS.find((candidate) => password.length >= candidate.minimum);
  if (band) {
    return {
      level: band.level,
      label: band.label,
      progress: Math.min(1, password.length / 30),
    };
  }

  const remaining = PASSWORD_MINIMUM_LENGTH - password.length;
  return {
    level: "short",
    label: `${remaining} more character${remaining === 1 ? "" : "s"} to go.`,
    progress: password.length / PASSWORD_MINIMUM_LENGTH,
  };
}

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
            <input id="register-username" name="username" type="text" autocomplete="username" minlength="3" maxlength="100" pattern="[A-Za-z0-9][A-Za-z0-9._\-]*[A-Za-z0-9]" required autofocus />
            <p class="field__hint">3–100 letters, numbers, dots, hyphens, or underscores. No spaces.</p>
          </div>
          <div class="field">
            <label for="register-password">Password</label>
            <input id="register-password" name="password" type="password" autocomplete="new-password" minlength="15" maxlength="128" required aria-describedby="password-hint password-strength" />
            <p class="field__hint" id="password-hint">
              At least 15 characters. <strong>Spaces are welcome</strong> — a sentence you'll
              remember makes a great password, like <em>my grandmother collected silver coins</em>.
              Length beats complicated: no capitals, digits, or symbols are required.
            </p>
            <p class="password-strength" id="password-strength" role="status" aria-live="polite" data-level="empty">
              <span class="password-strength__track"><span class="password-strength__fill"></span></span>
              <span class="password-strength__label"></span>
            </p>
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
  const strength = form.querySelector("#password-strength");
  const strengthFill = strength?.querySelector(".password-strength__fill");
  const strengthLabel = strength?.querySelector(".password-strength__label");

  if (strength) {
    password.addEventListener("input", () => {
      const { level, label, progress } = describeStrength(password.value);
      strength.dataset.level = level;
      strengthLabel.textContent = label;
      strengthFill.style.width = `${Math.round(progress * 100)}%`;
    });
  }

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
