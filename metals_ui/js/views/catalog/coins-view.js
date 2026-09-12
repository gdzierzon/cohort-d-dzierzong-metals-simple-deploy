import { getMintProducts } from "../../api/coins-api.js";
import { METAL_ORDER, PRODUCT_TYPES } from "../../constants/mint-product-metadata.js";
import { loadPreferences, restoreCodes, savePreferences } from "../../preferences.js";

const coinImageDirectory = "./assets/images/coins";
const fallbackCoinImage = `${coinImageDirectory}/american-gold-eagle-1-oz.png`;
const PREFERENCES_NAME = "coins-view";

// The route stays #/coins, but the catalog is no longer only coins: bars, rounds,
// goldbacks, medals and tokens live in the same table now.
const SORTERS = {
  name: (a, b) => a.name.localeCompare(b.name),
  metal: (a, b) => a.primary_metal.localeCompare(b.primary_metal) || a.name.localeCompare(b.name),
  // Nulls last in both directions - an undated piece at the top of the list just
  // looks like a bug.
  year: (a, b) => nullsLast(a.year_introduced, b.year_introduced) || a.name.localeCompare(b.name),
  weight: (a, b) => nullsLast(numberOf(a.gross_weight_g), numberOf(b.gross_weight_g)),
};

function numberOf(value) {
  return value == null ? null : Number(value);
}

function nullsLast(left, right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left - right;
}

export function coinsView() {
  return `
    <main id="app-content" class="page catalog-page">
      <section class="catalog-intro" aria-labelledby="coins-title">
        <div>
          <p class="catalog-intro__eyebrow">The collection</p>
          <h1 id="coins-title">Coins &amp; Bullion</h1>
          <p>Coins, rounds, bars and goldbacks - and the alloys that give them weight, color, and character.</p>
        </div>
        <img class="catalog-intro__image" src="./assets/images/coins-collection.png" alt="A collection of proof coins" />
      </section>

      <section class="catalog-section" aria-label="Mint product catalog">
        <div class="catalog-toolbar catalog-toolbar--sticky">
          <form id="coins-filter" class="catalog-filter" role="search">
            <label class="sr-only" for="coin-search">Search</label>
            <input id="coin-search" name="search" type="search" placeholder="Search by name, issuer, or mint" autocomplete="off" />

            <label class="sr-only" for="coin-issuer">Filter by issuer</label>
            <select id="coin-issuer" name="issuer"><option value="">All issuers</option></select>

            <label class="sr-only" for="coin-sort">Sort by</label>
            <select id="coin-sort" name="sort">
              <option value="name">Sort by name</option>
              <option value="metal">Sort by metal</option>
              <option value="year">Sort by year</option>
              <option value="weight">Sort by weight</option>
            </select>

            <button id="coin-direction" class="catalog-filter__toggle" type="button" aria-pressed="false" title="Reverse the sort order">
              A → Z
            </button>

            <span class="catalog-filter__views" role="group" aria-label="Result layout">
              <button id="coin-view-cards" class="catalog-filter__toggle" type="button" aria-pressed="true">Cards</button>
              <button id="coin-view-table" class="catalog-filter__toggle" type="button" aria-pressed="false">Table</button>
            </span>

            <button class="catalog-filter__reset" type="reset">Clear</button>
          </form>
          <p id="coins-count" class="catalog-toolbar__count" aria-live="polite"></p>
        </div>

        <fieldset id="coin-metals" class="category-filter">
          <legend>Metal</legend>
          <div class="category-filter__group" id="coin-metals-group">
            <button class="category-filter__group-toggle" type="button" data-group="all">All metals</button>
          </div>
        </fieldset>

        <fieldset id="coin-types" class="category-filter">
          <legend>Form</legend>
          <div class="category-filter__group">
            <button class="category-filter__group-toggle" type="button" data-group="all">All forms</button>
            ${PRODUCT_TYPES.map(
              (type) => `
              <label class="category-filter__option">
                <input type="checkbox" name="type" value="${type}" checked />
                <span class="use-chip">${formatLabel(type)}</span>
              </label>`,
            ).join("")}
          </div>
        </fieldset>

        <div id="coins-results" class="coin-grid" aria-live="polite"><p class="placeholder">Loading catalog…</p></div>
      </section>
    </main>`;
}

export async function bindCoinsView() {
  const results = document.querySelector("#coins-results");
  const filter = document.querySelector("#coins-filter");
  const search = document.querySelector("#coin-search");
  const issuer = document.querySelector("#coin-issuer");
  const sort = document.querySelector("#coin-sort");
  const direction = document.querySelector("#coin-direction");
  const metalFilter = document.querySelector("#coin-metals");
  const typeFilter = document.querySelector("#coin-types");
  const cardsButton = document.querySelector("#coin-view-cards");
  const tableButton = document.querySelector("#coin-view-table");
  const count = document.querySelector("#coins-count");

  if (!results || !filter || !search || !issuer || !sort || !direction || !metalFilter || !typeFilter || !count) {
    return;
  }

  let descending = false;
  let layout = "cards";

  try {
    const products = await getMintProducts();

    // primary_metal is derived from each piece's alloy, so the filter is built
    // from what is actually present rather than from a fixed list - no checkbox
    // that can only ever return nothing.
    const availableMetals = METAL_ORDER.filter((metal) =>
      products.some((product) => product.primary_metal === metal),
    );
    renderMetalOptions(document.querySelector("#coin-metals-group"), availableMetals);
    populateIssuerOptions(products, issuer);

    const checkedValues = (container, name) =>
      new Set([...container.querySelectorAll(`input[name="${name}"]:checked`)].map((i) => i.value));

    const persist = () =>
      savePreferences(PREFERENCES_NAME, {
        search: search.value,
        issuer: issuer.value,
        sort: sort.value,
        descending,
        layout,
        metals: [...checkedValues(metalFilter, "metal")],
        types: [...checkedValues(typeFilter, "type")],
      });

    const applyFilters = () => {
      const term = search.value.trim().toLowerCase();
      const selectedIssuer = issuer.value;
      const allowedMetals = checkedValues(metalFilter, "metal");
      const allowedTypes = checkedValues(typeFilter, "type");

      const filtered = products.filter((product) => {
        const text = `${product.name} ${product.issuer ?? ""} ${product.mint ?? ""}`.toLowerCase();
        return (
          (!term || text.includes(term)) &&
          (!selectedIssuer || product.issuer === selectedIssuer) &&
          allowedMetals.has(product.primary_metal) &&
          allowedTypes.has(product.product_type)
        );
      });

      const compare = SORTERS[sort.value] ?? SORTERS.name;
      filtered.sort((a, b) => (descending ? compare(b, a) : compare(a, b)));

      render(results, filtered, layout);
      count.replaceChildren(
        ...describeCount(filtered.length, products.length, allowedMetals, availableMetals, allowedTypes),
      );
      persist();
    };

    restorePreferences({ search, issuer, sort, metalFilter, typeFilter }, availableMetals, (restored) => {
      descending = restored.descending;
      layout = restored.layout;
    });
    setDirectionLabel(direction, descending);
    setLayoutButtons(cardsButton, tableButton, layout);

    filter.addEventListener("submit", (event) => event.preventDefault());
    search.addEventListener("input", applyFilters);
    issuer.addEventListener("change", applyFilters);
    sort.addEventListener("change", applyFilters);
    metalFilter.addEventListener("change", applyFilters);
    typeFilter.addEventListener("change", applyFilters);

    direction.addEventListener("click", () => {
      descending = !descending;
      setDirectionLabel(direction, descending);
      applyFilters();
    });

    const groupHandler = (container, name) => (event) => {
      if (!event.target.closest(".category-filter__group-toggle")) return;
      const inputs = [...container.querySelectorAll(`input[name="${name}"]`)];
      const turningOn = !inputs.every((input) => input.checked);
      inputs.forEach((input) => {
        input.checked = turningOn;
      });
      applyFilters();
    };
    metalFilter.addEventListener("click", groupHandler(metalFilter, "metal"));
    typeFilter.addEventListener("click", groupHandler(typeFilter, "type"));

    const setLayout = (next) => {
      layout = next;
      setLayoutButtons(cardsButton, tableButton, next);
      applyFilters();
    };
    cardsButton?.addEventListener("click", () => setLayout("cards"));
    tableButton?.addEventListener("click", () => setLayout("table"));

    const checkEverything = () => {
      [metalFilter, typeFilter].forEach((container) => {
        container.querySelectorAll("input[type='checkbox']").forEach((input) => {
          input.checked = true;
        });
      });
    };

    count.addEventListener("click", (event) => {
      if (!event.target.closest("#coins-show-all")) return;
      checkEverything();
      applyFilters();
    });

    filter.addEventListener("reset", () =>
      window.setTimeout(() => {
        // Both fieldsets sit outside the form, so a native reset never reaches
        // their checkboxes.
        checkEverything();
        descending = false;
        layout = "cards";
        setDirectionLabel(direction, false);
        setLayoutButtons(cardsButton, tableButton, "cards");
        applyFilters();
      }, 0),
    );

    applyFilters();
  } catch (error) {
    results.replaceChildren(createStatus(error.message || "We could not load the catalog."));
  }
}

function renderMetalOptions(group, metals) {
  if (!group) return;
  metals.forEach((metal) => {
    const label = document.createElement("label");
    label.className = "category-filter__option";
    const input = document.createElement("input");
    input.type = "checkbox";
    input.name = "metal";
    input.value = metal;
    input.checked = true;
    const chip = document.createElement("span");
    chip.className = "metal-chip";
    chip.dataset.metal = metal;
    chip.textContent = formatLabel(metal);
    label.append(input, chip);
    group.append(label);
  });
}

function populateIssuerOptions(products, select) {
  [...new Set(products.map((product) => product.issuer).filter(Boolean))]
    .sort((a, b) => a.localeCompare(b))
    .forEach((value) => {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = value;
      select.append(option);
    });
}

function restorePreferences({ search, issuer, sort, metalFilter, typeFilter }, availableMetals, applyToggles) {
  const saved = loadPreferences(PREFERENCES_NAME);

  if (typeof saved.search === "string") search.value = saved.search;
  if (typeof saved.issuer === "string" && [...issuer.options].some((o) => o.value === saved.issuer)) {
    issuer.value = saved.issuer;
  }
  if (typeof saved.sort === "string" && saved.sort in SORTERS) sort.value = saved.sort;

  applyToggles({
    descending: saved.descending === true,
    layout: saved.layout === "table" ? "table" : "cards",
  });

  applyCodes(metalFilter, "metal", restoreCodes(saved.metals, availableMetals));
  applyCodes(typeFilter, "type", restoreCodes(saved.types, PRODUCT_TYPES));
}

function applyCodes(container, name, codes) {
  if (codes === null) return;
  const wanted = new Set(codes);
  container.querySelectorAll(`input[name="${name}"]`).forEach((input) => {
    input.checked = wanted.has(input.value);
  });
}

function setDirectionLabel(button, descending) {
  button.setAttribute("aria-pressed", String(descending));
  button.textContent = descending ? "Z → A" : "A → Z";
}

function setLayoutButtons(cardsButton, tableButton, layout) {
  cardsButton?.setAttribute("aria-pressed", String(layout === "cards"));
  tableButton?.setAttribute("aria-pressed", String(layout === "table"));
}

function describeCount(shown, total, allowedMetals, availableMetals, allowedTypes) {
  const summary = document.createElement("span");
  summary.textContent = `Showing ${shown} of ${total} piece${total === 1 ? "" : "s"}`;

  const hiddenMetals = availableMetals.length - allowedMetals.size;
  const hiddenTypes = PRODUCT_TYPES.length - allowedTypes.size;
  if (!hiddenMetals && !hiddenTypes) return [summary];

  const parts = [];
  if (hiddenMetals) parts.push(`${hiddenMetals} of ${availableMetals.length} metals`);
  if (hiddenTypes) parts.push(`${hiddenTypes} of ${PRODUCT_TYPES.length} forms`);

  const note = document.createElement("span");
  note.className = "catalog-toolbar__note";
  note.textContent = ` · ${parts.join(" and ")} hidden`;

  const showAll = document.createElement("button");
  showAll.id = "coins-show-all";
  showAll.className = "catalog-filter__reset";
  showAll.type = "button";
  showAll.textContent = "Show everything";

  return [summary, note, showAll];
}

function render(container, products, layout) {
  if (!products.length) {
    container.className = "coin-grid";
    container.replaceChildren(createStatus("Nothing matches those filters."));
    return;
  }

  if (layout === "table") {
    container.className = "element-table-wrap";
    container.replaceChildren(createProductTable(products));
    return;
  }

  container.className = "coin-grid";
  container.replaceChildren(...products.map(createProductCard));
}

function createProductTable(products) {
  const table = document.createElement("table");
  table.className = "element-table";
  table.innerHTML = `
    <thead>
      <tr>
        <th scope="col">Name</th><th scope="col">Form</th><th scope="col">Metal</th>
        <th scope="col">Issuer</th><th scope="col">Year</th><th scope="col">Weight</th>
        <th scope="col">Fine metal</th><th scope="col">Face value</th>
      </tr>
    </thead>
    <tbody></tbody>`;

  const body = table.querySelector("tbody");
  products.forEach((product) => {
    const row = document.createElement("tr");

    const nameCell = document.createElement("th");
    nameCell.scope = "row";
    nameCell.className = "element-table__name";
    const link = document.createElement("a");
    link.href = `#/coins/${product.mint_product_id}`;
    link.textContent = product.name;
    nameCell.append(link);

    const metalChip = document.createElement("span");
    metalChip.className = "metal-chip";
    metalChip.dataset.metal = product.primary_metal ?? "";
    metalChip.textContent = formatLabel(product.primary_metal);
    const metalCell = document.createElement("td");
    metalCell.append(metalChip);

    row.append(
      nameCell,
      textCell(formatLabel(product.product_type)),
      metalCell,
      textCell(product.issuer || "—"),
      textCell(product.year_introduced == null ? "—" : formatYear(product.year_introduced)),
      textCell(formatGrams(product.gross_weight_g)),
      textCell(formatGrams(product.fine_metal_weight_g)),
      textCell(formatFaceValue(product)),
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

function createProductCard(product) {
  const card = document.createElement("a");
  card.className = "coin-card";
  card.href = `#/coins/${product.mint_product_id}`;
  card.innerHTML = `<img><div class="coin-card__body"><p class="coin-card__chips"></p><h2></h2><p class="coin-card__mint"></p><dl class="coin-card__facts"><dt>Introduced</dt><dd></dd><dt>Weight</dt><dd></dd><dt>Fine metal</dt><dd></dd><dt>Alloy</dt><dd></dd><dt>Face value</dt><dd></dd></dl></div>`;

  const image = card.querySelector("img");
  image.src = `${coinImageDirectory}/${slugify(product.name)}.png`;
  image.alt = `${product.name} obverse and reverse`;
  image.loading = "lazy";
  image.addEventListener(
    "error",
    () => {
      image.src = fallbackCoinImage;
      image.alt = "Proof coin obverse and reverse";
    },
    { once: true },
  );

  const chips = card.querySelector(".coin-card__chips");
  const metalChip = document.createElement("span");
  metalChip.className = "metal-chip";
  metalChip.dataset.metal = product.primary_metal ?? "";
  metalChip.textContent = formatLabel(product.primary_metal);
  const typeChip = document.createElement("span");
  typeChip.className = "use-chip";
  typeChip.textContent = formatLabel(product.product_type);
  chips.append(metalChip, typeChip);

  // Layered pieces say so. A clad quarter is not the same object as a solid one.
  if ((product.components ?? []).length) {
    const layers = document.createElement("span");
    layers.className = "use-chip";
    layers.textContent = describeConstruction(product.components);
    chips.append(layers);
  }

  card.querySelector("h2").textContent = product.name;
  card.querySelector(".coin-card__mint").textContent =
    [product.issuer, product.mint].filter(Boolean).join(" · ") || "Mint not specified";

  const facts = card.querySelectorAll("dd");
  facts[0].textContent = product.year_introduced == null ? "—" : formatYear(product.year_introduced);
  facts[1].textContent = formatGrams(product.gross_weight_g);
  facts[2].textContent = formatGrams(product.fine_metal_weight_g);
  facts[3].textContent = product.alloy_name || "Unknown alloy";
  facts[4].textContent = formatFaceValue(product);
  return card;
}

function describeConstruction(components) {
  const roles = new Set(components.map((component) => component.component_role));
  if (roles.has("RING") || roles.has("CENTER")) return "Bimetallic";
  if (roles.has("CLADDING")) return "Clad";
  if (roles.has("PLATING")) return "Plated";
  return "Layered";
}

function formatFaceValue(product) {
  if (!product.is_coin) return "Not legal tender";
  // A Krugerrand is legal tender with no denomination struck on it.
  if (product.face_value == null) return `No denomination (${product.face_value_currency_code})`;
  return `${formatNumber(product.face_value)} ${product.face_value_currency_code}`;
}

function formatGrams(value) {
  return value == null ? "—" : `${formatNumber(value)} g`;
}

function formatYear(year) {
  return year < 0 ? `${Math.abs(year)} BC` : String(year);
}

function createStatus(message) {
  const status = document.createElement("p");
  status.className = "catalog-status";
  status.textContent = message;
  return status;
}

function formatNumber(value) {
  return new Intl.NumberFormat("en-US", { maximumFractionDigits: 4 }).format(Number(value));
}

function formatLabel(value) {
  return value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (l) => l.toUpperCase()) : "";
}

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}
