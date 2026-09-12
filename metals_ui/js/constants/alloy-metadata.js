// Shared by the alloys catalog page and the alloys admin form so the two cannot
// drift apart. These mirror chk_alloy_family and chk_alloy_use_code in
// sql/metals-db.sql, and ALLOY_FAMILIES / ALLOY_USE_CODES in
// metals_api/dtos/alloy_dto.py - change one, change all three.

// Ordered by how many alloys sit in each family, so the common ones come first.
export const ALLOY_FAMILIES = [
  "COPPER",
  "PRECIOUS",
  "FERROUS",
  "ALUMINUM",
  "NICKEL",
  "TIN",
  "TITANIUM",
  "ZINC",
  "MAGNESIUM",
];

// What an alloy looks like, as five buckets over twenty-eight free-text colors.
// Mirrors chk_alloy_color_family and ALLOY_COLOR_FAMILIES in alloy_dto.py.
//
// Ordered light to warm rather than by size, because these are colors and a
// reader scans them as a spectrum. The swatch is only a hint - the real color is
// still the alloy's own text, which is why the card shows both.
export const ALLOY_COLOR_FAMILIES = [
  { code: "SILVER", label: "Silver", swatch: "#c9ccd1" },
  { code: "GRAY", label: "Gray", swatch: "#8a9096" },
  { code: "GOLD", label: "Gold", swatch: "#d4af37" },
  { code: "BRONZE", label: "Bronze", swatch: "#a2703f" },
  { code: "RED", label: "Red", swatch: "#b4653a" },
];

export const ALLOY_COLOR_FAMILY_CODES = ALLOY_COLOR_FAMILIES.map((family) => family.code);

// Seventeen separate checkboxes would swamp the toolbar, so the uses are
// grouped the way the elements page groups its categories: a clickable group
// name that toggles the whole set, with the individual codes under it.
export const ALLOY_USE_GROUPS = [
  {
    id: "industrial",
    label: "Structural & industrial",
    codes: ["STRUCTURAL", "FASTENERS", "BEARING", "TOOLING", "HIGH_TEMPERATURE"],
  },
  {
    id: "precision",
    label: "Electrical & precision",
    codes: ["ELECTRICAL", "SOLDERING", "INSTRUMENTATION", "MEDICAL"],
  },
  { id: "transport", label: "Transport", codes: ["AEROSPACE", "MARINE"] },
  {
    id: "craft",
    label: "Craft & household",
    codes: ["JEWELRY", "DECORATIVE", "COOKWARE", "MUSICAL"],
  },
  { id: "money", label: "Money", codes: ["BULLION", "COINAGE"] },
];

// Flat list for the admin form and for validation, derived so it can never
// disagree with the groups above.
export const ALLOY_USES = ALLOY_USE_GROUPS.flatMap((group) => group.codes).sort();

export function formatAlloyLabel(value) {
  return value
    ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase())
    : "";
}
