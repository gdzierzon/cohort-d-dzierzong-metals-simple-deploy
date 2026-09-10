export function adminHomeView() {
  return `
    <main id="app-content" class="page admin-page">
      <header class="admin-header"><div><p class="catalog-intro__eyebrow">Control room</p><h1>Administration</h1><p>Manage the reference catalog available to Metals Atlas customers.</p></div></header>
      <div class="admin-home-grid">
        <a class="admin-home-card" href="#/admin/elements"><img src="./assets/images/elements-gold-nugget-slate.png" alt="Gold specimen on slate"><span><strong>Elements</strong><small>Manage elemental records</small></span></a>
        <a class="admin-home-card" href="#/admin/alloys"><img src="./assets/images/alloys-ingots-slate.png" alt="Alloy ingots on slate"><span><strong>Alloys</strong><small>Manage alloy records</small></span></a>
        <a class="admin-home-card" href="#/admin/coins"><img src="./assets/images/coins-collection.png" alt="Collection of proof coins"><span><strong>Coins</strong><small>Manage coin records</small></span></a>
        <a class="admin-home-card admin-home-card--users" href="#/admin/users"><span class="admin-home-card__icon" aria-hidden="true">✦</span><span><strong>Users</strong><small>Manage administrator permissions</small></span></a>
      </div>
    </main>
  `;
}
