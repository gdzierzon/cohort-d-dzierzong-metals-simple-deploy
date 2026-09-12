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

export const ALLOY_USES = [
  "AEROSPACE",
  "BEARING",
  "BULLION",
  "COINAGE",
  "COOKWARE",
  "DECORATIVE",
  "ELECTRICAL",
  "FASTENERS",
  "HIGH_TEMPERATURE",
  "INSTRUMENTATION",
  "JEWELRY",
  "MARINE",
  "MEDICAL",
  "MUSICAL",
  "SOLDERING",
  "STRUCTURAL",
  "TOOLING",
];

export function formatAlloyLabel(value) {
  return value
    ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase())
    : "";
}
