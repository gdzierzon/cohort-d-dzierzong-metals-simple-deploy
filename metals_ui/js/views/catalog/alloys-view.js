import { getAlloys } from "../../api/alloys-api.js";
import {
  ALLOY_COLOR_FAMILIES,
  ALLOY_COLOR_FAMILY_CODES,
  ALLOY_FAMILIES,
  ALLOY_USES,
  ALLOY_USE_GROUPS,
} from "../../constants/alloy-metadata.js";
import { loadPreferences, restoreCodes, savePreferences } from "../../preferences.js";

const alloyImageDirectory = "./assets/images/alloys";
const fallbackAlloyImage = "./assets/images/no-image.png";
const PREFERENCES_NAME = "alloys-view";

// Where each color family sits in the light-to-warm order the chips use. Sorting
// on the code itself would be alphabetical - BRONZE, GOLD, GRAY, RED, SILVER -
// which scatters the spectrum.
const COLOR_FAMILY_RANK = new Map(
  ALLOY_COLOR_FAMILY_CODES.map((code, index) => [code, index]),
);

const SORTERS = {
  name: (a, b) => a.name.localeCompare(b.name),
  family: (a, b) => a.alloy_family.localeCompare(b.alloy_family) || a.name.localeCompare(b.name),
  color_family: (a, b) =>
    (COLOR_FAMILY_RANK.get(a.color_family) ?? Number.MAX_SAFE_INTEGER) -
      (COLOR_FAMILY_RANK.get(b.color_family) ?? Number.MAX_SAFE_INTEGER) ||
    a.name.localeCompare(b.name),
  alloy_id: (a, b) => a.alloy_id - b.alloy_id,
};

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
        <div class="catalog-toolbar catalog-toolbar--sticky">
          <form id="alloys-filter" class="catalog-filter" role="search">
            <label class="sr-only" for="alloy-search">Search alloys</label>
            <input id="alloy-search" name="search" type="search" placeholder="Search by alloy name" autocomplete="off" />

            <label class="sr-only" for="alloy-color">Filter by color</label>
            <select id="alloy-color" name="color"><option value="">All colors</option></select>

            <label class="sr-only" for="alloy-sort">Sort by</label>
            <select id="alloy-sort" name="sort">
              <option value="name">Sort by name</option>
              <option value="family">Sort by base metal</option>
              <option value="color_family">Sort by color</option>
              <option value="alloy_id">Sort by catalog order</option>
            </select>

            <button id="alloy-direction" class="catalog-filter__toggle" type="button" aria-pressed="false" title="Reverse the sort order">
              A → Z
            </button>

            <span class="catalog-filter__views" role="group" aria-label="Result layout">
              <button id="alloy-view-cards" class="catalog-filter__toggle" type="button" aria-pressed="true">Cards</button>
              <button id="alloy-view-table" class="catalog-filter__toggle" type="button" aria-pressed="false">Table</button>
            </span>

            <button class="catalog-filter__reset" type="reset">Clear</button>
          </form>
          <p id="alloys-count" class="catalog-toolbar__count" aria-live="polite"></p>
        </div>

        <fieldset id="alloy-families" class="category-filter">
          <legend>Base metal</legend>
          <div class="category-filter__group">
            <button class="category-filter__group-toggle" type="button" data-group="all">All metals</button>
            ${ALLOY_FAMILIES.map(
              (family) => `
              <label class="category-filter__option">
                <input type="checkbox" name="family" value="${family}" checked />
                <span class="family-chip" data-family="${family}">${formatLabel(family)}</span>
              </label>`,
            ).join("")}
          </div>
        </fieldset>

        <fieldset id="alloy-color-families" class="category-filter">
          <legend>Color</legend>
          <div class="category-filter__group">
            <button class="category-filter__group-toggle" type="button" data-group="all">All colors</button>
            ${ALLOY_COLOR_FAMILIES.map(
              (family) => `
              <label class="category-filter__option">
                <input type="checkbox" name="color_family" value="${family.code}" checked />
                <span class="color-chip"><span class="color-chip__swatch" style="background:${family.swatch}"></span>${family.label}</span>
              </label>`,
            ).join("")}
          </div>
        </fieldset>

        <fieldset id="alloy-uses" class="category-filter">
          <legend>Used for</legend>
          ${ALLOY_USE_GROUPS.map(
            (group) => `
            <div class="category-filter__group">
              <button class="category-filter__group-toggle" type="button" data-group="${group.id}">${group.label}</button>
              ${group.codes
                .map(
                  (code) => `
                <label class="category-filter__option">
                  <input type="checkbox" name="use" value="${code}" checked />
                  <span class="use-chip">${formatLabel(code)}</span>
                </label>`,
                )
                .join("")}
            </div>`,
          ).join("")}
        </fieldset>

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
  const sort = document.querySelector("#alloy-sort");
  const direction = document.querySelector("#alloy-direction");
  const familyFilter = document.querySelector("#alloy-families");
  const useFilter = document.querySelector("#alloy-uses");
  const colorFamilyFilter = document.querySelector("#alloy-color-families");
  const cardsButton = document.querySelector("#alloy-view-cards");
  const tableButton = document.querySelector("#alloy-view-table");
  const count = document.querySelector("#alloys-count");

  if (!results || !filter || !search || !color || !sort || !direction || !familyFilter || !useFilter || !colorFamilyFilter || !count) {
    return;
  }

  // The three checkbox fieldsets behave identically for reset, "show everything"
  // and restoring defaults, so they are handled as one list throughout.
  const fieldsets = [familyFilter, colorFamilyFilter, useFilter];

  let descending = false;
  let layout = "cards";

  try {
    const alloys = await getAlloys();
    populateColorOptions(alloys, color);

    const checkedValues = (container, name) =>
      new Set([...container.querySelectorAll(`input[name="${name}"]:checked`)].map((input) => input.value));

    const persist = () => {
      savePreferences(PREFERENCES_NAME, {
        search: search.value,
        color: color.value,
        sort: sort.value,
        descending,
        layout,
        families: [...checkedValues(familyFilter, "family")],
        colorFamilies: [...checkedValues(colorFamilyFilter, "color_family")],
        uses: [...checkedValues(useFilter, "use")],
      });
    };

    const applyFilters = () => {
      const searchTerm = search.value.trim().toLowerCase();
      const selectedColor = color.value.toLowerCase();
      const allowedFamilies = checkedValues(familyFilter, "family");
      const allowedUses = checkedValues(useFilter, "use");
      const allowedColorFamilies = checkedValues(colorFamilyFilter, "color_family");

      const filtered = alloys.filter((alloy) => {
        const searchText = `${alloy.name} ${alloy.description ?? ""}`.toLowerCase();
        const matchesSearch = !searchTerm || searchText.includes(searchTerm);
        const matchesColor = !selectedColor || alloy.color?.toLowerCase() === selectedColor;
        // An alloy matches if ANY of its uses is still ticked, the same way the
        // API's ?use= filter behaves. With every use ticked nothing is being
        // filtered, so an alloy that records no uses at all still shows -
        // otherwise a newly created alloy would be invisible until someone
        // thought to give it one.
        const filteringByUse = allowedUses.size !== ALLOY_USES.length;
        const matchesUse = !filteringByUse || (alloy.uses ?? []).some((code) => allowedUses.has(code));
        return (
          matchesSearch &&
          matchesColor &&
          matchesUse &&
          allowedFamilies.has(alloy.alloy_family) &&
          allowedColorFamilies.has(alloy.color_family)
        );
      });

      const compare = SORTERS[sort.value] ?? SORTERS.name;
      filtered.sort((a, b) => (descending ? compare(b, a) : compare(a, b)));

      render(results, filtered, layout);
      count.replaceChildren(
        ...describeCount(filtered.length, alloys.length, allowedFamilies, allowedUses, allowedColorFamilies),
      );
      persist();
    };

    restorePreferences({ search, color, sort, familyFilter, useFilter, colorFamilyFilter }, (restored) => {
      descending = restored.descending;
      layout = restored.layout;
    });
    setDirectionLabel(direction, descending);
    setLayoutButtons(cardsButton, tableButton, layout);

    filter.addEventListener("submit", (event) => event.preventDefault());
    search.addEventListener("input", applyFilters);
    color.addEventListener("change", applyFilters);
    sort.addEventListener("change", applyFilters);
    familyFilter.addEventListener("change", applyFilters);
    useFilter.addEventListener("change", applyFilters);
    colorFamilyFilter.addEventListener("change", applyFilters);

    direction.addEventListener("click", () => {
      descending = !descending;
      setDirectionLabel(direction, descending);
      applyFilters();
    });

    // One handler for both fieldsets: a group name turns its whole set on,
    // unless the set is already fully on, in which case it clears it.
    const handleGroupClick = (container, name, codesFor) => (event) => {
      const toggle = event.target.closest(".category-filter__group-toggle");
      if (!toggle) return;

      const codes = codesFor(toggle.dataset.group);
      const inputs = codes
        .map((code) => container.querySelector(`input[name="${name}"][value="${code}"]`))
        .filter(Boolean);
      const turningOn = !inputs.every((input) => input.checked);
      inputs.forEach((input) => {
        input.checked = turningOn;
      });
      applyFilters();
    };

    familyFilter.addEventListener("click", handleGroupClick(familyFilter, "family", () => ALLOY_FAMILIES));
    colorFamilyFilter.addEventListener(
      "click",
      handleGroupClick(colorFamilyFilter, "color_family", () => ALLOY_COLOR_FAMILY_CODES),
    );
    useFilter.addEventListener(
      "click",
      handleGroupClick(useFilter, "use", (groupId) =>
        ALLOY_USE_GROUPS.find((group) => group.id === groupId)?.codes ?? [],
      ),
    );

    const setLayout = (next) => {
      layout = next;
      setLayoutButtons(cardsButton, tableButton, next);
      applyFilters();
    };
    cardsButton?.addEventListener("click", () => setLayout("cards"));
    tableButton?.addEventListener("click", () => setLayout("table"));

    count.addEventListener("click", (event) => {
      if (!event.target.closest("#alloys-show-all")) return;
      fieldsets.forEach((container) => {
        container.querySelectorAll("input[type='checkbox']").forEach((input) => {
          input.checked = true;
        });
      });
      applyFilters();
    });

    filter.addEventListener("reset", () =>
      window.setTimeout(() => {
        // A form reset only clears the controls inside the form; the three
        // fieldsets sit outside it, so they are restored by hand.
        fieldsets.forEach((container) => {
          container.querySelectorAll("input[type='checkbox']").forEach((input) => {
            input.checked = true;
          });
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
    results.replaceChildren(createStatus(error.message || "We could not load the alloy catalog."));
  }
}

function restorePreferences(
  { search, color, sort, familyFilter, useFilter, colorFamilyFilter },
  applyToggles,
) {
  const saved = loadPreferences(PREFERENCES_NAME);

  if (typeof saved.search === "string") search.value = saved.search;
  // The color list is built from the data, so a remembered color that is no
  // longer offered has to be ignored or the page would filter to nothing.
  if (typeof saved.color === "string" && [...color.options].some((option) => option.value === saved.color)) {
    color.value = saved.color;
  }
  if (typeof saved.sort === "string" && saved.sort in SORTERS) sort.value = saved.sort;

  applyToggles({
    descending: saved.descending === true,
    layout: saved.layout === "table" ? "table" : "cards",
  });

  applyCodes(familyFilter, "family", restoreCodes(saved.families, ALLOY_FAMILIES));
  applyCodes(useFilter, "use", restoreCodes(saved.uses, ALLOY_USES));
  applyCodes(
    colorFamilyFilter,
    "color_family",
    restoreCodes(saved.colorFamilies, ALLOY_COLOR_FAMILY_CODES),
  );
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

function describeCount(shown, total, allowedFamilies, allowedUses, allowedColorFamilies) {
  const summary = document.createElement("span");
  summary.textContent = `Showing ${shown} of ${total} alloy${total === 1 ? "" : "s"}`;

  const hiddenFamilies = ALLOY_FAMILIES.length - allowedFamilies.size;
  const hiddenUses = ALLOY_USES.length - allowedUses.size;
  const hiddenColors = ALLOY_COLOR_FAMILY_CODES.length - allowedColorFamilies.size;
  if (!hiddenFamilies && !hiddenUses && !hiddenColors) return [summary];

  const parts = [];
  if (hiddenFamilies) parts.push(`${hiddenFamilies} of ${ALLOY_FAMILIES.length} metals`);
  if (hiddenColors) parts.push(`${hiddenColors} of ${ALLOY_COLOR_FAMILY_CODES.length} colors`);
  if (hiddenUses) parts.push(`${hiddenUses} of ${ALLOY_USES.length} uses`);

  // Three filters can be narrowed at once now, so "a and b and c" needs to become
  // "a, b and c".
  const listed =
    parts.length > 1
      ? `${parts.slice(0, -1).join(", ")} and ${parts[parts.length - 1]}`
      : parts[0];

  const note = document.createElement("span");
  note.className = "catalog-toolbar__note";
  note.textContent = ` · ${listed} hidden`;

  const showAll = document.createElement("button");
  showAll.id = "alloys-show-all";
  showAll.className = "catalog-filter__reset";
  showAll.type = "button";
  showAll.textContent = "Show everything";

  return [summary, note, showAll];
}

function render(container, alloys, layout) {
  if (!alloys.length) {
    container.className = "alloy-grid";
    container.replaceChildren(createStatus("No alloys match those filters."));
    return;
  }

  if (layout === "table") {
    container.className = "element-table-wrap";
    container.replaceChildren(createAlloyTable(alloys));
    return;
  }

  container.className = "alloy-grid";
  container.replaceChildren(...alloys.map(createAlloyCard));
}

// A dot in the alloy's color family, so sorting by color reads as bands of like
// colors rather than an unexplained reordering. The text beside it stays the
// alloy's own specific color - the swatch groups, the words describe.
function createColorSwatch(colorFamily) {
  const match = ALLOY_COLOR_FAMILIES.find((family) => family.code === colorFamily);
  const swatch = document.createElement("span");
  swatch.className = "color-chip__swatch";
  if (match) {
    swatch.style.background = match.swatch;
    // Not decoration: it is the only place the family name appears on a card.
    swatch.title = `${match.label} family`;
  }
  return swatch;
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

function createAlloyTable(alloys) {
  const table = document.createElement("table");
  table.className = "element-table";
  table.innerHTML = `
    <thead>
      <tr><th scope="col">Alloy</th><th scope="col">Base metal</th><th scope="col">Color</th><th scope="col">Used for</th></tr>
    </thead>
    <tbody></tbody>
  `;

  const body = table.querySelector("tbody");
  alloys.forEach((alloy) => {
    const row = document.createElement("tr");

    const nameCell = document.createElement("th");
    nameCell.scope = "row";
    nameCell.className = "element-table__name";
    const link = document.createElement("a");
    link.href = `#/alloys/${alloy.alloy_id}`;
    link.textContent = alloy.name;
    nameCell.append(link);
    row.append(nameCell);

    const chip = document.createElement("span");
    chip.className = "family-chip";
    chip.dataset.family = alloy.alloy_family ?? "";
    chip.textContent = formatLabel(alloy.alloy_family) || "Alloy";

    const familyCell = document.createElement("td");
    familyCell.append(chip);

    const colorCell = document.createElement("td");
    colorCell.className = "alloy-table__color";
    colorCell.append(
      createColorSwatch(alloy.color_family),
      document.createTextNode(formatLabel(alloy.color) || "—"),
    );

    const useCell = document.createElement("td");
    useCell.className = "element-table__uses";
    useCell.textContent = (alloy.uses ?? []).map(formatLabel).join(", ") || "—";

    row.append(familyCell, colorCell, useCell);
    body.append(row);
  });

  return table;
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
    image.alt = "No image available";
  }, { once: true });

  const family = document.createElement("span");
  family.className = "family-chip";
  family.dataset.family = alloy.alloy_family ?? "";
  family.textContent = formatLabel(alloy.alloy_family) || "Alloy";

  const name = document.createElement("h2");
  name.textContent = alloy.name;

  const color = document.createElement("p");
  color.className = "alloy-card__color";
  color.append(
    createColorSwatch(alloy.color_family),
    document.createTextNode(formatLabel(alloy.color) || "Color not specified"),
  );

  const description = document.createElement("p");
  description.className = "alloy-card__description";
  description.textContent = alloy.description || "A metal blend in the Metals Atlas collection.";

  const body = document.createElement("div");
  body.className = "alloy-card__body";
  body.append(family, name, color, description);

  const uses = alloy.uses ?? [];
  if (uses.length) {
    const useRow = document.createElement("p");
    useRow.className = "alloy-card__uses";
    uses.forEach((code) => {
      const chip = document.createElement("span");
      chip.className = "use-chip";
      chip.textContent = formatLabel(code);
      useRow.append(chip);
    });
    body.append(useRow);
  }

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
