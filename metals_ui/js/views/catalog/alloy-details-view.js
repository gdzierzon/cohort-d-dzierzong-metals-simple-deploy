import { getAlloyElements } from "../../api/alloy-elements-api.js";
import { getAlloy } from "../../api/alloys-api.js";
import { getElements } from "../../api/elements-api.js";
import { getMintProductsByAlloy } from "../../api/coins-api.js";
import { labelCurrentVisit } from "../../navigation-history.js";
import { detailsNavMarkup } from "./details-nav.js";

const alloyImageDirectory = "./assets/images/alloys";
const elementImageDirectory = "./assets/images/elements";
const fallbackAlloyImage = "./assets/images/no-image.png";
const fallbackElementImage = "./assets/images/no-image.png";
const coinImageDirectory = "./assets/images/coins";
const fallbackCoinImage = "./assets/images/no-image.png";
const percentFormatter = new Intl.NumberFormat("en-US", { maximumFractionDigits: 3 });

export function alloyDetailsView({ alloyId } = {}) {
  const id = Number(alloyId);
  const nav = detailsNavMarkup("/alloys", "alloys");
  if (!Number.isInteger(id) || id <= 0) {
    return `<main id="app-content" class="page details-page">${nav}<p class="catalog-status">That alloy could not be found.</p></main>`;
  }

  return `
    <main id="app-content" class="page details-page alloy-details-page">
      ${nav}
      <section id="alloy-details" data-alloy-id="${id}" aria-live="polite"><p class="placeholder">Loading alloy details…</p></section>
    </main>
  `;
}

export async function bindAlloyDetailsView() {
  const container = document.querySelector("#alloy-details");
  if (!container) return;

  try {
    const alloyId = Number(container.dataset.alloyId);
    const [alloy, composition, elements, coins] = await Promise.all([
      getAlloy(alloyId),
      getAlloyElements(alloyId),
      getElements(),
      getMintProductsByAlloy(alloyId),
    ]);
    labelCurrentVisit(alloy.name);
    container.replaceChildren(createAlloyDetails(alloy, composition, elements, coins));
  } catch (error) {
    container.replaceChildren(createStatus(error.message || "We could not load this alloy."));
  }
}

function createAlloyDetails(alloy, composition, elements, coins) {
  const fragment = document.createDocumentFragment();
  const hero = document.createElement("section");
  hero.className = "alloy-details-hero";

  const image = document.createElement("img");
  image.src = `${alloyImageDirectory}/${slugify(alloy.name)}.png`;
  image.alt = `${alloy.name} polished alloy bar on slate`;
  addImageFallback(image, fallbackAlloyImage, "No image available");

  const content = document.createElement("div");
  content.className = "alloy-details-hero__content";
  content.innerHTML = `<p class="details-content__eyebrow">Alloy <span></span></p><h1></h1><p class="alloy-details-hero__color"></p><p class="alloy-details-hero__description"></p>`;
  content.querySelector("span").textContent = String(alloy.alloy_id);
  content.querySelector("h1").textContent = alloy.name;
  content.querySelector(".alloy-details-hero__color").textContent = formatLabel(alloy.color) || "Color not specified";
  content.querySelector(".alloy-details-hero__description").textContent = alloy.description || "A metal blend in the Metals Atlas collection.";
  hero.append(image, content);

  const compositionSection = document.createElement("section");
  compositionSection.className = "alloy-composition";
  compositionSection.innerHTML = `<div class="alloy-composition__heading"><div><p class="catalog-intro__eyebrow">Composition</p><h2>Elements in this alloy</h2></div><p></p></div><div class="composition-grid"></div>`;
  const elementsByNumber = new Map(elements.map((element) => [Number(element.atomic_number), element]));
  const resolved = composition
    .map((component) => ({ component, element: elementsByNumber.get(Number(component.atomic_number)) }))
    .filter(({ element }) => element)
    .sort((a, b) => Number(b.component.percent_of_alloy) - Number(a.component.percent_of_alloy));
  const total = resolved.reduce((sum, { component }) => sum + Number(component.percent_of_alloy), 0);
  compositionSection.querySelector(".alloy-composition__heading > p").textContent = resolved.length ? `${percentFormatter.format(total)}% total` : "No composition recorded";
  const grid = compositionSection.querySelector(".composition-grid");
  grid.replaceChildren(...(resolved.length ? resolved.map(createCompositionCard) : [createStatus("No elements have been added to this alloy yet.")]));

  const coinsSection = document.createElement("section");
  coinsSection.className = "alloy-coins";
  coinsSection.innerHTML = `<div class="alloy-composition__heading"><div><p class="catalog-intro__eyebrow">Coinage</p><h2>Coins using this alloy</h2></div><p></p></div><div class="coin-grid"></div>`;
  coinsSection.querySelector(".alloy-composition__heading > p").textContent = `${coins.length} ${coins.length === 1 ? "coin" : "coins"}`;
  coinsSection.querySelector(".coin-grid").replaceChildren(...(coins.length ? coins.map(createCoinCard) : [createStatus("Nothing in the catalog currently uses this alloy.")]));

  fragment.append(hero, compositionSection, coinsSection);
  return fragment;
}

function createCompositionCard({ component, element }) {
  const card = document.createElement("a");
  card.className = "composition-card";
  card.href = `#/elements/${element.atomic_number}`;
  card.innerHTML = `<img><div class="composition-card__body"><div class="composition-card__top"><span class="composition-card__number"></span><strong class="composition-card__percent"></strong></div><div class="composition-card__identity"><h3></h3><span></span></div><span class="composition-card__link">View element <span aria-hidden="true">›</span></span></div>`;
  const image = card.querySelector("img");
  image.src = `${elementImageDirectory}/${element.symbol}.png`;
  image.alt = `${element.name} specimen on slate`;
  image.loading = "lazy";
  addImageFallback(image, fallbackElementImage, "No image available");
  card.querySelector(".composition-card__number").textContent = `Atomic no. ${element.atomic_number}`;
  card.querySelector(".composition-card__percent").textContent = `${percentFormatter.format(Number(component.percent_of_alloy))}%`;
  card.querySelector("h3").textContent = element.name;
  card.querySelector(".composition-card__identity > span").textContent = element.symbol;
  return card;
}

function createCoinCard(coin) {
  const card = document.createElement("a");
  card.className = "coin-card coin-card--compact";
  card.href = `#/coins/${coin.mint_product_id}`;
  card.innerHTML = `<img><div class="coin-card__body"><span class="coin-card__country"></span><h3></h3><p class="coin-card__mint"></p><span class="composition-card__link">View coin <span aria-hidden="true">›</span></span></div>`;
  const image = card.querySelector("img");
  image.src = `${coinImageDirectory}/${slugify(coin.name)}.png`;
  image.alt = `${coin.name} proof obverse and reverse`;
  image.loading = "lazy";
  addImageFallback(image, fallbackCoinImage, "No image available");
  // "country" became "issuer" when coins grew into mint_products: a private mint
  // can strike a bar, and it is not a country. The old name read undefined here, so
  // every card said "Country not specified".
  card.querySelector(".coin-card__country").textContent = coin.issuer || "Issuer not specified";
  card.querySelector("h3").textContent = coin.name;
  card.querySelector(".coin-card__mint").textContent = coin.mint || "Mint not specified";
  return card;
}

function addImageFallback(image, fallback, alt) {
  image.addEventListener("error", () => { image.src = fallback; image.alt = alt; }, { once: true });
}

function createStatus(message) {
  const status = document.createElement("p");
  status.className = "catalog-status";
  status.textContent = message;
  return status;
}

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function formatLabel(value) {
  return value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase()) : "";
}
