import { getAlloys } from "../../api/alloys-api.js";
import { createCoin, deleteCoin, getCoins, updateCoin } from "../../api/coins-api.js";
import { adminCrudView, bindAdminCrud } from "./crud-admin.js";

let alloyNames = new Map();
const config = {
  key: "coins-admin", title: "Coins", singular: "coin", idKey: "coin_id",
  description: "Create and maintain collectible coins and their associated alloys.",
  fields: [
    { name: "name", label: "Name", required: true, wide: true },
    { name: "country", label: "Country" },
    { name: "mint", label: "Mint" },
    { name: "year_introduced", label: "Year introduced", type: "number", min: 500, max: 3000 },
    { name: "alloy_id", label: "Alloy", type: "select", required: true, options: [] },
    { name: "gross_weight_g", label: "Gross weight (g)", type: "number", min: 0, step: "any" },
    { name: "face_value", label: "Face value", type: "number", min: 0, step: "any" },
    { name: "face_value_currency_code", label: "Currency code" },
  ],
  prepare: async (form) => {
    const alloys = await getAlloys();
    alloys.sort((a, b) => a.name.localeCompare(b.name));
    alloyNames = new Map(alloys.map((alloy) => [Number(alloy.alloy_id), alloy.name]));
    const select = form.elements.alloy_id;
    alloys.forEach((alloy) => { const option = document.createElement("option"); option.value = alloy.alloy_id; option.textContent = alloy.name; select.append(option); });
  },
  list: getCoins, create: createCoin, update: updateCoin, remove: deleteCoin,
  sort: (a, b) => a.name.localeCompare(b.name),
  itemName: (item) => item.name,
  summary: (item) => `${item.country || "Country unknown"} · ${item.year_introduced || "Year unknown"} · ${alloyNames.get(Number(item.alloy_id)) || "Unknown alloy"}`,
};

export const coinsAdminView = () => adminCrudView(config);
export const bindCoinsAdminView = () => bindAdminCrud(config);
