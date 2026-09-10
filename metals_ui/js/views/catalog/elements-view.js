import { getElements } from "../../api/elements-api.js";

const numberFormatter = new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 });
const elementImageDirectory = "./assets/images/elements";
const fallbackElementImage = `${elementImageDirectory}/generic.png`;

export function elementsView() {
  return `
    <main id="app-content" class="page catalog-page">
      <section class="catalog-intro" aria-labelledby="elements-title">
        <div>
          <p class="catalog-intro__eyebrow">The collection</p>
          <h1 id="elements-title">Elements</h1>
          <p>Discover the materials that give every alloy its character.</p>
        </div>
        <img class="catalog-intro__image" src="./assets/images/elements-gold-nugget-slate.png" alt="A natural gold nugget on slate" />
      </section>

      <section class="catalog-section" aria-label="Element catalog">
        <div class="catalog-toolbar">
          <form id="elements-filter" class="catalog-filter" role="search">
            <label class="sr-only" for="element-search">Search elements</label>
            <input id="element-search" name="search" type="search" placeholder="Search by name or symbol" autocomplete="off" />
            <label class="sr-only" for="element-color">Filter by color</label>
            <select id="element-color" name="color"><option value="">All colors</option></select>
            <button class="catalog-filter__reset" type="reset">Clear</button>
          </form>
          <p id="elements-count" class="catalog-toolbar__count" aria-live="polite"></p>
        </div>
        <div id="elements-results" class="element-grid" aria-live="polite"><p class="placeholder">Loading elements…</p></div>
      </section>
    </main>
  `;
}

export async function bindElementsView() {
  const results = document.querySelector("#elements-results");
  const filter = document.querySelector("#elements-filter");
  const search = document.querySelector("#element-search");
  const color = document.querySelector("#element-color");
  const count = document.querySelector("#elements-count");

  if (!results || !filter || !search || !color || !count) return;

  try {
    const elements = await getElements();
    const sortedElements = [...elements].sort((a, b) => a.atomic_number - b.atomic_number);
    populateColorOptions(sortedElements, color);

    const applyFilters = () => {
      const searchTerm = search.value.trim().toLowerCase();
      const selectedColor = color.value.toLowerCase();
      const filtered = sortedElements.filter((element) => {
        const matchesSearch = !searchTerm || element.name.toLowerCase().includes(searchTerm) || element.symbol.toLowerCase().includes(searchTerm);
        return matchesSearch && (!selectedColor || element.color?.toLowerCase() === selectedColor);
      });
      renderElements(results, filtered);
      count.textContent = `${filtered.length} ${filtered.length === 1 ? "element" : "elements"}`;
    };

    search.addEventListener("input", applyFilters);
    color.addEventListener("change", applyFilters);
    filter.addEventListener("reset", () => window.setTimeout(applyFilters, 0));
    applyFilters();
  } catch (error) {
    results.replaceChildren(createStatus(error.message || "We could not load the element catalog."));
  }
}

function populateColorOptions(elements, select) {
  const colors = [...new Set(elements.map((element) => element.color).filter(Boolean))].sort((a, b) => a.localeCompare(b));
  colors.forEach((elementColor) => {
    const option = document.createElement("option");
    option.value = elementColor;
    option.textContent = formatLabel(elementColor);
    select.append(option);
  });
}

function renderElements(container, elements) {
  container.replaceChildren(...(elements.length ? elements.map(createElementCard) : [createStatus("No elements match those filters.")]));
}

function createElementCard(element) {
  const card = document.createElement("a");
  card.className = "element-card";
  card.href = `#/elements/${element.atomic_number}`;
  card.innerHTML = `
    <div class="element-card__heading"><span class="element-card__atomic-number"></span><span class="element-card__symbol"></span></div>
    <h2></h2><p class="element-card__category"></p>
    <dl class="element-card__facts"><dt>State</dt><dd></dd><dt>Density</dt><dd></dd><dt>Melting</dt><dd></dd><dt>Color</dt><dd></dd></dl>
  `;
  const image = document.createElement("img");
  image.className = "element-card__image";
  image.src = `${elementImageDirectory}/${element.symbol}.png`;
  image.alt = `${element.name} specimen on slate`;
  image.loading = "lazy";
  image.addEventListener("error", () => {
    image.src = fallbackElementImage;
    image.alt = "Generic atomic element illustration";
  }, { once: true });
  card.prepend(image);
  const values = card.querySelectorAll("span, h2, p, dd");
  values[0].textContent = String(element.atomic_number);
  values[1].textContent = element.symbol;
  values[2].textContent = element.name;
  values[3].textContent = formatLabel(element.category) || "Element";
  values[4].textContent = formatLabel(element.state_at_room_temp) || "—";
  values[5].textContent = element.density == null ? "—" : `${numberFormatter.format(element.density)} g/cm³`;
  values[6].textContent = element.melting_point_f == null ? "—" : `${numberFormatter.format(element.melting_point_f)} °F`;
  values[7].textContent = formatLabel(element.color) || "—";
  if (element.common_uses) {
    const uses = document.createElement("p");
    uses.className = "element-card__uses";
    uses.textContent = element.common_uses;
    card.append(uses);
  }
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
