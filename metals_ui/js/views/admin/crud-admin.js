import { confirmDeletion } from "../../components/confirm-dialog.js";

export function adminCrudView(config) {
  return `
    <main id="app-content" class="page admin-page">
      <a class="details-back" href="#/admin">‹ Back to administration</a>
      <header class="admin-header"><div><p class="catalog-intro__eyebrow">Administration</p><h1>${config.title}</h1><p>${config.description}</p></div></header>
      <section class="admin-editor" aria-labelledby="${config.key}-form-title">
        <div class="admin-section-heading"><div><p class="catalog-intro__eyebrow">Editor</p><h2 id="${config.key}-form-title">Add ${config.singular}</h2></div><button id="${config.key}-cancel" class="admin-button admin-button--quiet" type="button" hidden>Cancel editing</button></div>
        <form id="${config.key}-form" class="admin-form">${config.fields.map(renderField).join("")}<div id="${config.key}-message" class="admin-form__message" aria-live="polite"></div><button class="button button--primary admin-form__submit" type="submit">Create ${config.singular}</button></form>
      </section>
      <section class="admin-list-section" aria-labelledby="${config.key}-list-title">
        <div class="admin-section-heading"><div><p class="catalog-intro__eyebrow">Catalog</p><h2 id="${config.key}-list-title">Existing ${config.title.toLowerCase()}</h2></div><p id="${config.key}-count" class="catalog-toolbar__count"></p></div>
        <div id="${config.key}-list" class="admin-list"><p class="placeholder">Loading…</p></div>
      </section>
    </main>`;
}

export async function bindAdminCrud(config) {
  const form = document.querySelector(`#${config.key}-form`);
  if (!form) return;
  const list = document.querySelector(`#${config.key}-list`);
  const count = document.querySelector(`#${config.key}-count`);
  const message = document.querySelector(`#${config.key}-message`);
  const title = document.querySelector(`#${config.key}-form-title`);
  const cancel = document.querySelector(`#${config.key}-cancel`);
  const submit = form.querySelector("button[type='submit']");
  let items = [];
  let editing = null;

  if (config.prepare) await config.prepare(form);

  const resetEditor = () => {
    editing = null;
    form.reset();
    setLockedFields(form, config, false);
    title.textContent = `Add ${config.singular}`;
    submit.textContent = `Create ${config.singular}`;
    cancel.hidden = true;
    setMessage(message, "");
  };

  const load = async () => {
    list.innerHTML = `<p class="placeholder">Loading…</p>`;
    try {
      items = await config.list();
      items.sort(config.sort);
      count.textContent = `${items.length} ${items.length === 1 ? config.singular : config.title.toLowerCase()}`;
      list.replaceChildren(...(items.length ? items.map((item) => createAdminRow(item, config, startEdit, remove)) : [status("No records found.")]));
    } catch (error) {
      list.replaceChildren(status(error.message || `Could not load ${config.title.toLowerCase()}.`, true));
    }
  };

  const startEdit = (item) => {
    editing = item;
    config.fields.forEach((field) => setFieldValue(form.elements[field.name], item[field.name], field));
    setLockedFields(form, config, true);
    title.textContent = `Edit ${config.singular}`;
    submit.textContent = `Save changes`;
    cancel.hidden = false;
    setMessage(message, "");
    form.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  async function remove(item) {
    if (!confirmDeletion(config.itemName(item))) return;
    try {
      await config.remove(item[config.idKey]);
      if (editing?.[config.idKey] === item[config.idKey]) resetEditor();
      await load();
    } catch (error) {
      setMessage(message, error.message || "The record could not be deleted.", true);
    }
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    submit.disabled = true;
    setMessage(message, editing ? "Saving changes…" : "Creating record…");
    try {
      const payload = buildPayload(form, config.fields, Boolean(editing));
      if (editing) await config.update(editing[config.idKey], payload);
      else await config.create(payload);
      resetEditor();
      await load();
    } catch (error) {
      setMessage(message, error.message || "There was an error with your request.", true);
    } finally {
      submit.disabled = false;
    }
  });
  cancel.addEventListener("click", resetEditor);
  await load();
}

function renderField(field) {
  const required = field.required ? " required" : "";
  const min = field.min == null ? "" : ` min="${field.min}"`;
  const max = field.max == null ? "" : ` max="${field.max}"`;
  const step = field.step == null ? "" : ` step="${field.step}"`;
  if (field.type === "checkbox") return `<label class="admin-checkbox"><input name="${field.name}" type="checkbox"> <span>${field.label}</span></label>`;
  if (field.type === "textarea") return `<label class="admin-field admin-field--wide"><span>${field.label}</span><textarea name="${field.name}" rows="3"${required}></textarea></label>`;
  if (field.type === "select") return `<label class="admin-field"><span>${field.label}</span><select name="${field.name}"${required}><option value="">${field.placeholder || "Select…"}</option>${(field.options || []).map((option) => `<option value="${option.value}">${option.label}</option>`).join("")}</select></label>`;
  return `<label class="admin-field${field.wide ? " admin-field--wide" : ""}"><span>${field.label}</span><input name="${field.name}" type="${field.type || "text"}"${required}${min}${max}${step}></label>`;
}

function createAdminRow(item, config, edit, remove) {
  const row = document.createElement("article");
  row.className = "admin-row";
  const content = document.createElement("div");
  content.className = "admin-row__content";
  const heading = document.createElement("h3"); heading.textContent = config.itemName(item);
  const summary = document.createElement("p"); summary.textContent = config.summary(item);
  content.append(heading, summary);
  const actions = document.createElement("div"); actions.className = "admin-row__actions";
  const editButton = document.createElement("button"); editButton.className = "admin-button"; editButton.type = "button"; editButton.textContent = "Edit"; editButton.addEventListener("click", () => edit(item));
  const deleteButton = document.createElement("button"); deleteButton.className = "admin-button admin-button--danger"; deleteButton.type = "button"; deleteButton.textContent = "Delete"; deleteButton.addEventListener("click", () => remove(item));
  actions.append(editButton, deleteButton); row.append(content, actions); return row;
}

function buildPayload(form, fields, editing) {
  const payload = {};
  fields.forEach((field) => {
    if (editing && field.createOnly) return;
    const control = form.elements[field.name];
    if (field.type === "checkbox") payload[field.name] = control.checked;
    else if (control.value === "") payload[field.name] = field.required ? control.value : null;
    else if (field.type === "number") payload[field.name] = Number(control.value);
    else payload[field.name] = control.value.trim();
  });
  return payload;
}

function setFieldValue(control, value, field) { if (field.type === "checkbox") control.checked = Boolean(value); else control.value = value ?? ""; }
function setLockedFields(form, config, editing) { config.fields.filter((field) => field.createOnly).forEach((field) => { form.elements[field.name].disabled = editing; }); }
function setMessage(node, text, error = false) { node.textContent = text; node.classList.toggle("admin-form__message--error", error); }
function status(message, error = false) { const node = document.createElement("p"); node.className = `catalog-status${error ? " notice--error" : ""}`; node.textContent = message; return node; }
