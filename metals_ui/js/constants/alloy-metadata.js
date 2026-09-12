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
