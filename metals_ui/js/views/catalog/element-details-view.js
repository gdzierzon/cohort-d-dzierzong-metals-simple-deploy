import { getElement } from "../../api/elements-api.js";

const numberFormatter = new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 });
const elementImageDirectory = "./assets/images/elements";
const fallbackElementImage = `${elementImageDirectory}/generic.png`;

export function elementDetailsView({ atomicNumber } = {}) {
  const atomicNumberValue = Number(atomicNumber);
  if (!Number.isInteger(atomicNumberValue) || atomicNumberValue <= 0) {
    return `<main id="app-content" class="page details-page"><a class="details-back" href="#/elements">‹ Back to elements</a><p class="catalog-status">That element could not be found.</p></main>`;
  }

  return `
    <main id="app-content" class="page details-page">
      <a class="details-back" href="#/elements">‹ Back to elements</a>
      <section id="element-details" class="details-layout" data-atomic-number="${atomicNumberValue}" aria-live="polite"><p class="placeholder">Loading element details…</p></section>
    </main>
  `;
}

export async function bindElementDetailsView() {
  const container = document.querySelector("#element-details");
  if (!container) return;

  try {
    const element = await getElement(Number(container.dataset.atomicNumber));
    container.replaceChildren(createDetails(element));
  } catch (error) {
    const status = document.createElement("p");
    status.className = "catalog-status";
    status.textContent = error.message || "We could not load this element.";
    container.replaceChildren(status);
  }
}

function createDetails(element) {
  const fragment = document.createDocumentFragment();
  const visual = document.createElement("div");
  visual.className = "details-visual";
  const image = document.createElement("img");
  image.src = `${elementImageDirectory}/${element.symbol}.png`;
  image.alt = element.symbol === "Co" ? "Silvery cobalt metal beside a rich blue crystal on slate" : `${element.name} specimen on slate`;
  image.addEventListener("error", () => {
    image.src = fallbackElementImage;
    image.alt = "Generic atomic element illustration";
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

  fragment.append(visual, content);
  return fragment;
}

function formatLabel(value) {
  return value ? value.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase()) : "";
}
