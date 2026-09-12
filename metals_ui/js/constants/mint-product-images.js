// Most product images follow the UI slug for the database name. The reference
// images supplied for the newer world products use marketplace-style filenames,
// so keep those aliases here while leaving the display names canonical.
const MINT_PRODUCT_IMAGE_ALIASES = Object.freeze({
  "2025 Silver Lunar Snake, Dragon Privy (1 oz)":
    "2025-1-oz-silver-lunar-snake-dragon-privy-bu-australian-perth-mint.png",
  "2026 Silver Kookaburra (1 oz)":
    "2026-1-oz-silver-australian-kookaburra-perth-mint-bu.png",
  "20 Franc Swiss Vreneli": "20-franc-gold-swiss-vreneli-au-bu-1879-1949.png",
  "Austrian 1 Ducat (1915 Restrike)": "1915-austrian-gold-1-ducat-au-bu-restrike.png",
  "Tara Tree of Life Gold Round (1 oz)":
    "tara-tree-of-life-1-oz-gold-round-9999-pure.png",
  "Aztec Calendar Copper Round (5 oz)": "5-oz-aztec-calendar-copper-round.png",
  "2022 South Korean Silver Phoenix (1 oz)":
    "2022-1-oz-south-korean-silver-phoenix.png",
  "Year of the Snake Silver Round (1 oz)": "1-oz-year-of-the-snake-silver-round.png",
  "Tara Tree of Life Silver Round (1 oz)":
    "1-oz-ireland-tara-tree-of-life-silver-round.png",
  "2026 Silver Vienna Philharmonic (1 oz)":
    "2026-1-oz-austrian-silver-philharmonic-coin-bu.png",
});

export function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

export function mintProductImageFilename(productName) {
  return MINT_PRODUCT_IMAGE_ALIASES[productName] ?? `${slugify(productName)}.png`;
}
