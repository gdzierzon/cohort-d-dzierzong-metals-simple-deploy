import { getAlloys } from "../../api/alloys-api.js";
import { getCoins } from "../../api/coins-api.js";

const coinImageDirectory = "./assets/images/coins";
const fallbackCoinImage = `${coinImageDirectory}/american-gold-eagle-1-oz.png`;

export function coinsView() {
  return `
    <main id="app-content" class="page catalog-page">
      <section class="catalog-intro" aria-labelledby="coins-title">
        <div><p class="catalog-intro__eyebrow">The collection</p><h1 id="coins-title">Coins</h1><p>Explore proof-finished coins and the alloys that give them weight, color, and character.</p></div>
        <img class="catalog-intro__image" src="./assets/images/coins-collection.png" alt="A collection of proof coins" />
      </section>
      <section class="catalog-section" aria-label="Coin catalog">
        <div class="catalog-toolbar">
          <form id="coins-filter" class="catalog-filter" role="search">
            <label class="sr-only" for="coin-search">Search coins</label>
            <input id="coin-search" name="search" type="search" placeholder="Search by coin, country, or mint" autocomplete="off" />
            <label class="sr-only" for="coin-country">Filter by country</label>
            <select id="coin-country" name="country"><option value="">All countries</option></select>
            <button class="catalog-filter__reset" type="reset">Clear</button>
          </form>
          <p id="coins-count" class="catalog-toolbar__count" aria-live="polite"></p>
        </div>
        <div id="coins-results" class="coin-grid" aria-live="polite"><p class="placeholder">Loading coins…</p></div>
      </section>
    </main>`;
}

export async function bindCoinsView() {
  const results = document.querySelector("#coins-results");
  const filter = document.querySelector("#coins-filter");
  const search = document.querySelector("#coin-search");
  const country = document.querySelector("#coin-country");
  const count = document.querySelector("#coins-count");
  if (!results || !filter || !search || !country || !count) return;

  try {
    const [coins, alloys] = await Promise.all([getCoins(), getAlloys()]);
    const alloysById = new Map(alloys.map((alloy) => [Number(alloy.alloy_id), alloy]));
    const sorted = [...coins].sort((a, b) => a.name.localeCompare(b.name));
    [...new Set(sorted.map((coin) => coin.country).filter(Boolean))].sort().forEach((value) => {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = value;
      country.append(option);
    });
    const applyFilters = () => {
      const term = search.value.trim().toLowerCase();
      const selectedCountry = country.value;
      const filtered = sorted.filter((coin) => {
        const text = `${coin.name} ${coin.country ?? ""} ${coin.mint ?? ""}`.toLowerCase();
        return (!term || text.includes(term)) && (!selectedCountry || coin.country === selectedCountry);
      });
      results.replaceChildren(...(filtered.length ? filtered.map((coin) => createCoinCard(coin, alloysById.get(Number(coin.alloy_id)))) : [createStatus("No coins match those filters.")]));
      count.textContent = `${filtered.length} ${filtered.length === 1 ? "coin" : "coins"}`;
    };
    search.addEventListener("input", applyFilters);
    country.addEventListener("change", applyFilters);
    filter.addEventListener("reset", () => window.setTimeout(applyFilters, 0));
    applyFilters();
  } catch (error) {
    results.replaceChildren(createStatus(error.message || "We could not load the coin catalog."));
  }
}

function createCoinCard(coin, alloy) {
  const card = document.createElement("a");
  card.className = "coin-card";
  card.href = `#/coins/${coin.coin_id}`;
  card.innerHTML = `<img><div class="coin-card__body"><span class="coin-card__country"></span><h2></h2><p class="coin-card__mint"></p><dl class="coin-card__facts"><dt>Introduced</dt><dd></dd><dt>Weight</dt><dd></dd><dt>Alloy</dt><dd></dd></dl></div>`;
  const image = card.querySelector("img");
  image.src = `${coinImageDirectory}/${slugify(coin.name)}.png`;
  image.alt = `${coin.name} proof obverse and reverse`;
  image.loading = "lazy";
  image.addEventListener("error", () => { image.src = fallbackCoinImage; image.alt = "Proof coin obverse and reverse"; }, { once: true });
  card.querySelector(".coin-card__country").textContent = coin.country || "Country not specified";
  card.querySelector("h2").textContent = coin.name;
  card.querySelector(".coin-card__mint").textContent = coin.mint || "Mint not specified";
  const facts = card.querySelectorAll("dd");
  facts[0].textContent = coin.year_introduced ?? "—";
  facts[1].textContent = coin.gross_weight_g == null ? "—" : `${formatNumber(coin.gross_weight_g)} g`;
  facts[2].textContent = alloy?.name || "Unknown alloy";
  return card;
}

function createStatus(message) { const status = document.createElement("p"); status.className = "catalog-status"; status.textContent = message; return status; }
function formatNumber(value) { return new Intl.NumberFormat("en-US", { maximumFractionDigits: 4 }).format(Number(value)); }
function slugify(value) { return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""); }
