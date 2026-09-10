export function confirmDeletion(itemName) {
  return window.confirm(`Delete ${itemName}? This action cannot be undone.`);
}
