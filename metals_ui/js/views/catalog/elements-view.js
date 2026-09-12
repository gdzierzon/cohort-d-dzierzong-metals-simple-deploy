import { getElements } from "../../api/elements-api.js";
import { loadPreferences, restoreCodes, savePreferences } from "../../preferences.js";

const PREFERENCES_NAME = "elements-view";
const numberFormatter = new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 });
// Gas densities are far below two decimal places - hydrogen is 0.000090 g/cm³,
// which the formatter above rounds to a flat "0". Switch to significant digits
// once a value is that small.
const smallNumberFormatter = new Intl.NumberFormat("en-US", { maximumSignificantDigits: 2 });
const elementImageDirectory = "./assets/images/elements";
const fallbackElementImage = "./assets/images/no-image.png";

// The ten categories the API returns, grouped the way the periodic table groups
// them. Metals are on by default because this catalog is about metals and the
// alloys made from them. Metalloids are strictly not metals so they start off,
// even though a few of them (silicon, arsenic) do turn up in real alloys.
const CATEGORY_GROUPS = [
  {
    id: "metals",
    label: "Metals",
    defaultOn: true,
    categories: [
      "ALKALI_METAL",
      "ALKALINE_EARTH_METAL",
      "TRANSITION_METAL",
      "POST_TRANSITION_METAL",
      "LANTHANIDE",
      "ACTINIDE",
    ],
  },
  { id: "metalloids", label: "Metalloids", defaultOn: false, categories: ["METALLOID"] },
  { id: "nonmetals", label: "Non-metals", defaultOn: false, categories: ["NONMETAL", "NOBLE_GAS", "HALOGEN"] },
];

const ALL_CATEGORIES = CATEGORY_GROUPS.flatMap((group) => group.categories);

// What "Clear" goes back to. The fieldset lives outside the <form>, so a native
// form reset never reaches these checkboxes - they are restored by hand.
const DEFAULT_CATEGORIES = new Set(
  CATEGORY_GROUPS.filter((group) => group.defaultOn).flatMap((group) => group.categories),
);

// Symbol first: it is how the periodic table is read, and it keeps the default
// order stable and short. Only these three are sortable - the remaining columns
// arrive from the API as strings, so sorting them would need coercion.
const SORTERS = {
  symbol: (a, b) => a.symbol.localeCompare(b.symbol),
  name: (a, b) => a.name.localeCompare(b.name),
  atomic_number: (a, b) => a.atomic_number - b.atomic_number,
};

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
        <div class="catalog-toolbar catalog-toolbar--sticky">
          <form id="elements-filter" class="catalog-filter" role="search">
            <label class="sr-only" for="element-search">Search elements</label>
            <input id="element-search" name="search" type="search" placeholder="Search by name or symbol" autocomplete="off" />

            <label class="sr-only" for="element-color">Filter by color</label>
            <select id="element-color" name="color"><option value="">All colors</option></select>

            <label class="sr-only" for="element-sort">Sort by</label>
            <select id="element-sort" name="sort">
              <option value="symbol">Sort by symbol</option>
              <option value="name">Sort by name</option>
              <option value="atomic_number">Sort by atomic number</option>
            </select>

            <button id="element-direction" class="catalog-filter__toggle" type="button" aria-pressed="false" title="Reverse the sort order">
              A → Z
            </button>

            <span class="catalog-filter__views" role="group" aria-label="Result layout">
              <button id="element-view-cards" class="catalog-filter__toggle" type="button" aria-pressed="true">Cards</button>
              <button id="element-view-table" class="catalog-filter__toggle" type="button" aria-pressed="false">Table</button>
            </span>

            <button class="catalog-filter__reset" type="reset">Clear</button>
          </form>
          <p id="elements-count" class="catalog-toolbar__count" aria-live="polite"></p>
        </div>

        <fieldset id="element-categories" class="category-filter">
          <legend>Element types</legend>
          ${CATEGORY_GROUPS.map(
            (group) => `
            <div class="category-filter__group">
              <button class="category-filter__group-toggle" type="button" data-group="${group.id}">${group.label}</button>
              ${group.categories
                .map(
                  (category) => `
                <label class="category-filter__option">
                  <input type="checkbox" name="category" value="${category}"${group.defaultOn ? " checked" : ""} />
                  <span class="category-chip" data-category="${category}">${formatLabel(category)}</span>
                </label>`,
                )
                .join("")}
            </div>`,
          ).join("")}
        </fieldset>

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
  const sort = document.querySelector("#element-sort");
  const direction = document.querySelector("#element-direction");
  const categories = document.querySelector("#element-categories");
  const cardsButton = document.querySelector("#element-view-cards");
  const tableButton = document.querySelector("#element-view-table");
  const count = document.querySelector("#elements-count");

  if (!results || !filter || !search || !color || !sort || !direction || !categories || !count) return;

  let descending = false;
  let layout = "cards";

  try {
    const elements = await getElements();
    populateColorOptions(elements, color);

    const selectedCategories = () =>
      new Set(
        [...categories.querySelectorAll('input[name="category"]:checked')].map((input) => input.value),
      );

    const persist = () => {
      savePreferences(PREFERENCES_NAME, {
        search: search.value,
        color: color.value,
        sort: sort.value,
        descending,
        layout,
        categories: [...selectedCategories()],
      });
    };

    const applyFilters = () => {
      const searchTerm = search.value.trim().toLowerCase();
      const selectedColor = color.value.toLowerCase();
      const allowed = selectedCategories();

      const filtered = elements.filter((element) => {
        const matchesSearch =
          !searchTerm ||
          element.name.toLowerCase().includes(searchTerm) ||
          element.symbol.toLowerCase().includes(searchTerm);
        const matchesColor = !selectedColor || element.color?.toLowerCase() === selectedColor;
        return matchesSearch && matchesColor && allowed.has(element.category);
      });

      const compare = SORTERS[sort.value] ?? SORTERS.symbol;
      filtered.sort((a, b) => (descending ? compare(b, a) : compare(a, b)));

      render(results, filtered, layout);
      count.replaceChildren(...describeCount(filtered.length, elements.length, allowed));
      persist();
    };

    restorePreferences({ search, color, sort, categories }, (restored) => {
      descending = restored.descending;
      layout = restored.layout;
    });
    setDirectionLabel(direction, descending);
    setLayoutButtons(cardsButton, tableButton, layout);

    // Filtering is live, so there is nothing to submit - and a submit would
    // reload the page out from under the hash router.
    filter.addEventListener("submit", (event) => event.preventDefault());

    search.addEventListener("input", applyFilters);
    color.addEventListener("change", applyFilters);
    sort.addEventListener("change", applyFilters);
    categories.addEventListener("change", applyFilters);

    direction.addEventListener("click", () => {
      descending = !descending;
      setDirectionLabel(direction, descending);
      applyFilters();
    });

    categories.addEventListener("click", (event) => {
      const toggle = event.target.closest(".category-filter__group-toggle");
      if (!toggle) return;
      const group = CATEGORY_GROUPS.find((candidate) => candidate.id === toggle.dataset.group);
      const inputs = group.categories.map((category) =>
        categories.querySelector(`input[value="${category}"]`),
      );
      // Turn the whole group on unless it is already fully on, in which case
      // this is a "clear the group" click.
      const turningOn = !inputs.every((input) => input.checked);
      inputs.forEach((input) => {
        input.checked = turningOn;
      });
      applyFilters();
    });

    const setLayout = (next) => {
      layout = next;
      setLayoutButtons(cardsButton, tableButton, next);
      applyFilters();
    };
    cardsButton?.addEventListener("click", () => setLayout("cards"));
    tableButton?.addEventListener("click", () => setLayout("table"));

    count.addEventListener("click", (event) => {
      if (!event.target.closest("#elements-show-all")) return;
      categories.querySelectorAll('input[name="category"]').forEach((input) => {
        input.checked = true;
      });
      applyFilters();
    });

    filter.addEventListener("reset", () =>
      window.setTimeout(() => {
        // The category fieldset sits outside the form, so a reset does not
        // touch it. Put it back to the metals-only default by hand.
        categories.querySelectorAll('input[name="category"]').forEach((input) => {
          input.checked = DEFAULT_CATEGORIES.has(input.value);
        });
        descending = false;
        layout = "cards";
        setDirectionLabel(direction, false);
        setLayoutButtons(cardsButton, tableButton, "cards");
        applyFilters();
      }, 0),
    );

    applyFilters();
  } catch (error) {
    results.replaceChildren(createStatus(error.message || "We could not load the element catalog."));
  }
}

function restorePreferences({ search, color, sort, categories }, applyToggles) {
  const saved = loadPreferences(PREFERENCES_NAME);

  if (typeof saved.search === "string") search.value = saved.search;
  // The colour list is built from the data, so a remembered colour that is no
  // longer offered has to be ignored or the page would filter to nothing.
  if (typeof saved.color === "string" && [...color.options].some((option) => option.value === saved.color)) {
    color.value = saved.color;
  }
  if (typeof saved.sort === "string" && saved.sort in SORTERS) sort.value = saved.sort;

  applyToggles({
    descending: saved.descending === true,
    layout: saved.layout === "table" ? "table" : "cards",
  });

  const restored = restoreCodes(saved.categories, ALL_CATEGORIES);
  if (restored !== null) {
    const wanted = new Set(restored);
    categories.querySelectorAll('input[name="category"]').forEach((input) => {
      input.checked = wanted.has(input.value);
    });
  }
}

function setDirectionLabel(button, descending) {
  button.setAttribute("aria-pressed", String(descending));
  button.textContent = descending ? "Z → A" : "A → Z";
}

function setLayoutButtons(cardsButton, tableButton, layout) {
  cardsButton?.setAttribute("aria-pressed", String(layout === "cards"));
  tableButton?.setAttribute("aria-pressed", String(layout === "table"));
}

// The metals-only default hides 27 of 118 elements on first load. Saying so
// plainly, with a way out, keeps that from looking like missing data.
function describeCount(shown, total, allowed) {
  const summary = document.createElement("span");
  summary.textContent = `Showing ${shown} of ${total} element${total === 1 ? "" : "s"}`;

  const hidden = ALL_CATEGORIES.length - allowed.size;
  if (!hidden) return [summary];

  const note = document.createElement("span");
  note.className = "catalog-toolbar__note";
  note.textContent = ` · ${hidden} of ${ALL_CATEGORIES.length} types hidden`;

  const showAll = document.createElement("button");
  showAll.id = "elements-show-all";
  showAll.className = "catalog-filter__reset";
  showAll.type = "button";
  showAll.textContent = "Show all types";

  return [summary, note, showAll];
}

function render(container, elements, layout) {
  if (!elements.length) {
    container.className = "element-grid";
    container.replaceChildren(createStatus("No elements match those filters."));
    return;
  }

  if (layout === "table") {
    container.className = "element-table-wrap";
    container.replaceChildren(createElementTable(elements));
    return;
  }

  container.className = "element-grid";
  container.replaceChildren(...elements.map(createElementCard));
}

function populateColorOptions(elements, select) {
  const colors = [...new Set(elements.map((element) => element.color).filter(Boolean))].sort((a, b) =>
    a.localeCompare(b),
  );
  colors.forEach((elementColor) => {
    const option = document.createElement("option");
    option.value = elementColor;
    option.textContent = formatLabel(elementColor);
    select.append(option);
  });
}

function createElementTable(elements) {
  const table = document.createElement("table");
  table.className = "element-table";
  table.innerHTML = `
    <thead>
      <tr>
        <th scope="col">Symbol</th><th scope="col">Name</th><th scope="col">Number</th>
        <th scope="col">Type</th><th scope="col">State</th><th scope="col">Density</th>
        <th scope="col">Melting</th><th scope="col">Color</th>
      </tr>
    </thead>
    <tbody></tbody>
  `;

  const body = table.querySelector("tbody");
  elements.forEach((element) => {
    const row = document.createElement("tr");

    const symbolCell = document.createElement("th");
    symbolCell.scope = "row";
    const link = document.createElement("a");
    link.href = `#/elements/${element.atomic_number}`;
    link.textContent = element.symbol;
    symbolCell.append(link);
    row.append(symbolCell);

    const chip = document.createElement("span");
    chip.className = "category-chip";
    chip.dataset.category = element.category ?? "";
    chip.textContent = formatLabel(element.category) || "Element";

    row.append(
      textCell(element.name),
      textCell(String(element.atomic_number)),
      nodeCell(chip),
      textCell(formatLabel(element.state_at_room_temp) || "—"),
      textCell(formatDensity(element.density)),
      textCell(formatTemperature(element.melting_point_f)),
      textCell(formatLabel(element.color) || "—"),
    );
    body.append(row);
  });

  return table;
}

function textCell(value) {
  const cell = document.createElement("td");
  cell.textContent = value;
  return cell;
}

function nodeCell(node) {
  const cell = document.createElement("td");
  cell.append(node);
  return cell;
}

function createElementCard(element) {
  const card = document.createElement("a");
  card.className = "element-card";
  card.href = `#/elements/${element.atomic_number}`;
  card.innerHTML = `
    <div class="element-card__heading"><span class="element-card__atomic-number"></span><span class="element-card__symbol"></span></div>
    <h2></h2>
    <p class="element-card__category"><span class="category-chip"></span></p>
    <dl class="element-card__facts"><dt>State</dt><dd></dd><dt>Density</dt><dd></dd><dt>Melting</dt><dd></dd><dt>Color</dt><dd></dd></dl>
  `;
  const image = document.createElement("img");
  image.className = "element-card__image";
  image.src = `${elementImageDirectory}/${element.symbol}.png`;
  image.alt =
    element.symbol === "Co"
      ? "Silvery cobalt metal beside a rich blue crystal on slate"
      : `${element.name} specimen on slate`;
  image.loading = "lazy";
  image.addEventListener(
    "error",
    () => {
      image.src = fallbackElementImage;
      image.alt = "No image available";
    },
    { once: true },
  );
  card.prepend(image);

  card.querySelector(".element-card__atomic-number").textContent = String(element.atomic_number);
  card.querySelector(".element-card__symbol").textContent = element.symbol;
  card.querySelector("h2").textContent = element.name;

  const chip = card.querySelector(".category-chip");
  chip.dataset.category = element.category ?? "";
  chip.textContent = formatLabel(element.category) || "Element";

  const facts = card.querySelectorAll(".element-card__facts dd");
  facts[0].textContent = formatLabel(element.state_at_room_temp) || "—";
  facts[1].textContent = formatDensity(element.density);
  facts[2].textContent = formatTemperature(element.melting_point_f);
  facts[3].textContent = formatLabel(element.color) || "—";

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

// The API sends numeric columns as strings, so parse before deciding a format.
function formatDensity(value) {
  if (value == null) return "—";
  const density = Number(value);
  if (Number.isNaN(density)) return "—";
  const formatter = density !== 0 && Math.abs(density) < 0.01 ? smallNumberFormatter : numberFormatter;
  return `${formatter.format(density)} g/cm³`;
}

function formatTemperature(value) {
  return value == null ? "—" : `${numberFormatter.format(Number(value))} °F`;
}

function formatLabel(value) {
  return value
    ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase())
    : "";
}
