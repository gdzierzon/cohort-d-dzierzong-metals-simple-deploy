import { getAlloy } from "../../api/alloys-api.js";
import { getMintProduct } from "../../api/coins-api.js";
import { mintProductImageFilename, slugify } from "../../constants/mint-product-images.js";
import { labelCurrentVisit } from "../../navigation-history.js";
import { detailsNavMarkup } from "./details-nav.js";

const coinImageDirectory = "./assets/images/coins";
const alloyImageDirectory = "./assets/images/alloys";
const fallbackCoinImage = "./assets/images/no-image.png";
const fallbackAlloyImage = "./assets/images/no-image.png";
// ISO 4217 reserves 'XXX' for "no currency involved".
const NO_CURRENCY_CODE = "XXX";

export function coinDetailsView({ coinId } = {}) {
  const id = Number(coinId);
  const nav = detailsNavMarkup("/coins", "coins");
  if (!Number.isInteger(id) || id <= 0) {
    return `<main id="app-content" class="page details-page">${nav}<p class="catalog-status">That coin could not be found.</p></main>`;
  }
  return `<main id="app-content" class="page details-page coin-details-page">${nav}<section id="coin-details" data-coin-id="${id}" aria-live="polite"><p class="placeholder">Loading coin details…</p></section></main>`;
}

export async function bindCoinDetailsView() {
  const container = document.querySelector("#coin-details");
  if (!container) return;
  try {
    const coin = await getMintProduct(Number(container.dataset.coinId));
    const alloy = await getAlloy(coin.alloy_id);
    // So the next page can offer "Back to Morgan Silver Dollar" by name.
    labelCurrentVisit(coin.name);
    container.replaceChildren(createDetails(coin, alloy));
  } catch (error) {
    container.replaceChildren(createStatus(error.message || "We could not load this coin."));
  }
}

function createDetails(coin, alloy) {
  const fragment = document.createDocumentFragment();
  const hero = document.createElement("section");
  hero.className = "coin-details-hero";
  const image = document.createElement("img");
  image.src = `${coinImageDirectory}/${mintProductImageFilename(coin.name)}`;
  image.alt = `${coin.name} proof obverse and reverse`;
  addFallback(image, fallbackCoinImage, "No image available");
  const content = document.createElement("article");
  content.className = "coin-details-hero__content";
  content.innerHTML = `<p class="details-content__eyebrow"><span class="details-content__label"></span> <span></span></p><h1></h1><p class="coin-details-hero__origin"></p><dl class="details-facts"><dt>Form</dt><dd></dd><dt>Metal</dt><dd></dd><dt>Mint</dt><dd></dd><dt>Introduced</dt><dd></dd><dt>Gross weight</dt><dd></dd><dt>Fine metal</dt><dd></dd><dt>Face value</dt><dd></dd><dt>Legal tender</dt><dd></dd></dl>`;
  content.querySelector(".details-content__label").textContent = formatLabel(coin.product_type) || "Piece";
  content.querySelectorAll(".details-content__eyebrow span")[1].textContent = String(coin.mint_product_id);
  content.querySelector("h1").textContent = coin.name;
  content.querySelector(".coin-details-hero__origin").textContent = coin.issuer || "Issuer not specified";
  const facts = content.querySelectorAll("dd");
  facts[0].textContent = formatLabel(coin.product_type) || "—";
  facts[1].textContent = formatLabel(coin.primary_metal) || "—";
  facts[2].textContent = coin.mint || "—";
  facts[3].textContent = coin.year_introduced == null ? "—" : formatYear(coin.year_introduced);
  facts[4].textContent = coin.gross_weight_g == null ? "—" : `${formatNumber(coin.gross_weight_g)} g`;
  facts[5].textContent = coin.fine_metal_weight_g == null ? "—" : `${formatNumber(coin.fine_metal_weight_g)} g`;
  facts[6].textContent = formatFaceValue(coin);
  facts[7].textContent = coin.is_coin ? (coin.is_legal_tender ? "Yes" : "No longer") : "Not currency";
  hero.append(image, content);

  const alloySection = document.createElement("section");
  alloySection.className = "coin-alloy-section";
  alloySection.innerHTML = `<p class="catalog-intro__eyebrow">Composition</p><h2>Predominant alloy</h2>`;
  alloySection.append(createAlloyCard(alloy));
  fragment.append(hero, alloySection);

  // Only layered pieces have components. Worth showing, because the predominant
  // alloy alone is misleading for a clad coin - the quarter above says "pure
  // copper", which is the core you cannot see.
  const components = coin.components ?? [];
  if (components.length) {
    fragment.append(createConstructionSection(components));
  }
  return fragment;
}

function createConstructionSection(components) {
  const section = document.createElement("section");
  section.className = "coin-alloy-section";
  section.innerHTML = `<p class="catalog-intro__eyebrow">Construction</p><h2>How it is layered</h2><div class="element-table-wrap"><table class="element-table"><thead><tr><th scope="col">Layer</th><th scope="col">Alloy</th><th scope="col">Share of weight</th></tr></thead><tbody></tbody></table></div>`;

  const body = section.querySelector("tbody");
  components.forEach((component) => {
    const row = document.createElement("tr");

    const roleCell = document.createElement("th");
    roleCell.scope = "row";
    roleCell.textContent = formatLabel(component.component_role);

    const alloyCell = document.createElement("td");
    alloyCell.className = "element-table__name";
    const link = document.createElement("a");
    link.href = `#/alloys/${component.alloy_id}`;
    link.textContent = component.alloy_name;
    alloyCell.append(link);

    const shareCell = document.createElement("td");
    // Null where the split between layers is not something we can state - a
    // bimetallic ring and centre, for instance.
    shareCell.textContent =
      component.percent_of_weight == null
        ? "Not recorded"
        : `${formatNumber(component.percent_of_weight)}%`;

    row.append(roleCell, alloyCell, shareCell);
    body.append(row);
  });

  return section;
}

function createAlloyCard(alloy) {
  const card = document.createElement("a");
  card.className = "coin-alloy-card";
  card.href = `#/alloys/${alloy.alloy_id}`;
  card.innerHTML = `<img><div><span class="coin-alloy-card__label">Alloy</span><h3></h3><p class="coin-alloy-card__color"></p><p class="coin-alloy-card__description"></p><span class="coin-alloy-card__link">View alloy <span aria-hidden="true">›</span></span></div>`;
  const image = card.querySelector("img");
  image.src = `${alloyImageDirectory}/${slugify(alloy.name)}.png`;
  image.alt = `${alloy.name} polished alloy bar on slate`;
  addFallback(image, fallbackAlloyImage, "No image available");
  card.querySelector("h3").textContent = alloy.name;
  card.querySelector(".coin-alloy-card__color").textContent = formatLabel(alloy.color) || "Color not specified";
  card.querySelector(".coin-alloy-card__description").textContent = alloy.description || "A metal blend in the Metals Atlas collection.";
  return card;
}

function addFallback(image, source, alt) { image.addEventListener("error", () => { image.src = source; image.alt = alt; }, { once: true }); }
function createStatus(message) { const status = document.createElement("p"); status.className = "catalog-status"; status.textContent = message; return status; }
function formatNumber(value) { return new Intl.NumberFormat("en-US", { maximumFractionDigits: 4 }).format(Number(value)); }
function formatFaceValue(coin) {
  if (!coin.is_coin) return "Not legal tender";
  const code = coin.face_value_currency_code;

  if (coin.face_value == null) {
    // A Krugerrand has a currency but carries no denomination; its value is the
    // gold price. 'XXX' is the reverse - a denomination in a unit that never had
    // an ISO 4217 code, like a ducat or a real.
    if (code === NO_CURRENCY_CODE) return "Pre-ISO denomination";
    return code ? `No denomination (${code})` : "No denomination";
  }
  return `${code || ""} ${formatNumber(coin.face_value)}`.trim();
}
function formatYear(year) { return year < 0 ? `${Math.abs(year)} BC` : String(year); }
function formatLabel(value) { return value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase()) : ""; }
