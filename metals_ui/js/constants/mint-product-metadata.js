// Mirrors chk_mint_products_type in sql/metals-db.sql and PRODUCT_TYPES in
// metals_api/dtos/mint_product_dto.py - change one, change all three.
//
// COIN first because it is most of the catalog, then the bullion forms, then the
// oddities. A NOTE here is a goldback: polymer carrying a measured gold leaf, not
// a banknote - this database has no room for anything without an alloy.
export const PRODUCT_TYPES = ["COIN", "ROUND", "BAR", "INGOT", "NOTE", "MEDAL", "TOKEN"];

// Display order for the metal filter. The list shown is narrowed to the metals
// actually present in the data, since primary_metal is derived from each piece's
// alloy rather than stored on the piece.
export const METAL_ORDER = [
  "GOLD",
  "SILVER",
  "PLATINUM",
  "PALLADIUM",
  "COPPER",
  "NICKEL",
  "IRON",
  "ZINC",
  "ALUMINUM",
  "TIN",
  "TITANIUM",
  "MAGNESIUM",
];

export const COMPONENT_ROLES = ["CORE", "CLADDING", "PLATING", "RING", "CENTER", "LEAF"];
