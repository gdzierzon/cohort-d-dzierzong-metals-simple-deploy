import { createAlloy, deleteAlloy, getAlloys, updateAlloy } from "../../api/alloys-api.js";
import { adminCrudView, bindAdminCrud } from "./crud-admin.js";

const config = {
  key: "alloys-admin", title: "Alloys", singular: "alloy", idKey: "alloy_id",
  description: "Create and maintain alloy names, colors, and descriptions.",
  fields: [
    { name: "name", label: "Name", required: true },
    { name: "color", label: "Color" },
    { name: "description", label: "Description", type: "textarea" },
  ],
  list: getAlloys, create: createAlloy, update: updateAlloy, remove: deleteAlloy,
  sort: (a, b) => a.name.localeCompare(b.name),
  itemName: (item) => item.name,
  summary: (item) => `${item.color || "Color not specified"} · ${item.description || "No description"}`,
};

export const alloysAdminView = () => adminCrudView(config);
export const bindAlloysAdminView = () => bindAdminCrud(config);
