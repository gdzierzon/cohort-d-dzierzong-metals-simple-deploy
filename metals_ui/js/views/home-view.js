export function homeView() {
  return `
    <main id="app-content" class="page home">
      <div class="home__frame">
        <section class="hero" aria-labelledby="home-title">
          <div class="hero__content">
            <div class="hero__eyebrow" aria-hidden="true"></div>
            <h1 id="home-title">Metals <span>Atlas</span></h1>
            <p class="hero__description">Explore elements, alloys &amp; coins.</p>
            <div class="hero__actions">
              <a class="button button--primary" href="#/login">Log in <span aria-hidden="true">›</span></a>
            </div>
          </div>
        </section>
        <section class="home__collections" aria-label="Explore the catalog">
          <a class="collection-card" href="#/elements">
            <img class="collection-card__image" src="./assets/images/elements-gold-nugget-slate.png" alt="A natural gold nugget on slate" />
            <span class="collection-card__footer"><span class="collection-card__title">Elements</span><span class="collection-card__arrow" aria-hidden="true">›</span></span>
          </a>
          <a class="collection-card" href="#/alloys">
            <img class="collection-card__image" src="./assets/images/alloys-ingots-slate.png" alt="Gold and silver alloy ingots on slate" />
            <span class="collection-card__footer"><span class="collection-card__title">Alloys</span><span class="collection-card__arrow" aria-hidden="true">›</span></span>
          </a>
          <a class="collection-card" href="#/coins">
            <img class="collection-card__image" src="./assets/images/coins-collection-slate.png" alt="Silver and gold collectible coins on slate" />
            <span class="collection-card__footer"><span class="collection-card__title">Coins</span><span class="collection-card__arrow" aria-hidden="true">›</span></span>
          </a>
        </section>
      </div>
    </main>
  `;
}
