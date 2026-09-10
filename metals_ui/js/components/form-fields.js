export function textField({ id, label, type = "text", required = false }) {
  return `
    <label for="${id}">${label}</label>
    <input id="${id}" name="${id}" type="${type}" ${required ? "required" : ""} />
  `;
}
