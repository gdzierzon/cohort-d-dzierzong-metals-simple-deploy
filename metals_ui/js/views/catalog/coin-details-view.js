import { getAlloy } from "../../api/alloys-api.js";
import { getCoin } from "../../api/coins-api.js";

const coinImageDirectory = "./assets/images/coins";
const alloyImageDirectory = "./assets/images/alloys";
const fallbackCoinImage = `${coinImageDirectory}/american-gold-eagle-1-oz.png`;
const fallbackAlloyImage = `${alloyImageDirectory}/aluminum-alloy.png`;

export function coinDetailsView({ coinId } = {}) {
  const id = Number(coinId);
  if (!Number.isInteger(id) || id <= 0) {
    return `<main id="app-content" class="page details-page"><a class="details-back" href="#/coins">‹ Back to coins</a><p class="catalog-status">That coin could not be found.</p></main>`;
  }
  return `<main id="app-content" class="page details-page coin-details-page"><a class="details-back" href="#/coins">‹ Back to coins</a><section id="coin-details" data-coin-id="${id}" aria-live="polite"><p class="placeholder">Loading coin details…</p></section></main>`;
}

export async function bindCoinDetailsView() {
  const container = document.querySelector("#coin-details");
  if (!container) return;
  try {
    const coin = await getCoin(Number(container.dataset.coinId));
    const alloy = await getAlloy(coin.alloy_id);
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
  image.src = `${coinImageDirectory}/${slugify(coin.name)}.png`;
  image.alt = `${coin.name} proof obverse and reverse`;
  addFallback(image, fallbackCoinImage, "Proof coin obverse and reverse");
  const content = document.createElement("article");
  content.className = "coin-details-hero__content";
  content.innerHTML = `<p class="details-content__eyebrow">Coin <span></span></p><h1></h1><p class="coin-details-hero__origin"></p><dl class="details-facts"><dt>Mint</dt><dd></dd><dt>Introduced</dt><dd></dd><dt>Gross weight</dt><dd></dd><dt>Face value</dt><dd></dd></dl>`;
  content.querySelector("span").textContent = String(coin.coin_id);
  content.querySelector("h1").textContent = coin.name;
  content.querySelector(".coin-details-hero__origin").textContent = coin.country || "Country not specified";
  const facts = content.querySelectorAll("dd");
  facts[0].textContent = coin.mint || "—";
  facts[1].textContent = coin.year_introduced ?? "—";
  facts[2].textContent = coin.gross_weight_g == null ? "—" : `${formatNumber(coin.gross_weight_g)} g`;
  facts[3].textContent = formatFaceValue(coin);
  hero.append(image, content);

  const alloySection = document.createElement("section");
  alloySection.className = "coin-alloy-section";
  alloySection.innerHTML = `<p class="catalog-intro__eyebrow">Composition</p><h2>Coin alloy</h2>`;
  alloySection.append(createAlloyCard(alloy));
  fragment.append(hero, alloySection);
  return fragment;
}

function createAlloyCard(alloy) {
  const card = document.createElement("a");
  card.className = "coin-alloy-card";
  card.href = `#/alloys/${alloy.alloy_id}`;
  card.innerHTML = `<img><div><span class="coin-alloy-card__label">Alloy</span><h3></h3><p class="coin-alloy-card__color"></p><p class="coin-alloy-card__description"></p><span class="coin-alloy-card__link">View alloy <span aria-hidden="true">›</span></span></div>`;
  const image = card.querySelector("img");
  image.src = `${alloyImageDirectory}/${slugify(alloy.name)}.png`;
  image.alt = `${alloy.name} polished alloy bar on slate`;
  addFallback(image, fallbackAlloyImage, "Polished alloy bar on slate");
  card.querySelector("h3").textContent = alloy.name;
  card.querySelector(".coin-alloy-card__color").textContent = formatLabel(alloy.color) || "Color not specified";
  card.querySelector(".coin-alloy-card__description").textContent = alloy.description || "A metal blend in the Metals Atlas collection.";
  return card;
}

function addFallback(image, source, alt) { image.addEventListener("error", () => { image.src = source; image.alt = alt; }, { once: true }); }
function createStatus(message) { const status = document.createElement("p"); status.className = "catalog-status"; status.textContent = message; return status; }
function formatNumber(value) { return new Intl.NumberFormat("en-US", { maximumFractionDigits: 4 }).format(Number(value)); }
function formatFaceValue(coin) { return coin.face_value == null ? "—" : `${coin.face_value_currency_code || ""} ${formatNumber(coin.face_value)}`.trim(); }
function slugify(value) { return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""); }
function formatLabel(value) { return value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase()) : ""; }
