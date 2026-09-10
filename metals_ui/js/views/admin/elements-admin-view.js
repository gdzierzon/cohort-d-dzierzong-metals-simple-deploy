import { createElement, deleteElement, getElements, updateElement } from "../../api/elements-api.js";
import { adminCrudView, bindAdminCrud } from "./crud-admin.js";

const config = {
  key: "elements-admin", title: "Elements", singular: "element", idKey: "atomic_number",
  description: "Create and maintain the elemental reference catalog.",
  fields: [
    { name: "atomic_number", label: "Atomic number", type: "number", required: true, min: 1, createOnly: true },
    { name: "name", label: "Name", required: true },
    { name: "symbol", label: "Symbol", required: true },
    { name: "category", label: "Category" },
    { name: "state_at_room_temp", label: "State at room temperature", type: "select", options: ["SOLID", "LIQUID", "GAS"].map((value) => ({ value, label: value[0] + value.slice(1).toLowerCase() })) },
    { name: "color", label: "Color" },
    { name: "density", label: "Density (g/cm³)", type: "number", min: 0, step: "any" },
    { name: "melting_point_f", label: "Melting point (°F)", type: "number", step: "any" },
    { name: "boiling_point_f", label: "Boiling point (°F)", type: "number", step: "any" },
    { name: "is_toxic", label: "Toxic", type: "checkbox" },
    { name: "is_magnetic", label: "Magnetic", type: "checkbox" },
    { name: "common_uses", label: "Common uses", type: "textarea" },
  ],
  list: getElements, create: createElement, update: updateElement, remove: deleteElement,
  sort: (a, b) => a.atomic_number - b.atomic_number,
  itemName: (item) => `${item.name} (${item.symbol})`,
  summary: (item) => `Atomic no. ${item.atomic_number} · ${formatLabel(item.category) || "Uncategorized"} · ${formatLabel(item.state_at_room_temp) || "State unknown"}`,
};

export const elementsAdminView = () => adminCrudView(config);
export const bindElementsAdminView = () => bindAdminCrud(config);
function formatLabel(value) { return value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase()) : ""; }
