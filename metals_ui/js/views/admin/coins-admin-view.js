import { getAlloys } from "../../api/alloys-api.js";
import {
  createMintProduct,
  deleteMintProduct,
  getMintProducts,
  updateMintProduct,
} from "../../api/coins-api.js";
import { PRODUCT_TYPES } from "../../constants/mint-product-metadata.js";
import { adminCrudView, bindAdminCrud } from "./crud-admin.js";

let alloyNames = new Map();

const formatLabel = (value) =>
  value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (l) => l.toUpperCase()) : "";

const config = {
  key: "coins-admin",
  title: "Coins & bullion",
  singular: "mint product",
  idKey: "mint_product_id",
  description:
    "Create and maintain coins, rounds, bars, ingots, medals, tokens and goldbacks. The legal tender fields apply to coins only.",
  fields: [
    { name: "name", label: "Name", required: true, wide: true },
    {
      name: "product_type",
      label: "Form",
      type: "select",
      required: true,
      placeholder: "Select a form…",
      options: PRODUCT_TYPES.map((type) => ({ value: type, label: formatLabel(type) })),
    },
    { name: "alloy_id", label: "Predominant alloy", type: "select", required: true, options: [] },
    { name: "issuer", label: "Issuer" },
    { name: "mint", label: "Mint" },
    // Negative years are BC: the Roman denarius is -211.
    { name: "year_introduced", label: "Year introduced (negative for BC)", type: "number", min: -3000, max: 3000 },
    { name: "gross_weight_g", label: "Gross weight (g)", type: "number", min: 0, step: "any" },
    { name: "fine_metal_weight_g", label: "Fine metal weight (g)", type: "number", min: 0, step: "any" },
    { name: "face_value", label: "Face value (coins only)", type: "number", min: 0, step: "any" },
    { name: "face_value_currency_code", label: "Currency code (coins only)" },
  ],
  prepare: async (form) => {
    const alloys = await getAlloys();
    alloys.sort((a, b) => a.name.localeCompare(b.name));
    alloyNames = new Map(alloys.map((alloy) => [Number(alloy.alloy_id), alloy]));
    const select = form.elements.alloy_id;
    alloys.forEach((alloy) => {
      const option = document.createElement("option");
      option.value = alloy.alloy_id;
      // The metal is derived from the alloy, so showing it here explains why a
      // piece ends up filed under gold or copper.
      option.textContent = `${alloy.name} (${formatLabel(alloy.primary_metal)})`;
      select.append(option);
    });
  },
  list: getMintProducts,
  create: createMintProduct,
  update: updateMintProduct,
  remove: deleteMintProduct,
  sort: (a, b) => a.name.localeCompare(b.name),
  itemName: (item) => item.name,
  summary: (item) =>
    [
      formatLabel(item.product_type),
      formatLabel(item.primary_metal),
      item.issuer || "No issuer",
      item.year_introduced == null
        ? "Year unknown"
        : item.year_introduced < 0
          ? `${Math.abs(item.year_introduced)} BC`
          : String(item.year_introduced),
      alloyNames.get(Number(item.alloy_id))?.name || "Unknown alloy",
      item.is_coin ? "Legal tender" : "Not currency",
    ].join(" · "),
};

export const coinsAdminView = () => adminCrudView(config);
export const bindCoinsAdminView = () => bindAdminCrud(config);
