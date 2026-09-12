import { getAlloys } from "../../api/alloys-api.js";
// All nine families start checked: unlike the elements page there is no reason
// to hide any by default - showing the full range is the point of adding them.
// Uses get a dropdown rather than seventeen more checkboxes, because the
// toolbar has to stay readable and "show me the marine alloys" is a
// one-at-a-time question.
import { ALLOY_FAMILIES, ALLOY_USES } from "../../constants/alloy-metadata.js";

const alloyImageDirectory = "./assets/images/alloys";
const fallbackAlloyImage = `${alloyImageDirectory}/aluminum-alloy.png`;

const SORTERS = {
  name: (a, b) => a.name.localeCompare(b.name),
  family: (a, b) => a.alloy_family.localeCompare(b.alloy_family) || a.name.localeCompare(b.name),
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

            <label class="sr-only" for="alloy-use">Filter by use</label>
            <select id="alloy-use" name="use">
              <option value="">All uses</option>
              ${ALLOY_USES.map((code) => `<option value="${code}">${formatLabel(code)}</option>`).join("")}
            </select>

            <label class="sr-only" for="alloy-sort">Sort by</label>
            <select id="alloy-sort" name="sort">
              <option value="name">Sort by name</option>
              <option value="family">Sort by family</option>
              <option value="alloy_id">Sort by catalog order</option>
            </select>

            <button id="alloy-direction" class="catalog-filter__toggle" type="button" aria-pressed="false" title="Reverse the sort order">
              A → Z
            </button>

            <button class="catalog-filter__reset" type="reset">Clear</button>
          </form>
          <p id="alloys-count" class="catalog-toolbar__count" aria-live="polite"></p>
        </div>

        <fieldset id="alloy-families" class="category-filter">
          <legend>Base metal</legend>
          <div class="category-filter__group">
            ${ALLOY_FAMILIES.map(
              (family) => `
              <label class="category-filter__option">
                <input type="checkbox" name="family" value="${family}" checked />
                <span class="family-chip" data-family="${family}">${formatLabel(family)}</span>
              </label>`,
            ).join("")}
          </div>
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
  const use = document.querySelector("#alloy-use");
  const sort = document.querySelector("#alloy-sort");
  const direction = document.querySelector("#alloy-direction");
  const families = document.querySelector("#alloy-families");
  const count = document.querySelector("#alloys-count");

  if (!results || !filter || !search || !color || !use || !sort || !direction || !families || !count) return;

  let descending = false;

  try {
    const alloys = await getAlloys();
    populateColorOptions(alloys, color);

    const selectedFamilies = () =>
      new Set([...families.querySelectorAll('input[name="family"]:checked')].map((input) => input.value));

    const applyFilters = () => {
      const searchTerm = search.value.trim().toLowerCase();
      const selectedColor = color.value.toLowerCase();
      const selectedUse = use.value;
      const allowed = selectedFamilies();

      const filtered = alloys.filter((alloy) => {
        const searchText = `${alloy.name} ${alloy.description ?? ""}`.toLowerCase();
        const matchesSearch = !searchTerm || searchText.includes(searchTerm);
        const matchesColor = !selectedColor || alloy.color?.toLowerCase() === selectedColor;
        const matchesUse = !selectedUse || (alloy.uses ?? []).includes(selectedUse);
        return matchesSearch && matchesColor && matchesUse && allowed.has(alloy.alloy_family);
      });

      const compare = SORTERS[sort.value] ?? SORTERS.name;
      filtered.sort((a, b) => (descending ? compare(b, a) : compare(a, b)));

      results.replaceChildren(
        ...(filtered.length ? filtered.map(createAlloyCard) : [createStatus("No alloys match those filters.")]),
      );
      count.replaceChildren(...describeCount(filtered.length, alloys.length, allowed, families));
    };

    filter.addEventListener("submit", (event) => event.preventDefault());
    search.addEventListener("input", applyFilters);
    color.addEventListener("change", applyFilters);
    use.addEventListener("change", applyFilters);
    sort.addEventListener("change", applyFilters);
    families.addEventListener("change", applyFilters);

    direction.addEventListener("click", () => {
      descending = !descending;
      direction.setAttribute("aria-pressed", String(descending));
      direction.textContent = descending ? "Z → A" : "A → Z";
      applyFilters();
    });

    count.addEventListener("click", (event) => {
      if (!event.target.closest("#alloys-show-all")) return;
      families.querySelectorAll('input[name="family"]').forEach((input) => {
        input.checked = true;
      });
      applyFilters();
    });

    filter.addEventListener("reset", () =>
      window.setTimeout(() => {
        descending = false;
        direction.setAttribute("aria-pressed", "false");
        direction.textContent = "A → Z";
        families.querySelectorAll('input[name="family"]').forEach((input) => {
          input.checked = true;
        });
        applyFilters();
      }, 0),
    );

    applyFilters();
  } catch (error) {
    results.replaceChildren(createStatus(error.message || "We could not load the alloy catalog."));
  }
}

function describeCount(shown, total, allowed) {
  const summary = document.createElement("span");
  summary.textContent = `Showing ${shown} of ${total} alloy${total === 1 ? "" : "s"}`;

  const hidden = ALLOY_FAMILIES.length - allowed.size;
  if (!hidden) return [summary];

  const note = document.createElement("span");
  note.className = "catalog-toolbar__note";
  note.textContent = ` · ${hidden} of ${ALLOY_FAMILIES.length} families hidden`;

  const showAll = document.createElement("button");
  showAll.id = "alloys-show-all";
  showAll.className = "catalog-filter__reset";
  showAll.type = "button";
  showAll.textContent = "Show all families";

  return [summary, note, showAll];
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

  const family = document.createElement("span");
  family.className = "family-chip";
  family.dataset.family = alloy.alloy_family ?? "";
  family.textContent = formatLabel(alloy.alloy_family) || "Alloy";

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
