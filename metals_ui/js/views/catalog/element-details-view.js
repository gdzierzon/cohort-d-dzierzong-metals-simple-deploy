import { getAlloyElementsByElement } from "../../api/alloy-elements-api.js";
import { getAlloys } from "../../api/alloys-api.js";
import { getElement } from "../../api/elements-api.js";
import { labelCurrentVisit } from "../../navigation-history.js";
import { detailsNavMarkup } from "./details-nav.js";

const numberFormatter = new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 });
const percentFormatter = new Intl.NumberFormat("en-US", { maximumFractionDigits: 3 });
const elementImageDirectory = "./assets/images/elements";
const alloyImageDirectory = "./assets/images/alloys";
const fallbackElementImage = "./assets/images/no-image.png";
const fallbackAlloyImage = "./assets/images/no-image.png";

export function elementDetailsView({ atomicNumber } = {}) {
  const atomicNumberValue = Number(atomicNumber);
  const nav = detailsNavMarkup("/elements", "elements");
  if (!Number.isInteger(atomicNumberValue) || atomicNumberValue <= 0) {
    return `<main id="app-content" class="page details-page">${nav}<p class="catalog-status">That element could not be found.</p></main>`;
  }

  // The .details-layout grid moved inside, onto a wrapper, so the alloys section
  // below can be a sibling of it rather than a third column in it.
  return `
    <main id="app-content" class="page details-page">
      ${nav}
      <section id="element-details" data-atomic-number="${atomicNumberValue}" aria-live="polite"><p class="placeholder">Loading element details…</p></section>
    </main>
  `;
}

export async function bindElementDetailsView() {
  const container = document.querySelector("#element-details");
  if (!container) return;

  try {
    const atomicNumber = Number(container.dataset.atomicNumber);
    // The alloy lookups are secondary: if either fails, the element itself should
    // still render, just without its alloys section.
    const [element, memberships, alloys] = await Promise.all([
      getElement(atomicNumber),
      getAlloyElementsByElement(atomicNumber).catch(() => []),
      getAlloys().catch(() => []),
    ]);
    labelCurrentVisit(element.name);
    container.replaceChildren(createDetails(element, memberships, alloys));
  } catch (error) {
    const status = document.createElement("p");
    status.className = "catalog-status";
    status.textContent = error.message || "We could not load this element.";
    container.replaceChildren(status);
  }
}

function createDetails(element, memberships = [], alloys = []) {
  const fragment = document.createDocumentFragment();
  const visual = document.createElement("div");
  visual.className = "details-visual";
  const image = document.createElement("img");
  image.src = `${elementImageDirectory}/${element.symbol}.png`;
  image.alt = element.symbol === "Co" ? "Silvery cobalt metal beside a rich blue crystal on slate" : `${element.name} specimen on slate`;
  image.addEventListener("error", () => {
    image.src = fallbackElementImage;
    image.alt = "No image available";
  }, { once: true });
  visual.append(image);

  const content = document.createElement("article");
  content.className = "details-content";
  content.innerHTML = `<p class="details-content__eyebrow">Element <span></span></p><div class="details-content__title"><h1></h1><span></span></div><p class="details-content__category"></p><dl class="details-facts"><dt>Atomic number</dt><dd></dd><dt>State</dt><dd></dd><dt>Color</dt><dd></dd><dt>Density</dt><dd></dd><dt>Melting point</dt><dd></dd><dt>Boiling point</dt><dd></dd><dt>Magnetic</dt><dd></dd><dt>Toxic</dt><dd></dd></dl>`;

  const spans = content.querySelectorAll("span");
  const facts = content.querySelectorAll("dd");
  spans[0].textContent = String(element.atomic_number);
  spans[1].textContent = element.symbol;
  content.querySelector("h1").textContent = element.name;
  content.querySelector(".details-content__category").textContent = formatLabel(element.category) || "Element";
  const values = [element.atomic_number, formatLabel(element.state_at_room_temp) || "—", formatLabel(element.color) || "—", element.density == null ? "—" : `${numberFormatter.format(element.density)} g/cm³`, element.melting_point_f == null ? "—" : `${numberFormatter.format(element.melting_point_f)} °F`, element.boiling_point_f == null ? "—" : `${numberFormatter.format(element.boiling_point_f)} °F`, element.is_magnetic ? "Yes" : "No", element.is_toxic ? "Yes" : "No"];
  facts.forEach((fact, index) => { fact.textContent = String(values[index]); });

  if (element.common_uses) {
    const uses = document.createElement("section");
    uses.className = "details-uses";
    uses.innerHTML = "<h2>Common uses</h2><p></p>";
    uses.querySelector("p").textContent = element.common_uses;
    content.append(uses);
  }

  const layout = document.createElement("div");
  layout.className = "details-layout";
  layout.append(visual, content);
  fragment.append(layout);

  // Only when the element is actually in something, and that is the common case in
  // reverse: just 29 of the 118 elements appear in any alloy, so 89 element pages
  // would otherwise carry an empty section promising alloys. Copper is the busiest
  // at 49.
  const alloysSection = createAlloysSection(element, memberships, alloys);
  if (alloysSection) fragment.append(alloysSection);

  return fragment;
}

function createAlloysSection(element, memberships, alloys) {
  const alloysById = new Map(alloys.map((alloy) => [Number(alloy.alloy_id), alloy]));
  const resolved = memberships
    .map((membership) => ({ membership, alloy: alloysById.get(Number(membership.alloy_id)) }))
    // An alloy the catalog did not return - deleted between the two requests, or a
    // filtered list - is dropped rather than rendered as a card linking nowhere.
    .filter(({ alloy }) => alloy)
    // Richest first, which is the same ordering the alloy page uses for elements.
    .sort((a, b) => Number(b.membership.percent_of_alloy) - Number(a.membership.percent_of_alloy));

  if (!resolved.length) return null;

  const section = document.createElement("section");
  section.className = "element-alloys";
  section.innerHTML = `<div class="alloy-composition__heading"><div><p class="catalog-intro__eyebrow">Alloys</p><h2></h2></div><p></p></div><div class="composition-grid"></div>`;
  section.querySelector("h2").textContent = `Alloys containing ${element.name}`;
  section.querySelector(".alloy-composition__heading > p").textContent =
    `${resolved.length} ${resolved.length === 1 ? "alloy" : "alloys"}`;
  section
    .querySelector(".composition-grid")
    .replaceChildren(...resolved.map((entry) => createAlloyCard(entry, element)));
  return section;
}

function createAlloyCard({ membership, alloy }, element) {
  const card = document.createElement("a");
  card.className = "composition-card";
  card.href = `#/alloys/${alloy.alloy_id}`;
  card.innerHTML = `<img><div class="composition-card__body"><div class="composition-card__top"><span class="composition-card__number"></span><strong class="composition-card__percent"></strong></div><div class="composition-card__identity"><h3></h3></div><span class="composition-card__link">View alloy <span aria-hidden="true">›</span></span></div>`;

  const image = card.querySelector("img");
  image.src = `${alloyImageDirectory}/${slugify(alloy.name)}.png`;
  image.alt = `${alloy.name} polished alloy bar on slate`;
  image.loading = "lazy";
  image.addEventListener("error", () => {
    image.src = fallbackAlloyImage;
    image.alt = "No image available";
  }, { once: true });

  // The label and the percentage sit side by side and read as a pair, so the label
  // has to name what the number measures. The alloy's family here would produce
  // "Precious 38.3%" on 10K Yellow Gold, where 38.3% is its copper, not its gold.
  card.querySelector(".composition-card__number").textContent = `${element.symbol} content`;
  card.querySelector(".composition-card__percent").textContent =
    `${percentFormatter.format(Number(membership.percent_of_alloy))}%`;
  card.querySelector("h3").textContent = alloy.name;
  return card;
}

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function formatLabel(value) {
  return value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase()) : "";
}
