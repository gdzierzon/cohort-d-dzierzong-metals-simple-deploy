import { getAlloys } from "../../api/alloys-api.js";

const alloyImageDirectory = "./assets/images/alloys";
const fallbackAlloyImage = `${alloyImageDirectory}/aluminum-alloy.png`;

export function alloysView() {
  return `
    <main id="app-content" class="page catalog-page">
      <section class="catalog-intro" aria-labelledby="alloys-title">
        <div>
          <p class="catalog-intro__eyebrow">The collection</p>
          <h1 id="alloys-title">Alloys</h1>
          <p>Explore thoughtful combinations of metals, shaped for strength, color, and character.</p>
        </div>
        <img class="catalog-intro__image" src="./assets/images/alloys-ingots-slate.png" alt="Gold and silver alloy ingots on slate" />
      </section>

      <section class="catalog-section" aria-label="Alloy catalog">
        <div class="catalog-toolbar">
          <form id="alloys-filter" class="catalog-filter" role="search">
            <label class="sr-only" for="alloy-search">Search alloys</label>
            <input id="alloy-search" name="search" type="search" placeholder="Search by alloy name" autocomplete="off" />
            <label class="sr-only" for="alloy-color">Filter by color</label>
            <select id="alloy-color" name="color"><option value="">All colors</option></select>
            <button class="catalog-filter__reset" type="reset">Clear</button>
          </form>
          <p id="alloys-count" class="catalog-toolbar__count" aria-live="polite"></p>
        </div>
        <div id="alloys-results" class="alloy-grid" aria-live="polite"><p class="placeholder">Loading alloys…</p></div>
      </section>
    </main>
  `;
}

export async function bindAlloysView() {
  const results = document.querySelector("#alloys-results");
  const filter = document.querySelector("#alloys-filter");
  const search = document.querySelector("#alloy-search");
  const color = document.querySelector("#alloy-color");
  const count = document.querySelector("#alloys-count");

  if (!results || !filter || !search || !color || !count) return;

  try {
    const alloys = await getAlloys();
    const sortedAlloys = [...alloys].sort((a, b) => a.name.localeCompare(b.name));
    populateColorOptions(sortedAlloys, color);

    const applyFilters = () => {
      const searchTerm = search.value.trim().toLowerCase();
      const selectedColor = color.value.toLowerCase();
      const filtered = sortedAlloys.filter((alloy) => {
        const searchText = `${alloy.name} ${alloy.description ?? ""}`.toLowerCase();
        return (!searchTerm || searchText.includes(searchTerm))
          && (!selectedColor || alloy.color?.toLowerCase() === selectedColor);
      });
      renderAlloys(results, filtered);
      count.textContent = `${filtered.length} ${filtered.length === 1 ? "alloy" : "alloys"}`;
    };

    search.addEventListener("input", applyFilters);
    color.addEventListener("change", applyFilters);
    filter.addEventListener("reset", () => window.setTimeout(applyFilters, 0));
    applyFilters();
  } catch (error) {
    results.replaceChildren(createStatus(error.message || "We could not load the alloy catalog."));
  }
}

function populateColorOptions(alloys, select) {
  const colors = [...new Set(alloys.map((alloy) => alloy.color).filter(Boolean))].sort((a, b) => a.localeCompare(b));
  colors.forEach((alloyColor) => {
    const option = document.createElement("option");
    option.value = alloyColor;
    option.textContent = formatLabel(alloyColor);
    select.append(option);
  });
}

function renderAlloys(container, alloys) {
  container.replaceChildren(...(alloys.length ? alloys.map(createAlloyCard) : [createStatus("No alloys match those filters.")]));
}

function createAlloyCard(alloy) {
  const card = document.createElement("a");
  card.className = "alloy-card";
  card.href = `#/alloys/${alloy.alloy_id}`;

  const image = document.createElement("img");
  image.className = "alloy-card__image";
  image.src = `${alloyImageDirectory}/${slugify(alloy.name)}.png`;
  image.alt = `${alloy.name} polished alloy bar on slate`;
  image.loading = "lazy";
  image.addEventListener("error", () => {
    image.src = fallbackAlloyImage;
    image.alt = "Polished alloy bar on slate";
  }, { once: true });

  const id = document.createElement("span");
  id.className = "alloy-card__id";
  id.textContent = `Alloy ${alloy.alloy_id}`;

  const name = document.createElement("h2");
  name.textContent = alloy.name;

  const color = document.createElement("p");
  color.className = "alloy-card__color";
  color.textContent = formatLabel(alloy.color) || "Color not specified";

  const description = document.createElement("p");
  description.className = "alloy-card__description";
  description.textContent = alloy.description || "A metal blend in the Metals Atlas collection.";

  const body = document.createElement("div");
  body.className = "alloy-card__body";
  body.append(id, name, color, description);
  card.append(image, body);
  return card;
}

function createStatus(message) {
  const status = document.createElement("p");
  status.className = "catalog-status";
  status.textContent = message;
  return status;
}

function formatLabel(value) {
  return value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase()) : "";
}

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}
