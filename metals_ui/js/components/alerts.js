export function alert(message, type = "error") {
  return `<p class="notice notice--${type}" role="alert">${message}</p>`;
}
