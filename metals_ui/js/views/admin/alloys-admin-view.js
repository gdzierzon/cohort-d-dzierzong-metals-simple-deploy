import { createAlloy, deleteAlloy, getAlloys, updateAlloy } from "../../api/alloys-api.js";
import { ALLOY_FAMILIES, ALLOY_USES, formatAlloyLabel } from "../../constants/alloy-metadata.js";
import { adminCrudView, bindAdminCrud } from "./crud-admin.js";

const asOptions = (codes) => codes.map((code) => ({ value: code, label: formatAlloyLabel(code) }));

const config = {
  key: "alloys-admin", title: "Alloys", singular: "alloy", idKey: "alloy_id",
  description: "Create and maintain alloy names, base metals, colors, uses, and descriptions.",
  fields: [
    { name: "name", label: "Name", required: true },
    // Required because alloys.alloy_family is NOT NULL with no default.
    { name: "alloy_family", label: "Base metal", type: "select", required: true, placeholder: "Select a base metal…", options: asOptions(ALLOY_FAMILIES) },
    { name: "color", label: "Color" },
    { name: "uses", label: "Uses", type: "multicheckbox", options: asOptions(ALLOY_USES) },
    { name: "description", label: "Description", type: "textarea" },
  ],
  list: getAlloys, create: createAlloy, update: updateAlloy, remove: deleteAlloy,
  sort: (a, b) => a.name.localeCompare(b.name),
  itemName: (item) => item.name,
  summary: (item) => [
    formatAlloyLabel(item.alloy_family) || "No base metal",
    item.color || "Color not specified",
    (item.uses ?? []).length ? item.uses.map(formatAlloyLabel).join(", ") : "No uses recorded",
  ].join(" · "),
};

export const alloysAdminView = () => adminCrudView(config);
export const bindAlloysAdminView = () => bindAdminCrud(config);
